function renderAdminBroadcast(app) {
    state.broadcastPhotoFile = null;
    app.innerHTML = '<h2>Рассылка</h2><div class="form-group"><label>Текст</label><textarea id="btext"></textarea></div><div class="form-group"><label>Фото</label><input type="file" id="bphoto_input" accept="image/*" style="display:none" onchange="onBroadcastPhotoSelected(this)"><button class="btn-photo" onclick="document.getElementById(\'bphoto_input\').click()">📷 Прикрепить фото</button><span class="file-selected" id="bphoto_name"></span></div><button class="btn-send" style="width:100%" onclick="sendBroadcast()">📢 Отправить всем</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
}

function onBroadcastPhotoSelected(input) {
    if (input.files && input.files[0]) {
        state.broadcastPhotoFile = input.files[0];
        document.getElementById('bphoto_name').textContent = '✅ ' + input.files[0].name;
    }
}

async function sendBroadcast() {
    const text = document.getElementById('btext').value;
    if (!text && !state.broadcastPhotoFile) { tg?.showAlert?.('Введите текст или прикрепите фото'); return; }
    let photoPath = null;
    if (state.broadcastPhotoFile) { const upRes = await uploadPhoto(state.broadcastPhotoFile); if (upRes.ok) photoPath = upRes.path; }
    const res = await api('/api/admin/broadcast', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, text: text || '', photo_path: photoPath }) });
    if (res.ok) { tg?.showAlert?.(`Отправлено: ${res.sent}, ошибок: ${res.failed}`); rn('menu'); }
    else { tg?.showAlert?.('Ошибка'); }
}
