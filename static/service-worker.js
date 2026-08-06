const CACHE = 'nexo-shell-v2';
const ASSETS = ['/static/style.css', '/static/theme-refresh.css', '/static/security.js', '/static/icons/nexo.svg'];
self.addEventListener('install', (event) => event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(ASSETS))));
self.addEventListener('activate', (event) => event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))));
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET' || !new URL(event.request.url).pathname.startsWith('/static/')) return;
  event.respondWith(caches.match(event.request).then((cached) => cached || fetch(event.request)));
});
