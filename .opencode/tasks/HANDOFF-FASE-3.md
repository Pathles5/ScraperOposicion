# HANDOFF — FASE 3: Scraper local en Raspberry Pi (multi-site + hash)

> **Estado final**: ✅ Completado el 2026-07-22. Ver CHANGELOG.md y feature_list.json para los entregables.

**Fecha:** 2026-07-22
**Estado:** ✅ **VALIDADO — Pendiente de OK final del usuario**
**Rama:** `local` (trackea `origin/local`)
**Último commit:** `759bd8f chore(agents): relax permissions for frictionless local workflow`

> Este HANDOFF consolida las decisiones D1–D5 originales más las D6–D9 validadas en la sesión del 2026-07-22. **NO se ha delegado todavía a developer. NO se han creado tasks.** El usuario debe dar **OK explícito** sobre el alcance y el breakdown de tasks aquí propuesto antes de fragmentar.

---

## 1. Contexto y motivación

Las Fases 1 y 2 dejaron el scraper funcionando en GitHub Actions (cron `*/30 * * * *`, regex de "Última actualización:"). El usuario quiere **migrar la ejecución a una Raspberry Pi local** y **redefinir la lógica de detección** para soportar más de una página con notificación siempre activa.

---

## 2. Decisiones validadas

### De sesiones anteriores (D1–D5)

- **D1**: El scraper se ejecuta en la **Raspberry Pi localmente**, no en GitHub Actions. GitHub Actions queda como legado desactivado.
- **D2**: Polling cada **5 minutos**.
- **D3**: Cada consulta **envía un mensaje a Telegram aunque NO haya cambios**.
- **D4**: Detección de cambios pasa de **regex** a **hash del HTML**.
- **D5**: Se monitorizan **DOS páginas web**. El mensaje resume ambas. Si cualquiera cambia, indica cuál.

### De esta sesión (D6–D9)

- **D6**: Segunda web = `https://sede.comunidad.madrid/oferta-empleo/oposiciones-maestros-2026` (sede CM, oferta de empleo).
- **D7**: Política de notificación = **cada poll emite 1 mensaje** (288/día). Literal de D3.
- **D8**: Formato del mensaje = **1 único mensaje Markdown con el estado de ambas webs**.
- **D9**: Persistencia del hash entre reinicios = **fichero en disco `state/<slug>.hash`**. Directorio `state/` se añade a `.gitignore` (con `.gitkeep` para preservar el directorio).

### Decisiones técnicas adicionales (validadas en esta sesión)

- **D10'** (validada 2026-07-22): **Detección híbrida automática HEAD-first con fallback a hash SHA-256 normalizado**.
  1. Para cada sitio, hacer petición **HEAD** y leer `Last-Modified` y `ETag`.
  2. Si `Last-Modified` está presente → guardar y comparar ese string.
  3. Else si `ETag` está presente → guardar y comparar.
  4. Else (ninguno presente) → **fallback**: GET + SHA-256 sobre HTML normalizado.

  Normalización del HTML (solo en la rama hash):
  - cheerio elimina `<script>`, `<style>`, comentarios HTML.
  - `$("body").text()` para quedarse solo con el texto visible.
  - Colapsar whitespace (múltiples espacios/tabs/newlines → 1 espacio) y trim.
  - SHA-256 hex (`node:crypto`).

  Estructura del fingerprint guardado:
  ```
  <tipo>\n<valor>\n
  ```
  Donde `tipo` ∈ `{"last-modified", "etag", "sha256"}`.

- **D11** (validada 2026-07-22): **Scheduling = systemd timer + service** (vs cron). Justificación:
  - `After=network-online.target` espera a la red antes del primer poll (cron no).
  - Logs centralizados en `journalctl`.
  - `Restart=on-failure` para resiliencia ante crashes transitorios.
  - Cuesta 2 ficheros extra (`scripts/raspberry/scraper.service` + `scraper.timer`) frente a 1 línea en crontab.

- **D12** (validada 2026-07-22): **Logging = journalctl + fichero rotado en `logs/scraper.log`**. Rotación simple por tamaño (1 MB → truncar a 500 KB). Sin librería externa (`fs.appendFile` + check de tamaño en cada write).

- **D13** (validada 2026-07-22): Renombrar estructura de estado:
  - **Eliminar** `state.txt` (raíz, versionado).
  - **Crear** `state/` con un fichero por sitio: `state/<siteId>.fingerprint`.
  - **Añadir** `state/*.fingerprint` y `logs/*.log` a `.gitignore` + `state/.gitkeep` para preservar el directorio.

- **D14** (validada 2026-07-22): Configuración declarativa de sitios en `.opencode/config/sites.json`. Estructura:

  ```json
  {
    "sites": [
      {
        "id": "cm-educacion",
        "name": "CM Educacion — Procesos selectivos maestros",
        "url": "https://www.comunidad.madrid/educacion/procesos-selectivos-oposiciones-maestros"
      },
      {
        "id": "cm-sede-oposiciones-2026",
        "name": "CM Sede — Oferta empleo oposiciones maestros 2026",
        "url": "https://sede.comunidad.madrid/oferta-empleo/oposiciones-maestros-2026"
      }
    ]
  }
  ```
  El fichero se commitea al repo (las URLs no son secretos). Añadir/quitar sitios no requiere tocar código.

- **D15** (validada 2026-07-22): Primera ejecución (no hay fingerprint previo) → no se notifica como "cambio". Se envía un mensaje "🟢 Monitor arrancado" la primera vez (marcado por flag `state/.initialized`).

- **D16** (validada 2026-07-22): Escritura atómica del fingerprint: `writeFile(state/<siteId>.fingerprint.tmp)` → `rename(tmp, final)` para evitar corrupciones si systemd mata el proceso a mitad.

---

## 3. ADRs a registrar al cierre de la fase

| ADR | Título | Sustituye |
|---|---|---|
| **ADR-003** | Paradigma local en Raspberry Pi vs GitHub Actions | workflow GH Actions queda legacy |
| **ADR-004** | Detección de cambios por hash vs regex | la regex agnóstica de Fase 1 |
| **ADR-005** | Scheduling con systemd timer vs cron | n/a (nuevo) |
| **ADR-006** | Persistencia de estado con ficheros vs SQLite | `state.txt` versionado |

Los ADRs se redactan en el commit de cierre de fase, con la plantilla de `docs/decisions.md`.

---

## 4. Alcance detallado

### 4.1 Archivos a crear / modificar / eliminar

| Path | Acción | Notas |
|---|---|---|
| `monitor.js` | **Refactor mayor** | Pasa de "1 web + regex" a "N webs + hash + always notify". Conserva entrypoint y exports (nombre `main`). |
| `state.txt` | **Eliminar** | Reemplazado por `state/<siteId>.fingerprint`. |
| `state/` | **Crear** | Contiene `<siteId>.fingerprint` por sitio + `.gitkeep`. |
| `state/.gitkeep` | **Crear** | Para que git no ignore el directorio. |
| `.gitignore` | **Modificar** | Añadir `state/*.fingerprint` + `logs/*.log` (mantener `.gitkeep`). |
| `.opencode/config/sites.json` | **Crear** | Lista declarativa de sitios (D14). Se commitea al repo. |
| `scripts/raspberry/scraper.service` | **Crear** | Unit de systemd. |
| `scripts/raspberry/scraper.timer` | **Crear** | Timer `OnUnitActiveSec=5min`. |
| `scripts/raspberry/install.sh` | **Crear** | Script que copia los units a `/etc/systemd/system/` y hace `systemctl daemon-reload + enable`. Idempotente. |
| `scripts/raspberry/README.md` | **Crear** | Instrucciones de despliegue. |
| `.github/workflows/monitor.yml` | **Modificar** | Comentar (no eliminar) el bloque `schedule:` para evitar duplicación. Añadir nota de "legacy". |
| `package.json` | **Modificar** | Añadir script `monitor` si hace falta. Sin nuevas deps (Node nativo cubre hash + fs). |
| `README.md` | **Modificar** | Sección "Running locally on Raspberry Pi". Actualizar la tabla de endpoints si cambia algo HTTP (no debería). |
| `docs/architecture.md` | **Modificar** | Diagrama actualizado: "N webs + hash + persistencia + always notify + systemd". |
| `docs/roadmap.md` | **Modificar** | Marcar Fase 3 "En curso" → al cerrar, "Completado". |
| `docs/decisions.md` | **Modificar** | Añadir ADR-003, 004, 005, 006. |
| `CHANGELOG.md` | **Modificar** | Entrada Fase 3 al cierre. |
| `feature_list.json` | **Modificar** | Añadir features `raspberry-local-scraper` y `multi-site-hash`. Marcar completadas al cierre. |
| `SESSION_CONTEXT.md` | **Modificar** | Actualizar estado. |
| `eslint.config.js` | **Verificar** | No debería cambiar. Confirmar en review. |

### 4.2 Estructura interna de `monitor.js` (post-refactor)

```
main():
  1. Cargar sites desde .opencode/config/sites.json
  2. Para cada site:
       a. fetchHead(url) → { lastModified, etag }
       b. Si (lastModified o etag) presente → currentFingerprint = { tipo, valor }
       c. Else → fetchPage(url) → html; normalizeAndHash(html) → currentFingerprint
       d. loadStoredFingerprint(siteId) → previousFingerprint
       e. changed = currentFingerprint !== previousFingerprint (false si previousFingerprint es null)
       f. saveStoredFingerprint(siteId, currentFingerprint)  // atómico (D16)
       g. Registrar { siteId, name, changed, currentFingerprint, previousFingerprint, url, detectionMethod }
  3. sendTelegramSummary(summary)  (siempre, D3 + D7 + D8) — task-302
  4. process.exit(0)
```

Funciones nuevas / modificadas:

- `loadSites()` — lee `sites.json`, valida estructura, throw claro si falla.
- `loadStoredFingerprint(siteId)` — lee `state/<siteId>.fingerprint`, parsea `<tipo>\n<valor>\n`. Devuelve `null` si no existe.
- `saveStoredFingerprint(siteId, fingerprint)` — escribe atómicamente: `writeFile(state/<id>.fingerprint.tmp)` → `rename(tmp, final)`.
- `fetchHead(url)` → `{ lastModified, etag }`. Timeout 10s.
- `fetchPage(url)` → HTML completo (mantener firma actual).
- `normalizeAndHash(html)` → `{ tipo: "sha256", valor }`. cheerio → texto → strip whitespace → SHA-256 hex.
- `detectFingerprint(site)` → orquesta la rama HEAD-first / hash-fallback.
- `sendTelegramSummary(summary)` — 1 mensaje Markdown listando N webs con ✓/🔔. **(Implementada en task-302.)**
- `notifyChange(newDate, url)` de Fase 2 → **se elimina o se deprecara**. La nueva función `sendTelegramSummary` reemplaza la responsabilidad.

### 4.3 Formato del mensaje (propuesta, ajustar en task-303)

```
🛰 Monitor oposiciones CM — 2026-07-22 14:35 UTC

• CM Educacion — Procesos selectivos maestros
  ✓ sin cambios (hash: a1b2c3d4…)

• CM Sede — Oferta empleo oposiciones maestros 2026
  🔔 CAMBIO DETECTADO
    hash anterior: 12345678…
    hash nuevo:     9abcdef0…
    url: https://sede.comunidad.madrid/...

Próximo check en 5 min.
```

---

## 5. Task breakdown (propuesto, consolidado a 4 tasks)

| ID | Título | Tipo | Bloqueante siguiente |
|---|---|---|---|
| **task-301** | Refactor `monitor.js` core: multi-site + detección híbrida HEAD-first/hash-fallback + sites.json + state/ + persistencia atómica + .gitignore. **Stub notification** (console.log). | Implementación core | task-302 |
| **task-302** | Notificación real: always-notify + formato Markdown con N sitios + mensaje "🟢 Monitor arrancado" la primera vez | Implementación | task-303 |
| **task-303** | Setup systemd: `scripts/raspberry/*.service` + `*.timer` + `install.sh` + `README.md` + logging a fichero rotado | Despliegue | task-304 |
| **task-304** | Cleanup + docs: desactivar cron GH Actions + actualizar README/CHANGELOG/roadmap/architecture/decisions/feature_list/SESSION_CONTEXT + ADRs 003-006 | Cierre de fase | (fin) |

**Total estimado**: 4 tasks. Se ejecutan en orden secuencial (cada uno construye sobre el anterior). El developer no trabaja en paralelo.

### Dependencias entre tasks

```
task-301 ──> task-302 ──> task-303 ──> task-304
```

---

## 6. Estimación

- **task-301**: 1 sesión de developer (refactor mayor + sites.json + state/ + persistencia atómica).
- **task-302**: ½ sesión (reemplaza el stub por llamada real a Telegram con formato nuevo).
- **task-303**: ½ sesión (ficheros systemd + install.sh + README de despliegue + rotación logs).
- **task-304**: ½ sesión (docs + desactivación GH Actions + 4 ADRs).

**Total**: ~2.5 sesiones de developer, ~3-4 reviews.

---

## 7. Riesgos identificados

| Riesgo | Mitigación |
|---|---|
| Raspberry se reinicia y pierde estado | `state/<siteId>.fingerprint` en disco + escritura atómica (D16). |
| HTML tiene timestamps/scripts dinámicos → falsos positivos | Normalización D10' (solo en rama hash). Revisable en task-301. |
| Telegram spam (288 msgs/día) | Aceptado por el usuario en P2 (literal D3). Si se arrepiente, se resuelve en una fase futura. |
| GitHub Actions sigue corriendo en paralelo | Comentar `schedule:` en task-304. |
| systemd unit falla por paths absolutos | `install.sh` usa `realpath` para resolver rutas. |
| Primera ejecución: no hay fingerprint previo → ¿notifica como "cambio"? | D15: notifica como "🟢 Monitor arrancado" sin marcar cambio. Flag en `state/.initialized`. |

---

## 8. Fuera de alcance (explícito)

- ❌ Tests automatizados (ADR-002 vigente).
- ❌ Eliminar `.github/workflows/monitor.yml` (se mantiene desactivado).
- ❌ Interfaz web / dashboard.
- ❌ Otros canales (Discord, ntfy.sh, email).
- ❌ Autenticación / multi-usuario.
- ❌ Refactor a arquitectura hexagonal.
- ❌ Histórico de cambios (SQLite con timestamps) — solo se guarda el último hash.

---

## 9. Plan de ejecución al aprobar

1. Leader crea `task-301` a `task-304` en `.opencode/tasks/` con el skeleton del proyecto.
2. Leader delega `task-301` al developer.
3. Reviewer valida → si APROBADO, continuar.
4. Repetir para tasks 302 → 303 → 304.
5. Leader hace commit de cierre de fase con conventional-commits (`feat(raspberry): ...`).
6. Leader actualiza `feature_list.json`, `CHANGELOG.md`, `README.md`, `docs/roadmap.md`.
7. Leader añade ADR-003, 004, 005, 006 en `docs/decisions.md` (en el mismo commit o en uno separado posterior).
8. Leader mergea `local` → `main` (al final, tras validación).

---

## 10. Estado de archivos al cierre de esta sesión de planning

- Rama activa: `local`.
- Working tree: limpio salvo `HANDOFF-FASE-3.md` (ahora **VALIDADO, pendiente de OK**).
- Este HANDOFF sigue sin commitear (se commitea en task-305 junto al cierre de fase, o antes si quieres trazabilidad del planning).