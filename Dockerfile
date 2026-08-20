# syntax=docker/dockerfile:1

FROM dunglas/frankenphp:static-builder-musl AS builder

RUN --mount=type=secret,id=github-token \
    default_extensions="$(sed -n 's/^defaultExtensions="\([^"]*\)".*/\1/p' build-static.sh)" && \
    case ",${default_extensions}," in \
        *,xhprof,*) extensions="${default_extensions}" ;; \
        *) extensions="${default_extensions},xhprof" ;; \
    esac && \
    if [ -s /run/secrets/github-token ]; then export GITHUB_TOKEN="$(cat /run/secrets/github-token)"; fi && \
    PHP_EXTENSIONS="${extensions}" ./build-static.sh

FROM scratch

LABEL org.opencontainers.image.title="WatchState FrankenPHP"
LABEL org.opencontainers.image.description="Static FrankenPHP with the PHP extensions required by WatchState"
LABEL org.opencontainers.image.source="https://github.com/arabcoders/franken_builder"

COPY --from=builder /go/src/app/dist/frankenphp-linux-* /usr/local/bin/frankenphp

ENTRYPOINT ["/usr/local/bin/frankenphp"]
