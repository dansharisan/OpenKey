#!/bin/bash
# Build and run the engine tests.
#   tests/engine/run.sh               run all tests
#   tests/engine/run.sh --probe keys  print what the engine types for each key sequence

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENGINE="$ROOT/Sources/OpenKey/engine"
OUT="$ROOT/build/engine_test"

mkdir -p "$ROOT/build"
clang++ -std=c++17 -g -O0 -fsanitize=address,undefined -Wno-deprecated-declarations \
    -o "$OUT" \
    "$ROOT/tests/engine/engine_test.cpp" \
    "$ENGINE/Engine.cpp" "$ENGINE/Vietnamese.cpp" "$ENGINE/Macro.cpp" \
    "$ENGINE/SmartSwitchKey.cpp" "$ENGINE/ConvertTool.cpp"

"$OUT" "$@"
