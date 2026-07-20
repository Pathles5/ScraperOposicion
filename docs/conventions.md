# Conventions

> Estándares de código que cualquier agente o contributor debe respetar. La fuente de verdad es este documento + el código real; ante conflicto, gana el código y se actualiza este archivo.

## Sistema de módulos

- **ESM only**: `"type": "module"` en `package.json`.
- Los imports requieren extensión `.js`: `import { X } from "./x.js"`.
- **Named exports** exclusivamente. Nunca `export default`.

## Naming

| Tipo | Convención | Ejemplo |
|---|---|---|
| Variables | `camelCase` | `userId`, `parsePayload` |
| Funciones | `camelCase` | `validateInput` |
| Clases | `PascalCase` | `RelayAdapter` |
| Interfaces / tipos (JSDoc) | `PascalCase` | `UserPayload` |
| Enums (valores) | `SCREAMING_SNAKE_CASE` | `STATUS_OK` |
| Archivos | `kebab-case.js` | `relay-adapter.js` |
| Directorios | `kebab-case` | `adapters/`, `gateway/` |

## Errores

- Toda clase de error custom **extiende `Error`**.
- Los errores de un módulo se agrupan en un `errors.js` por módulo.
- Usar una clase base de error como foundation para routing/transport errors.

## JSDoc

- Toda clase y función **exportada** lleva JSDoc con `@param`, `@returns` y `@throws` cuando aplique.
- Preferir `interface` sobre `type` para formas de objeto (`@typedef` con `@property`).

## Validación por commit

```bash
pnpm lint
```

> Este proyecto **no incluye suite de tests** por decisión explícita del usuario en el bootstrap. Si en una fase futura se introducen tests, el verification order pasará a ser `pnpm lint && pnpm test`.

## Mensajes de commit

Formato: `<type>(<scope>): <description>`

Tipos válidos (conventional-commits):

| Tipo | Uso |
|---|---|
| `feat` | Nueva feature |
| `fix` | Bug fix |
| `refactor` | Cambio interno sin cambio de comportamiento |
| `docs` | Solo documentación |
| `chore` | Tareas de mantenimiento (deps, build, config) |

Ejemplos:

- `feat(gateway): add circuit breaker to relay`
- `fix(gateway): handle empty test cases`
- `docs(readme): update architecture diagram`
- `chore(deps): bump eslint to v9`

## Documentación

- Todo endpoint HTTP modificado debe sincronizar **en el mismo commit**:
  - El contrato OpenAPI (`src/<...>/openapi/spec.yaml` o equivalente).
  - La tabla de endpoints en `README.md`.
  - `docs/architecture.md` si cambia el flujo HTTP.
- Toda decisión arquitectónica significativa se registra en `docs/decisions.md` como ADR.

## Referencias

- [docs/architecture.md](./architecture.md) — Estructura del proyecto.
- [docs/decisions.md](./decisions.md) — ADRs.