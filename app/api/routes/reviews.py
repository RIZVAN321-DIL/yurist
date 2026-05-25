from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.api.schemas.review import ReviewCreateSchema
from app.services.review_service import ReviewService
from app.repositories.client_repo import ClientRepository
from app.repositories.review_repo import ReviewRepository
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["reviews"])

@router.post("/reviews")
async def create_review(data: ReviewCreateSchema, session: AsyncSession = Depends(get_session)):
    client = await ClientRepository(session).get_by_telegram_id(data.telegram_id)
    if not client:
        raise HTTPException(status_code=404, detail="Клиент не найден")
    try:
        return await ReviewService(session).create_review(client.id, data.booking_id, data.rating, data.comment)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/my-reviews")
async def get_my_reviews(telegram_id: int, session: AsyncSession = Depends(get_session)):
    client = await ClientRepository(session).get_by_telegram_id(telegram_id)
    if not client:
        return []
    reviews = await ReviewRepository(session).get_by_client(client.id)
    return [{"id": r.id, "lawyer_name": r.lawyer.name if r.lawyer else "—", "rating": r.rating, "comment": r.comment} for r in reviews]

@router.get("/admin/reviews")
async def get_all_reviews(admin_telegram_id: int, lawyer_id: int | None = Query(default=None), session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403)
    reviews = await ReviewRepository(session).get_all_reviews(lawyer_id)
    return [{"id": r.id, "client_name": r.client.first_name or "—", "lawyer_name": r.lawyer.name if r.lawyer else "—", "rating": r.rating, "comment": r.comment} for r in reviews]
