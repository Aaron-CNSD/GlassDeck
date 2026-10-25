// GlassCraft resource metadata API. GPL-3.0, see upstream repository LICENSE.
const BASE = '/glasscraft/api';
const cors = {'Access-Control-Allow-Origin':'*','Content-Type':'application/json; charset=utf-8'};
const json = (value, status=200) => new Response(JSON.stringify(value), {status,headers:cors});
export async function resourceAPI(request) {
  const url = new URL(request.url);
  if (!url.pathname.startsWith(BASE + '/')) return null;
  if (request.method === 'OPTIONS') return new Response(null,{status:204,headers:{...cors,'Access-Control-Allow-Methods':'GET, OPTIONS'}});
  if (request.method !== 'GET') return json({error:'method_not_allowed'},405);
  const route = url.pathname.slice(BASE.length);
  if (route === '/health') return json({service:'GlassCraft',version:'0.1.0-preview',nativeBuild:'unverified'});
  let upstream;
  if (route === '/versions') upstream='https://piston-meta.mojang.com/mc/game/version_manifest_v2.json';
  else if (route === '/search') {
    const type=url.searchParams.get('type') || 'mod';
    if (!['mod','modpack','shader'].includes(type)) return json({error:'invalid_type'},400);
    const q=url.searchParams.get('q') || '';
    const version=url.searchParams.get('version') || '';
    if(q.length>120 || version.length>40) return json({error:'query_too_long'},400);
    const facets=[[`project_type:${type}`]];
    if(version) facets.push([`versions:${version}`]);
    const params=new URLSearchParams({query:q,facets:JSON.stringify(facets),limit:'20'});
    upstream='https://api.modrinth.com/v2/search?'+params;
  } else {
    const match=route.match(/^\/projects\/([A-Za-z0-9_-]{1,80})\/versions$/);
    if(!match) return json({error:'not_found'},404);
    const params=new URLSearchParams();
    const version=url.searchParams.get('version');
    if(version && version.length>40) return json({error:'invalid_version'},400);
    if(version) params.set('game_versions',JSON.stringify([version]));
    upstream='https://api.modrinth.com/v2/project/'+encodeURIComponent(match[1])+'/version?'+params;
  }
  try {
    const response=await fetch(upstream,{headers:{'User-Agent':'Aaron-CNSD/GlassCraft-iOS/0.1 (https://github.com/Aaron-CNSD/GlassCraft-iOS)'},cf:{cacheTtl:300,cacheEverything:true},signal:AbortSignal.timeout(12000)});
    if(!response.ok) return json({error:'upstream_error',status:response.status},response.status===429?429:502);
    const result=json(await response.json());
    result.headers.set('Cache-Control','public, max-age=300');
    return result;
  } catch { return json({error:'upstream_unavailable'},502); }
}
export default {fetch:async request => await resourceAPI(request) || json({error:'not_found'},404)};
