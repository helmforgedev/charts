# Claude Code — Helm Charts Repository

## Repository

OCI Helm chart registry at `ghcr.io/mberlofa/helm`. Charts live under `charts/<name>/`.

## Skills To Use

Use these skills when they match the task:

- `helm-chart-scaffolding`
- `kubernetes-specialist`
- `coding-standards`
- `context7-docs-lookup`
- `git-workflow`
- `continuous-learning`
- `.claude/skills/repo-standards-maintenance`

## Task Matrix

| Task | Primary skill | Secondary skill |
|------|---------------|-----------------|
| Add or modify templates in `charts/*/templates/` | `helm-chart-scaffolding` | `kubernetes-specialist` |
| Add or change values in `charts/*/values.yaml` | `helm-chart-scaffolding` | `kubernetes-specialist` |
| Add a new chart | `helm-chart-scaffolding` | `kubernetes-specialist`, `context7-docs-lookup` |
| Modify `.github/workflows/*` | `git-workflow` | `Workflow Automation`, `DevOps Practices` |
| Update commit, branch, or PR conventions | `git-workflow` | `.claude/skills/repo-standards-maintenance` |
| Notice a reusable repository improvement | `.claude/skills/repo-standards-maintenance` | `continuous-learning` |
| Review chart regressions or gaps | `Code Quality` | `kubernetes-specialist` |

## Git Rules

Use Conventional Commits for commit messages and PR titles.

Chart-scoped:

- `feat(<chart>): ...`
- `fix(<chart>): ...`
- `docs(<chart>): ...`
- `refactor(<chart>): ...`
- `feat(<chart>)!: ...`

Repository-wide:

- `ci: ...`
- `docs(repo): ...`
- `refactor(repo): ...`

Rules:

- always write commit subjects in lowercase
- always use the exact chart directory name as scope for chart changes
- keep repository-instruction changes in their own commit when practical
- keep PR titles in the same Conventional Commit format for readable workflow history
- always open PRs from the working branch to `main`
- never create branch-to-branch PRs in this repository

Use the repository owner's git identity. When the agent contributed materially, add:

```text
Co-Authored-By: OpenAI Codex <codex@openai.com>
```

## Branches

Use:

- `feat/<chart>-<description>`
- `fix/<chart>-<description>`
- `refactor/<chart>-<description>`
- `docs/<scope>-<description>`
- `ci/<description>`

Mandatory flow:

1. create a branch from `main`
2. implement the change
3. commit all intended files
4. push the branch
5. create a PR to `main`

## Chart Authoring Rules

- design each chart around the application, not around `generic`
- research official docs and mature public charts before implementing
- use external charts as references, not as copy sources
- keep `values.yaml` product-oriented and explicit
- use helpers to reduce duplication inside one chart
- avoid cross-chart abstraction until it is clearly justified
- when a chart supports distinct architectures, document each one in `docs/`

## Validation

Run before pushing chart changes:

```bash
helm lint charts/<name> --strict
helm template test charts/<name>
for f in charts/<name>/ci/*.yaml; do helm template test charts/<name> -f "$f"; done
```

When available, also validate with `kubeconform`.

## Documentation Rules

- root `README.md`: repository overview, charts list, CI/CD, commit standards
- chart `README.md`: install, features, examples, values, operational usage
- chart `docs/*.md`: architecture-specific guidance
- do not expose design-history files as end-user documentation

## Repository Learning Rule

When real work reveals a stable reusable improvement:

1. fix the concrete issue
2. convert it into a short rule if it is likely to recur
3. update the smallest relevant standard document in the same branch

Preferred targets:

- `README.md`
- `AGENTS.md`
- `.claude/CLAUDE.md`
- `charts/<name>/README.md`
- `charts/<name>/docs/*.md`
