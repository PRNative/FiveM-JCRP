/* ============================================================
   JCRP Spawn Selection NUI
   ============================================================ */

const typeIcons = {
    'last_location': '📍',
    'predefined': '🏙️',
    'apartment': '🏠',
    'default': '✈️',
};

const typeLabels = {
    'last_location': 'Last Location',
    'predefined': 'Spawn Point',
    'apartment': 'Your Property',
    'default': 'Default',
};

window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'open':
            document.getElementById('app').classList.remove('hidden');
            break;

        case 'close':
            document.getElementById('app').classList.add('hidden');
            break;

        case 'updateOptions':
            renderOptions(data.options || []);
            break;
    }
});

function renderOptions(options) {
    const container = document.getElementById('spawn-options');
    container.innerHTML = '';

    options.forEach(function(opt) {
        const div = document.createElement('div');
        div.className = 'spawn-option' + (opt.type === 'last_location' ? ' last-location' : '');
        div.onclick = function() { selectSpawn(opt.id); };

        const icon = typeIcons[opt.type] || '📍';
        const typeLabel = typeLabels[opt.type] || opt.type;

        div.innerHTML = `
            <div class="option-icon">${icon}</div>
            <div class="option-label">${escapeHtml(opt.label)}</div>
            <div class="option-desc">${escapeHtml(opt.description || '')}</div>
            <span class="option-type type-${opt.type}">${typeLabel}</span>
        `;

        container.appendChild(div);
    });
}

function selectSpawn(id) {
    fetch('https://core_spawn/selectSpawn', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: id }),
    });
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.appendChild(document.createTextNode(text));
    return div.innerHTML;
}

// ESC to close — fallback to first option
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        fetch('https://core_spawn/closeSpawnUI', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({}),
        });
    }
});
