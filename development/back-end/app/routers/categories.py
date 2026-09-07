"""Category endpoints. Read this file first -- it is the simplest of the five
and every other router follows the same five-step shape."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db

# prefix -> every path below is automatically /api/categories/...
# tags   -> groups these endpoints together in the auto-generated /docs page.
router = APIRouter(prefix="/api/categories", tags=["categories"])


def get_category_or_404(category_id: int, db: Session) -> models.Category:
    """Fetch-or-fail helper.

    WHY a helper? Three endpoints need "load it, and if it is missing return a
    404". Writing that three times is three chances to get it subtly wrong.
    """
    category = db.get(models.Category, category_id)
    if category is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Category {category_id} not found",
        )
    return category


@router.post("", response_model=schemas.CategoryRead, status_code=status.HTTP_201_CREATED)
def create_category(payload: schemas.CategoryCreate, db: Session = Depends(get_db)):
    """201 Created, not 200 OK: the response code tells the client a new
    resource now exists. Small detail, but it is what REST clients expect."""
    exists = db.scalar(select(models.Category).where(models.Category.name == payload.name))
    if exists:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Category '{payload.name}' already exists",
        )

    category = models.Category(**payload.model_dump())
    db.add(category)       # stage it in the session
    db.commit()            # write to disk (the transaction ends here)
    db.refresh(category)   # re-read it so `id` and `created_at` are populated
    return category


@router.get("", response_model=list[schemas.CategoryRead])
def list_categories(db: Session = Depends(get_db)):
    return db.scalars(select(models.Category).order_by(models.Category.id)).all()


@router.get("/{category_id}", response_model=schemas.CategoryRead)
def get_category(category_id: int, db: Session = Depends(get_db)):
    return get_category_or_404(category_id, db)


@router.put("/{category_id}", response_model=schemas.CategoryRead)
def update_category(
    category_id: int, payload: schemas.CategoryUpdate, db: Session = Depends(get_db)
):
    category = get_category_or_404(category_id, db)

    # exclude_unset=True is the key line: it gives us ONLY the fields the
    # client actually sent. Without it, every omitted field would arrive as
    # None and we would wipe good data with nulls.
    changes = payload.model_dump(exclude_unset=True)

    if "name" in changes and changes["name"] != category.name:
        clash = db.scalar(select(models.Category).where(models.Category.name == changes["name"]))
        if clash:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Category '{changes['name']}' already exists",
            )

    for field, value in changes.items():
        setattr(category, field, value)
    db.commit()
    db.refresh(category)
    return category


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category(category_id: int, db: Session = Depends(get_db)):
    """204 No Content: success, and there is deliberately nothing to return.

    We refuse to delete a category that still has products. The alternative
    (cascade-delete the products) destroys data the caller did not ask about.
    """
    category = get_category_or_404(category_id, db)

    in_use = db.scalar(
        select(models.Product).where(models.Product.category_id == category_id).limit(1)
    )
    if in_use:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cannot delete a category that still has products assigned to it",
        )

    db.delete(category)
    db.commit()
    return None
