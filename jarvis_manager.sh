#!/bin/bash

# --- Couleurs ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

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

install_jarvis() {
    echo -e "${BLUE}🔧 Installation / mise à jour de JARVIS...${NC}"

    # Mise à jour système et dépendances de base
    sudo dpkg --configure -a > /dev/null 2>&1 || true
    sudo apt-get update -qq > /dev/null 2>&1 &
    spinner $!
    sudo apt-get upgrade -y -qq > /dev/null 2>&1 &
    spinner $!
    sudo apt-get install -y -qq python3 python3-pip python3-venv curl docker.io docker-compose openssh-server > /dev/null 2>&1 &
    spinner $!

    # Création et activation du venv
    python3 -m venv jarvis-env
    source jarvis-env/bin/activate

    # Installation des paquets Python
    pip install --upgrade pip > /dev/null 2>&1 &
    spinner $!
    pip install torch transformers openai-whisper fastapi uvicorn python-multipart > /dev/null 2>&1 &
    spinner $!

    # Configuration SSH
    sudo systemctl enable --now ssh > /dev/null 2>&1
    sudo bash -c "echo -e 'Port 2222\nPermitRootLogin no\nPasswordAuthentication no' >> /etc/ssh/sshd_config"
    sudo systemctl restart ssh > /dev/null 2>&1

    # Création Dockerfile
    cat <<EOF > Dockerfile
FROM python:3.11-slim
RUN pip install --no-cache-dir \\
    torch \\
    transformers \\
    openai-whisper \\
    fastapi \\
    uvicorn \\
    python-multipart
COPY . /app
WORKDIR /app
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

    # Création docker-compose.yml
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

    # Création server.py
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

    # Lancement docker-compose
    docker-compose up -d --build

    echo -e "${GREEN}✅ Installation et lancement terminés.${NC}"
    echo -e "${BLUE}👉 Accède à http://localhost:8000 ou http://<IP_de_ton_serveur>:8000${NC}"
}

check_jarvis() {
    echo -e "${BLUE}🔍 Vérification de l'environnement JARVIS...${NC}"

    echo -e "\n⚙️  Vérification des outils système..."
    for tool in python3 pip docker docker-compose ffmpeg curl; do
        if command -v $tool >/dev/null 2>&1; then
            echo -e "✅ $tool est installé."
        else
            echo -e "❌ $tool est manquant."
        fi
    done

    echo -e "\n📦 Activation de l’environnement virtuel Python (si disponible)..."
    if [ -f jarvis-env/bin/activate ]; then
        source jarvis-env/bin/activate
        echo -e "✅ Environnement 'jarvis-env' activé."
    else
        echo -e "❌ Environnement 'jarvis-env' non trouvé."
    fi

    echo -e "\n🐍 Vérification des bibliothèques Python..."
    for pkg in torch transformers whisper fastapi uvicorn python-multipart; do
        python -c "import $pkg" >/dev/null 2>&1 && echo -e "✅ Package Python '$pkg' installé." || echo -e "❌ Package Python '$pkg' NON installé."
    done

    echo -e "\n📂 Vérification de la structure du projet..."
    for file in server.py Dockerfile docker-compose.yml; do
        [ -f "$file" ] && echo -e "✅ $file présent." || echo -e "❌ $file manquant."
    done

    echo -e "\n🐳 Vérification du conteneur Docker..."
    if docker ps --filter "name=jarvis" --filter "status=running" | grep jarvis >/dev/null; then
        echo -e "✅ Conteneur 'jarvis' trouvé. Statut : running"
    else
        echo -e "❌ Conteneur 'jarvis' non trouvé ou arrêté."
    fi

    echo -e "\n🎙️ Test du chargement du modèle Whisper..."
    python -c "import whisper; whisper.load_model('base')" >/dev/null 2>&1 && echo -e "✅ Modèle Whisper chargé avec succès." || echo -e "❌ Échec du chargement du modèle Whisper."

    echo -e "\n🌐 Test de l'API JARVIS (http://localhost:8000)..."
    if curl --max-time 5 -s http://localhost:8000 | grep -q 'Jarvis est en ligne'; then
        echo -e "✅ API JARVIS répond bien sur le port 8000."
    else
        echo -e "❌ API JARVIS ne répond pas sur http://localhost:8000 (le conteneur est peut-être arrêté ou crashé)."
    fi

    echo -e "\n🧪 Fin des vérifications."
}

# --- Menu ---
while true; do
    echo -e "\n${YELLOW}==== Menu JARVIS ====${NC}"
    echo "1) Installer / Réinstaller JARVIS"
    echo "2) Vérifier l'installation actuelle"
    echo "3) Quitter"
    read -rp "Choisis une option (1-3) : " choice
    case $choice in
        1) install_jarvis ;;
        2) check_jarvis ;;
        3) echo "Bye !" ; exit 0 ;;
        *) echo -e "${RED}Option invalide.${NC}" ;;
    esac
done
