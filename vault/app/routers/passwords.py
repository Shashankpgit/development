from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models.password_entry import PasswordEntry
from app.schemas.password_entry import (
    PasswordEntryCreate,
    PasswordEntryUpdate,
    PasswordListResponse,
    PasswordDetailResponse,
)
from app.utils.crypto import encrypt, decrypt

router = APIRouter(prefix="/passwords", tags=["passwords"])


@router.post("", response_model=PasswordListResponse, status_code=201)
def create_password(entry: PasswordEntryCreate, db: Session = Depends(get_db)):
    db_entry = PasswordEntry(
        user_id=entry.user_id,
        label=entry.label,
        username=entry.username,
        encrypted_value=encrypt(entry.value),
    )
    db.add(db_entry)
    db.commit()
    db.refresh(db_entry)
    return db_entry


@router.get("", response_model=List[PasswordListResponse])
def list_passwords(user_id: int, db: Session = Depends(get_db)):
    return db.query(PasswordEntry).filter(PasswordEntry.user_id == user_id).all()


@router.get("/{entry_id}", response_model=PasswordDetailResponse)
def get_password(entry_id: int, db: Session = Depends(get_db)):
    entry = db.query(PasswordEntry).filter(PasswordEntry.id == entry_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Password entry not found")
    return PasswordDetailResponse(
        id=entry.id,
        user_id=entry.user_id,
        label=entry.label,
        username=entry.username,
        created_at=entry.created_at,
        updated_at=entry.updated_at,
        value=decrypt(entry.encrypted_value),
    )


@router.put("/{entry_id}", response_model=PasswordListResponse)
def update_password(entry_id: int, payload: PasswordEntryUpdate, db: Session = Depends(get_db)):
    entry = db.query(PasswordEntry).filter(PasswordEntry.id == entry_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Password entry not found")
    update_data = payload.model_dump(exclude_unset=True)
    if "value" in update_data:
        entry.encrypted_value = encrypt(update_data.pop("value"))
    for field, value in update_data.items():
        setattr(entry, field, value)
    db.commit()
    db.refresh(entry)
    return entry


@router.delete("/{entry_id}", status_code=204)
def delete_password(entry_id: int, db: Session = Depends(get_db)):
    entry = db.query(PasswordEntry).filter(PasswordEntry.id == entry_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Password entry not found")
    db.delete(entry)
    db.commit()
