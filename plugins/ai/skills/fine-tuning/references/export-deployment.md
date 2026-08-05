# Exporting and Deploying an Unsloth Fine-Tune

Read when saving a trained model, choosing a quantization method, serving with vLLM or Ollama, or debugging garbled output after export. Facts as of 2026-08-05.

## Saving to GGUF (llama.cpp / Ollama / LM Studio)

> Source: https://docs.unsloth.ai/basics/inference-and-deployment/saving-to-gguf

Direct one-liner export:

```python
model.save_pretrained_gguf("directory", tokenizer, quantization_method = "q4_k_m")
model.save_pretrained_gguf("directory", tokenizer, quantization_method = "q8_0")
model.save_pretrained_gguf("directory", tokenizer, quantization_method = "f16")
```

Push straight to the Hugging Face Hub:

```python
model.push_to_hub_gguf("hf_username/directory", tokenizer, quantization_method = "q4_k_m")
```

Manual path — merge to 16-bit, then convert with llama.cpp directly:

```python
model.save_pretrained_merged("merged_model", tokenizer, save_method = "merged_16bit")
```

```bash
git clone https://github.com/ggml-org/llama.cpp
cmake llama.cpp -B llama.cpp/build -DBUILD_SHARED_LIBS=OFF -DGGML_CUDA=ON
cmake --build llama.cpp/build --config Release -j

python llama.cpp/convert_hf_to_gguf.py merged_model --outfile model-F16.gguf --outtype f16
```

Quantization methods:

- `q4_k_m` — uses Q6_K for half of the `attention.wv` and `feed_forward.w2` tensors and Q4_K elsewhere; a quality/size hybrid.
- `q5_k_m` — same hybrid strategy at higher precision.
- `q8_0` — fast conversion, generally acceptable quality/size tradeoff.
- `f16` — fastest conversion, retains full accuracy, largest file.

OOM during GGUF save — cap memory usage:

```python
model.save_pretrained_gguf("directory", tokenizer, maximum_memory_usage = 0.5)
```

## Saving and deploying for vLLM

> Source: https://docs.unsloth.ai/basics/inference-and-deployment/vllm-guide

vLLM's native serving path needs a full merged checkpoint, not just a LoRA adapter:

```python
model.save_pretrained_merged("finetuned_model", tokenizer, save_method = "merged_16bit")
```

Or push directly to the Hub:

```python
model.push_to_hub_merged("hf/model", tokenizer, save_method = "merged_16bit", token = "")
```

Serve it:

```bash
vllm serve finetuned_model
# or, if the relative path isn't found:
vllm serve /full/path/to/finetuned_model
```

The docs explicitly discourage merging to 4-bit for general deployment: "I highly discourage you, unless you know what you are going to do with the 4bit model." LoRA-adapter-only saving is also supported, for adapter-based serving.

## Saving to Ollama

> Source: https://docs.unsloth.ai/basics/inference-and-deployment/saving-to-ollama

1. Export the fine-tune to GGUF. The Ollama walkthrough defaults to `Q8_0` for the quick path, though `q4_k_m` and others are usable.
2. Unsloth auto-generates a `Modelfile` alongside the GGUF, containing model settings plus the exact chat template used during fine-tuning. Print and inspect it before deploying.
3. Run `ollama create` pointing at the GGUF plus the generated `Modelfile` to register the model with Ollama.
4. Start the server — `ollama serve` locally; in Colab, launched via `subprocess` in the background.

**Critical gotcha:** the chat template used at Ollama inference time must exactly match the one used during fine-tuning. Template mismatch is cited as "the most common cause" of gibberish or degraded output after export.

## Sources

- https://docs.unsloth.ai/basics/inference-and-deployment/saving-to-gguf
- https://docs.unsloth.ai/basics/inference-and-deployment/vllm-guide
- https://docs.unsloth.ai/basics/inference-and-deployment/saving-to-ollama

Fetched: 2026-08-05
