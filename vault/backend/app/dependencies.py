import base64
import json
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User
from app.repositories import user_repository

bearer_scheme = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    try:
        payload_b64 = credentials.credentials.split(".")[1]
        padding = 4 - len(payload_b64) % 4
        if padding != 4:
            payload_b64 += "=" * padding
        payload = json.loads(base64.urlsafe_b64decode(payload_b64))
        sub = payload.get("sub")
        if not sub:
            raise ValueError("No sub claim")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = user_repository.get_by_sub(db, sub)
    if not user:
        user = user_repository.create(db, sub=sub)
    return user
