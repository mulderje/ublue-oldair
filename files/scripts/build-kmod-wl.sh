#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

dnf5 -y config-manager setopt "terra".enabled=true
sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/rpmfusion-*.repo

### BUILD wl (succeed or fail-fast with debug output)
dnf5 install -y \
  akmod-wl-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod wl
modinfo /usr/lib/modules/${KERNEL}/extra/wl/wl.ko.xz >/dev/null ||
  (find /var/cache/akmods/wl/ -name \*.log -print -exec cat {} \; && exit 1)

dnf5 -y config-manager setopt "terra".enabled=false
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/rpmfusion-*.repo
