# Week 2: Python Fundamentals for FastAPI 🐍

**Goal**: Review Python concepts that are ESSENTIAL for FastAPI development.

**Note**: This is a review, not a complete Python course. I'm focusing only on what you'll actually use in backend development.

---

## Lesson 1: Functions and Parameters

### Why This Matters for FastAPI
Every API endpoint is a function! Understanding functions is crucial.

### Basic Function
```python
def greet(name):
    return f"Hello, {name}!"

result = greet("Alice")
print(result)  # Output: Hello, Alice!
```

### Function with Type Hints (IMPORTANT FOR FASTAPI!)
```python
def greet(name: str) -> str:
    return f"Hello, {name}!"

# name: str  → Parameter 'name' should be a string
# -> str     → Function returns a string
```

**Why type hints?**
- FastAPI uses them for automatic validation
- Better code editor support
- Catches errors early

### Default Parameters
```python
def greet(name: str = "Guest") -> str:
    return f"Hello, {name}!"

print(greet())          # Output: Hello, Guest!
print(greet("Alice"))   # Output: Hello, Alice!
```

**FastAPI Example:**
```python
@app.get("/items")
def get_items(skip: int = 0, limit: int = 10):
    # If user doesn't provide skip, it defaults to 0
    # If user doesn't provide limit, it defaults to 10
    return {"skip": skip, "limit": limit}

# URL: /items        → skip=0, limit=10
# URL: /items?skip=5 → skip=5, limit=10
```

### Multiple Return Values
```python
def get_user_info() -> tuple[str, int]:
    name = "Alice"
    age = 25
    return name, age

user_name, user_age = get_user_info()
print(user_name)  # Alice
print(user_age)   # 25
```

---

## Lesson 2: Type Hints (Critical for FastAPI!)

### Why Type Hints Matter
FastAPI reads your type hints to:
- Validate incoming data automatically
- Generate API documentation
- Provide autocomplete in editors

### Basic Types
```python
# Simple types
name: str = "Alice"
age: int = 25
height: float = 5.6
is_active: bool = True

# Function with type hints
def add_numbers(a: int, b: int) -> int:
    return a + b
```

### Collection Types
```python
from typing import List, Dict, Optional, Union

# List of strings
names: List[str] = ["Alice", "Bob", "Charlie"]

# Dictionary with string keys and int values
scores: Dict[str, int] = {"Alice": 95, "Bob": 87}

# Optional - can be None
middle_name: Optional[str] = None
age: Optional[int] = None

# Union - can be multiple types
user_id: Union[int, str] = "user_123"  # Can be int OR string
```

### FastAPI Examples
```python
from typing import List, Optional
from pydantic import BaseModel

# List of items
@app.get("/users")
def get_users() -> List[dict]:
    return [
        {"id": 1, "name": "Alice"},
        {"id": 2, "name": "Bob"}
    ]

# Optional parameter
@app.get("/users/{user_id}")
def get_user(user_id: int, include_email: Optional[bool] = False):
    # include_email is optional, defaults to False
    pass
```

---

## Lesson 3: Dictionaries (You'll Use These EVERYWHERE!)

### Why Dictionaries Matter
- JSON data maps directly to Python dictionaries
- Database results often returned as dictionaries
- Most API responses are dictionaries

### Basic Dictionary Operations
```python
# Create dictionary
user = {
    "id": 1,
    "name": "Alice",
    "email": "alice@example.com"
}

# Access values
print(user["name"])        # Alice
print(user.get("age"))     # None (key doesn't exist)
print(user.get("age", 25)) # 25 (default value)

# Add/Update
user["age"] = 25
user["name"] = "Alice Smith"

# Check if key exists
if "email" in user:
    print("Email exists!")

# Loop through dictionary
for key, value in user.items():
    print(f"{key}: {value}")
```

### Dictionary Unpacking (SUPER USEFUL!)
```python
# This is very common in FastAPI/database work
user_data = {
    "name": "Alice",
    "email": "alice@example.com",
    "age": 25
}

# Instead of this:
# User(name=user_data["name"], email=user_data["email"], age=user_data["age"])

# Do this:
user = User(**user_data)  # Unpacks dictionary into parameters!

# Real FastAPI example:
from pydantic import BaseModel

class User(BaseModel):
    name: str
    email: str
    age: int

user_dict = {"name": "Alice", "email": "alice@example.com", "age": 25}
user = User(**user_dict)  # Creates User object from dictionary
```

### Converting Objects to Dictionaries
```python
from pydantic import BaseModel

class User(BaseModel):
    name: str
    age: int

user = User(name="Alice", age=25)

# Convert to dictionary
user_dict = user.model_dump()
print(user_dict)  # {'name': 'Alice', 'age': 25}
```

---

## Lesson 4: Classes and Objects (OOP Basics)

### Why Classes Matter
- Database models are classes
- Pydantic schemas are classes
- You'll create classes all the time

### Basic Class
```python
class User:
    def __init__(self, name: str, age: int):
        self.name = name
        self.age = age
    
    def greet(self):
        return f"Hi, I'm {self.name}"

# Create instance (object)
user = User("Alice", 25)
print(user.name)      # Alice
print(user.greet())   # Hi, I'm Alice
```

### Understanding `self`
```python
class Counter:
    def __init__(self):
        self.count = 0  # Instance variable
    
    def increment(self):
        self.count += 1  # Access instance variable with self
    
    def get_count(self):
        return self.count

counter = Counter()
counter.increment()
counter.increment()
print(counter.get_count())  # 2
```

**Think of `self` as**: "this specific instance"

### Class with Type Hints
```python
class User:
    def __init__(self, name: str, age: int) -> None:
        self.name: str = name
        self.age: int = age
    
    def get_info(self) -> dict:
        return {
            "name": self.name,
            "age": self.age
        }
```

### Pydantic Classes (FastAPI Uses These!)
```python
from pydantic import BaseModel

class User(BaseModel):
    name: str
    age: int
    email: str

# Pydantic automatically validates!
user = User(name="Alice", age=25, email="alice@example.com")

# This will raise validation error:
# user = User(name="Alice", age="twenty-five", email="alice@example.com")
# Error: age must be an integer!
```

---

## Lesson 5: Decorators (FastAPI Uses These Heavily!)

### What is a Decorator?
A decorator is a function that modifies another function.

### Basic Example
```python
def make_bold(func):
    def wrapper():
        return f"<b>{func()}</b>"
    return wrapper

@make_bold
def say_hello():
    return "Hello!"

print(say_hello())  # Output: <b>Hello!</b>
```

### How FastAPI Uses Decorators
```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")  # ← This is a decorator!
def home():
    return {"message": "Hello"}

# What @app.get("/") does:
# 1. Tells FastAPI: "When someone visits /, call this function"
# 2. Sets HTTP method to GET
# 3. Registers the route
```

### Different HTTP Methods
```python
@app.get("/users")      # GET request
def get_users():
    return []

@app.post("/users")     # POST request
def create_user():
    return {"id": 1}

@app.put("/users/1")    # PUT request
def update_user():
    return {"updated": True}

@app.delete("/users/1") # DELETE request
def delete_user():
    return {"deleted": True}
```

### You Don't Need to Write Decorators
**Important**: You just need to UNDERSTAND them, not create your own.

FastAPI provides all decorators you need:
- `@app.get()`
- `@app.post()`
- `@app.put()`
- `@app.delete()`

---

## Lesson 6: Working with Lists

### Why Lists Matter
- Returning multiple items from API
- Storing multiple database results
- Query parameters can be lists

### Basic List Operations
```python
# Create list
users = ["Alice", "Bob", "Charlie"]

# Access items
print(users[0])     # Alice
print(users[-1])    # Charlie (last item)

# Add items
users.append("David")
users.insert(0, "Eve")  # Insert at beginning

# Remove items
users.remove("Bob")     # Remove by value
deleted = users.pop()   # Remove and return last item

# Loop through list
for user in users:
    print(user)

# List comprehension (VERY COMMON!)
numbers = [1, 2, 3, 4, 5]
squared = [n * n for n in numbers]
print(squared)  # [1, 4, 9, 16, 25]
```

### FastAPI Examples
```python
from typing import List

# Return list of users
@app.get("/users")
def get_users() -> List[dict]:
    return [
        {"id": 1, "name": "Alice"},
        {"id": 2, "name": "Bob"},
        {"id": 3, "name": "Charlie"}
    ]

# Filter list based on query
@app.get("/users/search")
def search_users(name: str):
    all_users = [
        {"id": 1, "name": "Alice"},
        {"id": 2, "name": "Bob"},
        {"id": 3, "name": "Alice Smith"}
    ]
    # List comprehension to filter
    results = [u for u in all_users if name.lower() in u["name"].lower()]
    return results
```

---

## Lesson 7: Exception Handling

### Why This Matters
- Handle errors gracefully
- Return proper error messages
- Don't let your API crash

### Basic Try-Except
```python
try:
    result = 10 / 0
except ZeroDivisionError:
    print("Cannot divide by zero!")
```

### Multiple Exceptions
```python
try:
    user_id = int("abc")  # This will fail
    result = 10 / user_id
except ValueError:
    print("Invalid number format")
except ZeroDivisionError:
    print("Cannot divide by zero")
except Exception as e:
    print(f"Something went wrong: {e}")
```

### Finally Block
```python
try:
    file = open("data.txt")
    # Do something with file
except FileNotFoundError:
    print("File not found")
finally:
    # This ALWAYS runs
    print("Cleanup done")
```

### FastAPI Exception Handling
```python
from fastapi import HTTPException

@app.get("/users/{user_id}")
def get_user(user_id: int):
    # Imagine we check database
    user = None  # User not found
    
    if user is None:
        raise HTTPException(
            status_code=404,
            detail=f"User {user_id} not found"
        )
    
    return user
```

---

## Lesson 8: Working with None and Optional

### Understanding None
```python
# None means "no value"
user = None

if user is None:
    print("No user found")

# Check if value exists
if user:
    print(user.name)
else:
    print("User is None")
```

### Optional Type
```python
from typing import Optional

def get_user(user_id: int) -> Optional[dict]:
    # Might return a user, might return None
    if user_id == 1:
        return {"id": 1, "name": "Alice"}
    return None

user = get_user(1)
if user:
    print(user["name"])
else:
    print("User not found")
```

### FastAPI with Optional
```python
from typing import Optional

@app.get("/users/{user_id}")
def get_user(user_id: int, include_email: Optional[bool] = None):
    user = {"id": user_id, "name": "Alice"}
    
    if include_email:
        user["email"] = "alice@example.com"
    
    return user

# URL: /users/1                    → No email
# URL: /users/1?include_email=true → With email
```

---

## Lesson 9: String Formatting (f-strings)

### Why This Matters
- Creating response messages
- Logging
- Error messages

### Old Way (Don't Use)
```python
name = "Alice"
age = 25
message = "Hello, " + name + "! You are " + str(age) + " years old."
```

### Modern Way (f-strings)
```python
name = "Alice"
age = 25
message = f"Hello, {name}! You are {age} years old."
print(message)  # Hello, Alice! You are 25 years old.
```

### Expressions in f-strings
```python
a = 5
b = 10
print(f"Sum: {a + b}")           # Sum: 15
print(f"Product: {a * b}")       # Product: 50

user = {"name": "Alice", "age": 25}
print(f"User: {user['name']}")   # User: Alice
```

### FastAPI Examples
```python
@app.get("/users/{user_id}")
def get_user(user_id: int):
    return {
        "message": f"Fetching user {user_id}",
        "url": f"/users/{user_id}"
    }

@app.post("/users")
def create_user(name: str):
    return {
        "message": f"User '{name}' created successfully"
    }
```

---

## Lesson 10: async/await (Brief Introduction)

### What is Async?
- Allows handling multiple requests simultaneously
- Makes your API faster
- Not required, but recommended

### Sync vs Async
```python
# Synchronous (regular function)
@app.get("/users")
def get_users():
    return [{"name": "Alice"}]

# Asynchronous (async function)
@app.get("/users")
async def get_users():
    return [{"name": "Alice"}]
```

### When to Use Async
```python
# Use async when doing I/O operations:
# - Database queries
# - API calls
# - File operations

import httpx

@app.get("/external-data")
async def get_external_data():
    async with httpx.AsyncClient() as client:
        response = await client.get("https://api.example.com/data")
        return response.json()
```

### Don't Worry Too Much About Async Yet
- Start with regular functions (sync)
- Add async later when you understand basics
- FastAPI works with both!

---

## 🎯 Week 2 Practice Exercises

### Exercise 1: Functions and Type Hints
Write a function that takes a list of numbers and returns the average:

```python
def calculate_average(numbers: List[float]) -> float:
    # Your code here
    pass

# Test
print(calculate_average([10, 20, 30]))  # Should return 20.0
```

<details>
<summary>Solution</summary>

```python
from typing import List

def calculate_average(numbers: List[float]) -> float:
    if not numbers:
        return 0.0
    return sum(numbers) / len(numbers)

print(calculate_average([10, 20, 30]))  # 20.0
```
</details>

---

### Exercise 2: Dictionaries
Create a function that takes a list of user dictionaries and returns only users older than 18:

```python
def get_adults(users: List[dict]) -> List[dict]:
    # Your code here
    pass

# Test
users = [
    {"name": "Alice", "age": 25},
    {"name": "Bob", "age": 17},
    {"name": "Charlie", "age": 30}
]
print(get_adults(users))  # Should return Alice and Charlie
```

<details>
<summary>Solution</summary>

```python
from typing import List

def get_adults(users: List[dict]) -> List[dict]:
    return [user for user in users if user["age"] > 18]

users = [
    {"name": "Alice", "age": 25},
    {"name": "Bob", "age": 17},
    {"name": "Charlie", "age": 30}
]
print(get_adults(users))
# Output: [{'name': 'Alice', 'age': 25}, {'name': 'Charlie', 'age': 30}]
```
</details>

---

### Exercise 3: Classes
Create a `Product` class with name and price, and a method to apply discount:

```python
class Product:
    # Your code here
    pass

# Test
product = Product("Laptop", 1000)
print(product.apply_discount(10))  # Should return 900 (10% off)
```

<details>
<summary>Solution</summary>

```python
class Product:
    def __init__(self, name: str, price: float):
        self.name = name
        self.price = price
    
    def apply_discount(self, discount_percent: float) -> float:
        discount_amount = self.price * (discount_percent / 100)
        return self.price - discount_amount

product = Product("Laptop", 1000)
print(product.apply_discount(10))  # 900.0
```
</details>

---

### Exercise 4: Exception Handling
Write a function that safely divides two numbers:

```python
def safe_divide(a: float, b: float) -> Optional[float]:
    # Return result if successful, None if division by zero
    pass

# Test
print(safe_divide(10, 2))   # Should return 5.0
print(safe_divide(10, 0))   # Should return None
```

<details>
<summary>Solution</summary>

```python
from typing import Optional

def safe_divide(a: float, b: float) -> Optional[float]:
    try:
        return a / b
    except ZeroDivisionError:
        return None

print(safe_divide(10, 2))   # 5.0
print(safe_divide(10, 0))   # None
```
</details>

---

### Exercise 5: String Formatting and Dictionaries
Create a function that formats user data into a greeting:

```python
def create_greeting(user: dict) -> str:
    # Return: "Hello, {name}! You are {age} years old."
    pass

# Test
user = {"name": "Alice", "age": 25}
print(create_greeting(user))  # "Hello, Alice! You are 25 years old."
```

<details>
<summary>Solution</summary>

```python
def create_greeting(user: dict) -> str:
    return f"Hello, {user['name']}! You are {user['age']} years old."

user = {"name": "Alice", "age": 25}
print(create_greeting(user))
```
</details>

---

## 📚 Additional Resources

### Practice Python
1. **Python Type Hints**: https://docs.python.org/3/library/typing.html
2. **Real Python - Type Checking**: https://realpython.com/python-type-checking/
3. **Python Decorators**: https://realpython.com/primer-on-python-decorators/

### Quick Practice
Try these websites for quick Python practice:
- **Python Tutor**: https://pythontutor.com (Visualize code execution)
- **LeetCode Easy Problems**: Focus on lists, dictionaries

---

## ✅ Week 2 Checklist

Mark these as you complete:

- [ ] I understand type hints (str, int, List, Optional)
- [ ] I can work with dictionaries confidently
- [ ] I understand classes and `self`
- [ ] I know what decorators are (even if I can't write them)
- [ ] I can use f-strings for formatting
- [ ] I understand exception handling with try/except
- [ ] I completed all 5 practice exercises
- [ ] I understand the difference between sync and async (basic)

---

## 🎓 Knowledge Check

Before moving to Week 3, answer these:

1. **What's the difference between `List[str]` and `Optional[str]`?**
2. **What does `self` represent in a class?**
3. **Why do we use type hints in FastAPI?**
4. **What's the output of: `user.get("age", 18)` if "age" key doesn't exist?**
5. **What decorator would you use for a GET request in FastAPI?**

<details>
<summary>Answers</summary>

1. `List[str]` = List of strings, `Optional[str]` = Either string or None
2. `self` = The current instance of the class
3. For automatic validation, documentation, and editor support
4. `18` (the default value)
5. `@app.get()`
</details>

---

## 🚀 What's Next?

**Week 3: Your First FastAPI Application!**

In Week 3, you'll:
- Install FastAPI and create your first API
- Write actual endpoints that work
- See your API documentation at `/docs`
- Build a simple calculator API
- Test everything in your browser

**This is where the fun begins - you'll write real code!**

---

**Ready for Week 3? Just say: "I completed Week 2, ready for Week 3!"**

Or ask me any questions about Week 2 concepts! 😊

---

**Progress**: Week 2 of 14 ⭐⭐
**Next Topic**: Your First FastAPI Application