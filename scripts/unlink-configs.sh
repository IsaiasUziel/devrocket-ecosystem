#!/bin/sh

set -eu

LINK_CONFIGS_SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LINK_CONFIGS_REPO_ROOT=$(CDPATH= cd -- "$LINK_CONFIGS_SCRIPT_DIR/.." && pwd)
. "$LINK_CONFIGS_SCRIPT_DIR/lib/link-configs-common.sh"

TARGET_IDS=$(selected_targets "$@")
load_state_if_present

if [ "$STATE_PRESENT" -ne 1 ]; then
	fail "missing state file: $LINK_STATE_FILE"
fi

restored_count=0
skipped_count=0
remaining_records=''

for target_id in $(all_target_ids); do
	record=$(record_for_id "$target_id" "$STATE_RECORDS")
	if [ -z "$record" ]; then
		continue
	fi

	selected=0
	for requested_id in $TARGET_IDS; do
		if [ "$requested_id" = "$target_id" ]; then
			selected=1
			break
		fi
		done

	if [ "$selected" -ne 1 ]; then
		remaining_records=$(append_record "$remaining_records" "$record")
		continue
	fi

	IFS='|' read -r rid _ _ target_path expected_link backup_path <<EOF
$record
EOF
	if [ ! -L "$target_path" ]; then
		fail "unexpected target state for $rid: $target_path"
	fi
	current_link=$(readlink_target "$target_path")
	if [ "$current_link" != "$expected_link" ]; then
		fail "unexpected target state for $rid: $target_path -> $current_link"
	fi

	rm "$target_path"
	if [ -n "$backup_path" ]; then
		ensure_parent_dir "$target_path"
		mv "$backup_path" "$target_path"
		restored_count=$((restored_count + 1))
	else
		skipped_count=$((skipped_count + 1))
	fi
	remove_empty_parents "$target_path"
done

for requested_id in $TARGET_IDS; do
	if [ -z "$(record_for_id "$requested_id" "$STATE_RECORDS")" ]; then
		fail "target is not managed in state: $requested_id"
	fi
done

if [ -n "$remaining_records" ]; then
	write_state_file "$STATE_LINKED_AT" "$STATE_BACKUP_DIR" "$remaining_records"
else
	remove_state_file
	if [ -d "$STATE_BACKUP_DIR" ]; then
		rmdir "$STATE_BACKUP_DIR" 2>/dev/null || true
	fi
fi

log_ok "linked=0 restored=$restored_count skipped=$skipped_count state=$LINK_STATE_FILE backup_dir=$STATE_BACKUP_DIR"
