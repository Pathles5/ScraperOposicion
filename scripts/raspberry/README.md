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

**Opción A**: instalar en `/opt/scraper-oposicion` (default, recomendado):

```bash
cd /opt
sudo git clone https://github.com/<owner>/scraper-oposicion.git
sudo chown -R $USER:$USER /opt/scraper-oposicion
cd /opt/scraper-oposicion
pnpm install --production
```

**Opción B**: instalar en tu home (p.ej. `~/bots/...`):

```bash
mkdir -p ~/bots
cd ~/bots
git clone https://github.com/<owner>/scraper-oposicion.git
cd ScraperOposicion
pnpm install --production
```

### 3. Configurar credenciales de Telegram

```bash
sudo cp scripts/raspberry/telegram.env.example /etc/scraper-oposicion/telegram.env
sudo nano /etc/scraper-oposicion/telegram.env
# Rellenar TELEGRAM_BOT_TOKEN y TELEGRAM_CHAT_ID
```

### 4. Instalar y arrancar

`install.sh` automatiza todo: detecta `node`, valida versión, copia el proyecto, **instala las dependencias** (`pnpm install --production` o fallback a `npm install --omit=dev`), genera `scraper.service` con los paths correctos, e instala los units systemd. Si quieres instalar en un directorio distinto al del clone, pásalo como argumento.

**Instalación estándar** (a `/opt/scraper-oposicion`):

```bash
chmod +x scripts/raspberry/install.sh
sudo ./scripts/raspberry/install.sh
```

**Instalación en home** (p.ej. `~/bots/...`):

```bash
sudo ./scripts/raspberry/install.sh "$HOME/bots/ScraperOposicion"
```

El script:
- Detecta `node` (cascada: PATH actual → login shell del usuario original → rutas absolutas comunes). Cubre nvm/fnm bajo sudo.
- Valida que sea ≥ 20.
- Copia el proyecto al destino (excluyendo `.git/`, `node_modules/`, `state/`, `logs/`).
- **Instala dependencias** (`pnpm install --production` preferido, `npm install --omit=dev` fallback) si `node_modules/` no existe. Idempotente: re-ejecuciones saltan este paso.
- Crea `/etc/scraper-oposicion/telegram.env` desde el `.example` si no existe.
- Genera `/etc/systemd/system/scraper.service` con `ExecStart=<node-path>`, `WorkingDirectory=<destino>`, `EnvironmentFile=/etc/scraper-oposicion/telegram.env`.
- Copia `/etc/systemd/system/scraper.timer`.
- Habilita y arranca el timer.

### 5. Verificar

```bash
systemctl status scraper.timer
systemctl list-timers scraper.timer
journalctl -u scraper.service -f
```

Si systemd falla con `Unable to locate executable '/usr/bin/node'`, significa que tu `node` no está en `/usr/bin/node`. Re-ejecuta `install.sh` — detectará el path correcto automáticamente. Si quieres ver dónde está:

```bash
which node
```

Si systemd falla con `Cannot find package 'axios'` (o `cheerio`), `node_modules/` no existe en el destino. Re-ejecuta `install.sh` — instalará las dependencias automáticamente. O hazlo manual:

```bash
cd /opt/scraper-oposicion   # o tu INSTALL_DIR
sudo -u $USER pnpm install --production
# o: sudo -u $USER npm install --omit=dev
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
