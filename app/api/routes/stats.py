from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.services.stats_service import StatsService
from app.repositories.booking_repo import BookingRepository
from app.repositories.audit_repo import AuditRepository
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["stats"])

@router.get("/admin/stats")
async def get_stats(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    return await StatsService(session).get_stats()

@router.get("/admin/today-bookings")
async def get_today_bookings(admin_telegram_id: int, lawyer_id: int | None = Query(default=None), session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    bookings = await BookingRepository(session).get_today_bookings(lawyer_id)
    return [{"id": b.id, "client_name": b.client.first_name or b.manual_client_name or "—", "lawyer": b.lawyer.name, "service": b.service.name, "time": b.time, "price": b.service.price, "is_manual": b.is_manual} for b in bookings]

@router.get("/admin/audit-log")
async def get_audit_log(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    logs = await AuditRepository(session).get_recent()
    return [{"id": l.id, "admin_id": l.admin_id, "action": l.action, "details": l.details} for l in logs]
