from sqlalchemy.orm import Session
from app.models.password_entry import PasswordEntry


def get_by_user(db: Session, user_id: int):
    return db.query(PasswordEntry).filter(PasswordEntry.user_id == user_id).all()


def get_by_id(db: Session, entry_id: int, user_id: int):
    return db.query(PasswordEntry).filter(PasswordEntry.id == entry_id, PasswordEntry.user_id == user_id).first()


def create(db: Session, user_id: int, label: str, username: str, encrypted_value: str):
    entry = PasswordEntry(user_id=user_id, label=label, username=username, encrypted_value=encrypted_value)
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry


def update(db: Session, entry: PasswordEntry, data: dict):
    for field, value in data.items():
        setattr(entry, field, value)
    db.commit()
    db.refresh(entry)
    return entry


def delete(db: Session, entry: PasswordEntry):
    db.delete(entry)
    db.commit()
