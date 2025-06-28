# server.py

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
import uvicorn
import whisper
from transformers import pipeline
import tempfile
import shutil
import os

# --- Initialisation de l'app ---
app = FastAPI(title="Jarvis Assistant API", version="1.0")

# --- Chargement des modèles ---
print("🔊 Chargement du modèle Whisper (transcription)...")
whisper_model = whisper.load_model("base")

print("🧠 Chargement du pipeline Transformers (analyse de sentiment)...")
nlp_model = pipeline("sentiment-analysis")

# --- Route racine ---
@app.get("/")
async def root():
    return {"message": "Jarvis est en ligne."}

# --- Route de transcription audio ---
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

# --- Route d’analyse de texte ---
@app.post("/analyze")
async def analyze_text(text: str):
    try:
        result = nlp_model(text)
        return {"analysis": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- Exécution directe pour développement ---
if __name__ == "__main__":
    uvicorn.run("server:app", host="0.0.0.0", port=8000, reload=True)
