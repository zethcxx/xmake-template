-- Normalize names produced by the C++ modules fallback scanner.
--
--   add_rules("cxx.scanner_norm")
--
-- Aligned imports (`import std   ;`, `import <cstdio> ;`) keep their padding,
-- which otherwise no longer matches the modules that provide them.

local _patched = {}

rule("cxx.scanner_norm")
    on_config(function (target)
        if _patched[target:fullname()] then
            return
        end
        _patched[target:fullname()] = true

        local json = import("core.base.json")
        local support = import("rules.c++.modules.support", {rootdir = os.programdir()})
        if not support then
            return
        end

        local function normalize(name)
            return name and name:gsub("[%s>\"]+$", "")
        end

        if not support._scanner_norm_sanitized then
            support._scanner_norm_sanitized = true
            for _, name in ipairs({"find_angle_header_file", "find_quote_header_file"}) do
                local orig = support[name]
                if orig then
                    support[name] = function (a1, a2)
                        return orig(a1, normalize(a2))
                    end
                end
            end
        end

        local function trim_dependfile(dependfile)
            local data = io.load(dependfile)
            if not (data and data.moduleinfo) then
                return
            end

            local output = json.decode(data.moduleinfo)
            if not (output and output.rules) then
                return
            end

            local changed = false
            local function sanitize(items)
                for _, item in ipairs(items or {}) do
                    local name = normalize(item["logical-name"])
                    if name and name ~= item["logical-name"] then
                        item["logical-name"] = name
                        changed = true
                    end
                end
            end

            for _, rule in ipairs(output.rules) do
                sanitize(rule.provides)
                sanitize(rule.requires)
            end

            if changed then
                data.moduleinfo = json.encode(output)
                io.save(dependfile, data)
            end
        end

        local scanner = support.import_implementation_of(target, "scanner")
        if not (scanner and scanner.scan_dependency_for) then
            return
        end

        local scan_dependency_for = scanner.scan_dependency_for
        scanner.scan_dependency_for = function (t, sourcefile, rescan, opt)
            local changed = scan_dependency_for(t, sourcefile, rescan, opt)
            if changed then
                trim_dependfile(t:dependfile(sourcefile))
            end
            return changed
        end
    end)
rule_end()
