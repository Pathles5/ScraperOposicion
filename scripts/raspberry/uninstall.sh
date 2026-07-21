#!/usr/bin/env bash
set -euo pipefail

echo "[uninstall] Deshabilitando timer y service…"
sudo systemctl disable --now scraper.timer || true
sudo systemctl stop scraper.service || true

sudo rm -f /etc/systemd/system/scraper.service
sudo rm -f /etc/systemd/system/scraper.timer
sudo systemctl daemon-reload

echo "[uninstall] Hecho."
echo "  /opt/scraper-oposicion NO se borra (contiene state/ con tus fingerprints)."
echo "  Para borrarlo: sudo rm -rf /opt/scraper-oposicion"
echo "  /etc/scraper-oposicion NO se borra (contiene telegram.env)."
echo "  Para borrarlo: sudo rm -rf /etc/scraper-oposicion"
