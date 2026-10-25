import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp, readFile, rm, access} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {Script} from 'node:vm';
test('native workspace bundles a standalone classic script and local assets',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'glassdeck-native-'));
 try {
  execFileSync('bash',['tools/bundle-workspace.sh',dir]);
  const html=await readFile(join(dir,'index.html'),'utf8');
  assert(!html.includes('type="module"'));assert(!html.includes('rel="manifest"'));
  for(const [,path]of html.matchAll(/(?:src|href)="\.\/([^"#]+)"/g))await access(join(dir,path));
  const script=await readFile(join(dir,'workspace.js'),'utf8');
  assert.doesNotThrow(()=>new Script(script));
  assert(script.includes('window.glassDeckNative'));assert(script.includes("action:'save'"));
 }finally{await rm(dir,{recursive:true,force:true});}
});
