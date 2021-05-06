build-base:
	docker build -t dstat-builder ../dstat
	docker build -t benchmark-base ../common

build-image: build-base
	docker build -t quay.io/kinvolk/benchmark-envoy .

push-image: build-image
	docker push quay.io/kinvolk/benchmark-envoy
