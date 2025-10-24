# Kubernetes Live CD

A minimal, layered Linux distribution designed for running Kubernetes clusters in virtual environments. Built using Docker multi-stage builds to create reproducible, lightweight system images.

## Overview

This project provides a complete, bootable Linux system optimized for Kubernetes workloads. It uses a layered architecture where each component is built independently and combined to create a Live CD/ISO that boots into a functional Kubernetes-ready environment.

## Architecture

The system is composed of five main layers:

### 1. Kernel Layer (`kernel/`)

Builds a custom Linux kernel optimized for containerization and Kubernetes.

**Purpose:**
- Provides a minimal kernel with only required features enabled
- Includes support for namespaces, cgroups v2, overlay filesystems, and container networking
- Configured for QEMU/KVM virtualization with VirtIO drivers

**Key Features:**
- Container runtime support (namespaces, cgroups, seccomp, AppArmor)
- Network filtering (netfilter, nftables, iptables)
- Block device and filesystem support (overlay, squashfs, ext4, ISO9660)
- Initrd support for Live CD boot
- Bridge networking and VETH devices for container networking

**Files:**
- `vanilla.Dockerfile` - Builds kernel from upstream source with custom configuration
- `distro.Dockerfile` - Alternative: extracts kernel from Debian distribution

**Output:** `kernel/out/vmlinuz` (compressed kernel image)

### 2. Base Root Filesystem Layer (`rootfs/`)

Creates a minimal Debian-based root filesystem with systemd.

**Purpose:**
- Provides the base operating system with essential utilities
- Includes systemd for service management
- Sets up networking, SSH access, and system administration tools

**Key Components:**
- systemd with networkd, resolved, and timesyncd
- Cloud-init for initial configuration
- OpenSSH server for remote access
- Network tools: iproute2, iptables, nftables
- System utilities: bash, coreutils, htop, mc, nano

**Configuration:**
- Hostname: `k8s-livecd`
- Root password: `root`
- Networkd configured for DHCP
- Resolved for DNS management
- Persistent journald logging

**Output:**
- `rootfs/out/rootfs.tar.gz` (tarball)
- `rootfs/out/rootfs.qcow2` (disk image for testing)

### 3. Kubernetes Layer (`rootfs-k8s/`)

Extends the base rootfs with Kubernetes components and container runtime.

**Purpose:**
- Adds Kubernetes control plane and worker node binaries
- Installs containerd as the container runtime
- Includes container management tools

**Components:**
- **Kubernetes:** kubelet, kubeadm, kubectl
- **Container Runtime:** containerd, runc
- **Container Tools:** crictl, nerdctl
- **Networking:** CNI plugins for container networking

**Systemd Services:**
- `containerd.service` - Container runtime daemon
- `kubelet.service` - Kubernetes node agent
- `preload-k8s-images.service` - Pre-loads container images

**Output:**
- `rootfs-k8s/out/rootfs-k8s.tar.gz` (tarball)
- `rootfs-k8s/out/rootfs-k8s.qcow2` (disk image)

### 4. Live CD Layer (`livecd/`)

Packages everything into a bootable ISO image with an overlay filesystem.

**Purpose:**
- Creates a bootable Live CD/ISO
- Implements an overlay filesystem for persistent storage
- Provides custom init system for boot process

**Architecture:**
- **Lower layer:** Read-only squashfs containing the root filesystem
- **Upper layer:** Read-write ext4 partition for changes
- **Overlay:** Combines both layers using OverlayFS

**Boot Process (`livecd/files/init`):**
1. Mount proc, sys, and devtmpfs
2. Locate and mount the Live CD (ISO) containing squashfs
3. Mount squashfs as read-only lower layer
4. Find available writable device and format as ext4 if needed
5. Create upper and work directories on writable device
6. Mount overlay filesystem combining lower and upper layers
7. Switch root and start systemd

**GRUB Configuration:**
- Boots with kernel and custom initrd
- Console output on serial (ttyS0) and VGA
- Passes kernel parameters for systemd and cgroup v2

**Output:**
- `livecd/out/node.iso` - Bootable ISO image
- `livecd/out/initrd.img` - Initial ramdisk with custom init

### 5. Cloud-Init Layer (`cloudinit/`)

Provides cloud-init configuration for automated system setup.

**Purpose:**
- Automates initial system configuration
- Configures networking, users, and services on first boot
- Uses NoCloud datasource (no cloud provider required)

**Components:**
- `user-data` - Cloud-init user data configuration
- `meta-data` - Instance metadata
- `network-config` - Network configuration

**Output:** `cloudinit/cloud-init-seed.iso` - NoCloud seed ISO with label `cidata`

## Building

Run the main build script to create all layers:

```bash
./build.sh
```

This script:
1. Builds the kernel from source
2. Creates the base rootfs
3. Adds Kubernetes components
4. Packages everything into a Live CD ISO
5. Generates cloud-init configuration ISO

### Build Arguments

Kubernetes and container runtime versions can be customized via build arguments in `build.sh`:

- `KUBELET_URL`, `KUBEADM_URL`, `KUBECTL_URL` - Kubernetes binaries
- `CONTAINERD_TGZ_URL` - containerd release
- `RUNC_URL` - runc binary
- `CRICTL_TGZ_URL` - CRI tools
- `NERDCTL_TGZ_URL` - nerdctl (containerd CLI)
- `CNI_PLUGINS_TGZ_URL` - CNI networking plugins

## Running

Start the VM with QEMU/KVM:

```bash
./run.sh
```

This launches a VM with:
- KVM acceleration
- 2GB RAM, all CPU cores
- Serial console (nographic)
- Network with SSH port forwarding (host:2222 → guest:22)
- Live CD ISO as bootable media
- Cloud-init seed ISO for configuration
- Persistent storage disk (`var.qcow2`)

### Access

SSH into the running VM:

```bash
ssh -p 2222 root@localhost
```

Default password: `root`

## Use Cases

- **Kubernetes Development:** Test Kubernetes features in isolated VMs
- **Cluster API:** Base image for Cluster API providers
- **CI/CD:** Ephemeral test environments
- **Learning:** Understand Linux boot process and containerization
- **Immutable Infrastructure:** Read-only base with overlay for changes

## Technical Details

### Storage Layout

- `/` - OverlayFS (lower: squashfs from ISO, upper: ext4 on var.qcow2)
- `/mnt` - Mount point for the writable upper layer device
- Persistent data stored on the upper layer survives reboots

### Kernel Configuration

The kernel is built with minimal configuration including:
- No loadable modules support (all drivers built-in)
- Container features: namespaces, cgroups v2, seccomp
- VirtIO drivers for QEMU performance
- Networking: bridge, veth, netfilter, nftables
- Filesystems: ext4, overlay, squashfs, ISO9660

### System Services

Key systemd services configured:
- `systemd-networkd` - Network management (DHCP)
- `systemd-resolved` - DNS resolution
- `systemd-timesyncd` - Time synchronization
- `containerd` - Container runtime
- `kubelet` - Kubernetes node agent
- `cloud-init` - Initial configuration

## Requirements

- Docker (for building)
- QEMU/KVM (for running)
- xorriso or genisoimage (for ISO creation)
- Sufficient disk space (~5GB for build artifacts)

## License

This project is a collection of open-source components. Refer to individual component licenses for details.
