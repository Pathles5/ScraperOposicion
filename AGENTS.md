# AGENTS.md

Instructions for AI agents working on **scraper-oposicion**.

## Quick Reference

| Command | Purpose |
|---|---|
| `pnpm dev` | Run dev server |
| `pnpm lint` | Run linter |
| `pnpm format` | Run formatter |

**Verification order**: `pnpm lint`

> **Nota:** Este proyecto **no incluye suite de tests** por decisión explícita del usuario (ver ADR-002). El verification order es solo `pnpm lint`. Si en una fase futura se añaden tests, este archivo se actualizará.

## Agent Team

5-agent team with clear responsibilities. See `.opencode/agents/*.md` for detailed definitions.

| Agent | ID | Role | Read | Execute | Write | Git |
|---|---|---|---|---|---|---|
| Leader | `leader` | Task Manager | Yes | Yes | Tasks only | **Yes** |
| Explorer | `explorer` | Research | Yes | Yes | No | No |
| Developer | `developer` | Code Implementation | Yes | Yes | **Yes** | No |
| Reviewer | `reviewer` | Code Review & Lint | Yes | Yes | Tasks only | No |
| Documenter | `documenter` | Documentation | Yes | Yes | **Yes** | No |

### Double-Check Rule
No task is complete without:
1. Developer implements
2. Reviewer approves

### Phase Completion
When a phase completes:
1. Leader marks phase complete (`feature_list.json` + `docs/roadmap.md`)
2. Leader reviews all changes
3. Documentation updated (`CHANGELOG.md`, `README.md`, `docs/architecture.md` si aplica)
4. **Si la fase tocó endpoints HTTP**: OpenAPI spec + tabla en README sincronizados en el MISMO commit (ver ADR-001 §"Regla API Documentation Sync")

## Architecture

Hexagonal (Ports & Adapters). See [docs/architecture.md](./docs/architecture.md) for full details.

**Dependency flow**: `server/` → `gateway/` → `adapters/`

Agents never import adapters directly. They use logical identifiers resolved by the router.

## Module Boundaries

| Module | Owns | Cannot Import |
|---|---|---|
| (pendiente) | — | — |

> Tabla a rellenar cuando el usuario defina el primer módulo en una fase futura.

## Key Conventions

### Module System
- **ESM only**: `"type": "module"` en `package.json`.
- Los imports requieren extensión `.js`: `import { X } from "./x.js"`.
- **Named exports only**. Nunca `export default`.

### Lint
- ESLint plano (sin Prettier acoplado).
- `pnpm lint` debe pasar antes de cualquier commit.

### Naming
- `camelCase` para variables y funciones.
- `PascalCase` para clases e interfaces (JSDoc `@typedef`).
- `SCREAMING_SNAKE_CASE` para valores de enum.
- Archivos: `kebab-case.js`.

### Errors
- Clases de error custom extienden `Error`.
- Errores de un módulo agrupados en `errors.js` por módulo.
- Usar clase base de error como foundation para routing/transport errors.

### Types
- JSDoc por módulo (no shared types file salvo necesidad real).
- Preferir `interface` (JSDoc `@typedef`) sobre `type` para formas de objeto.

## Common Pitfalls

1. **Olvidar `.js` en imports** — ESM requiere extensiones explícitas.
2. **Importar cruzando límites de módulo** — respetar la tabla de ownership.
3. **Console pollution** — usar `vi.spyOn(console, "log").mockImplementation(() => {})` cuando se introduzcan tests en el futuro.
4. **Scope creep en tasks** — el developer implementa SOLO lo que dice el task; el reviewer lo detecta y rechaza.
5. **API Documentation Sync** — si modificas endpoints HTTP (path, método, body, status, schema), actualiza el spec OpenAPI + tabla en README en el MISMO commit. Ver `docs/conventions.md` §"Documentación".

## References

- [docs/architecture.md](./docs/architecture.md) — Arquitectura completa y componentes.
- [docs/conventions.md](./docs/conventions.md) — Estándares de código.
- [docs/decisions.md](./docs/decisions.md) — Log de decisiones arquitectónicas (ADRs).
- [docs/roadmap.md](./docs/roadmap.md) — Fases y timeline.
- [.opencode/agents/](./.opencode/agents/) — Definiciones de los 5 agentes.
- [feature_list.json](./feature_list.json) — Tracker de features.