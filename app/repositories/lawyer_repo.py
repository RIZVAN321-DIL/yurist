from sqlalchemy import select, update, func, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.lawyer import Lawyer
from app.models.review import Review
from app.models.lawyer_day_off import LawyerDayOff
from app.models.booking import Booking

class LawyerRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_all_active(self) -> list[Lawyer]:
        result = await self.session.execute(select(Lawyer).where(Lawyer.is_active == True).order_by(Lawyer.rating.desc()))
        return list(result.scalars().all())
    async def get_all(self) -> list[Lawyer]:
        result = await self.session.execute(select(Lawyer).order_by(Lawyer.id))
        return list(result.scalars().all())
    async def get_by_id(self, lawyer_id: int) -> Lawyer | None:
        result = await self.session.execute(select(Lawyer).where(Lawyer.id == lawyer_id))
        return result.scalar_one_or_none()
    async def create(self, lawyer: Lawyer) -> Lawyer:
        self.session.add(lawyer)
        await self.session.flush()
        return lawyer
    async def update_fields(self, lawyer_id: int, **kwargs):
        await self.session.execute(update(Lawyer).where(Lawyer.id == lawyer_id).values(**kwargs))
        await self.session.flush()
    async def toggle_active(self, lawyer_id: int) -> Lawyer | None:
        lawyer = await self.get_by_id(lawyer_id)
        if lawyer:
            lawyer.is_active = not lawyer.is_active
            await self.session.flush()
        return lawyer
    async def update_rating(self, lawyer_id: int):
        result = await self.session.execute(select(func.avg(Review.rating), func.count(Review.id)).where(Review.lawyer_id == lawyer_id))
        avg_rating, total = result.one()
        await self.session.execute(update(Lawyer).where(Lawyer.id == lawyer_id).values(rating=round(float(avg_rating or 5.0), 1), total_reviews=total or 0))
        await self.session.flush()
    async def add_day_off(self, lawyer_id: int, date: str, reason: str | None = None) -> LawyerDayOff:
        day_off = LawyerDayOff(lawyer_id=lawyer_id, date=date, reason=reason)
        self.session.add(day_off)
        await self.session.flush()
        return day_off
    async def is_day_off(self, lawyer_id: int, date: str) -> bool:
        result = await self.session.execute(select(LawyerDayOff).where(LawyerDayOff.lawyer_id == lawyer_id, LawyerDayOff.date == date))
        return result.scalar_one_or_none() is not None
    async def delete(self, lawyer_id: int) -> bool:
        has_active = await self.session.execute(select(func.count()).select_from(Booking).where(Booking.lawyer_id == lawyer_id, Booking.status == "confirmed", Booking.date >= func.date('now')))
        if has_active.scalar() > 0:
            return False
        await self.session.execute(delete(LawyerDayOff).where(LawyerDayOff.lawyer_id == lawyer_id))
        await self.session.execute(delete(Lawyer).where(Lawyer.id == lawyer_id))
        await self.session.flush()
        return True
    async def get_available_lawyers_for_slot(self, date: str, time: str, service_id: int, exclude_lawyer_id: int) -> list[Lawyer]:
        from app.models.service import Service
        service = await self.session.execute(select(Service).where(Service.id == service_id))
        svc = service.scalar_one_or_none()
        if not svc:
            return []
        slots_needed = max(1, (svc.duration_minutes + 29) // 30)
        hour, minute = map(int, time.split(":"))
        slot_times = []
        for i in range(slots_needed):
            m = minute + i * 30
            h = hour + m // 60
            m = m % 60
            slot_times.append(f"{h:02d}:{m:02d}")
        booked_lawyers = set()
        for t in slot_times:
            result = await self.session.execute(select(Booking.lawyer_id).where(Booking.date == date, Booking.time == t, Booking.status == "confirmed"))
            booked_lawyers.update(row[0] for row in result.all())
        booked_lawyers.add(exclude_lawyer_id)
        result = await self.session.execute(select(Lawyer).where(Lawyer.is_active == True, Lawyer.id.notin_(booked_lawyers)).order_by(Lawyer.rating.desc()).limit(3))
        return list(result.scalars().all())
