# Register QEMU (just once per host—skip if you already did it)
# docker run --rm --privileged tonistiigi/binfmt --install all

docker buildx create --use --name tmp-multiarch

docker buildx build \
        --builder tmp-multiarch \
        --platform linux/amd64,linux/arm64 \
        --tag ghcr.io/arabcoders/franken_builder:latest \
        --progress plain \
        --push \
        . &&

docker buildx rm tmp-multiarch