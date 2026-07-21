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
