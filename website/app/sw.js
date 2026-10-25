const CACHE = 'glassdeck-web-v1';
const SHELL = ['./','./index.html','./style.css','./app.mjs','./model.mjs','./manifest.webmanifest','./icon.svg','./icon-192.png','./icon-512.png','./icon-maskable.png'];
self.addEventListener('install', event => {event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(SHELL)).then(()=>self.skipWaiting()));});
self.addEventListener('activate', event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('glassdeck-web-')&&key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim()));});
self.addEventListener('fetch', event=>{
  const url=new URL(event.request.url);
  if(event.request.method!=='GET'||url.origin!==self.location.origin||!url.pathname.startsWith('/app/'))return;
  // Never substitute HTML for a missing script, icon, or manifest.
  if(event.request.mode==='navigate'){
    event.respondWith(fetch(event.request).then(response=>response.ok?response:caches.match('./index.html')).catch(()=>caches.match('./index.html')));return;
  }
  event.respondWith(caches.match(event.request).then(cached=>cached||fetch(event.request)));
});
