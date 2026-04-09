from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.api import deps
from app.crud import crud_comment
from app.schemas.comment import CommentCreate, CommentResponse

router = APIRouter()


@router.post("/", response_model=CommentResponse, status_code=status.HTTP_201_CREATED)
def create_comment(
    *,
    db: Session = Depends(deps.get_db),
    comment_in: CommentCreate
):
    """Create new comment"""
    return crud_comment.create_comment(db, comment=comment_in)


@router.get("/todo/{todo_id}", response_model=List[CommentResponse])
def read_comments_by_todo(
    todo_id: int,
    db: Session = Depends(deps.get_db)
):
    """Retrieve comments for a todo"""
    return crud_comment.get_comments_by_todo(db, todo_id=todo_id)


@router.delete("/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_comment(
    *,
    db: Session = Depends(deps.get_db),
    comment_id: int
):
    """Delete a comment"""
    success = crud_comment.delete_comment(db, comment_id=comment_id)
    if not success:
        raise HTTPException(
            status_code=404,
            detail="Comment not found",
        )
    return None
