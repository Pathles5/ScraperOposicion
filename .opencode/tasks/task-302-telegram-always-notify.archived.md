# Task 302: Notificación Telegram real — always-notify + formato Markdown con N sitios

**Fase:** 3
**Agente asignado:** developer
**Estado:** Pendiente de implementación (depende de task-301 APROBADO)
**HANDOFF:** `.opencode/tasks/HANDOFF-FASE-3.md`
**Task anterior:** task-301
**Task siguiente (bloqueante):** task-303

## Objetivo

Reemplazar el `sendTelegramSummary(summary)` stub de task-301 por una **implementación real** que envíe 1 único mensaje Markdown a Telegram por cada ejecución del monitor, con el estado de los N sitios configurados. El mensaje se envía **siempre** (D3 + D7), haya cambios o no. La primera ejecución tras un arranque en frío envía un mensaje especial "🟢 Monitor arrancado" (D15).

## Contexto

- task-301 ya implementó `detectFingerprint`, `loadStoredFingerprint`, `saveStoredFingerprint` y deja `summary` con la forma:
  ```js
  {
    siteId: string,
    name: string,
    url: string,
    changed: boolean,
    detectionMethod: "last-modified" | "etag" | "sha256",
    fingerprintPreview: string,
    previousPreview: string | null,
  }
  ```
- `notifyChange` de Fase 2 **ya no existe** (task-301 lo eliminó). La nueva función se llama `sendTelegramSummary`.
- Variables de entorno: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` (mismas que Fase 2).
- Bot del usuario: `@OposicionCamBot`.

## Decisiones aplicables

- **D3, D7, D8**: siempre notificar, 1 mensaje Markdown con ambas webs.
- **D15**: primera ejecución → mensaje "🟢 Monitor arrancado" sin marcar como cambio.

## Archivos a modificar

| Path | Acción |
|---|---|
| `monitor.js` | **Modificar**: reemplazar el stub `sendTelegramSummary` por la implementación real + lógica de primera ejecución |

NO se crean ficheros nuevos en esta task. NO se modifican dependencias.

## 1) Detección de "primera ejecución" (D15)

Antes de procesar los sitios, comprobar si existe `state/.initialized`.

```js
const INIT_FLAG = `${STATE_DIR}/.initialized`;

async function isFirstRun() {
  try {
    await readFile(INIT_FLAG, "utf8");
    return false;
  } catch (err) {
    if (err.code === "ENOENT") return true;
    throw err;
  }
}

async function markInitialized() {
  await writeFile(INIT_FLAG, new Date().toISOString(), "utf8");
}
```

Integración en `main()`:

```js
const firstRun = await isFirstRun();
// ... existing per-site loop ...
if (firstRun) {
  await markInitialized();
}
sendTelegramSummary(summary, { firstRun });
```

`sendTelegramSummary` recibe `firstRun` para elegir el formato (ver §3).

## 2) Implementación de `sendTelegramSummary(summary, { firstRun })`

```js
/**
 * Envía un mensaje Markdown a Telegram con el estado de los N sitios.
 * Se invoca SIEMPRE (D3 + D7), haya cambios o no.
 * Si firstRun=true, el mensaje incluye cabecera "🟢 Monitor arrancado".
 *
 * @param {Array<object>} summary  Uno por sitio (ver forma en task-301).
 * @param {{firstRun: boolean}} opts
 * @returns {Promise<void>}
 * @throws si faltan env vars o si Telegram API devuelve error.
 */
async function sendTelegramSummary(summary, { firstRun }) {
  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;

  if (!botToken || !chatId) {
    throw new Error(
      "Faltan variables de entorno para Telegram. " +
        "Configura TELEGRAM_BOT_TOKEN y TELEGRAM_CHAT_ID en el entorno " +
        "de la Raspberry (systemd EnvironmentFile=) o en .env local."
    );
  }

  const now = new Date().toISOString().replace("T", " ").slice(0, 16) + " UTC";

  const lines = [];
  lines.push(firstRun ? "🟢 *Monitor arrancado*" : "🛰 *Monitor oposiciones CM*");
  lines.push(`_${now}_`);
  lines.push("");

  for (const item of summary) {
    const status = item.changed ? "🔔 *CAMBIO DETECTADO*" : "✓ sin cambios";
    lines.push(`• *${item.name}*`);
    lines.push(`  ${status}`);
    lines.push(`  método: \`${item.detectionMethod}\``);
    lines.push(`  fingerprint: \`${item.fingerprintPreview}\``);
    if (item.changed && item.previousPreview) {
      lines.push(`  anterior:    \`${item.previousPreview}\``);
    }
    lines.push(`  url: ${item.url}`);
    lines.push("");
  }

  if (firstRun) {
    lines.push("Próximo check en 5 min. A partir de ahora recibirás un mensaje por poll (288/día).");
  } else {
    const cambios = summary.filter((s) => s.changed).length;
    if (cambios > 0) {
      lines.push(`⚠️ ${cambios} de ${summary.length} sitios cambiaron.`);
    }
    lines.push("Próximo check en 5 min.");
  }

  const message = lines.join("\n");

  const apiUrl = `https://api.telegram.org/bot${botToken}/sendMessage`;
  const response = await axios.post(
    apiUrl,
    {
      chat_id: chatId,
      text: message,
      parse_mode: "Markdown",
      disable_web_page_preview: true,
    },
    {
      timeout: GET_TIMEOUT_MS,
      validateStatus: (status) => status >= 200 && status < 300,
    }
  );

  if (!response.data || response.data.ok !== true) {
    throw new Error(`Telegram API devolvió error: ${JSON.stringify(response.data)}`);
  }
}
```

### Notas de diseño

- `parse_mode: "Markdown"` — el carácter `_` se usa para cursiva. Si un nombre de sitio contiene `_`, Telegram puede interpretarlo mal. Aceptamos ese riesgo (los nombres de los 2 sitios actuales no contienen `_`).
- `disable_web_page_preview: true` — para no spamear con previews de las URLs.
- Si Telegram trunca el mensaje (>4096 chars), partimos en chunks. **NO** necesario para N=2 sitios típicos. Si en el futuro N>20, considerar chunking.
- Si el usuario quiere un `inline_keyboard` con botones ("Ver web", "Marcar como revisado"), queda fuera de alcance (Fase 4+).

## 3) Importes a actualizar en `monitor.js`

```js
import { readFile, writeFile, rename, unlink } from "node:fs/promises";
```

(Ya están del task-301; asegurarse de que `readFile` y `writeFile` siguen importados para `isFirstRun`/`markInitialized`.)

## Restricciones

- ❌ NO añadir librerías nuevas. Usar `axios` (ya en package.json).
- ❌ NO cambiar el formato del `summary` (es la salida de task-301; task-302 solo lo consume).
- ❌ NO enviar mensajes duplicados. Una llamada por `main()`. No usar setInterval aquí (eso va en task-303 con systemd).
- ❌ NO incluir lógica de reintentos. Si Telegram falla, throw y dejar que el `main().catch(...)` exit(1) — systemd se encargará del siguiente intento.
- ❌ NO commit. Espera al reviewer.
- ❌ NO modificar `sites.json`, `.gitignore`, `state/.gitkeep`, `state.txt` (ya están como en task-301).
- ❌ NO crear systemd units (task-303).
- ✅ Mantener la firma `sendTelegramSummary(summary, { firstRun })` exactamente como se especifica.
- ✅ Conservar el throw claro si faltan env vars (incluyendo el texto orientativo).
- ✅ Conservar `console.log` de progreso en stdout (compatible con `journalctl`).

## Validación local (obligatoria)

### 3.1 Lint + sintaxis

```bash
cd C:\Users\pathl\Workspace\ScraperOposicion
pnpm lint
node --check monitor.js
```

Ambos exit 0.

### 3.2 Simulación sin Telegram (entrega a stdout)

Si no tienes las env vars, este test verifica que el código intenta enviar y falla con el mensaje claro:

```bash
node monitor.js
```

Salida esperada (con env vars ausentes):

```
[monitor] Sitios configurados: 2
[monitor] Procesando: cm-educacion (...)
[monitor] Procesando: cm-sede-oposiciones-2026 (...)
[monitor] ERROR: Faltan variables de entorno para Telegram. Configura TELEGRAM_BOT_TOKEN y TELEGRAM_CHAT_ID en el entorno de la Raspberry (systemd EnvironmentFile=) o en .env local.
```

Exit code 1.

### 3.3 Simulación con Telegram (entrega real, solo si el developer tiene las credenciales)

Si el developer tiene `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID` locales, puede ejecutar:

```bash
TELEGRAM_BOT_TOKEN=<tu_token> TELEGRAM_CHAT_ID=<tu_chat_id> node monitor.js
```

Validar:
- Primera ejecución (con `state/.initialized` ausente) → mensaje "🟢 Monitor arrancado" llega al chat.
- Segunda ejecución (con `state/.initialized` presente) → mensaje "🛰 Monitor oposiciones CM" llega.
- Ambos con los 2 sitios listados.

### 3.4 Verificación del flag

Después de una ejecución:

```bash
ls -la state/
```

Debe existir `state/.initialized` con una fecha ISO 8601.

## Entregable del developer

Reporta:

1. Output literal de `pnpm lint`.
2. Output literal de `node --check monitor.js`.
3. Output literal de `node monitor.js` (sin env vars) — debe mostrar el error claro de env vars.
4. Si tienes credenciales: output literal con env vars, y captura del mensaje recibido en Telegram (pegar el texto literal).
5. Contenido literal de `state/.initialized` (la fecha ISO).
6. `git diff monitor.js` (literal, solo la parte de `sendTelegramSummary` + helpers de firstRun).
7. `git status`.

NO HAGAS COMMIT. Espera al reviewer.