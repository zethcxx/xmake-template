$ErrorActionPreference = "Stop"

$ProjectName = if ($args[0]) { $args[0] } else { "." }
$BaseUrl = "https://raw.githubusercontent.com/zethcxx/xmake-template/main"

$Entries = @(
    "xmake.lua",

    "xmake/modules/actions.lua",
    "xmake/modules/cfg/flags.lua",
    "xmake/modules/cfg/triple.lua",
    "xmake/modules/payload_header.lua",
    "xmake/modules/utils/strings.lua",

    "xmake/packages/l/lbyte.stx/xmake.lua",

    "xmake/rules/compile_commands.lua",
    "xmake/rules/payload_bin.lua",
    "xmake/rules/payload_extract.lua",

    "app/main.cpp"
)

Write-Host "[*] Creating project structure: $ProjectName" -ForegroundColor Gray

foreach ($entry in $Entries) {
    $url = "$BaseUrl/$entry"
    $outputPath = Join-Path $ProjectName $entry

    $dir = Split-Path $outputPath -Parent

    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    Write-Host "[+] Downloading: $entry" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $outputPath -UseBasicParsing
}

Write-Host "`n[✔] Environment initialized successfully." -ForegroundColor Green

