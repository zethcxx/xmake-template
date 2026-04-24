set_project ( "Testing" )
set_version ( "1.0.0"   )
set_xmakever( "2.8.0"   )

-- GENERATE compile_commands.json -----------------------------------------------------
rule( "vscode.compile_commands" )
    after_config( function( target )
        import( "core.base.task" ).run( "project", {
            kind      = "compile_commands",
            outputdir = ".vscode"
        })
    end )
rule_end()


-- HELPERS ---------------------------------------------------------------------------
local function _run_process( target )
    import("core.base.process")

    local program = target:targetfile()
    local args    = target:get("runargs") or {}

    cprint( "${bright green}[Running: " .. program .. "]" )

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

local function _config_proyect( target )
    local triple = import( "xmake.cfg_triple")
    local flags  = import( "xmake.cfg_flags" )
    local info   = triple.get( target )

    flags.apply      ( target, info )
    triple.print_info( target, info )
end


-- CONFIGS ---------------------------------------------------------------------------
add_rules( "vscode.compile_commands" )


-- MAIN TARGET -----------------------------------------------------------------------
target( "main" )
    set_default   ( true     )
    set_languages ( "c++23"  )
    set_kind      ( "binary" )
    set_basename  ( "exec"   )

    add_files("app/main.cpp")

    on_config( _config_proyect )
    on_run   ( _run_process    )
target_end()

