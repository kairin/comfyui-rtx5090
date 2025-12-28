# AGENTS.md - ComfyUI RTX 5090 Docker Project

> Single source of truth for AI agents (Claude, Gemini, etc.)

## Project Overview

Production-ready Docker image for ComfyUI optimized for NVIDIA RTX 5090 (Blackwell) GPUs.

**Stack:**
- CUDA 12.8 | PyTorch 2.9.0 | Python 3.12
- SageAttention (replaces xformers for Blackwell)
- TensorRT for inference optimization
- FP8 precision on Blackwell Tensor Cores

**Target Hardware:**
- NVIDIA RTX 5090 (sm_120 architecture, 32GB VRAM)
- AMD Ryzen 7 7700 (16 threads)

## Repository Structure

```
comfyui-rtx5090/
├── Dockerfile              # Multi-stage build (runtime_base -> build_environment -> final)
├── docker-compose.yml      # Runtime config with GPU allocation
├── docker-bake.hcl         # Buildx multi-tag versioning
├── build-push.sh           # Build and push script
├── start.sh                # Container startup with Blackwell optimizations
├── requirements_frozen.txt # Pinned Python dependencies
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

## Key Files to Understand

### Dockerfile (Multi-Stage)
1. `runtime_base`: Minimal CUDA runtime + dev tools (eza, bat, grc, lsd)
2. `build_environment`: Full CUDA devel + Python + pip installs
3. Final stage: Copies only venv and custom_nodes, clones ComfyUI fresh

### start.sh
- Sets Blackwell-specific environment variables
- Verifies package installation
- Launches ComfyUI with optimized flags:
  - `--use-sage-attention` (2-3x attention speedup)
  - `--fp8-unet --fp8-te` (FP8 on Tensor Cores)
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
| CUDA not detected | Check `nvidia-smi`, ensure nvidia-container-toolkit installed |
| Out of VRAM | Reduce `--reserve-vram` or use `--lowvram` flag |
| Model not found | Verify paths in `extra_model_paths.yaml` |
| Permission denied | Container runs as UID 10001, ensure host dirs are accessible |

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
