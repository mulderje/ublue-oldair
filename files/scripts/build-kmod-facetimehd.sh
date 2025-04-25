#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

dnf5 -y copr enable mulderje/facetimehd-kmod

### BUILD facetimehd (succeed or fail-fast with debug output)
dnf5 install -y \
  akmod-facetimehd-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod facetimehd
modinfo "/usr/lib/modules/${KERNEL}/extra/facetimehd/facetimehd.ko.xz" >/dev/null ||
  (find /var/cache/akmods/facetimehd/ -name \*.log -print -exec cat {} \; && exit 1)

dnf5 -y copr disable mulderje/facetimehd-kmod
