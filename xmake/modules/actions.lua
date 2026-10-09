import("cfg.triple"          )
import("cfg.flags"           )
import("lang.core"           )
import("core.project.project")
import("core.project.config" )
import("core.cache.localcache")
import("core.base.option"    )
import("core.base.process"   )

-- Static files are now embedded by the embed_cxx rule (see xmake/rules/embed_cxx.lua),
-- which generates them in on_config so they always exist before the C++ modules
-- scanner preprocesses the .cppm units.

local function collect_shared_libs()
    local libs = {}
    local pkg_base = path.join(os.getenv("HOME"), ".xmake", "packages")
    if not os.isdir(pkg_base) then return libs end

    local libdirs = os.dirs(path.join(pkg_base, "*", "*", "*", "*", "lib"))
    for _, libdir in ipairs(libdirs or {}) do
        local so_files = os.files(path.join(libdir, "*.so"))
        if so_files then
            for _, so in ipairs(so_files) do
                table.insert(libs, so)
            end
        end
    end
    return libs
end

local function purge_stale_module_cache(target)
    -- xmake's module cache (localcache group "cxxmodules") maps `module →
    -- BMI path` per target, keyed WITHOUT the active mode/toolchain, so an
    -- in-place `xmake f` switching mode or toolchain keeps pointing `import std`
    -- at the stale BMIs from the previous config. On a mode switch that made
    -- clang load a `debug` std BMI built with different flags (`-fexceptions`)
    -- and fail with a configuration mismatch. Clearing the map once per xmake
    -- session makes the scanner rerun and rebuild the BMIs for the new config,
    -- mirroring the manual `rm -rf build .xmake` workflow.
    if _g.purged_module_cache then return end
    _g.purged_module_cache = true

    if not os.isfile(config.filepath()) then
        return
    end
    local old = io.load(config.filepath()) or {}
    local getters =
    {
        mode      = config.mode
    ,   toolchain = function() return config.get("toolchain") end
    ,   arch      = config.arch
    ,   plat      = config.plat
    }
    local which = {}
    for name, get in pairs(getters) do
        if tostring(get()) ~= tostring(old[name]) then
            table.insert(which, name .. "(" .. tostring(old[name]) .. "->" .. tostring(get()) .. ")")
        end
    end
    if #which == 0 then return end

    localcache.clear("cxxmodules")
    if option.get("diagnosis") then
        print("<%s>: purged stale module cache after config change (%s)", target:fullname(), table.concat(which, ", "))
    end
end

function configure(target)
    if os.getenv("XMAKE_IN_COMPILE_COMMANDS_PROJECT_GENERATOR") then return end

    purge_stale_module_cache(target)

    -- GCC pins its module cache to `gcm.cache/` relative to the compiler's
    -- working directory, so the flag probes xmake runs while configuring (and,
    -- on GCC, no build step) leave dead BMIs there. Reclaim the cache at the
    -- end of configuring and again after the build so the project root stays
    -- clean; see `cleanup_gcm_cache`.
    cleanup_gcm_cache(target)

    -- Info boxes are shown on demand via `xmake pinfo [target]`; configuring
    -- stays quiet.
    if target:rule("perl") then
        return
    end

    local info = triple.get(target)
    if not info then return end

    flags.apply(target, info)

    if is_plat("linux") then
        local libs = collect_shared_libs()
        if #libs > 0 then
            target:add("ldflags", "-Wl,-rpath,$ORIGIN/lib", {force = true})
            target:values_set("shared_libs", libs)
        end
    end

    for _, depname in ipairs(target:get("deps") or {}) do
        local dep = project.target(depname)
        if dep then
            local gen_dir = dep:values("payload.generated_dir")
            if gen_dir then
                target:add("includedirs", gen_dir, {force = true})
            end
        end
    end

    local xmake_dir = path.join(os.projectdir(), ".xmake")
    os.mkdir(xmake_dir)

    local root_file = path.join(xmake_dir, ".source_root_linux")
    if not os.isfile(root_file) and not is_host("windows") then
        io.writefile(root_file, os.projectdir())
    end

    if info.abi == "msvc" and is_mode("debug") then
        local lldb_dir = path.join(os.projectdir(), "build", "lldb")
        os.mkdir(lldb_dir)
        local src_root = os.isfile(root_file) and io.readfile(root_file):trim() or os.projectdir()
        io.writefile(
            path.join(lldb_dir, target:name() .. ".lldbinit"),
            "settings set target.source-map "
                .. src_root
                .. " "
                .. os.projectdir()
                .. "\n"
        )
    end

    if target:data("cxx.has_modules") and target:has_tool("cxx", "gcc", "gxx") then
        patch_fallback_scanner_names(target)
    end

    headerunits(target)
end

-- clang-scan-deps scans every TU before building anything, and xmake only
-- schedules the header-unit build *after* that scan, so a cold build that
-- imports a header unit (`import <cstdio>;`) needs its BMI to already exist.
-- We precompile the required system headers once per mode here and feed the
-- result to every clang++ invocation via `-fmodule-file=<pcm>`.
-- GCC needs none of this: with `build.c++.modules.gcc.fallbackscanner` its
-- header units are discovered by the fallback scanner and built into
-- `build/.gens/.../bmi/cache/headerunits/`, so no `gcm.cache` is produced.
function headerunits(target)
    if os.getenv("XMAKE_IN_COMPILE_COMMANDS_PROJECT_GENERATOR") then return end
    if not target:policy("build.c++.modules") then return end

    -- Only module targets need header-unit support (see the c++ modules rule,
    -- which sets this marker in config.lua).
    if not target:data("cxx.has_modules") then return end

    local clang = target:has_tool("cxx", "clang", "clangxx", "clang_cl")
    if not clang then return end

    local compinst = target:compiler("cxx")
    local program = compinst:program()
    if not program then return end

    -- reuse the target's real language options (applied by cfg.flags) so the BMI
    -- matches the compilation it is loaded into
    local compflags = compinst:compflags({target = target, sourcekind = "cxx"}) or {}
    local headerflags = {}
    local i = 1
    while i <= #compflags do
        local flag = compflags[i]
        local skip_next = false
        if flag == "-x" or flag == "-o" or flag == "-MF" or flag == "-MT" or flag == "-MQ" then
            skip_next = true
        elseif not (flag:startswith("-fmodule") or flag:startswith("-fmodules") or
                    flag:startswith("-M") or flag == "-c") then
            table.insert(headerflags, flag)
        end
        i = i + (skip_next and 2 or 1)
    end

    local mode = get_config("mode") or is_mode() or target:get("mode") or "release"
    local outputdir = path.join(os.projectdir(), "build", "headerunits", mode)
    os.mkdir(outputdir)
    for _, header in ipairs({"cstdio"}) do
        local pcm = path.join(outputdir, header .. ".pcm")
        if not os.isfile(pcm) then
            os.vrunv(program, table.join(headerflags, {"-Wno-experimental-header-units",
                               "-xc++-system-header", "--precompile", header, "-o", pcm}))
        end
        target:add("cxxflags", "-fmodule-file=" .. pcm)
    end
    target:add("cxxflags", "-Wno-experimental-header-units")
end

function patch_fallback_scanner_names(target)
    -- GCC's fallback scanner (build.c++.modules.gcc.fallbackscanner) parses
    -- module sources with a per-line regex and takes the logical-name verbatim
    -- from the `import`/`export import` text. Column-aligned declarations, e.g.
    --
    --     import :layout  ;
    --     import :catalog ;
    --     export import :config ;
    --
    -- yield names with trailing padding (":layout  ", ":catalog ") that no
    -- longer match the clean `provides` names of the modules themselves, so the
    -- missing-dependency check aborts the build. Same for aligned header-unit
    -- imports: `import <cstdio> ;` captures "<cstdio> " and the fallback
    -- `sub(2, -2)` strips the padding space instead of the `>`.
    -- clang-scan-deps output is already clean, so this is a no-op for clang.
    if _g.patched_fallback_scanner_names then return end
    _g.patched_fallback_scanner_names = true

    local normalize_name = function(name)
        if name then
            name = name:match("^%s*(.-)%s*$")
            name = name:gsub("[<>\"]", "")
        end
        return name
    end

    local seen = {}
    local function patch_support(support)
        if not support or seen[support] then
            return
        end
        seen[support] = true

        local find_angle_header_file = support.find_angle_header_file
        support.find_angle_header_file = function(t, file)
            return find_angle_header_file(t, normalize_name(file))
        end

        local find_quote_header_file = support.find_quote_header_file
        support.find_quote_header_file = function(sourcefile, file)
            return find_quote_header_file(sourcefile, normalize_name(file))
        end

        local load_moduleinfo = support.load_moduleinfo
        support.load_moduleinfo = function(t, sourcefile)
            local moduleinfo, err = load_moduleinfo(t, sourcefile)
            if moduleinfo and moduleinfo.rules then
                for _, rule in ipairs(moduleinfo.rules) do
                    if rule.provides then
                        for _, provide in ipairs(rule.provides) do
                            provide["logical-name"] = normalize_name(provide["logical-name"])
                        end
                    end
                    if rule.requires then
                        for _, require in ipairs(rule.requires) do
                            require["logical-name"] = normalize_name(require["logical-name"])
                        end
                    end
                end
            end
            return moduleinfo, err
        end
    end

    patch_support(import("rules.c++.modules.support", {rootdir = os.programdir()}))
    local modules_dir = path.join(os.programdir(), "rules", "c++", "modules")
    patch_support(import("support", {rootdir = modules_dir}))
    -- The per-toolchain support modules (gcc/clang/msvc) don't import the base
    -- support table by reference, they take a snapshot of it at load time via
    -- `import(".support", {inherit = true})`. Patching only the base instances
    -- above therefore reaches gcc's scanner but NOT clang's (and vice versa),
    -- so the trailing-`>`-name fix would silently not apply depending on the
    -- toolchain. Patch the inherited snapshots as well so aligned header-unit
    -- imports (`import <cstdio> ;`) normalize identically under gcc and clang.
    for _, toolchain in ipairs({"gcc", "clang", "msvc"}) do
        patch_support(import(toolchain .. ".support", {rootdir = modules_dir}))
    end
end

function after_build(target)
    -- Registered from xmake.lua as the target's single `after_build` hook:
    -- xmake keeps only the last generic `after_build(...)` (interpreter.lua
    -- replaces the previous script), so everything that must run post-build
    -- lives here instead of stacking multiple registrations.
    copy_shared_libs(target)
    cleanup_gcm_cache(target)
end

function cleanup_gcm_cache(target)
    -- GCC pins its module cache to `gcm.cache/` relative to the compiler's
    -- working directory (no flag or env var relocates it), so xmake's flag
    -- probes -- empty TUs compiled as header units while configuring -- leave
    -- dead BMIs there. Nothing ever reads them: real header units resolve
    -- through the per-TU `-fmodule-mapper` into `build/.gens/.../bmi/cache/`.
    -- Reclaim the cache after configuring and again after the build so the
    -- project root stays free of GCC's working-directory byproduct.
    -- Only GCC + module targets ever produce it.
    if is_host("windows") then return end
    if not (target and target:has_tool("cxx", "gcc", "gxx") and target:data("cxx.has_modules")) then return end
    local gcmcache = path.join(os.projectdir(), "gcm.cache")
    if os.isdir(gcmcache) then
        os.rmdir(gcmcache)
    end
end

function copy_shared_libs(target)
    local libs = target:values("shared_libs")
    if not libs or #libs == 0 then return end

    local libdir = path.join(path.directory(target:targetfile()), "lib")
    os.mkdir(libdir)

    for _, so in ipairs(libs) do
        os.cp(so, libdir)
    end
end

function run_process(target)
    local program = target:targetfile()
    local args    = table.wrap(target:get("runargs") or {})

    local rel = path.relative(program, os.projectdir())
    cprint("${bright green}[Running 1/1: %s]${clear}", rel ~= program and rel or path.filename(program))

    -- Opt-in per target: set_values("run.detach", true) lets the child
    -- outlive xmake (daemons/background). Attached by default.
    local dv = target:values("run.detach")
    if type(dv) == "table" then
        dv = dv[1]
    end
    local detached = (dv == true or dv == "true")
    if detached then
        cprint("${yellow}[Running detached (Ctrl+C kills it via the signal handler)]${clear}")
    end

    local ok, status = core.exec(program, args, {detach = detached})
    core.report(ok, status)
end

