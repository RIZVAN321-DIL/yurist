from sqlalchemy import select, update, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.client import Client

class ClientRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_by_telegram_id(self, telegram_id: int) -> Client | None:
        result = await self.session.execute(select(Client).where(Client.telegram_id == telegram_id))
        return result.scalar_one_or_none()
    async def get_by_phone(self, phone: str) -> Client | None:
        result = await self.session.execute(select(Client).where(Client.phone_number == phone))
        return result.scalar_one_or_none()
    async def get_or_create(self, telegram_id: int, chat_id: int | None = None, username: str | None = None, first_name: str | None = None, last_name: str | None = None, phone_number: str | None = None) -> Client:
        client = await self.get_by_telegram_id(telegram_id)
        if not client:
            client = Client(telegram_id=telegram_id, chat_id=chat_id or telegram_id, username=username, first_name=first_name, last_name=last_name, phone_number=phone_number)
            self.session.add(client)
            await self.session.flush()
        return client
    async def get_or_create_manual(self, first_name: str, phone_number: str | None = None) -> Client:
        if phone_number:
            client = await self.get_by_phone(phone_number)
            if client:
                return client
        client = Client(telegram_id=0, first_name=first_name, phone_number=phone_number)
        self.session.add(client)
        await self.session.flush()
        return client
    async def get_all_telegram_ids(self) -> list[int]:
        result = await self.session.execute(select(Client.telegram_id))
        return [row[0] for row in result.all() if row[0] != 0]
    async def get_total_count(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(Client))
        return result.scalar() or 0
    async def add_bonus(self, client_id: int, amount: int):
        await self.session.execute(update(Client).where(Client.id == client_id).values(bonus_balance=Client.bonus_balance + amount))
        await self.session.flush()
    async def increment_visits(self, client_id: int):
        await self.session.execute(update(Client).where(Client.id == client_id).values(total_visits=Client.total_visits + 1))
        await self.session.flush()
