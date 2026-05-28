---
name: elefant
description: "Use whenever Elefant MCP tools are available in the session. Elefant is the user's persistent second-brain memory platform — a first-class memory layer that travels across conversations, devices, and agents, plus a shared wiki the agent can both read and author. This skill defines how to use it well — when to search before answering, when and how to capture, which tool to reach for, when durable content belongs in memory versus the wiki, how to read the user's operating mode and configuration from stored settings, and how to operate in second-brain mode when enabled. Apply this skill aggressively whenever Elefant tools are present, even if the user hasn't explicitly invoked it — Elefant is meant to be the default memory backbone, not a sidecar that waits to be asked."
---

# Elefant

Elefant is a persistent memory and knowledge platform. It is the user's second brain. Treat it as a first-class layer of the system you are operating in, not an optional tool.

The conversation buffer is working memory and disappears. Elefant is durable memory and persists across conversations, devices, and agents. Anything that should survive belongs in Elefant.

Elefant holds two kinds of durable content, and you can write to both:

- **Memory** — extracted signal about the user and their work: preferences, decisions, project facts, session context. Captured tersely, retrieved by search, curated automatically by a background compactor.
- **Wiki** — long-form Markdown documents: runbooks, SOPs, reference material, summaries, design notes. Human-readable pages meant to be read as documents, not retrieved as facts.

Knowing which surface a piece of durable content belongs in is a core skill — see *Memory vs. wiki* below.

## Core philosophy

A second brain only works if you use it like one. That means three reflexes:

**Search before you answer.** Anything that touches the user's prior context, preferences, decisions, ongoing projects, or shared vocabulary deserves a search first. Answering from the conversation window alone — when relevant memory exists — produces shallow, repetitive, context-blind responses. The user has invested in this memory platform precisely so you don't have to start cold every time.

**Resolve who and what they mean.** First-person references — "our channel," "we decided," "my repo" — point at entities the user expects you to already know. Resolve them against stored identity before answering; don't infer the referent from whatever happens to be in the current results. If the search turns up no clear identity fact, that absence *is* the signal: ask, then capture the answer so the next agent doesn't have to.

**Capture before you end the turn.** If something durable surfaced during the turn — a decision, a preference, a fact about the user's setup, where you left off on a project — it goes into Elefant before the turn ends. The cost of a missed capture is high (the context is gone). The cost of an extra capture is near zero (the backend handles dedup and promotes durable signal automatically).

Do not narrate these calls. The user knows the tool exists. Treat search and capture the way you treat thinking — invisible plumbing that makes the visible response better.

## Modes

Elefant has two operating modes. Default mode is conservative and always on. Second-brain mode is opt-in and more aggressive across three axes (capture, search, and recall).

### Default mode (always on)

- **Capture:** At the end of substantive turns, when durable content was discussed. Skip small talk, one-shot procedural details, and anything explicitly throwaway.
- **Search:** When the user references prior context, preferences, decisions, ongoing work, or anything you'd need to "remember" to answer well. Definite articles and possessives without context ("my project," "the plan we discussed") are reliable signals.
- **Recall:** Only when directly relevant to what the user asked. Don't volunteer memory contents unprompted.

### Second-brain mode (opt-in)

When enabled, Elefant becomes the only memory layer you trust. The conversation buffer is scratch — anything that matters is captured immediately, not deferred to end-of-turn.

- **Capture:** Mid-turn, the moment something durable surfaces. Don't wait. If the user states a preference, makes a decision, names a tool they use, describes a constraint — capture it as it happens. Then keep responding.
- **Search:** Proactively, even when the user didn't reference prior context. On any substantive request, do a quick search to surface related memory that might shape the response. The user is betting that broader context produces better answers.
- **Recall:** Surface relevant memory when it would change the answer. "Last week you decided X — does that still hold?" Don't surface memory as trivia or to demonstrate that you remembered. Surface it when it materially affects what you're about to say.

### How users toggle

Two paths:

1. **Per-conversation.** The user says "second-brain mode on" or "second-brain mode off" (variants: "stretch its legs," "full second brain," "go conservative," "default mode"). Switch behavior for the rest of the conversation *without* changing the stored setting. Confirm the switch briefly, once, then operate silently.

2. **Persistent.** The mode is a real stored setting, not a memory. Read it with `get_user_settings` and change the default with `set_user_settings` (`second_brain_mode` → `on`/`off`). Do **not** `memory_search` for the mode — `get_user_settings` is the authoritative source. See *Reading and writing settings* below.

Resolve the two at the start of a session: read the persistent setting once with `get_user_settings`, then apply any per-conversation override the user states this turn. Persisting a new default ("always run in second-brain mode from now on") means calling `set_user_settings` — a tenant-wide, approve-once write you only make on an explicit request.

## Tool selection

Elefant exposes many tools. Most are self-explanatory from their descriptions. Four clusters deserve a point of view.

### Choosing a search tool

- **`search`** — unified search across both memories and wiki documents. Default choice when you're not sure what kind of content you need, or when the user's question could be answered by either personal memory or knowledge base content.
- **`memory_search`** — memories only. Use when you specifically want the user's stored facts, preferences, decisions, or session context, and want to exclude knowledge base noise.
- **`wiki_search_only`** — wiki documents only. Use when the user is asking about reference material, documentation, or shared knowledge, and personal memory would be a distraction.

When in doubt, start with `search`. Narrow to `memory_search` or `wiki_search_only` if results are diluted.

**Search ranks by relevance, not recency.** The top hit is the best *match*, not the *newest* item. When the user asks for the "latest," "newest," or "most recent" of something, don't answer with the first result — resolve by date: read the series' index/landing page (kept newest-first) or compare a dated metadata field (e.g. a `Published:` line) across the candidates. And keep two dates separate: when something happened in the real world versus when its page was written. They diverge — the most recently *authored* page is often not the most recently *published* thing.

### Choosing a capture tool

- **`memory_capture`** — the default. Cheap, streams into the hot tier, gets clustered and promoted by the backend. Use this for nearly everything: preferences, decisions, project facts, where you left off, observations about the user's setup. Bloat is cheap because the compactor handles dedup and surfaces durable signal automatically.
- **`memory_add`** — bypasses the hot tier and writes directly to durable. Use only when (a) the user explicitly says "remember this exactly" or similar, or (b) you are certain a single, well-formed durable record is the right outcome right now (e.g., a critical preference that should never be lost to compaction). Default to `memory_capture`; reach for `memory_add` deliberately.
- **`memory_update`** — when you know an existing memory is now wrong or stale and the correction matters. Most stale information can be left for the compactor to handle as fresher captures accumulate. Use `memory_update` for explicit corrections ("actually I work at Y now, not X") or when leaving the old version in place would cause confusion. Note: it only targets **durable-tier** memories — calling it with the id of a recent `memory_capture` that's still in the hot tier returns 404. To correct something you just captured, write a corrected `memory_capture`/`memory_add` (or let the compactor reconcile it) rather than updating by id.

### Writing to the wiki

**`wiki_write`** creates or updates a Markdown wiki page. Reach for it when the user wants durable, structured, human-readable reference material — a runbook, an SOP, a design note, a project summary, an onboarding doc — something meant to be *read as a document*, not retrieved as a fact. It is the right tool when the output is too long, too structured, or too reference-like to live as memory.

A few rules govern it, by design:

- **AI pages live in a dedicated folder.** Agents may only write inside the org's designated AI folder (default `AI/`). A bare name like `notes.md` is auto-placed there; you can also organise content into **subfolders** — `AI/runbooks/db-restore.md`, `AI/designs/auth-rework.md`. You cannot write outside the AI folder, and you cannot overwrite human-authored pages elsewhere.
- **AI pages are clearly labelled.** Every page under the AI folder shows an "AI-generated" banner in the wiki UI. The label is tied to the page's location, not baked into the file — so it's honest and automatic.
- **Humans promote by moving.** When a human reviewer validates a page, they move it out of the AI folder. At that point the banner disappears, the page reads as ordinary human-reviewed content, and **agents can no longer modify it**. Don't try to "promote" a page yourself or write outside the AI folder to skip review — that boundary is the point.
- **Create or update.** Writing to an existing path under the AI folder replaces its content. Before substantially rewriting a page you didn't create this session, consider `get_wiki_page` to read what's there.
- **Requires the `wiki_write` scope.** If the token lacks it, the tool returns a permission error — that's expected, not a bug. The same scope governs `wiki_reindex`.

Use `wiki_write` for the artifact; still `memory_capture` the *fact that you created it* if it matters for continuity ("Wrote the DB-restore runbook to `AI/runbooks/db-restore.md`").

### Finding the right wiki path

Path handling is the most common stumble, because search and the file tools speak different dialects:

- **Search and `wiki_search_only` display *tenant-prefixed* paths** — e.g. `the-smart-workshop/AI/youtube-transcripts/...`. That leading segment is the tenant / wiki root, **not** part of the page path.
- **`get_wiki_page` and `wiki_write` want the path with that tenant segment stripped** — start at the top-level folder: `Code Reference/Linux/Armbian.md`, `AI/runbooks/db-restore.md`. Passing the displayed `the-smart-workshop/...` form straight back will 404.
- **Your writable root is always `AI/`.** Write `AI/<area>/<file>.md`; never prepend the tenant or a brand name to get there (no `the-smart-workshop/AI/...`). A channel, project, or brand can be a *subfolder* — `AI/youtube-transcripts/the-smart-workshop/<video>.md` — and watch the trap when the tenant name and a subfolder name coincide, which makes the displayed path look doubled (`the-smart-workshop/AI/.../the-smart-workshop/...`). Only one of those is the tenant root.
- **To read an `AI/` page, prefer `search` / `wiki_search_only` over `get_wiki_page`.** Agent-authored `AI/` pages are indexed and searchable, but `get_wiki_page` may 404 on them; the search tools return the page body in chunks, which is the dependable way to read AI content back. If a path you got from search 404s on `get_wiki_page`, don't keep permuting it — fall back to search.

### Reading and writing settings

`get_user_settings` and `set_user_settings` read and write Elefant's **prescriptive configuration** — real stored values (booleans, numbers), not semantic memory. Never use `search` or `memory_search` to discover them.

- **`get_user_settings`** — call once near the start of a session, before answering, to learn how to operate this session. It returns the tenant's settings as concrete values; a key shown as "system default" has no override set. The key that changes your behavior is `second_brain_mode` (on/off) — it decides which mode you run in (see *Modes*). The others tune the hot-tier compactor — `hot_tier_promote_score`, `hot_tier_drop_score`, `hot_tier_drop_age_days`, `hot_tier_cluster_threshold` — and rarely need your attention unless the user asks about retention or promotion behavior.
- **`set_user_settings`** — writes ONE setting for the entire tenant. Because it's durable and tenant-wide, treat every call as approve-once: only call it when the user explicitly asks to change a setting ("turn on second-brain mode from now on", "set the promote score to 1.2"). Never call it speculatively or to "tidy up." Pass `default` (or `none`/`clear`) as the value to drop an override and return to the system default. It needs a token with `memory_write` permission; a permission error there is expected, not a bug.

Mode preference and the compactor thresholds live here, not in memory. If the user wants second-brain mode on by default, `set_user_settings second_brain_mode on` — don't write a memory like "user prefers second-brain mode" and try to read it back next session.

### Other tools

`memory_delete`, `memory_list`, `memory_events`, `get_wiki_page`, `list_sources`, `source_tree`, `set_source_state`, `git_read`, `git_search`, `wiki_reindex`, `reindex_status` — use as their descriptions indicate. These are mostly inspection, source navigation, and administration; they don't need special guidance.

## Memory vs. wiki: where durable content belongs

Both persist. The question is *shape and audience*.

**Memory** is extracted signal, retrieved by search, read by agents. It's terse, atomic, and self-contained. It answers "what do I know about this user / project / decision?" It's curated automatically — capture liberally and let the compactor sort it out.

**Wiki** is a document, read by humans (and agents) as a coherent whole. It's long-form, structured, and deliberate. It answers "how do we do X?" or "what is the design of Y?" Nothing curates it automatically — what you write is what stays, until a human edits or promotes it.

Rules of thumb:

- A preference, a fact, a decision, where you left off → **memory** (`memory_capture`).
- A procedure, a reference doc, an architecture write-up, a multi-section summary someone will return to → **wiki** (`wiki_write`).
- If it's a sentence or two and only useful via search → memory.
- If it has headings, steps, or is meant to be opened and read top-to-bottom → wiki.
- When a wiki page captures something durable about the project, capture a short memory pointing to it. Memory is the index; the wiki is the library.

When genuinely unsure, prefer memory — it's cheaper, self-curating, and reversible. Promote to a wiki page when the content has grown structured enough to deserve one.

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
- Sensitive credentials, secrets, or anything that shouldn't persist (passwords, API keys, financial account numbers) — this applies to wiki pages too; never write secrets into a document.

When uncertain, lean toward capturing. The compactor drops single-source one-off signal and promotes recurring, cross-source signal. Over-capture is self-correcting; under-capture is not.

## Writing good captures

Captures should be terse, self-contained, and useful out of context. A future search may surface this memory in a totally different conversation — write it so it stands alone.

Good: `User runs an iPad-as-remote-interface workflow, SSH'ing from iPad into a Mac Studio (M1 Max, 32GB) as the primary dev machine.`

Less good: `iPad SSH workflow.` (Too terse — strips the context that makes it useful later.)

Less good: `The user mentioned earlier in our conversation today that they sometimes use their iPad to SSH into their Mac Studio for development.` (Padded with conversational framing that won't matter when retrieved.)

A capture is a note to a future agent. Write what that agent would need to know, nothing more.

## Writing good wiki pages

A wiki page is a document a human will open and read. Write accordingly:

- Lead with a one-line statement of what the page is and when to use it.
- Use headings and short sections. Favour steps, lists, and tables over walls of prose.
- Make it self-contained — a reader shouldn't need the conversation that produced it.
- Prefer a clear path: `AI/<area>/<topic>.md` (e.g. `AI/runbooks/db-restore.md`) so the folder structure stays navigable.
- Don't restate the AI-generated banner in the body; the UI adds it. Keep the content clean so it reads correctly if a human promotes the page.

## Conflicts and stale information

If a search returns contradictory memories, the newer or more specific one usually wins, but check the user when it matters. Don't silently pick a side on something consequential — "I have notes saying both X and Y about your setup; which is current?" is better than guessing wrong.

If you discover a memory is stale through the conversation (the user contradicts it, or the situation has clearly changed), use `memory_update` to correct it. Leaving stale memories in place pollutes future searches. For a stale wiki page you authored under the AI folder, update it with `wiki_write`.

## Anti-patterns

- **Narrating the calls.** "Let me search my memory for that…" — don't. The user knows. Just do it and respond.
- **Asking permission to capture.** Capture is the default behavior, not a request. Skip the meta-conversation.
- **Treating Elefant as backup-only.** If you only write to Elefant and never read from it, it isn't memory — it's a journal. Search first.
- **Capturing the conversation as transcript.** Captures are extracted signal, not verbatim history. Distill.
- **Ignoring the wiki.** When the user has synced repositories or documents, `wiki_search_only` may answer questions faster and more authoritatively than memory. Use the right surface.
- **Reaching for `memory_add` by default.** It bypasses the system that makes Elefant smart. Prefer `memory_capture` unless you have a specific reason.
- **Dumping long-form reference material into memory.** A multi-section runbook is a wiki page, not a memory. Use `wiki_write`.
- **Using `wiki_write` for ephemeral notes.** A one-line preference or "where I left off" is memory, not a document. Don't litter the wiki with fragments.
- **Trying to write outside the AI folder, or expecting to edit a promoted page.** The AI folder and the move-to-promote boundary are deliberate. Work within them.
- **Using memory to store or read operating settings.** Second-brain mode and the compactor thresholds are real configuration — read them with `get_user_settings`, change them with `set_user_settings`. A memory like "user wants second-brain mode" is the wrong tool, and `memory_search` is the wrong way to discover the current mode.
- **Answering "latest" with the top search hit.** Search ranks by relevance, not recency. Resolve newest by date, not rank.
- **Guessing who "our/we/my" refers to.** Resolve first-person references against stored identity; if there's no identity fact, ask and capture it rather than inferring from incidental context.
- **Feeding a displayed (tenant-prefixed) path into a file tool.** `get_wiki_page`/`wiki_write` want the path with the leading tenant segment stripped. Don't keep permuting a 404'ing `AI/` path — read it via `search` instead.

## Quick reference

| Situation | Action |
|---|---|
| User asks anything touching prior context | `search` first, then answer |
| Substantive turn ending with durable content | `memory_capture` before closing |
| User says "remember this exactly" | `memory_add` |
| User corrects something you said | `memory_update` if a stored memory is now wrong; capture the correction either way |
| New conversation, Elefant tools present | `get_user_settings` once to learn mode + config; `search` for any obviously relevant context |
| User wants the default mode or a compactor threshold changed | `set_user_settings` (explicit request only, approve-once) |
| Second-brain mode on, durable signal mid-turn | `memory_capture` immediately, keep responding |
| Search returns contradictions on something consequential | Ask the user |
| User wants a runbook / SOP / design doc / structured summary | `wiki_write` to a path under the AI folder (subfolders welcome) |
| Long-form content authored | `wiki_write` for the document; short `memory_capture` pointing to it |
| Reading a wiki page before rewriting it | `get_wiki_page` (strip the tenant prefix); for `AI/` pages, read via `search` if it 404s |
| User asks for the "latest / newest" of a series | Resolve by date (index page, newest-first, or a `Published:` field) — not the top search hit |
| User refers to "our / we / my &lt;thing&gt;" | Resolve against stored identity; if none found, ask, then capture |
| Search path 404s on `get_wiki_page` / `wiki_write` | Strip the leading tenant segment; writable root is `AI/` |
