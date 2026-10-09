-- Headers -----------------------------------------------------------------------------------------
set_project ("Template")
set_version ("0.1.0")
set_xmakever("3.0.0")

-- Includes ----------------------------------------------------------------------------------------
includes("./xmake/rules/*.lua") -- or only rule specify


-- Configs -----------------------------------------------------------------------------------------
add_repositories("local-repo ./xmake/")
add_moduledirs("./xmake/modules/")

set_policy("build.c++.modules"                , true)
set_policy("build.c++.modules.std"            , true)
set_policy("build.c++.modules.gcc.cxx11abi"   , true)
set_policy("build.c++.modules.fallbackscanner", true)
set_policy("build.c++.modules.reuse.strict"   , true)


-- Values ------------------------------------------------------------------------------------------
_embed_orig_set_values = _embed_orig_set_values or set_values
function set_values(...)
    local args = {...}
    if #args == 2 then
        local name, value = args[1], args[2]
        if type(value) == "table" and table.is_dictionary(value) then
            return _embed_orig_set_values(name, value, {expand = false})
        end
    end
    return _embed_orig_set_values(...)
end


-- Rules -------------------------------------------------------------------------------------------
add_rules("vscode.compile_commands")


-- Deps --------------------------------------------------------------------------------------------
add_requires("lbyte.stx v0.4.0", {configs = { use_modules = true }})


----------------------------------------------------------------------------------------------------
--                                             Targets
----------------------------------------------------------------------------------------------------
target("main")
    set_default  (true    )
    set_languages("c++23" )
    set_kind     ("binary")
    set_basename ("exec"  )

    add_rules("cxx.headerunit_dirs")
    add_rules("cxx.scanner_norm"   )

    add_files("src/main.cpp")

    add_packages("lbyte.stx")

    on_config  ("actions.configure"  )
    after_build("actions.after_build")
    on_run     ("actions.run_process")

