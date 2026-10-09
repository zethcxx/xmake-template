$ErrorActionPreference = "Stop"

$ProjectName = if ($args[0]) { $args[0] } else { "." }
$BaseUrl = "https://raw.githubusercontent.com/zethcxx/xmake-template/main"

$Entries = @(
    "src/main.cpp",
    "xmake.lua",
    "xmake/modules/actions.lua",
    "xmake/modules/cfg/flags.lua",
    "xmake/modules/cfg/infobox.lua",
    "xmake/modules/cfg/triple.lua",
    "xmake/modules/embed_gen.lua",
    "xmake/modules/embed_hex.lua",
    "xmake/modules/utils/strings.lua",
    "xmake/packages/l/lbyte.stx/xmake.lua",
    "xmake/rules/bundle.lua",
    "xmake/rules/compile_commands.lua",
    "xmake/rules/embed_cxx.lua",
    "xmake/rules/headerunit_dirs.lua",
    "xmake/rules/payload_extract.lua",
    "xmake/rules/scanner_norm.lua",
    "xmake/rules/tasks.lua"
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

