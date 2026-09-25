---
name: docker-build-debug
description: Layered diagnosis for Podman build failures, container startup, healthchecks, image size. Load when container build fails or container not starting.
---

Work layers in order.

## 1. Which stage?
builder → L2 · final → L3 · runtime → L4

## 2. Builder
`podman build --no-cache -f docker/app/Containerfile .`
- `uv.lock` not in `.containerignore`; `pyproject.toml` + `uv.lock` COPYed before `RUN uv sync`
- `--mount=type=cache,target=/root/.cache/uv`
- Python version matches `requires-python`; uv copied `COPY --from=ghcr.io/astral-sh/uv:x.x.x /uv /bin/uv`

## 3. Final stage
- `.venv` COPY path mismatch · missing `ENV PATH="/.venv/bin:$PATH"` · COPY before `USER appuser` or use `--chown`

## 4. Starts then exits
`podman compose logs app`
- pydantic `ValidationError` → env var missing, check `env_file:`
- DB not ready → `depends_on` with `condition: service_healthy`
- `podman compose logs app | grep alembic`

## 5. Healthcheck
`podman exec <c> curl -sf http://localhost:8000/service/healthcheck/` — raise `--start-period`; slim image lacks `curl` → Python healthcheck.

## 6. Size
`podman history --no-trunc <image>` — `.containerignore` complete; final stage COPYs `.venv` + src only; `podman run --rm <image> pip list | grep ruff` must be empty.

## 7. Ports
`lsof -i :8000` — change host port in `compose.yml`.

## 8. Scan
`trivy image --severity HIGH,CRITICAL <image>` — fixable CRITICAL/HIGH blocks push.
