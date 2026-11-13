#!/usr/bin/env bash
set -euo pipefail

SMIC_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SMIC_PROJECT_DIR=$(cd -- "${SMIC_SCRIPT_DIR}/.." && pwd)
SMIC_COMPAT_DIR=${SMIC_PROJECT_DIR}/.vivado-compat
SMIC_TMP_DIR=$(mktemp -d)
trap 'rm -rf -- "${SMIC_TMP_DIR}"' EXIT

SMIC_TINFO_DEB=${SMIC_TMP_DIR}/libtinfo5_6.3-2_amd64.deb
SMIC_NCURSES_DEB=${SMIC_TMP_DIR}/libncurses5_6.3-2_amd64.deb

curl -L --fail --max-time 60 -o "${SMIC_TINFO_DEB}" \
    https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb
curl -L --fail --max-time 60 -o "${SMIC_NCURSES_DEB}" \
    https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb

printf '%s  %s\n' \
    d2597b5aec92a930cf549e1b429ad892595813e72ec7814685ea146a9fb715e5 "${SMIC_TINFO_DEB}" \
    d9b8efb37a056e01c46d93c7ef6977aa04ad2586978137d9a3954c15ad5d14c3 "${SMIC_NCURSES_DEB}" \
    | sha256sum -c -

mkdir -p "${SMIC_COMPAT_DIR}"
dpkg-deb -x "${SMIC_TINFO_DEB}" "${SMIC_COMPAT_DIR}"
dpkg-deb -x "${SMIC_NCURSES_DEB}" "${SMIC_COMPAT_DIR}"
echo "Vivado compatibility libraries installed in ${SMIC_COMPAT_DIR}"
