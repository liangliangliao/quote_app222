#!/usr/bin/env bash
set -euo pipefail

# Hosted Ubuntu images may omit ripgrep. Keep the CI checks portable.
prp_find() {
  if command -v rg >/dev/null 2>&1; then command rg "$@";
  else command grep -E "$@"; fi
}

prp_device="${PRP_DEVICE:-emulator-5554}"
test "$(adb -s "$prp_device" shell getprop ro.kernel.qemu | tr -d '\r')" = "1"
mkdir -p build/prp/device-evidence
prp_collect_exit() {
  prp_exit_status=$?
  trap - EXIT
  adb -s "$prp_device" logcat -d >build/prp/device-evidence/logcat.txt || true
  if [ "$prp_exit_status" -ne 0 ]; then
    adb -s "$prp_device" exec-out screencap -p >build/prp/device-evidence/failure-screen.png || true
  fi
  exit "$prp_exit_status"
}
trap prp_collect_exit EXIT
adb -s "$prp_device" shell wm size 480x1000
adb -s "$prp_device" shell wm density 160
adb -s "$prp_device" install -r build/prp/acceptance/app-debug.apk
adb -s "$prp_device" shell pm clear com.example.quote_app
adb -s "$prp_device" shell pm grant com.example.quote_app android.permission.RECORD_AUDIO
# This permission is confined to the disposable emulator, for the existing overlay path.
adb -s "$prp_device" shell appops set com.example.quote_app SYSTEM_ALERT_WINDOW allow
if [ "${PRP_API_LEVEL:-35}" -ge 33 ]; then
  adb -s "$prp_device" shell pm grant com.example.quote_app android.permission.POST_NOTIFICATIONS
fi
prp_drive_ok=false
for prp_attempt in 1 2; do
  if flutter drive --no-pub --no-dds --verbose --driver=test_driver/prp_acceptance_driver.dart \
    --target=integration_test/prp_acceptance_test.dart \
    --use-application-binary=build/prp/acceptance/app-debug.apk \
    --no-enable-impeller --keep-app-running -d "$prp_device" --timeout=900 \
    >build/prp/device-evidence/flutter-drive.log 2>&1; then
    prp_drive_ok=true
    break
  fi
  cp build/prp/device-evidence/flutter-drive.log "build/prp/device-evidence/flutter-drive-attempt-$prp_attempt.log"
  # Retry only a VM attachment failure before any test executes. Never retry
  # assertions, application crashes, or a partially completed product workflow.
  if ! prp_find -q '(Failed to register service methods.*|getIsolate:.*)Service connection disposed' build/prp/device-evidence/flutter-drive.log || \
      prp_find -q 'TestFailure|Some tests failed|Failure in method:|PRP Android acceptance:' build/prp/device-evidence/flutter-drive.log; then
    break
  fi
  adb -s "$prp_device" wait-for-device
  adb -s "$prp_device" shell am force-stop com.example.quote_app
done
timeout 60 adb -s "$prp_device" wait-for-device
# Device files are written only after every UI/database assertion has passed.
# Keep the app installed so native instrumentation sees the same local ledger.
prp_device_report=false
if adb -s "$prp_device" exec-out run-as com.example.quote_app cat app_flutter/prp-ci/flutter-results.json \
    >build/prp/device-evidence/flutter-results.json; then
  if python3 - <<'PY'
import json,os,pathlib
p=pathlib.Path('build/prp/device-evidence/flutter-results.json')
d=json.loads(p.read_text())
assert d['source_sha']==os.environ['PRP_SOURCE_SHA']
assert d['ui_acceptance']=='passed' and len(d['captured_screenshots'])==14
assert all(pathlib.Path(n).name==n and n.endswith('.png') for n in d['captured_screenshots'])
PY
  then
    prp_device_report=true
    while IFS= read -r prp_name; do
      adb -s "$prp_device" exec-out run-as com.example.quote_app cat "app_flutter/prp-ci/$prp_name" \
        >"build/prp/device-evidence/$prp_name"
    done < <(python3 -c "import json;print('\n'.join(json.load(open('build/prp/device-evidence/flutter-results.json'))['captured_screenshots']))")
  fi
fi
# A successful device report cannot overrule any assertion/teardown failure.
# It can recover the documented ADB disconnect after the test runner passed.
if [ "$prp_drive_ok" != true ] && [ "$prp_device_report" = true ] && \
    prp_find -q 'All tests passed' build/prp/device-evidence/flutter-drive.log && \
    prp_find -q 'Service connection disposed' build/prp/device-evidence/flutter-drive.log && \
    ! prp_find -q 'TestFailure|Some tests failed|Failure in method:' build/prp/device-evidence/flutter-drive.log; then
  prp_drive_ok=true
fi
if [ "$prp_device_report" != true ]; then prp_drive_ok=false; fi
if [ "$prp_drive_ok" != true ]; then
  tail -n 120 build/prp/device-evidence/flutter-drive.log
fi
adb -s "$prp_device" install -r -t build/prp/acceptance/app-debug-androidTest.apk
adb -s "$prp_device" shell pm list instrumentation >build/prp/device-evidence/instrumentation.txt
prp_find 'com.example.quote_app.PrpAcceptanceProbe' build/prp/device-evidence/instrumentation.txt
adb -s "$prp_device" shell am instrument -w \
  com.example.quote_app.test/com.example.quote_app.PrpAcceptanceProbe \
  >build/prp/device-evidence/native-probe.log 2>&1
prp_native_ok=false
if prp_find 'PRP_NATIVE_ACCEPTANCE_PASS' build/prp/device-evidence/native-probe.log; then
  prp_native_ok=true
else
  cat build/prp/device-evidence/native-probe.log
fi
for prp_name in native_01_on.png native_02_off.png native_03_overlay.png native-results.json; do
  # Android 8 has no executable `test` accessible to run-as; pull directly.
  if ! adb -s "$prp_device" exec-out run-as com.example.quote_app cat "files/prp-ci/$prp_name" \
      >"build/prp/device-evidence/$prp_name"; then
    rm -f "build/prp/device-evidence/$prp_name"
  fi
done
if [ "$prp_drive_ok" != true ] || [ "$prp_native_ok" != true ]; then
  exit 1
fi
adb -s "$prp_device" logcat -d >build/prp/device-evidence/logcat.txt
python3 - <<'PY'
import hashlib,json,os,pathlib,re
folder=pathlib.Path('build/prp/device-evidence')
logcat=(folder/'logcat.txt').read_text(errors='replace')
for fatal in re.finditer(r'FATAL EXCEPTION:',logcat):
    crash=logcat[fatal.start():fatal.start()+2000]
    assert not re.search(r'Process: (com\.example\.quote_app|com\.android\.systemui)\b',crash),crash
native=json.loads((folder/'native-results.json').read_text())
flutter=json.loads((folder/'flutter-results.json').read_text())
assert native['status']=='passed'
assert flutter['ui_acceptance']=='passed'
assert flutter['source_sha']==os.environ['PRP_SOURCE_SHA']
files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.glob('*.png')}
assert len(files)>=17,files
report={'source_sha':os.environ['PRP_SOURCE_SHA'],'api_level':os.environ['PRP_API_LEVEL'],
        'physical_device':False,'status':'passed','screenshots_sha256':files,
        'native_checks':native['passed']}
(folder/'acceptance-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
PY
