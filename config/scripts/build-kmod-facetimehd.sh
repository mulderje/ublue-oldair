#!/bin/sh

set -oeux pipefail

export KERNEL_NAME="kernel"
mkdir -p /tmp /var/tmp && \
chmod -R 1777 /var/tmp

wget https://copr.fedorainfracloud.org/coprs/mulderje/facetimehd-kmod/repo/fedora-$(rpm -E %fedora)/mulderje-facetimehd-kmod-fedora-$(rpm -E %fedora).repo -O /etc/yum.repos.d/_copr_mulderje-facetimehd-kmod.repo

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

### BUILD facetimehd (succeed or fail-fast with debug output)
rpm-ostree install \
    akmod-facetimehd-*.fc${RELEASE}.${ARCH} \
    facetimehd-firmware
akmods --force --kernels "${KERNEL}" --kmod facetimehd
modinfo /usr/lib/modules/${KERNEL}/extra/facetimehd/facetimehd.ko.xz > /dev/null \
|| (find /var/cache/akmods/facetimehd/ -name \*.log -print -exec cat {} \; && exit 1)
