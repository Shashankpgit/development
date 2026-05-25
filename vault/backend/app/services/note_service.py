from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.repositories import note_repository


def list_for_user(db: Session, user_id: int):
    return note_repository.get_by_user(db, user_id)


def get(db: Session, note_id: int, user_id: int):
    note = note_repository.get_by_id(db, note_id, user_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    return note


def create(db: Session, user_id: int, title: str, body: str):
    return note_repository.create(db, user_id=user_id, title=title, body=body)


def update(db: Session, note_id: int, user_id: int, data: dict):
    note = get(db, note_id, user_id)
    return note_repository.update(db, note, data)


def delete(db: Session, note_id: int, user_id: int):
    note = get(db, note_id, user_id)
    note_repository.delete(db, note)
