#!/usr/bin/env bash
# preflight-unsloth.sh — read-only check of this machine against Unsloth's documented
# requirements (2026-08-05). Installs nothing, writes nothing, changes no state.
#
# Usage: bash preflight-unsloth.sh
# Exit code is always 0; read the PASS/WARN/FAIL lines.

set -u

pass() { printf '  PASS  %s\n' "$1"; }
warn() { printf '  WARN  %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; }
head_() { printf '\n== %s ==\n' "$1"; }

head_ "Operating system"
# Documented: Linux & WSL (Ubuntu 20.04+), Windows 10/11 64-bit, macOS 12+.
uname_s="$(uname -s 2>/dev/null || echo unknown)"
printf '  detected: %s\n' "$uname_s"
case "$uname_s" in
  Linux*)  pass "Linux/WSL is a supported platform (Ubuntu 20.04+ documented)" ;;
  Darwin*) warn "macOS 12+ is supported for install, but Apple Silicon/MLX training was in development, not GA" ;;
  MINGW*|MSYS*|CYGWIN*) pass "Windows 10/11 64-bit is a supported platform" ;;
  *)       warn "unrecognized OS — confirm against the requirements page" ;;
esac

head_ "Python (need >=3.11 and <3.14)"
py="$(command -v python3 || command -v python || true)"
if [ -z "$py" ]; then
  fail "no python on PATH"
else
  pyver="$("$py" -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null || echo "?")"
  printf '  detected: %s (%s)\n' "$pyver" "$py"
  case "$pyver" in
    3.11|3.12|3.13) pass "Python $pyver is in the supported range" ;;
    "?")            fail "could not determine Python version" ;;
    *)              fail "Python $pyver is outside the documented range (>=3.11, <3.14)" ;;
  esac
fi

head_ "Build toolchain (git, cmake, C++ compiler)"
for tool in git cmake; do
  if command -v "$tool" >/dev/null 2>&1; then pass "$tool found"; else fail "$tool not found (required)"; fi
done
if command -v g++ >/dev/null 2>&1 || command -v clang++ >/dev/null 2>&1 || command -v cl >/dev/null 2>&1; then
  pass "C++ compiler found"
else
  fail "no C++ compiler found (g++/clang++/cl required)"
fi

head_ "CUDA toolkit (need 12.4+, or 12.8+ on Blackwell)"
if command -v nvcc >/dev/null 2>&1; then
  nvcc_ver="$(nvcc --version 2>/dev/null | sed -n 's/.*release \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n1)"
  printf '  detected: CUDA %s\n' "${nvcc_ver:-unknown}"
  major="${nvcc_ver%%.*}"; minor="${nvcc_ver##*.}"
  if [ -n "${nvcc_ver:-}" ] && [ "${major:-0}" -ge 13 ] 2>/dev/null; then
    pass "CUDA $nvcc_ver meets the 12.4+ floor"
  elif [ "${major:-0}" -eq 12 ] 2>/dev/null && [ "${minor:-0}" -ge 4 ] 2>/dev/null; then
    pass "CUDA $nvcc_ver meets the 12.4+ floor (Blackwell GPUs need 12.8+)"
  else
    fail "CUDA ${nvcc_ver:-unknown} is below the documented 12.4+ floor"
  fi
else
  warn "nvcc not on PATH — CUDA toolkit may be missing (required for NVIDIA training)"
fi

head_ "GPU: compute capability (need >=7.0) and VRAM"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv,noheader 2>/dev/null |
  while IFS=, read -r name cap mem; do
    cap="$(printf '%s' "$cap" | tr -d ' ')"
    printf '  GPU: %s | compute_cap %s | VRAM%s\n' "$(printf '%s' "$name" | sed 's/^ *//')" "$cap" "$mem"
    capmaj="${cap%%.*}"
    if [ "${capmaj:-0}" -ge 7 ] 2>/dev/null; then
      pass "compute capability $cap meets the 7.0 minimum"
    else
      fail "compute capability $cap is below the 7.0 minimum"
    fi
  done
else
  warn "nvidia-smi not found — no NVIDIA GPU visible; AMD/Intel have separate install guides"
fi

head_ "VRAM budget reference (documented requirements)"
cat <<'TABLE'
  Params | QLoRA (4-bit) | LoRA (16-bit)
  3B     | 3.5 GB        | 8 GB
  7B     | 5 GB          | 19 GB
  70B    | 41 GB         | 164 GB
  405B   | 237 GB        | 950 GB
  Rule of thumb for reasoning/RL: params in billions ~= VRAM in GB.
  If a run OOMs, lower batch size first — the docs name it as the common cause.
TABLE

head_ "Installed packages (informational)"
if [ -n "${py:-}" ]; then
  "$py" - <<'PY' 2>/dev/null || echo "  (import check unavailable)"
import importlib.metadata as md
for pkg in ("unsloth", "unsloth_zoo", "torch", "xformers", "bitsandbytes", "triton", "vllm"):
    try:
        print(f"  {pkg}: {md.version(pkg)}")
    except Exception:
        print(f"  {pkg}: not installed")
PY
fi

printf '\nDone. Nothing was modified.\n'

# Sources:
#   https://docs.unsloth.ai/get-started/beginner-start-here/unsloth-requirements
#   https://docs.unsloth.ai/get-started/install-and-update
# Fetched: 2026-08-05
