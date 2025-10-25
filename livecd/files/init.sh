#!/bin/busybox sh
set -eu
export PATH=/bin:/sbin

die() { echo "ERROR: $*"; exec /bin/sh; }

# Mount base filesystems
/bin/mount -t proc     proc     /proc
/bin/mount -t sysfs    sysfs    /sys
/bin/mount -t devtmpfs devtmpfs /dev

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
    label=$(/bin/blkid -o value -s LABEL "$d" 2>/dev/null || true)
    if [ "$label" = "$iso_label" ]; then
      iso_dev="$d"
      break
    fi
  done
fi

[ -n "$iso_dev" ] || {
  echo "Known optical/block devices and labels:"
  /bin/blkid /dev/sr* /dev/sd? /dev/vd? 2>/dev/null || true
  die "$iso_label ISO not found"
}

# Mount ISO and verify squashfs
/bin/mount -o ro "$iso_dev" /mnt || die "Failed to mount $iso_dev"
[ -f /mnt/live/filesystem.squashfs ] || die "filesystem.squashfs not found"

# Mount squashfs (optimize for small images)
sqfs_size=$(/bin/stat -c %s /mnt/live/filesystem.squashfs 2>/dev/null || echo 0)
if [ "$sqfs_size" -le 52428800 ]; then
  /bin/umount /mnt 2>/dev/null || true
  /bin/mount -t squashfs -o loop,ro "$iso_dev" /lower 2>/dev/null || \
    /bin/mount -t squashfs -o loop,ro /mnt/live/filesystem.squashfs /lower || die "Failed to mount squashfs"
else
  /bin/mount -t squashfs -o loop,ro /mnt/live/filesystem.squashfs /lower || die "Failed to mount squashfs"
fi

# 2) select/prepare device FOR overlay (DO NOT TOUCH)
pick_dev() {
  [ -e /dev/disk/by-label/VAR ] && { readlink -f /dev/disk/by-label/VAR; return; }
  for x in $(/bin/lsblk -ndo PATH,TYPE | awk '$2=="part"{print $1}'); do /bin/findmnt -S "$x" >/dev/null 2>&1 || echo "$x"; done
  for x in $(/bin/lsblk -ndpo NAME,TYPE | awk '$2=="disk"{print $1}'); do /bin/findmnt -S "$x" >/dev/null 2>&1 || echo "$x"; done
}
vardev=""
for x in $(pick_dev); do
  case "$x" in /dev/sr*|/dev/loop*) continue;; esac
  ro=$(/bin/lsblk -ndo RO "$x" 2>/dev/null || echo 0); [ "$ro" = "1" ] && continue
  fstype=$(/bin/blkid -o value -s TYPE "$x" 2>/dev/null || true)
  if [ -z "$fstype" ]; then /bin/mkfs.ext4 -F -L VAR "$x"; vardev="$x"; break; fi
  if [ "$fstype" = "ext4" ]; then /bin/tune2fs -L VAR "$x" >/dev/null 2>&1 || true; vardev="$x"; break; fi
done
[ -n "$vardev" ] || { echo "No RW device for overlay"; exec /bin/sh; }
# ---- can be modified below ----

# 3) mount RW device and prepare directories
/bin/mkdir -p /rw
/bin/mount -t ext4 -o rw "$vardev" /rw || { echo "mount $vardev -> /rw failed"; exec /bin/sh; }
/bin/mkdir -p \
  /rw/overlay/upper/root /rw/overlay/work/root \
  /rw/overlay/upper/etc  /rw/overlay/work/etc \
  /rw/var

# 4) root as overlayfs (fixes EROFS in namespaces)
/bin/mkdir -p /newroot
/bin/mount -t overlay overlay \
  -o lowerdir=/lower,upperdir=/rw/overlay/upper/root,workdir=/rw/overlay/work/root \
  /newroot || { echo "overlay root failed"; exec /bin/sh; }

# 5) /var directly from real device
/bin/mkdir -p /newroot/var
/bin/mount --bind /rw/var /newroot/var || { echo "bind /rw/var -> /newroot/var failed"; exec /bin/sh; }

# 6) /etc as separate overlay on top of lower/etc, upper/work on the same disk
/bin/mkdir -p /newroot/etc
/bin/mount -t overlay overlay \
  -o lowerdir=/lower/etc,upperdir=/rw/overlay/upper/etc,workdir=/rw/overlay/work/etc \
  /newroot/etc || { echo "overlay /etc failed"; exec /bin/sh; }

# 7) system mount points and switch_root
/bin/mkdir -p /newroot/proc /newroot/sys /newroot/dev /newroot/run /newroot/mnt /newroot/rw
mount --move /proc /newroot/proc
mount --move /sys  /newroot/sys
mount --move /dev  /newroot/dev
# /run как tmpfs после старта systemd, но текущий /run переносим:
/bin/mount -t tmpfs tmpfs /run || true
mount --move /run  /newroot/run 2>/dev/null || true
mount --move /mnt  /newroot/mnt
mount --move /rw   /newroot/rw

exec /bin/switch_root /newroot /sbin/init
