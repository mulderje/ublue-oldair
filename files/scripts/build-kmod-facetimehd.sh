#!/bin/sh

set -oeux pipefail

ARCH="$(rpm -E '%_arch')"
KERNEL="$(rpm -q "${KERNEL_NAME:-kernel}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
RELEASE="$(rpm -E '%fedora')"

# [SCRATCH] Local rebuild of akmod-facetimehd against the patched kmodtool
# from koji scratch task 144642202 (Fedora dist-git kmodtool PR #18). With
# the patched kmodtool in the rpmbuild chroot, the generated %post line
# ends in ` || :` so the akmods-ostree-post call is non-fatal and the OCI
# install transaction no longer aborts on akmodsbuild's root guard. Remove
# this block once the upstream kmodtool fix ships in stable Fedora and the
# mulderje/facetimehd-kmod COPR rebuilds against it.
dnf5 install -y --nogpgcheck \
  https://kojipkgs.fedoraproject.org/work/tasks/2312/144642312/kmodtool-1.2-4.fc45.noarch.rpm

dnf5 install -y rpm-build "kernel-devel-${KERNEL}"

dnf5 -y copr enable mulderje/facetimehd-kmod

WORKDIR="$(mktemp -d)"
(
  cd "${WORKDIR}"
  dnf5 download --source akmod-facetimehd
  rpmbuild --rebuild --define "_topdir ${WORKDIR}/rpmbuild" facetimehd-kmod-*.src.rpm
)

dnf5 install -y "${WORKDIR}"/rpmbuild/RPMS/*/akmod-facetimehd-*.rpm

getent passwd akmods >/dev/null \
  || useradd -r -s /sbin/nologin -d /var/cache/akmods akmods

akmods --force --kernels "${KERNEL}" --kmod facetimehd
modinfo "/usr/lib/modules/${KERNEL}/extra/facetimehd/facetimehd.ko.xz" >/dev/null ||
  (find /var/cache/akmods/facetimehd/ -name \*.log -print -exec cat {} \; && exit 1)

dnf5 -y copr disable mulderje/facetimehd-kmod
