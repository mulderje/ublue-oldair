#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

dnf5 -y copr enable mulderje/facetimehd-kmod-pr

### BUILD facetimehd (succeed or fail-fast with debug output)
# Install akmods first so its scriptlets create the `akmods` system user.
# In minimal OCI builds, the implicit Requires: chain from akmod-facetimehd
# sometimes leaves the user uncreated, which makes `akmods` fall through
# to invoking akmodsbuild as root and trip its "-w /" guard:
#   >>> ERROR: Not to be used as root; start as user or 'akmodsbuild' instead.
dnf5 install -y \
  akmods \
  akmod-facetimehd-*.fc${RELEASE}.${ARCH}

# Belt-and-braces: if the scriptlet still didn't create the user, do it now.
getent passwd akmods >/dev/null \
  || useradd -r -s /sbin/nologin -d /var/cache/akmods akmods

akmods --force --kernels "${KERNEL}" --kmod facetimehd
modinfo "/usr/lib/modules/${KERNEL}/extra/facetimehd/facetimehd.ko.xz" >/dev/null ||
  (find /var/cache/akmods/facetimehd/ -name \*.log -print -exec cat {} \; && exit 1)

dnf5 -y copr disable mulderje/facetimehd-kmod-pr
