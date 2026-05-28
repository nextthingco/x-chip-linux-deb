# x-chip-linux-deb

This repository is for building the linux kernel for Debian. It attempts to adhere to Debian convention as close as possible so as to introduce little friction using the distro while using a different flavor of kernel.

## building

Use `make` to build a docker image, and to run the build.

## details

We pull the regular Debian kernel source, select the defconfig, apply 2 patches for the nand, and build as a new `-chip` kernel flavor.