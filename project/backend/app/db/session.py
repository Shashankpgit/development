"""
Database session management
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# Create engine
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    echo=True  # Set False in production
)

# Create session factory
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)


def get_db():
    """
    Database session dependency
    Yields session and ensures cleanup
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()