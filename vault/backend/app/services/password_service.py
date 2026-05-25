from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.repositories import password_repository
from app.utils.crypto import encrypt, decrypt


def list_for_user(db: Session, user_id: int):
    return password_repository.get_by_user(db, user_id)


def get(db: Session, entry_id: int, user_id: int):
    entry = password_repository.get_by_id(db, entry_id, user_id)
    if not entry:
        raise HTTPException(status_code=404, detail="Password entry not found")
    return entry


def get_with_decrypted_value(db: Session, entry_id: int, user_id: int) -> dict:
    entry = get(db, entry_id, user_id)
    return {
        "id": entry.id,
        "user_id": entry.user_id,
        "label": entry.label,
        "username": entry.username,
        "value": decrypt(entry.encrypted_value),
        "created_at": entry.created_at,
        "updated_at": entry.updated_at,
    }


def create(db: Session, user_id: int, label: str, username: str, value: str):
    return password_repository.create(db, user_id=user_id, label=label, username=username, encrypted_value=encrypt(value))


def update(db: Session, entry_id: int, user_id: int, data: dict):
    entry = get(db, entry_id, user_id)
    if "value" in data:
        data["encrypted_value"] = encrypt(data.pop("value"))
    return password_repository.update(db, entry, data)


def delete(db: Session, entry_id: int, user_id: int):
    entry = get(db, entry_id, user_id)
    password_repository.delete(db, entry)
