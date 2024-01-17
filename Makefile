IMG := docker.io/strivewrt/embedded-postgres-binaries
DEPS :=  \
	CONF_VERSION=HEAD \
	GDAL_VERSION=2.4.1 \
    GEOS_VERSION=3.12.1 \
    PATCHELF_VERSION=0.9 \
    POSTGIS_VERSION=3.3.4 \
    PROJ_DATUMGRID_VERSION=1.8 \
    PROJ_VERSION=6.1.0

.PHONY: build
build: debian alpine

.PHONY: publish
publish: latest
	docker push $(IMG):latest
	cd static && \
		git init && \
		git checkout -b gh-pages && \
		git remote add origin $(shell git remote -v | grep push | awk '{print $$2}') && \
		git add -A && \
		git commit -m $(@) && \
		git push -f origin HEAD \
		&& rm -rf static/.git

static/index.html: build
	$(DEPS) USER=$(shell id -u):$(shell id -g) \
		docker compose -f static.yml up --build --force-recreate --abort-on-container-exit --exit-code-from crawler
	docker compose -f test.yml down --remove-orphans --volumes

.PHONY: test
test: test/debian test/alpine

.PHONY: test/debian
test/debian: docker-compose-test/debian

.PHONY: test/alpine
test/alpine: BASE_IMG := -alpine
test/alpine: docker-compose-test/alpine

IMG_CACHE := .cache/$(shell printf $(IMG):latest | sha256sum | cut -d' ' -f1).img
$(IMG_CACHE): latest
	mkdir -p .cache
	docker save $(IMG):latest > $(@)

.PHONY: docker-compose-test/%
docker-compose-test/%: $(IMG_CACHE)
	$(DEPS) \
	USER_ID=$(shell id -u) \
	GROUP_ID=$(shell id -g) \
	BASE_IMG=golang:1.21$(BASE_IMG) \
	IMG_CACHE=$(shell basename $(IMG_CACHE)) \
		docker compose -f test.yml up --build --force-recreate --abort-on-container-exit --exit-code-from test
	docker compose -f test.yml down --remove-orphans --volumes

# postgres <= v11 is EOL by POSTGIS
# https://trac.osgeo.org/postgis/wiki/UsersWikiPostgreSQLPostGIS
versions: Makefile go.mod
#	generate versions explicitly supported by fergusstrange/embedded-postgres
	curl -s $$(\
		grep github.com/fergusstrange/embedded-postgres go.mod | \
		awk '{printf "https://raw.githubusercontent.com/fergusstrange/embedded-postgres/%s/config.go", $$2}') | \
		grep -F ' = PostgresVersion(' \
		| cut -d'"' -f2 \
		| grep $(shell seq 12 16 | xargs -n 1 printf '-e ^%s ') \
		> $(@)
#	this will generate _all_ versions >= 12
#	curl -s https://www.postgresql.org/docs/release/ | \
#		grep -F '<a href="/docs/release/' | \
#		awk -F/ '{print $$(NF-1)}' | \
#		grep $$(seq 12 16 | xargs -n 1 printf '-e ^%s ') \
#		> $(@)

define pull_or_build
	docker pull $(1) || (docker build -t $(1) $(foreach v,$(DEPS),--build-arg $(v)) $(2) && docker push $(1))
endef

img_of = $(IMG):$(strip $(1))-$(strip $(2))-$(shell find $(1) -type f | sort | xargs cat | md5sum | cut -d' ' -f1)

DEBIAN_BASE := $(call img_of, debian, base)
ALPINE_BASE := $(call img_of, alpine, base)

.PHONY: debian
debian: $(foreach v,$(shell cat versions),debian/jar/$(v))

.PHONY: debian/base
debian/base:
	$(call pull_or_build, $(DEBIAN_BASE), -f debian/base.Dockerfile debian)

.PHONY: debian/postgres/%
debian/postgres/%: debian/base
	$(call pull_or_build, \
		$(call img_of, debian, $(@F)), \
		--build-arg FROM=$(DEBIAN_BASE) --build-arg PG_VERSION=$(@F) -f debian/pg.Dockerfile debian)

.PHONY: debian/jar/%
debian/jar/%: debian/postgres/%
	$(eval OUT := $(CURDIR)/static/io/zonky/test/postgres/embedded-postgres-binaries-linux-amd64/$(@F))
	mkdir -p $(OUT)
	docker run --rm -u $(shell id -u):$(shell id -g) -v $(OUT):/out $(call img_of, debian, $(@F))

.PHONY: alpine
alpine: $(foreach v,$(shell cat versions),alpine/jar/$(v))

.PHONY: alpine/base
alpine/base:
	$(call pull_or_build, $(ALPINE_BASE), -f alpine/base.Dockerfile alpine)

.PHONY: alpine/postgres/%
alpine/postgres/%: alpine/base
	$(call pull_or_build, \
		$(call img_of, alpine, $(@F)), \
		--build-arg FROM=$(ALPINE_BASE) --build-arg PG_VERSION=$(@F) -f alpine/pg.Dockerfile alpine)

.PHONY: alpine/jar/%
alpine/jar/%: alpine/postgres/%
	$(eval OUT := $(CURDIR)/static/io/zonky/test/postgres/embedded-postgres-binaries-linux-amd64-alpine/$(@F))
	mkdir -p $(OUT)
	docker run --rm -u $(shell id -u):$(shell id -g) -v $(OUT):/out $(call img_of, alpine, $(@F))

define \n


endef

.PHONY: Dockerfile
Dockerfile: static/index.html
	echo FROM scratch > $(@)
	for f in $$(find static -type f | sort -nr); \
 	do \
 	  printf 'COPY %s %s\n' $$f $$(echo $$f | sed 's!^static!!') >> $(@); \
 	done

.PHONY: latest
latest: Dockerfile
	docker build -t $(IMG):latest .