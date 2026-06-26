--: Headers ---------------------------------------------
set_project ("Testing")
set_version ("0.1.0"  )
set_xmakever("2.8.0"  )


--: Includes --------------------------------------------
includes("./xmake/rules/*.lua") -- or only rule specify


--: Configs ---------------------------------------------
add_repositories("local-repo ./xmake/")
add_moduledirs("./xmake/modules/")


--: Rules -----------------------------------------------
add_rules("vscode.compile_commands")


--: Targets ---------------------------------------------
target( "main" )
    set_default  (true    )
    set_languages("c++23" )
    set_kind     ("binary")
    set_basename ("exec"  )

    add_files( "app/main.cpp" )

    on_config( "actions.configure"   )
    on_run   ( "actions.run_process" )

