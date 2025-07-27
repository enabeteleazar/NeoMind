#!/bin/bash

spinner_pid=0

start_spinner() {
  local message="$1"
  echo -ne "$message..."
  spin &
  spinner_pid=$!
  disown
}

stop_spinner() {
  local exit_code=$1
  kill "$spinner_pid" > /dev/null 2>&1
  wait "$spinner_pid" 2>/dev/null
  if [[ $exit_code -eq 0 ]]; then
    echo -e " ✅"
  else
    echo -e " ❌"
  fi
}

spin() {
  local -a spinners=('⠋' '⠙' '⠸' '⠴' '⠦' '⠇')
  while true; do
    for i in "${spinners[@]}"; do
      echo -ne "\r$i"
      sleep 0.1
    done
  done
}