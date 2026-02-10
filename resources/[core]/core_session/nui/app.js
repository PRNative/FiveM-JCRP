/* ============================================================
   JCRP Character Selection NUI
   ============================================================ */

let characters = [];
let deleteSlot = null;

// ---- NUI Message Listener ----
window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'open':
            document.getElementById('app').classList.remove('hidden');
            break;

        case 'close':
            document.getElementById('app').classList.add('hidden');
            break;

        case 'updateCharacters':
            characters = data.characters || [];
            renderCharacters();
            break;

        case 'createResult':
            if (data.success) {
                closeCreateModal();
                showMessage('Character created successfully!', 'success');
            } else {
                showMessage(data.message || 'Failed to create character.', 'error');
            }
            break;

        case 'deleteResult':
            closeDeleteModal();
            if (data.success) {
                showMessage('Character deleted.', 'success');
            } else {
                showMessage(data.message || 'Failed to delete character.', 'error');
            }
            break;

        case 'showError':
            showMessage(data.message, 'error');
            break;
    }
});

// ---- Render Character Cards ----
function renderCharacters() {
    for (let slot = 1; slot <= 3; slot++) {
        const card = document.getElementById('slot-' + slot);
        const char = characters.find(c => c.slot === slot);

        if (char) {
            card.innerHTML = renderFilledCard(slot, char);
            card.onclick = null; // Remove create handler
        } else {
            card.innerHTML = renderEmptyCard(slot);
            card.onclick = function() { openCreateModal(slot); };
        }
    }
}

function renderFilledCard(slot, char) {
    const gender = char.gender === 0 ? 'Male' : 'Female';
    const lastPlayed = char.last_played ? new Date(char.last_played).toLocaleDateString() : 'Never';

    return `
        <div class="card-header">
            <span class="slot-number">SLOT ${slot}</span>
        </div>
        <div class="card-body">
            <div class="char-name">${escapeHtml(char.firstname)} ${escapeHtml(char.lastname)}</div>
            <div class="char-info">DOB: <span>${escapeHtml(char.dob || 'N/A')}</span></div>
            <div class="char-info">Gender: <span>${gender}</span></div>
            <div class="char-info">Last Played: <span>${lastPlayed}</span></div>
            <div class="char-citizenid">${escapeHtml(char.citizenid)}</div>
            <div class="card-actions">
                <button class="btn btn-primary btn-sm btn-play" onclick="selectCharacter('${escapeHtml(char.citizenid)}')">Play</button>
                <button class="btn btn-danger btn-sm btn-delete" onclick="confirmDelete(${slot}, '${escapeHtml(char.firstname)} ${escapeHtml(char.lastname)}')">Delete</button>
            </div>
        </div>
    `;
}

function renderEmptyCard(slot) {
    return `
        <div class="card-header">
            <span class="slot-number">SLOT ${slot}</span>
        </div>
        <div class="card-body empty-slot">
            <div class="empty-icon">+</div>
            <p>Create Character</p>
        </div>
    `;
}

// ---- Actions ----
function selectCharacter(citizenid) {
    fetch('https://core_session/selectCharacter', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ citizenid: citizenid }),
    });
}

function openCreateModal(slot) {
    document.getElementById('create-slot').value = slot;
    document.getElementById('firstname').value = '';
    document.getElementById('lastname').value = '';
    document.getElementById('dob').value = '1990-01-01';
    document.getElementById('gender').value = '0';
    document.getElementById('backstory').value = '';
    document.getElementById('create-modal').classList.remove('hidden');
}

function closeCreateModal() {
    document.getElementById('create-modal').classList.add('hidden');
}

function submitCreate() {
    const slot = parseInt(document.getElementById('create-slot').value);
    const firstname = document.getElementById('firstname').value.trim();
    const lastname = document.getElementById('lastname').value.trim();
    const dob = document.getElementById('dob').value;
    const gender = parseInt(document.getElementById('gender').value);
    const backstory = document.getElementById('backstory').value.trim();

    if (!firstname || !lastname) {
        showMessage('First name and last name are required.', 'error');
        return;
    }

    if (firstname.length < 2 || lastname.length < 2) {
        showMessage('Names must be at least 2 characters.', 'error');
        return;
    }

    fetch('https://core_session/createCharacter', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            slot: slot,
            firstname: firstname,
            lastname: lastname,
            dob: dob,
            gender: gender,
            backstory: backstory,
        }),
    });
}

function confirmDelete(slot, name) {
    deleteSlot = slot;
    document.getElementById('delete-confirm-text').innerText =
        `Are you sure you want to delete "${name}"? This action cannot be undone. All character data will be permanently lost.`;
    document.getElementById('delete-modal').classList.remove('hidden');

    document.getElementById('confirm-delete-btn').onclick = function() {
        fetch('https://core_session/deleteCharacter', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ slot: deleteSlot }),
        });
    };
}

function closeDeleteModal() {
    document.getElementById('delete-modal').classList.add('hidden');
    deleteSlot = null;
}

// ---- Utilities ----
function showMessage(text, type) {
    const bar = document.getElementById('message-bar');
    bar.innerText = text;
    bar.className = 'message-bar ' + type;
    bar.classList.remove('hidden');

    setTimeout(function() {
        bar.classList.add('hidden');
    }, 4000);
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.appendChild(document.createTextNode(text));
    return div.innerHTML;
}

// ---- Keyboard close (ESC) ----
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        if (!document.getElementById('create-modal').classList.contains('hidden')) {
            closeCreateModal();
        } else if (!document.getElementById('delete-modal').classList.contains('hidden')) {
            closeDeleteModal();
        }
        // Don't allow closing main UI with ESC — player must select a character
    }
});
