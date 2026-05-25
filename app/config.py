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
