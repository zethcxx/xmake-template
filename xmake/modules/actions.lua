import("cfg.triple"          )
import("cfg.flags"           )
import("core.project.project")
import("core.base.process"   )

function configure(target)
    if os.getenv("XMAKE_IN_COMPILE_COMMANDS_PROJECT_GENERATOR") then return end

    local info = triple.get(target)
    if not info then return end

    local marker = path.join(path.directory(target:targetfile()), ".info_printed")
    if not os.isfile(marker) then
        triple.print_info(target, info)
        io.writefile(marker, "")
    elseif import("core.base.option").get("pinfo") then
        triple.print_info(target, info)
    end
    flags.apply(target, info)

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
end

function run_process(target)
    local program = target:targetfile()
    local args    = target:get("runargs") or {}

    cprint("${bright green}[Running: " .. program .. "]")

    local proc = process.openv(program, args, { detach = true })
    local ok, status = proc:wait()

    if ok < 0 then
        cprint("${bright red}[Process failed with status: " .. ok .. "]")
    else
        if status == 0 then
            cprint("${bright green}[Command was successful]")
        else
            cprint("${bright red}[Command exited with " .. status .. "]")
        end
    end

    proc:close()
end

