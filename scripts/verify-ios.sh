#!/bin/bash
# Run the shared scheme's unit and UI tests and retain reproducible evidence.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${SIMULATOR_UDID:-}" && "${CI:-false}" != true ]]; then
  echo "Local verification requires SIMULATOR_UDID for a dedicated clean app simulator. Synthetic receipt fixtures are imported into its Photos library; CI uses an ephemeral runner." >&2
  exit 1
fi
output="${ARTIFACTS_DIR:-$PWD/artifacts/$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
xcodebuild -version | tee "$output/toolchain.txt"
xcrun --sdk iphonesimulator --show-sdk-version | tee "$output/sdk.txt"
# Bind evidence to the exact checked-out sources, including authorized uncommitted
# modernization changes. Build caches, user settings and artifacts are excluded.
python3 - "$output/source-manifest.json" <<'PYSOURCE'
import hashlib, json, pathlib, subprocess, sys
roots = ["SplitMyMeal-Prod-A", "SplitMyMealTests", "SplitMyMealUITests", "SplitMyMeal-Prod-A.xcodeproj", "scripts"]
files = {}
for root in roots:
    for path in sorted(pathlib.Path(root).rglob("*")):
        if path.is_file() and "xcuserdata" not in path.parts and path.name != ".DS_Store":
            files[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
manifest = {"gitHead": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(), "sha256": files}
pathlib.Path(sys.argv[1]).write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
PYSOURCE
python3 scripts/select-simulator.py | tee "$output/simulator.json"
udid="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["udid"])' "$output/simulator.json")"
if [[ -e "$output/Tests.xcresult" ]]; then
  echo "Result bundle already exists: $output/Tests.xcresult. Select a fresh ARTIFACTS_DIR." >&2
  exit 1
fi
finish() {
  status=$?
  if [[ -n "${video_pid:-}" ]]; then
    # SIGINT is the documented native finalization path for this owned recorder.
    if kill -0 "$video_pid" 2>/dev/null; then
      if ! kill -INT "$video_pid"; then
        echo "Could not stop the owned walkthrough recorder." >&2
        if [[ "$status" -eq 0 ]]; then status=1; fi
      fi
    fi
    if ! wait "$video_pid" || [[ ! -s "$output/demo-walkthrough.mp4" ]]; then
      echo "Walkthrough recording did not finalize. Inspect video.log." >&2
      if [[ "$status" -eq 0 ]]; then status=1; fi
    fi
  fi
  if [[ -n "${original_contrast:-}" ]]; then
    if ! xcrun simctl ui "$udid" increase_contrast "$original_contrast"; then
      echo "Could not restore the dedicated simulator's original Increase Contrast setting." >&2
      if [[ "$status" -eq 0 ]]; then status=1; fi
    fi
  fi
  if [[ "${live_requested:-false}" == true ]]; then
    if ! xcrun simctl location "$udid" clear; then
      echo "Could not clear the dedicated simulator's synthetic location." >&2
      if [[ "$status" -eq 0 ]]; then status=1; fi
    fi
  fi
  if [[ "$status" -eq 0 && ! -f "$output/Tests.xcresult/Info.plist" ]]; then
    echo "No completed native test result exists; verification did not run." >&2
    status=1
  fi
  if [[ -d "$output/Tests.xcresult" ]]; then
    if ! xcrun xcresulttool get test-results summary --path "$output/Tests.xcresult" > "$output/test-summary.json"; then
      echo "Could not read the native test summary." >&2
      if [[ "$status" -eq 0 ]]; then status=1; fi
    elif [[ "$status" -eq 0 ]]; then
      if ! python3 - "$output/test-summary.json" <<'PYSUMMARY'
import json, sys
summary = json.load(open(sys.argv[1]))
if summary.get("totalTestCount", 0) < 1 or summary.get("failedTests", 0) != 0 or summary.get("result") not in {"Passed", "Skipped"}:
    sys.exit("Native verification requires completed tests with no failures; inspect test-summary.json.")
print(f"Native results: {summary.get('passedTests', 0)} passed, {summary.get('skippedTests', 0)} skipped.")
PYSUMMARY
      then status=1; fi
    fi
    if ! xcrun xcresulttool export attachments --path "$output/Tests.xcresult" --output-path "$output/attachments"; then
      echo "Could not export screenshot attachments; the original result bundle is retained." >&2
      if [[ "$status" -eq 0 ]]; then status=1; fi
    fi
  fi
  if [[ "$status" -eq 0 ]]; then
    if python3 -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1])).get("passedTests", 0) > 0 else 1)' "$output/test-summary.json"; then
      echo "Verified results: $output/Tests.xcresult"
    else
      echo "Tests completed with skips and no passing checks. Inspect $output/test-summary.json; provider behavior remains unverified."
    fi
  else
    echo "Verification failed. Inspect the logs and result bundle in $output." >&2
  fi
  exit "$status"
}
trap finish EXIT
derived="${DERIVED_DATA_DIR:-$output/DerivedData}"
# External Maps checks run only when explicitly selected on a dedicated device.
live_requested=false
for argument in "$@"; do
  if [[ "$argument" == -only-testing:SplitMyMealUITests/LiveMapKitTests* ]]; then live_requested=true; fi
done
if [[ "$live_requested" == true && -z "${SIMULATOR_UDID:-}" ]]; then
  echo "Live Maps verification requires an explicit SIMULATOR_UDID for a dedicated test device." >&2
  exit 1
fi
common=(
  -project SplitMyMeal-Prod-A.xcodeproj
  -scheme SplitMyMeal-Prod-A
  -destination "platform=iOS Simulator,id=$udid"
  -destination-timeout 120
  -parallel-testing-enabled NO
  -test-timeouts-enabled YES
  -default-test-execution-time-allowance 240
  # Three complete multi-launch journeys set their own measured hosted-run budget.
  # Every other test retains the four-minute default above.
  -maximum-test-execution-time-allowance 420
  # Xcode27's simulator diagnostics collector stalled after completed failures.
  # Keep the complete native result, screenshots, videos, AX and logs; omit that
  # separate system-wide diagnostic collection from reproducible app checks.
  -collect-test-diagnostics never
  -derivedDataPath "$derived"
  CODE_SIGNING_ALLOWED=NO
)
xcodebuild build-for-testing "${common[@]}" "$@" 2>&1 | tee "$output/build.log"
# The unit host starts before test methods and must use the local test store.
# UI classes independently assert and record arguments before every app launch.
python3 - "$derived/Build/Products" "$output/test-launch-arguments.json" <<'PYARGUMENTS'
import json, pathlib, plistlib, sys
candidates = []
for path in sorted(pathlib.Path(sys.argv[1]).glob("*.xctestrun")):
    metadata = plistlib.loads(path.read_bytes())
    if "SplitMyMealTests" in metadata and "SplitMyMealUITests" in metadata:
        candidates.append((path, metadata))
if len(candidates) != 1:
    sys.exit("Expected one app xctestrun file. Use fresh DERIVED_DATA_DIR and verify the shared scheme contains both test targets.")
path, metadata = candidates[0]
arguments = {
    "xctestrun": str(path),
    "unitHost": metadata["SplitMyMealTests"].get("CommandLineArguments", []),
    "uiRunner": metadata["SplitMyMealUITests"].get("CommandLineArguments", []),
    "uiTargetApp": metadata["SplitMyMealUITests"].get("UITargetAppCommandLineArguments", [])
}
pathlib.Path(sys.argv[2]).write_text(json.dumps(arguments, indent=2) + "\n")
if "--uitesting" not in arguments["unitHost"]:
    sys.exit("Test startup is not isolated. Enable --uitesting on the shared scheme's TestAction; inspect test-launch-arguments.json.")
PYARGUMENTS
# Preload fictional photos from the isolated debug store, so receipt attachment
# and replacement exercise the real system Photos picker on every fresh runner.
xcrun simctl bootstatus "$udid" -b 2>&1 | tee "$output/boot.log"
app_path="$derived/Build/Products/Debug-iphonesimulator/SplitMyMeal-Prod-A.app"
xcrun simctl install "$udid" "$app_path"
xcrun simctl launch --terminate-running-process "$udid" shreyassane.SplitMyMeal-Prod-A --uitesting --reset-test-data --seed-demo | tee "$output/fixture-launch.txt"
container="$(xcrun simctl get_app_container "$udid" shreyassane.SplitMyMeal-Prod-A data)"
for attempt in {1..30}; do
  if [[ -f "$container/Documents/UITesting-receipt.jpg" && -f "$container/Documents/UITesting-replacement.jpg" ]]; then break; fi
  sleep 1
done
if [[ ! -f "$container/Documents/UITesting-receipt.jpg" || ! -f "$container/Documents/UITesting-replacement.jpg" ]]; then
  echo "Both receipt fixtures must be generated. Inspect the isolated seed launch; photo attachment and replacement cannot be tested without them." >&2
  exit 1
fi
python3 - "$container/Documents" "$output/fixtures.json" <<'PYFIXTURE'
import hashlib, json, pathlib, sys
folder = pathlib.Path(sys.argv[1])
files = ["UITesting-receipt.jpg", "UITesting-replacement.jpg"]
digests = {name: hashlib.sha256((folder / name).read_bytes()).hexdigest() for name in files}
if len(set(digests.values())) != 2:
    sys.exit("Photo fixtures must contain different images to verify replacement.")
pathlib.Path(sys.argv[2]).write_text(json.dumps(digests, indent=2) + "\n")
PYFIXTURE
marker="$container/Documents/.split-my-meal-photo-fixtures.json"
pending="$marker.pending"
if [[ -f "$pending" ]]; then
  echo "A previous Photos import did not finalize. Use a fresh dedicated simulator to avoid ambiguous partial imports." >&2
  exit 1
fi
if [[ -f "$marker" ]]; then
  if ! cmp -s "$marker" "$output/fixtures.json"; then
    echo "Receipt fixtures changed. Create a fresh dedicated simulator rather than adding ambiguous duplicate photos." >&2
    exit 1
  fi
  echo "reused-existing-fixtures" > "$output/photo-import.txt"
else
  cp "$output/fixtures.json" "$pending"
  xcrun simctl addmedia "$udid" "$container/Documents/UITesting-receipt.jpg" "$container/Documents/UITesting-replacement.jpg"
  mv "$pending" "$marker"
  echo "imported-two-distinct-fixtures" > "$output/photo-import.txt"
fi
xcrun simctl terminate "$udid" shreyassane.SplitMyMeal-Prod-A
if [[ "$live_requested" == true ]]; then
  echo '{"latitude":37.7749,"longitude":-122.4194,"source":"synthetic simulator coordinate"}' > "$output/location.json"
  xcrun simctl location "$udid" set 37.7749,-122.4194
fi
if [[ -n "${SIMULATOR_INCREASE_CONTRAST:-}" ]]; then
  if [[ -z "${SIMULATOR_UDID:-}" || ! "$SIMULATOR_INCREASE_CONTRAST" =~ ^(enabled|disabled)$ ]]; then
    echo "Increase Contrast verification requires an explicit dedicated SIMULATOR_UDID and enabled|disabled value." >&2
    exit 1
  fi
  original_contrast="$(xcrun simctl ui "$udid" increase_contrast)"
  if [[ ! "$original_contrast" =~ ^(enabled|disabled)$ ]]; then
    echo "Simulator Increase Contrast setting is unavailable: $original_contrast" >&2
    original_contrast=""
    exit 1
  fi
  xcrun simctl ui "$udid" increase_contrast "$SIMULATOR_INCREASE_CONTRAST"
  printf 'original=%s\nverified=%s\n' "$original_contrast" "$SIMULATOR_INCREASE_CONTRAST" > "$output/increase-contrast.txt"
fi
if [[ "${RECORD_DEMO_VIDEO:-0}" == 1 ]]; then
  demo_selected=false
  selected_count=0
  for argument in "$@"; do
    if [[ "$argument" == -only-testing:* ]]; then selected_count=$((selected_count + 1)); fi
    if [[ "$argument" == -only-testing:SplitMyMealUITests/MealJourneyTests/testDemoWalkthrough ]]; then demo_selected=true; fi
  done
  if [[ "$demo_selected" != true || "$selected_count" -ne 1 ]]; then
    echo "Recording requires -only-testing:SplitMyMealUITests/MealJourneyTests/testDemoWalkthrough." >&2
    exit 1
  fi
  xcrun simctl io "$udid" recordVideo --codec=h264 "$output/demo-walkthrough.mp4" > "$output/video.log" 2>&1 &
  video_pid=$!
  for attempt in {1..50}; do
    if rg -q 'Recording started' "$output/video.log"; then break; fi
    if ! kill -0 "$video_pid" 2>/dev/null; then cat "$output/video.log" >&2; exit 1; fi
    sleep 0.1
  done
  if ! rg -q 'Recording started' "$output/video.log"; then
    echo "Simulator recording did not start within 5 seconds." >&2
    exit 1
  fi
fi
# Bash3.2 treats an empty named array as unset under nounset. Build a nonempty
# command instead, appending the optional stable-suite filter conditionally.
test_command=(xcodebuild test-without-building "${common[@]}" -resultBundlePath "$output/Tests.xcresult")
if [[ "$live_requested" != true ]]; then test_command+=(-skip-testing:SplitMyMealUITests/LiveMapKitTests); fi
test_command+=("$@")
"${test_command[@]}" 2>&1 | tee "$output/test.log"
