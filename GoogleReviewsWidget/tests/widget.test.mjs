import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { start } from '../dist/app.mjs';
import { parseRequest, validPlaceID } from '../dist/model.mjs';
const { JSDOM } = createRequire(import.meta.url)(process.env.JSDOM_MODULE || 'jsdom');
const html = await readFile(new URL('../dist/index.html', import.meta.url), 'utf8');
const hash = new URLSearchParams({name:'Ореха',address:'Алеко Богориди 51',lat:'42.49',lng:'27.47'}).toString();
const config = {enabled:true, apiKey:'AIzaTEST_ONLY_NOT_A_REAL_KEY'};
const placeID = 'ChIJ-test-restaurant-123456';
async function page(t, options = {}) {
  const dom = new JSDOM(html, {url:'https://reviews.example.test/#'+hash+(options.place ? '&place='+options.place : '')});
  t.after(() => dom.window.close());
  const messages = [];
  dom.window.webkit = {messageHandlers:{restaurantReviews:{postMessage: m => messages.push(m)}}};
  const d = dom.window.document;
  await start({document:d,window:dom.window,fetchConfig:async()=>options.config ?? config,load:async()=>{},...options});
  return {d,w:dom.window,messages,fire:(element,type,extras={})=>element.dispatchEvent(Object.assign(new dom.window.Event(type),extras))};
}
test('validates inputs and rejects missing coordinates or injected IDs',()=>{
  assert.equal(parseRequest('#name=a&lat=&lng=27'),null);
  assert.equal(parseRequest('#name=a&lat=NaN&lng=27'),null);
  assert.equal(parseRequest('#name=a&lat=99&lng=27'),null);
  assert.equal(validPlaceID('https://evil.example/x'),false);
  assert.equal(validPlaceID(placeID),true);
});
test('disabled config never loads Google or displays a fake rating',async t=>{
  let calls=0;
  const {d}=await page(t,{config:{enabled:false},load:async()=>{calls++}});
  assert.equal(calls,0); assert.match(d.getElementById('status').textContent,/не са активирани/);
  assert.equal(d.querySelector('gmp-place-details'),null);
});
test('search uses restaurant coordinates, never automatically selects first match',async t=>{
  const {d,fire,messages}=await page(t);
  const search=d.querySelector('gmp-place-search'),q=d.querySelector('gmp-place-text-search-request');
  assert.deepEqual(q.locationBias,{lat:42.49,lng:27.47});
  assert.match(q.textQuery,/Ореха.*Богориди/);
  search.places=[{id:placeID}]; fire(search,'gmp-load');
  assert.equal(d.querySelector('gmp-place-details'),null);
  assert.equal(messages.some(x=>x.event==='match'),false);
});
test('selection opens official review component, saves only ID after successful load',async t=>{
  const {d,fire,messages}=await page(t);
  fire(d.querySelector('gmp-place-search'),'gmp-select',{place:{id:placeID}});
  assert.equal(d.querySelector('gmp-place-details-place-request').place,placeID);
  assert.ok(d.querySelector('gmp-place-details gmp-place-reviews'));
  assert.equal(messages.some(x=>x.event==='match'),false);
  fire(d.querySelector('gmp-place-details'),'gmp-load');
  assert.deepEqual(messages.find(x=>x.event==='match'),{event:'match',placeID});
});
test('stored match opens directly and can be replaced',async t=>{
  const {d,messages}=await page(t,{place:placeID});
  assert.equal(d.querySelector('gmp-place-search'),null);
  assert.equal(d.querySelector('gmp-place-details-place-request').place,placeID);
  d.getElementById('change').click();
  assert.ok(d.querySelector('gmp-place-search'));
  assert.ok(messages.some(x=>x.event==='clearMatch'));
});
test('Google error exposes retry without blaming Wi-Fi or retaining a failed selection',async t=>{
  const {d,fire,messages}=await page(t);
  fire(d.querySelector('gmp-place-search'),'gmp-select',{place:{id:placeID}});
  fire(d.querySelector('gmp-place-details'),'gmp-error');
  assert.equal(d.getElementById('retry').hidden,false);
  assert.match(d.getElementById('status').textContent,/услугата или настройката/);
  assert.equal(messages.some(x=>x.event==='match'),false);
  const old=d.querySelector('gmp-place-details');d.getElementById('retry').click();
  assert.notEqual(d.querySelector('gmp-place-details'),old);
});
test('late events from a replaced search cannot overwrite current results',async t=>{
  const {d,fire}=await page(t);const old=d.querySelector('gmp-place-search');
  fire(old,'gmp-select',{place:{id:placeID}});fire(d.querySelector('gmp-place-details'),'gmp-load');
  fire(old,'gmp-error');
  assert.equal(d.getElementById('status').hidden,true);
});
test('no results leaves editable search and timeout exposes manual retry',async t=>{
  const {d,fire}=await page(t,{timeoutMS:5});
  await new Promise(resolve=>setTimeout(resolve,15));
  assert.equal(d.getElementById('retry').hidden,false);
  const search=d.querySelector('gmp-place-search');search.places=[];fire(search,'gmp-load');
  assert.match(d.getElementById('status').textContent,/Няма намерено/);
  assert.equal(d.getElementById('search-form').hidden,false);
});
test('restaurant names are text, not HTML',async t=>{
  const {d}=await page(t);d.getElementById('query').value='<img src=x onerror=alert(1)>';
  d.getElementById('search-form').dispatchEvent(new d.defaultView.Event('submit',{cancelable:true}));
  assert.equal(d.querySelector('img'),null);
});
