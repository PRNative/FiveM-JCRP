// Loading screen - no DB, config injected by FiveM or use defaults
document.getElementById('brandName').textContent = 'FiveM Platform';
document.getElementById('brandTagline').textContent = 'DB-First Roleplay';

let progress = 0;
const interval = setInterval(() => {
  progress += Math.random() * 15 + 5;
  if (progress >= 95) progress = 95;
  document.getElementById('progress').style.width = progress + '%';
  document.getElementById('status').textContent = progress < 30 ? 'Loading resources...' : progress < 60 ? 'Connecting...' : 'Almost ready...';
}, 300);

// FiveM will shut us down
window.addEventListener('message', (e) => {
  if (e.data && e.data.eventName === 'loadProgress' && e.data.loadFraction !== undefined) {
    document.getElementById('progress').style.width = (e.data.loadFraction * 100) + '%';
  }
});
