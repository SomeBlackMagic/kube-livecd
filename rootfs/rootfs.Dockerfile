FROM debian:12 AS builder
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash","-o","pipefail","-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    mmdebstrap ca-certificates qemu-utils e2fsprogs \
 && rm -rf /var/lib/apt/lists/*

ARG SUITE=bookworm
ARG MIRROR=http://deb.debian.org/debian
ARG IMAGE_SIZE=2G

RUN set -eux; \
  mkdir -p /work/rootfs /out; \
  mmdebstrap \
    --customize-hook='echo k8s-livecd > "$1/etc/hostname"' \
    --customize-hook='echo "127.0.1.1 livecd" >> "$1/etc/hosts"' \
    --variant=essential \
    --skip=check/essential \
    --include=systemd,systemd-sysv,systemd-timesyncd,systemd-resolved,bash,coreutils,util-linux,tzdata,ca-certificates,curl,iproute2,ethtool,kmod,udev,iptables,nftables,procps,socat,htop,ncdu,fdisk,nano,mc,e2fsprogs,cloud-init,openssh-server,ufw \
    --dpkgopt=path-exclude=/usr/share/doc/* \
    --dpkgopt=path-include=/usr/share/doc/*/copyright \
    --dpkgopt=path-exclude=/usr/share/man/* \
    --dpkgopt=path-exclude=/usr/share/locale/* \
    --dpkgopt=path-exclude=/usr/share/i18n/* \
    --dpkgopt=path-exclude=/usr/share/info/* \
    "$SUITE" /work/rootfs "$MIRROR"

# networkd DHCP
RUN set -eux; \
  mkdir -p /work/rootfs/etc/systemd/network;

# enable services + resolv.conf
RUN set -eux; \
  mkdir -p /work/rootfs/etc/systemd/system/multi-user.target.wants; \
  ln -sf /lib/systemd/system/systemd-networkd.service  /work/rootfs/etc/systemd/system/multi-user.target.wants/systemd-networkd.service; \
  ln -sf /lib/systemd/system/systemd-resolved.service  /work/rootfs/etc/systemd/system/multi-user.target.wants/systemd-resolved.service; \
  ln -sf /lib/systemd/system/systemd-timesyncd.service /work/rootfs/etc/systemd/system/multi-user.target.wants/systemd-timesyncd.service; \
  rm -f /work/rootfs/etc/resolv.conf || true; \
  ln -s /run/systemd/resolve/stub-resolv.conf /work/rootfs/etc/resolv.conf

# locale
RUN set -eux; printf 'LANG=C.UTF-8\n' > /work/rootfs/etc/default/locale

# root password
RUN set -eux; echo 'root:root' | chroot /work/rootfs chpasswd

# cleanup apt/dpkg/perl
RUN set -eux; \
  rm -rf /work/rootfs/var/lib/apt /work/rootfs/var/cache/apt \
         /work/rootfs/usr/bin/apt* /work/rootfs/usr/lib/apt \
         /work/rootfs/usr/share/apt /work/rootfs/etc/apt \
         /work/rootfs/usr/lib/x86_64-linux-gnu/perl* \
         /work/rootfs/usr/share/perl* /work/rootfs/usr/lib/perl* \
         /work/rootfs/usr/local/share/perl* || true

# journald persistent
RUN set -eux; \
  mkdir -p /work/rootfs/etc/systemd;

COPY rootfs/etc /work/rootfs/etc

# tar rootfs + qcow2 (for testing)
RUN tar -C /work/rootfs -czf /out/rootfs.tar.gz .
RUN set -eux; \
  truncate -s "$IMAGE_SIZE" /out/rootfs.raw; \
  mke2fs -F -t ext4 -L rootfs -d /work/rootfs /out/rootfs.raw; \
  qemu-img convert -O qcow2 -c /out/rootfs.raw /out/rootfs.qcow2; \
  rm -f /out/rootfs.raw

FROM busybox
COPY --from=builder /out/rootfs.tar.gz /out/rootfs.tar.gz
COPY --from=builder /out/rootfs.qcow2 /out/rootfs.qcow2
