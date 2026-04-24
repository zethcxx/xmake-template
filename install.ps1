New-Item -ItemType Directory -Force -Path xmake;
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/zethcxx/repo/main/xmake.lua" -OutFile "xmake.lua";
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/zethcxx/repo/main/xmake/cfg_flags.lua" -OutFile "xmake/cfg_flags.lua";
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/zethcxx/repo/main/xmake/cfg_triple.lua" -OutFile "xmake/cfg_triple.lua";
Write-Host "Environment initialized." -ForegroundColor Green
