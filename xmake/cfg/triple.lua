import( "core.project.config" )

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


local function find_target_flag( toolchain, target )
    if toolchain then
        for _, key in ipairs({ "cxflags", "cxxflags", "cflags", "ldflags" }) do
            local flags = toolchain:get( key )
            if flags then
                for _, f in ipairs( flags ) do
                    local t = f:match( "-target%s+(%S+)" ) or f:match( "--target=(%S+)" )
                    if t then return t end
                end
            end
        end
    end
    for _, key in ipairs({ "cxflags", "cxxflags", "cflags", "ldflags" }) do
        local flags = target:get( key )
        if flags then
            for _, flag in ipairs( flags ) do
                local t = flag:match( "-target%s+(%S+)" ) or flag:match( "--target=(%S+)" )
                if t then return t end
            end
        end
    end
    return nil
end


local function detect_triple( target, cc, compiler, toolchain )
    local flag_target = find_target_flag( toolchain, target )
    if flag_target then return flag_target end

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

    local arch = target:arch() or "unknown"
    local plat = target:plat() or "unknown"
    if plat == "windows" then
        return arch .. "-pc-windows-msvc"
    end
    return arch .. "-unknown-" .. plat .. "-gnu"
end


local function detect_os( raw_triple )
    local parts = string.split( raw_triple, "-" )
    local n = #parts
    if n >= 4 then
        return parts[n - 1]
    elseif n == 3 then
        return parts[n]
    end
    return "unknown"
end


local function detect_abi( raw_triple )
    if not raw_triple then return "gnu" end

    local parts = string.split( raw_triple, "-" )
    local last  = parts[#parts]

    if     last == "msvc"    then return "msvc"
    elseif last == "gnu"     then return "gnu"
    elseif last == "musl"    then return "musl"
    elseif last == "android" then return "android"
    elseif last == "cygnus"  then return "cygnus"
    end

    if raw_triple:find( "msvc"    ) then return "msvc"    end
    if raw_triple:find( "android" ) then return "android" end

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

    local raw_triple = detect_triple( target, cc, compiler, toolchain )
    local plat       = target:plat() or "unknown"
    local arch       = target:arch() or "unknown"
    local parts      = string.split( raw_triple, "-" )

    local info = {
        raw       = raw_triple,
        toolchain = toolchain and toolchain:name():lower() or compiler,
        compiler  = compiler,
        arch      = arch,
        vendor    = parts[2] or "unknown",
        os        = detect_os( raw_triple ),
        bits      = ( arch:find( "64" ) or raw_triple:find( "64" )) and "64" or "32",
        is_x64    = ( arch:find( "64" ) or raw_triple:find( "64" )) and true or false,
        mode      = config.get( "mode" ),
        abi       = detect_abi( raw_triple ),
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
