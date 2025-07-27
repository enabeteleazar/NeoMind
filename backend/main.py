from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="NeoMind API", version="1.0")

# Middleware CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tu peux restreindre à des domaines spécifiques
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modèle de requête pour /chat
class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    response: str

@app.get("/")
async def root():
    return {"message": "Bienvenue sur NeoMind API"}

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    user_message = request.message
    print(f"🗣️ Message reçu : {user_message}")

    # Simule une réponse (à remplacer par ton moteur LLM ou API)
    reply = f"Tu as dit : {user_message}"
    
    return {"response": reply}

@app.get("/health")
async def health_check():
    return JSONResponse(content={"status": "ok"}, status_code=200)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
