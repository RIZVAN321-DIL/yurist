from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.weekend import Weekend

class WeekendRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_all(self) -> list[int]:
        result = await self.session.execute(select(Weekend.day_of_week))
        return [row[0] for row in result.all()]
    async def set(self, days: list[int]):
        await self.session.execute(delete(Weekend))
        for d in days:
            self.session.add(Weekend(day_of_week=d))
        await self.session.flush()
