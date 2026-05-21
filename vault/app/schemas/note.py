from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime


class NoteCreate(BaseModel):
    user_id: int
    title: str
    body: Optional[str] = None


class NoteUpdate(BaseModel):
    title: Optional[str] = None
    body: Optional[str] = None


class NoteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    title: str
    body: Optional[str]
    created_at: datetime
    updated_at: datetime
