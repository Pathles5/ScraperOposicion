# Session Context

> Snapshot persistente del estado del proyecto al cierre de cada sesión.
> Se commitea desde Fase 3 (revierte la regla "no se commitea" de Fase 0). Antes de cada cierre de sesión, el leader actualiza este fichero con: estado, decisiones, commits, próximos pasos y notas operativas.

---

## Estado Actual del Proyecto (2026-07-22 — cierre de sesión)

### Ramas y commits

- **Rama activa:** `local` (trackea `origin/local`)
- **Último commit:** `a57d1c8 fix(deploy): install.sh auto-detects node path and accepts custom install dir`
- **Diferencia con origin:** 9 commits ahead (todos pushed)
- **Working tree:** limpio

### Fases

| Fase | Estado | Commit de cierre |
|---|---|---|
| 0 — Foundation | ✅ Completado | `ea890ba chore: bootstrap project documentation` |
| 1 — Monitor CM Educacion | ✅ Completado | `5d57fce docs: register Fase 1 close` |
| 2 — Notificación Telegram | ✅ Completado | `afc2e2b docs: register Fase 2 close` |
| 3 — Scraper local Raspberry Pi | ✅ Completado | `ab56ed7 docs: register Fase 3 close` + 5 commits posteriores (`3040920`, `03bd2bb`, `b82435b`, `a58d012`, `a57d1c8`) |

> Commits `3b270b3` y `14d4f36` fueron hechos directamente por el usuario desde la Raspberry Pi (archivó task-304 + .gitignore tweak).

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
| `multi-site-hash` | 3 | Detección multi-site híbrida + persistencia atómica. **Política notificación**: solo en cambios (default) o always-notify con `SCRAPER_DEBUG=1`. |
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
6. **Apliqué 4 commits de cleanup/ajuste** post-Fase 3 por feedback directo del usuario:
   - Mover `sites.json` de `.opencode/config/` a raíz + eliminar `.github/workflows/monitor.yml` (`3040920`).
   - Cambiar el timestamp del mensaje Telegram de UTC a hora local Madrid (Europe/Madrid, DST-aware) (`03bd2bb`).
   - Refrescar `SESSION_CONTEXT.md` con el cierre completo de Fase 3 (`b82435b`).
   - **Revertir** la política always-notify tras reconsideración del usuario: ahora solo notifica en cambios por defecto, con switch `SCRAPER_DEBUG=1` para volver al always-notify (`a58d012`).

### Commits realizados (11 — incluye los 2 commits del usuario desde la Pi)

```
a57d1c8 fix(deploy): install.sh auto-detects node path and accepts custom install dir   ← leader
14d4f36 gitignore                                                                       ← usuario desde Pi
3b270b3 Save session                                                                    ← usuario desde Pi (archivó task-304)
a58d012 feat(notify): revert always-notify by default, add SCRAPER_DEBUG switch          ← leader
b82435b docs(session): refresh SESSION_CONTEXT with full Fase 3 close + cleanup history  ← leader
03bd2bb fix(notify): use Madrid local time in Telegram message timestamp                ← leader
3040920 chore(repo): move sites.json to root + drop GitHub Actions workflow             ← leader
ab56ed7 docs: register Fase 3 close + multi-site + systemd + 4 ADRs                     ← leader
789ee73 feat(raspberry): systemd timer + service + install script + rotated logging      ← leader (task-303)
223d4cb feat(monitor): real Telegram notification with always-notify + Markdown         ← leader (task-302)
59f4c0b feat(monitor): multi-site fingerprint detection (HEAD-first + SHA-256 fallback) ← leader (task-301)
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
- **Always-notify (D3/D7/D8)**: activado al cierre de Fase 3. El usuario reconsideró al usarlo mentalmente (288 msgs/día = demasiado ruido) → revertido en D18. La funcionalidad se conserva como opt-in vía `SCRAPER_DEBUG=1`.

### Desviaciones de los specs durante la sesión (todas justificadas)

1. **task-302 — `await` añadido a `sendTelegramSummary` en `main()`**: el spec tenía un typo; sin `await`, las rejections de Telegram no se propagaban al `.catch()` de `main()` (unhandled promise rejection). Reviewer confirmó que era un fix necesario, no scope creep.
2. **task-303 — `chmod +x` aplicado al index de git para `.sh`**: los archivos tenían modo 755 en filesystem pero Git index los registró como 644. Leader ejecutó `git update-index --chmod=+x` antes del commit.
3. **task-304 — BOM UTF-8 eliminado de `feature_list.json`**: el BOM hacía fallar `JSON.parse(...)`. Fix legítimo, no scope creep.
4. **task-304 — `task-301/302/303` archivados aparecen como `new file` (no `rename`)**: los specs estaban untracked antes de la task, así que `git mv` requirió `git add` previo. La historia del filesystem es correcta, solo cambia la etiqueta del diff.
5. **task-304 — `SESSION_CONTEXT.md` staged con `git add -f`**: estaba en `.gitignore` por convención de Fase 0 ("no se commitea"). El spec de task-304 revirtió esa regla para commitear el contexto actualizado.
6. **task-304 leader fix — 4 secciones de `README.md` actualizadas directamente por el leader**: el spec no las incluía pero quedaban en estado Fase 1/2 (intro, Project Structure, Architecture table, Tech Stack). El leader las arregló antes de commitear para evitar abrir una task-305.
7. **deploy fix (post-Fase 3) — `install.sh` reescrito para auto-detectar `node`**: el usuario detectó `Unable to locate executable '/usr/bin/node'` en su primer arranque real. El `scraper.service` commiteado tenía `/usr/bin/node` hardcodeado y `install.sh` asumía `/opt/...`. Leader reescribió `install.sh` con `command -v node` + arg de ruta destino + generación dinámica del service.

### Limitaciones conocidas del código actual

- **Detección HEAD-first activa en ambas URLs reales** (`comunidad.madrid` y `sede.comunidad.madrid`): ambas responden con `Last-Modified`. El fallback SHA-256 está implementado pero no se ha ejercitado en producción todavía.
- **Logs ERROR pueden perderse en crash paths**: `logToFile` es fire-and-forget; la línea `[ERROR ...]` puede no llegar a `logs/scraper.log` si el proceso termina antes de que `appendFile` complete. El stderr sí queda capturado por `journal` vía `StandardError=journal`, así que el error no se pierde del todo.
- **`state/.initialized` se marca ANTES del envío Telegram**: si Telegram falla en el primer poll, en el siguiente poll el flag ya está puesto y no se re-enviará "🟢 Monitor arrancado". Comportamiento del spec, no bug.
- **`systemd-analyze verify` no validado en dev** (Windows + WSL stub): la validación del syntax INI de los units queda para el primer deploy real en la Pi.
- **BOM en HANDOFF-FASE-3.md**: presente al cierre (cosmético, no rompe nada).
- **Primer deploy en Pi falló (2026-07-22)**: systemd no encontró `node` en `/usr/bin/node`. Solucionado por `a57d1c8` (auto-detect en `install.sh`). El usuario debe re-ejecutar `install.sh` con el path correcto (`sudo ./scripts/raspberry/install.sh "$HOME/bots/.../ScraperOposicion"`).
- **Segundo intento de install falló (2026-07-22, post-commit `a57d1c8`)**: el usuario tiene node v24.18.0 vía nvm (ruta en su home, no en sudo PATH). `command -v node` bajo sudo falla porque el `secure_path` de `/etc/sudoers` no incluye `/home/user/.nvm/versions/node/v24.18.0/bin`. Solucionado por la nueva `detect_node_bin()` que prueba como `SUDO_USER` con login shell (`sudo -u $SUDO_USER -H bash -lc 'command -v node'`). El usuario debe re-ejecutar `install.sh` (mismo path que antes).

---

## Próximos pasos al reabrir la sesión

### Inmediatos (orden recomendado)

1. **Recuperar el deploy en Pi** (el fix `a57d1c8` ya está pushed):
   ```bash
   cd ~/bots/oposiciones/ScraperOposicion   # o donde lo clonaras
   git pull
   sudo ./scripts/raspberry/install.sh "$HOME/bots/oposiciones/ScraperOposicion"
   systemctl cat scraper.service | grep -E "ExecStart|WorkingDirectory"
   journalctl -u scraper.service -f
   ```
   Si `systemctl cat` muestra paths incorrectos, el `install.sh` no detectó bien; ejecuta `which node` y reporta.
2. **Validación 24h** (primer `next_actions` en `feature_list.json`): comprobar que no hay falsos positivos y que `Restart=on-failure` funciona ante errores transitorios.
3. **Validación con credenciales reales**: el developer no tenía `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` en su entorno dev, así que el envío real solo se probará cuando el bot corra en la Pi con `/etc/scraper-oposicion/telegram.env` configurado.
4. **Merge `local` → `main`** (opcional, decisión del usuario): el spec del HANDOFF §9.8 lo deja al usuario tras validación en Pi.

### Opcionales (limpieza)

5. **Limpiar BOM de HANDOFF-FASE-3.md**: cosmético.
6. **Forzar `systemd-analyze verify`** en Pi para validar syntax INI de los units.
7. **Revisar si `git mv` el archivo `task-304` archivado es visible en el repo**: el usuario lo hizo con `3b270b3 Save session`. Confirmar que el archivo está bien.

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
   - Verificar `git log --oneline -10` para confirmar el último commit (`a57d1c8`).
   - Verificar `git status` para confirmar working tree limpio.
   - Preguntar al usuario: "¿Funcionó el deploy en Pi tras el re-run de install.sh? ¿Algún issue nuevo?"
3. **No re-preguntar decisiones D1–D18** ya validadas — están documentadas arriba.

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
| `SCRAPER_DEBUG=1` (env var) | Switch opcional. Activado: notifica en cada poll (always-notify). Desactivado (default): solo notifica cuando hay cambios. Configurable en `/etc/scraper-oposicion/telegram.env` (línea comentada en `telegram.env.example`) o como `Environment=` en `scraper.service`. |
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
- **Push al cerrar:** hecho. `origin/local` está 9 commits ahead del HEAD inicial de la sesión.
- **Convención archivado tasks**: tras cierre de fase, los specs se renombran a `.archived.md` para preservar histórico sin contaminar el directorio activo. El usuario archivó `task-304` él mismo desde la Pi (`3b270b3`).
- **Política actual de notificación**: producción silenciosa (solo en cambios). Para activar always-notify (heartbeat cada 5 min): `SCRAPER_DEBUG=1` en `telegram.env` o `Environment=SCRAPER_DEBUG=1` en `scraper.service`. La Pi arranca en modo producción por defecto.
- **Flujo deploy actual**: el usuario clonó en `~/bots/oposiciones/ScraperOposicion` (no `/opt`). El fix `a57d1c8` permite ambas rutas via `install.sh [INSTALL_DIR]`. El deploy correcto en Pi requiere re-ejecutar `install.sh` con el path real del usuario.
- **`.gitignore` cubre** `scripts/raspberry/telegram.env` por seguridad (decidido por el usuario en `14d4f36`), aunque el env real vive en `/etc/scraper-oposicion/`.