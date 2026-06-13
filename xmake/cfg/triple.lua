import( "core.project.config" )

local ABI_MAP = {
    msvc    = "msvc",
    windows = "msvc",
    cygwin  = "cygnus",
    android = "android",
    linux   = "gnu",
}

local function detect_compiler( cc )
    if not cc then return "unknown" end
    local compiler = "unknown"
    try {
        function()
            local out = os.iorunv( cc, { "--version" }):lower()
            if out:find( "clang" ) then
                compiler = "clang"
            elseif out:find( "gcc" ) or out:find( "g++" ) or out:find( "gnu" ) then
                compiler = "gcc"
            end
        end
    }
    return compiler
end


local function detect_triple( target, cc, compiler )
    -- 1. Buscar --target= en cxflags (cross-compilation con clang)
    local cxflags = target:get( "cxflags" )
    if cxflags then
        for _, flag in ipairs( cxflags ) do
            local t = flag:match( "-target%s+(%S+)" ) or flag:match( "--target=(%S+)" )
            if t then return t end
        end
    end

    -- 2. Ejecutar el compilador (funciona para compilación nativa)
    local raw = nil
    if cc then
        local args = compiler == "clang" and { "-print-target-triple" } or { "-dumpmachine" }
        try {
            function()
                raw = os.iorunv( cc, args ):trim()
            end
        }
    end
    if raw and raw ~= "" then return raw end

    -- 3. Construir triple desde target:arch() + target:plat()
    local arch = target:arch() or "unknown"
    local plat = target:plat() or "unknown"
    if plat == "windows" then
        return arch .. "-pc-windows-msvc"
    end
    return arch .. "-unknown-" .. plat .. "-gnu"
end


local function detect_abi( raw_triple, plat )
    for key, abi in pairs( ABI_MAP ) do
        if raw_triple:find( key ) then
            return abi
        end
    end
    if plat == "windows" then
        return "msvc"
    end
    return "gnu"
end


function get( target )
    local toolchain = target:toolchain( config.get( "toolchain" )) or target:toolchains()[1]
    local cc        = target:tool( "cc" )
    local compiler  = detect_compiler( cc )

    if compiler == "unknown" then
        cprint( "${bright red}unsupported compiler. use gcc or clang." )
        return nil
    end

    local raw_triple = detect_triple( target, cc, compiler )
    local plat       = target:plat() or "unknown"
    local arch       = target:arch() or "unknown"
    local parts      = string.split( raw_triple, "-" )

    local info = {
        raw       = raw_triple,
        toolchain = toolchain and toolchain:name():lower() or compiler,
        compiler  = compiler,
        arch      = arch,
        vendor    = parts[2] or "unknown",
        os        = plat,
        bits      = ( arch:find( "64" ) or raw_triple:find( "64" )) and "64" or "32",
        is_x64    = ( arch:find( "64" ) or raw_triple:find( "64" )) and true or false,
        mode      = config.get( "mode" ),
        abi       = detect_abi( raw_triple, plat ),
    }

    return info
end


function print_info( target, info )
    if not info then return end
    cprint( "${white}┌${#216}[ ${bright}%s${reset}${#216}: %s ]", target:name(), target:targetfile())
    cprint( "${white}│${#223}    mode     : ${white}%s"         , info.mode     )
    cprint( "${white}│${#223}    toolchain: ${white}%s"         , info.toolchain)
    cprint( "${white}│${#223}    compiler : ${white}%s"         , info.compiler )
    cprint( "${white}│${#223}    triple   : ${white}%s"         , info.raw      )
    cprint( "${white}└─${clear}" )
end
