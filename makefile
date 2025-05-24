# Makefile pour Jarvis

# Variables
SCRIPT=install_jarvis.sh
ENV_DIR=jarvis-env

.PHONY: help install install-nc clean start stop restart logs test lint

help:
	@echo "Usage:" 
	@echo "  make install        # Exécute le script d'installation avec couleurs"
	@echo "  make install-nc     # Exécute le script d'installation sans couleurs"
	@echo "  make clean          # Supprime l'environnement virtuel et les containers Docker"
	@echo "  make start          # Démarre le container Docker Jarvis"
	@echo "  make stop           # Arrête le container Docker Jarvis"
	@echo "  make restart        # Redémarre le container Docker Jarvis"
	@echo "  make logs           # Affiche les logs du container Jarvis"
	@echo "  make test           # Exécute les tests unitaires avec pytest"
	@echo "  make lint           # Analyse le code avec flake8"

install:
	@chmod +x $(SCRIPT)
	@bash $(SCRIPT)

install-nc:
	@chmod +x $(SCRIPT)
	@bash $(SCRIPT) --no-color

clean:
	@echo "🧹 Suppression de l'environnement virtuel et des containers Docker..."
	@rm -rf $(ENV_DIR)
	@docker-compose down --volumes --remove-orphans

start:
	@echo "🚀 Démarrage du container Jarvis..."
	@docker-compose up -d

stop:
	@echo "⏹️ Arrêt du container Jarvis..."
	@docker-compose stop

restart: stop start

logs:
	@docker logs -f jarvis

test:
	@echo "🧪 Lancement des tests avec pytest..."
	@pytest tests/

lint:
	@echo "🔍 Analyse du code avec flake8..."
	@flake8 .
