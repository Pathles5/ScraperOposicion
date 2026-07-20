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

// Regex ESTRICTA en formato (D mes YYYY), tolerante en whitespace entre
// la etiqueta y la fecha (la página la pone en la línea siguiente).
// Si no matchea → exit(1) (decisión del usuario).
const UPDATE_REGEX =
  /Última actualización:\s*(\d{1,2}\s+(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+\d{4})/i;


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