verify_neo() {
    echo -e "${BLUE}🔍 Vérification de l'environnement Neo...${NC}"

    echo -e "\n⚙️  Vérification des outils système..."
    for tool in python3 pip docker docker-compose ffmpeg curl; do
        if command -v $tool >/dev/null 2>&1; then
            echo -e "✅ $tool est installé."
        else
            echo -e "❌ $tool est manquant."
        fi
    done

    echo -e "\n📦 Activation de l’environnement virtuel Python (si disponible)..."
    if [ -f Neo-env/bin/activate ]; then
        source Neo-env/bin/activate
        echo -e "✅ Environnement 'Neo-env' activé."
    else
        echo -e "❌ Environnement 'Neo-env' non trouvé."
    fi

    echo -e "\n🐍 Vérification des bibliothèques Python..."
    for pkg in torch transformers whisper fastapi uvicorn python-multipart; do
        python -c "import $pkg" >/dev/null 2>&1 && echo -e "✅ Package Python '$pkg' installé." || echo -e "❌ Package Python '$pkg' NON installé."
    done

    echo -e "\n📂 Vérification de la structure du projet..."
    for file in server.py Dockerfile docker-compose.yml; do
        [ -f "$file" ] && echo -e "✅ $file présent." || echo -e "❌ $file manquant."
    done

    echo -e "\n🐳 Vérification du conteneur Docker..."
    if docker ps --filter "name=Neo" --filter "status=running" | grep Neo >/dev/null; then
        echo -e "✅ Conteneur 'Neo' trouvé. Statut : running"
    else
        echo -e "❌ Conteneur 'Neo' non trouvé ou arrêté."
    fi

    echo -e "\n🎙️ Test du chargement du modèle Whisper..."
    python -c "import whisper; whisper.load_model('base')" >/dev/null 2>&1 && echo -e "✅ Modèle Whisper chargé avec succès." || echo -e "❌ Échec du chargement du modèle Whisper."

    echo -e "\n🌐 Test de l'API Neo (http://localhost:8000)..."
    if curl --max-time 5 -s http://localhost:8000 | grep -q 'Neo est en ligne'; then
        echo -e "✅ API Neo répond bien sur le port 8000."
    else
        echo -e "❌ API Neo ne répond pas sur http://localhost:8000 (le conteneur est peut-être arrêté ou crashé)."
    fi

    echo -e "\n🧪 Fin des vérifications."
}