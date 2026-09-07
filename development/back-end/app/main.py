"""Application entry point: build the FastAPI app, wire middleware + routers.

Run it locally with:
    uvicorn app.main:app --reload --port 8000
                ^^^^ ^^^
                file  variable inside that file
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from . import models  # noqa: F401  -- imported so Base knows about the tables
from .config import settings
from .database import Base, engine
from .routers import cart, categories, orders, products, users


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown hook.

    Code before `yield` runs once when the process starts, code after runs on
    shutdown. create_all() issues CREATE TABLE IF NOT EXISTS for every model.

    IMPORTANT for later: create_all only ADDS tables. It will never alter a
    column you changed. The moment this app has real data, this line must be
    replaced by Alembic migrations run as a Kubernetes Job -- otherwise two
    pods starting at once both try to create the same tables.
    """
    if settings.auto_create_tables:
        Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description="A small CRUD shop API: products, categories, users, cart, orders.",
    lifespan=lifespan,
)

# ---------------------------------------------------------------------------
# CORS -- the single most common "why does my frontend not work" cause.
#
# The browser enforces the "same-origin policy": JavaScript served from
# http://localhost:5173 may not read a response from http://localhost:8000,
# because host+port differ, so they are different ORIGINS. The browser first
# sends an OPTIONS "preflight" asking the API for permission; this middleware
# is what answers it. Note this is a BROWSER rule -- curl and Postman ignore
# it entirely, which is why an endpoint can work in Postman and fail in the UI.
# ---------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["health"])
def liveness():
    """LIVENESS: "is this process alive?" -- deliberately does NOT touch the DB.

    WHY: Kubernetes RESTARTS a pod that fails its liveness probe. If this
    checked Postgres, a database blip would restart every pod in the
    deployment, turning a recoverable outage into a crash loop.
    """
    return {"status": "ok", "service": settings.app_name}


@app.get("/health/ready", tags=["health"])
def readiness():
    """READINESS: "can this pod serve traffic right now?" -- DB check belongs here.

    Kubernetes only removes a not-ready pod from the load balancer; it does not
    kill it. So when Postgres comes back, the pod starts serving again.
    """
    from .database import SessionLocal

    db = SessionLocal()
    try:
        db.execute(text("SELECT 1"))
        return {"status": "ready", "database": "connected"}
    except Exception as exc:
        # 503 Service Unavailable is the correct code: we are healthy code
        # with an unhealthy dependency.
        from fastapi import HTTPException

        raise HTTPException(status_code=503, detail=f"database unavailable: {exc}") from exc
    finally:
        db.close()


app.include_router(categories.router)
app.include_router(products.router)
app.include_router(users.router)
app.include_router(cart.router)
app.include_router(orders.router)
