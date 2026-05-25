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
