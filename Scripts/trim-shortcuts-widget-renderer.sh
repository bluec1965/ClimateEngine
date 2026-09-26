#!/bin/zsh

set -u

threshold_kb="${CLIMATEENGINE_WIDGET_RENDERER_THRESHOLD_KB:-512000}"
log_file="${CLIMATEENGINE_WIDGET_RENDERER_LOG:-/tmp/climateengine-widget-renderer.log}"
renderer_path="/System/Library/CoreServices/WidgetRenderer_Activities.app/Contents/MacOS/WidgetRenderer_Activities"

timestamp() {
    /bin/date '+%Y-%m-%d %H:%M:%S%z'
}

log_message() {
    /usr/bin/printf '%s %s\n' "$(timestamp)" "$1" >> "$log_file"
}

if [[ "$threshold_kb" != <-> ]]; then
    log_message "SKIP invalid threshold=${threshold_kb}"
    exit 0
fi

# Never interfere with an active Shortcuts command. The next sensor cycle will
# retry the memory check after the command has completed.
shortcuts_active="${CLIMATEENGINE_SHORTCUTS_ACTIVE:-auto}"
if [[ "$shortcuts_active" == "1" ]] || {
    [[ "$shortcuts_active" == "auto" ]] && /usr/bin/pgrep -x shortcuts >/dev/null 2>&1
}; then
    exit 0
fi

process_snapshot="${CLIMATEENGINE_WIDGET_RENDERER_SNAPSHOT:-$(/bin/ps -axo pid=,rss=,comm=)}"
matched=0
while IFS=$'\t' read -r pid rss_kb; do
    [[ -z "$pid" || -z "$rss_kb" ]] && continue
    matched=1
    if (( rss_kb < threshold_kb )); then
        continue
    fi

    if [[ "${CLIMATEENGINE_WIDGET_RENDERER_DRY_RUN:-0}" == "1" ]]; then
        log_message "WOULD_RESTART pid=${pid} rss_kb=${rss_kb} threshold_kb=${threshold_kb}"
        continue
    fi

    if /bin/kill -TERM "$pid" 2>/dev/null; then
        log_message "RESTART pid=${pid} rss_kb=${rss_kb} threshold_kb=${threshold_kb}"
    else
        log_message "FAILED pid=${pid} rss_kb=${rss_kb} threshold_kb=${threshold_kb}"
    fi
done < <(/usr/bin/printf '%s\n' "$process_snapshot" | /usr/bin/awk -v path="$renderer_path" '
    index($0, path) {
        pid = $1
        rss = $2
        printf "%s\t%s\n", pid, rss
    }
')

if (( matched == 0 )); then
    exit 0
fi
