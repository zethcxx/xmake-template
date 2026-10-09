#!/usr/bin/env bash
set -e

PROJECT_NAME="${1:-.}"

mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

echo "[*] Creating project structure: $PROJECT_NAME"

BASE_URL="https://raw.githubusercontent.com/zethcxx/xmake-template/main"

ENTRIES=(
    "src/main.cpp"
    "xmake.lua"
    "xmake/modules/actions.lua"
    "xmake/modules/cfg/flags.lua"
    "xmake/modules/cfg/infobox.lua"
    "xmake/modules/cfg/triple.lua"
    "xmake/modules/embed_gen.lua"
    "xmake/modules/embed_hex.lua"
    "xmake/modules/utils/strings.lua"
    "xmake/packages/l/lbyte.stx/xmake.lua"
    "xmake/rules/bundle.lua"
    "xmake/rules/compile_commands.lua"
    "xmake/rules/embed_cxx.lua"
    "xmake/rules/headerunit_dirs.lua"
    "xmake/rules/payload_extract.lua"
    "xmake/rules/scanner_norm.lua"
    "xmake/rules/tasks.lua"
)

for ((i=0; i<${#ENTRIES[@]}; i++)); do
    entry="${ENTRIES[$i]}"
    DIR="$(dirname "$entry")"
    if [[ "$DIR" != "." && ! -d "$DIR" ]]; then
        mkdir -p "$DIR"
    fi
    echo "[*] Downloading: $entry"
    if command -v wget >/dev/null 2>&1; then
        wget -q "$BASE_URL/$entry" -O "$entry" || true
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL "$BASE_URL/$entry" -o "$entry" || true
    fi
done

echo ""
echo "[✔] Environment initialized successfully."
