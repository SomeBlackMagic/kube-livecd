#!/bin/bash
set -euo pipefail

#docker build \
#  -f kernel.distro.Dockerfile \
#  -t kimg:distro .
#cid=$(docker create kimg:distro)
#docker cp "$cid":/out/vmlinuz ./vmlinuz
#docker cp "$cid":/out/modules ./modules
#docker rm "$cid"

docker build -f kernel/vanilla.Dockerfile \
  --build-arg LINUX_TARBALL_URL=https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.17.4.tar.xz \
  -t kernel:vanilla .
cid=$(docker create kernel:vanilla)
docker cp "$cid":/out ./kernel
docker rm "$cid"

docker build -f rootfs/rootfs.Dockerfile -t rootfs:base .
cid=$(docker create rootfs:base)
docker cp "$cid":/out ./rootfs/
docker rm "$cid"

