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
