set_project ( "Testing" )
set_version ( "1.0.0"   )
set_xmakever( "2.8.0"   )

-- GENERATE compile_commands.json -----------------------------------------------------
rule("vscode.compile_commands")
    after_config(function()
        import("plugins.project.clang.compile_commands", {rootdir = os.programdir()}).make(".vscode")
    end)
rule_end()


-- HELPERS ---------------------------------------------------------------------------
local cfg_triple = import("xmake.cfg_triple")
local cfg_flags  = import("xmake.cfg_flags" )

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
    flags.apply( target, cfg_triple.get( target ))
end

local function _print_info( target )
    if os.getenv("XMAKE_IN_COMPILE_COMMANDS_PROJECT_GENERATOR") then return end
    cfg_triple.print_info(target, cfg_triple.get( target ))
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

    on_config ( _config_proyect )
    on_prepare( _print_info     )
    on_run    ( _run_process    )

