"""Insert demo data so the UI is not an empty shell on first run.

    python -m app.seed

Idempotent: it bails out if categories already exist, so running it twice
does not create duplicates.
"""

from sqlalchemy import select

from .database import Base, SessionLocal, engine
from .models import Category, Product, User

CATEGORIES = [
    ("Electronics", "Phones, laptops and gadgets"),
    ("Books", "Paperbacks, hardcovers and technical titles"),
    ("Home & Kitchen", "Everything for the house"),
    ("Fitness", "Gear to stay in shape"),
]

# (name, description, price, stock, category index, image)
PRODUCTS = [
    ("Aurora Laptop 14", "14-inch ultrabook, 16GB RAM, 512GB SSD", 1099.00, 12, 0,
     "https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=600&q=80"),
    ("Pulse Wireless Earbuds", "Active noise cancelling, 30h battery", 129.99, 60, 0,
     "https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=600&q=80"),
    ("Nimbus Smart Watch", "Heart rate, GPS, 7-day battery", 199.50, 25, 0,
     "https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=600&q=80"),
    ("Clean Architecture", "A craftsman's guide to software structure", 34.95, 40, 1,
     "https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=600&q=80"),
    ("The Pragmatic Programmer", "From journeyman to master", 41.20, 33, 1,
     "https://images.unsplash.com/photo-1512820790803-83ca734da794?w=600&q=80"),
    ("Ceramic Pour-Over Set", "Dripper, carafe and 50 filters", 48.00, 18, 2,
     "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=600&q=80"),
    ("Cast Iron Skillet 12\"", "Pre-seasoned, oven safe to 260C", 39.99, 22, 2,
     "https://images.unsplash.com/photo-1585515320310-259814833e62?w=600&q=80"),
    ("Adjustable Dumbbell Pair", "2 x 24kg, twist-lock plates", 289.00, 8, 3,
     "https://images.unsplash.com/photo-1584735935682-2f2b69dff9d2?w=600&q=80"),
    ("Cork Yoga Mat", "6mm, natural cork over rubber", 62.00, 30, 3,
     "https://images.unsplash.com/photo-1601925260368-ae2f83cf8b7f?w=600&q=80"),
]

USERS = [
    ("Asha Rao", "asha@example.com", "+91-9800000001", "12 MG Road, Bengaluru 560001"),
    ("Daniel Kim", "daniel@example.com", "+1-415-555-0134", "88 Market St, San Francisco 94103"),
    ("Priya Nair", "priya@example.com", "+91-9800000002", "5 Marine Drive, Kochi 682011"),
]


def main() -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        if db.scalar(select(Category).limit(1)):
            print("Data already present -- nothing to seed.")
            return

        categories = [Category(name=n, description=d) for n, d in CATEGORIES]
        db.add_all(categories)
        db.flush()  # assigns ids without ending the transaction

        db.add_all(
            Product(
                name=name,
                description=desc,
                price=price,
                stock=stock,
                category_id=categories[cat_idx].id,
                image_url=image,
            )
            for name, desc, price, stock, cat_idx, image in PRODUCTS
        )
        db.add_all(
            User(full_name=n, email=e, phone=p, address=a) for n, e, p, a in USERS
        )
        db.commit()
        print(
            f"Seeded {len(CATEGORIES)} categories, {len(PRODUCTS)} products, "
            f"{len(USERS)} users."
        )
    finally:
        db.close()


if __name__ == "__main__":
    main()
