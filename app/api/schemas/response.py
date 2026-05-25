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
