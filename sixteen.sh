#!/bin/bash

if [ "$#" -lt 9 ]; then
    echo "Usage: $0 <STOCK_DEVICE> <STOCK_DEVICE_CSC> <STOCK_DEVICE_IMEI> <USE_UI_8_TETHERING_APEX> <TARGET_DEVICE> <TARGET_DEVICE_CSC> <TARGET_DEVICE_IMEI> <OUTPUT_FILESYSTEM> <CRAP_VERSION>"
    exit 1
fi

# Zmienne wejściowe z GitHub Actions
export STOCK_DEVICE="$1"
export STOCK_DEVICE_CSC="$2"
export STOCK_DEVICE_IMEI="$3"
export USE_UI_8_TETHERING_APEX="$4"
export TARGET_DEVICE="$5"
export TARGET_DEVICE_CSC="$6"
export TARGET_DEVICE_IMEI="$7"
export OUTPUT_FILESYSTEM="$8"
export VERSION="$9"

# Ścieżki robocze
export FIRM_DIR="$(pwd)/FW"
export OUT_DIR="$(pwd)/OUT"
export WORK_DIR="$(pwd)/WORK"
export APKTOOL="$(pwd)/bin/java/apktool.jar"
export DEVICES_DIR="$(pwd)/QuantumROM/Devices"
export VNDKS_COLLECTION="$(pwd)/QuantumROM/vndks"
export SMART_MANAGER_CN="$(pwd)/QuantumROM/Mods/SMART_MANAGER_CN"

export BUILD_PARTITIONS="product,system_ext,system"

# Załadowanie skryptów pomocniczych
source "$(pwd)/scripts/debloat.sh"
source "$(pwd)/scripts/QuantumRom.sh"

# ====================================================================
# SEKCJA: Pobieranie i Ekstrakcja Firmware dla STOCK_DEVICE (np. A52s)
# ====================================================================
export STOCK_DIR="$FIRM_DIR/$STOCK_DEVICE"

if [ -n "$STOCK_DEVICE" ] && [ "$STOCK_DEVICE" != "None" ]; then
    echo "======================================================"
    echo " PRZYGOTOWYWANIE STOCK Fw DLA SYSTEMU BAZOWEGO ($STOCK_DEVICE)"
    echo " CSC: $STOCK_DEVICE_CSC | IMEI: $STOCK_DEVICE_IMEI"
    echo "======================================================"
    
    # 1. Pobieranie obrazów za pomocą przekazanych dedykowanych parametrów ze stocka
    DOWNLOAD_FIRMWARE "$STOCK_DEVICE" "$STOCK_DEVICE_CSC" "$STOCK_DEVICE_IMEI" "$FIRM_DIR"
    
    # 2. Rozpakowanie archiwów i dekompresja pliku .lz4
    EXTRACT_FIRMWARE "$STOCK_DIR"
    
    # 3. Rozpakowanie obrazu super.img dla Stocka
    EXTRACT_SUPER_IMG "$STOCK_DIR"
    
    # Przełączamy ekstrakcję obrazów tylko na system i product w celu optymalizacji czasu
    OLD_PARTITIONS="$BUILD_PARTITIONS"
    export BUILD_PARTITIONS="system,product"
    
    EXTRACT_FIRMWARE_IMG "$STOCK_DIR" "all"
    
    # Powrót do domyślnych partycji wymaganych przez portowany system
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
# SEKCJA: Szybka podmiana i uzupełnienie build.prop (Stock -> Target)
# ====================================================================
if [ -d "$STOCK_DIR" ]; then
    PATCH_BUILD_PROPS_FROM_STOCK "$STOCK_DIR" "$FIRM_DIR/$TARGET_DEVICE"
fi

# Set ROM display info
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" "QuantumROM Sixteen"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.quantum.version" "$VERSION"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.quantum.build.type" "Official"

# Naprawy i Debloat (zgodnie z pierwotnym skryptem)
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

# Kompilacja finalna oprogramowania
BUILD_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE" "all"
BUILD_SUPER_IMG "$FIRM_DIR/$TARGET_DEVICE" "$OUT_DIR"
