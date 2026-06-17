#!/bin/bash

if [ "$#" -lt 7 ]; then
    echo "Usage: $0 <STOCK_DEVICE> <USE_UI_8_TETHERING_APEX> <TARGET_DEVICE> <TARGET_DEVICE_CSC> <TARGET_DEVICE_IMEI> <OUTPUT_FILESYSTEM> <CRAP_VERSION>"
    exit 1
fi

# Device info
export STOCK_DEVICE="$1"
export USE_UI_8_TETHERING_APEX="$2"
export TARGET_DEVICE="$3"
export TARGET_DEVICE_CSC="$4"
export TARGET_DEVICE_IMEI="$5"
export OUTPUT_FILESYSTEM="$6"
export VERSION="$7"

# Directories
export FIRM_DIR="$(pwd)/FW"
export OUT_DIR="$(pwd)/OUT"
export WORK_DIR="$(pwd)/WORK"
export APKTOOL="$(pwd)/bin/java/apktool.jar"
export DEVICES_DIR="$(pwd)/QuantumROM/Devices"
export VNDKS_COLLECTION="$(pwd)/QuantumROM/vndks"
export SMART_MANAGER_CN="$(pwd)/QuantumROM/Mods/SMART_MANAGER_CN"

export BUILD_PARTITIONS="product,system_ext,system"

# Source
source "$(pwd)/scripts/debloat.sh"
source "$(pwd)/scripts/QuantumRom.sh"

# Extract firmware
EXTRACT_SUPER_IMG "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE" "all"

# Patch base system (Zmieniona kolejność: DEBLOAT na samym końcu po dodaniu aplikacji flagowych)
DECODE_OMC "$FIRM_DIR/$TARGET_DEVICE"
APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"
PATCH_SELINUX "$FIRM_DIR/$TARGET_DEVICE"
DISABLE_SECURITY "$FIRM_DIR/$TARGET_DEVICE"
ADD_SAMSUNG_FLAGSHIP_APPS "$FIRM_DIR/$TARGET_DEVICE"
APPLY_CUSTOM_FEATURES "$FIRM_DIR/$TARGET_DEVICE"

# OSTATECZNE CZYSZCZENIE SYSTEMU
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE"

# Framework modifications
INSTALL_FRAMEWORK "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/framework-res.apk"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/ssrm.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/services.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/samsungkeystoreutils.jar" "$WORK_DIR"

PATCH_SSRM "$WORK_DIR/ssrm"
PATCH_FLAG_SECURE "$WORK_DIR/services"
PATCH_SECURE_FOLDER "$WORK_DIR/services"
PATCH_PRIVATE_SHARE "$WORK_DIR/samsungkeystoreutils"

RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/ssrm" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/services" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/samsungkeystoreutils" "$WORK_DIR"
mv -f "$WORK_DIR"/*.jar "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/"

PATCH_BT_LIB "$FIRM_DIR/$TARGET_DEVICE" "$WORK_DIR"

# Set ROM display info
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" "[CrapUI $VERSION]"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.build.display.id" "[CrapUI $VERSION]"

# Set device model spoofing
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.product.model" "SM-A528B"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.product.system.model" "SM-A528B"

# =================================================================
# ALL CUSTOM TWEAKS CONSOLIDATED INTO SYSTEM PARTITION
# =================================================================

# 1. Hardware Graphics Pipeline & SkiaGL Renderer
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.hwui.renderer" "skiagl"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.sf.hw" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.egl.hw" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.performance.tuning" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.composition.type" "gpu"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "windowsmgr.max_events_per_sec" "150"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "view.scroll_friction" "0.008"

# 2. Advanced RAM & LMK Optimization
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.fha_enable" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.sys.fw.bg_apps_limit" "32"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_cached_max" "16"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_empty_max" "16"

# 3. Telemetry, Deep Logging & Error Reporting Disable
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.ssrm.fewer_log" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.nocheckin" "yes"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "profiler.force_disable_err_rpt" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "profiler.force_disable_ulog" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "logcat.live" "disable"

# 4. Multimedia Core Components Tuning
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "media.stagefright.audio.sink" "28672"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.media.enc.jpeg.quality" "100"

# =================================================================

# Build image
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "all" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
