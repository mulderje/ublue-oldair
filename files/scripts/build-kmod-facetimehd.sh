#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

dnf5 -y copr enable mulderje/facetimehd-kmod

### BUILD facetimehd (succeed or fail-fast with debug output)
# Three-step install so akmods's scriptlet creates the `akmods` user before
# akmod-facetimehd's %post runs. In minimal OCI builds the implicit Requires:
# chain can leave the user uncreated when akmods and akmod-facetimehd are in
# the same transaction, which makes `akmods` fall through to invoking
# akmodsbuild as root and trip its "-w /" guard:
#   >>> ERROR: Not to be used as root; start as user or 'akmodsbuild' instead.
dnf5 install -y akmods

# Belt-and-braces: if akmods's scriptlet didn't create the user, do it now.
getent passwd akmods >/dev/null \
  || useradd -r -s /sbin/nologin -d /var/cache/akmods akmods

dnf5 install -y akmod-facetimehd-*.fc${RELEASE}.${ARCH}

akmods --force --kernels "${KERNEL}" --kmod facetimehd
modinfo "/usr/lib/modules/${KERNEL}/extra/facetimehd/facetimehd.ko.xz" >/dev/null ||
  (find /var/cache/akmods/facetimehd/ -name \*.log -print -exec cat {} \; && exit 1)

dnf5 -y copr disable mulderje/facetimehd-kmod
