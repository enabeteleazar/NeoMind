#!/bin/bash

# Détection automatique de la prise en charge des couleurs
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors)" -ge 8 ]; then
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
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "      \b\b\b\b\b\b"
}

clear

echo -e "\n${BLUE}🔧 Vérification et correction de l'état du gestionnaire de paquets...${NC}\n"
if sudo dpkg --configure -a > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Gestionnaire de paquets opérationnel.${NC}"
else
    echo -e "${RED}❌ Erreur détectée, tentative de correction...${NC}"
    sudo dpkg --configure -a > /dev/null 2>&1 &
    spinner $!
fi

echo -e "\n${BLUE}🔧 Mise à jour du système...${NC}\n"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq -o=Dpkg::Progress-Fancy="1" > /dev/null 2>&1 &
spinner $!
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq -o=Dpkg::Progress-Fancy="1" > /dev/null 2>&1 &
spinner $!

echo -e "\n${YELLOW}🐍 Installation de Python et pip...${NC}\n"
sudo apt-get install -y -qq python3 python3-pip python3-venv > /dev/null 2>&1 &
spinner $!

echo -e "\n${YELLOW}📦 Installation de curl si nécessaire...${NC}\n"
if ! command -v curl >/dev/null 2>&1; then
    sudo apt-get install -y -qq curl > /dev/null 2>&1 &
    spinner $!
fi

echo -e "\n${RED}🐳 Installation de Docker...${NC}\n"
sudo apt-get install -y -qq docker.io docker-compose > /dev/null 2>&1 &
spinner $!

echo -e "\n${GREEN}📦 Création de l’environnement virtuel Python...${NC}\n"
python3 -m venv jarvis-env
source jarvis-env/bin/activate

echo -e "\n${YELLOW}📦 Installation des dépendances IA...${NC}\n"
pip install --upgrade pip > /dev/null 2>&1 &
spinner $!
pip install --default-timeout=100 --timeout=100 --retries=10 torch transformers fastapi uvicorn whisper > /dev/null 2>&1 &
spinner $!

echo -e "\n${RED}🔐 Installation et configuration de SSH...${NC}\n"
sudo apt-get install -y -qq openssh-server > /dev/null 2>&1
sudo systemctl enable --now ssh > /dev/null 2>&1

echo -e "\n${GREEN}🔧 Configuration avancée de SSH...${NC}\n"
{
  echo "Port 2222"
  echo "PermitRootLogin no"
  echo "PasswordAuthentication no"
} | sudo tee -a /etc/ssh/sshd_config > /dev/null
sudo systemctl restart ssh > /dev/null 2>&1

echo -e "\n${BLUE}📂 Création du fichier Dockerfile...${NC}\n"
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

echo -e "\n${YELLOW}📂 Création du fichier docker-compose.yml...${NC}\n"
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

echo -e "\n${GREEN}✅ Installation terminée !${NC}\n"

echo -e "\n${RED}🚀 Lancement automatique de ton assistant...${NC}\n"
docker-compose up -d > /dev/null 2>&1 &
spinner $!

echo -e "\n${BLUE}✨ Ton assistant JARVIS tourne maintenant en arrière-plan !${NC}\n"
