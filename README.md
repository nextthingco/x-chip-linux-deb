# x-chip-linux-deb

This repository is for building the linux kernel for Debian. It attempts to adhere to Debian convention as close as possible so as to introduce little friction using the distro while using a different flavor of kernel.

## building

Use `make` to build a docker image, and to run the build.

## details

We pull the regular Debian kernel source, select the defconfig, apply our patches (NAND device tree, dtb `__symbols__`, composite overscan), and build as a new `-chip` kernel flavor.

## verifying nand.cfg

`nand.cfg` is a config *fragment*, merged on top of Debian's armmp config and run
through `oldconfig`. **kconfig silently drops or demotes any value whose
dependencies aren't met** -- with no build error. We shipped a kernel where the
DIP display bridges were modules despite `nand.cfg` saying `=y`, because their
`=y` depended on `CONFIG_DRM`/`CONFIG_DRM_SUN4I` which armmp ships `=m`; kconfig
quietly rewrote `=y` back to `=m`. The same check also catches stale symbol names
that no longer exist in a newer kernel (these just vanish).

Two checks guard against this:

### 1. After a build: did every nand.cfg symbol take effect?

`make` leaves a fully resolved `.config` in the build tree. Run:

```
./verify-config.sh
```

It compares every `CONFIG_*` line in `nand.cfg` against the resolved config and
prints `ok` / `FAIL` per symbol (non-zero exit on any `FAIL`). A `FAIL` means the
symbol was demoted (`=y`->`=m`) or dropped (absent -- usually a wrong/stale name
or an unmet dependency). Run this before publishing a kernel.

### 2. Before adding a symbol: what does it actually pull in?

To add a symbol the way `nconfig` would (with full dependency resolution) and see
the real delta -- including whether it even *can* be set -- diff against the
resolved baseline using the same cross toolchain the build uses:

```
cd build/linux-*/                       # the unpacked kernel source
export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
mkdir -p /tmp/kcfg
cp debian/build/build_*_chip/.config /tmp/kcfg/.config
make O=/tmp/kcfg olddefconfig          # normalize baseline under the cross toolchain
cp /tmp/kcfg/.config /tmp/baseline
scripts/config --file /tmp/kcfg/.config -e SOME_SYMBOL -e ANOTHER_SYMBOL
make O=/tmp/kcfg olddefconfig          # resolve deps/selects/demotions
diff /tmp/baseline /tmp/kcfg/.config   # the authoritative delta to fold into nand.cfg
```

If a symbol you `-e`'d does **not** appear in the diff as `=y`, kconfig refused
it -- a dependency is missing and must be forced first. (Use `O=` so the source
tree stays read-only; the build tree is often left root-owned by docker.)