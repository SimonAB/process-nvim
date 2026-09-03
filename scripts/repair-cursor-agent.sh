#!/usr/bin/env bash
# Repair Cursor Agent CLI shims under ~/.local/bin.
#
# Hermes (and similar tools) also install into ~/.local/bin and may replace or
# orphan the `agent` / `cursor-agent` symlinks that point at the versioned
# package in ~/.local/share/cursor-agent/versions/. When those shims are wrong,
# the wrapper can fail early (e.g. `dirname: command not found` under an empty
# PATH) or invoke the wrong Node binary.
#
# Sync policy (see ~/Documents/etc/README.md):
#   - Syncable: this script and CodeCompanion config via Documents/etc → nvim
#   - Not syncable: ~/.local/bin shims, ~/.local/share/cursor-agent packages,
#     ~/.hermes installs, or agent auth/state under ~/.cursor
#
# Usage:
#   ~/.config/nvim/scripts/repair-cursor-agent.sh           # diagnose + repair
#   ~/.config/nvim/scripts/repair-cursor-agent.sh --check   # diagnose only

set -euo pipefail

readonly LOCAL_BIN="${HOME}/.local/bin"
readonly VERSIONS_DIR="${HOME}/.local/share/cursor-agent/versions"
readonly ETC_ROOT="${HOME}/Documents/etc"
readonly ETC_README="${ETC_ROOT}/README.md"
CHECK_ONLY=0

if [[ "${1:-}" == "--check" ]]; then
	CHECK_ONLY=1
fi

# Print a labelled diagnostic line.
print_info() {
	printf '▸ %s\n' "$*"
}

# Print a success line.
print_ok() {
	printf '✓ %s\n' "$*"
}

# Print a warning line.
print_warn() {
	printf '! %s\n' "$*" >&2
}

# Describe a path: missing, symlink target, or regular file.
describe_path() {
	local path="$1"
	if [[ ! -e "${path}" && ! -L "${path}" ]]; then
		printf 'missing'
		return
	fi
	if [[ -L "${path}" ]]; then
		printf 'symlink -> %s' "$(readlink "${path}")"
		return
	fi
	printf 'file (%s bytes)' "$(wc -c < "${path}" | tr -d ' ')"
}

# Return the newest versioned cursor-agent executable, if any.
newest_versioned_agent() {
	local candidate=""
	local best=""

	if [[ ! -d "${VERSIONS_DIR}" ]]; then
		return 1
	fi

	# Lexicographic order matches the dated version directory names.
	while IFS= read -r candidate; do
		[[ -z "${candidate}" ]] && continue
		[[ "$(basename "${candidate}")" == .tmp-* ]] && continue
		if [[ -x "${candidate}/cursor-agent" ]]; then
			best="${candidate}/cursor-agent"
		fi
	done < <(find "${VERSIONS_DIR}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort)

	if [[ -n "${best}" ]]; then
		printf '%s\n' "${best}"
		return 0
	fi
	return 1
}

# Summarise Documents/etc sync guidance without inventing an allowlist.
note_etc_sync_policy() {
	print_info "Dotfiles sync root: ${ETC_ROOT}"
	if [[ -f "${ETC_README}" ]]; then
		print_ok "Found ${ETC_README} — only sync paths listed there"
	else
		print_warn "No ${ETC_README} yet; do not copy ~/.local or ~/.hermes into etc"
	fi

	# Common layout from this repo's scripts: config/nvim inside Documents/etc.
	if [[ -e "${ETC_ROOT}/config/nvim" ]]; then
		print_ok "Synced nvim config path present: ${ETC_ROOT}/config/nvim"
	fi

	print_info "Keep machine-local (do not sync):"
	print_info "  ${LOCAL_BIN}/{agent,cursor-agent,node}"
	print_info "  ${VERSIONS_DIR}/"
	print_info "  ${HOME}/.hermes/"
	print_info "  ${HOME}/.cursor/projects/ and auth/state"
	print_info "Syncable via etc (when listed in the README):"
	print_info "  nvim config (includes this repair script + CodeCompanion setup)"
	print_info "  shell PATH snippets that add ~/.local/bin"
}

echo ""
echo "Cursor Agent repair"
echo ""

note_etc_sync_policy
echo ""

print_info "PATH includes ~/.local/bin: $([[ ":${PATH}:" == *":${LOCAL_BIN}:"* ]] && echo yes || echo no)"
print_info "agent shim:        $(describe_path "${LOCAL_BIN}/agent")"
print_info "cursor-agent shim: $(describe_path "${LOCAL_BIN}/cursor-agent")"
print_info "Hermes node shim:  $(describe_path "${LOCAL_BIN}/node")"

VERSIONED="$(newest_versioned_agent || true)"
if [[ -n "${VERSIONED}" ]]; then
	print_ok "Versioned agent found: ${VERSIONED}"
else
	print_warn "No versioned agent under ${VERSIONS_DIR}"
fi

# Ensure core utilities are visible for any follow-up wrapper execution.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${LOCAL_BIN}:${PATH}"

if [[ "${CHECK_ONLY}" -eq 1 ]]; then
	if command -v agent >/dev/null 2>&1; then
		print_ok "agent is on PATH: $(command -v agent)"
	else
		print_warn "agent is not on PATH"
	fi
	exit 0
fi

# Prefer repairing shims from an existing versioned install (common after Hermes
# rewrites ~/.local/bin). Only download when the package tree is missing.
if [[ -z "${VERSIONED}" ]]; then
	print_info "Reinstalling Cursor Agent via https://cursor.com/install ..."
	curl -fsS https://cursor.com/install | bash
	VERSIONED="$(newest_versioned_agent)"
else
	print_info "Reusing existing versioned install (skip download)"
fi

if [[ -z "${VERSIONED}" || ! -x "${VERSIONED}" ]]; then
	print_warn "No usable cursor-agent binary found after repair attempt"
	exit 1
fi

mkdir -p "${LOCAL_BIN}"
rm -f "${LOCAL_BIN}/agent" "${LOCAL_BIN}/cursor-agent"
ln -s "${VERSIONED}" "${LOCAL_BIN}/agent"
ln -s "${VERSIONED}" "${LOCAL_BIN}/cursor-agent"
print_ok "Restored symlinks:"
print_ok "  ${LOCAL_BIN}/agent -> ${VERSIONED}"
print_ok "  ${LOCAL_BIN}/cursor-agent -> ${VERSIONED}"

if [[ -L "${LOCAL_BIN}/node" ]]; then
	NODE_TARGET="$(readlink "${LOCAL_BIN}/node")"
	if [[ "${NODE_TARGET}" == *hermes* ]]; then
		print_warn "Left Hermes node shim in place: ${LOCAL_BIN}/node -> ${NODE_TARGET}"
		print_warn "Cursor Agent uses its bundled node via the versioned package; this is fine."
	fi
fi

print_info "Smoke test: agent --help"
if agent --help >/dev/null 2>&1; then
	print_ok "agent --help succeeded"
else
	print_warn "agent --help failed; run 'agent login' after checking network/auth"
	exit 1
fi

echo ""
print_ok "Repair complete. Machine-local shims only — sync remains via ${ETC_ROOT}."
print_ok "In Neovim, reopen CodeCompanion chat (:CodeCompanionChat)."
echo ""
