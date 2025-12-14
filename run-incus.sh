#incus init --empty k8s --vm
#incus config device add k8s root disk path=/ pool=vg_md1 size=150GB
#incus config set k8s limits.cpu=8
#incus config set k8s limits.memory=64GiB
#incus config set k8s security.secureboot=false
#incus config device add k8s install-iso disk source=/root/node-k8s-1.33.7.iso boot.priority=10 readonly=true
#incus config device add k8s eth0 nic nictype=bridged parent=incusbr0


incus stop k8s || true
incus rm k8s || true


incus init --empty k8s --vm \
  --profile default \
  --config limits.cpu=$(nproc) \
  --config limits.memory=2GiB \
  --config security.secureboot=false


incus config device add k8s install-iso disk \
  source=$PWD/livecd/out/node.iso \
  boot.priority=10 \
  readonly=true


incus config set k8s cloud-init.user-data - <<EOF
#cloud-config
hostname: k8s
ssh_pwauth: false

write_files:
  - path: /etc/kubernetes/kubeadm.yaml
    content: |
      ---
      apiVersion: kubeadm.k8s.io/v1beta4
      kind: InitConfiguration

      patches:
        directory: /etc/kubeadm/patches

      nodeRegistration:
        criSocket: unix:///run/containerd/containerd.sock
        kubeletExtraArgs:
          - name: resolv-conf
            value: /run/systemd/resolve/resolv.conf

      ---
      apiVersion: kubeadm.k8s.io/v1beta4
      kind: ClusterConfiguration

      kubernetesVersion: v1.32.10
      clusterName: immutable-cluster

      networking:
        podSubnet: 10.244.0.0/16
        serviceSubnet: 10.96.0.0/12
        dnsDomain: cluster.local

      apiServer:
        extraArgs:
          - name: authorization-mode
            value: Node,RBAC
          - name: enable-admission-plugins
            value: NodeRestriction
        certSANs:
          - 127.0.0.1

      controllerManager:
        extraArgs:
          - name: bind-address
            value: 0.0.0.0

      scheduler:
        extraArgs:
          - name: bind-address
            value: 0.0.0.0

      ---
      apiVersion: kubeproxy.config.k8s.io/v1alpha1
      kind: KubeProxyConfiguration

      mode: iptables

      ---
      apiVersion: kubelet.config.k8s.io/v1beta1
      kind: KubeletConfiguration

      volumePluginDir: ""
      staticPodPath: /etc/kubernetes/manifests

      clusterDomain: cluster.local
      clusterDNS:
        - 10.96.0.10

      cgroupDriver: systemd
      failSwapOn: true
      rotateCertificates: true

      podLogsDir: /var/log/pods
      containerLogMaxSize: "10Mi"
      containerLogMaxFiles: 3



package_update: false
package_upgrade: false

runcmd:
#  - [ sh, -c, "" ]
  - kubeadm config images pull
  - kubeadm init --config /etc/kubernetes/kubeadm.yaml
  - mkdir -p /root/.kube
  - cp -i /etc/kubernetes/admin.conf /root/.kube/config
EOF

incus config set k8s cloud-init.vendor-data - <<EOF
#cloud-config
runcmd:
  - echo "Vendor OK" > /root/vendor.txt
EOF


incus config set k8s cloud-init.network-config - <<EOF
version: 2
ethernets:
  eth0:
    dhcp4: true
EOF

incus config device add k8s cloud-init disk source=cloud-init:config

incus config device add k8s eth0 nic network=incusbr0

incus start k8s
sleep 1
incus console k8s


#mkdir -p $HOME/.kube
#cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#chown $(id -u):$(id -g) $HOME/.kube/config
#kubectl -n kube-system describe pod kube-controller-manager-k8s
#kubectl -n kube-system describe pod kube-proxy-djb2p
#kubectl -n kube-system describe pod coredns-668d6bf9bc-9r6sz
#kubectl -n kube-system logs -f coredns-668d6bf9bc-9r6sz

#kubeadm init phase control-plane controller-manager
#kubectl -n kube-system get pods -o wide
#kubectl -n kube-system get pods \
#  -l tier=control-plane \
#  -o wide
#kubectl get nodes -o wide
#kubectl -n kube-system get pods -o wide
#kubectl run dns-test \
#  --image=busybox:1.36 \
#  --restart=Never \
#  --rm -it \
#  -- nslookup kubernetes.default
#kubectl get svc kubernetes
#
#kubectl run svc-test \
#  --image=busybox:1.36 \
#  --restart=Never \
#  --rm -it \
#  -- wget -qO- https://kubernetes.default
#
#kubectl run net-test \
#  --image=busybox:1.36 \
#  --restart=Never \
#  --rm -it \
#  -- ip addr
#
#
#kubectl get --raw=/healthz
#kubectl get --raw=/readyz


kubectl -n kube-system patch daemonset kube-proxy --type=strategic -p '
spec:
  template:
    spec:
      volumes:
      - name: lib-modules
        hostPath:
          path: /lib/modules
          type: Directory
'


# shellcheck disable=SC2016
kubectl -n kube-system patch daemonset kube-proxy --type=strategic -p '
spec:
  template:
    spec:
      containers:
      - name: kube-proxy
        volumeMounts:
        - mountPath: /lib/modules
          $patch: delete
      volumes:
      - name: lib-modules
        $patch: delete
'
