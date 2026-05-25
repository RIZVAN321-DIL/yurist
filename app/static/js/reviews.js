function renderReviews(app) {
    app.innerHTML = '<h2>Оставить отзыв</h2><div id="rvlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('rvlist');
    if (!state.pastBookings.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет прошедших записей</p>'; return; }
    state.pastBookings.forEach(b => {
        if (b.is_manual) return;
        const card = document.createElement('div'); card.className = 'card'; card.id = 'rv_' + b.id;
        card.innerHTML = `<div class="row"><span class="label">${b.date} в ${b.time}</span></div><div class="row"><span class="label">Юрист:</span><span class="value">${b.lawyer}</span></div><div class="row"><span class="label">Услуга:</span><span class="value">${b.service}</span></div><div class="stars" id="stars_${b.id}">${[1,2,3,4,5].map(n => `<span class="star" data-n="${n}">★</span>`).join('')}</div>`;
        c.appendChild(card);
        const stars = document.querySelectorAll(`#stars_${b.id} .star`);
        stars.forEach(s => {
            s.onmouseenter = () => { const n = parseInt(s.dataset.n); stars.forEach((ss, i) => ss.classList.toggle('active', i < n)); };
            s.onclick = async () => {
                const rating = parseInt(s.dataset.n);
                const res = await api('/api/reviews', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ telegram_id: user?.id, booking_id: b.id, rating }) });
                if (res.ok) { tg?.showAlert?.(res.bonus_added ? `Спасибо! +${res.bonus_amount}₽ бонус!` : 'Спасибо за отзыв!'); const p = await api(`/api/profile?telegram_id=${user?.id}`); if (p?.exists) { state.profile = p; state.pastBookings = p.past_bookings_for_review || []; } rn('reviews'); }
                else { tg?.showAlert?.(res.detail || 'Ошибка'); }
            };
        });
    });
}

function renderMyReviewsHistory(app) {
    app.innerHTML = '<h2>Мои отзывы</h2><div id="myrv"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('myrv');
    if (!state.myReviews || !state.myReviews.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет отзывов</p>'; return; }
    state.myReviews.forEach(r => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">Юрист: ${r.lawyer_name}</span><span class="value">${'★'.repeat(r.rating)}${'☆'.repeat(5-r.rating)}</span></div>${r.comment?`<div class="row"><span class="label">Комментарий:</span><span class="value">${r.comment}</span></div>`:''}`;
        c.appendChild(card);
    });
}
