"""Pydantic schemas = the contract of the HTTP API.

Three flavours per resource, and the reason there are three:
  *Create  -- what the client MUST send to create (required fields).
  *Update  -- what the client MAY send to change (everything optional).
  *Read    -- what we send back (includes server-generated id / timestamps).

Never expose a SQLAlchemy model directly: it would leak every column forever,
including ones you later add and did not mean to publish.

NOTE on PUT: strictly, PUT means "replace the whole thing" and PATCH means
"change these fields". We accept partial payloads on PUT because it is far
friendlier for a UI, and we document that choice rather than hide it.
"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field

# from_attributes=True lets Pydantic read values off a SQLAlchemy object
# (obj.name) instead of a dict (obj["name"]).
ORM = ConfigDict(from_attributes=True)


# --------------------------------------------------------------- Category
class CategoryCreate(BaseModel):
    # min_length=1 rejects "" -- an empty name passes a naive `str` check.
    name: str = Field(min_length=1, max_length=80)
    description: str | None = Field(default=None, max_length=255)


class CategoryUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    description: str | None = Field(default=None, max_length=255)


class CategoryRead(BaseModel):
    model_config = ORM
    id: int
    name: str
    description: str | None
    created_at: datetime


# ---------------------------------------------------------------- Product
class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    # gt=0 -> a free or negative-priced product is a data bug, not a discount.
    price: float = Field(gt=0)
    stock: int = Field(default=0, ge=0)
    image_url: str | None = Field(default=None, max_length=500)
    category_id: int | None = None


class ProductUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    price: float | None = Field(default=None, gt=0)
    stock: int | None = Field(default=None, ge=0)
    image_url: str | None = Field(default=None, max_length=500)
    category_id: int | None = None


class ProductRead(BaseModel):
    model_config = ORM
    id: int
    name: str
    description: str | None
    price: float
    stock: int
    image_url: str | None
    category_id: int | None
    created_at: datetime
    # Nested so the UI can show "Laptop -- Electronics" in one request
    # instead of fetching every category separately (the "N+1" problem).
    category: CategoryRead | None = None


# ------------------------------------------------------------------- User
class UserCreate(BaseModel):
    full_name: str = Field(min_length=1, max_length=120)
    # EmailStr is why we installed pydantic[email]: it validates the format
    # so "abc" is rejected at the edge, before it reaches the database.
    email: EmailStr
    phone: str | None = Field(default=None, max_length=20)
    address: str | None = Field(default=None, max_length=300)


class UserUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=1, max_length=120)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, max_length=20)
    address: str | None = Field(default=None, max_length=300)


class UserRead(BaseModel):
    model_config = ORM
    id: int
    full_name: str
    email: EmailStr
    phone: str | None
    address: str | None
    created_at: datetime


# ------------------------------------------------------------------- Cart
class CartItemCreate(BaseModel):
    user_id: int
    product_id: int
    quantity: int = Field(default=1, gt=0)


class CartItemUpdate(BaseModel):
    quantity: int = Field(gt=0)


class CartItemRead(BaseModel):
    model_config = ORM
    id: int
    user_id: int
    product_id: int
    quantity: int
    product: ProductRead | None = None
    # Computed in the router, not stored: derived values must never be able
    # to disagree with the values they are derived from.
    subtotal: float = 0.0


class CartRead(BaseModel):
    user_id: int
    items: list[CartItemRead]
    total_items: int
    total_amount: float


# ------------------------------------------------------------------ Order
class OrderItemRead(BaseModel):
    model_config = ORM
    id: int
    # None once the product has been deleted -- product_name and unit_price
    # still describe what was bought.
    product_id: int | None
    product_name: str
    unit_price: float
    quantity: int


class OrderLineCreate(BaseModel):
    product_id: int
    quantity: int = Field(gt=0)


class OrderCreate(BaseModel):
    user_id: int
    shipping_address: str | None = Field(default=None, max_length=300)
    # Two ways to order:
    #   items omitted -> build the order from whatever is in the user's cart
    #   items given   -> "buy now", straight from a product page
    items: list[OrderLineCreate] | None = None


class OrderUpdate(BaseModel):
    status: str | None = None
    shipping_address: str | None = Field(default=None, max_length=300)


class OrderRead(BaseModel):
    model_config = ORM
    id: int
    user_id: int
    status: str
    total_amount: float
    shipping_address: str | None
    created_at: datetime
    items: list[OrderItemRead] = []
