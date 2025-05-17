docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/arabcoders/franken_builder:latest \
  --push \
  .