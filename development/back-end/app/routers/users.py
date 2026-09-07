"""User endpoints.

Note what is NOT here: passwords, login, tokens. This is a CRUD exercise, so
"user" means "a record with contact details". Auth is its own topic with its
own hazards (hashing, sessions, refresh) and mixing it in here would blur both.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db

router = APIRouter(prefix="/api/users", tags=["users"])


def get_user_or_404(user_id: int, db: Session) -> models.User:
    user = db.get(models.User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"User {user_id} not found"
        )
    return user


@router.post("", response_model=schemas.UserRead, status_code=status.HTTP_201_CREATED)
def create_user(payload: schemas.UserCreate, db: Session = Depends(get_db)):
    exists = db.scalar(select(models.User).where(models.User.email == payload.email))
    if exists:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=f"Email {payload.email} is already used"
        )
    user = models.User(**payload.model_dump())
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.get("", response_model=list[schemas.UserRead])
def list_users(db: Session = Depends(get_db)):
    return db.scalars(select(models.User).order_by(models.User.id)).all()


@router.get("/{user_id}", response_model=schemas.UserRead)
def get_user(user_id: int, db: Session = Depends(get_db)):
    return get_user_or_404(user_id, db)


@router.put("/{user_id}", response_model=schemas.UserRead)
def update_user(user_id: int, payload: schemas.UserUpdate, db: Session = Depends(get_db)):
    user = get_user_or_404(user_id, db)
    changes = payload.model_dump(exclude_unset=True)

    if "email" in changes and changes["email"] != user.email:
        clash = db.scalar(select(models.User).where(models.User.email == changes["email"]))
        if clash:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Email {changes['email']} is already used",
            )

    for field, value in changes.items():
        setattr(user, field, value)
    db.commit()
    db.refresh(user)
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(user_id: int, db: Session = Depends(get_db)):
    """Blocked if the user has orders.

    WHY: orders are financial records. Silently deleting them to make a DELETE
    call succeed is the kind of "convenience" that ends up in an audit report.
    The cart, by contrast, is disposable -- cascade="all, delete-orphan" on the
    model wipes it automatically.
    """
    user = get_user_or_404(user_id, db)

    has_orders = db.scalar(select(models.Order).where(models.Order.user_id == user_id).limit(1))
    if has_orders:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot delete a user who has orders. Cancel or reassign them first.",
        )

    db.delete(user)
    db.commit()
    return None
