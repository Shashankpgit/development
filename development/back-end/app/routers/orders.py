"""Order endpoints -- the only place in this app with real business logic.

Creating an order changes THREE things at once:
  1. inserts the order + its line items
  2. decrements product stock
  3. empties the user's cart

Either all three happen or none do. That is what a database transaction is
for, and it is why there is exactly one db.commit() at the end of the
function: everything before it is staged, and any HTTPException raised in
between leaves the database untouched.
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from .. import models, schemas
from ..database import get_db

router = APIRouter(prefix="/api/orders", tags=["orders"])

# A plain set, not a free-text field: "Shipped", "shiped" and "SHIPPED" would
# otherwise all end up in the column and every report downstream would lie.
ALLOWED_STATUSES = {"pending", "paid", "shipped", "delivered", "cancelled"}
# Once an order is finished or cancelled, stock and money have settled.
FINAL_STATUSES = {"delivered", "cancelled"}


def get_order_or_404(order_id: int, db: Session) -> models.Order:
    order = db.get(models.Order, order_id)
    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=f"Order {order_id} not found"
        )
    return order


def _restock(order: models.Order, db: Session) -> None:
    """Give stock back when an order is cancelled."""
    for line in order.items:
        product = db.get(models.Product, line.product_id)
        if product is not None:  # product may have been deleted since
            product.stock += line.quantity


@router.post("", response_model=schemas.OrderRead, status_code=status.HTTP_201_CREATED)
def create_order(payload: schemas.OrderCreate, db: Session = Depends(get_db)):
    user = db.get(models.User, payload.user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"User {payload.user_id} does not exist",
        )

    # Two entry points, one code path below: either the client sent explicit
    # lines ("buy now"), or we read whatever is in the cart ("checkout").
    if payload.items:
        wanted = [(line.product_id, line.quantity) for line in payload.items]
        cart_rows: list[models.CartItem] = []
    else:
        cart_rows = db.scalars(
            select(models.CartItem).where(models.CartItem.user_id == payload.user_id)
        ).all()
        if not cart_rows:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cart is empty -- add items or pass them in the request body",
            )
        wanted = [(row.product_id, row.quantity) for row in cart_rows]

    order = models.Order(
        user_id=payload.user_id,
        # Fall back to the address on the user record so the client does not
        # have to repeat it on every order.
        shipping_address=payload.shipping_address or user.address,
        status="pending",
    )

    total = 0.0
    for product_id, quantity in wanted:
        product = db.get(models.Product, product_id)
        if product is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Product {product_id} does not exist",
            )
        if quantity > product.stock:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Only {product.stock} unit(s) of '{product.name}' in stock",
            )

        product.stock -= quantity
        order.items.append(
            models.OrderItem(
                product_id=product.id,
                # Snapshot: these two values must never change afterwards.
                product_name=product.name,
                unit_price=product.price,
                quantity=quantity,
            )
        )
        total += product.price * quantity

    order.total_amount = round(total, 2)
    db.add(order)

    for row in cart_rows:  # checkout empties the cart; "buy now" does not
        db.delete(row)

    db.commit()  # <-- the single moment all of the above becomes real
    db.refresh(order)
    return order


@router.get("", response_model=list[schemas.OrderRead])
def list_orders(
    db: Session = Depends(get_db),
    user_id: int | None = Query(default=None, description="Filter by user"),
    order_status: str | None = Query(
        default=None,
        alias="status",
        description="Filter by status",
    ),
):
    """`alias="status"` lets the URL say ?status=paid while the Python
    parameter is called order_status -- `status` is already taken by the
    imported fastapi.status module in this file."""
    stmt = select(models.Order).order_by(models.Order.id.desc())
    if user_id is not None:
        stmt = stmt.where(models.Order.user_id == user_id)
    if order_status is not None:
        stmt = stmt.where(models.Order.status == order_status)
    return db.scalars(stmt).all()


@router.get("/{order_id}", response_model=schemas.OrderRead)
def get_order(order_id: int, db: Session = Depends(get_db)):
    return get_order_or_404(order_id, db)


@router.put("/{order_id}", response_model=schemas.OrderRead)
def update_order(order_id: int, payload: schemas.OrderUpdate, db: Session = Depends(get_db)):
    """Only the status and the address are editable.

    WHY can't you edit the line items? Because total_amount and stock were
    already derived from them. Allowing edits here would mean re-running all
    of that arithmetic -- in a real system you cancel and re-order instead.
    """
    order = get_order_or_404(order_id, db)
    changes = payload.model_dump(exclude_unset=True)

    if "status" in changes and changes["status"] is not None:
        new_status = changes["status"].lower()
        if new_status not in ALLOWED_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"status must be one of: {', '.join(sorted(ALLOWED_STATUSES))}",
            )
        if order.status in FINAL_STATUSES and new_status != order.status:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Order {order_id} is already '{order.status}' and cannot change",
            )
        if new_status == "cancelled" and order.status != "cancelled":
            _restock(order, db)
        changes["status"] = new_status

    for field, value in changes.items():
        setattr(order, field, value)
    db.commit()
    db.refresh(order)
    return order


@router.delete("/{order_id}", response_model=schemas.OrderRead)
def cancel_order(order_id: int, db: Session = Depends(get_db)):
    """DELETE = cancel (a "soft delete"), and it returns the cancelled order.

    WHY not actually remove the row? Orders are history. A shop that forgets a
    cancelled order cannot answer "why was I refunded?". So DELETE flips the
    status to 'cancelled' and returns stock -- the resource stays readable.

    This is a deliberate, documented deviation from textbook REST, which is
    why this endpoint returns 200 + a body instead of 204 + nothing.
    """
    order = get_order_or_404(order_id, db)

    if order.status == "cancelled":
        return order  # idempotent: cancelling twice is not an error
    if order.status == "delivered":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A delivered order cannot be cancelled",
        )

    _restock(order, db)
    order.status = "cancelled"
    db.commit()
    db.refresh(order)
    return order
