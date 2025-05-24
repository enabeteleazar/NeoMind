# Makefile Jarvis - version avancée

SCRIPT=install_jarvis.sh
ENV_DIR=jarvis-env
CONTAINER_NAME=jarvis
SERVICE_URL=http://localhost:8000
REGISTRY=mydockerhubusername/jarvis

.PHONY: help install update update-deps clean start stop restart rebuild logs test test-unit lint deploy check-ssh

help:
	@echo "Usage :"
	@echo "  make install       # Exécute le script d'installation complet"
	@echo "  make update        # Mise à jour des paquets système"
	@echo "  make update-deps   # Mise à jour des dépendances Python"
	@echo "  make clean         # Nettoyage complet"
	@echo "  make start         # Démarre le container Docker Jarvis"
	@echo "  make stop          # Arrête le container Docker Jarvis"
	@echo "  make restart       # Redémarre le container Docker Jarvis"
	@echo "  make rebuild       # Reconstruit l'image Docker et démarre"
	@echo "  make logs          # Affiche les logs du container"
	@echo "  make test          # Teste la disponibilité de l'API"
	@echo "  make test-unit     # Lance les tests unitaires Python"
	@echo "  make lint          # Analyse le style de code Python"
	@echo "  make deploy        # Pousse l'image Docker sur Docker Hub"
	@echo "  make check-ssh     # Vérifie que SSH est actif"

install:
	@chmod +x $(SCRIPT)
	@./$(SCRIPT)

update:
	@echo "🔄 Mise à jour des paquets système..."
	@sudo apt-get update -qq
	@sudo apt-get upgrade -y -qq
	@echo "✅ Mise à jour terminée."

update-deps:
	@echo "⬆️ Mise à jour des dépendances Python..."
	@source $(ENV_DIR)/bin/activate && pip install --upgrade torch transformers fastapi uvicorn whisper

clean:
	@echo "🧹 Nettoyage complet..."
	@rm -rf $(ENV_DIR)
	@docker-compose down --rmi all --volumes --remove-orphans
	@echo "✅ Nettoyage terminé."

start:
	@echo "🚀 Démarrage du container Jarvis..."
	@docker-compose up -d

stop:
	@echo "⏹️ Arrêt du container Jarvis..."
	@docker-compose stop

restart: stop
	@sleep 2
	@$(MAKE) start

rebuild: stop
	@echo "♻️ Reconstruction de l'image Docker..."
	@docker-compose build --no-cache
	@$(MAKE) start

logs:
	@docker logs -f $(CONTAINER_NAME)

test:
	@echo "🔍 Test de disponibilité du service sur $(SERVICE_URL)..."
	@curl --silent --fail $(SERVICE_URL) && echo "✅ Service disponible." || echo "❌ Service non disponible."

test-unit:
	@echo "🧪 Lancement des tests unitaires Python..."
	@source $(ENV_DIR)/bin/activate && pytest tests || echo "❌ Des tests ont échoué."

lint:
	@echo "🔍 Analyse du style de code avec flake8..."
	@source $(ENV_DIR)/bin/activate && flake8 . || echo "❌ Problèmes de style détectés."

deploy: rebuild
	@echo "🚀 Push de l'image Docker vers $(REGISTRY)..."
	@docker tag jarvis:latest $(REGISTRY):latest
	@docker push $(REGISTRY):latest

check-ssh:
	@echo "🔐 Vérification du service SSH..."
	@systemctl is-active ssh && echo "✅ SSH est actif." || echo "❌ SSH n'est pas actif."
