# Single Broker

Use `architecture=single-broker` for development, CI, demos, and low-risk internal workloads where broker-node redundancy is not required.

## What this mode does

- runs one combined KRaft node with both `broker` and `controller` roles
- stores metadata and log data on one PVC when persistence is enabled
- exposes one internal bootstrap service for in-cluster clients

## What this mode does not do

- survive node loss
- keep replication factors above `1`
- represent the production topology recommended by this chart

## Recommended usage

- local development
- application CI flows that need a real Kafka broker
- temporary environments

## Operational note

Combined KRaft mode is practical for simple environments, but the production path in this chart is the dedicated `cluster` topology.

<!-- @AI-METADATA
type: chart-docs
title: Kafka - Single Broker
description: When to use the single-broker Kafka topology and what its limits are

keywords: kafka, kraft, single-broker, development

purpose: Explain the supported single-broker Kafka topology and its limits
scope: Chart Architecture

relations:
  - charts/kafka/README.md
  - charts/kafka/docs/cluster.md
path: charts/kafka/docs/single-broker.md
version: 1.0
date: 2026-03-31
-->
