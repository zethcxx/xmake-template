option("compile-commands")
    set_default(false)
    set_showmenu(true)
    set_description("Generate compile_commands.json after configuration")
option_end()

rule("vscode.compile_commands")
    after_config(function()
        if not has_config("compile-commands") then
            return
        end

        import("core.project.project")
        local target_buildutils = import("private.action.build.target")
        local compile_commands = import("plugins.project.clang.compile_commands", {rootdir = os.programdir()})

        os.setenv("XMAKE_IN_COMPILE_COMMANDS_PROJECT_GENERATOR", "true")

        local all_targets = {}
        for _, target in pairs(project.targets()) do
            if target:is_enabled() and not target:is_phony() then
                table.insert(all_targets, target)
            end
        end
        if #all_targets > 0 then
            target_buildutils.run_targetjobs(all_targets, {
                job_kind = "prepare",
                for_generator = true,
                jobs = os.default_njob()
            })
        end

        compile_commands.make(".vscode")

        os.setenv("XMAKE_IN_COMPILE_COMMANDS_PROJECT_GENERATOR", nil)
    end)
rule_end()
