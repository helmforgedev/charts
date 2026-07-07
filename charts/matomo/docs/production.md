# Production Guide

Matomo has two production-critical runtime domains: MySQL or MariaDB for
analytics data, and the Matomo application volume for configuration, plugins,
and generated assets. Back up both before upgrades.

## Database

For production, prefer `database.mode=external` with a managed MySQL or MariaDB
service. The bundled MySQL subchart is useful for development and controlled
single-cluster installations.

## Archiving

Enable the chart-managed `archiver` CronJob so reports are precomputed outside
interactive user traffic. Start with the upstream hourly schedule at minute 5
and tune resources when archive runs overlap.

## Scaling

The chart allows multiple web replicas, but Matomo installations must ensure
safe shared storage and session handling first. Keep `replicaCount=1` until
those concerns are handled explicitly.

## Reverse Proxy

When Matomo runs behind Ingress or Gateway API, configure trusted proxy headers
inside Matomo after installation so HTTPS and client IP detection are correct.

<!-- @AI-METADATA
type: chart-docs
title: Matomo Production Guide
description: Production operating notes for the Matomo chart
keywords: matomo, production, archiver, mysql
purpose: Explain production concerns for Matomo on Kubernetes
scope: Chart
relations:
  - charts/matomo/values.yaml
path: charts/matomo/docs/production.md
version: 1.0
date: 2026-07-06
-->
