// SPDX-License-Identifier: Apache-2.0
const live=process.argv[2]==='live';
try{
 const response=await fetch('http://127.0.0.1:18789/'+(live?'healthz':'startupz'),{signal:AbortSignal.timeout(3000)});
 if(!response.ok)process.exit(1);
 const body=await response.json();
 process.exit(body.ok===true && body.status===(live?'live':'started')?0:1);
}catch{process.exit(1);}
