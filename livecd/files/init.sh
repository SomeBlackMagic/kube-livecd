#!/bin/busybox sh
set -eu
export PATH=/bin:/sbin

/bin/mount -t proc     proc     /proc
/bin/mount -t sysfs    sysfs    /sys
/bin/mount -t devtmpfs devtmpfs /dev

# 1) lower: найти ISO и смонтировать squashfs
for d in /dev/sr0 /dev/cdrom /dev/sda /dev/vda; do
  /bin/mount -o ro "$d" /mnt 2>/dev/null && break
done
[ -f /mnt/live/filesystem.squashfs ] || { echo "filesystem.squashfs not found"; exec /bin/sh; }
/bin/mount -t squashfs -o loop,ro /mnt/live/filesystem.squashfs /lower || exec /bin/sh

# 2) выбор/подготовка устройства ДЛЯ overlay (НЕ ТРОГАТЬ)
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
# ---- дальше можно изменять ----

# 3) смонтировать RW-устройство и подготовить каталоги
/bin/mkdir -p /rw
/bin/mount -t ext4 -o rw "$vardev" /rw || { echo "mount $vardev -> /rw failed"; exec /bin/sh; }
/bin/mkdir -p \
  /rw/overlay/upper/root /rw/overlay/work/root \
  /rw/overlay/upper/etc  /rw/overlay/work/etc \
  /rw/var

# 4) root как overlayfs (исправляет EROFS в namespaces)
/bin/mkdir -p /newroot
/bin/mount -t overlay overlay \
  -o lowerdir=/lower,upperdir=/rw/overlay/upper/root,workdir=/rw/overlay/work/root \
  /newroot || { echo "overlay root failed"; exec /bin/sh; }

# 5) /var напрямую с реального устройства
/bin/mkdir -p /newroot/var
/bin/mount --bind /rw/var /newroot/var || { echo "bind /rw/var -> /newroot/var failed"; exec /bin/sh; }

# 6) /etc отдельным overlay поверх lower/etc, upper/work на том же диске
/bin/mkdir -p /newroot/etc
/bin/mount -t overlay overlay \
  -o lowerdir=/lower/etc,upperdir=/rw/overlay/upper/etc,workdir=/rw/overlay/work/etc \
  /newroot/etc || { echo "overlay /etc failed"; exec /bin/sh; }

# 7) служебные точки и switch_root
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
