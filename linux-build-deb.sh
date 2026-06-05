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

# Give every build a unique, monotonically-increasing version. The Debian source
# version (e.g. 6.12.86-1) is identical across rebuilds until Debian itself bumps
# it, so without this a rebuilt -chip kernel (new nand.cfg, DT patch, etc.) keeps
# the same version and devices never `apt upgrade` to it. Append a build id (unix
# time by default; set CHIP_BUILD_ID -- e.g. the kernel submodule's commit time
# -- for reproducible builds). This only changes the package VERSION, not the
# package name / ABI (those derive from the upstream version + abiname), so uname
# and the linux-image-*-chip name stay stable.
base_ver=$(dpkg-parsechangelog -S Version)
chip_ver="${base_ver}+chip${CHIP_BUILD_ID:-$(date -u +%s)}"
{
    printf '%s (%s) trixie; urgency=medium\n\n' "$(dpkg-parsechangelog -S Source)" "$chip_ver"
    printf '  * Automated CHIP build (%s).\n\n' "$chip_ver"
    printf ' -- CHIP CI <software@nextthing.co>  %s\n\n' "$(date -uR)"
    cat debian/changelog
} > debian/changelog.chip
mv debian/changelog.chip debian/changelog

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
