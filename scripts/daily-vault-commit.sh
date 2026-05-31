#!/opt/homebrew/bin/zsh
# Daily auto-commit for the Obsidian vault git repository.
# Reduces gitsigns / git status overhead by keeping the working tree clean.
#
# Sync:
#   - This script is in dotfiles (config/nvim/scripts/) and syncs with your nvim/dotfiles repo.
#   - The launchd job is per machine: run `install` once on each Mac after dotfiles sync.
#
# Multi-device:
#   - Pulls/rebases before commit and pushes when a git remote exists.
#   - Skips if the tree is already clean (including after sync).
#   - Amends today's existing daily snapshot instead of creating a duplicate commit.
#   - Staggered run time per hostname when installing the launchd job.
#
# Usage:
#   ./scripts/daily-vault-commit.sh          # run once now
#   ./scripts/daily-vault-commit.sh install  # schedule daily via launchd (macOS)
#   ./scripts/daily-vault-commit.sh uninstall
#
# Environment:
#   OBSIDIAN_VAULT_PATH          Vault root (optional)
#   DAILY_VAULT_COMMIT_PUSH=0    Never push (overrides auto-push)
#   DAILY_VAULT_COMMIT_PUSH=1    Always push when a remote exists
#   DAILY_VAULT_COMMIT_HOUR=18   Base hour for daily run (install)
#   DAILY_VAULT_COMMIT_MINUTE=0  Base minute for daily run (install)

set -euo pipefail

readonly LABEL="com.simonab.daily-vault-commit"
readonly LOG_FILE="${HOME}/Library/Logs/daily-vault-commit.log"
readonly SCRIPT_PATH="${0:A}"
readonly PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"

resolve_vault_path() {
	if [[ -n "${OBSIDIAN_VAULT_PATH:-}" ]]; then
		print -r -- "${OBSIDIAN_VAULT_PATH:A}"
		return
	fi
	print -r -- "${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notebook"
}

daily_snapshot_message() {
	print -r -- "chore(vault): daily snapshot $(date '+%Y-%m-%d')"
}

log() {
	local timestamp
	timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
	print -r -- "[${timestamp}] $*" | tee -a "${LOG_FILE}"
}

has_git_remote() {
	[[ -n "$(git remote 2>/dev/null)" ]]
}

should_push() {
	if [[ "${DAILY_VAULT_COMMIT_PUSH:-}" == "0" ]]; then
		return 1
	fi
	if [[ "${DAILY_VAULT_COMMIT_PUSH:-}" == "1" ]]; then
		return 0
	fi
	has_git_remote
}

sync_with_remote() {
	if ! has_git_remote; then
		log "note: no git remote; local commit only"
		return 0
	fi

	local remote branch upstream
	remote="$(git remote | head -1)"
	branch="$(git branch --show-current 2>/dev/null || true)"
	upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

	if ! git fetch "${remote}" --quiet 2>>"${LOG_FILE}"; then
		log "warn: fetch failed; continuing with local commit only"
		return 0
	fi

	if [[ -z "${upstream}" && -n "${branch}" ]]; then
		if git ls-remote --exit-code --heads "${remote}" "${branch}" >/dev/null 2>&1; then
			git branch --set-upstream-to="${remote}/${branch}" "${branch}" 2>>"${LOG_FILE}" || true
			upstream="${remote}/${branch}"
		fi
	fi

	if [[ -z "${upstream}" ]]; then
		log "note: no upstream branch; skipping pull"
		return 0
	fi

	if ! git pull --rebase --autostash --quiet 2>>"${LOG_FILE}"; then
		log "error: pull --rebase failed; resolve conflicts manually"
		return 1
	fi

	return 0
}

install_schedule_time() {
	local base_hour="${DAILY_VAULT_COMMIT_HOUR:-18}"
	local base_minute="${DAILY_VAULT_COMMIT_MINUTE:-0}"
	# Spread Macs by hostname so two machines rarely commit at the same instant.
	local host_offset=$(( $(cksum <<< "$(hostname)" | cut -d' ' -f1) % 45 ))
	local minute=$(( base_minute + host_offset ))
	local hour=$(( base_hour ))

	while (( minute >= 60 )); do
		minute=$(( minute - 60 ))
		hour=$(( hour + 1 ))
	done

	while (( hour >= 24 )); do
		hour=$(( hour - 24 ))
	done

	print -r -- "${hour} ${minute}"
}

run_commit() {
	local vault_path message head_message
	vault_path="$(resolve_vault_path)"
	message="$(daily_snapshot_message)"

	if [[ ! -d "${vault_path}/.git" ]]; then
		log "skip: not a git repository: ${vault_path}"
		return 0
	fi

	cd "${vault_path}"

	if ! sync_with_remote; then
		return 1
	fi

	if [[ -z "$(git status --porcelain)" ]]; then
		log "skip: working tree clean (${vault_path})"
		return 0
	fi

	git add -A

	if git diff --cached --quiet; then
		log "skip: nothing staged after git add (${vault_path})"
		return 0
	fi

	head_message="$(git log -1 --format=%s 2>/dev/null || true)"
	if [[ "${head_message}" == "${message}" ]]; then
		git commit --amend --no-edit
		log "amended: ${message} (${vault_path})"
	else
		git commit -m "${message}"
		log "committed: ${message} (${vault_path})"
	fi

	if should_push; then
		local remote
		remote="$(git remote | head -1)"
		if git push "${remote}" --quiet 2>>"${LOG_FILE}"; then
			log "pushed to ${remote} (${vault_path})"
		else
			log "error: push to ${remote} failed"
			return 1
		fi
	fi
}

write_plist() {
	local schedule hour minute
	schedule="$(install_schedule_time)"
	hour="${schedule%% *}"
	minute="${schedule##* }"

	mkdir -p "${HOME}/Library/LaunchAgents"
	cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>${LABEL}</string>
	<key>ProgramArguments</key>
	<array>
		<string>/opt/homebrew/bin/zsh</string>
		<string>${SCRIPT_PATH}</string>
	</array>
	<key>StartCalendarInterval</key>
	<dict>
		<key>Hour</key>
		<integer>${hour}</integer>
		<key>Minute</key>
		<integer>${minute}</integer>
	</dict>
	<key>StandardOutPath</key>
	<string>${LOG_FILE}</string>
	<key>StandardErrorPath</key>
	<string>${LOG_FILE}</string>
</dict>
</plist>
EOF
}

install_launchd() {
	local schedule hour minute
	write_plist
	schedule="$(install_schedule_time)"
	hour="${schedule%% *}"
	minute="${schedule##* }"
	launchctl bootout "gui/${UID}" "${PLIST_PATH}" 2>/dev/null || true
	launchctl bootstrap "gui/${UID}" "${PLIST_PATH}"
	log "installed: daily run at ${hour}:$(printf '%02d' "${minute}") on $(hostname)"
	print -r -- "LaunchAgent: ${PLIST_PATH}"
	print -r -- "Log file:   ${LOG_FILE}"
}

uninstall_launchd() {
	if [[ -f "${PLIST_PATH}" ]]; then
		launchctl bootout "gui/${UID}" "${PLIST_PATH}" 2>/dev/null || true
		rm -f "${PLIST_PATH}"
		log "uninstalled launchd job"
	else
		print -r -- "Not installed."
	fi
}

case "${1:-run}" in
	run)
		mkdir -p "$(dirname "${LOG_FILE}")"
		run_commit
		;;
	install)
		mkdir -p "$(dirname "${LOG_FILE}")"
		install_launchd
		;;
	uninstall)
		uninstall_launchd
		;;
	*)
		print -r -- "Usage: $0 [run|install|uninstall]" >&2
		exit 1
		;;
esac
