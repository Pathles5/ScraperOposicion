#!/usr/bin/env bash
set -euo pipefail

# Rutas asumidas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INSTALL_DIR="/opt/scraper-oposicion"
ENV_DIR="/etc/scraper-oposicion"
ENV_FILE="${ENV_DIR}/telegram.env"

echo "[install] Proyecto: ${PROJECT_DIR}"
echo "[install] Destino:  ${INSTALL_DIR}"

# 1) Crear /opt/scraper-oposicion (si no existe)
if [[ ! -d "${INSTALL_DIR}" ]]; then
  echo "[install] Creando ${INSTALL_DIR}…"
  sudo mkdir -p "${INSTALL_DIR}"
  sudo chown "$(whoami)":"$(whoami)" "${INSTALL_DIR}"
fi

# 2) Copiar proyecto (solo lo necesario: monitor.js, sites.json, package.json, eslint, etc.)
echo "[install] Copiando ficheros del proyecto…"
sudo rsync -a --delete \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='state' \
  --exclude='logs' \
  "${PROJECT_DIR}/" "${INSTALL_DIR}/"

# 3) Asegurar logs/ con permisos
sudo mkdir -p "${INSTALL_DIR}/logs"
sudo chown "$(whoami)":"$(whoami)" "${INSTALL_DIR}/logs"

# 4) Crear /etc/scraper-oposicion si no existe
if [[ ! -d "${ENV_DIR}" ]]; then
  echo "[install] Creando ${ENV_DIR}…"
  sudo mkdir -p "${ENV_DIR}"
  sudo chown root:root "${ENV_DIR}"
  sudo chmod 750 "${ENV_DIR}"
fi

# 5) Crear telegram.env si no existe (a partir del .example)
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "[install] Creando ${ENV_FILE} (PLACEHOLDER — rellena con tus credenciales)…"
  sudo cp "${SCRIPT_DIR}/telegram.env.example" "${ENV_FILE}"
  sudo chmod 640 "${ENV_FILE}"
  echo "  >> Edita ${ENV_FILE} con: sudo nano ${ENV_FILE}"
fi

# 6) Instalar units systemd
echo "[install] Instalando units systemd…"
sudo cp "${SCRIPT_DIR}/scraper.service" /etc/systemd/system/scraper.service
sudo cp "${SCRIPT_DIR}/scraper.timer" /etc/systemd/system/scraper.timer
sudo chmod 644 /etc/systemd/system/scraper.service /etc/systemd/system/scraper.timer
sudo systemctl daemon-reload

# 7) Habilitar y arrancar el timer
sudo systemctl enable scraper.timer
sudo systemctl restart scraper.timer

echo "[install] Hecho. Comandos útiles:"
echo "  systemctl status scraper.timer"
echo "  systemctl list-timers scraper.timer"
echo "  journalctl -u scraper.service -f"
