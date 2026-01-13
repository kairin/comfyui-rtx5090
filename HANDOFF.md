# Project Handoff Document

**Last Updated**: 2026-01-14
**Last Session**: Claude Opus 4.5
**Repository**: https://github.com/kairin/comfyui-rtx5090

---

## Executive Summary

This project provides Docker-based ComfyUI setup for **two NVIDIA devices**:
1. **RTX 5090** (x86_64, Docker) - Production ready, fully implemented
2. **DGX Spark** (ARM64, native Python) - Scripts created, awaiting testing on device

---

## Current Repository State

### Git Status
```
Branch: main
Remote: origin/main (in sync)
Status: Clean, no pending changes
Version: 1.0.10
```

### Recent Commits
```
6fa1f86 feat(dgx-spark): add DGX Spark ComfyUI setup scripts  <-- LATEST
f603520 feat: add LLM workflow docs, fix duplicate paths, update model paths
f369932 fix(deps): add missing core ComfyUI dependencies
993202b fix(start): use correct FP8 flag format for ComfyUI
0d5b1db fix(build): add --file flag to bake command to fix empty targets
64b3044 chore: remove GitHub Actions workflow, switch to local builds only
69b2091 fix(blackwell): correct CUDA version refs and pin TensorRT for RTX 5090
a849d9c Initial release: ComfyUI optimized for RTX 5090 (Blackwell)
```

### Directory Structure
```
comfyui-rtx5090/
├── AGENTS.md              # AI agent instructions (CLAUDE.md, GEMINI.md symlinked)
├── Dockerfile             # RTX 5090 Docker build (NGC PyTorch base)
├── docker-compose.yml     # RTX 5090 runtime config
├── docker-bake.hcl        # Multi-tag versioning
├── build-push.sh          # Build and push script
├── start.sh               # RTX 5090 container startup
├── requirements_minimal.txt
├── requirements_frozen.txt
├── extra_model_paths.yaml # Model directory mapping
├── .version               # Current: 1.0.10
├── dgx-spark/             # NEW: DGX Spark setup
│   ├── README.md          # Quick start guide
│   ├── install.sh         # NVIDIA official installation
│   ├── start.sh           # Simple startup
│   └── start-optimized.sh # Memory-optimized startup
└── README.md
```

---

## What Was Completed This Session

### 1. DGX Spark ComfyUI Setup (Phase 1)

Created installation scripts following [NVIDIA's official instructions](https://build.nvidia.com/spark/comfy-ui/instructions):

| File | Purpose |
|------|---------|
| `dgx-spark/install.sh` | pip3/venv installation, PyTorch CUDA 13.0, downloads SD 1.5 |
| `dgx-spark/start.sh` | Simple `python main.py --listen 0.0.0.0` |
| `dgx-spark/start-optimized.sh` | Adds `--highvram` + memory optimizations for 128GB |
| `dgx-spark/README.md` | Documentation |

### 2. Research Completed

- **Model Compatibility**: Qwen-Image, Z-Image Turbo, Flux, HunyuanVideo, Wan 2.1, Illustrious XL, Pony all compatible
- **Hardware Specs**: Grace Blackwell GB10, ARM64, sm_121, 128GB unified LPDDR5X, CUDA 13.0
- **Approach Decision**: User chose NVIDIA official approach over enhanced uv-based approach

### 3. Git Configuration

Set up git config via gh CLI:
```
user.name=Mister K
user.email=678459+kairin@users.noreply.github.com
```

---

## Pending Tasks

### Priority 1: Test DGX Spark Setup
- [ ] SSH to DGX Spark device
- [ ] Copy `dgx-spark/` folder to device
- [ ] Run `./install.sh` and verify installation
- [ ] Run `./start.sh` and access `http://<IP>:8188`
- [ ] Generate test image with SD 1.5
- [ ] Test `./start-optimized.sh` with larger models (Flux, Qwen-Image)

### Priority 2: Model Testing on DGX Spark
- [ ] Test Flux.1 dev (~24GB) - leverage 128GB unified memory
- [ ] Test Qwen-Image-2512 (20B) - native ComfyUI support
- [ ] Test HunyuanVideo 1.5 - video generation
- [ ] Document performance/compatibility findings

### Priority 3: RTX 5090 Device Setup (Phase 2)
- [ ] RTX 5090 Docker setup is already complete in main repo
- [ ] User needs to run `./build-push.sh` on RTX 5090 machine
- [ ] Verify with `docker compose up -d`

### Future Enhancements (Optional)
- [ ] Add ComfyUI_Manager to DGX Spark install (currently not included per NVIDIA official)
- [ ] Create unified model sync between devices (if user wants shared storage later)
- [ ] Docker support for DGX Spark (when ARM64 NGC containers mature)

---

## Hardware Reference

### DGX Spark
| Spec | Value |
|------|-------|
| CPU | Grace ARM64 (20-core: 10× Cortex-X925 + 10× Cortex-A725) |
| GPU | Blackwell GB10 (sm_121, 6,144 CUDA cores) |
| Memory | 128GB unified LPDDR5X @ 273GB/s |
| CUDA | 13.0 |
| Best For | Large models (40GB+), video generation |

### RTX 5090
| Spec | Value |
|------|-------|
| CPU | AMD Ryzen 7 7700 (x86_64, 16 threads) |
| GPU | Blackwell RTX 5090 (sm_120, 21,760 CUDA cores) |
| Memory | 32GB GDDR7 dedicated |
| CUDA | 13.1 |
| Best For | Fast inference, high throughput |

---

## Key Files to Review

1. **`AGENTS.md`** - AI agent instructions, build approach, constraints
2. **`dgx-spark/README.md`** - DGX Spark quick start
3. **`dgx-spark/install.sh`** - Installation script (NVIDIA official)
4. **`.claude/plans/glistening-waddling-dahl.md`** - Detailed planning document

---

## Important Constraints (from AGENTS.md)

1. **DO NOT** use `nvidia/cuda` base images - use NGC PyTorch `nvcr.io/nvidia/pytorch:25.12-py3`
2. **DO NOT** install PyTorch via pip wheel on RTX 5090 Docker - NGC provides it
3. **DO** use `uv` for package management in Docker (10-100x faster than pip)
4. **DGX Spark uses pip3** per NVIDIA official instructions (not uv)
5. **Version bumps**: Edit `.version` before building Docker images

---

## Commands for Next Session

### To test DGX Spark:
```bash
# On local machine
scp -r dgx-spark/ user@dgx-spark:~/

# On DGX Spark
ssh user@dgx-spark
cd ~/dgx-spark
chmod +x *.sh
./install.sh
./start.sh
# Access: http://<DGX_SPARK_IP>:8188
```

### To build RTX 5090 Docker:
```bash
# On RTX 5090 machine
cd /path/to/comfyui-rtx5090
./build-push.sh
docker compose up -d
# Access: http://localhost:8188
```

### Git workflow:
```bash
# gh CLI is configured
gh auth status
git config user.name   # "Mister K"
git config user.email  # "678459+kairin@users.noreply.github.com"
```

---

## User Preferences (Discovered This Session)

- **Model Storage**: Separate local storage on each device (not shared NFS)
- **Custom Nodes**: Minimal (ComfyUI_Manager only, install on-demand)
- **Installation Approach**: NVIDIA official (simple pip3/venv, not enhanced uv)
- **Target Models**: Flux, SDXL, Large models (40GB+), Pony, Illustrious, Chinese models (Qwen, Z-Image, HunyuanVideo, Wan)

---

## Sources Referenced

- [NVIDIA ComfyUI on DGX Spark](https://build.nvidia.com/spark/comfy-ui/instructions)
- [ComfyUI Blog: DGX Spark](https://blog.comfy.org/p/comfyui-on-nvidia-dgx-spark)
- [DGX Spark Hardware](https://docs.nvidia.com/dgx/dgx-spark/hardware.html)
- [NVIDIA Forums: vLLM on DGX Spark](https://forums.developer.nvidia.com/t/run-vllm-in-spark/348862)

---

## Notes for Next LLM

1. **Read `AGENTS.md` first** - Contains critical build constraints
2. **Check git status** - Should be clean and synced with origin/main
3. **DGX Spark not tested yet** - Scripts created but need real device testing
4. **User has 2 devices** - RTX 5090 (Docker) and DGX Spark (native Python)
5. **gh CLI is authenticated** - Username: kairin
