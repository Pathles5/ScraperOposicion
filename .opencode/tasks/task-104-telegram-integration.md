# Task 104: Integración real con Telegram Bot API (Fase 2)

**Fase:** 2 (Notificación)
**Agente asignado:** developer
**Estado:** Pendiente de implementación

## Contexto y decisiones del usuario

- **Bot creado**: username `OposicionCamBot`, nombre `Monitor Oposiciones`.
- **Secret de GitHub**: `TELEGRAM_BOT_TOKEN_HTTP` (el usuario lo nombró así, NO `TELEGRAM_BOT_TOKEN`).
- **Otro secret**: `TELEGRAM_CHAT_ID` (mismo nombre que la variable de entorno).
- **Ambos secrets están en un GitHub Environment llamado `main`** (no a nivel de repo). El workflow debe referenciar ese environment para acceder a ellos.
- **Decisión previa**: notificar vía Telegram Bot API, no Discord, no Slack, etc.

## Objetivo

Reemplazar el stub `notifyChange` por una llamada real a la API de Telegram que envía un mensaje Markdown cuando se detecta un cambio en la fecha de actualización.

## Cambios a aplicar

### 1. `monitor.js` — reemplazar la PARTE 3 (NOTIFICACIÓN)

**Reemplazar las líneas 82-89 (función `notifyChange` actual stub):**

**Antes:**
```js
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
```

**Después:**
```js
// ============================================================
// PARTE 3: NOTIFICACIÓN (Telegram Bot API)
// ============================================================

/**
 * Envía una notificación a Telegram cuando se detecta un cambio.
 * Lee TELEGRAM_BOT_TOKEN y TELEGRAM_CHAT_ID de las variables de entorno
 * (configuradas como secrets en GitHub Environment "main").
 *
 * @param {string} newDate  Contenido nuevo detectado (fecha, nombre, código, lo que sea)
 * @param {string} url      URL monitorizada
 * @returns {Promise<void>}
 * @throws {Error} si faltan env vars o si la API de Telegram devuelve error
 */
async function notifyChange(newDate, url) {
  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;

  if (!botToken || !chatId) {
    throw new Error(
      "Faltan variables de entorno para Telegram. " +
        "Configura TELEGRAM_BOT_TOKEN y TELEGRAM_CHAT_ID como secrets " +
        "en el GitHub Environment 'main' (o como env vars locales)."
    );
  }

  const message = [
    "🔔 *Cambio detectado — Oposiciones Maestros CM*",
    "",
    "*Nueva fecha de actualización:*",
    "`" + newDate + "`",
    "",
    "*URL:*",
    url,
  ].join("\n");

  const apiUrl = "https://api.telegram.org/bot" + botToken + "/sendMessage";

  const response = await axios.post(
    apiUrl,
    {
      chat_id: chatId,
      text: message,
      parse_mode: "Markdown",
      disable_web_page_preview: true,
    },
    {
      timeout: HTTP_TIMEOUT_MS,
      validateStatus: (status) => status >= 200 && status < 300,
    }
  );

  if (!response.data || response.data.ok !== true) {
    throw new Error(
      "Telegram API devolvió error: " + JSON.stringify(response.data)
    );
  }
}
```

### 2. `.github/workflows/monitor.yml` — varios cambios

**2a. Añadir `environment: main` al job:**

En el bloque `jobs.check`, después de `runs-on: ubuntu-latest` y `timeout-minutes: 5`, añadir:

```yaml
    environment: main
```

Quedando:
```yaml
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    environment: main
```

**2b. Reemplazar el bloque `env:` del step "Run monitor":**

**Antes:**
```yaml
      - name: Run monitor
        env:
          # Reservado para Fase 2 (cuando se implemente notifyChange).
          # Si el secret no existe en el repo, GH Actions falla la ejecución.
          # Por ahora NO lo referenciamos aquí — solo dejamos el comentario.
          DISCORD_WEBHOOK: ${{ secrets.DISCORD_WEBHOOK }}
        run: node monitor.js
```

**Después:**
```yaml
      - name: Run monitor
        env:
          # Fase 2: notificación real vía Telegram Bot API.
          # Los secrets viven en el GitHub Environment "main" (no a nivel de repo),
          # por eso este job referencia `environment: main` arriba.
          # Nombre del secret en GitHub: TELEGRAM_BOT_TOKEN_HTTP (el usuario lo llamó así).
          # Se mapea a la variable de entorno TELEGRAM_BOT_TOKEN que lee el código.
          TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN_HTTP }}
          TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}
        run: node monitor.js
```

**Nota**: se elimina la línea `DISCORD_WEBHOOK` porque ya no se usa (decisión: Telegram, no Discord).

## Validación local (obligatoria)

```bash
cd C:\Users\pathl\Workspace\ScraperOposicion
pnpm lint
node --check monitor.js
```

Ambos deben pasar con exit 0.

### Validación adicional del código de notifyChange (sin enviar nada a Telegram)

El developer **NO puede** validar el envío real sin tokens reales (los tiene el usuario en GitHub Secrets, no en local). Pero puede validar:

1. **Que el código se ejecuta sin lanzar la rama del throw cuando NO hay env vars** (simulando entorno limpio):
   ```bash
   node -e "import('./monitor.js').catch(e=>console.log('OK (no envio):', e.message.split('\n')[0]))" 2>&1 | head -5
   ```
   Esperarías que en ejecución normal no salte este error (porque el `main()` solo llama a `notifyChange` cuando hay cambio detectado), pero puedes forzarlo importando solo la función si haces un mini-script de prueba.

2. **Que el código **compila** y la sintaxis es válida**: `node --check monitor.js` (ya cubierto arriba).

3. **Validación de la rama de error con env vacías** — el developer puede hacer una mini-prueba aislada sin ejecutar `main()`:
   ```bash
   node --input-type=module -e "
   import { readFile, writeFile } from 'node:fs/promises';
   import axios from 'axios';
   const HTTP_TIMEOUT_MS = 30000;
   async function notifyChange(newDate, url) {
     const botToken = process.env.TELEGRAM_BOT_TOKEN;
     const chatId = process.env.TELEGRAM_CHAT_ID;
     if (!botToken || !chatId) {
       throw new Error('Faltan variables de entorno para Telegram. Configura TELEGRAM_BOT_TOKEN y TELEGRAM_CHAT_ID...');
     }
   }
   notifyChange('test', 'http://x').catch(e => console.log('OK error esperado:', e.message.split('.')[0]));
   "
   ```
   Salida esperada: `OK error esperado: Faltan variables de entorno para Telegram`.

## Restricciones

- ❌ NO modificar NINGÚN archivo de docs (CHANGELOG, README, roadmap, feature_list, HANDOFF). Eso lo hace el leader al cierre.
- ❌ NO hacer commit.
- ❌ NO cambiar el regex (mantener el agnóstico de task-103).
- ❌ NO añadir flags al regex ni a las llamadas axios nuevas.
- ❌ NO usar `console.log` dentro de `notifyChange` (la función solo debe hacer la llamada HTTP o lanzar error).
- ❌ NO hardcodear tokens ni chat_ids. Siempre desde env vars.
- ❌ NO cambiar el `parse_mode`, el `disable_web_page_preview` ni el formato del mensaje (Markdown).
- ✅ Mantener el estilo del archivo (ESM, named imports, kebab-case para archivos, camelCase para funciones).
- ✅ Mantener la sección `// === PARTE 3: NOTIFICACIÓN ===` con banner actualizado a "Telegram Bot API".

## Entregable del developer

Reporta al leader:

1. Output literal de `pnpm lint`.
2. Output literal de `node --check monitor.js`.
3. Output literal de la mini-prueba del throw con env vacías (debe decir "Faltan variables de entorno para Telegram").
4. `git diff monitor.js .github/workflows/monitor.yml` (literal).

NO HAGAS COMMIT.
