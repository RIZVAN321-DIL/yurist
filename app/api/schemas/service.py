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
