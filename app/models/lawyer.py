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
