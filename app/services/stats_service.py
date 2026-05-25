from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.booking_repo import BookingRepository
from app.repositories.client_repo import ClientRepository

class StatsService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.booking_repo = BookingRepository(session)
        self.client_repo = ClientRepository(session)

    async def get_stats(self):
        today_bookings = await self.booking_repo.get_today_bookings()
        total_clients = await self.client_repo.get_total_count()
        today_revenue = await self.booking_repo.get_today_revenue()
        return {"today_bookings": len(today_bookings), "total_clients": total_clients, "today_revenue": today_revenue}
