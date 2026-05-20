local triple  = import("cfg.triple")
local flags   = import("cfg.flags")
local process = import("core.base.process")

act = {}

function act.configure( target )
    flags.apply( target, triple.get( target ))
end

function act.print_info(target)
    if os.getenv("XMAKE_IN_COMPILE_COMMANDS_PROJECT_GENERATOR") then return end
    triple.print_info( target, triple.get( target ))
end

function act.run_process(target)
    local program = target:targetfile()
    local args    = target:get("runargs") or {}

    cprint("${bright green}[Running: " .. program .. "]")

    local proc = process.openv(program, args, {detach = true})
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

