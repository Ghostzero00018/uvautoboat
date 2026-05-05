// Cache-bust: always load the latest app.js
const s = document.createElement('script');
s.src = 'app.js?v=' + Date.now();
document.body.appendChild(s);
