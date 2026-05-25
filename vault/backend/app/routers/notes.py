from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models.user import User
from app.schemas.note import NoteCreate, NoteUpdate, NoteResponse
from app.dependencies import get_current_user
from app.services import note_service

router = APIRouter(prefix="/notes", tags=["notes"])


@router.post("", response_model=NoteResponse, status_code=201)
def create_note(note: NoteCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return note_service.create(db, user_id=current_user.id, title=note.title, body=note.body)


@router.get("", response_model=List[NoteResponse])
def list_notes(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return note_service.list_for_user(db, current_user.id)


@router.get("/{note_id}", response_model=NoteResponse)
def get_note(note_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return note_service.get(db, note_id, current_user.id)


@router.put("/{note_id}", response_model=NoteResponse)
def update_note(note_id: int, payload: NoteUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return note_service.update(db, note_id, current_user.id, payload.model_dump(exclude_unset=True))


@router.delete("/{note_id}", status_code=204)
def delete_note(note_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    note_service.delete(db, note_id, current_user.id)
