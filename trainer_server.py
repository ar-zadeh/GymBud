from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn
from typing import List, Dict

app = FastAPI(title="Gym App Custom Trainer Backend")

class ChatRequest(BaseModel):
    message: str
    history: List[Dict[str, str]]
    goals: str

class ChatResponse(BaseModel):
    reply: str

@app.post("/trainer/chat", response_model=ChatResponse)
def handle_chat(request: ChatRequest):
    print(f"--- Received Chat Request ---")
    print(f"Goals: {request.goals}")
    print(f"Message: {request.message}")
    print(f"History: {len(request.history)} past messages")
    
    # TODO: Implement your custom LLM logic here!
    # E.g., pass this to another AI agent, a local model, LangChain, etc.
    
    bot_reply = f"""Hello! I am your custom remote trainer backend.
I received your message: '{request.message}'
Your recorded goals: '{request.goals}'

You can edit this response logic in `trainer_server.py`."""

    return ChatResponse(reply=bot_reply)

if __name__ == "__main__":
    # Runs on port 8000. For Android Emulator, access this via http://10.0.2.2:8000
    uvicorn.run(app, host="0.0.0.0", port=8000)
