# scraper-oposicion

> Bot autónomo que monitoriza la página de procesos selectivos de oposiciones a maestros de la Comunidad de Madrid y alerta cuando cambia la fecha de "Última actualización".

## What is scraper-oposicion?

`scraper-oposicion` es un monitor ligero escrito en Node.js (ESM) que:

1. Descarga el HTML de la página objetivo cada 30 minutos (GitHub Actions cron).
2. Extrae la fecha de "Última actualización" con una regex estricta.
3. Compara con el valor guardado en `state.txt`.
4. Si cambia, notifica (Fase 2 — Telegram Bot API) y persiste el nuevo estado en `state.txt`.
5. El workflow hace commit/push automático de `state.txt` con `github-actions[bot]`.

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

Para probarlo contra la página real necesitas `state.txt` con la fecha actual en disco. Si solo quieres validar sintaxis:
```bash
node --check monitor.js
```

### Verification Order
```bash
pnpm lint
```

> **Nota:** Este proyecto **no incluye suite de tests** (ver [ADR-002](docs/decisions.md)).

## GitHub Actions

El workflow [`.github/workflows/monitor.yml`](.github/workflows/monitor.yml) ejecuta el monitor:

- **Cron**: `*/30 * * * *` (cada 30 minutos).
- **Manual**: pestaña Actions → "Run workflow".
- **Entorno**: `ubuntu-latest`, Node 20, pnpm 9 con cache.
- **Persistencia**: `permissions: contents: write` + commit/push idempotente de `state.txt` con `github-actions[bot]`.
- **Concurrencia**: grupo `monitor-cm` (runs concurrentes se serializan).

Para activar Fase 2 (Telegram) añade los secrets `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID` en Settings → Secrets → Actions.

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── monitor.yml       # Cron + workflow_dispatch + commit/push
├── .opencode/                # Harness de agentes (no es producto)
├── docs/                     # Documentacion canonica
├── monitor.js                # Entry point (3 partes: scraping, busqueda, notificacion)
├── state.txt                 # Estado persistente (versionado)
├── package.json              # ESM, axios, cheerio
├── eslint.config.js          # ESLint 9 plano
└── README.md
```

## Architecture (monitor.js)

El script está organizado en tres secciones claramente diferenciadas:

| Sección | Función | Responsabilidad |
|---|---|---|
| **1. Scraping** | `fetchPage(url)` | Descarga HTML con axios + User-Agent Mozilla, timeout 30s. |
| **2. Búsqueda** | `extractUpdateDate(html)` | Parsea con cheerio y aplica regex ESTRICTA `/Última actualización: ([^\n<]+)/`. Exit(1) si no matchea. |
| **3. Notificación** | `notifyChange(date, url)` | Stub en Fase 1. Será Telegram en Fase 2. |

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
| Automation | GitHub Actions (cron + workflow_dispatch) |
| Tests | (no incluidos — ver ADR-002) |

## License

ISC

