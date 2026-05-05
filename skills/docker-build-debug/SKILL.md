---
name: docker-build-debug
description: >
  Layered diagnosis for Podman/container build failures, startup issues, health checks,
  image size. Load when container build fails or container not starting.
---

# Podman Build & Container Diagnosis

Work through layers in order. Most issues caught by 1-3.

## Layer 1: Which Stage Fails?

- **builder stage** -> uv install, Python version, lockfile issue (Layer 2)
- **final stage** -> COPY, permission, PATH issue (Layer 3)
- **runtime** -> app crash, missing env var, healthcheck (Layer 4)

## Layer 2: Builder Failures

```bash
podman build --no-cache -f docker/app/Containerfile .  # rule out stale cache
```

Check:
- `uv.lock` not in `.containerignore`
- `pyproject.toml` + `uv.lock` COPYed BEFORE `RUN uv sync`
- Cache mount syntax: `--mount=type=cache,target=/root/.cache/uv`
- Python version matches `requires-python`
- uv binary copied: `COPY --from=ghcr.io/astral-sh/uv:x.x.x /uv /bin/uv`

## Layer 3: Final Stage Failures

- `.venv` path mismatch between builder COPY source and actual location
- Missing `ENV PATH="/.venv/bin:$PATH"` in final stage
- Permission denied: `COPY` before `USER appuser`, or use `--chown`

## Layer 4: Container Starts Then Exits

```bash
podman compose logs app
```

- **Missing env var**: pydantic-settings `ValidationError` at startup. Check `.env` passed via `env_file:`.
- **DB not ready**: `depends_on` must use `condition: service_healthy`, not bare list.
- **Alembic fails**: check `podman compose logs app | grep alembic`

## Layer 5: Health Check Failing

```bash
podman exec <container> curl -sf http://localhost:8000/service/healthcheck/
```

- Endpoint not responding: app crashing before handling requests
- Timing: increase `--start-period` for slow startup
- `curl` not in slim image: install it or use Python-based healthcheck

## Layer 6: Image Size

```bash
podman history --no-trunc <image>
```

- Check `.containerignore` completeness
- Final stage should only COPY `.venv` + source -- no `uv sync` again
- Verify dev deps excluded: `podman run --rm <image> pip list | grep ruff`

## Layer 7: Port Conflicts

```bash
lsof -i :8000
lsof -i :5433
```

Change host-side port in `compose.yml`.

## Layer 8: Security Scan

```bash
trivy image --severity HIGH,CRITICAL <image>
```

CRITICAL/HIGH with fix available = block push. Update package or base image.
