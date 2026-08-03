#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 1 ]]; then
	printf 'usage: %s <godot arguments...>\n' "$0" >&2
	exit 64
fi

godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
watchdog_seconds="${GODOT_WATCHDOG_SECONDS:-35}"
log_path="$(mktemp -t riftline-godot.XXXXXX)"
child_pid=""

stop_tree() {
	local parent_pid="$1"
	local descendant_pid=""
	for descendant_pid in $(pgrep -P "$parent_pid" 2>/dev/null || true); do
		stop_tree "$descendant_pid"
		kill "$descendant_pid" 2>/dev/null || true
	done
}

cleanup() {
	if [[ -n "$child_pid" ]] && kill -0 "$child_pid" 2>/dev/null; then
		stop_tree "$child_pid"
		kill "$child_pid" 2>/dev/null || true
		for _ in 1 2 3 4 5; do
			if ! kill -0 "$child_pid" 2>/dev/null; then
				break
			fi
			sleep 0.2
		done
		if kill -0 "$child_pid" 2>/dev/null; then
			kill -KILL "$child_pid" 2>/dev/null || true
		fi
		wait "$child_pid" 2>/dev/null || true
	fi
	rm -f "$log_path"
}

trap cleanup EXIT INT TERM

"$godot_bin" "$@" >"$log_path" 2>&1 &
child_pid=$!
started_at="$(date +%s)"
status=0
while kill -0 "$child_pid" 2>/dev/null; do
	if (( $(date +%s) - started_at >= watchdog_seconds )); then
		printf 'Godot watchdog stopped PID %s after %ss.\n' "$child_pid" "$watchdog_seconds" >&2
		status=124
		break
	fi
	sleep 0.2
done

if [[ "$status" -eq 0 ]]; then
	wait "$child_pid" || status=$?
else
	kill "$child_pid" 2>/dev/null || true
	wait "$child_pid" 2>/dev/null || true
fi

cat "$log_path"
exit "$status"
