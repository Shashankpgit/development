from fastapi import FastAPI

app = FastAPI(
    title="My Calculator API",
    description="A simple calculator API built with FastAPI",
    version="1.0.1"
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

@app.get("/modulo")
def modulo(a:int, b:int):
    """Calculate a modulo b"""
    if b == 0:
        return {
            "error": "Cannot perform modulo by zero!"
        }
    return {
        "operation": "modulo",
        "a": a,
        "b": b,
        "result": a % b
    }

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

@app.get("/temperature/{celsius}")
def temperature_conversion(celsius: float):
    """Convert Celsius to Fahrenheit"""
    fahrenheit = (celsius * 9/5) + 32
    return {
        "celsius": celsius,
        "fahrenheit": round(fahrenheit, 2)
    }
