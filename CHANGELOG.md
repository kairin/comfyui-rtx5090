# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-28

### Added

- Initial release optimized for NVIDIA RTX 5090 (Blackwell)
- Multi-stage Docker build for optimized image size
- CUDA 12.8 with cuDNN runtime
- PyTorch 2.9.0 with CUDA 12.8 support
- SageAttention for 2-3x faster attention on Blackwell
- TensorRT integration for inference acceleration
- FP8 precision support on Blackwell Tensor Cores
- Pre-installed custom nodes:
  - ComfyUI_Manager
  - ComfyUI_essentials
  - ComfyUI-Impact-Pack / Subpack
  - ComfyUI-Inspire-Pack
  - ComfyUI-Lora-Manager
  - ComfyUI-Model-Manager
  - ComfyUI_IPAdapter_plus
  - ComfyUI_FaceAnalysis
  - ComfyUI_InstantID
  - ComfyUI_GGUF
  - PuLID_ComfyUI
  - nunchaku_nodes
- Semantic versioning with Docker Hub tags (v1.0.0, date, latest)
- Non-root user for security (UID 10001)
- Health check for container orchestration
- Dev tools included: eza, bat, grc, lsd

### Optimized

- Selective COPY in final stage (saves ~4GB vs copying entire build directory)
- Removed .git directories from custom nodes
- Used `--no-cache-dir` for all pip installs
- Fresh ComfyUI clone in final stage (source only, no build artifacts)

### Configuration

- External model storage via volume mounts (/srv/models)
- Configurable thread count for AMD Ryzen 7 7700
- 16GB shared memory for large model handling
- Lazy CUDA module loading for faster startup
