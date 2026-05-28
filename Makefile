.PHONY: all

# platform flags maybe unnecessary, but left in for maybe
# arm mac builders???
all:
	docker build --platform linux/amd64 -t chip-linux-amd64 .
	docker run --rm --platform linux/amd64 -v $$PWD:/build -w /build chip-linux-amd64 ./linux-build-deb.sh
