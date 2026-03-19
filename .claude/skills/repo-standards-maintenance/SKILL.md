---
name: repo-standards-maintenance
description: Maintain repository standards, commit conventions, PR naming rules, and reusable agent guidance for this Helm repository. Use when a task reveals a stable correction or recurring improvement that should update README.md, AGENTS.md, .claude/CLAUDE.md, or chart usage documentation.
---

# Repo Standards Maintenance

Use this skill after real repository work exposed a reusable rule.

## Goal

Keep repository guidance aligned with actual practice.

## Apply This Workflow

1. Identify the concrete correction made during the task.
2. Decide whether it is reusable:
   - repeated user correction
   - stable git or PR convention
   - recurring chart-authoring mistake
   - documentation drift caused by a real change
3. Update the smallest correct target:
   - `README.md`
   - `AGENTS.md`
   - `.claude/CLAUDE.md`
   - `charts/<name>/README.md`
   - `charts/<name>/docs/*.md`
4. Keep the update short, imperative, and operational.

## Rules

- Do not document design history.
- Do not add process noise that will not affect future work.
- Prefer one precise rule over a long explanation.
- If workflow history readability is affected, update commit and PR title guidance.
- If the improvement is product-specific, update chart docs instead of repository-wide docs.

## Commit Standard

Preferred patterns:

- `feat(<chart>): ...`
- `fix(<chart>): ...`
- `docs(<chart>): ...`
- `ci: ...`
- `docs(repo): ...`
- `refactor(repo): ...`

Keep chart work and repository-standard updates in separate commits when practical.
