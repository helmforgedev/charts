#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
umask 077
if [ "${HELMFORGE_METRICS_TOKEN+x}" = x ]; then
  test "$(printf %s "$HELMFORGE_METRICS_TOKEN" | wc -c)" -ge 16 || { echo "Metrics token must contain at least 16 bytes" >&2; exit 1; }
  unset HELMFORGE_METRICS_TOKEN
fi
cat /etc/ssl/cert.pem > /runtime-trust/ca.crt
if [ -s /tls/ca.crt ]; then cat /tls/ca.crt >> /runtime-trust/ca.crt; fi
if [ -s /trusted-ca/ca.crt ]; then cat /trusted-ca/ca.crt >> /runtime-trust/ca.crt; fi
mkdir -p /workspace/config /workspace/data
probe=$(mktemp /workspace/data/.helmforge-xattr.XXXXXX)
trap 'rm -f "$probe"' EXIT HUP INT TERM
setfattr -n user.helmforge_probe -v persistent-native-xattr "$probe"
test "$(getfattr --only-values -n user.helmforge_probe "$probe" 2>/dev/null)" = persistent-native-xattr
rm -f "$probe"
trap - EXIT HUP INT TERM
if [ -s /workspace/config/opencloud.yaml ]; then
  echo 'Existing native identity configuration preserved'
  exit 0
fi
if [ -n "$(find /workspace/data -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  echo 'Data exists without native identity configuration; restore the matching config before startup' >&2
  exit 1
fi
IDM_ADMIN_PASSWORD=$(cat /bootstrap-auth/password)
export IDM_ADMIN_PASSWORD
test "$(printf %s "$IDM_ADMIN_PASSWORD" | wc -c)" -ge 16
/usr/bin/opencloud init --insecure=false --config-path=/workspace/config --quiet
test -s /workspace/config/opencloud.yaml
echo 'Native identity initialized with operator Secret; xattr storage verified'
