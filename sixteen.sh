#!/bin/bash

if [ "$#" -lt 6 ]; then
    echo "Usage: $0 <STOCK_DEVICE> <USE_UI_8_TETHERING_APEX> <TARGET_DEVICE> <TARGET_DEVICE_CSC> <TARGET_DEVICE_IMEI> <OUTPUT_FILESYSTEM>"
    exit 1
fi

# Device info
export STOCK_DEVICE="$1"
export USE_UI_8_TETHERING_APEX="$2"
export TARGET_DEVICE="$3"
export TARGET_DEVICE_CSC="$4"
export TARGET_DEVICE_IMEI="$5"
export OUTPUT_FILESYSTEM="$6"

VERSION="1"

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

#EXTRACT_FIRMWARE "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_SUPER_IMG "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE" "all"

DECODE_OMC "$FIRM_DIR/$TARGET_DEVICE"
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE"

APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"
PATCH_SELINUX "$FIRM_DIR/$TARGET_DEVICE"
DISABLE_SECURITY "$FIRM_DIR/$TARGET_DEVICE"
ADD_SAMSUNG_FLAGSHIP_APPS "$FIRM_DIR/$TARGET_DEVICE"
APPLY_CUSTOM_FEATURES "$FIRM_DIR/$TARGET_DEVICE"

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

B_ID="$(grep -m1 '^ro.system.build.id=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"
B_V="$(grep -m1 '^ro.system.build.version.incremental=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" "${B_ID} ${B_V} V-${VERSION}: CrappyROM"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.build.display.id" "${B_ID} ${B_V} V-${VERSION}: CrappyROM"

# Patch device model to SM-A528B
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.product.model" "SM-A528B"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.product.system.model" "SM-A528B"

# ==========================================
# One UI 8.0 Performance & Battery Tweaks
# ==========================================

# Performance & GPU
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.performance.tuning" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "video.accelerate.hw" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.composition.type" "gpu"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.composition.type" "gpu"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.sf.hw" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "hw2d.force" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "hw3d.force" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.ui.hw" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.enable.hw_accel" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.hwui.renderer" "skiagl"

# Better RAM management
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_cached_max" "12"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_empty_max" "24"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_step" "2"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_th_rate" "1.8"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.purgeable_assets" "1"

# Faster boot & app launch
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.sys.fw.bg_apps_limit" "32"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.sys.fw.use_trim_settings" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.min.fling_velocity" "8000"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.max.fling_velocity" "20000"

# Disable logging & debugging (saves battery)
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "profiler.force_disable_err_rpt" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "profiler.force_disable_ulog" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.nocheckin" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.kernel.android.checkjni" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.use_dithering" "0"

# Call & RIL tweaks
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.telephony.call_ring.delay" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.lge.proximity.delay" "25"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.mot.buttonlight.timeout" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.ril.disable.power.collapse" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.ril.power.collapse" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "pm.sleep_mode" "1"

# Fast dormancy
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.fast.dormancy" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.ril.fast.dormancy.rule" "1"

# Disable SNS logs
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.debug.sensors.hub.log" "0"

# Better scrolling & UI smoothness
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "windowsmgr.max_events_per_sec" "240"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.max.fling_velocity" "12000"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.min.fling_velocity" "8000"

# Build image
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "all" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
