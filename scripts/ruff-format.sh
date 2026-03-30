#!/usr/bin/env bash
# ruff-format.sh
#
# Three-step ruff pipeline that mirrors conform.nvim's Python formatter sequence:
#   ruff_fix              → ruff check --fix        (auto-fix violations)
#   ruff_format           → ruff format              (code style, replaces black)
#   ruff_organize_imports → ruff check --select I    (sort imports)
#
# Usage: ruff-format.sh <file>
#
# The --config pyproject.toml flag is used when a pyproject.toml exists in the
# current working directory (i.e. the project root), ensuring your full ruff
# rule set applies rather than ruff's defaults.

set -euo pipefail

FILE="$1"

if [[ -z "$FILE" ]]; then
  echo "Usage: ruff-format.sh <file>" >&2
  exit 1
fi

# Resolve config flag — only pass if pyproject.toml exists in cwd (project root)
CONFIG_FLAG=()
if [[ -f "pyproject.toml" ]]; then
  CONFIG_FLAG=(--config pyproject.toml)
fi

# Step 1: ruff_fix — auto-fix all fixable violations
# || true: non-zero exit means unfixable violations remain; that's fine here —
# the linter (pre-commit / CI) is responsible for reporting those, not the formatter.
ruff check --fix "${CONFIG_FLAG[@]}" "$FILE" || true

# Step 2: ruff_format — format code style (line length, quotes, trailing commas, etc.)
ruff format "${CONFIG_FLAG[@]}" "$FILE"

# Step 3: ruff_organize_imports — sort and deduplicate imports (I rule set)
# Run after format so any import grouping changes are formatted consistently.
ruff check --select I --fix "${CONFIG_FLAG[@]}" "$FILE" || true
