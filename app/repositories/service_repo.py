from sqlalchemy import select, update, func, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.service import Service
from app.models.booking import Booking

class ServiceRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_all_active(self) -> list[Service]:
        result = await self.session.execute(select(Service).where(Service.is_active == True).order_by(Service.category, Service.price))
        return list(result.scalars().all())
    async def get_all(self) -> list[Service]:
        result = await self.session.execute(select(Service).order_by(Service.id))
        return list(result.scalars().all())
    async def get_by_id(self, service_id: int) -> Service | None:
        result = await self.session.execute(select(Service).where(Service.id == service_id))
        return result.scalar_one_or_none()
    async def create(self, service: Service) -> Service:
        self.session.add(service)
        await self.session.flush()
        return service
    async def update_fields(self, service_id: int, **kwargs):
        await self.session.execute(update(Service).where(Service.id == service_id).values(**kwargs))
        await self.session.flush()
    async def toggle_active(self, service_id: int) -> Service | None:
        service = await self.get_by_id(service_id)
        if service:
            service.is_active = not service.is_active
            await self.session.flush()
        return service
    async def delete(self, service_id: int) -> bool:
        has_active = await self.session.execute(select(func.count()).select_from(Booking).where(Booking.service_id == service_id, Booking.status == "confirmed", Booking.date >= func.date('now')))
        if has_active.scalar() > 0:
            return False
        await self.session.execute(delete(Service).where(Service.id == service_id))
        await self.session.flush()
        return True
