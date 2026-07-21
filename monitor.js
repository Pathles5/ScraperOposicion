/**
 * Monitor de oposiciones — multi-site
 * Detecta cambios en N páginas web mediante:
 *   1) HEAD-first: usa Last-Modified o ETag si el servidor lo envía.
 *   2) Fallback: SHA-256 sobre HTML normalizado.
 * Persistencia por sitio en state/<siteId>.fingerprint.
 */

import { readFile, writeFile, rename } from "node:fs/promises";
import { createHash } from "node:crypto";
import axios from "axios";
import * as cheerio from "cheerio";

const SITES_FILE = ".opencode/config/sites.json";
const STATE_DIR = "state";
const INIT_FLAG = `${STATE_DIR}/.initialized`;
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
async function loadSites() {
  const raw = await readFile(SITES_FILE, "utf8");
  const parsed = JSON.parse(raw);
  if (!Array.isArray(parsed.sites)) {
    throw new Error("sites.json debe contener { sites: [...] }");
  }
  for (const s of parsed.sites) {
    if (!s.id || !s.name || !s.url) {
      throw new Error(`Sitio inválido: ${JSON.stringify(s)}`);
    }
  }
  return parsed.sites;
}


// ============================================================
// PARTE 2: SCRAPING
// ============================================================

/**
 * HEAD request para inspeccionar Last-Modified y ETag sin descargar el body.
 * @param {string} url
 * @returns {Promise<{lastModified: string|null, etag: string|null}>}
 */
async function fetchHead(url) {
  const response = await axios.head(url, {
    headers: { "User-Agent": USER_AGENT },
    timeout: HEAD_TIMEOUT_MS,
    validateStatus: () => true, // no tirar en 4xx/5xx; queremos leer headers si los hay
  });
  return {
    lastModified: response.headers["last-modified"] || null,
    etag: response.headers["etag"] || null,
  };
}

/**
 * GET request del HTML completo.
 * @param {string} url
 * @returns {Promise<string>}
 * @throws {Error} si la petición falla o el status no es 2xx
 */
async function fetchPage(url) {
  const response = await axios.get(url, {
    headers: { "User-Agent": USER_AGENT },
    timeout: GET_TIMEOUT_MS,
    responseType: "text",
    validateStatus: (status) => status >= 200 && status < 300,
  });
  return response.data;
}


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
function normalizeAndHash(html) {
  const $ = cheerio.load(html);
  $("script, style").remove();
  // Quitar comentarios HTML
  $("*").contents().filter((_, n) => n.type === "comment").remove();
  const text = $("body").text();
  const collapsed = text.replace(/\s+/g, " ").trim();
  return createHash("sha256").update(collapsed).digest("hex");
}

/**
 * Detecta el fingerprint de un sitio.
 * Estrategia:
 *   1) HEAD → si lastModified presente, devuelve { tipo: "last-modified", valor }.
 *   2) Si no, si etag presente, devuelve { tipo: "etag", valor }.
 *   3) Si no, GET → normalizeAndHash → { tipo: "sha256", valor }.
 * @param {{id: string, url: string}} site
 * @returns {Promise<{tipo: string, valor: string, detectionMethod: string}>}
 */
async function detectFingerprint(site) {
  const { lastModified, etag } = await fetchHead(site.url);

  if (lastModified) {
    return { tipo: "last-modified", valor: lastModified, detectionMethod: "last-modified" };
  }
  if (etag) {
    return { tipo: "etag", valor: etag, detectionMethod: "etag" };
  }

  const html = await fetchPage(site.url);
  const hash = normalizeAndHash(html);
  return { tipo: "sha256", valor: hash, detectionMethod: "sha256" };
}


// ============================================================
// PARTE 4: PERSISTENCIA ATÓMICA
// ============================================================

/**
 * Lee el fingerprint almacenado para un sitio.
 * Formato del fichero: "<tipo>\n<valor>\n".
 * @param {string} siteId
 * @returns {Promise<{tipo: string, valor: string}|null>}
 */
async function loadStoredFingerprint(siteId) {
  try {
    const raw = await readFile(`${STATE_DIR}/${siteId}.fingerprint`, "utf8");
    const [tipo, valor] = raw.trim().split("\n");
    return { tipo, valor };
  } catch (err) {
    if (err.code === "ENOENT") return null;
    throw err;
  }
}

/**
 * Persiste el fingerprint de un sitio de forma atómica.
 * Escribe en <siteId>.fingerprint.tmp y luego rename → <siteId>.fingerprint.
 * @param {string} siteId
 * @param {{tipo: string, valor: string}} fingerprint
 */
async function saveStoredFingerprint(siteId, fingerprint) {
  const finalPath = `${STATE_DIR}/${siteId}.fingerprint`;
  const tmpPath = `${finalPath}.tmp`;
  await writeFile(tmpPath, `${fingerprint.tipo}\n${fingerprint.valor}\n`, "utf8");
  await rename(tmpPath, finalPath);
}


// ============================================================
// PARTE 5: DETECCIÓN DE PRIMERA EJECUCIÓN (D15)
// ============================================================

/**
 * Comprueba si es la primera ejecución del monitor
 * (ausencia del flag `state/.initialized`).
 * @returns {Promise<boolean>} true si NO existe el flag (primera vez).
 * @throws si el error de lectura no es ENOENT.
 */
async function isFirstRun() {
  try {
    await readFile(INIT_FLAG, "utf8");
    return false;
  } catch (err) {
    if (err.code === "ENOENT") return true;
    throw err;
  }
}

/**
 * Marca que el monitor ya se ha ejecutado al menos una vez.
 * Persiste la fecha ISO actual en `state/.initialized`.
 */
async function markInitialized() {
  await writeFile(INIT_FLAG, new Date().toISOString(), "utf8");
}


// ============================================================
// PARTE 6: NOTIFICACIÓN TELEGRAM (always-notify + Markdown)
// ============================================================

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


// ============================================================
// ORQUESTACIÓN
// ============================================================

async function main() {
  const sites = await loadSites();
  console.log(`[monitor] Sitios configurados: ${sites.length}`);

  const firstRun = await isFirstRun();
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

  if (firstRun) {
    await markInitialized();
  }
  await sendTelegramSummary(summary, { firstRun });
}

main().catch((err) => {
  console.error(`[monitor] ERROR: ${err.message}`);
  process.exit(1);
});