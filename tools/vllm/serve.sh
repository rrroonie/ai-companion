#!/bin/bash
# Serve a vLLM model (with vllm-metal) on a given port.
# Usage: ./serve-vllm-metal.sh <port> [model]
# Example: ./serve-vllm-metal.sh 8000
# Example: ./serve-vllm-metal.sh 8080 Qwen/Qwen2.5-1.5B-Instruct

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Resolve venv: prefer project .venv-vllm-metal, then ~/.venv-vllm-metal
if [[ -d "$ROOT_DIR/.venv-vllm-metal" ]]; then
  VENV_ACTIVATE="$ROOT_DIR/.venv-vllm-metal/bin/activate"
elif [[ -d "$HOME/.venv-vllm-metal" ]]; then
  VENV_ACTIVATE="$HOME/.venv-vllm-metal/bin/activate"
else
  echo "error: .venv-vllm-metal not found in $ROOT_DIR or $HOME" >&2
  exit 1
fi

source "$VENV_ACTIVATE"

PORT="${1:?Usage: $0 <port> [model]}"
MODEL="${2:-Qwen/Qwen2.5-1.5B-Instruct}"

echo "Serving model: $MODEL"
echo "Port: $PORT"
exec vllm serve "$MODEL" --port "$PORT"
