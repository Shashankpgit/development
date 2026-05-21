from fastapi import FastAPI
from app.config import APP_ENV
from app.routers import health
from app.database import Base, engine

app = FastAPI(
    title="Personal Vault",
    description="A private storage app for notes and passwords",
    version="0.1.0",
)

app.include_router(health.router)


@app.on_event("startup")
async def startup():
    print(f"[vault] starting in {APP_ENV} mode")
    Base.metadata.create_all(bind=engine)
