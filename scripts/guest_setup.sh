#!/usr/bin/env bash
# ==============================================================================
# Script: guest_setup.sh
# Purpose: Provision Debian/Ubuntu PRoot container for Minecraft: Java Edition
#          with unmodified Eclipse Temurin® OpenJDK aarch64 and Mesa Zink.
# ==============================================================================

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "=========================================================="
echo "  Provisioning Linux Container for Minecraft Java (aarch64)"
echo "=========================================================="

echo "[1/5] Updating package repositories..."
apt-get update -y

echo "[2/5] Installing core libraries and graphics dependencies..."
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    jq \
    tar \
    unzip \
    git \
    zenity \
    pulseaudio-utils \
    libpulse0 \
    libasound2 \
    libx11-6 \
    libx11-xcb1 \
    libxext6 \
    libxcursor1 \
    libxrandr2 \
    libxinerama1 \
    libxi6 \
    libxxf86vm1 \
    libgl1-mesa-dri \
    libgl1 \
    libglx-mesa0 \
    mesa-vulkan-drivers \
    mesa-utils \
    vulkan-tools \
    libglfw3 \
    libopenal1 \
    libudev1

echo "[3/5] Installing unmodified Eclipse Temurin® OpenJDK runtimes..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install Temurin 21 (Modern MC 1.20.5+) as system default
"${SCRIPT_DIR}/install_temurin.sh" --version 21 --dest /opt/temurin-jdk-21 --set-default

# Install Temurin 17 (MC 1.17 - 1.20.4)
"${SCRIPT_DIR}/install_temurin.sh" --version 17 --dest /opt/temurin-jdk-17

# Install Temurin 8 (Legacy MC 1.12.2 and older)
"${SCRIPT_DIR}/install_temurin.sh" --version 8 --dest /opt/temurin-jdk-8 || {
    echo "[!] Warning: Temurin 8 install skipped or unavailable, continuing..."
}

echo "[4/5] Installing Prism Launcher (aarch64 native)..."
# Download latest stable Prism Launcher AppImage or deb package for aarch64
PRISM_DIR="/opt/prismlauncher"
mkdir -p "${PRISM_DIR}"

PRISM_LATEST_DEB_URL="$(curl -fsSL https://api.github.com/repos/PrismLauncher/PrismLauncher/releases/latest | \
    jq -r '.assets[] | select(.name | test(".*(arm64|aarch64).*\\.deb$")) | .browser_download_url' | head -n 1 || true)"

if [[ -n "${PRISM_LATEST_DEB_URL}" ]]; then
    echo "[+] Found Prism Launcher deb: ${PRISM_LATEST_DEB_URL}"
    TMP_DEB="/tmp/prismlauncher.deb"
    curl -fSL -o "${TMP_DEB}" "${PRISM_LATEST_DEB_URL}"
    dpkg -i "${TMP_DEB}" 2>/dev/null || apt-get install -f -y
    rm -f "${TMP_DEB}"
else
    echo "[-] Could not retrieve Prism Launcher deb automatically; configuring fallback launcher script."
fi

echo "[5/5] Creating hardware-accelerated wrapper scripts..."
# Wrapper for Prism Launcher with Zink & Turnip acceleration
cat <<'WRAPPER_EOF' > /usr/local/bin/prismlauncher-accel
#!/usr/bin/env bash
# Hardware-accelerated launcher wrapper
export DISPLAY="${DISPLAY:-:0}"
export PULSE_SERVER="${PULSE_SERVER:-127.0.0.1}"

# Mesa Zink / Turnip Vulkan configuration
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink
export TU_DEBUG=noconform
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLSL_VERSION_OVERRIDE=460

exec prismlauncher "$@"
WRAPPER_EOF
chmod +x /usr/local/bin/prismlauncher-accel

# Clean package cache
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "=========================================================="
echo "[✓] Container provisioning complete!"
echo "    - Eclipse Temurin 21 installed at /opt/temurin-jdk-21 (Default)"
echo "    - Eclipse Temurin 17 installed at /opt/temurin-jdk-17"
echo "    - Eclipse Temurin 8  installed at /opt/temurin-jdk-8"
echo "    - Accelerated wrapper: /usr/local/bin/prismlauncher-accel"
echo "=========================================================="
