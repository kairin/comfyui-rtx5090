# =============================================================================
# ComfyUI Optimized for RTX 5090 (Blackwell) with CUDA 12.8
# =============================================================================
# Target: NVIDIA RTX 5090 (sm_120, 32GB VRAM)
# CUDA: 12.8 | PyTorch: 2.9.0 | Python: 3.12
# Optimizations: SageAttention, FP8, TensorRT (Official sources only)
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Runtime Base (minimal footprint for final image)
# -----------------------------------------------------------------------------
FROM nvidia/cuda:12.8.0-cudnn-runtime-ubuntu24.04 AS runtime_base

LABEL description="Optimized runtime base for ComfyUI on RTX 5090"
LABEL maintainer="kkk"
LABEL cuda.version="12.8"
LABEL pytorch.version="2.9.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    curl ca-certificates git libgl1 libglib2.0-0 zsh \
    grc eza lsd bat && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# -----------------------------------------------------------------------------
# Stage 2: Build Environment (for compiling and installing dependencies)
# -----------------------------------------------------------------------------
FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04 AS build_environment

LABEL description="Build environment for ComfyUI Python dependencies"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV NVIDIA_VISIBLE_DEVICES=all
ENV SHELL=/bin/zsh
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV COMFYUI_INSTALL_TYPE=DOCKER

# Install system packages with security updates
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    git python3.12 python3.12-venv python3-pip wget curl ca-certificates \
    libgl1 libglib2.0-0 zsh grc eza lsd bat \
    build-essential python3.12-dev cmake && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package manager)
RUN echo "Installing uv..." && \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv && \
    mv /root/.local/bin/uvx /usr/local/bin/uvx

# Disable pip constraints that might interfere
RUN if [ -f /etc/pip/constraint.txt ]; then mv /etc/pip/constraint.txt /etc/pip/constraint.txt.original_disabled; fi && \
    if [ -f /etc/pip.conf ]; then sed -i -E '/^[[:space:]]*constraint[s]?\s*=/d' /etc/pip.conf; fi && \
    mkdir -p /etc/pip && touch /etc/pip/constraint.txt

# Configure zsh as default shell
SHELL ["/usr/bin/zsh", "-c"]
RUN if ! grep -q "$(which zsh)" /etc/shells; then echo "$(which zsh)" >> /etc/shells; fi && \
    chsh -s "$(which zsh)" root

# Setup shell aliases for enhanced CLI
RUN echo '\n# Custom Aliases for Enhanced CLI Tools' >> /root/.zshrc && \
    echo "alias ls='eza --icons --color=always --git --group-directories-first -F'" >> /root/.zshrc && \
    echo "alias ll='eza -lghH --icons --color=always --git --group-directories-first --header -F'" >> /root/.zshrc && \
    echo "alias la='eza -laghH --icons --color=always --git --group-directories-first --header -F'" >> /root/.zshrc && \
    echo "alias bat='batcat -p --paging=never'" >> /root/.zshrc && \
    echo "alias cat='batcat -p --paging=never'" >> /root/.zshrc && \
    echo "alias ps='grc --colour=auto ps'" >> /root/.zshrc && \
    echo "alias df='grc --colour=auto df'" >> /root/.zshrc && \
    echo "alias diff='grc --colour=auto diff'" >> /root/.zshrc && \
    echo "alias tail='grc --colour=auto tail'" >> /root/.zshrc && \
    echo "alias ping='grc --colour=auto ping'" >> /root/.zshrc

# -----------------------------------------------------------------------------
# Environment Configuration
# -----------------------------------------------------------------------------
ARG COMFYUI_BASE_DIR=/opt/comf
ARG VENV_DIR=${COMFYUI_BASE_DIR}/.venv
ARG COMFYUI_CUSTOM_NODES_PATH=${COMFYUI_BASE_DIR}/custom_nodes

ENV COMFYUI_BASE_DIR=${COMFYUI_BASE_DIR}
ENV VENV_DIR=${VENV_DIR}
ENV COMFYUI_CUSTOM_NODES_PATH=${COMFYUI_CUSTOM_NODES_PATH}
ENV PATH="${VENV_DIR}/bin:${PATH}"
ENV VIRTUAL_ENV=${VENV_DIR}

# -----------------------------------------------------------------------------
# Clone ComfyUI
# -----------------------------------------------------------------------------
RUN mkdir -p ${COMFYUI_BASE_DIR}
WORKDIR ${COMFYUI_BASE_DIR}
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git .

# Configure uv for Python 3.12
RUN echo -e '\n[tool.uv]\npython-preference = "managed"\n\n[tool.uv.pip]\npython-version = "3.12"' >> /opt/comf/pyproject.toml

# -----------------------------------------------------------------------------
# Create Virtual Environment
# -----------------------------------------------------------------------------
RUN uv venv ${VENV_DIR} --python $(which python3.12)

RUN echo "--- Verifying Python in venv ---" && \
    source ${VENV_DIR}/bin/activate && \
    python --version && \
    which python && \
    echo "--------------------------------"

# -----------------------------------------------------------------------------
# Install Core ML Stack: PyTorch 2.9.0 + CUDA 12.8
# -----------------------------------------------------------------------------
COPY requirements_frozen.txt ${COMFYUI_BASE_DIR}/requirements_frozen.txt

RUN source ${VENV_DIR}/bin/activate && \
    python -m ensurepip && \
    python -m pip install --no-cache-dir --upgrade pip setuptools wheel && \
    echo "Installing PyTorch 2.9.0 with CUDA 12.8..." && \
    python -m pip install --no-cache-dir \
    torch==2.9.0+cu128 \
    torchvision==0.24.0+cu128 \
    torchaudio==2.9.0+cu128 \
    triton \
    --index-url https://download.pytorch.org/whl/cu128

# -----------------------------------------------------------------------------
# Install SageAttention (replaces xformers for Blackwell)
# -----------------------------------------------------------------------------
RUN source ${VENV_DIR}/bin/activate && \
    echo "Installing SageAttention for Blackwell..." && \
    python -m pip install --no-cache-dir sageattention

# -----------------------------------------------------------------------------
# Install TensorRT for CUDA 12.8 (Blackwell requires TensorRT 10.7+)
# NOTE: As of TensorRT 10.7, GroupNormalizationPlugin is NOT supported on
# Blackwell. Use TensorRT's native INormalizationLayer instead.
# See: https://github.com/nvidia/tensorrt/blob/main/plugin/groupNormalizationPlugin/README.md
# -----------------------------------------------------------------------------
RUN source ${VENV_DIR}/bin/activate && \
    echo "Installing TensorRT 10.7+ for CUDA 12.8 (Blackwell compatible)..." && \
    python -m pip install --no-cache-dir "tensorrt>=10.7" "torch_tensorrt>=2.5" \
    --extra-index-url https://pypi.nvidia.com || \
    echo "Warning: TensorRT installation had issues, continuing..."

# -----------------------------------------------------------------------------
# Install Remaining Dependencies from requirements_frozen.txt
# -----------------------------------------------------------------------------
RUN source ${VENV_DIR}/bin/activate && \
    echo "Installing remaining dependencies..." && \
    python -c "preinstalled = {'torch', 'torchvision', 'torchaudio', 'triton', 'tensorrt', 'torch_tensorrt', 'sageattention'}; lines = [l.strip() for l in open('${COMFYUI_BASE_DIR}/requirements_frozen.txt') if l.strip() and not l.startswith('#')]; remaining = [l for l in lines if l.split('==')[0].split('>=')[0].split('<')[0].lower() not in preinstalled]; open('${COMFYUI_BASE_DIR}/requirements_remaining.txt', 'w').write('\n'.join(remaining))" && \
    python -m pip install --no-cache-dir --no-deps -r ${COMFYUI_BASE_DIR}/requirements_remaining.txt \
    --index-url https://download.pytorch.org/whl/cu128 \
    --extra-index-url https://pypi.org/simple \
    --extra-index-url https://pypi.nvidia.com || true && \
    rm -rf /root/.cache/pip && rm -rf /tmp/* 2>/dev/null || true

# -----------------------------------------------------------------------------
# Verify Core Package Installation
# -----------------------------------------------------------------------------
RUN echo "--- Verifying core packages ---" && \
    source ${VENV_DIR}/bin/activate && \
    python --version && \
    python -c "import torch; print(f'PyTorch: {torch.__version__}')" && \
    python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')" && \
    python -c "import sageattention; print('SageAttention: OK')" || echo "SageAttention not available" && \
    python -c "import tensorrt; print(f'TensorRT: {tensorrt.__version__}')" || echo "TensorRT not available" && \
    python -c "import aiohttp; print(f'aiohttp: {aiohttp.__version__}')" || echo "aiohttp not available" && \
    python -c "import numpy; print(f'numpy: {numpy.__version__}')" || echo "numpy not available" && \
    echo "--------------------------------"

# -----------------------------------------------------------------------------
# Clone Custom Nodes (shallow clones for smaller size)
# -----------------------------------------------------------------------------
RUN git clone --depth=1 https://github.com/mit-han-lab/nunchaku.git ${COMFYUI_CUSTOM_NODES_PATH}/nunchaku_nodes && \
    cd ${COMFYUI_CUSTOM_NODES_PATH}/nunchaku_nodes && \
    git submodule update --init --depth=1 && \
    source ${VENV_DIR}/bin/activate && \
    python setup.py develop || echo "nunchaku setup had issues, continuing..."

RUN git clone --depth=1 https://github.com/cubiq/ComfyUI_essentials.git ${COMFYUI_CUSTOM_NODES_PATH}/ComfyUI_essentials && \
    git clone --depth=1 https://github.com/willmiao/ComfyUI-Lora-Manager.git ${COMFYUI_CUSTOM_NODES_PATH}/ComfyUI-Lora-Manager && \
    git clone --depth=1 https://github.com/hayden-fr/ComfyUI-Model-Manager.git ${COMFYUI_CUSTOM_NODES_PATH}/ComfyUI-Model-Manager && \
    git clone --depth=1 https://github.com/cubiq/PuLID_ComfyUI.git ${COMFYUI_CUSTOM_NODES_PATH}/PuLID_ComfyUI && \
    git clone --depth=1 https://github.com/cubiq/ComfyUI_FaceAnalysis.git ${COMFYUI_CUSTOM_NODES_PATH}/ComfyUI_FaceAnalysis && \
    git clone --depth=1 https://github.com/cubiq/ComfyUI_IPAdapter_plus.git ${COMFYUI_CUSTOM_NODES_PATH}/ComfyUI_IPAdapter_plus && \
    git clone --depth=1 https://github.com/city96/ComfyUI-GGUF.git ${COMFYUI_CUSTOM_NODES_PATH}/ComfyUI_GGUF && \
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git ${COMFYUI_CUSTOM_NODES_PATH}/ComfyUI_Impact_Pack && \
    git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git ${COMFYUI_CUSTOM_NODES_PATH}/ComfyUI_Manager && \
    git clone --depth=1 https://github.com/ltdrdata/comfyui-connection-helper.git ${COMFYUI_CUSTOM_NODES_PATH}/comfyui-connection-helper && \
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Inspire-Pack.git ${COMFYUI_CUSTOM_NODES_PATH}/ComfyUI_Inspire-Pack && \
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git ${COMFYUI_CUSTOM_NODES_PATH}/ComfyUI-Impact-Subpack && \
    git clone --depth=1 https://github.com/HaydenReeve/ComfyUI-Better-Strings.git ${COMFYUI_CUSTOM_NODES_PATH}/ComfyUI_Better-Strings && \
    git clone --depth=1 https://github.com/cubiq/ComfyUI_InstantID.git ${COMFYUI_CUSTOM_NODES_PATH}/ComfyUI_InstantID

# -----------------------------------------------------------------------------
# Generate Custom Node Dependency Report
# -----------------------------------------------------------------------------
RUN COLLECTED_DEPS_FILE="${COMFYUI_BASE_DIR}/collected_node_dependencies.txt" && \
    echo "--- Custom Node Dependency Collection Report ---" > "${COLLECTED_DEPS_FILE}" && \
    echo "Generated on: $(date)" >> "${COLLECTED_DEPS_FILE}" && \
    echo "------------------------------------------------" >> "${COLLECTED_DEPS_FILE}" && \
    for node_dir in "${COMFYUI_CUSTOM_NODES_PATH}"/*; do \
        if [ -d "$node_dir" ]; then \
            NODE_NAME=$(basename "$node_dir") && \
            echo "### Node: $NODE_NAME ###" >> "${COLLECTED_DEPS_FILE}" && \
            if [ -f "$node_dir/requirements.txt" ]; then \
                echo "--- requirements.txt ---" >> "${COLLECTED_DEPS_FILE}" && \
                cat "$node_dir/requirements.txt" >> "${COLLECTED_DEPS_FILE}" 2>/dev/null || true && \
                echo "" >> "${COLLECTED_DEPS_FILE}"; \
            fi; \
        fi; \
    done && \
    echo "--- End of Report ---" >> "${COLLECTED_DEPS_FILE}"

# -----------------------------------------------------------------------------
# Stage 3: Final Runtime Image
# -----------------------------------------------------------------------------
FROM runtime_base

LABEL description="ComfyUI Optimized for RTX 5090 (Blackwell)"
LABEL org.opencontainers.image.title="ComfyUI RTX 5090"
LABEL org.opencontainers.image.description="ComfyUI optimized for NVIDIA RTX 5090 Blackwell with CUDA 12.8, PyTorch 2.9, SageAttention"
LABEL org.opencontainers.image.vendor="kairin"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/kairin/comfyui-rtx5090"

ARG COMFYUI_BASE_DIR=/opt/comf
ARG VENV_DIR=${COMFYUI_BASE_DIR}/.venv
ARG COMFYUI_CUSTOM_NODES_PATH=${COMFYUI_BASE_DIR}/custom_nodes

ENV COMFYUI_BASE_DIR=${COMFYUI_BASE_DIR}
ENV VENV_DIR=${VENV_DIR}
ENV COMFYUI_CUSTOM_NODES_PATH=${COMFYUI_CUSTOM_NODES_PATH}
ENV PATH="${VENV_DIR}/bin:${PATH}"
ENV VIRTUAL_ENV=${VENV_DIR}

# RTX 5090 / Blackwell specific environment
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics
ENV NVIDIA_VISIBLE_DEVICES=all
ENV CUDA_MODULE_LOADING=LAZY
ENV NVIDIA_TF32_OVERRIDE=1
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# -----------------------------------------------------------------------------
# Copy only what's needed from build stage (not entire directory)
# This saves ~4GB by excluding build artifacts, caches, and .git directories
# -----------------------------------------------------------------------------

# Create base directory structure
RUN mkdir -p ${COMFYUI_BASE_DIR}

# Copy only the Python virtual environment (contains all installed packages)
COPY --from=build_environment ${VENV_DIR} ${VENV_DIR}

# Clone ComfyUI fresh in final stage (source code only, ~50MB vs build artifacts)
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git ${COMFYUI_BASE_DIR}/comfyui_temp && \
    mv ${COMFYUI_BASE_DIR}/comfyui_temp/* ${COMFYUI_BASE_DIR}/ && \
    mv ${COMFYUI_BASE_DIR}/comfyui_temp/.* ${COMFYUI_BASE_DIR}/ 2>/dev/null || true && \
    rm -rf ${COMFYUI_BASE_DIR}/comfyui_temp

# Copy custom nodes from build stage
COPY --from=build_environment ${COMFYUI_CUSTOM_NODES_PATH} ${COMFYUI_CUSTOM_NODES_PATH}

# Remove .git directories from custom nodes to save space (~500MB)
RUN find ${COMFYUI_CUSTOM_NODES_PATH} -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true

# Copy startup script
COPY start.sh ${COMFYUI_BASE_DIR}/start.sh
RUN chmod +x ${COMFYUI_BASE_DIR}/start.sh

# Copy model paths configuration
COPY extra_model_paths.yaml ${COMFYUI_BASE_DIR}/extra_model_paths.yaml

WORKDIR ${COMFYUI_BASE_DIR}

# Create non-root user for security (using 10001 to avoid conflicts with base image)
RUN groupadd -r comfyui --gid=10001 && \
    useradd -r -g comfyui --uid=10001 --home-dir=/opt/comf --shell=/bin/bash comfyui && \
    chown -R comfyui:comfyui /opt/comf

USER comfyui

EXPOSE 8188

CMD ["/opt/comf/start.sh"]
