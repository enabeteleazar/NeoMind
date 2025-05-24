.PHONY: install run build stop restart clean logs status

# 🔧 Exécute le script d'installation complet
install:
	@echo "🔧 Lancement du script d'installation de Jarvis..."
	bash install_jarvis.sh

# 🚀 Lance Jarvis en arrière-plan via Docker
run:
	@echo "🚀 Démarrage de Jarvis..."
	docker-compose up -d

# 🧱 Rebuild les conteneurs Docker (utile si tu modifies ton code ou Dockerfile)
build:
	@echo "🔄 Reconstruction de l’image Docker..."
	docker-compose build

# 🛑 Stoppe Jarvis
stop:
	@echo "🛑 Arrêt de Jarvis..."
	docker-compose down

# 🔁 Redémarre le conteneur Jarvis
restart:
	@echo "🔁 Redémarrage de Jarvis..."
	docker-compose down && docker-compose up -d

# 🧹 Nettoie tous les conteneurs, images et volumes (⚠️ Destructif)
clean:
	@echo "🧹 Nettoyage complet Docker..."
	docker-compose down -v --rmi all --remove-orphans

# 📜 Affiche les logs de Jarvis en direct
logs:
	@echo "📜 Affichage des logs..."
	docker-compose logs -f

# 📊 Montre l’état des conteneurs Docker
status:
	@echo "📊 État des conteneurs Docker..."
	docker ps -a
