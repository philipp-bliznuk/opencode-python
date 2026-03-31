# opencode-python

A highly opinionated [OpenCode](https://opencode.ai) configuration for Python backend
development. This is not a general-purpose AI assistant setup — it is a precise,
curated environment built around a specific stack, specific patterns, and non-negotiable
quality standards.

## Philosophy

Most AI coding setups trade precision for generality. This one does the opposite.

Every agent in this configuration operates within a single authoritative ruleset
(`AGENTS.md`) that defines the exact tools, patterns, and constraints used across all
projects. There is no "let the AI decide" for tooling choices, code style, project
structure, or architectural patterns — those decisions have already been made, documented,
and encoded. Agents enforce them unconditionally.

The result is that AI assistance becomes genuinely useful for the hard parts — domain
logic, architecture decisions, debugging — rather than wasting conversation on
"which formatter should I use?" or "how should I structure this FastAPI router?"

**This configuration is opinionated about:**
- **Toolchain**: `uv` for package management, `ruff` for linting and formatting (with a
  custom three-step pipeline), `bandit` for security, `pre-commit` for enforcement — no
  alternatives, no overrides
- **Code quality**: McCabe complexity ≤ 4, max 4 function arguments, strict typing with
  `X | None` over `Optional`, absolute imports only, Google docstrings — all enforced
  at the agent level before any code is written
- **Architecture**: FastAPI with `create_app()` factory, `Annotated[T, Depends()]`
  everywhere, `Controller(Generic[ModelType])` repository pattern, `model_factory()`
  for schema derivation, `selectin` loading on all relationships — agents know these
  patterns and apply them without being asked
- **Docker**: multi-stage builds, layer ordering as a caching discipline, non-root
  execution, uv-managed venv, `python:3.x-slim` only
- **Performance**: async-first with explicit rules against blocking I/O, N+1
  awareness, algorithmic complexity consciousness — as a passive quality signal,
  never a blocker
- **Security**: bandit strict profile, `allow_skipping = false` (no `# nosec`),
  token hashing, least-privilege IAM, OWASP Top 10 awareness built into every review

**Where agents ask rather than assume:**
- Deployment target (FastAPI / Lambda / full-stack)
- Authentication strategy and role model
- Database choice and schema design
- Testing scope and infrastructure

Everything else is handled by the standards, and the goal is to keep it that way.

## Stack

This configuration is built around a specific primary stack and knows it deeply:

| Layer | Technology |
|---|---|
| **Language** | Python 3.14 |
| **Package manager** | uv (workspaces, lockfiles, venv) |
| **Web framework** | FastAPI + pydantic-settings |
| **ORM / DB** | SQLModel + asyncpg + PostgreSQL 17 |
| **Migrations** | Alembic (async, with `alembic-postgresql-enum`) |
| **Auth** | JWT-based (provider-agnostic pattern) |
| **Testing** | pytest + asyncio + xdist + pytest-socket (95% branch coverage) |
| **Linting** | ruff (46 rule sets, preview mode, unsafe fixes) |
| **Security** | bandit (strict profile, zero suppressions) |
| **Container** | Docker multi-stage, gunicorn + UvicornWorker |
| **Serverless** | AWS SAM + python-uv build method |
| **Frontend** (occasional) | bun + Vite + Biome + TypeScript strict |
| **CI/CD** | GitHub Actions + OIDC + composite setup action |

Secondary patterns that are also well-understood: AWS Lambda, SAM templates, OIDC
deployments, and bun-first full-stack apps where FastAPI serves the built frontend.

## What's Inside

```
opencode-config/
├── AGENTS.md              # Global Python coding standards — loaded into every session
├── opencode.jsonc         # Runtime config: LSP, MCP servers, formatters, plugins, watcher
├── tui.jsonc              # TUI settings: catppuccin-mocha theme, scroll acceleration
├── agents/                # 13 specialised agents (6 primary, 7 subagents)
├── skills/                # 7 on-demand procedural playbooks
├── tools/                 # 3 custom TypeScript tools
├── plugins/
│   └── shell-strategy/    # Non-interactive shell instructions (uv + bun aware)
└── scripts/
    └── ruff-format.sh     # Three-step Python formatter pipeline
```

---

## Agents

### Primary Agents

Switch between primary agents with `Tab` in the TUI.

| Agent | Model | Color | Purpose |
|---|---|---|---|
| `build` | claude-sonnet-4-5 | Green | Full implementation. Enforces `AGENTS.md` on every write. Proactively invokes subagents after completing work. |
| `plan` | claude-haiku-4-5 | Blue | Read-only analysis. Produces structured plans with file paths and compliance notes. Never writes code. |
| `refactor` | claude-sonnet-4-5 | Amber | Reduces complexity, improves naming, enforces limits. Never changes behaviour. Show-before-apply workflow. |
| `git` | claude-haiku-4-5 | Red | Git specialist. Conventional commits, branch management, PR descriptions. All git commands require approval. |
| `debug` | claude-sonnet-4-5 | Deep orange | Diagnoses bugs and traces failure chains. Full read + bash access for diagnostics. Never edits files. |
| `frontend` | claude-sonnet-4-5 | Cyan | Bun-first frontend specialist. Asks about framework/stack upfront. Knows the `backend/`+`frontend/` split, Vite proxy, and multi-stage Docker build. |

### Subagents

Invoke subagents via `@name` in a prompt, or they are triggered automatically by primary agents.

| Agent | Model | Purpose |
|---|---|---|
| `code-review` | claude-sonnet-4-5 | Reviews against `AGENTS.md`: Blocker / Suggestion / Nitpick tiers. |
| `security` | claude-sonnet-4-5 | OWASP Top 10, auth flaws, secrets exposure, bandit findings. Critical→Info severity tiers. |
| `tests` | claude-sonnet-4-5 | Generates pytest suites. Reads `conftest.py` before inventing fixtures. 95% coverage target. |
| `docs` | claude-haiku-4-5 | Google-style docstrings, README sections, `CLAUDE.md` files. |
| `db` | claude-sonnet-4-5 | SQLModel models, Alembic migrations, query analysis. Catches N+1, unnamed constraints, unsafe migrations. |
| `ci` | claude-haiku-4-5 | GitHub Actions, Dockerfiles, docker-compose, SAM templates, Makefiles. |
| `research` | claude-haiku-4-5 | Fetches and synthesises external docs, RFCs, PEPs, library changelogs. Never writes to project files. |

### Automatic subagent invocations (by `build`)

| Situation | Subagent called |
|---|---|
| After completing a feature or fix | `@code-review` |
| Touching auth, tokens, or cryptography | `@security` |
| New module or function without test coverage | `@tests` |
| Creating or modifying a SQLModel model | `@db` |

---

## Skills

Skills are on-demand playbooks loaded by agents when the situation matches. They are not always in context — agents load them only when needed.

| Skill | Loaded by | Trigger |
|---|---|---|
| `new-fastapi-project` | `build` | "new project", "bootstrap", "scaffold" |
| `new-lambda-project` | `build`, `ci` | "new Lambda", "new SAM", "serverless" |
| `alembic-migration` | `build`, `db` | "add migration", "modify model", "schema change" |
| `pr-checklist` | `git`, `code-review` | "open PR", "ready to merge", "prepare PR" |
| `docker-build-debug` | `debug`, `ci` | "docker build failing", "container issue" |
| `new-frontend-feature` | `build`, `frontend` | "add frontend", "add UI", "React/Vue/Svelte component" |
| `performance-analysis` | `build`, `debug` | "slow", "high memory", "profile", "optimise", "benchmark" |

---

## Plugins

Three npm plugins are loaded automatically by OpenCode at startup (no manual install needed —
OpenCode resolves them from the `plugin` array in `opencode.jsonc`). One instruction-based
plugin ships as a local file.

| Plugin | Source | Purpose |
|---|---|---|
| `@tarquinen/opencode-dcp` | npm | Prunes stale tool outputs from context; extends session life on long tasks |
| `opencode-handoff` | npm | Creates focused handoff prompts for continuing work in a new session |
| `shell-strategy` | local instructions | Teaches agents to use non-interactive shell flags in all contexts. uv-aware (Python), bun-aware (frontend), no bare `python` or `pip`. |

---

## MCP Servers

All servers run as **local processes** — no external service calls.

| Server | Runs via | Scoped to | Purpose |
|---|---|---|---|
| `sequential-thinking` | `npx` | `plan`, `refactor`, `debug`, `frontend` | Structured step-by-step reasoning scaffold |
| `aws-documentation` | `uvx` | `research`, `ci`, `debug` | Official AWS docs search and fetch |
| `aws-serverless` | `uvx` | `ci` | SAM CLI: build, validate, deploy, logs |
| `postgres` | `uvx pg-mcp-server` (SSE) | `db` | Live DB introspection: `pg_query`, `pg_explain`, schema discovery, table stats |

Servers are **disabled globally** and re-enabled only on the agents that need them, avoiding context bloat everywhere else.

### PostgreSQL MCP (`pg-mcp-server`)

Unlike the other MCP servers which start on demand as child processes,
`pg-mcp-server` runs as a **persistent SSE server** and must be started
before invoking the `db` agent for live analysis.

```bash
# Start (requires your docker-compose DB to be running)
make pg_mcp_start        # in projects that have this Makefile target

# Or start manually:
PG_MCP_DATABASE_URL=postgresql://postgres:postgres@localhost:5433/<dbname> \
  uvx stuzero/pg-mcp-server

# Stop
make pg_mcp_stop
# or: pkill -f pg-mcp-server
```

The server listens at `http://localhost:8000/sse` by default and runs
**read-only** — it cannot modify your database. Safe to leave running
for an entire development session.

Once running, the `db` agent connects automatically and can:
- Execute any read-only SQL via `pg_query`
- Run `EXPLAIN (ANALYZE, BUFFERS)` via `pg_explain`
- Inspect schemas, tables, columns, and indexes
- Query `pg_stat_statements` to find slow queries
- Query `pg_stat_user_tables` to detect table bloat

**Adding Makefile targets to a project:** when scaffolding a new FastAPI project
with a DB, the `new-fastapi-project` skill and the `build` agent will both add
`pg_mcp_start` / `pg_mcp_stop` targets automatically.

---

## Custom Tools

Three TypeScript tools (require [Bun](https://bun.sh)) that provide structured output rather than raw terminal text.

| Tool | Invocation | Purpose |
|---|---|---|
| `uv_run` | `{ command: string[] }` | Runs any command through `uv run --` in the project venv. Ensures the correct Python is always used. |
| `ruff_check` | `{ paths: string[], fix?: bool }` | Runs `ruff check --output-format json`. Returns structured violations array rather than colourised terminal output. |
| `pytest_collect` | `{ path?: string, filter?: string }` | Collects test node IDs without running them. Surfaces import errors and missing tests before executing the suite. |

---

## Formatters

OpenCode formats every file it writes. The formatter config mirrors the Neovim `conform.nvim` setup exactly so agent-written files and editor-saved files come out identical.

| Filetype | Formatter | Notes |
|---|---|---|
| `.py`, `.pyi` | `ruff-format.sh` | Three-step pipeline: `ruff check --fix` → `ruff format` → `ruff check --select I --fix`. Uses `--config pyproject.toml` when present. |
| `.md`, `.mdx` | `prettier` (via npx) | `--prose-wrap preserve` — does not reflow manually-wrapped paragraphs. |
| `.js`, `.jsx`, `.ts`, `.tsx`, `.css`, `.html` | `prettier` (via npx) | Fallback for frontend files. Biome auto-overrides per-project when `biome.json` is present. |
| `.json`, `.jsonc`, `.yaml`, `.yml` | `prettier` (via npx) | Single formatter for all config and data files. Biome auto-overrides per-project when `biome.json` is present. |
| `.sh`, `.bash` | `shfmt` | Standard shell script formatting. |

---

## Prerequisites

| Tool | Required for | Install |
|---|---|---|
| [opencode](https://opencode.ai) | Everything | `brew install sst/tap/opencode` |
| [uv](https://docs.astral.sh/uv/) | Python projects | `brew install uv` |
| [ruff](https://docs.astral.sh/ruff/) | Python formatter | `brew install ruff` |
| [node](https://nodejs.org) | MCP servers, npm plugins, prettier | `brew install node` |
| [bun](https://bun.sh) | Custom TS tools, frontend runtime | `brew install bun` |
| [shfmt](https://github.com/mvdan/sh) | Shell formatter | `brew install shfmt` |
| [trivy](https://trivy.dev) | Docker image CVE scanning *(optional)* | `brew install trivy` |
| [aws-sam-cli](https://aws.amazon.com/serverless/sam/) | `aws-serverless` MCP *(optional)* | `brew install aws-sam-cli` |

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
4. Make `scripts/ruff-format.sh` executable
5. Verify the shell-strategy instructions file is present

npm plugins (`@tarquinen/opencode-dcp`, `opencode-handoff`) are loaded
automatically by OpenCode at startup — no separate install step is required.

Because the config directory is a symlink to the repo, any `git pull` takes effect immediately — no re-running the install script.

---

## Updating

```bash
cd ~/projects/opencode
git pull
```

That's it. The symlink means there is no copy step.

---

## Optional Features

### Web search (Exa AI)

No API key required. Pass an environment variable when launching:

```bash
OPENCODE_ENABLE_EXA=1 opencode
```

### Experimental LSP tool

Gives agents access to go-to-definition, find-references, and call hierarchy via the LSP:

```bash
OPENCODE_EXPERIMENTAL_LSP_TOOL=true opencode
```

### Editor integration (`/editor` and `/export`)

The `/editor` command (compose a long prompt in your editor) and `/export` (export session to Markdown) use the `$EDITOR` environment variable. Add this to your shell profile:

```bash
export EDITOR=nvim   # or vim, code --wait, etc.
```

### PostgreSQL MCP (live DB introspection)

The `postgres` MCP is already configured and active in `opencode.jsonc`. It uses
`pg-mcp-server` (SSE) and is scoped to the `db` agent. See the
[PostgreSQL MCP setup](#postgresql-mcp-pg-mcp-server) section under MCP Servers
for start/stop instructions and usage.

---

## Adapting to a New Project

`AGENTS.md` is a **global** instruction — it applies to every project opened in OpenCode. For project-specific overrides, add an `opencode.json` at the project root. Config files are merged, not replaced, so project-level settings stack on top of the global ones without losing anything.

Example: pin a different model for a specific project:

```json
// ~/your-project/opencode.json
{
  "model": "openai/o3"
}
```

Example: add project-specific instructions:

```json
{
  "instructions": ["./CLAUDE.md"]
}
```
