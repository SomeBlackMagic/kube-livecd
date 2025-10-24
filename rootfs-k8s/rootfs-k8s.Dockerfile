# syntax=docker/dockerfile:1
FROM debian:12 AS builder
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash","-o","pipefail","-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates xz-utils tar gzip coreutils \
 && rm -rf /var/lib/apt/lists/*

ARG KUBELET_URL=""
ARG KUBELET_SHA256=""

ARG KUBEADM_URL=""
ARG KUBEADM_SHA256=""

ARG KUBECTL_URL=""
ARG KUBECTL_SHA256=""

ARG CONTAINERD_TGZ_URL=""
ARG CONTAINERD_TGZ_SHA256=""

ARG RUNC_URL=""
ARG RUNC_SHA256=""

ARG CRIO_TGZ_URL=""
ARG CRIO_TGZ_SHA256=""

ARG CRICTL_TGZ_URL=""
ARG CRICTL_TGZ_SHA256=""

ARG NERDCTL_TGZ_URL=""
ARG NERDCTL_TGZ_SHA256=""

ARG CNI_PLUGINS_TGZ_URL=""
ARG CNI_PLUGINS_TGZ_SHA256=""




RUN set -eux; mkdir -p /work/rootfs /tmp/dl;

# kubelet
RUN set -eux; \
  [ -z "$KUBELET_URL" ] || { \
    curl -fsSL "$KUBELET_URL" -o /tmp/dl/kubelet; \
    [ -z "$KUBELET_SHA256" ] || echo "$KUBELET_SHA256  /tmp/dl/kubelet" | sha256sum -c -; \
    install -m0755 -D /tmp/dl/kubelet /work/rootfs/usr/bin/kubelet; \
  }

# kubeadm
RUN set -eux; \
  [ -z "$KUBEADM_URL" ] || { \
    curl -fsSL "$KUBEADM_URL" -o /tmp/dl/kubeadm; \
    [ -z "$KUBEADM_SHA256" ] || echo "$KUBEADM_SHA256  /tmp/dl/kubeadm" | sha256sum -c -; \
    install -m0755 -D /tmp/dl/kubeadm /work/rootfs/usr/bin/kubeadm; \
  }

# kubectl
RUN set -eux; \
  [ -z "$KUBECTL_URL" ] || { \
    curl -fsSL "$KUBECTL_URL" -o /tmp/dl/kubectl; \
    [ -z "$KUBECTL_SHA256" ] || echo "$KUBECTL_SHA256  /tmp/dl/kubectl" | sha256sum -c -; \
    install -m0755 -D /tmp/dl/kubectl /work/rootfs/usr/bin/kubectl; \
  }

# containerd
RUN set -eux; \
  [ -z "$CONTAINERD_TGZ_URL" ] || { \
    curl -fsSL "$CONTAINERD_TGZ_URL" -o /tmp/dl/containerd.tgz; \
    [ -z "$CONTAINERD_TGZ_SHA256" ] || echo "$CONTAINERD_TGZ_SHA256  /tmp/dl/containerd.tgz" | sha256sum -c -; \
    mkdir -p /tmp/containerd; tar -xzf /tmp/dl/containerd.tgz -C /tmp/containerd; \
    if [ -d /tmp/containerd/bin ]; then \
      install -m0755 -t /work/rootfs/usr/bin /tmp/containerd/bin/*; \
    else \
      find /tmp/containerd -maxdepth 2 -type f -perm -111 -name 'containerd*' -exec install -m0755 -t /work/rootfs/usr/bin {} +; \
    fi; \
  }

# runc
RUN set -eux; \
  [ -z "$RUNC_URL" ] || { \
    curl -fsSL "$RUNC_URL" -o /tmp/dl/runc; \
    [ -z "$RUNC_SHA256" ] || echo "$RUNC_SHA256  /tmp/dl/runc" | sha256sum -c -; \
    install -m0755 -D /tmp/dl/runc /work/rootfs/usr/sbin/runc; \
  }

# crictl
RUN set -eux; \
  [ -z "$CRICTL_TGZ_URL" ] || { \
    curl -fsSL "$CRICTL_TGZ_URL" -o /tmp/dl/crictl.tgz; \
    [ -z "$CRICTL_TGZ_SHA256" ] || echo "$CRICTL_TGZ_SHA256  /tmp/dl/crictl.tgz" | sha256sum -c -; \
    mkdir -p /tmp/crictl; tar -xzf /tmp/dl/crictl.tgz -C /tmp/crictl; \
    find /tmp/crictl -type f -name crictl -exec install -m0755 -t /work/rootfs/usr/bin {} +; \
  }

# nerdctl
RUN set -eux; \
  [ -z "$NERDCTL_TGZ_URL" ] || { \
    curl -fsSL "$NERDCTL_TGZ_URL" -o /tmp/dl/nerdctl.tgz; \
    [ -z "$NERDCTL_TGZ_SHA256" ] || echo "$NERDCTL_TGZ_SHA256  /tmp/dl/nerdctl.tgz" | sha256sum -c -; \
    mkdir -p /tmp/nerdctl; tar -xzf /tmp/dl/nerdctl.tgz -C /tmp/nerdctl; \
    find /tmp/nerdctl -type f -name nerdctl -exec install -m0755 -t /work/rootfs/usr/bin {} +; \
  }

# CNI plugins
RUN set -eux; \
  [ -z "$CNI_PLUGINS_TGZ_URL" ] || { \
    curl -fsSL "$CNI_PLUGINS_TGZ_URL" -o /tmp/dl/cni.tgz; \
    [ -z "$CNI_PLUGINS_TGZ_SHA256" ] || echo "$CNI_PLUGINS_TGZ_SHA256  /tmp/dl/cni.tgz" | sha256sum -c -; \
    mkdir -p /work/rootfs/opt/cni/bin; tar -xzf /tmp/dl/cni.tgz -C /work/rootfs/opt/cni/bin; \
    chmod 0755 /work/rootfs/opt/cni/bin/* || true; \
  }

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-utils e2fsprogs \
 && rm -rf /var/lib/apt/lists/*



# systemd units and configs
COPY --chown=root:root --chmod=0644 rootfs-k8s/files/etc  /work/rootfs/etc

# Configs and units
RUN set -eux; \
  mkdir -p /work/rootfs/etc/systemd/system /work/rootfs/etc/containerd /work/rootfs/etc/cni/net.d; \
  mkdir -p /work/rootfs/etc/systemd/system/multi-user.target.wants; \
  ln -sf ../containerd.service /work/rootfs/etc/systemd/system/multi-user.target.wants/containerd.service; \
  ln -sf ../preload-k8s-images.service /work/rootfs/etc/systemd/system/multi-user.target.wants/preload-k8s-images.service; \
  ln -sf ../kubelet.service     /work/rootfs/etc/systemd/system/multi-user.target.wants/kubelet.service

COPY rootfs/out/rootfs.tar.gz /in/rootfs.tar.gz
RUN tar -C /work/rootfs -xzf /in/rootfs.tar.gz

ARG IMAGE_SIZE=2G
# Archiving
RUN set -eux; \
  mkdir -p /out; \
  tar -C /work/rootfs -czf /out/rootfs-k8s.tar.gz .
RUN set -eux; \
  truncate -s "$IMAGE_SIZE" /out/rootfs.raw; \
  mke2fs -F -t ext4 -L rootfs -O ^metadata_csum,^has_journal -d /work/rootfs /out/rootfs.raw; \
  qemu-img convert -O qcow2 -c /out/rootfs.raw /out/rootfs-k8s.qcow2; \
  rm -f /out/rootfs.raw

FROM busybox
COPY --from=builder /out/rootfs-k8s.tar.gz /out/rootfs-k8s.tar.gz
COPY --from=builder /out/rootfs-k8s.qcow2 /out/rootfs-k8s.qcow2
