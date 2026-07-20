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

## Módulos

> Se rellena cuando el usuario defina el primer módulo en una fase futura.

| Módulo | Owns | Cannot Import |
|---|---|---|
| (pendiente) | — | — |

## Flujo de datos

> Se documenta cuando exista un flujo end-to-end.

## Diagrama de componentes

> Pendiente. Se añadirá un diagrama cuando haya al menos un módulo implementado.

## Referencias

- [AGENTS.md](../AGENTS.md) — Límites de módulo y reglas de dependencia.
- [docs/conventions.md](./conventions.md) — Estándares de código.
- [docs/decisions.md](./decisions.md) — Decisiones arquitectónicas (ADRs).
- [docs/roadmap.md](./roadmap.md) — Fases y entregables.