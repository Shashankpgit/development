import logging
from fastapi import FastAPI
from app.config import APP_ENV
from app.routers import health
from app.routers import users
from app.routers import notes
from app.routers import passwords
from app.database import Base, engine

# Configure Python logging so vault.auth errors appear in kubectl logs
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
)
logger = logging.getLogger("vault")

app = FastAPI(
    title="Personal Vault",
    description="A private storage app for notes and passwords",
    version="0.1.0",
)

app.include_router(health.router)
app.include_router(users.router)
app.include_router(notes.router)
app.include_router(passwords.router)


@app.on_event("startup")
async def startup():
    logger.info(f"[vault] starting in {APP_ENV} mode")
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("[vault] database tables verified/created")
    except Exception as e:
        logger.error("[vault] STARTUP FAILED — could not create tables: %s", e)
        raise
