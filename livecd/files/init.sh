#!/bin/busybox sh
set -eu
export PATH=/bin:/sbin

die() { echo "ERROR: $*"; exec sh; }

# Mount base filesystems
mount -t proc     proc     /proc
mount -t sysfs    sysfs    /sys
mount -t devtmpfs devtmpfs /dev

# 1) Find and verify K8S_NODE ISO
iso_label="K8S_NODE"
iso_dev=""

# Prefer by-label symlink if present
if [ -e "/dev/disk/by-label/$iso_label" ]; then
  iso_dev="$(readlink -f "/dev/disk/by-label/$iso_label" 2>/dev/null || true)"
fi

# Fallback: scan common devices (include all sr*)
if [ -z "$iso_dev" ]; then
  for d in /dev/sr* /dev/cdrom /dev/sd? /dev/vd?; do
    [ -b "$d" ] || continue
    label=$(blkid -o value -s LABEL "$d" 2>/dev/null || true)
    if [ "$label" = "$iso_label" ]; then
      iso_dev="$d"
      break
    fi
  done
fi

[ -n "$iso_dev" ] || {
  echo "Known optical/block devices and labels:"
  blkid /dev/sr* /dev/sd? /dev/vd? 2>/dev/null || true
  die "$iso_label ISO not found"
}

# Mount ISO and verify squashfs
mount -o ro "$iso_dev" /mnt || die "Failed to mount $iso_dev"
[ -f /mnt/live/filesystem.squashfs ] || die "filesystem.squashfs not found"

# Mount squashfs (optimize for small images)
sqfs_size=$(stat -c %s /mnt/live/filesystem.squashfs 2>/dev/null || echo 0)
if [ "$sqfs_size" -le 52428800 ]; then
  umount /mnt 2>/dev/null || true
  mount -t squashfs -o loop,ro "$iso_dev" /lower 2>/dev/null || \
    mount -t squashfs -o loop,ro /mnt/live/filesystem.squashfs /lower || die "Failed to mount squashfs"
else
  mount -t squashfs -o loop,ro /mnt/live/filesystem.squashfs /lower || die "Failed to mount squashfs"
fi

# 2) select/prepare device FOR overlay (DO NOT TOUCH)
pick_dev() {
  [ -e /dev/disk/by-label/VAR ] && { readlink -f /dev/disk/by-label/VAR; return; }
  for x in $(lsblk -ndo PATH,TYPE | awk '$2=="part"{print $1}'); do findmnt -S "$x" >/dev/null 2>&1 || echo "$x"; done
  for x in $(lsblk -ndpo NAME,TYPE | awk '$2=="disk"{print $1}'); do findmnt -S "$x" >/dev/null 2>&1 || echo "$x"; done
}

vardev=""
for x in $(pick_dev); do
  case "$x" in /dev/sr*|/dev/loop*) continue;; esac
  ro=$(lsblk -ndo RO "$x" 2>/dev/null || echo 0); [ "$ro" = "1" ] && continue
  fstype=$(blkid -o value -s TYPE "$x" 2>/dev/null || true)

  if [ -z "$fstype" ]; then
    mkfs.ext4 -F -L VAR "$x"
    vardev="$x"
    break
  fi

  if [ "$fstype" = "ext4" ]; then
    tune2fs -L VAR "$x" >/dev/null 2>&1 || true
    vardev="$x"
    break
  fi
done

[ -n "$vardev" ] || { echo "No RW device for overlay"; exec sh; }


mkdir -p /mnt-rw
mount -t ext4 -o rw "$vardev" /mnt-rw || { echo "mount $vardev -> /mnt-rw failed"; exec sh; }

# upper/work dirs for overlays
mkdir -p \
  /mnt-rw/upper/etc  /mnt-rw/work/etc \
  /mnt-rw/upper/home /mnt-rw/work/home \
  /mnt-rw/upper/root /mnt-rw/work/root \
  /mnt-rw/var


# 4) root is pure squashfs — NO overlay for /
mkdir -p /newroot
mount --bind /lower /newroot || { echo "bind lower failed"; exec sh; }

# 5) /var directly from real device (bind)
mkdir -p /newroot/var
mount --bind /mnt-rw/var /newroot/var || { echo "bind /mnt-rw/var failed"; exec sh; }

# 6) /etc overlay
mkdir -p /newroot/etc
mount -t overlay overlay \
  -o lowerdir=/lower/etc,upperdir=/mnt-rw/upper/etc,workdir=/mnt-rw/work/etc \
  /newroot/etc || { echo "overlay /etc failed"; exec sh; }

# 7) /home overlay
mkdir -p /newroot/home
mount -t overlay overlay \
  -o lowerdir=/lower/home,upperdir=/mnt-rw/upper/home,workdir=/mnt-rw/work/home \
  /newroot/home || { echo "overlay /home failed"; exec sh; }

# 8) /root overlay
mkdir -p /newroot/root
mount -t overlay overlay \
  -o lowerdir=/lower/root,upperdir=/mnt-rw/upper/root,workdir=/mnt-rw/work/root \
  /newroot/root || { echo "overlay /home failed"; exec sh; }


# system mount points and switch_root
mkdir -p /newroot/proc /newroot/sys /newroot/dev /newroot/run /newroot/mnt /newroot/tmp

mount -t devtmpfs devtmpfs /newroot/dev   # devices
mount -t tmpfs    tmpfs    /newroot/run   # /run
mount -t tmpfs    tmpfs    /newroot/tmp   # /tmp

mkdir -p /newroot/proc /newroot/sys /newroot/mnt
mount --move /proc /newroot/proc
mount --move /sys  /newroot/sys
mount --move /mnt  /newroot/mnt


# NOTE: /mnt-rw NOT moved → disappears after switch_root

exec switch_root /newroot /sbin/init
