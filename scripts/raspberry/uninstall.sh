#!/usr/bin/env bash
set -euo pipefail

# Si el usuario pasó una ruta de instalación personalizada a install.sh,
# debe pasarla también aquí. Default: /opt/scraper-oposicion.
INSTALL_DIR="${1:-/opt/scraper-oposicion}"
ENV_DIR="/etc/scraper-oposicion"

echo "[uninstall] Deshabilitando timer y service…"
sudo systemctl disable --now scraper.timer || true
sudo systemctl stop scraper.service || true

sudo rm -f /etc/systemd/system/scraper.service
sudo rm -f /etc/systemd/system/scraper.timer
sudo systemctl daemon-reload

echo "[uninstall] Hecho."
echo "  ${INSTALL_DIR} NO se borra (contiene state/ con tus fingerprints)."
echo "  Para borrarlo: sudo rm -rf ${INSTALL_DIR}"
echo "  ${ENV_DIR} NO se borra (contiene telegram.env)."
echo "  Para borrarlo: sudo rm -rf ${ENV_DIR}"
echo "  /etc/scraper-oposicion NO se borra (contiene telegram.env)."
echo "  Para borrarlo: sudo rm -rf /etc/scraper-oposicion"
