#!/bin/bash
# =============================================================================
# ComfyUI Startup for DGX Spark (NVIDIA Official)
# Source: https://build.nvidia.com/spark/comfy-ui/instructions
# =============================================================================
set -e

source comfyui-env/bin/activate
cd ComfyUI

echo "Starting ComfyUI on DGX Spark..."
echo "Access at: http://<DGX_SPARK_IP>:8188"
echo ""

python main.py --listen 0.0.0.0 "$@"
