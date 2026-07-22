# Roadmap

> Fases del proyecto en orden de ejecución. Convención: **Fase 0..N** = fundación, **Fase A..Z** = refinamiento, renombrados, refactors.

## Leyenda de estado

- **Pendiente** — definida pero no iniciada.
- **En curso** — tiene al menos un HANDOFF emitido.
- **Completado** — todas las features asociadas cerradas en `feature_list.json` y CHANGELOG actualizado.

---

## Fase 2: Notificación Telegram

**Estado:** Completado
**Fecha:** 2026-07-20

Entregables:

- `monitor.js` → `notifyChange` integrado con Telegram Bot API (`https://api.telegram.org/bot<TOKEN>/sendMessage`).
- Mensaje en Markdown con el cambio detectado, nueva fecha y URL.
- Variables de entorno `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID` leídas de `process.env`. Throw claro si faltan (instrucciones para configurarlas).
- Workflow declara `environment: main` (GitHub Environment donde el usuario guardó los secrets).
- Mapeo del secret con sufijo `_HTTP` (`TELEGRAM_BOT_TOKEN_HTTP`) a la env var limpia.
- Línea muerta `DISCORD_WEBHOOK` eliminada del workflow.
- Bot del usuario: `@OposicionCamBot` (Monitor Oposiciones).

HANDOFF(s):

- `.opencode/tasks/HANDOFF-FASE-1.md` (registra la decisión original).

Task(s):

- `.opencode/tasks/task-104-telegram-integration.md`

---

## Fase 1: Monitor de Oposiciones CM

**Estado:** Completado
**Fecha:** 2026-07-20

Entregables:

- Bot autónomo en Node.js (`monitor.js`) con tres secciones diferenciadas: SCRAPING (axios), LÓGICA DE BÚSQUEDA (cheerio + regex agnóstica tras task-103), NOTIFICACIÓN (stub en Fase 1, real con Telegram en Fase 2).
- Persistencia de estado en `state.txt` versionado en el repo (valor inicial `16 julio 2026`).
- GitHub Actions workflow (`.github/workflows/monitor.yml`) con cron `5,35 * * * *` UTC + `workflow_dispatch`, Node 20, ubuntu-latest, pnpm 9 con cache, secrets Telegram via environment "main", permisos `contents: write`, commit/push idempotente.
- `package.json` ESM con `axios` + `cheerio`.
- `eslint.config.js` plano (ESLint 9 flat config, sin Prettier).
- README actualizado con tagline real e instrucciones de uso.

Fixes incluidos en Fase 1:

- task-102: regex tolerante a multi-línea y cron ajustado a `:05/:35` UTC.
- task-103: regex reemplazada por versión agnóstica al formato (captura cualquier contenido tras "Última actualización:").

HANDOFF(s):

- `.opencode/tasks/HANDOFF-FASE-1.md`

Pendiente:

_Ninguno._ Las notificaciones reales se completaron en Fase 2.

---

## Fase 0: Foundation

**Estado:** Completado
**Fecha:** 2026-07-20

Entregables:

- Estructura `.opencode/agents/` con 5 agentes definidos (leader, explorer, developer, reviewer, documenter).
- Estructura `.opencode/tasks/` lista para HANDOFF y tasks.
- Harness de documentación canónica en `docs/` (architecture, conventions, decisions, roadmap).
- Meta-archivos en root: `AGENTS.md`, `CONTRIBUTING.md`, `README.md`, `CHANGELOG.md`, `feature_list.json`.
- `.gitignore` mínimo viable.
- ADR-001 (agent swarm + SDD) y ADR-002 (sin suite de tests por defecto) registrados.

---

## Fase 3: Scraper local en Raspberry Pi (multi-site + hash)

**Estado:** Completado
**Fecha:** 2026-07-22

Entregables:

- `monitor.js` → refactor a multi-site con detección híbrida HEAD-first / SHA-256 (fallback).
- `sites.json` (raíz) → 2 webs declaradas (CM Educacion + CM Sede).
- `state/<siteId>.fingerprint` → persistencia por sitio (atomic write).
- `sendTelegramSummary` → 1 mensaje Markdown con N sitios. Política producción: solo notifica cuando hay cambios. Política debug (`SCRAPER_DEBUG=1`): notifica siempre.
- `scripts/raspberry/{scraper.service, scraper.timer, install.sh, uninstall.sh, README.md, telegram.env.example}` → setup systemd.
- `logs/scraper.log` → fichero rotado (1 MB → 500 KB).
- `.github/workflows/monitor.yml` → cron desactivado, queda como legacy.

Fixes incluidos en Fase 3:

- n/a (cambios mayores, no fixes).

HANDOFF(s):

- `.opencode/tasks/HANDOFF-FASE-3.md`

Tasks:

- `.opencode/tasks/task-301-multi-site-detection.md`
- `.opencode/tasks/task-302-telegram-always-notify.md`
- `.opencode/tasks/task-303-systemd-setup.md`
- `.opencode/tasks/task-304-cleanup-docs-adrs.md`

---

<!-- Plantilla para nuevas fases:

## Fase X: <título>

**Estado:** Pendiente | En curso | Completado
**Fecha:** YYYY-MM-DD (cuando arranque)

Entregables:

- ...

HANDOFF(s):

- `.opencode/tasks/HANDOFF-FASE-X.md` (cuando se emita)

-->
