#!/usr/bin/env sh
set -e

PROJECT_NAME="${1:-.}"

mkdir -p "$PROJECT_NAME/xmake/cfg" "$PROJECT_NAME/xmake/rules" "$PROJECT_NAME/app"

echo "[*] Creating project structure: $PROJECT_NAME"

BASE_URL="https://raw.githubusercontent.com/zethcxx/xmake-template/refs/heads/main"
ENTRIES=( "xmake.lua" "xmake/cfg/triple.lua" "xmake/cfg/flags.lua" "xmake/rules/compile_commands.lua" "xmake/actions.lua" "app/main.cpp" )

cd "$PROJECT_NAME"

for entry in ${ENTRIES[@]}
do
    echo "[*] Downloading: $entry"
    wget -q "$BASE_URL/$entry" -O "$entry"
done

echo ""
echo "[✔] Environment initialized successfully."
