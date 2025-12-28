# Contributing to ComfyUI RTX 5090

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Use the bug report template
3. Include:
   - Docker version (`docker --version`)
   - NVIDIA driver version (`nvidia-smi`)
   - Container logs (`docker logs comfyui-rtx5090`)
   - Steps to reproduce

### Suggesting Features

1. Open an issue with the feature request template
2. Describe the use case and expected behavior
3. Consider if it fits the project scope (RTX 5090 optimization)

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test the Docker build: `docker buildx build .`
5. Commit with clear messages
6. Push and open a PR

## Code Style

### Dockerfile

- One logical operation per `RUN` statement
- Clean apt cache at the end of each `RUN`
- Use `--no-cache-dir` for all pip installs
- Add comments for non-obvious operations

```dockerfile
# Good
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Avoid
RUN apt-get update
RUN apt-get install curl
```

### Shell Scripts

- Use `#!/bin/bash` with `set -e`
- Quote all variables: `"${VAR}"`
- Add error handling for critical operations

### Python Dependencies

- Pin exact versions: `package==1.2.3`
- Use `>=` only for security patches
- Document why each package is needed

## Testing

Before submitting a PR:

1. Build the image: `docker buildx build -t test .`
2. Run the container: `docker run --gpus all -it test`
3. Verify GPU access: `nvidia-smi` inside container
4. Test ComfyUI starts: check `http://localhost:8188`

## Branch Naming

- `feature/*` - New features
- `fix/*` - Bug fixes
- `docs/*` - Documentation updates

## Commit Messages

- Use present tense: "Add feature" not "Added feature"
- Keep first line under 72 characters
- Reference issues when applicable: "Fix #123"

## Questions?

Open an issue with the question label or start a discussion.
