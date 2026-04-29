# AI Metadata Standard

Every markdown documentation file in this repository must include an `@AI-METADATA` HTML comment block at the end of the file.
This block provides structured, machine-readable metadata that helps AI agents quickly understand
each document's purpose, scope, and relationships without reading the full content,
without polluting normal Markdown reading on GitHub.

## Why

- **Fast document discovery**: agents can scan metadata blocks to find relevant docs without parsing full content
- **Relationship mapping**: `relations` field creates a navigable graph between related documents
- **Invisible in normal reading**: HTML comment metadata stays out of the rendered document flow on GitHub and similar Markdown viewers
- **Plain Markdown friendly**: do not add YAML frontmatter to `.md` files in `helm/`; reserve frontmatter for rendered site content such as `site/src/pages/**/*.mdx`

## Block Format

```html
<!-- @AI-METADATA
type: <document-type>
title: <document-title>
description: <one-line-description>

keywords: <comma-separated-keywords>

purpose: <why-this-document-exists>
scope: <organizational-scope>

relations:
  - <relative-path-to-related-file>
  - <relative-path-to-related-file>
path: <relative-path-from-repo-root>
version: <semver-minor>
date: <YYYY-MM-DD>
-->
```

## Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Document classification (see types below) |
| `title` | Yes | Human-readable title |
| `description` | Yes | One-line summary (max 120 chars) |
| `keywords` | Yes | Comma-separated terms for search and classification |
| `purpose` | Yes | Why this document exists — what problem it solves |
| `scope` | Yes | Organizational scope (see scopes below) |
| `relations` | Yes | List of related file paths (relative to repo root), or `[]` if none |
| `path` | Yes | File path relative to repo root |
| `version` | Yes | Document version (Major.Minor) |
| `date` | Yes | Last significant update (YYYY-MM-DD) |

## Document Types

| Type | Used For |
|------|----------|
| `overview` | Repository-level overview documents (root README) |
| `chart-readme` | Chart README files (`charts/<name>/README.md`) |
| `chart-docs` | Chart architecture and operational guides (`charts/<name>/docs/*.md`) |
| `design` | Chart design documents (`charts/<name>/DESIGN.md`) |
| `guide` | How-to guides and strategy documents (`docs/*.md`) |
| `agent-instructions` | AI agent configuration files (.claude/AGENTS.md, .claude/CLAUDE.md) |
| `skill-definition` | Claude Code skill definitions (.claude/skills/*/SKILL.md) |
| `issue-template` | GitHub issue templates (.github/ISSUE_TEMPLATE/*.md) |

## Scopes

| Scope | Used For |
|-------|----------|
| `Repository` | Root-level repository docs |
| `Chart` | Chart README files |
| `Chart Architecture` | Chart-specific architecture and operational docs |
| `Chart Design` | Chart design decision documents |
| `Testing` | Testing strategy and patterns |
| `Agent Configuration` | AI agent instructions and skills |

## Rules for Agents

1. **Always add `@AI-METADATA`** when creating a new markdown file
2. **Always preserve `@AI-METADATA`** when editing an existing file — never remove it
3. **Update the `date` field** when making significant content changes
4. **Update the `version` field** when the document purpose or scope changes
5. **Update `relations`** when adding cross-references to other documents
6. **Keep `description` under 120 characters** — it is a summary, not a paragraph
7. **Use relative paths** from the repository root for `path` and `relations`
8. **Place the block at the very end** of the file, after all content
9. **Leave one blank line** between the last content line and the `<!-- @AI-METADATA` opening
10. **Match the `type` field** to the document's actual classification from the types table above
11. **Do not add YAML frontmatter** to plain `.md` files in `helm/`

## Example

For a new chart architecture document at `charts/redis/docs/standalone.md`:

```html
<!-- @AI-METADATA
type: chart-docs
title: Redis - Standalone
description: Standalone Redis deployment guide

keywords: redis, standalone, single-node, deployment

purpose: Standalone Redis deployment guide
scope: Chart Architecture

relations:
  - charts/redis/README.md
path: charts/redis/docs/standalone.md
version: 1.0
date: 2026-03-31
-->
```

<!-- @AI-METADATA
type: guide
title: AI Metadata Standard
description: Standard for @AI-METADATA footer blocks in documentation files

keywords: ai-metadata, standard, documentation, agents, discoverability

purpose: Define the @AI-METADATA block standard for all repository documentation
scope: Repository

relations:
  - .claude/AGENTS.md
  - .claude/CLAUDE.md
  - docs/testing-strategy.md
path: docs/ai-metadata-standard.md
version: 1.0
date: 2026-03-20
-->
