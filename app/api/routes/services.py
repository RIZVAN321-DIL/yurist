from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.service_repo import ServiceRepository
from app.repositories.audit_repo import AuditRepository
from app.api.schemas.service import ServiceCreateSchema, ServiceUpdateSchema, ServiceToggleSchema
from app.models.service import Service
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["services"])

@router.get("/services")
async def get_services(session: AsyncSession = Depends(get_session)):
    services = await ServiceRepository(session).get_all_active()
    return [{"id": s.id, "name": s.name, "price": s.price, "duration": s.duration_minutes, "category": s.category} for s in services]

@router.get("/admin/services")
async def get_all_services(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    services = await ServiceRepository(session).get_all()
    return [{"id": s.id, "name": s.name, "price": s.price, "duration": s.duration_minutes, "category": s.category, "is_active": s.is_active} for s in services]

@router.post("/admin/services")
async def create_service(data: ServiceCreateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    s = Service(name=data.name, price=data.price, duration_minutes=data.duration_minutes, category=data.category)
    result = await ServiceRepository(session).create(s)
    await AuditRepository(session).log(data.admin_telegram_id, "create_service", data.name)
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/admin/services/{service_id}")
async def update_service(service_id: int, data: ServiceUpdateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    updates = {k: v for k, v in data.model_dump(exclude={"admin_telegram_id"}).items() if v is not None}
    if updates:
        await ServiceRepository(session).update_fields(service_id, **updates)
        await AuditRepository(session).log(data.admin_telegram_id, "update_service", str(service_id))
        await session.commit()
    return {"ok": True}

@router.post("/admin/services/{service_id}/toggle")
async def toggle_service(service_id: int, data: ServiceToggleSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    s = await ServiceRepository(session).toggle_active(service_id)
    if not s:
        raise HTTPException(status_code=404)
    await AuditRepository(session).log(data.admin_telegram_id, "toggle_service", str(service_id))
    await session.commit()
    return {"ok": True, "is_active": s.is_active}

@router.delete("/admin/services/{service_id}")
async def delete_service(service_id: int, admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    ok = await ServiceRepository(session).delete(service_id)
    if not ok:
        raise HTTPException(status_code=400, detail="Нельзя удалить услугу с активными записями")
    await AuditRepository(session).log(admin_telegram_id, "delete_service", str(service_id))
    await session.commit()
    return {"ok": True}
