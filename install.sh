#!/usr/bin/env sh

mkdir -p xmake
wget -q https://raw.githubusercontent.com/zethcxx/repo/main/xmake.lua -O xmake.lua
wget -q https://raw.githubusercontent.com/zethcxx/repo/main/xmake/cfg_flags.lua -O xmake/cfg_flags.lua
wget -q https://raw.githubusercontent.com/zethcxx/repo/main/xmake/cfg_triple.lua -O xmake/cfg_triple.lua
echo "Environment initialized."
