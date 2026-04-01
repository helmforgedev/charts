# Mosquitto Architecture Notes

This chart focuses on valid deployment models for Eclipse Mosquitto on Kubernetes, without pretending Mosquitto is a native shared-state MQTT cluster.

## Supported Model

- `standalone` mode runs a single broker
- `federated` mode runs a `StatefulSet` with 2+ brokers
- each federated broker keeps its own data volume when persistence is enabled
- clients connect through a regular Service for TCP MQTT or WebSocket
- `sessionAffinity: None` is the default for broad Kubernetes compatibility; sticky routing can be enabled explicitly with `ClientIP`
- a headless Service is created so brokers can discover peers through stable DNS names

## Federated Mode

- the chart builds bridge connections between broker peers using Mosquitto's official bridge configuration model
- each broker connects to the other StatefulSet peers over the headless Service DNS names
- bridge topic replication is controlled through `broker.federation.*`

This is a valid Mosquitto architecture for broker federation, but it is not the same as a native clustered broker with shared internal state.

## What Federated Mode Does Not Provide

- shared session state across replicas
- native clustered retained-message replication
- transparent failover of long-lived client sessions without reconnect behavior

## Operational Guidance

- use `standalone` when you want the simplest and most predictable broker behavior
- use `federated` when you explicitly want bridged brokers and understand the state boundaries
- keep `service.sessionAffinity=None` unless you explicitly need sticky routing for stable source IPs
- expose the WebSocket listener when using `mqttxWeb` or browser clients
- document client expectations clearly if you rely on persistent sessions or retained state

## MQTTX Web Companion

The chart can optionally deploy MQTTX Web as a companion browser client.

- the chart computes and documents a default broker WebSocket URL
- upstream version alignment for MQTTX Web must be checked against both Docker Hub and GitHub releases before pinning a strict image tag
- if you want browser access, enable `websocketIngress` and expose a reachable host/path

## Scheduling Defaults

When `architecture.mode=federated` and `broker.replicaCount > 1`, the chart can apply opinionated scheduling defaults to improve operational availability on Kubernetes:

- preferred or required pod anti-affinity
- topology spread constraints by node hostname

These defaults are controlled by `broker.multiReplicaDefaults.*` and are skipped automatically when operators provide explicit `affinity` or `topologySpreadConstraints`.

<!-- @AI-METADATA
type: chart-docs
title: Mosquitto - Architecture Notes
description: Architecture and high-availability notes for the Mosquitto Helm chart

keywords: mosquitto, mqtt, architecture, ha, websocket, mqttx

purpose: Explain the supported Mosquitto deployment model and HA limits on Kubernetes
scope: Chart

relations:
  - charts/mosquitto/README.md
path: charts/mosquitto/docs/architecture.md
version: 1.0
date: 2026-04-01
-->
