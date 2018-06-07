IMAGE=gcr.io/smooth-calling-205216/mounter
VERSION=v5

build:
	docker build -t $(IMAGE):$(VERSION) .

push:
	docker push $(IMAGE):$(VERSION)

release: build push
