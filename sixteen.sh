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

# ====================================================================
# SEKCJA: Pobieranie i Ekstrakcja Firmware dla STOCK_DEVICE (np. A52s)
# ====================================================================
export STOCK_DIR="$FIRM_DIR/$STOCK_DEVICE"

if [ -n "$STOCK_DEVICE" ] && [ "$STOCK_DEVICE" != "None" ]; then
    echo "======================================================"
    echo " PRZYGOTOWYWANIE STOCK Fw DLA SYSTEMU BAZOWEGO ($STOCK_DEVICE)"
    echo "======================================================"
    
    # 1. Pobieranie obrazów stockowych (QuantumRom.sh)
    DOWNLOAD_FIRMWARE "$STOCK_DEVICE" "$TARGET_DEVICE_CSC" "$TARGET_DEVICE_IMEI" "$FIRM_DIR"
    
    # 2. Ekstrakcja archiwów i dekompresja lz4
    EXTRACT_FIRMWARE "$STOCK_DIR"
    
    # 3. Rozpakowanie super.img dla Stocka
    EXTRACT_SUPER_IMG "$STOCK_DIR"
    
    # Ograniczamy ekstrakcję obrazów Stocka tylko do system i product dla oszczędności czasu
    OLD_PARTITIONS="$BUILD_PARTITIONS"
    export BUILD_PARTITIONS="system,product"
    
    EXTRACT_FIRMWARE_IMG "$STOCK_DIR" "all"
    
    # Przywracamy domyślne partycje dla portu
    export BUILD_PARTITIONS="$OLD_PARTITIONS"
fi

# ====================================================================
# SEKCJA: Ekstrakcja Docelowego Firmware Portu
# ====================================================================
echo "======================================================"
echo " EKSTRAKCJA DOCELOWEGO FIRMWARE PORTU ($TARGET_DEVICE)"
echo "======================================================"
EXTRACT_SUPER_IMG "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE" "all"

# Patch base system
DECODE_OMC "$FIRM_DIR/$TARGET_DEVICE"
APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"

# ====================================================================
# SEKCJA: Automatyczne Kopiowanie Właściwości ze Stocka do Portu
# ====================================================================
if [ -d "$STOCK_DIR" ]; then
    PATCH_BUILD_PROPS_FROM_STOCK "$STOCK_DIR" "$FIRM_DIR/$TARGET_DEVICE"
fi

# Set ROM display info
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" "QuantumROM Sixteen"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.quantum.version" "$VERSION"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.quantum.build.type" "Official"

# Fixes
FIX_BT "$FIRM_DIR/$TARGET_DEVICE"
FIX_SECURE_FOLDER "$FIRM_DIR/$TARGET_DEVICE"
FIX_WALLPAPER_CRASH "$FIRM_DIR/$TARGET_DEVICE"
FIX_PRINTING_CRASH "$FIRM_DIR/$TARGET_DEVICE"
FIX_AUTO_ROTATE_CRASH "$FIRM_DIR/$TARGET_DEVICE"
FIX_ADB "$FIRM_DIR/$TARGET_DEVICE"
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE"
ADD_WALLPAPERS "$FIRM_DIR/$TARGET_DEVICE"

if [ "$USE_UI_8_TETHERING_APEX" = "True" ]; then
    REPLACE_TETHERING_APEX "$FIRM_DIR/$TARGET_DEVICE"
fi

if [ "$STOCK_DEVICE" = "SM-A528B" ]; then
    A52S_AUDIO_FIX "$FIRM_DIR/$TARGET_DEVICE"
fi

APPLY_OMC_MODS "$FIRM_DIR/$TARGET_DEVICE"

# Build firmware
BUILD_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE" "all"
BUILD_SUPER_IMG "$FIRM_DIR/$TARGET_DEVICE" "$OUT_DIR"
