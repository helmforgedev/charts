// SPDX-License-Identifier: Apache-2.0
import fs from 'node:fs';
import {initializeDatabase,shutdownDatabase} from '/app/src/config/database.js';
import userService from '/app/src/services/userService.js';
import userRepository from '/app/src/repositories/userRepository.js';
import {up_v1_5_0_snippets} from '/app/src/config/migrations/20241117-migration.js';
try {
 const adapter=await initializeDatabase();
 const db=adapter.db??adapter;
 if(!db?.exec||!db?.prepare) throw new Error('ByteStash SQLite adapter does not expose the required native database handle');
 db.exec('BEGIN IMMEDIATE');
 try {
 const count=db.prepare('SELECT COUNT(*) AS count FROM users').get().count;
 const username=process.env.BOOTSTRAP_USERNAME;
 if(count===0){
  const password=fs.readFileSync('/run/bootstrap/password','utf8').trim();
  const user=await userService.createUser(username,password);
  if(userRepository.setAdmin) await userRepository.setAdmin(user.id, true);
  await up_v1_5_0_snippets(db,user.id);
  console.log('Initial administrative account created before HTTP exposure');
 }else {
  const existing=await userRepository.findByUsername(username);
  if(!existing){
   throw new Error('Configured bootstrap administrator is absent from existing database; set bootstrap.username to the intended existing administrator or explicitly adopt the populated claim with bootstrap disabled');
  }
  if(userRepository.setAdmin) await userRepository.setAdmin(existing.id, true);
  console.log('Existing administrator retained; password not reset');
 }
 const extraAdmins=(process.env.ADMIN_USERNAMES||'').split(',').map(s=>s.trim()).filter(Boolean);
 for(const extra of extraAdmins){
  const extraUser=await userRepository.findByUsername(extra);
  if(extraUser&&userRepository.setAdmin) await userRepository.setAdmin(extraUser.id, true);
 }
 db.exec('COMMIT');
 } catch(error) { db.exec('ROLLBACK'); throw error; }
}finally{await shutdownDatabase();}
