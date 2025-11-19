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



incus config set node cloud-init.user-data - <<EOF
#cloud-config
hostname: test-node
ssh_pwauth: false

users:
  - name: ubuntu
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-ed25519 AAAA......

package_update: false
package_upgrade: false

runcmd:
  - [ sh, -c, "echo 'cloud-init executed' > /root/ci.txt" ]
EOF

incus config set node cloud-init.vendor-data - <<EOF
#cloud-config
runcmd:
  - echo "Vendor OK" > /root/vendor.txt
EOF


incus config set node cloud-init.network-config - <<EOF
version: 2
ethernets:
  eth0:
    dhcp4: true
EOF

echo "===> Adding cloud-init device"

incus config device add node cloud-init disk source=cloud-init:config


incus config device add node eth0 nic network=incusbr0

incus start node
sleep 1
incus console node
