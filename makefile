# Makefile pour Jarvis Assistant

# --- Variables
SCRIPT=install_jarvis.sh
ENV_DIR=jarvis-env
DOCKER_COMPOSE_CMD := $(shell command -v docker-compose >/dev/null 2>&1 && echo docker-compose || echo docker compose)

# --- Cibles disponibles
.PHONY: help install install-nc install-core check clean start stop restart logs build test lint

# --- Affiche l'aide
help:
	@echo "🛠️  Commandes disponibles :"
	@echo "  make install         # Exécute le script avec menu interactif"
	@echo "  make install-nc      # Exécute le script sans couleurs (option --no-color)"
	@echo "  make install-core    # Lance uniquement la fonction install_jarvis()"
	@echo "  make check           # Lance uniquement la fonction check_jarvis()"
	@echo "  make clean           # Supprime l’environnement Python et les containers Docker"
	@echo "  make start           # Démarre le conteneur Docker Jarvis"
	@echo "  make stop            # Arrête le conteneur Docker Jarvis"
	@echo "  make restart         # Redémarre le conteneur Docker Jarvis"
	@echo "  make logs            # Affiche les logs du conteneur Jarvis"
	@echo "  make build           # Reconstruit l’image Docker Jarvis"
	@echo "  make test            # Exécute les tests unitaires avec pytest"
	@echo "  make lint            # Analyse le code avec flake8"

# --- Installation interactive avec menu
install:
	@chmod +x $(SCRIPT)
	@bash $(SCRIPT)

# --- Installation sans couleur (prévoir la gestion de --no-color dans ton script)
install-nc:
	@chmod +x $(SCRIPT)
	@bash $(SCRIPT) --no-color

# --- Installation directe sans menu
install-core:
	@chmod +x $(SCRIPT)
	@bash $(SCRIPT) install

# --- Vérification de l’installation sans menu
check:
	@chmod +x $(SCRIPT)
	@bash $(SCRIPT) check

# --- Nettoyage complet
clean:
	@echo "🧹 Suppression de l’environnement virtuel et des containers Docker..."
	@rm -rf $(ENV_DIR)
	@$(DOCKER_COMPOSE_CMD) down --volumes --remove-orphans

# --- Démarrage, arrêt et redémarrage du conteneur
start:
	@echo "🚀 Démarrage du conteneur Jarvis..."
	@$(DOCKER_COMPOSE_CMD) up -d

stop:
	@echo "⏹️  Arrêt du conteneur Jarvis..."
	@$(DOCKER_COMPOSE_CMD) stop

restart: stop start

# --- Logs du conteneur
logs:
	@$(DOCKER_COMPOSE_CMD) logs -f jarvis

# --- Rebuild de l’image Docker
build:
	@echo "🔧 Reconstruction de l’image Docker Jarvis..."
	@$(DOCKER_COMPOSE_CMD) build

# --- Tests unitaires
test:
	@echo "🧪 Lancement des tests avec pytest..."
	@pytest tests/

# --- Linting avec flake8
lint:
	@echo "🔍 Analyse du code avec flake8..."
	@flake8 .
