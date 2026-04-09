from sqlalchemy.orm import Session
from typing import List, Optional
from app.models.category import Category
from app.schemas.category import CategoryCreate


def get_category(db: Session, category_id: int) -> Optional[Category]:
    """Get category by ID"""
    return db.query(Category).filter(Category.id == category_id).first()


def get_category_by_name(db: Session, name: str) -> Optional[Category]:
    """Get category by name"""
    return db.query(Category).filter(Category.name == name).first()


def get_categories(db: Session, skip: int = 0, limit: int = 100) -> List[Category]:
    """Get all categories"""
    return db.query(Category).offset(skip).limit(limit).all()


def create_category(db: Session, category: CategoryCreate) -> Category:
    """Create new category"""
    db_category = Category(**category.model_dump())
    db.add(db_category)
    db.commit()
    db.refresh(db_category)
    return db_category


def delete_category(db: Session, category_id: int) -> bool:
    """Delete category"""
    db_category = get_category(db, category_id)
    if not db_category:
        return False
    
    db.delete(db_category)
    db.commit()
    return True
