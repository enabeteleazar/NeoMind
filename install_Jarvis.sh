#!/bin/bash

# ==================== CONFIG =====================
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# =============== SPINNER INSTALLATION ============
install_with_spinner() {
    PACKAGE="$1"
    CMD="$2"

    echo -n "📦 Installation de ${PACKAGE} en cours..."

    (
        eval "${CMD}" &> /tmp/${PACKAGE}_install.log
        echo $? > /tmp/${PACKAGE}_status
    ) &

    pid=$!
    spin='-\|/'

    i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r📦 Installation de ${PACKAGE} en cours... ${spin:$i:1}"
        sleep 0.2
    done

    exit_code=$(cat /tmp/${PACKAGE}_status)

    if [ "$exit_code" -eq 0 ]; then
        printf "\r✅ ${PACKAGE} installé avec succès !          \n"
    else
        printf "\r❌ Échec de l’installation de ${PACKAGE}.\n"
        echo "🪵 Consulte /tmp/${PACKAGE}_install.log pour les détails."
        exit 1
    fi
}

# ========== VÉRIFICATION dpkg & PRÉREQUIS ==========
echo -e "\n${BLUE}🔎 Vérification de l'état du gestionnaire de paquets...${NC}"
if sudo dpkg --configure -a --force-confdef --force-confold > /dev/null 2>&1; then
    echo -e "${GREEN}✅ dpkg OK${NC}\n"
else
    echo -e "${RED}❌ Échec de la correction dpkg${NC}"
    exit 1
fi

# ================== MISE À JOUR ====================
echo -e "${BLUE}🔧 Mise à jour du système...${NC}"
sudo apt-get update -y > /dev/null 2>&1 &
spinner_pid=$!
spin='-\|/'
i=0
while kill -0 $spinner_pid 2>/dev/null; do
    i=$(( (i+1) %4 ))
    printf "\r🔄 Mise à jour... ${spin:$i:1}"
    sleep 0.2

done
printf "\r✅ Mise à jour terminée !           \n"
sudo apt-get upgrade -y > /dev/null 2>&1

# ============= PRÉREQUIS PACKAGES ================
echo -e "\n${YELLOW}📦 Installation des paquets système...${NC}"
sudo apt-get install -y python3 python3-pip python3-venv docker.io docker-compose openssh-server curl > /dev/null 2>&1

# ============ CONFIGURATION SSH ===================
echo -e "\n${RED}🔐 Configuration de SSH...${NC}"
sudo systemctl enable --now ssh
sudo sed -i '/^#Port /c\Port 2222' /etc/ssh/sshd_config
sudo sed -i '/^#PermitRootLogin /c\PermitRootLogin no' /etc/ssh/sshd_config
sudo sed -i '/^#PasswordAuthentication /c\PasswordAuthentication no' /etc/ssh/sshd_config
sudo systemctl restart ssh

# ========== ENVIRONNEMENT PYTHON ==================
echo -e "\n${GREEN}🐍 Création de l'environnement virtuel...${NC}"
python3 -m venv jarvis-env
source jarvis-env/bin/activate

# ======== INSTALLATION DÉPENDANCES IA ============
echo -e "\n${YELLOW}📦 Installation des bibliothèques IA...${NC}"
install_with_spinner "pip_upgrade" "pip install --upgrade pip"
install_with_spinner "torch" "pip install torch"
install_with_spinner "transformers" "pip install transformers"
install_with_spinner "fastapi" "pip install fastapi"
install_with_spinner "uvicorn" "pip install uvicorn"
install_with_spinner "whisper" "pip install git+https://github.com/openai/whisper.git"

# =============== DOCKERFILE =======================
echo -e "\n${BLUE}📄 Création du Dockerfile...${NC}"
cat <<EOF > Dockerfile
FROM python:3.11-slim
RUN pip install torch transformers fastapi uvicorn git+https://github.com/openai/whisper.git
COPY . /app
WORKDIR /app
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# =========== DOCKER-COMPOSE =======================
echo -e "\n${BLUE}🧩 Création de docker-compose.yml...${NC}"
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

# ================ LANCEMENT =======================
echo -e "\n${GREEN}🚀 Lancement de l'assistant...${NC}"
docker-compose up -d

# ================== FIN ===========================
echo -e "\n${GREEN}✨ Ton assistant JARVIS tourne maintenant en arrière-plan !${NC}\n"
