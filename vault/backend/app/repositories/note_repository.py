from sqlalchemy.orm import Session
from app.models.note import Note


def get_by_user(db: Session, user_id: int):
    return db.query(Note).filter(Note.user_id == user_id).all()


def get_by_id(db: Session, note_id: int, user_id: int):
    return db.query(Note).filter(Note.id == note_id, Note.user_id == user_id).first()


def create(db: Session, user_id: int, title: str, body: str):
    note = Note(user_id=user_id, title=title, body=body)
    db.add(note)
    db.commit()
    db.refresh(note)
    return note


def update(db: Session, note: Note, data: dict):
    for field, value in data.items():
        setattr(note, field, value)
    db.commit()
    db.refresh(note)
    return note


def delete(db: Session, note: Note):
    db.delete(note)
    db.commit()
