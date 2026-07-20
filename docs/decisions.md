# Architectural Decision Records (ADRs)

> Registro cronológico **inverso** de decisiones arquitectónicas significativas. La entrada más reciente va arriba. Cada ADR debe incluir: **Contexto**, **Decisión**, **Alternativas consideradas**, **Consecuencias**.

---

<!-- Plantilla para nuevos ADRs (borrar al usar):

## ADR-NNN: <título corto, imperativo>

**Fecha:** YYYY-MM-DD
**Estado:** Propuesto | Aceptado | Superseded by ADR-XXX

### Contexto
<qué problema estamos resolviendo, qué tensiones hay>

### Decisión
<qué decidimos hacer>

### Alternativas consideradas
- <opción A> — <por qué se descartó>
- <opción B> — <por qué se descartó>

### Consecuencias
- Positivas: ...
- Negativas: ...
- Neutras: ...

-->

## ADR-001: Bootstrap con agent swarm y Spec-Driven Development (SDD)

**Fecha:** 2026-07-20
**Estado:** Aceptado

### Contexto
Arrancamos un proyecto Node.js desde cero y necesitamos un flujo de trabajo repetible y verificable para evitar scope creep, deuda de documentación y commits caóticos. Las opciones evaluadas eran: (a) workflow ad-hoc sin estructura, (b) workflow con TodoWrite puntual pero sin harness, (c) agent swarm con SDD.

### Decisión
Adoptamos un agent swarm de 5 roles (leader, explorer, developer, reviewer, documenter) definidos en `.opencode/agents/*.md`. Todo trabajo se planifica como una **fase** (HANDOFF) que se fragmenta en **tasks** (`task-{X}{NN}-{name}.md`). Cada task pasa por implementar (developer) → revisar (reviewer) → commit (leader). Documentación canónica en `docs/`, mantenida por el leader al cierre de cada fase.

### Alternativas consideradas
- **Workflow ad-hoc** — rápido al principio, pero acumula decisiones implícitas sin trazabilidad.
- **TodoWrite puntual sin harness** — útil para sesiones cortas, no escala cuando hay múltiples fases.
- **Documenter agent como owner de docs** — descartado por fricción; el leader aplica docs directamente al cierre de cada fase. El agent existe como referencia.

### Consecuencias
- **Positivas**: trazabilidad completa (cada commit cierra al menos un task verificable); decisiones arquitectónicas se persisten como ADRs; scope creep se detecta en review.
- **Negativas**: overhead inicial alto; requiere disciplina para no saltarse el HANDOFF.
- **Neutras**: el usuario es el aprobador final de cada HANDOFF; el leader no delega sin OK explícito.

---

## ADR-002: Sin suite de tests por defecto

**Fecha:** 2026-07-20
**Estado:** Aceptado

### Contexto
El usuario indicó explícitamente "No queremos TEST, nada" durante el bootstrap. La pregunta es si el verification order queda solo con `pnpm lint` o si dejamos preparado el terreno para introducir tests en una fase futura.

### Decisión
El verification order canónico es **solo `pnpm lint`**. No creamos carpeta `tests/`, no añadimos test framework al `package.json`, no añadimos sección de testing en `docs/conventions.md`. Si en una fase futura se decide introducir tests, será una nueva decisión (ADR) que actualizará conventions y verificación.

### Alternativas consideradas
- **Incluir Vitest por defecto** — descartado por instrucción explícita del usuario.
- **Dejar comandos `pnpm test` como no-op** — descartado para evitar confusión; el README y AGENTS.md no mencionan tests.

### Consecuencias
- **Positivas**: respeta la decisión del usuario; minimiza dependencias.
- **Negativas**: el quality gate del reviewer depende solo de lint + lectura crítica del código.
- **Neutras**: cuando se introduzcan tests en el futuro, este ADR se marcará como *Superseded*.