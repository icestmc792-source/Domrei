# Domrei 🐘

> **Run Minecraft: Java Edition on Android using an unmodified version of OpenJDK aarch64/arm64 (Eclipse Temurin® by Adoptium).**

[![Adoptium Temurin](https://img.shields.io/badge/OpenJDK-Eclipse%20Temurin%C2%AE-purple.svg)](https://adoptium.net)
[![Architecture](https://img.shields.io/badge/Architecture-aarch64%20%7C%20ARM64-blue.svg)](#)
[![Graphics](https://img.shields.io/badge/Graphics-Mesa%20Zink%20%2F%20Turnip-red.svg)](#)
[![Root](https://img.shields.io/badge/Root-Not%20Required-success.svg)](#)

---

## Overview

Unlike standard mobile launchers that require a custom-compiled or modified Android Bionic OpenJDK fork, **Domrei** enables running **100% official, unmodified desktop Eclipse Temurin® OpenJDK binaries (`aarch64`)** directly on Android.

### Key Highlights
- **Unmodified OpenJDK Runtimes**: Uses official Adoptium production releases for Java 21, Java 17, and Java 8 with SHA-256 integrity verification.
- **Full Mod Compatibility**: Compatible with mods and libraries that require standard desktop `glibc` (including modern Fabric, Sodium, Iris Shaders, and Forge).
- **Desktop Hardware Acceleration**: Translates desktop OpenGL 4.6 Core Profile to Vulkan using **Mesa Zink** and **Turnip** (for Qualcomm Adreno GPUs) or system Vulkan.
- **Zero Root Required**: Operates inside non-root userland through PRoot syscall translation (`PTRACE_SYSEMU`).
- **Low-Latency Audio**: Sound output routed via a local PulseAudio TCP sink to Android's native audio engine.

---

## Prerequisites on Android

Before getting started, make sure you have the following installed on your Android device (64-bit ARM / `aarch64`):

1. **[Termux](https://github.com/termux/termux-app/releases)**: The terminal emulator and Linux environment for Android (install the APK from GitHub releases or F-Droid; do **not** use the deprecated Google Play Store version).
2. **[Termux-X11](https://github.com/termux/termux-x11/releases)**: The X11 display server companion APK for Android that renders desktop windows with hardware acceleration.

---

## Quick Start Guide

### Step 1: Clone and Run Setup in Termux
Open the **Termux** app on your phone and run:

```bash
# Clone the repository
git clone https://github.com/icestmc792-source/Domrei.git
cd Domrei

# Make scripts executable
chmod +x setup.sh launch.sh scripts/*.sh

# Run the automated setup
./setup.sh
```

The [setup.sh](file:///workspaces/Domrei/setup.sh) script will:
1. Validate your device architecture (`aarch64`).
2. Install `proot-distro`, `pulseaudio`, and `x11-repo`.
3. Provision a Debian Linux container.
4. Download and install official, unmodified **Eclipse Temurin® OpenJDK 21** and **17** directly from the Adoptium API.
5. Set up Mesa graphics drivers (Zink + Turnip) and Prism Launcher.

---

### Step 2: Launch Minecraft
Whenever you want to play, open Termux and run:

```bash
cd Domrei
./launch.sh
```

[launch.sh](file:///workspaces/Domrei/launch.sh) automatically:
- Starts the **PulseAudio** audio daemon.
- Initializes the **Termux-X11** display server.
- Opens the **Termux:X11** app in full-screen.
- Launches **Prism Launcher** accelerated by Mesa Zink and running on Eclipse Temurin OpenJDK.

---

## Repository Structure

```
Domrei/
├── README.md                     # Project overview and user guide
├── setup.sh                      # One-command installer for Android Termux
├── launch.sh                     # Everyday game launcher script
├── config/
│   ├── jvm_options.conf          # Mobile ARM64 optimized JVM flags (G1GC, RAM sizing)
│   └── termux-x11.conf           # Recommended Termux-X11 preferences
├── scripts/
│   ├── install_temurin.sh        # Adoptium API downloader & SHA-256 validator
│   ├── guest_setup.sh            # In-container package provisioning script
│   ├── run_minecraft.sh          # Direct CLI launcher for Minecraft server/client
│   └── test_jvm.sh               # JVM diagnostics and JIT compilation benchmark
└── docs/
    └── ARCHITECTURE.md           # Systems architecture, ABI differences & pipelines
```

---

## OpenJDK Version Matrix

| Minecraft Version | Required Java Version | Default Temurin Path | Installed by Domrei |
| :--- | :--- | :--- | :--- |
| **1.20.5 – 1.21+** | **Java 21** | `/opt/temurin-jdk-21` | Yes (System default) |
| **1.17 – 1.20.4** | **Java 17** | `/opt/temurin-jdk-17` | Yes |
| **1.12.2 and older** | **Java 8** | `/opt/temurin-jdk-8` | Optional |

To install an additional version of Eclipse Temurin manually:
```bash
# Inside the container:
./scripts/install_temurin.sh --version 17 --dest /opt/temurin-jdk-17
```

---

## Performance & Optimization

### 1. Memory Tuning
Edit [config/jvm_options.conf](file:///workspaces/Domrei/config/jvm_options.conf) to match your device's physical RAM:

- **Devices with 6 GB RAM**: Set `-Xms1536M -Xmx2560M`
- **Devices with 8 GB – 12 GB RAM**: Set `-Xms2048M -Xmx4096M` (Default)
- **Devices with 16 GB+ RAM**: Set `-Xms4096M -Xmx8192M`

### 2. Recommended Mods for Mobile ARM64
For maximum framerates (60–120 FPS on Snapdragon 870/888/8 Gen 1/2/3):
- **Fabric Loader**
- **Sodium** (Modern rendering engine for Minecraft)
- **Lithium** (Physics and server tick optimization)
- **FerriteCore** (Memory usage reduction)
- **Entity Culling** (Skips rendering entities behind walls)

### 3. GPU Driver Selection
- **Qualcomm Snapdragon (Adreno GPUs)**: Uses open-source **Turnip + Zink**, providing near-native desktop OpenGL 4.6.
- **MediaTek / Exynos (Mali / Xclipse GPUs)**: Uses system Vulkan with Zink or VirGL fallback.

---

## Verifying the Unmodified JVM

To confirm that the JVM running is indeed official, unmodified Eclipse Temurin HotSpot aarch64, execute the diagnostic benchmark:

```bash
./scripts/test_jvm.sh
```

Example output:
```
==========================================================
  Eclipse Temurin® OpenJDK Runtime Diagnostics & Benchmark
==========================================================
[*] Java Runtime Diagnostics:
    - Vendor:       Eclipse Adoptium
    - VM Name:      OpenJDK 64-Bit Server VM
    - VM Version:   21.0.13+9
    - VM Info:      mixed mode, sharing
    - Architecture: aarch64
    - Data Model:   64-bit
[*] Executing JIT Micro-Benchmark (Warmup & Compilation)...
    - Time elapsed: 182 ms
[✓] JIT Compilation confirmed active and generating native code!
```

---

## Architecture Deep Dive

For an in-depth breakdown of `glibc` vs `bionic`, `PTRACE_SYSEMU` syscall virtualization, and the Mesa Zink graphics pipeline, see [docs/ARCHITECTURE.md](file:///workspaces/Domrei/docs/ARCHITECTURE.md).

---

## License

This project is open-source under the Apache 2.0 License. Eclipse Temurin® is a registered trademark of the Eclipse Foundation. Minecraft is a trademark of Mojang AB / Microsoft.
