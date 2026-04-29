#!/bin/sh

set -eu

LINK_CONFIGS_SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LINK_CONFIGS_REPO_ROOT=$(CDPATH= cd -- "$LINK_CONFIGS_SCRIPT_DIR/.." && pwd)
. "$LINK_CONFIGS_SCRIPT_DIR/lib/link-configs-common.sh"

ensure_state_root
TARGET_IDS=$(selected_targets "$@")
require_repo_sources $TARGET_IDS
load_state_if_present

backup_dir=${STATE_BACKUP_DIR:-}
linked_at=${STATE_LINKED_AT:-}
if [ -z "$linked_at" ]; then
	linked_at=$(timestamp_utc)
fi

prepared_records=''
linked_count=0
skipped_count=0

for target_id in $TARGET_IDS; do
	target_path=$(target_path "$target_id")
	expected_link=$(target_expected_link "$target_id")
	record=$(record_for_id "$target_id" "$STATE_RECORDS")
	backup_path=''

	if [ -n "$record" ]; then
		IFS='|' read -r _ _ _ _ _ backup_path <<EOF
$record
EOF
	fi

	if [ -L "$target_path" ]; then
		if [ -z "$record" ]; then
			fail "foreign symlink detected for $target_id: $target_path -> $(readlink_target "$target_path")"
		fi
		current_link=$(readlink_target "$target_path")
		if [ "$current_link" != "$expected_link" ]; then
			fail "foreign symlink detected for $target_id: $target_path -> $current_link"
		fi
		prepared_records=$(append_record "$prepared_records" "${target_id}|$(target_kind "$target_id")|$(target_source "$target_id")|$target_path|$expected_link|$backup_path")
		skipped_count=$((skipped_count + 1))
		continue
	fi

	if [ -e "$target_path" ]; then
		if [ -n "$record" ]; then
			fail "unexpected target state for $target_id: $target_path"
		fi
		backup_dir=$(ensure_backup_dir "$backup_dir")
		backup_path="$backup_dir/$target_id"
		ensure_parent_dir "$backup_path"
		mv "$target_path" "$backup_path"
	fi

	ensure_parent_dir "$target_path"
	ln -s "$expected_link" "$target_path"
	prepared_records=$(append_record "$prepared_records" "${target_id}|$(target_kind "$target_id")|$(target_source "$target_id")|$target_path|$expected_link|$backup_path")
	linked_count=$((linked_count + 1))
done

if [ -z "$backup_dir" ]; then
	backup_dir=$(ensure_backup_dir "")
fi

merged_records=''
for target_id in $(all_target_ids); do
	record=$(record_for_id "$target_id" "$prepared_records")
	if [ -z "$record" ]; then
		record=$(record_for_id "$target_id" "$STATE_RECORDS")
	fi
	if [ -n "$record" ]; then
		merged_records=$(append_record "$merged_records" "$record")
	fi
done

write_state_file "$linked_at" "$backup_dir" "$merged_records"

log_ok "linked=$linked_count restored=0 skipped=$skipped_count state=$LINK_STATE_FILE backup_dir=$backup_dir"
