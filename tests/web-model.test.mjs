import test from 'node:test';
import assert from 'node:assert/strict';
import {emptyState, validateState, remaining, settleTimer, convert} from '../website/app/model.mjs';
test('a suspended timer uses its deadline, settles once and survives a backup',()=>{
 const state=emptyState();state.timer.endAt=100000;
 assert.equal(remaining(state.timer,40000),60);
 const done=settleTimer(state.timer,101000);assert.equal(done.completed,1);assert.equal(done.remaining,0);
 assert.equal(settleTimer(done,200000).completed,1);
 assert.deepEqual(validateState(JSON.parse(JSON.stringify({...state,timer:done}))).timer,done);
});
test('paused timers keep their remaining time and future clock changes cannot exceed duration',()=>{
 const timer={duration:300,remaining:123,endAt:null,completed:0};assert.equal(remaining(timer,999999),123);
 timer.endAt=99999999;assert.equal(remaining(timer,0),300);
});
test('backup validation rejects malformed data without coercion',()=>{
 for (const change of [{version:2},{tasks:[{id:'x',text:'',done:false}]},{notes:0},{timer:{...emptyState().timer,endAt:'tomorrow'}},{timer:{...emptyState().timer,remaining:-1}},{tasks:[{id:'x',text:'a',done:false},{id:'x',text:'b',done:false}]}])assert.throws(()=>validateState({...emptyState(),...change}));
 assert.throws(()=>validateState({...emptyState(),notes:'x'.repeat(100001)}));
});
test('valid backups retain unicode and literal HTML without executing it',()=>{
 const s=emptyState();s.notes='科学 ☀️';s.tasks=[{id:'abc',text:'<img src=x onerror=alert(1)>',done:false}];assert.deepEqual(validateState(s),s);
});
test('converters correctly handle metric imperial and temperatures',()=>{
 assert.equal(convert(1,'km','m','length'),1000);assert.equal(convert(1,'in','cm','length'),2.54);
 assert.equal(convert(32,'F','C','temperature'),0);assert.equal(convert(0,'C','K','temperature'),273.15);
 assert.throws(()=>convert(-274,'C','K','temperature'));assert.throws(()=>convert(NaN,'m','ft','length'));
 assert.throws(()=>convert(1,'C','m','length'));
});
