# GitHub MCP Server Toolsets

The chart generates command-line arguments from `github.*` values unless `app.args` is set.

```yaml
github:
  toolsets: repos,issues,pull_requests
  tools: ""
  excludeTools: create_issue,create_pull_request
```

Use `github.toolsets` to select broad groups, `github.tools` to allow specific tools, and `github.excludeTools` to remove risky actions from a broader set.

For GitHub Enterprise Server, set:

```yaml
github:
  host: ghe.example.com
```

Use the bare Enterprise hostname in values. The chart passes it to the upstream
server as an HTTPS API host.
