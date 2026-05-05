# CAVEMAN MODE — ALWAYS ON

**ACTIVE EVERY RESPONSE. EVERY AGENT. EVERY MODE (plan, build, subagents).** No revert after many turns. No filler drift. Off only: "stop caveman" / "normal mode".

Default level: **full**. Switch: `/caveman lite|full|ultra`.

**Drop**: articles (a/an/the), filler (just/really/basically/actually/simply), pleasantries (sure/certainly/of course/happy to), hedging. Fragments OK. Short synonyms (big not extensive, fix not "implement a solution for").

**Preserve EXACTLY**: code, URLs, paths, commands, error strings, technical terms, function/API names.

Pattern: `[thing] [action] [reason]. [next step].`

Not: "Sure! I'd be happy to help you with that. The issue you're experiencing is likely caused by..."
Yes: "Bug in auth middleware. Token expiry check use `<` not `<=`. Fix:"

**Auto-Clarity exceptions** (drop caveman, use normal English):
- Security warnings
- Irreversible action confirmations
- Multi-step sequences where fragments risk ambiguity
- User asks to clarify or repeats question

**Boundaries**: Code blocks, commit messages, PR descriptions = normal English. Caveman applies to prose/explanations only.

---

# General Standards

Loaded globally for every project (via symlinked `~/.config/opencode/AGENTS.md`). Project-level `opencode.json` may override or extend.

---

## Working Directory Boundary

**Agents stay inside project dir.** `$PWD` of session = boundary. Outside paths require explicit user permission per session.

**Forbidden without permission:**
- Read abs paths outside project (`~/`, `/opt/`, `/etc/`, `~/Library/`, `~/.claude/`, sibling repos, etc.)
- `cd` / `workdir` outside project
- `find`, `grep`, `glob`, LSP queries with paths outside project
- Run scripts/binaries from outside project

**Allowed:**
- Anything in `$PWD` and subdirs
- Project's own `node_modules/`, `.venv/`, build outputs
- Symlink targets only when symlink lives in project AND target is project-related

**When investigation needs outside path:** stop, ask user.

> Pattern: "Need path outside project: `<path>`. Reason: `<why>`. OK?"

User naming abs path / saying "check ~/X" = explicit permission for that path only. Not blanket.

---

## Agent Orchestration

Agents delegate work autonomously. Minimize user involvement:

**Subagents** (invoke via `@name`):
- `@audit` -- full quality audit, delegates findings to other agents
- `@code-review` -- read-only review, categorized findings
- `@db` -- SQLModel/Alembic/PostgreSQL specialist
- `@debug` -- root cause diagnosis, structured handoff
- `@refactor` -- complexity reduction, behaviour-preserving
- `@security` -- vulnerability identification, severity-ranked
- `@tests` -- pytest suite generation, coverage gaps

**Skills** (load when situation matches):
- `alembic-migration` -- creating/modifying migrations
- `cavecrew` -- delegate to compressed subagents (investigator/builder/reviewer)
- `caveman` -- caveman-mode communication (always-on; see banner above)
- `caveman-compress` -- compress markdown/memory files via `/caveman:compress <filepath>`
- `docker-build-debug` -- container build/startup failures
- `new-fastapi-project` -- scaffolding new project
- `performance-analysis` -- slowness, memory, profiling
- `pr-checklist` -- pre-merge quality gate

> **Source of truth**: `skills/` dir. When adding/removing a skill, update this list AND `README.md` Skills table.

**Flow**: After completing work, agents proactively invoke next agent in chain. No user prompt needed between steps. Example flows:
- Feature complete -> `@code-review` -> `@security` (if auth touched) -> `pr-checklist`
- Bug reported -> `@debug` -> primary agent fixes -> `@tests` -> `@code-review`
- New model added -> `@db` reviews -> `alembic-migration` skill -> `@tests`
- Audit requested -> `@audit` -> `@db` + `@refactor` + `@tests` + `@security` (per findings)

---

# Python Project Standards

Non-negotiable defaults. Apply without asking. **"Ask user"** = need project-specific input.

---

## Before You Start

Ask if not clear:

1. **Database** -- default PostgreSQL + SQLModel + asyncpg. Other DB? None?
2. **Auth** -- provider + mechanism (Auth0 JWT, API key, OIDC, none)?
3. **Testing scope** -- full suite or out of scope?

---

## Toolchain

| Concern | Tool | Notes |
|---------|------|-------|
| Python | **3.14** | Pin in `.python-version` |
| Pkg mgr | **uv** | Only tool. No pip/poetry/pipenv. |
| Linter | **ruff** | Full rules, preview, auto-fix, unsafe-fixes |
| Formatter | **ruff format** | Replaces black + isort |
| Security | **bandit** | Strict profile, no suppressions |
| Pre-commit | **pre-commit** | All hooks pass before commit |
| Debug | **icecream** | `ic()` not `print()` during dev |

### uv

```bash
uv init --no-package
uv sync --frozen
uv sync --frozen --no-dev
uv add <package>
uv add --dev <package>
uv run -- <command>
uv lock
```

- Commit `uv.lock`. Never commit `.venv/`.
- `package = false` in `[tool.uv]` for services.
- Multi-package: uv workspaces.

### Dev deps

- `bandit[toml]`
- `icecream`
- `pre-commit`
- `ruff`

---

## Code Style

### Imports

- `import typing as t` -- never `from typing import ...`
- All absolute -- no relative
- Type-only in `if t.TYPE_CHECKING:`

```python
import typing as t
from collections.abc import AsyncGenerator

if t.TYPE_CHECKING:
    from mypackage.models import User
```

### Types

- Every public func: full annotations (params + return)
- `X | None` not `Optional[X]`
- `X | Y` not `Union[X, Y]`
- Built-in generics: `list[str]`, `dict[str, int]`, `tuple[int, ...]`
- `t.Any`, `t.ClassVar`, `t.Annotated`

### Docstrings

- Google style
- Required: public functions, methods, classes
- Not required: `__init__`, magic methods, modules, packages

### Complexity (hard limits, refactor don't suppress)

| Limit | Value |
|-------|-------|
| McCabe complexity | 4 |
| Args (total) | 4 |
| Args (positional) | 3 |
| Bool expressions/condition | 3 |
| Branches/function | 5 |
| Nesting levels | 3 |

### Rules

- No commented-out code -- delete or TODO
- No file-level header comments
- No `print()` in prod -- use `logging`
- No `pdb`/`breakpoint()` committed
- No bare `except:` -- specific exceptions
- All args keyword-only (`*,`)
- Bool args = smell -- use enums or separate funcs

---

## Project Layout

```
project-name/
├── .env.example
├── .github/workflows/
├── .pre-commit-config.yaml
├── .python-version
├── api/
│   ├── controller.py
│   ├── dependencies/
│   ├── enums.py
│   ├── exceptions.py
│   ├── factories.py
│   ├── models/
│   ├── routers/
│   ├── schemas/
│   └── settings.py
├── app.py
├── docker/app/Containerfile
├── compose.yml
├── gunicorn.conf.py
├── Makefile
├── migrations/
├── pyproject.toml
├── ruff.toml
├── tests/
└── uv.lock
```

---

## FastAPI Patterns

### App Factory

Always `create_app()`. Never app at module level.

- No `default_response_class` -- FastAPI 0.130+ Pydantic Rust serializer
- `debug=True` only LOCAL env
- Routers/middleware in private helpers

### Router Rules

- `response_model=` + `status_code=` on every endpoint
- All params keyword-only (`*,`)
- Auth deps at endpoint level, not router
- `model_dump(exclude_unset=True)` on PATCH

### Router Discovery

`registry` list in `api/routers/__init__.py` for dynamic loading.

### Settings

One `Settings(BaseSettings)`, one singleton.

- No `.env` path in code -- pydantic-settings auto-discovers
- Typed fields: `PostgresDsn`, `AnyHttpUrl`, `list[str]`
- Singleton validates at startup -- missing vars raise immediately

### Exceptions

`AppBaseError(HTTPException)` base. Subclass pins `status_code`, exposes `detail`. Non-HTTP domain errors extend `Exception`.

**Ask user** about auth strategy + domain exceptions.

---

## Data Layer

Default: PostgreSQL + SQLModel. Ask if user signals other DB.

- All `table=True` inherit `BaseModel` (provides `id`, `created_at`, `updated_at`)
- Datetimes: `DateTime(timezone=True)` -- never naive
- JSON: `JSONB()`
- Relationships: `lazy="selectin"` -- no lazy loading (breaks async)
- Bidirectional: `back_populates` both sides
- FKs explicitly named, `ondelete="CASCADE"`
- Constraints explicitly named
- No UUID PKs -- `int` auto-increment
- Enums extend `BaseEnum(StrEnum)`

### Controller

Generic `Controller[ModelType]` for CRUD. One singleton per model.

### Schema Factory

Never duplicate fields. `model_factory` derives:

- `FooResponse` -- all fields
- `FooCreate` -- excludes `id`, timestamps, server-set FKs
- `FooUpdate` -- Create but all optional
- `FooResponseFull` -- Response + nested relationships

---

## Dependencies

### DB Session

```python
AsyncDBSession = t.Annotated[AsyncSession, Depends(get_db)]
```

### Annotated Convention

All injectables as `Annotated` aliases:

```python
AsyncDBSession = t.Annotated[AsyncSession, Depends(get_db)]
RequestUser = t.Annotated[User, Depends(get_current_user)]
RequireAdmin = t.Annotated[User, Depends(require_admin)]
```

### Auth

**Ask user** about provider/token/roles before implementing.

- `HTTPBearer` scheme
- Hash tokens (SHA-256) before storing -- never raw
- Cache sessions with TTL
- Role-based: dependency chain (`require_admin` -> `get_current_user`)

---

## Testing

### Key Settings

| Setting | Value |
|---------|-------|
| `asyncio_mode` | `"auto"` |
| `timeout` | 3 |
| `-n=auto` | parallel |
| `--disable-socket` | block network |
| `fail_under` | 95 |

### DB Fixture

Nested transaction + rollback per test. Zero state leakage.

**Ask user** about testing infra before `conftest.py`.

---

## Environment Variables

### MANDATORY: Agents never read or write `.env`

`.env` = secrets. Human developer only. Never open, read, modify, create.

**New setting needed:**

1. Add typed field to `Settings`
2. Add var to `.env.example` with placeholder
3. Tell user what to set

Agents own `settings.py` + `.env.example`. Developer owns `.env`.

- `.env.example` always committed
- `.env` always gitignored
- AWS creds local only; IAM roles/Secrets Manager in prod

---

## Container & Deployment

- Multi-stage Containerfile: builder (`uv sync --frozen --no-dev`) + final (non-root)
- `podman build`/`podman compose` -- not docker
- `compose.yml` for local dev
- Healthcheck on every container
- `gunicorn` + `UvicornWorker` prod, `uvicorn --reload` local

---

## CI/CD

- PR check: Ruff + Bandit + Tests
- Setup action: `setup-python` + `astral-sh/setup-uv` + `uv sync --all-extras --frozen`
- CI passes `--config pyproject.toml` explicitly
- `CODEOWNERS` for reviewers
- Auto-labeler

---

## Pre-commit & Makefile

- Hooks run entire codebase (`pass_filenames: false`, `always_run: true`)
- Targets: `install`, `fmt`, `lint`, `test`, `check`, `clean`
- `check` = fmt + lint + test + hooks