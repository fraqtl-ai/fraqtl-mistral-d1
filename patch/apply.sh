#!/usr/bin/env bash
#
# apply.sh — clone upstream llama.cpp at the pinned SHA + apply the D1 patch.
#
# Usage:
#   ./apply.sh [work_dir]
#
# Defaults to ./build-fraqtl-mistral-d1/ as the working directory.
#
# After this script finishes, build with:
#   ./build.sh [work_dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${1:-$(pwd)/build-fraqtl-mistral-d1}"
PIN="$(cat "$SCRIPT_DIR/PINNED_UPSTREAM.txt" | tr -d '[:space:]')"
PATCH="$SCRIPT_DIR/fraqtl-mistral-d1.patch"

echo "================================================================"
echo "fraQtl D1 — apply patch to upstream llama.cpp"
echo "================================================================"
echo "  Work dir   : $WORK_DIR"
echo "  Upstream   : https://github.com/ggerganov/llama.cpp"
echo "  Pinned SHA : $PIN"
echo "  Patch      : $PATCH"
echo ""

if [ ! -f "$PATCH" ]; then
    echo "ERROR: patch file not found at $PATCH" >&2
    exit 1
fi

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

if [ ! -d "llama.cpp" ]; then
    echo "[1/3] Cloning upstream llama.cpp ..."
    git clone --depth 200 https://github.com/ggerganov/llama.cpp llama.cpp
fi

cd llama.cpp

# Reset to a clean state and check out the pinned commit.
if ! git rev-parse --verify "$PIN" >/dev/null 2>&1; then
    echo "[2/3] Fetching pinned commit $PIN ..."
    git fetch --depth 1 origin "$PIN"
fi

echo "[2/3] Checking out pinned commit ..."
git checkout -q "$PIN"

CUR=$(git rev-parse HEAD)
if [ "$CUR" != "$PIN" ]; then
    echo "ERROR: HEAD is $CUR, expected $PIN" >&2
    exit 1
fi

echo "[3/3] Applying D1 patch ..."
if ! git apply --check "$PATCH" 2>/dev/null; then
    echo "ERROR: patch failed --check on upstream@$PIN" >&2
    echo "       Did you already apply it? Or is the upstream pin wrong?" >&2
    exit 1
fi
git apply "$PATCH"

echo ""
echo "✓ Patched llama.cpp ready at: $WORK_DIR/llama.cpp"
echo "  Next: $SCRIPT_DIR/build.sh \"$WORK_DIR\""
