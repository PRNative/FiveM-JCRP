window.addEventListener('message', (e) => {
  const { action, cash, bank, hunger, thirst, stress, job, street } = e.data || {};
  if (action === 'show') {
    document.getElementById('hud').classList.remove('hidden');
  } else if (action === 'hide') {
    document.getElementById('hud').classList.add('hidden');
  } else if (action === 'update') {
    if (cash !== undefined) document.getElementById('cash').textContent = formatMoney(cash);
    if (bank !== undefined) document.getElementById('bank').textContent = formatMoney(bank);
    if (hunger !== undefined) document.getElementById('hunger').textContent = hunger;
    if (thirst !== undefined) document.getElementById('thirst').textContent = thirst;
    if (stress !== undefined) document.getElementById('stress').textContent = stress;
    if (job !== undefined) document.getElementById('jobDisplay').textContent = job;
    if (street !== undefined) document.getElementById('streetDisplay').textContent = street;
  }
});

function formatMoney(n) {
  return (n || 0).toLocaleString();
}
