#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

# Install akmods + kernel-devel up front so (a) akmods's scriptlet creates
# the `akmods` system user, and (b) akmodsbuild has a kernel tree to build
# against when we invoke it below.
dnf5 install -y akmods "kernel-devel-${KERNEL}"

# Belt-and-braces: if akmods's scriptlet didn't create the user, do it now.
getent passwd akmods >/dev/null \
  || useradd -r -s /sbin/nologin -d /var/cache/akmods akmods

dnf5 -y copr enable mulderje/facetimehd-kmod

# Download the akmod RPM but DO NOT install it. Its kmodtool-generated
# %post synchronously calls `akmods-ostree-post` → `akmodsbuild`, which
# trips `akmodsbuild`'s id-u-0 root guard in OCI builds and aborts the
# transaction. We want the .src.rpm it ships under /usr/src/akmods/, not
# the trigger RPM itself. Then build the per-kernel kmod RPM directly by
# running `akmodsbuild` as the akmods user (bypassing the broken %post).
WORKDIR="/var/cache/akmods/_build_facetimehd"
mkdir -p "${WORKDIR}"
chown akmods:akmods "${WORKDIR}"
(
  cd "${WORKDIR}"
  dnf5 download akmod-facetimehd
  rpm2cpio akmod-facetimehd-*.rpm | cpio -idm './usr/src/akmods/*.src.rpm'
  chown -R akmods:akmods usr
  runuser -u akmods -- akmodsbuild \
    --kernels "${KERNEL}" \
    --target "${ARCH}" \
    --outputdir "${WORKDIR}" \
    usr/src/akmods/facetimehd-kmod-*.src.rpm
)

dnf5 install -y "${WORKDIR}"/kmod-facetimehd-*.rpm

modinfo "/usr/lib/modules/${KERNEL}/extra/facetimehd/facetimehd.ko.xz" >/dev/null ||
  (find /var/cache/akmods/facetimehd/ -name \*.log -print -exec cat {} \; && exit 1)

dnf5 -y copr disable mulderje/facetimehd-kmod
