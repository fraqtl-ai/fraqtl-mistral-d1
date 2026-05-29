# fraQtl D1 — Mistral-7B-v0.3 KV-cache compression at 128K

> A reproducibility bundle for **one specific result**: Mistral-7B-Instruct-v0.3 Q4_K_M at 128K context, 13,261 MiB live VRAM, 5/5 NIAH retrieval. Apply the patch to a pinned upstream `llama.cpp` SHA, build with CUDA, run the smoke test, compare against the locked receipt.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Upstream pin](https://img.shields.io/badge/upstream-b760272f-purple)](https://github.com/ggerganov/llama.cpp/commit/b760272f1a25fcae065d827ce2cbcaa035597b02)
[![Demo: Mistral 7B v0.3](https://img.shields.io/badge/demo-Mistral--7B--v0.3-indigo)](https://huggingface.co/datasets/fraQtl/Mistral-7B-v0.3-fraqtl-sidecars)

## The result

Same Q4_K_M weights, same `llama.cpp` Q4_K_M kernel path. Only the **KV cache treatment** varies. NIAH = "needle-in-a-haystack" 5-fact retrieval at 128K context length, scored 0–5.

| Run | KV cache | Live VRAM peak | NIAH (5-fact retrieval) |
|---|---|---:|---:|
| baseline | fp16 | 22,657 MiB | **5 / 5** |
| `llama.cpp --cache-type-k q8_0` | Q8_0 | 15,437 MiB | 1 / 5 |
| `llama.cpp --cache-type-k q4_0` | Q4_0 | 11,287 MiB | 0 / 5 |
| **fraQtl D1** *(this bundle)* | sidecar + sink/residual | **13,261 MiB** | **5 / 5** |

Weights-orthogonal control (**T1**): fp16 weights + the same fraQtl D1 KV recipe = 22,781 MiB, 5/5 NIAH. The recipe isn't quality-gated by weight quantization; it's a KV-side compression with a per-model calibration sidecar.

→ **fraQtl D1 is the only Q4-class KV configuration that holds NIAH at 128K on this model.** The two in-tree `llama.cpp` KV-quant options both fail at this scale.

## 4-step reproduction

```bash
# 1. Apply the patch to a fresh upstream llama.cpp at the pinned SHA.
./patch/apply.sh

# 2. Build the patched llama.cpp with CUDA. Override sm_NN for your GPU.
./patch/build.sh ./build-fraqtl-mistral-d1 90   # 90=H100, 89=Ada/4090, 80=A100

# 3. Download the base model (any public Mistral-7B-v0.3 Q4_K_M GGUF works).
huggingface-cli download bartowski/Mistral-7B-Instruct-v0.3-GGUF \
  Mistral-7B-Instruct-v0.3-Q4_K_M.gguf --local-dir .

# 4. Run the D1 smoke test + compare against the locked receipt.
./patch/smoke.sh ./build-fraqtl-mistral-d1 ./Mistral-7B-Instruct-v0.3-Q4_K_M.gguf
```

Sidecars (`sidecar_real_u_…bin` and `…-k.fraqtl-k-eigenbasis.bin`) are in `sidecars/` — verified against `sidecars/SHA256SUMS`.

## What's in this bundle

```
.
├── README.md                         ← this file
├── QUICKSTART.md                     ← the same recipe with annotations
├── LICENSE                           ← MIT
├── patch/
│   ├── fraqtl-mistral-d1.patch       ← diff vs upstream pin
│   ├── apply.sh                      ← clone + checkout + apply
│   ├── build.sh                      ← cmake + nvcc
│   ├── smoke.sh                      ← run D1 + nudge to compare receipt
│   └── PINNED_UPSTREAM.txt           ← the locked upstream SHA
├── sidecars/
│   ├── sidecar_real_u_mistral-7b-instruct-v0.3.bin       (8.4 MB, V eigenbasis)
│   ├── mistral-7b-instruct-v0.3-k.fraqtl-k-eigenbasis.bin (8.4 MB, K eigenbasis)
│   └── SHA256SUMS
└── receipts/
    ├── d1_q4km_kv_128k.json                      ← the headline (13,261 MiB, 5/5)
    ├── t1_fp16_weights_d1_kv_128k.json           ← weights-orthogonal control
    ├── q8_0_baseline_128k.json
    ├── q4_0_baseline_128k.json
    ├── fp16_kv_baseline_128k.json
    └── methodology.md                            ← how NIAH was scored, prompts, hardware
```

## What's NOT in this bundle (the moat)

This is a **runtime demo**: it consumes the precomputed sidecars to reproduce D1 inference. The private fraQtl calibration stack that **generates** those sidecars from a base model is not part of this release:

- Calibration code
- Theorem / scoring math
- Bit-budget allocator
- Adaptive policy generation
- Sidecar factory pipeline

**Translation**: anyone can drive the car (run D1 on Mistral-7B-v0.3 with the included sidecars). To get fraQtl-quality KV compression on a different base model (Llama 3.1 / Qwen / DeepSeek / your own checkpoint), the calibration is the service business — **DM contact@fraqtl.ai**.

## Honest scope

- **Reproducibility, not novelty.** `llama.cpp` has shipped `--cache-type-k q8_0` and `q4_0` for over a year. The claim is *retrieval quality at 128K*, not "first to KV compression."
- **Throughput is not measured publicly.** We don't yet publish head-to-head tok/s vs the upstream KV-quant options.
- **Scope-locked to Mistral-7B-Instruct-v0.3 Q4_K_M.** Other base models need their own sidecars.
- **Quality-orthogonal to weight quant.** T1 receipt shows the same D1 KV recipe works with fp16 weights too.

## License

MIT, inherits upstream `ggml-org/llama.cpp`. The patch additions (`--fraqtl-*` CLI flags, the sidecar loader, the decompression kernels in `ggml/src/ggml-cuda/fraqtl*`) ship under the same MIT license. Calibrator code (private) is not part of this license grant and not in this repo.

## Contact

- 🌐 [fraqtl.ai](https://fraqtl.ai)
- 📬 contact@fraqtl.ai
- 🧪 Free diagnostic: `pip install fraqtl-diagnostic` or [HF Space](https://huggingface.co/spaces/fraQtl/fraqtl-diagnostic) — project savings on any HF model id in 30 seconds, no GPU needed.

---

**For calibration on other base models, partnership, or commercial inquiries — DM.** The runtime is open here; the calibration is the service.
