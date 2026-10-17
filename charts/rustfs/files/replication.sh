#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
umask 077
config=${CONFIG_FILE:-/configuration/config.json}
credentials=${CREDENTIALS_DIR:-/credentials}
export RC_CONFIG_DIR=${RC_CONFIG_DIR:-/tmp/rc}
mkdir -p "$RC_CONFIG_DIR"
local_endpoint=$(jq -er '.localEndpoint' "$config")
rc alias set local "$local_endpoint" "$(cat "$credentials/local/access-key")" "$(cat "$credentials/local/secret-key")" --region us-east-1 --bucket-lookup path >/dev/null
# The Kubernetes Job deadline bounds retries, including unreachable peers.
until rc ready local >/dev/null 2>&1; do sleep 5; done
for peer in $(jq -r '.peers[].name' "$config"); do
  endpoint=$(jq -er --arg name "$peer" '.peers[] | select(.name == $name) | .endpoint' "$config")
  rc alias set "$peer" "$endpoint" "$(cat "$credentials/$peer/access-key")" "$(cat "$credentials/$peer/secret-key")" --region us-east-1 --bucket-lookup path >/dev/null
  until rc ready "$peer" >/dev/null 2>&1; do sleep 5; done
done
if [ "$(jq -r '.mode' "$config")" = site ]; then
  rc --json admin replicate info local > /tmp/site-info.json
  # Fail closed if the CLI output does not match the pinned release's schema.
  jq -e '.data.operations[0].result | (.enabled | type == "boolean") and (.sites | type == "array")' /tmp/site-info.json >/dev/null
  if jq -e '.data.operations[0].result.enabled' /tmp/site-info.json >/dev/null; then
    expected=$(jq -c '[.peers[].endpoint | rtrimstr("/")] | unique | sort' "$config")
    actual=$(jq -c --arg local "${local_endpoint%/}" '[.data.operations[0].result.sites[].endpoint | rtrimstr("/") | select(. != $local)] | unique | sort' /tmp/site-info.json)
    if [ "$expected" != "$actual" ]; then
      echo 'Existing site membership differs; migrate it manually before rerunning setup.' >&2
      exit 1
    fi
    echo 'Site relationship already configured; checking status.'
  else
    set -- local
    for peer in $(jq -r '.peers[].name' "$config"); do set -- "$@" "$peer"; done
    rc admin replicate add "$@"
  fi
  rc admin replicate status local
else
  count=$(jq '.buckets | length' "$config")
  i=0
  while [ "$i" -lt "$count" ]; do
    jq --argjson index "$i" '.buckets[$index]' "$config" > /tmp/rule.json
    id=$(jq -er '.id' /tmp/rule.json)
    source="local/$(jq -er '.sourceBucket' /tmp/rule.json)"
    destination="$(jq -er '.destinationPeer' /tmp/rule.json)/$(jq -er '.destinationBucket' /tmp/rule.json)"
    if jq -e '.createBuckets == true' /tmp/rule.json >/dev/null; then
      rc mb "$source" --ignore-existing
      rc mb "$destination" --ignore-existing
    fi
    rc version enable "$source"
    rc version enable "$destination"
    rc --json replicate list "$source" > /tmp/rules.json
    jq -e '.rules | type == "array"' /tmp/rules.json >/dev/null
    set -- "$source" --id "$id" --priority "$(jq -r '.priority' /tmp/rule.json)" --prefix "$(jq -r '.prefix // ""' /tmp/rule.json)" --replicate "$(jq -r '.replicate // "delete,delete-marker,existing-objects"' /tmp/rule.json)"
    if jq -e --arg id "$id" '.rules | any(.id == $id)' /tmp/rules.json >/dev/null; then
      # Inspect the target without exposing exported credentials in logs.
      rc replicate export "$source" > /tmp/export.json
      peer=$(jq -r '.destinationPeer' /tmp/rule.json)
      endpoint=$(jq -r --arg name "$peer" '.peers[] | select(.name == $name) | .endpoint | rtrimstr("/")' "$config")
      bucket=$(jq -r '.destinationBucket' /tmp/rule.json)
      if ! jq -e --arg id "$id" --arg endpoint "$endpoint" --arg bucket "$bucket" '
        (.rules[] | select(.id == $id) | .destination.bucketArn) as $arn |
        any(.remoteTargets[]; .arn == $arn and .targetbucket == $bucket and
          (((if .secure then "https://" else "http://" end) + .endpoint) == $endpoint))
      ' /tmp/export.json >/dev/null; then
        echo 'Existing rule destination differs; migrate it manually before rerunning setup.' >&2
        exit 1
      fi
      # Updating by ID preserves other rules. Destination migrations are an operator action.
      rc replicate update "$@"
    else
      rc replicate add "$@" --remote-bucket "$destination"
    fi
    i=$((i + 1))
  done
fi
