package("lbyte.stx")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/zethcxx/stx")
    set_description("C++23 Systems Toolbelt")

    add_urls("https://github.com/zethcxx/stx/archive/refs/tags/$(version).tar.gz",
             {version = "(v%d+%.%d+%.%d+)"})
    add_urls("https://github.com/zethcxx/stx/archive/$(version).tar.gz")

    add_versions("main", "main")

    add_configs("use_modules", { description = "Build C++ modules", default = false, type = "boolean" })

    on_load(function (package)
        package:add("includedirs", "include")
        if package:config("use_modules") then
            package:add("cxxmodules", "modules/stx/*.cppm")
        end
    end)

    on_install(function (package)
        os.cp("include", package:installdir())
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            #include <lbyte/stx/core.hpp>
            using namespace lbyte;

            int main(){ return stx::u32{}; }
        ]]}, { configs = { languages = "cxx23" } }))
    end)
package_end()
