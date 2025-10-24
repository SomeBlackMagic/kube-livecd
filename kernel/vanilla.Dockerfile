# syntax=docker/dockerfile:1

ARG DEBIAN_FRONTEND=noninteractive
ARG LINUX_TARBALL_URL

FROM debian:12 AS build
ARG DEBIAN_FRONTEND
ARG LINUX_TARBALL_URL

RUN test -n "$LINUX_TARBALL_URL" || (echo "Set LINUX_TARBALL_URL" && exit 2)

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential bc bison flex libssl-dev libncurses-dev \
    libelf-dev zlib1g-dev pkg-config dwarves xz-utils wget ca-certificates \
 && update-ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN --mount=type=cache,target=/build wget -O linux.tar.xz "$LINUX_TARBALL_URL" && tar -xf linux.tar.xz

RUN --mount=type=cache,target=/build \
  set -eux; \
  cd linux-*; \
  make defconfig; \
  \
  # ============================================================
  # BASIC SYSTEM CAPABILITIES
  # ============================================================
  ./scripts/config --enable CONFIG_SECURITY_APPARMOR; \
  ./scripts/config --enable CONFIG_FHANDLE; \
  ./scripts/config --enable CONFIG_TMPFS; \
  ./scripts/config --enable CONFIG_EXT4_FS; \
  ./scripts/config --enable CONFIG_NET; \
  ./scripts/config --enable CONFIG_FW_LOADER; \
  ./scripts/config --disable CONFIG_MODULES; \
  ./scripts/config --enable CONFIG_BINFMT_SCRIPT; \
  \
  # ============================================================
  # NAMESPACES
  # ============================================================
  ./scripts/config --enable CONFIG_NAMESPACES; \
  ./scripts/config --enable CONFIG_UTS_NS; \
  ./scripts/config --enable CONFIG_IPC_NS; \
  ./scripts/config --enable CONFIG_PID_NS; \
  ./scripts/config --enable CONFIG_NET_NS; \
  \
  # ============================================================
  # DEVTMPFS
  # ============================================================
  ./scripts/config --enable CONFIG_DEVTMPFS; \
  ./scripts/config --enable CONFIG_DEVTMPFS_MOUNT; \
  \
  # ============================================================
  # CGROUPS v2
  # ============================================================
  ./scripts/config --enable CONFIG_CGROUPS; \
  ./scripts/config --enable CONFIG_CGROUP_SCHED; \
  ./scripts/config --enable CONFIG_CGROUP_PIDS; \
  ./scripts/config --enable CONFIG_CGROUP_FREEZER; \
  ./scripts/config --enable CONFIG_CGROUP_DEVICE; \
  ./scripts/config --enable CONFIG_CGROUP_HUGETLB; \
  ./scripts/config --enable CONFIG_CGROUP_BPF; \
  ./scripts/config --enable CONFIG_CPUSETS; \
  ./scripts/config --enable CONFIG_MEMCG; \
  ./scripts/config --enable CONFIG_MEMCG_SWAP; \
  ./scripts/config --enable CONFIG_CFS_BANDWIDTH; \
  \
  # ============================================================
  # BPF
  # ============================================================
  ./scripts/config --enable CONFIG_BPF; \
  ./scripts/config --enable CONFIG_BPF_SYSCALL; \
  ./scripts/config --enable CONFIG_BPF_JIT; \
  \
  # ============================================================
  # SECURITY
  # ============================================================
  ./scripts/config --enable CONFIG_SECCOMP; \
  ./scripts/config --enable CONFIG_SECCOMP_FILTER; \
  \
  # ============================================================
  # FILESYSTEMS
  # ============================================================
  ./scripts/config --enable CONFIG_OVERLAY_FS; \
  ./scripts/config --enable CONFIG_SQUASHFS; \
  ./scripts/config --enable CONFIG_SQUASHFS_XZ; \
  ./scripts/config --enable CONFIG_ISO9660_FS; \
  \
  # ============================================================
  # BLOCK DEVICES
  # ============================================================
  ./scripts/config --enable CONFIG_BLK_DEV_LOOP; \
  ./scripts/config --enable CONFIG_BLK_DEV_DM; \
  ./scripts/config --enable CONFIG_BLK_DEV_SR; \
  ./scripts/config --enable CONFIG_CDROM; \
  \
  # ============================================================
  # INITRD
  # ============================================================
  ./scripts/config --enable CONFIG_BLK_DEV_INITRD; \
  ./scripts/config --enable CONFIG_RD_GZIP; \
  \
  # ============================================================
  # VIRTIO
  # ============================================================
  ./scripts/config --enable CONFIG_VIRTIO_PCI; \
  ./scripts/config --enable CONFIG_VIRTIO_BLK; \
  ./scripts/config --enable CONFIG_VIRTIO_NET; \
  \
  # ============================================================
  # KERNEL CONFIG EXPORT
  # ============================================================
  ./scripts/config --enable CONFIG_IKCONFIG; \
  ./scripts/config --enable CONFIG_IKCONFIG_PROC; \
  \
  # ============================================================
  # NETFILTER: BASE
  # ============================================================
  ./scripts/config --enable CONFIG_NETFILTER; \
  ./scripts/config --enable CONFIG_NETFILTER_ADVANCED; \
  \
  # ============================================================
  # NETFILTER: CONNECTION TRACKING
  # ============================================================
  ./scripts/config --enable CONFIG_NF_CONNTRACK; \
  ./scripts/config --enable CONFIG_NF_CONNTRACK_IPV4; \
  ./scripts/config --enable CONFIG_NF_CONNTRACK_IPV6; \
  \
  # ============================================================
  # NETFILTER: NAT
  # ============================================================
  ./scripts/config --enable CONFIG_NF_NAT; \
  ./scripts/config --enable CONFIG_NF_NAT_MASQUERADE; \
  ./scripts/config --enable CONFIG_IP_NF_NAT; \
  \
  # ============================================================
  # NETFILTER: NFTABLES
  # ============================================================
  ./scripts/config --enable CONFIG_NF_TABLES; \
  ./scripts/config --enable CONFIG_NF_TABLES_INET; \
  ./scripts/config --enable CONFIG_NF_TABLES_IPV4; \
  ./scripts/config --enable CONFIG_NF_TABLES_IPV6; \
  ./scripts/config --enable CONFIG_NF_TABLES_BRIDGE; \
  ./scripts/config --enable CONFIG_NFT_CT; \
  ./scripts/config --enable CONFIG_NFT_COUNTER; \
  ./scripts/config --enable CONFIG_NFT_LOG; \
  ./scripts/config --enable CONFIG_NFT_REJECT; \
  ./scripts/config --enable CONFIG_NFT_REDIR; \
  ./scripts/config --enable CONFIG_NFT_MASQ; \
  ./scripts/config --enable CONFIG_NFT_NAT; \
  ./scripts/config --enable CONFIG_NFT_TUNNEL; \
  ./scripts/config --enable CONFIG_NFT_COMPAT; \
  \
  # ============================================================
  # NETFILTER: XTABLES (IPv4)
  # ============================================================
  ./scripts/config --enable CONFIG_NETFILTER_XTABLES; \
  ./scripts/config --enable CONFIG_NETFILTER_XT_MATCH_COMMENT; \
  ./scripts/config --enable CONFIG_NETFILTER_XT_TARGET_REDIRECT; \
  ./scripts/config --enable CONFIG_IP_NF_IPTABLES; \
  ./scripts/config --enable CONFIG_IP_NF_FILTER; \
  ./scripts/config --enable CONFIG_IP_NF_MANGLE; \
  ./scripts/config --enable CONFIG_IP_NF_TARGET_REDIRECT; \
  ./scripts/config --enable CONFIG_IP_NF_MATCH_AH; \
  ./scripts/config --enable CONFIG_IP_NF_MATCH_ECN; \
  ./scripts/config --enable CONFIG_IP_NF_MATCH_RPFILTER; \
  ./scripts/config --enable CONFIG_IP_NF_MATCH_TTL; \
  ./scripts/config --enable CONFIG_IP_NF_TARGET_REJECT; \
  ./scripts/config --enable CONFIG_IP_NF_TARGET_SYNPROXY; \
  ./scripts/config --enable CONFIG_IP_NF_TARGET_ECN; \
  \
  # ============================================================
  # NETFILTER: XTABLES (IPv6)
  # ============================================================
  ./scripts/config --enable CONFIG_IP6_NF_IPTABLES; \
  ./scripts/config --enable CONFIG_IP6_NF_FILTER; \
  ./scripts/config --enable CONFIG_IP6_NF_MANGLE; \
  \
  # ============================================================
  # BRIDGE NETFILTER
  # ============================================================
  ./scripts/config --enable CONFIG_BRIDGE; \
  ./scripts/config --enable CONFIG_BRIDGE_NETFILTER; \
  ./scripts/config --enable CONFIG_NET_NS; \
  ./scripts/config --enable CONFIG_VETH; \
  \
  yes "" | make olddefconfig; \
  make -j"$(nproc)"; \
  install -D arch/x86/boot/bzImage /out/vmlinuz; \
  install -D .config               /out/config; \
  [ -f System.map ] && install -D System.map /out/System.map || true

FROM busybox
COPY --from=build /out/ /out/
