# Session Context

> Snapshot persistente del estado del proyecto al cierre de cada sesión.
> Se commitea desde Fase 3 (revierte la regla "no se commitea" de Fase 0). Antes de cada cierre de sesión, el leader actualiza este fichero con: estado, decisiones, commits, próximos pasos y notas operativas.

---

## Estado Actual del Proyecto (2026-07-22 — cierre de sesión)

### Ramas y commits

- **Rama activa:** `local` (trackea `origin/local`)
- **Último commit:** `03bd2bb fix(notify): use Madrid local time in Telegram message timestamp`
- **Diferencia con origin:** 6 commits ahead (todos pushed)
- **Working tree:** limpio salvo `.opencode/tasks/task-304-cleanup-docs-adrs.md` untracked

### Fases

| Fase | Estado | Commit de cierre |
|---|---|---|
| 0 — Foundation | ✅ Completado | `ea890ba chore: bootstrap project documentation` |
| 1 — Monitor CM Educacion | ✅ Completado | `5d57fce docs: register Fase 1 close` |
| 2 — Notificación Telegram | ✅ Completado | `afc2e2b docs: register Fase 2 close` |
| 3 — Scraper local Raspberry Pi | ✅ Completado | `ab56ed7 docs: register Fase 3 close` + 2 commits de cleanup (`3040920`, `03bd2bb`) |

### ADRs registrados (6)

| ID | Título | Sustituye |
|---|---|---|
| 001 | Agent swarm + SDD | n/a |
| 002 | Sin suite de tests por defecto | n/a |
| 003 | Scraper ejecutado en Raspberry Pi local vs GitHub Actions | workflow GH Actions (legacy) |
| 004 | Detección por fingerprint híbrido (HEAD-first + SHA-256 fallback) | regex agnóstica de Fase 1 |
| 005 | Scheduling con systemd timer + service vs cron | n/a (nuevo) |
| 006 | Persistencia con ficheros planos vs SQLite | `state.txt` versionado |

### Features en `feature_list.json` (4, todas completed)

| ID | Fase | Descripción breve |
|---|---|---|
| `monitor-cm-edu` | 1 | Monitor CM Educacion original (regex + GH Actions). Sustituido por `multi-site-hash`. |
| `telegram-notify` | 2 | Notificación Telegram via Bot API. Sustituido por `multi-site-hash`. |
| `multi-site-hash` | 3 | Detección multi-site híbrida + always-notify + persistencia atómica. |
| `raspberry-local-scraper` | 3 | systemd timer + service + install.sh + logging rotado. |

---

## Cambios de esta sesión (2026-07-22)

### Resumen ejecutivo

Esta sesión retomó el HANDOFF-FASE-3.md que estaba en estado DRAFT desde 2026-07-22 (mañana). El usuario dijo "continua" y:

1. **Recopilé las 6 decisiones pendientes (P1–P6)** del HANDOFF y las planteé al usuario.
2. **Discutí la estrategia de detección de cambios** (3 alternativas: HEAD-first puro, hash SHA-256 puro, híbrido) → el usuario eligió **híbrido HEAD-first con fallback a hash SHA-256 normalizado** (D10').
3. **Reescribí el HANDOFF** consolidando D1–D9 + D10' + D11–D16.
4. **Creé 4 tasks** (`task-301..304`) en `.opencode/tasks/`.
5. **Iteré las 4 tasks** con el flujo `developer → reviewer → commit`:
   - 3 veredictos APROBADO.
   - 1 veredicto APROBADO_CON_OBSERVACIONES (task-303: chmod workflow + limitaciones de logging inherentes al spec).
6. **Apliqué 2 commits de cleanup** post-Fase 3 por feedback directo del usuario:
   - Mover `sites.json` de `.opencode/config/` a raíz + eliminar `.github/workflows/monitor.yml`.
   - Cambiar el timestamp del mensaje Telegram de UTC a hora local Madrid (Europe/Madrid, DST-aware).

### Commits realizados (6)

```
03bd2bb fix(notify): use Madrid local time in Telegram message timestamp
3040920 chore(repo): move sites.json to root + drop GitHub Actions workflow
ab56ed7 docs: register Fase 3 close + multi-site + systemd + 4 ADRs
789ee73 feat(raspberry): systemd timer + service + install script + rotated logging
223d4cb feat(monitor): real Telegram notification with always-notify + Markdown
59f4c0b feat(monitor): multi-site fingerprint detection (HEAD-first + SHA-256 fallback)
```

### Decisiones clave validadas con el usuario

- **D1** (Fase 3 inicio): scraper en Raspberry Pi local, GH Actions queda como legacy.
- **D2**: polling cada 5 minutos.
- **D3**: cada consulta envía mensaje a Telegram aunque NO haya cambios.
- **D4**: detección pasa de regex a fingerprint del HTML.
- **D5**: monitorización de 2 webs (1 CM Educacion + 1 CM Sede).
- **D6**: segunda web = `https://sede.comunidad.madrid/oferta-empleo/oposiciones-maestros-2026`.
- **D7**: política notify = cada poll = 1 mensaje (288/día, literal de D3).
- **D8**: formato = 1 único mensaje Markdown con estado de ambas webs.
- **D9**: persistencia del fingerprint entre reinicios = fichero `state/<siteId>.fingerprint`.
- **D10'**: detección híbrida HEAD-first (Last-Modified/ETag) con fallback a SHA-256 sobre HTML normalizado (cheerio strips scripts/styles/comments, whitespace colapsado).
- **D11**: scheduling = systemd timer + service (vs cron) — justificado por `After=network-online.target`, `Restart=on-failure`, `journalctl`.
- **D12**: logging = `journalctl` + `logs/scraper.log` rotado (1 MB → 500 KB).
- **D13**: estructura de estado = `state/<siteId>.fingerprint` (elimina `state.txt`).
- **D14**: lista de sitios en `sites.json` (raíz, NO en `.opencode/config/`).
- **D15**: primera ejecución → mensaje "🟢 Monitor arrancado" sin marcar como cambio.
- **D16**: escritura atómica del fingerprint (`writeFile.tmp` + `rename`).
- **D17** (post-Fase 3, sesión actual): timestamp del mensaje Telegram en hora local Madrid (Europe/Madrid), DST-aware, vía `Intl.DateTimeFormat` nativo.
- **D18** (post-Fase 3, sesión actual): **reversión de D3/D7/D8**. Política de notificación vuelve a `solo cuando hay cambios` por defecto. Se añade switch de debug `SCRAPER_DEBUG=1` (env var) para forzar always-notify. Razón: el usuario reconsideró tras probar — el always-notify producía demasiado ruido en Telegram. El switch queda documentado en `scripts/raspberry/telegram.env.example` (línea comentada) y `scripts/raspberry/scraper.service` (línea comentada).

### Decisiones revertidas durante la sesión

- **`sites.json` location**: inicialmente planificado en `.opencode/config/sites.json` (D14). El usuario corrigió post-Fase 3 → movido a raíz. Razón: `.opencode/` es harness de agentes, no producto.
- **GitHub Actions retention**: inicialmente "cron comentado, workflow queda como legacy". El usuario corrigió post-Fase 3 → workflow completo eliminado del repo. Razón: "en esta rama no vamos a tener workflows".

### Desviaciones de los specs durante la sesión (todas justificadas)

1. **task-302 — `await` añadido a `sendTelegramSummary` en `main()`**: el spec tenía un typo; sin `await`, las rejections de Telegram no se propagaban al `.catch()` de `main()` (unhandled promise rejection). Reviewer confirmó que era un fix necesario, no scope creep.
2. **task-303 — `chmod +x` aplicado al index de git para `.sh`**: los archivos tenían modo 755 en filesystem pero Git index los registró como 644. Leader ejecutó `git update-index --chmod=+x` antes del commit.
3. **task-304 — BOM UTF-8 eliminado de `feature_list.json`**: el BOM hacía fallar `JSON.parse(...)`. Fix legítimo, no scope creep.
4. **task-304 — `task-301/302/303` archivados aparecen como `new file` (no `rename`)**: los specs estaban untracked antes de la task, así que `git mv` requirió `git add` previo. La historia del filesystem es correcta, solo cambia la etiqueta del diff.
5. **task-304 — `SESSION_CONTEXT.md` staged con `git add -f`**: estaba en `.gitignore` por convención de Fase 0 ("no se commitea"). El spec de task-304 revirtió esa regla para commitear el contexto actualizado.
6. **task-304 leader fix — 4 secciones de `README.md` actualizadas directamente por el leader**: el spec no las incluía pero quedaban en estado Fase 1/2 (intro, Project Structure, Architecture table, Tech Stack). El leader las arregló antes de commitear para evitar abrir una task-305.

### Limitaciones conocidas del código actual

- **Detección HEAD-first activa en ambas URLs reales** (`comunidad.madrid` y `sede.comunidad.madrid`): ambas responden con `Last-Modified`. El fallback SHA-256 está implementado pero no se ha ejercitado en producción todavía.
- **Logs ERROR pueden perderse en crash paths**: `logToFile` es fire-and-forget; la línea `[ERROR ...]` puede no llegar a `logs/scraper.log` si el proceso termina antes de que `appendFile` complete. El stderr sí queda capturado por `journal` vía `StandardError=journal`, así que el error no se pierde del todo.
- **`state/.initialized` se marca ANTES del envío Telegram**: si Telegram falla en el primer poll, en el siguiente poll el flag ya está puesto y no se re-enviará "🟢 Monitor arrancado". Comportamiento del spec, no bug.
- **`systemd-analyze verify` no validado en dev** (Windows + WSL stub): la validación del syntax INI de los units queda para el primer deploy real en la Pi.
- **BOM en HANDOFF-FASE-3.md**: presente al cierre (cosmético, no rompe nada).

---

## Próximos pasos al reabrir la sesión

### Inmediatos (orden recomendado)

1. **Push a `origin/local`** — ya hecho en esta sesión. Si la rama queda atrás por algún push remoto, rebase.
2. **Merge `local` → `main`** (opcional, decisión del usuario): el spec del HANDOFF §9.8 lo deja al usuario tras validación en Pi.
3. **Deploy en Raspberry Pi real** (cuando el usuario decida probarlo):
   ```bash
   cd /opt
   sudo git clone https://github.com/<owner>/scraper-oposicion.git
   sudo chown -R $USER:$USER /opt/scraper-oposicion
   cd /opt/scraper-oposicion
   pnpm install --production
   sudo cp scripts/raspberry/telegram.env.example /etc/scraper-oposicion/telegram.env
   sudo nano /etc/scraper-oposicion/telegram.env   # rellenar tokens
   sudo ./scripts/raspberry/install.sh
   ```
   Verificar con `systemctl status scraper.timer` y `journalctl -u scraper.service -f`.
4. **Validación 24h** (primer `next_actions` en `feature_list.json`): comprobar que no hay falsos positivos y que `Restart=on-failure` funciona ante errores transitorios.
5. **Validación con credenciales reales**: el developer no tenía `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` en su entorno dev, así que el envío real solo se probará cuando el bot corra en la Pi con `/etc/scraper-oposicion/telegram.env` configurado.

### Opcionales (limpieza)

6. **Archivar `task-304-cleanup-docs-adrs.md`**: sigue untracked. Si quieres, `git mv` a `.archived.md` y commit. Convención del proyecto: archivado al cierre de fase.
7. **Limpiar BOM de HANDOFF-FASE-3.md**: cosmético.
8. **Forzar `systemd-analyze verify`** en Pi para validar syntax INI de los units.

### Ideas para Fase 4 (NO iniciadas, solo documentadas como referencia)

- Histórico de cambios con SQLite (timestamps + diffs por sitio). ADR-006 lo menciona como motivación para SQLite si en el futuro se quiere diff histórico.
- Dashboard web mínimo que muestre el estado actual de los sitios.
- Integración con Discord o ntfy.sh como canales alternativos (Fase 4+) — el spec lo puso fuera de alcance en Fase 3.
- Tests (ADR-002 vigente: solo `pnpm lint`).
- Refactor a arquitectura hexagonal (también fuera de alcance en Fase 3).

---

## Cómo retomar la sesión

1. **Salir de esta sesión y volver más tarde.** El contexto completo está aquí.
2. **Al volver**, el leader debe:
   - Leer este fichero (especialmente "Cambios de esta sesión" y "Próximos pasos").
   - Verificar `git log --oneline -10` para confirmar el último commit (`03bd2bb`).
   - Verificar `git status` para confirmar working tree limpio.
   - Preguntar al usuario: "¿Seguimos con el deploy en Pi o quieres empezar Fase 4?"
3. **No re-preguntar decisiones D1–D17** ya validadas — están documentadas arriba.

---

## Archivos clave para referencia rápida

| Fichero | Para qué sirve |
|---|---|
| `monitor.js` | Entry point. 7 secciones (config, scraping, fingerprint, persistencia, first-run, notify, logging). |
| `sites.json` | Lista declarativa de 2 webs CM. |
| `state/<siteId>.fingerprint` | Estado runtime por sitio (gitignored). Contiene `<tipo>\n<valor>\n`. |
| `state/.initialized` | Flag primera ejecución (gitignored). |
| `logs/scraper.log` | Logs con rotación (gitignored). 1 MB → 500 KB. |
| `.env` | Credenciales Telegram para dev local (gitignored). |
| `scripts/raspberry/telegram.env.example` | Plantilla para `/etc/scraper-oposicion/telegram.env` en la Pi. |
| `scripts/raspberry/scraper.service` + `scraper.timer` | systemd units. |
| `scripts/raspberry/install.sh` | Idempotente: clona proyecto + crea `/etc/scraper-oposicion/telegram.env` desde .example + instala units + enable timer. |
| `docs/decisions.md` | 6 ADRs (001-006). |
| `docs/architecture.md` | Diagrama de flujo + componentes Fase 3. |
| `docs/roadmap.md` | Roadmap con las 4 fases marcadas como Completado. |
| `.opencode/tasks/HANDOFF-FASE-3.md` | Histórico del planning de Fase 3 (cerrada, no modificar). |
| `.opencode/tasks/task-301..303-*.archived.md` | Specs archivados de las 3 tasks de implementación. |
| `.opencode/tasks/task-304-cleanup-docs-adrs.md` | Spec de la task de cierre (untracked, archivado opcional). |

---

## Notas operativas

- **Working directory del agent:** `C:\Users\pathl\Workspace\ScraperOposicion`.
- **Shell:** PowerShell 5.1 en Windows. El developer tuvo que usar Git Bash (`C:\Program Files\Git\bin\bash.exe`) para `bash -n` de los scripts.
- **Permisos:** `permission: allow` global en `~/.config/opencode/opencode.json`. Los agentes tienen permisos ampliados commiteados en `.opencode/agents/*.md`.
- **Push al cerrar:** hecho. `origin/local` está 6 commits ahead de cuando empezó esta sesión.
- **Convención archivado tasks**: tras cierre de fase, los specs se renombran a `.archived.md` para preservar histórico sin contaminar el directorio activo. `task-304` quedó fuera de este ciclo (untracked) — archivado a criterio del usuario.