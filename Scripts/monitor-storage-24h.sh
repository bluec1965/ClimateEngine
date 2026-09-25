#!/bin/zsh

set -u

account_home="/Users/aloiscarnier"
data_directory="$account_home/Library/Application Support/ClimateEngine"
diagnostics_directory="$data_directory/diagnostics"
state_file="$diagnostics_directory/storage-monitor.state"
latest_file="$diagnostics_directory/storage-monitor-latest.txt"
interval_seconds=300
duration_seconds=86400

/bin/mkdir -p "$diagnostics_directory"

if [[ -f "$state_file" ]]; then
    start_epoch="$(/bin/cat "$state_file")"
else
    start_epoch="$(/bin/date +%s)"
    /usr/bin/printf '%s\n' "$start_epoch" > "$state_file"
fi

start_stamp="$(/bin/date -r "$start_epoch" '+%Y-%m-%d_%H-%M-%S')"
output_file="$diagnostics_directory/storage-monitor-$start_stamp.csv"
/usr/bin/printf '%s\n' "$output_file" > "$latest_file"

if [[ ! -f "$output_file" ]]; then
    /usr/bin/printf '%s\n' \
        'timestamp,free_disk_kb,swap_used_mb,climateengine_data_kb,climateengine_logs_kb,app_rss_kb,web_rss_kb,largest_process_rss_kb,largest_process' \
        > "$output_file"
fi

while true; do
    now_epoch="$(/bin/date +%s)"
    if (( now_epoch - start_epoch >= duration_seconds )); then
        /usr/bin/printf 'completed_at=%s\noutput=%s\n' \
            "$(/bin/date '+%Y-%m-%d %H:%M:%S%z')" "$output_file" \
            > "$diagnostics_directory/storage-monitor-complete.txt"
        exit 0
    fi

    timestamp="$(/bin/date '+%Y-%m-%d %H:%M:%S%z')"
    free_disk_kb="$(/bin/df -k /System/Volumes/Data | /usr/bin/awk 'NR == 2 { print $4 }')"
    swap_used_mb="$(/usr/sbin/sysctl -n vm.swapusage | /usr/bin/awk '{ for (i = 1; i <= NF; i++) if ($i == "used") { value = $(i + 2); sub(/M$/, "", value); print value; exit } }')"
    climateengine_data_kb="$(/usr/bin/du -sk "$data_directory" 2>/dev/null | /usr/bin/awk '{ print $1 + 0 }')"
    climateengine_logs_kb="$(/usr/bin/du -ck /tmp/climateengine* 2>/dev/null | /usr/bin/awk '/total$/ { print $1 + 0 }')"

    process_snapshot="$(/bin/ps -axo rss=,pid=,command=)"
    app_rss_kb="$(/usr/bin/printf '%s\n' "$process_snapshot" | /usr/bin/awk '/ClimateEngineApp.app\/Contents\/MacOS\/ClimateEngineApp/ { total += $1 } END { print total + 0 }')"
    web_rss_kb="$(/usr/bin/printf '%s\n' "$process_snapshot" | /usr/bin/awk '/ClimateEngine\/WebApp\/server.py/ { total += $1 } END { print total + 0 }')"
    largest_process="$(/usr/bin/printf '%s\n' "$process_snapshot" | /usr/bin/sort -k1,1nr | /usr/bin/head -1)"
    largest_process_rss_kb="$(/usr/bin/printf '%s\n' "$largest_process" | /usr/bin/awk '{ print $1 + 0 }')"
    largest_process_pid="$(/usr/bin/printf '%s\n' "$largest_process" | /usr/bin/awk '{ print $2 + 0 }')"
    largest_process_name="$(/bin/ps -p "$largest_process_pid" -o comm=)"
    largest_process_name="${largest_process_name:t}"
    largest_process_name="${largest_process_name//\"/\"\"}"

    /usr/bin/printf '%s,%s,%s,%s,%s,%s,%s,%s,"%s"\n' \
        "$timestamp" "$free_disk_kb" "$swap_used_mb" \
        "$climateengine_data_kb" "${climateengine_logs_kb:-0}" \
        "$app_rss_kb" "$web_rss_kb" "$largest_process_rss_kb" \
        "$largest_process_name" >> "$output_file"

    /bin/sleep "$interval_seconds"
done
