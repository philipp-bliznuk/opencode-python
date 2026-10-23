# opencode-python

Minimal [OpenCode](https://opencode.ai) V2 config for Python/FastAPI backend work. One ruleset (`AGENTS.md`), four read-mostly subagents, five on-demand skills, two commands. Nothing else.

```
AGENTS.md        global standards - caveman mode, no em dash, dir boundary, verification, critic loop, Python/FastAPI/SQLModel rules
opencode.jsonc   provider, policies, permissions, websearch, formatters, compaction
cli.json         TUI: theme, scroll, diffs, notifications, turn tokens
agents/          review · debug · tests · critic
commands/        /review - diff → @review in background · /critic - claim → @critic in background
skills/          alembic-migration · docker-build-debug · new-fastapi-project · performance-analysis · pr-checklist
```

## Install

```bash
git clone https://github.com/philipp-bliznuk/opencode-python.git ~/.config/opencode
```

Repo must be the real `~/.config/opencode` dir - file watching for hot-reload of `AGENTS.md`, agents, skills does not follow symlinks on Linux. Convenience symlink elsewhere is fine: `ln -s ~/.config/opencode ~/projects/opencode`.

Then in OpenCode: `/connect` → **Tavily** (free 1k searches/mo) for `websearch`. Bedrock uses AWS profile `by-sales` / `us-east-1` set inline in `opencode.jsonc`; edit to taste. `service.json` (gitignored) is created by the OpenCode service.

## Guardrails

`experimental.policies` in `opencode.jsonc` - hard rules no project config or "Allow always" can lift:

- Only `amazon-bedrock` provider usable.
- `.env` / `.env.*` never read or edited; `.env.example` allowed.

Plus `git commit` and `git push` always ask (primary agents).

## Agents

All subagents: full shell, never prompt. Denied for all: `git commit`, `git push`. Edit scope is the only per-agent difference.

| Agent | Edits | Purpose |
|---|---|---|
| `@review` | no | Code + security + data-layer review against `AGENTS.md`. Blocker/Suggestion/Nitpick, OWASP severity, evidence section. |
| `@debug` | no | Root cause. Reproduce → trace → isolate → structured handoff. |
| `@tests` | `tests/` | pytest suites from existing fixtures. 95% coverage target. |
| `@critic` | no | Adversarial skeptic. Steelman → evidence-backed flaws FATAL/MATERIAL/MINOR → verdict HOLDS / HOLDS WITH CONDITIONS / FLAWED / INSUFFICIENT EVIDENCE. Caller rebuts in same session with new evidence; stalemate escalates to user. No nested subagents. |

Chains run without prompting: feature → `@review` → `pr-checklist` · bug → `@debug` → fix → `@tests` → `@review` · new model → `alembic-migration` → `@tests` · uncertain / conflicting evidence / irreversible → `@critic` ⇄ caller.

`/review` runs `@review` on the working-tree diff as a background child session. `/critic <claim>` runs `@critic` on the claim with working-tree status as context.

## Compaction

Native V2 compaction only, no plugins. Ceiling = model window - `compaction.buffer`; `buffer: 800000` triggers at ~200K on the 1M Claude models, keeping `keep.tokens: 30000` of recent turns verbatim beside the summary. Not clamped: on a 200K-window model it compacts every turn, so stay on 1M models. Force manually: `opencode api post /api/session/<id>/compact --data '{}'`.

## Formatters

Built-ins auto-detected: `ruff` (needs ruff config in project), `shfmt`, `prettier`/`biome` (needs dep in `package.json`). Custom: `stylua`.

## Prereqs

`opencode` · `uv` · `ruff` · `just` · `podman` · `podman-compose` · `shfmt` · optional `stylua`, `trivy`.
