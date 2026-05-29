# Contributing to fraqtl-mistral-d1

This repo is a **reproducibility bundle**, not a general-purpose project. It exists to lock the public claim "Mistral-7B-Instruct-v0.3 Q4_K_M at 128K = 13,261 MiB / 5-of-5 NIAH" and let anyone re-run that result with the included patch + sidecars + scripts.

## What this repo IS

A small, audit-clean public artifact:
- A **patch** against a pinned upstream `llama.cpp` SHA (`b760272f1a25fcae065d827ce2cbcaa035597b02`).
- Two precomputed **sidecar binaries** (V + K eigenbasis) for Mistral-7B-Instruct-v0.3.
- Five **receipt JSONs** locking the measured numbers + methodology.
- Three **scripts** (apply / build / smoke) that walk you through reproduction.

## What this repo is NOT

- It is **not** a fork of llama.cpp. Use the upstream `ggerganov/llama.cpp` repo for upstream development.
- It does **not** contain the fraQtl **calibrator** — the offline code that *produces* the sidecars from a base model. That's our research and stays private.
- It does **not** contain code for adaptive bit-budget allocation, theorem-derived scoring, or any of the calibration-stack policy logic that determines *what* to compress and by *how much*.

## What's open vs what's the moat

| What | Open (this repo) | Private (fraQtl service) |
|---|---|---|
| Runtime CUDA kernels that decompress V and K | ✅ | — |
| Sidecar binary loader | ✅ | — |
| Runtime arena memory plumbing | ✅ | — |
| CLI flag surface (7 `--fraqtl-*` flags) | ✅ | — |
| Sidecars for **Mistral-7B-Instruct-v0.3** | ✅ | — |
| **Calibrator** — generates sidecars from a base model | — | ✅ |
| Theorem math, scoring, bit-budget allocator | — | ✅ |
| Adaptive policy generation | — | ✅ |
| Per-(layer, kvh) protection-rank selection | — | ✅ |
| Sidecars for other base models | — | DM us |

**Translation**: anyone can drive the car (run D1 on Mistral-7B-v0.3 with the included sidecars). For fraQtl-quality KV compression on Llama 3.1 / Qwen / DeepSeek / your own checkpoint, the calibration is the service business — **DM contact@fraqtl.ai**.

## Contributing to THIS repo

Acceptable PRs:
- **Bug fixes** in the patch (e.g., a missing `#include`, a wrong cast).
- **Build / portability fixes** for the apply/build/smoke scripts.
- **Methodology documentation** improvements (clarify NIAH scoring, add troubleshooting cases).
- **Reproduction reports** on different hardware classes (consumer 4090, A100 SXM, etc.) — open an issue with your full output + diff vs the locked receipt.

Out-of-scope for this repo:
- Calibration on other base models (DM us instead).
- New features in the runtime — fraqtl-mistral-d1 is a frozen artifact at v0.1.4. New runtime features ship in future-tagged bundles.
- Upstream `llama.cpp` changes — file those at https://github.com/ggerganov/llama.cpp.

## Issues + bug reports

When opening an issue, please include:
- Your hardware (GPU model, CUDA version)
- Your `nvidia-smi` output during the smoke run
- The exact CLI you ran
- The `nvidia-smi` peak you observed vs the receipt's expected value

## Security / IP

If you find something in the patch that you believe leaks proprietary information (algorithms, internal codenames, etc.), please **do not open a public issue**. Email contact@fraqtl.ai with subject `[security] fraqtl-mistral-d1`.

## License

All contributions to this repo are released under the MIT license (see `LICENSE`).
