# Task 303: Setup systemd — service + timer + install.sh + README + logging rotado

**Fase:** 3
**Agente asignado:** developer
**Estado:** Pendiente de implementación (depende de task-301 y task-302 APROBADOS)
**HANDOFF:** `.opencode/tasks/HANDOFF-FASE-3.md`
**Task anterior:** task-302
**Task siguiente (bloqueante):** task-304

## Objetivo

Crear los ficheros de **systemd timer + service** que ejecutarán `node monitor.js` cada 5 minutos en la Raspberry Pi, junto con un script de instalación idempotente, un README de despliegue, y la rotación simple del fichero de logs.

## Contexto

- En task-301 y task-302, `monitor.js` ya hace fetch + detección + Telegram.
- Falta el **scheduler** que lo invoque periódicamente: D11 eligió **systemd timer + service** (vs cron) por:
  - `After=network-online.target` (espera a la red antes del primer poll).
  - Logs centralizados en `journalctl`.
  - `Restart=on-failure` ante crashes.
- El **logging rotado** (D12) es un fichero adicional `logs/scraper.log` con rotación por tamaño (1 MB → truncar a 500 KB).
- Las **variables de entorno** de Telegram se leen vía `EnvironmentFile=` apuntando a un fichero NO versionado (`/etc/scraper-oposicion/telegram.env`).
- La Raspberry Pi ejecuta Raspberry Pi OS (basado en Debian 12 / systemd).

## Decisiones aplicables

- **D2**: cada 5 minutos (`OnUnitActiveSec=5min`).
- **D11**: systemd timer + service.
- **D12**: journalctl + fichero rotado.
- **D16**: el fingerprint ya se persiste atómicamente (task-301). No afecta a systemd.

## Archivos a crear

| Path | Acción |
|---|---|
| `scripts/raspberry/scraper.service` | **Crear** — unit de tipo `oneshot`. |
| `scripts/raspberry/scraper.timer` | **Crear** — timer que dispara el service. |
| `scripts/raspberry/install.sh` | **Crear** — instala units + crea `/etc/scraper-oposicion/telegram.env` placeholder. Idempotente. |
| `scripts/raspberry/uninstall.sh` | **Crear** — desinstala units. Idempotente. |
| `scripts/raspberry/README.md` | **Crear** — instrucciones paso a paso. |
| `scripts/raspberry/telegram.env.example` | **Crear** — plantilla para `/etc/scraper-oposicion/telegram.env`. |
| `monitor.js` | **Modificar** — añadir logging a fichero rotado. |
| `.gitignore` | **Modificar** — añadir `logs/*.log` (si no está ya de task-301). |

## 1) `scripts/raspberry/scraper.service`

```ini
[Unit]
Description=Scraper Oposiciones CM — monitor multi-site
Documentation=https://github.com/<owner>/scraper-oposicion
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=/opt/scraper-oposicion
ExecStart=/usr/bin/node monitor.js
EnvironmentFile=/etc/scraper-oposicion/telegram.env
StandardOutput=journal
StandardError=journal
SyslogIdentifier=scraper-oposicion

# Resiliencia
Restart=on-failure
RestartSec=30s
StartLimitInterval=10min
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
```

## 2) `scripts/raspberry/scraper.timer`

```ini
[Unit]
Description=Scraper Oposiciones CM — cada 5 minutos
Requires=scraper.service

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=10s
Unit=scraper.service
Persistent=true

[Install]
WantedBy=timers.target
```

Notas:
- `OnBootSec=2min` → primer poll 2 min tras arrancar la Pi (da tiempo a la red y a systemd).
- `OnUnitActiveSec=5min` → polls cada 5 min desde el último final.
- `AccuracySec=10s` → systemd puede ajustar ±10s para agrupar con otros timers; irrelevante para este caso.
- `Persistent=true` → si la Pi estuvo apagada, al arrancar systemd ejecuta los polls perdidos. (Con `OnUnitActiveSec=5min` no hay "polling perdido" estrictamente, pero es defensivo.)

## 3) `scripts/raspberry/install.sh`

Script bash **idempotente** (re-ejecutable sin romper nada):

```bash
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
```

> **IMPORTANTE para el developer**: este script usa `sudo`. En la Raspberry Pi, el usuario debe tener sudo. NO usar `sudo -i` ni cambiar de usuario; asumir sudo passwordless o con prompt.

## 4) `scripts/raspberry/uninstall.sh`

```bash
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
```

## 5) `scripts/raspberry/telegram.env.example`

```bash
# Rellenar con tus credenciales y copiar a /etc/scraper-oposicion/telegram.env
# Bot: @OposicionCamBot
TELEGRAM_BOT_TOKEN=123456:ABC-DEF...
TELEGRAM_CHAT_ID=123456789
```

## 6) `scripts/raspberry/README.md`

```markdown
# Despliegue en Raspberry Pi

Requisitos:
- Raspberry Pi OS (Debian 12+) con systemd.
- Node.js 20+ instalado (`node --version`).
- pnpm instalado (`pnpm --version`).
- El usuario tiene `sudo` sin password o con prompt.

## Pasos

### 1. Instalar Node y pnpm (si no están)

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g pnpm
```

### 2. Clonar el repo y preparar

```bash
cd /opt
sudo git clone https://github.com/<owner>/scraper-oposicion.git
sudo chown -R $USER:$USER /opt/scraper-oposicion
cd /opt/scraper-oposicion
pnpm install --production
```

### 3. Configurar credenciales de Telegram

```bash
sudo cp scripts/raspberry/telegram.env.example /etc/scraper-oposicion/telegram.env
sudo nano /etc/scraper-oposicion/telegram.env
# Rellenar TELEGRAM_BOT_TOKEN y TELEGRAM_CHAT_ID
```

### 4. Instalar y arrancar

```bash
chmod +x scripts/raspberry/install.sh
./scripts/raspberry/install.sh
```

### 5. Verificar

```bash
systemctl status scraper.timer
systemctl list-timers scraper.timer
journalctl -u scraper.service -f
```

## Desinstalar

```bash
sudo ./scripts/raspberry/uninstall.sh
```

## Desinstalación completa (borrar todo)

```bash
sudo ./scripts/raspberry/uninstall.sh
sudo rm -rf /opt/scraper-oposicion /etc/scraper-oposicion
```
```

## 7) Modificación a `monitor.js` — logging a fichero rotado

Añadir al inicio del fichero (con el resto de imports):

```js
import { appendFile, stat, truncate, mkdir } from "node:fs/promises";
import { join } from "node:path";

const LOG_DIR = "logs";
const LOG_FILE = join(LOG_DIR, "scraper.log");
const LOG_MAX_BYTES = 1_000_000;   // 1 MB → rotar
const LOG_KEEP_BYTES = 500_000;    // truncar a 500 KB
```

Añadir helper:

```js
async function logToFile(line) {
  try {
    await mkdir(LOG_DIR, { recursive: true });
    await appendFile(LOG_FILE, line + "\n", "utf8");
    const stats = await stat(LOG_FILE).catch(() => null);
    if (stats && stats.size > LOG_MAX_BYTES) {
      await truncate(LOG_FILE, LOG_KEEP_BYTES);
    }
  } catch (err) {
    // Fallar el log no debe matar el monitor.
    console.error("[monitor] No pude escribir en logs/scraper.log:", err.message);
  }
}
```

Y un wrapper que sustituya todos los `console.log` y `console.error` por algo así:

```js
function logInfo(msg) {
  console.log(msg);
  logToFile(`[INFO ${new Date().toISOString()}] ${msg}`);
}

function logError(msg) {
  console.error(msg);
  logToFile(`[ERROR ${new Date().toISOString()}] ${msg}`);
}
```

Refactor: **reemplazar todos los `console.log` y `console.error` del `main()` y de las funciones auxiliares por `logInfo` / `logError`**. Esto incluye:

- `[monitor] Sitios configurados: …`
- `[monitor] Procesando: …`
- `[monitor] (STUB) Resumen…` (ya no aplica en task-303, pero mantener el estilo)
- `[monitor] ERROR: …` del catch final.

`logError` debe capturar también errores no esperados para que siempre queden en el fichero rotado.

## 8) `.gitignore` (verificar)

`task-301` ya añadió `logs/*.log`. Verificar que está; si no, añadirlo.

## Restricciones

- ❌ NO usar cron. Solo systemd.
- ❌ NO añadir dependencias npm. Todo con módulos nativos de Node.
- ❌ NO crear un proceso long-lived con `setInterval` en `monitor.js`. El timer externo de systemd es quien invoca.
- ❌ NO cambiar el formato del mensaje Telegram (eso es task-302).
- ❌ NO usar Docker.
- ❌ NO commit. Espera al reviewer.
- ✅ El `install.sh` debe ser idempotente: re-ejecutable sin romper.
- ✅ El `scraper.service` debe usar `Type=oneshot` (el binario termina solo).
- ✅ El `install.sh` debe asumir que el destino `/opt/scraper-oposicion` puede no existir y crearlo.
- ✅ El `telegram.env.example` debe estar commiteable (es plantilla, no tiene secretos).

## Validación local (obligatoria)

### 8.1 Lint + sintaxis

```bash
cd C:\Users\pathl\Workspace\ScraperOposicion
pnpm lint
node --check monitor.js
```

Ambos exit 0.

### 8.2 Validación de los units systemd (sintaxis)

Si tienes acceso a una máquina Linux (o WSL con systemd) puedes ejecutar:

```bash
sudo cp scripts/raspberry/scraper.service /tmp/
sudo cp scripts/raspberry/scraper.timer /tmp/
systemd-analyze verify /tmp/scraper.service
systemd-analyze verify /tmp/scraper.timer
```

Debe devolver exit 0 sin errores.

### 8.3 Validación del install.sh (dry-run)

```bash
bash -n scripts/raspberry/install.sh
bash -n scripts/raspberry/uninstall.sh
```

Debe devolver exit 0 (sin errores de sintaxis bash).

### 8.4 Validación del logging

```bash
node monitor.js
ls -la logs/
cat logs/scraper.log
```

Debe existir `logs/scraper.log` con líneas con prefijo `[INFO ...]` y `[ERROR ...]`.

Si ejecutas 3 veces seguidas (modificando algo en `state/<siteId>.fingerprint` para forzar detección), el fichero debe seguir < 1 MB. Forzar rotación manual:

```bash
node -e "import('node:fs/promises').then(async fs => { for (let i = 0; i < 1000; i++) await fs.appendFile('logs/scraper.log', 'x'.repeat(2000)); })"
node monitor.js
ls -la logs/scraper.log
```

Tras la ejecución de `monitor.js`, el fichero debe estar truncado a ~500 KB.

## Entregable del developer

Reporta:

1. Output literal de `pnpm lint`.
2. Output literal de `node --check monitor.js`.
3. Output literal de `bash -n scripts/raspberry/install.sh` y `uninstall.sh`.
4. Si tienes acceso a Linux con systemd: output literal de `systemd-analyze verify` para ambos units.
5. Output literal de `node monitor.js` mostrando que se crea `logs/scraper.log`.
6. `ls -la logs/` después de la ejecución.
7. Output literal de la prueba de rotación (paso 8.4) mostrando que `scraper.log` queda truncado.
8. `git status` y `git diff --stat`.

NO HAGAS COMMIT. Espera al reviewer.