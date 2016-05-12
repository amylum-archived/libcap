PACKAGE = libcap
ORG = amylum

DEP_DIR = /tmp/dep-dir

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
CFLAGS = -I$(DEP_DIR)/usr/include

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/libcap-korg-//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

PAM_VERSION = 1.2.1-10
PAM_URL = https://github.com/amylum/pam/releases/download/$(PAM_VERSION)/pam.tar.gz
PAM_TAR = /tmp/pam.tar.gz
PAM_DIR = /tmp/pam
PAM_PATH = -I$(PAM_DIR)/usr/include -L$(PAM_DIR)/usr/lib

.PHONY : default submodule deps manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(DEP_DIR)
	mkdir -p $(DEP_DIR)/usr/include
	cp -R /usr/include/{linux,asm,asm-generic} $(DEP_DIR)/usr/include/
	rm -rf $(PAM_DIR) $(PAM_TAR)
	mkdir $(PAM_DIR)
	curl -sLo $(PAM_TAR) $(PAM_URL)
	tar -x -C $(PAM_DIR) -f $(PAM_TAR)

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	sed -i "/SBINDIR/s#sbin#bin#" $(BUILD_DIR)/Make.Rules
	cd $(BUILD_DIR) && make CFLAGS='$(CFLAGS) $(PAM_PATH)' CC=musl-gcc prefix=/usr lib=/lib DESTDIR=$(RELEASE_DIR) install
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/License $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

