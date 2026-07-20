# Roadmap

> Fases del proyecto en orden de ejecución. Convención: **Fase 0..N** = fundación, **Fase A..Z** = refinamiento, renombrados, refactors.

## Leyenda de estado

- **Pendiente** — definida pero no iniciada.
- **En curso** — tiene al menos un HANDOFF emitido.
- **Completado** — todas las features asociadas cerradas en `feature_list.json` y CHANGELOG actualizado.

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

## Fase 1: Monitor de Oposiciones CM

**Estado:** Completado
**Fecha:** 2026-07-20

Entregables:

- Bot autónomo en Node.js (`monitor.js`) con tres secciones diferenciadas: SCRAPING (axios), LÓGICA DE BÚSQUEDA (cheerio + regex estricta), NOTIFICACIÓN (stub).
- Persistencia de estado en `state.txt` versionado en el repo (valor inicial `16 julio 2026`).
- GitHub Actions workflow (`.github/workflows/monitor.yml`) con cron cada 30 minutos + `workflow_dispatch`, Node 20, ubuntu-latest, pnpm, secret reservado para Fase 2, permisos `contents: write`, commit/push idempotente.
- `package.json` ESM con `axios` + `cheerio`.
- `eslint.config.js` plano (ESLint 9 flat config, sin Prettier).
- README actualizado con tagline real e instrucciones de uso.

HANDOFF(s):

- `.opencode/tasks/HANDOFF-FASE-1.md`

Pendiente para Fase 2 (no incluido en Fase 1):

- Implementar `notifyChange` real con **Telegram Bot API** (decisión registrada en HANDOFF-FASE-1).
- Crear bot con @BotFather, obtener `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID`, añadirlos como secrets.
- Actualizar workflow para inyectar ambos secrets.

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
