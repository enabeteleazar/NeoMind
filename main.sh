#!/bin/bash
#build: 20250805

# Chargement des modules
source utils/colors.sh
source utils/spinner.sh
source functions/install.sh
source functions/check.sh

main_menu() {
  clear
  echo -e "${CYAN}"
  echo "╔════════════════════════════════════════╗"
  echo "║        🧠 INSTALLATEUR NEO v1.1.0      ║"
  echo "╚════════════════════════════════════════╝"
  echo -e "${NC}"

  echo -e "1️⃣  Installer NEO"
  echo -e "2️⃣  Vérifier l'installation"
  echo -e "3️⃣  Quitter\n"
  read -rp "👉 Ton choix : " choix

  case "$choix" in
    1) install_neo ;;
    2) verify_neo ;;
    3) echo -e "${YELLOW}👋 À bientôt !${NC}"; exit 0 ;;
    *) echo -e "${RED}❌ Choix invalide.${NC}"; sleep 1; main_menu ;;
  esac
}

# Lancement du menu
main_menu
