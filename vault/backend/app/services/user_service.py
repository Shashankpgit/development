from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.repositories import user_repository


def get(db: Session, user_id: int):
    user = user_repository.get_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
