FROM php:8.3-cli-alpine AS base

RUN apk add --no-cache \
    bash curl git build-base cmake go jq \
    coreutils openssl-dev libzip-dev zlib-dev libpng-dev libjpeg-turbo-dev \
    libwebp-dev freetype-dev libxml2-dev icu-dev libxslt-dev \
    postgresql-dev bzip2-dev gmp-dev sqlite-dev oniguruma-dev \
    tidyhtml-dev openldap-dev linux-headers

WORKDIR /frankenphp

# Optional: pin to tag or commit
RUN git clone --recursive https://github.com/dunglas/frankenphp . && \
    chmod +x ./build-static.sh

ENV PHP_VERSION=8.4 \
    PHP_EXTENSIONS="ctype,curl,dom,fileinfo,intl,mbstring,opcache,pcntl,pdo_sqlite,phar,posix,session,shmop,simplexml,sockets,sodium,sysvmsg,sysvsem,sysvshm,tokenizer,xml,openssl,xmlreader,xmlwriter,zip,redis,igbinary,xhprof" \
    PHP_EXTENSION_LIBS="bzip2,freetype,libjpeg,libpng,libsodium,libzip,libxml2,zlib,icu,libxslt,libwebp" \
    SPC_LIBC=musl \
    CLASSIC=1 \
    MIMALLOC=1

RUN ./build-static.sh

FROM alpine:3.20 AS frankenphp-builder

COPY --from=base /frankenphp/dist/frankenphp-linux-*/ /usr/local/bin/frankenphp
