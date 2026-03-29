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

# --- MOCK DATABASE ---
mock_profile = {
    "name": "User",
    "goals": "General fitness",
    "age": 25
}

mock_sleep_kb = [
    {"id": "1", "content": "Slept 8 hours, feel great.", "date": "2023-10-01"}
]

# --- MODELS ---
from typing import Optional
import uuid

class ProfileUpdate(BaseModel):
    name: Optional[str] = None
    goals: Optional[str] = None
    age: Optional[int] = None

class SleepEntry(BaseModel):
    content: str
    date: Optional[str] = "today"

# --- PROFILE ENDPOINTS ---
@app.get("/profile")
def get_profile():
    return mock_profile

@app.patch("/profile")
def update_profile(update: ProfileUpdate):
    # Using dict() for broader Pydantic v1/v2 compatibility
    update_data = update.dict(exclude_unset=True) 
    mock_profile.update(update_data)
    return {"status": "success", "profile": mock_profile}

# --- KNOWLEDGE BASE ENDPOINTS ---
@app.get("/kb/sleep")
def get_sleep_kb():
    return mock_sleep_kb

@app.post("/kb/sleep")
def add_sleep_kb(entry: SleepEntry):
    new_entry = {
        "id": str(uuid.uuid4()),
        "content": entry.content,
        "date": entry.date
    }
    mock_sleep_kb.append(new_entry)
    return {"status": "success", "entry": new_entry}

@app.get("/kb/sleep/search")
def search_sleep_kb(q: str):
    results = [entry for entry in mock_sleep_kb if q.lower() in entry["content"].lower()]
    return {"status": "success", "results": results}

if __name__ == "__main__":
    # Runs on port 8000. For Android Emulator, access this via http://10.0.2.2:8000
    uvicorn.run(app, host="0.0.0.0", port=8000)
