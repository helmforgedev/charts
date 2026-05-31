# Jenkins JCasC And Plugins

JCasC is opt-in because the Configuration as Code plugin must be available in
the image or installed during plugin bootstrap.

```yaml
jcasC:
  enabled: true
  configScripts:
    welcome.yaml: |
      jenkins:
        systemMessage: "Managed by HelmForge"

plugins:
  install:
    enabled: true
    list:
      - configuration-as-code:2074.va_57f83f7a_10b_
      - workflow-aggregator:608.v67378e9d3db_1
```

For production, pin plugin versions and test plugin upgrades before promoting
them to the controller.
