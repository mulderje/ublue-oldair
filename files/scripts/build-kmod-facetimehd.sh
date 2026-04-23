#!/bin/sh

set -oeux pipefail

KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

dnf5 -y copr enable mulderje/facetimehd-kmod

dnf5 install -y "kmod-facetimehd-${KERNEL}"
modinfo "/usr/lib/modules/${KERNEL}/extra/facetimehd/facetimehd.ko.xz" >/dev/null

dnf5 -y copr disable mulderje/facetimehd-kmod
