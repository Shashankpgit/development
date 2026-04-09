"""
FastAPI application entry point
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.db.base import Base
from app.db.session import engine
from app.api.v1.api import api_router

# Create database tables
Base.metadata.create_all(bind=engine)

# Initialize FastAPI app
app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Authentication API with JWT",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API router
app.include_router(api_router, prefix="/api/v1")


@app.get("/", tags=["Root"])
def root():
    """Root endpoint"""
    return {
        "message": f"Welcome to {settings.PROJECT_NAME}",
        "docs": "/docs",
        "version": "1.0.0"
    }


@app.get("/health", tags=["Health"])
def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)