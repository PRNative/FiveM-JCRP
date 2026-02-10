/* JCRP Banking UI */
window.addEventListener('message', function(e) {
    const d = e.data;
    if (d.action === 'open') document.getElementById('app').classList.remove('hidden');
    if (d.action === 'close') document.getElementById('app').classList.add('hidden');
    if (d.action === 'updateData') {
        if (d.balances) {
            document.getElementById('cash-balance').textContent = '$' + fmt(d.balances.cash || 0);
            document.getElementById('bank-balance').textContent = '$' + fmt(d.balances.bank || 0);
        }
        if (d.ledger) renderLedger(d.ledger);
    }
});

function renderLedger(entries) {
    const list = document.getElementById('ledger-list');
    if (!entries || entries.length === 0) {
        list.innerHTML = '<p class="empty-ledger">No transactions yet.</p>';
        return;
    }
    list.innerHTML = entries.map(function(e) {
        const isPositive = e.amount >= 0;
        const date = e.created_at ? new Date(e.created_at).toLocaleString() : '';
        return '<div class="ledger-row">' +
            '<span class="ledger-reason">' + esc(e.reason || 'N/A') + '</span>' +
            '<span class="ledger-amount ' + (isPositive ? 'positive' : 'negative') + '">' +
            (isPositive ? '+' : '') + '$' + fmt(Math.abs(e.amount)) + '</span>' +
            '<span class="ledger-date">' + esc(date) + '</span>' +
            '</div>';
    }).join('');
}

function deposit() {
    const amount = document.getElementById('dw-amount').value;
    if (!amount || amount <= 0) return;
    fetch('https://system_banking_ui/deposit', { method: 'POST', body: JSON.stringify({ amount: amount }) });
    document.getElementById('dw-amount').value = '';
}

function withdraw() {
    const amount = document.getElementById('dw-amount').value;
    if (!amount || amount <= 0) return;
    fetch('https://system_banking_ui/withdraw', { method: 'POST', body: JSON.stringify({ amount: amount }) });
    document.getElementById('dw-amount').value = '';
}

function transfer() {
    const target = document.getElementById('transfer-target').value;
    const amount = document.getElementById('transfer-amount').value;
    if (!target || !amount || amount <= 0) return;
    fetch('https://system_banking_ui/transfer', { method: 'POST', body: JSON.stringify({ target: target, amount: amount }) });
    document.getElementById('transfer-target').value = '';
    document.getElementById('transfer-amount').value = '';
}

function closeBank() {
    fetch('https://system_banking_ui/closeBank', { method: 'POST', body: JSON.stringify({}) });
}

function fmt(n) { return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
function esc(t) { if (!t) return ''; const d = document.createElement('div'); d.appendChild(document.createTextNode(t)); return d.innerHTML; }

document.addEventListener('keydown', function(e) { if (e.key === 'Escape') closeBank(); });
