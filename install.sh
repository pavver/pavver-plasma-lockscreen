#!/usr/bin/env bash
# ==============================================================================
# Pavver Plasma Lock Screen Theme Installation Script
# ==============================================================================

set -euo pipefail

THEME_ID="pavver-plasma-lockscreen"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_TARGET_DIR="${HOME}/.local/share/plasma/look-and-feel/${THEME_ID}"
SYSTEM_TARGET_DIR="/usr/share/plasma/look-and-feel/${THEME_ID}"

echo "======================================================="
echo "   Встановлення теми блокування Plasma: ${THEME_ID}"
echo "======================================================="

if [ "${EUID}" -eq 0 ]; then
    TARGET_DIR="${SYSTEM_TARGET_DIR}"
    echo "(!) Встановлення у загальносистемний каталог: ${TARGET_DIR}"
else
    TARGET_DIR="${USER_TARGET_DIR}"
    echo "(!) Встановлення у каталог поточного користувача: ${TARGET_DIR}"
fi

TARGET_PARENT="$(dirname "${TARGET_DIR}")"
mkdir -p "${TARGET_PARENT}"

STAGING_DIR="$(mktemp -d "${TARGET_PARENT}/.${THEME_ID}.install.XXXXXX")"
BACKUP_DIR=""

cleanup() {
    if [ -n "${STAGING_DIR}" ] && [ -d "${STAGING_DIR}" ]; then
        rm -rf -- "${STAGING_DIR}"
    fi
}
trap cleanup EXIT

echo "[1/3] Підготовка повного пакета теми..."
install -m 644 "${SCRIPT_DIR}/metadata.json" "${STAGING_DIR}/metadata.json"
cp -a "${SCRIPT_DIR}/contents" "${STAGING_DIR}/contents"

echo "[2/3] Встановлення прав і заміна попередньої версії..."
find "${STAGING_DIR}" -type d -exec chmod 755 {} +
find "${STAGING_DIR}" -type f -exec chmod 644 {} +

if [ -e "${TARGET_DIR}" ] || [ -L "${TARGET_DIR}" ]; then
    BACKUP_DIR="$(mktemp -d "${TARGET_PARENT}/.${THEME_ID}.backup.XXXXXX")"
    rmdir "${BACKUP_DIR}"
    mv -- "${TARGET_DIR}" "${BACKUP_DIR}"
fi

if mv -- "${STAGING_DIR}" "${TARGET_DIR}"; then
    STAGING_DIR=""
    if [ -n "${BACKUP_DIR}" ]; then
        rm -rf -- "${BACKUP_DIR}"
    fi
else
    if [ -n "${BACKUP_DIR}" ] && [ -e "${BACKUP_DIR}" ]; then
        mv -- "${BACKUP_DIR}" "${TARGET_DIR}"
    fi
    exit 1
fi
trap - EXIT

echo "[3/3] Активація теми в налаштуваннях екрана блокування Plasma..."
if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kscreenlockerrc --group Greeter --key Theme "${THEME_ID}"
    echo "      Оновлено kscreenlockerrc -> Theme=${THEME_ID}"
fi

echo "======================================================="
echo "Тему блокування успішно встановлено та активовано!"
echo "Для перевірки запустіть у терміналі:"
echo "/usr/lib/kscreenlocker_greet --testing"
echo "======================================================="
