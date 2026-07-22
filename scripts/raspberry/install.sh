#!/usr/bin/env bash
set -euo pipefail

# Rutas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# Destino del proyecto: arg1 si se pasa, si no /opt/scraper-oposicion.
INSTALL_DIR="${1:-/opt/scraper-oposicion}"
ENV_DIR="/etc/scraper-oposicion"
ENV_FILE="${ENV_DIR}/telegram.env"

# Usuario real (cuando se ejecuta con sudo, SUDO_USER está definido).
ACTUAL_USER="${SUDO_USER:-$(whoami)}"

echo "[install] Proyecto: ${PROJECT_DIR}"
echo "[install] Destino:  ${INSTALL_DIR}"
echo "[install] Usuario:  ${ACTUAL_USER}"

# Detecta el binario de una herramienta (node, pnpm, npm, ...) con la misma
# estrategia robusta que antes: PATH actual → login shell del usuario original
# (cubre nvm/fnm/custom) → null.
#   $1 = nombre del ejecutable a buscar.
detect_tool() {
  local tool_name="$1"
  local tool_bin=""

  # 1) PATH actual (funciona sin sudo o si el binario está en /usr/bin)
  tool_bin="$(command -v "${tool_name}" 2>/dev/null || true)"
  if [[ -n "${tool_bin}" && -x "${tool_bin}" ]]; then
    echo "${tool_bin}"
    return 0
  fi

  # 2) Login shell del usuario original (cubre nvm/fnm/custom)
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    tool_bin="$(sudo -u "${SUDO_USER}" -H bash -lc "command -v ${tool_name}" 2>/dev/null || true)"
    if [[ -n "${tool_bin}" && -x "${tool_bin}" ]]; then
      echo "${tool_bin}"
      return 0
    fi
  fi

  return 1
}

NODE_BIN="$(detect_tool node || true)"
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

# 2.5) Instalar dependencias (pnpm preferido, npm fallback).
#      Solo si node_modules/ no existe (idempotencia: re-ejecuciones no reinstalan).
if [[ ! -d "${INSTALL_DIR}/node_modules" ]]; then
  PKG_MANAGER=""
  PKG_MANAGER_BIN=""
  for candidate in pnpm npm; do
    PKG_MANAGER_BIN="$(detect_tool "${candidate}" || true)"
    if [[ -n "${PKG_MANAGER_BIN}" ]]; then
      PKG_MANAGER="${candidate}"
      break
    fi
  done

  if [[ -z "${PKG_MANAGER}" ]]; then
    echo "[install] ERROR: ni 'pnpm' ni 'npm' están disponibles para instalar dependencias." >&2
    echo "  Instala uno (recomendado pnpm):" >&2
    echo "    sudo npm install -g pnpm" >&2
    echo "    sudo apt install -y npm    # fallback" >&2
    exit 1
  fi

  echo "[install] Instalando dependencias con ${PKG_MANAGER} (${PKG_MANAGER_BIN})…"
  # Ejecutar como ACTUAL_USER (no root) para evitar warnings de pnpm sobre HOME.
  if [[ "${PKG_MANAGER}" == "pnpm" ]]; then
    sudo -u "${ACTUAL_USER}" bash -lc "cd '${INSTALL_DIR}' && '${PKG_MANAGER_BIN}' install --production"
  else
    sudo -u "${ACTUAL_USER}" bash -lc "cd '${INSTALL_DIR}' && '${PKG_MANAGER_BIN}' install --omit=dev"
  fi
else
  echo "[install] node_modules/ ya existe en ${INSTALL_DIR} (skip install)."
fi

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