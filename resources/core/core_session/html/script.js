let characters = [];
let maxSlots = 3;
let currentSlot = null;

// Listen for messages from game
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'showCharacterSelector') {
        characters = data.characters || [];
        maxSlots = data.maxSlots || 3;
        showUI();
        renderCharacters();
    } else if (data.action === 'hide') {
        hideUI();
    } else if (data.action === 'refreshCharacters') {
        characters = data.characters || [];
        renderCharacters();
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

// Render characters
function renderCharacters() {
    const grid = document.getElementById('characterGrid');
    grid.innerHTML = '';
    
    // Create array of all slots
    const slots = [];
    for (let i = 1; i <= maxSlots; i++) {
        const char = characters.find(c => c.slot === i);
        slots.push(char || {slot: i, empty: true});
    }
    
    // Render each slot
    slots.forEach(slot => {
        const card = document.createElement('div');
        card.className = 'character-card';
        
        if (slot.empty) {
            card.classList.add('empty');
            card.innerHTML = `
                <div class="empty-icon">+</div>
                <div class="empty-text">Create New Character</div>
            `;
            card.onclick = () => openCreateModal(slot.slot);
        } else {
            const dob = new Date(slot.dob).toLocaleDateString();
            const lastPlayed = new Date(slot.last_played).toLocaleDateString();
            
            card.innerHTML = `
                <h3>${slot.firstname} ${slot.lastname}</h3>
                <div class="character-info">
                    <label>Citizen ID:</label>
                    <span>${slot.citizenid}</span>
                </div>
                <div class="character-info">
                    <label>Date of Birth:</label>
                    <span>${dob}</span>
                </div>
                <div class="character-info">
                    <label>Gender:</label>
                    <span>${slot.gender}</span>
                </div>
                <div class="character-info">
                    <label>Last Played:</label>
                    <span>${lastPlayed}</span>
                </div>
                <div class="character-actions">
                    <button class="btn btn-primary" onclick="selectCharacter('${slot.citizenid}')">Select</button>
                    <button class="btn btn-danger" onclick="deleteCharacter(${slot.slot}, event)">Delete</button>
                </div>
            `;
        }
        
        grid.appendChild(card);
    });
}

// Select character
function selectCharacter(citizenid) {
    fetch(`https://${GetParentResourceName()}/selectCharacter`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({citizenid: citizenid})
    }).then(resp => resp.json()).then(data => {
        if (!data.success) {
            alert(data.message || 'Failed to select character');
        }
    });
}

// Delete character
function deleteCharacter(slot, event) {
    event.stopPropagation();
    
    if (!confirm('Are you sure you want to delete this character? This action cannot be undone.')) {
        return;
    }
    
    fetch(`https://${GetParentResourceName()}/deleteCharacter`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({slot: slot})
    }).then(resp => resp.json()).then(data => {
        if (!data.success) {
            alert(data.message || 'Failed to delete character');
        }
    });
}

// Open create modal
function openCreateModal(slot) {
    currentSlot = slot;
    document.getElementById('createModal').style.display = 'flex';
}

// Close create modal
function closeCreateModal() {
    currentSlot = null;
    document.getElementById('createModal').style.display = 'none';
    document.getElementById('createForm').reset();
}

// Handle create form submission
document.getElementById('createForm').addEventListener('submit', function(e) {
    e.preventDefault();
    
    const firstname = document.getElementById('firstname').value;
    const lastname = document.getElementById('lastname').value;
    const dob = document.getElementById('dob').value;
    const gender = document.getElementById('gender').value;
    
    fetch(`https://${GetParentResourceName()}/createCharacter`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            slot: currentSlot,
            charData: {
                firstname: firstname,
                lastname: lastname,
                dob: dob,
                gender: gender
            }
        })
    }).then(resp => resp.json()).then(data => {
        if (data.success) {
            closeCreateModal();
        } else {
            alert(data.message || 'Failed to create character');
        }
    });
});

// Get parent resource name
function GetParentResourceName() {
    return window.location.hostname === '' ? 'core_session' : window.location.hostname;
}

// Close on ESC key
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && document.getElementById('createModal').style.display === 'flex') {
        closeCreateModal();
    }
});
