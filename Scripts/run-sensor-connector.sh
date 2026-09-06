#!/bin/zsh

set -u

shortcut_name="${CLIMATEENGINE_SHORTCUT_NAME:-ClimateEngine Sensor Connector}"
shortcuts_command="${CLIMATEENGINE_SHORTCUTS_COMMAND:-/usr/bin/shortcuts}"
log_file="${CLIMATEENGINE_RETRY_LOG:-/tmp/climateengine-sensor-retry.log}"
lock_file="${CLIMATEENGINE_RETRY_LOCK:-/tmp/climateengine-sensor-retry.lock}"
retry_delay="${CLIMATEENGINE_RETRY_DELAY_SECONDS:-20}"
max_attempts="${CLIMATEENGINE_MAX_ATTEMPTS:-3}"

timestamp() {
    /bin/date '+%Y-%m-%d %H:%M:%S%z'
}

log_message() {
    /usr/bin/printf '%s %s\n' "$(timestamp)" "$1" >> "$log_file"
}

if ! /usr/bin/shlock -f "$lock_file" -p $$; then
    log_message "SKIP another connector run is still active"
    exit 0
fi

cleanup() {
    /bin/rm -f "$lock_file"
}
trap cleanup EXIT INT TERM HUP

terrace_config="${CLIMATEENGINE_TERRACE_CONFIG:-${CLIMATEENGINE_DATA_DIRECTORY:-$HOME/Library/Application Support/ClimateEngine}/sensor-input/terrace-connector.json}"
additional_config="${CLIMATEENGINE_ADDITIONAL_CONFIG:-${CLIMATEENGINE_DATA_DIRECTORY:-$HOME/Library/Application Support/ClimateEngine}/additional-sensors/connector.json}"
if [[ "$shortcut_name" == "ClimateEngine Additional Sensor Connector" && -f "$additional_config" ]]; then
    log_message "START isolated additional connector"
    "${CLIMATEENGINE_PYTHON_COMMAND:-/usr/bin/python3}" -B "${0:A:h}/run-additional-connector.py" --config "$additional_config"
    exit_code=$?
    log_message "FINISH isolated additional connector exit=${exit_code}"
    exit "$exit_code"
fi
if [[ "$shortcut_name" == "ClimateEngine Sensor Connector" && -f "$terrace_config" ]]; then
    log_message "START terrace connector"
    "${CLIMATEENGINE_PYTHON_COMMAND:-/usr/bin/python3}" -B "${0:A:h}/run-terrace-connector.py" --config "$terrace_config"
    exit_code=$?
    log_message "FINISH terrace connector exit=${exit_code}"
    exit "$exit_code"
fi

attempt=1
while (( attempt <= max_attempts )); do
    error_file="${TMPDIR:-/tmp}/climateengine-sensor-attempt-$$-${attempt}.err"
    : > "$error_file"

    log_message "START attempt=${attempt}/${max_attempts}"
    "$shortcuts_command" run "$shortcut_name" 2> "$error_file"
    exit_code=$?
    error_text="$(<"$error_file")"
    /bin/rm -f "$error_file"

    if (( exit_code == 0 )); then
        log_message "SUCCESS attempt=${attempt}/${max_attempts}"
        exit 0
    fi

    compact_error="${error_text//$'\n'/ }"
    log_message "FAIL attempt=${attempt}/${max_attempts} exit=${exit_code} error=${compact_error}"

    if [[ "$error_text" != *"Schreib-/Lesevorgang fehlgeschlagen"* ]]; then
        /usr/bin/printf '%s\n' "$error_text" >&2
        exit "$exit_code"
    fi

    if (( attempt == max_attempts )); then
        /usr/bin/printf '%s\n' "$error_text" >&2
        log_message "GIVE_UP attempts=${max_attempts}"
        exit "$exit_code"
    fi

    log_message "RETRY in=${retry_delay}s"
    /bin/sleep "$retry_delay"
    (( attempt += 1 ))
done
