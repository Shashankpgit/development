from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate


def get_user(db: Session, user_id: int) -> Optional[User]:
    """Get user by ID"""
    return db.query(User).filter(User.id == user_id).first()


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """Get user by email"""
    return db.query(User).filter(User.email == email).first()


def get_users(db: Session, skip: int = 0, limit: int = 100) -> List[User]:
    """Get all users"""
    return db.query(User).offset(skip).limit(limit).all()


def get_user_with_todos(db: Session, user_id: int) -> Optional[User]:
    """Get user with all their todos (eager loading)"""
    return db.query(User)\
        .options(joinedload(User.todos))\
        .filter(User.id == user_id)\
        .first()


def create_user(db: Session, user: UserCreate) -> User:
    """Create new user"""
    db_user = User(**user.model_dump())
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def update_user(db: Session, user_id: int, user_update: UserUpdate) -> Optional[User]:
    """Update user"""
    db_user = get_user(db, user_id)
    if not db_user:
        return None
    
    update_data = user_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_user, field, value)
    
    db.commit()
    db.refresh(db_user)
    return db_user


def delete_user(db: Session, user_id: int) -> bool:
    """Delete user (cascades to todos)"""
    db_user = get_user(db, user_id)
    if not db_user:
        return False
    
    db.delete(db_user)
    db.commit()
    return True
