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

<!-- Plantilla para nuevas fases:

## Fase X: <título>

**Estado:** Pendiente | En curso | Completado
**Fecha:** YYYY-MM-DD (cuando arranque)

Entregables:

- ...

HANDOFF(s):

- `.opencode/tasks/HANDOFF-FASE-X.md` (cuando se emita)

-->