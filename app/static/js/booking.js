function renderBookingService(app) {
    app.innerHTML = '<h2>Выберите услугу</h2><div id="svc"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('svc');
    state.services.forEach(x => {
        const e = document.createElement('div'); e.className = 'option';
        e.innerHTML = `<div class="info"><b>${x.name}</b><span>${x.duration} мин</span></div><strong style="color:#c9a96e">${x.price}₽</strong>`;
        e.onclick = () => { state.svc = x; rn('booking_lawyer'); }; c.appendChild(e);
    });
}

function renderBookingLawyer(app) {
    app.innerHTML = '<h2>Выберите юриста</h2><div id="lwr"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_service\')">← Назад</button></div>';
    const c = document.getElementById('lwr');
    state.lawyers.forEach(x => {
        const e = document.createElement('div'); e.className = 'option';
        e.innerHTML = `<img src="${x.photo || ''}" onerror="this.style.display=\'none\'"><div class="info"><b>${x.name}</b><span>⭐${x.rating} | Опыт ${x.experience} лет</span></div>`;
        e.onclick = () => { state.lwr = x; rn('booking_date'); }; c.appendChild(e);
    });
}

function renderBookingDate(app) {
    app.innerHTML = '<h2>Выберите дату</h2><div class="grid" id="dt"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_lawyer\')">← Назад</button></div>';
    const g = document.getElementById('dt'); const t = new Date();
    for (let i = 0; i < 14; i++) {
        const d = new Date(t); d.setDate(t.getDate() + i);
        const ds = d.toISOString().split('T')[0]; const dow = d.getDay();
        const b = document.createElement('div');
        b.textContent = d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short', weekday: 'short' });
        if (state.weekendDays.includes(dow)) { b.className = 'weekend'; b.textContent += ' (вых)'; }
        else { b.onclick = () => { state.date = ds; rn('booking_time'); }; }
        g.appendChild(b);
    }
}

async function renderBookingTime(app) {
    app.innerHTML = '<h2>Выберите время</h2><div class="grid" id="tm"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_date\')">← Назад</button></div>';
    const g = document.getElementById('tm');
    const bk = await api(`/api/booked-slots?date=${state.date}&lawyer_id=${state.lwr.id}`);
    const bt = (bk || []).map(x => x.time);
    const now = new Date(); const today = now.toISOString().split('T')[0];
    const curH = now.getHours(); const curM = now.getMinutes();
    for (let h = 9; h < 18; h++) {
        for (let m = 0; m < 60; m += 30) {
            const tm = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
            const b = document.createElement('div');
            const isPast = state.date === today && (h < curH || (h === curH && m <= curM));
            if (bt.includes(tm) || isPast) { b.className = 'booked'; b.textContent = tm; }
            else { b.textContent = tm; b.onclick = () => { state.time = tm; rn('booking_confirm'); }; }
            g.appendChild(b);
        }
    }
}

function renderBookingConfirm(app) {
    app.innerHTML = '<h2>Подтверждение</h2><div class="summary"><div class="summary-item"><span>Услуга</span><strong id="sm_svc"></strong></div><div class="summary-item"><span>Юрист</span><strong id="sm_lwr"></strong></div><div class="summary-item"><span>Дата</span><strong id="sm_dt"></strong></div><div class="summary-item"><span>Время</span><strong id="sm_tm"></strong></div><div class="summary-item total"><span>Цена</span><strong id="sm_pr"></strong></div></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_time\')">← Назад</button><button class="btn-confirm" id="cfbtn" onclick="confirmBooking()">Подтвердить</button></div>';
    document.getElementById('sm_svc').textContent = state.svc?.name || '';
    document.getElementById('sm_lwr').textContent = state.lwr?.name || '';
    document.getElementById('sm_dt').textContent = state.date || '';
    document.getElementById('sm_tm').textContent = state.time || '';
    document.getElementById('sm_pr').textContent = (state.svc?.price || '') + '₽';
}

async function confirmBooking() {
    if (state.isSubmitting || !user) return;
    state.isSubmitting = true;
    const btn = document.getElementById('cfbtn'); btn.textContent = 'Создаём...'; btn.disabled = true;
    const payload = { telegram_id: user.id, chat_id: user.id, username: user.username || null, first_name: user.first_name || null, last_name: user.last_name || null, service_id: state.svc?.id, lawyer_id: state.lwr?.id, date: state.date, time: state.time };
    try {
        const res = await api('/api/book', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
        if (res.ok) {
            tg?.showAlert?.(`Запись подтверждена!\n\n${res.service}\nЮрист: ${res.lawyer}\n${res.date} в ${res.time}\nЦена: ${res.price}₽`);
            const p = await api(`/api/profile?telegram_id=${user.id}`);
            if (p?.exists) { state.profile = p; state.bookings = p.bookings || []; state.pastBookings = p.past_bookings_for_review || []; }
            rn('my_bookings');
        } else if (res.detail?.startsWith('alternatives|')) {
            tg?.showAlert?.(`Юрист занят.\n\nСвободные:\n${res.detail.split('|')[1]}\n\nВыберите другого.`);
            rn('booking_lawyer');
        } else { tg?.showAlert?.(res.detail || 'Ошибка записи'); }
    } catch (e) { tg?.showAlert?.('Ошибка соединения'); }
    state.isSubmitting = false; btn.textContent = 'Подтвердить'; btn.disabled = false;
}

function renderMyBookings(app) {
    app.innerHTML = '<h2>Мои записи</h2><div id="bklist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('bklist');
    if (!state.bookings.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет записей</p>'; return; }
    state.bookings.forEach(b => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${b.date} в ${b.time}</span><span class="status-badge ${b.status==='confirmed'?'status-active':'status-inactive'} ${b.is_manual?'status-manual':''}">${b.is_manual?'📞 Ручная':b.status==='confirmed'?'✅ Активна':'❌ Отменена'}</span></div><div class="row"><span class="label">Юрист:</span><span class="value">${b.lawyer}</span></div><div class="row"><span class="label">Услуга:</span><span class="value">${b.service}</span></div><div class="row"><span class="label">Цена:</span><span class="value">${b.price}₽</span></div>`;
        if (b.status === 'confirmed' && !b.is_manual) {
            const btn = document.createElement('button'); btn.className = 'btn-cancel'; btn.textContent = '❌ Отменить'; btn.style.marginTop = '8px'; btn.style.width = '100%';
            btn.onclick = async () => {
                const res = await api('/api/cancel', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ telegram_id: user?.id, booking_id: b.id }) });
                if (res.ok) { tg?.showAlert?.('Запись отменена'); const p = await api(`/api/profile?telegram_id=${user?.id}`); state.bookings = p?.bookings || []; rn('my_bookings'); }
                else { tg?.showAlert?.(res.detail || 'Ошибка'); }
            }; card.appendChild(btn);
        }
        c.appendChild(card);
    });
}

function renderBonuses(app) {
    app.innerHTML = '<h2>Бонусы</h2><div id="bn"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('bn');
    if (!state.profile) { c.innerHTML = '<p style="color:#888">Нет данных</p>'; return; }
    c.innerHTML = `<div class="card"><div class="row"><span class="label">Всего визитов:</span><span class="value">${state.profile.total_visits}</span></div><div class="row"><span class="label">Бонусный баланс:</span><span class="value green">${state.profile.bonus_balance}₽</span></div><div class="row"><span class="label">До следующего бонуса:</span><span class="value">${state.profile.visits_to_next_bonus} визитов</span></div></div>`;
}
