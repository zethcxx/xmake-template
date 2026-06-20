package("lbyte.stx")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/zethcxx/stx")
    set_description("C++23 Systems Toolbelt")

    add_urls("https://github.com/zethcxx/stx.git")
    add_versions("main", "main")
    add_versions("v0.1.0", "v0.1.0")
    add_versions("v0.2.0", "v0.2.0")

    add_configs("use_modules", { description = "Build C++ modules", default = false, type = "boolean" })

    on_load(function (package)
        package:add("includedirs", "include")
        if package:config("use_modules") then
            package:add("cxxmodules", "modules/stx/*.cppm")
        end
    end)

    on_install(function (package)
        os.cp("include", package:installdir())
        if package:config("use_modules") then
            os.cp("modules", package:installdir())
        end
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            #include <lbyte/stx/core.hpp>
            using namespace lbyte;

            int main(){ return stx::u32{}; }
        ]]}, { configs = { languages = "cxx23" } }))
    end)
package_end()
