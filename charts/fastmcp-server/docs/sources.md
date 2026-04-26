# Sources

FastMCP Server can load tools, resources, prompts, and knowledge from inline ConfigMaps, S3-compatible object storage, Git repositories, and OCI artifacts.

## Inline

Inline content is mounted from ConfigMaps and copied from `sources.inline.dir`.

```yaml
sources:
  inline:
    dir: /app/inline
    tools:
      greet.py: |
        def greet(name: str) -> str:
            return f"Hello, {name}!"
```

Hot reload is available for development-style deployments:

```yaml
hotReload:
  enabled: true
```

## S3

```yaml
sources:
  s3:
    enabled: true
    bucket: mcp-assets
    prefix: production
    existingSecret: fastmcp-s3
    include:
      - tools/**
    exclude:
      - "**/*.tmp"
    syncInterval: 60
```

## Git

```yaml
sources:
  git:
    enabled: true
    repository: https://github.com/example/mcp-content.git
    branch: main
    path: mcp
    existingSecret: fastmcp-git
    allowedRepositories:
      - https://github.com/example/*
    allowedBranches:
      - main
      - release/*
```

## OCI

```yaml
sources:
  oci:
    enabled: true
    registry: oci://registry.example.com/mcp-content
    tag: "1.0.0"
    existingSecret: fastmcp-oci
```

## Safety Filters

Use `sources.blockedFileAllowlist` only for intentional exceptions to the server source-file safety filter.

```yaml
sources:
  blockedFileAllowlist:
    - knowledge/private-config.example
```

<!-- @AI-METADATA
type: chart-docs
title: FastMCP Server Sources
description: Source loading guide for the FastMCP Server chart
keywords: fastmcp, s3, git, oci, inline, hot-reload
purpose: Feature-specific chart documentation
scope: Chart
relations:
  - charts/fastmcp-server/values.yaml
  - charts/fastmcp-server/templates/deployment.yaml
path: charts/fastmcp-server/docs/sources.md
version: 1.0
date: 2026-04-26
-->
