#!/bin/bash

# --- Fonction pour détecter si on doit désactiver les couleurs ---
should_use_color() {
  # 1) Si --no-color est passé dans les arguments, on désactive
  for arg in "$@"; do
    if [[ "$arg" == "--no-color" ]]; then
      return 1
    fi
  done

  # 2) Si variable d'env NO_COLOR est définie, désactive couleur
  if [[ -n "$NO_COLOR" ]]; then
    return 1
  fi

  # 3) Si sortie non interactive, désactive couleur
  if ! test -t 1; then
    return 1
  fi

  # 4) Si terminal basique ou dumb, désactive couleur
  if [[ "$TERM" == "dumb" ]]; then
    return 1
  fi

  # Sinon, on active couleur
  return 0
}

# --- Définition des couleurs selon le test ---
if should_use_color "$@"; then
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

# --- Spinner fonction pour masquer la sortie avec animation ---
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  tput civis  # Cache le curseur
  while kill -0 "$pid" 2>/dev/null; do
    for i in $(seq 0 3); do
      printf "\r%s" "${spinstr:i:1}"
      sleep $delay
    done
  done
  printf "\r"
  tput cnorm  # Restaure le curseur
}

# --- Vérification et correction automatique de dpkg ---
echo -e "\n${BLUE}🔍 Vérification de l’état du gestionnaire de paquets...${NC}"
if sudo dpkg --configure -a >/dev/null 2>&1; then
  echo -e "${GREEN}✔️ Gestionnaire de paquets OK${NC}"
else
  echo -e "${RED}❌ Erreur avec dpkg, tentative de réparation en cours...${NC}"
  sudo dpkg --configure -a
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✔️ Réparation réussie${NC}"
  else
    echo -e "${RED}❌ La réparation automatique a échoué. Merci d’intervenir manuellement.${NC}"
    exit 1
  fi
fi

# --- Mise à jour du système (progression cachée + spinner) ---
echo -e "\n${BLUE}🔧 Mise à jour du système (cela peut prendre un moment)...${NC}"
sudo apt-get update -qq &>/dev/null
sudo apt-get upgrade -y -qq &>/dev/null &
pid=$!
spinner $pid
wait $pid
echo -e "${GREEN}✔️ Système mis à jour${NC}"

# --- Installation de curl si absent (progression cachée + spinner) ---
if ! command -v curl >/dev/null 2>&1; then
  echo -e "\n${YELLOW}⬇️ Installation de curl...${NC}"
  sudo apt-get install -y -qq curl &>/dev/null &
  pid=$!
  spinner $pid
  wait $pid
  echo -e "${GREEN}✔️ curl installé${NC}"
fi

# --- Installation de Python, pip, venv ---
echo -e "\n${YELLOW}🐍 Installation de Python, pip et venv...${NC}"
sudo apt-get install -y -qq python3 python3-pip python3-venv &>/dev/null &
pid=$!
spinner $pid
wait $pid
echo -e "${GREEN}✔️ Python installé${NC}"

# --- Installation de Docker et docker-compose ---
echo -e "\n${RED}🐳 Installation de Docker et docker-compose...${NC}"
sudo apt-get install -y -qq docker.io docker-compose &>/dev/null &
pid=$!
spinner $pid
wait $pid
echo -e "${GREEN}✔️ Docker installé${NC}"

# --- Création de l'environnement virtuel Python ---
echo -e "\n${GREEN}📦 Création de l’environnement virtuel Python...${NC}"
python3 -m venv jarvis-env
source jarvis-env/bin/activate

# --- Installation silencieuse et résiliente des dépendances IA ---
echo -e "\n${YELLOW}📦 Installation des dépendances IA (cela peut prendre un moment)...${NC}"
pip install --upgrade pip --quiet
pip install torch transformers fastapi uvicorn whisper --quiet --retries 5 --timeout 30 &
pid=$!
spinner $pid
wait $pid

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✔️ Dépendances IA installées avec succès${NC}"
else
  echo -e "${RED}❌ Erreur lors de l’installation des dépendances IA. Veuillez vérifier votre connexion.${NC}"
  deactivate
  exit 1
fi

# --- Installation et configuration SSH ---
echo -e "\n${RED}🔐 Installation et configuration SSH...${NC}"
sudo apt-get install -y -qq openssh-server &>/dev/null &
pid=$!
spinner $pid
wait $pid
sudo systemctl enable --now ssh

echo -e "\n${GREEN}🔧 Configuration avancée de SSH...${NC}"
sudo sed -i '/^Port /d' /etc/ssh/sshd_config
sudo sed -i '/^PermitRootLogin /d' /etc/ssh/sshd_config
sudo sed -i '/^PasswordAuthentication /d' /etc/ssh/sshd_config
echo "Port 2222" | sudo tee -a /etc/ssh/sshd_config >/dev/null
echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config >/dev/null
echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config >/dev/null
sudo systemctl restart ssh

# --- Création Dockerfile ---
echo -e "\n${BLUE}📂 Création du fichier Dockerfile...${NC}"
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

# --- Création docker-compose.yml ---
echo -e "\n${YELLOW}📂 Création du fichier docker-compose.yml...${NC}"
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

# --- Lancement de docker-compose ---
echo -e "\n${GREEN}✅ Installation terminée !${NC}"
echo -e "${RED}🚀 Lancement automatique de ton assistant...${NC}"
docker-compose up -d

echo -e "\n${BLUE}✨ Ton assistant JARVIS tourne maintenant en arrière-plan !${NC}\n"

# --- Désactivation de l'environnement virtuel ---
deactivate
