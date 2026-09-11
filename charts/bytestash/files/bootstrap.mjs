// SPDX-License-Identifier: Apache-2.0
import fs from 'node:fs';
import {initializeDatabase,shutdownDatabase} from '/app/src/config/database.js';
import userService from '/app/src/services/userService.js';
import userRepository from '/app/src/repositories/userRepository.js';
import {up_v1_5_0_snippets} from '/app/src/config/migrations/20241117-migration.js';
try {
 const db=initializeDatabase();
 db.exec('BEGIN IMMEDIATE');
 try {
 const count=db.prepare('SELECT COUNT(*) AS count FROM users').get().count;
 const username=process.env.BOOTSTRAP_USERNAME;
 if(count===0){
  const password=fs.readFileSync('/run/bootstrap/password','utf8').trim();
  const user=await userService.createUser(username,password);
  await up_v1_5_0_snippets(db,user.id);
  console.log('Initial administrative account created before HTTP exposure');
 }else if(!await userRepository.findByUsername(username)){
  throw new Error('Configured bootstrap administrator is absent from existing database; set bootstrap.username to the intended existing administrator or explicitly adopt the populated claim with bootstrap disabled');
 }else console.log('Existing administrator retained; password not reset');
 db.exec('COMMIT');
 } catch(error) { db.exec('ROLLBACK'); throw error; }
}finally{shutdownDatabase();}
