incus stop -f node || true
incus rm -f node || true

incus init --empty node --vm
incus config device add node root disk path=/ pool=default
incus config set node limits.cpu=$(nproc)
incus config set node limits.memory=2GiB
incus config set node security.secureboot=false

incus config device add node install-iso disk \
  source=$PWD/livecd/out/node.iso \
  boot.priority=10 \
  readonly=true


#cloud-init seed ISO
mkdir -p incus-cloudinit

cat > incus-cloudinit/user-data <<EOF

runcmd:
  - mkdir -p /etc/incus
  - mkdir -p /var/lib/incus
  - systemctl daemon-reload
  - systemctl enable incus-agent.service
  - systemctl restart incus-agent.service
EOF

cat > incus-cloudinit/meta-data <<EOF
instance-id: iid-node-001
local-hostname: node
EOF

cat > incus-cloudinit/network-config <<EOF
version: 2
ethernets:
  eth0:
    dhcp4: true
EOF


genisoimage -output seed.iso -volid cidata -joliet -rock incus-cloudinit/
rm -rvf incus-cloudinit/


incus config device add node seed disk source=$PWD/seed.iso readonly=true

incus config device add node eth0 nic network=incusbr0

incus start node
sleep 1
incus console node
