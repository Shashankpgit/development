"""
User CRUD operations
"""
from sqlalchemy.orm import Session
from typing import Optional, List
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate
from app.core.security import get_password_hash, verify_password


def get_user(db: Session, user_id: int) -> Optional[User]:
    """Get user by ID"""
    return db.query(User).filter(User.id == user_id).first()


def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """Get user by email"""
    return db.query(User).filter(User.email == email).first()


def get_users(db: Session, skip: int = 0, limit: int = 100) -> List[User]:
    """Get all users (paginated)"""
    return db.query(User).offset(skip).limit(limit).all()


def create_user(db: Session, user_in: UserCreate) -> User:
    """
    Create new user
    
    Args:
        db: Database session
        user_in: User creation data
        
    Returns:
        Created user
    """
    db_user = User(
        email=user_in.email,
        hashed_password=get_password_hash(user_in.password),
        full_name=user_in.full_name,
        is_active=True,
        is_superuser=False,
        is_verified=False  # Set to True after email verification
    )
    
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    return db_user


def authenticate(db: Session, email: str, password: str) -> Optional[User]:
    """
    Authenticate user
    
    Args:
        db: Database session
        email: User email
        password: Plain text password
        
    Returns:
        User if credentials valid, None otherwise
    """
    user = get_user_by_email(db, email=email)
    
    if not user:
        return None
    
    if not verify_password(password, user.hashed_password):
        return None
    
    return user


def update_user(db: Session, user_id: int, user_in: UserUpdate) -> Optional[User]:
    """
    Update user
    
    Args:
        db: Database session
        user_id: User ID
        user_in: Update data
        
    Returns:
        Updated user or None
    """
    user = get_user(db, user_id)
    
    if not user:
        return None
    
    update_data = user_in.model_dump(exclude_unset=True)
    
    # Handle password separately
    if "password" in update_data:
        hashed_password = get_password_hash(update_data["password"])
        del update_data["password"]
        update_data["hashed_password"] = hashed_password
    
    for field, value in update_data.items():
        setattr(user, field, value)
    
    db.commit()
    db.refresh(user)
    
    return user


def delete_user(db: Session, user_id: int) -> bool:
    """
    Delete user
    
    Args:
        db: Database session
        user_id: User ID
        
    Returns:
        True if deleted, False if not found
    """
    user = get_user(db, user_id)
    
    if not user:
        return False
    
    db.delete(user)
    db.commit()
    
    return True


def activate_user(db: Session, user_id: int) -> Optional[User]:
    """Activate user account"""
    user = get_user(db, user_id)
    
    if not user:
        return None
    
    user.is_active = True
    db.commit()
    db.refresh(user)
    
    return user


def deactivate_user(db: Session, user_id: int) -> Optional[User]:
    """Deactivate user account"""
    user = get_user(db, user_id)
    
    if not user:
        return None
    
    user.is_active = False
    db.commit()
    db.refresh(user)
    
    return user


def verify_user_email(db: Session, user_id: int) -> Optional[User]:
    """Mark user email as verified"""
    user = get_user(db, user_id)
    
    if not user:
        return None
    
    user.is_verified = True
    db.commit()
    db.refresh(user)
    
    return user