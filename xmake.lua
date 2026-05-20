--: Headers ---------------------------------------------
set_project   ("Testing")
set_version   ("0.1.0")
set_xmakever  ("2.8.0")
set_toolchains( "clang", "gcc" )

--: Includes --------------------------------------------
includes("xmake/rules/compile_commands.lua")
includes("xmake/actions.lua")

--: Configs ---------------------------------------------
add_rules("vscode.compile_commands")

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

