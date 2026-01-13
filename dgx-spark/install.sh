#!/bin/bash
# =============================================================================
# ComfyUI Installation for DGX Spark (NVIDIA Official Instructions)
# Source: https://build.nvidia.com/spark/comfy-ui/instructions
# =============================================================================
set -e

echo "=============================================="
echo "  DGX Spark ComfyUI Installation             "
echo "  (NVIDIA Official Instructions)             "
echo "=============================================="
echo ""

# Step 1: Verify prerequisites
echo "[1/6] Checking prerequisites..."
echo "  Python: $(python3 --version 2>&1)"
echo "  pip:    $(pip3 --version 2>&1 | head -1)"
echo "  CUDA:   $(nvcc --version 2>&1 | grep release | awk '{print $6}')"
echo ""
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "  GPU: Check nvidia-smi manually"
echo ""

# Step 2: Create virtual environment
echo "[2/6] Creating virtual environment..."
python3 -m venv comfyui-env
source comfyui-env/bin/activate
echo "  Created: ./comfyui-env"
echo ""

# Step 3: Install PyTorch with CUDA 13.0
echo "[3/6] Installing PyTorch with CUDA 13.0..."
echo "  This may take a few minutes..."
pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu130
echo ""

# Step 4: Clone ComfyUI
echo "[4/6] Cloning ComfyUI..."
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI/
echo "  Cloned to: ./ComfyUI"
echo ""

# Step 5: Install dependencies
echo "[5/6] Installing ComfyUI dependencies..."
pip install -r requirements.txt
echo ""

# Step 6: Download a starter model (SD 1.5)
echo "[6/6] Downloading Stable Diffusion 1.5 model (~2GB)..."
cd models/checkpoints/
wget -q --show-progress https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive/resolve/main/v1-5-pruned-emaonly-fp16.safetensors
cd ../../
echo ""

# Verify installation
echo "=============================================="
echo "  Verifying Installation                     "
echo "=============================================="
python -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA:    {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'GPU:     {torch.cuda.get_device_name(0)}')
"
echo ""

echo "=============================================="
echo "  Installation Complete!                     "
echo "=============================================="
echo ""
echo "To start ComfyUI:"
echo "  source comfyui-env/bin/activate"
echo "  cd ComfyUI"
echo "  python main.py --listen 0.0.0.0"
echo ""
echo "Access at: http://<DGX_SPARK_IP>:8188"
echo ""
