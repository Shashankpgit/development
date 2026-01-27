# Deployment and Local Development Guide

This guide provides step-by-step instructions for running the application locally for development and containerizing it for deployment.

## Prerequisites
- Docker and Docker Compose installed
- Node.js (v18+) and npm installed
- Python (v3.10+) installed
- PostgreSQL (optional, can use internal SQLite for local dev)

---

## 🚀 Option 1: Local Development (Without Docker)

This method is best for rapid development where you want to see changes immediately (`hot-reloading`).

### 1. Backend Setup

Open a terminal and navigate to the `backend` directory:

```bash
cd backend
```

**Step 1.1: Create Virtual Environment**
```bash
python3 -m venv venv
```

**Step 1.2: Activate Virtual Environment**
- On Linux/macOS:
  ```bash
  source venv/bin/activate
  ```
- On Windows:
  ```bash
  .\venv\Scripts\activate
  ```

**Step 1.3: Install Dependencies**
```bash
pip install -r requirements.txt
```

**Step 1.4: Configure Environment**
Copy the example environment file:
```bash
cp .env.example .env
```
*Note: By default, it uses a local SQLite database if `DATABASE_URL` is not set. For production, set the `DATABASE_URL` in `.env`.*

**Step 1.5: Run the Server**
```bash
uvicorn main:app --reload
```
The backend is now running at `http://localhost:8000`.

### 2. Frontend Setup

Open a **new** terminal window and navigate to the `frontend` directory:

```bash
cd frontend
```

**Step 2.1: Install Dependencies**
```bash
npm install
```

**Step 2.2: Configure Environment**
Copy the example environment file:
```bash
cp .env.example .env
```
*Ensure `VITE_API_URL` is set to `http://localhost:8000` inside `.env`.*

**Step 2.3: Run the Development Server**
```bash
npm run dev
```
The frontend is now running at `http://localhost:5173` (or similar).

---

## 🐳 Option 2: Docker Deployment

This method is used to package your application for production or to run the exact production environment locally.

### 1. Build and Run Backend Container

**Step 1.1: Build the Image**
From the `backend` directory:
```bash
cd backend
docker build -t my-app-backend .
```

**Step 1.2: Run the Container**
```bash
docker run -d -p 8000:8000 --name backend-container my-app-backend
```
*To pass a real database URL (e.g., if you have a Postgres container running):*
```bash
docker run -d -p 8000:8000 --name backend-container -e DATABASE_URL="postgresql://user:pass@host:5432/db" my-app-backend
```

### 2. Build and Run Frontend Container

**Step 2.1: Build the Image**
From the `frontend` directory:
```bash
cd frontend
docker build -t my-app-frontend .
```

**Step 2.2: Run the Container**
```bash
docker run -d -p 80:80 --name frontend-container my-app-frontend
```
The frontend will be available at `http://localhost`.

---

## 🛠️ Testing Changes

### Local Dev (Option 1)
- **Backend**: Just save any `.py` file. Uvicorn will auto-reload.
- **Frontend**: Just save any `.jsx` or `.css` file. Vite will hot-reload automatically.

### Docker (Option 2)
If you are running with Docker, you must rebuild the images to see changes:
1. Stop the container: `docker stop <container-name>`
2. Remove the container: `docker rm <container-name>`
3. Rebuild the image: `docker build -t <image-name> .`
4. Run again.

*(For a faster Docker feedback loop, you would typically use Docker Compose with volumes, but the above steps cover the manual build process requested).*
