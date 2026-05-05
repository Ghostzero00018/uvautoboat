// Cache-bust: always load the latest CSS
const link = document.createElement('link');
link.rel = 'stylesheet';
link.href = 'style_merged.css?v=' + Date.now();
document.head.appendChild(link);
