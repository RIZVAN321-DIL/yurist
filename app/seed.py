from sqlalchemy import select, func
from app.database import async_session
from app.models.lawyer import Lawyer
from app.models.service import Service
from app.logger import logger

LAWYERS = [
    {"id":1,"name":"Иванов Иван Иванович","photo_url":None,"rating":4.9,"experience_years":15,"telegram_id":None,"max_bookings_per_day":10,"is_admin":False},
    {"id":2,"name":"Петрова Анна Сергеевна","photo_url":None,"rating":4.8,"experience_years":10,"telegram_id":None,"max_bookings_per_day":10,"is_admin":False},
    {"id":3,"name":"Сидоров Василий Кузьмич","photo_url":None,"rating":4.7,"experience_years":8,"telegram_id":None,"max_bookings_per_day":10,"is_admin":False},
]
SERVICES = [
    {"id":1,"name":"Консультация","price":2000,"duration_minutes":40,"category":"consult"},
    {"id":2,"name":"Составление договора","price":5000,"duration_minutes":60,"category":"docs"},
    {"id":3,"name":"Сопровождение в суде","price":15000,"duration_minutes":90,"category":"court"},
    {"id":4,"name":"Защита по уголовным делам","price":25000,"duration_minutes":120,"category":"criminal"},
]

async def seed_database():
    async with async_session() as session:
        if not await session.scalar(select(func.count()).select_from(Lawyer)):
            for m in LAWYERS:
                session.add(Lawyer(**m))
            await session.commit()
            logger.info(f"Юристы: {len(LAWYERS)}")
        if not await session.scalar(select(func.count()).select_from(Service)):
            for s in SERVICES:
                session.add(Service(**s))
            await session.commit()
            logger.info(f"Услуги: {len(SERVICES)}")
