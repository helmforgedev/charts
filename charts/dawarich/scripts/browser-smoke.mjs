// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {chromium} from 'playwright';

export async function verifyBrowserForms({base,email,password,publicUrl}){
 const host=new URL(publicUrl).hostname,port=new URL(base).port;
 const browser=await chromium.launch({headless:true,args:['--no-proxy-server','--host-resolver-rules=MAP '+host+' 127.0.0.1']});
 const context=await browser.newContext({baseURL:'http://'+host+':'+port,locale:'en-US'});
 const page=await context.newPage();page.setDefaultTimeout(15000);
 const go=path=>page.goto(path,{waitUntil:'domcontentloaded'});
 async function login(){
  const response=await go('/users/sign_in');assert.equal(response.status(),200);
  await page.locator('#user_email').fill(email);await page.locator('#user_password').fill(password);
  await Promise.all([page.waitForURL(url=>url.pathname!=='/users/sign_in'),page.locator('form').filter({has:page.locator('#user_password')}).locator('[type=submit]').click()]);
  const edit=await go('/users/edit');assert.equal(edit.status(),200);assert.equal(await page.locator('#user_email').inputValue(),email);
 }
 async function updateEmail(value){
  await page.locator('#user_email').fill(value);await page.locator('#user_current_password').fill(password);
  const submitted=page.waitForResponse(response=>new URL(response.url()).pathname==='/users'&&response.request().method()==='POST');
  await page.locator('form').filter({has:page.locator('#user_current_password')}).locator('[type=submit]').click();
  const response=await submitted;assert.ok([302,303].includes(response.status()),'Native profile update must redirect successfully');
  assert.equal(new URLSearchParams(response.request().postData()).get('_method'),'put','Browser must exercise the native HTML method override');
  await go('/users/edit');assert.equal(await page.locator('#user_email').inputValue(),value,'Native profile update must survive a fresh page load');
 }
 try{
  await login();
  await updateEmail(email.replace('@','+helmforge-browser@'));
  await updateEmail(email);
  await page.locator('[onclick="delete_account_modal.showModal()"]').click();
  const dialog=page.locator('#delete_account_modal');await dialog.locator('[name=password]').fill('incorrect-owned-fixture');
  const submitted=page.waitForResponse(response=>new URL(response.url()).pathname==='/users'&&response.request().method()==='POST');
  await dialog.locator('[type=submit]').click();const response=await submitted;
  assert.ok([302,303].includes(response.status()),'Native deletion validation must run rather than be blocked as registration');
  assert.equal(new URLSearchParams(response.request().postData()).get('_method'),'delete');
  await context.clearCookies();await login();
  console.log('PASS real browser login, persisted HTML profile edits and native invalid-password deletion protection through method override');
 }finally{await browser.close();}
}
