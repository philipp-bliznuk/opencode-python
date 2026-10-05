# opencode-python

Minimal [OpenCode](https://opencode.ai) V2 config for Python/FastAPI backend work. One ruleset (`AGENTS.md`), four read-mostly subagents, five on-demand skills, two commands, one plugin. Nothing else.

```
AGENTS.md        global standards - caveman mode, no em dash, dir boundary, verification, critic loop, Python/FastAPI/SQLModel rules
opencode.jsonc   provider, policies, permissions, websearch, formatters, compaction, plugins
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

Plus `git push` always asks.

## Agents

| Agent | Edits | Shell | Purpose |
|---|---|---|---|
| `@review` | no | `uv run -- ruff/pytest/bandit` | Code + security + data-layer review against `AGENTS.md`. Blocker/Suggestion/Nitpick, OWASP severity, evidence section. |
| `@debug` | no | all but commit/push/alembic up/down | Root cause. Reproduce → trace → isolate → structured handoff. |
| `@tests` | `tests/` | `uv run *` | pytest suites from existing fixtures. 95% coverage target. |
| `@critic` | no | read-only git, `uv run -- pytest/ruff/bandit`, `uv tree`; rest asks | Adversarial skeptic. Steelman → evidence-backed flaws FATAL/MATERIAL/MINOR → verdict HOLDS / HOLDS WITH CONDITIONS / FLAWED / INSUFFICIENT EVIDENCE. Caller rebuts in same session, 3-round cap, then escalate to user. |

Chains run without prompting: feature → `@review` → `pr-checklist` · bug → `@debug` → fix → `@tests` → `@review` · new model → `alembic-migration` → `@tests` · uncertain / conflicting evidence / irreversible → `@critic` ⇄ caller (≤3 rounds).

`/review` runs `@review` on the working-tree diff as a background child session. `/critic <claim>` runs `@critic` on the claim with working-tree status as context.

## Plugins

`@tarquinen/opencode-dcp` - context pruning: dedups repeated tool output, purges errored calls, exposes `compress` tool to the model. `/dcp` shows stats. Native compaction remains fallback (`compaction.keep.tokens: 30000`, `buffer: 20000`).

## Formatters

Built-ins auto-detected: `ruff` (needs ruff config in project), `shfmt`, `prettier`/`biome` (needs dep in `package.json`). Custom: `stylua`.

## Prereqs

`opencode` · `uv` · `ruff` · `podman` · `podman-compose` · `shfmt` · optional `stylua`, `trivy`.
