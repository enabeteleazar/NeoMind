#!/bin/bash

# --- Gestion optionnelle des couleurs ---
NO_COLOR=0
for arg in "$@"; do
  if [[ "$arg" == "--no-color" ]]; then
    NO_COLOR=1
    shift
    break
  fi
done

if [[ $NO_COLOR -eq 0 ]] && [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors)" -ge 8 ]; then
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

# --- Spinner amélioré ---
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    while ps -p "$pid" > /dev/null 2>&1; do
        printf " [%c]  " "${spinstr:0:1}"
        spinstr=${spinstr:1}${spinstr:0:1}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "       \b\b\b\b\b\b\b"
}

# --- Fonction pour exécuter une commande avec spinner + vérification ---
run_with_spinner() {
    local cmd=$1
    local msg=$2
    echo -e "${BLUE}${msg}${NC}"
    bash -c "$cmd" > /dev/null 2>&1 &
    local pid=$!
    spinner $pid
    wait $pid
    local status=$?
    if [ $status -ne 0 ]; then
      echo -e "${RED}❌ Échec : $msg${NC}"
      exit $status
    else
      echo -e "${GREEN}✅ Succès : $msg${NC}"
    fi
}

clear

# --- Début du script ---
echo

run_with_spinner "sudo dpkg --configure -a" "🔧 Vérification et correction de l'état du gestionnaire de paquets..."

run_with_spinner "sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq -o=Dpkg::Progress-Fancy=\"1\"" "🔧 Mise à jour du système (apt-get update)..."
run_with_spinner "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq -o=Dpkg::Progress-Fancy=\"1\"" "🔧 Mise à jour du système (apt-get upgrade)..."

run_with_spinner "sudo apt-get install -y -qq python3 python3-pip python3-venv" "🐍 Installation de Python et pip..."

if ! command -v curl >/dev/null 2>&1; then
  run_with_spinner "sudo apt-get install -y -qq curl" "📦 Installation de curl..."
else
  echo -e "${GREEN}✅ curl est déjà installé.${NC}"
fi

run_with_spinner "sudo apt-get install -y -qq docker.io docker-compose" "🐳 Installation de Docker..."

echo -e "${GREEN}📦 Création de l’environnement virtuel Python...${NC}"
python3 -m venv jarvis-env || { echo -e "${RED}❌ Échec création environnement virtuel${NC}"; exit 1; }
source jarvis-env/bin/activate || { echo -e "${RED}❌ Échec activation environnement virtuel${NC}"; exit 1; }

run_with_spinner "pip install --upgrade pip" "📦 Mise à jour de pip..."

run_with_spinner "pip install --default-timeout=100 --timeout=100 --retries=10 torch transformers fastapi uvicorn whisper" "📦 Installation des dépendances IA..."

# SSH Installation/configuration silencieuse
echo -e "${RED}🔐 Installation et configuration de SSH...${NC}"
sudo apt-get install -y -qq openssh-server > /dev/null 2>&1 || { echo -e "${RED}❌ Échec installation SSH${NC}"; exit 1; }
sudo systemctl enable --now ssh > /dev/null 2>&1 || { echo -e "${RED}❌ Échec activation SSH${NC}"; exit 1; }

# Configuration SSH sécurisée (ajoute uniquement si absente)
SSH_CONFIG_LINES=("Port 2222" "PermitRootLogin no" "PasswordAuthentication no")
for line in "${SSH_CONFIG_LINES[@]}"; do
  if ! sudo grep -qF "$line" /etc/ssh/sshd_config; then
    echo "$line" | sudo tee -a /etc/ssh/sshd_config > /dev/null
  fi
done
sudo systemctl restart ssh > /dev/null 2>&1 || { echo -e "${RED}❌ Échec redémarrage SSH${NC}"; exit 1; }

echo -e "${BLUE}📂 Création du fichier Dockerfile...${NC}"
cat <<EOF > Dockerfile
# Image de base Python
FROM python:3.11-slim

# Installation des dépendances
RUN pip install torch transformers fastapi uvicorn whisper

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

echo -e "${GREEN}✅ Installation terminée !${NC}"

run_with_spinner "docker-compose up -d" "🚀 Lancement automatique de ton assistant..."

echo -e "${BLUE}✨ Ton assistant JARVIS tourne maintenant en arrière-plan !${NC}"
echo

