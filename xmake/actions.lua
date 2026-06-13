act = {}

function act.configure( target )
    local triple  = import("xmake.cfg.triple")
    local info    = triple.get( target )
    if not info then return end

    local flags = import("xmake.cfg.flags")
    flags.apply( target, info )
end

function act.run_process( target )
    local process = import("core.base.process")
    local program = target:targetfile()
    local args    = target:get("runargs") or {}

    cprint("${bright green}[Running: " .. program .. "]")

    local proc = process.openv( program, args, { detach = true })
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

function act.print_info( target )
    if os.getenv("XMAKE_IN_COMPILE_COMMANDS_PROJECT_GENERATOR") then return end
    local triple = import("xmake.cfg.triple")
    triple.print_info( target, triple.get( target ))
end

