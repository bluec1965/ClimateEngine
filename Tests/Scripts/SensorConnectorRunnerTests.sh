#!/bin/zsh

set -eu

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
runner="$project_root/Scripts/run-sensor-connector.sh"
test_directory="$(mktemp -d /tmp/climateengine-runner-tests.XXXXXX)"
trap '/bin/rm -rf "$test_directory"' EXIT INT TERM HUP

fake_shortcuts="$test_directory/fake-shortcuts.sh"
cat > "$fake_shortcuts" <<'SCRIPT'
#!/bin/zsh
count=0
if [[ -f "$FAKE_COUNT_FILE" ]]; then
    count="$(<"$FAKE_COUNT_FILE")"
fi
(( count += 1 ))
print -r -- "$count" > "$FAKE_COUNT_FILE"

case "$FAKE_MODE" in
    retry_then_success)
        if (( count < 3 )); then
            print -u2 -- "Error: Schreib-/Lesevorgang fehlgeschlagen."
            exit 1
        fi
        print -- "NONE"
        ;;
    non_retryable)
        print -u2 -- "Error: Sensormessung wurde verworfen."
        exit 2
        ;;
    *)
        print -- "NONE"
        ;;
esac
SCRIPT
chmod +x "$fake_shortcuts"

run_helper() {
    local mode="$1"
    local case_name="$2"
    local count_file="$test_directory/$case_name.count"
    local log_file="$test_directory/$case_name.log"
    local lock_file="$test_directory/$case_name.lock"

    FAKE_MODE="$mode" \
    FAKE_COUNT_FILE="$count_file" \
    CLIMATEENGINE_SHORTCUTS_COMMAND="$fake_shortcuts" \
    CLIMATEENGINE_RETRY_DELAY_SECONDS=0 \
    CLIMATEENGINE_RETRY_LOG="$log_file" \
    CLIMATEENGINE_RETRY_LOCK="$lock_file" \
    "$runner"
}

output="$(run_helper retry_then_success retry)"
[[ "$output" == "NONE" ]]
[[ "$(<"$test_directory/retry.count")" == "3" ]]
grep -q 'SUCCESS attempt=3/3' "$test_directory/retry.log"

set +e
run_helper non_retryable non-retryable \
    > "$test_directory/non-retryable.out" \
    2> "$test_directory/non-retryable.err"
exit_code=$?
set -e
[[ "$exit_code" == "2" ]]
[[ "$(<"$test_directory/non-retryable.count")" == "1" ]]
grep -q 'Sensormessung wurde verworfen' "$test_directory/non-retryable.err"

held_lock="$test_directory/held.lock"
/usr/bin/shlock -f "$held_lock" -p $$
FAKE_MODE=success \
FAKE_COUNT_FILE="$test_directory/locked.count" \
CLIMATEENGINE_SHORTCUTS_COMMAND="$fake_shortcuts" \
CLIMATEENGINE_RETRY_LOG="$test_directory/locked.log" \
CLIMATEENGINE_RETRY_LOCK="$held_lock" \
"$runner"
[[ ! -f "$test_directory/locked.count" ]]
grep -q 'SKIP another connector run is still active' "$test_directory/locked.log"
/bin/rm -f "$held_lock"

print -- "SensorConnectorRunnerTests passed"
