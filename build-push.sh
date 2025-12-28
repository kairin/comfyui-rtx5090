#!/bin/bash
set -e

# Read version from file
VERSION=$(cat .version)
DATE_TAG=$(date +%Y%m%d)

echo "========================================"
echo "Building ComfyUI Docker Image"
echo "========================================"
echo "Version: $VERSION"
echo "Date:    $DATE_TAG"
echo "========================================"
echo ""

# Build and push with all tags
VERSION=$VERSION DATE_TAG=$DATE_TAG docker buildx bake --push

echo ""
echo "========================================"
echo "Successfully pushed:"
echo "========================================"
echo "  - kairin/bases:comfyui-rtx5090-v$VERSION"
echo "  - kairin/bases:comfyui-rtx5090-$DATE_TAG"
echo "  - kairin/bases:comfyui-rtx5090-latest"
echo ""
echo "To run: docker compose up -d"
echo "========================================"
