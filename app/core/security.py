from app.config import settings

def is_admin(telegram_id: int) -> bool:
    return telegram_id in settings.ADMIN_IDS
