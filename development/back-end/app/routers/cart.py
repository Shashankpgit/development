"""Cart endpoints.

ROUTE ORDER MATTERS IN THIS FILE. FastAPI matches paths top to bottom, and
"/items" also fits the pattern "/{user_id}". If /{user_id} were declared
first, a request to /api/cart/items would try to parse "items" as an integer
and fail with a confusing 422. Rule of thumb: literal paths before dynamic
ones.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db

router = APIRouter(prefix="/api/cart", tags=["cart"])


def _as_read(item: models.CartItem) -> schemas.CartItemRead:
    """Attach the derived subtotal on the way out."""
    price = item.product.price if item.product else 0.0
    data = schemas.CartItemRead.model_validate(item)
    data.subtotal = round(price * item.quantity, 2)
    return data


# ---- literal paths first -------------------------------------------------
@router.post("/items", response_model=schemas.CartItemRead, status_code=status.HTTP_201_CREATED)
def add_to_cart(payload: schemas.CartItemCreate, db: Session = Depends(get_db)):
    """Adding a product that is already in the cart INCREMENTS it.

    WHY not create a second row? Because a cart showing "Laptop x1" twice is a
    bug users notice immediately. The UNIQUE constraint on the model backs
    this up at the database level.
    """
    if db.get(models.User, payload.user_id) is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"User {payload.user_id} does not exist",
        )

    product = db.get(models.Product, payload.product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Product {payload.product_id} does not exist",
        )

    existing = db.scalar(
        select(models.CartItem).where(
            models.CartItem.user_id == payload.user_id,
            models.CartItem.product_id == payload.product_id,
        )
    )

    wanted = payload.quantity + (existing.quantity if existing else 0)
    if wanted > product.stock:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Only {product.stock} unit(s) of '{product.name}' in stock",
        )

    if existing:
        existing.quantity = wanted
        item = existing
    else:
        item = models.CartItem(**payload.model_dump())
        db.add(item)

    db.commit()
    db.refresh(item)
    return _as_read(item)


@router.put("/items/{item_id}", response_model=schemas.CartItemRead)
def update_cart_item(
    item_id: int, payload: schemas.CartItemUpdate, db: Session = Depends(get_db)
):
    """Set an absolute quantity (not a delta) -- PUT replaces, it does not add."""
    item = db.get(models.CartItem, item_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Cart item {item_id} not found"
        )

    if item.product and payload.quantity > item.product.stock:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Only {item.product.stock} unit(s) of '{item.product.name}' in stock",
        )

    item.quantity = payload.quantity
    db.commit()
    db.refresh(item)
    return _as_read(item)


@router.delete("/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_cart_item(item_id: int, db: Session = Depends(get_db)):
    item = db.get(models.CartItem, item_id)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Cart item {item_id} not found"
        )
    db.delete(item)
    db.commit()
    return None


# ---- dynamic path last ---------------------------------------------------
@router.get("/{user_id}", response_model=schemas.CartRead)
def get_cart(user_id: int, db: Session = Depends(get_db)):
    """An empty cart is a 200 with zero items, NOT a 404.

    WHY: the cart is a property of an existing user, and "you have nothing in
    your cart" is a successful answer. 404 would force the UI to treat a
    normal empty state as an error.
    """
    if db.get(models.User, user_id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"User {user_id} not found"
        )

    rows = db.scalars(
        select(models.CartItem)
        .where(models.CartItem.user_id == user_id)
        .order_by(models.CartItem.id)
    ).all()

    items = [_as_read(row) for row in rows]
    return schemas.CartRead(
        user_id=user_id,
        items=items,
        total_items=sum(i.quantity for i in items),
        total_amount=round(sum(i.subtotal for i in items), 2),
    )
