FROM golang:1.26-alpine AS builder

ARG TARGETARCH

ARG FRANKENPHP_VERSION=''
ENV FRANKENPHP_VERSION=${FRANKENPHP_VERSION}

ARG PHP_VERSION=''
ENV PHP_VERSION=${PHP_VERSION}

ARG XCADDY_ARGS=''
ARG CLEAN=''
ARG EMBED=''
ARG DEBUG_SYMBOLS=''
ARG MIMALLOC=''
ARG NO_COMPRESS=''
ARG PHP_EXTENSIONS="xhprof,iconv"
ARG PHP_EXTENSION_LIBS="icu"

ENV GOTOOLCHAIN=local

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

LABEL org.opencontainers.image.title=FrankenPHP
LABEL org.opencontainers.image.description="The modern PHP app server"
LABEL org.opencontainers.image.url=https://frankenphp.dev
LABEL org.opencontainers.image.source=https://github.com/dunglas/frankenphp
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.vendor="Kévin Dunglas"

RUN apk update && apk add --no-cache alpine-sdk autoconf automake bash binutils bison build-base cmake curl \
	file flex g++ gcc git jq libgcc libstdc++ libtool linux-headers m4 make gettext-dev binutils-gold patchelf pkgconfig php84 \
	php84-common php84-ctype php84-curl php84-dom php84-mbstring php84-openssl php84-pcntl php84-phar php84-posix php84-session php84-sodium \
	php84-tokenizer php84-xml php84-xmlwriter php84-iconv upx wget xz && \
	ln -sf /usr/bin/php84 /usr/bin/php && go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=composer/composer:2-bin /composer /usr/bin/composer

WORKDIR /go/src/app

RUN git clone --recursive https://github.com/dunglas/frankenphp . && \
	if [ -n "${FRANKENPHP_VERSION}" ]; then git checkout "${FRANKENPHP_VERSION}"; fi

RUN go mod download

WORKDIR /go/src/app/caddy
RUN go mod download

WORKDIR /go/src/app

ENV SPC_DEFAULT_C_FLAGS='-fPIE -fPIC -O3'
ENV SPC_LIBC='musl'
ENV SPC_CMD_VAR_PHP_MAKE_EXTRA_LDFLAGS_PROGRAM='-Wl,-O3 -pie'
ENV SPC_OPT_BUILD_ARGS='--with-config-file-path=/etc/frankenphp --with-config-file-scan-dir=/etc/frankenphp/php.d'
ENV SPC_REL_TYPE='binary'
ENV EXTENSION_DIR='/usr/lib/frankenphp/modules'
ENV PHP_EXTENSIONS=${PHP_EXTENSIONS}
ENV PHP_EXTENSION_LIBS=${PHP_EXTENSION_LIBS}

RUN --mount=type=secret,id=github-token \
	defaultExtensions=$(grep '^defaultExtensions=' build-static.sh \
	| sed -E 's/^defaultExtensions="([^"]*)".*/\1/') && \
	defaultLibs=$(grep '^defaultExtensionLibs=' build-static.sh \
	| sed -E 's/^defaultExtensionLibs="([^"]*)".*/\1/') && \
	mergedExts="${defaultExtensions},${PHP_EXTENSIONS}" && \
	mergedLibs="${defaultLibs},${PHP_EXTENSION_LIBS}" && \
	PHP_EXTENSIONS=$(echo "$mergedExts"           \
	| tr ',' '\n'                 \
	| awk '!seen[$0]++'           \
	| paste -sd ',' -) &&         \
	PHP_EXTENSION_LIBS=$(echo "$mergedLibs"       \
	| tr ',' '\n'             \
	| awk '!seen[$0]++'       \
	| paste -sd ',' -) &&     \
	export PHP_EXTENSIONS PHP_EXTENSION_LIBS &&   \
	GITHUB_TOKEN=$(cat /run/secrets/github-token) \
	./build-static.sh && \
	rm -rf dist/static-php-cli/source/*

FROM alpine:3.20 AS frankenphp

LABEL org.opencontainers.image.title=FrankenPHP
LABEL org.opencontainers.image.description="The modern PHP app server"
LABEL org.opencontainers.image.url=https://frankenphp.dev
LABEL org.opencontainers.image.source=https://github.com/dunglas/frankenphp

# Copy the statically‑built FrankenPHP binary from builder
COPY --from=builder /go/src/app/dist/frankenphp-linux-* /usr/local/bin/frankenphp

# Make it executable (just in case)
RUN chmod +x /usr/local/bin/frankenphp

ENTRYPOINT ["/usr/local/bin/frankenphp"]
