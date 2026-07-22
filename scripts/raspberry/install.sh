#!/usr/bin/env bash
set -euo pipefail

# Rutas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# Destino del proyecto: arg1 si se pasa, si no /opt/scraper-oposicion.
# Si el usuario no pasa ruta y el proyecto NO está en /opt/scraper-oposicion,
# avisa para evitar el caso típico "cloné en ~/bots/... pero install.sh
# instaló por defecto en /opt/...".
INSTALL_DIR="${1:-/opt/scraper-oposicion}"
if [[ -z "${1:-}" ]]; then
  echo "[install] WARNING: no pasaste ruta destino. Usando default '${INSTALL_DIR}'."
  echo "[install]   Si tu proyecto está en otro sitio (ej. ~/bots/...), pasa la ruta:"
  echo "[install]     sudo \$0 \"\$HOME/bots/ScraperOposicion\""
  echo ""
fi
ENV_DIR="/etc/scraper-oposicion"
ENV_FILE="${ENV_DIR}/telegram.env"

# Usuario real (cuando se ejecuta con sudo, SUDO_USER está definido).
ACTUAL_USER="${SUDO_USER:-$(whoami)}"

echo "[install] Proyecto: ${PROJECT_DIR}"
echo "[install] Destino:  ${INSTALL_DIR}"
echo "[install] Usuario:  ${ACTUAL_USER}"

# Detectar binario de node de forma robusta.
# El problema típico: el usuario tiene node en ~/.../node/vXX/bin (nvm/fnm/custom)
# y funciona como usuario normal, pero sudo resetea PATH al secure_path de
# /etc/sudoers y no lo encuentra. Tres estrategias en orden:
#   1) command -v node en el PATH actual (funciona si no se usa sudo, o si
#      sudo preserva PATH, o si node está en /usr/bin).
#   2) sudo -u SUDO_USER → command -v node en el login shell del usuario
#      original. Activa nvm/fnm desde su .bashrc y resuelve la ruta real.
#   3) Rutas absolutas comunes (apt/NodeSource/brew/snap).
detect_node_bin() {
  local node_bin=""

  # 1) PATH actual
  node_bin="$(command -v node 2>/dev/null || true)"
  if [[ -n "${node_bin}" && -x "${node_bin}" ]]; then
    echo "${node_bin}"
    return 0
  fi

  # 2) Bajo el usuario original (cubre nvm/fnm/custom)
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    # -H = login shell (carga /etc/profile, ~/.bash_profile, ~/.bashrc, nvm, fnm…)
    # -l  = explícitamente login shell (necesario con -c en bash moderno)
    node_bin="$(sudo -u "${SUDO_USER}" -H bash -lc 'command -v node' 2>/dev/null || true)"
    if [[ -n "${node_bin}" && -x "${node_bin}" ]]; then
      echo "${node_bin}"
      return 0
    fi
  fi

  # 3) Rutas absolutas comunes (último recurso)
  local path
  for path in \
    /usr/bin/node \
    /usr/local/bin/node \
    /opt/homebrew/bin/node \
    /snap/bin/node; do
    if [[ -x "${path}" ]]; then
      echo "${path}"
      return 0
    fi
  done

  return 1
}

NODE_BIN="$(detect_node_bin || true)"
if [[ -z "${NODE_BIN}" ]]; then
  echo "[install] ERROR: 'node' no se encuentra en PATH." >&2
  echo "  Como usuario normal funciona: ${SUDO_USER:-user} tiene node en su PATH" >&2
  echo "  (probablemente nvm/fnm/custom), pero sudo no lo ve." >&2
  echo "" >&2
  echo "  Opciones:" >&2
  echo "    A) Instala node en una ruta accesible para sudo (recomendado):" >&2
  echo "         curl -fsSL https://deb.nodesource.org/setup_24.x | sudo -E bash - && sudo apt install -y nodejs" >&2
  echo "    B) Añade el dir de node al secure_path de /etc/sudoers:" >&2
  echo "         Defaults  secure_path = ...:/home/${SUDO_USER:-user}/.nvm/versions/node/v24.18.0/bin" >&2
  echo "    C) Ejecuta install.sh sin sudo (no recomendado: necesita sudo para los units y /etc/)." >&2
  exit 1
fi
echo "[install] node:     ${NODE_BIN}"

# Validar versión mínima (Node 20+)
NODE_VERSION="$(${NODE_BIN} --version | sed 's/^v//')"
NODE_MAJOR="${NODE_VERSION%%.*}"
if [[ "${NODE_MAJOR}" -lt 20 ]]; then
  echo "[install] ERROR: se requiere Node.js >= 20. Detectado: ${NODE_VERSION}" >&2
  exit 1
fi

# 1) Crear el directorio destino si no existe
if [[ ! -d "${INSTALL_DIR}" ]]; then
  echo "[install] Creando ${INSTALL_DIR}…"
  sudo mkdir -p "${INSTALL_DIR}"
  sudo chown "${ACTUAL_USER}:${ACTUAL_USER}" "${INSTALL_DIR}"
fi

# 2) Copiar proyecto (excluyendo .git, node_modules, state, logs)
echo "[install] Copiando proyecto a ${INSTALL_DIR}…"
sudo rsync -a --delete \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='state' \
  --exclude='logs' \
  "${PROJECT_DIR}/" "${INSTALL_DIR}/"

# 3) Asegurar logs/ con permisos correctos
sudo mkdir -p "${INSTALL_DIR}/logs"
sudo chown "${ACTUAL_USER}:${ACTUAL_USER}" "${INSTALL_DIR}/logs"

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

# 6) Generar scraper.service con los paths correctos detectados.
#    (El scraper.service commiteado en el repo es una REFERENCIA con
#    paths por defecto; este es el que se despliega realmente.)
echo "[install] Generando /etc/systemd/system/scraper.service…"
echo "         ExecStart=${NODE_BIN} monitor.js"
echo "         WorkingDirectory=${INSTALL_DIR}"
echo "         EnvironmentFile=${ENV_FILE}"
SERVICE_FILE="$(mktemp)"
cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Scraper Oposiciones CM — monitor multi-site
Documentation=https://github.com/<owner>/scraper-oposicion
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=${INSTALL_DIR}
ExecStart=${NODE_BIN} monitor.js
EnvironmentFile=${ENV_FILE}
StandardOutput=journal
StandardError=journal
SyslogIdentifier=scraper-oposicion

# Para activar el modo debug (notifica a Telegram en cada poll, no solo cuando
# hay cambios), descomenta la siguiente línea y reinicia el timer:
#   sudo systemctl restart scraper.timer
# Para volver a modo producción (default), comenta la línea y reinicia el timer.
#Environment=SCRAPER_DEBUG=1

# Resiliencia
Restart=on-failure
RestartSec=30s
StartLimitInterval=10min
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF
sudo cp "${SERVICE_FILE}" /etc/systemd/system/scraper.service
sudo chmod 644 /etc/systemd/system/scraper.service
rm -f "${SERVICE_FILE}"

# 7) Copiar scraper.timer (no depende de paths)
sudo cp "${SCRIPT_DIR}/scraper.timer" /etc/systemd/system/scraper.timer
sudo chmod 644 /etc/systemd/system/scraper.timer
sudo systemctl daemon-reload

# 8) Habilitar y arrancar el timer
sudo systemctl enable scraper.timer
sudo systemctl restart scraper.timer

echo ""
echo "[install] Hecho. Comandos útiles:"
echo "  systemctl status scraper.timer"
echo "  systemctl list-timers scraper.timer"
echo "  journalctl -u scraper.service -f"
echo ""
echo "[install] Si algo falla, revisa:"
echo "  - ${ENV_FILE} tiene TELEGRAM_BOT_TOKEN y TELEGRAM_CHAT_ID correctos."
echo "  - ${INSTALL_DIR} tiene los ficheros del proyecto (monitor.js, sites.json, etc.)."
echo "  - ${NODE_BIN} funciona: ${NODE_BIN} --version"