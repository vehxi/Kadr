#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kadr-library-benchmark.XXXXXX")"
cd "$ROOT_DIR"

# This opt-in build cannot open the user's library or clean up their covers.
action=test
for trial in 1 2 3; do
  for count in 100 1000 5000; do
    TEST_RUNNER_KADR_PERFORMANCE_COUNT="$count" \
    TEST_RUNNER_KADR_PERFORMANCE_OUTPUT="$WORK_DIR/$count-$trial.json" xcodebuild -quiet \
        -project Kadr.xcodeproj -scheme Kadr -configuration Release \
        -destination 'platform=macOS,arch=arm64' -derivedDataPath "$WORK_DIR" \
        -only-testing:KadrTests/LibraryPerformanceTests ENABLE_TESTABILITY=YES \
        'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) KADR_ISOLATED_TEST_HOST' \
        CODE_SIGNING_ALLOWED=NO "$action" > "$WORK_DIR/$count-$trial.log" 2>&1
    action=test-without-building
    printf 'Finished %s records, trial %s; JSON: %s/%s-%s.json\n' "$count" "$trial" "$WORK_DIR" "$count" "$trial"
  done
done
printf 'Build and results: %s\n' "$WORK_DIR"
