# Operations

## Upgrade

Review Eclipse Mosquitto release notes before changing `image.tag`. Mosquitto
2.1 uses plugin-based password and ACL files and defaults `max_packet_size` to
2,000,000 bytes. Export current values, back up persistent data, test the new
image in a non-production namespace, and use `helm upgrade --install` with the
reviewed values file.

## Backup and restore

Each broker owns `/mosquitto/data` independently. Use CSI snapshots or your
storage platform's backup mechanism. Quiesce publishers when a crash-consistent
snapshot is insufficient. Restore a volume to the matching StatefulSet ordinal
and validate retained messages and subscriptions before reopening traffic.

## Rollback

Run `helm rollback`, then wait for every broker pod to become Ready. Confirm the
running image, inspect logs for persistence-format errors, and complete an MQTT
publish/subscribe test. Application rollback does not automatically restore a
previous PVC snapshot.

## Federation

Bridge links are generated from StatefulSet ordinals and headless Service DNS.
Inspect each broker's logs separately. A Ready pod proves a listener is open; it
does not prove that every bridge peer is connected. Federated brokers retain
independent sessions and persistent stores.

## Troubleshooting

Check the generated `/mosquitto/config/mosquitto.conf`, referenced Secret and
ConfigMap keys, named Service targets, and NetworkPolicy enforcement. For TLS
errors verify certificate paths, trust chain, hostname, and client certificate
requirements. For MQTTX Web verify both its process port and independent
Service port.
