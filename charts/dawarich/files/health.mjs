// SPDX-License-Identifier: Apache-2.0
const response=await fetch('http://127.0.0.1:3010/api/v1/health',{
 headers:{Host:process.env.APPLICATION_HOSTS,'X-Forwarded-Proto':process.env.APPLICATION_PROTOCOL},
 redirect:'manual',signal:AbortSignal.timeout(4000)
});
if(response.status!==200||(await response.json()).status!=='ok')process.exit(1);
