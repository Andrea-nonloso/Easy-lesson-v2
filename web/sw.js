// Easy Lesson: funziona anche offline una volta aperta.
// Strategia: rete prima (così si vede sempre l'ultima versione), cache se non c'è connessione.
const CACHE = 'easylesson-v1';

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(['./', 'index.html', 'manifest.json', 'favicon.png', 'icons/Icon-192.png']).catch(() => {})));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  // Solo i file dell'app (e i font di Flutter); le chiamate al server restano normali.
  const same = url.origin === self.location.origin;
  const fonts = url.hostname === 'fonts.gstatic.com' || url.hostname === 'www.gstatic.com';
  if (!same && !fonts) return;
  e.respondWith(
    fetch(req)
      .then((res) => {
        if (res && res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy));
        }
        return res;
      })
      .catch(() => caches.match(req).then((hit) => hit || (req.mode === 'navigate' ? caches.match('index.html') : undefined)))
  );
});
