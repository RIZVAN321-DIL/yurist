from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.api.schemas.booking import BookingCreateSchema, ManualBookingSchema, BookingCancelSchema, AdminCancelSchema, LawyerDayOffSchema
from app.services.booking_service import BookingService
from app.core.security import is_admin
from app.repositories.audit_repo import AuditRepository

router = APIRouter(prefix="/api", tags=["booking"])

@router.post("/book")
async def create_booking(data: BookingCreateSchema, session: AsyncSession = Depends(get_session)):
    try:
        service = BookingService(session)
        result = await service.create_booking(data.telegram_id, data.chat_id, data.username, data.first_name, data.last_name, data.service_id, data.lawyer_id, data.date, data.time)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/admin/manual-booking")
async def create_manual_booking(data: ManualBookingSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    try:
        service = BookingService(session)
        result = await service.create_manual_booking(data.client_name, data.phone, data.service_id, data.lawyer_id, data.date, data.time, data.admin_telegram_id)
        await AuditRepository(session).log(data.admin_telegram_id, "manual_booking", data.client_name)
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/cancel")
async def cancel_booking(data: BookingCancelSchema, session: AsyncSession = Depends(get_session)):
    try:
        return await BookingService(session).cancel_booking(data.booking_id, data.telegram_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/admin/cancel")
async def admin_cancel(data: AdminCancelSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    try:
        result = await BookingService(session).cancel_booking(data.booking_id, data.admin_telegram_id, True)
        await AuditRepository(session).log(data.admin_telegram_id, "cancel_booking", str(data.booking_id))
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/admin/lawyer-day-off")
async def set_lawyer_day_off(data: LawyerDayOffSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    try:
        result = await BookingService(session).set_lawyer_day_off(data.lawyer_id, data.date, data.reason, data.admin_telegram_id)
        await AuditRepository(session).log(data.admin_telegram_id, "lawyer_day_off", f"lawyer={data.lawyer_id} date={data.date}")
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
