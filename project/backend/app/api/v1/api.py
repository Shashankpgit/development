"""
API v1 router
"""
from fastapi import APIRouter
from app.api.v1.endpoints import auth, users

api_router = APIRouter()

# Authentication routes
api_router.include_router(
    auth.router,
    prefix="/auth",
    tags=["authentication"]
)

# User management routes
api_router.include_router(
    users.router,
    prefix="/users",
    tags=["users"]
)