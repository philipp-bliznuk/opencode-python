---
name: new-fastapi-project
description: Scaffold new FastAPI service — uv, pyproject, ruff, bandit, pre-commit, GitHub Actions, Makefile, Podman, api/ layout. Load when user asks to create/bootstrap FastAPI project.
---

## Ask first
Project name · DB (PostgreSQL or none) · protected branches (default `main dev stage prod`) · GitHub owner for `CODEOWNERS`.

## Steps
1. `uv init --no-package <name> && cd <name> && echo 3.14 > .python-version`
2. Deps:
```bash
uv add fastapi[standard] pydantic-settings uvicorn[standard]
uv add sqlmodel asyncpg alembic alembic-postgresql-enum          # if DB
uv add --group dev bandit[toml] icecream pre-commit ruff
uv add --group test gevent pytest pytest-asyncio pytest-cov pytest-env pytest-instafail \
    pytest-lazy-fixtures pytest-mock pytest-socket pytest-sugar pytest-timeout pytest-xdist httpx
```
3. `pyproject.toml` per AGENTS.md. Add `extend-immutable-calls = ["fastapi.Depends", "fastapi.Query", "fastapi.Header"]`, `runtime-evaluated-base-classes` for Pydantic/SQLModel.
4. `ruff.toml`: `extend = "./pyproject.toml"`, `[lint] unfixable = ["F401", "T20"]`.
5. `.gitignore`: `.venv/ __pycache__/ .env opencode.json .ruff_cache/ .pytest_cache/ coverage/`. `.env.example` with placeholders.
6. `Makefile`: `install fmt lint test check clean build up down logs` (+ `migration_*` if DB).
7. `.pre-commit-config.yaml` — hooks run whole codebase.
8. Layout:
```
app.py                     create_app() → _set_routers, _set_middleware
<pkg>/
  controller.py  enums.py  exceptions.py  settings.py
  dependencies/db.py       models/base.py       schemas/
  routers/__init__.py (registry)  routers/service/healthcheck.py
```
9. `.github/`: `CODEOWNERS`, `labeler.yml`, `actions/setup_env/action.yml`, `workflows/pr_check.yml`.
10. `docker/app/Containerfile` (multi-stage), `docker/app/entrypoint.sh`, `compose.yml`, `gunicorn.conf.py`, `.containerignore`.
11. DB: `uv run -- alembic init --template async migrations`; canonical `env.py`.
12. `uv lock && uv sync && uv run -- pre-commit install --install-hooks && make fmt lint`
