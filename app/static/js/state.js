const tg = window.Telegram?.WebApp;
tg?.expand?.();
tg?.ready?.();
tg?.setHeaderColor?.('#0d0d0d');
tg?.setBackgroundColor?.('#0d0d0d');

const user = tg?.initDataUnsafe?.user || null;
const ADMIN_IDS = [5724746367];
const isAdmin = user && ADMIN_IDS.includes(user.id);

let state = {
    screen: 'menu', svc: null, lwr: null, date: null, time: null,
    services: [], lawyers: [], bookings: [], pastBookings: [], myReviews: [],
    profile: null, lawyerInfo: null, isLawyer: false, isLawyerAdmin: false,
    stats: null, todayBookings: [], allServices: [], allLawyers: [], allReviews: [],
    isSubmitting: false, todayFilterLawyer: null,
    selectedPhotoFile: null, selectedPhotoPath: null, broadcastPhotoFile: null,
    manualSvc: null, manualLwr: null, manualDate: null, manualTime: null,
    manualClientName: '', manualPhone: '', weekendDays: []
};
