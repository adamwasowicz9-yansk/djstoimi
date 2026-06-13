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

# Funkcja pomocnicza implementująca zachowanie SMALI_PATCH z pliku customize.sh
apply_smali_patch() {
    local target_dir="$1"     # Katalog roboczy zdekompilowanej paczki (np. $WORK_DIR/services)
    local rel_file_path="$2"  # Ścieżka relatywna do pliku smali wewnątrz tego katalogu
    local search_text="$3"    # Tekst szukany
    local replace_text="$4"   # Tekst podmieniany

    local full_path="${target_dir}/${rel_file_path}"

    if [ -f "$full_path" ]; then
        sed -i "s|${search_text}|${replace_text}|g" "$full_path"
        echo "[PATCH] Pomyślnie zmodyfikowano: ${rel_file_path}"
    else
        echo "[PATCH] OSTRZEŻENIE: Plik ${full_path} nie istnieje!"
    fi
}

#EXTRACT_FIRMWARE "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_SUPER_IMG "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE" "all"

DECODE_OMC "$FIRM_DIR/$TARGET_DEVICE" "$WORK_DIR"

APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"
PATCH_SELINUX "$FIRM_DIR/$TARGET_DEVICE"
DISABLE_SECURITY "$FIRM_DIR/$TARGET_DEVICE"
ADD_SAMSUNG_FLAGSHIP_APPS "$FIRM_DIR/$TARGET_DEVICE"
APPLY_CUSTOM_FEATURES "$FIRM_DIR/$TARGET_DEVICE"

# DEBLOAT przeniesiony tutaj – wykonywany dopiero po dodaniu aplikacji flagowych i konfiguracji custom features
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE"

INSTALL_FRAMEWORK "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/framework-res.apk"

# --- DEKOMPILACJA JAR / APK ---
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/ssrm.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/services.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/samsungkeystoreutils.jar" "$WORK_DIR"
# Dekompilacja SecSettings.apk z partycji system do katalogu roboczego
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/priv-app/SecSettings/SecSettings.apk" "$WORK_DIR"

# --- STANDARDOWE MODYFIKACJE QUANTUM ---
PATCH_SSRM "$WORK_DIR/ssrm"
PATCH_FLAG_SECURE "$WORK_DIR/services"
PATCH_SECURE_FOLDER "$WORK_DIR/services"
PATCH_PRIVATE_SHARE "$WORK_DIR/samsungkeystoreutils"

# --- INTEGRACJA Z CUSTOMIZE.SH (Modyfikacja PIN z 6 na 4 cyfry dla auto-confirm) ---
echo "[CUSTOMIZE] Rozpoczynam aplikowanie patchy na długość kodu PIN (6 -> 4)..."

# 1. Patche dla services.jar
apply_smali_patch "$WORK_DIR/services" \
    "smali/com/android/server/locksettings/LockSettingsService.smali" \
    "const/4 v0, 0x6" \
    "const/4 v0, 0x4"

apply_smali_patch "$WORK_DIR/services" \
    "smali/com/android/server/locksettings/SyntheticPasswordManager.smali" \
    "const/4 v12, 0x6" \
    "const/4 v12, 0x4"

# 2. Patche dla SecSettings.apk (Znak $ w nazwie pliku maskowany jako \$)
apply_smali_patch "$WORK_DIR/SecSettings" \
    "smali/com/android/settings/password/ChooseLockPassword\$ChooseLockPasswordFragment.smali" \
    "const/4 v4, 0x6" \
    "const/4 v4, 0x4"

apply_smali_patch "$WORK_DIR/SecSettings" \
    "smali/com/android/settings/password/ChooseLockPassword\$ChooseLockPasswordFragment.smali" \
    "const/4 p2, 0x6" \
    "const/4 p2, 0x4"

echo "[CUSTOMIZE] Patchowanie ukończone."

# --- REKOMPILACJA JAR / APK ---
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/ssrm" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/services" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/samsungkeystoreutils" "$WORK_DIR"
# Rekompilacja zmodyfikowanego SecSettings.apk
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/SecSettings" "$WORK_DIR"

# Przeniesienie gotowych plików z powrotem do struktury ROMu
mv -f "$WORK_DIR"/*.jar "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/"
mv -f "$WORK_DIR"/SecSettings.apk "$FIRM_DIR/$TARGET_DEVICE/system/priv-app/SecSettings/SecSettings.apk"

# --- DALSZE OPERACJE ---
PATCH_BT_LIB "$FIRM_DIR/$TARGET_DEVICE" "$WORK_DIR"

B_ID="$(grep -m1 '^ro.system.build.id=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"
B_V="$(grep -m1 '^ro.system.build.version.incremental=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" "[CrapUI $VERSION]"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.build.display.id" "[CrapUI $VERSION]"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.performance.tuning" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.composition.type" "gpu"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.composition.type" "gpu"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.sf.hw" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.ui.hw" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.enable.hw_accel" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.hwui.renderer" "skiagl"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.texture_cache_size" "88"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.layer_cache_size" "58"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.r_buffer_cache_size" "8"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.path_cache_size" "32"

# Fling Velocity (Szybkość przewijania list)
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "view.scroll_friction" "0.005"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "view.scroll_friction" "0.005"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "windowsmgr.max_events_per_sec" "240"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.min.fling_velocity" "8000"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.min.fling_velocity" "8000"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.max.fling_velocity" "20000"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.max.fling_velocity" "20000"

# 2. Zarządzanie Ramem (DHA) & Wielozadaniowość
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_cached_max" "12"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.dha_cached_max" "12"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_empty_max" "24"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.dha_empty_max" "24"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_step" "2"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.dha_step" "2"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.dha_th_rate" "1.8"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.dha_th_rate" "1.8"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.purgeable_assets" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.sys.fw.bg_apps_limit" "32"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.sys.fw.bg_apps_limit" "32"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.sys.fw.use_trim_settings" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.sys.fw.use_trim_settings" "true"

# 3. Głębokie uśpienie i oszczędzanie baterii (Deep Sleep fixes)
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "pm.sleep_mode" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "pm.sleep_mode" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.hw_power_saving" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.hw_power_saving" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.am.reschedule_service" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.am.reschedule_service" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.smart_power" "1"

# 4. Wyłączenie logowania i telemetrii (Zwalnianie zasobów procesora)
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "profiler.force_disable_err_rpt" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "profiler.force_disable_ulog" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.nocheckin" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.nocheckin" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.kernel.android.checkjni" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.use_dithering" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.debug.sensors.hub.log" "0"

# 5. One UI 8 Network & RIL Enhancements
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.telephony.call_ring.delay" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.telephony.call_ring.delay" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.lge.proximity.delay" "25"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.ril.disable.power.collapse" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.ril.power.collapse" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.ril.power.collapse" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.fast.dormancy" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "fast.dormancy" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "net.tcp.buffersize.wifi" "4096,87380,256144,4096,16384,256144"

BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "all" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
