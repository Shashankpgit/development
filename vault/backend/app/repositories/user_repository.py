from sqlalchemy.orm import Session
from app.models.user import User


def get_by_username(db: Session, username: str):
    return db.query(User).filter(User.username == username).first()


def get_by_id(db: Session, user_id: int):
    return db.query(User).filter(User.id == user_id).first()


def create(db: Session, username: str, hashed_password: str):
    user = User(username=username, hashed_password=hashed_password)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user
