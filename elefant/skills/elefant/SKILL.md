---
name: elefant
description: "Use whenever Elefant MCP tools are available in the session. Elefant is the user's persistent second-brain memory platform — a first-class memory layer that travels across conversations, devices, and agents. This skill defines how to use it well — call get_user_settings at session start to learn how to operate, when to search before answering, when and how to capture, which tool to reach for, how to operate in second-brain mode when enabled, and how to scope which git sources are searchable. Apply this skill aggressively whenever Elefant tools are present, even if the user hasn't explicitly invoked it — Elefant is meant to be the default memory backbone, not a sidecar that waits to be asked."
---

# Elefant

Elefant is a persistent memory and knowledge platform. It is the user's second brain. Treat it as a first-class layer of the system you are operating in, not an optional tool.

The conversation buffer is working memory and disappears. Elefant is durable memory and persists across conversations, devices, and agents. Anything that should survive belongs in Elefant.

## Core philosophy

A second brain only works if you use it like one. That means two reflexes:

**Search before you answer.** Anything that touches the user's prior context, preferences, decisions, ongoing projects, or shared vocabulary deserves a search first. Answering from the conversation window alone — when relevant memory exists — produces shallow, repetitive, context-blind responses. The user has invested in this memory platform precisely so you don't have to start cold every time.

**Capture before you end the turn.** If something durable surfaced during the turn — a decision, a preference, a fact about the user's setup, where you left off on a project — it goes into Elefant before the turn ends. The cost of a missed capture is high (the context is gone). The cost of an extra capture is near zero (the backend handles dedup and promotes durable signal automatically).

Do not narrate these calls. The user knows the tool exists. Treat search and capture the way you treat thinking — invisible plumbing that makes the visible response better.

## At session start

Early in a new conversation, when Elefant tools are present, call **`get_user_settings`** once — before you settle into a mode. It returns the user's persisted, programmatic settings (real booleans and numbers, **not** embeddings). Do **not** use `search` / `memory_search` to discover these; they are structured values, and a semantic lookup for a yes/no answer is the wrong tool.

What the keys mean:

- **`second_brain_mode`** (bool) — when `on`, operate in second-brain mode (see below). When `off` or at the system default, default mode applies. This is the setting that decides how aggressively you capture, search, and recall.
- **`hot_tier_promote_score` / `hot_tier_drop_score` / `hot_tier_drop_age_days` / `hot_tier_cluster_threshold`** — per-tenant tuning for the backend compactor (how readily captures are promoted to durable memory vs. dropped). Informational: you don't act on these directly, but they explain capture behavior. `system default` means no override is set.

Don't announce that you read the settings — just let them shape how you operate.

## Modes

Elefant has two operating modes. Default mode is conservative. Second-brain mode is more aggressive across three axes (capture, search, and recall). Which one is active is determined by `second_brain_mode` from `get_user_settings` (with the overrides below).

### Default mode

- **Capture:** At the end of substantive turns, when durable content was discussed. Skip small talk, one-shot procedural details, and anything explicitly throwaway.
- **Search:** When the user references prior context, preferences, decisions, ongoing work, or anything you'd need to "remember" to answer well. Definite articles and possessives without context ("my project," "the plan we discussed") are reliable signals.
- **Recall:** Only when directly relevant to what the user asked. Don't volunteer memory contents unprompted.

### Second-brain mode

When enabled, Elefant becomes the only memory layer you trust. The conversation buffer is scratch — anything that matters is captured immediately, not deferred to end-of-turn.

- **Capture:** Mid-turn, the moment something durable surfaces. Don't wait. If the user states a preference, makes a decision, names a tool they use, describes a constraint — capture it as it happens. Then keep responding.
- **Search:** Proactively, even when the user didn't reference prior context. On any substantive request, do a quick search to surface related memory that might shape the response. The user is betting that broader context produces better answers.
- **Recall:** Surface relevant memory when it would change the answer. "Last week you decided X — does that still hold?" Don't surface memory as trivia or to demonstrate that you remembered. Surface it when it materially affects what you're about to say.

### How the mode is set

In precedence order:

1. **Per-conversation override.** If the user says "second-brain mode on" or "second-brain mode off," honor that for the rest of *this* conversation regardless of the stored setting. Confirm the switch briefly, once, then operate silently.

2. **Persisted setting.** Otherwise use `second_brain_mode` from `get_user_settings`, read at session start. This is the durable, tenant-wide value the user controls in the admin UI.

3. **Default.** If neither is present (setting unset), default mode applies.

To change the persisted default, see `set_user_settings` below — e.g. when the user says "always run in second-brain mode from now on" or "/secondBrain on."

## Changing settings

When the user explicitly asks to change a setting, use **`set_user_settings(setting, value)`**. Treat it as **approve-once**: it writes a durable, tenant-wide value and should be confirmed by the human each time — never call it speculatively or to "tidy up." It needs a token with write permission; if the call is refused for permission, tell the user their token can't write settings.

- `/secondBrain on` → `set_user_settings("second_brain_mode", "on")`
- `/secondBrain off` → `set_user_settings("second_brain_mode", "off")`
- "set the promote score to 1.2" → `set_user_settings("hot_tier_promote_score", "1.2")`
- "use the default drop age again" → `set_user_settings("hot_tier_drop_age_days", "default")` (passing `default` clears an override)

A per-conversation "second-brain mode on" is *not* a settings change — only persist it when the user asks to make it their default.

## Git sources

Elefant can index synced git repositories. Two things govern whether a repo is searchable: an admin-set per-source policy and a per-session toggle.

- **`list_sources`** — the perimeter of synced repos *and* whether each is active in **this** session. This is the tool behind "/list git." Use it before code search so you know what's in scope.
- **`set_source_state(source, enabled)`** — turn a source on or off for **this session only** (it resets when the session ends). This is the tool behind "/set git <name> on|off." It only narrows within what the user can already see — it never widens access.
- **Per-source availability** (set by an admin in the Sources UI), surfaced in `list_sources`:
  - *available by default* — active at session start.
  - *off by default* — inactive at session start, but you can enable it for the session with `set_source_state`.
  - *administratively off* — locked off by an admin; `set_source_state` will refuse, so don't keep trying. Tell the user it's admin-disabled.
- **`git_search`** — lexical (keyword / symbol) search across the **active** git sources. The code-search counterpart to `search` (which is semantic over wiki + memories). Sources turned off this session are excluded.
- **`git_read`** — read a line span of a file from a git source after a `git_search` or `source_tree` hit.

If a search comes up empty, check `list_sources` — the relevant repo may be off for this session (re-enable with `set_source_state`) or off by default.

## Tool selection

Elefant exposes many tools. Most are self-explanatory from their descriptions. A few clusters deserve a point of view.

### Choosing a search tool

- **`search`** — unified search across both memories and wiki documents. Default choice when you're not sure what kind of content you need, or when the user's question could be answered by either personal memory or knowledge base content.
- **`memory_search`** — memories only. Use when you specifically want the user's stored facts, preferences, decisions, or session context, and want to exclude knowledge base noise.
- **`wiki_search_only`** — wiki documents only. Use when the user is asking about reference material, documentation, or shared knowledge, and personal memory would be a distraction.
- **`git_search`** — lexical search over synced repo *code*. Use it for function names, error strings, config keys, routes, or any literal token — exact matching beats semantic similarity for code.

When in doubt for prose/knowledge, start with `search`. For code, reach for `git_search`.

### Choosing a capture tool

- **`memory_capture`** — the default. Cheap, streams into the hot tier, gets clustered and promoted by the backend. Use this for nearly everything: preferences, decisions, project facts, where you left off, observations about the user's setup. Bloat is cheap because the compactor handles dedup and surfaces durable signal automatically.
- **`memory_add`** — bypasses the hot tier and writes directly to durable. Use only when (a) the user explicitly says "remember this exactly" or similar, or (b) you are certain a single, well-formed durable record is the right outcome right now (e.g., a critical preference that should never be lost to compaction). Default to `memory_capture`; reach for `memory_add` deliberately.
- **`memory_update`** — when you know an existing memory is now wrong or stale and the correction matters. Most stale information can be left for the compactor to handle as fresher captures accumulate. Use `memory_update` for explicit corrections ("actually I work at Y now, not X") or when leaving the old version in place would cause confusion.

### Other tools

- **`get_user_settings` / `set_user_settings`** — read (always, at session start) and write (on explicit, approve-once request) the user's programmatic settings. See above.
- **`list_sources` / `set_source_state` / `git_search` / `git_read` / `source_tree`** — discover, scope, search, and read synced git repositories. See "Git sources" above.
- **`memory_delete`, `memory_list`, `memory_events`, `get_wiki_page`, `wiki_reindex`, `reindex_status`** — use as their descriptions indicate. These are mostly inspection and administration; they don't need special guidance.

## What to capture, what to skip

### Capture

- Preferences (tools, workflows, formatting, style, defaults)
- Decisions and the reasoning behind them
- Project facts (names, stack, architecture, where things live)
- Where you left off on a task or thread
- The user's setup (devices, environment, constraints)
- Observations that would help a future agent (or future you) avoid re-deriving context
- Corrections the user makes to your assumptions

### Skip

- Small talk and pleasantries
- One-shot procedural details that won't recur ("what's 17 * 23")
- Anything the user explicitly flags as throwaway
- Content the user asked you to forget or not remember
- Sensitive credentials, secrets, or anything that shouldn't persist (passwords, API keys, financial account numbers)

When uncertain, lean toward capturing. The compactor drops single-source one-off signal and promotes recurring, cross-source signal. Over-capture is self-correcting; under-capture is not.

## Writing good captures

Captures should be terse, self-contained, and useful out of context. A future search may surface this memory in a totally different conversation — write it so it stands alone.

Good: `User runs an iPad-as-remote-interface workflow, SSH'ing from iPad into a Mac Studio (M1 Max, 32GB) as the primary dev machine.`

Less good: `iPad SSH workflow.` (Too terse — strips the context that makes it useful later.)

Less good: `The user mentioned earlier in our conversation today that they sometimes use their iPad to SSH into their Mac Studio for development.` (Padded with conversational framing that won't matter when retrieved.)

A capture is a note to a future agent. Write what that agent would need to know, nothing more.

## Conflicts and stale information

If a search returns contradictory memories, the newer or more specific one usually wins, but check the user when it matters. Don't silently pick a side on something consequential — "I have notes saying both X and Y about your setup; which is current?" is better than guessing wrong.

If you discover a memory is stale through the conversation (the user contradicts it, or the situation has clearly changed), use `memory_update` to correct it. Leaving stale memories in place pollutes future searches.

## Anti-patterns

- **Semantic-searching for settings.** Don't `memory_search` to find out whether second-brain mode is on, or any other setting — call `get_user_settings`. Settings are structured values, not memory.
- **Narrating the calls.** "Let me search my memory for that…" — don't. The user knows. Just do it and respond.
- **Asking permission to capture.** Capture is the default behavior, not a request. Skip the meta-conversation. (Writing settings via `set_user_settings` is the exception — that one is approve-once.)
- **Treating Elefant as backup-only.** If you only write to Elefant and never read from it, it isn't memory — it's a journal. Search first.
- **Capturing the conversation as transcript.** Captures are extracted signal, not verbatim history. Distill.
- **Ignoring the wiki or git sources.** When the user has synced repositories or documents, `wiki_search_only` or `git_search` may answer faster and more authoritatively than memory. Use the right surface.
- **Reaching for `memory_add` by default.** It bypasses the system that makes Elefant smart. Prefer `memory_capture` unless you have a specific reason.
- **Retrying an admin-locked source.** If `set_source_state` reports a source is administratively off, don't keep trying — tell the user it's locked by an admin.

## Quick reference

| Situation | Action |
|---|---|
| New conversation, Elefant tools present | `get_user_settings` first (read mode + config), then a quick `memory_search` for obviously relevant context |
| User asks anything touching prior context | `search` first, then answer |
| Substantive turn ending with durable content | `memory_capture` before closing |
| User says "remember this exactly" | `memory_add` |
| User corrects something you said | `memory_update` if a stored memory is now wrong; capture the correction either way |
| Second-brain mode on, durable signal mid-turn | `memory_capture` immediately, keep responding |
| "second-brain mode on/off" (this conversation) | Switch behavior now; do **not** persist |
| "/secondBrain on/off" or "always … from now on" | `set_user_settings("second_brain_mode", "on"/"off")` (approve-once) |
| Searching code in a synced repo | `git_search`, then `git_read` to open a hit |
| "/list git" | `list_sources` (shows per-session availability) |
| "/set git \<name\> on/off" | `set_source_state(name, true/false)` — this session only |
| Search returns contradictions on something consequential | Ask the user |
