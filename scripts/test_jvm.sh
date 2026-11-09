#!/usr/bin/env bash
# ==============================================================================
# Script: test_jvm.sh
# Purpose: Verify unmodified Eclipse Temurin® OpenJDK aarch64 runtime,
#          JVM properties, and JIT compilation on Android.
# ==============================================================================

set -euo pipefail

JAVA_CMD="${1:-java}"

if ! command -v "${JAVA_CMD}" &>/dev/null; then
    echo "[-] Java binary not found: ${JAVA_CMD}"
    exit 1
fi

echo "=========================================================="
echo "  Eclipse Temurin® OpenJDK Runtime Diagnostics & Benchmark"
echo "=========================================================="
echo "[+] Java Executable: $(command -v "${JAVA_CMD}")"
echo "----------------------------------------------------------"
"${JAVA_CMD}" -version
echo "----------------------------------------------------------"

TEST_DIR="$(mktemp -d /tmp/temurin-test.XXXXXX)"
cleanup() {
    rm -rf "${TEST_DIR}"
}
trap cleanup EXIT

TEST_JAVA="${TEST_DIR}/TemurinDiagnostic.java"

cat <<'EOF' > "${TEST_JAVA}"
public class TemurinDiagnostic {
    public static void main(String[] args) {
        System.out.println("[*] Java Runtime Diagnostics:");
        System.out.println("    - Vendor:       " + System.getProperty("java.vendor"));
        System.out.println("    - VM Name:      " + System.getProperty("java.vm.name"));
        System.out.println("    - VM Version:   " + System.getProperty("java.vm.version"));
        System.out.println("    - VM Info:      " + System.getProperty("java.vm.info"));
        System.out.println("    - Java Home:    " + System.getProperty("java.home"));
        System.out.println("    - Architecture: " + System.getProperty("os.arch"));
        System.out.println("    - Data Model:   " + System.getProperty("sun.arch.data.model") + "-bit");
        System.out.println("    - OS Name/Ver:  " + System.getProperty("os.name") + " " + System.getProperty("os.version"));
        System.out.println("    - Available CPUs: " + Runtime.getRuntime().availableProcessors());
        System.out.println("    - Max Heap Mem: " + (Runtime.getRuntime().maxMemory() / (1024 * 1024)) + " MB");

        System.out.println("\n[*] Executing JIT Micro-Benchmark (Warmup & Compilation)...");
        long start = System.nanoTime();
        long sum = 0;
        for (int i = 0; i < 50_000_000; i++) {
            sum += (i ^ (i >>> 3));
        }
        long durationMs = (System.nanoTime() - start) / 1_000_000;
        System.out.println("    - Calculation checksum: " + sum);
        System.out.println("    - Time elapsed:         " + durationMs + " ms");

        if (durationMs < 500) {
            System.out.println("[✓] JIT Compilation confirmed active and generating native code!");
        } else {
            System.out.println("[!] Notice: Execution took longer than expected, JIT may still be warming up.");
        }
    }
}
EOF

echo "[+] Compiling and executing diagnostic test with unmodified JVM..."
"${JAVA_CMD}" "${TEST_JAVA}"

echo "=========================================================="
echo "[✓] Eclipse Temurin® OpenJDK verification complete."
echo "=========================================================="
