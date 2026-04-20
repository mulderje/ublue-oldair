#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

# TODO: fix terra wl spec
# dnf5 -y config-manager setopt "terra".enabled=true
dnf5 install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${RELEASE}.noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${RELEASE}.noarch.rpm

# Ensure akmods is installed first so its scriptlet creates the akmods
# system user; without it, akmods' runuser -u akmods fallback trips
# akmodsbuild's "Not to be used as root" guard during the OCI build.
dnf5 install -y akmods
getent passwd akmods >/dev/null 2>&1 || useradd -r -s /sbin/nologin -d /var/cache/akmods akmods

### BUILD wl (succeed or fail-fast with debug output)
dnf5 install -y \
  akmod-wl-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod wl
modinfo /usr/lib/modules/${KERNEL}/extra/wl/wl.ko.xz >/dev/null ||
  (find /var/cache/akmods/wl/ -name \*.log -print -exec cat {} \; && exit 1)

# TODO: fix terra wl spec
# dnf5 -y config-manager setopt "terra".enabled=false
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/rpmfusion-*.repo
