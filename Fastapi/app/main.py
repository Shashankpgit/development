from fastapi import FastAPI
from fastapi.params import Body
from pydantic import BaseModel

app = FastAPI()

class Post(BaseModel):
    title: str
    content: str

@app.get("/msg")
def root():
    return {"message": "Hello, World! this is python FastAPI"}

@app.get("/post")
def get_post():
    return { "this is your post"}


@app.post("/createpost")
def create_post(newpost: Post):
    # print(newpost)
    return {"data": newpost}