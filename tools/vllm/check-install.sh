#!/bin/bash
source ~/.venv-vllm-metal/bin/activate

# vLLM version
python -c "import vllm; print(f'vLLM: {vllm.__version__}')"
# -> vLLM: 0.13.0
# vllm-metal plugin
python -c "import vllm_metal; print('vllm-metal: loaded')"
 
# MLX GPU
python -c "import mlx.core as mx; print(f'MLX device: {mx.default_device()}')"
# -> MLX device: gpu
# Quick compute test
python -c "
import mlx.core as mx
a = mx.ones((100, 100)); b = mx.ones((100, 100))
c = a @ b; mx.eval(c)
print(f'GPU matmul: OK ({c[0,0]:.0f})')
"
# -> GPU matmul: OK (100)