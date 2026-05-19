rule("vscode.compile_commands")
    after_config(function()
        import("plugins.project.clang.compile_commands", {rootdir = os.programdir()}).make(".vscode")
    end)
rule_end()

