# Architecture

> Documento canónico de arquitectura. Se actualiza cuando cambia la estructura del proyecto, los límites de módulo o el flujo de datos. La fuente de verdad es el código, no este archivo.

## Vista general

ScraperOposicion es un proyecto Node.js con módulos ES nativos. La arquitectura objetivo es **hexagonal (Ports & Adapters)**, aunque en fases tempranas esta separación puede estar implícita.

### Flujo de dependencias

```
server/ → gateway/ → adapters/
```

Los agentes nunca importan adapters directamente. Usan identificadores lógicos que el router resuelve.

## Árbol de archivos (placeholder)

```
.
├── .opencode/
│   ├── agents/        # Definiciones de los 5 agentes
│   └── tasks/         # HANDOFF y task-* generados por fase
├── docs/              # Documentación canónica
│   ├── architecture.md
│   ├── conventions.md
│   ├── decisions.md
│   └── roadmap.md
├── src/               # Código fuente (a poblar en fases futuras)
│   ├── server/
│   ├── gateway/
│   └── adapters/
├── AGENTS.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── README.md
├── SESSION_CONTEXT.md # No se commitea
└── feature_list.json
```

## Componentes (Fase 3)

- **Sites config** (`sites.json` en la raíz del repo): declarativo, commiteable.
- **State store** (`state/<siteId>.fingerprint`): fichero plano por sitio, escritura atómica.
- **Detection engine** (`monitor.js`): híbrido HEAD-first / hash-fallback.
- **Notifier** (`sendTelegramSummary` en `monitor.js`): 1 mensaje Markdown.
- **Scheduler** (systemd): `scripts/raspberry/scraper.timer` + `scraper.service`.
- **Logger** (dual): `journalctl` + `logs/scraper.log` rotado.

## Flujo de datos

> Se documenta cuando exista un flujo end-to-end.

## Flujo de ejecución (Fase 3)

```
┌──────────────────────────────────────────────────────────────────┐
│                       Raspberry Pi                                │
│                                                                  │
│  systemd timer (cada 5 min)                                      │
│         │                                                        │
│         ▼                                                        │
│  systemd service (oneshot)                                       │
│         │                                                        │
│         ▼                                                        │
│  node monitor.js                                                 │
│     │                                                            │
│     ├─ loadSites() ←── sites.json (raíz)                       │
│     │                                                            │
│     └─ for each site:                                            │
│          ├─ fetchHead(url) → { lastModified, etag }              │
│          │   └─ Si presentes: usar como fingerprint              │
│          ├─ else:                                                │
│          │   ├─ fetchPage(url) → html                            │
│          │   └─ normalizeAndHash(html) → sha256 (cheerio)        │
│          ├─ loadStoredFingerprint(siteId) ← state/<id>.fp        │
│          ├─ compare: changed = current !== previous              │
│          ├─ saveStoredFingerprint(siteId, current)  [atomic]     │
│          └─ registrar en summary                                 │
│                                                                  │
│  sendTelegramSummary(summary) → POST api.telegram.org           │
│         │                                                        │
│         ▼                                                        │
│  exit 0                                                          │
└──────────────────────────────────────────────────────────────────┘
```

## Referencias

- [AGENTS.md](../AGENTS.md) — Límites de módulo y reglas de dependencia.
- [docs/conventions.md](./conventions.md) — Estándares de código.
- [docs/decisions.md](./decisions.md) — Decisiones arquitectónicas (ADRs).
- [docs/roadmap.md](./roadmap.md) — Fases y entregables.