#!/usr/bin/env bash
set -euo pipefail
task_package=com.example.quote_app
test_apk=$(find build/app/outputs -path '*/androidTest/*.apk' -print -quit)
test -n "$test_apk"
test "$(adb shell getprop ro.kernel.qemu | tr -d '\r')" = 1
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb install -r "$test_apk"
adb shell pm grant "$task_package" android.permission.POST_NOTIFICATIONS
adb shell appops set "$task_package" SCHEDULE_EXACT_ALARM allow
adb shell svc wifi disable
adb shell svc data disable

seed() {
  adb shell am instrument -w -e phase "$1" "$task_package.test/com.example.quote_app.ReminderProbe" > "probe-$1.txt"
  cat "probe-$1.txt"
  grep -Eq "REMINDER_PROBE_READY:$1" "probe-$1.txt"
}
active() { adb shell cmd notification list | tr -d '\r'; }
await_pair() {
  local growth_id=$1 diet_id=$2
  for ((attempt=0;attempt<60;attempt++)); do
    active > probe-active.txt
    if grep -Eq "\|$task_package\|$growth_id\|evidence_growth\|" probe-active.txt && grep -Eq "\|$task_package\|$diet_id\|" probe-active.txt; then
      cat probe-active.txt
      return 0
    fi
    sleep 5
  done
  adb shell dumpsys notification --noredact > probe-notifications.txt
  adb logcat -d > probe-logcat.txt
  return 1
}

seed kill
adb shell input keyevent 223
adb shell am kill "$task_package"
for ((attempt=0;attempt<10;attempt++)); do
  [[ -z "$(adb shell pidof "$task_package" | tr -d '\r')" ]] && break
  adb shell am kill "$task_package"
  sleep 1
done
test -z "$(adb shell pidof "$task_package" | tr -d '\r')"
await_pair 9101 19101
printf '%s\n' 'PASS: growth and diet delivered after process termination with screen off'

seed reboot
adb reboot
adb wait-for-device
for ((attempt=0;attempt<90;attempt++)); do
  [[ "$(adb shell getprop sys.boot_completed | tr -d '\r')" == 1 ]] && break
  sleep 2
done
test "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1
adb shell input keyevent 224
adb shell wm dismiss-keyguard
await_pair 9201 19201
printf '%s\n' 'PASS: growth and diet restored after reboot/unlock without opening Flutter'

seed stop
adb shell am force-stop "$task_package"
sleep 55
active > probe-stopped.txt
if grep -Eq "\|$task_package\|(9301|19301)\|" probe-stopped.txt; then exit 1; fi
printf '%s\n' 'PASS: force-stop is respected; no claim of bypassing Android stopped state'
