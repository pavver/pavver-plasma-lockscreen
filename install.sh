#!/usr/bin/env bash
# ==============================================================================
# Pavver Plasma Lock Screen Theme Installation Script
# ==============================================================================

set -e

THEME_ID="pavver-plasma-lockscreen"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_TARGET_DIR="${HOME}/.local/share/plasma/look-and-feel/${THEME_ID}"
SYSTEM_TARGET_DIR="/usr/share/plasma/look-and-feel/${THEME_ID}"

echo "======================================================="
echo "   Встановлення теми блокування Plasma: ${THEME_ID}"
echo "======================================================="

# Determine destination (user or system-wide)
if [ "$EUID" -eq 0 ]; then
    TARGET_DIR="${SYSTEM_TARGET_DIR}"
    echo "(!) Встановлення у загальносистемний каталог: ${TARGET_DIR}"
else
    TARGET_DIR="${USER_TARGET_DIR}"
    echo "(!) Встановлення у каталог поточного користувача: ${TARGET_DIR}"
fi

echo "[1/3] Копіювання файлів теми у ${TARGET_DIR}..."
mkdir -p "${TARGET_DIR}"
cp -rf "${SCRIPT_DIR}/metadata.json" "${TARGET_DIR}/"
cp -rf "${SCRIPT_DIR}/contents" "${TARGET_DIR}/"

echo "[2/3] Встановлення прав доступу..."
chmod -R 755 "${TARGET_DIR}"

echo "[3/3] Активація теми в налаштуваннях Plasma..."
if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage "${THEME_ID}"
    kwriteconfig6 --file kscreenlockerrc --group Greeter --key Theme "${THEME_ID}"
    echo "      Оновлено kdeglobals та kscreenlockerrc -> Theme=${THEME_ID}"
fi

echo "======================================================="
echo "Тему блокування успішно встановлено та активовано!"
echo "Для перевірки запустіть у терміналі:"
echo "/usr/lib/kscreenlocker_greet --testing"
echo "======================================================="
