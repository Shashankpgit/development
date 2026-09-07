"""Database wiring: one engine, one session factory, one Base class.

WHY this file exists:
  Every request needs a short-lived "conversation" with the database (a
  Session). Opening a fresh TCP connection to Postgres per request costs
  milliseconds you do not need to spend, so SQLAlchemy keeps a POOL of open
  connections and hands them out. This module owns that pool.
"""

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import settings

engine = create_engine(
    settings.database_url,
    # pool_size: connections kept open permanently.
    # max_overflow: extra ones opened under load, then discarded.
    # This matters in Kubernetes: pool_size * number_of_pods must stay under
    # Postgres's max_connections (default 100), or new pods get rejected.
    pool_size=5,
    max_overflow=10,
    # Recycle connections after 30 min. Load balancers and Postgres itself
    # silently drop idle connections; without this you get a mystery
    # "server closed the connection unexpectedly" hours after deploying.
    pool_recycle=1800,
    # Check a connection is still alive before using it. Costs one tiny
    # round-trip, saves a class of flaky 500s.
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    """Parent class for every table. SQLAlchemy collects table metadata here."""


def get_db() -> Generator[Session, None, None]:
    """FastAPI dependency: hand a Session to the endpoint, always close it.

    `yield` makes this context-manager-like. The code after yield runs AFTER
    the response is sent -- even if the endpoint raised. Closing the session
    returns its connection to the pool; forget it and the pool leaks until
    the app hangs waiting for a free connection.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
