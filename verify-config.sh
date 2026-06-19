#!/bin/bash
# Verify that every CONFIG_* line in nand.cfg actually survived kconfig
# resolution in the built kernel.
#
# WHY THIS EXISTS: nand.cfg is a config *fragment* merged on top of Debian's
# armmp config and then run through `oldconfig`. kconfig will SILENTLY DROP or
# DEMOTE any value whose dependencies aren't met -- e.g. a built-in (`=y`) bridge
# whose DRM core is `=m` gets quietly rewritten to `=m`, with no build error.
# We hit exactly this: the kernel shipped with the DIP display bridges as
# modules despite nand.cfg saying `=y`, and nobody noticed until the panel stayed
# dark. This script makes that failure loud.
#
# It does NOT rebuild anything. Run it AFTER `make` (which leaves a fully
# resolved .config in the build tree), or point it at any resolved .config.
#
# Usage:
#   ./verify-config.sh                 # auto-find the build tree's resolved .config
#   ./verify-config.sh path/to/.config # check against a specific .config
#
# Exit status: 0 = every nand.cfg symbol took effect; 1 = at least one was
# dropped/demoted (details printed); 2 = couldn't find a .config to check.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
FRAG="${HERE}/nand.cfg"

resolved="${1:-}"
if [ -z "${resolved}" ]; then
	# Newest resolved config left by `make` (build/linux-*/debian/build/build_*_chip/.config).
	resolved="$(ls -t "${HERE}"/build/linux-*/debian/build/build_*_chip/.config 2>/dev/null | head -1)"
fi
if [ -z "${resolved}" ] || [ ! -f "${resolved}" ]; then
	echo "error: no resolved .config found. Build first (\`make\`) or pass a path." >&2
	echo "       (looked under ${HERE}/build/linux-*/debian/build/build_*_chip/.config)" >&2
	exit 2
fi

echo "fragment: ${FRAG}"
echo "resolved: ${resolved}"
echo

fail=0
while IFS= read -r line; do
	# Requested-on:  CONFIG_FOO=y / =m / ="str" / =123
	if [[ "${line}" =~ ^(CONFIG_[A-Za-z0-9_]+)=(.*)$ ]]; then
		sym="${BASH_REMATCH[1]}"; want="${BASH_REMATCH[2]}"
	# Requested-off: # CONFIG_FOO is not set
	elif [[ "${line}" =~ ^#\ (CONFIG_[A-Za-z0-9_]+)\ is\ not\ set$ ]]; then
		sym="${BASH_REMATCH[1]}"; want="n"
	else
		continue
	fi

	if grep -q "^${sym}=" "${resolved}"; then
		got="$(sed -n "s/^${sym}=//p" "${resolved}")"
	elif grep -q "^# ${sym} is not set$" "${resolved}"; then
		got="n"
	else
		got="(absent)"
	fi

	if [ "${got}" = "${want}" ]; then
		printf '  ok    %-32s %s\n' "${sym}" "${want}"
	else
		printf '  FAIL  %-32s requested=%-6s resolved=%s\n' "${sym}" "${want}" "${got}"
		fail=1
	fi
done < "${FRAG}"

echo
if [ "${fail}" -eq 0 ]; then
	echo "PASS: every nand.cfg symbol survived kconfig resolution."
else
	echo "DEMOTED/DROPPED symbols above did NOT take effect in the build."
	echo "Usually a missing dependency (e.g. a =y symbol that depends on a =m one)."
	echo "Fix by also forcing the dependency =y in nand.cfg; see README.md."
fi
exit "${fail}"
