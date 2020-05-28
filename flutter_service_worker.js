'use strict';
const CACHE_NAME = 'flutter-app-cache';
const RESOURCES = {
  "favicon.ico": "f3a7edfb4ae829180a54697ed795ca0d",
"index.html": "c37bda9144c75f224b40a0dcb944823c",
"/": "c37bda9144c75f224b40a0dcb944823c",
"main.dart.js": "ff72a004b3018469e5a7e5a43aa52100",
"icons/apple-touch-icon-120x120.png": "5b0adeb0adc831b2741a38e26a5a8edb",
"icons/android-touch-icon.png": "f92716bcd4f8db3df6dc11351264eee1",
"icons/apple-touch-icon-152x152.png": "6c397351d8600e2db895ec7d2f4d088c",
"icons/apple-touch-icon-180x180.png": "faf9ed7a21c7819fa1415e14975666df",
"icons/apple-touch-icon-76x76.png": "891c18d7ce87278179426207abf7b10f",
"manifest.json": "00c402e124c18c3463e88c98c125242d",
"assets/LICENSE": "d104fc572642a5c66fe865b10aead58b",
"assets/AssetManifest.json": "8bc4c635082ba94c66b2588314b48b55",
"assets/public/blogs.json": "ea90e4b8cc522b1730b701e49b22cc93",
"assets/public/MacOS%25E4%25BD%25BF%25E7%2594%25A8%25E6%258A%2580%25E5%25B7%25A7.html": "e0143d4b215cee644e7238440dc43d93",
"assets/public/%25E7%2590%2586%25E8%25A7%25A3%25E5%25BC%2582%25E6%25AD%25A5%25E7%25BC%2596%25E7%25A8%258B.html": "10ed380ef9488beb600b4ff5cf7c642b",
"assets/FontManifest.json": "580ff1a5d08679ded8fcf5c6848cece7",
"assets/packages/flutter_markdown/assets/logo.png": "67642a0b80f3d50277c44cde8f450e50",
"assets/fonts/MaterialIcons-Regular.ttf": "56d3ffdef7a25659eab6a68a3fbfaf16"
};

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (cacheName) {
      return caches.delete(cacheName);
    }).then(function (_) {
      return caches.open(CACHE_NAME);
    }).then(function (cache) {
      return cache.addAll(Object.keys(RESOURCES));
    })
  );
});

self.addEventListener('fetch', function (event) {
  event.respondWith(
    caches.match(event.request)
      .then(function (response) {
        if (response) {
          return response;
        }
        return fetch(event.request);
      })
  );
});
