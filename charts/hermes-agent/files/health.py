# SPDX-License-Identifier: Apache-2.0
"""Readiness is authenticated JSON state, never just an HTTP 200 response."""
import json
import os
import sys
import urllib.request

try:
    request = urllib.request.Request('http://127.0.0.1:8642/health/detailed',
                                     headers={'Authorization': 'Bearer ' + os.environ['API_SERVER_KEY']})
    with urllib.request.urlopen(request, timeout=3) as response:
        healthy = json.load(response).get('readiness', {}).get('status') == 'ok'
    sys.exit(0 if healthy else 1)
except Exception:
    sys.exit(1)
