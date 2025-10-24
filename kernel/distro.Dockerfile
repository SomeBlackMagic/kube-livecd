# syntax=docker/dockerfile:1
ARG DEBIAN_FRONTEND=noninteractive
FROM debian:12 AS build
ARG DEBIAN_FRONTEND
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates linux-image-amd64 rsync && \
    rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    KVER=$(ls -1 /boot/vmlinuz-* | sed 's|/boot/vmlinuz-||' | tail -n1); \
    mkdir -p /out/modules; \
    cp "/boot/vmlinuz-$KVER" /out/vmlinuz; \
    rsync -a "/lib/modules/$KVER" /out/modules/

FROM busybox
COPY --from=build /out/ /out/
