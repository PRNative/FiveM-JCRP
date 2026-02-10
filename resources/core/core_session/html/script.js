const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

let characters = [];
let maxSlots = 3;
let spawnOptions = [];

window.addEventListener('message', (e) => {
  const { action, characters: chars, maxSlots: slots, options, error } = e.data || {};
  if (action === 'showCharacterSelect') {
    characters = chars || [];
    maxSlots = slots || 3;
    $('#app').classList.remove('hidden');
    $('#spawn-select').classList.add('hidden');
    $('#create-modal').classList.add('hidden');
    $('#character-select').classList.remove('hidden');
    renderCharacterSlots();
  } else if (action === 'showSpawnSelect') {
    spawnOptions = options || [];
    $('#character-select').classList.add('hidden');
    $('#spawn-select').classList.remove('hidden');
    renderSpawnOptions();
  } else if (action === 'hide') {
    $('#app').classList.add('hidden');
  } else if (action === 'selectError' || action === 'createError') {
    console.error('Session error:', error);
    // Could show toast
  }
});

function renderCharacterSlots() {
  const container = $('#character-slots');
  container.innerHTML = '';
  for (let i = 1; i <= maxSlots; i++) {
    const char = characters.find((c) => c.slot === i);
    if (char) {
      const el = document.createElement('div');
      el.className = 'character-slot';
      el.innerHTML = `
        <div class="info">
          <div class="name">${escapeHtml(char.firstname)} ${escapeHtml(char.lastname)}</div>
          <div class="meta">${char.citizenid || ''} • Slot ${char.slot}</div>
        </div>
        <div class="actions">
          <button class="btn btn-primary" data-action="select" data-citizenid="${escapeHtml(char.citizenid)}">Select</button>
          <button class="btn btn-danger" data-action="delete" data-slot="${char.slot}">Delete</button>
        </div>
      `;
      el.querySelector('[data-action="select"]').addEventListener('click', () => {
        fetch(`https://${GetParentResourceName()}/selectCharacter`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ citizenid: char.citizenid }),
        }).then((r) => r.json());
      });
      el.querySelector('[data-action="delete"]').addEventListener('click', (ev) => {
        ev.stopPropagation();
        if (confirm('Delete this character? This cannot be undone.')) {
          fetch(`https://${GetParentResourceName()}/deleteCharacter`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ slot: char.slot }),
          }).then((r) => r.json());
        }
      });
      container.appendChild(el);
    } else {
      const el = document.createElement('div');
      el.className = 'slot-empty';
      el.textContent = `Slot ${i} - Create Character`;
      el.addEventListener('click', () => openCreateModal(i));
      container.appendChild(el);
    }
  }
}

function openCreateModal(slot) {
  $('#create-slot').value = slot;
  $('#firstname').value = '';
  $('#lastname').value = '';
  $('#dob').value = '';
  $('#create-modal').classList.remove('hidden');
}

function closeCreateModal() {
  $('#create-modal').classList.add('hidden');
}

$('#btn-create')?.addEventListener('click', () => {
  const firstEmpty = Array.from({ length: maxSlots }, (_, i) => i + 1).find(
    (s) => !characters.some((c) => c.slot === s)
  );
  openCreateModal(firstEmpty || 1);
});

$('#btn-cancel-create')?.addEventListener('click', closeCreateModal);

$('#create-form')?.addEventListener('submit', (e) => {
  e.preventDefault();
  const slot = parseInt($('#create-slot').value, 10);
  const charData = {
    firstname: $('#firstname').value.trim(),
    lastname: $('#lastname').value.trim(),
    dob: $('#dob').value.trim() || undefined,
  };
  fetch(`https://${GetParentResourceName()}/createCharacter`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ slot, charData }),
  }).then((r) => r.json());
  closeCreateModal();
});

function renderSpawnOptions() {
  const container = $('#spawn-options');
  container.innerHTML = '';
  spawnOptions.forEach((opt) => {
    const el = document.createElement('div');
    el.className = 'spawn-option';
    el.innerHTML = `<div class="label">${escapeHtml(opt.label || opt.id || 'Spawn')}</div>`;
    el.addEventListener('click', () => {
      fetch(`https://${GetParentResourceName()}/selectSpawn`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ optionId: opt.id }),
      }).then((r) => r.json());
    });
    container.appendChild(el);
  });
}

function escapeHtml(s) {
  if (!s) return '';
  const div = document.createElement('div');
  div.textContent = s;
  return div.innerHTML;
}

function GetParentResourceName() {
  return window.GetParentResourceName ? window.GetParentResourceName() : 'core_session';
}
