default: containerized_build 

export GOPATH=$(CURDIR)/
export GOBIN=$(CURDIR)/.temp/
export GOCACHE=$(CURDIR)/.cache/
export BOJI_VERSION

init: clean
	go get ./src/boji/...
	@find ./src -mindepth 1 -type d -name ".git" | xargs rm -rf

build: init
	go build -o ./.output/boji .

test:
	go test
	go test -bench=.

clean:
	@rm -rf ./.output/

fmt:
	@go fmt .
	@go fmt ./src/boji

dist: build test

	export GOOS=linux; \
	export GOARCH=amd64; \
	go build -o ./.output/boji .

	export GOOS=darwin; \
	export GOARCH=amd64; \
	go build -o ./.output/boji_osx .

	export GOOS=windows; \
	export GOARCH=amd64; \
	go build -o ./.output/boji.exe .

package: dist fpmPackage

fpmPackage: versionTest fpmTest

	fpm \
		--log error \
		-s dir \
		-t deb \
		-v $(BOJI_VERSION) \
		-n boji \
		--after-install=package/install.sh \
		./.output/boji=/usr/local/bin/boji \
		./docs/boji.7=/usr/share/man/man7/boji.7 \
		./autocomplete/boji=/etc/bash_completion.d/boji \
		./package/init.d.sh=/etc/init.d/boji \
		./package/defaults.sh=/etc/default/boji \
		./static/=/var/lib/boji/static/

	@mv ./*.deb ./.output/

dockerPackage: containerized_package dockerTest
	docker build . -t boji:$(BOJI_VERSION)
	docker tag boji:$(BOJI_VERSION) boji:latest

dockerPublish: dockerPackage
	docker tag boji:$(BOJI_VERSION) knetic/boji:$(BOJI_VERSION)
	docker push knetic/boji:$(BOJI_VERSION)

fpmTest:
ifeq ($(shell which fpm), )
	@echo "FPM is not installed, no packages will be made."
	@echo "https://github.com/jordansissel/fpm"
	@exit 1
endif

versionTest:
ifeq ($(BOJI_VERSION), )

	@echo "No 'BOJI_VERSION' was specified."
	@echo "Export a 'BOJI_VERSION' environment variable to perform a package"
	@exit 1
endif

dockerTest:
ifeq ($(shell which docker), )
	@echo "Docker is not installed."
	@exit 1
endif

containerized_build: dockerTest

	docker run \
		--rm \
		-v "$(CURDIR)":"/srv/build":rw \
		-u "$(shell id -u $(whoami)):$(shell id -g $(whoami))" \
		-e BOJI_VERSION=$(BOJI_VERSION) \
		golang:1.14 \
		bash -c \
		"cd /srv/build; make build"
		
containerized_dist: dockerTest

	docker run \
		--rm \
		-v "$(CURDIR)":"/srv/build":rw \
		-u "$(shell id -u $(whoami)):$(shell id -g $(whoami))" \
		-e BOJI_VERSION=$(BOJI_VERSION) \
		golang:1.14 \
		bash -c \
		"cd /srv/build; make dist"

containerized_package: containerized_build

	docker run \
		-v "$(CURDIR)":"/srv/build" \
		-u "$(shell id -u $(whoami)):$(shell id -g $(whoami))" \
		-e BOJI_VERSION=$(BOJI_VERSION) \
		alanfranz/fpm-within-docker:debian-stretch \
		bash -c \
		"cd /srv/build; make fpmPackage"
