--: Headers ---------------------------------------------
set_project ("Testing")
set_version ("0.1.0")
set_xmakever("2.8.0")


--: Configs ---------------------------------------------
includes("xmake/rules/compile_commands.lua")
add_rules("vscode.compile_commands")


--: Actions ---------------------------------------------
local act = import("xmake.actions")


--: Targets ---------------------------------------------
target("main")
    set_default  (true    )
    set_languages("c++23" )
    set_kind     ("binary")
    set_basename ("exec"  )

    add_files( "app/main.cpp" )

    on_config ( act.configure   )
    on_prepare( act.print_info  )
    on_run    ( act.run_process )

