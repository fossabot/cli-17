VERSION := $(shell cat VERSION)

PKG:= kcl-lang.io/kcl
LDFLAGS := -X $(PKG)/cmd.Version=$(VERSION)

GO ?= go

.PHONY: run
run:
	go run kcl.go run ./examples/kubernetes.k

.PHONY: format
format:
	test -z "$$(find . -type f -o -name '*.go' -exec gofmt -d {} + | tee /dev/stderr)" || \
	test -z "$$(find . -type f -o -name '*.go' -exec gofmt -w {} + | tee /dev/stderr)"

.PHONY: lint
lint:
	scripts/update-gofmt.sh
	scripts/verify-gofmt.sh
	scripts/verify-govet.sh

.PHONY: build
build: lint
	mkdir -p bin/
	go build -v -o bin/kcl -ldflags="$(LDFLAGS)"

.PHONY: test
test:
	go test -v ./...

.PHONY: cover
cover: ## Generates coverage report
	go test -gcflags=all=-l -timeout=20m `go list $(SOURCE_PATHS)` -coverprofile $(COVER_FILE) ${TEST_FLAGS} -v

.PHONY: fmt
fmt:
	go fmt ./...

.PHONY: bootstrap
bootstrap:
	go mod download
	command -v golint || GO111MODULE=off go get -u golang.org/x/lint/golint

.PHONY: docker-run-release
docker-run-release: export pkg=/go/src/github.com/kcl-lang/cli
docker-run-release:
	git checkout main
	git push
	docker run -it --rm -e GITHUB_TOKEN -v $(shell pwd):$(pkg) -w $(pkg) golang:1.19.1 make bootstrap release

.PHONY: dist
dist: export COPYFILE_DISABLE=1 #teach OSX tar to not put ._* files in tar archive
dist: export CGO_ENABLED=0
dist:
	rm -rf build/kcl/* release/*
	mkdir -p build/kcl/bin release/
	cp -f README.md LICENSE build/kcl
	GOOS=linux GOARCH=amd64 $(GO) build -o build/kcl/bin/kcl -trimpath -ldflags="$(LDFLAGS)"
	tar -C build/ -zcvf $(CURDIR)/release/kcl-linux-amd64.tgz kcl/
	GOOS=linux GOARCH=arm64 $(GO) build -o build/kcl/bin/kcl -trimpath -ldflags="$(LDFLAGS)"
	tar -C build/ -zcvf $(CURDIR)/release/kcl-linux-arm64.tgz kcl/
	GOOS=darwin GOARCH=amd64 $(GO) build -o build/kcl/bin/kcl -trimpath -ldflags="$(LDFLAGS)"
	tar -C build/ -zcvf $(CURDIR)/release/kcl-macos-amd64.tgz kcl/
	GOOS=darwin GOARCH=arm64 $(GO) build -o build/kcl/bin/kcl -trimpath -ldflags="$(LDFLAGS)"
	tar -C build/ -zcvf $(CURDIR)/release/kcl-macos-arm64.tgz kcl/
	rm build/kcl/bin/kcl
	GOOS=windows GOARCH=amd64 $(GO) build -o build/kcl/bin/kcl.exe -trimpath -ldflags="$(LDFLAGS)"
	tar -C build/ -zcvf $(CURDIR)/release/kcl-windows-amd64.tgz kcl/

.PHONY: release
release: lint dist
	scripts/release.sh v$(VERSION)
