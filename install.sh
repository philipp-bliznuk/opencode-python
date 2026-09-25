#!/usr/bin/env bash
# Verify this repo lives at the OpenCode config dir and report missing tools.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEST="$(cd "${XDG_CONFIG_HOME:-$HOME/.config}" 2>/dev/null && pwd -P)/opencode"

if [ "$REPO" = "$DEST" ]; then
	echo "ok   repo at $DEST"
else
	echo "MISSING  repo must live at $DEST (symlinks break config hot-reload)"
	echo "         mv \"$REPO\" \"$DEST\" && ln -s \"$DEST\" \"$REPO\""
	exit 1
fi

missing=0
for tool in opencode uv ruff podman podman-compose shfmt; do
	if command -v "$tool" >/dev/null; then
		echo "ok   $tool"
	else
		echo "MISSING  $tool"
		missing=1
	fi
done
for tool in stylua trivy; do
	command -v "$tool" >/dev/null && echo "ok   $tool" || echo "opt  $tool (optional)"
done

echo
echo "Next: opencode  →  /connect Tavily (websearch)  →  put provider secrets in $DEST/.secrets/"
exit $missing
