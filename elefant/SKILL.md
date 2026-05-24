---
name: elefant
description: "Use whenever Elefant MCP tools are available in the session. Elefant is the user's persistent second-brain memory platform — a first-class memory layer that travels across conversations, devices, and agents. This skill defines how to use it well — when to search before answering, when and how to capture, which tool to reach for, and how to operate in second-brain mode when enabled. Apply this skill aggressively whenever Elefant tools are present, even if the user hasn't explicitly invoked it — Elefant is meant to be the default memory backbone, not a sidecar that waits to be asked."
---

# Elefant

Elefant is a persistent memory and knowledge platform. It is the user's second brain. Treat it as a first-class layer of the system you are operating in, not an optional tool.

The conversation buffer is working memory and disappears. Elefant is durable memory and persists across conversations, devices, and agents. Anything that should survive belongs in Elefant.

## Core philosophy

A second brain only works if you use it like one. That means two reflexes:

**Search before you answer.** Anything that touches the user's prior context, preferences, decisions, ongoing projects, or shared vocabulary deserves a search first. Answering from the conversation window alone — when relevant memory exists — produces shallow, repetitive, context-blind responses. The user has invested in this memory platform precisely so you don't have to start cold every time.

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

1. **Per-conversation.** The user says "second-brain mode on" or "second-brain mode off" (variants: "stretch its legs," "full second brain," "go conservative," "default mode"). Switch behavior for the rest of the conversation. Confirm the switch briefly, once, then operate silently.

2. **Persistent.** The user can store their preferred default in Elefant itself — a memory like "User wants second-brain mode enabled by default." Early in a new conversation, when Elefant tools are present, do a quick `memory_search` for mode preference (query like "second-brain mode preference"). If found, adopt it. If not found, default mode applies.

If the user changes mode persistently ("always run in second-brain mode from now on"), capture that preference so future conversations pick it up.

## Tool selection

Elefant exposes many tools. Most are self-explanatory from their descriptions. Two clusters deserve a point of view.

### Choosing a search tool

- **`search`** — unified search across both memories and wiki documents. Default choice when you're not sure what kind of content you need, or when the user's question could be answered by either personal memory or knowledge base content.
- **`memory_search`** — memories only. Use when you specifically want the user's stored facts, preferences, decisions, or session context, and want to exclude knowledge base noise.
- **`wiki_search_only`** — wiki documents only. Use when the user is asking about reference material, documentation, or shared knowledge, and personal memory would be a distraction.

When in doubt, start with `search`. Narrow to `memory_search` or `wiki_search_only` if results are diluted.

### Choosing a capture tool

- **`memory_capture`** — the default. Cheap, streams into the hot tier, gets clustered and promoted by the backend. Use this for nearly everything: preferences, decisions, project facts, where you left off, observations about the user's setup. Bloat is cheap because the compactor handles dedup and surfaces durable signal automatically.
- **`memory_add`** — bypasses the hot tier and writes directly to durable. Use only when (a) the user explicitly says "remember this exactly" or similar, or (b) you are certain a single, well-formed durable record is the right outcome right now (e.g., a critical preference that should never be lost to compaction). Default to `memory_capture`; reach for `memory_add` deliberately.
- **`memory_update`** — when you know an existing memory is now wrong or stale and the correction matters. Most stale information can be left for the compactor to handle as fresher captures accumulate. Use `memory_update` for explicit corrections ("actually I work at Y now, not X") or when leaving the old version in place would cause confusion.

### Other tools

`memory_delete`, `memory_list`, `memory_events`, `get_wiki_page`, `list_sources`, `source_tree`, `wiki_reindex`, `reindex_status` — use as their descriptions indicate. These are mostly inspection and administration; they don't need special guidance.

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

- **Narrating the calls.** "Let me search my memory for that…" — don't. The user knows. Just do it and respond.
- **Asking permission to capture.** Capture is the default behavior, not a request. Skip the meta-conversation.
- **Treating Elefant as backup-only.** If you only write to Elefant and never read from it, it isn't memory — it's a journal. Search first.
- **Capturing the conversation as transcript.** Captures are extracted signal, not verbatim history. Distill.
- **Ignoring the wiki.** When the user has synced repositories or documents, `wiki_search_only` may answer questions faster and more authoritatively than memory. Use the right surface.
- **Reaching for `memory_add` by default.** It bypasses the system that makes Elefant smart. Prefer `memory_capture` unless you have a specific reason.

## Quick reference

| Situation | Action |
|---|---|
| User asks anything touching prior context | `search` first, then answer |
| Substantive turn ending with durable content | `memory_capture` before closing |
| User says "remember this exactly" | `memory_add` |
| User corrects something you said | `memory_update` if a stored memory is now wrong; capture the correction either way |
| New conversation, Elefant tools present | Quick `memory_search` for mode preference and any obviously relevant context |
| Second-brain mode on, durable signal mid-turn | `memory_capture` immediately, keep responding |
| Search returns contradictions on something consequential | Ask the user |
