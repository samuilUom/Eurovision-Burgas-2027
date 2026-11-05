import { parseRequest, searchQuery, validPlaceID, loadGoogle } from './model.mjs';

export async function start({ document, window, fetchConfig, load = loadGoogle, timeoutMS = 25000 }) {
  const $ = id => document.getElementById(id);
  const status = $('status'), content = $('content'), form = $('search-form');
  const retry = $('retry'), change = $('change'), query = $('query');
  const request = parseRequest(window.location.hash);
  let generation = 0, timer, selectedID = request?.placeID, lastAction, googleReady = false;
  const bridge = (event, extras = {}) => window.webkit?.messageHandlers?.restaurantReviews?.postMessage({ event, ...extras });
  function message(text, kind = 'info') { status.textContent = text; status.dataset.kind = kind; status.hidden = false; }
  function done() { window.clearTimeout(timer); form.querySelector('button').disabled = false; bridge('ready'); }
  function fail(text) { done(); message(text, 'error'); retry.hidden = false; change.hidden = !selectedID; }
  function begin(text) {
    const token = ++generation; window.clearTimeout(timer); retry.hidden = true;
    message(text); form.querySelector('button').disabled = true;
    timer = window.setTimeout(() => { if (token === generation) fail('Зареждането отнема твърде дълго. Опитай отново.'); }, timeoutMS);
    return token;
  }
  function googleError() {
    fail(window.navigator.onLine === false ? 'Няма връзка с интернет. Опитай отново, когато се свържеш.' : 'Google не успя да зареди данните. Възможен е проблем с услугата или настройката ѝ.');
  }
  function configElement(tags) {
    const config = document.createElement('gmp-place-content-config');
    tags.forEach(tag => config.append(document.createElement(tag)));
    return config;
  }
  function showDetails(id, remember = false) {
    if (!validPlaceID(id)) return;
    lastAction = () => showDetails(id, remember);
    selectedID = id; form.hidden = true; change.hidden = false;
    const token = begin('Зареждаме Google ревютата…');
    const details = document.createElement('gmp-place-details');
    const place = document.createElement('gmp-place-details-place-request');
    place.place = id;
    details.append(place, configElement(['gmp-place-address', 'gmp-place-rating', 'gmp-place-reviews']));
    details.addEventListener('gmp-load', () => {
      if (token !== generation) return;
      done(); status.hidden = true; retry.hidden = true;
      if (remember) bridge('match', { placeID: id });
    });
    details.addEventListener('gmp-error', () => { if (token === generation) googleError(); });
    content.replaceChildren(details);
  }
  function search() {
    const text = query.value.trim();
    if (!text) { message('Въведи името на заведението.'); return; }
    lastAction = search; selectedID = null; change.hidden = true; form.hidden = false;
    const token = begin('Търсим същото заведение в Google…');
    const results = document.createElement('gmp-place-search'); results.selectable = true;
    const searchRequest = document.createElement('gmp-place-text-search-request');
    searchRequest.maxResultCount = 5;
    searchRequest.locationBias = { lat: request.lat, lng: request.lng };
    searchRequest.textQuery = text;
    results.append(searchRequest, configElement(['gmp-place-address', 'gmp-place-rating']));
    results.addEventListener('gmp-load', () => {
      if (token !== generation) return;
      done(); retry.hidden = true;
      message(results.places?.length ? 'Избери заведението с правилния адрес, за да видиш ревютата.' : 'Няма намерено съвпадение. Опитай с по-кратко име или поправи адреса.');
    });
    results.addEventListener('gmp-select', event => {
      if (token === generation && validPlaceID(event.place?.id)) showDetails(event.place.id, true);
    });
    results.addEventListener('gmp-error', () => { if (token === generation) googleError(); });
    content.replaceChildren(results);
  }
  async function boot() {
    if (!request) { message('Отвори заведение в приложението и избери „Ревюта от Google“.'); bridge('ready'); return; }
    const token = begin('Свързваме се с Google…'); lastAction = boot;
    try {
      const config = await fetchConfig();
      if (token !== generation) return;
      if (config.enabled !== true || typeof config.apiKey !== 'string' || !config.apiKey.startsWith('AIza')) {
        done(); message('Google ревютата още не са активирани. Ревютата от посетители на приложението остават достъпни.'); return;
      }
      await load(document, window, config.apiKey);
      if (token !== generation) return;
      googleReady = true; done();
      window.gm_authFailure = googleError;
      if (selectedID) showDetails(selectedID); else search();
    } catch { if (token === generation) googleError(); }
  }
  if (request) {
    $('restaurant-name').textContent = request.name;
    $('restaurant-address').textContent = request.address;
    query.value = searchQuery(request);
  }
  form.addEventListener('submit', event => { event.preventDefault(); if (googleReady) search(); });
  retry.addEventListener('click', () => lastAction?.());
  change.addEventListener('click', () => { selectedID = null; bridge('clearMatch'); if (googleReady) search(); else boot(); });
  window.addEventListener('pagehide', () => { ++generation; window.clearTimeout(timer); });
  await boot();
}

if (typeof document !== 'undefined') {
  void start({ document, window, fetchConfig: async () => {
    const response = await fetch('./config.json', { cache: 'no-store', credentials: 'omit' });
    if (!response.ok) throw new Error('configuration-unavailable');
    return response.json();
  } });
}
