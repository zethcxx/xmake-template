import("core.project.config"     )
import("cfg.infobox"             )

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

    if     raw_triple:find("msvc"   ) then return "msvc"
    elseif raw_triple:find("android") then return "android"
    elseif raw_triple:find("musl"   ) then return "musl"
    elseif raw_triple:find("cygnus" ) then return "cygnus"
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

    local raw_triple = detect_triple( target, cc, compiler, toolchain )
    local parts      = string.split( raw_triple, "-" )
    local arch       = (parts[1] or "") ~= "" and parts[1] or (target:arch() or "unknown")

    local info = {
        raw       = raw_triple,
        toolchain = toolchain and toolchain:name():lower() or compiler,
        compiler  = compiler,
        arch      = arch,
        vendor    = parts[2] or "unknown",
        os        = detect_os( raw_triple ),
        bits      = ( arch:find( "64" ) or raw_triple:find( "64" )) and "64" or "32",
        is_x64    = ( arch:find( "64" ) or raw_triple:find( "64" )) and true or false,
        mode      = config.get( "mode" ) or config.read( "mode" ),
        abi       = detect_abi( raw_triple ),
    }

    return info
end

local PAYLOAD_PREFIX = "payload.cfg."

local function payload_items(target)
    local values = target:get("values")
    if type(values) ~= "table" then
        return {}
    end

    local names = {}
    for key in pairs(values) do
        if type(key) == "string" and key:sub(1, #PAYLOAD_PREFIX) == PAYLOAD_PREFIX then
            local name = key:sub(#PAYLOAD_PREFIX + 1)
            if name ~= "" then
                names[#names + 1] = name
            end
        end
    end
    table.sort(names)

    local items = {}
    for _, name in ipairs(names) do
        local cfg = values[PAYLOAD_PREFIX .. name] or {}
        local bin = cfg.binfile and path.absolute(cfg.binfile)
            or values["payload.bin." .. name]
        if not bin and target:targetfile() then
            bin = path.join(path.directory(target:targetfile()), name .. ".bin")
        end
        if bin then
            items[#items + 1] = {label = "payload." .. name, value = string.format("%s (%s)", bin, cfg.section or ".text")}
        end
    end
    return items
end

function print_info( target, info )
    if not info then return end

    local march = info.arch
    for _, flag in ipairs(target:get("cxflags") or {}) do
        local m = flag:match("^-march=(.+)$")
        if m then march = m; break end
    end

    local items = {
        {label = "toolchain", value = string.format("%s ${#223}-${white} %s ${#223}(${white}%s${#223}-abi)", info.toolchain, info.compiler, info.abi)},
        {label = "triple",    value = info.raw},
        {label = "march",     value = march},
        {label = "mode",      value = info.mode},
    }

    for _, item in ipairs(payload_items(target)) do
        items[#items + 1] = item
    end

    infobox.render(target:name(), target:targetfile(), items)
end

