verif_dpkg() {
  echo -e "${BLUE}🔧 Vérification du gestionnaire de paquets...${NC}"
  sudo dpkg --configure -a > /dev/null 2>&1
  exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}✅ Gestionnaire OK.${NC}"
  else
    echo -e "${RED}❌ Problème détecté, tentative de correction...${NC}"
    start_spinner "🔄 Correction en cours"
    sudo dpkg --configure -a > /dev/null 2>&1
    exit_code=$?
    stop_spinner $exit_code

    if [[ $exit_code -eq 0 ]]; then
      echo -e "${GREEN}✅ Correction effectuée.${NC}"
    else
      echo -e "${RED}❌ La correction a échoué.${NC}"
    fi
  fi
  echo ""
}

update_system() {
  echo -e "${BLUE}🔄 Mise à jour du système...${NC}"

  start_spinner "📦 Mise à jour des paquets (apt update)"
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq > /dev/null 2>&1
  exit_code=$?
  stop_spinner $exit_code

  if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}✅ update terminé.${NC}"
  else
    echo -e "${RED}❌ update échoué.${NC}"
  fi

  start_spinner "⬆️  Mise à niveau des paquets (apt upgrade)"
  sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq > /dev/null 2>&1
  exit_code=$?
  stop_spinner $exit_code

  if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}✅ upgrade terminé.${NC}"
  else
    echo -e "${RED}❌ upgrade échoué.${NC}"
  fi

  echo ""
}

install_dependance() {
  echo -e "${BLUE}📦 Installation des dépendances...${NC}"
  start_spinner "🔧 Installation : python3, pip, venv, curl, docker, docker-compose"
  sudo apt-get install -y -qq python3 python3-pip python3-venv curl docker.io docker-compose > /dev/null 2>&1
  exit_code=$?
  stop_spinner $exit_code

  if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}✅ Dépendances installées.${NC}"
  else
    echo -e "${RED}❌ Échec de l'installation des dépendances.${NC}"
  fi
  echo ""
}

verif_curl() {
  echo -e "\n${YELLOW}📦 Vérification de curl...${NC}"
  if ! command -v curl >/dev/null 2>&1; then
    start_spinner "🔧 Installation de curl"
    sudo apt-get install -y -qq curl > /dev/null 2>&1
    exit_code=$?
    stop_spinner $exit_code

    if [[ $exit_code -eq 0 ]]; then
      echo -e "${GREEN}✅ curl installé.${NC}"
    else
      echo -e "${RED}❌ Échec de l'installation de curl.${NC}"
    fi
  else
    echo -e "${GREEN}✅ curl déjà présent.${NC}"
  fi
  echo ""
}

verif_docker() {
  echo -e "\n${YELLOW}📦 Vérification de Docker...${NC}"
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker n'est PAS installé. Installation en cours...${NC}"
    start_spinner "🔧 Installation de Docker"
    sudo apt-get install -y -qq docker.io > /dev/null 2>&1
    exit_code=$?
    stop_spinner $exit_code

    if [[ $exit_code -eq 0 ]]; then
      echo -e "${GREEN}✅ Docker installé avec succès.${NC}"
    else
      echo -e "${RED}❌ Échec de l'installation de Docker.${NC}"
    fi
  else
    echo -e "${GREEN}✅ Docker est déjà installé.${NC}"
  fi

  echo -e "\n${YELLOW}📦 Vérification de Docker Compose...${NC}"
  if ! command -v docker-compose >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker Compose n'est PAS installé. Installation en cours...${NC}"
    start_spinner "🔧 Installation de Docker Compose"
    sudo apt-get install -y -qq docker-compose > /dev/null 2>&1
    exit_code=$?
    stop_spinner $exit_code

    if [[ $exit_code -eq 0 ]]; then
      echo -e "${GREEN}✅ Docker Compose installé avec succès.${NC}"
    else
      echo -e "${RED}❌ Échec de l'installation de Docker Compose.${NC}"
    fi
  else
    echo -e "${GREEN}✅ Docker Compose est déjà installé.${NC}"
  fi
  echo ""
}
 
activ_env() {
  echo -e "\n${YELLOW}📦 Création et activation de l’environnement virtuel Python...${NC}"

  if [[ ! -d "neo-env" ]]; then
    start_spinner "🔧 Création de l’environnement virtuel"
    python3 -m venv neo-env > /dev/null 2>&1
    exit_code=$?
    stop_spinner $exit_code
    if [[ $exit_code -ne 0 ]]; then
      echo -e "${RED}❌ Échec lors de la création de l'environnement virtuel.${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}✅ Environnement virtuel déjà présent.${NC}"
  fi

  # Activation de l'environnement virtuel
  # S'assurer que le script existe avant sourcing
  if [[ -f "neo-env/bin/activate" ]]; then
    source neo-env/bin/activate
    if [[ -n "$VIRTUAL_ENV" ]]; then
      echo -e "${GREEN}✅ Environnement virtuel activé.${NC}"
    else
      echo -e "${RED}❌ Impossible d’activer l’environnement virtuel.${NC}"
      return 1
    fi
  else
    echo -e "${RED}❌ Script d'activation introuvable : neo-env/bin/activate${NC}"
    return 1
  fi

  echo ""
}

install_pkg_python() {
  echo -e "\n${YELLOW}📦 Installation des bibliothèques Python...${NC}"

  start_spinner "🔄 Mise à jour de pip"
  python3 -m pip install --upgrade pip > /dev/null 2>&1
  exit_code=$?
  stop_spinner $exit_code
  if [[ $exit_code -ne 0 ]]; then
    echo -e "${RED}❌ Échec de la mise à jour de pip.${NC}"
    return 1
  fi
  echo -e "${GREEN}✅ pip mis à jour.${NC}"

  start_spinner "📦 Installation des packages necessaires."  
  mkdir -p ~/tmp
  echo "📦 Installation des dépendances depuis backend/requirements.txt..."
  TMPDIR=~/tmp pip install --default-timeout=100 --timeout=100 --retries=10 -r backend/requirements.txt > /dev/null 2>&1
  exit_code=$?
  stop_spinner $exit_code
  if [[ $exit_code -ne 0 ]]; then
    echo -e "${RED}❌ Échec de l’installation des packages Python.${NC}"
    return 1
  fi
  echo -e "${GREEN}✅ Bibliothèques Python installées avec succès.${NC}"
  echo ""
}

check_files() {
  echo -e "\n${BLUE}🔍 Vérification des fichiers essentiels...${NC}"
  local missing=0
  local files=(
    "backend/Dockerfile"
    "docker-compose.yml"
    "backend/requirements.txt"
    "backend/main.py"
  )

  for file in "${files[@]}"; do
    start_spinner "🔎 Recherche de $file"
    sleep 0.5
    stop_spinner 0

    if [[ ! -f "$file" ]]; then
      echo -e "${RED}❌ Fichier manquant : $file${NC}"
      missing=1
    else
      echo -e "${GREEN}✅ $file trouvé.${NC}"
    fi
  done

  if [[ $missing -eq 1 ]]; then
    echo -e "\n${RED}❌ Un ou plusieurs fichiers essentiels sont manquants.${NC}"
    echo -e "${YELLOW}⚠️ Merci de créer ces fichiers avant de continuer.${NC}"
    exit 1
  fi
  echo ""
}

start_docker_compose() {
  echo -e "\n${CYAN}🚀 Lancement de NEO...${NC}"
  
  # Lancer docker-compose en mode détaché
  docker-compose up -d > /dev/null 2>&1 &
  start_spinner "Démarrage des conteneurs Docker"
  wait $!
  stop_spinner $?
  
  # Pause courte pour laisser docker démarrer les conteneurs
  sleep 5

  # Vérification que le conteneur 'neo' tourne bien
  if docker ps --filter "name=neo" --filter "status=running" | grep -q neo; then
    echo -e "${GREEN}✅ Le conteneur NEO tourne correctement.${NC}"
  else
    echo -e "${RED}❌ Le conteneur NEO ne tourne PAS.${NC}"
    echo -e "${YELLOW}🔄 Tentative de redémarrage...${NC}"
    docker-compose up -d
    
    echo -e "${YELLOW}📋 Logs du conteneur neo :${NC}"
    docker logs neo
  fi
  echo ""
}

verif_api() {
  echo -e "${BLUE}🔍 Vérification de l’API NEO...${NC}"

  # Lance curl en arrière-plan et récupère la réponse
  curl -s http://localhost:8000 > /tmp/neo_api_response.txt 2>/dev/null &
  start_spinner "Test de l'API Neo"
  wait $!
  exit_code=$?
  stop_spinner $exit_code

  if [[ $exit_code -eq 0 ]]; then
    if grep -q "Neo" /tmp/neo_api_response.txt; then
      echo -e "\n${GREEN}🎉 Installation de NEO terminée avec succès !${NC}\n"
      echo -e "${BLUE}👉 Accès : http://localhost:8000${NC}\n"
    else
      echo -e "${RED}❌ API NEO accessible mais réponse inattendue.${NC}"
      echo -e "${YELLOW}🔄 Vérifie les logs : docker logs neo${NC}"
    fi
  else
    echo -e "${RED}❌ API NEO inaccessible.${NC}"
    echo -e "${YELLOW}🔄 Vérifie que le conteneur est bien lancé et les logs : docker logs neo${NC}"
  fi

  rm -f /tmp/neo_api_response.txt
  echo ""
}

install_neo() {
  verif_dpkg
  update_system
  install_dependance
  verif_curl
  verif_docker
  activ_env
  install_pkg_python
  check_files
  start_docker_compose
  verif_api
}