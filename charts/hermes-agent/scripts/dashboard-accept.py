# SPDX-License-Identifier: Apache-2.0
import http.cookiejar
import json
import os
import urllib.error
import urllib.request

url = 'http://127.0.0.1:9119'
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
with opener.open(url + '/api/status') as response:
    status = json.load(response)
    assert status['auth_required'] is True, 'Dashboard authentication is not required'
    assert status['gateway_running'] is True, 'Dashboard cannot see the gateway process'
for path in ('/api/config', '/api/auth/me'):
    try:
        opener.open(url + path)
        raise AssertionError('Unauthenticated dashboard access was accepted')
    except urllib.error.HTTPError as error:
        assert error.code in (401, 403), error.code
for correct in (False, True):
    payload = {'provider': 'basic', 'username': os.environ['HERMES_DASHBOARD_BASIC_AUTH_USERNAME'], 'password': os.environ['HERMES_DASHBOARD_BASIC_AUTH_PASSWORD'] if correct else 'incorrect'}
    request = urllib.request.Request(url + '/auth/password-login', data=json.dumps(payload).encode(), headers={'Content-Type': 'application/json'})
    try:
        with opener.open(request) as response:
            assert correct and json.load(response)['ok'] is True
    except urllib.error.HTTPError as error:
        assert not correct and error.code == 401, error.code
with opener.open(url + '/api/auth/me') as response:
    assert response.status == 200
print('PASS dashboard denies unauthenticated access, rejects bad password and accepts signed login session')
with opener.open(url + '/api/status') as response:
    result = json.load(response)
    print('Dashboard status fields:', ', '.join(sorted(result)))
