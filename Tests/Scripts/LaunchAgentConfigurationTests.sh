#!/bin/zsh

set -eu

project_root="$(cd "$(dirname "$0")/../.." && pwd)"
main_plist="$project_root/Support/ch.climateengine.poller.plist"
additional_plist="$project_root/Support/ch.climateengine.additional-sensor-poller.plist"

plutil -lint "$main_plist" "$additional_plist" >/dev/null

main_first_minute="$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval:0:Minute' "$main_plist")"
main_last_minute="$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval:11:Minute' "$main_plist")"
additional_first_minute="$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval:0:Minute' "$additional_plist")"
additional_last_minute="$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval:11:Minute' "$additional_plist")"
shortcut_name="$(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:CLIMATEENGINE_SHORTCUT_NAME' "$additional_plist")"
shared_lock="$(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:CLIMATEENGINE_RETRY_LOCK' "$additional_plist")"

[[ "$main_first_minute" == "0" ]]
[[ "$main_last_minute" == "55" ]]
[[ "$additional_first_minute" == "2" ]]
[[ "$additional_last_minute" == "57" ]]
[[ "$shortcut_name" == "ClimateEngine Additional Sensor Connector" ]]
[[ "$shared_lock" == "/tmp/climateengine-sensor-retry.lock" ]]

print -- "LaunchAgentConfigurationTests passed"
