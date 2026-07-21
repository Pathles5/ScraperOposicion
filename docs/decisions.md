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

## ADR-003: Scraper ejecutado en Raspberry Pi local vs GitHub Actions

**Fecha:** 2026-07-22
**Estado:** Aceptado

### Contexto
El scraper llevaba dos fases corriendo en GitHub Actions (cron cada 30 min). El usuario quiere migrar a una Raspberry Pi local para tener control total, evitar límites de minutos gratis de GH Actions y poder iterar más rápido.

### Decisión
El scraper se ejecuta en una Raspberry Pi local con systemd timer (cada 5 min). GitHub Actions queda como legacy desactivado (cron comentado, solo `workflow_dispatch` manual).

### Alternativas consideradas
- **Seguir en GitHub Actions** — funciona pero limita la frecuencia (free tier = 2000 min/mes, con cron cada 5 min × 288 polls/día × 30 días = suficiente pero con poco margen) y bloquea iteración.
- **Raspberry Pi + cron** — más simple que systemd pero no espera a la red y no tiene `Restart=on-failure` (ver ADR-005).
- **VPS externo** — más caro y expone el scraper a internet.

### Consecuencias
- **Positivas**: control total del entorno, polling más frecuente (5 min vs 30), independiente de GH Actions, logs locales.
- **Negativas**: requiere mantener la Pi encendida y con red; un reinicio requiere que systemd reanude automáticamente (lo hace con `Wants=network-online.target`).
- **Neutras**: el repo sigue siendo el source-of-truth; `state/` y `logs/` se generan en runtime.

---

## ADR-004: Detección de cambios por fingerprint híbrido (HEAD-first + hash-fallback) vs regex

**Fecha:** 2026-07-22
**Estado:** Aceptado

### Contexto
Fase 1 implementó una regex agnóstica que capturaba cualquier contenido tras "Última actualización:". Esto requirió 2 fixes (task-102 tolerante a multi-línea, task-103 agnóstica al formato). El usuario quiere pasar a una detección más robusta que no dependa de un patrón textual concreto y que soporte webs sin esa etiqueta.

### Decisión
Se adopta detección por **fingerprint**:
1. Petición HEAD; si `Last-Modified` o `ETag` están presentes → guardar y comparar.
2. Si no → GET + SHA-256 sobre HTML normalizado (cheerio elimina `<script>`, `<style>`, comentarios; collapse whitespace).

El fingerprint se guarda en `state/<siteId>.fingerprint` con formato `<tipo>\n<valor>\n`.

### Alternativas consideradas
- **Mantener regex agnóstica** — frágil ante cambios de estructura HTML.
- **Hash SHA-256 del HTML crudo sin normalizar** — demasiados falsos positivos por contenido dinámico (analytics, session IDs).
- **Solo HEAD** — depende de que el servidor envíe headers, no todas las webs lo hacen.
- **Diff visual (rendered HTML)** — overkill para este caso.

### Consecuencias
- **Positivas**: detecta CUALQUIER cambio, no solo el de "Última actualización:"; funciona en webs sin esa etiqueta; universal.
- **Negativas**: descarga el body cuando no hay headers (más bandwidth); puede tener falsos positivos si la web tiene banners rotativos muy agresivos (mitigado por normalización).
- **Neutras**: en sitios con `Last-Modified` válido, el ahorro de bandwidth es notable (HEAD no transfiere body).

---

## ADR-005: Scheduling con systemd timer + service vs cron

**Fecha:** 2026-07-22
**Estado:** Aceptado

### Contexto
La Raspberry Pi ejecuta Linux con systemd (Raspberry Pi OS, basado en Debian 12). Necesitamos lanzar `node monitor.js` cada 5 minutos de forma resiliente.

### Decisión
Se usa **systemd timer + service** (`scripts/raspberry/scraper.service` + `scraper.timer`).

### Alternativas consideradas
- **cron tradicional** — más simple mentalmente (1 línea en crontab) pero:
  - No espera a la red (`After=network-online.target` sí lo hace).
  - Logs dispersos (systemd journal vs syslog/var/log).
  - Sin `Restart=on-failure` automático.
- **node-cron en proceso long-lived** — añade dependencia npm y punto único de fallo (si muere el proceso, no se reinicia sin supervisor).
- **Docker + cron interno** — añade complejidad innecesaria para 1 binario.

### Consecuencias
- **Positivas**: red-espera, logs centralizados (`journalctl -u scraper.service -f`), restart ante fallos, comandos uniformes (`systemctl enable/disable/status`).
- **Negativas**: 2 ficheros extra (`.service` + `.timer`) frente a 1 línea en crontab.
- **Neutras**: requiere usuario con `sudo` para `install.sh`. Una vez instalado, el usuario corriente puede inspeccionar con `systemctl` y `journalctl`.

---

## ADR-006: Persistencia de estado con ficheros planos vs SQLite

**Fecha:** 2026-07-22
**Estado:** Aceptado

### Contexto
Fase 1-2 usaban `state.txt` versionado en el repo (1 línea con la fecha). Fase 3 monitoriza N webs, así que el estado pasa a ser N fingerprints. Necesitamos decidir cómo persistir.

### Decisión
Cada sitio tiene su propio fichero en `state/<siteId>.fingerprint`, formato `<tipo>\n<valor>\n` (donde `tipo` ∈ `{last-modified, etag, sha256}`). Directorio `state/` está en `.gitignore` (con `.gitkeep` para preservar el dir). Escritura atómica: `writeFile(.tmp)` → `rename(.tmp, final)`.

### Alternativas consideradas
- **SQLite (better-sqlite3)** — más robusto para futuro histórico de cambios (timestamps, diffs), pero añade dependencia nativa que complica el deploy en Pi.
- **Un único JSON en `state/state.json`** — más fácil de volcar a un dashboard pero pierde atomicidad si N escrituras concurrentes (no aplica aquí porque es secuencial, pero queremos margen).
- **Variables de entorno / en memoria** — falsos positivos en cada reinicio.

### Consecuencias
- **Positivas**: cero dependencias, depurable con `cat`/`ls`, sobrevive reboots, escritura atómica evita corrupciones.
- **Negativas**: no hay histórico de cambios (solo el último fingerprint por sitio). Si en el futuro se quiere diff histórico, hay que migrar a SQLite (sería una nueva ADR).
- **Neutras**: el flag de "primera ejecución" (`state/.initialized`) vive en el mismo directorio.

---

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