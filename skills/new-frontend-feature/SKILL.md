---
name: new-frontend-feature
description: Step-by-step scaffold for adding a frontend to an existing FastAPI project. Covers bun setup, Vite config, Biome, TypeScript, Podman Compose dev containers, multi-stage Containerfile production build, and FastAPI static serving. Load this when the user asks to add a UI, frontend, React/Vue/Svelte component, or web interface to a Python backend project.
license: MIT
compatibility: opencode
---

# Skill: Add Frontend to FastAPI Project

## Before you start — ask the user

Do not write any files until you have answers to all of these:

1. **Framework** — React, Vue, Svelte, or plain TypeScript?
2. **CSS approach** — Tailwind CSS, CSS Modules, or plain CSS?
3. **Project shape** — where is the FastAPI project root? What is the directory structure?
   - If it's already split into `backend/` and `frontend/`: confirm and continue
   - If it's a single-root FastAPI project: you will create a `frontend/` sibling directory
     alongside the existing source; ask before touching the backend structure
4. **Existing Podman setup** — is there already a `Containerfile` and `compose.yml`?
   Show the user what you will change before touching them.

---

## Step 1 — Create the frontend directory and init bun

```bash
# From project root
mkdir frontend && cd frontend
bun create vite . --template <framework>-ts
# react-ts | vue-ts | svelte-ts | vanilla-ts — use the answer from Step 0
```

For a blank TypeScript project without a framework:
```bash
mkdir frontend && cd frontend
bun init -y
```

After init, verify `bun.lock` was created. This file must be committed.

---

## Step 2 — Install and configure Biome

```bash
cd frontend
bun add -d @biomejs/biome
bunx --bun @biomejs/biome init
```

Replace the generated `biome.json` with this baseline config:

```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
  "organizeImports": {
    "enabled": true
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true
    }
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 88
  },
  "javascript": {
    "formatter": {
      "quoteStyle": "single",
      "trailingCommas": "es5"
    }
  },
  "files": {
    "ignore": ["dist/", "node_modules/"]
  }
}
```

---

## Step 3 — TypeScript configuration

Replace or create `frontend/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "isolatedModules": true,
    "jsx": "react-jsx",        // remove if not using React
    "skipLibCheck": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

---

## Step 4 — Vite configuration with API proxy

Replace `frontend/vite.config.ts` with:

```ts
import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"  // swap for @vitejs/plugin-vue or @sveltejs/vite-plugin-svelte
import { resolve } from "path"

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": resolve(__dirname, "./src"),
    },
  },
  server: {
    host: true,     // required for Podman containers — listens on 0.0.0.0 not just localhost
    port: 5173,
    proxy: {
      "/api": {
        // In Podman Compose: use the backend service name as hostname
        // For bare local dev (no Docker): change to http://localhost:8000
        target: "http://backend:8000",
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: "dist",
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ["react", "react-dom"],  // adjust for your framework
        },
      },
    },
  },
})
```

---

## Step 5 — Update package.json scripts

Ensure `frontend/package.json` has these scripts:

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "check": "biome check --write . && tsc --noEmit",
    "test": "bun test",
    "test:watch": "bun test --watch"
  }
}
```

---

## Step 6 — Update .gitignore

Add to the **root** `.gitignore`:

```gitignore
# Frontend
frontend/node_modules/
frontend/dist/

# Backend static (populated at Podman build time)
backend/api/static/dist/
# PROJECT-SPECIFIC: adjust path to match your FastAPI static directory
```

---

## Step 7 — compose.yml: add frontend service

Add to the existing `compose.yml`. Show the user the diff before applying:

```yaml
  frontend:
    image: oven/bun:latest
    working_dir: /frontend
    volumes:
      - ./frontend:/frontend:cached
      - /frontend/node_modules    # anonymous volume — prevents host dir override
    ports:
      - "5173:5173"
    command: sh -c "bun install --frozen-lockfile && bun run dev"
    depends_on:
      backend:                    # PROJECT-SPECIFIC: match your backend service name
        condition: service_healthy
```

The frontend dev server proxies all `/api/*` requests to the `backend` service over the
internal Docker network. No CORS configuration is needed for local development.

> **Note**: the proxy target in `vite.config.ts` uses the Podman Compose service name `backend`
> as the hostname. For running Vite outside of Docker (bare `bun run dev`), change the
> target to `http://localhost:8000` or extract it to an env var:
> ```ts
> target: process.env.API_URL ?? "http://localhost:8000"
> ```
> Then set `API_URL=http://backend:8000` in the frontend container's environment.

---

## Step 8 — Containerfile: add frontend build stage

Show the user the full diff before modifying the Containerfile.

Add a new first stage **before** the existing Python builder stage:

```dockerfile
# ── Stage 0: frontend builder ────────────────────────────────────────────────
FROM oven/bun:latest AS frontend-builder
WORKDIR /frontend
# Copy only package files first for layer caching
COPY frontend/package.json frontend/bun.lock ./
RUN bun install --frozen-lockfile
COPY frontend/ .
RUN bun run build
```

In the **final** Python stage, copy the built assets into the FastAPI static directory:

```dockerfile
# Copy built frontend into FastAPI's static directory
# This line goes AFTER the Python source COPY and BEFORE the USER instruction
COPY --from=frontend-builder /frontend/dist ./backend/api/static/dist
# PROJECT-SPECIFIC: adjust the destination path to your FastAPI static directory
```

---

## Step 9 — FastAPI: serve the frontend

Add static file serving to `app.py`'s `create_app()` function.

First, add `python-multipart` and `aiofiles` if not already present (required for
`StaticFiles`):

```bash
uv add aiofiles
```

Then add the static mounting function:

```python
# In app.py
from pathlib import Path

from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

_STATIC = Path("backend/api/static/dist")  # PROJECT-SPECIFIC: adjust to your layout


def _set_static(*, application: FastAPI) -> None:
    """Mount built frontend assets and serve SPA fallback."""
    if not _STATIC.exists():
        # Backend starts cleanly in dev when frontend has not been built
        return

    application.mount(
        "/assets",
        StaticFiles(directory=_STATIC / "assets"),
        name="static-assets",
    )

    @application.get("/{full_path:path}", include_in_schema=False)
    async def serve_spa(full_path: str) -> FileResponse:
        """Return index.html for all unmatched routes (SPA fallback)."""
        return FileResponse(_STATIC / "index.html")
```

Call `_set_static(application=server)` in `create_app()`, **after** `_set_routers()` and
`_set_middleware()` — the catch-all route must be registered last so it does not shadow
API endpoints.

---

## Step 10 — Makefile targets

Add to the project `Makefile`:

```makefile
fe_install: ## Install frontend dependencies
	cd frontend && bun install

fe_dev: ## Start frontend dev server (bare, without Docker)
	cd frontend && bun run dev

fe_build: ## Build frontend for production
	cd frontend && bun run build

fe_check: ## Lint, format, and type-check frontend
	cd frontend && bunx --bun @biomejs/biome check --write . && bunx tsc --noEmit

fe_test: ## Run frontend unit tests
	cd frontend && bun test
```

---

## Step 11 — GitHub Actions: Frontend job

Add a `Frontend` job to `.github/workflows/pr_check.yml`:

```yaml
  Frontend:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4

      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest

      - name: Install dependencies
        run: bun install --frozen-lockfile
        working-directory: frontend

      - name: Lint and format check
        run: bunx --bun @biomejs/biome check .
        working-directory: frontend

      - name: Type check
        run: bunx tsc --noEmit
        working-directory: frontend

      - name: Build
        run: bun run build
        working-directory: frontend

      - name: Test
        run: bun test
        working-directory: frontend
```

---

## Step 12 — Final verification

```bash
# From project root
cd frontend && bun install && bun run check && bun run build
```

Confirm:
- `dist/` directory was created with `index.html` and `assets/`
- No TypeScript errors (`tsc --noEmit` clean)
- No Biome violations (`biome check .` clean)
- `bun test` passes (if tests were written)

Then start the full stack:
```bash
podman compose up --build
```

Confirm:
- Frontend accessible at `http://localhost:5173`
- API requests proxied correctly: `http://localhost:5173/api/...` → FastAPI
- No CORS errors in the browser console
