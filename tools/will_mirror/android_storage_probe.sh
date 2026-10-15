#!/usr/bin/env bash
set -euo pipefail

device="${1:-emulator-5554}"
package=com.example.quote_app
probe_db=databases/will_mirror_android_upgrade_probe.sqlite

# flutter test uninstalls its app during teardown, deleting its data and keys.
# Drive with keep-app-running preserves the installation; force-stop ends each
# process without clearing data. AndroidDevice installs the next APK with -r.
run_probe() {
  local phase="$1"
  adb -s "$device" shell am force-stop "$package"
  flutter drive --no-dds --keep-app-running \
    --driver=test_driver/will_mirror_storage_driver.dart \
    --target=integration_test/will_mirror_storage_test.dart \
    --dart-define="MIRROR_UPGRADE_PHASE=$phase" -d "$device"
}

on_exit() {
  local result=$?
  if [[ "$result" -ne 0 ]]; then
    # This emulator contains synthetic test data only. Limit diagnostics to
    # Android crash reports; never run this probe against a user's live device.
    adb -s "$device" logcat -b crash -d || true
  fi
  adb -s "$device" shell am force-stop "$package" || true
}
trap on_exit EXIT

run_probe normal
run_probe seed
# Explicitly fail if the runner removed the seeded installation/data.
adb -s "$device" shell run-as "$package" test -f "$probe_db"
run_probe verify
