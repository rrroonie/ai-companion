from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

app = FastAPI()


class Item(BaseModel):
    message: str


@app.post("/chat")
async def chat(item: Item):
    # Echo back the incoming message for now
    return {"message": item.message}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8888)