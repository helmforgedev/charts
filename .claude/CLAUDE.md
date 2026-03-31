# Claude Code — Helm Charts Repository

## Repository

Helm chart repository at `https://repo.helmforge.dev`, OCI registry at `ghcr.io/helmforgedev/helm`, website at `https://helmforge.dev`, and documentation at `https://helmforge.dev/doc`. Charts live under `charts/<name>/`.

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
| Add or modify unit tests in `charts/*/tests/` | `helm-chart-scaffolding` | `kubernetes-specialist` |
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

Use the repository owner's git identity.

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
- before starting the next phase for the same chart or workstream, verify that the previous PR was merged and refresh local `main` from `origin/main`
- do not assume local `main` is current after a merge; this repository can add a publish/release commit immediately after the PR merge
- when resuming work on a chart that was just merged, treat `merge commit + automated release commit` as the normal expected state to avoid stale-base conflicts

## Chart Authoring Rules

- **never edit `version` in `Chart.yaml` manually** — the publish workflow (`publish.yml`) calculates semantic versions automatically from commit messages, updates `Chart.yaml`, tags, and publishes. Manual version edits will conflict with CI.
- design each chart around the application, not around `generic`
- research official docs and mature public charts before implementing
- confirm the latest stable application version from the official project repository before setting `appVersion`, image tags, or versioned examples
- use an official runtime image when upstream provides one; if it does not, document that clearly and validate with an image built from the official source or package
- use external charts as references, not as copy sources
- keep `values.yaml` product-oriented and explicit
- document default `values.yaml` keys with inline comments following the repository pattern already used by the documented charts
- use helpers to reduce duplication inside one chart
- avoid cross-chart abstraction until it is clearly justified
- when a chart supports distinct architectures, document each one in `docs/`
- if a solution exposes a UI or web entrypoint, include configurable ingress support with `ingressClassName`
- for UI/web solutions, `ingressClassName` may default to `traefik`, and docs must mention that `nginx` or another supported ingress class can also be used
- before pushing on a branch with an existing PR, verify whether the PR is still open, merged, closed, or obsolete

## ArtifactHub Annotations

Every `Chart.yaml` must include ArtifactHub annotations for chart discovery. When creating a new chart, always add:

```yaml
annotations:
  artifacthub.io/license: MIT
  artifacthub.io/category: <category>
  artifacthub.io/links: |
    - name: Documentation
      url: https://helmforge.dev/docs/charts/<chart-name>
    - name: Source
      url: https://github.com/helmforgedev/charts/tree/main/charts/<chart-name>
```

Valid categories: `database`, `streaming-messaging`, `security`, `networking`, `monitoring-logging`, `integration-delivery`, `storage`, `gaming`. See `AGENTS.md` for details.

## Validation

Run before pushing chart changes:

```bash
helm lint charts/<name> --strict
helm template test charts/<name>
helm unittest charts/<name>
for f in charts/<name>/ci/*.yaml; do helm template test charts/<name> -f "$f"; done
```

When available, also validate with `kubeconform`.

Before any local `helm install`, `helm upgrade`, `helm uninstall`, or runtime validation command:

- run `kubectl config current-context`
- confirm the context is the intended local `k3d` context
- treat context verification as a hard gate, not as an optional check
- never perform local validation installs against a non-local cluster context
- never run `helm install`, `helm upgrade`, or `helm uninstall` until the local `k3d` context is explicitly confirmed
- if the context is wrong or unclear, stop and fix it before continuing
- remember that installing into the wrong context can impact shared or production-like clusters
- if the chart adds or changes S3 backup behavior, validate the backup CronJob against a local MinIO endpoint on the local `k3d` cluster before merging

## Local k3d Validation (New Charts)

When creating a new chart, always deploy and validate it on a local k3d cluster **before merging the PR**:

1. Push and open the PR, wait for CI to pass.
2. Create a k3d cluster if one is not already running (`k3d cluster create test`).
3. Install the chart with default values and verify pods reach `Running`/`Completed` state.
4. Install at least one non-default CI scenario and verify the application is reachable.
5. Fix any issues found before merging — commit fixes to the same PR branch.
6. Clean up test releases after validation (`helm uninstall`).
7. Merge the PR only after k3d validation succeeds.
8. If the chart adds or changes backup behavior, run the backup flow end-to-end against local MinIO and confirm the artifact lands in object storage.

Critical safety rule:

- do not assume cluster creation switched `kubectl` automatically
- verify the active context explicitly before the first install
- repeat that verification before every validation install, upgrade, or uninstall
- if `kubectl config current-context` is not the expected local `k3d` context, do not install
- treat MinIO-backed backup execution as mandatory local validation for backup-capable chart changes

## Unit Testing Rules

Tests live under `charts/<name>/tests/<template>_test.yaml`. See `docs/testing-strategy.md` for the full testing guide.

Key rules for writing helm-unittest tests:

- when a template uses `include` to reference another template (e.g., checksum annotations), add the dependency to the suite `templates` list and use `template:` at the test level to target assertions
- never rely on `documentIndex` across multiple template files; `documentIndex` is scoped per-template, not globally across all rendered templates
- use `template: <file>.yaml` at the test level when the suite lists multiple templates
- use `documentSelector` by `kind` or `metadata.name` when the document order is unstable
- Kubernetes adds `protocol: TCP` by default; if the rendered output includes it, assertions must include it too
- check whether secrets use `data` (base64) or `stringData` (plain text) before writing assertions
- test conditional resources in both enabled and disabled states
- for PDBs, test the full condition (some require `replicaCount > 1` or specific architecture modes)
- always run `helm unittest charts/<name>` locally before pushing

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

## AI Metadata Rules

Every markdown documentation file must include an `<!-- @AI-METADATA -->` HTML comment block at the end. See `docs/ai-metadata-standard.md` for the full specification.

Key rules:

- always add `@AI-METADATA` when creating a new markdown file
- always preserve existing `@AI-METADATA` blocks when editing files — never remove them
- update `date` when making significant content changes
- update `relations` when adding cross-references to other documents
- use the correct `type` from the standard: `overview`, `chart-readme`, `chart-docs`, `design`, `guide`, `agent-instructions`, `skill-definition`, `issue-template`
- place the block at the very end of the file after all content
- use relative paths from the repository root for `path` and `relations`

## Release Notes and Versioning

Releases are fully automated by the `publish.yml` workflow. Do not create releases, tags, or changelogs manually.

How the pipeline works:

1. PR merges to `main` trigger `publish.yml`
2. The workflow detects changed charts and calculates the next semantic version from Conventional Commits
3. It packages the chart, pushes to OCI and the Helm repo index
4. It creates an annotated git tag (`{chart}-v{version}`)
5. It generates categorized release notes and creates a GitHub Release

Release notes are auto-generated from commits between the previous tag and HEAD for each chart. Commits are categorized as:

- **Breaking Changes**: commits with `!:` or `BREAKING CHANGE` in the body
- **Features**: `feat(...):`
- **Bug Fixes**: `fix(...):`
- **Other Changes**: `docs`, `refactor`, `ci`, etc.

Rules:

- never create GitHub Releases manually — the pipeline owns this
- never edit `version` in `Chart.yaml` — the pipeline calculates and updates it
- never create or push git tags manually — the pipeline creates annotated tags
- write clear, descriptive Conventional Commit messages — they become the release notes
- keep each commit focused on one logical change so release notes are readable
- if a commit message is unclear or vague, the release notes will reflect that — invest in good commit messages
- breaking changes must use `!:` in the commit subject or `BREAKING CHANGE` in the body so they are highlighted in release notes

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

<!-- @AI-METADATA
type: agent-instructions
title: Claude Code Project Instructions
description: Project-specific instructions for Claude Code agents working on this Helm repository

keywords: claude-code, agent, instructions, helm, conventions, git, testing

purpose: Configure Claude Code behavior for this Helm chart repository
scope: Agent Configuration

relations:
  - AGENTS.md
  - docs/testing-strategy.md
path: .claude/CLAUDE.md
version: 1.0
date: 2026-03-20
-->
