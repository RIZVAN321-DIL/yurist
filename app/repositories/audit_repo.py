from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.audit_log import AuditLog

class AuditRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def log(self, admin_id: int, action: str, details: str = ""):
        self.session.add(AuditLog(admin_id=admin_id, action=action, details=details))
        await self.session.flush()
    async def get_recent(self, limit: int = 50) -> list[AuditLog]:
        result = await self.session.execute(select(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit))
        return list(result.scalars().all())
