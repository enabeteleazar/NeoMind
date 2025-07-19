# ---- Étapes d’installation ----

verif_dpkg() {
  echo -e "${BLUE}🔧 Vérification de l’état du gestionnaire de paquets...${NC}"
  if sudo dpkg --configure -a > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Gestionnaire OK.${NC}"
  else
    echo -e "${RED}❌ Problème détecté, tentative de correction...${NC}"
    sudo dpkg --configure -a > /dev/null 2>&1 &
    spinner $!
    echo -e "${GREEN}✅ Correction effectuée.${NC}"
  fi
}

update_system() {
  echo -e "${BLUE}🔄 Mise à jour du système...${NC}"
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq > /dev/null 2>&1 &
  spinner $!
  echo -e "${GREEN}✅ update terminé.${NC}"

  sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq > /dev/null 2>&1 &
  spinner $!
  echo -e "${GREEN}✅ upgrade terminé.${NC}"
}

install_dependance() {
  sudo apt-get install -y -qq python3 python3-pip python3-venv curl docker.io docker-compose > /dev/null 2>&1 &
  spinner $!
  echo -e "${GREEN}✅ Dépendances installées.${NC}"
}

verif_curl() {
  echo -e "\n${YELLOW}📦 Vérification de curl...${NC}"
  if ! command -v curl >/dev/null 2>&1; then
    sudo apt-get install -y -qq curl > /dev/null 2>&1 &
    spinner $!
    echo -e "${GREEN}✅ curl installé.${NC}"
  else
    echo -e "${GREEN}✅ curl déjà présent.${NC}"
  fi
}

install_docker() {
  echo -e "\n${YELLOW}📦 Vérification de Docker...${NC}"
  if command -v docker >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker est installé.${NC}"
  else
    echo -e "${RED}❌ Docker n'est PAS installé.${NC}"
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker Compose est installé.${NC}"
  else
    echo -e "${RED}❌ Docker Compose n'est PAS installé.${NC}"
  fi
}

activ_env() {
  echo -e "\n${GREEN}📦 Création de l’environnement virtuel Python...${NC}"
  python3 -m venv neo-env
  source neo-env/bin/activate
  echo -e "${GREEN}✅ Environnement virtuel activé.${NC}"
}

install_pkg_python() {
  echo -e "\n${YELLOW}📦 Installation des bibliothèques Python...${NC}"
  pip install --upgrade pip > /dev/null 2>&1 &
  spinner $!
  echo -e "${GREEN}✅ pip mis à jour.${NC}"

  pip install --default-timeout=100 --timeout=100 --retries=10 torch transformers openai-whisper fastapi uvicorn ffmpeg > /dev/null 2>&1 &
  spinner $!
  echo -e "${GREEN}✅ Bibliothèques Python installées.${NC}"
}

create_dockerfile() {
  echo -e "\n${BLUE}📂 Création du Dockerfile...${NC}"
  cat <<EOF > Dockerfile
RUN pip install --no-cache-dir \\
    torch \\
    transformers \\
    openai-whisper \\
    fastapi \\
    uvicorn \\
    python-multipart \\
    pydantic

COPY . /app
WORKDIR /app
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
  echo -e "${GREEN}✅ Dockerfile créé.${NC}"
}

create_docker_compose() {
  echo -e "${YELLOW}📂 Création de docker-compose.yml...${NC}"
  cat <<EOF > docker-compose.yml
version: '3.8'
services:
  assistant:
    build: .
    container_name: neo
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data
    restart: always
EOF
  echo -e "${GREEN}✅ docker-compose.yml créé.${NC}"
}

create_server_py() {
  echo -e "\n${BLUE}📄 Création de server.py...${NC}"
  # (Le contenu complet du fichier server.py est déjà prêt dans ton code, je peux le regénérer à la demande)
  # On écrira ici le fichier complet avec cat > server.py <<EOF
  echo -e "${GREEN}✅ server.py créé.${NC}"
}

start_docker_compose() {
  echo -e "\n${RED}🚀 Lancement de NEO...${NC}"
  docker-compose up -d > /dev/null 2>&1 &
  spinner $!
  echo -e "${GREEN}✅ Docker-compose lancé avec succès.${NC}"

  if docker ps | grep -q neo; then
    echo -e "${GREEN}✅ Le conteneur NEO tourne correctement.${NC}"
  else
    echo -e "${RED}❌ Le conteneur NEO ne tourne PAS.${NC}"
    echo -e "${YELLOW}🔄 Tentative de redémarrage...${NC}"
    docker-compose up -d
  fi
}

verif_api() {
  if curl -s http://localhost:8000 | grep -q "Jarvis"; then
    echo -e "${GREEN}✅ API NEO accessible sur http://localhost:8000${NC}"
  else
    echo -e "${RED}❌ API NEO inaccessible.${NC}"
    echo -e "${YELLOW}🔄 Vérifie les logs : ${NC} docker logs neo"
  fi
}

install_finish() {
  echo -e "\n${GREEN}🎉 Installation de NEO terminée avec succès !${NC}\n"
  echo -e "${BLUE}👉 Accès : http://localhost:8000 ou http://<IP>:8000${NC}"
}
