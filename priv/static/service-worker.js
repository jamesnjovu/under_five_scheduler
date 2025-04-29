// Cache names with version numbers to ensure proper updates
const CACHE_VERSION = 'v1';
const STATIC_CACHE = `under-five-static-${CACHE_VERSION}`;
const DYNAMIC_CACHE = `under-five-dynamic-${CACHE_VERSION}`;
const ASSETS_CACHE = `under-five-assets-${CACHE_VERSION}`;

// Resources that should be pre-cached
const STATIC_ASSETS = [
  '/',
  '/offline.html',
  '/assets/app.css',
  '/assets/app.js',
  '/images/icon-192.png',
  '/images/icon-512.png',
  '/images/maskable-icon.png',
  '/images/child-doctor1.png',
  '/images/healthcare-provider.png'
];

// Install event - pre-cache static resources
self.addEventListener('install', event => {
  console.log('[Service Worker] Installing Service Worker...', event);
  
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then(cache => {
        console.log('[Service Worker] Pre-caching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => {
        console.log('[Service Worker] Successfully pre-cached assets');
        return self.skipWaiting();
      })
      .catch(error => {
        console.error('[Service Worker] Pre-caching failed:', error);
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', event => {
  console.log('[Service Worker] Activating Service Worker...', event);
  
  event.waitUntil(
    caches.keys()
      .then(keyList => {
        return Promise.all(
          keyList.map(key => {
            // If the cache name doesn't match our current versions, delete it
            if (![STATIC_CACHE, DYNAMIC_CACHE, ASSETS_CACHE].includes(key)) {
              console.log('[Service Worker] Removing old cache:', key);
              return caches.delete(key);
            }
          })
        );
      })
      .then(() => {
        console.log('[Service Worker] Claiming clients for this service worker');
        return self.clients.claim();
      })
  );
});

// Fetch event - handle network requests with cache strategies
self.addEventListener('fetch', event => {
  // CRITICAL: Skip non-HTTP(S) requests completely (like chrome-extension://)
  if (!event.request.url.startsWith('http')) {
    console.log('[Service Worker] Skipping non-HTTP request:', event.request.url);
    return; // Don't call respondWith for non-HTTP requests
  }
  
  try {
    const url = new URL(event.request.url);
    
    // Handle API requests (network first, fall back to offline response)
    if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/live/')) {
      event.respondWith(networkFirstStrategy(event.request));
      return;
    }
    
    // Handle asset requests (cache first)
    if (
      url.pathname.startsWith('/assets/') ||
      url.pathname.startsWith('/images/') ||
      url.pathname.includes('.js') ||
      url.pathname.includes('.css')
    ) {
      event.respondWith(cacheFirstStrategy(event.request, ASSETS_CACHE));
      return;
    }
    
    // For HTML navigation requests, use network first
    if (event.request.mode === 'navigate') {
      event.respondWith(
        fetch(event.request)
          .catch(() => {
            return caches.match('/offline.html');
          })
      );
      return;
    }
    
    // Default to cache first for everything else (but only for HTTP requests)
    event.respondWith(cacheFirstStrategy(event.request, DYNAMIC_CACHE));
  } catch (error) {
    console.error('[Service Worker] Error in fetch handler:', error);
    // Don't attempt to handle this request
  }
});

// Cache-first strategy: try cache first, then network
async function cacheFirstStrategy(request, cacheName) {
  try {
    // Double-check we're only processing HTTP requests
    if (!request.url.startsWith('http')) {
      console.log('[Service Worker] Skipping non-HTTP URL in cacheFirstStrategy:', request.url);
      return fetch(request);
    }
    
    const cachedResponse = await caches.match(request);
    
    if (cachedResponse) {
      return cachedResponse;
    }
    
    const networkResponse = await fetch(request);
    
    // Only cache valid responses from HTTP/HTTPS requests
    if (
      networkResponse && 
      networkResponse.status === 200 &&
      networkResponse.type !== 'opaque'
    ) {
      try {
        const cache = await caches.open(cacheName);
        await cache.put(request, networkResponse.clone());
      } catch (cacheError) {
        console.error('[Service Worker] Cache put error:', cacheError, 'for URL:', request.url);
        // Continue even if caching fails
      }
    }
    
    return networkResponse;
  } catch (error) {
    console.error('[Service Worker] Fetch failed:', error, 'for URL:', request.url);
    
    // For image requests, you might want to return a fallback
    if (request.url.match(/\.(jpg|jpeg|png|gif|svg)$/)) {
      return caches.match('/images/fallback-image.png');
    }
    
    // Otherwise return nothing
    return new Response(null, { status: 404 });
  }
}

// Network-first strategy: try network first, then cache
async function networkFirstStrategy(request) {
  try {
    // Double-check we're only processing HTTP requests
    if (!request.url.startsWith('http')) {
      console.log('[Service Worker] Skipping non-HTTP URL in networkFirstStrategy:', request.url);
      return fetch(request);
    }
    
    const networkResponse = await fetch(request);
    
    // Cache the response for future if it's an HTTP request
    if (
      networkResponse && 
      networkResponse.status === 200 && 
      networkResponse.type !== 'opaque'
    ) {
      try {
        const cache = await caches.open(DYNAMIC_CACHE);
        await cache.put(request, networkResponse.clone());
      } catch (cacheError) {
        console.error('[Service Worker] Cache put error:', cacheError, 'for URL:', request.url);
        // Continue even if caching fails
      }
    }
    
    return networkResponse;
  } catch (error) {
    console.log('[Service Worker] Fetch failed, falling back to cache:', error, 'for URL:', request.url);
    
    try {
      const cachedResponse = await caches.match(request);
      
      if (cachedResponse) {
        return cachedResponse;
      }
      
      // If the request is for an API endpoint, return an offline JSON response
      if (request.url.includes('/api/')) {
        return new Response(
          JSON.stringify({ 
            error: true, 
            message: 'You are currently offline', 
            offline: true 
          }),
          { 
            status: 503,
            headers: { 'Content-Type': 'application/json' } 
          }
        );
      }
    } catch (cacheError) {
      console.error('[Service Worker] Cache match error:', cacheError);
    }
    
    // For other requests, return nothing
    return new Response(null, { status: 504 });
  }
}

// Handle push notifications
self.addEventListener('push', event => {
  console.log('[Service Worker] Push Notification received', event);

  let data = { title: 'New Notification', body: 'Something happened!', icon: '/images/icon-192.png' };
  
  if (event.data) {
    try {
      data = event.data.json();
    } catch (e) {
      data.body = event.data.text();
    }
  }

  const options = {
    body: data.body,
    icon: data.icon || '/images/icon-192.png',
    badge: '/images/icon-192.png',
    vibrate: [100, 50, 100],
    data: {
      openUrl: data.openUrl || '/'
    }
  };

  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});

// Handle notification clicks
self.addEventListener('notificationclick', event => {
  console.log('[Service Worker] Notification click received', event);

  event.notification.close();

  event.waitUntil(
    clients.matchAll({ type: 'window' })
      .then(clientList => {
        const url = event.notification.data.openUrl || '/';
        
        // If a window is already open, focus it
        for (const client of clientList) {
          if (client.url === url && 'focus' in client) {
            return client.focus();
          }
        }
        
        // Otherwise open a new window
        if (clients.openWindow) {
          return clients.openWindow(url);
        }
      })
  );
});