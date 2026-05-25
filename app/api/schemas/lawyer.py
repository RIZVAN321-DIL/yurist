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
