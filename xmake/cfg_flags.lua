import( "core.project.config" )

local function reset_flags(target)
    target:set( "cflags",   {} )
    target:set( "cxxflags", {} )
    target:set( "cxflags",  {} )
    target:set( "ldflags",  {} )
end


local function is_clang( info ) return info.toolchain:find("clang") ~= nil end
local function is_gcc  ( info ) return info.toolchain:find("gcc"  ) ~= nil end

local function is_windows( info )
    return info.os:find("windows") or info.abi == "msvc"
end

local function is_release( target )
    return config.get("mode") == "release"
end


local function apply_common_flags( target, info )
    local _add_cxflags  = function( flags ) target:add( "cxflags" , flags, { force = true }) end
    local _add_cflags   = function( flags ) target:add( "cflags"  , flags, { force = true }) end
    local _add_cxxflags = function( flags ) target:add( "cxxflags", flags, { force = true }) end
    local _add_defines  = function( flags ) target:add( "defines" , flags, { force = true }) end

    _add_cxflags({
        "-pipe",
        "-masm=intel",
        "-fdiagnostics-color=always",
        "-march=x86-64-v2",
        "-mtune=generic",
    })

    if is_windows( info ) then
        _add_defines({
            "_CRT_SECURE_NO_WARNINGS=1",
            "WIN32_LEAN_AND_MEAN=1",
            "NOMINMAX=1",
            "UNICODE=1",
            "_UNICODE=1",
            -- "_DLL",
            -- "_MT",
            -- "_WIN32_WINNT=0x0A00",
        })
    end

    if is_release( target ) then
        _add_cxflags({

        })
    end
end


local function apply_debug_flags( target, info )
    if not is_mode("debug") then return end

    local _add_cxflags  = function( flags ) target:add( "cxflags" , flags, { force = true }) end
    local _add_cflags   = function( flags ) target:add( "cflags"  , flags, { force = true }) end
    local _add_cxxflags = function( flags ) target:add( "cxxflags", flags, { force = true }) end

    -- WARNINGS AND DEBUG FLAGS (C + C++) ---------------------------------------------------
    -- [[ COMMONG FLAGS ]]
    _add_cxflags({
        "-Wall",
        "-Wextra",
        "-Wpedantic",

        "-Wconversion",
        "-Wsign-conversion",
        "-Wshadow",
        "-Wformat=2",
        "-Wnull-dereference",
        "-Wdouble-promotion",
        "-Wimplicit-fallthrough",

        "-Wcast-align",
        "-Wcast-qual",

        "-Wmissing-declarations",
        -- "-Wmissing-prototypes",
        -- "-Wundef",

        "-Wwrite-strings",
        "-Wvla",

        "-Werror",

        "-O0",
        "-g3",
        "-fno-inline",
        "-fno-omit-frame-pointer",
        "-fno-optimize-sibling-calls",
        "-fexceptions",
    })

    -- [[ C ONLY ]]
    _add_cflags({
        "-Wbad-function-cast",
        "-Wnested-externs",
        "-Wjump-misses-init",
    })

    -- [[ CXX ONLY ]]
    _add_cxxflags({
        "-Wnon-virtual-dtor",
        "-Wdelete-non-virtual-dtor",
        "-Woverloaded-virtual",

        "-Wold-style-cast",
        "-Wzero-as-null-pointer-constant",

        "-Wredundant-move",
        "-Wpessimizing-move",
        "-Wdeprecated-copy",
        "-Wdeprecated-copy-dtor",
        "-Wreorder",
        "-Wextra-semi",
    })

    -- [[ GCC EXTRA ]]
    if is_gcc( info ) then
        _add_cxflags({
            "-Wlogical-op",
            "-Wduplicated-cond",
            "-Wcatch-value",
            "-Wuseless-cast",
            "-Wclass-memaccess",
            "-Waligned-new",
            "-Wplacement-new=2",
            "-Wrestrict",
            "-Wduplicated-branches",
        })

        _add_cxxflags({
            "-Wnoexcept",
            "-Wnoexcept-type",
        })
    end

    -- [[ CLANG EXTRA ]]
    if is_clang( info ) then
        _add_cxxflags({
            "-Wcomma",
            "-Wextra-tokens",
            "-Wrange-loop-analysis",
            "-Wself-move",
            "-Winconsistent-missing-destructor-override",
        })
    end


    -- DEFINES (C + C++) ---------------------------------------------------
    -- [[ COMMON ]]
    target:add( "defines",
        "_GLIBCXX_ASSERTIONS",
        "DEBUG=1",
        "_DEBUG=1",
        { force = true })

    -- [[ WINDOWS ]]
    if is_windows( info ) then
        target:add("defines",
            "_ITERATOR_DEBUG_LEVEL=2",
            "_SECURE_SCL=1",
            "_CRTDBG_MAP_ALLOC=1",
            { force = true })
    end

    -- [[ LINUX/GCC ]]
    if not is_windows(info) then
        target:add("defines", "_GLIBCXX_ASSERTIONS", { force = true })
    end
end


local function apply_release_flags( target, info )
    if not is_mode("release") then return end

    local _add_cxflags  = function( flags ) target:add( "cxflags" , flags, { force = true }) end
    local _add_cflags   = function( flags ) target:add( "cflags"  , flags, { force = true }) end
    local _add_cxxflags = function( flags ) target:add( "cxxflags", flags, { force = true }) end

    -- WARNINGS AND DEBUG FLAGS (C + C++) ---------------------------------------------------
    -- [[ COMMONG FLAGS ]]
    _add_cxflags({
        "-fomit-frame-pointer",
        "-fdata-sections",
        "-ffunction-sections",

        "-fvisibility=hidden",
        "-fvisibility-inlines-hidden",

        "-fstack-protector-strong",
        "-fvisibility-inlines-hidden",
        "-fvisibility=hidden",

        "-fno-exceptions",
        "-fno-rtti",
        "-fno-ident",

        -- "-fno-enforce-eh-specs",
    })

    -- [[ C ONLY ]]
    _add_cflags({})

    -- [[ CXX ONLY ]]
    _add_cxxflags({})

    -- [[ GCC EXTRA ]]
    if is_gcc(info) then
        _add_cxflags({
            "-O3",
        })
    end

    -- [[ CLANG EXTRA ]]
    if is_clang( info ) then
        _add_cxxflags({
            "-Oz",
        })

        if not is_windows then
            _add_cxxflags({
                "-flto",
                "-fuse-ld=lld",
            })
        end
    end


    -- DEFINES (C + C++) ---------------------------------------------------
    -- [[ COMMON ]]
    target:add( "defines",
        "_FORTIFY_SOURCE=2",
        "_NDEBUG=1",
        "NDEBUG=1",
        { force = true })

    -- [[ LINUX/GCC ]]
    if not is_windows(info) then
        target:add("defines", "_FORTIFY_SOURCE=2", { force = true })
    end

    -- [[ WINDOWS ]]
    if is_windows( info ) then
        target:add("defines",
            "NDEBUG=1",
            "_SECURE_SCL=0",
            { force = true })
    end
end


local function apply_linker( target, info )
    -- COFF (clang + MSVC ABI → lld-link)
    if is_windows(info) then
        if is_release( target ) then
            target:add("ldflags",
                "-Wl,/INCREMENTAL:NO",
                "-Wl,/OPT:REF",
                "-Wl,/OPT:ICF",
                "-Wl,/DYNAMICBASE",
                "-Wl,/NXCOMPAT",
                "-Wl,/HIGHENTROPYVA",
                "-Wl,/MANIFEST:NO",
                "-Wl,/DEBUG:NONE",
                "-Wl,/SUBSYSTEM:CONSOLE",

                -- extreme optimization  --
                -- "-Wl,/LTCG",
                -- "-Wl,/ENTRY:start",
                -- "-Wl,/NODEFAULTLIB",
                -- "-Wl,/MERGE:.rdata=.text",
                -- "-Wl,/ALIGN:16",
                -- "-Wl,/FILEALIGN:16",
                {force = true})
        else
            target:add("ldflags",
                "-Wl,/DEBUG",
                "-Wl,/INCREMENTAL",
                {force = true})
        end

    -- ELF o GNU PE
    else

        if is_release( target ) then
            target:add("ldflags",
                "-Wl,--gc-sections",
                "-Wl,--exclude-libs,ALL",
                "-Wl,--strip-all",
                "-Wl,--gc-sections",
                "-Wl,-z,relro",
                "-Wl,-z,noexecstack",
                "-Wl,-z,defs",
                {force = true})
        else
            target:add("ldflags",
                "-Wl,-z,relro",
                "-Wl,-z,now",
                "-Wl,-z,noexecstack",
                "-Wl,-z,defs",
                {force = true})
        end
    end
end


function apply( target, info )
    reset_flags( target )

    apply_common_flags ( target, info )
    apply_debug_flags  ( target, info )
    apply_release_flags( target, info )
    apply_linker       ( target, info )
end

