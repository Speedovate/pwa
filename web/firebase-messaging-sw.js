// web/firebase-messaging-sw.js

importScripts("https://www.gstatic.com/firebasejs/9.6.10/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.6.10/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyA3tvPnJN8hy3HksAFLDkMHDAC6wMeXS-Q",
  authDomain: "toda-pal.firebaseapp.com",
  databaseURL: "https://toda-pal-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "toda-pal",
  storageBucket: "toda-pal.firebasestorage.app",
  messagingSenderId: "599344409686",
  appId: "1:599344409686:web:ae1f18c90ac11007675ff7"
});

self.addEventListener('push', function(event) {
  event.stopImmediatePropagation();

  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (error) {
    notifDebug('web sw push payload parse failed', { error: `${error}` });
  }

  event.waitUntil(showParsedNotification(payload));
});

const messaging = firebase.messaging();
const PWA_STATE_CACHE = 'pwa-notification-state';
const PWA_STATE_URL = '/__pwa_install_state__';
const standaloneClientIds = new Set();

function notifDebug(message, data) {}

function normalizeWhitespace(value) {
  const text = `${value ?? ''}`.replace(/\s+/g, ' ').trim();
  return text.toLowerCase() === 'null' ? '' : text;
}

function parseNotificationTitle(title) {
  const normalizedTitle = normalizeWhitespace(title).toLowerCase();
  if (normalizedTitle.includes('ride status update')) {
    notifDebug('web sw parse title matched ride status update', { raw: title });
    return 'Booking Update';
  }
  const parsed = normalizeWhitespace(title);
  notifDebug('web sw parse title unchanged', { raw: title, parsed });
  return parsed;
}

function parseNotificationBody(body) {
  const parsed = normalizeWhitespace(body).replace(/ride booking/gi, 'booking');
  notifDebug('web sw parse body', { raw: body, parsed });
  return parsed;
}

function notificationTitleFromPayload(payload) {
  return parseNotificationTitle(
    payload?.data?.title ?? payload?.notification?.title ?? ''
  );
}

function notificationBodyFromPayload(payload) {
  return parseNotificationBody(
    payload?.data?.body ?? payload?.notification?.body ?? ''
  );
}

function notificationTargetUrlFromPayload(payload) {
  return (
    payload?.data?.url ||
    payload?.data?.link ||
    payload?.fcmOptions?.link ||
    payload?.notification?.click_action ||
    '/'
  );
}

function notificationTagFromPayload(payload, title, body) {
  return (
    payload?.data?.notification_id ||
    payload?.data?.id ||
    payload?.messageId ||
    payload?.message_id ||
    `${title}:${body}`
  );
}

async function showParsedNotification(payload) {
  notifDebug('web sw receive push message', payload);
  const targetUrl = notificationTargetUrlFromPayload(payload);
  const title = notificationTitleFromPayload(payload);
  const body = notificationBodyFromPayload(payload);
  notifDebug('web sw parse result', { title, body });
  if (!title && !body) {
    notifDebug('web sw notification skipped empty title/body', payload);
    return;
  }
  notifDebug('web sw create notification', {
    title,
    body,
    targetUrl,
    data: payload?.data || {},
  });

  await self.registration.showNotification(
    title,
    {
      body,
      icon: "/icons/webiconsmall.png",
      badge: "/icons/notification-badge.png",
      tag: notificationTagFromPayload(payload, title, body),
      renotify: false,
      data: {
        url: new URL(targetUrl, self.location.origin).href,
      },
    }
  );
}

async function rememberPwaState(state) {
  const cache = await caches.open(PWA_STATE_CACHE);
  await cache.put(
    PWA_STATE_URL,
    new Response(JSON.stringify(state), {
      headers: {
        'content-type': 'application/json',
      },
    })
  );
}

async function readPwaState() {
  const cache = await caches.open(PWA_STATE_CACHE);
  const response = await cache.match(PWA_STATE_URL);
  if (!response) {
    return null;
  }

  try {
    return await response.json();
  } catch (_) {
    return null;
  }
}

function isSameOriginClient(client) {
  return typeof client?.url === 'string' && client.url.includes(self.location.origin);
}

async function focusClient(client, targetUrl) {
  if ('navigate' in client && client.url !== targetUrl) {
    await client.navigate(targetUrl);
  }
  if ('focus' in client) {
    return client.focus();
  }
  return client;
}

self.addEventListener('message', function(event) {
  const data = event.data;
  if (!data || data.type !== 'PWA_CLIENT_STATE') {
    return;
  }

  if (event.source?.id) {
    if (data.isStandalone) {
      standaloneClientIds.add(event.source.id);
    } else {
      standaloneClientIds.delete(event.source.id);
    }
  }

  event.waitUntil(
    rememberPwaState({
      installed: data.isInstalled === true,
      standalone: data.isStandalone === true,
      updatedAt: Date.now(),
    })
  );
});

self.addEventListener('notificationclick', function(event) {
  notifDebug('web sw notification click', event.notification?.data || {});
  event.notification.close();

  const targetUrl = event.notification?.data?.url || self.location.origin;

  event.waitUntil(
    Promise.all([
      clients.matchAll({ type: 'window', includeUncontrolled: true }),
      readPwaState(),
    ]).then(async function(results) {
      const clientList = results[0];
      const pwaState = results[1];

      const sameOriginClients = clientList.filter(isSameOriginClient);
      const standaloneClients = sameOriginClients.filter(function(client) {
        return standaloneClientIds.has(client.id);
      });

      for (const client of standaloneClients) {
        return focusClient(client, targetUrl);
      }

      if (pwaState?.installed && clients.openWindow) {
        const openedClient = await clients.openWindow(targetUrl);
        if (openedClient) {
          return openedClient;
        }
      }

      for (const client of sameOriginClients) {
        return focusClient(client, targetUrl);
      }

      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
