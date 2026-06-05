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

# Give every build a unique, monotonically-increasing version so devices `apt
# upgrade` to a rebuilt -chip kernel even when Debian's own version (e.g.
# 6.12.86-1) is unchanged (new nand.cfg, DT patch, etc.).
#
# Debian's kernel packaging REJECTS arbitrary version suffixes for a release
# suite: gencontrol.py checks the revision against trixie's revision_regex
# '\d+(\.\d+)?(\+deb13u\d+)?' (debian/config/defines.toml) -> a '+chip<ts>'
# revision dies with "Can't upload to trixie with a version of ...". So we use
# the allowed '.N' minor-revision slot, inserting our build serial after the
# leading revision integer and BEFORE any +deb13uN (the regex requires that
# order). e.g. 6.12.86-1 -> 6.12.86-1.<serial>; 6.12.86-1+deb13u2 ->
# 6.12.86-1.<serial>+deb13u2.
#
# We EDIT the top changelog entry IN PLACE rather than prepend a new stanza: a
# second trixie entry with the same upstream version trips gencontrol's ABI
# serialisation (it appends '.1' to the abiname), which would change the package
# name / uname. Editing in place keeps abiname = <upstream>+deb13, so the
# linux-image-*-chip name and uname stay stable -- only the VERSION moves.
#
# CHIP_BUILD_ID defaults to unix time; set it (e.g. the kernel submodule commit
# epoch) for reproducible builds.
base_ver=$(dpkg-parsechangelog -S Version)
serial="${CHIP_BUILD_ID:-$(date -u +%s)}"
chip_ver=$(printf '%s' "$base_ver" | sed -E "s/^(.*-[0-9]+)(\+deb[0-9]+u[0-9]+)?$/\1.${serial}\2/")
sed -i -E "1s/\([^)]*\)/(${chip_ver})/" debian/changelog

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
