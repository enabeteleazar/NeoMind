#!/bin/bash

# Fonction générique pour exécuter une commande avec un spinner Unicode animé
run_with_spinner() {
    local cmd="$1"
    local msg="${2:-Exécution en cours...}"
    local endmsg="${3:-✅ Terminé}"
    local delay=0.1
    local spinstr=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

    echo -ne "${msg} "

    tput civis  # cache le curseur

    # Lance la commande en arrière-plan
    bash -c "$cmd" > /dev/null 2>&1 &
    local pid=$!

    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\b${spinstr[i]}"
        i=$(((i + 1) % ${#spinstr[@]}))
        sleep $delay
    done

    wait $pid
    local exit_code=$?

    printf "\b%s\n" "$endmsg"
    tput cnorm  # remet le curseur

    return $exit_code
}
