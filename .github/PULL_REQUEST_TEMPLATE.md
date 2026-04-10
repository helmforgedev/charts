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
- [ ] I updated the `site/` repository if this change affects public chart docs, listing, or maturity

## Version Validation

- [ ] I verified the application version against official GitHub Releases
- [ ] I verified the image tag against official Docker Hub tags
- [ ] I only pinned a version after confirming both sources matched

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
