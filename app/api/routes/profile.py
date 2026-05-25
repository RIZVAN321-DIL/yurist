from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.client_repo import ClientRepository
from app.repositories.booking_repo import BookingRepository
from app.repositories.review_repo import ReviewRepository
from app.repositories.lawyer_repo import LawyerRepository
from app.config import settings

router = APIRouter(prefix="/api", tags=["profile"])

@router.get("/profile")
async def get_profile(telegram_id: int, session: AsyncSession = Depends(get_session)):
    client = await ClientRepository(session).get_by_telegram_id(telegram_id)
    if not client:
        return {"exists": False}
    bookings = await BookingRepository(session).get_client_bookings(client.id)
    past = await BookingRepository(session).get_past_confirmed(client.id)
    reviews = await ReviewRepository(session).get_by_client(client.id)
    all_lawyers = await LawyerRepository(session).get_all()
    lawyer_info = None
    for l in all_lawyers:
        if l.telegram_id == telegram_id:
            lawyer_info = {"lawyer_id": l.id, "is_admin": l.is_admin, "name": l.name}
            break
    return {
        "exists": True, "first_name": client.first_name, "bonus_balance": client.bonus_balance,
        "total_visits": client.total_visits, "referral_code": client.referral_code,
        "visits_to_next_bonus": settings.BONUS_VISITS_INTERVAL - (client.total_visits % settings.BONUS_VISITS_INTERVAL),
        "lawyer_info": lawyer_info,
        "bookings": [{"id": b.id, "lawyer": b.lawyer.name, "service": b.service.name, "date": b.date, "time": b.time, "price": b.service.price, "status": b.status, "is_manual": b.is_manual} for b in bookings],
        "past_bookings_for_review": [{"id": b.id, "lawyer": b.lawyer.name, "service": b.service.name, "date": b.date, "time": b.time} for b in past],
        "my_reviews": [{"id": r.id, "lawyer_name": r.lawyer.name if r.lawyer else "—", "rating": r.rating, "comment": r.comment} for r in reviews]
    }
