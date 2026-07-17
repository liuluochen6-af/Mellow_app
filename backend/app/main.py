from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import os

from app.database import create_tables
from app.routers.auth import router as auth_router
from app.routers.checkin import router as checkin_router
from app.routers.social import router as social_router
from app.routers.stats import router as stats_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    await create_tables()
    yield


app = FastAPI(title="FoodCheckIn API", lifespan=lifespan)

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

app.include_router(auth_router)
app.include_router(checkin_router)
app.include_router(social_router)
app.include_router(stats_router)


@app.get("/health")
async def health():
    return {"status": "ok"}
