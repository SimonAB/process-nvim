#!/usr/bin/env bash
# Configure Zathura inverse search for VimTeX (Linux SyncTeX counterpart to Skim).
#
# Writes ~/.config/zathura/zathurarc so Ctrl+click in Zathura runs:
#   nvim --headless -c "VimtexInverseSearch %{line}:%{column} '%{input}'"
#
# macOS Skim setup is separate: scripts/configure-skim-synctex.sh
# VimTeX also passes -x when it starts Zathura; this file covers PDFs opened
# outside VimTeX and acts as a durable fallback.

set -euo pipefail

if [[ "$(uname -s)" == "Darwin" ]]; then
	echo "configure-zathura-synctex: this machine is macOS; use configure-skim-synctex.sh instead." >&2
	exit 1
fi

NVIM="$(command -v nvim 2>/dev/null || true)"
if [[ -z "$NVIM" ]]; then
	echo "configure-zathura-synctex: nvim not found in PATH" >&2
	exit 1
fi

if ! command -v zathura >/dev/null 2>&1; then
	echo "configure-zathura-synctex: zathura not found; install with: sudo pacman -S zathura zathura-pdf-mupdf" >&2
	exit 1
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zathura"
CONFIG_FILE="$CONFIG_DIR/zathurarc"
MARKER_BEGIN="# >>> process-nvim vimtex synctex >>>"
MARKER_END="# <<< process-nvim vimtex synctex <<<"

# Literal line written into zathurarc (escaped quotes match Zathura's expected form).
EDITOR_LINE="set synctex-editor-command \"$NVIM --headless -c \\\"VimtexInverseSearch %{line}:%{column} '%{input}'\\\"\""

mkdir -p "$CONFIG_DIR"

write_block() {
	printf '%s\n' \
		"$MARKER_BEGIN" \
		"# Managed by ~/.config/nvim/scripts/configure-zathura-synctex.sh — do not edit by hand." \
		"set synctex true" \
		"# Keep Neovim/Ghostty focused on SyncTeX forward search (\\lv); mirrors Skim activate=0." \
		"set dbus-raise-window false" \
		"$EDITOR_LINE" \
		"$MARKER_END"
}

tmp="$(mktemp)"
if [[ -f "$CONFIG_FILE" ]] && grep -qF "$MARKER_BEGIN" "$CONFIG_FILE"; then
	# Replace the managed block in place.
	awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
		$0 == begin { skip = 1; next }
		$0 == end { skip = 0; next }
		!skip { print }
	' "$CONFIG_FILE" >"$tmp"
	# Append a blank line before the block if the file is non-empty and does not end with one.
	if [[ -s "$tmp" ]] && [[ "$(tail -c 1 "$tmp" | wc -l)" -eq 0 ]]; then
		printf '\n' >>"$tmp"
	elif [[ -s "$tmp" ]]; then
		printf '\n' >>"$tmp"
	fi
	write_block >>"$tmp"
	mv "$tmp" "$CONFIG_FILE"
else
	if [[ -f "$CONFIG_FILE" ]]; then
		cat "$CONFIG_FILE" >"$tmp"
		printf '\n' >>"$tmp"
	fi
	write_block >>"$tmp"
	mv "$tmp" "$CONFIG_FILE"
fi

echo "Zathura SyncTeX editor configured:"
echo "  File:    $CONFIG_FILE"
echo "  Command: $NVIM --headless -c \"VimtexInverseSearch %{line}:%{column} '%{input}'\""
echo ""
echo "In Neovim (Linux): \\lv forward search; in Zathura: Ctrl+click for inverse search."
echo "macOS Skim affordances are unchanged (configure-skim-synctex.sh)."
