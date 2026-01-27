# Full-Stack CRUD Application

This is a simple full-stack CRUD application for managing Users. It features a Python FastAPI backend and a React + Vite frontend with a polished, modern UI.

## Project Structure

```
project-root/
├── backend/            # FastAPI Backend
│   ├── .env.example    # Backend environment variables example
│   ├── schema.sql      # Database schema
│   ├── main.py         # Application entry point & API
│   ├── models.py       # SQLAlchemy models
│   ├── schemas.py      # Pydantic schemas
│   ├── database.py     # Database connection
│   └── requirements.txt
├── frontend/           # React + Vite Frontend
│   ├── .env.example    # Frontend environment variables example
│   ├── src/            # Source code
│   └── ...
└── README.md
```

## Setup Instructions

### Backend

1. Navigate to the `backend` directory:
   ```bash
   cd backend
   ```

2. Create a virtual environment and activate it:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Configure Environment:
   - Copy `.env.example` to `.env`:
     ```bash
     cp .env.example .env
     ```
   - Update `DATABASE_URL` in `.env` if using a real PostgreSQL database.
   - If `DATABASE_URL` is not set or invalid, the app will fallback to a local SQLite database (`test.db`) for development convenience.

5. Run the server:
   ```bash
   uvicorn main:app --reload
   ```
   The API will be available at `http://localhost:8000`.
   API Documentation (Swagger UI) is available at `http://localhost:8000/docs`.

### Frontend

1. Navigate to the `frontend` directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Configure Environment:
   - Copy `.env.example` to `.env`:
     ```bash
     cp .env.example .env
     ```
   - Ensure `VITE_API_URL` points to your backend (default: `http://localhost:8000`).

4. Run the development server:
   ```bash
   npm run dev
   ```
   The application will be available at `http://localhost:5173`.

## API Documentation

### Base URL
`http://localhost:8000`

### Endpoints

#### List All Users
- **URL**: `/users`
- **Method**: `GET`
- **Response**: `200 OK`
  ```json
  [
    {
      "name": "John Doe",
      "email": "john@example.com",
      "id": 1,
      "created_at": "2023-01-01T12:00:00Z"
    }
  ]
  ```

#### Get Single User
- **URL**: `/users/:id`
- **Method**: `GET`
- **Status Codes**: 
  - `200 OK`
  - `404 Not Found`

#### Create User
- **URL**: `/users`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "name": "Jane Doe",
    "email": "jane@example.com"
  }
  ```
- **Status Codes**:
  - `201 Created`
  - `400 Bad Request` (if email exists)

#### Update User
- **URL**: `/users/:id`
- **Method**: `PUT`
- **Body**:
  ```json
  {
    "name": "Jane Smith",
    "email": "jane.smith@example.com"
  }
  ```
- **Status Codes**:
  - `200 OK`
  - `404 Not Found`

#### Delete User
- **URL**: `/users/:id`
- **Method**: `DELETE`
- **Status Codes**:
  - `204 No Content`
  - `404 Not Found`