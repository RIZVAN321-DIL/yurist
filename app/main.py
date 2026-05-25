from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from app.database import engine, Base
from app.seed import seed_database
from app.logger import logger
from app.core.scheduler import scheduler
from app.services.notification_service import NotificationService
from app.api.routes.booking import router as booking_router
from app.api.routes.services import router as services_router
from app.api.routes.lawyers import router as lawyers_router
from app.api.routes.slots import router as slots_router
from app.api.routes.reviews import router as reviews_router
from app.api.routes.stats import router as stats_router
from app.api.routes.broadcast import router as broadcast_router
from app.api.routes.profile import router as profile_router
from app.api.routes.upload import router as upload_router
from app.api.routes.weekend import router as weekend_router
import app.models

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("API start")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await seed_database()
    scheduler.start()
    await NotificationService.restore_reminders()
    logger.info("API ready")
    yield
    scheduler.shutdown(wait=False)
    logger.info("API stop")

app = FastAPI(title="Yurist API", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(booking_router)
app.include_router(services_router)
app.include_router(lawyers_router)
app.include_router(slots_router)
app.include_router(reviews_router)
app.include_router(stats_router)
app.include_router(broadcast_router)
app.include_router(profile_router)
app.include_router(upload_router)
app.include_router(weekend_router)
app.mount("/static", StaticFiles(directory="app/static"), name="static")

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/mini-app")
async def mini_app():
    return FileResponse("app/static/index.html")
