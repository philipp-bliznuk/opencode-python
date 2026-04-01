---
description: Read this project's CLAUDE.md and confirm what you know about its current state, decisions, and constraints before starting work.
agent: plan
---

Read the project's `CLAUDE.md` file and confirm your understanding of the project state before starting work.

If `CLAUDE.md` exists, read it and respond with a structured summary:

1. **What the project is** — one sentence
2. **Current state** — what's done, what's in progress, what's next
3. **Active decisions** — the key technical and architectural choices in force
4. **Constraints** — anything that deviates from the standard stack defaults
5. **Open questions** — what still needs to be decided

If anything is ambiguous or seems outdated (e.g. references something already done), flag it.

If `CLAUDE.md` does not exist, say so clearly and suggest running `/save-context` after the first planning session to create it.

Do not start implementing anything — this command is for orientation only.
