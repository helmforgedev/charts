// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";

export async function verifyMetrics({ k, forward, values, namespace, context, deployment }) {
  if (deployment.metadata.name === "twenty-metrics") {
    const name = "twenty-metrics-denied",
      target = deployment.metadata.name;
    const code = `async function control(){const deadline=Date.now()+20000;while(Date.now()<deadline){try{const r=await fetch('http://${target}:${values.service.port}/healthz',{signal:AbortSignal.timeout(4000)});if(r.ok)return;}catch{}await new Promise(r=>setTimeout(r,500));}throw Error('Positive HTTP network control failed');}await control();for(let n=0;n<3;n++){let reachable=false;try{await fetch('http://${target}-metrics:${values.metrics.port}/metrics',{signal:AbortSignal.timeout(4000)});reachable=true;}catch{}if(reachable)throw Error('Unauthorized peer reached native metrics');}await control();console.log('HTTP positive control passed; metrics connection denied');`;
    const probe = {
      apiVersion: "v1",
      kind: "Pod",
      metadata: { name, labels: { "helmforge.dev/runtime-fixture": "true" } },
      spec: {
        restartPolicy: "Never",
        automountServiceAccountToken: false,
        securityContext: values.podSecurityContext,
        containers: [
          {
            name: "probe",
            image: values.image.repository + ":" + values.image.tag,
            command: ["node", "--input-type=module", "-e", code],
            securityContext: values.securityContext,
            resources: {
              requests: { cpu: "50m", memory: "64Mi" },
              limits: { cpu: "500m", memory: "128Mi" },
            },
          },
        ],
      },
    };
    execFileSync("kubectl", ["--context", context, "-n", namespace, "apply", "-f", "-"], {
      input: JSON.stringify(probe),
      encoding: "utf8",
    });
    try {
      const deadline = Date.now() + 60000;
      let phase;
      while (Date.now() < deadline) {
        phase = JSON.parse(k(["get", "pod", name, "-o", "json"])).status.phase;
        if (["Succeeded", "Failed"].includes(phase)) break;
        await new Promise((r) => setTimeout(r, 500));
      }
      const logs = k(["logs", name]);
      assert.equal(phase, "Succeeded", logs);
      assert.match(logs, /HTTP positive control passed; metrics connection denied/);
      console.log("PASS unrelated Pod denied native metrics with a working application-network control");
    } finally {
      k(["delete", "pod/" + name, "--wait=true", "--timeout=30s"]);
    }
  }
  await forward(async (base) => {
    const response = await fetch(base + "/metrics", {
      signal: AbortSignal.timeout(10000),
    });
    assert.equal(response.status, 200);
    const body = await response.text();
    assert.match(body, /^# HELP /m);
    assert.match(body, /^# TYPE /m);
    const families = [...body.matchAll(/^# TYPE ([a-zA-Z_:][a-zA-Z0-9_:]*) (counter|gauge|histogram|summary)$/gm)].map(
      (match) => match[1],
    );
    assert.ok(
      families.includes("graphql_operation_200_total"),
      "Native GraphQL operation counter missing: " + families.join(", "),
    );
    assert.ok(
      body
        .split("\n")
        .some((line) => line.startsWith("graphql_operation_200_total") && Number(line.trim().split(/\s+/).at(-1)) > 0),
      "Native successful GraphQL operation counter must reflect CRM traffic",
    );
    console.log("PASS native Prometheus exposition; families: " + families.slice(0, 18).join(", "));
  }, values.metrics.port);
  if (!values.metrics.serviceMonitor.enabled) return;
  k(["rollout", "status", "statefulset/prometheus-twenty-monitor", "--timeout=90s"]);
  await forward(
    async (base) => {
      const deadline = Date.now() + 45000;
      let result = [];
      while (Date.now() < deadline) {
        const response = await fetch(
          base + "/api/v1/query?query=" + encodeURIComponent('up{namespace="' + namespace + '",endpoint="metrics"}'),
          { signal: AbortSignal.timeout(10000) },
        );
        assert.equal(response.status, 200);
        const data = await response.json();
        result = data.data?.result ?? [];
        if (result.length && result.every((row) => row.value[1] === "1")) break;
        await new Promise((resolve) => setTimeout(resolve, 1500));
      }
      assert.ok(result.length);
      assert.ok(
        result.every((row) => row.value[1] === "1"),
        "Real Prometheus must scrape the native metrics ServiceMonitor",
      );
      if (values.metrics.prometheusRule.enabled) {
        const response = await fetch(base + "/api/v1/rules");
        assert.equal(response.status, 200);
        const data = await response.json();
        assert.ok(
          data.data.groups.some((group) => group.rules.some((rule) => rule.name === "TwentyMetricsUnavailable")),
        );
      }
      console.log("PASS real Prometheus ServiceMonitor scrape up=1 and loaded native target availability rule");
    },
    9090,
    "service/twenty-monitor",
  );
}
