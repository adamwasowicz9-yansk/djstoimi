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

# Patch base system
DECODE_OMC "$FIRM_DIR/$TARGET_DEVICE"
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE"
APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"
PATCH_SELINUX "$FIRM_DIR/$TARGET_DEVICE"
DISABLE_SECURITY "$FIRM_DIR/$TARGET_DEVICE"
ADD_SAMSUNG_FLAGSHIP_APPS "$FIRM_DIR/$TARGET_DEVICE"
APPLY_CUSTOM_FEATURES "$FIRM_DIR/$TARGET_DEVICE"

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
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" " [CrapUI $VERSION] "
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.build.display.id" " [CrapUI $VERSION] "

# Set device model spoofing
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.product.model" "SM-A528B"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.product.system.model" "SM-A528B"

# ==========================================
# CrapUI - System Tweaks
# ==========================================

echo "⚙️ Injecting performance, battery and network tweaks..."

# 1. UI Rendering & 120Hz Smoothness (Optimized for SkiaGL)
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.performance.tuning" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.composition.type" "gpu"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.composition.type" "gpu"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.sf.hw" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.ui.hw" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.enable.hw_accel" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.hwui.renderer" "skiagl"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "view.scroll_friction" "0.005"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "view.scroll_friction" "0.005"

# 2. RAM Management & DHA Optimization
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_cached_max" "12"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.dha_cached_max" "12"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_empty_max" "24"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.dha_empty_max" "24"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_step" "2"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.dha_step" "2"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_th_rate" "1.8"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.dha_th_rate" "1.8"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.purgeable_assets" "1"

# 3. Boot Speed & Fling Velocity
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.sys.fw.bg_apps_limit" "32"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.sys.fw.bg_apps_limit" "32"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.sys.fw.use_trim_settings" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.sys.fw.use_trim_settings" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "windowsmgr.max_events_per_sec" "240"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.min.fling_velocity" "8000"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.min.fling_velocity" "8000"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.max.fling_velocity" "20000"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.max.fling_velocity" "20000"

# 4. Deep Sleep & Power Saving
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "pm.sleep_mode" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "pm.sleep_mode" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.hw_power_saving" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.hw_power_saving" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.am.reschedule_service" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.am.reschedule_service" "true"

# 5. Disable Logs & Telemetry
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "profiler.force_disable_err_rpt" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "profiler.force_disable_ulog" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.nocheckin" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.nocheckin" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.kernel.android.checkjni" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.use_dithering" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.debug.sensors.hub.log" "0"

# 6. Network, Wi-Fi & RIL Enhancements
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.telephony.call_ring.delay" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.telephony.call_ring.delay" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.lge.proximity.delay" "25"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.mot.buttonlight.timeout" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.ril.disable.power.collapse" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.ril.power.collapse" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.ril.power.collapse" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.fast.dormancy" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.fast.dormancy" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.ril.fast.dormancy.rule" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.ril.fast.dormancy.rule" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "net.tcp.buffersize.wifi" "4096,87380,256144,4096,16384,256144"

# Build image
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "all" "$OUTPUT_FILESYSTEM" "$OUT_DIR"

