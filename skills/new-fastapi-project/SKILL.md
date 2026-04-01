---
name: new-fastapi-project
description: Complete step-by-step scaffold for a new FastAPI web service project. Covers uv init, pyproject.toml, ruff, bandit, pre-commit, GitHub Actions, Makefile, Docker, and the full api/ directory structure. Load this when the user asks to create, bootstrap, or scaffold a new FastAPI or Python web service project.
license: MIT
compatibility: opencode
---

# Skill: New FastAPI Project Scaffold

## Before you start — ask the user

Do not begin writing files until you have answers to all of these:

1. **Project name** — used for the directory, package name, and Podman image tag
2. **Database** — PostgreSQL (SQLModel + asyncpg + Alembic)? Or no DB?
3. **Protected branches** — which branch names should be blocked from direct commits? (default: `main`, `dev`, `stage`, `prod`)
4. **AWS region** — used in CI/CD if deploying to ECS (default: `us-east-1`)
5. **GitHub owner/team** — for `CODEOWNERS` (e.g. `@acme/backend`)

Once you have answers, execute the steps below in order.

---

## Step 1 — Initialise the project

```bash
uv init --no-package <project-name>
cd <project-name>
echo "3.14" > .python-version
```

---

## Step 2 — Install dependencies

```bash
# Runtime (adjust to project needs — these are the baseline)
uv add fastapi[standard] pydantic-settings uvicorn[standard]

# Add if using DB:
uv add sqlmodel asyncpg alembic alembic-postgresql-enum

# Dev group
uv add --group dev bandit[toml] icecream pre-commit ruff

# Test group (web services always have tests)
uv add --group test gevent pytest pytest-asyncio pytest-cov pytest-env \
    pytest-instafail pytest-lazy-fixtures pytest-mock pytest-socket \
    pytest-sugar pytest-timeout pytest-xdist httpx
```

---

## Step 3 — `pyproject.toml`

Replace the generated `pyproject.toml` with the full canonical version from `AGENTS.md` Section 3. Key substitutions:
- `name = "<project-name>"`
- `src = ["<package-dir>"]` — match the actual source directory (e.g. `"api"`)
- `known-first-party = ["<package-dir>"]`
- `targets = ["<package-dir>"]` in `[tool.bandit]`
- `--cov=<package-dir>` in `addopts`
- `source = ["<package-dir>"]` in `[tool.coverage.run]`
- Add `[tool.ruff.lint.flake8-bugbear] extend-immutable-calls = ["fastapi.Depends", "fastapi.Query", "fastapi.Header"]`
- Add `runtime-evaluated-base-classes = ["pydantic.BaseModel", "sqlmodel.SQLModel"]` and `runtime-evaluated-decorators = ["pydantic.validate_call"]` to `[tool.ruff.lint.flake8-type-checking]`
- Add `"sqlalchemy.orm.declared_attr"` to `classmethod-decorators` in `[tool.ruff.lint.pep8-naming]`

Add `[tool.pytest.ini_options] env = [...]` with all required settings injected for the test run:
```toml
[tool.pytest.ini_options]
env = [
    "ENV=testing",
    # Add all required Settings fields here with test-safe values
]
```

---

## Step 4 — `ruff.toml` local override

```toml
# ruff.toml — local/IDE override only. CI uses --config pyproject.toml.
extend = "./pyproject.toml"

[lint]
unfixable = [
    "F401",
    "T20",
]
```

---

## Step 5 — `.gitignore`

```gitignore
# Python
.venv/
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
*.egg-info/
dist/
build/

# Environment
.env

# Tools
.ruff_cache/
.pytest_cache/
.mypy_cache/
coverage/
.coverage
htmlcov/

# macOS
.DS_Store

# IDE
.idea/
.vscode/
*.swp
```

---

## Step 6 — `.env.example`

```bash
# Application
ENV=local
APP_DOMAIN=http://localhost:8000
BACKEND_CORS_ORIGINS=["http://localhost:3000"]

# Database (if applicable)
# DB_URI=postgresql+asyncpg://postgres:postgres@localhost:5433/<project-name>

# Add all required settings here — one line per variable
```

---

## Step 7 — `Makefile`

```makefile
UV := uv

.PHONY: help install fmt lint lint_ruff lint_bandit test check clean \
        pre_commit_install pre_commit_uninstall pre_commit_update pre_commit_run \
        uv_install uv_lock build up down logs restart

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

install: uv_install pre_commit_install ## Bootstrap the project

fmt: ## Format code with ruff
	$(UV) run -- ruff format --config pyproject.toml .

lint_ruff: ## Run ruff linter
	$(UV) run -- ruff check --config pyproject.toml .

lint_bandit: ## Run bandit security scanner
	$(UV) run -- bandit -c pyproject.toml -r .

lint: lint_ruff lint_bandit ## Run all linters

test: ## Run the test suite
	$(UV) run -- pytest

check: fmt lint test pre_commit_run ## Full quality gate

clean: ## Remove build artifacts and caches
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -exec rm -rf {} +
	rm -rf .ruff_cache .pytest_cache coverage/ .coverage

pre_commit_install: ## Install pre-commit hooks
	$(UV) run -- pre-commit install --install-hooks

pre_commit_uninstall: ## Remove pre-commit hooks
	$(UV) run -- pre-commit uninstall

pre_commit_update: ## Update hook versions
	$(UV) run -- pre-commit autoupdate

pre_commit_run: ## Run all hooks on all files
	$(UV) run -- pre-commit run -a

uv_install: ## Install all dependencies
	$(UV) sync --all-packages

uv_lock: ## Regenerate lockfile
	$(UV) lock

build: ## Build Podman image
	podman compose build

up: ## Start services
	podman compose up -d

down: ## Stop services
	podman compose down

logs: ## Follow app logs
	podman compose logs -f app

restart: ## Restart app service
	podman compose restart app
```

If the project uses a DB, add:

```makefile
migration_create: ## Create a new migration (MSG= required)
	$(UV) run -- alembic revision --autogenerate -m "$(MSG)"

migration_upgrade: ## Apply all pending migrations
	$(UV) run -- alembic upgrade head

migration_downgrade: ## Rollback one migration
	$(UV) run -- alembic downgrade -1

migration_history: ## Show migration history
	$(UV) run -- alembic history --verbose

pg_mcp_start: ## Start the PostgreSQL MCP server for live DB analysis (db agent)
	@echo "Starting pg-mcp-server on http://localhost:8000/sse ..."
	@PG_MCP_DATABASE_URL=postgresql://postgres:postgres@localhost:5433/$(shell basename $(CURDIR)) \
		uvx stuzero/pg-mcp-server &
	@echo "pg-mcp-server started. Stop with: make pg_mcp_stop"
	@echo "Connect string: postgresql://postgres:postgres@localhost:5433/$(shell basename $(CURDIR))"
	@echo "Note: adjust the connection string if your DB name differs from the project directory name."

pg_mcp_stop: ## Stop the PostgreSQL MCP server
	@pkill -f "pg-mcp-server" && echo "pg-mcp-server stopped." || echo "pg-mcp-server was not running."
```

`# PROJECT-SPECIFIC: adjust the connection string in pg_mcp_start to match your
# compose.yml DB name, user, password, and port.`

---

## Step 8 — `.pre-commit-config.yaml`

Use the full canonical version from `AGENTS.md` Section 12 verbatim. Substitute the protected branch names in the `no-commit-to-branch` hook args with the user's answer from Step 0.

---

## Step 9 — Source directory structure

Create the following empty stubs. The package directory name should match what was set in `pyproject.toml src=`:

```
<package>/
├── __init__.py
├── controller.py          # leave empty — add models before populating
├── dependencies/
│   ├── __init__.py
│   └── db.py              # DB session dependency (if DB project)
├── enums.py               # class BaseEnum(StrEnum): ...
├── exceptions.py          # AppBaseError hierarchy from AGENTS.md
├── models/
│   ├── __init__.py
│   └── base.py            # BaseModel from AGENTS.md (if DB project)
├── routers/
│   ├── __init__.py        # registry = ["service"]
│   └── service/
│       ├── __init__.py    # registry = ["healthcheck"]
│       └── healthcheck.py # GET /service/healthcheck/ → {"status": "ok"}
├── schemas/               # empty, populated per resource
│   └── __init__.py
└── settings.py            # Settings(BaseSettings) + settings singleton
```

`app.py` at project root:

```python
import importlib
import typing as t

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.requests import Request
from fastapi.responses import JSONResponse, Response
from fastapi import status
import logging

from <package>.settings import settings
from <package>.enums import Environment


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    server = FastAPI(
        title="<Project Name>",
        version="0.1.0",
        debug=settings.ENV == Environment.LOCAL,
        # default_response_class is omitted — FastAPI 0.130+ uses Pydantic's
        # Rust-based serializer by default; ORJSONResponse is deprecated.
    )
    _set_routers(application=server)
    _set_middleware(application=server)
    return server


def _set_routers(*, application: FastAPI) -> None:
    """Dynamically import and register all routers from the registry."""
    from <package> import routers
    _import_routers(app=application, base_path="<package>.routers", module_name="__init__")


def _import_routers(*, app: FastAPI, base_path: str, module_name: str) -> None:
    """Recursively import routers from registry lists."""
    module = importlib.import_module(f"{base_path}")
    if hasattr(module, "router"):
        app.include_router(module.router)
    if hasattr(module, "registry"):
        for sub in module.registry:
            _import_routers(app=app, base_path=f"{base_path}.{sub}", module_name=sub)


def _set_middleware(*, application: FastAPI) -> None:
    """Configure application middleware."""

    @application.middleware("http")
    async def catch_exceptions_middleware(
        request: Request, call_next: t.Callable[..., t.Any]
    ) -> Response:
        try:
            return await call_next(request)
        except Exception:
            logging.getLogger(__name__).exception("Unexpected error")
            return JSONResponse(
                content={"detail": "Internal server error"},
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    if settings.BACKEND_CORS_ORIGINS:
        application.add_middleware(
            CORSMiddleware,
            allow_origins=settings.BACKEND_CORS_ORIGINS,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )


app = create_app()
```

---

## Step 10 — GitHub Actions

### `.github/CODEOWNERS`
```
* <github-owner-from-user-answer>
```

### `.github/labeler.yml`
Use the canonical version from `AGENTS.md` Section 13. Add project-specific labels:
```yaml
api:
  - changed-files:
      - any-glob-to-any-file: "<package>/**/*"
migrations:
  - changed-files:
      - any-glob-to-any-file: "migrations/**/*"
```

### `.github/actions/setup_env/action.yml`
Use the canonical version from `AGENTS.md` Section 13 verbatim.

### `.github/workflows/pr_check.yml`
Use the canonical version from `AGENTS.md` Section 13. If this is a DB project, add the `Tests` job with a `postgres:17-alpine` service container.

---

## Step 11 — Docker (if web service)

Create the following files using the canonical content from `AGENTS.md` Section 14:
- `docker/app/Containerfile`
- `docker/app/entrypoint.sh` (make executable: `chmod +x docker/app/entrypoint.sh`)
- `compose.yml`
- `gunicorn.conf.py`
- `.containerignore`

---

## Step 12 — Alembic (if DB project)

```bash
uv run -- alembic init --template async migrations
```

Then replace `migrations/env.py` with the canonical async version from `AGENTS.md` Section 8.

Replace the `[alembic]` section of `alembic.ini`:
```ini
[alembic]
script_location = migrations
file_template = %%(year)d%%(month).2d%%(day).2d%%(hour).2d%%(minute).2d_%%(slug)s
prepend_sys_path = .

[post_write_hooks]
hooks = ruff, ruff_format
ruff.type = exec
ruff.executable = ruff
ruff.options = check --fix REVISION_SCRIPT_FILENAME
ruff_format.type = exec
ruff_format.executable = ruff
ruff_format.options = format REVISION_SCRIPT_FILENAME
```

---

## Step 13 — Final bootstrap

```bash
uv lock
uv sync --all-packages
uv run -- pre-commit install --install-hooks
make fmt
make lint
```

Confirm output is clean before handing back to the user.

---

## Step 14 — CLAUDE.md

Create `CLAUDE.md` at the project root. This file is the **cross-session memory** for the project — OpenCode reads it automatically at the start of every session, so agents never need to re-derive project decisions.

Use this structure:

```markdown
# Project Context

## What this project is
<one paragraph — purpose, stack, deployment target>

## Current state
- Scaffolded with new-fastapi-project skill
- [ ] Auth not yet implemented
- [ ] First feature not yet started

## Key decisions
- Python 3.14, uv for package management
- <any decisions made during setup that deviate from AGENTS.md defaults>

## Constraints
- Local dev prerequisites: Podman, podman-compose
- <any project-specific rules>

## Open questions
- Auth provider: <TBD>
- <anything not yet decided>

## Ruled out
- (none yet)
```

Keep it terse. An agent should read the whole file in under 30 seconds.
Run `/save-context` at the end of planning sessions to keep it current.
Commit `CLAUDE.md` to git — it is project documentation, not personal config.
