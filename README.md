# opencode-python

Minimal [OpenCode](https://opencode.ai) V2 config for Python/FastAPI backend work. One ruleset (`AGENTS.md`), four read-mostly subagents, five on-demand skills, one plugin. Nothing else.

```
AGENTS.md        global standards — caveman mode, dir boundary, Python/FastAPI/SQLModel rules
opencode.jsonc   providers, permissions, websearch, formatters, plugins
cli.json         TUI: theme, scroll, diffs
agents/          review · debug · tests · db
skills/          alembic-migration · docker-build-debug · new-fastapi-project · performance-analysis · pr-checklist
install.sh       verify repo location, report missing tools
```

## Install

```bash
git clone https://github.com/philipp-bliznuk/opencode-python.git ~/.config/opencode
~/.config/opencode/install.sh
```

Repo must be the real `~/.config/opencode` dir, not a symlink — OpenCode V2 uses inotify to hot-reload `AGENTS.md`, agents, skills, and inotify cannot watch through symlinks. Optional shortcut: `ln -s ~/.config/opencode ~/projects/opencode`.

Then in OpenCode: `/connect` → **Tavily** (free 1k searches/mo) for `websearch`. Provider secrets go in `.secrets/` (gitignored): `aws-profile`, `aws-region`, `anthropic-base-url`, `anthropic-api-key`.

## Agents

| Agent | Edits | Purpose |
|---|---|---|
| `@review` | no | Code + security review against `AGENTS.md`. Blocker/Suggestion/Nitpick + OWASP severity. |
| `@debug` | no | Root cause. Reproduce → trace → isolate → structured handoff. |
| `@tests` | `tests/` | pytest suites from existing fixtures. 95% coverage target. |
| `@db` | no | SQLModel/Alembic/query review; live PostgreSQL via `postgres` MCP. |

Chains run without prompting: feature → `@review` → `pr-checklist` · bug → `@debug` → fix → `@tests` → `@review` · new model → `@db` → `alembic-migration` → `@tests`.

## Plugins

`opencode-with-claude` — runs Meridian proxy so the `anthropic` provider uses a Claude Max subscription. Context overflow handled by native V2 compaction (`compaction.keep.tokens: 30000`).

## PostgreSQL MCP (per project)

```bash
opencode mcp add postgres --env DATABASE_URI=postgresql://user:pass@localhost:5433/db -- uvx postgres-mcp --access-mode=unrestricted
```

Writes to project `opencode.json` — add it to `.gitignore` + `.containerignore`.

## Formatters

Built-ins auto-detected: `ruff` (needs ruff config in project), `shfmt`, `prettier`/`biome` (needs dep in `package.json`). Custom: `stylua`.

## Prereqs

`opencode` · `uv` · `ruff` · `podman` · `podman-compose` · `shfmt` · optional `stylua`, `trivy`. `install.sh` lists what is missing.
