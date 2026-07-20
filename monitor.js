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

// Regex AGNÓSTICA: captura cualquier contenido (fecha, nombre, código, lo que sea)
// tras "Última actualización:" hasta el próximo bloque claro (doble salto de línea)
// o fin del body. Si no matchea → exit(1).
// [\s\S]+?   → captura lazy cualquier char incluyendo newlines.
// (?=\n\s*\n|$) → lookahead: termina en próximo bloque vacío (doble \n) o fin.
const UPDATE_REGEX = /Última actualización:\s*([\s\S]+?)(?=\n\s*\n|$)/;


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