---
name: docker-build-debug
description: Layered diagnosis playbook for Docker build failures, container startup issues, docker-compose service problems, and image size/performance concerns. Load this when the user reports a Docker build failing, a container not starting, a health check failing, or any Docker or docker-compose issue.
license: MIT
compatibility: opencode
---

# Skill: Docker Build & Container Diagnosis

Work through each layer below in order. Most issues are caught by layers 1-3. Only proceed deeper if the earlier layers are clean.

---

## Layer 1 — Identify which stage fails

A multi-stage build has two stages: `builder` (installs deps) and `final` (runs the app). The error message tells you which stage failed:

```
=> ERROR [builder 4/4] RUN uv sync --frozen --no-dev
=> ERROR [final 3/5] COPY --from=builder /code/.venv /.venv
```

- **`builder` stage failure**: uv install, Python version, lockfile, or cache mount issue → see Layer 2
- **`final` stage failure**: COPY, permission, or PATH issue → see Layer 3
- **Runtime failure (container exits after starting)**: app crash, missing env var, or healthcheck → see Layer 4

---

## Layer 2 — Builder stage failures

### Rule out stale cache first

```bash
docker build --no-cache -f docker/app/Dockerfile .
```

If it passes with `--no-cache` but fails normally, the issue is a corrupted layer cache. Prune and rebuild:

```bash
docker builder prune --filter type=exec.cachemount
docker build -f docker/app/Dockerfile .
```

### `uv sync --frozen --no-dev` fails

**Check 1 — `uv.lock` is not in `.dockerignore`**

```bash
grep 'uv.lock' .dockerignore
```

If `uv.lock` is excluded, uv cannot install in frozen mode. Remove it from `.dockerignore`.

**Check 2 — `pyproject.toml` and `uv.lock` are both COPYed before `RUN uv sync`**

```dockerfile
# Correct order:
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev
```

If `COPY . .` happens before the `RUN`, subsequent code changes invalidate the dep install cache. The `pyproject.toml + uv.lock` copy must be a separate layer.

**Check 3 — uv cache mount syntax**

```dockerfile
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev
```

The `--mount` flag requires BuildKit. Confirm BuildKit is enabled:

```bash
DOCKER_BUILDKIT=1 docker build -f docker/app/Dockerfile .
# or: docker buildx build -f docker/app/Dockerfile .
```

**Check 4 — Python version mismatch**

The base image Python version must satisfy `requires-python` in `pyproject.toml`. Confirm:

```bash
grep 'requires-python' pyproject.toml
# should be >=3.14

docker run --rm python:3.14-slim python --version
# should be Python 3.14.x
```

### uv not found in builder

```dockerfile
# Must copy uv binary before using it
COPY --from=ghcr.io/astral-sh/uv:x.x.x /uv /bin/uv
# ^ pin to the current release: https://github.com/astral-sh/uv/releases
```

If this line is missing or the version tag does not exist, the build fails with `uv: not found`. Pin the version explicitly — never use `:latest`.

---

## Layer 3 — Final stage failures

### `.venv` not found after COPY

```dockerfile
# Builder puts venv at /code/.venv
COPY --from=builder /code/.venv /.venv
```

Confirm the path matches where uv actually created the venv in the builder stage. Check:

```bash
docker build --target builder -t debug-builder -f docker/app/Dockerfile . 2>&1
docker run --rm debug-builder ls /code/
# should show .venv/
```

### Commands not found in final stage (PATH issue)

The final stage does not inherit the builder's `PATH`. Confirm:

```dockerfile
ENV PATH="/.venv/bin:$PATH"
```

This must be in the `final` stage `ENV` block, not only in `builder`. Test:

```bash
docker run --rm <image> python --version
docker run --rm <image> which gunicorn
```

### Permission denied errors

Non-root user (`USER appuser`) must not need write access to directories owned by root. Common causes:

```bash
# Check ownership inside the container
docker run --rm --entrypoint sh <image> -c "ls -la /code/"
```

Fix: ensure `COPY` in the final stage happens before `USER appuser`, or use `--chown`:

```dockerfile
COPY --chown=appuser:appuser --from=builder /code/.venv /.venv
COPY --chown=appuser:appuser . .
USER appuser
```

---

## Layer 4 — Container starts but immediately exits

```bash
docker compose logs app
# or:
docker run --rm <image>   # see exit output directly
```

### Missing environment variable

A `ValidationError` from pydantic-settings at startup means a required env var is absent:

```
pydantic_settings.env_settings.ValidationError: 1 validation error for Settings
DB_URI
  Field required [type=missing]
```

Check `.env` is present, is not in `.dockerignore`, and is passed to docker-compose:

```yaml
services:
  app:
    env_file: .env   # must be present
```

Or confirm the variable is set in `environment:` block. Cross-reference with `.env.example` to find which vars are missing.

### Database not ready

The app starts before PostgreSQL is healthy. Confirm `depends_on` uses `condition: service_healthy`, not bare `depends_on`:

```yaml
depends_on:
  db:
    condition: service_healthy   # correct
# NOT: depends_on: [db]          # wrong — does not wait for health
```

And confirm the DB service has a `healthcheck`:

```yaml
db:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U postgres"]
    interval: 5s
    timeout: 5s
    retries: 5
```

### Alembic upgrade fails on start

`entrypoint.sh` runs `alembic upgrade head` — if migrations fail, the app may still start (it runs in background), but you will see errors in logs. Check:

```bash
docker compose logs app | grep -i alembic
```

Common causes: DB not reachable (see above), migration has a constraint naming error, enum type out of sync.

---

## Layer 5 — Health check failing

```bash
docker compose ps    # shows (unhealthy) status
docker inspect <container_id> | jq '.[0].State.Health'
```

**Check 1 — endpoint is actually responding**

```bash
docker exec <container> curl -sf http://localhost:8000/service/healthcheck/
```

If this fails: the app is crashing before handling requests. Check logs.

**Check 2 — health check timing**

For slow-starting apps (large model loads, DB migrations), the default intervals may be too aggressive:

```dockerfile
HEALTHCHECK --interval=15s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/service/healthcheck/ || exit 1
```

Increase `--start-period` to give the app time to complete startup before health checks begin.

**Check 3 — `curl` not in final image**

`python:3.14-slim` does not include `curl`. Install it in the final stage:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
```

Or use a Python-based health check instead:

```dockerfile
HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/service/healthcheck/')"
```

---

## Layer 6 — Image size unexpectedly large

```bash
docker images <image-name>
docker history <image-name>
```

**Check `.dockerignore` completeness**

These must be excluded:

```
.git
.github
.venv
.env
tests/
coverage/
ruff.toml
Makefile
docker-compose.yml
**/__pycache__
**/*.pyc
**/.pytest_cache
**/.ruff_cache
```

**Check the builder cache is not leaking into the final stage**

The final stage should only `COPY --from=builder /code/.venv /.venv` and `COPY . .` — it must not run `uv sync` again or copy the entire `/code` from builder.

**Check for large dev dependencies in production**

`uv sync --frozen --no-dev` in the builder stage should exclude dev deps. Verify:

```bash
docker run --rm <image> pip list | grep -E 'ruff|bandit|pytest|icecream'
# should return nothing
```

**Layer analysis tools**

```bash
# Show each layer's size and the command that created it (no truncation)
docker history --no-trunc <image>

# Interactive layer explorer with file-level diff per layer
# Install: brew install dive
dive <image>

# Build context size — should be KBs, not MBs
docker build --progress=plain . 2>&1 | grep -i "transferring context"
```

If `dive` shows a layer is unexpectedly large, the creating `RUN` or `COPY`
instruction is the culprit. Check for: leftover build tools, uncleaned apt
cache, accidentally copied directories.

---

## Layer 7 — Port conflicts

```bash
docker compose up 2>&1 | grep 'port is already allocated'
```

The default mapping is `"8000:8000"` for app and `"5433:5432"` for DB. If another process holds those ports:

```bash
lsof -i :8000
lsof -i :5433
```

Change the host-side port in `docker-compose.yml` (left side of `:`):

```yaml
ports:
  - "8001:8000"   # host:container
```

---

## Layer 8 — Security scanning

After diagnosing build and size issues, always run a CVE scan before pushing
to a registry:

```bash
# Docker Scout (built-in to Docker Desktop — no install required)
docker scout quickview <image>
docker scout cves <image>

# Trivy (install: brew install trivy)
trivy image <image>
trivy image --severity HIGH,CRITICAL <image>    # high/critical only
trivy image --ignore-unfixed <image>             # only CVEs with a known fix
```

**What to do with findings:**

| Severity | Action |
|---|---|
| CRITICAL with fix available | Block the push — update the package or base image |
| HIGH with fix available | Block the push — same |
| MEDIUM / LOW | Note and schedule for next maintenance window |
| Any severity, no fix available | Accept and document; re-check monthly |

**If the CVE is in the base image** (`python:3.14-slim`): check if a newer
patch of the base image has the fix (`docker pull python:3.14-slim && trivy
image python:3.14-slim`). If not, the only option is a distroless or custom
base image.

**If the CVE is in a Python package**: update it in `pyproject.toml` with `uv
add <pkg>@latest`, re-lock with `uv lock`, and rebuild.

---

## Handoff

Once the root cause is identified, summarise using the debug handoff format and pass to `@build` for the fix, or directly apply if it is a configuration change (Dockerfile, docker-compose.yml, .dockerignore).
