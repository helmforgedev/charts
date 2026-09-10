// SPDX-License-Identifier: Apache-2.0
import http from 'node:http';
const server=http.createServer((req,res)=>{
  if(req.url!=='/metrics'){res.writeHead(404);res.end();return;}
  if(req.method!=='GET'){res.writeHead(405,{Allow:'GET'});res.end();return;}
  const upstream=http.request({hostname:'127.0.0.1',port:9205,path:'/metrics',method:'GET',agent:false,timeout:8000,headers:typeof req.headers.authorization==='string'?{Authorization:req.headers.authorization}:{}},response=>{
    res.writeHead(response.statusCode,{'Content-Type':response.headers['content-type']||'text/plain','Cache-Control':'no-store'});response.pipe(res);
  });
  upstream.on('timeout',()=>upstream.destroy());upstream.on('error',()=>{if(!res.headersSent)res.writeHead(502);res.end();});
  res.on('close',()=>upstream.destroy());upstream.end();
});
server.headersTimeout=10000;server.requestTimeout=10000;server.keepAliveTimeout=1000;server.maxHeadersCount=20;
server.listen(Number(process.env.PORT),'0.0.0.0');
process.on('SIGTERM',()=>server.close(()=>process.exit(0)));
