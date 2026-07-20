# Contributing to scraper-oposicion

## Development Workflow
1. Create a feature branch from `<base-branch>` (pendiente de definir; por ahora `main`).
2. Make changes following the conventions below.
3. Run verification: `pnpm lint`
4. Submit a pull request.

> **Nota:** Este proyecto **no incluye suite de tests** (ver ADR-002). El verification order es solo `pnpm lint`. Si en una fase futura se introducen tests, este archivo se actualizará.

## Branch Naming
- `feat/` — New features
- `fix/` — Bug fixes
- `refactor/` — Code restructuring
- `docs/` — Documentation changes
- `chore/` — Maintenance (deps, build, config)

## Code Conventions
See [docs/conventions.md](docs/conventions.md) for full coding standards.

Key points:
- ESM only, imports require `.js` extension
- Named exports only
- No `export default`

## Commit Messages
Format: `<type>(<scope>): <description>`

Examples:
- `feat(gateway): add circuit breaker to relay`
- `fix(gateway): handle empty test cases`
- `docs(readme): update architecture diagram`
- `chore(deps): bump eslint to v9`

## Pull Request Checklist
- [ ] Branch is up to date with `<base-branch>`
- [ ] `pnpm lint` passes
- [ ] New code follows conventions in `docs/conventions.md`
- [ ] Documentation updated (if applicable)
- [ ] **Si modificaste un endpoint HTTP (path, método, body, status code, schema)**:
  - [ ] Spec OpenAPI actualizado
  - [ ] Tabla de endpoints en `README.md` actualizada si aplica