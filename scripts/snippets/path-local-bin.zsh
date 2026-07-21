# Ensure ~/.local/bin is on PATH (Cursor Agent + Hermes shims).
#
# Sync: keep this snippet in ~/Documents/etc only if that README lists shell
# PATH helpers. Do not sync ~/.local/bin itself or Cursor Agent packages.
#
# Example (zsh), from an etc-managed ~/.zshrc:
#   source /path/to/process-nvim/scripts/snippets/path-local-bin.zsh

if [[ -d "${HOME}/.local/bin" ]]; then
	case ":${PATH}:" in
		*":${HOME}/.local/bin:"*) ;;
		*) export PATH="${HOME}/.local/bin:${PATH}" ;;
	esac
fi
