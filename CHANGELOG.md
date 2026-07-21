# Changelog
All notable changes to scraper-oposicion will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [Fase 3] — 2026-07-22 — Scraper local en Raspberry Pi (multi-site)

### Added
- Detección de cambios **híbrida HEAD-first con fallback a hash SHA-256** sobre HTML normalizado (cheerio). Funciona con y sin headers `Last-Modified` / `ETag`.
- Soporte **multi-site**: lista declarativa en `.opencode/config/sites.json`. Añadir/quitar webs no requiere tocar código.
- Monitorizan **2 webs**: CM Educacion (oposiciones maestros) y CM Sede (oferta empleo oposiciones 2026).
- **systemd timer + service** para scheduling cada 5 min en Raspberry Pi (`scripts/raspberry/`).
- Script de instalación idempotente (`scripts/raspberry/install.sh`).
- Logging dual: `journalctl` + fichero rotado `logs/scraper.log` (1 MB → trunca a 500 KB).
- Mensaje "🟢 Monitor arrancado" la primera ejecución (D15).
- Persistencia atómica del fingerprint (`writeFile` + `rename`, D16).
- 4 ADRs nuevos: ADR-003 (Raspberry vs GH Actions), ADR-004 (hash vs regex), ADR-005 (systemd vs cron), ADR-006 (ficheros vs SQLite).

### Changed
- Política de notificación: pasa de "solo si hay cambio" a **siempre notificar** (288 mensajes/día por diseño).
- Formato del mensaje: 1 único mensaje Markdown con el estado de las N webs.
- Estado persistido en `state/<siteId>.fingerprint` (sustituye a `state.txt` versionado).

### Removed
- Regex agnóstica de Fase 1 (`UPDATE_REGEX`, `extractUpdateDate`).
- Función `notifyChange` de Fase 2 (sustituida por `sendTelegramSummary`).
- Cron del workflow `.github/workflows/monitor.yml` (queda comentado, ver nota legacy).

### Fixed
- n/a.

### Notes
- Bot en Telegram: `@OposicionCamBot` (mismo de Fase 2).
- Workflow GH Actions queda como **legacy** para `workflow_dispatch` manual.

### Added (Fase 1 — Monitor CM Educacion)
- `monitor.js`: monitor de oposiciones de la Comunidad de Madrid con tres secciones claramente diferenciadas:
  - **SCRAPING** — `fetchPage(url)`: axios con User-Agent Mozilla, timeout 30s, validateStatus 2xx.
  - **LÓGICA DE BÚSQUEDA** — `extractUpdateDate(html)`: cheerio + regex ESTRICTA `/Última actualización: ([^\n<]+)/`. Throw + exit(1) si no matchea.
  - **NOTIFICACIÓN** — `notifyChange(date, url)`: stub preparado para Fase 2 (Telegram, pendiente de implementar).
- `state.txt`: estado persistente con valor inicial `16 julio 2026`. Versionado en repo.
- `.github/workflows/monitor.yml`: cron `*/30 * * * *` + `workflow_dispatch`. Node 20, ubuntu-latest, pnpm 9 con cache. Secret `DISCORD_WEBHOOK` reservado (Fase 2). `permissions: contents: write`, `concurrency: monitor-cm`, commit/push idempotente con autor `github-actions[bot]`.
- `package.json`: ESM, deps `axios ^1.7.7` + `cheerio ^1.0.0`, devDeps `eslint ^9.12.0` + `@eslint/js ^9.12.0`.
- `eslint.config.js`: ESLint 9 flat config plano (sin Prettier acoplado).

### Changed (Fase 1)
- README actualizado con tagline real e instrucciones de uso (Node 20, pnpm).
- Roadmap marca Fase 1 como completada.
- `feature_list.json` registra la feature `monitor-cm-edu`.

## [0.0.0] - 2026-07-20

### Added (Fase 0 — Foundation)
- Bootstrap del proyecto: agent swarm (5 agentes) + harness de documentación + SDD loop.
- Documentación canónica en `docs/` (architecture, conventions, decisions, roadmap).
- ADRs-001 (agent swarm + SDD) y ADR-002 (sin suite de tests por defecto) registrados.
- Meta-archivos: `AGENTS.md`, `CONTRIBUTING.md`, `README.md` (placeholder), `feature_list.json`, `.gitignore`.


### Fixed (Fase 1 — task-102, 2026-07-20)
- `monitor.js`: regex `extractUpdateDate` ahora tolera salto de línea entre "Última actualización:" y la fecha (la web la pone en línea separada tras la conversión HTML→texto). Sigue siendo estricto en formato `D mes YYYY` con los 12 meses en español explícitos y flag `i` para mayúsculas/minúsculas. Si no matchea, mantiene `throw + exit(1)`.
- `.github/workflows/monitor.yml`: cron ajustado de `*/30 * * * *` a `5,35 * * * *` (mismo intervalo de 30 min, desfase +5 min en :05 y :35 UTC).


### Fixed (Fase 1 — task-103, 2026-07-20)
- `monitor.js`: regex `extractUpdateDate` reemplazada por una versión **agnóstica al formato` `/Última actualización:\s*([\s\S]+?)(?=\n\s*\n|$)/`. Captura literalmente cualquier contenido tras los dos puntos (fecha, nombre, código, etc.) hasta el próximo bloque claro o fin del body. Sin flags. Si no matchea, mantiene `throw + exit(1)`.


### Added (Fase 2 — Notificación Telegram)
- `monitor.js`: `notifyChange` reemplazado por llamada real a Telegram Bot API. Lee `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID` de `process.env` (throw claro si faltan). POST a `https://api.telegram.org/bot<TOKEN>/sendMessage` con `parse_mode: "Markdown"` y `disable_web_page_preview: true`. Throw si la API responde `ok !== true`.
- `.github/workflows/monitor.yml`: job `check` declara `environment: main` para acceder a los secrets del GitHub Environment donde el usuario guardó los tokens. Step "Run monitor" inyecta `TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN_HTTP }}` (mapeo del secret con sufijo `_HTTP` a env var limpia) y `TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}`. Línea muerta `DISCORD_WEBHOOK` eliminada.

### Changed (Fase 2)
- Bot del usuario: `@OposicionCamBot` (Monitor Oposiciones).
- README actualizado: sección "GitHub Actions" explica la configuración de secrets Telegram y el environment "main". Arquitectura (monitor.js) refleja que la PARTE 3 ya no es stub.
