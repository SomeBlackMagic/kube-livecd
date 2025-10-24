# syntax=docker/dockerfile:1
FROM debian:12 AS builder
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash","-o","pipefail","-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    xorriso grub-pc-bin grub-efi-amd64-bin mtools \
    squashfs-tools busybox-static cpio file \
    util-linux e2fsprogs ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# inputs
COPY kernel/out/vmlinuz /build/in/vmlinuz
COPY rootfs-k8s/out/rootfs-k8s.tar.gz /build/in/rootfs.tar.gz
COPY livecd/files/init /build/in/init
COPY livecd/files/grub.cfg /build/in/grub.cfg
COPY livecd/files/copybin.sh /build/in/copybin.sh

# 1) build squashfs from rootfs
RUN set -eux; \
  mkdir -p /build/rootfs /iso/live /iso/boot; \
  tar -C /build/rootfs -xzf /build/in/rootfs.tar.gz; \
  mksquashfs /build/rootfs /iso/live/filesystem.squashfs -comp xz -b 1M -noappend

# 2) initrd with overlayfs (upper/work in root of RW-disk)
RUN set -eux; \
  rm -rf /initrd; \
  mkdir -p /initrd/bin /initrd/sbin /initrd/proc /initrd/sys /initrd/dev /initrd/newroot /initrd/mnt /initrd/lower /initrd/run; \
  install -m0755 "$(command -v busybox)" /initrd/bin/busybox; \
  for n in sh mount switch_root mkdir mknod echo cat; do ln -sf busybox /initrd/bin/"$n"; done; \
  mknod -m 666 /initrd/dev/null    c 1 3; \
  mknod -m 666 /initrd/dev/tty     c 5 0; \
  mknod -m 600 /initrd/dev/console c 5 1; \
  mknod -m 660 /initrd/dev/loop0   b 7 0; \
  . /build/in/copybin.sh; \
  copybin lsblk; \
  copybin blkid; \
  copybin findmnt; \
  copybin mkfs.ext4; \
  copybin tune2fs; \
  install -m0755 /build/in/init /initrd/init

# 3) pack initrd
RUN set -eux; \
  (cd /initrd && find . -mindepth 1 -printf '%P\0' | cpio --null -ov -H newc --owner 0:0 | gzip -9) > /iso/boot/initrd.img; \
  file /iso/boot/initrd.img

# 4) build ISO
RUN set -eux; \
  cp /build/in/vmlinuz /iso/boot/vmlinuz; \
  mkdir -p /iso/boot/grub /out; \
  cp /build/in/grub.cfg /iso/boot/grub/grub.cfg; \
  grub-mkrescue -o /out/node.iso /iso

FROM busybox
COPY --from=builder /out/node.iso /out/node.iso
COPY --from=builder /iso/boot/initrd.img /out/initrd.img
