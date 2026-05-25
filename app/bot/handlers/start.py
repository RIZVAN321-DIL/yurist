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
