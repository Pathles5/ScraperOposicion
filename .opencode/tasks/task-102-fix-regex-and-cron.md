# Task 102: Fix regex multi-línea + ajustar cron a XX:05/XX:35

**Fase:** 1 (fix en caliente)
**Agente asignado:** developer
**Estado:** Pendiente de implementación

## Problema

El monitor falla al ejecutarse contra la página real:

```
[monitor] ERROR: No se encontró el fragmento 'Última actualización: ...' en la página.
```

### Causa raíz (diagnosticada por el explorer)

La página real **sí contiene** "Última actualización:" pero la fecha va en la línea siguiente, no en la misma línea. Tras el conversor HTML→texto el contenido es:

```
Última actualización:

            16 julio 2026
```

El regex actual `/Última actualización: ([^\n<]+)/` exige que la fecha esté en la **misma línea** (el `[^\n<]+` excluye saltos de línea), por eso nunca matchea.

Además, el usuario quiere ajustar el cron de `*/30 * * * *` (que ejecuta en :00 y :30 UTC) a `5,35 * * * *` (que ejecuta en :05 y :35 UTC), manteniendo cadencia de 30 minutos pero con 5 min de desfase.

## Cambios a aplicar

### 1. `monitor.js` — reemplazar la línea 20 (definición de `UPDATE_REGEX`)

**Antes:**
```js
// Regex ESTRICTA (decisión del usuario). Si no matchea → exit(1).
const UPDATE_REGEX = /Última actualización: ([^\n<]+)/;
```

**Después:**
```js
// Regex ESTRICTA en formato (D mes YYYY), tolerante en whitespace entre
// la etiqueta y la fecha (la página la pone en la línea siguiente).
// Si no matchea → exit(1) (decisión del usuario).
const UPDATE_REGEX =
  /Última actualización:\s*(\d{1,2}\s+(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+\d{4})/i;
```

**Por qué este regex:**
- "Última actualización:" literal → estricto.
- `\s*` después de los `:` → tolera cualquier whitespace (espacios, tabs, saltos de línea) entre la etiqueta y la fecha.
- `\d{1,2}\s+` → día (1-2 dígitos).
- `(?:enero|febrero|...|diciembre)\s+` → mes en español (alternativa explícita, no tolerante a typos).
- `\d{4}` → año (4 dígitos).
- Flag `i` → tolera mayúscula/minúscula en el mes (ej: "Julio" o "julio") por si la web cambia.
- Sigue siendo **estricto** en estructura: si la web pone la fecha en formato `DD/MM/YYYY` o `YYYY-MM-DD` o en inglés, **no matcheará** → exit(1) como pidió el usuario.

### 2. `.github/workflows/monitor.yml` — reemplazar la línea del cron

**Antes (líneas 4-7):**
```yaml
on:
  schedule:
    # Cada 30 minutos
    - cron: "*/30 * * * *"
```

**Después:**
```yaml
on:
  schedule:
    # Cada 30 minutos, en los minutos :05 y :35 (UTC)
    - cron: "5,35 * * * *"
```

Equivale a `5,35 * * * *` = ejecutar en el minuto 5 y en el minuto 35 de cada hora UTC. Misma cadencia (48/día), distinto desfase.

## Validación local (obligatoria antes de avisar al reviewer)

Después de aplicar los dos cambios, ejecuta en este orden:

```bash
cd C:\Users\pathl\Workspace\ScraperOposicion
pnpm lint
node --check monitor.js
```

Ambos deben pasar con exit 0.

Adicionalmente, valida el regex con el HTML real guardado por el explorer en:
`C:\Users\pathl\.local\share\opencode\tool-output\tool_f80298fd2001PMZYuDZ37udInm`

Copia un fragmento del archivo que contenga "Última actualización" y prueba el regex así (ejecuta desde la raíz del proyecto):

```bash
node -e "const fs=require('fs');const html=fs.readFileSync('C:\Users\pathl\.local\share\opencode\tool-output\tool_f80298fd2001PMZYuDZ37udInm','utf8');const re=/Última actualización:\s*(\d{1,2}\s+(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+\d{4})/i;const m=html.match(re);console.log('match:',m&&m[1]);"
```

**Salida esperada:** `match: 16 julio 2026`

Si no sale eso, depura antes de avisar al reviewer.

## Restricciones

- ❌ NO modificar otros archivos (CHANGELOG, README, roadmap, feature_list, package.json, eslint.config.js, state.txt, etc.).
- ❌ NO hacer commit.
- ❌ NO relajar más el regex (ej: no usar `\s+` entre número y mes que capture basura; no aceptar mes en inglés; no quitar el flag `i`).
- ❌ NO cambiar la decisión "exit(1) si no matchea" del usuario.
- ✅ Mantener el comentario explicativo sobre el regex.

## Entregable del developer

Reporta al leader:

1. Output literal de `pnpm lint` (debe pasar).
2. Output literal de `node --check monitor.js` (debe pasar).
3. Output literal del comando de validación del regex (debe imprimir `match: 16 julio 2026`).
4. Diff de los 2 archivos modificados (puedes usar `git diff monitor.js .github/workflows/monitor.yml`).
