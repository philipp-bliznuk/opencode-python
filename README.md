# opencode-python

Minimal, opinionated [OpenCode](https://opencode.ai) configuration for Python backend
development. Conservative by design — no custom tools to maintain, no npm build step,
no frontend scaffolding, no plugin proliferation. What remains is precise and
non-negotiable.

## Philosophy

Most AI coding setups accumulate features. This one removes them.

Fewer moving parts means fewer failure modes. No custom TypeScript tools, no shell-strategy
plugin. Installation is a symlink. That's it.

What stays is strict: a single authoritative ruleset (`AGENTS.md`) that defines exact
tools, patterns, and constraints across all projects. Agents enforce them unconditionally.
The goal is that AI assistance becomes useful for the hard parts — domain logic, architecture
decisions, debugging — not for figuring out which formatter to use.

**Non-negotiable choices:**

- **Toolchain**: `uv` for package management, `ruff` for linting and formatting, `bandit`
  for security, `pre-commit` for enforcement — no alternatives, no overrides
- **Code quality**: McCabe complexity ≤ 4, max 4 function arguments, strict typing with
  `X | None` over `Optional`, absolute imports only, Google docstrings — all enforced
  at the agent level before any code is written
- **Architecture**: FastAPI with `create_app()` factory, `Annotated[T, Depends()]`
  everywhere, `Controller(Generic[ModelType])` repository pattern, `model_factory()`
  for schema derivation, `selectin` loading on all relationships — agents know these
  patterns and apply them without being asked
- **Podman**: multi-stage Containerfiles, layer ordering as a caching discipline, non-root
  execution, uv-managed venv, `python:3.x-slim` only
- **Security**: bandit strict profile, `allow_skipping = false` (no `# nosec`),
  token hashing, least-privilege IAM, OWASP Top 10 awareness built into every review

**Where agents ask rather than assume:**

- Deployment target
- Authentication strategy and role model
- Database choice and schema design
- Testing scope and infrastructure

Everything else is handled by the standards.

## Stack

| Layer                     | Technology                                                     |
| ------------------------- | -------------------------------------------------------------- |
| **Language**              | Python 3.14                                                    |
| **Package manager**       | uv (workspaces, lockfiles, venv)                               |
| **Web framework**         | FastAPI + pydantic-settings                                    |
| **ORM / DB**              | SQLModel + asyncpg + PostgreSQL 17 _(default; agents ask)_     |
| **Migrations**            | Alembic (async, with `alembic-postgresql-enum`)                |
| **Auth**                  | JWT-based (provider-agnostic pattern)                          |
| **Testing**               | pytest + asyncio + xdist + pytest-socket (95% branch coverage) |
| **Linting**               | ruff (46 rule sets, preview mode, unsafe fixes)                |
| **Security**              | bandit (strict profile, zero suppressions)                     |
| **Container**             | Podman multi-stage, gunicorn + UvicornWorker                   |

## What's Inside

```
opencode-config/
├── AGENTS.md              # Global Python coding standards — loaded into every session
├── opencode.jsonc         # Runtime config: providers, formatters, watcher, plugins
├── dcp.jsonc              # Context pruning config (for @tarquinen/opencode-dcp)
├── tui.jsonc              # TUI settings: opencode theme, scroll acceleration
├── agents/                # 7 subagents
├── skills/                # 8 on-demand playbooks
└── install.sh
```

---

## Agents

All agents are subagents. Invoke via `@name` in any prompt, or agents chain to each
other automatically after completing work.

| Agent         | Model             | Purpose                                                                                                   |
| ------------- | ----------------- | --------------------------------------------------------------------------------------------------------- |
| `audit`       | claude-sonnet-4-6 | Full quality audit: complexity, coverage, mutation testing. Delegates findings to other agents.           |
| `code-review` | claude-sonnet-4-6 | Read-only review against `AGENTS.md`: Blocker / Suggestion / Nitpick tiers.                              |
| `db`          | claude-sonnet-4-6 | SQLModel models, Alembic migrations, query analysis. Catches N+1, unnamed constraints, unsafe migrations. |
| `debug`       | claude-sonnet-4-6 | Root cause diagnosis, structured handoff. Full read + bash access. Never edits files.                    |
| `refactor`    | claude-sonnet-4-6 | Reduces complexity, improves naming, enforces limits. Never changes behaviour.                            |
| `security`    | claude-sonnet-4-6 | OWASP Top 10, auth flaws, secrets exposure, bandit findings. Critical→Info severity tiers.                |
| `tests`       | claude-sonnet-4-6 | Generates pytest suites. Reads `conftest.py` before inventing fixtures. 95% coverage target.             |

### Automatic chaining

Agents chain without user prompts between steps:

| Trigger                                      | Chain                                                    |
| -------------------------------------------- | -------------------------------------------------------- |
| Feature or fix complete                      | `@code-review` → `@security` (if auth touched)          |
| Bug reported                                 | `@debug` → primary agent fixes → `@tests` → `@code-review` |
| New SQLModel model                           | `@db` → alembic-migration skill → `@tests`               |
| Audit requested                              | `@audit` → `@db` + `@refactor` + `@tests` + `@security` per findings |

---

## Skills

On-demand playbooks loaded by agents when the situation matches. Not always in context.

| Skill                 | Trigger                                                              |
| --------------------- | -------------------------------------------------------------------- |
| `alembic-migration`   | "add migration", "modify model", "schema change"                     |
| `cavecrew`            | "delegate to subagent", "save context", "use cavecrew", "spawn investigator/builder/reviewer" |
| `caveman`             | "caveman mode", "less tokens", "be brief", `/caveman`               |
| `caveman-compress`    | `/caveman:compress <filepath>`, "compress memory file"               |
| `docker-build-debug`  | "podman build failing", "container issue", "container not starting"  |
| `new-fastapi-project` | "new project", "bootstrap", "scaffold"                               |
| `performance-analysis`| "slow", "high memory", "profile", "optimise", "benchmark"           |
| `pr-checklist`        | "open PR", "ready to merge", "prepare PR"                            |

---

## Plugins

Two plugins load automatically at startup from the `plugin` array in `opencode.jsonc`.
No manual install required — OpenCode resolves them.

| Plugin                    | Source | Purpose                                                                                     |
| ------------------------- | ------ | ------------------------------------------------------------------------------------------- |
| `opencode-with-claude`    | npm    | Session hooks: injects caveman mode system prompt at startup and on session resume          |
| `@tarquinen/opencode-dcp` | npm    | Dynamic context pruning: deduplication, error purging, range compression. Config in `dcp.jsonc`. |

---

## MCP Servers

No MCP servers in the global config. Add per-project when needed.

### PostgreSQL (`crystaldba/postgres-mcp`)

Spawned on demand via `uvx` — no manual install or start/stop required. Create a
git-ignored `opencode.json` at the project root:

```json
{
  "mcp": {
    "postgres": {
      "type": "local",
      "command": ["uvx", "postgres-mcp", "--access-mode=unrestricted"],
      "environment": {
        "DATABASE_URI": "postgresql://postgres:postgres@localhost:5433/<dbname>"
      }
    }
  }
}
```

> **Note:** `type` and `command` are required by the OpenCode config schema. An
> `environment`-only entry fails validation with `Invalid input mcp.postgres`.

The `db` agent picks up `DATABASE_URI` automatically and can:

- Inspect schemas via `postgres_list_schemas` / `postgres_get_object_details`
- Execute SQL via `postgres_execute_sql`
- Run `EXPLAIN (ANALYZE, BUFFERS)` via `postgres_explain_query`
- Find slow queries via `postgres_get_top_queries`
- Get index recommendations via `postgres_analyze_workload_indexes` / `postgres_analyze_query_indexes`
- Run a full DB health check via `postgres_analyze_db_health`

Add `opencode.json` to `.gitignore` and `.containerignore` — it contains credentials.

When scaffolding a new FastAPI project with a DB, the `new-fastapi-project` skill
creates the `opencode.json` stub automatically and adds it to `.gitignore`
and `.containerignore`.

---

## Formatters

OpenCode formats every file it writes.

| Filetype                                      | Formatter            | Notes                                                                     |
| --------------------------------------------- | -------------------- | ------------------------------------------------------------------------- |
| `.py`, `.pyi`                                 | `ruff format`        | Single-step. Uses `--config pyproject.toml` when present.                 |
| `.lua`                                        | `stylua`             | 2-space indent, 120 column width.                                         |
| `.js`, `.jsx`, `.ts`, `.tsx`, `.css`, `.html` | `prettier` (via npx) | Biome auto-overrides per-project when `biome.json` is present.            |
| `.json`, `.jsonc`, `.yaml`, `.yml`            | `prettier` (via npx) | Biome auto-overrides per-project when `biome.json` is present.            |
| `.sh`, `.bash`                                | `shfmt`              | Standard shell formatting.                                                |

---

## Prerequisites

| Tool                                                           | Required for                         | Install                         |
| -------------------------------------------------------------- | ------------------------------------ | ------------------------------- |
| [opencode](https://opencode.ai)                                | Everything                           | `brew install sst/tap/opencode` |
| [uv](https://docs.astral.sh/uv/)                               | Python projects                      | `brew install uv`               |
| [ruff](https://docs.astral.sh/ruff/)                           | Python formatter                     | `brew install ruff`             |
| [node](https://nodejs.org)                                     | npm plugins, prettier                | `brew install node`             |
| [podman](https://podman.io)                                    | Container runtime                    | `brew install podman`           |
| [podman-compose](https://github.com/containers/podman-compose) | Compose support                      | `brew install podman-compose`   |
| [shfmt](https://github.com/mvdan/sh)                           | Shell formatter                      | `brew install shfmt`            |
| [stylua](https://github.com/JohnnyMorganz/StyLua)              | Lua formatter _(optional)_           | `brew install stylua`           |
| [trivy](https://trivy.dev)                                     | Container CVE scanning _(optional)_  | `brew install trivy`            |

---

## Installation

```bash
git clone https://github.com/philipp-bliznuk/opencode-python.git ~/projects/opencode
cd ~/projects/opencode
./install.sh
```

The script will:

1. Check for all prerequisites and offer to install missing ones via Homebrew
2. Back up any existing `~/.config/opencode/` directory
3. Create a symlink: `~/.config/opencode` → this repo

npm plugins (`opencode-with-claude`, `@tarquinen/opencode-dcp`) load automatically
at OpenCode startup — no separate install step required.

Because the config directory is a symlink to the repo, any `git pull` takes effect
immediately — no re-running the install script. Live OpenCode sessions cache the
config; restart OpenCode after `git pull` to pick up `AGENTS.md`, agent, or skill
changes.

---

## Updating

```bash
cd ~/projects/opencode
git pull
```

---

## Optional Features

### Web search (Exa AI)

No API key required. Pass an environment variable when launching:

```bash
OPENCODE_ENABLE_EXA=1 opencode
```

### Experimental LSP tool

Gives agents access to go-to-definition, find-references, and call hierarchy via LSP:

```bash
OPENCODE_EXPERIMENTAL_LSP_TOOL=true opencode
```

### Editor integration (`/editor` and `/export`)

The `/editor` command and `/export` use the `$EDITOR` environment variable:

```bash
export EDITOR=nvim   # or vim, code --wait, etc.
```

### PostgreSQL MCP (live DB introspection)

No global config entry — add per-project. See the
[PostgreSQL setup](#postgresql-crystaldbapostgres-mcp) section above.

---

## Adapting to a New Project

`AGENTS.md` is a **global** instruction — it applies to every project opened in OpenCode.
For project-specific overrides, add an `opencode.json` at the project root. Config files
are merged, not replaced.

Pin a different model:

```json
{ "model": "openai/o3" }
```

Add project-specific instructions:

```json
{ "instructions": ["./CLAUDE.md"] }
```

Set the PostgreSQL connection string (git-ignored):

```json
{
  "mcp": {
    "postgres": {
      "environment": {
        "DATABASE_URI": "postgresql://postgres:postgres@localhost:5433/myproject"
      }
    }
  }
}
```

Add `opencode.json` to `.gitignore` and `.containerignore` — it contains credentials.
