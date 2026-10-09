-- Make `import <dir/header.hpp>;` work with xmake's GCC header-unit builder.
--
-- xmake's GCC builder strips a header unit's source path to its basename before
-- invoking the compiler (gcc/builder.lua: `path.filename(module.sourcefile)`),
-- while clang keeps the full path. It also only adds `-I <header dir>` for
-- quote-includes, not for include-angle headers (gcc/builder.lua:
-- `_make_headerunitflags`). As a result GCC fails to find sub-directory headers,
-- e.g. `glaze/glaze.hpp`, with "No such file or directory".
--
-- This rule hooks the GCC builder implementation and exposes each header's own
-- directory on the include path right before the header unit is compiled, so the
-- basename resolves again. It is a no-op for clang.

local _patched = {}

local function _expose_header_dir(target, headerunit, support_impl)
    local dir = path.directory(headerunit.sourcefile)

    if dir == "." then return end

    local toolchain_dirs =
        support_impl
            .import_implementation_of(target, "support")
            .toolchain_includedirs(target)

    local includedirs =
        table.join(
            table.wrap(
                target:get("includedirs")),
                table.wrap(target:get("sysincludedirs")
            )
        )

    if not table.contains(includedirs, dir) and not table.contains(toolchain_dirs, dir) then
        target:add("includedirs", dir)
    end
end

rule("cxx.headerunit_dirs")
    on_config(function (target)
        if not target:has_tool("cxx", "gcc", "gxx") then
            return
        end

        if _patched[target:fullname()] then
            return
        end

        _patched[target:fullname()] = true

        local support = import("rules.c++.modules.support", {rootdir = os.programdir()})
        local mapper  = import("rules.c++.modules.mapper",  {rootdir = os.programdir()})
        local builder = support.import_implementation_of(target, "builder")
        if not builder then
            return
        end

        local make_headerunit_job = builder.make_headerunit_job
        builder.make_headerunit_job = function (t, headerunit, ...)
            _expose_header_dir(t, headerunit, support)
            return make_headerunit_job(t, headerunit, ...)
        end

        local make_headerunit_buildcmds = builder.make_headerunit_buildcmds
        builder.make_headerunit_buildcmds = function (t, batchcmds, headerunit, ...)
            _expose_header_dir(t, headerunit, support)
            return make_headerunit_buildcmds(t, batchcmds, headerunit, ...)
        end

        local make_headerunit_job = builder.make_headerunit_job
        builder.make_headerunit_job = function (t, headerunit, ...)
            if headerunit.bmifile and not path.absolute(headerunit.bmifile):startswith(os.projectdir()) then
                local outputdir = support.modules_cachedir(t, {headerunit = true, mkdir = true})
                headerunit.bmifile = path.join(outputdir,
                    support.get_modulehash(headerunit.sourcefile),
                    path.filename(headerunit.sourcefile) .. support.get_bmi_extension(t))
            end
            _expose_header_dir(t, headerunit, support)
            return make_headerunit_job(t, headerunit, ...)
        end

        local mapper_get = mapper.get
        mapper.get = function (t, key)
            local module = mapper_get(t, key)
            if module and module.headerunit and module.bmifile
            and not path.absolute(module.bmifile):startswith(os.projectdir()) then
                local outputdir = support.modules_cachedir(t, {headerunit = true, mkdir = true})
                module.bmifile = path.join(outputdir,
                    support.get_modulehash(module.sourcefile),
                    path.filename(module.sourcefile) .. support.get_bmi_extension(t))
            end
            return module
        end
    end)
rule_end()
