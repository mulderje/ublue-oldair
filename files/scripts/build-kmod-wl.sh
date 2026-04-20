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

### BUILD wl (succeed or fail-fast with debug output)
# Install akmods first so its scriptlets create the `akmods` system user.
# In minimal OCI builds, the implicit Requires: chain from akmod-wl
# sometimes leaves the user uncreated, which makes `akmods` fall through
# to invoking akmodsbuild as root and trip its "-w /" guard:
#   >>> ERROR: Not to be used as root; start as user or 'akmodsbuild' instead.
dnf5 install -y \
  akmods \
  akmod-wl-*.fc${RELEASE}.${ARCH}

# Belt-and-braces: if the scriptlet still didn't create the user, do it now.
getent passwd akmods >/dev/null \
  || useradd -r -s /sbin/nologin -d /var/cache/akmods akmods

akmods --force --kernels "${KERNEL}" --kmod wl
modinfo /usr/lib/modules/${KERNEL}/extra/wl/wl.ko.xz >/dev/null ||
  (find /var/cache/akmods/wl/ -name \*.log -print -exec cat {} \; && exit 1)

# TODO: fix terra wl spec
# dnf5 -y config-manager setopt "terra".enabled=false
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/rpmfusion-*.repo
