#!/bin/bash

# === Couleurs portables avec tput ===
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
NC=$(tput sgr0)

# === Fonction spinner ===
with_spinner() {
  local cmd="$1"
  local msg="$2"
  echo -ne "${YELLOW}${msg}...${NC}"
  bash -c "$cmd" > /dev/null 2>&1 &
  local pid=$!
  local spinner="/|\\-/"
  local i=0
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) %4 ))
    printf "\r${YELLOW}${msg}... ${spinner:$i:1}${NC}"
    sleep 0.1
  done
  wait $pid
  if [ $? -eq 0 ]; then
    echo -e "\r${GREEN}${msg} : OK ✅${NC}"
  else
    echo -e "\r${RED}${msg} : ÉCHEC ❌${NC}"
    exit 1
  fi
}

# === Vérifie sudo ===
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Ce script doit être exécuté en tant que root (sudo).${NC}"
  exit 1
fi

# === Nettoyage des locks ===
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
rm -f /var/cache/apt/archives/lock /var/lib/apt/lists/lock

# === Réparation du gestionnaire de paquets ===
echo -ne "${YELLOW}🧰 Vérification de l'état du gestionnaire de paquets...${NC}"
dpkg --configure -a > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo -e "\r${YELLOW}🧰 Problème détecté. Tentative de réparation avec apt...${NC}"
  apt-get install -f -y > /dev/null 2>&1
  dpkg --configure -a > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "\r${RED}🧰 Impossible de réparer automatiquement dpkg. Corrige manuellement avec :${NC}"
    echo -e "${RED}   sudo dpkg --configure -a${NC}"
    exit 1
  else
    echo -e "\r${GREEN}🧰 dpkg réparé avec succès après tentative ! ✅${NC}"
  fi
else
  echo -e "\r${GREEN}🧰 Gestionnaire de paquets OK ✅${NC}"
fi

# === Mise à jour système ===
with_spinner "apt-get update -y && apt-get upgrade -y" "🔄 Mise à jour du système"

# === curl ===
if ! command -v curl &> /dev/null; then
  with_spinner "apt-get install -y curl" "📥 Installation de curl"
fi

# === Python & pip ===
with_spinner "apt-get install -y python3 python3-pip python3-venv" "🐍 Installation de Python, pip et venv"

# === Docker ===
with_spinner "apt-get install -y docker.io docker-compose" "🐳 Installation de Docker & Compose"

# === SSH ===
with_spinner "apt-get install -y openssh-server" "🔐 Installation de SSH"
with_spinner "systemctl enable --now ssh" "📡 Activation de SSH"

# === Configuration sécurisée SSH ===
echo "Port 2222" >> /etc/ssh/sshd_config
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
systemctl restart ssh

# === Environnement Python ===
echo -e "${YELLOW}📦 Création de l’environnement virtuel Python...${NC}"
python3 -m venv jarvis-env
source jarvis-env/bin/activate
 
# === Dépendances IA ===
echo -e "${YELLOW}📦 Installation des bibliothèques IA...${NC}"
pip install --upgrade pip > /dev/null
pip install torch transformers fastapi uvicorn whisper > /dev/null

# === Dockerfile ===
echo -e "${YELLOW}⚙️ Création du Dockerfile...${NC}"
cat <<EOF > Dockerfile
FROM python:3.11-slim
RUN pip install torch transformers fastapi uvicorn whisper
COPY . /app
WORKDIR /app
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# === docker-compose.yml ===
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

# === Lancement de JARVIS ===
with_spinner "docker-compose up -d" "🚀 Lancement de l’assistant JARVIS"

# === Fin ===
echo -e "\n${GREEN}✨ Ton assistant JARVIS tourne maintenant sur http://localhost:8000 !${NC}\n"
