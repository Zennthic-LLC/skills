---
name: ratel
description: "Use whenever Ratel (a.k.a. Ratel Gateway) MCP tools are available in the session. Ratel is a gateway for managing Docker across one or more registered hosts. Apply this skill whenever Ratel tools are present, even if the user never says the word Ratel: any request to inspect containers, read container logs, check container or host health, list images/volumes/networks, pull an image, or start/stop/restart a container on a remote Docker host is a Ratel task. The cardinal rule — every Ratel tool except list_hosts takes a required host id, so call list_hosts first to discover hosts, then target every other call by host. Scope: Ratel does container lifecycle (start/stop/restart/pull) and observability (list/inspect/logs/stats, plus system info and disk usage); it does NOT create, run, exec into, build, or delete containers/images/volumes/networks — don't promise what it can't do."
---

# Ratel

Ratel (the Ratel Gateway) is a Docker management layer exposed over MCP. A single gateway fronts one or more Docker hosts registered with it, and lets you observe and operate the containers running on them without SSHing into each box.

Think of Ratel as two things bolted together:

- **An observability surface** over every registered host — what is running, how it is configured, what it is logging, and how much CPU/memory/disk it is using.
- **A narrow container-lifecycle remote** — start, stop, restart a container, and pull an image.

It is deliberately not a full Docker CLI. Knowing the edges of what it can do is as important as knowing the tools themselves.

## The cardinal rule: resolve the host first

Every Ratel tool **except `list_hosts`** has a required `host` parameter — the `host_id` of the Docker host to act on. There is no implicit "current" or "default" host.

So the first move in almost any Ratel interaction is **`list_hosts`**. It returns the registered hosts with their `host_id`, display name, and last-seen status. From there:

- **Never guess or hard-code a `host_id`.** Discover it.
- **Map the user's words to a host.** Users say "the prod box," "staging," "the NAS" — resolve that against the display names from `list_hosts`. If it is ambiguous, ask rather than guess.
- **Mind last-seen.** If a host looks offline/stale in `list_hosts`, surface that before blaming a container — the gateway may simply have lost contact with that daemon.
- **One host at a time.** Operations are per-host. To act across hosts, iterate; the same container or image name can exist on several hosts, so always pass the right one.
- **Confirm correct host if duplicate containers** You may find the same container names and patterns on different hosts, which is likely separate dev/test/prod instances of the container stack. Ensure you know what environment you should be operating in, the correct hostname based on past history if highly confident, before proceeding. Ask for confirmation if you are not sure.

## What Ratel can and cannot do

**Can (observability):** `list_hosts`, `system_info`, `system_df`, `list_containers`, `list_images`, `list_networks`, `list_volumes`, `inspect_container`, `get_logs`, `get_stats`.

**Can (lifecycle):** `start_container`, `stop_container`, `restart_container`, `pull_image`.

**Cannot — do not promise these:**
- Create / `run` a new container, or recreate one with new config.
- `exec` into a container or run commands inside it.
- Remove or prune containers, images, volumes, or networks.
- Build images, or push to a registry.
- Drive `docker compose` up/down (it can *see* a container's compose project via `inspect_container`, but not control the stack).

If a request needs one of these, say so plainly and stop at the boundary — e.g. "Ratel can pull the image and restart the container, but it can't recreate it with a new port mapping; that needs a change on the host itself." Offer the closest supported action.

## Tool selection

Group the tools by intent:

- **Orient** — `list_hosts` (always first), then `system_info` (daemon version, OS/kernel, CPU/mem, container/image counts) and `system_df` (disk rolled up by images/containers/volumes) for a health read on the host itself.
- **Inventory** — `list_containers` (with filters; `all=true` to include stopped), `list_images`, `list_networks`, `list_volumes`.
- **Diagnose one container** — `inspect_container` (state, restart count, exit code, mounts, network, restart policy, compose project), `get_logs`, `get_stats` (one-shot CPU/mem/net/block-I/O).
- **Act** — `start_container`, `stop_container`, `restart_container`, `pull_image`.

### Finding the right container

`list_containers` is how you turn a vague reference into a concrete container `id` (name or ID both work on the lifecycle/inspect tools). Use its filters instead of pulling the whole list and eyeballing:

- `status` — e.g. running, exited.
- `name_contains` — substring match on name.
- `label_equals` — `key=value` label match (great for compose projects/services).
- `all=true` — **include stopped containers.** A container that "disappeared" is usually just stopped, not gone.

### Reading logs well

`get_logs` defaults to `tail=200` (max 2000). Don't dump the max when a small tail answers the question. Use:
- `since_unix` to bound logs to a time window (e.g. since the last restart/incident).
- `timestamps=true` when correlating events.
- `stdout`/`stderr` toggles to cut noise — errors usually live on `stderr`.

### A standard "why is this container unhealthy?" pass

1. `list_containers` with `all=true` (and a `name_contains`/`label_equals` filter) → find the container and its current status.
2. `inspect_container` → restart count, last exit code, restart policy, mounts/network.
3. `get_logs` with a sensible `tail` (and `stderr`) → the actual error.
4. `get_stats` → rule resource exhaustion in or out (CPU pegged, memory near limit).

That sequence answers most "it's down / it's flapping / it's slow" questions before you touch a single mutating tool.

## Mutations: act with care

`start_container` is low-risk. **`stop_container` and `restart_container` cause downtime**, and on a shared or production host that downtime is visible to others — confirm the host and container with the user before issuing them unless already authorized. **`pull_image` changes the host's image store and uses bandwidth** — confirm the `reference` (e.g. `nginx:1.27-alpine`) and host.

Practical guidance:
- Always state **which host and which container** you're about to act on, in the user's terms.
- Use `timeout_sec` on stop/restart when a process needs a moment to drain; otherwise the default graceful stop applies.
- **Verify after acting.** `pull_image` does not restart anything — a newly pulled tag has no effect until the container is restarted onto it, and Ratel can't recreate a container, so if the container pins an old image or config you may need a host-side change. After start/stop/restart, re-`inspect_container` or `list_containers` to confirm the new state.

## Anti-patterns

- **Calling any tool without `host`, or guessing a `host_id`.** `list_hosts` first, every time.
- **Assuming a missing container is deleted.** Re-list with `all=true`; it's probably stopped.
- **Promising create/exec/rm/build/compose.** Ratel doesn't expose them. Name the boundary instead of improvising.
- **Stopping or restarting shared services without confirmation.** Downtime is visible to others.
- **Dumping 2000 log lines.** Start with a small tail + `stderr` + `since_unix`; widen only if needed.
- **Treating `get_stats` as monitoring.** It's a single snapshot, not a stream — take a couple of readings if you need a trend, and don't present one sample as steady state.
- **Acting on the wrong host.** The same name can exist on many hosts; bind every call to the host you actually mean.

## Quick reference

| Situation | Tool(s) |
|---|---|
| Start of any Ratel task | `list_hosts` → get `host_id` |
| Host health / version / capacity | `system_info`, `system_df` |
| What's running here? | `list_containers` (`all=true` for stopped) |
| Find a specific container | `list_containers` + `name_contains` / `label_equals` / `status` |
| Why is it down/flapping/slow? | `inspect_container` → `get_logs` → `get_stats` |
| What images/volumes/networks exist? | `list_images`, `list_volumes`, `list_networks` |
| Bring a stopped container up | `start_container` |
| Take a container down / cycle it | `stop_container` / `restart_container` (confirm first; `timeout_sec` to drain) |
| Get a newer image onto the host | `pull_image` (then restart the container; confirm `reference` + host) |
| Asked to create/exec/rm/build/compose | Not supported — state the boundary, offer nearest action |
