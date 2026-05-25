from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.api.schemas.response import BroadcastSchema
from app.services.broadcast_service import BroadcastService
from app.repositories.audit_repo import AuditRepository
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["broadcast"])

@router.post("/admin/broadcast")
async def send_broadcast(data: BroadcastSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    result = await BroadcastService.send_broadcast(data.text, session, data.photo_path)
    await AuditRepository(session).log(data.admin_telegram_id, "broadcast", f"sent={result['sent']}")
    await session.commit()
    return result
