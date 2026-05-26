from sqlalchemy.orm import Session
from app.models.user import User


def get_by_sub(db: Session, sub: str):
    return db.query(User).filter(User.sub == sub).first()


def get_by_id(db: Session, user_id: int):
    return db.query(User).filter(User.id == user_id).first()


def create(db: Session, sub: str):
    user = User(sub=sub)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user
