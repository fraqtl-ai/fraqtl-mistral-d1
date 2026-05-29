#!/usr/bin/env bash
#
# build.sh — cmake-build the patched llama.cpp with CUDA support.
#
# Usage:
#   ./build.sh [work_dir] [cuda_arch]
#
# Defaults:
#   work_dir   = ./build-fraqtl-mistral-d1
#   cuda_arch  = 90  (H100). Override for your GPU:
#                80 = A100, 89 = Ada (4090), 90 = Hopper (H100/H200)
#
# Builds the llama-completion target. Other targets (llama-cli,
# llama-perplexity) build the same way; pass `--target NAME` to cmake --build.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${1:-$(pwd)/build-fraqtl-mistral-d1}"
CUDA_ARCH="${2:-90}"

REPO="$WORK_DIR/llama.cpp"

echo "================================================================"
echo "fraQtl D1 — build patched llama.cpp"
echo "================================================================"
echo "  Repo       : $REPO"
echo "  CUDA arch  : $CUDA_ARCH"
echo ""

if [ ! -d "$REPO" ]; then
    echo "ERROR: expected $REPO to exist. Run apply.sh first." >&2
    exit 1
fi

cd "$REPO"

# Verify the patch landed by looking for one of the new files.
if [ ! -f "src/llama-fraqtl.h" ]; then
    echo "ERROR: src/llama-fraqtl.h not found. Run apply.sh first." >&2
    exit 1
fi

if [ ! -d build ]; then
    echo "[1/2] cmake configure (GGML_CUDA=ON, sm_$CUDA_ARCH) ..."
    cmake -B build \
        -DGGML_CUDA=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CUDA_ARCHITECTURES="$CUDA_ARCH" \
        -DLLAMA_CURL=OFF
fi

echo "[2/2] cmake --build (target llama-completion) ..."
cmake --build build -j "$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 8)" --target llama-completion

CLI="$REPO/build/bin/llama-completion"
if [ -x "$CLI" ]; then
    echo ""
    echo "✓ Build succeeded."
    echo "  Binary: $CLI"
    echo ""
    echo "  fraqtl flags:"
    "$CLI" --help 2>&1 | grep -E '^\s+--fraqtl-' || true
else
    echo "ERROR: build completed but binary not found at $CLI" >&2
    exit 1
fi
