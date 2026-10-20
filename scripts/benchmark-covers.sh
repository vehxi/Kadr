#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kadr-cover-benchmark.XXXXXX")"

swiftc -O -g -swift-version 6 -D COVER_THUMBNAILS_AVAILABLE -parse-as-library \
    "$ROOT_DIR/Kadr/Services/CoverThumbnailLoader.swift" \
    "$ROOT_DIR/scripts/benchmarks/CoverLoadingBenchmark.swift" \
    -o "$WORK_DIR/cover-benchmark"

"$WORK_DIR/cover-benchmark" prepare "$WORK_DIR/covers"
for trial in 1 2 3; do
    "$WORK_DIR/cover-benchmark" legacy "$WORK_DIR/covers" 3 > "$WORK_DIR/legacy-$trial.json"
    "$WORK_DIR/cover-benchmark" optimized "$WORK_DIR/covers" 3 > "$WORK_DIR/optimized-$trial.json"
done

printf 'Benchmark results and synthetic covers: %s\n' "$WORK_DIR"
