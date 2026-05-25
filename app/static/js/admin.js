function renderAdminStats(app) {
    app.innerHTML = '<h2>Статистика</h2><div id="st"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const s = state.stats || {};
    document.getElementById('st').innerHTML = `<div class="card"><div class="row"><span class="label">Записей сегодня:</span><span class="value">${s.today_bookings||0}</span></div><div class="row"><span class="label">Всего клиентов:</span><span class="value">${s.total_clients||0}</span></div><div class="row"><span class="label">Выручка сегодня:</span><span class="value green">${s.today_revenue||0}₽</span></div></div>`;
}

async function renderAdminToday(app) {
    app.innerHTML = '<h2>Записи на сегодня</h2><div class="form-group"><label>Фильтр по юристу</label><select id="mfilter" onchange="loadTodayFiltered()"><option value="">Все юристы</option>' + state.allLawyers.map(m => `<option value="${m.id}" ${state.todayFilterLawyer==m.id?'selected':''}>${m.name}</option>`).join('') + '</select></div><div id="tdlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    await loadTodayFiltered();
}

async function loadTodayFiltered() {
    const mid = document.getElementById('mfilter')?.value || '';
    state.todayFilterLawyer = mid || null;
    const url = mid ? `/api/admin/today-bookings?admin_telegram_id=${user?.id}&lawyer_id=${mid}` : `/api/admin/today-bookings?admin_telegram_id=${user?.id}`;
    state.todayBookings = await api(url);
    const c = document.getElementById('tdlist'); c.innerHTML = '';
    if (!state.todayBookings.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет записей</p>'; return; }
    state.todayBookings.forEach(b => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${b.time}</span><span class="value">${b.client_name} ${b.is_manual?'📞':''}</span></div><div class="row"><span class="label">Юрист:</span><span class="value">${b.lawyer}</span></div><div class="row"><span class="label">Услуга:</span><span class="value">${b.service} (${b.price}₽)</span></div>`;
        const btn = document.createElement('button'); btn.className = 'btn-cancel'; btn.textContent = '❌ Отменить'; btn.style.marginTop = '8px'; btn.style.width = '100%';
        btn.onclick = async () => {
            const res = await api('/api/admin/cancel', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, booking_id: b.id }) });
            if (res.ok) { tg?.showAlert?.('Запись отменена'); await loadTodayFiltered(); } else { tg?.showAlert?.(res.detail || 'Ошибка'); }
        }; card.appendChild(btn); c.appendChild(card);
    });
}

function renderAdminLawyers(app) {
    app.innerHTML = '<h2>Юристы</h2><div id="mlist"></div><button class="btn-admin" style="width:100%;margin-top:8px" onclick="showLawyerForm()">➕ Добавить юриста</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    renderLawyersList();
}

function renderLawyersList() {
    const c = document.getElementById('mlist'); c.innerHTML = '';
    state.allLawyers.forEach(m => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="value">${m.name}</span><span class="status-badge ${m.is_active?'status-active':'status-inactive'}">${m.is_active?'Активен':'Неактивен'}${m.is_admin?' | Админ':''}</span></div><div class="row"><span class="label">Рейтинг: ${m.rating} | Опыт: ${m.experience} лет | Лимит: ${m.max_bookings} зап/день</span></div>${m.photo?`<img src="${m.photo}" style="width:60px;height:60px;border-radius:12px;object-fit:cover;margin-top:8px">`:''}<div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap"><button class="btn-admin" onclick="editLawyer(${m.id},'${m.name}','${m.photo||''}',${m.experience},${m.telegram_id||0},${m.max_bookings||10},${m.is_admin||false})">✏️</button><button class="btn-admin" onclick="toggleLawyer(${m.id})">${m.is_active?'⏸️ Отключить':'▶️ Включить'}</button><button class="btn-dayoff" onclick="showDayOffForm(${m.id},'${m.name}')">🚫 Выходной</button><button class="btn-cancel" onclick="deleteLawyer(${m.id},'${m.name}')">🗑️</button></div>`;
        c.appendChild(card);
    });
}

function showLawyerForm(editData = null) {
    const app = document.getElementById('app'); state.selectedPhotoFile = null; state.selectedPhotoPath = editData?.photo || null;
    app.innerHTML = `<h2>${editData?'Изменить юриста':'Добавить юриста'}</h2><div class="form-group"><label>ФИО</label><input id="lname" value="${editData?.name||''}"></div><div class="form-group"><label>Фото</label>${state.selectedPhotoPath?`<img src="${state.selectedPhotoPath}" class="preview-img" id="lphoto_preview"><br>`:''}<input type="file" id="lphoto_input" accept="image/*" style="display:none" onchange="onPhotoSelected(this)"><button class="btn-photo" onclick="document.getElementById('lphoto_input').click()">📷 Выбрать фото</button><span class="file-selected" id="lphoto_name">${state.selectedPhotoPath?'✅ Фото загружено':''}</span></div><div class="form-group"><label>Опыт (лет)</label><input id="lexp" type="number" value="${editData?.exp||0}"></div><div class="form-group"><label>Telegram ID</label><input id="ltg" type="number" value="${editData?.tg||''}"></div><div class="form-group"><label>Лимит записей в день</label><input id="lmax" type="number" value="${editData?.max||10}"></div><div class="form-group"><label><input type="checkbox" id="lisadmin" ${editData?.isAdmin?'checked':''}> Права администратора</label></div><button class="btn-confirm" style="width:100%" onclick="${editData?`saveLawyerEdit(${editData.id})`:'saveLawyerNew()'}">Сохранить</button><div class="btn-group"><button class="btn-back" onclick="rn('admin_lawyers')">← Назад</button></div>`;
}

function onPhotoSelected(input) {
    if (input.files && input.files[0]) {
        state.selectedPhotoFile = input.files[0];
        document.getElementById('lphoto_name').textContent = '✅ ' + input.files[0].name;
        const preview = document.getElementById('lphoto_preview');
        if (preview) preview.src = URL.createObjectURL(input.files[0]);
    }
}

async function saveLawyerNew() {
    const name = document.getElementById('lname').value;
    const exp = parseInt(document.getElementById('lexp').value) || 0;
    const tgid = parseInt(document.getElementById('ltg').value) || null;
    const max = parseInt(document.getElementById('lmax').value) || 10;
    const isAdm = document.getElementById('lisadmin')?.checked || false;
    let photoPath = null;
    if (state.selectedPhotoFile) { const upRes = await uploadPhoto(state.selectedPhotoFile); if (upRes.ok) photoPath = upRes.path; }
    await api('/api/admin/lawyers', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, name, photo_url: photoPath, experience_years: exp, telegram_id: tgid, max_bookings_per_day: max, is_admin: isAdm }) });
    state.allLawyers = await api(`/api/admin/lawyers?admin_telegram_id=${user?.id}`); rn('admin_lawyers');
}

function editLawyer(id, name, photo, exp, tg, max, isAdm) { showLawyerForm({ id, name, photo, exp, tg, max, isAdmin: isAdm }); }

async function saveLawyerEdit(id) {
    const name = document.getElementById('lname').value;
    const exp = parseInt(document.getElementById('lexp').value) || 0;
    const tgid = parseInt(document.getElementById('ltg').value) || null;
    const max = parseInt(document.getElementById('lmax').value) || 10;
    const isAdm = document.getElementById('lisadmin')?.checked || false;
    let photoPath = state.selectedPhotoPath;
    if (state.selectedPhotoFile) { const upRes = await uploadPhoto(state.selectedPhotoFile); if (upRes.ok) photoPath = upRes.path; }
    await api(`/api/admin/lawyers/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, name, photo_url: photoPath, experience_years: exp, telegram_id: tgid, max_bookings_per_day: max, is_admin: isAdm }) });
    state.allLawyers = await api(`/api/admin/lawyers?admin_telegram_id=${user?.id}`); rn('admin_lawyers');
}

async function toggleLawyer(id) {
    await api(`/api/admin/lawyers/${id}/toggle`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, lawyer_id: id }) });
    state.allLawyers = await api(`/api/admin/lawyers?admin_telegram_id=${user?.id}`); rn('admin_lawyers');
}

async function deleteLawyer(id, name) {
    if (!confirm(`Удалить юриста "${name}"?`)) return;
    const res = await api(`/api/admin/lawyers/${id}?admin_telegram_id=${user?.id}`, { method: 'DELETE' });
    if (res.ok) { tg?.showAlert?.('Юрист удалён'); state.allLawyers = await api(`/api/admin/lawyers?admin_telegram_id=${user?.id}`); rn('admin_lawyers'); }
    else { tg?.showAlert?.(res.detail || 'Нельзя удалить юриста с активными записями'); }
}

function showDayOffForm(lawyerId, lawyerName) {
    const app = document.getElementById('app');
    app.innerHTML = `<h2>Выходной юриста</h2><p style="color:#888;margin-bottom:12px">Юрист: <b>${lawyerName}</b></p><div class="form-group"><label>Дата</label><input id="ddate" type="date"></div><div class="form-group"><label>Причина</label><textarea id="dreason"></textarea></div><button class="btn-confirm" style="width:100%" onclick="saveDayOff(${lawyerId})">Установить выходной</button><div class="btn-group"><button class="btn-back" onclick="rn('admin_lawyers')">← Назад</button></div>`;
}

async function saveDayOff(lawyerId) {
    const date = document.getElementById('ddate').value;
    const reason = document.getElementById('dreason').value;
    if (!date) { tg?.showAlert?.('Выберите дату'); return; }
    const res = await api('/api/admin/lawyer-day-off', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, lawyer_id: lawyerId, date, reason }) });
    if (res.ok) { tg?.showAlert?.(`Выходной установлен. Отменено записей: ${res.cancelled_bookings}`); rn('admin_lawyers'); }
    else { tg?.showAlert?.(res.detail || 'Ошибка'); }
}

function renderAdminServices(app) {
    app.innerHTML = '<h2>Услуги</h2><div id="slist"></div><button class="btn-admin" style="width:100%;margin-top:8px" onclick="showServiceForm()">➕ Добавить услугу</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    renderServicesList();
}

function renderServicesList() {
    const c = document.getElementById('slist'); c.innerHTML = '';
    state.allServices.forEach(s => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="value">${s.name}</span><span class="status-badge ${s.is_active?'status-active':'status-inactive'}">${s.is_active?'Активна':'Неактивна'}</span></div><div class="row"><span class="label">Цена: ${s.price}₽ | Длит: ${s.duration} мин | Кат: ${s.category||'—'}</span></div><div style="display:flex;gap:8px;margin-top:8px"><button class="btn-admin" onclick="editService(${s.id},'${s.name}',${s.price},${s.duration},'${s.category||''}')">✏️</button><button class="btn-admin" onclick="toggleService(${s.id})">${s.is_active?'⏸️ Отключить':'▶️ Включить'}</button><button class="btn-cancel" onclick="deleteService(${s.id},'${s.name}')">🗑️</button></div>`;
        c.appendChild(card);
    });
}

function showServiceForm(editData = null) {
    const app = document.getElementById('app');
    app.innerHTML = `<h2>${editData?'Изменить услугу':'Добавить услугу'}</h2><div class="form-group"><label>Название</label><input id="sname" value="${editData?.name||''}"></div><div class="form-group"><label>Цена</label><input id="sprice" type="number" value="${editData?.price||''}"></div><div class="form-group"><label>Длительность (мин)</label><input id="sdur" type="number" value="${editData?.dur||''}"></div><div class="form-group"><label>Категория</label><input id="scat" value="${editData?.cat||''}"></div><button class="btn-confirm" style="width:100%" onclick="${editData?`saveServiceEdit(${editData.id})`:'saveServiceNew()'}">Сохранить</button><div class="btn-group"><button class="btn-back" onclick="rn('admin_services')">← Назад</button></div>`;
}

async function saveServiceNew() {
    const name = document.getElementById('sname').value;
    const price = parseInt(document.getElementById('sprice').value) || 0;
    const dur = parseInt(document.getElementById('sdur').value) || 0;
    const cat = document.getElementById('scat').value;
    await api('/api/admin/services', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, name, price, duration_minutes: dur, category: cat }) });
    state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`); rn('admin_services');
}

function editService(id, name, price, dur, cat) { showServiceForm({ id, name, price, dur, cat }); }

async function saveServiceEdit(id) {
    const name = document.getElementById('sname').value;
    const price = parseInt(document.getElementById('sprice').value) || 0;
    const dur = parseInt(document.getElementById('sdur').value) || 0;
    const cat = document.getElementById('scat').value;
    await api(`/api/admin/services/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, name, price, duration_minutes: dur, category: cat }) });
    state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`); rn('admin_services');
}

async function toggleService(id) {
    await api(`/api/admin/services/${id}/toggle`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, service_id: id }) });
    state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`); rn('admin_services');
}

async function deleteService(id, name) {
    if (!confirm(`Удалить услугу "${name}"?`)) return;
    const res = await api(`/api/admin/services/${id}?admin_telegram_id=${user?.id}`, { method: 'DELETE' });
    if (res.ok) { tg?.showAlert?.('Услуга удалена'); state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`); rn('admin_services'); }
    else { tg?.showAlert?.(res.detail || 'Нельзя удалить услугу с активными записями'); }
}

async function renderAdminReviews(app) {
    app.innerHTML = '<h2>Отзывы клиентов</h2><div class="form-group"><label>Фильтр по юристу</label><select id="rfilter" onchange="loadAdminReviews()"><option value="">Все юристы</option>' + state.allLawyers.map(m => `<option value="${m.id}">${m.name}</option>`).join('') + '</select></div><div id="arlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    await loadAdminReviews();
}

async function loadAdminReviews() {
    const mid = document.getElementById('rfilter')?.value || '';
    const url = mid ? `/api/admin/reviews?admin_telegram_id=${user?.id}&lawyer_id=${mid}` : `/api/admin/reviews?admin_telegram_id=${user?.id}`;
    state.allReviews = await api(url);
    const c = document.getElementById('arlist'); c.innerHTML = '';
    if (!state.allReviews || !state.allReviews.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет отзывов</p>'; return; }
    state.allReviews.forEach(r => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${r.client_name}</span><span class="value">${'★'.repeat(r.rating)}${'☆'.repeat(5-r.rating)}</span></div><div class="row"><span class="label">Юрист: ${r.lawyer_name}</span></div>${r.comment?`<div class="row"><span class="label">Комментарий:</span><span class="value">${r.comment}</span></div>`:''}`;
        c.appendChild(card);
    });
}

async function renderAdminAudit(app) {
    app.innerHTML = '<h2>Аудит</h2><div id="alist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const logs = await api(`/api/admin/audit-log?admin_telegram_id=${user?.id}`);
    const c = document.getElementById('alist');
    if (!logs || !logs.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет записей</p>'; return; }
    logs.forEach(l => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${l.action}</span><span class="value">${l.details||''}</span></div>`;
        c.appendChild(card);
    });
}

async function renderAdminWeekend(app) {
    app.innerHTML = '<h2>Выходные дни</h2><div id="wlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const days = ['Вс','Пн','Вт','Ср','Чт','Пт','Сб'];
    const current = state.weekendDays || [];
    const c = document.getElementById('wlist');
    days.forEach((name, idx) => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="value">${name}</span><label><input type="checkbox" class="wcheck" data-day="${idx}" ${current.includes(idx)?'checked':''}> Выходной</label></div>`;
        c.appendChild(card);
    });
    const btn = document.createElement('button'); btn.className = 'btn-confirm'; btn.textContent = '💾 Сохранить'; btn.style.marginTop = '16px'; btn.style.width = '100%';
    btn.onclick = async () => {
        const selected = [];
        document.querySelectorAll('.wcheck:checked').forEach(cb => selected.push(parseInt(cb.dataset.day)));
        const res = await api('/api/admin/weekend-days', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, days: selected }) });
        if (res.ok) { state.weekendDays = selected; tg?.showAlert?.('Выходные дни сохранены'); rn('menu'); }
        else { tg?.showAlert?.('Ошибка'); }
    };
    c.appendChild(btn);
}
