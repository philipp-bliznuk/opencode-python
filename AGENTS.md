# CAVEMAN MODE — ALWAYS ON

Every response, every agent, every mode. Off only on "stop caveman" / "normal mode".

**Drop**: articles, filler (just/really/basically), pleasantries, hedging. Fragments OK. Short synonyms.
**Keep exact**: code, paths, URLs, commands, error strings, API names.
Pattern: `[thing] [action] [reason]. [next step].`

| Level | Change |
|---|---|
| lite | No filler. Full sentences. |
| **full** (default) | Drop articles. Fragments. |
| ultra | Abbreviate prose (DB/auth/cfg/fn), arrows for causality. Never abbreviate code symbols. |

Switch: `/caveman lite|full|ultra`.

**Normal English for**: security warnings, irreversible-action confirmations, multi-step sequences where fragments risk ambiguity, user asks to clarify. Code blocks, commit messages, PR descriptions always normal.

---

# Working Directory Boundary

Stay inside `$PWD`. Outside paths (`~/`, `/etc/`, sibling repos) need explicit per-session permission. Ask: "Need path outside project: `<path>`. Reason: `<why>`. OK?" User naming a path = permission for that path only.

Allowed: `$PWD` + subdirs, project `node_modules/`, `.venv/`, build outputs.

---

# Agents & Skills

Subagents: `@review` (code + security, read-only) · `@debug` (root cause, read-only) · `@tests` (pytest, edits `tests/` only) · `@db` (SQLModel/Alembic/PostgreSQL, read-only).

Skills: `alembic-migration` · `docker-build-debug` · `new-fastapi-project` · `performance-analysis` · `pr-checklist`.

Chain without asking: feature done → `@review` → `pr-checklist`. Bug → `@debug` → fix → `@tests` → `@review`. New model → `@db` → `alembic-migration` → `@tests`.

---

# Python Standards

Non-negotiable. Ask user only for: DB choice (default PostgreSQL + SQLModel + asyncpg), auth provider/mechanism, testing scope.

## Toolchain

Python **3.14** (`.python-version`) · **uv** only (no pip/poetry) · **ruff** lint + format (preview, unsafe-fixes) · **bandit** strict, no `# nosec` · **pre-commit** · `icecream` for dev debugging.

`uv add <pkg>` / `uv add --dev <pkg>` / `uv run -- <cmd>` / `uv sync --frozen`. Commit `uv.lock`. `package = false` for services.

## Style

- `import typing as t` — never `from typing import`. Absolute imports only. Type-only imports under `if t.TYPE_CHECKING:`.
- Full annotations on public funcs. `X | None`, `list[str]`, `dict[str, int]` — no `Optional`/`Union`/`List`.
- Google docstrings on public funcs/classes. Not on `__init__`/magic/modules.
- All args keyword-only (`*,`). Bool args = smell → enum or split func.
- No commented-out code, file headers, `print()`, `breakpoint()`, bare `except:`.

| Limit | Value |
|---|---|
| McCabe | 4 |
| Args total / positional | 4 / 3 |
| Bool exprs per condition | 3 |
| Branches per func | 5 |
| Nesting | 3 |

Refactor, never suppress.

## FastAPI

- `create_app()` factory. No module-level app. `debug=True` only LOCAL.
- Every endpoint: `response_model=` + `status_code=`. Params kw-only. Auth deps at endpoint level.
- PATCH: `model_dump(exclude_unset=True)`.
- Router `registry` list in `api/routers/__init__.py`.
- One `Settings(BaseSettings)` singleton; typed fields (`PostgresDsn`, `AnyHttpUrl`); validates at startup.
- `AppBaseError(HTTPException)` base; subclasses pin `status_code`.
- Deps as `Annotated` aliases: `AsyncDBSession = t.Annotated[AsyncSession, Depends(get_db)]`.
- Auth: `HTTPBearer`; hash tokens SHA-256 before storing; role chain `require_admin` → `get_current_user`.

## Data

- `table=True` models inherit `BaseModel` (`id`, `created_at`, `updated_at`). Int PKs.
- `DateTime(timezone=True)` · `JSONB()` · `lazy="selectin"` · `back_populates` both sides.
- FKs + constraints explicitly named, `ondelete="CASCADE"`. Enums extend `BaseEnum(StrEnum)`.
- Generic `Controller[ModelType]` CRUD, one singleton per model.
- `model_factory` derives `FooResponse` / `FooCreate` / `FooUpdate` / `FooResponseFull` — never duplicate fields.

## Testing

`asyncio_mode = "auto"` · `timeout = 3` · `-n auto` · `--disable-socket` · `fail_under = 95`. Nested-transaction rollback fixture per test.

## Environment

**Never read/write `.env`.** Add typed field to `Settings` + placeholder to `.env.example`, tell user. `.env.example` committed; `.env` gitignored.

## Deploy

Multi-stage Containerfile (builder `uv sync --frozen --no-dev` → non-root final). `podman`, not docker. Healthcheck every container. `gunicorn` + `UvicornWorker` prod. CI: ruff + bandit + tests. Makefile: `install fmt lint test check clean`.
