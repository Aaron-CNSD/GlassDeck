import {STORAGE_KEY, emptyState, validateState, remaining, settleTimer, convert} from './model.mjs';
const $ = id => document.getElementById(id);
const nativeHost = window.glassDeckNative === true && window.webkit?.messageHandlers?.glassDeckExport;
if (nativeHost) {
  document.querySelectorAll('#install, #install-guide, #wake').forEach(el => el.hidden = true);
  $('offline-ready').textContent = '工作台已随 Mac 应用打包，无需联网。';
  document.querySelector('.workspace span').textContent = 'MAC';
  document.querySelector('.sidebar-bottom p').textContent = '保存在此 Mac 应用中，与浏览器版分别存储。可通过备份导入导出。';
  document.querySelector('.sidebar-bottom .local-dot').textContent = '数据保存在此 Mac 应用';
  $('quick-save').textContent = $('note-save').textContent = '自动保存到此 Mac 应用';
  document.querySelector('.backup-card .muted').textContent = '导出待办、笔记与计时记录，再导入其他设备。Mac 应用与浏览器分别存储，不会自动同步；删除应用数据前请先导出。';
  document.querySelector('.micro').textContent = '计时按实际时间恢复；应用退出或设备休眠时不保证响铃。';
}
function newTaskID() {
  if (typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  return Array.from(crypto.getRandomValues(new Uint8Array(16)), n => n.toString(16).padStart(2, '0')).join('');
}
let state = emptyState();
let storageFailed = false;
function announce(message) { $('status').textContent = message; }
try { const saved = localStorage.getItem(STORAGE_KEY); if (saved) state = validateState(JSON.parse(saved)); }
catch { storageFailed = true; announce('无法读取保存的数据。请先导出备份；当前操作只会保留在本次会话中。'); }
function save() {
  if (storageFailed) return false;
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); return true; }
  catch { storageFailed = true; announce('存储空间不足或浏览器禁止保存。请导出备份；离开页面前请保存你的内容。'); return false; }
}
let currentPage = 'overview';
function showPage(page) {
  if (!['overview','notes','tools'].includes(page)) return;
  currentPage = page;
  for (const el of document.querySelectorAll('.page')) el.hidden = el.id !== page;
  for (const el of document.querySelectorAll('nav button')) {
    if (el.dataset.page === page) el.setAttribute('aria-current','page'); else el.removeAttribute('aria-current');
  }
  $('page-name').textContent = {overview:'总览',notes:'随手笔记',tools:'工具箱'}[page];
  if (location.hash !== `#${page}`) history.replaceState(null,'',`#${page}`);
}
document.querySelectorAll('[data-page]').forEach(b => b.addEventListener('click', () => showPage(b.dataset.page)));
showPage(location.hash.slice(1) || 'overview');
window.addEventListener('hashchange', () => showPage(location.hash.slice(1)));
try { document.body.classList.toggle('light', localStorage.getItem('glassdeck.theme') === 'light'); } catch {}
$('theme').addEventListener('click', () => {
  document.body.classList.toggle('light');
  try { localStorage.setItem('glassdeck.theme', document.body.classList.contains('light') ? 'light' : 'dark'); } catch {}
});
function renderTasks() {
  const list = $('tasks'); list.replaceChildren();
  for (const task of state.tasks) {
    const li = document.createElement('li'); li.classList.toggle('done',task.done);
    const check = document.createElement('input'); check.type = 'checkbox'; check.checked = task.done; check.id = `task-${task.id}`;
    const label = document.createElement('label'); label.htmlFor = check.id; label.textContent = task.text;
    check.addEventListener('change', () => {task.done = check.checked; save(); li.classList.toggle('done',task.done); taskCounts();});
    const remove = document.createElement('button'); remove.className='delete-task'; remove.textContent='×'; remove.setAttribute('aria-label',`删除待办 ${task.text}`);
    remove.addEventListener('click', () => {state.tasks=state.tasks.filter(t=>t.id!==task.id); save(); renderTasks(); $('task-input').focus();});
    li.append(check,label,remove); list.append(li);
  }
  taskCounts();
}
function taskCounts() {
  const done = state.tasks.filter(t=>t.done).length;
  $('task-count').textContent=`${state.tasks.length-done} 项待办`;
  $('task-summary').textContent=state.tasks.length ? `已完成 ${done} / ${state.tasks.length}` : '把大目标拆成小步骤';
  $('clear-done').hidden=done===0;
  $('task-empty').hidden=state.tasks.length>0;
}
$('task-form').addEventListener('submit', event => {
  event.preventDefault(); const text=$('task-input').value.trim(); if (!text) return;
  if (state.tasks.length>=1000) { announce('待办已达 1000 项，请先清理已完成事项。'); return; }
  state.tasks.push({id:newTaskID(),text,done:false}); save(); renderTasks(); $('task-input').value=''; $('task-input').focus();
});
$('clear-done').addEventListener('click', () => {if (!confirm('清除所有已完成待办？')) return; state.tasks=state.tasks.filter(t=>!t.done);save();renderTasks();});
function notesChanged(source) {
  state.notes=source.value;
  const other=source.id==='quick-note' ? $('note-editor') : $('quick-note'); other.value=state.notes;
  $('note-count').textContent=`${Array.from(state.notes).length.toLocaleString()} 字符`;
  const ok=save(); const message=ok?(nativeHost?'已保存到此 Mac 应用':'已保存到此浏览器'):'尚未保存，请导出备份';
  $('quick-save').textContent=message; $('note-save').textContent=message;
}
$('quick-note').addEventListener('input',()=>notesChanged($('quick-note')));
$('note-editor').addEventListener('input',()=>notesChanged($('note-editor')));
function renderNotes() { $('quick-note').value=state.notes; $('note-editor').value=state.notes; $('note-count').textContent=`${Array.from(state.notes).length.toLocaleString()} 字符`; }
let audioContext;
function enableAudio() {try {audioContext ??= new (window.AudioContext || window.webkitAudioContext)(); audioContext.resume().catch(()=>{});}catch{}}
function chime() {try {if(!audioContext || audioContext.state!=='running')return; const oscillator=audioContext.createOscillator(); const gain=audioContext.createGain(); oscillator.frequency.value=660; gain.gain.setValueAtTime(.09,audioContext.currentTime); gain.gain.exponentialRampToValueAtTime(.001,audioContext.currentTime+.7); oscillator.connect(gain).connect(audioContext.destination); oscillator.start(); oscillator.stop(audioContext.currentTime+.7);}catch{}}
function updateTimer() {
  const previous=state.timer; state.timer=settleTimer(state.timer);
  if (previous!==state.timer) {save(); announce('计时完成。休息一下，再继续下一件事。'); chime();}
  const left=remaining(state.timer); const running=state.timer.endAt!==null;
  const text=`${String(Math.floor(left/60)).padStart(2,'0')}:${String(left%60).padStart(2,'0')}`;
  $('timer').textContent=text; document.title=running?`${text} · Glass Deck`:'Glass Deck Web · 随处进入状态';
  $('start').textContent=running?'暂停计时':left===0?'再来一次 →':'开始专注 →';
  $('timer-state').textContent=running?'专注中':left===0?'已完成':left<state.timer.duration?'已暂停':'准备开始';
  $('progress-ring').style.strokeDashoffset=String(628.319*(1-left/state.timer.duration));
  $('sessions').textContent=String(state.timer.completed);
  document.querySelectorAll('[data-minutes]').forEach(b=>b.setAttribute('aria-pressed',String(Number(b.dataset.minutes)*60===state.timer.duration)));
}
$('start').addEventListener('click',()=>{
  enableAudio(); updateTimer();
  const t=state.timer;
  if(t.endAt!==null){t.remaining=remaining(t);t.endAt=null;}
  else {if(t.remaining===0)t.remaining=t.duration;t.endAt=Date.now()+t.remaining*1000;}
  save();updateTimer();
});
$('reset').addEventListener('click',()=>{if(state.timer.endAt!==null&&!confirm('重置正在运行的计时？'))return;state.timer.remaining=state.timer.duration;state.timer.endAt=null;save();updateTimer();});
document.querySelectorAll('[data-minutes]').forEach(b=>b.addEventListener('click',()=>{
  if(state.timer.endAt!==null&&!confirm('切换时长会重置当前计时，继续吗？'))return;
  state.timer.duration=Number(b.dataset.minutes)*60;state.timer.remaining=state.timer.duration;state.timer.endAt=null;save();updateTimer();
}));
let wakeLock=null, wantsWake=false;
async function acquireWake() {
  try {wakeLock=await navigator.wakeLock.request('screen');wakeLock.addEventListener('release',()=>{wakeLock=null; $('wake').setAttribute('aria-pressed','false');$('wake').textContent=wantsWake?'回到页面后恢复常亮':'保持屏幕常亮';});$('wake').setAttribute('aria-pressed','true');$('wake').textContent='常亮已开启 · 关闭';}
  catch {wantsWake=false;announce('此设备或浏览器暂时不允许保持屏幕常亮。');$('wake').setAttribute('aria-pressed','false');$('wake').textContent='保持屏幕常亮';}
}
$('wake').addEventListener('click',async()=>{
  if(!('wakeLock'in navigator)){announce('此浏览器不支持屏幕常亮，请使用设备的显示设置。');return;}
  wantsWake=!wantsWake;
  if(wantsWake)await acquireWake();else {await wakeLock?.release();$('wake').textContent='保持屏幕常亮';}
});
document.addEventListener('visibilitychange',()=>{updateTimer();if(document.visibilityState==='visible'&&wantsWake&&!wakeLock)acquireWake();});
const units={length:{m:'米 m',km:'千米 km',cm:'厘米 cm',mm:'毫米 mm',in:'英寸 in',ft:'英尺 ft',mi:'英里 mi'},temperature:{C:'摄氏度 °C',F:'华氏度 °F',K:'开尔文 K'}};
function unitOptions(){
  for(const id of ['from-unit','to-unit']){const select=$(id);select.replaceChildren();for(const [value,text] of Object.entries(units[$('category').value])){const o=document.createElement('option');o.value=value;o.textContent=text;select.append(o);}}
  $('to-unit').selectedIndex=1;renderConversion();
}
function renderConversion(){try{if($('convert-value').value.trim()==='')throw new Error();const result=convert(Number($('convert-value').value),$('from-unit').value,$('to-unit').value,$('category').value);if(!Number.isFinite(result))throw new Error();$('convert-result').textContent=`${Number(result.toPrecision(10)).toLocaleString('zh-CN',{maximumSignificantDigits:10})} ${$('to-unit').value}`;}catch{$('convert-result').textContent='请输入有效范围内的数值';}}
$('category').addEventListener('change',unitOptions);['convert-value','from-unit','to-unit'].forEach(id=>$(id).addEventListener('input',renderConversion));
function textCount(){const text=$('tool-text').value;$('text-count').textContent=`${Array.from(text).length} 字符 · ${text.trim()?text.trim().split(/\s+/u).length:0} 个空格分隔词`;$('json-result').textContent='';}
$('tool-text').addEventListener('input',textCount);
$('format-json').addEventListener('click',()=>{try{$('tool-text').value=JSON.stringify(JSON.parse($('tool-text').value),null,2);textCount();$('json-result').textContent='格式已整理。';}catch{$('json-result').textContent='JSON 格式无效，请检查引号、逗号和括号。';}});
$('copy-text').addEventListener('click',async()=>{try{if(nativeHost)nativeHost.postMessage({action:'copy',text:$('tool-text').value});else await navigator.clipboard.writeText($('tool-text').value);$('json-result').textContent='已复制。';}catch{$('tool-text').select();$('json-result').textContent='无法自动复制，请使用系统的复制操作。';}});
function download(text,type,name){if(nativeHost){nativeHost.postMessage({action:'save',text,name});return;}const url=URL.createObjectURL(new Blob([text],{type}));const a=document.createElement('a');a.href=url;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),30000);}
$('download-note').addEventListener('click',()=>download(state.notes,'text/plain;charset=utf-8','glassdeck-notes.txt'));
$('export').addEventListener('click',()=>{updateTimer();download(JSON.stringify(state,null,2),'application/json',`glassdeck-backup-${new Date().toISOString().slice(0,10)}.json`);});
$('import').addEventListener('click',()=>$('import-file').click());
$('import-file').addEventListener('change',async event=>{
  const file=event.target.files[0];event.target.value='';if(!file)return;
  try{if(file.size>2*1024*1024)throw new Error();const imported=validateState(JSON.parse(await file.text()));if(!confirm('导入将替换此浏览器的待办、笔记和计时记录。建议先导出当前备份。继续吗？'))return;
    state=imported;storageFailed=false;const ok=save();renderTasks();renderNotes();updateTimer();announce(ok?'已导入备份并保存。':'备份已载入本次会话，但未能保存，请导出备份。');
  }catch{announce('无法导入：请选择有效的 Glass Deck 备份文件（不超过 2 MB）。现有数据未改变。');}
});
let installPrompt;
window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();installPrompt=event;});
async function install(){if(installPrompt){const prompt=installPrompt;installPrompt=null;await prompt.prompt();await prompt.userChoice;}else $('install-dialog').showModal();}
$('install').addEventListener('click',install);$('install-guide').addEventListener('click',()=>$('install-dialog').showModal());$('close-dialog').addEventListener('click',()=>$('install-dialog').close());
window.addEventListener('appinstalled',()=>{installPrompt=null;announce('Glass Deck 已安装。');});
function network(){ $('network').textContent=navigator.onLine?'在线':'离线模式'; }
window.addEventListener('online',network);window.addEventListener('offline',network);network();
if(!nativeHost && 'serviceWorker'in navigator){
  navigator.serviceWorker.register('./sw.js',{scope:'./'}).then(()=>navigator.serviceWorker.ready).then(()=>{$('offline-ready').textContent='离线资源已就绪。此页面可在断网后重新打开。';}).catch(()=>{$('offline-ready').textContent='离线资源尚未就绪；请保持联网使用并稍后重试。';});
}else if(!nativeHost) $('offline-ready').textContent='此浏览器不支持离线资源，请联网使用。';
function clock(){const now=new Date();$('clock').textContent=now.toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit',hour12:false});$('today').textContent=now.toLocaleDateString('zh-CN',{year:'numeric',month:'long',day:'numeric',weekday:'long'});}
renderTasks();renderNotes();unitOptions();updateTimer();clock();setInterval(()=>{updateTimer();clock();},1000);
