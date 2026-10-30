-- Keep header-unit BMIs per target.
--
--   add_rules("cxx.headerunit_dirs")
--
-- Needed when targets use different language options (-fexceptions, -frtti, ...);
-- xmake otherwise shares header-unit BMIs per mode or relies on gcm.cache.

local _patched = {}

local function _expose_header_dir(target, headerunit, support)
    local dir = path.directory(headerunit.sourcefile)
    if dir == "." then
        return
    end

    local toolchain_dirs = support.import_implementation_of(target, "support").toolchain_includedirs(target)
    local includedirs = target:get("includedirs")
    if not table.contains(table.wrap(toolchain_dirs), dir) and
       not table.contains(table.wrap(includedirs), dir) then
        target:add("includedirs", dir)
    end
end

rule("cxx.headerunit_dirs")
    on_config(function (target)
        if not target:has_tool("cxx", "gcc", "gxx", "clang", "clangxx", "clang_cl") then
            return
        end
        if _patched[target:fullname()] then
            return
        end
        _patched[target:fullname()] = true

        local is_gcc = target:has_tool("cxx", "gcc", "gxx")
        local support = import("rules.c++.modules.support", {rootdir = os.programdir()})
        local mapper = import("rules.c++.modules.mapper", {rootdir = os.programdir()})
        local builder = support.import_implementation_of(target, "builder")
        if not builder then
            return
        end

        local function relocate(t, module)
            if module and module.headerunit and module.bmifile then
                module.bmifile = path.join(
                    support.modules_cachedir(t, {headerunit = true, mkdir = true}),
                    support.get_modulehash(module.sourcefile),
                    path.filename(module.sourcefile) .. support.get_bmi_extension(t))
            end
        end

        local mapper_get = mapper.get
        mapper.get = function (t, key)
            local module = mapper_get(t, key)
            relocate(t, module)
            return module
        end

        local make_headerunit_job = builder.make_headerunit_job
        builder.make_headerunit_job = function (t, headerunit, ...)
            relocate(t, headerunit)
            if is_gcc then
                _expose_header_dir(t, headerunit, support)
            end
            return make_headerunit_job(t, headerunit, ...)
        end

        local make_headerunit_buildcmds = builder.make_headerunit_buildcmds
        builder.make_headerunit_buildcmds = function (t, batchcmds, headerunit, ...)
            relocate(t, headerunit)
            if is_gcc then
                _expose_header_dir(t, headerunit, support)
            end
            return make_headerunit_buildcmds(t, batchcmds, headerunit, ...)
        end
    end)
rule_end()
