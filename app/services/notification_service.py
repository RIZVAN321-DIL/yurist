from datetime import datetime, timedelta
from aiogram import Bot
from aiogram.client.default import DefaultBotProperties
from app.config import settings
from app.core.scheduler import scheduler
from app.logger import logger

reminder_jobs: dict[int, list[str]] = {}

class NotificationService:
    @staticmethod
    async def get_bot() -> Bot:
        return Bot(token=settings.BOT_TOKEN, default=DefaultBotProperties(parse_mode="HTML"))

    @classmethod
    async def notify_admin_new_booking(cls, booking):
        try:
            bot = await cls.get_bot()
            client_display = booking.client.first_name or booking.manual_client_name or "—"
            text = f"🔔 <b>Новая запись!</b>\nКлиент: {client_display}\nЮрист: {booking.lawyer.name}\nУслуга: {booking.service.name}\nДата: {booking.date}\nВремя: {booking.time}\nДлительность: {booking.duration_minutes} мин\nЦена: {booking.service.price}₽"
            for admin_id in settings.ADMIN_IDS:
                await bot.send_message(admin_id, text)
            if booking.lawyer.telegram_id:
                try:
                    await bot.send_message(booking.lawyer.telegram_id, text)
                except Exception as e:
                    logger.error(f"Ошибка уведомления юристу: {e}")
            await bot.session.close()
        except Exception as e:
            logger.error(f"Ошибка уведомления: {e}")

    @classmethod
    async def notify_client_confirmation(cls, booking):
        try:
            if booking.is_manual and (not booking.client or booking.client.telegram_id == 0):
                return
            bot = await cls.get_bot()
            text = f"✅ <b>Запись подтверждена!</b>\n\nУслуга: {booking.service.name}\nЮрист: {booking.lawyer.name}\nДата: {booking.date}\nВремя: {booking.time}\nЦена: {booking.service.price}₽\n\n📍 ул. Ленина, 10"
            await bot.send_message(booking.client.telegram_id, text)
            await bot.session.close()
        except Exception as e:
            logger.error(f"Ошибка уведомления клиенту: {e}")

    @classmethod
    async def notify_manual_booking(cls, booking, client):
        try:
            if client.telegram_id == 0:
                return
            bot = await cls.get_bot()
            text = f"📞 <b>Вас записали по звонку!</b>\n\nУслуга: {booking.service.name}\nЮрист: {booking.lawyer.name}\nДата: {booking.date}\nВремя: {booking.time}\nЦена: {booking.service.price}₽\n\n📍 ул. Ленина, 10"
            await bot.send_message(client.telegram_id, text)
            await bot.session.close()
        except Exception as e:
            logger.error(f"Ошибка уведомления о ручной записи: {e}")

    @classmethod
    async def notify_lawyer_day_off(cls, booking, reason: str):
        try:
            if booking.is_manual:
                return
            bot = await cls.get_bot()
            text = f"😔 <b>Юрист {booking.lawyer.name} не сможет вас принять {booking.date} в {booking.time}.</b>\n\nПричина: {reason or 'Выходной день'}\n\nЗапишитесь на другую дату.\nПриносим извинения!"
            await bot.send_message(booking.client.telegram_id, text)
            await bot.session.close()
        except Exception as e:
            logger.error(f"Ошибка уведомления о выходном: {e}")

    @classmethod
    async def schedule_reminders(cls, booking):
        try:
            if booking.is_manual and (not booking.client or booking.client.telegram_id == 0):
                return
            dt = datetime.strptime(f"{booking.date} {booking.time}", "%Y-%m-%d %H:%M")
            reminder_24h = dt - timedelta(hours=24)
            reminder_2h = dt - timedelta(hours=2)
            now = datetime.now()
            job_ids = []
            if reminder_24h > now:
                job_24 = scheduler.add_job(cls._send_reminder, "date", run_date=reminder_24h, args=[booking.id, 24], misfire_grace_time=300)
                job_ids.append(job_24.id)
            if reminder_2h > now:
                job_2 = scheduler.add_job(cls._send_reminder, "date", run_date=reminder_2h, args=[booking.id, 2], misfire_grace_time=300)
                job_ids.append(job_2.id)
            if job_ids:
                reminder_jobs[booking.id] = job_ids
                logger.info(f"Напоминания для #{booking.id}: {len(job_ids)} шт.")
        except Exception as e:
            logger.error(f"Ошибка планирования напоминаний: {e}")

    @classmethod
    async def remove_reminders(cls, booking_id: int):
        reminder_jobs.pop(booking_id, None)

    @classmethod
    async def _send_reminder(cls, booking_id: int, hours: int):
        from app.database import async_session
        from app.repositories.booking_repo import BookingRepository
        async with async_session() as session:
            repo = BookingRepository(session)
            booking = await repo.get_by_id(booking_id)
            if not booking or booking.status != "confirmed":
                return
            if booking.is_manual and (not booking.client or booking.client.telegram_id == 0):
                return
            try:
                bot = await cls.get_bot()
                if hours == 24:
                    text = f"🔔 <b>Напоминаем!</b>\n\nЗавтра в {booking.time} у вас запись к {booking.lawyer.name}.\nУслуга: {booking.service.name}\n📍 ул. Ленина, 10"
                else:
                    text = f"⏰ <b>Запись через 2 часа!</b>\n\nСегодня в {booking.time}, юрист: {booking.lawyer.name}\nУслуга: {booking.service.name}\n📍 ул. Ленина, 10"
                await bot.send_message(booking.client.telegram_id, text)
                await bot.session.close()
                await repo.mark_reminder_sent(booking_id)
                await session.commit()
            except Exception as e:
                logger.error(f"Ошибка отправки напоминания: {e}")

    @classmethod
    async def restore_reminders(cls):
        from app.database import async_session
        from app.repositories.booking_repo import BookingRepository
        async with async_session() as session:
            repo = BookingRepository(session)
            bookings = await repo.get_upcoming_confirmed()
            count = 0
            for b in bookings:
                if not b.is_manual or (b.client and b.client.telegram_id != 0):
                    await cls.schedule_reminders(b)
                    count += 1
            logger.info(f"Восстановлено напоминаний для {count} записей")
