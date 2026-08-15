# Community Branch Plugin

The chart can install the community branch plugin during pod initialization.

```yaml
communityBranchPlugin:
  enabled: true
  version: "26.4.0"
```

When enabled, the chart:

- downloads the plugin JAR to `/opt/sonarqube/extensions/plugins`
- downloads and unpacks `sonarqube-webapp.zip`
- mounts the patched web application at `/opt/sonarqube/web`
- writes the required web and compute engine Java agent properties

The default URLs are derived from the configured plugin version. Override them when mirroring artifacts internally:

```yaml
communityBranchPlugin:
  enabled: true
  version: "26.4.0"
  jarUrl: https://artifacts.example.com/sonarqube-community-branch-plugin-26.4.0.jar
  webappUrl: https://artifacts.example.com/sonarqube-webapp.zip
```

The chart validates plugin `26.4.0` with its default SonarQube image. When
changing either version, consult the plugin compatibility notes and rerun the
`ci/plugins.yaml` scenario before deployment.

## Additional Plugins

Use `plugins.install` for extra plugin JARs:

```yaml
plugins:
  enabled: true
  install:
    - name: sonar-auth-oidc
      url: https://example.com/sonar-auth-oidc.jar
```

Use an internal artifact repository for production so startup does not depend on public internet availability.
