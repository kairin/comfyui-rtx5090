#!/bin/bash
# =============================================================================
# ComfyUI Startup with DGX Spark Optimizations (Optional)
# Use this instead of start.sh for better memory utilization
# =============================================================================
set -e

source comfyui-env/bin/activate
cd ComfyUI

# Memory optimizations for 128GB unified memory
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"
export CUDA_MODULE_LOADING=LAZY

# Thread config: Grace CPU has 10 performance + 10 efficiency cores
# Using only performance cores for consistent latency
export OMP_NUM_THREADS=10
export TORCH_NUM_THREADS=10

echo "Starting ComfyUI on DGX Spark (optimized)..."
echo "Memory: 128GB unified | Threads: 10 (performance cores)"
echo "Access at: http://<DGX_SPARK_IP>:8188"
echo ""

python main.py --listen 0.0.0.0 --highvram "$@"
