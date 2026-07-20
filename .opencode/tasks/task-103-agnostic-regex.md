# Task 103: Regex agnóstica — capturar cualquier contenido tras "Última actualización:"

**Fase:** 1 (fix en caliente, segundo round)
**Agente asignado:** developer
**Estado:** Pendiente de implementación

## Problema / motivación

El regex anterior (`/Última actualización:\s*(\d{1,2}\s+(?:enero|...|diciembre)\s+\d{4})/i`) es **frágil**: asume que el contenido es siempre `D mes YYYY`. Si la web cambia a otro formato (ej: nombre de usuario, fecha en otro idioma, código, etc.) el bot falla con exit(1) sin notificar el cambio.

El usuario quiere que el bot **detecte cualquier cambio** en el contenido tras "Última actualización:", sea lo que sea (fecha, nombre, código, lo que venga). El usuario revisará manualmente qué cambió.

## Objetivo

Reemplazar el regex por uno **completamente agnóstico al formato**, que capture literalmente cualquier texto entre "Última actualización:" y el próximo bloque claro (doble salto de línea) o el fin del body.

## Cambio a aplicar en `monitor.js`

**Reemplazar la línea 19-23 (actual bloque de comentario + regex):**

**Antes:**
```js
// Regex ESTRICTA en formato (D mes YYYY), tolerante en whitespace entre
// la etiqueta y la fecha (la página la pone en la línea siguiente).
// Si no matchea → exit(1) (decisión del usuario).
const UPDATE_REGEX =
  /Última actualización:\s*(\d{1,2}\s+(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\s+\d{4})/i;
```

**Después:**
```js
// Regex AGNÓSTICA: captura cualquier contenido (fecha, nombre, código, lo que sea)
// tras "Última actualización:" hasta el próximo bloque claro (doble salto de línea)
// o fin del body. Si no matchea → exit(1).
// [\s\S]+?   → captura lazy cualquier char incluyendo newlines.
// (?=\n\s*\n|$) → lookahead: termina en próximo bloque vacío (doble \n) o fin.
const UPDATE_REGEX = /Última actualización:\s*([\s\S]+?)(?=\n\s*\n|$)/;
```

## Por qué este regex

| Caso de input | Contenido capturado | OK? |
|---|---|---|
| `"Última actualización: 16 julio 2026"` | `"16 julio 2026"` | ✅ |
| `"Última actualización:\n   \n   16 julio 2026\n\nFooter"` | `"16 julio 2026"` | ✅ |
| `"Última actualización: usuario123"` | `"usuario123"` | ✅ |
| `"Última actualización:\npepito\n\nMás cosas"` | `"pepito"` | ✅ |
| `"Última actualización:\n1.2.3 (build xyz)"` | `"1.2.3 (build xyz)"` | ✅ |
| `"Última actualización:\ntexto con\nsaltos internos\n\nfin"` | `"texto con\nsaltos internos"` | ✅ (corta en `\n\n`) |
| `"foo bar"` (sin la etiqueta) | NO MATCH | ✅ (exit 1) |

## Restricciones

- ❌ NO modificar NINGÚN otro archivo del proyecto (solo `monitor.js`).
- ❌ NO modificar el resto de `monitor.js` (la función `extractUpdateDate`, el `.trim()`, el `throw`, el `main`, etc. se mantienen intactos).
- ❌ NO añadir flags al regex (sin `i`, sin `m`, sin `g`).
- ❌ NO hacer commit.
- ❌ NO eliminar el `.trim()` que ya existe en `extractUpdateDate` (es importante para no comparar whitespace).
- ✅ Mantener el comentario de 3 líneas actualizado explicando la agnosticidad.

## Validación local (obligatoria)

Después de aplicar el cambio, ejecuta:

```bash
cd C:\Users\pathl\Workspace\ScraperOposicion
pnpm lint
node --check monitor.js
```

Ambos deben pasar con exit 0.

Y valida con estos casos de prueba (debe dar match con el contenido esperado):

```bash
node -e "const re=/Última actualización:\s*([\s\S]+?)(?=\n\s*\n|$)/;const casos=['Última actualización: 16 julio 2026','Última actualización:\n   \n   16 julio 2026\n\nFooter','Última actualización: usuario123','Última actualización:\npepito\n\nMás cosas','Última actualización:\n1.2.3 (build xyz)\n\nfin','Última actualización:\ntexto con\nsaltos internos\n\nfin','foo bar'];casos.forEach(c=>{const m=c.match(re);console.log(JSON.stringify(c),'=>',m?'['+m[1]+']':'NO MATCH')});"
```

**Salida esperada:**
```
"Última actualización: 16 julio 2026" => [16 julio 2026]
"Última actualización:\n   \n   16 julio 2026\n\nFooter" => [16 julio 2026]
"Última actualización: usuario123" => [usuario123]
"Última actualización:\npepito\n\nMás cosas" => [pepito]
"Última actualización:\n1.2.3 (build xyz)\n\nfin" => [1.2.3 (build xyz)]
"Última actualización:\ntexto con\nsaltos internos\n\nfin" => [texto con\nsaltos internos]
"foo bar" => NO MATCH
```

Y contra el HTML real del explorer (`C:\Users\pathl\.local\share\opencode\tool-output\tool_f80298fd2001PMZYuDZ37udInm`):

```bash
node -e "const fs=require('fs');const html=fs.readFileSync('C:\Users\pathl\.local\share\opencode\tool-output\tool_f80298fd2001PMZYuDZ37udInm','utf8');const re=/Última actualización:\s*([\s\S]+?)(?=\n\s*\n|$)/;const m=html.match(re);console.log('match:',m&&JSON.stringify(m[1]));"
```

**Salida esperada:** `match: "16 julio 2026"` (con comillas porque JSON.stringify las añade).

## Entregable del developer

Reporta:

1. Output literal de `pnpm lint`.
2. Output literal de `node --check monitor.js`.
3. Output literal de las 7 pruebas de robustez (la línea con los 7 `=>`).
4. Output literal de la validación contra HTML real.
5. `git diff monitor.js` (literal).

NO HAGAS COMMIT.
