#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

### BUILD wl (succeed or fail-fast with debug output)
dnf5 install -y --enable-repo="rpmfusion-nonfree" \
  akmod-wl-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod wl
modinfo /usr/lib/modules/${KERNEL}/extra/wl/wl.ko.xz >/dev/null ||
  (find /var/cache/akmods/wl/ -name \*.log -print -exec cat {} \; && exit 1)
