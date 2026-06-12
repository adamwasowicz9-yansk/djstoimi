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

# ====================================================================
# DODATKOWY PATCH: AUTO-CONFIRM 4-DIGIT PIN (UN1CA FEATURE)
# ====================================================================
echo "--> Aplikowanie patcha auto-confirm PIN do services.jar..."
LSS_SMALI="$WORK_DIR/services/smali/com/android/server/locksettings/LockSettingsService.smali"
SPM_SMALI="$WORK_DIR/services/smali/com/android/server/locksettings/SyntheticPasswordManager.smali"

if [ -f "$LSS_SMALI" ]; then
    echo "Patchowanie LockSettingsService.smali..."
    sed -i '/refreshStoredPinLength(I)Z/,/end method/ s/const\/4 v0, 0x6/const\/4 v0, 0x4/' "$LSS_SMALI"
fi

if [ -f "$SPM_SMALI" ]; then
    echo "Patchowanie SyntheticPasswordManager.smali..."
    sed -i '/createLskfBasedProtector/,/end method/ s/const\/4 v12, 0x6/const\/4 v12, 0x4/' "$SPM_SMALI"
fi

# Patchowanie SecSettings.apk (Ustawienia, PIN i Wywalanie Podręcznika oraz Zdalnego Zarządzania)
if [ -f "$FIRM_DIR/$TARGET_DEVICE/system/system/priv-app/SecSettings/SecSettings.apk" ]; then
    echo "--> Rozpoczynam patchowanie SecSettings.apk..."
    "$APKTOOL" d -f -r "$FIRM_DIR/$TARGET_DEVICE/system/system/priv-app/SecSettings/SecSettings.apk" -o "$WORK_DIR/SecSettings_out"
    
    # 1. PIN Patch
    CLP_SMALI="$WORK_DIR/SecSettings_out/smali/com/android/settings/password/ChooseLockPassword\$ChooseLockPasswordFragment.smali"
    if [ -f "$CLP_SMALI" ]; then
        echo "Aplikowanie poprawek smali w ChooseLockPasswordFragment..."
        sed -i '/handleNext\$2()V/,/end method/ s/const\/4 v4, 0x6/const\/4 v4, 0x4/' "$CLP_SMALI"
        sed -i '/setAutoPinConfirmOption(IZ)V/,/end method/ s/const\/4 p2, 0x6/const\/4 p2, 0x4/' "$CLP_SMALI"
    fi

    # 2. Patch usuwający "Podręcznik użytkownika" i "Zdalne zarządzanie" z głównego menu Ustawień
    echo "Ukrywanie Podręcznika użytkownika i Zdalnego zarządzania z głównego menu..."
    TOP_XML="$WORK_DIR/SecSettings_out/res/xml/top_level_settings.xml"
    
    if [ -f "$TOP_XML" ]; then
        sed -i 's/android:key="online_help"/android:key="online_help" android:visible="false"/g' "$TOP_XML"
        sed -i 's/android:key="user_manual"/android:key="user_manual" android:visible="false"/g' "$TOP_XML"
        sed -i 's/android:key="remote_support"/android:key="remote_support" android:visible="false"/g' "$TOP_XML"
        sed -i 's/android:key="omc_remote_support"/android:key="omc_remote_support" android:visible="false"/g' "$TOP_XML"
    else
        find "$WORK_DIR/SecSettings_out/res/xml/" -type f -name "*.xml" | while read -r xml_file; do
            if grep -q 'key="online_help"' "$xml_file" || grep -q 'key="remote_support"' "$xml_file"; then
                sed -i 's/android:key="online_help"/android:key="online_help" android:visible="false"/g' "$xml_file"
                sed -i 's/android:key="user_manual"/android:key="user_manual" android:visible="false"/g' "$xml_file"
                sed -i 's/android:key="remote_support"/android:key="remote_support" android:visible="false"/g' "$xml_file"
                sed -i 's/android:key="omc_remote_support"/android:key="omc_remote_support" android:visible="false"/g' "$xml_file"
            fi
        done
    fi
    
    echo "Kompilacja zwrotna SecSettings.apk..."
    "$APKTOOL" b "$WORK_DIR/SecSettings_out" -o "$FIRM_DIR/$TARGET_DEVICE/system/system/priv-app/SecSettings/SecSettings.apk"
    rm -rf "$WORK_DIR/SecSettings_out"
fi

# ====================================================================
# DODATKOWY PATCH: ADVANCED POWER MENU (REBOOT TO RECOVERY/BOOTLOADER)
# ====================================================================
echo "--> Aplikowanie patcha Advanced Power Menu..."
PWM_SMALI="$WORK_DIR/services/smali/com/android/server/policy/PhoneWindowManager.smali"
if [ -f "$PWM_SMALI" ]; then
    echo "Patchowanie PhoneWindowManager.smali pod kątem Advanced Reboot..."
    sed -i 's/isAdvancedRebootEnabled()Z/isAdvancedRebootEnabled_disabled()Z/g' "$PWM_SMALI"
fi
# ====================================================================

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

# === DODATKOWE PATCHES BUILD.PROP (fingerprint, opis, produkt) ===
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.product.system.name" "a52sxqxx"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.product.system.device" "a52sxq"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.system.build.fingerprint" "samsung/a52sxqxx/a52sxq:11/RP1A.200720.012/A528BXXSBGYI3:user/release-keys"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.description" "a52sxqxx-user 11 RP1A.200720.012 A528BXXSBGYI3 release-keys"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.product" "a52sxq"

# ====================================================================
# CRAPUI TWEAKS - SYSTEM & PRODUCT PROPERTIES (NON-VENDOR)
# ====================================================================
echo "⚙️ Injecting optimized non-vendor tweaks into system and product props..."

# 1. UI Rendering & HWUI Cache (Płynność 120Hz bez dropów)
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

# 6. Aktywacja Advanced Power Menu na poziomie właściwości systemowych
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.atom.advanced_reboot" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "persist.atom.advanced_reboot" "1"

# 7. Samsung DeX Standalone Mode (Tablet-like DeX on device screen)
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "const.coexist.device" "tablet"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "const.coexist.device" "tablet"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.config.knox.dex.standalone" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.config.knox.dex.standalone" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "persist.sys.dex.standalone" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "persist.sys.dex.standalone" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.dex.standalone.ux" "true"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.dex.standalone.ux" "true"

# ====================================================================
# INJECT FLOATING FEATURE ACCENTS
# ====================================================================
FLOATING_XML="$FIRM_DIR/$TARGET_DEVICE/product/etc/sysconfig/floating_feature.xml"
if [ -f "$FLOATING_XML" ]; then
    echo "--> Patchowanie floating_feature.xml pod DeX Standalone..."
    if grep -q "SEC_FLOATING_FEATURE_COMMON_SUPPORT_DEX" "$FLOATING_XML"; then
        sed -i 's|<SEC_FLOATING_FEATURE_COMMON_SUPPORT_DEX>.*</SEC_FLOATING_FEATURE_COMMON_SUPPORT_DEX>|<SEC_FLOATING_FEATURE_COMMON_SUPPORT_DEX>support,phone,standalone,wireless,desktop,pad</SEC_FLOATING_FEATURE_COMMON_SUPPORT_DEX>|g' "$FLOATING_XML"
    else
        sed -i 's|</SecFloatingFeatureSet>|    <SEC_FLOATING_FEATURE_COMMON_SUPPORT_DEX>support,phone,standalone,wireless,desktop,pad</SEC_FLOATING_FEATURE_COMMON_SUPPORT_DEX>\n</SecFloatingFeatureSet>|g' "$FLOATING_XML"
    fi
fi
# ====================================================================

# Build image
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "all" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
