// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';

export async function verifyMetrics({k,forward,values,namespace}){
 await forward(async base=>{
  const response=await fetch(base+'/metrics',{signal:AbortSignal.timeout(10000)});assert.equal(response.status,200);
  const body=await response.text();assert.match(body,/^# HELP /m);assert.match(body,/^# TYPE /m);
  const families=[...body.matchAll(/^# TYPE ([a-zA-Z_:][a-zA-Z0-9_:]*) (counter|gauge|histogram|summary)$/gm)].map(match=>match[1]);
  assert.ok(families.includes('go_sql_connections_open'),'Native SQL connection gauge must exist');
  assert.ok(families.includes('http_server_request_duration_seconds'),'Native HTTP request histogram must exist');
  console.log('PASS native Prometheus exposition; families: '+families.slice(0,18).join(', '));
 },values.metrics.port);
 if(!values.metrics.serviceMonitor.enabled&&!values.metrics.prometheusRule.enabled)return;
 const services=JSON.parse(k(['get','service','-o','json'])).items;
 const metricsService=services.find(service=>service.spec.ports.some(port=>port.name==='metrics'));
 assert.ok(metricsService,'A Service with the named metrics port must exist');
 if(values.metrics.prometheusRule.enabled){const rule=JSON.parse(k(['get','prometheusrule','pocket-id-metrics','-o','json']));const alert=rule.spec.groups.flatMap(group=>group.rules).find(item=>item.alert==='PocketIDMetricsUnavailable');assert.ok(alert);assert.equal(alert.expr,'up{namespace="'+namespace+'",service="'+metricsService.metadata.name+'"} == 0');}
 if(!values.metrics.serviceMonitor.enabled)return;
 const serviceMonitor=JSON.parse(k(['get','servicemonitor','pocket-id-metrics','-o','json']));
 for(const [label,value] of Object.entries(serviceMonitor.spec.selector.matchLabels)){assert.equal(metricsService.metadata.labels[label],value,'ServiceMonitor selector must match the metrics Service');}
 assert.equal(serviceMonitor.spec.endpoints[0].port,'metrics');
 assert.equal(serviceMonitor.spec.endpoints[0].path,'/metrics');
 k(['rollout','status','statefulset/prometheus-pocket-id-monitor','--timeout=90s']);
 await forward(async base=>{
  const deadline=Date.now()+45000;let result=[];
  while(Date.now()<deadline){const response=await fetch(base+'/api/v1/query?query='+encodeURIComponent('up{namespace="'+namespace+'",endpoint="metrics"}'),{signal:AbortSignal.timeout(10000)});assert.equal(response.status,200);const data=await response.json();result=data.data?.result??[];if(result.length&&result.every(row=>row.value[1]==='1'))break;await new Promise(resolve=>setTimeout(resolve,1500));}
  assert.ok(result.length);assert.ok(result.every(row=>row.value[1]==='1'),'Real Prometheus must scrape the native metrics ServiceMonitor');
  if(values.metrics.prometheusRule.enabled){const response=await fetch(base+'/api/v1/rules');assert.equal(response.status,200);const data=await response.json();assert.ok(data.data.groups.some(group=>group.rules.some(rule=>rule.name==='PocketIDMetricsUnavailable')));}
  console.log('PASS rendered ServiceMonitor/PrometheusRule contract and real Prometheus scrape up=1');
 },9090,'service/pocket-id-monitor');
}
