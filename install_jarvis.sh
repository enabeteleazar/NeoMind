#!/bin/bash

# --- Gestion optionnelle du --no-color ---
NO_COLOR=0
for arg in "$@"; do
    if [ "$arg" = "--no-color" ]; then
        NO_COLOR=1
        break
    fi
done

# --- Détection automatique de la prise en charge des couleurs ---
if [ $NO_COLOR -eq 0 ] && [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors)" -ge 8 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    BLUE=''
    YELLOW=''
    NC=''
fi

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "${spinstr}"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "      \b\b\b\b\b\b"
}

set -e

echo -e "${BLUE}🔧 Vérification et correction de l'état du gestionnaire de paquets...${NC}"
if sudo dpkg --configure -a > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Gestionnaire de paquets opérationnel.${NC}"
else
    echo -e "${RED}❌ Erreur détectée, tentative de correction...${NC}"
    sudo dpkg --configure -a > /dev/null 2>&1 &
    spinner $!
fi

echo -e "${BLUE}🔧 Mise à jour du système...${NC}"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq > /dev/null 2>&1 &
spinner $!
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq > /dev/null 2>&1 &
spinner $!

echo -e "${YELLOW}🐍 Installation de Python et pip...${NC}"
sudo apt-get install -y -qq python3 python3-pip python3-venv > /dev/null 2>&1 &
spinner $!

echo -e "${YELLOW}📦 Installation de curl si nécessaire...${NC}"
if ! command -v curl >/dev/null 2>&1; then
    sudo apt-get install -y -qq curl > /dev/null 2>&1 &
    spinner $!
fi

echo -e "${RED}🐳 Installation de Docker et docker-compose...${NC}"
sudo apt-get install -y -qq docker.io docker-compose > /dev/null 2>&1 &
spinner $!

echo -e "${GREEN}📦 Création de l’environnement virtuel Python...${NC}"
python3 -m venv jarvis-env
source jarvis-env/bin/activate

echo -e "${YELLOW}📦 Installation des bibliothèques Python nécessaires (silencieux + résilient)...${NC}"
pip install --upgrade pip > /dev/null 2>&1 &
spinner $!
pip install --default-timeout=100 --timeout=100 --retries=10 torch transformers openai-whisper fastapi uvicorn > /dev/null 2>&1 &
spinner $!
echo -e "${GREEN}✅ Installation des bibliothèques terminée.${NC}"

echo -e "${RED}🔐 Installation et configuration de SSH...${NC}"
sudo apt-get install -y -qq openssh-server > /dev/null 2>&1
sudo systemctl enable --now ssh > /dev/null 2>&1

echo -e "${GREEN}🔧 Configuration avancée de SSH...${NC}"
{
  echo "Port 2222"
  echo "PermitRootLogin no"
  echo "PasswordAuthentication no"
} | sudo tee -a /etc/ssh/sshd_config > /dev/null
sudo systemctl restart ssh > /dev/null 2>&1

echo -e "${BLUE}📂 Création du fichier Dockerfile...${NC}"
cat <<EOF > Dockerfile
# Image de base Python
FROM python:3.11-slim

# Installation des dépendances
RUN pip install torch transformers openai-whisper fastapi uvicorn

# Copie du code source
COPY . /app

# Définition du répertoire de travail
WORKDIR /app

# Commande de démarrage
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

echo -e "${YELLOW}📂 Création du fichier docker-compose.yml...${NC}"
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  assistant:
    build: .
    container_name: jarvis
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data
    restart: always
EOF

echo -e "${BLUE}📄 Création du fichier server.py...${NC}"

cat > server.py << 'EOF'
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
import uvicorn
import whisper
from transformers import pipeline
import tempfile
import shutil

app = FastAPI(title="Jarvis Assistant API", version="1.1")

print("Chargement du modèle Whisper (transcription)...")
whisper_model = whisper.load_model("base")

print("Chargement du pipeline Transformers (analyse de sentiment)...")
nlp_model = pipeline("sentiment-analysis")

@app.get("/")
async def root():
    return {"message": "Jarvis est en ligne."}

@app.post("/transcribe-audio/")
async def transcribe_audio(file: UploadFile = File(...)):
    try:
        with tempfile.NamedTemporaryFile(delete=False) as tmp_file:
            shutil.copyfileobj(file.file, tmp_file)
            tmp_file_path = tmp_file.name

        result = whisper_model.transcribe(tmp_file_path)
        transcription = result.get("text", "")

        file.file.close()
        import os
        os.remove(tmp_file_path)

        return {"transcription": transcription}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/analyze-text/")
async def analyze_text(text: str):
    try:
        result = nlp_model(text)
        return {"analysis": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

echo -e "${GREEN}✅ server.py créé avec succès.${NC}"

echo -e "${GREEN}✅ Installation terminée !${NC}"

echo -e "${RED}🚀 Lancement automatique de ton assistant...${NC}"
docker-compose up -d > /dev/null 2>&1 &
spinner $!

echo -e "${BLUE}✨ Ton assistant JARVIS tourne maintenant en arrière-plan !${NC}"
echo -e "${BLUE}👉 Accède à http://localhost:8000 ou http://<IP_de_ton_serveur>:8000${NC}"
