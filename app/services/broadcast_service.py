import asyncio, os
from aiogram import Bot
from aiogram.client.default import DefaultBotProperties
from aiogram.types import BufferedInputFile
from app.config import settings
from app.repositories.client_repo import ClientRepository
from app.logger import logger

class BroadcastService:
    @staticmethod
    async def send_broadcast(text: str, session, photo_path: str | None = None):
        client_repo = ClientRepository(session)
        all_ids = await client_repo.get_all_telegram_ids()
        bot = Bot(token=settings.BOT_TOKEN, default=DefaultBotProperties(parse_mode="HTML"))
        success, failed = 0, 0
        photo_bytes = None
        if photo_path:
            full_path = os.path.join(photo_path.lstrip("/"))
            if os.path.exists(full_path):
                with open(full_path, "rb") as f:
                    photo_bytes = f.read()
        for tg_id in all_ids:
            try:
                if photo_bytes:
                    await bot.send_photo(tg_id, BufferedInputFile(photo_bytes, filename="broadcast.jpg"), caption=text or "")
                else:
                    await bot.send_message(tg_id, text or "")
                success += 1
                await asyncio.sleep(0.05)
            except Exception as e:
                logger.error(f"Ошибка отправки {tg_id}: {e}")
                failed += 1
        await bot.session.close()
        return {"ok": True, "sent": success, "failed": failed}
