from sqlalchemy.ext.asyncio import AsyncSession
from app.models.review import Review
from app.repositories.review_repo import ReviewRepository
from app.repositories.booking_repo import BookingRepository
from app.repositories.client_repo import ClientRepository
from app.repositories.lawyer_repo import LawyerRepository
from app.config import settings

class ReviewService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.review_repo = ReviewRepository(session)
        self.booking_repo = BookingRepository(session)
        self.client_repo = ClientRepository(session)
        self.lawyer_repo = LawyerRepository(session)

    async def create_review(self, client_id: int, booking_id: int, rating: int, comment: str | None = None):
        booking = await self.booking_repo.get_by_id(booking_id)
        if not booking:
            raise ValueError("Запись не найдена")
        if booking.client_id != client_id:
            raise ValueError("Это не ваша запись")
        existing = await self.review_repo.get_by_booking_id(booking_id)
        if existing:
            raise ValueError("Отзыв уже оставлен")
        review = Review(client_id=client_id, lawyer_id=booking.lawyer_id, booking_id=booking_id, rating=rating, comment=comment)
        await self.review_repo.create(review)
        await self.lawyer_repo.update_rating(booking.lawyer_id)
        total_reviews = await self.review_repo.count_by_client(client_id)
        if total_reviews % settings.BONUS_VISITS_INTERVAL == 0:
            await self.client_repo.add_bonus(client_id, settings.BONUS_AMOUNT)
            await self.session.commit()
            return {"ok": True, "review_id": review.id, "bonus_added": True, "bonus_amount": settings.BONUS_AMOUNT}
        await self.session.commit()
        return {"ok": True, "review_id": review.id, "bonus_added": False}
