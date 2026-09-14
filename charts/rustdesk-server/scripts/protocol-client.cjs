// SPDX-License-Identifier: Apache-2.0
// Minimal independent client for the pinned upstream rendezvous protobuf protocol.
const assert = require('node:assert/strict');
const net = require('node:net');
const dgram = require('node:dgram');
const crypto = require('node:crypto');
const [host, rendezvousText, relayText, serverKey, mode = 'initial'] = process.argv.slice(2);
const rendezvous = Number(rendezvousText);
const relay = Number(relayText);
const id = '900000001';
const uuid = Buffer.alloc(16, 29);
const peerKey = Buffer.alloc(32, 17);
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
function varint(value) {
  const out = [];
  do { const b = value & 127; value = Math.floor(value / 128); out.push(b | (value ? 128 : 0)); } while (value);
  return Buffer.from(out);
}
function field(number, value) {
  if (typeof value === 'number') return Buffer.concat([varint(number * 8), varint(value)]);
  const bytes = Buffer.isBuffer(value) ? value : Buffer.from(value);
  return Buffer.concat([varint(number * 8 + 2), varint(bytes.length), bytes]);
}
const message = (number, fields = []) => field(number, Buffer.concat(fields));
function decode(bytes) {
  let offset = 0;
  const fields = new Map();
  const integer = () => {
    let value = 0, shift = 0, b;
    do { assert(offset < bytes.length); b = bytes[offset++]; value += (b & 127) * 2 ** shift; shift += 7; } while (b & 128);
    return value;
  };
  while (offset < bytes.length) {
    const tag = integer();
    const wire = tag & 7;
    if (wire === 0) fields.set(tag >> 3, integer());
    else if (wire === 2) { const length = integer(); fields.set(tag >> 3, bytes.subarray(offset, offset + length)); offset += length; }
    else throw new Error(`Unsupported protobuf wire ${wire}`);
  }
  return fields;
}
function framed(bytes) {
  const width = bytes.length <= 63 ? 1 : bytes.length <= 16383 ? 2 : bytes.length <= 4194303 ? 3 : 4;
  const header = Buffer.alloc(width);
  header.writeUIntLE(bytes.length * 4 + width - 1, 0, width);
  return Buffer.concat([header, bytes]);
}
async function connect(port) {
  const socket = net.createConnection({ host, port });
  await new Promise((resolve, reject) => {
    socket.setTimeout(8000, () => socket.destroy(new Error('TCP connection timeout')));
    socket.once('connect', () => { socket.setTimeout(0); resolve(); });
    socket.once('error', reject);
  });
  return socket;
}
function receive(socket, size) {
  return new Promise((resolve, reject) => {
    let bytes = Buffer.alloc(0);
    const timer = setTimeout(() => done(new Error('TCP response timeout')), 8000);
    const error = e => done(e);
    const close = () => done(new Error('Unexpected TCP EOF'));
    const data = chunk => {
      bytes = Buffer.concat([bytes, chunk]);
      if (size !== undefined) { if (bytes.length >= size) done(null, bytes); }
      else if (bytes.length) {
        const width = (bytes[0] & 3) + 1;
        if (bytes.length >= width) {
          const length = bytes.readUIntLE(0, width) >> 2;
          if (bytes.length >= width + length) done(null, bytes.subarray(width, width + length));
        }
      }
    };
    function done(err, value) {
      clearTimeout(timer);
      socket.off('data', data); socket.off('error', error); socket.off('close', close);
      if (err) reject(err); else resolve(value);
    }
    socket.on('data', data); socket.once('error', error); socket.once('close', close);
  });
}
async function exchange(port, request) {
  const socket = await connect(port);
  try { const response = receive(socket); socket.write(framed(request)); return { fields: decode(await response), localPort: socket.localPort }; }
  finally { socket.destroy(); }
}
async function websocketCheck() {
  const open = async port => {
    const ws = new WebSocket(`ws://${net.isIP(host) === 6 ? `[${host}]` : host}:${port}`);
    ws.binaryType = 'arraybuffer';
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => { ws.close(); reject(new Error('WebSocket upgrade timeout')); }, 8000);
      ws.onopen = () => { clearTimeout(timer); resolve(); };
      ws.onerror = () => { clearTimeout(timer); reject(new Error('WebSocket upgrade failed')); };
    });
    return ws;
  };
  const next = ws => new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('WebSocket response timeout')), 8000);
    ws.onmessage = event => { clearTimeout(timer); resolve(Buffer.from(event.data)); };
  });
  const idSocket = await open(rendezvous + 2);
  try {
    const answer = next(idSocket);
    idSocket.send(message(8, [field(1, id), field(3, 'incorrect-server-key')]));
    assert.equal(decode(decode(await answer).get(11)).get(3), 3, 'WebSocket rendezvous enforces the server key');
  } finally { idSocket.close(); }
  const a = await open(relay + 2), b = await open(relay + 2);
  try {
    const request = message(18, [field(2, crypto.randomUUID()), field(6, serverKey)]);
    a.send(request); b.send(request);
    await delay(150);
    const receivedA = next(a), receivedB = next(b);
    const payloadA = crypto.randomBytes(4096), payloadB = crypto.randomBytes(4096);
    a.send(payloadA); b.send(payloadB);
    assert.deepEqual(await receivedA, payloadB);
    assert.deepEqual(await receivedB, payloadA);
    console.log('PASS WebSocket: rendezvous key enforcement and bidirectional relay payload');
  } finally { a.close(); b.close(); }
}
async function main() {
  const udp = dgram.createSocket(net.isIP(host) === 6 ? 'udp6' : 'udp4');
  await new Promise(resolve => udp.bind(0, resolve));
  const udpRequest = bytes => new Promise((resolve, reject) => {
    const timer = setTimeout(() => { udp.off('message', onMessage); reject(new Error('UDP response timeout')); }, 8000);
    const onMessage = data => { clearTimeout(timer); resolve(decode(data)); };
    udp.once('message', onMessage);
    udp.send(bytes, rendezvous, host, error => { if (error) { clearTimeout(timer); udp.off('message', onMessage); reject(error); } });
  });
  try {
    if (mode === 'retained') {
      const collision = await udpRequest(message(15, [field(1, id), field(2, Buffer.alloc(16, 99)), field(3, peerKey)]));
      assert.equal(decode(collision.get(16)).get(1), 2, 'SQLite must retain the original UUID association');
    }
    const registration = await udpRequest(message(15, [field(1, id), field(2, uuid), field(3, peerKey)]));
    assert.equal(decode(registration.get(16)).get(1) ?? 0, 0, 'native public-key registration succeeds');
    const heartbeat = await udpRequest(message(6, [field(1, id)]));
    assert.equal(decode(heartbeat.get(7)).get(2) ?? 0, 0, 'known peer heartbeat does not request its key again');
    for (const port of [rendezvous - 1, rendezvous]) {
      const nat = await exchange(port, message(20));
      assert.equal(decode(nat.fields.get(21)).get(1), nat.localPort, 'NAT response observes the client source port');
    }
    const badPunch = await exchange(rendezvous, message(8, [field(1, id), field(3, 'incorrect-server-key')]));
    assert.equal(decode(badPunch.fields.get(11)).get(3), 3, 'rendezvous rejects an incorrect server key');
    const denied = await connect(relay);
    try {
      const closed = new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('Relay accepted an incorrect key')), 8000);
        denied.once('close', () => { clearTimeout(timer); resolve(); });
      });
      denied.write(framed(message(18, [field(2, crypto.randomUUID()), field(6, 'incorrect-server-key')])));
      await closed;
    } finally { denied.destroy(); }
    const first = await connect(relay);
    const second = await connect(relay);
    try {
      const session = crypto.randomUUID();
      const request = framed(message(18, [field(2, session), field(6, serverKey)]));
      first.write(request); second.write(request);
      await delay(150);
      const forward = crypto.randomBytes(65536);
      const backward = crypto.randomBytes(65536);
      const atSecond = receive(second, forward.length);
      const atFirst = receive(first, backward.length);
      first.write(forward); second.write(backward);
      assert.deepEqual(await atSecond, forward, 'relay forwards complete client payload');
      assert.deepEqual(await atFirst, backward, 'relay returns complete remote payload');
    } finally { first.destroy(); second.destroy(); }
    console.log(`PASS ${mode}: UDP identity/heartbeat, TCP NAT, wrong-key rejection, 64KiB relay in both directions`);
    if (process.argv.includes('--websocket')) await websocketCheck();
  } finally { udp.close(); }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
