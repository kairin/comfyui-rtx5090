variable "REGISTRY" {
  default = "docker.io/kairin"
}

variable "IMAGE_NAME" {
  default = "bases"
}

variable "IMAGE_TAG" {
  default = "comfyui-rtx5090"
}

variable "VERSION" {
  default = "latest"
}

variable "DATE_TAG" {
  default = ""
}

target "default" {
  context = "."
  dockerfile = "Dockerfile"

  tags = compact([
    # Always include specific version (immutable)
    "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}-v${VERSION}",

    # Date-based tag for easy tracking
    DATE_TAG != "" ? "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}-${DATE_TAG}" : "",

    # Latest tag for development
    "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}-latest",
  ])

  output = ["type=registry"]
}
