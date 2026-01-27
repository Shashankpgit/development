# Project Requirements

## Overview
Develop a simple full-stack CRUD application with separate frontend and backend directories, following real-world project structure and best practices.

## Backend Requirements

### Technology Stack
- **Language**: Python (Flask/FastAPI) OR Java (Spring Boot)
- **Database**: PostgreSQL
- **Architecture**: RESTful API

### Features
- Complete CRUD operations for User entity
- User model should include basic fields (id, name, email, created_at, etc.)
- Database connection via environment variables (no hardcoded values)
- Proper error handling and validation
- CORS enabled for frontend communication

### Deliverables
- Separate backend directory
- Environment configuration file template (.env.example)
- Database migration/schema files
- API documentation listing all endpoints with:
  - HTTP methods
  - Request/response formats
  - Example payloads
  - Status codes

## Frontend Requirements

### Technology Stack
- **Framework**: React, Vue, or plain HTML/CSS/JavaScript
- **HTTP Client**: Axios or Fetch API

### Features
- User interface for all CRUD operations:
  - Create new user
  - Read/List all users
  - Update existing user
  - Delete user
- Form validation
- API endpoint configuration via environment variables

### Deliverables
- Separate frontend directory
- Environment configuration file template (.env.example)
- Clean, responsive UI

## Project Structure

```
project-root/
├── backend/
│   ├── .env.example
│   ├── requirements.txt (Python) OR pom.xml (Java)
│   └── ...
├── frontend/
│   ├── .env.example
│   ├── package.json (if using Node-based framework)
│   └── ...
└── README.md
```

## General Requirements
- No hardcoded values (use environment variables for database credentials, API URLs, ports, etc.)
- Frontend and backend communicate exclusively through REST API
- Proper separation of concerns
- Both applications should be runnable independently
- Include setup/installation instructions

## API Documentation Requirements
Document should include:
- Base URL configuration
- Authentication (if applicable)
- All CRUD endpoints:
  - `GET /users` - List all users
  - `GET /users/:id` - Get single user
  - `POST /users` - Create new user
  - `PUT /users/:id` - Update user
  - `DELETE /users/:id` - Delete user
- Request/response examples for each endpoint
- Error response formats