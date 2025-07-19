from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
from fastapi.responses import JSONResponse
import uvicorn
import whisper
from transformers import pipeline
import tempfile
import shutil
import os

app = FastAPI(title="Neo Assistant API", version="1.0")

# Chargement des modèles (à optimiser si besoin)
print("🔊 Chargement du modèle Whisper (transcription)...")
whisper_model = whisper.load_model("base")

print("🧠 Chargement du pipeline Transformers (analyse de sentiment)...")
nlp_model = pipeline("sentiment-analysis")

print("💬 Chargement du modèle de génération de texte...")
chatbot_model = pipeline("text-generation", model="tiiuae/falcon-7b-instruct", tokenizer="tiiuae/falcon-7b-instruct")

class Message(BaseModel):
    message: str

@app.get("/")
async def root():
    return {"message": "Bienvenue dans Neo API"}

@app.post("/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    try:
        with tempfile.NamedTemporaryFile(delete=False) as tmp_file:
            shutil.copyfileobj(file.file, tmp_file)
            tmp_path = tmp_file.name

        result = whisper_model.transcribe(tmp_path)
        transcription = result.get("text", "")

        file.file.close()
        os.remove(tmp_path)

        return {"transcription": transcription}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/analyze")
async def analyze_text(text: str):
    try:
        result = nlp_model(text)
        return {"analysis": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/chat")
async def chat(msg: Message):
    try:
        prompt = msg.message
        output = chatbot_model(prompt, max_new_tokens=100, do_sample=True, temperature=0.7)
        response_text = output[0]["generated_text"]
        return {"response": response_text.strip()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
