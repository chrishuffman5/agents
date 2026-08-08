# Unsloth Setup, Hardware, and Model Coverage

Read when installing Unsloth, diagnosing an install/CUDA mismatch, sizing hardware for a run, or checking whether a model family or modality is supported. Facts as of 2026-08-05.

Unsloth's docs site 301-redirects `docs.unsloth.ai/*` → `unsloth.ai/docs/*`; content is identical and cited here under the canonical `docs.unsloth.ai` paths.

## System, OS, and Python requirements

> Source: https://docs.unsloth.ai/get-started/beginner-start-here/unsloth-requirements

- OS: Linux and WSL (Ubuntu 20.04+), Windows 10/11 (64-bit), macOS 12 Monterey or newer.
- Python: ≥3.11 and <3.14 (3.13 explicitly supported).
- CUDA Toolkit 12.4+; 12.8+ for Blackwell GPUs.
- Also required: Git, CMake, a C++ compiler, and a Python environment manager (uv, venv, or conda/mamba).
- Core dependencies: xformers, torch, bitsandbytes, triton.
- Explicitly named common OOM cause: batch size set too high.

## GPU hardware support

> Source: https://docs.unsloth.ai/get-started/beginner-start-here/unsloth-requirements

- NVIDIA: minimum CUDA Capability 7.0 — GPUs from 2018 onward, including Blackwell RTX 50. Confirmed working: V100, T4, Titan V, RTX 20 and 50 series, A100, H100, L40. GTX 1070/1080 work but are slow.
- AMD and Intel GPUs: supported through platform-specific install guides.
- Apple Silicon / MLX: in development, not GA as of the fetch date. Do not present it as supported.

## VRAM requirements by model size

> Source: https://docs.unsloth.ai/get-started/beginner-start-here/unsloth-requirements

| Params | QLoRA (4-bit) | LoRA (16-bit) |
|---|---|---|
| 3B | 3.5 GB | 8 GB |
| 7B | 5 GB | 19 GB |
| 70B | 41 GB | 164 GB |
| 405B | 237 GB | 950 GB |

Docs' rule of thumb for full-precision reasoning/RL work: parameter count in billions ≈ VRAM in GB. A free 16 GB Colab GPU comfortably handles GRPO on models up to roughly 16B.

## Installation commands

> Source: https://docs.unsloth.ai/get-started/install-and-update

Recommended (uv, auto-detects the CUDA/torch backend):

```bash
uv pip install unsloth --torch-backend=auto
```

Plain pip:

```bash
pip install unsloth
```

With vLLM, for fast RL / inference-in-the-loop:

```bash
uv pip install unsloth vllm --torch-backend=auto
```

Latest main branch (bleeding edge, no version pin):

```bash
pip uninstall unsloth unsloth_zoo -y && \
pip install --no-deps git+https://github.com/unslothai/unsloth_zoo.git && \
pip install --no-deps git+https://github.com/unslothai/unsloth.git
```

Dedicated virtual environment:

```bash
uv venv unsloth_env --python 3.13
source unsloth_env/bin/activate
uv pip install unsloth --torch-backend=auto
```

Pin an exact CUDA/Torch combination when auto-detection misfires:

```bash
# Torch 2.4 + CUDA 12.1
pip install "unsloth[cu121-torch240] @ git+https://github.com/unslothai/unsloth.git"
# Torch 2.5 + CUDA 12.4
pip install "unsloth[cu124-torch250] @ git+https://github.com/unslothai/unsloth.git"
```

Supported CUDA tags: `cu118`, `cu121`, `cu124`. For Ampere and newer (A100, H100, RTX 3090+), append `-ampere` to the extras tag.

Install platforms covered: macOS, Linux, Windows (PowerShell), WSL. Separate guides exist for Docker, AMD GPUs, Intel GPUs, and Windows-specific setup.

## Supported model families

> Source: https://docs.unsloth.ai/get-started/unsloth-model-catalog

Families with dedicated Unsloth support: Qwen (2, 2.5, 3, 3.5, 3.6 variants), Llama (2, 3, 3.1, 3.2, 3.3, 4), Gemma (2, 3, 3n, 4), DeepSeek (V3, V3.1, R1 and distilled variants), Mistral (Small, Large, NeMo, Magistral, Devstral, Pixtral, Mixtral), GLM (4.5 through 5), Phi (3, 3.5, 4), Kimi (K2, K2.5, K2.6, K2.7-Code, K3), plus NVIDIA Nemotron, gpt-oss, MiniMax, TinyLlama, SmolLM, and others.

Size range: 270M/1B at the small end up to 675B (Mistral Large 3) and 397B-A17B (Qwen3.5 MoE). The most common working range is 3B–70B.

Distribution formats per model: GGUF (llama.cpp / Unsloth Studio), 4-bit safetensors (inference or QLoRA fine-tuning), and 16-bit instruct/base weights.

## Modality coverage beyond text

> Source: https://docs.unsloth.ai/get-started/unsloth-notebooks

- Vision/multimodal fine-tuning: Gemma 4, Qwen3.5, Qwen3-VL, Mistral Ministral 3, DeepSeek-OCR, Llama 3.2 Vision.
- Text-to-speech: Sesame-CSM, Orpheus-TTS, Llasa-TTS, Spark-TTS. Speech-to-text: Whisper Large V3.
- Embeddings: EmbeddingGemma (300M), Qwen3-Embedding 4B, BGE M3, ModernBERT-large.
- Reasoning/RL: dedicated GRPO notebooks.
- Free-tier hardware: Colab free GPU tier is 15 GB VRAM, which caps usable model size; Colab's paid 80 GB GPUs unlock larger models. Some notebooks (e.g. Gemma-4-31B) are marked runnable free on Kaggle.

## Sources

- https://docs.unsloth.ai/get-started/beginner-start-here/unsloth-requirements
- https://docs.unsloth.ai/get-started/install-and-update
- https://docs.unsloth.ai/get-started/unsloth-model-catalog
- https://docs.unsloth.ai/get-started/unsloth-notebooks

Fetched: 2026-08-05
