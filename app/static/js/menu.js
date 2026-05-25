function renderMenu(app) {
    app.innerHTML = '<h2>Меню</h2><div class="menu-grid"></div>';
    const grid = app.querySelector('.menu-grid');
    const items = [];
    const hasAdmin = isAdmin || state.isLawyerAdmin;
    if (!hasAdmin) {
        items.push({ icon: '⚖️', label: 'Записаться', action: () => rn('booking_service') });
        items.push({ icon: '📋', label: 'Мои записи', action: () => rn('my_bookings') });
        items.push({ icon: '⭐', label: 'Отзывы', action: () => rn('reviews') });
        items.push({ icon: '📝', label: 'Мои отзывы', action: () => rn('my_reviews_history') });
        items.push({ icon: '🎁', label: 'Бонусы', action: () => rn('bonuses') });
    } else {
        items.push({ icon: '📞', label: 'Запись по звонку', action: () => rn('admin_manual_booking') });
        items.push({ icon: '📊', label: 'Статистика', action: () => rn('admin_stats') });
        items.push({ icon: '📅', label: 'Записи сегодня', action: () => rn('admin_today') });
        items.push({ icon: '👨‍💼', label: 'Юристы', action: () => rn('admin_lawyers') });
        items.push({ icon: '📋', label: 'Услуги', action: () => rn('admin_services') });
        items.push({ icon: '👁️', label: 'Отзывы клиентов', action: () => rn('admin_reviews') });
        items.push({ icon: '📢', label: 'Рассылка', action: () => rn('admin_broadcast') });
        items.push({ icon: '📜', label: 'Аудит', action: () => rn('admin_audit') });
        items.push({ icon: '📅', label: 'Выходные дни', action: () => rn('admin_weekend') });
    }
    items.forEach(item => {
        const div = document.createElement('div'); div.className = 'menu-item';
        div.innerHTML = `<div class="icon">${item.icon}</div><div class="label">${item.label}</div>`;
        div.onclick = item.action; grid.appendChild(div);
    });
}
