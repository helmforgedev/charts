# SPDX-License-Identifier: Apache-2.0
"""Exercise only an owned fixture watch in an isolated validation namespace."""
import http.server
import json
import os
import pathlib
import sys
import threading
import time
import urllib.error
import urllib.request

action, browser, version = sys.argv[1:]
browser = browser == "true"
settings_path = pathlib.Path('/datastore/changedetection.json')
settings = json.loads(settings_path.read_text())
token = settings['settings']['application']['api_access_token']
base = 'http://127.0.0.1:' + os.getenv('PORT', '5000')

def api(route, data=None, method=None, auth=True):
    headers = {'Content-Type': 'application/json'}
    if auth:
        headers['x-api-key'] = token
    req = urllib.request.Request(base + '/api/v1' + route, data=json.dumps(data).encode() if data is not None else None, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=45) as response:
        body = response.read().decode()
        return json.loads(body) if body and 'json' in response.headers.get('Content-Type', '') else body

try:
    api('/watch', auth=False)
    raise AssertionError('Anonymous API access unexpectedly accepted')
except urllib.error.HTTPError as error:
    assert error.code == 403, error.code

marker = pathlib.Path('/datastore/helmforge-runtime-fixture.json')
state = json.loads(marker.read_text()) if action == 'verify' else {}
generation = str(time.time_ns())
expected = 'HelmForge-rendered-' + generation

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = ('<html><body><p>fixture</p><script>document.body.innerText=' + json.dumps(expected) + ';</script></body></html>').encode()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

server = http.server.ThreadingHTTPServer(('0.0.0.0', 18080), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    if action == 'verify':
        uuid = state['uuid']
        old = api('/watch/' + uuid + '/history')
        assert state['history'] in old, 'Persisted snapshot missing'
        assert api('/watch/' + uuid)['title'] == 'HelmForge persistencia Unicode'
    else:
        if action == 'smoke':
            assert not api('/watch'), 'Default sample watches should be disabled'
        url = 'http://127.0.0.1:18080/caf\u00e9' if browser else 'https://helmforge.dev/'
        uuid = api('/watch', {'url': url, 'title': 'HelmForge persistencia Unicode', 'fetch_backend': 'html_webdriver' if browser else 'html_requests', 'time_between_check': {'minutes': 60}})['uuid']
    api('/watch/' + uuid + '?recheck=1')
    deadline = time.monotonic() + 150
    while time.monotonic() < deadline:
        history = api('/watch/' + uuid + '/history')
        if history:
            snapshot = api('/watch/' + uuid + '/history/latest')
            if (expected in snapshot if browser else 'HelmForge' in snapshot):
                break
        time.sleep(3)
    else:
        watch = api('/watch/' + uuid)
        raise AssertionError('No expected fetched snapshot: ' + str(watch.get('last_error')))
    if not browser and version == '0.60.3':
        from changedetectionio.validate_url import validate_fetch_url
        try:
            validate_fetch_url('http://127.0.0.1:18080/')
            raise AssertionError('Restricted URL accepted by default')
        except ValueError as error:
            assert 'private/reserved IP address' in str(error), str(error)
    if action != 'smoke':
        marker.write_text(json.dumps({'uuid': uuid, 'history': list(history)[0]}))
    if browser and version == '0.60.3':
        import io
        import re
        import requests
        import zipfile
        session = requests.Session()
        page = session.get(base + '/backups/create', timeout=30)
        page.raise_for_status()
        csrf = re.search(r'name="csrf_token"[^>]*value="([^"]+)"', page.text)
        assert csrf, 'Backup CSRF token missing'
        response = session.post(base + '/backups/request-backup', data={'csrf_token': csrf[1]}, timeout=30)
        response.raise_for_status()
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            response = session.get(base + '/backups/download/latest', timeout=30)
            if response.status_code == 200:
                with zipfile.ZipFile(io.BytesIO(response.content)) as archive:
                    urls = archive.read('url-list.txt').decode('utf-8')
                    assert 'caf' in urls and ('\u00e9' in urls or '%C3%A9' in urls), urls
                    assert 'changedetection.json' in archive.namelist()
                break
            time.sleep(2)
        else:
            raise AssertionError('Backup ZIP was not created')
        print('PASS: application backup ZIP contains UTF-8 URL list and settings; restore is not claimed.')
    if action == 'smoke':
        api('/watch/' + uuid, method='DELETE')
    print('PASS: changedetection ' + version + ', authenticated API, anonymous denial, ' + ('JavaScript rendering' if browser else 'HTTP fetch and restricted-address policy') + ', snapshot history' + (' retained after upgrade/replacement' if action == 'verify' else '') + '.')
finally:
    server.shutdown()
