#!/usr/bin/env bash
# ==============================================================================
# Script: launch.sh
# Purpose: Start Termux-X11, PulseAudio, and launch Minecraft Java Edition
#          with unmodified Eclipse Temurin® OpenJDK aarch64 on Android.
# ==============================================================================

set -euo pipefail

DISTRO="debian"
DISPLAY_NUM=":0"

echo "=========================================================="
echo "    Launching Minecraft Java Edition (Domrei / aarch64)   "
echo "=========================================================="

# 1. Start PulseAudio server (for game sound)
echo "[1/4] Checking PulseAudio server..."
if ! pgrep -f "pulseaudio" &>/dev/null; then
    echo "[+] Starting PulseAudio daemon..."
    pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
else
    echo "[+] PulseAudio is already running."
fi

# 2. Start Termux-X11 Display Server
echo "[2/4] Starting Termux-X11 Display Server..."
export DISPLAY="${DISPLAY_NUM}"
if ! pgrep -f "termux-x11 ${DISPLAY_NUM}" &>/dev/null; then
    echo "[+] Starting termux-x11 background process on ${DISPLAY}..."
    termux-x11 "${DISPLAY}" >/dev/null 2>&1 &
    sleep 1
else
    echo "[+] Termux-X11 is already running on ${DISPLAY}."
fi

# 3. Bring Termux-X11 app to the foreground on Android
echo "[3/4] Bringing Termux-X11 app to the foreground..."
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity 2>/dev/null || {
    echo "[!] Notice: Please manually switch to the Termux:X11 application if it doesn't open automatically."
}

# 4. Launch Container with GPU acceleration and Temurin JVM
echo "[4/4] Starting Prism Launcher with Eclipse Temurin®..."

proot-distro login "${DISTRO}" --shared-tmp -- /bin/bash -c "
    export DISPLAY=${DISPLAY}
    export PULSE_SERVER=127.0.0.1
    export XDG_RUNTIME_DIR=/tmp
    
    # Mesa Zink / Turnip hardware acceleration
    export MESA_LOADER_DRIVER_OVERRIDE=zink
    export GALLIUM_DRIVER=zink
    export TU_DEBUG=noconform
    export ZINK_DESCRIPTORS=lazy
    export MESA_GL_VERSION_OVERRIDE=4.6
    export MESA_GLSL_VERSION_OVERRIDE=460
    
    # Ensure default Java is set to Eclipse Temurin
    export JAVA_HOME=/opt/temurin-jdk-21
    export PATH=\${JAVA_HOME}/bin:\${PATH}
    
    if command -v prismlauncher &>/dev/null; then
        exec prismlauncher
    elif [ -f /usr/local/bin/prismlauncher-accel ]; then
        exec /usr/local/bin/prismlauncher-accel
    else
        echo '[-] Prism Launcher not detected. Opening shell with Temurin JDK active...'
        exec /bin/bash
    fi
"
