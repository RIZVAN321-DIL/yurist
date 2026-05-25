from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.lawyer_repo import LawyerRepository
from app.repositories.audit_repo import AuditRepository
from app.api.schemas.lawyer import LawyerCreateSchema, LawyerUpdateSchema, LawyerToggleSchema
from app.models.lawyer import Lawyer
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["lawyers"])

@router.get("/lawyers")
async def get_lawyers(session: AsyncSession = Depends(get_session)):
    lawyers = await LawyerRepository(session).get_all_active()
    return [{"id": l.id, "name": l.name, "photo": l.photo_url, "rating": l.rating, "experience": l.experience_years, "max_bookings": l.max_bookings_per_day} for l in lawyers]

@router.get("/admin/lawyers")
async def get_all_lawyers(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    lawyers = await LawyerRepository(session).get_all()
    return [{"id": l.id, "name": l.name, "photo": l.photo_url, "rating": l.rating, "experience": l.experience_years, "telegram_id": l.telegram_id, "max_bookings": l.max_bookings_per_day, "is_admin": l.is_admin, "is_active": l.is_active} for l in lawyers]

@router.post("/admin/lawyers")
async def create_lawyer(data: LawyerCreateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    l = Lawyer(name=data.name, photo_url=data.photo_url, experience_years=data.experience_years, telegram_id=data.telegram_id, max_bookings_per_day=data.max_bookings_per_day, is_admin=data.is_admin)
    result = await LawyerRepository(session).create(l)
    await AuditRepository(session).log(data.admin_telegram_id, "create_lawyer", data.name)
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/admin/lawyers/{lawyer_id}")
async def update_lawyer(lawyer_id: int, data: LawyerUpdateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    updates = {k: v for k, v in data.model_dump(exclude={"admin_telegram_id"}).items() if v is not None}
    if updates:
        await LawyerRepository(session).update_fields(lawyer_id, **updates)
        await AuditRepository(session).log(data.admin_telegram_id, "update_lawyer", str(lawyer_id))
        await session.commit()
    return {"ok": True}

@router.post("/admin/lawyers/{lawyer_id}/toggle")
async def toggle_lawyer(lawyer_id: int, data: LawyerToggleSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    l = await LawyerRepository(session).toggle_active(lawyer_id)
    if not l:
        raise HTTPException(status_code=404)
    await AuditRepository(session).log(data.admin_telegram_id, "toggle_lawyer", str(lawyer_id))
    await session.commit()
    return {"ok": True, "is_active": l.is_active}

@router.delete("/admin/lawyers/{lawyer_id}")
async def delete_lawyer(lawyer_id: int, admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    ok = await LawyerRepository(session).delete(lawyer_id)
    if not ok:
        raise HTTPException(status_code=400, detail="Нельзя удалить юриста с активными записями")
    await AuditRepository(session).log(admin_telegram_id, "delete_lawyer", str(lawyer_id))
    await session.commit()
    return {"ok": True}
