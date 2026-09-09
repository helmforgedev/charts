# SPDX-License-Identifier: Apache-2.0
"""Exercise the local Langflow API without a model provider or external credentials."""
import base64
import gzip
import hashlib
import importlib.metadata
import json
import os
import signal
import sqlite3
import sys
import urllib.error
import urllib.parse
import urllib.request
from http.cookiejar import CookieJar

from cryptography.fernet import Fernet

signal.alarm(140)
expected, action, *saved = sys.argv[1:]
assert importlib.metadata.version("langflow") == expected
base = "http://127.0.0.1:" + os.environ.get("LANGFLOW_PORT", "7860")
client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(CookieJar()))


def request(route, body=None, form=False):
    headers = {"Connection": "close"}
    data = None
    if body is not None:
        data = (urllib.parse.urlencode(body) if form else json.dumps(body)).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded" if form else "application/json"
    with client.open(urllib.request.Request(base + route, data=data, headers=headers), timeout=35) as response:
        payload = response.read()
        if response.headers.get("Content-Encoding") == "gzip":
            payload = gzip.decompress(payload)
        return json.loads(payload)


request("/health_check")
if os.environ.get("LANGFLOW_AUTO_LOGIN", "true").lower() == "false":
    try:
        request("/api/v1/flows/")
    except urllib.error.HTTPError as error:
        assert error.code in (401, 403), error.code
    else:
        raise AssertionError("Anonymous flow access must be rejected")
request("/api/v1/login", {
    "username": os.environ["LANGFLOW_SUPERUSER"],
    "password": os.environ["LANGFLOW_SUPERUSER_PASSWORD"],
}, form=True)

secret = os.environ["LANGFLOW_SECRET_KEY"]
key = base64.urlsafe_b64encode(hashlib.sha256(secret.encode()).digest()) if len(secret) < 32 else (secret + "=" * (-len(secret) % 4)).encode()
fernet = Fernet(key)
fixture = "HelmForge retained credential 42"
variable_name = "HELMFORGE_RUNTIME_SECRET"

if action == "create":
    palette = request("/api/v1/all")
    components = {name: value for group in palette.values() if isinstance(group, dict) for name, value in group.items()}
    nodes = []
    for kind in ("ChatInput", "ChatOutput"):
        component = components[kind]
        component["template"]["should_store_message"]["value"] = False
        node_id = kind + "-fixture"
        nodes.append({"id": node_id, "data": {"id": node_id, "type": kind, "node": component}})
    edge = {"source": "ChatInput-fixture", "target": "ChatOutput-fixture", "data": {
        "sourceHandle": {"dataType": "ChatInput", "id": "ChatInput-fixture", "name": "message", "output_types": ["Message"]},
        "targetHandle": {"fieldName": "input_value", "id": "ChatOutput-fixture", "inputTypes": ["Data", "DataFrame", "Message"], "type": "other"},
    }}
    flow = request("/api/v1/flows/", {"name": "HelmForge retained echo", "data": {"nodes": nodes, "edges": [edge]}, "is_component": False})
    flow_id = flow["id"]
    request("/api/v1/variables/", {"name": variable_name, "value": fixture, "type": "Credential", "default_fields": []})
else:
    flow_id = saved[0]
    assert request("/api/v1/flows/" + flow_id)["name"] == "HelmForge retained echo"

result = request("/api/v1/run/session/" + flow_id, {"input_value": "HelmForge echo 42", "input_type": "chat", "output_type": "chat"})
assert result["outputs"][0]["outputs"][0]["results"]["message"]["text"] == "HelmForge echo 42", "Echo output must match the supplied message"

url = os.environ.get("LANGFLOW_DATABASE_URL", "")
if url.startswith("postgres"):
    import psycopg
    with psycopg.connect(url.replace("postgresql+psycopg://", "postgresql://")) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT value FROM variable WHERE name = %s", (variable_name,))
            cipher = cursor.fetchone()[0]
else:
    db_path = os.path.join(os.environ["LANGFLOW_CONFIG_DIR"], "langflow.db")
    with sqlite3.connect(db_path) as connection:
        cipher = connection.execute("SELECT value FROM variable WHERE name = ?", (variable_name,)).fetchone()[0]
assert cipher != fixture
assert fernet.decrypt(cipher.encode()).decode() == fixture, "Persisted credential must decrypt with the retained key"
print(json.dumps({"status": "PASS", "version": expected, "flowId": flow_id, "proof": "health, authentication, stored echo flow execution and persisted credential decryption"}))
