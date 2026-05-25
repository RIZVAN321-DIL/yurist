from pydantic import BaseModel, Field

class ReviewCreateSchema(BaseModel):
    telegram_id: int
    booking_id: int
    rating: int = Field(ge=1, le=5)
    comment: str | None = None
