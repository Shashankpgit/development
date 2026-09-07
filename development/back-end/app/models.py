"""SQLAlchemy models = the database schema, expressed as Python classes.

Each class becomes one table. Each `Mapped[...]` attribute becomes one column.
Relationships are NOT columns -- they are convenience attributes SQLAlchemy
fills in by running the JOIN for you.
"""

from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def _utcnow() -> datetime:
    """Timezone-aware "now". datetime.utcnow() is deprecated and naive."""
    return datetime.now(timezone.utc)


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(80), unique=True, nullable=False)
    description: Mapped[str | None] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow)

    # back_populates keeps both sides of the link in sync in memory.
    products: Mapped[list["Product"]] = relationship(back_populates="category")


class Product(Base):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str | None] = mapped_column(String(500))
    price: Mapped[float] = mapped_column(Float, nullable=False)
    stock: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    image_url: Mapped[str | None] = mapped_column(String(500))
    # ForeignKey is the DB-level promise that this value exists in categories.id.
    # ondelete is not set, so we enforce "category in use cannot be deleted"
    # in the router instead -- clearer error messages for the API consumer.
    category_id: Mapped[int | None] = mapped_column(ForeignKey("categories.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow)

    category: Mapped["Category | None"] = relationship(back_populates="products")


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    # unique=True creates a UNIQUE INDEX. The database, not the app, is the
    # last line of defence against duplicate emails.
    email: Mapped[str] = mapped_column(String(200), unique=True, nullable=False)
    phone: Mapped[str | None] = mapped_column(String(20))
    address: Mapped[str | None] = mapped_column(String(300))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow)

    cart_items: Mapped[list["CartItem"]] = relationship(
        back_populates="user", cascade="all, delete-orphan"
    )
    orders: Mapped[list["Order"]] = relationship(back_populates="user")


class CartItem(Base):
    """One row per (user, product) pair -- the cart itself is not a table.

    WHY no `carts` table? A cart is just "the set of cart_items for a user".
    Adding a parent row would be extra state to keep consistent for no gain.
    """

    __tablename__ = "cart_items"
    # Adding the same product twice must not create two rows; the router
    # increments the quantity instead. This constraint enforces that even if
    # the router has a bug.
    __table_args__ = (UniqueConstraint("user_id", "product_id", name="uq_cart_user_product"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow)

    user: Mapped["User"] = relationship(back_populates="cart_items")
    product: Mapped["Product"] = relationship()


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)
    # Stored, not computed on read: the total is part of the historical record.
    total_amount: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    shipping_address: Mapped[str | None] = mapped_column(String(300))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow)

    user: Mapped["User"] = relationship(back_populates="orders")
    items: Mapped[list["OrderItem"]] = relationship(
        back_populates="order", cascade="all, delete-orphan"
    )


class OrderItem(Base):
    """A frozen snapshot of what was bought and what it cost at that moment.

    WHY copy name and price instead of just storing product_id? Because prices
    and names change. An invoice that silently rewrites itself when a product
    is renamed is a real-world bug, not a hypothetical one.
    """

    __tablename__ = "order_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"), nullable=False)
    # NULLABLE, with ondelete="SET NULL". If the product is deleted, this
    # reference is cleared but the LINE SURVIVES -- product_name and unit_price
    # below are what make the history readable without it.
    #
    # Postgres refuses to delete a row another table still references. Note
    # SQLite would have allowed it silently (it does not enforce foreign keys
    # by default), so this constraint only shows up on a real database.
    product_id: Mapped[int | None] = mapped_column(
        ForeignKey("products.id", ondelete="SET NULL"), nullable=True
    )
    product_name: Mapped[str] = mapped_column(String(120), nullable=False)
    unit_price: Mapped[float] = mapped_column(Float, nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)

    order: Mapped["Order"] = relationship(back_populates="items")
