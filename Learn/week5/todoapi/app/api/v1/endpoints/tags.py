from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.api import deps
from app.crud import crud_tag
from app.schemas.tag import TagCreate, TagResponse, TagWithTodos

router = APIRouter()


@router.post("/", response_model=TagResponse, status_code=status.HTTP_201_CREATED)
def create_tag(
    *,
    db: Session = Depends(deps.get_db),
    tag_in: TagCreate
):
    """Create new tag"""
    tag = crud_tag.get_tag_by_name(db, name=tag_in.name)
    if tag:
        raise HTTPException(
            status_code=400,
            detail="Tag already exists",
        )
    return crud_tag.create_tag(db, tag=tag_in)


@router.get("/", response_model=List[TagResponse])
def read_tags(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100
):
    """Retrieve tags"""
    return crud_tag.get_tags(db, skip=skip, limit=limit)


@router.get("/{tag_id}", response_model=TagWithTodos)
def read_tag_by_id(
    tag_id: int,
    db: Session = Depends(deps.get_db)
):
    """Get tag by ID with todos"""
    tag = crud_tag.get_tag(db, tag_id=tag_id)
    if not tag:
        raise HTTPException(
            status_code=404,
            detail="Tag not found",
        )
    return tag


@router.delete("/{tag_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_tag(
    *,
    db: Session = Depends(deps.get_db),
    tag_id: int
):
    """Delete a tag"""
    success = crud_tag.delete_tag(db, tag_id=tag_id)
    if not success:
        raise HTTPException(
            status_code=404,
            detail="Tag not found",
        )
    return None
