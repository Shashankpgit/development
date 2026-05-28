import base64
import json
import logging
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.user import User
from app.repositories import user_repository

bearer_scheme = HTTPBearer()
logger = logging.getLogger("vault.auth")


def _decode_jwt_payload(token: str) -> dict:
    """
    Decode the payload section of a JWT without verifying the signature.
    Signature verification is Kong's job — it validates before forwarding here.
    Raises ValueError with a descriptive message on any parse failure.
    """
    parts = token.split(".")
    if len(parts) != 3:
        raise ValueError(
            f"Expected a 3-part JWT (header.payload.sig), got {len(parts)} parts. "
            f"First 40 chars: {token[:40]!r}"
        )

    payload_b64 = parts[1]
    # JWT base64url strips '=' padding — add it back before decoding
    remainder = len(payload_b64) % 4
    if remainder:
        payload_b64 += "=" * (4 - remainder)

    raw = base64.urlsafe_b64decode(payload_b64)
    return json.loads(raw)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    # ── Step 1: decode the JWT (signature already verified by Kong) ───────────
    try:
        payload = _decode_jwt_payload(credentials.credentials)
    except (ValueError, KeyError, json.JSONDecodeError, Exception) as e:
        logger.error("JWT decode failed: %s", e)
        raise HTTPException(status_code=401, detail="Invalid token")

    sub = payload.get("sub")
    if not sub:
        logger.error(
            "JWT is missing 'sub' claim. Claims present: %s  iss=%s",
            list(payload.keys()),
            payload.get("iss"),
        )
        raise HTTPException(status_code=401, detail="Invalid token")

    # ── Step 2: look up or create the user (DB errors propagate as 500) ───────
    user = user_repository.get_by_sub(db, sub)
    if not user:
        user = user_repository.create(db, sub=sub)
    return user
