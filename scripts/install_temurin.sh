#!/usr/bin/env bash
# ==============================================================================
# Script: install_temurin.sh
# Purpose: Download, verify, and install official, unmodified Eclipse Temurin®
#          OpenJDK (aarch64/arm64) directly from Adoptium APIs.
# ==============================================================================

set -euo pipefail

DEFAULT_VERSION="21"
VERSION="${DEFAULT_VERSION}"
INSTALL_DIR=""
SET_DEFAULT=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -v, --version <8|17|21|22|23>  OpenJDK feature version (default: 21)
  -d, --dest <path>              Destination directory for installation
  -s, --set-default              Set this JDK as the system/user default (symlink / JAVA_HOME)
  -h, --help                     Display this help message

Examples:
  ./install_temurin.sh --version 21 --set-default
  ./install_temurin.sh --version 17 --dest /opt/temurin-17
EOF
    exit 0
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -d|--dest)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -s|--set-default)
            SET_DEFAULT=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option $1" >&2
            usage
            ;;
    esac
done

# Architecture verification
ARCH="$(uname -m)"
if [[ "${ARCH}" != "aarch64" && "${ARCH}" != "arm64" ]]; then
    echo "[-] Warning: Host architecture is '${ARCH}', but Eclipse Temurin aarch64 is targeted."
    echo "    This script will proceed to download aarch64 binaries."
fi

# Determine default installation directory if not specified
if [[ -z "${INSTALL_DIR}" ]]; then
    if [[ "$(id -u)" -eq 0 ]]; then
        INSTALL_DIR="/opt/temurin-jdk-${VERSION}"
    else
        INSTALL_DIR="${HOME}/.local/share/temurin-jdk-${VERSION}"
    fi
fi

echo "=========================================================="
echo "  Eclipse Temurin® OpenJDK (aarch64) Installer"
echo "=========================================================="
echo "[+] Target OpenJDK Version: ${VERSION}"
echo "[+] Target Architecture:    aarch64 (ARM64)"
echo "[+] Installation Directory: ${INSTALL_DIR}"
echo "----------------------------------------------------------"

# Ensure dependencies are available
for cmd in curl jq tar sha256sum; do
    if ! command -v "${cmd}" &>/dev/null; then
        echo "[-] Missing required dependency: ${cmd}"
        echo "    Please install it (e.g. 'apt-get install -y ${cmd}' or 'pkg install ${cmd}')"
        exit 1
    fi
done

API_URL="https://api.adoptium.net/v3/assets/feature_releases/${VERSION}/ga?architecture=aarch64&image_type=jdk&os=linux"
echo "[+] Querying Adoptium API: ${API_URL}"

API_RESP="$(curl -fsSL "${API_URL}" 2>/dev/null || true)"
if [[ -z "${API_RESP}" || "${API_RESP}" == "[]" ]]; then
    echo "[-] Failed to fetch release metadata for OpenJDK ${VERSION} (aarch64) from Adoptium API."
    echo "    Checking fallback latest release..."
    exit 1
fi

PKG_NAME="$(echo "${API_RESP}" | jq -r '.[0].binaries[0].package.name')"
DOWNLOAD_URL="$(echo "${API_RESP}" | jq -r '.[0].binaries[0].package.link')"
EXPECTED_SHA256="$(echo "${API_RESP}" | jq -r '.[0].binaries[0].package.checksum')"

echo "[+] Release Archive:   ${PKG_NAME}"
echo "[+] Download URL:      ${DOWNLOAD_URL}"
echo "[+] Expected SHA256:   ${EXPECTED_SHA256}"

TEMP_DIR="$(mktemp -d /tmp/temurin-dl.XXXXXX)"
cleanup() {
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

TARBALL="${TEMP_DIR}/${PKG_NAME}"

echo "[+] Downloading unmodified Eclipse Temurin binary..."
curl -fL --progress-bar -o "${TARBALL}" "${DOWNLOAD_URL}"

echo "[+] Verifying package integrity (SHA256)..."
ACTUAL_SHA256="$(sha256sum "${TARBALL}" | awk '{print $1}')"
if [[ "${ACTUAL_SHA256}" != "${EXPECTED_SHA256}" ]]; then
    echo "[-] Integrity check failed!"
    echo "    Expected: ${EXPECTED_SHA256}"
    echo "    Actual:   ${ACTUAL_SHA256}"
    exit 1
fi
echo "[+] Checksum matches successfully!"

echo "[+] Preparing destination directory: ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

echo "[+] Extracting archive..."
# Strip leading root folder from Adoptium tarballs (e.g. jdk-21.0.13+9)
tar -xzf "${TARBALL}" -C "${INSTALL_DIR}" --strip-components=1

# Verify executable
JAVA_BIN="${INSTALL_DIR}/bin/java"
if [[ ! -x "${JAVA_BIN}" ]]; then
    echo "[-] Verification failed: ${JAVA_BIN} is not executable."
    exit 1
fi

echo "[+] Testing unmodified OpenJDK binary:"
"${JAVA_BIN}" -version

if [[ "${SET_DEFAULT}" == true ]]; then
    echo "[+] Setting as default Java runtime..."
    if [[ "$(id -u)" -eq 0 ]]; then
        update-alternatives --install /usr/bin/java java "${JAVA_BIN}" 1000 2>/dev/null || {
            ln -sf "${JAVA_BIN}" /usr/local/bin/java
        }
        update-alternatives --install /usr/bin/javac javac "${INSTALL_DIR}/bin/javac" 1000 2>/dev/null || {
            ln -sf "${INSTALL_DIR}/bin/javac" /usr/local/bin/javac
        }
    else
        mkdir -p "${HOME}/.local/bin"
        ln -sf "${JAVA_BIN}" "${HOME}/.local/bin/java"
        ln -sf "${INSTALL_DIR}/bin/javac" "${HOME}/.local/bin/javac"
        echo "[+] Symlinked java to ${HOME}/.local/bin/java"
    fi

    # Create profile environment snippet
    PROFILE_FILE="/etc/profile.d/temurin-${VERSION}.sh"
    if [[ "$(id -u)" -eq 0 && -d "/etc/profile.d" ]]; then
        cat <<ENV_EOF > "${PROFILE_FILE}"
export JAVA_HOME="${INSTALL_DIR}"
export PATH="\${JAVA_HOME}/bin:\${PATH}"
ENV_EOF
        echo "[+] Environment written to ${PROFILE_FILE}"
    fi
fi

echo "----------------------------------------------------------"
echo "[✓] Eclipse Temurin® OpenJDK ${VERSION} installed successfully!"
echo "    JAVA_HOME: ${INSTALL_DIR}"
echo "    Binary:    ${JAVA_BIN}"
echo "=========================================================="
