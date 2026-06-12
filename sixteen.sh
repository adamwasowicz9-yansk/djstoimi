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

# Patchowanie SecSettings.apk (Ustawienia menu Lockscreena)
if [ -f "$FIRM_DIR/$TARGET_DEVICE/system/system/priv-app/SecSettings/SecSettings.apk" ]; then
    echo "--> Rozpoczynam patchowanie SecSettings.apk..."
    "$APKTOOL" d -f -r "$FIRM_DIR/$TARGET_DEVICE/system/system/priv-app/SecSettings/SecSettings.apk" -o "$WORK_DIR/SecSettings_out"
    
    CLP_SMALI="$WORK_DIR/SecSettings_out/smali/com/android/settings/password/ChooseLockPassword\$ChooseLockPasswordFragment.smali"
    
    if [ -f "$CLP_SMALI" ]; then
        echo "Aplikowanie poprawek smali w ChooseLockPasswordFragment..."
        sed -i '/handleNext\$2()V/,/end method/ s/const\/4 v4, 0x6/const\/4 v4, 0x4/' "$CLP_SMALI"
        sed -i '/setAutoPinConfirmOption(IZ)V/,/end method/ s/const\/4 p2, 0x6/const\/4 p2, 0x4/' "$CLP_SMALI"
        
        echo "Kompilacja zwrotna SecSettings.apk..."
        "$APKTOOL" b "$WORK_DIR/SecSettings_out" -o "$FIRM_DIR/$TARGET_DEVICE/system/system/priv-app/SecSettings/SecSettings.apk"
    fi
    rm -rf "$WORK_DIR/SecSettings_out"
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
#skia
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.hwui.renderer" "skiagl"

# Build image
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "all" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
