#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

dnf5 -y copr enable mulderje/facetimehd-kmod

# Ensure akmods is installed first so its scriptlet creates the akmods
# system user; without it, akmods' runuser -u akmods fallback trips
# akmodsbuild's "Not to be used as root" guard during the OCI build.
dnf5 install -y akmods
getent passwd akmods >/dev/null 2>&1 || useradd -r -s /sbin/nologin -d /var/cache/akmods akmods

### BUILD facetimehd (succeed or fail-fast with debug output)
dnf5 install -y \
  akmod-facetimehd-*.fc${RELEASE}.${ARCH}
akmods --force --kernels "${KERNEL}" --kmod facetimehd
modinfo "/usr/lib/modules/${KERNEL}/extra/facetimehd/facetimehd.ko.xz" >/dev/null ||
  (find /var/cache/akmods/facetimehd/ -name \*.log -print -exec cat {} \; && exit 1)

dnf5 -y copr disable mulderje/facetimehd-kmod
