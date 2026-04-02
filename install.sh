#!/usr/bin/env bash
# install.sh — Set up opencode-config
#
# What this script does:
#   1. Checks for all required prerequisites; offers to install missing ones
#      via Homebrew.
#   2. Backs up any existing ~/.config/opencode directory (unless it is already
#      a symlink pointing at this repo).
#   3. Creates a symlink: ~/.config/opencode → this repo.
#   4. Makes scripts/ruff-format.sh executable.
#   5. Verifies the shell-strategy instructions file is present.
#
# Plugins (@tarquinen/opencode-dcp, opencode-handoff) are loaded
# automatically by OpenCode at startup from the "plugin" array in opencode.jsonc
# — no manual npm install is required here.

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────

RESET="\033[0m"
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
DIM="\033[2m"

ok() { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
err() { echo -e "  ${RED}✗${RESET}  $*"; }
info() { echo -e "  ${CYAN}→${RESET}  $*"; }
dim() { echo -e "  ${DIM}$*${RESET}"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

MISSING_TOOLS=()
INSTALLED_TOOLS=()
SKIPPED_TOOLS=()

# Print a section header.
section() {
	echo ""
	echo -e "${BOLD}$*${RESET}"
	echo -e "${DIM}$(printf '─%.0s' {1..50})${RESET}"
}

# Check if a command exists.
has() { command -v "$1" &>/dev/null; }

# Return the version of a command (first line of --version output).
version_of() {
	"$1" --version 2>&1 | head -1 | sed 's/[^0-9.]//g' | head -c 20
}

# Prompt the user to install a tool via Homebrew.
# Usage: ask_install <display_name> <brew_package> <purpose> [optional]
ask_install() {
	local name="$1"
	local pkg="$2"
	local purpose="$3"
	local optional="${4:-}"

	if [ -n "$optional" ]; then
		warn "${name} — not found ${DIM}(${purpose}, optional)${RESET}"
	else
		err "${name} — not found ${DIM}(${purpose})${RESET}"
	fi

	echo -ne "     Install via Homebrew? ${DIM}[y/N]${RESET} "
	read -r answer </dev/tty
	echo ""

	if [[ "$answer" =~ ^[Yy]$ ]]; then
		if ! has brew; then
			err "Homebrew not found. Install it from https://brew.sh, then re-run this script."
			MISSING_TOOLS+=("$name")
			return
		fi
		info "Installing ${name}..."
		if brew install "$pkg" &>/dev/null; then
			local ver
			ver=$(version_of "$name" 2>/dev/null || echo "installed")
			ok "${name} ${DIM}${ver}${RESET} ${DIM}(installed)${RESET}"
			INSTALLED_TOOLS+=("$name")
		else
			err "Failed to install ${name} via Homebrew."
			MISSING_TOOLS+=("$name")
		fi
	else
		if [ -n "$optional" ]; then
			dim "Skipped. Install later with: brew install ${pkg}"
			SKIPPED_TOOLS+=("$name")
		else
			MISSING_TOOLS+=("$name")
		fi
	fi
}

# Check a required tool; offer to install if missing.
# Usage: check_tool <command> <display_name> <brew_package> <purpose>
check_tool() {
	local cmd="$1"
	local name="$2"
	local pkg="$3"
	local purpose="$4"

	if has "$cmd"; then
		local ver
		ver=$(version_of "$cmd" 2>/dev/null || echo "")
		ok "${name} ${DIM}${ver}${RESET}"
	else
		ask_install "$name" "$pkg" "$purpose"
	fi
}

# Check an optional tool; offer to install if missing but don't block.
# Usage: check_optional <command> <display_name> <brew_package> <purpose>
check_optional() {
	local cmd="$1"
	local name="$2"
	local pkg="$3"
	local purpose="$4"

	if has "$cmd"; then
		local ver
		ver=$(version_of "$cmd" 2>/dev/null || echo "")
		ok "${name} ${DIM}${ver}${RESET}"
	else
		ask_install "$name" "$pkg" "$purpose" "optional"
	fi
}

# ── Script entry point ────────────────────────────────────────────────────────

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.config/opencode"

echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  OpenCode Config — Install${RESET}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"

# ── 1. Prerequisites ──────────────────────────────────────────────────────────

section "Checking prerequisites..."

# opencode itself
check_tool "opencode" "opencode" "sst/tap/opencode" "the AI agent"

# Python toolchain
check_tool "uv" "uv" "uv" "Python package manager"
check_tool "ruff" "ruff" "ruff" "Python linter and formatter"

# uvx is bundled with uv — verify it works
if has uv; then
	if uv tool run --help &>/dev/null 2>&1; then
		ok "uvx ${DIM}(via uv)${RESET}"
	else
		warn "uvx — uv is installed but 'uv tool run' failed. Try: uv self update"
	fi
fi

# Node/npx — required for npm plugins and prettier
if has node; then
	local_ver=$(node --version 2>/dev/null || echo "")
	ok "node ${DIM}${local_ver}${RESET}"
	if has npx; then
		ok "npx ${DIM}(via node)${RESET}"
	else
		warn "npx not found — it should ship with node. Try: npm install -g npm"
	fi
else
	ask_install "node" "node" "npm plugins and prettier"
fi

# Bun — required for custom TypeScript tools and frontend container image
check_tool "bun" "bun" "bun" "custom TypeScript tools + frontend runtime"

# Podman — container runtime (replaces Docker)
check_tool "podman" "podman" "podman" "container runtime (build + run containers)"

# podman-compose — Compose support for Podman
check_tool "podman-compose" "podman-compose" "podman-compose" "Podman Compose (compose.yml support)"

# shfmt — shell script formatter
check_tool "shfmt" "shfmt" "shfmt" "shell script formatter"

# trivy — container image CVE scanner (optional but recommended before production pushes)
check_optional "trivy" "trivy" "trivy" "container image CVE scanning (optional)"

# ── Abort if required tools are still missing ─────────────────────────────────

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
	echo ""
	err "The following required tools are missing:"
	for t in "${MISSING_TOOLS[@]}"; do
		dim "  • ${t}"
	done
	echo ""
	err "Install them and re-run this script."
	exit 1
fi

# ── 2. Symlink ~/.config/opencode → this repo ─────────────────────────────────

section "Setting up symlink..."

mkdir -p "$HOME/.config"

if [ -L "$DEST" ]; then
	current_target="$(readlink "$DEST")"
	if [ "$current_target" = "$REPO_DIR" ]; then
		ok "${DEST} ${DIM}→ ${REPO_DIR} (already correct)${RESET}"
	else
		BACKUP="${DEST}.backup.$(date +%Y%m%d_%H%M%S)"
		warn "Existing symlink points elsewhere: ${DIM}${current_target}${RESET}"
		info "Backing up to ${BACKUP}"
		mv "$DEST" "$BACKUP"
		ln -s "$REPO_DIR" "$DEST"
		ok "${DEST} ${DIM}→ ${REPO_DIR}${RESET}"
		info "Backup saved to: ${DIM}${BACKUP}${RESET}"
	fi
elif [ -d "$DEST" ]; then
	BACKUP="${DEST}.backup.$(date +%Y%m%d_%H%M%S)"
	warn "Existing directory found at ${DEST}"
	info "Backing up to ${BACKUP}"
	mv "$DEST" "$BACKUP"
	ln -s "$REPO_DIR" "$DEST"
	ok "${DEST} ${DIM}→ ${REPO_DIR}${RESET}"
	info "Backup saved to: ${DIM}${BACKUP}${RESET}"
elif [ -e "$DEST" ]; then
	err "${DEST} exists but is not a directory or symlink. Remove it manually and re-run."
	exit 1
else
	ln -s "$REPO_DIR" "$DEST"
	ok "${DEST} ${DIM}→ ${REPO_DIR}${RESET}"
fi

# ── 3. Make scripts executable ────────────────────────────────────────────────

section "Making scripts executable..."

chmod +x "${REPO_DIR}/scripts/ruff-format.sh"
ok "scripts/ruff-format.sh"

# ── 4. Verify plugin assets ───────────────────────────────────────────────────

section "Verifying plugin assets..."

SHELL_STRATEGY="${REPO_DIR}/plugins/shell-strategy/shell_strategy.md"
if [ -f "$SHELL_STRATEGY" ]; then
	ok "plugins/shell-strategy/shell_strategy.md"
else
	warn "plugins/shell-strategy/shell_strategy.md not found"
	info "This file should be in the repository. Try: git pull"
fi

# ── 5. pg-mcp-server ──────────────────────────────────────────────────────────

section "Checking pg-mcp-server (PostgreSQL MCP)..."

# pg-mcp-server is a Python MCP server for live PostgreSQL analysis.
# It runs as a persistent SSE server — start it before using the db agent.
# It uses uvx (bundled with uv) and requires no separate install.
if has uv; then
	ok "pg-mcp-server available via uvx (bundled with uv)"
	dim "  Start manually:"
	dim "    PG_MCP_DATABASE_URL=postgresql://user:pass@localhost:5433/dbname \\"
	dim "      uvx stuzero/pg-mcp-server"
	dim "  Or in a project with the Makefile target: make pg_mcp_start"
	dim "  OpenCode db agent expects it at: http://localhost:8000/sse"
	dim "  Server runs in read-only mode by default — safe during dev sessions."
else
	warn "uv not installed — pg-mcp-server requires uv"
	info "Install uv first, then pg-mcp-server will be available automatically"
fi

# ── 6. Summary ────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Done!${RESET}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${RESET}"

if [ ${#INSTALLED_TOOLS[@]} -gt 0 ]; then
	echo ""
	echo -e "  ${BOLD}Installed:${RESET}"
	for t in "${INSTALLED_TOOLS[@]}"; do
		dim "  • ${t}"
	done
fi

if [ ${#SKIPPED_TOOLS[@]} -gt 0 ]; then
	echo ""
	echo -e "  ${BOLD}Skipped (optional):${RESET}"
	for t in "${SKIPPED_TOOLS[@]}"; do
		dim "  • ${t}"
	done
fi

echo ""
echo -e "  ${BOLD}Plugins (auto-loaded by OpenCode at startup):${RESET}"
dim "  @tarquinen/opencode-dcp  — context pruning"
dim "  opencode-handoff         — session handoff prompts"

echo ""
echo -e "  ${BOLD}PostgreSQL MCP (pg-mcp-server):${RESET}"
dim "  Start:  PG_MCP_DATABASE_URL=<conn_str> uvx stuzero/pg-mcp-server"
dim "  Or:     make pg_mcp_start  (in projects with that Makefile target)"
dim "  Stop:   make pg_mcp_stop  /  pkill -f pg-mcp-server"
dim "  The db agent connects to: http://localhost:8000/sse"
dim "  See README.md for full usage instructions."

echo ""
echo -e "  ${BOLD}Optional environment flags:${RESET}"
dim "  OPENCODE_ENABLE_EXA=1 opencode                  # web search via Exa AI"
dim "  OPENCODE_EXPERIMENTAL_LSP_TOOL=true opencode    # go-to-definition, find-references"

echo ""
echo -e "  ${BOLD}To use Neovim for /editor and /export commands:${RESET}"
dim "  Add to your shell profile: export EDITOR=nvim"

echo ""
echo -e "  ${BOLD}To update:${RESET}"
dim "  cd ${REPO_DIR} && git pull"
echo ""
