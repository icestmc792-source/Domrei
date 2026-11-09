#!/usr/bin/env bash
# ==============================================================================
# Script: setup.sh
# Purpose: Complete one-step automated installer for running Minecraft Java Edition
#          on Android using unmodified Eclipse Temurin® OpenJDK aarch64.
# Execution context: Run inside Android Termux application.
# ==============================================================================

set -euo pipefail

DISTRO="debian"
CONTAINER_NAME="domrei-mc"

echo "=========================================================="
echo "    Domrei: Minecraft Java on Android with Unmodified"
echo "           Eclipse Temurin® OpenJDK (aarch64)"
echo "=========================================================="

# 1. Architecture Check
ARCH="$(uname -m)"
if [[ "${ARCH}" != "aarch64" && "${ARCH}" != "arm64" ]]; then
    echo "[-] Error: Unsupported architecture '${ARCH}'."
    echo "    This setup requires a 64-bit ARM device (aarch64/arm64)."
    exit 1
fi
echo "[+] Detected Architecture: aarch64 (ARM64) [Supported]"

# 2. Check if running in Termux
if [[ ! -d "/data/data/com.termux/files" ]]; then
    echo "[!] Warning: This script is intended to run inside Android Termux."
    echo "    Continuing in standalone / development mode..."
fi

# 3. Update Termux repositories & install base dependencies
echo "[1/4] Updating Termux packages and adding X11 repositories..."
if command -v pkg &>/dev/null; then
    pkg update -y || true
    pkg install -y x11-repo || true
    pkg install -y proot-distro pulseaudio wget curl jq tar || true
    
    # Install Termux-X11 if available in repository
    pkg install -y termux-x11-nightly || {
        echo "[!] termux-x11-nightly not found in repo; please ensure Termux-X11 APK is installed."
    }
fi

# 4. Initialize Linux container via proot-distro
echo "[2/4] Setting up Debian glibc Linux container (${DISTRO})..."
if ! command -v proot-distro &>/dev/null; then
    echo "[-] Error: proot-distro is required. Please install it with 'pkg install proot-distro'."
    exit 1
fi

if ! proot-distro list | grep -q "${DISTRO} (installed)"; then
    echo "[+] Installing ${DISTRO} container via proot-distro..."
    proot-distro install "${DISTRO}"
else
    echo "[+] ${DISTRO} container already installed."
fi

# 5. Provision the container with unmodified Temurin & graphics stack
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[3/4] Copying provisioning scripts into container..."

# Copy scripts into container's root or /opt
CONTAINER_ROOT="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/${DISTRO}"
if [[ -d "${CONTAINER_ROOT}" ]]; then
    mkdir -p "${CONTAINER_ROOT}/opt/domrei"
    cp -r "${SCRIPT_DIR}/scripts" "${CONTAINER_ROOT}/opt/domrei/"
    cp -r "${SCRIPT_DIR}/config" "${CONTAINER_ROOT}/opt/domrei/"
    chmod +x "${CONTAINER_ROOT}/opt/domrei/scripts/"*.sh
else
    echo "[-] Warning: Direct rootfs path not found; using proot-distro login to transfer..."
fi

echo "[4/4] Executing guest provisioning inside Debian container..."
proot-distro login "${DISTRO}" -- /bin/bash -c "
    if [ -f /opt/domrei/scripts/guest_setup.sh ]; then
        /opt/domrei/scripts/guest_setup.sh
    else
        echo 'Provisioning script not found at /opt/domrei/scripts/guest_setup.sh'
        exit 1
    fi
"

echo "=========================================================="
echo "[✓] Domrei setup completed successfully!"
echo ""
echo "Next Steps to play:"
echo " 1. Ensure you have the Termux:X11 Android APK installed:"
echo "    https://github.com/termux/termux-x11/releases"
echo " 2. Run the launch script:"
echo "    ./launch.sh"
echo "=========================================================="
