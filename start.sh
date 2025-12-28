#!/bin/zsh
# =============================================================================
# ComfyUI Startup Script - Optimized for RTX 5090 (Blackwell)
# =============================================================================

echo "🚀 ComfyUI RTX 5090 Optimized Startup"
echo "====================================================="

# -----------------------------------------------------------------------------
# Environment Token Verification
# -----------------------------------------------------------------------------
echo "🔑 Checking API tokens..."
echo "   GitHub Token (GH_TOKEN): $( [ -n "$GH_TOKEN" ] && echo "SET ✓" || echo "NOT SET" )"
echo "   Hugging Face Token: $( [ -n "$HUGGING_FACE_HUB_TOKEN" ] && echo "SET ✓" || echo "NOT SET" )"
echo "   Civitai API Key: $( [ -n "$CIVITAI_API_KEY" ] && echo "SET ✓" || echo "NOT SET" )"
echo "-----------------------------------------------------"

# -----------------------------------------------------------------------------
# RTX 5090 / Blackwell Performance Optimizations
# -----------------------------------------------------------------------------
echo "⚡ Applying RTX 5090 (Blackwell) optimizations..."

# CUDA optimizations
export CUDA_MODULE_LOADING=LAZY
export NVIDIA_TF32_OVERRIDE=1
export CUDA_DEVICE_ORDER=PCI_BUS_ID

# PyTorch memory optimization
export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# cuDNN autotune for optimal kernel selection
export TORCH_CUDNN_BENCHMARK=1
export TORCH_CUDNN_BENCHMARK_LIMIT=10

# Thread optimization for AMD Ryzen 7 7700 (16 threads)
export TORCH_NUM_THREADS=16
export OMP_NUM_THREADS=16
export MKL_NUM_THREADS=16
export OPENBLAS_NUM_THREADS=16

# Triton cache on fast storage
export TRITON_CACHE_DIR=/tmp/triton_cache
mkdir -p /tmp/triton_cache

echo "   ✓ CUDA_MODULE_LOADING=LAZY"
echo "   ✓ NVIDIA_TF32_OVERRIDE=1"
echo "   ✓ PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True"
echo "   ✓ TORCH_CUDNN_BENCHMARK=1"
echo "   ✓ Thread count: 16"
echo "-----------------------------------------------------"

# -----------------------------------------------------------------------------
# Virtual Environment Setup
# -----------------------------------------------------------------------------
VENV_PYTHON="/opt/comf/.venv/bin/python3"
VENV_ACTIVATE="/opt/comf/.venv/bin/activate"
FROZEN_REQUIREMENTS_PATH="/opt/comf/requirements_frozen.txt"

echo "📦 Verifying Python virtual environment..."

# Activate venv and verify pip
source "$VENV_ACTIVATE"
if ! python -m pip --version > /dev/null 2>&1; then
    echo "⚠️  pip not found, attempting to ensure it..."
    python -m ensurepip || { echo "❌ Failed to ensure pip. Exiting."; exit 1; }
fi

# Upgrade pip silently
python -m pip install --upgrade pip setuptools wheel > /dev/null 2>&1 || true

# -----------------------------------------------------------------------------
# Package Verification
# -----------------------------------------------------------------------------
echo "🔍 Verifying critical packages..."

# Check torch
if python -c "import torch" > /dev/null 2>&1; then
    TORCH_VERSION=$(python -c "import torch; print(torch.__version__)")
    CUDA_AVAILABLE=$(python -c "import torch; print(torch.cuda.is_available())")
    echo "   ✓ PyTorch: $TORCH_VERSION (CUDA: $CUDA_AVAILABLE)"
else
    echo "   ❌ PyTorch not found!"
fi

# Check SageAttention
if python -c "import sageattention" > /dev/null 2>&1; then
    echo "   ✓ SageAttention: OK"
else
    echo "   ⚠️  SageAttention not available (will use fallback)"
fi

# Check TensorRT
if python -c "import tensorrt" > /dev/null 2>&1; then
    TRT_VERSION=$(python -c "import tensorrt; print(tensorrt.__version__)")
    echo "   ✓ TensorRT: $TRT_VERSION"
else
    echo "   ⚠️  TensorRT not available"
fi

# Check other critical packages
python -c "import aiohttp; print(f'   ✓ aiohttp: {aiohttp.__version__}')" 2>/dev/null || echo "   ⚠️  aiohttp not available"
python -c "import numpy; print(f'   ✓ numpy: {numpy.__version__}')" 2>/dev/null || echo "   ⚠️  numpy not available"
python -c "import transformers; print(f'   ✓ transformers: {transformers.__version__}')" 2>/dev/null || echo "   ⚠️  transformers not available"

echo "-----------------------------------------------------"

# -----------------------------------------------------------------------------
# GPU Information
# -----------------------------------------------------------------------------
echo "🖥️  GPU Information:"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null | while read line; do
        echo "   $line"
    done
else
    echo "   nvidia-smi not available"
fi
echo "-----------------------------------------------------"

# -----------------------------------------------------------------------------
# Launch ComfyUI with RTX 5090 Optimizations
# -----------------------------------------------------------------------------
echo "✨ Launching ComfyUI with Blackwell optimizations..."
echo ""
echo "   Flags:"
echo "   --use-sage-attention   (2-3x attention speedup)"
echo "   --fp8-unet --fp8-te    (FP8 on Blackwell Tensor Cores)"
echo "   --fast fp16_accumulation (15-25% matmul boost)"
echo "   --highvram             (keep models in 32GB VRAM)"
echo "   --reserve-vram 2       (reserve 2GB for OS)"
echo "   --preview-method taesd (fast previews)"
echo ""
echo "====================================================="

cd /opt/comf

$VENV_PYTHON main.py \
    --listen \
    --port 8188 \
    --enable-cors-header \
    --use-sage-attention \
    --fp8-unet \
    --fp8-te \
    --fast fp16_accumulation \
    --highvram \
    --reserve-vram 2 \
    --preview-method taesd \
    --extra-model-paths-config /opt/comf/extra_model_paths.yaml \
    --output-directory /mnt/output_host

# -----------------------------------------------------------------------------
# Fallback Shell
# -----------------------------------------------------------------------------
echo ""
echo "====================================================="
echo "ComfyUI process has finished or was stopped."
echo ""
echo "To restart manually:"
echo "  $VENV_PYTHON main.py --listen --port 8188 --enable-cors-header --use-sage-attention --fp8-unet --fp8-te --fast fp16_accumulation --highvram"
echo ""
echo "Type 'exit' to close (this will stop the container)."
echo "====================================================="

exec /bin/zsh
