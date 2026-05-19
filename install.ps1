$ErrorActionPreference = "Stop"

$ProjectName = if ($args[0]) { $args[0] } else { "." }

$BaseUrl = "https://raw.githubusercontent.com/zethcxx/xmake-template/main"

$Entries = @(
    "xmake.lua",
    "xmake/cfg/triple.lua",
    "xmake/cfg/flags.lua",
    "xmake/rules/compile_commands.lua",
    "xmake/actions.lua",
    "app/main.cpp"
)

Write-Host "[*] Creating project structure: $ProjectName" -ForegroundColor Gray
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectName "xmake/cfg")   | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectName "xmake/rules") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectName "app")         | Out-Null

foreach ($entry in $Entries) {
    $url = "$BaseUrl/$entry"
    $outputPath = Join-Path $ProjectName $entry

    Write-Host "[+] Downloading: $entry" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
}

Write-Host "`n[✔] Environment initialized successfully." -ForegroundColor Green
