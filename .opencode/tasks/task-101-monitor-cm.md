# Task 101: Monitor CM Educación — implementación completa

**Fase:** 1
**Agente asignado:** developer
**Estado:** Pendiente de implementación

## Objetivo

Implementar un bot en Node.js que monitorice la página de oposiciones de la Comunidad de Madrid y detecte cambios en la fecha de "Última actualización". Persistir el estado en `state.txt` versionado en el repo. Configurar GitHub Actions para ejecutarlo cada 30 minutos y commitear/pushear `state.txt` cuando cambie.

## Contexto

- URL objetivo: `https://www.comunidad.madrid/educacion/procesos-selectivos-oposiciones-maestros`
- Fecha inicial del estado: `16 julio 2026`
- Referencia: `.opencode/tasks/HANDOFF-FASE-1.md`
- Stack confirmado: Node 20, ESM (`"type": "module"`), axios, cheerio, pnpm
- Notificación en esta fase: **STUB** (no implementar Discord aún). Solo dejar la función `notifyChange` con un `console.log` y un TODO claro.
- Decisión del usuario: regex **estricta** + `exit(1)` si no matchea.

## Archivos a crear

### 1. `package.json` (raíz)

```json
{
  "name": "scraper-oposicion",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "description": "Monitor de oposiciones de la Comunidad de Madrid",
  "engines": {
    "node": ">=20"
  },
  "scripts": {
    "start": "node monitor.js",
    "lint": "eslint ."
  },
  "dependencies": {
    "axios": "^1.7.7",
    "cheerio": "^1.0.0"
  },
  "devDependencies": {
    "eslint": "^9.12.0"
  },
  "license": "ISC"
}
```

### 2. `eslint.config.js` (raíz)

ESLint plano (flat config), sin Prettier. Reglas mínimas razonables para ESM + Node 20.

```js
import js from "@eslint/js";

export default [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: "module",
      globals: {
        process: "readonly",
        console: "readonly",
        URL: "readonly",
      },
    },
    rules: {
      "no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
      "no-console": "off",
    },
  },
  {
    files: ["**/*.js"],
    ignores: ["node_modules/", "coverage/", "dist/"],
  },
];
```

> Nota: `@eslint/js` debe estar disponible. Si genera error de import, añadir `"@eslint/js": "^9.12.0"` a `devDependencies` del `package.json`.

### 3. `monitor.js` (raíz)

Tres secciones claramente diferenciadas con comentarios de cabecera. ESM, named imports, sin clases.

```js
/**
 * Monitor de oposiciones — Comunidad de Madrid
 * Detecta cambios en la fecha de "Última actualización" de la página
 * de procesos selectivos de oposiciones a maestros.
 */

import { readFile, writeFile } from "node:fs/promises";
import axios from "axios";
import * as cheerio from "cheerio";

const TARGET_URL =
  "https://www.comunidad.madrid/educacion/procesos-selectivos-oposiciones-maestros";
const STATE_FILE = "state.txt";
const HTTP_TIMEOUT_MS = 30_000;
const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

// Regex ESTRICTA (decisión del usuario). Si no matchea → exit(1).
const UPDATE_REGEX = /Última actualización: ([^\n<]+)/;


// ============================================================
// PARTE 1: SCRAPING
// ============================================================

/**
 * Descarga el HTML de la URL objetivo con un User-Agent realista.
 * @param {string} url
 * @returns {Promise<string>} HTML completo
 * @throws {Error} si la petición falla o el status no es 200
 */
async function fetchPage(url) {
  const response = await axios.get(url, {
    headers: { "User-Agent": USER_AGENT },
    timeout: HTTP_TIMEOUT_MS,
    responseType: "text",
    validateStatus: (status) => status >= 200 && status < 300,
  });
  return response.data;
}


// ============================================================
// PARTE 2: LÓGICA DE BÚSQUEDA DE ACTUALIZACIÓN
// ============================================================

/**
 * Extrae la fecha de "Última actualización" del HTML.
 * @param {string} html
 * @returns {string} fecha exacta (texto) encontrada en la web
 * @throws {Error} si la regex no encuentra el fragmento esperado
 */
function extractUpdateDate(html) {
  const $ = cheerio.load(html);
  const text = $("body").text();
  const match = text.match(UPDATE_REGEX);

  if (!match || !match[1]) {
    throw new Error(
      "No se encontró el fragmento 'Última actualización: ...' en la página. " +
        "Revisa si la web cambió de estructura."
    );
  }
  return match[1].trim();
}


// ============================================================
// PARTE 3: NOTIFICACIÓN (STUB — fase futura)
// ============================================================

/**
 * Stub de notificación. En esta fase NO se envía nada.
 * Cuando se implemente (Fase 2), reemplazar el cuerpo por la llamada
 * al proveedor elegido (Discord, Telegram, ntfy.sh, Slack, etc.).
 *
 * @param {string} newDate  Fecha nueva detectada
 * @param {string} url      URL monitorizada
 * @returns {Promise<void>}
 */
async function notifyChange(newDate, url) {
  // TODO (Fase 2): implementar notificación real.
  // Opciones pendientes de elegir: Discord, Telegram, ntfy.sh, Slack, GitHub Issues.
  // Estructura prevista: POST a un webhook con payload { date, url }.
  console.log(`[STUB notifyChange] Detectado cambio de fecha.`);
  console.log(`  Nueva fecha: ${newDate}`);
  console.log(`  URL:         ${url}`);
}


// ============================================================
// ORQUESTACIÓN
// ============================================================

async function readState() {
  const content = await readFile(STATE_FILE, "utf8");
  const trimmed = content.trim();
  if (!trimmed) {
    throw new Error(`El archivo ${STATE_FILE} está vacío.`);
  }
  return trimmed;
}

async function writeState(value) {
  await writeFile(STATE_FILE, value, "utf8");
}

async function main() {
  console.log(`[monitor] Iniciando check de ${TARGET_URL}`);

  const previousDate = await readState();
  console.log(`[monitor] Fecha anterior (state.txt): ${previousDate}`);

  const html = await fetchPage(TARGET_URL);
  const currentDate = extractUpdateDate(html);
  console.log(`[monitor] Fecha actual (web):           ${currentDate}`);

  if (currentDate === previousDate) {
    console.log("[monitor] Sin cambios. Todo sigue igual.");
    return;
  }

  console.log(`[monitor] ¡Cambio detectado!`);
  await notifyChange(currentDate, TARGET_URL);
  await writeState(currentDate);
  console.log(`[monitor] state.txt actualizado a: ${currentDate}`);
}

main().catch((err) => {
  console.error(`[monitor] ERROR: ${err.message}`);
  process.exit(1);
});
```

### 4. `state.txt` (raíz)

Contenido exacto (un solo línea, sin newline final extra):

```
16 julio 2026
```

> Crear el archivo con exactamente ese contenido. NO añadir saltos de línea extra.

### 5. `.github/workflows/monitor.yml`

```yaml
name: Monitor CM Educacion

on:
  schedule:
    # Cada 30 minutos
    - cron: "*/30 * * * *"
  # Lanzamiento manual desde la pestaña Actions
  workflow_dispatch:

permissions:
  contents: write

concurrency:
  group: monitor-cm
  cancel-in-progress: false

jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup pnpm
        uses: pnpm/action-setup@v4
        with:
          version: 9

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          cache: pnpm

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Run monitor
        env:
          # Reservado para Fase 2 (cuando se implemente notifyChange).
          # Si el secret no existe en el repo, GH Actions falla la ejecución.
          # Por ahora NO lo referenciamos aquí — solo dejamos el comentario.
          DISCORD_WEBHOOK: ${{ secrets.DISCORD_WEBHOOK }}
        run: node monitor.js

      - name: Commit state.txt if changed
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add state.txt
          if git diff --cached --quiet; then
            echo "Sin cambios en state.txt, nada que commitear."
          else
            git commit -m "chore(state): update last update date"
            git push
          fi
```

> **Nota sobre DISCORD_WEBHOOK**: el usuario eligió NO implementar notificación todavía. El secret queda preparado para Fase 2, pero `monitor.js` aún no lo lee. La línea `env: DISCORD_WEBHOOK:` se puede dejar comentada o eliminar de momento. **Recomendación**: déjala comentada con un comentario `# Pendiente Fase 2` para no romper la ejecución si el secret no está definido en GitHub.

## Verificación (quality gate del reviewer)

Después de implementar, **antes de avisar al reviewer**, el developer debe ejecutar localmente:

```bash
pnpm install
pnpm lint
```

`pnpm lint` debe pasar sin errores. Si falla, ajustar la config de ESLint hasta que pase (recordar: ESLint plano, sin Prettier).

## Restricciones explícitas

- ❌ NO hacer commit. Eso es responsabilidad del leader.
- ❌ NO modificar `AGENTS.md`, `docs/architecture.md`, `docs/conventions.md`, `docs/decisions.md` (documentación canónica del bootstrap). Solo se modifican al cierre de fase por el leader.
- ❌ NO implementar la notificación real (queda como stub).
- ❌ NO añadir tests (ADR-002).
- ❌ NO crear carpeta `src/` ni estructura hexagonal (decisión del usuario).
- ❌ NO usar clases custom de error (decisión del usuario). Solo `throw new Error(...)`.
- ❌ NO usar `export default`. Solo named exports.
- ✅ Imports con extensión `.js` (ESM).
- ✅ `kebab-case` para archivos, `camelCase` para funciones.

## Entregable del developer

Cuando termines, reporta al leader:
1. Lista de archivos creados/modificados.
2. Output literal de `pnpm lint` (debe pasar sin errores).
3. Cualquier desviación del spec (con justificación).
