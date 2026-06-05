.PHONY: all

# platform flags maybe unnecessary, but left in for maybe
# arm mac builders???
# CHIP_BUILD_ID is appended to the kernel package version (see linux-build-deb.sh)
# so rebuilds get a unique, upgradable version. Default to this repo's HEAD commit
# time (deterministic + monotonic); the orchestrator may pass its own. Falls back
# to now if not in a git checkout.
CHIP_BUILD_ID ?= $(shell git show -s --format=%ct HEAD 2>/dev/null || date -u +%s)

all:
	docker build --platform linux/amd64 -t chip-linux-amd64 .
	docker run --rm --platform linux/amd64 -e HOST_UID=$$(id -u) -e HOST_GID=$$(id -g) -e CHIP_BUILD_ID=$(CHIP_BUILD_ID) -v $$PWD:/build -w /build chip-linux-amd64 ./linux-build-deb.sh
