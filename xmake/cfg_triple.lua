import( "core.project.config" )

local function print_item( key, value )
    cprint("${blue}[*] ${bright white}%-12s ${blue}: ${bright white}%s${clear}", key, tostring( value ))
end

function get( target )
    local name      = config.get("toolchain")
    local toolchain = target:toolchain(name) or target:toolchains()[1]
    local cc        = target:tool( "cc" )

    assert( toolchain:name():find( "gcc") or toolchain:name():find("clang"),
        string.format( "Toolchain %s not supported. Use GCC or Clang.", toolchain ))

    local target_flag = nil
    local cxflags     = target:get("cxflags")
    if cxflags then
        for _, flag in ipairs(cxflags) do
            target_flag = flag:match( "-target%s+(%S+)" ) or flag:match( "--target=(%S+)" )
            if target_flag then break end
        end
    end

    local raw_triple = target_flag
    if not raw_triple then
        local args = toolchain:name():find( "clang" ) and { "-print-target-triple" } or { "-dumpmachine" }
        try {
            function()
                raw_triple = os.iorunv( cc, args ):trim()
            end
        }
    end

    raw_triple = raw_triple or "unknown-unknown-unknown"
    local parts = string.split(raw_triple, "-")

    local info = {
        raw       = raw_triple,
        toolchain = toolchain:name():lower(),
        arch      = parts[1] or "unknown",
        vendor    = parts[2] or "unknown",
        os        = parts[3] or "unknown",
    }

    local current_arch = target:arch() or info.arch
    info.bits     = ( current_arch:find( "64" ) or info.raw:find( "64" )) and "64" or "32"
    info.is_x64   = ( info.bits == "64" )
    info.mode     = config.get( "mode" )

    if info.raw:find("msvc") then
        info.abi = "msvc"
    elseif info.raw:find("gnu") or info.raw:find("linux") then
        info.abi = "gnu"
    end

    return info
end

function print_info( target, info )
    cprint( "${blue}-- TARGET DETAILS -------------------------------------------${clear}" )
    print_item( "Modo"        , info.mode            )
    print_item( "Toolchain"   , info.toolchain       )
    print_item( "Target"      , info.raw             )
    print_item( "Arquitectura", info.arch            )
    print_item( "Vendor"      , info.vendor          )
    print_item( "Plataforma"  , info.os              )
    print_item( "ABI Type"    , info.abi             )
    print_item( "Maquina"     , info.bits .. "-bits" )
    print_item( "Output"      , target:targetfile()  )
    cprint( "${blue}-------------------------------------------------------------" )

    -- if info.arch:find("i686") then
    --     cprint("  ${yellow}[!] ADVERTENCIA: Compilador en modo 32-bits detectado.${clear}")
    -- end
end

