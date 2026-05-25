from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.repositories import user_repository
from app.utils.auth import hash_password, verify_password, create_token


def register(db: Session, username: str, password: str):
    if user_repository.get_by_username(db, username):
        raise HTTPException(status_code=400, detail="Username already taken")
    return user_repository.create(db, username=username, hashed_password=hash_password(password))


def login(db: Session, username: str, password: str) -> str:
    user = user_repository.get_by_username(db, username)
    if not user or not verify_password(password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return create_token(user.id)


def get(db: Session, user_id: int):
    user = user_repository.get_by_id(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user
