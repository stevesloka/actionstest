PROJECT = actionstest
MODULE = github.com/stevesloka/$(PROJECT)
REGISTRY ?= stevesloka
IMAGE := $(REGISTRY)/$(PROJECT)
SRCDIRS := ./cmd

TAG_LATEST ?= false
# Used to supply a local Envoy docker container an IP to connect to that is running
# 'contour serve'. On MacOS this will work, but may not on other OSes. Defining
# LOCALIP as an env var before running 'make local' will solve that.
LOCALIP ?= $(shell ifconfig | grep inet | grep -v '::' | grep -v 127.0.0.1 | head -n1 | awk '{print $$2}')

GIT_REF = $(shell git rev-parse --short=8 --verify HEAD)
VERSION ?= $(GIT_REF)

export GO111MODULE=on

test: install
	go test -mod=readonly $(MODULE)/...

test-race: | test
	go test -race -mod=readonly $(MODULE)/...

vet: | test
	go vet $(MODULE)/...

check: test test-race vet gofmt staticcheck misspell unconvert unparam ineffassign
	@echo Checking rendered files are up to date

install:
	go install -mod=readonly -v -tags "oidc gcp" $(MODULE)/cmd/$(PROJECT)

race:
	go install -mod=readonly -v -race -tags "oidc gcp" $(MODULE)/cmd/$(PROJECT)

download:
	go mod download

container:
	docker build . -t $(IMAGE):$(VERSION)

push: container
	docker push $(IMAGE):$(VERSION)
ifeq ($(TAG_LATEST), true)
	docker tag $(IMAGE):$(VERSION) $(IMAGE):latest
	docker push $(IMAGE):latest
endif

staticcheck:
	go install honnef.co/go/tools/cmd/staticcheck
	staticcheck \
		-checks all,-ST1003 \
		$(MODULE)/{cmd,internal}/...

misspell:
	go install github.com/client9/misspell/cmd/misspell
	misspell \
		-i clas \
		-locale US \
		-error \
		cmd/* internal/* docs/* design/* *.md

unconvert:
	go install github.com/mdempsky/unconvert
	unconvert -v $(MODULE)/{cmd,internal}/...

ineffassign:
	go install github.com/gordonklaus/ineffassign
	find $(SRCDIRS) -name '*.go' | xargs ineffassign

pedantic: check errcheck

unparam:
	go install mvdan.cc/unparam
	unparam -exported $(MODULE)/{cmd,internal}/...

errcheck:
	go install github.com/kisielk/errcheck
	errcheck $(MODULE)/...

render:
	@echo Rendering example deployment files...
	@(cd examples && bash render.sh)

updategenerated:
	@echo Updating CRD generated code...
	@(bash hack/update-generated-crd-code.sh)

gofmt:
	@echo Checking code is gofmted
	@test -z "$(shell gofmt -s -l -d -e $(SRCDIRS) | tee /dev/stderr)"
