# Session Context

## Estado Actual del Proyecto (2026-07-22)

**Completado:**
- Fase 0: Foundation.
- Fase 1: Monitor CM Educacion (regex + GH Actions).
- Fase 2: Notificacion Telegram via Bot API.
- Fase 3: Scraper local en Raspberry Pi (multi-site + hash + systemd timer + always-notify).
- ADRs registrados: 001 (agent swarm), 002 (sin tests), 003 (Raspberry vs GH Actions), 004 (hash vs regex), 005 (systemd vs cron), 006 (ficheros vs SQLite).

**Pendiente:**
- Validar deploy real en la Raspberry Pi (ejecutar install.sh y observar 24h).

## Cambios de la sesión (2026-07-20)

### Bootstrap del proyecto

**Decisiones del usuario (sección §0):**
- Package manager: `pnpm`
- Test framework: ninguno (omitido por completo, ver ADR-002)
- Linter: ESLint plano
- Stack: Node.js + ESM
- Plugin OpenCode: omitido
- Modelo para los 5 agentes: `minimax/MiniMax-M3` (mismo para todos)
- Project name inferido: `scraper-oposicion`

**Estructura creada:**

```
.opencode/
  agents/      leader.md, explorer.md, developer.md, reviewer.md, documenter.md
  tasks/       (vacía, lista para HANDOFF y tasks)
docs/          architecture.md, conventions.md, decisions.md, roadmap.md
AGENTS.md
CONTRIBUTING.md
README.md
CHANGELOG.md
feature_list.json
.gitignore
SESSION_CONTEXT.md   ← este archivo, NO se commitea
```

**Lo que NO se hizo en esta sesión (deliberado):**
- No se escribió código de producto.
- No se instalaron dependencias (`pnpm install` no se ejecutó).
- No se hicieron commits.
- No se creó `package.json` (pendiente de definir stack concreto en fase futura).
- No se crearon tests (ver ADR-002).