import("cfg.triple")
import("cfg.flags")
import("core.project.project")
import("core.project.config")
import("core.cache.localcache")
import("core.base.option")

local function collect_shared_libs()
    local pkg_base = path.join(os.getenv("HOME"), ".xmake", "packages")
    if not os.isdir(pkg_base) then
        return {}
    end
    return os.files(path.join(pkg_base, "*", "*", "*", "*", "lib", "*.so")) or {}
end

local function purge_stale_module_cache(target)
    -- The cxxmodules cache is not keyed by mode/toolchain, so clear it after a
    -- config change to avoid loading BMIs built with other flags.
    if _g.purged_module_cache then
        return
    end
    _g.purged_module_cache = true

    if not os.isfile(config.filepath()) then
        return
    end

    local old = io.load(config.filepath()) or {}
    local current = {
        mode      = config.mode,
        toolchain = config.get("toolchain"),
        arch      = config.arch,
        plat      = config.plat,
    }

    local changed = {}
    for name, value in pairs(current) do
        if tostring(value) ~= tostring(old[name]) then
            table.insert(changed, name)
        end
    end
    if #changed == 0 then
        return
    end

    localcache.clear("cxxmodules")
    if option.get("diagnosis") then
        print("<%s>: purged stale module cache (%s)", target:fullname(), table.concat(changed, ", "))
    end
end

function configure(target)
    if os.getenv("XMAKE_IN_COMPILE_COMMANDS_PROJECT_GENERATOR") then
        return
    end

    purge_stale_module_cache(target)
    cleanup_gcm_cache(target)

    if target:rule("perl") then
        return
    end

    local info = triple.get(target)
    if not info then
        return
    end
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
        local gen_dir = dep and dep:values("payload.generated_dir")
        if gen_dir then
            target:add("includedirs", gen_dir, {force = true})
        end
    end

    local xmake_dir = path.join(os.projectdir(), ".xmake")
    os.mkdir(xmake_dir)

    local root_file = path.join(xmake_dir, ".source_root_linux")
    if not is_host("windows") and not os.isfile(root_file) then
        io.writefile(root_file, os.projectdir())
    end

    if info.abi == "msvc" and is_mode("debug") then
        local lldb_dir = path.join(os.projectdir(), "build", "lldb")
        os.mkdir(lldb_dir)
        local src_root = os.isfile(root_file) and io.readfile(root_file):trim() or os.projectdir()
        io.writefile(path.join(lldb_dir, target:name() .. ".lldbinit"),
            "settings set target.source-map " .. src_root .. " " .. os.projectdir() .. "\n")
    end
end

function after_build(target)
    copy_shared_libs(target)
    cleanup_gcm_cache(target)
end

function cleanup_gcm_cache(target)
    -- GCC writes gcm.cache next to the compiler; the real BMIs live under build.
    if is_host("windows") then
        return
    end
    if not (target and target:has_tool("cxx", "gcc", "gxx") and target:data("cxx.has_modules")) then
        return
    end
    local gcmcache = path.join(os.projectdir(), "gcm.cache")
    if os.isdir(gcmcache) then
        os.rmdir(gcmcache)
    end
end

function copy_shared_libs(target)
    local libs = target:values("shared_libs")
    if not libs or #libs == 0 then
        return
    end

    local libdir = path.join(path.directory(target:targetfile()), "lib")
    os.mkdir(libdir)
    for _, so in ipairs(libs) do
        os.cp(so, libdir)
    end
end

function run_process(target)
    local program = target:targetfile()
    local args = table.wrap(target:get("runargs") or {})

    local rel = path.relative(program, os.projectdir())
    cprint("${bright green}[Running 1/1: %s]${clear}", rel ~= program and rel or path.filename(program))

    local detach = target:values("run.detach")
    if type(detach) == "table" then
        detach = detach[1]
    end
    detach = detach == true or detach == "true"
    if detach then
        cprint("${yellow}[Running detached (Ctrl+C kills it via the signal handler)]${clear}")
    end

    os.execv(program, args, {detach = detach})
end
