from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models.user import User
from app.schemas.password_entry import (
    PasswordEntryCreate,
    PasswordEntryUpdate,
    PasswordListResponse,
    PasswordDetailResponse,
)
from app.dependencies import get_current_user
from app.services import password_service

router = APIRouter(prefix="/passwords", tags=["passwords"])


@router.post("", response_model=PasswordListResponse, status_code=201)
def create_password(entry: PasswordEntryCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return password_service.create(db, user_id=current_user.id, label=entry.label, username=entry.username, value=entry.value)


@router.get("", response_model=List[PasswordListResponse])
def list_passwords(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return password_service.list_for_user(db, current_user.id)


@router.get("/{entry_id}", response_model=PasswordDetailResponse)
def get_password(entry_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return password_service.get_with_decrypted_value(db, entry_id, current_user.id)


@router.put("/{entry_id}", response_model=PasswordListResponse)
def update_password(entry_id: int, payload: PasswordEntryUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return password_service.update(db, entry_id, current_user.id, payload.model_dump(exclude_unset=True))


@router.delete("/{entry_id}", status_code=204)
def delete_password(entry_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    password_service.delete(db, entry_id, current_user.id)
