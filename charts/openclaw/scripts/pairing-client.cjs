// SPDX-License-Identifier: Apache-2.0
const {createRequire} = require('node:module');
const requireApp = createRequire('/app/package.json');
const WebSocket = requireApp('ws');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = process.env.TEST_IDENTITY_FILE || '/tmp/openclaw-ci-identity.pem';
let privateKey;
try { privateKey = crypto.createPrivateKey(fs.readFileSync(path)); }
catch (error) {
  if (error.code !== 'ENOENT') throw error;
  const pair = crypto.generateKeyPairSync('ed25519');
  fs.writeFileSync(path, pair.privateKey.export({type:'pkcs8',format:'pem'}), {mode:0o600,flag:'wx'});
  privateKey = pair.privateKey;
}
const publicDer = crypto.createPublicKey(privateKey).export({type:'spki',format:'der'});
// Ed25519 SubjectPublicKeyInfo = fixed12byte prefix + raw32byte public key.
if (publicDer.length !== 44 || publicDer.subarray(0,12).toString('hex') !== '302a300506032b6570032100')
  throw new Error('unexpected Ed25519 public key encoding');
const raw = publicDer.subarray(12);
const deviceId = crypto.createHash('sha256').update(raw).digest('hex');
const token = process.env.TEST_GATEWAY_TOKEN;
if (!token) throw new Error('TEST_GATEWAY_TOKEN missing');
const ws = new WebSocket(process.env.TEST_GATEWAY_WS_URL, {
  origin: process.env.TEST_ORIGIN,
  handshakeTimeout: 10000,
});
const timer = setTimeout(() => { ws.terminate(); console.error('pairing timeout'); process.exitCode=1; }, 20000);
let finished=false;
function finish(result) {
  if (finished) return;
  finished=true; clearTimeout(timer);
  console.log(JSON.stringify(result)); ws.close();
}
ws.on('error', () => { if(!finished) { clearTimeout(timer); console.error('websocket connection error'); process.exitCode=1; } });
ws.on('message', rawFrame => {
  const frame=JSON.parse(rawFrame.toString());
  if(frame.type==='event' && frame.event==='connect.challenge') {
    const {nonce,ts}=frame.payload;
    if(typeof nonce!=='string' || !nonce || !Number.isSafeInteger(ts)) throw new Error('invalid challenge');
    const scopes=['operator.read'];
    const client={id:'openclaw-control-ui',version:'2026.9.4',platform:'linux',mode:'webchat',displayName:'HelmForge CI pairing'};
    const payload=['v3',deviceId,client.id,client.mode,'operator',scopes.join(','),String(ts),token,nonce,'linux',''].join('|');
    ws.send(JSON.stringify({type:'req',id:'hf-connect',method:'connect',params:{
      minProtocol:4,maxProtocol:4,client,role:'operator',scopes,caps:[],auth:{token},
      device:{id:deviceId,publicKey:raw.toString('base64url'),signedAt:ts,nonce,
        signature:crypto.sign(null,Buffer.from(payload),privateKey).toString('base64url')},
    }}));
  } else if(frame.type==='res' && frame.id==='hf-connect') {
    if(frame.ok) {
      if(frame.payload?.type!=='hello-ok') throw new Error('unexpected successful connect payload');
      finish({ok:true,deviceId,protocol:frame.payload.protocol});
    } else {
      finish({ok:false,deviceId,code:frame.error?.details?.code,
        requestId:frame.error?.details?.requestId || null});
    }
  }
});
ws.on('close', () => { if(!finished) { clearTimeout(timer); console.error('closed before connect result'); process.exitCode=1; } });
