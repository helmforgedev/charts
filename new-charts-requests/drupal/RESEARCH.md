# Drupal - Research Findings

Chart Request: Issue #104
Requester: khrystoph
Upstream: https://new.drupal.org/home
Research Date: 2026-04-23

## Core Architecture

Drupal is a PHP CMS typically deployed behind Apache or PHP-FPM and backed by MySQL, MariaDB, PostgreSQL, or SQLite. The Docker Official Image ships Apache variants and expects the site installation to be completed through the web installer or a custom image workflow. The application stores critical runtime state under `sites/`, especially `settings.php` and uploaded files.

## Official Runtime Sources

- Product site: https://new.drupal.org/home
- Drupal system requirements: https://www.drupal.org/docs/getting-started/system-requirements
- Docker Official Image packaging: https://github.com/docker-library/drupal
- Docker image metadata: https://hub.docker.com/_/drupal

Important note:

- Drupal upstream does not currently publish its own upstream-maintained runtime container image.
- The only broadly maintained official container distribution is the Docker Official Image `docker.io/library/drupal`.
- For this chart, that image is the practical source used for runtime packaging, and this exception should remain explicit in docs and review.

## Latest Stable Runtime

From `docker-library/drupal` `versions.json` on 2026-04-23:

- Drupal 11.3 line: `11.3.8`
- Supported Apache variants include `apache-trixie` and `apache-bookworm`

Selected runtime for this chart:

- Image: `docker.io/library/drupal:11.3.8-apache-bookworm`
- Reason: pinned stable release, explicit distro suffix, conservative Debian base

## Official Requirements That Matter For The Chart

From Drupal system requirements on 2026-04-23:

- Drupal 11 supports PHP 8.3, 8.4, and 8.5
- Drupal 11 database requirements:
  - MariaDB 10.6+
  - MySQL 8.0+
  - PostgreSQL 16+
  - SQLite 3.45+

## Existing Charts Analysis

### Bitnami Drupal Chart

Strengths:

- Mature chart packaging
- Full bootstrap flow with bundled MariaDB support
- Broad install options

Limitations:

- Violates HelmForge image policy because it is tied to Bitnami packaging
- Heavier abstraction than HelmForge's product-oriented values style
- Harder to align with HelmForge's upstream-image-only positioning

### Drupal.org helm_chart Project

Strengths:

- Drupal-community context
- Confirms user demand for Kubernetes packaging

Limitations:

- Not a dominant, production-standard chart source
- Less aligned with HelmForge chart UX and validation expectations
- Does not define a clear operational standard for HelmForge docs, tests, and NOTES quality

## Common Challenges

### 1. Persisting Drupal Correctly

Problem:

- Mounting a PVC over `/var/www/html` hides the application code from the image.

Solution:

- Persist only `sites/`, and seed it from the image in an init container before the main container mounts it.

### 2. Installation Is Mostly Interactive

Problem:

- The official runtime image does not natively expose a WordPress-style environment-variable bootstrap flow for the initial site install.

Solution:

- Provide a chart that gets Drupal and the database online cleanly, then guide the user through the installer with exact NOTES and docs.

### 3. Database Selection Needs To Be Explicit

Problem:

- Drupal supports multiple backends, but the runtime container does not use one fixed contract for automatic bootstrap.

Solution:

- Make MySQL the default bundled path for MVP, while documenting external database and SQLite install paths clearly.

## Production Requirements

- Persistent `sites/` storage
- Clear ingress and TLS support
- Honest single-replica default
- Exact installer guidance for database-backed and SQLite installs
- Documentation that explains what is and is not automated

## HelmForge Differentiation Opportunities

### Priority 1: Correct `sites/` Persistence Pattern

Impact: High

- Avoids the most common broken mount pattern for Drupal containers on Kubernetes.
- Gives users a working persistent install path without custom images.

### Priority 2: Product-Oriented Installer Guidance

Impact: High

- The chart can tell users exactly which host, database, username, and password to use in the installer.
- This reduces friction without pretending that installation is fully automated.

### Priority 3: Clean Upstream-Image Positioning

Impact: High

- HelmForge can offer a Drupal chart without Bitnami runtime images.
- The docs can explain the Docker Official Image nuance explicitly instead of hiding it.

## Comparison Matrix

| Feature | Existing Public Options | HelmForge Direction |
|---------|-------------------------|---------------------|
| Runtime image | Often Bitnami or mixed community packaging | Docker Official Image with explicit pinned tag |
| Persistence model | Often broad app-root mounts | `sites/`-only persistence with seed init container |
| Installer guidance | Frequently implicit | Explicit Helm NOTES and docs |
| Database path | Usually MariaDB-centric | MySQL default, external DB and SQLite documented |
| Documentation style | Varies widely | HelmForge docs + site sync + values reference |

## Estimated Complexity

- Chart implementation: Medium
- Time to MVP: 1 workstream
- Maintenance effort: Medium

## Recommendation

Priority: High

Rationale:

- Drupal is a major CMS request and fits HelmForge's catalog well.
- The chart can provide meaningful value even without automating the full site installation flow.
- The strongest differentiator is operational correctness around persistence and installation guidance.

Main risk:

- The runtime image is a Docker Official Image, not a Drupal-upstream-maintained image. Maintainers should confirm that this explicit exception is acceptable for HelmForge policy.
