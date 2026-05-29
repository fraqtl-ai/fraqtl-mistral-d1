# D1 / T1 Receipts — Methodology

This document describes how the locked numbers in the `*.json` receipts in this
folder were measured, so anyone can reproduce them or audit the claim.

## Setup

| Field | Value |
|---|---|
| Base model | `mistralai/Mistral-7B-Instruct-v0.3` |
| Public Q4_K_M GGUF used in D1 | any public Q4_K_M quantizer; this bundle's smoke uses `bartowski/Mistral-7B-Instruct-v0.3-GGUF` |
| Hardware | NVIDIA H100 80 GB SXM5 (CC 9.0) |
| CUDA toolkit | 12.4 |
| llama.cpp upstream | `b760272f1a25fcae065d827ce2cbcaa035597b02` |
| Patch | `patch/fraqtl-mistral-d1.patch` (in this bundle) |
| Context length | 131,072 tokens (YaRN ×4 over the native 32,768) |
| Ubatch | 2048 |
| Compute | flash-attention ON (`-fa on`) |

## Runs

Five configurations, **same weights, same Q4_K_M kernel path**, varying only the KV cache:

| Receipt | KV cache | CLI difference |
|---|---|---|
| `fp16_kv_baseline_128k.json` | fp16 | `--cache-type-k f16 --cache-type-v f16` (no `--fraqtl-*`) |
| `q8_0_baseline_128k.json` | Q8_0 | `--cache-type-k q8_0 --cache-type-v q8_0` (no `--fraqtl-*`) |
| `q4_0_baseline_128k.json` | Q4_0 | `--cache-type-k q4_0 --cache-type-v q4_0` (no `--fraqtl-*`) |
| `d1_q4km_kv_128k.json` | fraQtl D1 | `--fraqtl-kv --fraqtl-eigenbasis … --fraqtl-k-eigenbasis … --fraqtl-sink-tokens 8 --fraqtl-residual-window 2048 --fraqtl-kv-protect 32` |
| `t1_fp16_weights_d1_kv_128k.json` | fraQtl D1 + fp16 **weights** | same as D1 but with the fp16 model file instead of the Q4_K_M GGUF |

## Quality measurement — NIAH

We use a **5-fact "needle-in-a-haystack" retrieval** test. The prompt is built as:

1. A long filler context (~128K tokens) of public text that does NOT mention any of the 5 needles.
2. Five distinct facts ("needles") inserted at depths {0%, 25%, 50%, 75%, 100%} of the filler.
3. A retrieval query that asks the model to recall each fact by its identifying lead phrase.

Scoring: exact-match recall, rolled up to a 0–5 integer (one point per correctly-recalled needle). The integer NIAH score is what each receipt records.

Three independent runs per configuration. The integer NIAH score reproduced exactly across runs in all five configurations; live VRAM peak reproduced to within ±2 MiB.

## VRAM measurement

Live VRAM peak captured via `nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits`, polled every 200 ms during the entire run, taking the maximum. Compute scratch, weights, KV cache, and all CUDA allocations are included.

## Reproducibility

Each receipt JSON includes:

```jsonc
{
  "schema": "d1_receipt_v1",
  "run_label": "...",
  "kv_cache_treatment": "...",
  "vram_peak_mib": 13261,
  "niah_5fact_score": 5,
  "n_independent_runs": 3,
  "vram_drift_across_runs_mib": 2,
  "niah_drift_across_runs": 0,
  "hardware": "H100-SXM5-80GB-PCIe",
  "cuda_toolkit": "12.4",
  "upstream_pin": "b760272f1a25fcae065d827ce2cbcaa035597b02",
  "patch_sha256": "<sha>",
  "v_sidecar_sha256": "<sha>",
  "k_sidecar_sha256": "<sha>",
  "ts_first_run": "<iso>",
  "ts_last_run": "<iso>"
}
```

If you reproduce a different number on your hardware, please open an issue with your `nvidia-smi`, `cuda-toolkit --version`, your model GGUF sha256, and the sidecar shas — we'd like to understand the delta.

## Honest scope

- We do **not** measure throughput (tokens/sec) in this release. Decode tok/s is workload- and hardware-dependent and we have not yet published apples-to-apples numbers vs the in-tree KV-quant options.
- We do **not** claim D1 is the smallest Q4-class KV at 128K. `--cache-type-k q4_0` is smaller (11,287 MiB) but **fails NIAH** at this context length (0/5). D1 is the smallest Q4-class KV that **still retrieves correctly** at 128K.
- D1 is **specifically calibrated** for Mistral-7B-Instruct-v0.3. The same recipe shape generalizes (T1 demonstrates it works with fp16 weights too), but a different base model needs a different sidecar pair.

## Need calibration on a different base model?

The calibration is the service. DM contact@fraqtl.ai.
