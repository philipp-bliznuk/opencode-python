---
name: new-fastapi-project
description: >
  Complete scaffold for new FastAPI web service. Covers uv init, pyproject.toml, ruff, bandit,
  pre-commit, GitHub Actions, Makefile, Docker, full api/ structure. Load when user asks to
  create/bootstrap new FastAPI project.
---

# New FastAPI Project Scaffold

## Ask First

1. **Project name** -- directory + package name
2. **Database** -- PostgreSQL (SQLModel + asyncpg + Alembic) or none?
3. **Protected branches** -- (default: `main`, `dev`, `stage`, `prod`)
4. **GitHub owner/team** -- for `CODEOWNERS`

## Steps

### 1. Init
```bash
uv init --no-package <project-name>
cd <project-name>
echo "3.14" > .python-version
```

### 2. Dependencies
```bash
uv add fastapi[standard] pydantic-settings uvicorn[standard]
# If DB:
uv add sqlmodel asyncpg alembic alembic-postgresql-enum
# Dev:
uv add --group dev bandit[toml] icecream pre-commit ruff
# Test:
uv add --group test gevent pytest pytest-asyncio pytest-cov pytest-env \
    pytest-instafail pytest-lazy-fixtures pytest-mock pytest-socket \
    pytest-sugar pytest-timeout pytest-xdist httpx
```

### 3. pyproject.toml
Full canonical config from `AGENTS.md`. Substitute project-specific values:
- `name`, `src`, `known-first-party`, `targets`, `--cov=<pkg>`, `source`
- Add `extend-immutable-calls = ["fastapi.Depends", "fastapi.Query", "fastapi.Header"]`
- Add `runtime-evaluated-base-classes` for Pydantic/SQLModel

### 4. ruff.toml
```toml
extend = "./pyproject.toml"
[lint]
unfixable = ["F401", "T20"]
```

### 5. .gitignore
Standard: `.venv/`, `__pycache__/`, `.env`, `opencode.json`, `.ruff_cache/`, `.pytest_cache/`, `coverage/`, `.DS_Store`, IDE dirs.

### 6. .env.example
All required settings with safe placeholders. Never real secrets.

### 7. Makefile
Targets: `help`, `install`, `fmt`, `lint`, `test`, `check`, `clean`, `pre_commit_*`, `uv_*`, `build`, `up`, `down`, `logs`, `restart`.
DB projects add: `migration_create`, `migration_upgrade`, `migration_downgrade`.

### 8. .pre-commit-config.yaml
Canonical from AGENTS.md. Substitute protected branch names.

### 9. Source Structure
```
<pkg>/
├── __init__.py
├── controller.py
├── dependencies/
│   ├── __init__.py
│   └── db.py (if DB)
├── enums.py
├── exceptions.py
├── models/ (if DB)
│   ├── __init__.py
│   └── base.py
├── routers/
│   ├── __init__.py (registry)
│   └── service/healthcheck.py
├── schemas/
│   └── __init__.py
└── settings.py
```

`app.py` at root: `create_app()` factory with `_set_routers`, `_set_middleware`.

### 10. GitHub Actions
- `.github/CODEOWNERS`
- `.github/labeler.yml`
- `.github/actions/setup_env/action.yml`
- `.github/workflows/pr_check.yml`

### 11. Docker
- `docker/app/Containerfile` (multi-stage)
- `docker/app/entrypoint.sh` (chmod +x)
- `compose.yml`
- `gunicorn.conf.py`
- `.containerignore`

### 12. Alembic (if DB)
```bash
uv run -- alembic init --template async migrations
```
Replace `env.py` + `alembic.ini` with canonical versions.

### 13. Bootstrap
```bash
uv lock && uv sync --all-packages
uv run -- pre-commit install --install-hooks
make fmt && make lint
```
