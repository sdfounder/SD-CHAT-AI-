#!/usr/bin/env bash
set -e

ADB="/home/sekoudiaby433/android-sdk/platform-tools/adb"
APK="/home/sekoudiaby433/SD-CHAT-AI/mobile/build/app/outputs/flutter-apk/app-release.apk"
PACKAGE="com.sd.chat.sd_chat_ai"

echo "=== VÉRIFICATION DU PÉRIPHÉRIQUE ADB ==="
$ADB devices -l

DEVICE_COUNT=$($ADB devices | grep -v "List" | grep "device" | wc -l)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "⚠️ Aucun téléphone détecté en mode ADB."
    echo "1. Connectez votre téléphone par câble USB."
    echo "2. Sur votre Chromebook : autorisez le partage USB avec Linux."
    echo "3. Sur votre téléphone : acceptez la demande 'Autoriser le débogage USB'."
    exit 1
fi

DEVICE_ID=$($ADB devices | grep -v "List" | grep "device" | head -n1 | awk '{print $1}')
echo "📱 Appareil détecté : $DEVICE_ID"

echo "📦 Installation de SD CHAT AI officiel signé ($APK)..."
$ADB -s "$DEVICE_ID" install -r -d "$APK"

echo "🚀 Lancement de SD CHAT AI sur le smartphone..."
$ADB -s "$DEVICE_ID" shell am start -W -n "$PACKAGE/.MainActivity"

echo "✅ SD CHAT AI V1 officiel signé est installé et ouvert sur votre téléphone !"
