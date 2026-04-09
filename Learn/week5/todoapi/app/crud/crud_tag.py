from sqlalchemy.orm import Session
from typing import List, Optional
from app.models.tag import Tag
from app.schemas.tag import TagCreate


def get_tag(db: Session, tag_id: int) -> Optional[Tag]:
    """Get tag by ID"""
    return db.query(Tag).filter(Tag.id == tag_id).first()


def get_tag_by_name(db: Session, name: str) -> Optional[Tag]:
    """Get tag by name"""
    return db.query(Tag).filter(Tag.name == name).first()


def get_tags(db: Session, skip: int = 0, limit: int = 100) -> List[Tag]:
    """Get all tags"""
    return db.query(Tag).offset(skip).limit(limit).all()


def create_tag(db: Session, tag: TagCreate) -> Tag:
    """Create new tag"""
    db_tag = Tag(**tag.model_dump())
    db.add(db_tag)
    db.commit()
    db.refresh(db_tag)
    return db_tag


def delete_tag(db: Session, tag_id: int) -> bool:
    """Delete tag"""
    db_tag = get_tag(db, tag_id)
    if not db_tag:
        return False
    
    db.delete(db_tag)
    db.commit()
    return True
