#!/usr/bin/env bash
set -e

PROJECT_NAME="${1:-.}"

mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

echo "[*] Creating project structure: $PROJECT_NAME"

BASE_URL="https://raw.githubusercontent.com/zethcxx/xmake-template/main"
ENTRIES=(
    "xmake.lua"

    "xmake/modules/actions.lua"
    "xmake/modules/cfg/flags.lua"
    "xmake/modules/cfg/triple.lua"
    "xmake/modules/payload_header.lua"
    "xmake/modules/utils/strings.lua"

    "xmake/packages/l/lbyte.stx/xmake.lua"

    "xmake/rules/compile_commands.lua"
    "xmake/rules/payload_bin.lua"
    "xmake/rules/payload_extract.lua"

    "app/main.cpp"
)

for entry in "${ENTRIES[@]}"
do
    DIR=$(dirname ${entry})

    if [[ $DIR != "." && ! -d $DIR ]] then
        mkdir -p "$DIR"
    fi

    echo "[*] Downloading: $entry"
    wget -q "$BASE_URL/$entry" -O "$entry"
done

echo ""
echo "[✔] Environment initialized successfully."

