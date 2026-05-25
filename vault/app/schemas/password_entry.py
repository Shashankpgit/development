from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime


class PasswordEntryCreate(BaseModel):
    label: str
    username: str
    value: str


class PasswordEntryUpdate(BaseModel):
    label: Optional[str] = None
    username: Optional[str] = None
    value: Optional[str] = None


class PasswordListResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    label: str
    username: str
    created_at: datetime
    updated_at: datetime


class PasswordDetailResponse(PasswordListResponse):
    value: str
