import("core.project.config")

local SUBSYSTEMS = table.join(
    { "CONSOLE", "WINDOWS", "NATIVE", "POSIX" },
    is_host("windows") and { "EFI_APPLICATION" } or {}
)

local BUILDTYPES = {
    native  = { march = "native",       mtune = "native"  },
    generic = { march = "x86-64-v2",    mtune = "generic" },
    legacy  = { march = "x86-64-v1",    mtune = "generic" },
    modern  = { march = "x86-64-v4",    mtune = "generic" },
}

local function reset_flags(target)
    target:set("cflags",   {})
    target:set("cxxflags", {})
    target:set("cxflags",  {})
    target:set("ldflags",  {})
    target:set("links",    {})
end


local function is_clang  ( info ) return info.compiler == "clang" end
local function is_gcc    ( info ) return info.compiler == "gcc"   end
local function is_msvc  ( info ) return info.abi == "msvc" end
local function is_release( target ) return config.get("mode") == "release" end

local function get_target_value(target, key, default)
    local config_val = get_config(key)
    if type(config_val) == "string" then
        return config_val
    end
    if config_val == true then
        return true
    end
    local val = target:values(key)
    if val ~= nil then
        if type(val) == "table" then
            return val[1] or default
        end
        return val
    end
    local prop = target:get(key)
    if prop ~= nil then
        return prop
    end
    return default
end

local function add_to(target)
    return {
        cxflags  = function(flags) target:add("cxflags" , flags, {force = true}) end,
        cflags   = function(flags) target:add("cflags"  , flags, {force = true}) end,
        cxxflags = function(flags) target:add("cxxflags", flags, {force = true}) end,
        defines  = function(flags) target:add("defines" , flags, {force = true}) end,
        ldflags  = function(flags) target:add("ldflags" , flags, {force = true}) end,
    }
end


local function apply_common_flags( target, info )
    local f         = add_to(target)
    local buildtype = get_target_value(target, "buildtype", "generic")

    assert(BUILDTYPES[buildtype] ~= nil,
        "Invalid buildtype '" .. tostring(buildtype) .. "'. Options: " .. table.concat(table.keys(BUILDTYPES), ", "))

    local bt    = BUILDTYPES[buildtype]
    local march = get_target_value(target, "march", bt.march)
    local mtune = get_target_value(target, "mtune", bt.mtune)

    f.cxflags({
        "-pipe",
        "-masm=intel",
        "-fdiagnostics-color=always",
        "-march=" .. march,
        "-mtune=" .. mtune,
    })

    if is_msvc( info ) then
        f.defines({
            "_CRT_SECURE_NO_WARNINGS=1",
            "WIN32_LEAN_AND_MEAN=1",
            "NOMINMAX=1",
            "UNICODE=1",
            "_UNICODE=1",
        })
    end

    if is_release( target ) then
        f.cxflags({})
    end
end


local function apply_debug_flags( target, info )
    if not is_mode("debug") then return end
    local f = add_to( target )

    f.cxflags({
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

    f.cflags({
        "-Wbad-function-cast",
        "-Wnested-externs",
        "-Wjump-misses-init",
    })

    f.cxxflags({
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

    if is_gcc( info ) then
        f.cxflags({
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

        f.cxxflags({
            "-Wnoexcept",
            "-Wnoexcept-type",
        })
    end

    if is_clang( info ) then
        f.cxxflags({
            "-Wcomma",
            "-Wextra-tokens",
            "-Wrange-loop-analysis",
            "-Wself-move",
            "-Winconsistent-missing-destructor-override",
        })
    end


    target:add("defines", {
        "_GLIBCXX_ASSERTIONS",
        "DEBUG=1",
        "_DEBUG=1",
    }, { force = true })

    if is_msvc( info ) then
        target:add("defines", {
            "_ITERATOR_DEBUG_LEVEL=2",
            "_SECURE_SCL=1",
            "_CRTDBG_MAP_ALLOC=1",
        }, { force = true })
    end

    if not is_msvc(info) then
        target:add("defines", { "_GLIBCXX_ASSERTIONS" }, { force = true })
    end
end


local function apply_release_flags( target, info )
    if not is_mode("release") then return end
    local f = add_to(target)

    local is_payload      = get_target_value(target, "payloadtype"    , false)
    local stack_protector = get_target_value(target, "stack_protector", true )

    f.cxflags({
        "-fomit-frame-pointer",
        "-fdata-sections",
        "-ffunction-sections",

        "-fvisibility=hidden",
        "-fvisibility-inlines-hidden",

        "-fno-exceptions",
        "-fno-rtti",
        "-fno-ident",
    })

    if is_payload or not stack_protector then
        f.cxflags({ "-fno-stack-protector" })
    else
        f.cxflags({ "-fstack-protector-strong" })
    end

    f.cflags({})
    f.cxxflags({})

    if is_gcc(info) then
        f.cxflags({ "-O3" })
    end

    if is_clang( info ) then
        if is_payload then
            f.cxxflags({ "-Oz" })
        else
            f.cxxflags({ "-O3" })
        end

        if not is_msvc(info) and not is_payload then
            f.cxflags({ "-flto" })
            f.ldflags({ "-flto", "-fuse-ld=lld" })
        end
    end

    target:add("defines", {
        "_NDEBUG=1",
        "NDEBUG=1",
    }, { force = true })

    if not is_payload then
        if not is_msvc(info) and not target:policy("build.c++.modules.std") then
            target:add("defines", { "_FORTIFY_SOURCE=2" }, { force = true })
        end
    end

    if is_msvc( info ) then
        target:add("defines", {
            "NDEBUG=1",
            "_SECURE_SCL=0",
        }, { force = true })
    end
end


local function apply_linker( target, info )
    local subsystem = get_target_value(target, "subsystem", "CONSOLE")

    assert(table.contains(SUBSYSTEMS, subsystem),
        "Invalid subsystem '" .. tostring(subsystem) .. "'. Valid: " .. table.concat(SUBSYSTEMS, ", "))

    local entry      = get_target_value(target, "entry"      , false)
    local noentry    = get_target_value(target, "noentry"    , false)
    local is_payload = get_target_value(target, "payloadtype", false)

    assert(not (entry and noentry),
        "'entry' and 'noentry' are mutually exclusive. Use one or the other.")

    if is_msvc(info) then
        local f = add_to(target)

        f.ldflags({ "-Wl,/SUBSYSTEM:" .. subsystem,})

        if is_release(target) then
            if is_payload then
                f.ldflags({
                    "-Wl,/DYNAMICBASE:NO",
                    "-Wl,/NXCOMPAT:NO",
                    "-Wl,/NODEFAULTLIB",
                    "-Wl,/NODEFAULTLIB:uuid"
                })
            else
                f.ldflags({
                    "-Wl,/DYNAMICBASE",
                    "-Wl,/NXCOMPAT",
                    "-Wl,/HIGHENTROPYVA",
                })
            end

            if noentry then
                f.ldflags({ "-Wl,/NOENTRY" })
            end

            if entry then
                f.ldflags({ "-Wl,/ENTRY:" .. entry })
            end
        else
            f.ldflags({
                "-Wl,/DEBUG",
                "-Wl,/INCREMENTAL",
            })

            if noentry then
                f.ldflags({ "-Wl,/NOENTRY" })
            end

            if entry then
                f.ldflags({ "-Wl,/ENTRY:" .. entry })
            end
        end

    else
        if is_release(target) then
            target:add("ldflags", {
                "-Wl,--gc-sections",
                "-Wl,--exclude-libs,ALL",
                "-Wl,--strip-all",
                "-Wl,-z,relro",
                "-Wl,-z,noexecstack",
                "-Wl,-z,defs",
            }, {force = true})
        else
            target:add("ldflags", {
                "-Wl,-z,relro",
                "-Wl,-z,now",
                "-Wl,-z,noexecstack",
                "-Wl,-z,defs",
            }, {force = true})
        end

        if is_payload then
                target:add("ldflags", { "-nostdlib" }, {force = true})
        end

        if entry then
            target:add("ldflags", { "-Wl,--entry=" .. entry }, {force = true})
        end
    end
end


function apply( target, info )
    local saved = {
        cxflags  = target:get("cxflags"),
        cflags   = target:get("cflags"),
        cxxflags = target:get("cxxflags"),
        links    = target:get("links"),
        defines  = target:get("defines"),
    }

    reset_flags( target )

    apply_common_flags ( target, info )
    apply_debug_flags  ( target, info )
    apply_release_flags( target, info )
    apply_linker       ( target, info )

    target:add("cxflags",  saved.cxflags  or {}, {force = true})
    target:add("cflags",   saved.cflags   or {}, {force = true})
    target:add("cxxflags", saved.cxxflags or {}, {force = true})

    if saved.links then
        for _, lib in ipairs(saved.links) do
            target:add("links", lib)
        end
    end
    if saved.defines then
        target:add("defines", saved.defines, {force = true})
    end
end

