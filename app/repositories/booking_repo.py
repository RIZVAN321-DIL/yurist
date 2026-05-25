from datetime import date as dt_date, datetime
from sqlalchemy import select, update, func
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.booking import Booking
from app.models.service import Service

class BookingRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def check_slot_available(self, lawyer_id: int, date: str, time: str, duration_minutes: int) -> tuple[bool, list[str]]:
        slots_needed = max(1, (duration_minutes + 29) // 30)
        hour, minute = map(int, time.split(":"))
        slot_times = []
        for i in range(slots_needed):
            m = minute + i * 30
            h = hour + m // 60
            m = m % 60
            slot_times.append(f"{h:02d}:{m:02d}")
        for t in slot_times:
            result = await self.session.execute(select(Booking).where(Booking.lawyer_id == lawyer_id, Booking.date == date, Booking.time == t, Booking.status == "confirmed"))
            if result.scalar_one_or_none():
                return False, slot_times
        return True, slot_times
    async def get_active_count(self, client_id: int) -> int:
        result = await self.session.execute(select(func.count()).select_from(Booking).where(Booking.client_id == client_id, Booking.status == "confirmed", Booking.date >= dt_date.today().isoformat()))
        return result.scalar() or 0
    async def get_by_id(self, booking_id: int) -> Booking | None:
        result = await self.session.execute(select(Booking).options(selectinload(Booking.client), selectinload(Booking.lawyer), selectinload(Booking.service)).where(Booking.id == booking_id))
        return result.scalar_one_or_none()
    async def create(self, booking: Booking) -> Booking:
        self.session.add(booking)
        await self.session.flush()
        return booking
    async def cancel(self, booking_id: int, reason: str = "client_cancel") -> Booking | None:
        booking = await self.get_by_id(booking_id)
        if booking and booking.status == "confirmed":
            booking.status = "cancelled"
            booking.cancel_reason = reason
            await self.session.flush()
        return booking
    async def get_client_bookings(self, client_id: int) -> list[Booking]:
        result = await self.session.execute(select(Booking).options(selectinload(Booking.client), selectinload(Booking.lawyer), selectinload(Booking.service)).where(Booking.client_id == client_id).order_by(Booking.date.desc(), Booking.time.desc()))
        return list(result.scalars().all())
    async def get_today_bookings(self, lawyer_id: int | None = None) -> list[Booking]:
        today = dt_date.today().isoformat()
        query = select(Booking).options(selectinload(Booking.client), selectinload(Booking.lawyer), selectinload(Booking.service)).where(Booking.date == today, Booking.status == "confirmed")
        if lawyer_id:
            query = query.where(Booking.lawyer_id == lawyer_id)
        result = await self.session.execute(query.order_by(Booking.time))
        return list(result.scalars().all())
    async def get_today_revenue(self) -> int:
        today = dt_date.today().isoformat()
        result = await self.session.execute(select(func.sum(Service.price)).join(Booking, Booking.service_id == Service.id).where(Booking.date == today, Booking.status == "confirmed"))
        return result.scalar() or 0
    async def get_past_confirmed(self, client_id: int) -> list[Booking]:
        today = dt_date.today().isoformat()
        now_time = datetime.now().strftime("%H:%M")
        result = await self.session.execute(select(Booking).options(selectinload(Booking.client), selectinload(Booking.lawyer), selectinload(Booking.service)).where(Booking.client_id == client_id, Booking.status == "confirmed").where((Booking.date < today) | ((Booking.date == today) & (Booking.time < now_time))).order_by(Booking.date.desc()))
        return list(result.scalars().all())
    async def get_upcoming_confirmed(self) -> list[Booking]:
        today = dt_date.today().isoformat()
        result = await self.session.execute(select(Booking).options(selectinload(Booking.client), selectinload(Booking.lawyer), selectinload(Booking.service)).where(Booking.date >= today, Booking.status == "confirmed").order_by(Booking.date, Booking.time))
        return list(result.scalars().all())
    async def mark_reminder_sent(self, booking_id: int):
        await self.session.execute(update(Booking).where(Booking.id == booking_id).values(reminder_sent=True))
        await self.session.flush()
    async def get_lawyer_day_bookings_count(self, lawyer_id: int, date: str) -> int:
        result = await self.session.execute(select(func.count()).select_from(Booking).where(Booking.lawyer_id == lawyer_id, Booking.date == date, Booking.status == "confirmed"))
        return result.scalar() or 0
    async def cancel_all_for_lawyer_date(self, lawyer_id: int, date: str, reason: str):
        await self.session.execute(update(Booking).where(Booking.lawyer_id == lawyer_id, Booking.date == date, Booking.status == "confirmed").values(status="cancelled", cancel_reason=reason))
        await self.session.flush()
    async def get_confirmed_for_lawyer_date(self, lawyer_id: int, date: str) -> list[Booking]:
        result = await self.session.execute(select(Booking).options(selectinload(Booking.client), selectinload(Booking.lawyer), selectinload(Booking.service)).where(Booking.lawyer_id == lawyer_id, Booking.date == date, Booking.status == "confirmed"))
        return list(result.scalars().all())
    async def get_booked_slots(self, lawyer_id: int, date: str) -> list[str]:
        result = await self.session.execute(select(Booking.time, Booking.duration_minutes).where(Booking.lawyer_id == lawyer_id, Booking.date == date, Booking.status == "confirmed"))
        blocked = set()
        for time_str, dur in result.all():
            slots_needed = max(1, (dur + 29) // 30)
            hour, minute = map(int, time_str.split(":"))
            for i in range(slots_needed):
                m = minute + i * 30
                h = hour + m // 60
                m = m % 60
                blocked.add(f"{h:02d}:{m:02d}")
        return sorted(blocked)
