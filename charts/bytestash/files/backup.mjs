// SPDX-License-Identifier: Apache-2.0
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {randomUUID} from 'node:crypto';
const require = createRequire('/app/package.json');
const Database = require('better-sqlite3');
const destination = '/backups';
const retention = Number(process.env.BACKUP_RETENTION);
if (!Number.isInteger(retention) || retention < 1) throw new Error('BACKUP_RETENTION must be positive');
const filename = 'bytestash-' + new Date().toISOString().replace(/[:.]/g, '-') + '-' + randomUUID() + '.db';
const target = path.join(destination, filename);
const temporary = target + '.partial';
const source = new Database('/data/snippets/snippets.db', {readonly:true,fileMustExist:true,timeout:30000});
try {
 await source.backup(temporary);
 const verified = new Database(temporary,{readonly:true,fileMustExist:true});
 try {if (verified.pragma('integrity_check',{simple:true}) !== 'ok') throw new Error('Snapshot integrity check failed');}
 finally {verified.close();}
 fs.renameSync(temporary,target);
 const backups = fs.readdirSync(destination).filter(f => /^bytestash-\d{4}-\d{2}-\d{2}T[\d-]+Z-[a-f0-9-]{36}\.db$/.test(f)).sort().reverse();
 for (const old of backups.slice(retention)) fs.unlinkSync(path.join(destination,old));
 console.log('SQLite online snapshot verified and published; retained '+Math.min(backups.length,retention)+' backups');
} finally {source.close(); if(fs.existsSync(temporary)) fs.unlinkSync(temporary);}
