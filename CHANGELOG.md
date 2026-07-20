# Changelog
All notable changes to scraper-oposicion will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added (Fase 1 — Monitor CM Educacion)
- `monitor.js`: monitor de oposiciones de la Comunidad de Madrid con tres secciones claramente diferenciadas:
  - **SCRAPING** — `fetchPage(url)`: axios con User-Agent Mozilla, timeout 30s, validateStatus 2xx.
  - **LÓGICA DE BÚSQUEDA** — `extractUpdateDate(html)`: cheerio + regex ESTRICTA `/Última actualización: ([^\n<]+)/`. Throw + exit(1) si no matchea.
  - **NOTIFICACIÓN** — `notifyChange(date, url)`: stub preparado para Fase 2 (Telegram, pendiente de implementar).
- `state.txt`: estado persistente con valor inicial `16 julio 2026`. Versionado en repo.
- `.github/workflows/monitor.yml`: cron `*/30 * * * *` + `workflow_dispatch`. Node 20, ubuntu-latest, pnpm 9 con cache. Secret `DISCORD_WEBHOOK` reservado (Fase 2). `permissions: contents: write`, `concurrency: monitor-cm`, commit/push idempotente con autor `github-actions[bot]`.
- `package.json`: ESM, deps `axios ^1.7.7` + `cheerio ^1.0.0`, devDeps `eslint ^9.12.0` + `@eslint/js ^9.12.0`.
- `eslint.config.js`: ESLint 9 flat config plano (sin Prettier acoplado).

### Changed (Fase 1)
- README actualizado con tagline real e instrucciones de uso (Node 20, pnpm).
- Roadmap marca Fase 1 como completada.
- `feature_list.json` registra la feature `monitor-cm-edu`.

## [0.0.0] - 2026-07-20

### Added (Fase 0 — Foundation)
- Bootstrap del proyecto: agent swarm (5 agentes) + harness de documentación + SDD loop.
- Documentación canónica en `docs/` (architecture, conventions, decisions, roadmap).
- ADRs-001 (agent swarm + SDD) y ADR-002 (sin suite de tests por defecto) registrados.
- Meta-archivos: `AGENTS.md`, `CONTRIBUTING.md`, `README.md` (placeholder), `feature_list.json`, `.gitignore`.
