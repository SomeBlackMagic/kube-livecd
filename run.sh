#!/bin/bash
if [ ! -f var.qcow2 ]; then
    qemu-img create -f qcow2 var.qcow2 2G
fi

#qemu-system-x86_64 \
#  -enable-kvm -cpu host -smp 2 -m 1024 -nographic \
#  -kernel ./kernel/out/vmlinuz \
#  -drive if=virtio,format=qcow2,file=./rootfs/out/rootfs.qcow2 \
#  -append "root=/dev/vda rw rootwait console=ttyS0 init=/sbin/init systemd.unified_cgroup_hierarchy=1"

#qemu-system-x86_64 \
#  -enable-kvm -cpu host -smp 2 -m 2048 -nographic \
#  -kernel ./kernel/out/vmlinuz \
#  -drive if=virtio,format=qcow2,file=./rootfs-k8s/out/rootfs-k8s.qcow2 \
#  -append "root=/dev/vda rw rootwait console=ttyS0 init=/sbin/init systemd.unified_cgroup_hierarchy=1"
#

#qemu-system-x86_64 -enable-kvm -cpu host -m 2048 -nographic \
#  -kernel ./kernel/out/vmlinuz -initrd ./livecd/out/initrd.img \
#  -append "console=ttyS0 loglevel=7 rdinit=/init"


#qemu-system-x86_64 -enable-kvm -cpu host -m 2048 -nographic \
#  -kernel ./kernel/out/vmlinuz \
#  -initrd ./initrd.img \
#  -append "console=ttyS0 loglevel=7 ignore_loglevel rdinit=/init"
#  -cdrom ./node.iso

qemu-system-x86_64 \
  -enable-kvm -cpu host -m 2048 -smp $(nproc) -nographic \
  -drive file=livecd/out/node.iso,media=cdrom,if=none,id=cdrom \
  -drive file="cloudinit/cloud-init-seed.iso",if=virtio,format=raw,readonly=on,media=cdrom \
  -device virtio-scsi-pci -device scsi-cd,drive=cdrom \
  -drive if=virtio,format=qcow2,file=var.qcow2 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0
