#!/bin/sh

set -oeux pipefail

mkdir -p /tmp /var/tmp
chmod -R 1777 /var/tmp

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

if [[ "${RELEASE}" -ge 40 ]]; then
    COPR_RELEASE="rawhide"
else
    COPR_RELEASE="${RELEASE}"
fi

echo "$ARCH $KERNEL $RELEASE"
wget "https://copr.fedorainfracloud.org/coprs/mulderje/facetimehd-kmod/repo/fedora-${COPR_RELEASE}/mulderje-facetimehd-kmod-fedora-${COPR_RELEASE}.repo" -O /etc/yum.repos.d/_copr_mulderje-facetimehd-kmod.repo

### BUILD facetimehd (succeed or fail-fast with debug output)
rpm-ostree install \
    "akmod-facetimehd-*.fc${RELEASE}.${ARCH}" \
    facetimehd-firmware
akmods --force --kernels "${KERNEL}" --kmod facetimehd
modinfo "/usr/lib/modules/${KERNEL}/extra/facetimehd/facetimehd.ko.xz"sa > /dev/null \
|| (find /var/cache/akmods/facetimehd/ -name \*.log -print -exec cat {} \; && exit 1)

rm -f /etc/yum.repos.d/_copr_mulderje-facetimehd-kmod.repo
