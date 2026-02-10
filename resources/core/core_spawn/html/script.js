let spawnOptions = [];

// Listen for messages from game
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'showSpawnSelector') {
        spawnOptions = data.options || [];
        showUI();
        renderSpawnOptions();
    } else if (data.action === 'hide') {
        hideUI();
    }
});

// Show UI
function showUI() {
    document.getElementById('app').style.display = 'flex';
}

// Hide UI
function hideUI() {
    document.getElementById('app').style.display = 'none';
}

// Render spawn options
function renderSpawnOptions() {
    const list = document.getElementById('spawnList');
    list.innerHTML = '';
    
    spawnOptions.forEach(option => {
        const div = document.createElement('div');
        div.className = 'spawn-option';
        
        let icon = '📍';
        if (option.type === 'last') {
            icon = '🏁';
        } else if (option.type === 'apartment') {
            icon = '🏠';
        } else if (option.type === 'default') {
            icon = '⭐';
        }
        
        div.innerHTML = `
            <div class="spawn-info">
                <h3>${option.label}</h3>
                <div class="spawn-type">${option.type}</div>
            </div>
            <div class="spawn-icon">${icon}</div>
        `;
        
        div.onclick = () => selectSpawn(option);
        
        list.appendChild(div);
    });
}

// Select spawn
function selectSpawn(option) {
    fetch(`https://${GetParentResourceName()}/selectSpawn`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            coords: option.coords,
            heading: option.heading
        })
    }).then(resp => resp.json()).then(data => {
        if (!data.success) {
            alert(data.message || 'Failed to spawn');
        }
    });
}

// Get parent resource name
function GetParentResourceName() {
    return window.location.hostname === '' ? 'core_spawn' : window.location.hostname;
}
