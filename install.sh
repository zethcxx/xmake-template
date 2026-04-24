#!/usr/bin/env sh
set -e

PROJECT_NAME="${1:-.}"

mkdir -p "$PROJECT_NAME/xmake" "$PROJECT_NAME/app"

echo "[*] Creating project structure: $PROJECT_NAME"

BASE_URL="https://raw.githubusercontent.com/zethcxx/xmake-template/refs/heads/main"
ENTRIES=( "xmake.lua" "xmake/cfg_flags.lua" "xmake/cfg_triple.lua" "app/main.cpp" )

cd "$PROJECT_NAME"

for entry in ${ENTRIES[@]}
do
    echo "[*] Downloading: $entry"
    wget -q "$BASE_URL/$entry" -O "$entry"
done

echo ""
echo "[✔] Environment initialized successfully."
