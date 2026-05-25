from datetime import date, datetime
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.booking import Booking
from app.repositories.booking_repo import BookingRepository
from app.repositories.client_repo import ClientRepository
from app.repositories.lawyer_repo import LawyerRepository
from app.repositories.service_repo import ServiceRepository
from app.repositories.weekend_repo import WeekendRepository
from app.config import settings
from app.logger import logger
from app.services.notification_service import NotificationService

class BookingService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.booking_repo = BookingRepository(session)
        self.client_repo = ClientRepository(session)
        self.lawyer_repo = LawyerRepository(session)
        self.service_repo = ServiceRepository(session)
        self.weekend_repo = WeekendRepository(session)

    async def create_booking(self, telegram_id: int, chat_id: int, username: str | None, first_name: str | None, last_name: str | None, service_id: int, lawyer_id: int, booking_date: str, booking_time: str):
        today = date.today().isoformat()
        if booking_date < today:
            raise ValueError("Нельзя записаться на прошедшую дату")
        if booking_date == today:
            now = datetime.now().strftime("%H:%M")
            if booking_time <= now:
                raise ValueError("Нельзя записаться на прошедшее время")
        dt = datetime.strptime(booking_date, "%Y-%m-%d")
        weekend_days = await self.weekend_repo.get_all()
        if dt.weekday() in weekend_days:
            raise ValueError("Офис не работает в этот день")
        service = await self.service_repo.get_by_id(service_id)
        if not service or not service.is_active:
            raise ValueError("Услуга не найдена")
        lawyer = await self.lawyer_repo.get_by_id(lawyer_id)
        if not lawyer or not lawyer.is_active:
            raise ValueError("Юрист не найден")
        if await self.lawyer_repo.is_day_off(lawyer_id, booking_date):
            raise ValueError("У юриста выходной в этот день")
        client = await self.client_repo.get_or_create(telegram_id=telegram_id, chat_id=chat_id, username=username, first_name=first_name, last_name=last_name)
        active_count = await self.booking_repo.get_active_count(client.id)
        if active_count >= settings.MAX_ACTIVE_BOOKINGS:
            raise ValueError(f"У вас уже {active_count} активных записей")
        available, _ = await self.booking_repo.check_slot_available(lawyer_id, booking_date, booking_time, service.duration_minutes)
        if not available:
            raise ValueError("Слот уже занят")
        day_count = await self.booking_repo.get_lawyer_day_bookings_count(lawyer_id, booking_date)
        if day_count >= (lawyer.max_bookings_per_day or settings.DEFAULT_MAX_BOOKINGS_PER_DAY):
            alternatives = await self.lawyer_repo.get_available_lawyers_for_slot(booking_date, booking_time, service_id, lawyer_id)
            if alternatives:
                names = ", ".join([f"{m.name} (⭐{m.rating})" for m in alternatives[:3]])
                raise ValueError(f"alternatives|{names}")
            raise ValueError(f"Юрист {lawyer.name} полностью занят на этот день")
        booking = Booking(client_id=client.id, lawyer_id=lawyer.id, service_id=service.id, date=booking_date, time=booking_time, duration_minutes=service.duration_minutes)
        await self.booking_repo.create(booking)
        await self.client_repo.increment_visits(client.id)
        await self.session.commit()
        await self.session.refresh(booking)
        await self.session.refresh(booking, ["client", "lawyer", "service"])
        await NotificationService.notify_admin_new_booking(booking)
        await NotificationService.notify_client_confirmation(booking)
        await NotificationService.schedule_reminders(booking)
        logger.info(f"Запись создана: #{booking.id}")
        return {"ok": True, "booking_id": booking.id, "lawyer": lawyer.name, "service": service.name, "price": service.price, "date": booking.date, "time": booking.time}

    async def create_manual_booking(self, client_name: str, phone: str | None, service_id: int, lawyer_id: int, booking_date: str, booking_time: str, admin_id: int):
        today = date.today().isoformat()
        if booking_date < today:
            raise ValueError("Нельзя записаться на прошедшую дату")
        if booking_date == today:
            now = datetime.now().strftime("%H:%M")
            if booking_time <= now:
                raise ValueError("Нельзя записаться на прошедшее время")
        dt = datetime.strptime(booking_date, "%Y-%m-%d")
        weekend_days = await self.weekend_repo.get_all()
        if dt.weekday() in weekend_days:
            raise ValueError("Офис не работает в этот день")
        service = await self.service_repo.get_by_id(service_id)
        if not service or not service.is_active:
            raise ValueError("Услуга не найдена")
        lawyer = await self.lawyer_repo.get_by_id(lawyer_id)
        if not lawyer or not lawyer.is_active:
            raise ValueError("Юрист не найден")
        if await self.lawyer_repo.is_day_off(lawyer_id, booking_date):
            raise ValueError("У юриста выходной в этот день")
        available, _ = await self.booking_repo.check_slot_available(lawyer_id, booking_date, booking_time, service.duration_minutes)
        if not available:
            raise ValueError("Слот уже занят")
        day_count = await self.booking_repo.get_lawyer_day_bookings_count(lawyer_id, booking_date)
        if day_count >= (lawyer.max_bookings_per_day or settings.DEFAULT_MAX_BOOKINGS_PER_DAY):
            raise ValueError(f"Юрист {lawyer.name} полностью занят на этот день")
        client = await self.client_repo.get_or_create_manual(first_name=client_name, phone_number=phone)
        booking = Booking(client_id=client.id, lawyer_id=lawyer.id, service_id=service.id, date=booking_date, time=booking_time, duration_minutes=service.duration_minutes, is_manual=True, manual_client_name=client_name, manual_phone=phone)
        await self.booking_repo.create(booking)
        await self.client_repo.increment_visits(client.id)
        await self.session.commit()
        await self.session.refresh(booking)
        await self.session.refresh(booking, ["client", "lawyer", "service"])
        await NotificationService.notify_admin_new_booking(booking)
        if phone:
            tg_client = await self.client_repo.get_by_phone(phone)
            if tg_client and tg_client.telegram_id and tg_client.telegram_id != 0:
                try:
                    await NotificationService.notify_manual_booking(booking, tg_client)
                except Exception as e:
                    logger.error(f"Ошибка уведомления: {e}")
        await NotificationService.schedule_reminders(booking)
        logger.info(f"Ручная запись создана: #{booking.id}")
        return {"ok": True, "booking_id": booking.id, "lawyer": lawyer.name, "service": service.name, "price": service.price, "date": booking.date, "time": booking.time, "client_name": client_name}

    async def cancel_booking(self, booking_id: int, telegram_id: int, is_admin: bool = False):
        booking = await self.booking_repo.get_by_id(booking_id)
        if not booking:
            raise ValueError("Запись не найдена")
        if booking.status != "confirmed":
            raise ValueError("Запись уже отменена")
        if not is_admin:
            client = await self.client_repo.get_by_telegram_id(telegram_id)
            if not client or booking.client_id != client.id:
                raise ValueError("Это не ваша запись")
        reason = "admin_cancel" if is_admin else "client_cancel"
        await self.booking_repo.cancel(booking_id, reason)
        await NotificationService.remove_reminders(booking_id)
        await self.session.commit()
        return {"ok": True, "message": "Запись отменена"}

    async def set_lawyer_day_off(self, lawyer_id: int, date_str: str, reason: str | None, admin_id: int):
        lawyer = await self.lawyer_repo.get_by_id(lawyer_id)
        if not lawyer:
            raise ValueError("Юрист не найден")
        await self.lawyer_repo.add_day_off(lawyer_id, date_str, reason)
        bookings = await self.booking_repo.get_confirmed_for_lawyer_date(lawyer_id, date_str)
        for b in bookings:
            if not b.is_manual:
                await NotificationService.notify_lawyer_day_off(b, reason or "Выходной день")
            await NotificationService.remove_reminders(b.id)
        await self.booking_repo.cancel_all_for_lawyer_date(lawyer_id, date_str, "lawyer_day_off")
        await self.session.commit()
        return {"ok": True, "cancelled_bookings": len(bookings)}
