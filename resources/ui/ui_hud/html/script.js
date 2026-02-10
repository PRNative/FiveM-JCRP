// Format number with commas
function formatMoney(amount) {
    return '$' + amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

// Listen for messages from game
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'show') {
        document.getElementById('hud').style.display = 'block';
    } else if (data.action === 'hide') {
        document.getElementById('hud').style.display = 'none';
    } else if (data.action === 'update') {
        updateHUD(data.data);
    } else if (data.action === 'updateVitals') {
        updateVitals(data.health, data.armor);
    }
});

// Update HUD
function updateHUD(hudData) {
    // Update money
    if (hudData.money) {
        document.getElementById('cash').textContent = formatMoney(hudData.money.cash || 0);
        document.getElementById('bank').textContent = formatMoney(hudData.money.bank || 0);
    }
    
    // Update job
    if (hudData.job) {
        document.getElementById('jobTitle').textContent = hudData.job.label || 'Unemployed';
        document.getElementById('jobGrade').textContent = hudData.job.grade_label || '';
        
        const dutyElement = document.getElementById('jobDuty');
        if (hudData.job.duty) {
            dutyElement.style.display = 'block';
        } else {
            dutyElement.style.display = 'none';
        }
    }
    
    // Update status
    if (hudData.status) {
        const hunger = hudData.status.hunger || 100;
        const thirst = hudData.status.thirst || 100;
        const stress = hudData.status.stress || 0;
        
        document.getElementById('hungerBar').style.width = hunger + '%';
        document.getElementById('hunger').textContent = Math.round(hunger) + '%';
        
        document.getElementById('thirstBar').style.width = thirst + '%';
        document.getElementById('thirst').textContent = Math.round(thirst) + '%';
        
        document.getElementById('stressBar').style.width = stress + '%';
        document.getElementById('stress').textContent = Math.round(stress) + '%';
    }
    
    // Update location
    if (hudData.location) {
        document.getElementById('street').textContent = hudData.location.street || 'Unknown';
        document.getElementById('area').textContent = hudData.location.area || 'San Andreas';
    }
}

// Update vitals
function updateVitals(health, armor) {
    document.getElementById('healthBar').style.width = health + '%';
    document.getElementById('armorBar').style.width = armor + '%';
}
