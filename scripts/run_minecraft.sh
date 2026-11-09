#!/usr/bin/env bash
# ==============================================================================
# Script: run_minecraft.sh
# Purpose: Direct CLI launcher for Minecraft Java with Eclipse Temurin®
#          OpenJDK (aarch64) and hardware-accelerated OpenGL (Mesa Zink).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"

JAVA_VERSION="21"
TARGET_JAR=""
JVM_OPTS_FILE="${CONFIG_DIR}/jvm_options.conf"
EXTRA_JVM_ARGS=()

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] --jar <minecraft_server_or_client.jar>

Options:
  -j, --java <8|17|21>       Eclipse Temurin OpenJDK version (default: 21)
  --jar <path>               Path to Minecraft client/server .jar
  -c, --config <file>        Custom JVM options file (default: config/jvm_options.conf)
  -h, --help                 Display this help message

Examples:
  ./run_minecraft.sh --java 21 --jar server.jar
  ./run_minecraft.sh --java 17 --jar fabric-server-launch.jar
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -j|--java)
            JAVA_VERSION="$2"
            shift 2
            ;;
        --jar)
            TARGET_JAR="$2"
            shift 2
            ;;
        -c|--config)
            JVM_OPTS_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            EXTRA_JVM_ARGS+=("$1")
            shift
            ;;
    esac
done

# Resolve Temurin Java binary
JAVA_HOME_PATH="/opt/temurin-jdk-${JAVA_VERSION}"
if [[ ! -d "${JAVA_HOME_PATH}" ]]; then
    JAVA_HOME_PATH="${HOME}/.local/share/temurin-jdk-${JAVA_VERSION}"
fi

JAVA_BIN="${JAVA_HOME_PATH}/bin/java"
if [[ ! -x "${JAVA_BIN}" ]]; then
    if command -v java &>/dev/null; then
        echo "[!] Specific Temurin ${JAVA_VERSION} not found at ${JAVA_HOME_PATH}, falling back to system 'java'..."
        JAVA_BIN="$(command -v java)"
    else
        echo "[-] Error: Eclipse Temurin OpenJDK ${JAVA_VERSION} not found."
        echo "    Run './scripts/install_temurin.sh --version ${JAVA_VERSION}' to install it."
        exit 1
    fi
fi

# Load JVM options
JVM_ARGS=()
if [[ -f "${JVM_OPTS_FILE}" ]]; then
    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="$(echo "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [[ -z "${line}" || "${line}" =~ ^# ]] && continue
        JVM_ARGS+=("${line}")
    done < "${JVM_OPTS_FILE}"
fi

# Graphics environment variables for client execution
export DISPLAY="${DISPLAY:-:0}"
export PULSE_SERVER="${PULSE_SERVER:-127.0.0.1}"
export MESA_LOADER_DRIVER_OVERRIDE="${MESA_LOADER_DRIVER_OVERRIDE:-zink}"
export GALLIUM_DRIVER="${GALLIUM_DRIVER:-zink}"
export TU_DEBUG="${TU_DEBUG:-noconform}"
export MESA_GL_VERSION_OVERRIDE="${MESA_GL_VERSION_OVERRIDE:-4.6}"
export MESA_GLSL_VERSION_OVERRIDE="${MESA_GLSL_VERSION_OVERRIDE:-460}"

echo "=========================================================="
echo "  Starting Minecraft via Eclipse Temurin® (aarch64)"
echo "=========================================================="
echo "[+] Java Binary:  ${JAVA_BIN}"
echo "[+] Java Version: $("${JAVA_BIN}" -version 2>&1 | head -n 1)"
if [[ -n "${TARGET_JAR}" ]]; then
    echo "[+] Target JAR:   ${TARGET_JAR}"
fi
echo "----------------------------------------------------------"

if [[ -n "${TARGET_JAR}" ]]; then
    exec "${JAVA_BIN}" "${JVM_ARGS[@]}" "${EXTRA_JVM_ARGS[@]}" -jar "${TARGET_JAR}" "$@"
else
    echo "[!] No JAR specified. Starting interactive JShell or Java command line..."
    exec "${JAVA_BIN}" "${JVM_ARGS[@]}" "${EXTRA_JVM_ARGS[@]}" "$@"
fi
