# QUICKSTART — Reproduce the D1 result

This document walks through each step of the 4-step recipe in the [README](README.md), with prereqs and troubleshooting.

## Prereqs

- Linux (tested on Ubuntu 22.04) + CUDA Toolkit ≥ 12.1
- NVIDIA GPU with compute capability ≥ 8.0 (Ampere / Ada / Hopper)
- `git`, `cmake ≥ 3.18`, `nvcc`, `python3 ≥ 3.10`
- `huggingface-cli` (`pip install -U huggingface_hub`) for downloading the base model
- ~5 GB free for the Mistral 7B GGUF
- ~25 GB free GPU VRAM for the fp16-KV baseline run
- ~14 GB free GPU VRAM for the fraQtl D1 run

## Step 1 — apply the patch

```bash
./patch/apply.sh
```

What it does:
1. Clones `https://github.com/ggerganov/llama.cpp` into `./build-fraqtl-mistral-d1/llama.cpp` (200-commit shallow).
2. Fetches and checks out the pinned upstream SHA `b760272f1a25fcae065d827ce2cbcaa035597b02`.
3. Runs `git apply --check` followed by `git apply` on `patch/fraqtl-mistral-d1.patch`.

The patch touches 24 files (the 7 new `--fraqtl-*` CLI flags + the sidecar loader + the V/K decompression kernels + the runtime arena).

**Troubleshooting:**

| Symptom | Fix |
|---|---|
| `fatal: repository 'https://github.com/ggerganov/llama.cpp' not found` | Check network / corporate proxy |
| `error: patch failed` on `git apply --check` | Your upstream HEAD doesn't match the pin. Run `git checkout b760272f1a25fcae065d827ce2cbcaa035597b02` manually. |
| `Permission denied` on `apply.sh` | `chmod +x patch/*.sh` |

## Step 2 — build with CUDA

```bash
./patch/build.sh ./build-fraqtl-mistral-d1 90
```

The second argument is the CUDA architecture:
- `80` = A100 (sm_80)
- `89` = Ada / RTX 4090 (sm_89)
- `90` = H100 / H200 (sm_90)

Default builds the `llama-completion` target. For `llama-cli` or `llama-perplexity`, run:

```bash
cd build-fraqtl-mistral-d1/llama.cpp
cmake --build build -j$(nproc) --target llama-cli
```

Build time on a modern desktop CPU is ~5 min for `llama-completion` alone, ~10 min for the full set of targets.

**Troubleshooting:**

| Symptom | Fix |
|---|---|
| `CMAKE_CUDA_ARCHITECTURES is empty` | Pass the arch as the 2nd argument. Default in this build script is 90 (H100). |
| `nvcc: command not found` | `export PATH=/usr/local/cuda/bin:$PATH` |
| `error: too many initializers for ...` | Wrong upstream pin. Step 1 should have left HEAD at `b760272f`. |

## Step 3 — download the base model

Any public Mistral-7B-Instruct-v0.3 Q4_K_M GGUF works:

```bash
huggingface-cli download bartowski/Mistral-7B-Instruct-v0.3-GGUF \
  Mistral-7B-Instruct-v0.3-Q4_K_M.gguf --local-dir .
```

You can also use any other public quantizer's Q4_K_M of the same base model — the sidecar is fp16-derived and weight-quant-orthogonal.

## Step 4 — run the smoke test

```bash
./patch/smoke.sh ./build-fraqtl-mistral-d1 ./Mistral-7B-Instruct-v0.3-Q4_K_M.gguf
```

This runs `llama-completion` with the full D1 command line (see `patch/smoke.sh` for the exact flags) and emits a baseline trace.

In a separate terminal, capture the VRAM peak:

```bash
nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1
```

## Compare against the receipt

```bash
cat receipts/d1_q4km_kv_128k.json
```

Expected values (locked, three-run reproduced):

| Metric | Value | Tolerance |
|---|---:|---|
| Live VRAM peak | 13,261 MiB | ±100 MiB |
| NIAH 5-fact retrieval | 5 / 5 | exact |
| Quality drift vs fp16 KV | inside reproducibility noise | — |

If you're more than 100 MiB off, check:
- Did you pass `--ub 2048 -b 2048`? Smaller ubatch can shift the peak.
- Are there other CUDA processes on the GPU?
- Is your YaRN scaling configured? `--rope-scaling yarn --rope-scale 4.0 --yarn-orig-ctx 32768`

## What good output looks like

The `llama-completion` console output should:
1. Show `fraqtl: ARENA_CREATED total_bytes=...` from the runtime arena init
2. Show `fraqtl: V sidecar loaded` and `fraqtl: K sidecar loaded`
3. Produce coherent generation (the prompt `The capital of France is` should continue naturally, e.g. `" Paris..."`)

If you see garbled output: the sidecar may not match your model weights (Mistral-7B-Instruct-v0.3-specific) or `--fraqtl-kv-protect 32` may be wrong for your sidecar (this bundle ships sidecars built for K_PROTECT=32).

## What's NOT measured here

- Throughput (tok/s) vs upstream KV-quant options — we don't publish head-to-head numbers.
- Other models — sidecars are weight-revision-specific.
- Other context lengths (16K/32K/64K) — D1 is the locked 128K claim.
- Other GPUs (consumer-class) — receipts are H100/A100. Your VRAM peak may shift slightly on other hardware.

## Need calibration on a different model?

DM contact@fraqtl.ai. That's the service business — the runtime here is the demo.
