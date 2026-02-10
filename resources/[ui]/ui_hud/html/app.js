/* ============================================================
   JCRP HUD NUI Logic
   ============================================================ */

window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'show':
            document.getElementById('hud').classList.remove('hidden');
            break;

        case 'hide':
            document.getElementById('hud').classList.add('hidden');
            break;

        case 'update':
            updateHud(data.data);
            break;

        case 'notification':
            showNotification(data.message, data.type || 'info');
            break;
    }
});

function updateHud(d) {
    if (!d) return;

    // Money
    if (d.money) {
        setText('cash-value', '$' + formatNumber(d.money.cash || 0));
        setText('bank-value', '$' + formatNumber(d.money.bank || 0));
    }

    // Status bars
    if (d.health !== undefined) {
        setBarHeight('health-fill', Math.max(0, d.health));
    }
    if (d.armor !== undefined) {
        setBarHeight('armor-fill', d.armor);
        toggleElement('armor-bar', d.armor > 0);
    }
    if (d.status) {
        setBarHeight('hunger-fill', d.status.hunger || 0);
        setBarHeight('thirst-fill', d.status.thirst || 0);

        // Color coding when low
        setBarWarning('hunger-fill', d.status.hunger < 25);
        setBarWarning('thirst-fill', d.status.thirst < 25);
    }

    // Location
    if (d.location) {
        let streetText = d.location.street || '';
        if (d.location.cross) {
            streetText += ' / ' + d.location.cross;
        }
        setText('street-name', streetText);
        setText('area-name', d.location.area || '');
    }

    // Job
    if (d.job) {
        setText('job-label', (d.job.label || 'None') + (d.job.grade_label ? ' - ' + d.job.grade_label : ''));
        const badge = document.getElementById('duty-badge');
        if (d.job.duty) {
            badge.classList.remove('hidden');
        } else {
            badge.classList.add('hidden');
        }
    }

    // Speed
    if (d.speed !== undefined && d.speed > 0) {
        document.getElementById('speed-display').classList.remove('hidden');
        setText('speed-value', d.speed.toString());
    } else {
        document.getElementById('speed-display').classList.add('hidden');
    }
}

// ---- Notifications ----
function showNotification(message, type) {
    const container = document.getElementById('notification-container');
    const notif = document.createElement('div');
    notif.className = 'notification ' + type;
    notif.textContent = message;
    container.appendChild(notif);

    setTimeout(function() {
        if (notif.parentNode) {
            notif.parentNode.removeChild(notif);
        }
    }, 4000);
}

// ---- Helpers ----
function setText(id, text) {
    const el = document.getElementById(id);
    if (el) el.textContent = text;
}

function setBarHeight(id, value) {
    const el = document.getElementById(id);
    if (el) el.style.height = Math.max(0, Math.min(100, value)) + '%';
}

function setBarWarning(id, isWarning) {
    const el = document.getElementById(id);
    if (!el) return;
    if (isWarning) {
        el.style.animation = 'pulse 1s infinite';
    } else {
        el.style.animation = '';
    }
}

function toggleElement(id, show) {
    const el = document.getElementById(id);
    if (el) {
        if (show) el.classList.remove('hidden');
        else el.classList.add('hidden');
    }
}

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}
