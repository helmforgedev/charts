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
2. if a previous branch for the same line of work was merged, stop working from that branch
3. run `git checkout main` and `git pull --ff-only origin main` before creating the next branch
4. create the new branch from the updated local `main`
5. implement the change
6. commit all intended files
7. if the branch already has an open PR, check the PR status before pushing
8. push the branch
9. if no PR exists yet, create a PR to `main`

Conflict prevention rule:

- never start a new phase from an older feature branch after its PR was merged
- always restart from current `main`
- in this repository, reusing an old feature branch as the base for the next phase commonly creates avoidable conflicts in `README.md`, `values.yaml`, and chart docs

## Chart Authoring Rules

- design each chart around the application, not around `generic`
- research official docs and mature public charts before implementing
- use external charts as references, not as copy sources
- keep `values.yaml` product-oriented and explicit
- document default `values.yaml` keys with inline comments following the repository pattern already used by the documented charts
- use helpers to reduce duplication inside one chart
- avoid cross-chart abstraction until it is clearly justified
- when a chart supports distinct architectures, document each one in `docs/`
- if a solution exposes a UI or web entrypoint, include configurable ingress support with `ingressClassName`
- for UI/web solutions, `ingressClassName` may default to `traefik`, and docs must mention that `nginx` or another supported ingress class can also be used
- before pushing on a branch with an existing PR, verify whether the PR is still open, merged, closed, or obsolete

## Validation

Run before pushing chart changes:

```bash
helm lint charts/<name> --strict
helm template test charts/<name>
for f in charts/<name>/ci/*.yaml; do helm template test charts/<name> -f "$f"; done
```

When available, also validate with `kubeconform`.

## Documentation Rules

- all repository documentation must be written in English
- root `README.md`: repository overview, charts list, CI/CD, commit standards
- chart `README.md`: install, features, examples, values, operational usage
- chart `README.md` must document the main default values for the chart
- chart `docs/*.md`: architecture-specific guidance
- chart docs must use relative internal links only; never include local machine paths or repository-absolute filesystem paths
- external references in chart docs must point only to official vendor or project documentation
- chart documentation should stay exclusive to that chart, not to repository-internal development process
- always document ingress examples in `values.yaml` using `hosts`, `ingressClassName`, and `tls[].secretName`
- always use `ingressClassName` as the values key for ingress class selection
- whenever documenting ingress in `values.yaml`, include a commented annotation example with `cert-manager.io/cluster-issuer`
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
