#!/usr/bin/env bash
set -euo pipefail

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
    --no-enable-impeller -d "$prp_device" --timeout=900 \
    >build/prp/device-evidence/flutter-drive.log 2>&1; then
    prp_drive_ok=true
    break
  fi
  cp build/prp/device-evidence/flutter-drive.log "build/prp/device-evidence/flutter-drive-attempt-$prp_attempt.log"
  # Retry only a VM attachment failure before any test executes. Never retry
  # assertions, application crashes, or a partially completed product workflow.
  if ! rg -q 'Failed to register service methods.*Service connection disposed' build/prp/device-evidence/flutter-drive.log || \
      rg -q 'TestFailure|Some tests failed|Failure in method:' build/prp/device-evidence/flutter-drive.log; then
    break
  fi
  adb -s "$prp_device" wait-for-device
  adb -s "$prp_device" shell am force-stop com.example.quote_app
done
if [ "$prp_drive_ok" != true ]; then
  tail -n 120 build/prp/device-evidence/flutter-drive.log
  adb -s "$prp_device" logcat -d >build/prp/device-evidence/logcat.txt
  exit 1
fi
adb -s "$prp_device" install -r build/prp/acceptance/app-debug-androidTest.apk
adb -s "$prp_device" shell am instrument -w \
  com.example.quote_app.test/com.example.quote_app.PrpAcceptanceProbe \
  >build/prp/device-evidence/native-probe.log 2>&1
rg 'PRP_NATIVE_ACCEPTANCE_PASS' build/prp/device-evidence/native-probe.log
for prp_name in native_01_on.png native_02_off.png native_03_overlay.png native-results.json; do
  adb -s "$prp_device" exec-out run-as com.example.quote_app cat "files/prp-ci/$prp_name" \
    >"build/prp/device-evidence/$prp_name"
done
adb -s "$prp_device" logcat -d >build/prp/device-evidence/logcat.txt
python3 - <<'PY'
import hashlib,json,os,pathlib
folder=pathlib.Path('build/prp/device-evidence')
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
