#!/bin/bash


# --- Nettoyage écran (clear)
clear

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

## ---  VERIFICATION DPKG
    echo -e "${BLUE}🔧 Vérification de l’état du gestionnaire de paquets...${NC}"
    if sudo dpkg --configure -a > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Gestionnaire de paquets OK.${NC}"
    else
        echo -e "${RED}❌ Problème détecté, tentative de correction...${NC}"
        sudo dpkg --configure -a > /dev/null 2>&1 &
        spinner $!
        echo -e "${GREEN}✅ Correction effectuée.${NC}"
    fi


install_jarvis() {

## ---  FULL UPDATE
    echo -e "${BLUE}🔄 Mise à jour du système...${NC}"
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq > /dev/null 2>&1 &
    spinner $!
    echo -e "${GREEN}✅ apt-get update terminé.${NC}"

    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq > /dev/null 2>&1 &
    spinner $!
    echo -e "${GREEN}✅ apt-get upgrade terminé.${NC}"
    echo -e "${BLUE}🔧 Installation / mise à jour de JARVIS...${NC}"

## ---  INSTALL PYTHON & PIP / DOCKER
    sudo apt-get install -y -qq python3 python3-pip python3-venv curl docker.io docker-compose openssh-server > /dev/null 2>&1 &
    spinner $!
    echo -e "${GREEN}✅ Dépendances installés.${NC}"

## ---  INSTALL CURL
    echo -e "${YELLOW}📦 Vérification de curl...${NC}"
    if ! command -v curl >/dev/null 2>&1; then
        sudo apt-get install -y -qq curl > /dev/null 2>&1 &
        spinner $!
        echo -e "${GREEN}✅ curl installé.${NC}"
    else
        echo -e "${GREEN}✅ curl déjà présent.${NC}"
    fi

## ---  VERIFICATION FULL-INSTALL
    echo -e "\n${BLUE}🔎 Vérification finale de l'installation...${NC}\n"

## ---  INSTALL DOCKER.IO && DOCKER-COMPOSE
    # Vérification de Docker
    if command -v docker >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker est installé.${NC}"
    else
        echo -e "${RED}❌ Docker n'est PAS installé correctement.${NC}"
    fi

    # Vérification de Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker Compose est installé.${NC}"
    else
        echo -e "${RED}❌ Docker Compose n'est PAS installé correctement.${NC}"
    fi

# Vérification du conteneur
if docker ps | grep -q jarvis; then
    echo -e "${GREEN}✅ Le conteneur JARVIS tourne correctement.${NC}"
else
    echo -e "${RED}❌ Le conteneur JARVIS ne tourne PAS.${NC}"
    echo -e "${YELLOW}🔄 Tentative de redémarrage...${NC}"
    docker-compose up -d
fi


    # Création et activation du venv
    echo -e "${GREEN}📦 Création de l’environnement virtuel Python...${NC}"
    python3 -m venv jarvis-env
    source jarvis-env/bin/activate
    echo -e "${GREEN}✅ Environnement virtuel activé.${NC}"

    # Installation des paquets Python
    echo -e "${YELLOW}📦 Installation des bibliothèques Python...${NC}"
    pip install --upgrade pip > /dev/null 2>&1 &
    spinner $!
    echo -e "${GREEN}✅ pip mis à jour.${NC}"

    pip install --default-timeout=100 --timeout=100 --retries=10 torch transformers openai-whisper fastapi uvicorn > /dev/null 2>&1 &
    spinner $!
    echo -e "${GREEN}✅ Bibliothèques Python installées.${NC}"

    # Configuration SSH
    echo -e "${RED}🔐 Installation et configuration de SSH...${NC}"
    sudo apt-get install -y -qq openssh-server > /dev/null 2>&1 &
    spinner $!
    echo -e "${GREEN}✅ SSH installé.${NC}"

    sudo systemctl enable --now ssh > /dev/null 2>&1
    echo -e "${GREEN}✅ SSH activé.${NC}"

    echo -e "${GREEN}🔧 Configuration avancée de SSH...${NC}"
    {
        echo "Port 2222"
        echo "PermitRootLogin no"
        echo "PasswordAuthentication no"
    } | sudo tee -a /etc/ssh/sshd_config > /dev/null
    sudo systemctl restart ssh > /dev/null 2>&1
    echo -e "${GREEN}✅ Configuration SSH appliquée.${NC}"

    # Création Dockerfile
    echo -e "${BLUE}📂 Création du Dockerfile...${NC}"
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
echo -e "${GREEN}✅ Dockerfile créé.${NC}"

    # Création docker-compose.yml
    echo -e "${YELLOW}📂 Création de docker-compose.yml...${NC}"
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
echo -e "${GREEN}✅ docker-compose.yml créé.${NC}"

    # Création server.py
    echo -e "${BLUE}📄 Création de server.py...${NC}"
    cat > server.py << 'EOF'
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
EOF
echo -e "${GREEN}✅ server.py créé.${NC}"

    # Lancement docker-compose
    echo -e "${RED}🚀 Lancement de l’assistant...${NC}"
    docker-compose up -d > /dev/null 2>&1 &
    spinner $!
    echo -e "${GREEN}✅ Docker-compose lancé avec succès.${NC}"

    # Vérification de l'accès à l'API
if curl -s http://localhost:8000 | grep -q "Jarvis"; then
    echo -e "${GREEN}✅ API JARVIS accessible sur http://localhost:8000${NC}"
else
    echo -e "${RED}❌ API JARVIS inaccessible.${NC}"
    echo -e "${YELLOW}🔄 Vérifie les logs avec :${NC} docker logs jarvis"
fi

echo -e "\n${GREEN}🎉 Installation et validation terminées !${NC}\n"

    echo -e "${BLUE}✅ Installation et lancement terminés.${NC}"
    echo -e "${BLUE}✨ Ton assistant JARVIS tourne maintenant en arrière-plan !${NC}"
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
