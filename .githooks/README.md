<!-- SPDX-License-Identifier: Apache-2.0 -->
# Git hooks (GR-079)

Tracked hooks for this repo. Enable them once per clone:

```bash
git config core.hooksPath .githooks
```

## `pre-push`

Runs the helmforge-ops `standards-guard` before every push: each chart changed
vs `origin/main` must fully pass `standards-check` (zero BLOCKER/HIGH findings —
SPDX, required structure incl. `DESIGN.md`/`docs`/`examples`, README Security-Scan
section, deps, className, Chart.lock). See GR-079.

- Resolves helmforge-ops from `$HELMFORGE_OPS_DIR` or the sibling `../helmforge-ops`.
- If helmforge-ops isn't found it warns and does not block (server-side CI —
  `.github/workflows/standards-check.yml` — is the guarantee).
- Override a single push with `git push --no-verify` (discouraged).
