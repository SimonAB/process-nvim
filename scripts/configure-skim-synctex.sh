#!/bin/bash
# Configure Skim inverse search for VimTeX (no shell wrapper or nvr required).
#
# Skim → Preferences → Sync should show:
#   Preset:    Custom
#   Command:   <path-to-nvim>
#   Arguments: --headless -c "VimtexInverseSearch %line '%file'"

set -euo pipefail

NVIM="$(command -v nvim 2>/dev/null || true)"
if [[ -z "$NVIM" ]]; then
	echo "configure-skim-synctex: nvim not found in PATH" >&2
	exit 1
fi

ARGS='--headless -c "VimtexInverseSearch %line '\''%file'\''"'

defaults write -app Skim SKTeXEditorPreset -string ""
defaults write -app Skim SKTeXEditorCommand -string "$NVIM"
defaults write -app Skim SKTeXEditorArguments -string "$ARGS"

echo "Skim SyncTeX editor configured:"
echo "  Command:   $NVIM"
echo "  Arguments: $ARGS"
echo ""
echo "Open Skim → Preferences → Sync to confirm, then Cmd+Shift+click to test."
