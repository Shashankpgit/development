from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.api import deps
from app.crud import crud_category
from app.schemas.category import CategoryCreate, CategoryResponse, CategoryWithTodos

router = APIRouter()


@router.post("/", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
def create_category(
    *,
    db: Session = Depends(deps.get_db),
    category_in: CategoryCreate
):
    """Create new category"""
    category = crud_category.get_category_by_name(db, name=category_in.name)
    if category:
        raise HTTPException(
            status_code=400,
            detail="Category already exists",
        )
    return crud_category.create_category(db, category=category_in)


@router.get("/", response_model=List[CategoryResponse])
def read_categories(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100
):
    """Retrieve categories"""
    return crud_category.get_categories(db, skip=skip, limit=limit)


@router.get("/{category_id}", response_model=CategoryWithTodos)
def read_category_by_id(
    category_id: int,
    db: Session = Depends(deps.get_db)
):
    """Get category by ID with todos"""
    category = crud_category.get_category(db, category_id=category_id)
    if not category:
        raise HTTPException(
            status_code=404,
            detail="Category not found",
        )
    return category


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category(
    *,
    db: Session = Depends(deps.get_db),
    category_id: int
):
    """Delete a category"""
    success = crud_category.delete_category(db, category_id=category_id)
    if not success:
        raise HTTPException(
            status_code=404,
            detail="Category not found",
        )
    return None
