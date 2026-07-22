# Task 304: Cleanup + docs + ADRs + desactivar cron GH Actions (cierre de Fase 3)

**Fase:** 3
**Agente asignado:** developer (con apoyo del leader para commits de docs)
**Estado:** Pendiente de implementación (depende de task-301, task-302, task-303 APROBADOS)
**HANDOFF:** `.opencode/tasks/HANDOFF-FASE-3.md`
**Task anterior:** task-303
**Task siguiente:** ninguna (esta task cierra la fase)

## Objetivo

Cerrar la Fase 3 con todos los entregables de documentación sincronizados, los 4 ADRs registrados, el workflow de GitHub Actions desactivado (queda como legacy), y el `feature_list.json` actualizado. Esta task es mayoritariamente documental — la única modificación de código es comentar el `schedule:` del workflow.

## Contexto

- Las tasks 301-303 ya están implementadas y aprobadas.
- Falta sincronizar la documentación para que refleje la realidad.
- AGENTS.md exige: "Si la fase tocó endpoints HTTP: OpenAPI spec + tabla en README sincronizados en el MISMO commit." → **NO aplica** (no se ha tocado ningún endpoint HTTP — solo cliente saliente a `api.telegram.org` y a las 2 webs CM).
- El workflow GH Actions `.github/workflows/monitor.yml` actualmente corre en cron y **debe** desactivarse para evitar duplicación con el systemd timer de la Pi.

## Archivos a crear / modificar

| Path | Acción |
|---|---|
| `.github/workflows/monitor.yml` | **Modificar** — comentar `schedule:` |
| `CHANGELOG.md` | **Modificar** — entrada Fase 3 |
| `README.md` | **Modificar** — sección "Running locally on Raspberry Pi" + actualizar tabla de endpoints si aplica |
| `docs/architecture.md` | **Modificar** — diagrama actualizado |
| `docs/roadmap.md` | **Modificar** — marcar Fase 3 Completado |
| `docs/decisions.md` | **Modificar** — añadir ADR-003, 004, 005, 006 |
| `feature_list.json` | **Modificar** — añadir 2 features nuevas y marcarlas completadas |
| `SESSION_CONTEXT.md` | **Modificar** — actualizar estado |
| `.opencode/tasks/HANDOFF-FASE-3.md` | **Modificar** — marcar como Completed (opcional) |
| `.opencode/tasks/task-301..303-*.md` | **Archivar** — renombrar a `*.archived.md` (convención del proyecto) |

## 1) `.github/workflows/monitor.yml`

Comentar el bloque `schedule:` para evitar duplicación con el systemd timer:

```yaml
name: Monitor Oposiciones CM

# Legacy / fallback manual desde 2026-07-22 (Fase 3).
# El cron está DESACTIVADO porque el bot ahora corre en una Raspberry Pi
# con systemd timer (cada 5 min). Este workflow queda para ejecución manual
# de emergencia (workflow_dispatch) o para validar el setup localmente.
# Para reactivar, descomentar el bloque schedule: y dejar que la Pi siga corriendo
# (¡generará doble notificación!).

on:
  workflow_dispatch:
  # schedule:
  #   - cron: '5,35 * * * *'
```

> NO eliminar el workflow. La convención del proyecto es mantener workflows desactivados (ver HANDOFF-FASE-3 §8 "Fuera de alcance").

## 2) `CHANGELOG.md`

Añadir entrada al principio (debajo del título, formato inverso cronológico como el resto):

```markdown
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
```

## 3) `README.md`

Localizar la sección actual (Fase 1/2 hablaba de GitHub Actions). Añadir/actualizar:

- **Tagline** (si cambia): "Monitor multi-site de oposiciones CM ejecutándose en Raspberry Pi".
- **Sección "Running locally on Raspberry Pi"** (NUEVA): redirigir a `scripts/raspberry/README.md` con un resumen:
  ```markdown
  ## Running locally on Raspberry Pi

  El scraper se ejecuta en una Raspberry Pi con systemd timer (cada 5 min).
  Para desplegar:

  1. Clonar el repo en `/opt/scraper-oposicion`.
  2. Configurar credenciales en `/etc/scraper-oposicion/telegram.env`.
  3. Ejecutar `./scripts/raspberry/install.sh`.

  Detalle completo: [`scripts/raspberry/README.md`](scripts/raspberry/README.md).

  ### Useful commands

  ```bash
  systemctl status scraper.timer          # estado del timer
  systemctl list-timers scraper.timer     # próxima ejecución
  journalctl -u scraper.service -f        # logs en vivo
  tail -f /opt/scraper-oposicion/logs/scraper.log   # logs fichero rotado
  ```

  ### GitHub Actions (legacy)

  El workflow `.github/workflows/monitor.yml` está desactivado (cron comentado) y solo
  se ejecuta vía `workflow_dispatch` manual. El bot principal corre en la Raspberry Pi.
  ```

- **Tabla de endpoints** (en la sección "API" si existe): si no hay endpoints HTTP propios, no aplica. Si existe la tabla, mantener como está (no se han tocado endpoints en esta fase).

## 4) `docs/architecture.md`

Actualizar el diagrama y la descripción para reflejar el nuevo flujo:

```markdown
## Flujo de ejecución (Fase 3)

```
┌──────────────────────────────────────────────────────────────────┐
│                       Raspberry Pi                                │
│                                                                  │
│  systemd timer (cada 5 min)                                      │
│         │                                                        │
│         ▼                                                        │
│  systemd service (oneshot)                                       │
│         │                                                        │
│         ▼                                                        │
│  node monitor.js                                                 │
│     │                                                            │
│     ├─ loadSites() ←── .opencode/config/sites.json              │
│     │                                                            │
│     └─ for each site:                                            │
│          ├─ fetchHead(url) → { lastModified, etag }              │
│          │   └─ Si presentes: usar como fingerprint              │
│          ├─ else:                                                │
│          │   ├─ fetchPage(url) → html                            │
│          │   └─ normalizeAndHash(html) → sha256 (cheerio)        │
│          ├─ loadStoredFingerprint(siteId) ← state/<id>.fp        │
│          ├─ compare: changed = current !== previous              │
│          ├─ saveStoredFingerprint(siteId, current)  [atomic]     │
│          └─ registrar en summary                                 │
│                                                                  │
│  sendTelegramSummary(summary) → POST api.telegram.org           │
│         │                                                        │
│         ▼                                                        │
│  exit 0                                                          │
└──────────────────────────────────────────────────────────────────┘
```

## Componentes (Fase 3)

- **Sites config** (`.opencode/config/sites.json`): declarativo, commiteable.
- **State store** (`state/<siteId>.fingerprint`): fichero plano por sitio, escritura atómica.
- **Detection engine** (`monitor.js`): híbrido HEAD-first / hash-fallback.
- **Notifier** (`sendTelegramSummary` en `monitor.js`): 1 mensaje Markdown.
- **Scheduler** (systemd): `scripts/raspberry/scraper.timer` + `scraper.service`.
- **Logger** (dual): `journalctl` + `logs/scraper.log` rotado.
```

Sustituir el diagrama y la sección "Componentes" existentes. Mantener el resto del documento intacto.

## 5) `docs/roadmap.md`

Añadir bloque al final de la lista de fases:

```markdown
## Fase 3: Scraper local en Raspberry Pi (multi-site + hash)

**Estado:** Completado
**Fecha:** 2026-07-22

Entregables:

- `monitor.js` → refactor a multi-site con detección híbrida HEAD-first / SHA-256 (fallback).
- `.opencode/config/sites.json` → 2 webs declaradas (CM Educacion + CM Sede).
- `state/<siteId>.fingerprint` → persistencia por sitio (atomic write).
- `sendTelegramSummary` → 1 mensaje Markdown con N sitios, política always-notify (288/día).
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
```

## 6) `docs/decisions.md`

Añadir al principio (orden inverso cronológico) los 4 ADRs nuevos. **Plantilla** (basada en la sección "Plantilla para nuevos ADRs" del propio documento):

```markdown
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
```

## 7) `feature_list.json`

Modificar el JSON:

```json
{
  "project": "scraper-oposicion",
  "version": "1.1",
  "last_updated": "2026-07-22",
  "features": [
    {
      "id": "raspberry-local-scraper",
      "name": "Scraper local en Raspberry Pi con systemd timer",
      "phase": 3,
      "status": "completed",
      "completed_at": "2026-07-22",
      "description": "El scraper se ejecuta en una Raspberry Pi local con systemd timer + service (cada 5 min). Logs a journalctl + fichero rotado. Variables de entorno via /etc/scraper-oposicion/telegram.env. Workflow GH Actions desactivado (legacy).",
      "files": [
        "scripts/raspberry/scraper.service",
        "scripts/raspberry/scraper.timer",
        "scripts/raspberry/install.sh",
        "scripts/raspberry/uninstall.sh",
        "scripts/raspberry/README.md",
        "scripts/raspberry/telegram.env.example",
        ".github/workflows/monitor.yml"
      ],
      "task_ref": ".opencode/tasks/task-303-systemd-setup.md",
      "handoff_ref": ".opencode/tasks/HANDOFF-FASE-3.md"
    },
    {
      "id": "multi-site-hash",
      "name": "Deteccion multi-site por fingerprint hibrido",
      "phase": 3,
      "status": "completed",
      "completed_at": "2026-07-22",
      "description": "monitor.js monitoriza N webs declaradas en .opencode/config/sites.json. Deteccion hibrida: HEAD-first (Last-Modified/ETag) con fallback a SHA-256 sobre HTML normalizado. Persistencia atomica en state/<siteId>.fingerprint. Politica always-notify: 1 mensaje Markdown por poll con el estado de todas las webs.",
      "files": [
        "monitor.js",
        ".opencode/config/sites.json",
        "state/.gitkeep",
        ".gitignore"
      ],
      "task_ref": ".opencode/tasks/task-301-multi-site-detection.md",
      "handoff_ref": ".opencode/tasks/HANDOFF-FASE-3.md"
    },
    {
      "id": "monitor-cm-edu",
      "name": "Monitor CM Educacion (oposiciones maestros)",
      "phase": 1,
      "status": "completed",
      "completed_at": "2026-07-20",
      "description": "Bot autonomo que monitoriza https://www.comunidad.madrid/educacion/procesos-selectivos-oposiciones-maestros y detecta cambios en el contenido de 'Ultima actualizacion:' mediante regex agnostica. Si cambia, llama notifyChange (Telegram en Fase 2) y actualiza state.txt. GitHub Actions ejecuta cada 30 min en :05/:35 UTC. (Reemplazado por multi-site-hash en Fase 3.)",
      "files": [
        "monitor.js",
        "state.txt",
        ".github/workflows/monitor.yml",
        "package.json",
        "eslint.config.js"
      ],
      "task_ref": ".opencode/tasks/task-101-monitor-cm.md",
      "handoff_ref": ".opencode/tasks/HANDOFF-FASE-1.md"
    },
    {
      "id": "telegram-notify",
      "name": "Notificacion Telegram via Bot API",
      "phase": 2,
      "status": "completed",
      "completed_at": "2026-07-20",
      "description": "Cuando el monitor detecta un cambio, envia un mensaje Markdown al chat de Telegram configurado via Telegram Bot API (POST a /sendMessage). Lee TELEGRAM_BOT_TOKEN y TELEGRAM_CHAT_ID de process.env. Throw claro si faltan. Bot del usuario: @OposicionCamBot. (Sustituido por sendTelegramSummary en Fase 3.)",
      "files": [
        "monitor.js",
        ".github/workflows/monitor.yml"
      ],
      "task_ref": ".opencode/tasks/task-104-telegram-integration.md"
    }
  ],
  "phase_summary": {
    "0": {
      "name": "Foundation",
      "status": "completed",
      "completed_at": "2026-07-20",
      "features": []
    },
    "1": {
      "name": "Monitor de Oposiciones CM",
      "status": "completed",
      "completed_at": "2026-07-20",
      "features": ["monitor-cm-edu"]
    },
    "2": {
      "name": "Notificacion Telegram",
      "status": "completed",
      "completed_at": "2026-07-20",
      "features": ["telegram-notify"]
    },
    "3": {
      "name": "Scraper local en Raspberry Pi (multi-site + hash)",
      "status": "completed",
      "completed_at": "2026-07-22",
      "features": ["raspberry-local-scraper", "multi-site-hash"]
    }
  },
  "next_actions": [
    "Validar el deploy en la Raspberry Pi real ejecutando scripts/raspberry/install.sh y comprobando systemctl status scraper.timer.",
    "Tras 24h en producción, revisar logs/scraper.log y journalctl para validar que no hay falsos positivos."
  ]
}
```

> Mantener la indentación JSON exacta (2 espacios). Validar con `node -e "JSON.parse(require('fs').readFileSync('feature_list.json','utf8'))"`.

## 8) `SESSION_CONTEXT.md`

Actualizar la sección "Estado Actual del Proyecto":

```markdown
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
```

## 9) Archivar tasks (convención del proyecto)

Las tasks se renombran al cierre de cada fase para preservar histórico sin contaminar el directorio activo. Ejecutar:

```bash
cd C:\Users\pathl\Workspace\ScraperOposicion
git mv .opencode/tasks/task-301-multi-site-detection.md .opencode/tasks/task-301-multi-site-detection.archived.md
git mv .opencode/tasks/task-302-telegram-always-notify.md .opencode/tasks/task-302-telegram-always-notify.archived.md
git mv .opencode/tasks/task-303-systemd-setup.md .opencode/tasks/task-303-systemd-setup.archived.md
# task-304 NO se archiva aún — ver nota abajo
```

> **Nota**: `task-304` se archiva DESPUÉS de cerrar la fase (en un commit separado, idealmente por el leader). La convención del proyecto es que el archivo de la task de cierre queda vivo hasta que se confirma el cierre completo, y luego se archiva. Para esta task en particular, archivarla en el mismo commit de cierre si el usuario lo prefiere — **preguntar al leader antes de hacer el `git mv`**.

## 10) `HANDOFF-FASE-3.md` (opcional)

Añadir al principio (debajo del título):

```markdown
> **Estado final**: ✅ Completado el 2026-07-22. Ver CHANGELOG.md y feature_list.json para los entregables.
```

## Restricciones

- ❌ NO modificar `monitor.js` ni los systemd units (ya cerrados en tasks previas).
- ❌ NO añadir dependencias npm.
- ❌ NO eliminar el workflow `.github/workflows/monitor.yml` (solo comentar el `schedule:`).
- ❌ NO crear ficheros nuevos fuera de los listados.
- ❌ NO commit. **Esta task la cierra el leader con un commit de cierre de fase**, no el developer. El developer solo deja todos los cambios staged en working tree.
- ✅ Mantener la indentación JSON exacta en `feature_list.json`.
- ✅ Mantener orden inverso cronológico en `CHANGELOG.md` y `docs/decisions.md`.
- ✅ Validar `feature_list.json` con `node -e "JSON.parse(...)"`.

## Validación local (obligatoria)

### 10.1 Lint final

```bash
cd C:\Users\pathl\Workspace\ScraperOposicion
pnpm lint
```

Debe pasar exit 0 (no se han tocado .js, pero verifica que el repo entero está limpio).

### 10.2 Validar JSON de feature_list.json

```bash
node -e "JSON.parse(require('fs').readFileSync('feature_list.json','utf8'))"
echo "JSON OK"
```

Exit 0.

### 10.3 Validar sintaxis de los docs Markdown (opcional)

Si tienes `markdownlint`:

```bash
markdownlint docs/decisions.md docs/roadmap.md CHANGELOG.md README.md
```

Si no, al menos verifica visualmente que las tablas y listas están bien formadas.

### 10.4 Listado final de cambios staged

```bash
git status
git diff --stat
```

Reportar al leader. **No commitear.**

## Entregable del developer

Reporta:

1. Output literal de `pnpm lint`.
2. Output literal de la validación JSON de `feature_list.json`.
3. `git status` (debe mostrar todos los cambios de las 4 docs + el workflow + el SESSION_CONTEXT + el HANDOFF + los git mv de archivado, sin nada raro).
4. `git diff --stat` (resumen de líneas modificadas).
5. Confirmación de que NO has hecho commit.

**Tras esto, el leader cierra la fase con un commit `feat(raspberry): close Fase 3 — multi-site + systemd + docs + ADRs`.**