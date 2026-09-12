// SPDX-License-Identifier: Apache-2.0
// Only the external model service is simulated. The real gateway executes tools.
import http from 'node:http';
http.createServer(async(req,res)=>{
 if(req.url==='/health'){res.end('ok');return;}
 if(req.url==='/v1/models'){res.setHeader('content-type','application/json');res.end(JSON.stringify({object:'list',data:[{id:'helmforge-fixture',object:'model'}]}));return;}
 let raw='';for await(const part of req){raw+=part;if(raw.length>2*1024*1024){res.writeHead(413).end();return;}}
 let body;try{body=JSON.parse(raw);}catch{res.writeHead(400).end();return;}
 if(req.headers.authorization!=='Bearer helmforge-fixture-only'){res.writeHead(401).end();return;}
 const messages=body.messages??[];
 const latestUser=messages.findLastIndex(x=>x.role==='user');
 const request=JSON.stringify(messages[latestUser]??{});
 const toolResults=messages.slice(latestUser+1).filter(x=>x.role==='tool');
 let tool;
 if(!toolResults.length&&request.includes('HF_STORE'))tool={name:'write',arguments:JSON.stringify({path:'/home/node/.openclaw/workspace/helmforge-memory.txt',content:'HELMFORGE_PERSISTED_OPENCLAW_MEMORY'})};
 if(!toolResults.length&&request.includes('HF_READ'))tool={name:'read',arguments:JSON.stringify({path:'/home/node/.openclaw/workspace/helmforge-memory.txt'})};
 const content=tool?null:(toolResults.length?JSON.stringify(toolResults):'HELMFORGE_OPENCLAW_RESPONSE');
 const message=tool?{role:'assistant',content:null,tool_calls:[{id:'call_helmforge',type:'function',function:tool}]}:{role:'assistant',content};
 const finish=tool?'tool_calls':'stop';
 const common={id:'chatcmpl-helmforge',created:Math.floor(Date.now()/1000),model:'helmforge-fixture'};
 console.log(JSON.stringify({method:req.method,path:req.url,stream:!!body.stream,tool:tool?.name??null}));
 if(body.stream){
  res.writeHead(200,{'content-type':'text/event-stream','cache-control':'no-cache'});
  const delta=tool?{role:'assistant',tool_calls:[{index:0,id:'call_helmforge',type:'function',function:tool}]}:{role:'assistant',content};
  res.write('data: '+JSON.stringify({...common,object:'chat.completion.chunk',choices:[{index:0,delta,finish_reason:null}]})+'\n\n');
  res.write('data: '+JSON.stringify({...common,object:'chat.completion.chunk',choices:[{index:0,delta:{},finish_reason:finish}],usage:{prompt_tokens:30,completion_tokens:12,total_tokens:42}})+'\n\n');
  res.end('data: [DONE]\n\n');
 }else{res.setHeader('content-type','application/json');res.end(JSON.stringify({...common,object:'chat.completion',choices:[{index:0,message,finish_reason:finish}],usage:{prompt_tokens:30,completion_tokens:12,total_tokens:42}}));}
}).listen(8080,'0.0.0.0');
