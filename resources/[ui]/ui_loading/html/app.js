/* ============================================================
   JCRP Loading Screen Logic
   ============================================================ */

let config = {
    serverName: 'JCRP',
    serverTagline: 'Premium Roleplay Experience',
    tips: ['Welcome to the server!'],
    tipInterval: 6000,
};

let currentTip = 0;
let tipTimer = null;

// Load config
fetch('config.json')
    .then(r => r.json())
    .then(function(data) {
        config = Object.assign(config, data);
        init();
    })
    .catch(function() {
        init();
    });

function init() {
    // Set server name
    document.getElementById('server-name').textContent = config.serverName;
    document.getElementById('tagline').textContent = config.serverTagline;

    // Set background image if provided
    if (config.backgroundUrl) {
        const bg = document.getElementById('background');
        bg.style.backgroundImage = 'url(' + config.backgroundUrl + ')';
        bg.style.backgroundSize = 'cover';
        bg.style.backgroundPosition = 'center';
        bg.style.animation = 'none';
    }

    // Start tips rotation
    if (config.showTips && config.tips && config.tips.length > 0) {
        showTip();
        tipTimer = setInterval(nextTip, config.tipInterval);
    }
}

function showTip() {
    const tipEl = document.getElementById('tip-text');
    tipEl.style.opacity = '0';
    setTimeout(function() {
        tipEl.textContent = config.tips[currentTip];
        tipEl.style.opacity = '1';
    }, 300);
}

function nextTip() {
    currentTip = (currentTip + 1) % config.tips.length;
    showTip();
}

// ---- FiveM Loading Screen Events ----
const handlers = {
    startInitFunction(data) {
        updateProgress(data.type === 'MAP' ? 'Loading map...' : 'Initializing...', 10);
    },

    startInitFunctionOrder(data) {
        updateProgress('Loading game data...', 20 + (data.order || 0));
    },

    initFunctionInvoking(data) {
        updateProgress('Invoking: ' + (data.name || '...'), Math.min(40 + (data.idx || 0) * 2, 70));
    },

    startDataFileEntries(data) {
        updateProgress('Loading data files...', 75);
    },

    performMapLoadFunction(data) {
        updateProgress('Loading map...', 80);
    },

    onDataFileEntry(data) {
        updateProgress('Processing: ' + (data.name || '...'), 85);
    },

    onLogLine(data) {
        updateProgress(data.message || 'Loading...', null);
    },

    loadProgress(data) {
        const pct = Math.round((data.loadFraction || 0) * 100);
        updateProgress('Loading game...', pct);
    },
};

window.addEventListener('message', function(event) {
    const data = event.data;
    if (data && data.eventName && handlers[data.eventName]) {
        handlers[data.eventName](data);
    }
});

function updateProgress(text, percent) {
    if (text) {
        document.getElementById('progress-text').textContent = text;
    }
    if (percent !== null && percent !== undefined) {
        percent = Math.min(Math.max(percent, 0), 100);
        document.getElementById('progress-fill').style.width = percent + '%';
        document.getElementById('progress-percent').textContent = percent + '%';
    }
}

// Simulate minimal progress if no events come in
let simProgress = 0;
const simTimer = setInterval(function() {
    if (simProgress < 30) {
        simProgress += Math.random() * 3;
        updateProgress(null, Math.round(simProgress));
    }
}, 2000);
