# ComfyUI RTX 5090

[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-kairin%2Fbases-blue?logo=docker)](https://hub.docker.com/r/kairin/bases/tags?name=comfyui-rtx5090)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CUDA 12.8](https://img.shields.io/badge/CUDA-12.8-green?logo=nvidia)](https://developer.nvidia.com/cuda-toolkit)
[![PyTorch 2.9](https://img.shields.io/badge/PyTorch-2.9.0-ee4c2c?logo=pytorch)](https://pytorch.org/)

Production-ready Docker image for [ComfyUI](https://github.com/comfyanonymous/ComfyUI) optimized for NVIDIA RTX 5090 (Blackwell) GPUs with CUDA 12.8, PyTorch 2.9, and advanced performance optimizations.

## Features

- **RTX 5090 Optimized**: Built specifically for Blackwell architecture (sm_120)
- **SageAttention**: 2-3x faster attention than xformers on Blackwell
- **FP8 Precision**: Native FP8 support on Blackwell Tensor Cores
- **TensorRT**: Optional inference acceleration
- **32GB VRAM**: High VRAM mode for large models (SDXL, Flux, etc.)
- **Pre-installed Nodes**: Popular custom nodes included and ready to use

## Prerequisites

- Docker 24.0+
- NVIDIA Driver 570+ (for RTX 5090)
- [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- RTX 5090 GPU (or compatible Blackwell GPU)

## Quick Start

```bash
# Pull and run
docker compose up -d

# Access ComfyUI
open http://localhost:8188
```

## Configuration

### Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `/srv/models` | `/mnt/models_host` | Model storage (checkpoints, LoRAs, VAEs) |
| `/srv/output` | `/mnt/output_host` | Generated images output |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TORCH_NUM_THREADS` | 16 | CPU threads for PyTorch |
| `HUGGING_FACE_HUB_TOKEN` | - | HuggingFace API token |
| `CIVITAI_API_KEY` | - | Civitai API key |

See `.env.example` for the full list.

## Building Locally

```bash
# Clone the repository
git clone https://github.com/kairin/comfyui-rtx5090.git
cd comfyui-rtx5090

# Build and push (requires Docker Hub login)
./build-push.sh

# Or build without pushing
docker buildx build -t comfyui-rtx5090:local .
```

## Versioning

This project uses semantic versioning with Docker Hub tags:

| Tag Pattern | Example | Description |
|-------------|---------|-------------|
| `v{VERSION}` | `v1.0.0` | Immutable release version |
| `{DATE}` | `20251228` | Date-based snapshot |
| `latest` | - | Most recent build (development) |

To use a specific version:

```yaml
# docker-compose.yml
services:
  comfyui:
    image: kairin/bases:comfyui-rtx5090-v1.0.0  # Pin to specific version
```

## Included Custom Nodes

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

## Performance Optimizations

The container starts with these Blackwell-optimized flags:

```bash
--use-sage-attention    # 2-3x attention speedup
--fp8-unet --fp8-te     # FP8 on Blackwell Tensor Cores
--fast fp16_accumulation # 15-25% matmul boost
--highvram              # Keep models in 32GB VRAM
--reserve-vram 2        # Reserve 2GB for OS
```

## Troubleshooting

**CUDA not detected:**
```bash
# Verify NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi
```

**Permission denied:**
The container runs as UID 10001. Ensure host directories are accessible:
```bash
sudo chown -R 10001:10001 /srv/models /srv/output
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) by comfyanonymous
- [SageAttention](https://github.com/thu-ml/SageAttention) by THU-ML
- All custom node authors
