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

# --- SEKCJA WYPAKOWYWANIA ROZBUDOWANA O SPRAWDZENIE SUPER.IMG ---
TARGET_FIRM_DIR="$FIRM_DIR/$TARGET_DEVICE"

echo "🔍 Sprawdzanie zawartości i przygotowywanie plików w $TARGET_FIRM_DIR..."

# Jeśli firmware.zip istnieje, rozpakuj go najpierw do katalogu urządzenia
if [ -f "$TARGET_FIRM_DIR/firmware.zip" ]; then
    echo "📦 Rozpakowywanie firmware.zip..."
    unzip -o -q "$TARGET_FIRM_DIR/firmware.zip" -d "$TARGET_FIRM_DIR"
    rm -f "$TARGET_FIRM_DIR/firmware.zip"
fi

# Główny warunek: Sprawdzenie obecności super.img
if [ -f "$TARGET_FIRM_DIR/super.img" ]; then
    echo "📦 Wykryto super.img! Uruchamiam standardowe rozpakowywanie kontenera..."
    EXTRACT_SUPER_IMG "$TARGET_FIRM_DIR"
else
    echo "⚠️  Brak super.img w paczce. Wykryto bezpośrednie obrazy partycji (.img)."
    echo "🚀 Pomijam lpunpack i przechodzę bezpośrednio do przygotowania obrazów..."
fi

# Wyciągnięcie/Konwersja pojedynczych obrazów (obsługuje sparse i raw img)
EXTRACT_FIRMWARE_IMG "$TARGET_FIRM_DIR" "all"

# Patch base system (Zmieniona kolejność: DEBLOAT na samym końcu po dodaniu aplikacji flagowych)
DECODE_OMC "$FIRM_DIR/$TARGET_DEVICE"

if [ "$STOCK_DEVICE" != "None" ]; then
    # Create patch workdir
    mkdir -p "$WORK_DIR"
    
    # Extract Stock files
    EXTRACT_FIRMWARE_IMG "$DEVICES_DIR/$STOCK_DEVICE" "all"
    
    # Contexts
    cp -r "$DEVICES_DIR/$STOCK_DEVICE/config" "$WORK_DIR/config"
    
    # -------------------------------------------------------------------------
    # System Porting Core
    # -------------------------------------------------------------------------
    
    # Copy stock device configs & binaries
    echo "⚡ Porting Device Configurations..."
    rm -rf "$FIRM_DIR/$TARGET_DEVICE/system/system/etc/vintf"
    cp -r "$DEVICES_DIR/$STOCK_DEVICE/system/system/etc/vintf" "$FIRM_DIR/$TARGET_DEVICE/system/system/etc/vintf"
    
    # Copy audio/camera/display configs if exists
    [ -d "$DEVICES_DIR/$STOCK_DEVICE/system/system/etc/audio" ] && cp -r "$DEVICES_DIR/$STOCK_DEVICE/system/system/etc/audio" "$FIRM_DIR/$TARGET_DEVICE/system/system/etc/"
    [ -f "$DEVICES_DIR/$STOCK_DEVICE/system/system/etc/camera" ] && cp -r "$DEVICES_DIR/$STOCK_DEVICE/system/system/etc/camera" "$FIRM_DIR/$TARGET_DEVICE/system/system/etc/"
    
    # Fix Permissions & Ownerships for ported files
    echo "🔧 Fixing Ported File Permissions..."
    chmod -R 644 "$FIRM_DIR/$TARGET_DEVICE/system/system/etc/vintf"/*
    find "$FIRM_DIR/$TARGET_DEVICE/system/system/etc/vintf" -type d -exec chmod 755 {} +
fi

echo "📱 Modyfikacja plików build.prop..."
# 1. UI Fluidity, Rendering & Touch Response
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.texture_cache_size" "72"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.layer_cache_size" "48"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.r_buffer_cache_size" "8"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.path_cache_size" "32"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.gradient_cache_size" "1"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.drop_shadow_cache_size" "6"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.texture_cache_flushrate" "0.4"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.text_large_cache_width" "2048"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.text_large_cache_height" "1024"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.text_small_cache_width" "1024"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.hwui.text_small_cache_height" "512"

BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.sf.disable_hwc" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.gr.numframebuffers" "3"
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
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.atrace.tags.enableflags" "0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "lineage.updater.uri" "null"

# Wywołanie debloatu na samym końcu procesu
DEBLOAT_FIRMWARE "$FIRM_DIR/$TARGET_DEVICE"

# Repack firmware
REBUILD_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE" "all"

if [ -f "$TARGET_FIRM_DIR/super.img" ]; then
    echo "📦 Pakowanie z powrotem do obrazu super..."
    REBUILD_SUPER_IMG "$FIRM_DIR/$TARGET_DEVICE"
else
    echo "ℹ️  Pominięto budowanie super.img (oryginalnie build oparty na pojedynczych .img)."
fi

# Przeniesienie gotowych plików wynikowych .img do folderu OUT
echo "🚚 Przenoszenie gotowych obrazów partycji do OUT..."
rm -rf "$OUT_DIR"/*
mkdir -p "$OUT_DIR"

if [ -f "$TARGET_FIRM_DIR/super.img" ]; then
    mv "$TARGET_FIRM_DIR/super.img" "$OUT_DIR/"
fi

# Zawsze kopiujemy system, product i system_ext, bez względu na to czy super powstawał czy nie
for part in system product system_ext; do
    if [ -f "$TARGET_FIRM_DIR/${part}.img" ]; then
        cp "$TARGET_FIRM_DIR/${part}.img" "$OUT_DIR/"
    fi
done

echo "✅ Wszystkie operacje zakończone pomyślnie!"
