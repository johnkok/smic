#!/usr/bin/env bash
set -euo pipefail

SMIC_VIVADO_ROOT=/opt/AMD_II/2026.1/Vivado
SMIC_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SMIC_PROJECT_DIR=$(cd -- "${SMIC_SCRIPT_DIR}/.." && pwd)
SMIC_COMPAT_ROOT=${SMIC_PROJECT_DIR}/.vivado-compat
SMIC_COMPAT_LIB_DIR=${SMIC_COMPAT_ROOT}/lib/x86_64-linux-gnu
SMIC_COMPAT_USR_LIB_DIR=${SMIC_COMPAT_ROOT}/usr/lib/x86_64-linux-gnu

if [[ ! -x "${SMIC_VIVADO_ROOT}/bin/vivado" ]]; then
    echo "Vivado executable not found at ${SMIC_VIVADO_ROOT}/bin/vivado" >&2
    exit 127
fi

# shellcheck disable=SC1091
source "${SMIC_VIVADO_ROOT}/settings64.sh"
if [[ -d "${SMIC_COMPAT_LIB_DIR}" ]]; then
    export LD_LIBRARY_PATH="${SMIC_COMPAT_LIB_DIR}:${SMIC_COMPAT_USR_LIB_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
fi
cd "${SMIC_PROJECT_DIR}"
exec "${SMIC_VIVADO_ROOT}/bin/vivado" "$@"
