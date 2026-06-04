#!/bin/bash -ex

# this script builds a -chip flavor of the current repo's
# debian kernel. it's meant to be called via the Dockerfile
# in this directory, for which there's a Makefile to build
# and run the container

HERE=$PWD

# start clean so re-runs don't trip over a previous build/ (root-owned,
# already-extracted source, etc.)
rm -rf build
mkdir build
cd build
apt-get source linux
cd linux-*

# NAND device-tree patch.
PATCH=bugfix/arm/sun5i-r8-chip-enable-nand.patch
mkdir -p "debian/patches/$(dirname "${PATCH}")"
cp "${HERE}/sun5i-r8-chip.dts.nand.patch" "debian/patches/${PATCH}"
echo "${PATCH}" >> debian/patches/series

# ensure nand configs are in, this might be overkill on top of armmp
cp "${HERE}/nand.cfg" debian/config/armhf/config.chip

# grab from this file in apt-get source linux, and replace flavors (lpae armmp rt)
# with just this one
cat > debian/config/armhf/defines.toml <<'EOF'
[[flavour]]
name = "chip"
[flavour.defs]
is_default = true
[flavour.description]
hardware = 'NextThing C.H.I.P. (Allwinner R8 / sun5i)'
hardware_long = 'Single-board computer based on the Allwinner R8 (sun5i) SoC, with on-board NAND used in SLC mode.'

[[featureset]]
name = 'none'

[build]
enable_vdso = true
kernel_file = 'arch/arm/boot/zImage'
kernel_stem = 'vmlinuz'
EOF

# regenerate debian/control to include the new flavor
debian/rules debian/control-real || true

# armhf, binary, unsigned, cross compile
DEB_BUILD_OPTIONS="parallel=$(nproc)" \
    dpkg-buildpackage -aarmhf -B -uc -us -Pcross

# hand the build outputs (the .debs live in build/) back to the invoking
# host user (HOST_UID/GID from the Makefile), so build/ isn't root-owned.
[ -n "${HOST_UID:-}" ] && chown -R "$HOST_UID:$HOST_GID" "$HERE/build" || true
