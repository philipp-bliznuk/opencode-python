---
description: Distil this session's decisions and project state into CLAUDE.md so the next session starts fully informed.
agent: plan
---

Distil everything decided and learned in this session into the project's `CLAUDE.md` file.

## What to write

Read the current `CLAUDE.md` if it exists. Then update it — or create it — with the following structure, merging new information with anything already there. Never delete existing decisions unless they were explicitly reversed in this session.

```markdown
# Project Context

## What this project is
One paragraph: purpose, stack, deployment target. Written for an agent picking this up cold.

## Current state
- What has been implemented and is working
- What is currently in progress
- What is explicitly planned next

## Key decisions
Architectural and technical choices that have been made and should not be re-litigated:
- <decision> — <brief rationale>
- ...

## Constraints and rules
Things that are fixed for this project (auth approach, DB schema choices, naming conventions that deviate from defaults, etc.):
- ...

## Open questions
Things still to be decided. Remove items once they are resolved.
- ...

## Ruled out
Approaches that were considered and rejected, so future sessions don't re-suggest them:
- <approach> — <reason rejected>
```

## Rules for writing CLAUDE.md

- Be terse. Each bullet should be one line. An agent should be able to read the whole file in under 30 seconds.
- Decisions go under "Key decisions", not repeated elsewhere.
- Do not include code snippets — the code is in the repo.
- Do not summarise conversation history — only record outcomes and decisions.
- Do not invent decisions that were not made in this session.
- If a previous decision was reversed, update it in place with a note, don't delete it.
- Write for an agent that has read `AGENTS.md` and understands the standard stack — only record what *deviates* from or *extends* the defaults.

After writing the file, confirm what was added or changed with a brief summary.
