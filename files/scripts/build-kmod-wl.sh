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

# Install akmods + kernel-devel up front so (a) akmods's scriptlet creates
# the `akmods` system user, and (b) akmodsbuild has a kernel tree to build
# against when we invoke it below.
dnf5 install -y akmods "kernel-devel-${KERNEL}"

# Belt-and-braces: if akmods's scriptlet didn't create the user, do it now.
getent passwd akmods >/dev/null \
  || useradd -r -s /sbin/nologin -d /var/cache/akmods akmods

# Download the akmod RPM but DO NOT install it. Its kmodtool-generated
# %post synchronously calls `akmods-ostree-post` → `akmodsbuild`, which
# trips `akmodsbuild`'s id-u-0 root guard in OCI builds and aborts the
# transaction. We want the .src.rpm it ships under /usr/src/akmods/, not
# the trigger RPM itself. Then build the per-kernel kmod RPM directly by
# running `akmodsbuild` as the akmods user (bypassing the broken %post).
WORKDIR="/var/cache/akmods/_build_wl"
mkdir -p "${WORKDIR}"
chown akmods:akmods "${WORKDIR}"
(
  cd "${WORKDIR}"
  dnf5 download akmod-wl
  rpm2cpio akmod-wl-*.rpm | cpio -idm './usr/src/akmods/*.src.rpm'
  chown -R akmods:akmods usr
  runuser -u akmods -- akmodsbuild \
    --kernels "${KERNEL}" \
    --target "${ARCH}" \
    --outputdir "${WORKDIR}" \
    usr/src/akmods/wl-kmod-*.src.rpm
)

dnf5 install -y "${WORKDIR}"/kmod-wl-*.rpm

modinfo /usr/lib/modules/${KERNEL}/extra/wl/wl.ko.xz >/dev/null ||
  (find /var/cache/akmods/wl/ -name \*.log -print -exec cat {} \; && exit 1)

# TODO: fix terra wl spec
# dnf5 -y config-manager setopt "terra".enabled=false
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/rpmfusion-*.repo
