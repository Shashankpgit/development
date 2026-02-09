# Week 1: Understanding Backend Basics 🌐

**Goal**: Understand what backend development is before writing any code.

---

## Lesson 1: What is Backend Development?

### The Restaurant Analogy 🍽️

Imagine a restaurant:

```
Frontend (What customers see):
├── Menu (User Interface)
├── Waiter (Takes your order)
└── Dining area (Where you sit)

Backend (Kitchen - What customers DON'T see):
├── Chef (Processes requests)
├── Recipe book (Business logic)
├── Pantry (Database)
└── Kitchen staff (Handles operations)
```

**Frontend**: The waiter takes your order (user clicks a button)
**Backend**: The chef prepares your food (server processes the request)
**Database**: The pantry stores ingredients (data storage)

### Real Example

When you use Instagram:

```
1. You click "Like" button (FRONTEND)
   ↓
2. Request sent to Instagram's server (BACKEND)
   ↓
3. Server checks: Are you logged in? (AUTHENTICATION)
   ↓
4. Server saves your like to database (DATABASE)
   ↓
5. Server sends back confirmation (RESPONSE)
   ↓
6. Heart icon turns red (FRONTEND)
```

**You'll be building**: Steps 2, 3, 4, and 5!

---

## Lesson 2: How Does the Internet Work?

### The Client-Server Model

```
YOUR COMPUTER (Client)              BACKEND SERVER
     📱                                  🖥️
      |                                   |
      |  "Hey, show me cat videos"       |
      |---------------------------------->|
      |                                   |
      |  [Processing, checking database] |
      |                                   |
      |  "Here are 10 cat videos"        |
      |<----------------------------------|
      |                                   |
```

**Client**: Your phone, browser, app (asks for data)
**Server**: Computer that stores and sends data (responds)

### Request and Response

Every interaction on the internet is:
1. **REQUEST**: Client asks for something
2. **RESPONSE**: Server sends back data

---

## Lesson 3: What is an API?

### API = Application Programming Interface

Think of it as a **menu at a restaurant**:

```
Restaurant Menu (API):
├── 🍕 Pizza - $10
├── 🍔 Burger - $8
├── 🍟 Fries - $4
└── 🥤 Drink - $3

You can ONLY order what's on the menu!
The kitchen (backend) decides what to offer.
```

### Real API Example

**Twitter API** menu:
```
POST /tweets          → Create a new tweet
GET /tweets           → Get list of tweets
GET /tweets/123       → Get specific tweet
DELETE /tweets/123    → Delete a tweet
PUT /tweets/123       → Edit a tweet
```

### Your Job as Backend Developer

You'll create the "menu" (API) that tells:
- What data can be requested
- What data can be created
- What data can be updated
- What data can be deleted

---

## Lesson 4: HTTP Methods (The Verbs of the Internet)

Think of HTTP methods as **actions** you can perform:

### The Big Four (CRUD Operations)

| HTTP Method | Action | Example | Like... |
|------------|--------|---------|---------|
| **GET** | Read/Retrieve | Get list of users | Reading a book 📖 |
| **POST** | Create | Create new user | Writing a new book ✍️ |
| **PUT** | Update | Update user info | Editing a book 📝 |
| **DELETE** | Delete | Remove user | Throwing book away 🗑️ |

### Real-World Examples

```
YouTube:
GET    /videos           → Browse videos
POST   /videos           → Upload a video
PUT    /videos/123       → Edit video title
DELETE /videos/123       → Delete your video

Online Shopping:
GET    /products         → View products
POST   /cart             → Add item to cart
PUT    /cart/item/5      → Change quantity
DELETE /cart/item/5      → Remove from cart
```

### Important Rules

✅ **GET**: Should NEVER change data (just read)
✅ **POST**: Always creates something new
✅ **PUT**: Updates existing data
✅ **DELETE**: Removes data

❌ Never use GET to delete data
❌ Never use DELETE to create data

---

## Lesson 5: What is REST?

REST = **RE**presentational **S**tate **T**ransfer

It's just a set of **rules** for building APIs.

### REST Rules (Simplified)

1. **Use HTTP methods correctly**
   ```
   ✅ GET /users        → Get users
   ❌ GET /getUsers     → Redundant
   ```

2. **URLs should be nouns, not verbs**
   ```
   ✅ POST /users       → Create user
   ❌ POST /createUser  → Verb in URL (bad)
   ```

3. **Be consistent**
   ```
   ✅ /users, /posts, /comments
   ❌ /users, /getPosts, /comment-list
   ```

4. **Use plural nouns**
   ```
   ✅ /users/123
   ❌ /user/123
   ```

5. **Nested resources make sense**
   ```
   ✅ /users/123/posts     → Get posts by user 123
   ✅ /posts/456/comments  → Get comments on post 456
   ```

### RESTful API Example

```
Good RESTful API for a Blog:

GET    /posts              → Get all posts
GET    /posts/1            → Get post with ID 1
POST   /posts              → Create new post
PUT    /posts/1            → Update post 1
DELETE /posts/1            → Delete post 1

GET    /posts/1/comments   → Get comments on post 1
POST   /posts/1/comments   → Add comment to post 1
```

---

## Lesson 6: Understanding JSON

JSON = **J**ava**S**cript **O**bject **N**otation

It's the **language** that frontend and backend use to talk to each other.

### JSON Looks Like This

```json
{
  "name": "John",
  "age": 25,
  "isStudent": true,
  "hobbies": ["reading", "coding", "gaming"],
  "address": {
    "city": "New York",
    "country": "USA"
  }
}
```

### JSON Data Types

```json
{
  "string": "Hello",
  "number": 42,
  "boolean": true,
  "array": [1, 2, 3],
  "object": {"key": "value"},
  "null": null
}
```

### Real API Request/Response

**Request** (Frontend sends):
```json
POST /users

{
  "name": "Alice",
  "email": "alice@example.com",
  "password": "secret123"
}
```

**Response** (Backend sends back):
```json
{
  "id": 1,
  "name": "Alice",
  "email": "alice@example.com",
  "created_at": "2026-02-05T10:30:00"
}
```

Notice: Password is NOT returned (security!)

---

## Lesson 7: Status Codes (How Server Tells You What Happened)

Status codes are like **emoji reactions** from the server:

### The Common Ones

```
2xx = Success 🎉
├── 200 OK              → Request succeeded
├── 201 Created         → New resource created
└── 204 No Content      → Success, but no data to return

4xx = Client Error 😅 (Your fault)
├── 400 Bad Request     → You sent wrong data
├── 401 Unauthorized    → You need to login
├── 403 Forbidden       → You don't have permission
├── 404 Not Found       → Resource doesn't exist
└── 422 Unprocessable   → Data validation failed

5xx = Server Error 💥 (Server's fault)
├── 500 Internal Error  → Something broke on server
└── 503 Service Unavailable → Server is down
```

### Examples

```
GET /users/999
Response: 404 Not Found
Why: User 999 doesn't exist

POST /users (with invalid email)
Response: 422 Unprocessable Entity
Why: Email format is wrong

GET /users (when not logged in)
Response: 401 Unauthorized
Why: You need to login first

Server crashed:
Response: 500 Internal Server Error
Why: Bug in the code
```

---

## 🎯 Week 1 Practice Exercises

### Exercise 1: Identify the Method
What HTTP method would you use for:

1. Viewing your Instagram feed?
2. Posting a new photo?
3. Editing your bio?
4. Deleting a comment?

<details>
<summary>Click for Answers</summary>

1. GET (reading data)
2. POST (creating data)
3. PUT (updating data)
4. DELETE (removing data)
</details>

---

### Exercise 2: Design an API
Design a RESTful API for a Library system. What endpoints would you create?

<details>
<summary>Click for Answers</summary>

```
GET    /books              → List all books
GET    /books/123          → Get book details
POST   /books              → Add new book
PUT    /books/123          → Update book info
DELETE /books/123          → Remove book

GET    /books/123/reviews  → Get reviews for book
POST   /books/123/reviews  → Add a review

GET    /authors            → List authors
GET    /authors/5/books    → Get books by author 5
```
</details>

---

### Exercise 3: Understand JSON
Convert this information to JSON:
- Name: Sarah
- Age: 28
- Occupation: Developer
- Skills: Python, JavaScript, SQL
- Is employed: Yes

<details>
<summary>Click for Answers</summary>

```json
{
  "name": "Sarah",
  "age": 28,
  "occupation": "Developer",
  "skills": ["Python", "JavaScript", "SQL"],
  "isEmployed": true
}
```
</details>

---

### Exercise 4: Status Codes
What status code should the server return for:

1. User successfully logged in?
2. User tried to access admin page (but isn't admin)?
3. User sent invalid email format?
4. Server database is down?

<details>
<summary>Click for Answers</summary>

1. 200 OK (successful login)
2. 403 Forbidden (no permission)
3. 422 Unprocessable Entity (validation error)
4. 503 Service Unavailable (server issue)
</details>

---

## 📚 Additional Resources

### Videos to Watch
1. "What is an API?" - Simple explanation
   - Search YouTube: "what is api in 5 minutes"

2. "REST API Concepts"
   - Search YouTube: "rest api explained"

### Reading Material
1. MDN Web Docs: HTTP Methods
   - https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods

2. JSON Introduction
   - https://www.json.org/json-en.html

---

## ✅ Week 1 Checklist

Mark these as you complete:

- [ ] I understand what frontend vs backend is
- [ ] I know what client-server model means
- [ ] I can explain what an API is
- [ ] I know the 4 main HTTP methods (GET, POST, PUT, DELETE)
- [ ] I understand REST principles
- [ ] I can read and write basic JSON
- [ ] I know common HTTP status codes
- [ ] I completed all practice exercises

---

## 🎓 Knowledge Check

Before moving to Week 2, you should be able to answer:

1. **What's the difference between frontend and backend?**
2. **What does API stand for and what is it?**
3. **When would you use POST vs PUT?**
4. **What's wrong with this URL: `/createNewUser`?**
5. **What status code means "resource not found"?**

If you can answer these, you're ready for Week 2! 🎉

---

## 📞 Need Help?

Stuck on something? Just ask me:
- "Can you explain JSON again?"
- "I don't understand status codes"
- "What's the difference between PUT and POST?"

**Next**: When you're ready, ask for "Week 2: Python Fundamentals Review"

---

**Progress**: Week 1 of 14 ⭐
**Next Topic**: Python Fundamentals Review