# ComfyUI RTX 5090

[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-kairin%2Fbases-blue?logo=docker)](https://hub.docker.com/r/kairin/bases/tags?name=comfyui-rtx5090)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![NGC PyTorch](https://img.shields.io/badge/NGC-PyTorch%2025.12-76B900?logo=nvidia)](https://catalog.ngc.nvidia.com/orgs/nvidia/containers/pytorch)
[![CUDA 13.1](https://img.shields.io/badge/CUDA-13.1-green?logo=nvidia)](https://developer.nvidia.com/cuda-toolkit)
[![PyTorch 2.10](https://img.shields.io/badge/PyTorch-2.10.0a0-ee4c2c?logo=pytorch)](https://pytorch.org/)

Production-ready Docker image for [ComfyUI](https://github.com/comfyanonymous/ComfyUI) optimized for NVIDIA RTX 5090 (Blackwell) GPUs using NGC PyTorch container with CUDA 13.1, PyTorch 2.10, and advanced performance optimizations.

## Features

- **NGC PyTorch Base**: Uses `nvcr.io/nvidia/pytorch:25.12-py3` for native Blackwell support
- **RTX 5090 Optimized**: Pre-compiled PyTorch with sm_120 CUDA operators
- **SageAttention**: 2-3x faster attention than xformers (Triton-based)
- **FP8 Precision**: 80-100% faster than FP16 on Blackwell Tensor Cores
- **TensorRT 10.7+**: Optional FP4 inference acceleration
- **32GB VRAM**: High VRAM mode for large models (SDXL, Flux, etc.)

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

## Rebuild Workflow

After making changes to Docker-related files, use this standard workflow:

```bash
# 1. Stop running containers
docker compose down

# 2. Reclaim Docker space (optional, saves disk)
docker buildx prune -af && docker image prune -f

# 3. Rebuild and push
./build-push.sh

# 4. Start container
docker compose up -d

# 5. Verify
docker compose ps
docker compose logs -f --tail=100
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
--use-sage-attention       # 2-3x attention speedup (Triton kernels)
--fp8_e4m3fn-unet          # FP8 UNet on Blackwell Tensor Cores
--fp8_e4m3fn-text-enc      # FP8 Text Encoder
--fast fp16_accumulation   # 15-25% matmul boost
--highvram                 # Keep models in 32GB VRAM
--reserve-vram 2           # Reserve 2GB for OS
```

### GPU Acceleration Stack

| Technology | Performance Gain | Notes |
|------------|-----------------|-------|
| SageAttention | 2-3x attention speedup | Replaces xformers for Blackwell |
| FP8 (e4m3fn) | 80-100% faster than FP16 | Uses 12GB vs 23GB VRAM |
| Fast Matmul | 15-25% boost | fp16_accumulation mode |
| TensorRT | Up to 70% inference | Optional FP4 on Blackwell |

## Troubleshooting

**`torchvision::nms does not exist` error:**
This indicates the base image doesn't have Blackwell CUDA operators. The Dockerfile MUST use `nvcr.io/nvidia/pytorch:25.12-py3` as the base image. Do NOT use `nvidia/cuda:*` images.

**CUDA not detected:**
```bash
# Verify NVIDIA runtime
docker run --rm --gpus all nvcr.io/nvidia/pytorch:25.12-py3 nvidia-smi
```

**Permission denied:**
The container runs as UID 10001. Ensure host directories are accessible:
```bash
sudo chown -R 10001:10001 /srv/models /srv/output
```

**SageAttention not working:**
Ensure Triton is installed. The NGC container includes it by default.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) by comfyanonymous
- [SageAttention](https://github.com/thu-ml/SageAttention) by THU-ML
- All custom node authors
