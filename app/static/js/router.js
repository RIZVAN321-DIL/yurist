function rn(screen) {
    state.screen = screen;
    const app = document.getElementById('app');
    if (!app) return;
    app.innerHTML = '';
    const screens = {
        menu: renderMenu, booking_service: renderBookingService, booking_lawyer: renderBookingLawyer,
        booking_date: renderBookingDate, booking_time: renderBookingTime, booking_confirm: renderBookingConfirm,
        my_bookings: renderMyBookings, reviews: renderReviews, my_reviews_history: renderMyReviewsHistory,
        bonuses: renderBonuses, admin_stats: renderAdminStats, admin_today: renderAdminToday,
        admin_lawyers: renderAdminLawyers, admin_services: renderAdminServices,
        admin_broadcast: renderAdminBroadcast, admin_audit: renderAdminAudit, admin_reviews: renderAdminReviews,
        admin_manual_booking: renderAdminManualBooking, manual_service: renderManualService,
        manual_lawyer: renderManualLawyer, manual_date: renderManualDate, manual_time: renderManualTime,
        manual_confirm: renderManualConfirm, admin_weekend: renderAdminWeekend
    };
    if (screens[screen]) screens[screen](app);
    else renderMenu(app);
}
