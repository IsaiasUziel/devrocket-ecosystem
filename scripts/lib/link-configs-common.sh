#!/bin/sh

set -eu

if [ -z "${LINK_CONFIGS_SCRIPT_DIR:-}" ] || [ -z "${LINK_CONFIGS_REPO_ROOT:-}" ]; then
	printf 'ERROR link-configs-common.sh requires LINK_CONFIGS_SCRIPT_DIR and LINK_CONFIGS_REPO_ROOT\n' >&2
	exit 1
fi

LINK_STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/devrocket-ecosystem"
LINK_STATE_FILE="$LINK_STATE_ROOT/link-configs.json"
LINK_BACKUP_ROOT="$LINK_STATE_ROOT/link-configs-backups"

all_target_ids() {
	printf '%s\n' nvim tmux ghostty-config ghostty-assets ghostty-themes ghostty-shaders
}

is_supported_target() {
	case "$1" in
		nvim|tmux|ghostty-config|ghostty-assets|ghostty-themes|ghostty-shaders) return 0 ;;
		*) return 1 ;;
	esac
}

target_kind() {
	case "$1" in
		nvim|ghostty-assets|ghostty-themes|ghostty-shaders) printf 'dir\n' ;;
		tmux|ghostty-config) printf 'file\n' ;;
		*) return 1 ;;
	esac
}

target_source() {
	# Keep this subset aligned with internal/config/components.go.
	# Developer link mode intentionally mirrors only the approved local-config targets.
	case "$1" in
		nvim) printf 'configs/nvim\n' ;;
		tmux) printf 'configs/tmux/tmux.conf\n' ;;
		ghostty-config) printf 'configs/ghostty/config\n' ;;
		ghostty-assets) printf 'configs/ghostty/assets\n' ;;
		ghostty-themes) printf 'configs/ghostty/themes\n' ;;
		ghostty-shaders) printf 'configs/ghostty/shaders\n' ;;
		*) return 1 ;;
	esac
}

target_path() {
	case "$1" in
		nvim) printf '%s\n' "$HOME/.config/nvim" ;;
		tmux) printf '%s\n' "$HOME/.tmux.conf" ;;
		ghostty-config) printf '%s\n' "$HOME/.config/ghostty/config" ;;
		ghostty-assets) printf '%s\n' "$HOME/.config/ghostty/assets" ;;
		ghostty-themes) printf '%s\n' "$HOME/.config/ghostty/themes" ;;
		ghostty-shaders) printf '%s\n' "$HOME/.config/ghostty/shaders" ;;
		*) return 1 ;;
	esac
}

target_expected_link() {
	printf '%s/%s\n' "$LINK_CONFIGS_REPO_ROOT" "$(target_source "$1")"
}

log_info() {
	printf 'INFO %s\n' "$*"
}

log_ok() {
	printf 'OK %s\n' "$*"
}

log_warn() {
	printf 'WARN %s\n' "$*"
}

fail() {
	printf 'ERROR %s\n' "$*" >&2
	exit 1
}

ensure_state_root() {
	if ! mkdir -p "$LINK_STATE_ROOT" "$LINK_BACKUP_ROOT"; then
		fail "state directory is not writable: $LINK_STATE_ROOT"
	fi
}

json_escape() {
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

json_unescape() {
	printf '%s' "$1" | sed 's/\\"/"/g; s/\\\\/\\/g'
}

append_record() {
	existing=${1-}
	record=${2-}
	if [ -z "$record" ]; then
		printf '%s' "$existing"
	elif [ -z "$existing" ]; then
		printf '%s' "$record"
	else
		printf '%s\n%s' "$existing" "$record"
	fi
}

record_for_id() {
	records=${2-}
	if [ -z "$records" ]; then
		return 0
	fi
	printf '%s\n' "$records" | while IFS='|' read -r rid rkind rsource rtarget rexpected rbackup; do
		if [ "$rid" = "$1" ]; then
			printf '%s|%s|%s|%s|%s|%s\n' "$rid" "$rkind" "$rsource" "$rtarget" "$rexpected" "$rbackup"
			break
		fi
	done
}

selected_targets() {
	if [ "$#" -eq 0 ]; then
		all_target_ids
		return 0
	fi
	for target_id in "$@"; do
		if ! is_supported_target "$target_id"; then
			fail "unsupported target: $target_id"
		fi
		printf '%s\n' "$target_id"
	done
}

require_repo_sources() {
	for target_id in "$@"; do
		source_path="$LINK_CONFIGS_REPO_ROOT/$(target_source "$target_id")"
		if [ ! -e "$source_path" ]; then
			fail "missing repo source: $source_path"
		fi
		case "$target_id" in
			nvim)
				if [ ! -d "$source_path" ]; then
					fail "expected directory source for $target_id: $source_path"
				fi
				;;
			ghostty-assets|ghostty-themes|ghostty-shaders)
				if [ ! -d "$source_path" ]; then
					fail "expected directory source for $target_id: $source_path"
				fi
				;;
			*)
				if [ ! -f "$source_path" ] && [ ! -d "$source_path" ]; then
					fail "expected source path for $target_id: $source_path"
				fi
				;;
		esac
	done
}

readlink_target() {
	readlink "$1"
}

timestamp_utc() {
	date -u '+%Y-%m-%dT%H:%M:%SZ'
}

timestamp_dir() {
	date -u '+%Y-%m-%d_%H%M%S'
}

ensure_parent_dir() {
	parent_dir=$(dirname "$1")
	if ! mkdir -p "$parent_dir"; then
		fail "failed to create parent directory: $parent_dir"
	fi
}

ensure_backup_dir() {
	backup_dir=${1-}
	if [ -z "$backup_dir" ]; then
		backup_dir="$LINK_BACKUP_ROOT/$(timestamp_dir)"
	fi
	if ! mkdir -p "$backup_dir"; then
		fail "failed to create backup directory: $backup_dir"
	fi
	printf '%s\n' "$backup_dir"
}

remove_empty_parents() {
	path=$1
	while :; do
		parent_dir=$(dirname "$path")
		case "$parent_dir" in
			"$HOME"|"$HOME/.config"|/) return 0 ;;
		esac
		if rmdir "$parent_dir" 2>/dev/null; then
			path=$parent_dir
			continue
		fi
		return 0
	done
}

STATE_PRESENT=0
STATE_VERSION=''
STATE_REPO_ROOT=''
STATE_LINKED_AT=''
STATE_BACKUP_DIR=''
STATE_RECORDS=''

load_state_if_present() {
	STATE_PRESENT=0
	STATE_VERSION=''
	STATE_REPO_ROOT=''
	STATE_LINKED_AT=''
	STATE_BACKUP_DIR=''
	STATE_RECORDS=''

	if [ ! -f "$LINK_STATE_FILE" ]; then
		return 0
	fi

	STATE_PRESENT=1
	STATE_VERSION=$(sed -n 's/^[[:space:]]*"version": \([0-9][0-9]*\),$/\1/p' "$LINK_STATE_FILE")
	STATE_REPO_ROOT=$(sed -n 's/^[[:space:]]*"repo_root": "\(.*\)",$/\1/p' "$LINK_STATE_FILE" | head -n 1)
	STATE_LINKED_AT=$(sed -n 's/^[[:space:]]*"linked_at": "\(.*\)",$/\1/p' "$LINK_STATE_FILE" | head -n 1)
	STATE_BACKUP_DIR=$(sed -n 's/^[[:space:]]*"backup_dir": "\(.*\)",$/\1/p' "$LINK_STATE_FILE" | head -n 1)

	if [ -z "$STATE_VERSION" ] || [ -z "$STATE_REPO_ROOT" ] || [ -z "$STATE_LINKED_AT" ] || [ -z "$STATE_BACKUP_DIR" ]; then
		fail "invalid state file: $LINK_STATE_FILE"
	fi

	parsed_records=''
	while IFS= read -r line; do
		case "$line" in
			*'"id"'*)
				parsed=$(printf '%s\n' "$line" | sed -n 's/^[[:space:]]*{"id":"\([^"]*\)","kind":"\([^"]*\)","source":"\([^"]*\)","target":"\([^"]*\)","expected_link":"\([^"]*\)","backup":"\([^"]*\)"}[,]*$/\1|\2|\3|\4|\5|\6/p')
				if [ -z "$parsed" ]; then
					fail "invalid target entry in state file: $LINK_STATE_FILE"
				fi
				parsed_records=$(append_record "$parsed_records" "$(json_unescape "$parsed")")
				;;
		esac
	done < "$LINK_STATE_FILE"

	STATE_REPO_ROOT=$(json_unescape "$STATE_REPO_ROOT")
	STATE_LINKED_AT=$(json_unescape "$STATE_LINKED_AT")
	STATE_BACKUP_DIR=$(json_unescape "$STATE_BACKUP_DIR")
	STATE_RECORDS=$parsed_records

	if [ "$STATE_VERSION" != '1' ]; then
		fail "invalid state version: $STATE_VERSION"
	fi
	if [ "$STATE_REPO_ROOT" != "$LINK_CONFIGS_REPO_ROOT" ]; then
		fail "repo root mismatch: state=$STATE_REPO_ROOT current=$LINK_CONFIGS_REPO_ROOT"
	fi

	for target_id in $(all_target_ids); do
		record=$(record_for_id "$target_id" "$STATE_RECORDS")
		if [ -z "$record" ]; then
			continue
		fi
		IFS='|' read -r rid rkind rsource rtarget rexpected rbackup <<EOF
$record
EOF
		if [ "$rsource" != "$(target_source "$target_id")" ] || [ "$rtarget" != "$(target_path "$target_id")" ] || [ "$rexpected" != "$(target_expected_link "$target_id")" ]; then
			fail "invalid or stale state for target: $target_id"
		fi
		expected_kind=$(target_kind "$target_id")
		if [ "$rkind" != "$expected_kind" ]; then
			fail "invalid kind in state for target: $target_id"
		fi
		if [ -n "$rbackup" ] && [ ! -e "$rbackup" ]; then
			fail "missing recorded backup for target: $target_id"
		fi
	done
}

write_state_file() {
	linked_at=$1
	backup_dir=$2
	records=${3-}
	ensure_state_root
	tmp_file="$LINK_STATE_ROOT/.link-configs.$$.tmp"
	{
		printf '{\n'
		printf '  "version": 1,\n'
		printf '  "repo_root": "%s",\n' "$(json_escape "$LINK_CONFIGS_REPO_ROOT")"
		printf '  "linked_at": "%s",\n' "$(json_escape "$linked_at")"
		printf '  "backup_dir": "%s",\n' "$(json_escape "$backup_dir")"
		printf '  "targets": [\n'
		count=0
		total=0
		if [ -n "$records" ]; then
			total=$(printf '%s\n' "$records" | wc -l | tr -d ' ')
		fi
		printf '%s\n' "$records" | while IFS='|' read -r rid rkind rsource rtarget rexpected rbackup; do
			if [ -z "$rid" ]; then
				continue
			fi
			count=$((count + 1))
			suffix=,
			if [ "$count" -eq "$total" ]; then
				suffix=''
			fi
			printf '    {"id":"%s","kind":"%s","source":"%s","target":"%s","expected_link":"%s","backup":"%s"}%s\n' \
				"$(json_escape "$rid")" \
				"$(json_escape "$rkind")" \
				"$(json_escape "$rsource")" \
				"$(json_escape "$rtarget")" \
				"$(json_escape "$rexpected")" \
				"$(json_escape "$rbackup")" \
				"$suffix"
		done
		printf '  ]\n'
		printf '}\n'
	} > "$tmp_file"
	mv "$tmp_file" "$LINK_STATE_FILE"
}

remove_state_file() {
	rm -f "$LINK_STATE_FILE"
}
