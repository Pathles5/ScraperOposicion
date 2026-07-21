# Task 301: Refactor monitor.js — multi-site + detección híbrida HEAD-first / hash-fallback

**Fase:** 3
**Agente asignado:** developer
**Estado:** Pendiente de implementación
**HANDOFF:** `.opencode/tasks/HANDOFF-FASE-3.md`
**Task siguiente (bloqueante):** task-302

## Objetivo

Sustituir el scraper monolítico de Fase 1/2 (`monitor.js` con regex sobre 1 URL) por una versión **multi-site** con detección **híbrida automática**: HEAD-first (usa `Last-Modified` o `ETag` cuando están presentes) con fallback a **SHA-256 sobre HTML normalizado**. Persistencia por sitio en `state/<siteId>.fingerprint`. Lista declarativa de sitios en `.opencode/config/sites.json`. **Notification stub** (console.log) — la implementación real de Telegram va en task-302.

## Contexto

- **Fase 1**: `monitor.js` con regex agnóstica sobre `comunidad.madrid/educacion/...`. Estado en `state.txt` versionado.
- **Fase 2**: añade notificación Telegram (`notifyChange`).
- **Fase 3 (esta task)**: rehacer la detección. La regex se elimina. Se añade el patrón híbrido.
- **Decisiones aplicables**: D1–D6, D9, D10', D13, D14, D16 (ver HANDOFF §2).
- **State**: `state.txt` se elimina. Se crea `state/` con `.gitkeep` y un `<siteId>.fingerprint` por sitio.
- **Sites config**: `.opencode/config/sites.json` con 2 sitios.
- **No notification real aquí**: el bloque de envío a Telegram queda como `console.log` con un TODO claro hacia task-302.

## Archivos a crear / modificar / eliminar

| Path | Acción |
|---|---|
| `monitor.js` | **Refactor mayor** (mantener entrypoint `main`) |
| `state.txt` | **Eliminar** |
| `state/.gitkeep` | **Crear** (fichero vacío) |
| `.opencode/config/sites.json` | **Crear** |
| `.gitignore` | **Modificar** |

## 1) `.opencode/config/sites.json` (crear)

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

## 2) `state/.gitkeep` (crear)

Fichero vacío (0 bytes). Solo para que git preserve el directorio.

## 3) `.gitignore` (modificar)

Añadir (si no existen) las siguientes entradas, manteniendo el resto del fichero intacto:

```
# Estado runtime del monitor (Fase 3)
state/*.fingerprint
state/*.fingerprint.tmp
state/.initialized
logs/*.log
```

> `state/.gitkeep` debe **NO** estar ignorado (quiere commitearse).

## 4) `state.txt` (eliminar)

```bash
git rm state.txt
```

## 5) `monitor.js` (refactor mayor)

Mantener ESM, axios, cheerio. Añadir `node:crypto` (SHA-256) y `node:fs/promises`. Imports explícitos con `.js`.

### Estructura propuesta

```js
/**
 * Monitor de oposiciones — multi-site
 * Detecta cambios en N páginas web mediante:
 *   1) HEAD-first: usa Last-Modified o ETag si el servidor lo envía.
 *   2) Fallback: SHA-256 sobre HTML normalizado.
 * Persistencia por sitio en state/<siteId>.fingerprint.
 */

import { readFile, writeFile, rename, unlink } from "node:fs/promises";
import { createHash } from "node:crypto";
import axios from "axios";
import * as cheerio from "cheerio";

const SITES_FILE = ".opencode/config/sites.json";
const STATE_DIR = "state";
const HEAD_TIMEOUT_MS = 10_000;
const GET_TIMEOUT_MS = 30_000;
const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";


// ============================================================
// PARTE 1: CONFIGURACIÓN DE SITIOS
// ============================================================

/**
 * Carga y valida la lista de sitios desde sites.json.
 * @returns {Promise<Array<{id: string, name: string, url: string}>>}
 * @throws si el fichero no existe, no es JSON válido, o falta id/name/url.
 */
async function loadSites() { /* ... */ }


// ============================================================
// PARTE 2: SCRAPING
// ============================================================

/**
 * HEAD request para inspeccionar Last-Modified y ETag sin descargar el body.
 * @param {string} url
 * @returns {Promise<{lastModified: string|null, etag: string|null}>}
 */
async function fetchHead(url) { /* ... */ }

/**
 * GET request del HTML completo.
 * @param {string} url
 * @returns {Promise<string>}
 */
async function fetchPage(url) { /* ... */ }


// ============================================================
// PARTE 3: DETECCIÓN DE FINGERPRINT (híbrido HEAD-first + hash-fallback)
// ============================================================

/**
 * Normaliza el HTML y calcula su SHA-256.
 * - Quita <script>, <style>, comentarios HTML.
 * - Extrae solo el texto visible.
 * - Colapsa whitespace y trim.
 * @param {string} html
 * @returns {string} hex SHA-256 (64 chars)
 */
function normalizeAndHash(html) { /* ... */ }

/**
 * Detecta el fingerprint de un sitio.
 * Estrategia:
 *   1) HEAD → si lastModified presente, devuelve { tipo: "last-modified", valor }.
 *   2) Si no, si etag presente, devuelve { tipo: "etag", valor }.
 *   3) Si no, GET → normalizeAndHash → { tipo: "sha256", valor }.
 * @param {{id: string, url: string}} site
 * @returns {Promise<{tipo: string, valor: string, detectionMethod: string}>}
 */
async function detectFingerprint(site) { /* ... */ }


// ============================================================
// PARTE 4: PERSISTENCIA ATÓMICA
// ============================================================

/**
 * Lee el fingerprint almacenado para un sitio.
 * Formato del fichero: "<tipo>\n<valor>\n".
 * @param {string} siteId
 * @returns {Promise<{tipo: string, valor: string}|null>}
 */
async function loadStoredFingerprint(siteId) { /* ... */ }

/**
 * Persiste el fingerprint de un sitio de forma atómica.
 * Escribe en <siteId>.fingerprint.tmp y luego rename → <siteId>.fingerprint.
 * @param {string} siteId
 * @param {{tipo: string, valor: string}} fingerprint
 */
async function saveStoredFingerprint(siteId, fingerprint) { /* ... */ }


// ============================================================
// PARTE 5: NOTIFICACIÓN (STUB — se implementa en task-302)
// ============================================================

/**
 * STUB temporal. En task-302 se reemplaza por envío real a Telegram.
 * @param {Array<object>} summary
 */
function sendTelegramSummary(summary) {
  console.log("[monitor] (STUB) Resumen que se enviará a Telegram:");
  for (const item of summary) {
    console.log("  -", JSON.stringify(item));
  }
}


// ============================================================
// ORQUESTACIÓN
// ============================================================

async function main() {
  const sites = await loadSites();
  console.log(`[monitor] Sitios configurados: ${sites.length}`);

  const summary = [];

  for (const site of sites) {
    console.log(`[monitor] Procesando: ${site.id} (${site.url})`);

    const currentFingerprint = await detectFingerprint(site);
    const previousFingerprint = await loadStoredFingerprint(site.id);

    const changed =
      previousFingerprint !== null &&
      (previousFingerprint.tipo !== currentFingerprint.tipo ||
        previousFingerprint.valor !== currentFingerprint.valor);

    await saveStoredFingerprint(site.id, currentFingerprint);

    summary.push({
      siteId: site.id,
      name: site.name,
      url: site.url,
      changed,
      detectionMethod: currentFingerprint.tipo,
      fingerprintPreview: currentFingerprint.valor.slice(0, 12) + "…",
      previousPreview: previousFingerprint
        ? previousFingerprint.valor.slice(0, 12) + "…"
        : null,
    });
  }

  sendTelegramSummary(summary);
}

main().catch((err) => {
  console.error(`[monitor] ERROR: ${err.message}`);
  process.exit(1);
});
```

### Funciones auxiliares internas (referencia, el developer las implementa)

- **`loadSites()`**:
  ```js
  const raw = await readFile(SITES_FILE, "utf8");
  const parsed = JSON.parse(raw);
  if (!Array.isArray(parsed.sites)) throw new Error("sites.json debe contener { sites: [...] }");
  for (const s of parsed.sites) {
    if (!s.id || !s.name || !s.url) throw new Error(`Sitio inválido: ${JSON.stringify(s)}`);
  }
  return parsed.sites;
  ```

- **`fetchHead(url)`**:
  ```js
  const response = await axios.head(url, {
    headers: { "User-Agent": USER_AGENT },
    timeout: HEAD_TIMEOUT_MS,
    validateStatus: () => true, // no tirar en 4xx/5xx; queremos leer headers si los hay
  });
  return {
    lastModified: response.headers["last-modified"] || null,
    etag: response.headers["etag"] || null,
  };
  ```

- **`normalizeAndHash(html)`**:
  ```js
  const $ = cheerio.load(html);
  $("script, style").remove();
  // Quitar comentarios HTML
  $("*").contents().filter((_, n) => n.type === "comment").remove();
  const text = $("body").text();
  const collapsed = text.replace(/\s+/g, " ").trim();
  return createHash("sha256").update(collapsed).digest("hex");
  ```

- **`saveStoredFingerprint(siteId, { tipo, valor })`**:
  ```js
  const finalPath = `${STATE_DIR}/${siteId}.fingerprint`;
  const tmpPath = `${finalPath}.tmp`;
  await writeFile(tmpPath, `${tipo}\n${valor}\n`, "utf8");
  await rename(tmpPath, finalPath);
  ```

- **`loadStoredFingerprint(siteId)`**:
  ```js
  try {
    const raw = await readFile(`${STATE_DIR}/${siteId}.fingerprint`, "utf8");
    const [tipo, valor] = raw.trim().split("\n");
    return { tipo, valor };
  } catch (err) {
    if (err.code === "ENOENT") return null;
    throw err;
  }
  ```

## Restricciones

- ❌ NO implementar la llamada real a Telegram (eso es task-302). Solo el `console.log` stub.
- ❌ NO crear ficheros systemd, scripts de instalación ni `install.sh` (task-303).
- ❌ NO modificar `.github/workflows/monitor.yml` (task-304).
- ❌ NO modificar `CHANGELOG.md`, `README.md`, `docs/*`, `feature_list.json` (task-304).
- ❌ NO añadir dependencias nuevas al `package.json`. SHA-256 con `node:crypto`, atomic write con `node:fs/promises`.
- ❌ NO hacer commit.
- ❌ NO dejar la regex de Fase 1 (`UPDATE_REGEX`) en el código. Eliminarla por completo.
- ❌ NO dejar `extractUpdateDate` ni `notifyChange` de Fase 2. Sustituidos por la nueva arquitectura.
- ✅ Mantener `main()` como entrypoint. La firma `import { readFile, ... } from "node:fs/promises"` puede reorganizarse pero no eliminar el patrón ESM.
- ✅ Mantener comentarios JSDoc en funciones exportadas/nuevas.

## Validación local (obligatoria)

Después de aplicar el cambio, ejecuta desde la raíz del proyecto:

```bash
cd C:\Users\pathl\Workspace\ScraperOposicion
pnpm lint
node --check monitor.js
```

Ambos deben pasar con exit 0.

**Pruebas funcionales** (el bot debe ejecutarse contra las URLs reales; la primera vez mostrará "previousPreview: null" para ambos sitios):

```bash
node monitor.js
```

Salida esperada (formato aproximado, las fechas/hora varían):
```
[monitor] Sitios configurados: 2
[monitor] Procesando: cm-educacion (https://...)
[monitor] Procesando: cm-sede-oposiciones-2026 (https://...)
[monitor] (STUB) Resumen que se enviará a Telegram:
  - {"siteId":"cm-educacion", ..., "changed":false, "detectionMethod":"sha256", "fingerprintPreview":"a1b2c3d4e5f6…", "previousPreview":null}
  - {"siteId":"cm-sede-oposiciones-2026", ..., "changed":false, ...}
```

Verifica que:
1. El fichero `state/cm-educacion.fingerprint` se ha creado y contiene `<tipo>\n<valor>\n`.
2. El fichero `state/cm-sede-oposiciones-2026.fingerprint` igual.
3. Una segunda ejecución muestra `changed:false` para ambos (fingerprint estable) y `previousPreview` con valor (ya hay estado previo).
4. `state.txt` ya no existe.

Para verificar que el fingerprint es estable entre runs, ejecuta el monitor dos veces seguidas y comprueba que `fingerprintPreview` no cambia.

## Entregable del developer

Reporta al líder (en texto):

1. Output literal de `pnpm lint`.
2. Output literal de `node --check monitor.js`.
3. Output literal de la primera ejecución de `node monitor.js`.
4. Output literal de la segunda ejecución (debe mostrar `changed:false` y `previousPreview` distinto de `null`).
5. Contenido de `state/cm-educacion.fingerprint` (literal, las 2 líneas).
6. Contenido de `state/cm-sede-oposiciones-2026.fingerprint` (literal).
7. `git diff --stat` y `git status` (literal).
8. `git diff .gitignore` (literal, solo esa parte).

NO HAGAS COMMIT. Espera al reviewer.