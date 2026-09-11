// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {io} from 'socket.io-client';
import * as Y from 'yjs';

const docId=randomUUID(),marker='helmforge-'+randomUUID();
export async function collaboration({base,origin,cookies,workspace,k,pod,create=false}) {
  const sockets=[],documents=[];
  const scope={spaceType:'workspace',spaceId:workspace};
  const headers={Host:new URL(origin).host,Origin:origin,'x-affine-version':'0.27.4'};
  function socket(authenticated=true){const s=io(base,{transports:['websocket'],reconnection:false,forceNew:true,timeout:8000,extraHeaders:{...headers,...(authenticated?{Cookie:[...cookies].map(([k,v])=>k+'='+v).join('; ')}:{})}});sockets.push(s);return s;}
  function connected(s){return new Promise((resolve,reject)=>{s.once('connect',resolve);s.once('connect_error',reject);});}
  async function ack(s,event,payload){const result=await s.timeout(10000).emitWithAck(event,payload);assert.equal(result.error,undefined,JSON.stringify(result.error));assert.ok(result.data);return result.data;}
  async function joined(){const s=socket();await connected(s);assert.equal((await ack(s,'space:join',{...scope,clientVersion:'0.27.4'})).success,true);return s;}
  function document(){const d=new Y.Doc();documents.push(d);return d;}
  function native(operation,bytes,markdown=marker){
    const code="const fs=require('fs');const file=fs.readdirSync('/app/dist').find(n=>/^server-native\\..*\\.node$/.test(n));const n=require('/app/dist/'+file);const [op,id,encoded,text]=process.argv.slice(1);const bin=Buffer.from(encoded,'base64');if(op==='read'){const result=n.parseDocToMarkdown(bin,id);if(result.unknownBlocks.length)throw Error('Native document contains unknown blocks');console.log(JSON.stringify(result.markdown));}else console.log((op==='create'?n.createDocWithMarkdown('HelmForge fixture',text,id):n.updateDocWithMarkdown(bin,text,id)).toString('base64'));";
    const result=k(['exec',pod(),'-c','affine','--','node','-e',code,operation,docId,Buffer.from(bytes??[]).toString('base64'),markdown]).trim();
    return operation==='read'?JSON.parse(result):Buffer.from(result,'base64');
  }
  function content(d){return native('read',Y.encodeStateAsUpdate(d));}
  async function loaded(s){const result=await ack(s,'space:load-doc',{...scope,docId});assert.ok(result.missing);const d=document();Y.applyUpdate(d,Buffer.from(result.missing,'base64'));assert.ok(content(d).includes(marker));return d;}
  try {
    const anonymous=socket(false);await assert.rejects(connected(anonymous));anonymous.disconnect();
    const sender=await joined();
    if(create){
      const receiver=await joined(),source=document(),received=document();Y.applyUpdate(source,native('create'));
      let timer;
      const broadcast=new Promise((resolve,reject)=>{timer=setTimeout(()=>reject(Error('Native collaboration broadcast timed out')),12000);receiver.on('space:broadcast-doc-updates',event=>{if(event.spaceId!==workspace||event.docId!==docId)return;try{assert.ok(Array.isArray(event.updates));for(const update of event.updates)Y.applyUpdate(received,Buffer.from(update,'base64'));assert.ok(content(received).includes(marker));clearTimeout(timer);resolve();}catch(error){clearTimeout(timer);reject(error);}});});
      try{const result=await ack(sender,'space:push-doc-update',{...scope,docId,update:Buffer.from(Y.encodeStateAsUpdate(source)).toString('base64')});assert.equal(result.accepted,true);assert.ok(result.timestamp>0);await broadcast;}finally{clearTimeout(timer);}
      sender.disconnect();receiver.disconnect();source.destroy();received.destroy();
      await loaded(await joined());
    }else{
      const restored=await loaded(sender);Y.applyUpdate(restored,native('update',Y.encodeStateAsUpdate(restored),marker+'\n\nEdited after recovery: '+marker));
      assert.equal((await ack(sender,'space:push-doc-update',{...scope,docId,update:Buffer.from(Y.encodeStateAsUpdate(restored)).toString('base64')})).accepted,true);
      sender.disconnect();restored.destroy();const fresh=await loaded(await joined());assert.ok(content(fresh).includes('Edited after recovery: '+marker));
    }
    console.log('PASS native Socket.IO authentication, two-client Yjs broadcast and persisted document '+(create?'reopen':'post-replacement edit/reopen'));
  }finally{for(const s of sockets)s.disconnect();for(const d of documents)d.destroy();}
}
