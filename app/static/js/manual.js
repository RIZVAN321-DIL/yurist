function renderAdminManualBooking(app) {
    app.innerHTML = '<h2>📞 Запись по звонку</h2><div class="form-group"><label>Имя клиента</label><input id="mclient" value="' + (state.manualClientName || '') + '"></div><div class="form-group"><label>Телефон</label><input id="mphone" value="' + (state.manualPhone || '') + '"></div><button class="btn-manual" onclick="state.manualClientName=document.getElementById(\'mclient\').value;state.manualPhone=document.getElementById(\'mphone\').value;rn(\'manual_service\')">Далее: выбор услуги</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
}

function renderManualService(app) {
    app.innerHTML = '<h2>Выберите услугу</h2><div id="msvc"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'admin_manual_booking\')">← Назад</button></div>';
    const c = document.getElementById('msvc');
    state.services.forEach(x => {
        const e = document.createElement('div'); e.className = 'option';
        e.innerHTML = `<div class="info"><b>${x.name}</b><span>${x.duration} мин</span></div><strong style="color:#c9a96e">${x.price}₽</strong>`;
        e.onclick = () => { state.manualSvc = x; rn('manual_lawyer'); }; c.appendChild(e);
    });
}

function renderManualLawyer(app) {
    app.innerHTML = '<h2>Выберите юриста</h2><div id="mlwr"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'manual_service\')">← Назад</button></div>';
    const c = document.getElementById('mlwr');
    state.lawyers.forEach(x => {
        const e = document.createElement('div'); e.className = 'option';
        e.innerHTML = `<img src="${x.photo || ''}" onerror="this.style.display=\'none\'"><div class="info"><b>${x.name}</b><span>⭐${x.rating} | Опыт ${x.experience} лет</span></div>`;
        e.onclick = () => { state.manualLwr = x; rn('manual_date'); }; c.appendChild(e);
    });
}

function renderManualDate(app) {
    app.innerHTML = '<h2>Выберите дату</h2><div class="grid" id="mdt"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'manual_lawyer\')">← Назад</button></div>';
    const g = document.getElementById('mdt'); const t = new Date();
    for (let i = 0; i < 14; i++) {
        const d = new Date(t); d.setDate(t.getDate() + i);
        const ds = d.toISOString().split('T')[0]; const dow = d.getDay();
        const b = document.createElement('div');
        b.textContent = d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short', weekday: 'short' });
        if (state.weekendDays.includes(dow)) { b.className = 'weekend'; b.textContent += ' (вых)'; }
        else { b.onclick = () => { state.manualDate = ds; rn('manual_time'); }; }
        g.appendChild(b);
    }
}

async function renderManualTime(app) {
    app.innerHTML = '<h2>Выберите время</h2><div class="grid" id="mtm"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'manual_date\')">← Назад</button></div>';
    const g = document.getElementById('mtm');
    const bk = await api(`/api/booked-slots?date=${state.manualDate}&lawyer_id=${state.manualLwr?.id}`);
    const bt = (bk || []).map(x => x.time);
    const now = new Date(); const today = now.toISOString().split('T')[0];
    const curH = now.getHours(); const curM = now.getMinutes();
    for (let h = 9; h < 18; h++) {
        for (let m = 0; m < 60; m += 30) {
            const tm = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
            const b = document.createElement('div');
            const isPast = state.manualDate === today && (h < curH || (h === curH && m <= curM));
            if (bt.includes(tm) || isPast) { b.className = 'booked'; b.textContent = tm; }
            else { b.textContent = tm; b.onclick = () => { state.manualTime = tm; rn('manual_confirm'); }; }
            g.appendChild(b);
        }
    }
}

function renderManualConfirm(app) {
    app.innerHTML = '<h2>Подтверждение</h2><div class="summary"><div class="summary-item"><span>Клиент</span><strong>' + (state.manualClientName || '—') + '</strong></div><div class="summary-item"><span>Телефон</span><strong>' + (state.manualPhone || '—') + '</strong></div><div class="summary-item"><span>Услуга</span><strong>' + (state.manualSvc?.name || '') + '</strong></div><div class="summary-item"><span>Юрист</span><strong>' + (state.manualLwr?.name || '') + '</strong></div><div class="summary-item"><span>Дата</span><strong>' + (state.manualDate || '') + '</strong></div><div class="summary-item"><span>Время</span><strong>' + (state.manualTime || '') + '</strong></div><div class="summary-item total"><span>Цена</span><strong>' + (state.manualSvc?.price || '') + '₽</strong></div></div><div class="btn-group"><button class="btn-back" onclick="rn(\'manual_time\')">← Назад</button><button class="btn-confirm" onclick="manualCf()">Подтвердить</button></div>';
}

async function manualCf() {
    if (state.isSubmitting) return;
    if (!state.manualClientName || !state.manualClientName.trim()) { tg?.showAlert?.('Введите имя клиента'); return; }
    if (!state.manualSvc || !state.manualLwr || !state.manualDate || !state.manualTime) { tg?.showAlert?.('Данные утеряны. Начните заново.'); rn('admin_manual_booking'); return; }
    state.isSubmitting = true;
    const payload = { admin_telegram_id: user?.id, client_name: state.manualClientName.trim(), phone: state.manualPhone || null, service_id: state.manualSvc.id, lawyer_id: state.manualLwr.id, date: state.manualDate, time: state.manualTime };
    try {
        const res = await api('/api/admin/manual-booking', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
        if (res.ok) {
            tg?.showAlert?.(`Запись создана!\n\nКлиент: ${res.client_name}\n${res.service}\nЮрист: ${res.lawyer}\n${res.date} в ${res.time}`);
            if (isAdmin || state.isLawyerAdmin) { state.stats = await api(`/api/admin/stats?admin_telegram_id=${user?.id}`); state.todayBookings = await api(`/api/admin/today-bookings?admin_telegram_id=${user?.id}`); }
            rn('menu');
        } else { tg?.showAlert?.(res.detail || 'Ошибка'); }
    } catch (e) { tg?.showAlert?.('Ошибка соединения'); }
    state.isSubmitting = false;
}
