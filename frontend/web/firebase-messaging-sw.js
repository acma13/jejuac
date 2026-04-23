importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

// 새 버전이 발견되면 즉시 이전 버전을 쫓아내고 자리를 잡게 합니다.
self.addEventListener('install', (event) => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(clients.claim()));

firebase.initializeApp({
  apiKey: "AIzaSyDqlq-OTIY9jltHYRsSdxEXYKNOXUJCqcw",
  authDomain: "jejuac-a34ad.firebaseapp.com",
  projectId: "jejuac-a34ad",
  storageBucket: "jejuac-a34ad.firebasestorage.app",
  messagingSenderId: "311343930573",
  appId: "1:311343930573:web:c0eecb63f7c543ea0bdd84"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[sw.js] 수신된 전체 페이로드:', payload);

  // 1. 데이터 추출 (가장 확실한 경로)
  // data로 보냈을 때와 notification으로 보냈을 때를 모두 대응합니다.
  const title = payload.data?.title || payload.notification?.title || "제주양궁클럽";
  const body = payload.data?.body || payload.notification?.body || "새 알림이 있습니다.";

  // 2. 브라우저에게 알림 표시를 '약속(Promise)'합니다.
  // 이 return이 없으면 브라우저가 "업데이트되었습니다"라는 기본 문구를 띄웁니다.
  return self.registration.showNotification(title, {
    body: body,
    icon: '/icons/bow-and-arrow.png',
    tag: 'jejuac-notification', // 알림이 쌓이지 않고 교체되게 함
    renotify: true
  });
});