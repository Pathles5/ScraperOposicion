# HANDOFF — FASE 1: Monitor de Oposiciones CM

**Fecha:** 2026-07-20
**Estado:** Pendiente de OK del usuario

## Resumen

Bot en Node.js que monitoriza la página de oposiciones de la Comunidad de Madrid y detecta cambios en la fecha de "Última actualización". Si cambia, notifica (en esta fase: **stub**, sin implementación real). El estado persiste en `state.txt` versionado en el repo. GitHub Actions ejecuta el bot cada 30 minutos y hace commit/push de `state.txt` cuando cambia.

## Decisiones validadas con el usuario

- **D1**: 4 archivos sueltos en raíz, sin arquitectura hexagonal.
- **D2**: Node 20 (alineado en workflow y dev).
- **D3**: Regex **estricta** (`/Última actualización: ([^\n<]+)/`). Si no matchea → `process.exit(1)`.
- **D4**: Notificación **NO implementada** en esta fase. Stub preparado. Alternativas a presentar al usuario (Discord, Telegram, ntfy.sh, Slack, GitHub Issues, etc.).
- **D5**: Bootstrap completo (package.json, eslint plano, .gitignore).
- **D6**: Errores simples con `throw new Error(...)`, sin clases custom.

## Alcance

### Archivos a crear/modificar

| Path | Acción |
|---|---|
| `package.json` | Crear. ESM (`"type": "module"`), deps: `axios`, `cheerio`. Scripts: `start`, `lint`. |
| `eslint.config.js` | Crear. ESLint plano (flat config), sin Prettier. |
| `.gitignore` | Ya existe. Verificar que NO incluye `state.txt` (se commitea). |
| `monitor.js` | Crear. Entrypoint con 3 funciones separadas: `fetchPage`, `extractUpdateDate`, `notifyChange` (stub). |
| `state.txt` | Crear con valor inicial `16 julio 2026`. |
| `.github/workflows/monitor.yml` | Crear. Cron `*/30 * * * *`, `workflow_dispatch`, Node 20, ubuntu-latest, secret `DISCORD_WEBHOOK` (placeholder), `permissions: contents: write`, `concurrency` group, commit/push idempotente con `github-actions[bot]`. |
| `README.md` | Actualizar tagline + sección Getting Started con instrucciones reales. |
| `CHANGELOG.md` | Añadir entrada Fase 1. |
| `docs/roadmap.md` | Marcar Fase 1 completada. |
| `feature_list.json` | Añadir feature `monitor-cm-edu`. |

### Estructura interna de `monitor.js` (3 partes diferenciadas)

```
1. SCRAPING
   async function fetchPage(url) → string HTML
   - axios.get con User-Agent común (Mozilla/5.0 ...)
   - Timeout 30s
   - throw si status != 200

2. LÓGICA DE BÚSQUEDA DE ACTUALIZACIÓN
   function extractUpdateDate(html) → string fecha
   - cheerio parsea HTML, extrae text() del body
   - regex ESTRICTA: /Última actualización: ([^\n<]+)/
   - trim del match
   - throw + exit(1) si no encuentra

3. NOTIFICACIÓN (STUB en esta fase)
   async function notifyChange(newDate, url) → void
   - Por ahora: console.log con TODO documentado
   - Cuando se implemente: POST a webhook elegido por el usuario
   - Estructura preparada para que añadir Discord/Telegram/etc sea 1 sola función

main():
   1. Lee state.txt → previousDate
   2. fetchPage(url)
   3. extractUpdateDate(html) → currentDate
   4. Si currentDate === previousDate → console.log("Sin cambios") + exit(0)
   5. Si cambió → notifyChange(currentDate, url) + escribe state.txt + exit(0)
   6. Si fetch o extract fallan → throw + exit(1)
```

### Workflow `monitor.yml` (resumen)

```yaml
name: Monitor CM Educacion
on:
  schedule: [{ cron: '*/30 * * * *' }]
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
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: 9 }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - name: Run monitor
        env:
          DISCORD_WEBHOOK: ${{ secrets.DISCORD_WEBHOOK }}
        run: node monitor.js
      - name: Commit state if changed
        run: |
          git config user.name 'github-actions[bot]'
          git config user.email 'github-actions[bot]@users.noreply.github.com'
          git add state.txt
          git diff --cached --quiet || (git commit -m "chore(state): update last update date" && git push)
```

## Estimación

**1 task único** para el developer (todo va junto, es pequeño):
- `task-101-monitor-cm.md`

**Justificación de 1 sola task**: el usuario pidió "lo más simple posible" y "para mañana". El reviewer validará el conjunto.

## Alternativas a Discord (a presentar al usuario)

Para fase futura (Fase 2), opciones a considerar:

| Opción | Pros | Contras |
|---|---|---|
| **Discord webhook** | Ya planeado. Gratis. Embed rico. | Dependencia externa (Discord). |
| **Telegram Bot API** | Gratis. Muy popular en bots. Sin coste. App móvil excelente. | Requiere crear bot (@BotFather). |
| **ntfy.sh** | Literalmente `curl -d "msg" ntfy.sh/topic". Sin auth. Open source. Self-hostable. | Menos conocido. App básica. |
| **Slack webhook** | Similar a Discord. Si el usuario ya usa Slack. | Mismo patrón que Discord. |
| **GitHub Issues** | Cero infra externa. Crea una issue auto. | Ruido en el repo. |
| **Microsoft Teams** | Si el usuario usa Teams en trabajo. | Mismo patrón que Discord/Slack. |

**Recomendación Leader**: **Telegram** si quieres notificaciones móviles sólidas y gratuitas, o **ntfy.sh** si quieres máxima simplicidad sin dependencias.

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Web cambia estructura → regex no matchea | Regex estricta + `exit 1` → GitHub Actions muestra el error claramente. |
| Dos runs concurrentes compiten por push | `concurrency: group: monitor-cm` serializa ejecuciones. |
| `state.txt` vacío o corrupto | Si falla lectura o el contenido está vacío → `throw` + `exit 1`. |
| Sin tests (ADR-002) | Quality gate: lint + review crítica del código. |

## Fuera de alcance (explícito)

- ❌ Notificación real (queda como stub).
- ❌ Tests.
- ❌ Husky/lefthook.
- ❌ Reescritura de la arquitectura hexagonal del bootstrap (se mantiene la documentación existente).
- ❌ Múltiples URLs de monitorización.

## Pendiente de OK

- [ ] Usuario valida el plan.
- [ ] Usuario elige alternativa de notificación (para fase futura, no bloqueante ahora).


## Decisión registrada para Fase 2 (no bloqueante)

**Notificación elegida:** **Telegram Bot API**.

Pendiente para Fase 2:
- Crear bot con @BotFather, obtener `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID`.
- Reemplazar el stub `notifyChange` por llamada a `https://api.telegram.org/bot<TOKEN>/sendMessage`.
- Añadir `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID` como secrets en el repo.
- Actualizar workflow para inyectar ambos secrets.
- Actualizar HANDOFF y CHANGELOG al cierre de Fase 2.
