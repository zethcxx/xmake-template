$ErrorActionPreference = "Stop"

$ProjectName = if ($args[0]) { $args[0] } else { "." }

$BaseUrl = "https://raw.githubusercontent.com/zethcxx/xmake-template/refs/heads/main"

$Entries = @(
    "xmake.lua",
    "xmake/cfg_flags.lua",
    "xmake/cfg_triple.lua",
    "app/main.cpp"
)

Write-Host "[*] Creating project structure: $ProjectName" -ForegroundColor Gray
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectName "xmake") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectName "app") | Out-Null

foreach ($entry in $Entries) {
    $url = "$BaseUrl/$entry"
    $outputPath = Join-Path $ProjectName $entry
    
    Write-Host "[+] Downloading: $entry" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
}

Write-Host "`n[✔] Environment initialized successfully." -ForegroundColor Green
