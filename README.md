# scraper-oposicion

> Monitor multi-site de oposiciones CM ejecutándose en Raspberry Pi

## What is scraper-oposicion?

`scraper-oposicion` es un monitor ligero escrito en Node.js (ESM) que:

1. Carga una lista declarativa de N webs desde `sites.json` (raíz del repo).
2. Cada 5 minutos (systemd timer en la Raspberry Pi) itera sobre cada sitio.
3. Detecta cambios con estrategia **híbrida**: HEAD-first (`Last-Modified`/`ETag`) con fallback a SHA-256 sobre HTML normalizado.
4. Persiste el fingerprint por sitio en `state/<siteId>.fingerprint` (escritura atómica).
5. Envía un mensaje Markdown a Telegram con el estado de las N webs (`sendTelegramSummary`) — solo si hay cambios (modo producción) o en cada poll si `SCRAPER_DEBUG=1` (modo debug).

## Getting Started

### Prerequisites
- Node.js >= 20
- pnpm >= 9

### Installation
```bash
pnpm install
```

### Usage
```bash
pnpm start        # Ejecuta el monitor una vez (node monitor.js)
pnpm lint         # Pasa ESLint
```

Para probarlo contra las páginas reales necesitas las variables `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID` en el entorno. Si solo quieres validar sintaxis:
```bash
node --check monitor.js
```

### Verification Order
```bash
pnpm lint
```

> **Nota:** Este proyecto **no incluye suite de tests** (ver [ADR-002](docs/decisions.md)).

## Running locally on Raspberry Pi

El scraper se ejecuta en una Raspberry Pi con systemd timer (cada 5 min).
Para desplegar:

1. Clonar el repo donde prefieras:
   - **Opción A** (recomendada): `/opt/scraper-oposicion`
   - **Opción B** (sin sudo para el código): `~/bots/ScraperOposicion` u otra ruta en tu home
2. Configurar credenciales en `/etc/scraper-oposicion/telegram.env`.
3. Ejecutar `sudo ./scripts/raspberry/install.sh` (acepta la ruta destino como argumento: `sudo ./install.sh "$HOME/bots/ScraperOposicion"`).
4. `install.sh` detecta automáticamente la ruta de `node` y genera `scraper.service` con los paths correctos.

Detalle completo: [`scripts/raspberry/README.md`](scripts/raspberry/README.md).

### Useful commands

```bash
systemctl status scraper.timer          # estado del timer
systemctl list-timers scraper.timer     # próxima ejecución
journalctl -u scraper.service -f        # logs en vivo
tail -f <INSTALL_DIR>/logs/scraper.log  # logs fichero rotado (INSTALL_DIR por defecto /opt/scraper-oposicion)
```

## Project Structure

```
.
├── .opencode/                # Harness de agentes (no es producto)
│   ├── agents/               # Definiciones de los 5 agentes
│   └── tasks/                # HANDOFF + tasks (archivados al cierre de fase)
├── docs/                     # Documentacion canonica
├── scripts/
│   └── raspberry/            # Setup systemd (service + timer + install.sh + README)
├── sites.json                # Lista declarativa de webs a monitorizar
├── monitor.js                # Entry point multi-site
├── state/                    # Estado runtime (gitignored): <siteId>.fingerprint + .initialized
├── logs/                     # Logs runtime (gitignored): scraper.log rotado
├── .env                      # Credenciales Telegram para dev local (gitignored)
├── package.json              # ESM, axios, cheerio
├── eslint.config.js          # ESLint 9 plano
└── README.md
```

> **No hay GitHub Actions** en esta rama. La automatización corre exclusivamente en la Raspberry Pi con systemd.

## Architecture (monitor.js)

El script está organizado en secciones claramente diferenciadas. La fuente de verdad arquitectónica es [`docs/architecture.md`](docs/architecture.md); este resumen es solo una vista rápida.

| Sección | Funciones | Responsabilidad |
|---|---|---|
| **1. Configuración** | `loadSites()` | Lee y valida `sites.json` en la raíz (id, name, url). |
| **2. Scraping** | `fetchHead(url)`, `fetchPage(url)` | HEAD (sin body) o GET completo. |
| **3. Detección de fingerprint** | `normalizeAndHash(html)`, `detectFingerprint(site)` | Híbrido HEAD-first → hash-fallback. |
| **4. Persistencia** | `loadStoredFingerprint()`, `saveStoredFingerprint()` | Atomic write en `state/<siteId>.fingerprint`. |
| **5. Primera ejecución** | `isFirstRun()`, `markInitialized()` | Flag en `state/.initialized`. |
| **6. Notificación** | `sendTelegramSummary(summary, { firstRun })` | Telegram: solo cuando hay cambios (default) o siempre si `SCRAPER_DEBUG=1`. |
| **7. Logging** | `logToFile()`, `logInfo()`, `logError()` | Dual: stdout (journalctl) + `logs/scraper.log` rotado. |

## Documentation

| Document | Description |
|---|---|
| [AGENTS.md](AGENTS.md) | Agent instructions and conventions |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Development workflow and PR guidelines |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [docs/architecture.md](docs/architecture.md) | Architecture and components |
| [docs/conventions.md](docs/conventions.md) | Coding standards |
| [docs/decisions.md](docs/decisions.md) | Architectural decisions (ADRs) |
| [docs/roadmap.md](docs/roadmap.md) | Project phases |
| [feature_list.json](feature_list.json) | Feature tracking |

## Tech Stack

| Component | Technology |
|---|---|
| Language | JavaScript (Node.js 20+) |
| Module System | ESM |
| Package Manager | pnpm |
| HTTP Client | axios ^1.7.7 |
| HTML Parser | cheerio ^1.0.0 |
| Linting | ESLint 9 (flat config, sin Prettier) |
| Automation | systemd timer + service en Raspberry Pi (sin GitHub Actions en esta rama) |
| Notification | Telegram Bot API (`@OposicionCamBot`) |
| Tests | (no incluidos — ver ADR-002) |

## License

ISC

