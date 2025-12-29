# AGENTS.md - ComfyUI RTX 5090 Docker Project

> Single source of truth for AI agents (Claude, Gemini, etc.)

## IMPORTANT: Build Approach (READ FIRST)

> **DO NOT revert to nvidia/cuda base images or manual PyTorch wheel installation.**
>
> This project uses NVIDIA NGC PyTorch container as the base image. The NGC container
> provides pre-built PyTorch with Blackwell (sm_120) CUDA operator support, which
> solves the `torchvision::nms does not exist` runtime error that occurs with
> manual PyTorch wheel installations.

**Mandatory Base Image:** `nvcr.io/nvidia/pytorch:25.12-py3`
- CUDA 13.1.0 (Blackwell optimized)
- PyTorch 2.10.0a0 (pre-compiled with sm_120 support)
- torchvision with CUDA operators (nms, roi_align, etc.)
- cuDNN 9.x with Blackwell kernel libraries

**DO NOT:**
- Use `nvidia/cuda:*` base images for build stages
- Install PyTorch via `pip install torch --index-url https://download.pytorch.org/whl/cu*`
- Build PyTorch from source

**DO:**
- Use NGC PyTorch container as single-stage or base
- Use `uv` for package management (10-100x faster than pip)
- Install only Python dependencies not included in NGC
- Use `uv pip install --system --no-cache` to install to system Python

## Package Manager: uv

This project uses [uv](https://docs.astral.sh/uv/) for Python package management.

**Why uv?**
- 10-100x faster than pip
- Better dependency resolution
- Preserves NGC's pre-installed packages with `--system` flag

**Key Configuration (in Dockerfile):**
```dockerfile
# Copy uv binary from official image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Configure for system Python
ENV UV_SYSTEM_PYTHON=1
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

# Install dependencies (preserves NGC packages)
RUN uv pip install --system --no-cache -r requirements_minimal.txt
```

**DO NOT:**
- Use `uv sync` (creates venv, conflicts with NGC)
- Use `pip install` (slower, use uv instead)
- Install torch/torchvision/torchaudio (NGC provides these)

**Sources:**
- [uv Docker Guide](https://docs.astral.sh/uv/guides/integration/docker/)
- [uv PyTorch Integration](https://docs.astral.sh/uv/guides/integration/pytorch/)

## Project Overview

Production-ready Docker image for ComfyUI optimized for NVIDIA RTX 5090 (Blackwell) GPUs.

**Stack:**
- NGC PyTorch 25.12 | CUDA 13.1 | PyTorch 2.10.0a0 | Python 3.12
- SageAttention (replaces xformers for Blackwell)
- FP8 precision on Blackwell Tensor Cores (e4m3fn format)
- TensorRT 10.7+ (optional, FP4 Blackwell support)

**Target Hardware:**
- NVIDIA RTX 5090 (sm_120 architecture, 32GB VRAM)
- AMD Ryzen 7 7700 (16 threads)

## Repository Structure

```
comfyui-rtx5090/
├── Dockerfile              # Single-stage NGC PyTorch base with uv
├── docker-compose.yml      # Runtime config with GPU allocation
├── docker-bake.hcl         # Buildx multi-tag versioning
├── build-push.sh           # Build and push script
├── start.sh                # Container startup with Blackwell optimizations
├── requirements_minimal.txt # ComfyUI dependencies (NGC provides PyTorch)
├── extra_model_paths.yaml  # Model directory mapping
├── .version                # Semantic version number
├── AGENTS.md               # This file (AI agent instructions)
├── CLAUDE.md -> AGENTS.md  # Symlink for Claude
├── GEMINI.md -> AGENTS.md  # Symlink for Gemini
└── README.md               # User documentation
```

## Build Commands

```bash
# Build and push to Docker Hub (recommended)
./build-push.sh

# Run container (pulls from registry)
docker compose up -d

# Access ComfyUI
open http://localhost:8188
```

## Version Management

- Edit `.version` before building (e.g., `1.0.1`)
- Build creates tags: `v1.0.1`, `20251228`, `latest`
- Rollback: change `image:` in docker-compose.yml to specific version

## GPU Acceleration Stack

### 1. SageAttention (Primary - Replaces xformers)
- **Why**: xformers has no Blackwell support; SageAttention uses Triton kernels
- **Performance**: 2-3x faster attention than standard PyTorch
- **Flag**: `--use-sage-attention`
- **Install**: `pip install sageattention` (builds Triton kernels)

### 2. FP8 Precision (Blackwell Tensor Cores)
- **Why**: RTX 5090 has native FP8 Tensor Core support
- **Performance**: 80-100% faster than FP16, uses 12GB vs 23GB VRAM
- **Flags**: `--fp8_e4m3fn-unet --fp8_e4m3fn-text-enc`
- **Format**: e4m3fn (4-bit exponent, 3-bit mantissa, no infinity)

### 3. TensorRT (Optional - FP4 for Blackwell)
- **Why**: TensorRT 10.7+ supports FP4 on Blackwell
- **Performance**: Up to 70% faster inference
- **Caveat**: GroupNormalizationPlugin not yet supported on Blackwell
- **Install**: `tensorrt>=10.7` from pypi.nvidia.com

### 4. Fast Matmul (ComfyUI native)
- **Flag**: `--fast fp16_accumulation`
- **Performance**: 15-25% matmul speedup

## Key Files to Understand

### Dockerfile (Single-Stage NGC + uv)
- Uses `nvcr.io/nvidia/pytorch:25.12-py3` as base
- Copies `uv` binary from `ghcr.io/astral-sh/uv:latest`
- Sets `UV_SYSTEM_PYTHON=1` to install to system Python
- Clones ComfyUI and installs dependencies with `uv pip install --system`
- Installs SageAttention for Blackwell attention acceleration
- NO multi-stage build needed (NGC provides PyTorch)

### start.sh
- Sets Blackwell-specific environment variables
- Verifies package installation
- Launches ComfyUI with optimized flags:
  - `--use-sage-attention` (2-3x attention speedup)
  - `--fp8_e4m3fn-unet --fp8_e4m3fn-text-enc` (FP8 on Tensor Cores)
  - `--fast fp16_accumulation` (15-25% matmul boost)
  - `--highvram` (keep models in 32GB VRAM)

### docker-compose.yml
- GPU allocation via NVIDIA Container Toolkit
- Volume mounts: `/srv/models` -> `/mnt/models_host`
- 16GB shared memory for large model handling
- Health check on port 8188

## Important Constraints

1. **Never commit `.env`** - contains API keys (HF_TOKEN, CIVITAI_API_KEY)
2. **Always use `--no-cache-dir`** for pip installs in Dockerfile
3. **Models stored externally** in `/srv/models` (not in image)
4. **Test GPU access** with `nvidia-smi` inside container
5. **Pin versions** in requirements_frozen.txt

## Code Style

- **Dockerfile**: One logical operation per RUN, clean apt cache at end
- **Shell scripts**: `set -e`, quote all variables, use `#!/bin/bash` or `#!/bin/zsh`
- **Python deps**: Pin exact versions with `==`, use `>=` only for security patches

## LLM Workflow: Docker Improvements

**CRITICAL**: When making changes to Docker-related files (Dockerfile, docker-compose.yml, docker-bake.hcl, start.sh, requirements_*.txt), LLMs must:

1. **DO NOT** automatically run build commands
2. **DO** make the necessary file edits
3. **DO** bump the version in `.version`
4. **DO** provide the user with the complete rebuild commands

### Standard Output Format

After making Docker improvements, always output:

```text
Version bumped to X.Y.Z. Here are the complete commands:

# 1. Stop all running containers
docker compose -f /home/kkk/Apps/comf/docker-compose.yml down

# 2. Reclaim Docker space (buildx cache + dangling images)
docker buildx prune -af && docker image prune -f

# 3. Rebuild and push (from project directory)
cd /home/kkk/Apps/comf && ./build-push.sh

# 4. Start the container
docker compose -f /home/kkk/Apps/comf/docker-compose.yml up -d

# 5. Verify it's running and check logs
docker compose -f /home/kkk/Apps/comf/docker-compose.yml ps
docker compose -f /home/kkk/Apps/comf/docker-compose.yml logs -f --tail=100

Summary of changes:
- [Specific change with file:line reference]
- Version bumped: X.Y.Z-1 → X.Y.Z

Expected results after rebuild:
- [What will change/improve]
- [Known limitations that remain]
```

### Why This Workflow?

- **User control**: Builds can take time and network resources
- **Transparency**: User sees exactly what changed before rebuilding
- **Verification**: User can review changes before committing resources
- **Consistency**: Standard format makes it easy to follow

## Custom Nodes Included

- ComfyUI_Manager
- ComfyUI_essentials
- ComfyUI-Impact-Pack
- ComfyUI-Inspire-Pack
- ComfyUI-Lora-Manager
- ComfyUI-Model-Manager
- ComfyUI_IPAdapter_plus
- ComfyUI_FaceAnalysis
- ComfyUI_InstantID
- ComfyUI_GGUF
- PuLID_ComfyUI
- nunchaku_nodes (SageAttention)

## Docker Hub Tags

```
kairin/bases:comfyui-rtx5090-v1.0.0   # Immutable version
kairin/bases:comfyui-rtx5090-20251228 # Date-based
kairin/bases:comfyui-rtx5090-latest   # Development (mutable)
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `torchvision::nms does not exist` | **CRITICAL**: You're using wrong base image. Use NGC PyTorch `nvcr.io/nvidia/pytorch:25.12-py3` |
| CUDA not detected | Check `nvidia-smi`, ensure nvidia-container-toolkit installed |
| Out of VRAM | Reduce `--reserve-vram` or use `--lowvram` flag |
| Model not found | Verify paths in `extra_model_paths.yaml` |
| Permission denied | Container runs as UID 10001, ensure host dirs are accessible |
| SageAttention not working | Ensure Triton is installed (`pip install triton`) |
| FP8 errors | Verify GPU is Blackwell (sm_120), older GPUs don't support FP8 |

## Sub-Agent Architecture

This project uses a 5-tier, 24-agent system for AI-assisted development. Agents are defined in `.claude/agents/`.

### Tier 0: Workflow Automation (Haiku)

Quick daily automation triggers:

| Agent | Trigger | Purpose |
|-------|---------|---------|
| `000-health` | "Check health" | Docker/GPU/container status |
| `000-build` | "Build version" | Run build-push.sh |
| `000-commit` | "Commit changes" | Conventional git commits |
| `000-deps` | "Check deps" | Dependency scan |
| `000-cleanup` | "Clean Docker" | Prune images/cache |

### Tier 1: Orchestrators

| Agent | Model | Purpose |
|-------|-------|---------|
| `001-orchestrator` | Opus | Master task coordination |
| `001-release` | Sonnet | Release workflow |

### Tier 2: Core Domain Specialists (Sonnet)

| Agent | Domain | Key Files |
|-------|--------|-----------|
| `002-docker` | Build system | Dockerfile, compose |
| `002-cuda` | GPU optimization | start.sh |
| `002-nodes` | Custom nodes | Dockerfile |
| `002-models` | Model paths | extra_model_paths.yaml |
| `002-deps` | Dependencies | requirements_frozen.txt |
| `002-git` | Version control | .version |

### Tier 3: Utility Support (Sonnet/Haiku)

| Agent | Purpose |
|-------|---------|
| `003-cicd` | GitHub Actions workflows |
| `003-docs` | Documentation sync |
| `003-perf` | Performance benchmarking |
| `003-security` | CVE scanning, hardening |
| `003-compose` | Compose variants |

### Tier 4: Atomic Children (Haiku)

Located in `.claude/agents/children/`:

| Agent | Parent | Purpose |
|-------|--------|---------|
| `020-dockerfile` | 002-docker | Dockerfile edits |
| `021-compose` | 002-docker | Compose tweaks |
| `022-bake` | 002-docker | Tag management |
| `023-sage` | 002-cuda | SageAttention config |
| `024-fp8` | 002-cuda | FP8 precision |
| `025-tensorrt` | 002-cuda | TensorRT setup |
| `026-clone` | 002-nodes | Clone nodes |
| `027-reqs` | 002-nodes | Collect requirements |
| `028-verify` | 002-nodes | Verify installation |
| `029-freeze` | 002-deps | Pin versions |
| `030-conflict` | 002-deps | Conflict detection |
| `031-security` | 002-deps | CVE check |

### Agent Configuration

Tool permissions are defined in `.claude/settings.local.json`.
