// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';

const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

export async function validateExternalSecrets({k, json, values, release}) {
  if (!values.externalSecrets.enabled) return;
  const resources = json(['get', 'externalsecrets', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json']).items;
  assert.equal(resources.length, values.externalSecrets.items.length, 'Every configured ExternalSecret must exist');
  for (const resource of resources) {
    k(['wait', '--for=condition=Ready', `externalsecret/${resource.metadata.name}`, '--timeout=60s'], undefined, 70000);
    const current = json(['get', 'externalsecret', resource.metadata.name, '-o', 'json']);
    assert.ok(current.status?.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'), 'ExternalSecret must finish synchronization');
    // Presence is enough here; neither secret data nor values are included in assertions.
    k(['get', 'secret', current.spec.target.name, '-o', 'name']);
  }
  console.log('PASS ExternalSecret reconciliation and target Secret existence');
}

export async function validateObservability({k, json, apply, sql, values, name, ns, release}) {
  if (!values.metrics.enabled) return;
  k(['rollout', 'status', `deployment/${name}-metrics`, '--timeout=60s'], undefined, 70000);
  const exporter = json(['get', 'pods', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=metrics`, '-o', 'json']).items.find(item => item.status?.phase === 'Running');
  assert.ok(exporter, 'SQL exporter Pod must be running');
  const metricsUrl = `http://127.0.0.1:${values.metrics.port}/metrics`;
  let metrics = '';
  for (let attempt = 0; attempt < 12; attempt++) {
    try {
      metrics = k(['exec', exporter.metadata.name, '-c', 'exporter', '--', 'wget', '-qO-', '-T', '5', metricsUrl], undefined, 10000);
      if (/^mssql_instance_ready(?:\{[^\n]*\})? 1(?:\.0)?$/m.test(metrics)) break;
    } catch { /* The collector can wait for bootstrap login provisioning. */ }
    await delay(1000);
  }
  assert.match(metrics, /^mssql_instance_ready(?:\{[^\n]*\})? 1(?:\.0)?$/m, 'Exporter must execute an authenticated SQL query');
  assert.match(metrics, /^mssql_user_connections(?:\{[^\n]*\})? [1-9]/m, 'Exporter must collect real SQL sessions');
  assert.match(metrics, /^mssql_database_allocated_bytes\{/m, 'Exporter must collect allocated database bytes');
  assert.match(metrics, /^mssql_io_stall_seconds_total\{/m, 'Exporter must execute its permission-sensitive I/O DMV query');
  assert.equal(sql("SELECT IS_SRVROLEMEMBER('sysadmin')", 'hf_metrics', 'metrics-password'), '0', 'Monitoring login must not be sysadmin');

  const peer = 'mssql-observability-peer';
  let primaryFailure = false;
  try {
    apply({
      apiVersion: 'v1', kind: 'Pod',
      metadata: {name: peer, labels: {'helmforge.dev/runtime-fixture': 'true'}},
      spec: {
        restartPolicy: 'Never', automountServiceAccountToken: false, terminationGracePeriodSeconds: 1,
        securityContext: {runAsNonRoot: true, runAsUser: 65534, runAsGroup: 65534, seccompProfile: {type: 'RuntimeDefault'}},
        containers: [{
          name: 'client', image: `${values.metrics.image.repository}:${values.metrics.image.tag}`,
          command: ['/bin/sh', '-c', 'sleep 180'],
          securityContext: {allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: {drop: ['ALL']}},
          resources: {requests: {cpu: '10m', memory: '32Mi'}, limits: {cpu: '100m', memory: '64Mi'}},
        }],
      },
    });
    k(['wait', '--for=condition=Ready', `pod/${peer}`, '--timeout=30s'], undefined, 35000);
    const serviceUrl = `http://${name}-metrics:${values.metrics.port}/metrics`;
    const peerScrape = () => k(['exec', peer, '--', 'wget', '-qO-', '-T', '3', serviceUrl], undefined, 7000);
    if (values.networkPolicy.enabled) {
      let denied = false;
      try { peerScrape(); } catch { denied = true; }
      assert.ok(denied, 'Unrelated Pod must not access the metrics Service');
    }
    // The namespace-local metrics fixture explicitly admits app=mssql-monitor.
    k(['label', 'pod', peer, 'app=mssql-monitor']);
    let admitted = false;
    for (let attempt = 0; attempt < 8; attempt++) {
      try { admitted = /mssql_instance_ready/.test(peerScrape()); } catch { /* CNI propagation. */ }
      if (admitted) break;
      await delay(500);
    }
    assert.ok(admitted, 'Explicit Prometheus peer must reach the real metrics Service');
  } catch (error) {
    primaryFailure = true;
    throw error;
  } finally {
    try { k(['delete', 'pod', peer, '--ignore-not-found', '--wait=true', '--timeout=15s'], undefined, 20000); }
    catch { if (!primaryFailure) throw new Error('Failed to remove the observability test Pod'); }
  }

  if (values.metrics.serviceMonitor.enabled) {
    k(['rollout', 'status', 'statefulset/prometheus-mssql-monitor', '--timeout=60s'], undefined, 70000);
    const prometheus = json(['get', 'pods', '-l', 'prometheus=mssql-monitor', '-o', 'json']).items.find(item => item.status?.phase === 'Running');
    assert.ok(prometheus, 'Prometheus fixture Pod must be running');
    const api = endpoint => {
      const output = k(['exec', prometheus.metadata.name, '-c', 'prometheus', '--', 'wget', '-qO-', '-T', '5', `http://127.0.0.1:9090${endpoint}`], undefined, 10000);
      const response = JSON.parse(output);
      assert.equal(response.status, 'success', 'Prometheus API request must succeed');
      return response.data;
    };
    const selector = `{namespace=${JSON.stringify(ns)},service=${JSON.stringify(`${name}-metrics`)}}`;
    const query = expression => api(`/api/v1/query?query=${encodeURIComponent(expression)}`).result;
    let scraped = false;
    for (let attempt = 0; attempt < 20; attempt++) {
      try { scraped = query(`mssql_instance_ready${selector}`).some(series => Number(series.value[1]) === 1); }
      catch { /* Operator configuration and first scrape can lag behind readiness. */ }
      if (scraped) break;
      await delay(2000);
    }
    assert.ok(scraped, 'Prometheus must discover ServiceMonitor and ingest authenticated SQL metrics');
    assert.ok(query(`up${selector}`).some(series => Number(series.value[1]) === 1), 'Actual Prometheus scrape must be healthy');
    assert.ok(query(`mssql_user_connections${selector}`).some(series => Number(series.value[1]) > 0), 'Prometheus must ingest real database connections');
    if (values.metrics.prometheusRule.enabled) {
      let rules = [];
      for (let attempt = 0; attempt < 12; attempt++) {
        rules = api('/api/v1/rules').groups.flatMap(group => group.rules);
        if (['MSSQLMetricsUnavailable', 'MSSQLDatabaseNotOnline'].every(ruleName => rules.some(rule => rule.name === ruleName && rule.health === 'ok'))) break;
        await delay(1000);
      }
      for (const ruleName of ['MSSQLMetricsUnavailable', 'MSSQLDatabaseNotOnline']) {
        const rule = rules.find(item => item.name === ruleName);
        assert.ok(rule, `${ruleName} must load into the actual Prometheus engine`);
        assert.equal(rule.health, 'ok', `${ruleName} must evaluate without errors`);
      }
      const unavailable = rules.find(item => item.name === 'MSSQLMetricsUnavailable');
      assert.match(unavailable.query, /absent\(/, 'Availability rule must handle a missing target');
      const missingTargetExpression = unavailable.query.replaceAll(`${name}-metrics`, 'mssql-nonexistent-target');
      assert.ok(query(missingTargetExpression).some(series => Number(series.value[1]) === 1), 'Actual alert expression must identify a missing target');
    }
    console.log('PASS real Prometheus Operator discovery, SQL metric ingestion and healthy alert evaluation');
  }
  console.log('PASS non-admin SQL exporter, private metrics Service and explicit peer isolation');
}
