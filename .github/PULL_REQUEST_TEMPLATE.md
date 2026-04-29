## Summary

-

## Type Of Change

- [ ] New chart
- [ ] Existing chart change
- [ ] Documentation only
- [ ] CI / repository workflow

## PR Governance

- [ ] I linked an existing issue in this PR body (`Resolves #NNN` or `Related to #NNN`)
- [ ] If this is a new chart PR, labels `enhancement` and `type:feature` are applied

## Checklist

- [ ] I created this branch from updated `main`
- [ ] My PR targets `main`
- [ ] My commit message and PR title follow Conventional Commits
- [ ] I did not edit `version` in `Chart.yaml` manually
- [ ] I updated the root `README.md` if a new chart was added or public chart metadata changed
- [ ] I updated `values.schema.json` for any values changes
- [ ] I updated chart docs for behavior or default changes

## Upstream Verification

- [ ] I verified `appVersion` in `Chart.yaml` matches the real upstream release
- [ ] I confirmed the image tag in `values.yaml` corresponds to a published, stable tag
- [ ] I cross-referenced [upstream GitHub Releases](https://github.com) and [Docker Hub tags](https://hub.docker.com)

## Site Sync (GR-007)

> If this change affects chart defaults, install path, architecture, backup, or maturity:

- [ ] I updated the corresponding page in `site/` repository
- [ ] N/A — this change does not affect public documentation

## Local Validation

- [ ] I confirmed `kubectl config current-context` before local installs/upgrades/uninstalls
- [ ] `helm lint charts/<chart-name> --strict` passed
- [ ] `helm unittest charts/<chart-name>` passed
- [ ] All relevant `ci/*.yaml` scenarios rendered successfully
- [ ] I validated this change on a local `k3d` cluster when required
- [ ] I validated the default install
- [ ] I validated at least one main non-default scenario for this change
- [ ] If backup behavior changed, I validated the flow against local MinIO

## Notes

-

---

> 📚 See [CONTRIBUTING.md](../CONTRIBUTING.md) for full contribution guidelines.
