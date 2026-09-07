"""Product endpoints.

New idea in this file: validating a foreign key BEFORE hitting the database.
If we just saved category_id=999, SQLite would either accept the orphan row
(foreign keys are off by default!) or raise an IntegrityError that surfaces as
an ugly 500. Checking first gives the client a clear 400 instead.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db

router = APIRouter(prefix="/api/products", tags=["products"])


def get_product_or_404(product_id: int, db: Session) -> models.Product:
    product = db.get(models.Product, product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Product {product_id} not found"
        )
    return product


def assert_category_exists(category_id: int | None, db: Session) -> None:
    if category_id is None:
        return
    if db.get(models.Category, category_id) is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Category {category_id} does not exist",
        )


@router.post("", response_model=schemas.ProductRead, status_code=status.HTTP_201_CREATED)
def create_product(payload: schemas.ProductCreate, db: Session = Depends(get_db)):
    assert_category_exists(payload.category_id, db)
    product = models.Product(**payload.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@router.get("", response_model=list[schemas.ProductRead])
def list_products(
    db: Session = Depends(get_db),
    # Anything declared here that is NOT in the path becomes a query string
    # parameter: /api/products?category_id=1&search=lap
    category_id: int | None = Query(default=None, description="Filter by category"),
    search: str | None = Query(default=None, description="Case-insensitive name match"),
):
    stmt = select(models.Product).order_by(models.Product.id)
    if category_id is not None:
        stmt = stmt.where(models.Product.category_id == category_id)
    if search:
        # ilike = case-insensitive LIKE. % is the SQL wildcard.
        stmt = stmt.where(models.Product.name.ilike(f"%{search}%"))
    return db.scalars(stmt).all()


@router.get("/{product_id}", response_model=schemas.ProductRead)
def get_product(product_id: int, db: Session = Depends(get_db)):
    return get_product_or_404(product_id, db)


@router.put("/{product_id}", response_model=schemas.ProductRead)
def update_product(
    product_id: int, payload: schemas.ProductUpdate, db: Session = Depends(get_db)
):
    product = get_product_or_404(product_id, db)
    changes = payload.model_dump(exclude_unset=True)

    if "category_id" in changes:
        assert_category_exists(changes["category_id"], db)

    for field, value in changes.items():
        setattr(product, field, value)
    db.commit()
    db.refresh(product)
    return product


@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_product(product_id: int, db: Session = Depends(get_db)):
    """Deleting a product removes it from every cart it is sitting in.

    WHY the cart rows go: a cart row pointing at a product that no longer
    exists would crash every cart read.

    WHY order history stays: order_items.product_id is nullable with
    ondelete="SET NULL", so the database clears the reference and keeps the
    line. product_name and unit_price were copied at purchase time precisely
    so the invoice is still readable afterwards.

    Postgres ENFORCES this: without that SET NULL the delete fails with a
    ForeignKeyViolation (a 500). SQLite would have allowed it silently, since
    it does not enforce foreign keys by default -- a good reason to develop
    against the same engine you deploy on.
    """
    product = get_product_or_404(product_id, db)

    for item in db.scalars(
        select(models.CartItem).where(models.CartItem.product_id == product_id)
    ).all():
        db.delete(item)

    db.delete(product)
    db.commit()
    return None
