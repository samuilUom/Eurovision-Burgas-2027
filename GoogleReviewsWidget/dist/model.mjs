export function validPlaceID(value) { return typeof value === 'string' && /^[A-Za-z0-9_-]{10,255}$/.test(value); }
export function parseRequest(hash) {
  const p = new URLSearchParams(hash.replace(/^#/, ''));
  const name = (p.get('name') || '').trim().slice(0, 200);
  const address = (p.get('address') || '').trim().slice(0, 500);
  const lat = Number(p.get('lat')), lng = Number(p.get('lng'));
  if (!name || !p.get('lat') || !p.get('lng') || !Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
  return { name, address, lat, lng, placeID: validPlaceID(p.get('place')) ? p.get('place') : null };
}
export function searchQuery(request) { return [request.name, request.address, 'Бургас, България'].filter(Boolean).join(', '); }

export async function loadGoogle(document, window, apiKey) {
  if (window.google?.maps?.importLibrary) { await window.google.maps.importLibrary('places'); return; }
  await new Promise((resolve, reject) => {
    window.__restaurantGoogleReady = resolve;
    window.gm_authFailure = () => reject(new Error('google-configuration'));
    const script = document.createElement('script');
    const url = new URL('https://maps.googleapis.com/maps/api/js');
    url.search = new URLSearchParams({ key: apiKey, v: 'weekly', libraries: 'places', loading: 'async', language: 'bg', region: 'BG', callback: '__restaurantGoogleReady' }).toString();
    script.src = url.href; script.async = true;
    script.onerror = () => reject(new Error('google-unavailable'));
    document.head.append(script);
  });
  await window.google.maps.importLibrary('places');
}
