from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
from typing import List, Dict, Optional

import litert_lm
import os

app = FastAPI(title="Gym App Custom Trainer Backend")

# ── Optional sentence-transformers for /embed ─────────────────────────────────
try:
    from sentence_transformers import SentenceTransformer as _ST
    _st_model: Optional[_ST] = None          # loaded in startup_event
    _ST_AVAILABLE = True
except ImportError:
    _st_model = None
    _ST_AVAILABLE = False

# Configuration for Gemma-4-E2B via LiteRT-LM
MODEL_PATH = "gemma-4-E2B-it.litertlm" # Ensure this file is downloaded and in the same directory!
engine = None

@app.on_event("startup")
def startup_event():
    global engine, _st_model
    if os.path.exists(MODEL_PATH):
        try:
            print(f"Loading LiteRT-LM engine with model: {MODEL_PATH}")
            engine = litert_lm.Engine(MODEL_PATH, backend=litert_lm.Backend.CPU())
            print("LiteRT-LM model loaded successfully.")
        except Exception as e:
            print(f"Failed to load LiteRT-LM model: {e}")
    else:
        print(f"Warning: {MODEL_PATH} not found. Ensure you download Gemma-4-E2B.")

    if _ST_AVAILABLE:
        try:
            print("Loading sentence-transformers/all-MiniLM-L6-v2 …")
            _st_model = _ST("sentence-transformers/all-MiniLM-L6-v2")
            print("Embedding model loaded successfully.")
        except Exception as e:
            print(f"Failed to load embedding model: {e}")
    else:
        print("sentence-transformers not installed — /embed endpoint will return 503.")

@app.on_event("shutdown")
def shutdown_event():
    global engine
    if engine is not None:
        try:
            # Assuming the engine provides a close method or cleans up automatically
            engine.close()
        except AttributeError:
            pass

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
    
    global engine
    if engine is not None:
        try:
            bot_reply = ""
            sys_prompt = f"You are a personal trainer bot. The user's goals are: {request.goals}"
            
            # Format history for litert_lm if needed, or simply append context 
            messages = [litert_lm.Message.system(sys_prompt)]
            for msg in request.history:
                # Based on role, append to messages
                if msg.get("role") == "user":
                    messages.append(litert_lm.Message.user(msg.get("content", "")))
                elif msg.get("role") == "assistant" or msg.get("role") == "model":
                    text = msg.get("content", "")
                    # LiteRT API may not expose Message.assistant directly in all versions, 
                    # fallback to string prompt if that is the case
            
            # For simplicity, just combining prompt for the current message
            prompt = f"System: {sys_prompt}\nUser: {request.message}"
            
            # Use a short-lived conversation block
            with engine.create_conversation() as conversation:
                response = conversation.send_message(prompt)
                bot_reply = response["content"][0]["text"]
        except Exception as e:
            bot_reply = f"Error generating response via Gemma-4-E2B: {e}"
    else:
        # Fallback if model not downloaded
        bot_reply = f"""Hello! I am your custom remote trainer backend.
I received your message: '{request.message}'
Your recorded goals: '{request.goals}'

[Note: Gemma-4-E2B model not found at {MODEL_PATH}. 
Please download it to power this chat!]"""

    return ChatResponse(reply=bot_reply)

# ── Embedding endpoint ────────────────────────────────────────────────────────

class EmbedRequest(BaseModel):
    text: str

class EmbedResponse(BaseModel):
    embedding: List[float]
    dimensions: int
    model: str

@app.post("/embed", response_model=EmbedResponse)
def embed_text(request: EmbedRequest):
    """
    Returns a 384-dim L2-normalised embedding for the given text using
    sentence-transformers/all-MiniLM-L6-v2.  Because embeddings are
    normalised, cosine similarity equals the dot product.
    """
    if _st_model is None:
        raise HTTPException(
            status_code=503,
            detail="Embedding model not available. Install sentence-transformers and restart."
        )
    embedding = _st_model.encode(request.text, normalize_embeddings=True).tolist()
    return EmbedResponse(
        embedding=embedding,
        dimensions=len(embedding),
        model="sentence-transformers/all-MiniLM-L6-v2"
    )

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
