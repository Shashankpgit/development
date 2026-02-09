# Week 3: Your First FastAPI Application 🎉

**Goal**: Build a working API that you can see in your browser!

**What You'll Build**: A simple Calculator API with multiple endpoints

**Time to Complete**: 2-3 hours (take your time!)

---

## Part 1: Setup Your Environment

### Step 1: Create Project Folder

```bash
# Open your terminal/command prompt

# Create a folder for your project
mkdir my-first-api
cd my-first-api
```

### Step 2: Create Virtual Environment

**Why virtual environment?**
- Keeps this project's packages separate from other projects
- Prevents version conflicts
- Industry standard practice

```bash
# Create virtual environment
python -m venv venv

# Activate it
# On Windows:
venv\Scripts\activate

# On Mac/Linux:
source venv/bin/activate

# You should see (venv) in your terminal now
```

### Step 3: Install FastAPI

```bash
# Install FastAPI and Uvicorn (server)
pip install fastapi uvicorn

# This might take a minute...
```

### Step 4: Verify Installation

```bash
# Check if installed correctly
pip list

# You should see:
# fastapi        [version]
# uvicorn        [version]
```

---

## Part 2: Your First Endpoint (Hello World!)

### Create main.py

Create a file called `main.py` in your project folder:

```python
# main.py
from fastapi import FastAPI

# Create FastAPI application
app = FastAPI()

# Your first endpoint!
@app.get("/")
def home():
    return {"message": "Hello, World!"}
```

**Let's understand each line:**

```python
from fastapi import FastAPI
# Import the FastAPI class

app = FastAPI()
# Create an instance of FastAPI
# This 'app' object is your entire API

@app.get("/")
# Decorator that tells FastAPI:
# - HTTP method: GET
# - URL path: /
# - When someone visits /, call the function below

def home():
    return {"message": "Hello, World!"}
# Python dictionary automatically converted to JSON
```

### Run Your API!

```bash
# Make sure you're in the project folder and venv is activated
uvicorn main:app --reload

# You should see:
# INFO:     Uvicorn running on http://127.0.0.1:8000
# INFO:     Application startup complete.
```

**What does this command mean?**
- `uvicorn` - The server that runs your API
- `main` - Your file name (main.py)
- `app` - The variable name in your file
- `--reload` - Auto-restart when you change code

### Test It!

**Option 1: Browser**
- Open: http://127.0.0.1:8000
- You should see: `{"message":"Hello, World!"}`

**Option 2: Interactive Docs**
- Open: http://127.0.0.1:8000/docs
- This is FastAPI's automatic documentation! 🎉
- You can test your API right here!

---

## Part 3: Understanding URL Paths

### Add More Endpoints

Update your `main.py`:

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def home():
    return {"message": "Welcome to Calculator API"}

@app.get("/about")
def about():
    return {
        "name": "Calculator API",
        "version": "1.0",
        "description": "A simple calculator API"
    }

@app.get("/hello")
def hello():
    return {"message": "Hello from /hello endpoint!"}
```

**Test these URLs:**
- http://127.0.0.1:8000/ → Welcome message
- http://127.0.0.1:8000/about → API info
- http://127.0.0.1:8000/hello → Hello message

**Important**: The code auto-reloads! Just refresh your browser.

---

## Part 4: Path Parameters (Dynamic URLs)

### What are Path Parameters?

Instead of creating separate endpoints for each user:
```python
@app.get("/user1")
@app.get("/user2")
@app.get("/user3")
# ... This would be crazy!
```

We use path parameters:
```python
@app.get("/users/{user_id}")
# {user_id} is a placeholder - can be anything!
```

### Example: Greet User by Name

Add to your `main.py`:

```python
@app.get("/greet/{name}")
def greet_user(name: str):
    return {"message": f"Hello, {name}!"}
```

**Test it:**
- http://127.0.0.1:8000/greet/Alice → `{"message":"Hello, Alice!"}`
- http://127.0.0.1:8000/greet/Bob → `{"message":"Hello, Bob!"}`
- http://127.0.0.1:8000/greet/YourName → Try your name!

**How it works:**
1. User visits `/greet/Alice`
2. FastAPI extracts "Alice" from URL
3. Passes it to `greet_user(name="Alice")`
4. Function returns greeting

### Path Parameters with Type Checking

```python
@app.get("/square/{number}")
def square_number(number: int):
    result = number * number
    return {
        "number": number,
        "square": result
    }
```

**Test it:**
- http://127.0.0.1:8000/square/5 → `{"number":5,"square":25}`
- http://127.0.0.1:8000/square/10 → `{"number":10,"square":100}`
- http://127.0.0.1:8000/square/hello → **ERROR!** (not a number)

**FastAPI automatically validates!** If you pass "hello", it returns error because `number: int` expects an integer.

---

## Part 5: Query Parameters

### What are Query Parameters?

Query parameters come after `?` in URL:
```
http://example.com/search?query=fastapi&limit=10
                         ↑
                    Query parameters start here
```

### Example: Calculator with Query Parameters

Add to your `main.py`:

```python
@app.get("/add")
def add_numbers(a: int, b: int):
    result = a + b
    return {
        "operation": "addition",
        "a": a,
        "b": b,
        "result": result
    }
```

**Test it:**
- http://127.0.0.1:8000/add?a=5&b=3 → Result: 8
- http://127.0.0.1:8000/add?a=10&b=20 → Result: 30

**How it works:**
1. `?a=5&b=3` in URL
2. FastAPI extracts: a=5, b=3
3. Calls `add_numbers(a=5, b=3)`
4. Returns result

### Optional Query Parameters

```python
@app.get("/greet-fancy")
def greet_fancy(name: str, title: str = "Mr/Ms"):
    return {"message": f"Hello, {title} {name}!"}
```

**Test it:**
- http://127.0.0.1:8000/greet-fancy?name=Alice
  - Uses default title → `Hello, Mr/Ms Alice!`
- http://127.0.0.1:8000/greet-fancy?name=Alice&title=Dr
  - Uses provided title → `Hello, Dr Alice!`

---

## Part 6: Your Project - Calculator API

### Complete Calculator

Now let's build a full calculator! Replace your `main.py` with:

```python
from fastapi import FastAPI

app = FastAPI(
    title="My Calculator API",
    description="A simple calculator API built with FastAPI",
    version="1.0.0"
)

@app.get("/")
def home():
    return {
        "message": "Welcome to Calculator API",
        "endpoints": {
            "add": "/add?a=5&b=3",
            "subtract": "/subtract?a=10&b=4",
            "multiply": "/multiply?a=6&b=7",
            "divide": "/divide?a=20&b=5",
            "power": "/power?base=2&exponent=3"
        }
    }

@app.get("/add")
def add(a: float, b: float):
    """Add two numbers"""
    return {
        "operation": "addition",
        "a": a,
        "b": b,
        "result": a + b
    }

@app.get("/subtract")
def subtract(a: float, b: float):
    """Subtract b from a"""
    return {
        "operation": "subtraction",
        "a": a,
        "b": b,
        "result": a - b
    }

@app.get("/multiply")
def multiply(a: float, b: float):
    """Multiply two numbers"""
    return {
        "operation": "multiplication",
        "a": a,
        "b": b,
        "result": a * b
    }

@app.get("/divide")
def divide(a: float, b: float):
    """Divide a by b"""
    if b == 0:
        return {
            "error": "Cannot divide by zero!"
        }
    return {
        "operation": "division",
        "a": a,
        "b": b,
        "result": a / b
    }

@app.get("/power")
def power(base: float, exponent: float):
    """Calculate base raised to exponent"""
    return {
        "operation": "power",
        "base": base,
        "exponent": exponent,
        "result": base ** exponent
    }

@app.get("/square/{number}")
def square(number: float):
    """Calculate square of a number"""
    return {
        "number": number,
        "square": number ** 2
    }

@app.get("/cube/{number}")
def cube(number: float):
    """Calculate cube of a number"""
    return {
        "number": number,
        "cube": number ** 3
    }
```

### Test Your Calculator!

Visit http://127.0.0.1:8000/docs and try:

**Addition:**
- http://127.0.0.1:8000/add?a=15&b=25

**Subtraction:**
- http://127.0.0.1:8000/subtract?a=100&b=37

**Multiplication:**
- http://127.0.0.1:8000/multiply?a=12&b=8

**Division:**
- http://127.0.0.1:8000/divide?a=50&b=5
- http://127.0.0.1:8000/divide?a=10&b=0 (Try dividing by zero!)

**Power:**
- http://127.0.0.1:8000/power?base=2&exponent=8

**Square (path parameter):**
- http://127.0.0.1:8000/square/7

**Cube (path parameter):**
- http://127.0.0.1:8000/cube/5

---

## Part 7: Understanding the Auto-Generated Docs

### Visit /docs

Go to: http://127.0.0.1:8000/docs

**What you'll see:**
1. **All your endpoints** listed
2. **Try it out** buttons - test without browser URL
3. **Request/Response examples**
4. **Automatic documentation** from your docstrings!

### How to Use /docs

1. Click on any endpoint (e.g., "GET /add")
2. Click "Try it out"
3. Enter values in the form
4. Click "Execute"
5. See the response!

**This is your API playground!** 🎮

---

## Part 8: Tasks for You

### Task 1: Add a Modulo Endpoint
Create an endpoint that returns the remainder of division.

**Hint:**
```python
@app.get("/modulo")
def modulo(a: int, b: int):
    # Your code here
    pass
```

**Test:** `/modulo?a=17&b=5` should return `{"result": 2}`

<details>
<summary>Solution</summary>

```python
@app.get("/modulo")
def modulo(a: int, b: int):
    """Calculate a modulo b (remainder)"""
    if b == 0:
        return {"error": "Cannot divide by zero!"}
    return {
        "operation": "modulo",
        "a": a,
        "b": b,
        "result": a % b
    }
```
</details>

---

### Task 2: Create a Circle Calculator
Create an endpoint that calculates area and circumference of a circle.

**Requirements:**
- Path parameter: `radius`
- Return both area and circumference
- Use π ≈ 3.14159

**Hint:**
```python
@app.get("/circle/{radius}")
def circle_calculations(radius: float):
    # Your code here
    pass
```

**Test:** `/circle/5` should return area and circumference

<details>
<summary>Solution</summary>

```python
@app.get("/circle/{radius}")
def circle_calculations(radius: float):
    """Calculate circle area and circumference"""
    pi = 3.14159
    area = pi * radius ** 2
    circumference = 2 * pi * radius
    return {
        "radius": radius,
        "area": round(area, 2),
        "circumference": round(circumference, 2)
    }
```
</details>

---

### Task 3: Temperature Converter
Create endpoints to convert between Celsius and Fahrenheit.

**Requirements:**
- `/celsius-to-fahrenheit?celsius=100`
- `/fahrenheit-to-celsius?fahrenheit=212`

**Formulas:**
- F = (C × 9/5) + 32
- C = (F - 32) × 5/9

<details>
<summary>Solution</summary>

```python
@app.get("/celsius-to-fahrenheit")
def celsius_to_fahrenheit(celsius: float):
    """Convert Celsius to Fahrenheit"""
    fahrenheit = (celsius * 9/5) + 32
    return {
        "celsius": celsius,
        "fahrenheit": round(fahrenheit, 2)
    }

@app.get("/fahrenheit-to-celsius")
def fahrenheit_to_celsius(fahrenheit: float):
    """Convert Fahrenheit to Celsius"""
    celsius = (fahrenheit - 32) * 5/9
    return {
        "fahrenheit": fahrenheit,
        "celsius": round(celsius, 2)
    }
```
</details>

---

## Part 9: Common Errors and Solutions

### Error 1: "Module not found"
```
ModuleNotFoundError: No module named 'fastapi'
```
**Solution:** 
```bash
# Make sure virtual environment is activated
# Install FastAPI
pip install fastapi uvicorn
```

---

### Error 2: "Port already in use"
```
ERROR:    [Errno 48] Address already in use
```
**Solution:**
```bash
# Use a different port
uvicorn main:app --reload --port 8001
```

---

### Error 3: "uvicorn: command not found"
```
uvicorn: command not found
```
**Solution:**
```bash
# Make sure venv is activated, then:
pip install uvicorn

# Or run directly with python
python -m uvicorn main:app --reload
```

---

### Error 4: Changes Not Showing
**Solution:**
- Check if `--reload` flag is used
- Save your file (Ctrl+S / Cmd+S)
- Check terminal for error messages
- Try refreshing browser with Ctrl+F5

---

## Part 10: Project Structure (So Far)

```
my-first-api/
├── venv/                    # Virtual environment (don't touch)
└── main.py                  # Your API code
```

**Simple, right?** As projects grow, we'll organize better!

---

## ✅ Week 3 Checklist

Mark these as you complete:

- [ ] Created project folder
- [ ] Set up virtual environment
- [ ] Installed FastAPI and Uvicorn
- [ ] Created first endpoint (Hello World)
- [ ] Ran the server successfully
- [ ] Visited API in browser
- [ ] Explored /docs page
- [ ] Created endpoint with path parameter
- [ ] Created endpoint with query parameters
- [ ] Built complete Calculator API
- [ ] Completed Task 1 (Modulo)
- [ ] Completed Task 2 (Circle Calculator)
- [ ] Completed Task 3 (Temperature Converter)
- [ ] Understand how to test endpoints
- [ ] Know how to read error messages

---

## 🎓 Knowledge Check

Before Week 4, you should know:

1. **What does `@app.get("/users")` do?**
2. **What's the difference between `/users/{id}` and `/users?id=5`?**
3. **How do you run your FastAPI application?**
4. **Where can you test your API without writing code?**
5. **What happens if you pass a string to a parameter expecting int?**

<details>
<summary>Answers</summary>

1. Creates a GET endpoint at the /users path
2. First uses path parameter, second uses query parameter
3. `uvicorn main:app --reload`
4. At http://127.0.0.1:8000/docs (Swagger UI)
5. FastAPI automatically returns a validation error
</details>

---

## 🎉 Congratulations!

You've built your first working API! 

**What you learned:**
- ✅ Setting up FastAPI project
- ✅ Creating endpoints
- ✅ Path parameters vs Query parameters
- ✅ Type validation
- ✅ Testing with /docs
- ✅ Handling errors

---

## 🚀 What's Next in Week 4?

**Week 4: Request Body and Pydantic Models**

You'll learn:
- How to accept POST requests with data
- Creating data models with Pydantic
- Validation of complex data
- Building a Todo API (with data storage)

**Preview:**
```python
from pydantic import BaseModel

class Todo(BaseModel):
    title: str
    completed: bool = False

@app.post("/todos")
def create_todo(todo: Todo):
    # Save todo
    return todo
```

---

## 📞 Check-In Questions

1. Did you successfully run the Calculator API?
2. Were you able to test all endpoints in /docs?
3. Did you complete the 3 tasks?
4. Any errors or confusion?
5. Ready for Week 4?

**When you're ready, say: "I completed Week 3, ready for Week 4!"**

Or ask me any questions! 😊

---

**Progress**: Week 3 of 14 ⭐⭐⭐
**Next Topic**: Request Body & Pydantic Models
**Status**: 🎉 You're a FastAPI developer now!