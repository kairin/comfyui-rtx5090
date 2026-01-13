# ComfyUI on DGX Spark

ComfyUI installation following [NVIDIA's official instructions](https://build.nvidia.com/spark/comfy-ui/instructions).

## Hardware

| Component | Specification |
|-----------|---------------|
| **CPU** | 20-core Grace ARM64 (10× Cortex-X925 + 10× Cortex-A725) |
| **GPU** | Blackwell GB10 (sm_121, 6,144 CUDA cores) |
| **Memory** | 128GB unified LPDDR5X @ 273GB/s |
| **CUDA** | 13.0 |

## Quick Start (NVIDIA Official)

```bash
# 1. Copy scripts to DGX Spark
scp -r dgx-spark/ user@dgx-spark:~/

# 2. SSH and install
ssh user@dgx-spark
cd ~/dgx-spark
chmod +x *.sh
./install.sh

# 3. Start ComfyUI
./start.sh
```

Access at: `http://<DGX_SPARK_IP>:8188`

## What install.sh Does

Following NVIDIA's exact instructions:

1. Creates virtual environment: `python3 -m venv comfyui-env`
2. Installs PyTorch: `pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu130`
3. Clones ComfyUI: `git clone https://github.com/comfyanonymous/ComfyUI.git`
4. Installs dependencies: `pip install -r requirements.txt`
5. Downloads SD 1.5 model (~2GB)

## Files

| File | Purpose |
|------|---------|
| `install.sh` | NVIDIA official installation |
| `start.sh` | Simple startup (NVIDIA official) |
| `start-optimized.sh` | Optional: adds memory optimizations |

## Optional: Optimized Startup

For better memory utilization with 128GB unified memory:

```bash
./start-optimized.sh
```

This adds:
- `--highvram` flag (keep models in memory)
- `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`
- `OMP_NUM_THREADS=10` (use performance cores)

## Validation

```bash
curl -I http://localhost:8188
# Should return HTTP 200
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| PyTorch wheel not found | Verify `--index-url https://download.pytorch.org/whl/cu130` |
| wget fails | Check network; download model manually |
| Port 8188 blocked | `sudo ufw allow 8188` |
| CUDA not detected | Run `nvidia-smi` |

## References

- [NVIDIA ComfyUI on DGX Spark](https://build.nvidia.com/spark/comfy-ui/instructions)
- [ComfyUI GitHub](https://github.com/comfyanonymous/ComfyUI)
- [DGX Spark Hardware](https://docs.nvidia.com/dgx/dgx-spark/hardware.html)
