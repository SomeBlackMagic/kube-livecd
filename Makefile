K8S_VERSION ?= v1.32.1

build: build-kernel build-rootfs build-k8s

build-kernel:
	docker build -f kernel/vanilla.Dockerfile \
		--build-arg LINUX_TARBALL_URL=https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.17.4.tar.xz \
		-t kernel:vanilla .
	cid=$$(docker create kernel:vanilla) && \
	docker cp "$$cid":/out ./kernel && \
	docker rm "$$cid"

build-rootfs:
	docker build -f rootfs/rootfs.Dockerfile -t rootfs:base .
	cid=$$(docker create rootfs:base) && \
	docker cp "$$cid":/out ./rootfs/  && \
	docker rm "$$cid"

build-k8s:
	docker build \
		--build-arg KUBELET_URL=https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubelet \
		--build-arg KUBEADM_URL=https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubeadm \
		--build-arg KUBECTL_URL=https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl \
		--build-arg CONTAINERD_TGZ_URL=https://github.com/containerd/containerd/releases/download/v2.1.4/containerd-2.1.4-linux-amd64.tar.gz \
		--build-arg RUNC_URL=https://github.com/opencontainers/runc/releases/download/v1.3.2/runc.amd64 \
		--build-arg CRICTL_TGZ_URL=https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.34.0/crictl-v1.34.0-linux-amd64.tar.gz \
		--build-arg NERDCTL_TGZ_URL=https://github.com/containerd/nerdctl/releases/download/v2.1.6/nerdctl-2.1.6-linux-amd64.tar.gz \
		--build-arg CNI_PLUGINS_TGZ_URL=https://github.com/containernetworking/plugins/releases/download/v1.8.0/cni-plugins-linux-amd64-v1.8.0.tgz \
		--file rootfs-k8s/rootfs-k8s.Dockerfile \
		--tag rootfs:k8s .
	cid=$$(docker create rootfs:k8s) && \
	docker cp "$$cid":/out/ ./rootfs-k8s/ && \
	docker rm "$$cid"

	docker build -f livecd/livecd.Dockerfile --tag livecd:base .
	cid=$$(docker create livecd:base) && \
	docker cp "$$cid":/out/ ./livecd/ && \
	docker rm "$$cid"
