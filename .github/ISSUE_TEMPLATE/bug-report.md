---
name: Bug Report
about: Report a bug or unexpected behavior
title: '[BUG] '
labels: bug
assignees: ''
---

## Description

A clear description of what the bug is.

## Steps to Reproduce

1. Run `docker compose up -d`
2. Open ComfyUI at `http://localhost:8188`
3. ...
4. See error

## Expected Behavior

What you expected to happen.

## Actual Behavior

What actually happened.

## Environment

- **Docker version**: `docker --version`
- **NVIDIA Driver**: `nvidia-smi --query-gpu=driver_version --format=csv,noheader`
- **GPU Model**: RTX 5090 / other
- **Host OS**: Ubuntu 24.04 / other
- **Image tag**: `kairin/bases:comfyui-rtx5090-v1.0.0`

## Logs

```
Paste container logs here:
docker logs comfyui-rtx5090
```

## Additional Context

Add any other context about the problem here.
