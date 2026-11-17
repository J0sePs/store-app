@AGENTS.md

## Notas específicas de Claude Code

- Las reglas del proyecto están en `AGENTS.md` (importado arriba). Ese archivo es la fuente única de verdad.
- Comandos de OpenSpec en Claude Code (son skills): `/openspec-propose <name>`, `/openspec-apply-change`, `/openspec-verify-change`, `/openspec-archive-change`. Más: `/openspec-explore`, `/openspec-new-change`, `/openspec-continue-change`, `/openspec-ff-change`, `/openspec-update-change`, `/openspec-sync-specs`, `/openspec-bulk-archive-change`, `/openspec-onboard`.
- Skills del proyecto en `.claude/skills/` (incluida `harness-creator`).
- Este repo modifica también `../store-gitops`. Si no tienes acceso, pide al usuario que ejecute `/add-dir ../store-gitops`.
- Para changes grandes (infra, CI, gitops), presenta primero un plan y espera confirmación antes de editar.
