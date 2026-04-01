# Shell Non-Interactive Strategy

**Context:** OpenCode's shell environment is strictly **non-interactive**. It lacks a TTY/PTY,
meaning any command that waits for user input, confirmation, or launches a UI will hang
indefinitely and time out.

**Goal:** Always use non-interactive flags. Never require a human at the terminal.

---

## Core Mandates

1. **Assume `CI=true`** — act as if running in a headless CI/CD pipeline at all times
2. **No editors or pagers** — `vim`, `nano`, `less`, `more`, `man` are banned
3. **Always supply non-interactive flags** — `-y`, `-f`, `--no-edit`, `--frozen-lockfile`
4. **Prefer built-in tools** — use `Read`/`Write`/`Edit` tools over shell file manipulation
5. **No interactive modes** — never use `-i`, `-p`, or any flag that waits for input
6. **Never use bare `python` or `pip`** — always go through `uv`

---

## Environment Variables (set these to prevent prompts)

| Variable | Value | Purpose |
|---|---|---|
| `CI` | `true` | General CI detection |
| `DEBIAN_FRONTEND` | `noninteractive` | apt/dpkg prompts |
| `GIT_TERMINAL_PROMPT` | `0` | Git auth prompts |
| `GIT_EDITOR` | `true` | Block git from opening an editor |
| `GIT_PAGER` | `cat` | Disable git pager |
| `PAGER` | `cat` | Disable system pager |
| `HOMEBREW_NO_AUTO_UPDATE` | `1` | Homebrew update prompts |
| `BUN_NO_PROMPT` | `1` | Bun interactive prompts |

---

## Package Managers

### Python — always via uv (never bare python or pip)

| Action | BAD (hangs / wrong) | GOOD |
|---|---|---|
| Install deps | `pip install pkg` | `uv add pkg` |
| Sync lockfile | `uv sync` | `uv sync --frozen` |
| Run Python | `python` | `uv run -- python -c "code"` |
| Run script | `python script.py` | `uv run -- python script.py` |
| Run pytest | `pytest` | `uv run -- pytest` |
| Run ruff | `ruff check` | `uv run -- ruff check --config pyproject.toml` |
| Run alembic | `alembic upgrade` | `uv run -- alembic upgrade head` |
| New revision | `alembic revision` | `uv run -- alembic revision --autogenerate -m "slug"` |
| Rollback | `alembic downgrade` | `uv run -- alembic downgrade -1` |
| One-off tool | `uvx pkg` | `uvx pkg` (already non-interactive) |

**Never use `pip` directly.** It is not available in uv-managed environments and bypasses the lockfile.

### JavaScript/TypeScript — bun is the preferred runtime

| Action | BAD | GOOD |
|---|---|---|
| Init project | `bun init` | `bun init -y` |
| Install deps | `bun install` | `bun install --frozen-lockfile` (CI) |
| Add dep | `bun add pkg` | `bun add pkg` (non-interactive) |
| Run script | `npm run dev` | `bun run dev` |
| One-off tool | `npx pkg` | `bunx --bun pkg` |
| Run tests | `bun test --watch` | `bun test` (no watch flag) |
| Type-check | `tsc` | `bunx tsc --noEmit` |
| Biome | `biome check` | `bunx --bun @biomejs/biome check --write .` |

**Prefer `bun` over `npm`, `pnpm`, or `yarn` for all new frontend work.**

### npm (fallback only, for projects that are already npm-based)

| Action | BAD | GOOD |
|---|---|---|
| Init | `npm init` | `npm init -y` |
| Install | `npm install` | `npm install --yes` |
| Run | `npm run script` | `npm run script --if-present` |

### System packages

| Tool | BAD | GOOD |
|---|---|---|
| apt | `apt-get install pkg` | `apt-get install -y pkg` |
| apt | `apt-get upgrade` | `apt-get upgrade -y` |
| Homebrew | `brew install pkg` | `HOMEBREW_NO_AUTO_UPDATE=1 brew install pkg` |

---

## Git Operations

| Action | BAD | GOOD |
|---|---|---|
| Commit | `git commit` | `git commit -m "msg"` |
| Merge | `git merge branch` | `git merge --no-edit branch` |
| Pull | `git pull` | `git pull --no-edit` |
| Rebase | `git rebase -i` | `git rebase` (non-interactive only) |
| Add | `git add -p` | `git add .` or `git add <file>` |
| Log | `git log` | `git log --no-pager -n 20` |
| Diff | `git diff` | `git --no-pager diff` |

---

## System & File Commands

| Tool | BAD | GOOD |
|---|---|---|
| rm | `rm file` | `rm -f file` |
| cp | `cp -i a b` | `cp -f a b` |
| mv | `mv -i a b` | `mv -f a b` |
| unzip | `unzip file.zip` | `unzip -o file.zip` |
| ssh | `ssh host` | `ssh -o BatchMode=yes -o StrictHostKeyChecking=no host` |
| curl | `curl url` | `curl -fsSL url` |
| wget | `wget url` | `wget -q url` |

---

## Podman

| Action | BAD | GOOD |
|---|---|---|
| Run container | `podman run -it image` | `podman run image` |
| Exec in container | `podman exec -it container bash` | `podman exec container cmd` |
| Build | `podman build .` | `podman build --progress=plain .` |
| Compose up | `podman compose up` | `podman compose up -d` |
| Run command in service | `podman compose run app python` | `podman compose run --rm app uv run -- python -c "code"` |
| Follow logs | `podman compose logs app` | `podman compose logs --tail=50 app` |

---

## Banned Commands (always hang)

These will hang indefinitely — never use them:

- **Editors**: `vim`, `vi`, `nano`, `emacs`, `pico`, `ed`
- **Pagers**: `less`, `more`, `most`, `man`
- **Interactive git**: `git add -p`, `git rebase -i`, `git commit` (without `-m`)
- **REPLs**: bare `python`, bare `node`, bare `bun` (without a script or `-e`)
- **Interactive shells**: `bash -i`, `zsh -i`
- **Bare `pip`**: never, under any circumstances

---

## When a Command Has No Non-Interactive Flag

Use the "yes" pipe:
```bash
yes | ./install_script.sh
```

Use a heredoc:
```bash
./configure.sh <<EOF
option1
option2
EOF
```

Use a timeout as a last resort:
```bash
timeout 30 ./potentially_hanging_script.sh || echo "Timed out"
```

---

## Process Continuity

In non-interactive environments the agent must drive the workflow forward without stopping:

1. Execute command
2. Analyse output
3. State the next step explicitly: "Output is clean. Next: running tests."
4. Execute immediately — do not pause for confirmation unless the task is complete

Never stop after a tool execution to "wait for instructions" unless the task is finished or
a genuine decision point requires user input.
