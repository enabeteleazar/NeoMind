# Makefile pour Jarvis

# Variables
SCRIPT=install_jarvis.sh
ENV_DIR=jarvis-env

.PHONY: help install clean start stop restart logs

help:
	@echo "Usage:"
	@echo "  make install       # Exécute le script d'installation complet"
	@echo "  make clean         # Supprime l'environnement virtuel et les containers Docker"
	@echo "  make start         # Démarre le container Docker Jarvis"
	@echo "  make stop          # Arrête le container Docker Jarvis"
	@echo "  make restart       # Redémarre le container Docker Jarvis"
	@echo "  make logs          # Affiche les logs du container Jarvis"

install:
	@chmod +x $(SCRIPT)
	@./$(SCRIPT)

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
