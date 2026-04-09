from sqlalchemy.orm import Session
from typing import List, Optional
from app.models.comment import Comment
from app.schemas.comment import CommentCreate


def get_comment(db: Session, comment_id: int) -> Optional[Comment]:
    """Get comment by ID"""
    return db.query(Comment).filter(Comment.id == comment_id).first()


def get_comments_by_todo(db: Session, todo_id: int) -> List[Comment]:
    """Get all comments for a todo"""
    return db.query(Comment).filter(Comment.todo_id == todo_id).all()


def get_comments_by_user(db: Session, user_id: int) -> List[Comment]:
    """Get all comments by a user"""
    return db.query(Comment).filter(Comment.user_id == user_id).all()


def create_comment(db: Session, comment: CommentCreate) -> Comment:
    """Create new comment"""
    db_comment = Comment(**comment.model_dump())
    db.add(db_comment)
    db.commit()
    db.refresh(db_comment)
    return db_comment


def delete_comment(db: Session, comment_id: int) -> bool:
    """Delete comment"""
    db_comment = get_comment(db, comment_id)
    if not db_comment:
        return False
    
    db.delete(db_comment)
    db.commit()
    return True
