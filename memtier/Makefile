ARCH?=amd64

build-image:
	docker build -t quay.io/kinvolk/benchmark-memtier:v0.2-$(ARCH) .

push-image: build-image
	docker push quay.io/kinvolk/benchmark-memtier:v0.2-$(ARCH)

build-manifest:
	docker manifest create quay.io/kinvolk/benchmark-memtier:v0.2 \
	    --amend quay.io/kinvolk/benchmark-memtier:v0.2-amd64 \
	    --amend quay.io/kinvolk/benchmark-memtier:v0.2-arm64
	docker manifest annotate quay.io/kinvolk/benchmark-memtier:v0.2 \
	    quay.io/kinvolk/benchmark-memtier:v0.2-amd64 --arch=amd64 --os=linux
	docker manifest annotate quay.io/kinvolk/benchmark-memtier:v0.2 \
	    quay.io/kinvolk/benchmark-memtier:v0.2-arm64 --arch=arm64 --os=linux
	docker manifest push quay.io/kinvolk/benchmark-memtier:v0.2
