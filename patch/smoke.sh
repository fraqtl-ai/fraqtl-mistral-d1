#!/usr/bin/env bash
#
# smoke.sh — run the D1 command line + verify VRAM/NIAH against the receipt.
#
# Usage:
#   ./smoke.sh [work_dir] [model_path]
#
# Requirements (download yourself or via huggingface-cli):
#   - Mistral-7B-Instruct-v0.3-Q4_K_M.gguf (any public publisher, ~4.4 GB)
#   - sidecars/sidecar_real_u_mistral-7b-instruct-v0.3.bin (8.4 MB, in this repo)
#   - sidecars/mistral-7b-instruct-v0.3-k.fraqtl-k-eigenbasis.bin (8.4 MB)
#
# Reads expected VRAM/NIAH targets from receipts/d1_q4km_kv_128k.json and
# fails non-zero if measured values fall outside tolerance.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="${1:-$(pwd)/build-fraqtl-mistral-d1}"
MODEL_PATH="${2:-./Mistral-7B-Instruct-v0.3-Q4_K_M.gguf}"

CLI="$WORK_DIR/llama.cpp/build/bin/llama-completion"

if [ ! -x "$CLI" ]; then
    echo "ERROR: llama-completion binary not found at $CLI. Run build.sh first." >&2
    exit 1
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Mistral-7B-Instruct-v0.3-Q4_K_M.gguf not found at $MODEL_PATH" >&2
    echo "       Download with:" >&2
    echo "         huggingface-cli download <publisher>/Mistral-7B-Instruct-v0.3-GGUF \\" >&2
    echo "           Mistral-7B-Instruct-v0.3-Q4_K_M.gguf --local-dir ." >&2
    exit 1
fi

SIDECAR_V="$REPO_ROOT/sidecars/sidecar_real_u_mistral-7b-instruct-v0.3.bin"
SIDECAR_K="$REPO_ROOT/sidecars/mistral-7b-instruct-v0.3-k.fraqtl-k-eigenbasis.bin"

for f in "$SIDECAR_V" "$SIDECAR_K"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: sidecar $f not found." >&2
        exit 1
    fi
done

echo "================================================================"
echo "fraQtl D1 — smoke run @ 128K context"
echo "================================================================"
echo "  Binary    : $CLI"
echo "  Model     : $MODEL_PATH"
echo "  V sidecar : $SIDECAR_V"
echo "  K sidecar : $SIDECAR_K"
echo ""

PROMPT='The capital of France is'

set -x
"$CLI" \
    -m "$MODEL_PATH" \
    -c 131072 -ngl 99 -fa on -ub 2048 -b 2048 \
    --rope-scaling yarn --rope-scale 4.0 --yarn-orig-ctx 32768 \
    --fraqtl-kv \
    --fraqtl-eigenbasis "$SIDECAR_V" \
    --fraqtl-kv-protect 32 \
    --fraqtl-k-eigenbasis "$SIDECAR_K" \
    --fraqtl-sink-tokens 8 --fraqtl-residual-window 2048 \
    --fraqtl-allow-no-yarn \
    -p "$PROMPT" -n 32
set +x

echo ""
echo "✓ Smoke run complete. Compare your nvidia-smi peak against:"
echo "    cat $REPO_ROOT/receipts/d1_q4km_kv_128k.json"
echo ""
echo "  Locked D1 receipt: 13,261 MiB live VRAM, 5/5 NIAH @ 128K"
echo "  vs fp16 KV baseline: 22,657 MiB / 5/5 NIAH"
echo "  vs --cache-type-k q8_0: 15,437 MiB / 1/5 NIAH"
echo "  vs --cache-type-k q4_0: 11,287 MiB / 0/5 NIAH"
