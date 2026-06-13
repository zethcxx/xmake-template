import( "core.project.config" )

function get( target )
    local toolchain = target:toolchain( config.get("toolchain") ) or target:toolchains()[1]
    local cc        = target:tool( "cc" )

    local compiler = "unknown"
    if cc then
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
    end

    if compiler == "unknown" then
        cprint( "${bright red}unsupported compiler. use gcc or clang." )
        return nil
    end

    local args      = compiler == "clang" and { "-print-target-triple" } or { "-dumpmachine" }
    local raw_triple
    try {
        function()
            raw_triple = os.iorunv( cc, args ):trim()
        end
    }
    raw_triple = raw_triple or "unknown-unknown-unknown"
    local parts = string.split( raw_triple, "-" )

    local info = {
        raw       = raw_triple,
        toolchain = toolchain and toolchain:name():lower() or compiler,
        compiler  = compiler,
        arch      = parts[1] or "unknown",
        vendor    = parts[2] or "unknown",
        os        = parts[3] or "unknown",
    }

    local current_arch = target:arch() or info.arch
    info.bits     = ( current_arch:find( "64" ) or info.raw:find( "64" )) and "64" or "32"
    info.is_x64   = ( info.bits == "64" )
    info.mode     = config.get( "mode" )

    if info.raw:find( "msvc" ) then
        info.abi = "msvc"
    elseif info.raw:find( "gnu" ) or info.raw:find( "linux" ) then
        info.abi = "gnu"
    end

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
