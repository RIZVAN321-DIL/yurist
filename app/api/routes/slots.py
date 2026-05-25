from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.booking_repo import BookingRepository

router = APIRouter(prefix="/api", tags=["slots"])

@router.get("/booked-slots")
async def get_booked_slots(date: str = Query(...), lawyer_id: int = Query(...), session: AsyncSession = Depends(get_session)):
    times = await BookingRepository(session).get_booked_slots(lawyer_id, date)
    return [{"time": t} for t in times]
