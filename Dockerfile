# =============================================================================
# ComfyUI Optimized for RTX 5090 (Blackwell) - NGC PyTorch Base + uv
# =============================================================================
# IMPORTANT: This Dockerfile uses NGC PyTorch container as base.
# DO NOT revert to nvidia/cuda:* base images - they lack Blackwell CUDA operators.
# The NGC container provides pre-compiled PyTorch with sm_120 (Blackwell) support.
# =============================================================================
# Base: nvcr.io/nvidia/pytorch:25.12-py3
#   - CUDA 13.1.0
#   - PyTorch 2.10.0a0 (Blackwell optimized)
#   - torchvision with CUDA operators (nms, roi_align, etc.)
#   - cuDNN 9.x, Triton pre-installed
# =============================================================================
# Package Manager: uv (10-100x faster than pip)
#   - Uses --system flag to install to system Python
#   - Preserves NGC's pre-installed PyTorch packages
#   - Source: https://docs.astral.sh/uv/guides/integration/docker/
# =============================================================================

FROM nvcr.io/nvidia/pytorch:25.12-py3

LABEL description="ComfyUI Optimized for RTX 5090 (Blackwell)"
LABEL org.opencontainers.image.title="ComfyUI RTX 5090"
LABEL org.opencontainers.image.description="ComfyUI with NGC PyTorch, uv, SageAttention, FP8 for Blackwell"
LABEL org.opencontainers.image.vendor="kairin"
LABEL org.opencontainers.image.licenses="MIT"
LABEL maintainer="kkk"
LABEL cuda.version="13.1"
LABEL pytorch.version="2.10.0a0"
LABEL base.image="nvcr.io/nvidia/pytorch:25.12-py3"
LABEL package.manager="uv"

# -----------------------------------------------------------------------------
# Environment Configuration
# -----------------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics
ENV NVIDIA_VISIBLE_DEVICES=all
ENV SHELL=/bin/zsh
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# RTX 5090 / Blackwell optimizations
ENV CUDA_MODULE_LOADING=LAZY
ENV NVIDIA_TF32_OVERRIDE=1
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# uv configuration - use system Python (preserves NGC packages)
ENV UV_SYSTEM_PYTHON=1
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV UV_BREAK_SYSTEM_PACKAGES=1

# ComfyUI paths
ENV COMFYUI_BASE_DIR=/opt/comf
ENV COMFYUI_CUSTOM_NODES_PATH=/opt/comf/custom_nodes

# -----------------------------------------------------------------------------
# Install uv (copy from official image - faster than curl install)
# -----------------------------------------------------------------------------
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# -----------------------------------------------------------------------------
# Install System Dependencies
# -----------------------------------------------------------------------------
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    zsh grc eza lsd bat \
    libgl1 libglib2.0-0 \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure zsh as default shell
SHELL ["/bin/zsh", "-c"]
RUN if ! grep -q "$(which zsh)" /etc/shells; then echo "$(which zsh)" >> /etc/shells; fi

# Setup shell aliases for enhanced CLI
RUN echo '\n# Custom Aliases for Enhanced CLI Tools' >> /root/.zshrc && \
    echo "alias ls='eza --icons --color=always --git --group-directories-first -F'" >> /root/.zshrc && \
    echo "alias ll='eza -lghH --icons --color=always --git --group-directories-first --header -F'" >> /root/.zshrc && \
    echo "alias la='eza -laghH --icons --color=always --git --group-directories-first --header -F'" >> /root/.zshrc && \
    echo "alias bat='batcat -p --paging=never'" >> /root/.zshrc && \
    echo "alias cat='batcat -p --paging=never'" >> /root/.zshrc

# -----------------------------------------------------------------------------
# Clone ComfyUI
# -----------------------------------------------------------------------------
RUN mkdir -p ${COMFYUI_BASE_DIR}
WORKDIR ${COMFYUI_BASE_DIR}
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git .

# -----------------------------------------------------------------------------
# Install ComfyUI Dependencies with uv
# NOTE: NGC already provides torch, torchvision, torchaudio, triton, numpy, scipy, Pillow
# uv with --system flag installs to system Python without overwriting NGC packages
# -----------------------------------------------------------------------------
COPY requirements_minimal.txt ${COMFYUI_BASE_DIR}/requirements_minimal.txt

RUN echo "Installing ComfyUI dependencies with uv (NGC provides PyTorch stack)..." && \
    uv pip install --system --no-cache -r ${COMFYUI_BASE_DIR}/requirements_minimal.txt

# -----------------------------------------------------------------------------
# Install SageAttention (Blackwell attention acceleration)
# Uses Triton kernels, 2-3x faster than standard PyTorch attention
# -----------------------------------------------------------------------------
RUN echo "Installing SageAttention for Blackwell..." && \
    uv pip install --system --no-cache sageattention

# -----------------------------------------------------------------------------
# Verify Core Package Installation
# -----------------------------------------------------------------------------
RUN echo "--- Verifying core packages ---" && \
    python --version && \
    uv --version && \
    python -c "import torch; print(f'PyTorch: {torch.__version__}')" && \
    python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')" && \
    python -c "import torchvision; print(f'torchvision: {torchvision.__version__}')" && \
    python -c "import sageattention; print('SageAttention: OK')" || echo "SageAttention not available" && \
    python -c "import aiohttp; print(f'aiohttp: {aiohttp.__version__}')" || echo "aiohttp not available" && \
    echo "--------------------------------"

# -----------------------------------------------------------------------------
# Copy Configuration Files
# -----------------------------------------------------------------------------
COPY start.sh ${COMFYUI_BASE_DIR}/start.sh
RUN chmod +x ${COMFYUI_BASE_DIR}/start.sh

COPY extra_model_paths.yaml ${COMFYUI_BASE_DIR}/extra_model_paths.yaml

# -----------------------------------------------------------------------------
# Create Non-Root User (security)
# -----------------------------------------------------------------------------
RUN groupadd -r comfyui --gid=10001 && \
    useradd -r -g comfyui --uid=10001 --home-dir=/opt/comf --shell=/bin/bash comfyui && \
    chown -R comfyui:comfyui /opt/comf

USER comfyui

EXPOSE 8188

CMD ["/opt/comf/start.sh"]
