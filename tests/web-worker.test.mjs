import test from 'node:test';import assert from 'node:assert/strict';import worker from '../deploy/worker.js';
test('the installable app root redirects to the scoped trailing-slash URL',async()=>{
 const r=await worker.fetch(new Request('https://aarongame.com/app?source=home'),{ASSETS:{fetch(){throw new Error('not needed');}}});
 assert.equal(r.status,308);assert.equal(r.headers.get('location'),'https://aarongame.com/app/?source=home');
});
test('missing app assets stay 404 instead of returning the landing page',async()=>{
 for(const path of ['/app/missing.mjs','/app/missing.png']){
 const r=await worker.fetch(new Request('https://aarongame.com'+path),{ASSETS:{fetch:async()=>new Response('missing',{status:404})}});assert.equal(r.status,404);
 }
});
test('legacy landing redirects are preserved and assets pass through',async()=>{
 const env={ASSETS:{fetch:async r=>new Response(r.url.endsWith('.css')?'body{}':'missing',{status:r.url.endsWith('.css')?200:404})}};
 assert.equal((await worker.fetch(new Request('https://aarongame.com/old-page'),env)).status,301);
 assert.equal((await worker.fetch(new Request('https://aarongame.com/app/style.css'),env)).status,200);
});
