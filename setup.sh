#!/bin/bash

mkdir -p app/core app/models app/repositories app/services app/api/routes app/api/schemas app/bot/handlers app/static/uploads
touch app/static/uploads/.gitkeep

cat > .env << 'ENVEOF'
BOT_TOKEN=8649327502:AAEaG_RIjuWC0bJUSNfPxLraX019g7Kxphw
ADMIN_IDS=5724746367
DATABASE_URL=sqlite+aiosqlite:///./yurist.db
API_HOST=0.0.0.0
API_PORT=10000
BASE_URL=https://твой-домен.bothost.tech
SECRET_KEY=yurist-secret-2025
MAX_ACTIVE_BOOKINGS=3
BONUS_VISITS_INTERVAL=5
BONUS_AMOUNT=200
BOT_USERNAME=Yurist_Konsultant_bot
DEFAULT_MAX_BOOKINGS_PER_DAY=10
ENVEOF

cat > runtime.txt << 'EOF'
python-3.12
EOF

cat > Procfile << 'EOF'
web: uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
EOF

cat > requirements.txt << 'EOF'
aiogram>=3.7.0
fastapi>=0.115.0
uvicorn[standard]>=0.32.0
sqlalchemy[asyncio]>=2.0.36
aiosqlite>=0.20.0
pydantic>=2.10.0
pydantic-settings>=2.6.0
python-dotenv>=1.0.0
loguru>=0.7.0
python-multipart>=0.0.12
apscheduler>=3.10.4
httpx>=0.27.0
aiofiles>=23.0
Pillow>=10.0.0
EOF

cat > Dockerfile << 'EOF'
FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN mkdir -p /app/data /app/app/static/uploads
ENV DATABASE_URL=sqlite+aiosqlite:////app/data/yurist.db
EXPOSE 8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
EOF

cat > app/__init__.py << 'EOF'
EOF

cat > app/config.py << 'EOF'
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import field_validator

class Settings(BaseSettings):
    BOT_TOKEN: str
    DATABASE_URL: str = "sqlite+aiosqlite:///./yurist.db"
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    BASE_URL: str = ""
    ADMIN_IDS: list[int] = []
    SECRET_KEY: str = "change-me"
    MAX_ACTIVE_BOOKINGS: int = 3
    BONUS_VISITS_INTERVAL: int = 5
    BONUS_AMOUNT: int = 200
    BOT_USERNAME: str = ""
    DEFAULT_MAX_BOOKINGS_PER_DAY: int = 10
    UPLOAD_DIR: str = "app/static/uploads"
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")
    @field_validator("ADMIN_IDS", mode="before")
    @classmethod
    def parse_admins(cls, value):
        if isinstance(value, str):
            return [int(x.strip()) for x in value.split(",") if x.strip()]
        if isinstance(value, list):
            return value
        return []

settings = Settings()
EOF

cat > app/logger.py << 'EOF'
import logging, sys

def setup_logger():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(name)s | %(message)s", handlers=[logging.StreamHandler(sys.stdout), logging.FileHandler("bot.log", encoding="utf-8")])
    return logging.getLogger("yurist")

logger = setup_logger()
EOF

cat > app/database.py << 'EOF'
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
from app.config import settings

class Base(DeclarativeBase):
    pass

engine = create_async_engine(settings.DATABASE_URL, echo=False, pool_pre_ping=True, future=True)
async_session = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

async def get_session():
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()
EOF

cat > app/seed.py << 'EOF'
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
EOF

cat > app/main.py << 'EOF'
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from app.database import engine, Base
from app.seed import seed_database
from app.logger import logger
from app.core.scheduler import scheduler
from app.services.notification_service import NotificationService
from app.api.routes.booking import router as booking_router
from app.api.routes.services import router as services_router
from app.api.routes.lawyers import router as lawyers_router
from app.api.routes.slots import router as slots_router
from app.api.routes.reviews import router as reviews_router
from app.api.routes.stats import router as stats_router
from app.api.routes.broadcast import router as broadcast_router
from app.api.routes.profile import router as profile_router
from app.api.routes.upload import router as upload_router
from app.api.routes.weekend import router as weekend_router
import app.models

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("API start")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await seed_database()
    scheduler.start()
    await NotificationService.restore_reminders()
    logger.info("API ready")
    yield
    scheduler.shutdown(wait=False)
    logger.info("API stop")

app = FastAPI(title="Yurist API", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(booking_router)
app.include_router(services_router)
app.include_router(lawyers_router)
app.include_router(slots_router)
app.include_router(reviews_router)
app.include_router(stats_router)
app.include_router(broadcast_router)
app.include_router(profile_router)
app.include_router(upload_router)
app.include_router(weekend_router)
app.mount("/static", StaticFiles(directory="app/static"), name="static")

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/mini-app")
async def mini_app():
    return FileResponse("app/static/index.html")
EOF

cat > app/core/__init__.py << 'EOF'
EOF

cat > app/core/scheduler.py << 'EOF'
from apscheduler.schedulers.asyncio import AsyncIOScheduler
scheduler = AsyncIOScheduler()
EOF

cat > app/core/security.py << 'EOF'
from app.config import settings

def is_admin(telegram_id: int) -> bool:
    return telegram_id in settings.ADMIN_IDS
EOF

echo "Часть 1 готова"
cat > app/models/__init__.py << 'EOF'
from app.models.client import Client
from app.models.lawyer import Lawyer
from app.models.service import Service
from app.models.booking import Booking
from app.models.review import Review
from app.models.lawyer_day_off import LawyerDayOff
from app.models.audit_log import AuditLog
from app.models.weekend import Weekend
EOF

cat > app/models/client.py << 'EOF'
import secrets
from sqlalchemy import String, Integer, BigInteger, Boolean, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Client(Base):
    __tablename__ = "clients"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    telegram_id: Mapped[int] = mapped_column(BigInteger, unique=True, index=True)
    chat_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    username: Mapped[str | None] = mapped_column(String(255), nullable=True)
    first_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    last_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    phone_number: Mapped[str | None] = mapped_column(String(20), nullable=True, index=True)
    bonus_balance: Mapped[int] = mapped_column(Integer, default=0)
    total_visits: Mapped[int] = mapped_column(Integer, default=0)
    referral_code: Mapped[str] = mapped_column(String(50), unique=True, default=lambda: secrets.token_hex(4))
    referral_from: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    is_blocked: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    bookings = relationship("Booking", back_populates="client", cascade="all, delete-orphan")
    reviews = relationship("Review", back_populates="client", cascade="all, delete-orphan")
EOF

cat > app/models/lawyer.py << 'EOF'
from sqlalchemy import String, Float, Integer, Boolean, BigInteger
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Lawyer(Base):
    __tablename__ = "lawyers"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255))
    photo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    rating: Mapped[float] = mapped_column(Float, default=5.0)
    total_reviews: Mapped[int] = mapped_column(Integer, default=0)
    experience_years: Mapped[int] = mapped_column(Integer, default=0)
    telegram_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    max_bookings_per_day: Mapped[int] = mapped_column(Integer, default=10)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    bookings = relationship("Booking", back_populates="lawyer")
    reviews = relationship("Review", back_populates="lawyer")
    days_off = relationship("LawyerDayOff", back_populates="lawyer", cascade="all, delete-orphan")
EOF

cat > app/models/service.py << 'EOF'
from sqlalchemy import String, Integer, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Service(Base):
    __tablename__ = "services"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255))
    price: Mapped[int] = mapped_column(Integer)
    duration_minutes: Mapped[int] = mapped_column(Integer)
    category: Mapped[str | None] = mapped_column(String(100), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    bookings = relationship("Booking", back_populates="service")
EOF

cat > app/models/booking.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Booking(Base):
    __tablename__ = "bookings"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("clients.id"))
    lawyer_id: Mapped[int] = mapped_column(ForeignKey("lawyers.id"))
    service_id: Mapped[int] = mapped_column(ForeignKey("services.id"))
    date: Mapped[str] = mapped_column(String(10))
    time: Mapped[str] = mapped_column(String(5))
    duration_minutes: Mapped[int] = mapped_column(Integer, default=30)
    status: Mapped[str] = mapped_column(String(50), default="confirmed")
    cancel_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_manual: Mapped[bool] = mapped_column(Boolean, default=False)
    manual_client_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    manual_phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    reminder_sent: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    client = relationship("Client", back_populates="bookings")
    lawyer = relationship("Lawyer", back_populates="bookings")
    service = relationship("Service", back_populates="bookings")
EOF

cat > app/models/review.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Review(Base):
    __tablename__ = "reviews"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("clients.id"))
    lawyer_id: Mapped[int] = mapped_column(ForeignKey("lawyers.id"))
    booking_id: Mapped[int] = mapped_column(ForeignKey("bookings.id"), unique=True)
    rating: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    is_approved: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    client = relationship("Client", back_populates="reviews")
    lawyer = relationship("Lawyer", back_populates="reviews")
EOF

cat > app/models/lawyer_day_off.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class LawyerDayOff(Base):
    __tablename__ = "lawyer_days_off"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    lawyer_id: Mapped[int] = mapped_column(ForeignKey("lawyers.id"))
    date: Mapped[str] = mapped_column(String(10))
    reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    lawyer = relationship("Lawyer", back_populates="days_off")
EOF

cat > app/models/audit_log.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, BigInteger
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class AuditLog(Base):
    __tablename__ = "audit_logs"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    admin_id: Mapped[int] = mapped_column(BigInteger)
    action: Mapped[str] = mapped_column(String(255))
    details: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > app/models/weekend.py << 'EOF'
from sqlalchemy import String, Integer
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class Weekend(Base):
    __tablename__ = "weekends"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    day_of_week: Mapped[int] = mapped_column(Integer, unique=True)
EOF

echo "Часть 2 готова"
cat > app/repositories/__init__.py << 'EOF'
EOF

cat > app/repositories/client_repo.py << 'EOF'
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
EOF

cat > app/repositories/lawyer_repo.py << 'EOF'
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
EOF

cat > app/repositories/service_repo.py << 'EOF'
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
EOF

cat > app/repositories/booking_repo.py << 'EOF'
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
EOF

cat > app/repositories/review_repo.py << 'EOF'
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.review import Review

class ReviewRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_by_booking_id(self, booking_id: int) -> Review | None:
        result = await self.session.execute(select(Review).where(Review.booking_id == booking_id))
        return result.scalar_one_or_none()
    async def create(self, review: Review) -> Review:
        self.session.add(review)
        await self.session.flush()
        return review
    async def count_by_client(self, client_id: int) -> int:
        result = await self.session.execute(select(func.count()).select_from(Review).where(Review.client_id == client_id))
        return result.scalar() or 0
    async def get_by_client(self, client_id: int) -> list[Review]:
        result = await self.session.execute(select(Review).options(selectinload(Review.lawyer)).where(Review.client_id == client_id).order_by(Review.created_at.desc()))
        return list(result.scalars().all())
    async def get_all_reviews(self, lawyer_id: int | None = None, limit: int = 100) -> list[Review]:
        query = select(Review).options(selectinload(Review.client), selectinload(Review.lawyer))
        if lawyer_id:
            query = query.where(Review.lawyer_id == lawyer_id)
        result = await self.session.execute(query.order_by(Review.created_at.desc()).limit(limit))
        return list(result.scalars().all())
EOF

cat > app/repositories/audit_repo.py << 'EOF'
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.audit_log import AuditLog

class AuditRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def log(self, admin_id: int, action: str, details: str = ""):
        self.session.add(AuditLog(admin_id=admin_id, action=action, details=details))
        await self.session.flush()
    async def get_recent(self, limit: int = 50) -> list[AuditLog]:
        result = await self.session.execute(select(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit))
        return list(result.scalars().all())
EOF

cat > app/repositories/weekend_repo.py << 'EOF'
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
EOF

echo "Часть 3 готова"
cat > app/services/__init__.py << 'EOF'
EOF

cat > app/services/notification_service.py << 'EOF'
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
EOF

cat > app/services/booking_service.py << 'EOF'
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
EOF

echo "Часть 4 готова (продолжение следует)"
cat > app/services/review_service.py << 'EOF'
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.review import Review
from app.repositories.review_repo import ReviewRepository
from app.repositories.booking_repo import BookingRepository
from app.repositories.client_repo import ClientRepository
from app.repositories.lawyer_repo import LawyerRepository
from app.config import settings

class ReviewService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.review_repo = ReviewRepository(session)
        self.booking_repo = BookingRepository(session)
        self.client_repo = ClientRepository(session)
        self.lawyer_repo = LawyerRepository(session)

    async def create_review(self, client_id: int, booking_id: int, rating: int, comment: str | None = None):
        booking = await self.booking_repo.get_by_id(booking_id)
        if not booking:
            raise ValueError("Запись не найдена")
        if booking.client_id != client_id:
            raise ValueError("Это не ваша запись")
        existing = await self.review_repo.get_by_booking_id(booking_id)
        if existing:
            raise ValueError("Отзыв уже оставлен")
        review = Review(client_id=client_id, lawyer_id=booking.lawyer_id, booking_id=booking_id, rating=rating, comment=comment)
        await self.review_repo.create(review)
        await self.lawyer_repo.update_rating(booking.lawyer_id)
        total_reviews = await self.review_repo.count_by_client(client_id)
        if total_reviews % settings.BONUS_VISITS_INTERVAL == 0:
            await self.client_repo.add_bonus(client_id, settings.BONUS_AMOUNT)
            await self.session.commit()
            return {"ok": True, "review_id": review.id, "bonus_added": True, "bonus_amount": settings.BONUS_AMOUNT}
        await self.session.commit()
        return {"ok": True, "review_id": review.id, "bonus_added": False}
EOF

cat > app/services/stats_service.py << 'EOF'
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
EOF

cat > app/services/broadcast_service.py << 'EOF'
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
EOF

cat > app/api/__init__.py << 'EOF'
EOF

cat > app/api/schemas/__init__.py << 'EOF'
EOF

cat > app/api/schemas/booking.py << 'EOF'
from pydantic import BaseModel, Field

class BookingCreateSchema(BaseModel):
    telegram_id: int
    chat_id: int
    username: str | None = None
    first_name: str | None = None
    last_name: str | None = None
    service_id: int = Field(gt=0)
    lawyer_id: int = Field(gt=0)
    date: str
    time: str

class ManualBookingSchema(BaseModel):
    admin_telegram_id: int
    client_name: str = Field(min_length=1, max_length=255)
    phone: str | None = None
    service_id: int = Field(gt=0)
    lawyer_id: int = Field(gt=0)
    date: str
    time: str

class BookingCancelSchema(BaseModel):
    telegram_id: int
    booking_id: int

class AdminCancelSchema(BaseModel):
    admin_telegram_id: int
    booking_id: int

class LawyerDayOffSchema(BaseModel):
    admin_telegram_id: int
    lawyer_id: int
    date: str
    reason: str | None = None
EOF

cat > app/api/schemas/lawyer.py << 'EOF'
from pydantic import BaseModel, Field

class LawyerCreateSchema(BaseModel):
    admin_telegram_id: int
    name: str = Field(min_length=1, max_length=255)
    photo_url: str | None = None
    experience_years: int = Field(default=0, ge=0)
    telegram_id: int | None = None
    max_bookings_per_day: int = Field(default=10, ge=1)
    is_admin: bool = False

class LawyerUpdateSchema(BaseModel):
    admin_telegram_id: int
    name: str | None = None
    photo_url: str | None = None
    experience_years: int | None = None
    telegram_id: int | None = None
    max_bookings_per_day: int | None = None
    is_admin: bool | None = None

class LawyerToggleSchema(BaseModel):
    admin_telegram_id: int
    lawyer_id: int
EOF

cat > app/api/schemas/service.py << 'EOF'
from pydantic import BaseModel, Field

class ServiceCreateSchema(BaseModel):
    admin_telegram_id: int
    name: str = Field(min_length=1, max_length=255)
    price: int = Field(gt=0)
    duration_minutes: int = Field(gt=0)
    category: str | None = None

class ServiceUpdateSchema(BaseModel):
    admin_telegram_id: int
    name: str | None = None
    price: int | None = None
    duration_minutes: int | None = None
    category: str | None = None

class ServiceToggleSchema(BaseModel):
    admin_telegram_id: int
    service_id: int
EOF

cat > app/api/schemas/review.py << 'EOF'
from pydantic import BaseModel, Field

class ReviewCreateSchema(BaseModel):
    telegram_id: int
    booking_id: int
    rating: int = Field(ge=1, le=5)
    comment: str | None = None
EOF

cat > app/api/schemas/response.py << 'EOF'
from pydantic import BaseModel

class BookingResponse(BaseModel):
    ok: bool
    booking_id: int | None = None
    lawyer: str | None = None
    service: str | None = None
    price: int | None = None
    date: str | None = None
    time: str | None = None
    message: str | None = None
    client_name: str | None = None

class ReviewResponse(BaseModel):
    ok: bool
    review_id: int | None = None
    bonus_added: bool = False
    bonus_amount: int = 0

class BroadcastSchema(BaseModel):
    admin_telegram_id: int
    text: str = ""
    photo_path: str | None = None
EOF

cat > app/api/routes/__init__.py << 'EOF'
EOF

cat > app/api/routes/upload.py << 'EOF'
import uuid, os
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from app.core.security import is_admin
from app.config import settings
from PIL import Image

router = APIRouter(prefix="/api", tags=["upload"])

@router.post("/admin/upload-photo")
async def upload_photo(admin_telegram_id: int = Form(...), photo: UploadFile = File(...)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    if not photo.content_type or not photo.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Только изображения")
    content = await photo.read()
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Фото больше 10 МБ")
    ext = os.path.splitext(photo.filename or "photo.jpg")[1] or ".jpg"
    filename = f"{uuid.uuid4().hex}{ext}"
    upload_dir = settings.UPLOAD_DIR
    os.makedirs(upload_dir, exist_ok=True)
    filepath = os.path.join(upload_dir, filename)
    with open(filepath, "wb") as f:
        f.write(content)
    try:
        img = Image.open(filepath)
        img.thumbnail((300, 300))
        img.save(filepath, quality=85)
    except:
        pass
    return {"ok": True, "path": f"/static/uploads/{filename}"}
EOF

cat > app/api/routes/booking.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.api.schemas.booking import BookingCreateSchema, ManualBookingSchema, BookingCancelSchema, AdminCancelSchema, LawyerDayOffSchema
from app.services.booking_service import BookingService
from app.core.security import is_admin
from app.repositories.audit_repo import AuditRepository

router = APIRouter(prefix="/api", tags=["booking"])

@router.post("/book")
async def create_booking(data: BookingCreateSchema, session: AsyncSession = Depends(get_session)):
    try:
        service = BookingService(session)
        result = await service.create_booking(data.telegram_id, data.chat_id, data.username, data.first_name, data.last_name, data.service_id, data.lawyer_id, data.date, data.time)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/admin/manual-booking")
async def create_manual_booking(data: ManualBookingSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    try:
        service = BookingService(session)
        result = await service.create_manual_booking(data.client_name, data.phone, data.service_id, data.lawyer_id, data.date, data.time, data.admin_telegram_id)
        await AuditRepository(session).log(data.admin_telegram_id, "manual_booking", data.client_name)
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/cancel")
async def cancel_booking(data: BookingCancelSchema, session: AsyncSession = Depends(get_session)):
    try:
        return await BookingService(session).cancel_booking(data.booking_id, data.telegram_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/admin/cancel")
async def admin_cancel(data: AdminCancelSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    try:
        result = await BookingService(session).cancel_booking(data.booking_id, data.admin_telegram_id, True)
        await AuditRepository(session).log(data.admin_telegram_id, "cancel_booking", str(data.booking_id))
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/admin/lawyer-day-off")
async def set_lawyer_day_off(data: LawyerDayOffSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    try:
        result = await BookingService(session).set_lawyer_day_off(data.lawyer_id, data.date, data.reason, data.admin_telegram_id)
        await AuditRepository(session).log(data.admin_telegram_id, "lawyer_day_off", f"lawyer={data.lawyer_id} date={data.date}")
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
EOF

cat > app/api/routes/slots.py << 'EOF'
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.booking_repo import BookingRepository

router = APIRouter(prefix="/api", tags=["slots"])

@router.get("/booked-slots")
async def get_booked_slots(date: str = Query(...), lawyer_id: int = Query(...), session: AsyncSession = Depends(get_session)):
    times = await BookingRepository(session).get_booked_slots(lawyer_id, date)
    return [{"time": t} for t in times]
EOF

cat > app/api/routes/services.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.service_repo import ServiceRepository
from app.repositories.audit_repo import AuditRepository
from app.api.schemas.service import ServiceCreateSchema, ServiceUpdateSchema, ServiceToggleSchema
from app.models.service import Service
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["services"])

@router.get("/services")
async def get_services(session: AsyncSession = Depends(get_session)):
    services = await ServiceRepository(session).get_all_active()
    return [{"id": s.id, "name": s.name, "price": s.price, "duration": s.duration_minutes, "category": s.category} for s in services]

@router.get("/admin/services")
async def get_all_services(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    services = await ServiceRepository(session).get_all()
    return [{"id": s.id, "name": s.name, "price": s.price, "duration": s.duration_minutes, "category": s.category, "is_active": s.is_active} for s in services]

@router.post("/admin/services")
async def create_service(data: ServiceCreateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    s = Service(name=data.name, price=data.price, duration_minutes=data.duration_minutes, category=data.category)
    result = await ServiceRepository(session).create(s)
    await AuditRepository(session).log(data.admin_telegram_id, "create_service", data.name)
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/admin/services/{service_id}")
async def update_service(service_id: int, data: ServiceUpdateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    updates = {k: v for k, v in data.model_dump(exclude={"admin_telegram_id"}).items() if v is not None}
    if updates:
        await ServiceRepository(session).update_fields(service_id, **updates)
        await AuditRepository(session).log(data.admin_telegram_id, "update_service", str(service_id))
        await session.commit()
    return {"ok": True}

@router.post("/admin/services/{service_id}/toggle")
async def toggle_service(service_id: int, data: ServiceToggleSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    s = await ServiceRepository(session).toggle_active(service_id)
    if not s:
        raise HTTPException(status_code=404)
    await AuditRepository(session).log(data.admin_telegram_id, "toggle_service", str(service_id))
    await session.commit()
    return {"ok": True, "is_active": s.is_active}

@router.delete("/admin/services/{service_id}")
async def delete_service(service_id: int, admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    ok = await ServiceRepository(session).delete(service_id)
    if not ok:
        raise HTTPException(status_code=400, detail="Нельзя удалить услугу с активными записями")
    await AuditRepository(session).log(admin_telegram_id, "delete_service", str(service_id))
    await session.commit()
    return {"ok": True}
EOF

cat > app/api/routes/lawyers.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.lawyer_repo import LawyerRepository
from app.repositories.audit_repo import AuditRepository
from app.api.schemas.lawyer import LawyerCreateSchema, LawyerUpdateSchema, LawyerToggleSchema
from app.models.lawyer import Lawyer
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["lawyers"])

@router.get("/lawyers")
async def get_lawyers(session: AsyncSession = Depends(get_session)):
    lawyers = await LawyerRepository(session).get_all_active()
    return [{"id": l.id, "name": l.name, "photo": l.photo_url, "rating": l.rating, "experience": l.experience_years, "max_bookings": l.max_bookings_per_day} for l in lawyers]

@router.get("/admin/lawyers")
async def get_all_lawyers(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    lawyers = await LawyerRepository(session).get_all()
    return [{"id": l.id, "name": l.name, "photo": l.photo_url, "rating": l.rating, "experience": l.experience_years, "telegram_id": l.telegram_id, "max_bookings": l.max_bookings_per_day, "is_admin": l.is_admin, "is_active": l.is_active} for l in lawyers]

@router.post("/admin/lawyers")
async def create_lawyer(data: LawyerCreateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    l = Lawyer(name=data.name, photo_url=data.photo_url, experience_years=data.experience_years, telegram_id=data.telegram_id, max_bookings_per_day=data.max_bookings_per_day, is_admin=data.is_admin)
    result = await LawyerRepository(session).create(l)
    await AuditRepository(session).log(data.admin_telegram_id, "create_lawyer", data.name)
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/admin/lawyers/{lawyer_id}")
async def update_lawyer(lawyer_id: int, data: LawyerUpdateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    updates = {k: v for k, v in data.model_dump(exclude={"admin_telegram_id"}).items() if v is not None}
    if updates:
        await LawyerRepository(session).update_fields(lawyer_id, **updates)
        await AuditRepository(session).log(data.admin_telegram_id, "update_lawyer", str(lawyer_id))
        await session.commit()
    return {"ok": True}

@router.post("/admin/lawyers/{lawyer_id}/toggle")
async def toggle_lawyer(lawyer_id: int, data: LawyerToggleSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    l = await LawyerRepository(session).toggle_active(lawyer_id)
    if not l:
        raise HTTPException(status_code=404)
    await AuditRepository(session).log(data.admin_telegram_id, "toggle_lawyer", str(lawyer_id))
    await session.commit()
    return {"ok": True, "is_active": l.is_active}

@router.delete("/admin/lawyers/{lawyer_id}")
async def delete_lawyer(lawyer_id: int, admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    ok = await LawyerRepository(session).delete(lawyer_id)
    if not ok:
        raise HTTPException(status_code=400, detail="Нельзя удалить юриста с активными записями")
    await AuditRepository(session).log(admin_telegram_id, "delete_lawyer", str(lawyer_id))
    await session.commit()
    return {"ok": True}
EOF

cat > app/api/routes/reviews.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.api.schemas.review import ReviewCreateSchema
from app.services.review_service import ReviewService
from app.repositories.client_repo import ClientRepository
from app.repositories.review_repo import ReviewRepository
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["reviews"])

@router.post("/reviews")
async def create_review(data: ReviewCreateSchema, session: AsyncSession = Depends(get_session)):
    client = await ClientRepository(session).get_by_telegram_id(data.telegram_id)
    if not client:
        raise HTTPException(status_code=404, detail="Клиент не найден")
    try:
        return await ReviewService(session).create_review(client.id, data.booking_id, data.rating, data.comment)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/my-reviews")
async def get_my_reviews(telegram_id: int, session: AsyncSession = Depends(get_session)):
    client = await ClientRepository(session).get_by_telegram_id(telegram_id)
    if not client:
        return []
    reviews = await ReviewRepository(session).get_by_client(client.id)
    return [{"id": r.id, "lawyer_name": r.lawyer.name if r.lawyer else "—", "rating": r.rating, "comment": r.comment} for r in reviews]

@router.get("/admin/reviews")
async def get_all_reviews(admin_telegram_id: int, lawyer_id: int | None = Query(default=None), session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    reviews = await ReviewRepository(session).get_all_reviews(lawyer_id)
    return [{"id": r.id, "client_name": r.client.first_name or "—", "lawyer_name": r.lawyer.name if r.lawyer else "—", "rating": r.rating, "comment": r.comment} for r in reviews]
EOF

cat > app/api/routes/stats.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.services.stats_service import StatsService
from app.repositories.booking_repo import BookingRepository
from app.repositories.audit_repo import AuditRepository
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["stats"])

@router.get("/admin/stats")
async def get_stats(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    return await StatsService(session).get_stats()

@router.get("/admin/today-bookings")
async def get_today_bookings(admin_telegram_id: int, lawyer_id: int | None = Query(default=None), session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    bookings = await BookingRepository(session).get_today_bookings(lawyer_id)
    return [{"id": b.id, "client_name": b.client.first_name or b.manual_client_name or "—", "lawyer": b.lawyer.name, "service": b.service.name, "time": b.time, "price": b.service.price, "is_manual": b.is_manual} for b in bookings]

@router.get("/admin/audit-log")
async def get_audit_log(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    logs = await AuditRepository(session).get_recent()
    return [{"id": l.id, "admin_id": l.admin_id, "action": l.action, "details": l.details} for l in logs]
EOF

cat > app/api/routes/broadcast.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.api.schemas.response import BroadcastSchema
from app.services.broadcast_service import BroadcastService
from app.repositories.audit_repo import AuditRepository
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["broadcast"])

@router.post("/admin/broadcast")
async def send_broadcast(data: BroadcastSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    result = await BroadcastService.send_broadcast(data.text, session, data.photo_path)
    await AuditRepository(session).log(data.admin_telegram_id, "broadcast", f"sent={result['sent']}")
    await session.commit()
    return result
EOF

cat > app/api/routes/profile.py << 'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.client_repo import ClientRepository
from app.repositories.booking_repo import BookingRepository
from app.repositories.review_repo import ReviewRepository
from app.repositories.lawyer_repo import LawyerRepository
from app.config import settings

router = APIRouter(prefix="/api", tags=["profile"])

@router.get("/profile")
async def get_profile(telegram_id: int, session: AsyncSession = Depends(get_session)):
    client = await ClientRepository(session).get_by_telegram_id(telegram_id)
    if not client:
        return {"exists": False}
    bookings = await BookingRepository(session).get_client_bookings(client.id)
    past = await BookingRepository(session).get_past_confirmed(client.id)
    reviews = await ReviewRepository(session).get_by_client(client.id)
    all_lawyers = await LawyerRepository(session).get_all()
    lawyer_info = None
    for l in all_lawyers:
        if l.telegram_id == telegram_id:
            lawyer_info = {"lawyer_id": l.id, "is_admin": l.is_admin, "name": l.name}
            break
    return {
        "exists": True, "first_name": client.first_name, "bonus_balance": client.bonus_balance,
        "total_visits": client.total_visits, "referral_code": client.referral_code,
        "visits_to_next_bonus": settings.BONUS_VISITS_INTERVAL - (client.total_visits % settings.BONUS_VISITS_INTERVAL),
        "lawyer_info": lawyer_info,
        "bookings": [{"id": b.id, "lawyer": b.lawyer.name, "service": b.service.name, "date": b.date, "time": b.time, "price": b.service.price, "status": b.status, "is_manual": b.is_manual} for b in bookings],
        "past_bookings_for_review": [{"id": b.id, "lawyer": b.lawyer.name, "service": b.service.name, "date": b.date, "time": b.time} for b in past],
        "my_reviews": [{"id": r.id, "lawyer_name": r.lawyer.name if r.lawyer else "—", "rating": r.rating, "comment": r.comment} for r in reviews]
    }
EOF

cat > app/api/routes/weekend.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.weekend_repo import WeekendRepository
from app.core.security import is_admin
from pydantic import BaseModel

router = APIRouter(prefix="/api", tags=["weekend"])

class WeekendSetSchema(BaseModel):
    admin_telegram_id: int
    days: list[int]

@router.get("/weekend-days")
async def get_weekend_days(session: AsyncSession = Depends(get_session)):
    return await WeekendRepository(session).get_all()

@router.post("/admin/weekend-days")
async def set_weekend_days(data: WeekendSetSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403)
    await WeekendRepository(session).set(data.days)
    await session.commit()
    return {"ok": True}
EOF

cat > app/bot/__init__.py << 'EOF'
EOF

cat > app/bot/main.py << 'EOF'
import asyncio, sys
from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from app.config import settings
from app.bot.handlers.start import router as start_router
from app.logger import logger

async def main():
    logger.info("Бот запускается...")
    bot = Bot(token=settings.BOT_TOKEN, default=DefaultBotProperties(parse_mode="HTML"))
    dp = Dispatcher()
    dp.include_router(start_router)
    await dp.start_polling(bot, drop_pending_updates=True)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Бот остановлен")
    except Exception as e:
        logger.exception(f"Fatal: {e}")
        sys.exit(1)
EOF

cat > app/bot/handlers/__init__.py << 'EOF'
EOF

cat > app/bot/handlers/start.py << 'EOF'
from aiogram import Router, types
from aiogram.filters import CommandStart
from aiogram.utils.keyboard import InlineKeyboardBuilder
from app.config import settings

router = Router()

@router.message(CommandStart())
async def cmd_start(message: types.Message):
    builder = InlineKeyboardBuilder()
    builder.button(text="⚖️ Записаться", web_app=types.WebAppInfo(url=f"{settings.BASE_URL}/mini-app"))
    builder.button(text="🔗 Поделиться", switch_inline_query=f"Юридическая консультация: https://t.me/{settings.BOT_USERNAME}")
    builder.adjust(1)
    await message.answer("<b>⚖️ ЮРИДИЧЕСКАЯ КОНСУЛЬТАЦИЯ</b>\n\nОнлайн-запись доступна 24/7.\nул. Ленина, 10 | Пн–Пт 9:00–18:00\n\n<i>Нажмите кнопку ниже:</i>", reply_markup=builder.as_markup())
EOF

echo "Часть 5 готова"
mkdir -p app/static/js

cat > app/static/index.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title>Юридическая консультация</title>
    <script src="https://telegram.org/js/telegram-web-app.js"></script>
    <link rel="stylesheet" href="/static/styles.css">
</head>
<body>
    <div class="header"><h1>⚖️ ЮРКОНСУЛЬТАЦИЯ</h1><p>Онлайн-запись 24/7</p></div>
    <div id="app"></div>
    <div class="footer">ул. Ленина, 10 | Пн–Пт 9:00 – 18:00</div>
    <script src="/static/js/state.js"></script>
    <script src="/static/js/api.js"></script>
    <script src="/static/js/router.js"></script>
    <script src="/static/js/menu.js"></script>
    <script src="/static/js/booking.js"></script>
    <script src="/static/js/manual.js"></script>
    <script src="/static/js/reviews.js"></script>
    <script src="/static/js/admin.js"></script>
    <script src="/static/js/broadcast.js"></script>
    <script src="/static/js/app.js"></script>
</body>
</html>
EOF

cat > app/static/styles.css << 'EOF'
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#0d0d0d;color:#f5f5f5;padding:16px;min-height:100vh;display:flex;flex-direction:column}
.header{text-align:center;padding:24px 0 16px;border-bottom:1px solid #222;margin-bottom:20px}
.header h1{font-size:26px;color:#c9a96e;letter-spacing:1px}
.header p{color:#888;font-size:13px;margin-top:4px}
#app{flex:1}
h2{margin-bottom:16px;color:#c9a96e;font-size:20px;font-weight:600}
.menu-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:12px}
.menu-item{background:#1a1a1a;padding:20px 16px;border-radius:16px;cursor:pointer;transition:all 0.2s;text-align:center;border:2px solid transparent;display:flex;flex-direction:column;align-items:center;gap:8px}
.menu-item:hover{background:#222;border-color:#333}
.menu-item .icon{font-size:32px}
.menu-item .label{font-size:14px;color:#ccc;font-weight:500}
.option{background:#1a1a1a;padding:14px;margin:8px 0;border-radius:14px;cursor:pointer;transition:all 0.2s;border:2px solid transparent;display:flex;align-items:center;gap:12px}
.option:hover{background:#222;border-color:#333}
.option.selected{border-color:#c9a96e;background:#1a1a1a;box-shadow:0 0 20px rgba(201,169,110,0.15)}
.option img{width:52px;height:52px;border-radius:50%;object-fit:cover}
.option .info{flex:1}
.option .info b{display:block;font-size:15px;margin-bottom:2px}
.option .info span{font-size:13px;color:#999}
.btn-group{display:flex;gap:10px;margin-top:16px}
button{padding:14px 20px;border:none;border-radius:14px;font-size:15px;font-weight:600;cursor:pointer;transition:all 0.2s;flex:1}
.btn-next{background:#c9a96e;color:#0d0d0d}
.btn-back{background:#222;color:#ccc}
.btn-confirm{background:#4CAF50;color:#fff;font-size:16px}
.btn-cancel{background:#c0392b;color:#fff}
.btn-admin{background:#c9a96e;color:#0d0d0d;font-size:13px;padding:10px 16px}
.btn-send{background:#4CAF50;color:#fff;font-size:16px}
.btn-dayoff{background:#e67e22;color:#fff;font-size:13px;padding:8px 12px}
.btn-photo{background:#8e44ad;color:#fff;font-size:14px;padding:12px;width:100%;text-align:center;border-radius:14px;cursor:pointer;margin-top:8px}
.btn-manual{background:#3498db;color:#fff;font-size:16px;padding:14px 20px;width:100%;border-radius:14px;cursor:pointer;margin-top:8px}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:16px 0}
.grid div{background:#1a1a1a;padding:14px 8px;border-radius:12px;text-align:center;cursor:pointer;transition:all 0.2s;border:2px solid transparent;font-size:14px}
.grid div:hover{background:#222;border-color:#333}
.grid div.selected{border-color:#c9a96e;background:#1a1a1a;box-shadow:0 0 15px rgba(201,169,110,0.2)}
.grid div.booked{background:#1a0a0a;color:#666;cursor:not-allowed;text-decoration:line-through}
.grid div.weekend{background:#1a0a0a;color:#c0392b;cursor:not-allowed}
.summary{background:#1a1a1a;padding:20px;border-radius:16px;margin:8px 0}
.summary-item{display:flex;justify-content:space-between;padding:12px 0;border-bottom:1px solid #222}
.summary-item:last-child{border-bottom:none}
.summary-item span{color:#888;font-size:14px}
.summary-item strong{color:#f5f5f5;font-size:15px}
.summary-item.total strong{color:#c9a96e;font-size:20px}
.card{background:#1a1a1a;padding:16px;margin:8px 0;border-radius:14px}
.card .row{display:flex;justify-content:space-between;align-items:center;margin:6px 0}
.card .label{color:#888;font-size:13px}
.card .value{color:#f5f5f5;font-size:15px;font-weight:500}
.card .value.green{color:#4CAF50}
.stars{display:flex;gap:4px;justify-content:center;margin:12px 0}
.star{font-size:32px;cursor:pointer;color:#555;transition:0.2s}
.star.active{color:#f1c40f}
.star.readonly{cursor:default}
.form-group{margin:12px 0}
.form-group label{display:block;color:#888;font-size:13px;margin-bottom:4px}
.form-group input,.form-group textarea{width:100%;padding:12px;background:#1a1a1a;border:1px solid #333;border-radius:12px;color:#f5f5f5;font-size:15px;resize:vertical}
.form-group textarea{min-height:80px}
.status-badge{display:inline-block;padding:4px 10px;border-radius:20px;font-size:12px;font-weight:600}
.status-active{background:#1a3a1a;color:#4CAF50}
.status-inactive{background:#3a1a1a;color:#c0392b}
.status-manual{background:#1a2a3a;color:#3498db}
.footer{text-align:center;padding:16px 0;color:#555;font-size:12px;border-top:1px solid #222;margin-top:auto}
select{width:100%;padding:12px;background:#1a1a1a;border:1px solid #333;border-radius:12px;color:#f5f5f5;font-size:15px}
.preview-img{width:80px;height:80px;border-radius:12px;object-fit:cover;margin:8px 0;border:2px solid #333}
.file-selected{color:#4CAF50;font-size:13px;margin-top:4px}
EOF

cat > app/static/js/state.js << 'EOF'
const tg = window.Telegram?.WebApp;
tg?.expand?.();
tg?.ready?.();
tg?.setHeaderColor?.('#0d0d0d');
tg?.setBackgroundColor?.('#0d0d0d');

const user = tg?.initDataUnsafe?.user || null;
const ADMIN_IDS = [5724746367];
const isAdmin = user && ADMIN_IDS.includes(user.id);

let state = {
    screen: 'menu', svc: null, lwr: null, date: null, time: null,
    services: [], lawyers: [], bookings: [], pastBookings: [], myReviews: [],
    profile: null, lawyerInfo: null, isLawyer: false, isLawyerAdmin: false,
    stats: null, todayBookings: [], allServices: [], allLawyers: [], allReviews: [],
    isSubmitting: false, todayFilterLawyer: null,
    selectedPhotoFile: null, selectedPhotoPath: null, broadcastPhotoFile: null,
    manualSvc: null, manualLwr: null, manualDate: null, manualTime: null,
    manualClientName: '', manualPhone: '', weekendDays: []
};
EOF

cat > app/static/js/api.js << 'EOF'
async function api(url, options = {}) {
    try { const res = await fetch(url, options); return await res.json(); }
    catch (e) { console.error(e); return { error: true }; }
}

async function uploadPhoto(file) {
    if (!file) return { ok: false };
    const fd = new FormData(); fd.append('photo', file); fd.append('admin_telegram_id', user?.id || 0);
    try { const res = await fetch('/api/admin/upload-photo', { method: 'POST', body: fd }); return await res.json(); }
    catch { return { ok: false }; }
}
EOF

cat > app/static/js/router.js << 'EOF'
function rn(screen) {
    state.screen = screen;
    const app = document.getElementById('app');
    if (!app) return;
    app.innerHTML = '';
    const screens = {
        menu: renderMenu, booking_service: renderBookingService, booking_lawyer: renderBookingLawyer,
        booking_date: renderBookingDate, booking_time: renderBookingTime, booking_confirm: renderBookingConfirm,
        my_bookings: renderMyBookings, reviews: renderReviews, my_reviews_history: renderMyReviewsHistory,
        bonuses: renderBonuses, admin_stats: renderAdminStats, admin_today: renderAdminToday,
        admin_lawyers: renderAdminLawyers, admin_services: renderAdminServices,
        admin_broadcast: renderAdminBroadcast, admin_audit: renderAdminAudit, admin_reviews: renderAdminReviews,
        admin_manual_booking: renderAdminManualBooking, manual_service: renderManualService,
        manual_lawyer: renderManualLawyer, manual_date: renderManualDate, manual_time: renderManualTime,
        manual_confirm: renderManualConfirm, admin_weekend: renderAdminWeekend
    };
    if (screens[screen]) screens[screen](app);
    else renderMenu(app);
}
EOF

cat > app/static/js/menu.js << 'EOF'
function renderMenu(app) {
    app.innerHTML = '<h2>Меню</h2><div class="menu-grid"></div>';
    const grid = app.querySelector('.menu-grid');
    const items = [];
    const hasAdmin = isAdmin || state.isLawyerAdmin;
    if (!hasAdmin) {
        items.push({ icon: '⚖️', label: 'Записаться', action: () => rn('booking_service') });
        items.push({ icon: '📋', label: 'Мои записи', action: () => rn('my_bookings') });
        items.push({ icon: '⭐', label: 'Отзывы', action: () => rn('reviews') });
        items.push({ icon: '📝', label: 'Мои отзывы', action: () => rn('my_reviews_history') });
        items.push({ icon: '🎁', label: 'Бонусы', action: () => rn('bonuses') });
    } else {
        items.push({ icon: '📞', label: 'Запись по звонку', action: () => rn('admin_manual_booking') });
        items.push({ icon: '📊', label: 'Статистика', action: () => rn('admin_stats') });
        items.push({ icon: '📅', label: 'Записи сегодня', action: () => rn('admin_today') });
        items.push({ icon: '👨‍💼', label: 'Юристы', action: () => rn('admin_lawyers') });
        items.push({ icon: '📋', label: 'Услуги', action: () => rn('admin_services') });
        items.push({ icon: '👁️', label: 'Отзывы клиентов', action: () => rn('admin_reviews') });
        items.push({ icon: '📢', label: 'Рассылка', action: () => rn('admin_broadcast') });
        items.push({ icon: '📜', label: 'Аудит', action: () => rn('admin_audit') });
        items.push({ icon: '📅', label: 'Выходные дни', action: () => rn('admin_weekend') });
    }
    items.forEach(item => {
        const div = document.createElement('div'); div.className = 'menu-item';
        div.innerHTML = `<div class="icon">${item.icon}</div><div class="label">${item.label}</div>`;
        div.onclick = item.action; grid.appendChild(div);
    });
}
EOF

cat > app/static/js/booking.js << 'EOF'
function renderBookingService(app) {
    app.innerHTML = '<h2>Выберите услугу</h2><div id="svc"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('svc');
    state.services.forEach(x => {
        const e = document.createElement('div'); e.className = 'option';
        e.innerHTML = `<div class="info"><b>${x.name}</b><span>${x.duration} мин</span></div><strong style="color:#c9a96e">${x.price}₽</strong>`;
        e.onclick = () => { state.svc = x; rn('booking_lawyer'); }; c.appendChild(e);
    });
}

function renderBookingLawyer(app) {
    app.innerHTML = '<h2>Выберите юриста</h2><div id="lwr"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_service\')">← Назад</button></div>';
    const c = document.getElementById('lwr');
    state.lawyers.forEach(x => {
        const e = document.createElement('div'); e.className = 'option';
        e.innerHTML = `<img src="${x.photo || ''}" onerror="this.style.display=\'none\'"><div class="info"><b>${x.name}</b><span>⭐${x.rating} | Опыт ${x.experience} лет</span></div>`;
        e.onclick = () => { state.lwr = x; rn('booking_date'); }; c.appendChild(e);
    });
}

function renderBookingDate(app) {
    app.innerHTML = '<h2>Выберите дату</h2><div class="grid" id="dt"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_lawyer\')">← Назад</button></div>';
    const g = document.getElementById('dt'); const t = new Date();
    for (let i = 0; i < 14; i++) {
        const d = new Date(t); d.setDate(t.getDate() + i);
        const ds = d.toISOString().split('T')[0]; const dow = d.getDay();
        const b = document.createElement('div');
        b.textContent = d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short', weekday: 'short' });
        if (state.weekendDays.includes(dow)) { b.className = 'weekend'; b.textContent += ' (вых)'; }
        else { b.onclick = () => { state.date = ds; rn('booking_time'); }; }
        g.appendChild(b);
    }
}

async function renderBookingTime(app) {
    app.innerHTML = '<h2>Выберите время</h2><div class="grid" id="tm"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_date\')">← Назад</button></div>';
    const g = document.getElementById('tm');
    const bk = await api(`/api/booked-slots?date=${state.date}&lawyer_id=${state.lwr.id}`);
    const bt = (bk || []).map(x => x.time);
    const now = new Date(); const today = now.toISOString().split('T')[0];
    const curH = now.getHours(); const curM = now.getMinutes();
    for (let h = 9; h < 18; h++) {
        for (let m = 0; m < 60; m += 30) {
            const tm = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
            const b = document.createElement('div');
            const isPast = state.date === today && (h < curH || (h === curH && m <= curM));
            if (bt.includes(tm) || isPast) { b.className = 'booked'; b.textContent = tm; }
            else { b.textContent = tm; b.onclick = () => { state.time = tm; rn('booking_confirm'); }; }
            g.appendChild(b);
        }
    }
}

function renderBookingConfirm(app) {
    app.innerHTML = '<h2>Подтверждение</h2><div class="summary"><div class="summary-item"><span>Услуга</span><strong id="sm_svc"></strong></div><div class="summary-item"><span>Юрист</span><strong id="sm_lwr"></strong></div><div class="summary-item"><span>Дата</span><strong id="sm_dt"></strong></div><div class="summary-item"><span>Время</span><strong id="sm_tm"></strong></div><div class="summary-item total"><span>Цена</span><strong id="sm_pr"></strong></div></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_time\')">← Назад</button><button class="btn-confirm" id="cfbtn" onclick="confirmBooking()">Подтвердить</button></div>';
    document.getElementById('sm_svc').textContent = state.svc?.name || '';
    document.getElementById('sm_lwr').textContent = state.lwr?.name || '';
    document.getElementById('sm_dt').textContent = state.date || '';
    document.getElementById('sm_tm').textContent = state.time || '';
    document.getElementById('sm_pr').textContent = (state.svc?.price || '') + '₽';
}

async function confirmBooking() {
    if (state.isSubmitting || !user) return;
    state.isSubmitting = true;
    const btn = document.getElementById('cfbtn'); btn.textContent = 'Создаём...'; btn.disabled = true;
    const payload = { telegram_id: user.id, chat_id: user.id, username: user.username || null, first_name: user.first_name || null, last_name: user.last_name || null, service_id: state.svc?.id, lawyer_id: state.lwr?.id, date: state.date, time: state.time };
    try {
        const res = await api('/api/book', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
        if (res.ok) {
            tg?.showAlert?.(`Запись подтверждена!\n\n${res.service}\nЮрист: ${res.lawyer}\n${res.date} в ${res.time}\nЦена: ${res.price}₽`);
            const p = await api(`/api/profile?telegram_id=${user.id}`);
            if (p?.exists) { state.profile = p; state.bookings = p.bookings || []; state.pastBookings = p.past_bookings_for_review || []; }
            rn('my_bookings');
        } else if (res.detail?.startsWith('alternatives|')) {
            tg?.showAlert?.(`Юрист занят.\n\nСвободные:\n${res.detail.split('|')[1]}\n\nВыберите другого.`);
            rn('booking_lawyer');
        } else { tg?.showAlert?.(res.detail || 'Ошибка записи'); }
    } catch (e) { tg?.showAlert?.('Ошибка соединения'); }
    state.isSubmitting = false; btn.textContent = 'Подтвердить'; btn.disabled = false;
}

function renderMyBookings(app) {
    app.innerHTML = '<h2>Мои записи</h2><div id="bklist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('bklist');
    if (!state.bookings.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет записей</p>'; return; }
    state.bookings.forEach(b => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${b.date} в ${b.time}</span><span class="status-badge ${b.status==='confirmed'?'status-active':'status-inactive'} ${b.is_manual?'status-manual':''}">${b.is_manual?'📞 Ручная':b.status==='confirmed'?'✅ Активна':'❌ Отменена'}</span></div><div class="row"><span class="label">Юрист:</span><span class="value">${b.lawyer}</span></div><div class="row"><span class="label">Услуга:</span><span class="value">${b.service}</span></div><div class="row"><span class="label">Цена:</span><span class="value">${b.price}₽</span></div>`;
        if (b.status === 'confirmed' && !b.is_manual) {
            const btn = document.createElement('button'); btn.className = 'btn-cancel'; btn.textContent = '❌ Отменить'; btn.style.marginTop = '8px'; btn.style.width = '100%';
            btn.onclick = async () => {
                const res = await api('/api/cancel', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ telegram_id: user?.id, booking_id: b.id }) });
                if (res.ok) { tg?.showAlert?.('Запись отменена'); const p = await api(`/api/profile?telegram_id=${user?.id}`); state.bookings = p?.bookings || []; rn('my_bookings'); }
                else { tg?.showAlert?.(res.detail || 'Ошибка'); }
            }; card.appendChild(btn);
        }
        c.appendChild(card);
    });
}

function renderBonuses(app) {
    app.innerHTML = '<h2>Бонусы</h2><div id="bn"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('bn');
    if (!state.profile) { c.innerHTML = '<p style="color:#888">Нет данных</p>'; return; }
    c.innerHTML = `<div class="card"><div class="row"><span class="label">Всего визитов:</span><span class="value">${state.profile.total_visits}</span></div><div class="row"><span class="label">Бонусный баланс:</span><span class="value green">${state.profile.bonus_balance}₽</span></div><div class="row"><span class="label">До следующего бонуса:</span><span class="value">${state.profile.visits_to_next_bonus} визитов</span></div></div>`;
}
EOF

cat > app/static/js/manual.js << 'EOF'
function renderAdminManualBooking(app) {
    app.innerHTML = '<h2>📞 Запись по звонку</h2><div class="form-group"><label>Имя клиента</label><input id="mclient" value="' + (state.manualClientName || '') + '"></div><div class="form-group"><label>Телефон</label><input id="mphone" value="' + (state.manualPhone || '') + '"></div><button class="btn-manual" onclick="state.manualClientName=document.getElementById(\'mclient\').value;state.manualPhone=document.getElementById(\'mphone\').value;rn(\'manual_service\')">Далее: выбор услуги</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
}

function renderManualService(app) {
    app.innerHTML = '<h2>Выберите услугу</h2><div id="msvc"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'admin_manual_booking\')">← Назад</button></div>';
    const c = document.getElementById('msvc');
    state.services.forEach(x => {
        const e = document.createElement('div'); e.className = 'option';
        e.innerHTML = `<div class="info"><b>${x.name}</b><span>${x.duration} мин</span></div><strong style="color:#c9a96e">${x.price}₽</strong>`;
        e.onclick = () => { state.manualSvc = x; rn('manual_lawyer'); }; c.appendChild(e);
    });
}

function renderManualLawyer(app) {
    app.innerHTML = '<h2>Выберите юриста</h2><div id="mlwr"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'manual_service\')">← Назад</button></div>';
    const c = document.getElementById('mlwr');
    state.lawyers.forEach(x => {
        const e = document.createElement('div'); e.className = 'option';
        e.innerHTML = `<img src="${x.photo || ''}" onerror="this.style.display=\'none\'"><div class="info"><b>${x.name}</b><span>⭐${x.rating} | Опыт ${x.experience} лет</span></div>`;
        e.onclick = () => { state.manualLwr = x; rn('manual_date'); }; c.appendChild(e);
    });
}

function renderManualDate(app) {
    app.innerHTML = '<h2>Выберите дату</h2><div class="grid" id="mdt"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'manual_lawyer\')">← Назад</button></div>';
    const g = document.getElementById('mdt'); const t = new Date();
    for (let i = 0; i < 14; i++) {
        const d = new Date(t); d.setDate(t.getDate() + i);
        const ds = d.toISOString().split('T')[0]; const dow = d.getDay();
        const b = document.createElement('div');
        b.textContent = d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short', weekday: 'short' });
        if (state.weekendDays.includes(dow)) { b.className = 'weekend'; b.textContent += ' (вых)'; }
        else { b.onclick = () => { state.manualDate = ds; rn('manual_time'); }; }
        g.appendChild(b);
    }
}

async function renderManualTime(app) {
    app.innerHTML = '<h2>Выберите время</h2><div class="grid" id="mtm"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'manual_date\')">← Назад</button></div>';
    const g = document.getElementById('mtm');
    const bk = await api(`/api/booked-slots?date=${state.manualDate}&lawyer_id=${state.manualLwr?.id}`);
    const bt = (bk || []).map(x => x.time);
    const now = new Date(); const today = now.toISOString().split('T')[0];
    const curH = now.getHours(); const curM = now.getMinutes();
    for (let h = 9; h < 18; h++) {
        for (let m = 0; m < 60; m += 30) {
            const tm = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
            const b = document.createElement('div');
            const isPast = state.manualDate === today && (h < curH || (h === curH && m <= curM));
            if (bt.includes(tm) || isPast) { b.className = 'booked'; b.textContent = tm; }
            else { b.textContent = tm; b.onclick = () => { state.manualTime = tm; rn('manual_confirm'); }; }
            g.appendChild(b);
        }
    }
}

function renderManualConfirm(app) {
    app.innerHTML = '<h2>Подтверждение</h2><div class="summary"><div class="summary-item"><span>Клиент</span><strong>' + (state.manualClientName || '—') + '</strong></div><div class="summary-item"><span>Телефон</span><strong>' + (state.manualPhone || '—') + '</strong></div><div class="summary-item"><span>Услуга</span><strong>' + (state.manualSvc?.name || '') + '</strong></div><div class="summary-item"><span>Юрист</span><strong>' + (state.manualLwr?.name || '') + '</strong></div><div class="summary-item"><span>Дата</span><strong>' + (state.manualDate || '') + '</strong></div><div class="summary-item"><span>Время</span><strong>' + (state.manualTime || '') + '</strong></div><div class="summary-item total"><span>Цена</span><strong>' + (state.manualSvc?.price || '') + '₽</strong></div></div><div class="btn-group"><button class="btn-back" onclick="rn(\'manual_time\')">← Назад</button><button class="btn-confirm" onclick="manualCf()">Подтвердить</button></div>';
}

async function manualCf() {
    if (state.isSubmitting) return;
    if (!state.manualClientName || !state.manualClientName.trim()) { tg?.showAlert?.('Введите имя клиента'); return; }
    if (!state.manualSvc || !state.manualLwr || !state.manualDate || !state.manualTime) { tg?.showAlert?.('Данные утеряны. Начните заново.'); rn('admin_manual_booking'); return; }
    state.isSubmitting = true;
    const payload = { admin_telegram_id: user?.id, client_name: state.manualClientName.trim(), phone: state.manualPhone || null, service_id: state.manualSvc.id, lawyer_id: state.manualLwr.id, date: state.manualDate, time: state.manualTime };
    try {
        const res = await api('/api/admin/manual-booking', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
        if (res.ok) {
            tg?.showAlert?.(`Запись создана!\n\nКлиент: ${res.client_name}\n${res.service}\nЮрист: ${res.lawyer}\n${res.date} в ${res.time}`);
            if (isAdmin || state.isLawyerAdmin) { state.stats = await api(`/api/admin/stats?admin_telegram_id=${user?.id}`); state.todayBookings = await api(`/api/admin/today-bookings?admin_telegram_id=${user?.id}`); }
            rn('menu');
        } else { tg?.showAlert?.(res.detail || 'Ошибка'); }
    } catch (e) { tg?.showAlert?.('Ошибка соединения'); }
    state.isSubmitting = false;
}
EOF

cat > app/static/js/reviews.js << 'EOF'
function renderReviews(app) {
    app.innerHTML = '<h2>Оставить отзыв</h2><div id="rvlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('rvlist');
    if (!state.pastBookings.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет прошедших записей</p>'; return; }
    state.pastBookings.forEach(b => {
        if (b.is_manual) return;
        const card = document.createElement('div'); card.className = 'card'; card.id = 'rv_' + b.id;
        card.innerHTML = `<div class="row"><span class="label">${b.date} в ${b.time}</span></div><div class="row"><span class="label">Юрист:</span><span class="value">${b.lawyer}</span></div><div class="row"><span class="label">Услуга:</span><span class="value">${b.service}</span></div><div class="stars" id="stars_${b.id}">${[1,2,3,4,5].map(n => `<span class="star" data-n="${n}">★</span>`).join('')}</div>`;
        c.appendChild(card);
        const stars = document.querySelectorAll(`#stars_${b.id} .star`);
        stars.forEach(s => {
            s.onmouseenter = () => { const n = parseInt(s.dataset.n); stars.forEach((ss, i) => ss.classList.toggle('active', i < n)); };
            s.onclick = async () => {
                const rating = parseInt(s.dataset.n);
                const res = await api('/api/reviews', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ telegram_id: user?.id, booking_id: b.id, rating }) });
                if (res.ok) { tg?.showAlert?.(res.bonus_added ? `Спасибо! +${res.bonus_amount}₽ бонус!` : 'Спасибо за отзыв!'); const p = await api(`/api/profile?telegram_id=${user?.id}`); if (p?.exists) { state.profile = p; state.pastBookings = p.past_bookings_for_review || []; } rn('reviews'); }
                else { tg?.showAlert?.(res.detail || 'Ошибка'); }
            };
        });
    });
}

function renderMyReviewsHistory(app) {
    app.innerHTML = '<h2>Мои отзывы</h2><div id="myrv"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('myrv');
    if (!state.myReviews || !state.myReviews.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет отзывов</p>'; return; }
    state.myReviews.forEach(r => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">Юрист: ${r.lawyer_name}</span><span class="value">${'★'.repeat(r.rating)}${'☆'.repeat(5-r.rating)}</span></div>${r.comment?`<div class="row"><span class="label">Комментарий:</span><span class="value">${r.comment}</span></div>`:''}`;
        c.appendChild(card);
    });
}
EOF

cat > app/static/js/admin.js << 'EOF'
function renderAdminStats(app) {
    app.innerHTML = '<h2>Статистика</h2><div id="st"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const s = state.stats || {};
    document.getElementById('st').innerHTML = `<div class="card"><div class="row"><span class="label">Записей сегодня:</span><span class="value">${s.today_bookings||0}</span></div><div class="row"><span class="label">Всего клиентов:</span><span class="value">${s.total_clients||0}</span></div><div class="row"><span class="label">Выручка сегодня:</span><span class="value green">${s.today_revenue||0}₽</span></div></div>`;
}

async function renderAdminToday(app) {
    app.innerHTML = '<h2>Записи на сегодня</h2><div class="form-group"><label>Фильтр по юристу</label><select id="mfilter" onchange="loadTodayFiltered()"><option value="">Все юристы</option>' + state.allLawyers.map(m => `<option value="${m.id}" ${state.todayFilterLawyer==m.id?'selected':''}>${m.name}</option>`).join('') + '</select></div><div id="tdlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    await loadTodayFiltered();
}

async function loadTodayFiltered() {
    const mid = document.getElementById('mfilter')?.value || '';
    state.todayFilterLawyer = mid || null;
    const url = mid ? `/api/admin/today-bookings?admin_telegram_id=${user?.id}&lawyer_id=${mid}` : `/api/admin/today-bookings?admin_telegram_id=${user?.id}`;
    state.todayBookings = await api(url);
    const c = document.getElementById('tdlist'); c.innerHTML = '';
    if (!state.todayBookings.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет записей</p>'; return; }
    state.todayBookings.forEach(b => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${b.time}</span><span class="value">${b.client_name} ${b.is_manual?'📞':''}</span></div><div class="row"><span class="label">Юрист:</span><span class="value">${b.lawyer}</span></div><div class="row"><span class="label">Услуга:</span><span class="value">${b.service} (${b.price}₽)</span></div>`;
        const btn = document.createElement('button'); btn.className = 'btn-cancel'; btn.textContent = '❌ Отменить'; btn.style.marginTop = '8px'; btn.style.width = '100%';
        btn.onclick = async () => {
            const res = await api('/api/admin/cancel', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, booking_id: b.id }) });
            if (res.ok) { tg?.showAlert?.('Запись отменена'); await loadTodayFiltered(); } else { tg?.showAlert?.(res.detail || 'Ошибка'); }
        }; card.appendChild(btn); c.appendChild(card);
    });
}

function renderAdminLawyers(app) {
    app.innerHTML = '<h2>Юристы</h2><div id="mlist"></div><button class="btn-admin" style="width:100%;margin-top:8px" onclick="showLawyerForm()">➕ Добавить юриста</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    renderLawyersList();
}

function renderLawyersList() {
    const c = document.getElementById('mlist'); c.innerHTML = '';
    state.allLawyers.forEach(m => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="value">${m.name}</span><span class="status-badge ${m.is_active?'status-active':'status-inactive'}">${m.is_active?'Активен':'Неактивен'}${m.is_admin?' | Админ':''}</span></div><div class="row"><span class="label">Рейтинг: ${m.rating} | Опыт: ${m.experience} лет | Лимит: ${m.max_bookings} зап/день</span></div>${m.photo?`<img src="${m.photo}" style="width:60px;height:60px;border-radius:12px;object-fit:cover;margin-top:8px">`:''}<div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap"><button class="btn-admin" onclick="editLawyer(${m.id},'${m.name}','${m.photo||''}',${m.experience},${m.telegram_id||0},${m.max_bookings||10},${m.is_admin||false})">✏️</button><button class="btn-admin" onclick="toggleLawyer(${m.id})">${m.is_active?'⏸️ Отключить':'▶️ Включить'}</button><button class="btn-dayoff" onclick="showDayOffForm(${m.id},'${m.name}')">🚫 Выходной</button><button class="btn-cancel" onclick="deleteLawyer(${m.id},'${m.name}')">🗑️</button></div>`;
        c.appendChild(card);
    });
}

function showLawyerForm(editData = null) {
    const app = document.getElementById('app'); state.selectedPhotoFile = null; state.selectedPhotoPath = editData?.photo || null;
    app.innerHTML = `<h2>${editData?'Изменить юриста':'Добавить юриста'}</h2><div class="form-group"><label>ФИО</label><input id="lname" value="${editData?.name||''}"></div><div class="form-group"><label>Фото</label>${state.selectedPhotoPath?`<img src="${state.selectedPhotoPath}" class="preview-img" id="lphoto_preview"><br>`:''}<input type="file" id="lphoto_input" accept="image/*" style="display:none" onchange="onPhotoSelected(this)"><button class="btn-photo" onclick="document.getElementById('lphoto_input').click()">📷 Выбрать фото</button><span class="file-selected" id="lphoto_name">${state.selectedPhotoPath?'✅ Фото загружено':''}</span></div><div class="form-group"><label>Опыт (лет)</label><input id="lexp" type="number" value="${editData?.exp||0}"></div><div class="form-group"><label>Telegram ID</label><input id="ltg" type="number" value="${editData?.tg||''}"></div><div class="form-group"><label>Лимит записей в день</label><input id="lmax" type="number" value="${editData?.max||10}"></div><div class="form-group"><label><input type="checkbox" id="lisadmin" ${editData?.isAdmin?'checked':''}> Права администратора</label></div><button class="btn-confirm" style="width:100%" onclick="${editData?`saveLawyerEdit(${editData.id})`:'saveLawyerNew()'}">Сохранить</button><div class="btn-group"><button class="btn-back" onclick="rn('admin_lawyers')">← Назад</button></div>`;
}

function onPhotoSelected(input) {
    if (input.files && input.files[0]) {
        state.selectedPhotoFile = input.files[0];
        document.getElementById('lphoto_name').textContent = '✅ ' + input.files[0].name;
        const preview = document.getElementById('lphoto_preview');
        if (preview) preview.src = URL.createObjectURL(input.files[0]);
    }
}

async function saveLawyerNew() {
    const name = document.getElementById('lname').value;
    const exp = parseInt(document.getElementById('lexp').value) || 0;
    const tgid = parseInt(document.getElementById('ltg').value) || null;
    const max = parseInt(document.getElementById('lmax').value) || 10;
    const isAdm = document.getElementById('lisadmin')?.checked || false;
    let photoPath = null;
    if (state.selectedPhotoFile) { const upRes = await uploadPhoto(state.selectedPhotoFile); if (upRes.ok) photoPath = upRes.path; }
    await api('/api/admin/lawyers', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, name, photo_url: photoPath, experience_years: exp, telegram_id: tgid, max_bookings_per_day: max, is_admin: isAdm }) });
    state.allLawyers = await api(`/api/admin/lawyers?admin_telegram_id=${user?.id}`); rn('admin_lawyers');
}

function editLawyer(id, name, photo, exp, tg, max, isAdm) { showLawyerForm({ id, name, photo, exp, tg, max, isAdmin: isAdm }); }

async function saveLawyerEdit(id) {
    const name = document.getElementById('lname').value;
    const exp = parseInt(document.getElementById('lexp').value) || 0;
    const tgid = parseInt(document.getElementById('ltg').value) || null;
    const max = parseInt(document.getElementById('lmax').value) || 10;
    const isAdm = document.getElementById('lisadmin')?.checked || false;
    let photoPath = state.selectedPhotoPath;
    if (state.selectedPhotoFile) { const upRes = await uploadPhoto(state.selectedPhotoFile); if (upRes.ok) photoPath = upRes.path; }
    await api(`/api/admin/lawyers/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, name, photo_url: photoPath, experience_years: exp, telegram_id: tgid, max_bookings_per_day: max, is_admin: isAdm }) });
    state.allLawyers = await api(`/api/admin/lawyers?admin_telegram_id=${user?.id}`); rn('admin_lawyers');
}

async function toggleLawyer(id) {
    await api(`/api/admin/lawyers/${id}/toggle`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, lawyer_id: id }) });
    state.allLawyers = await api(`/api/admin/lawyers?admin_telegram_id=${user?.id}`); rn('admin_lawyers');
}

async function deleteLawyer(id, name) {
    if (!confirm(`Удалить юриста "${name}"?`)) return;
    const res = await api(`/api/admin/lawyers/${id}?admin_telegram_id=${user?.id}`, { method: 'DELETE' });
    if (res.ok) { tg?.showAlert?.('Юрист удалён'); state.allLawyers = await api(`/api/admin/lawyers?admin_telegram_id=${user?.id}`); rn('admin_lawyers'); }
    else { tg?.showAlert?.(res.detail || 'Нельзя удалить юриста с активными записями'); }
}

function showDayOffForm(lawyerId, lawyerName) {
    const app = document.getElementById('app');
    app.innerHTML = `<h2>Выходной юриста</h2><p style="color:#888;margin-bottom:12px">Юрист: <b>${lawyerName}</b></p><div class="form-group"><label>Дата</label><input id="ddate" type="date"></div><div class="form-group"><label>Причина</label><textarea id="dreason"></textarea></div><button class="btn-confirm" style="width:100%" onclick="saveDayOff(${lawyerId})">Установить выходной</button><div class="btn-group"><button class="btn-back" onclick="rn('admin_lawyers')">← Назад</button></div>`;
}

async function saveDayOff(lawyerId) {
    const date = document.getElementById('ddate').value;
    const reason = document.getElementById('dreason').value;
    if (!date) { tg?.showAlert?.('Выберите дату'); return; }
    const res = await api('/api/admin/lawyer-day-off', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, lawyer_id: lawyerId, date, reason }) });
    if (res.ok) { tg?.showAlert?.(`Выходной установлен. Отменено записей: ${res.cancelled_bookings}`); rn('admin_lawyers'); }
    else { tg?.showAlert?.(res.detail || 'Ошибка'); }
}

function renderAdminServices(app) {
    app.innerHTML = '<h2>Услуги</h2><div id="slist"></div><button class="btn-admin" style="width:100%;margin-top:8px" onclick="showServiceForm()">➕ Добавить услугу</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    renderServicesList();
}

function renderServicesList() {
    const c = document.getElementById('slist'); c.innerHTML = '';
    state.allServices.forEach(s => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="value">${s.name}</span><span class="status-badge ${s.is_active?'status-active':'status-inactive'}">${s.is_active?'Активна':'Неактивна'}</span></div><div class="row"><span class="label">Цена: ${s.price}₽ | Длит: ${s.duration} мин | Кат: ${s.category||'—'}</span></div><div style="display:flex;gap:8px;margin-top:8px"><button class="btn-admin" onclick="editService(${s.id},'${s.name}',${s.price},${s.duration},'${s.category||''}')">✏️</button><button class="btn-admin" onclick="toggleService(${s.id})">${s.is_active?'⏸️ Отключить':'▶️ Включить'}</button><button class="btn-cancel" onclick="deleteService(${s.id},'${s.name}')">🗑️</button></div>`;
        c.appendChild(card);
    });
}

function showServiceForm(editData = null) {
    const app = document.getElementById('app');
    app.innerHTML = `<h2>${editData?'Изменить услугу':'Добавить услугу'}</h2><div class="form-group"><label>Название</label><input id="sname" value="${editData?.name||''}"></div><div class="form-group"><label>Цена</label><input id="sprice" type="number" value="${editData?.price||''}"></div><div class="form-group"><label>Длительность (мин)</label><input id="sdur" type="number" value="${editData?.dur||''}"></div><div class="form-group"><label>Категория</label><input id="scat" value="${editData?.cat||''}"></div><button class="btn-confirm" style="width:100%" onclick="${editData?`saveServiceEdit(${editData.id})`:'saveServiceNew()'}">Сохранить</button><div class="btn-group"><button class="btn-back" onclick="rn('admin_services')">← Назад</button></div>`;
}

async function saveServiceNew() {
    const name = document.getElementById('sname').value;
    const price = parseInt(document.getElementById('sprice').value) || 0;
    const dur = parseInt(document.getElementById('sdur').value) || 0;
    const cat = document.getElementById('scat').value;
    await api('/api/admin/services', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, name, price, duration_minutes: dur, category: cat }) });
    state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`); rn('admin_services');
}

function editService(id, name, price, dur, cat) { showServiceForm({ id, name, price, dur, cat }); }

async function saveServiceEdit(id) {
    const name = document.getElementById('sname').value;
    const price = parseInt(document.getElementById('sprice').value) || 0;
    const dur = parseInt(document.getElementById('sdur').value) || 0;
    const cat = document.getElementById('scat').value;
    await api(`/api/admin/services/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, name, price, duration_minutes: dur, category: cat }) });
    state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`); rn('admin_services');
}

async function toggleService(id) {
    await api(`/api/admin/services/${id}/toggle`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, service_id: id }) });
    state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`); rn('admin_services');
}

async function deleteService(id, name) {
    if (!confirm(`Удалить услугу "${name}"?`)) return;
    const res = await api(`/api/admin/services/${id}?admin_telegram_id=${user?.id}`, { method: 'DELETE' });
    if (res.ok) { tg?.showAlert?.('Услуга удалена'); state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`); rn('admin_services'); }
    else { tg?.showAlert?.(res.detail || 'Нельзя удалить услугу с активными записями'); }
}

async function renderAdminReviews(app) {
    app.innerHTML = '<h2>Отзывы клиентов</h2><div class="form-group"><label>Фильтр по юристу</label><select id="rfilter" onchange="loadAdminReviews()"><option value="">Все юристы</option>' + state.allLawyers.map(m => `<option value="${m.id}">${m.name}</option>`).join('') + '</select></div><div id="arlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    await loadAdminReviews();
}

async function loadAdminReviews() {
    const mid = document.getElementById('rfilter')?.value || '';
    const url = mid ? `/api/admin/reviews?admin_telegram_id=${user?.id}&lawyer_id=${mid}` : `/api/admin/reviews?admin_telegram_id=${user?.id}`;
    state.allReviews = await api(url);
    const c = document.getElementById('arlist'); c.innerHTML = '';
    if (!state.allReviews || !state.allReviews.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет отзывов</p>'; return; }
    state.allReviews.forEach(r => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${r.client_name}</span><span class="value">${'★'.repeat(r.rating)}${'☆'.repeat(5-r.rating)}</span></div><div class="row"><span class="label">Юрист: ${r.lawyer_name}</span></div>${r.comment?`<div class="row"><span class="label">Комментарий:</span><span class="value">${r.comment}</span></div>`:''}`;
        c.appendChild(card);
    });
}

async function renderAdminAudit(app) {
    app.innerHTML = '<h2>Аудит</h2><div id="alist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const logs = await api(`/api/admin/audit-log?admin_telegram_id=${user?.id}`);
    const c = document.getElementById('alist');
    if (!logs || !logs.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет записей</p>'; return; }
    logs.forEach(l => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${l.action}</span><span class="value">${l.details||''}</span></div>`;
        c.appendChild(card);
    });
}

async function renderAdminWeekend(app) {
    app.innerHTML = '<h2>Выходные дни</h2><div id="wlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const days = ['Вс','Пн','Вт','Ср','Чт','Пт','Сб'];
    const current = state.weekendDays || [];
    const c = document.getElementById('wlist');
    days.forEach((name, idx) => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="value">${name}</span><label><input type="checkbox" class="wcheck" data-day="${idx}" ${current.includes(idx)?'checked':''}> Выходной</label></div>`;
        c.appendChild(card);
    });
    const btn = document.createElement('button'); btn.className = 'btn-confirm'; btn.textContent = '💾 Сохранить'; btn.style.marginTop = '16px'; btn.style.width = '100%';
    btn.onclick = async () => {
        const selected = [];
        document.querySelectorAll('.wcheck:checked').forEach(cb => selected.push(parseInt(cb.dataset.day)));
        const res = await api('/api/admin/weekend-days', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, days: selected }) });
        if (res.ok) { state.weekendDays = selected; tg?.showAlert?.('Выходные дни сохранены'); rn('menu'); }
        else { tg?.showAlert?.('Ошибка'); }
    };
    c.appendChild(btn);
}
EOF

cat > app/static/js/broadcast.js << 'EOF'
function renderAdminBroadcast(app) {
    state.broadcastPhotoFile = null;
    app.innerHTML = '<h2>Рассылка</h2><div class="form-group"><label>Текст</label><textarea id="btext"></textarea></div><div class="form-group"><label>Фото</label><input type="file" id="bphoto_input" accept="image/*" style="display:none" onchange="onBroadcastPhotoSelected(this)"><button class="btn-photo" onclick="document.getElementById(\'bphoto_input\').click()">📷 Прикрепить фото</button><span class="file-selected" id="bphoto_name"></span></div><button class="btn-send" style="width:100%" onclick="sendBroadcast()">📢 Отправить всем</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
}

function onBroadcastPhotoSelected(input) {
    if (input.files && input.files[0]) {
        state.broadcastPhotoFile = input.files[0];
        document.getElementById('bphoto_name').textContent = '✅ ' + input.files[0].name;
    }
}

async function sendBroadcast() {
    const text = document.getElementById('btext').value;
    if (!text && !state.broadcastPhotoFile) { tg?.showAlert?.('Введите текст или прикрепите фото'); return; }
    let photoPath = null;
    if (state.broadcastPhotoFile) { const upRes = await uploadPhoto(state.broadcastPhotoFile); if (upRes.ok) photoPath = upRes.path; }
    const res = await api('/api/admin/broadcast', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, text: text || '', photo_path: photoPath }) });
    if (res.ok) { tg?.showAlert?.(`Отправлено: ${res.sent}, ошибок: ${res.failed}`); rn('menu'); }
    else { tg?.showAlert?.('Ошибка'); }
}
EOF

cat > app/static/js/app.js << 'EOF'
async function ld() {
    try {
        state.services = await api('/api/services') || [];
        state.lawyers = await api('/api/lawyers') || [];
        state.weekendDays = await api('/api/weekend-days') || [];
        if (user) {
            const p = await api(`/api/profile?telegram_id=${user.id}`);
            if (p?.exists) {
                state.profile = p;
                state.bookings = p.bookings || [];
                state.pastBookings = p.past_bookings_for_review || [];
                state.myReviews = p.my_reviews || [];
                state.lawyerInfo = p.lawyer_info || null;
                state.isLawyer = !!state.lawyerInfo;
                state.isLawyerAdmin = state.lawyerInfo?.is_admin || false;
            }
        }
        if (isAdmin || state.isLawyerAdmin) {
            state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`) || [];
            state.allLawyers = await api(`/api/admin/lawyers?admin_telegram_id=${user?.id}`) || [];
            state.stats = await api(`/api/admin/stats?admin_telegram_id=${user?.id}`);
            state.todayBookings = await api(`/api/admin/today-bookings?admin_telegram_id=${user?.id}`) || [];
            state.allReviews = await api(`/api/admin/reviews?admin_telegram_id=${user?.id}`) || [];
        }
    } catch (e) { console.error(e); }
    rn(state.screen);
}

ld();
EOF

echo ""
echo "=============================================="
echo "  ЮРИДИЧЕСКАЯ ВЕРСИЯ ГОТОВА!"
echo "  6 частей. Модульный фронтенд (10 JS-файлов)."
echo "  Все 33 пункта + исправления + сжатие фото."
echo "  Запусти: bash setup.sh"
echo "=============================================="