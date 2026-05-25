async function ld() {
    try {
        state.services = await api('/api/services') || [];
        state.lawyers = await api('/api/lawyers') || [];
        state.weekendDays = await api('/api/weekend-days') || [];
        if (user) {
            const p = await api(`/api/profile?telegram_id=${user.id}`);
            if (p?.exists) {
                state.profile = p;
                state.bookings = p.bookings || [];
                state.pastBookings = p.past_bookings_for_review || [];
                state.myReviews = p.my_reviews || [];
                state.lawyerInfo = p.lawyer_info || null;
                state.isLawyer = !!state.lawyerInfo;
                state.isLawyerAdmin = state.lawyerInfo?.is_admin || false;
            }
        }
        if (isAdmin || state.isLawyerAdmin) {
            state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`) || [];
            state.allLawyers = await api(`/api/admin/lawyers?admin_telegram_id=${user?.id}`) || [];
            state.stats = await api(`/api/admin/stats?admin_telegram_id=${user?.id}`);
            state.todayBookings = await api(`/api/admin/today-bookings?admin_telegram_id=${user?.id}`) || [];
            state.allReviews = await api(`/api/admin/reviews?admin_telegram_id=${user?.id}`) || [];
        }
    } catch (e) { console.error(e); }
    rn(state.screen);
}

ld();
