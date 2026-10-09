-- Normalize trailing whitespace / mangled header names in xmake's C++ modules
-- fallback scanner.
--
-- The fallback scanner (`rules/c++/modules/scanner.lua` `fallback_generate_dependencies`)
-- matches `import%s+(.+)%s*;`. Because `(.+)` is greedy, an aligned import like
-- `import std      ;` keeps its padding in the captured logical-name, and
-- `import <cstdio>   ;` even becomes `cstdio>` after the scanner strips `<` and a
-- single trailing char via `sub(2, -2)`. Both break the scan:
--
--   * `cstdio>` is handed to `support.find_angle_header_file` which aborts with
--     `<cstdio>> not found!` before the depend file is even written.
--   * `std      ` does not match the module that provides `std`, so the DAG
--     validation fails with `<mopick> missing X dependency ...`.
--
-- This rule hooks the toolchain scanner so it
--
--   * sanitizes the name before the header lookup (kills the `not found!` abort),
--   * rewrites the stored moduleinfo right after the scan so every `logical-name`
--     loses its alignment padding / stray `>` / `"`, which the parse + dag step
--     reads afterwards.
--
-- The same code path is shared by gcc/msvc fallback scanners, so this also fixes
-- builds where no clang-scan-deps is available.

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

        -- 1) make the header lookups crash-proof.
        --    `fallback_generate_dependencies` resolves `<...>` / `"..."`
        --    imports through the *parent* support module, so patching it here is
        --    enough to stop `cstdio>` from aborting the scan.
        if not support._scanner_norm_sanitized then
            support._scanner_norm_sanitized = true
            for _, fname in ipairs({"find_angle_header_file", "find_quote_header_file"}) do
                local orig = support[fname]
                if orig then
                    support[fname] = function (a1, a2)
                        return orig(a1, a2:gsub("[%s>\"]+$", ""))
                    end
                end
            end
        end

        -- 2) normalize the logical-names persisted in the depend file so the
        --    parse/dag step sees `std` instead of `std      ` and `cstdio`
        --    instead of `cstdio>`.
        local function sanitize_names(items)
            if not items then
                return false
            end
            local changed = false
            for _, item in ipairs(items) do
                local name = item and item["logical-name"]
                if name then
                    local cleaned = name:gsub("[%s>\"]+$", "")
                    if cleaned ~= name then
                        item["logical-name"] = cleaned
                        changed = true
                    end
                end
            end
            return changed
        end

        local function trim_dependfile(dependfile)
            local data = io.load(dependfile)
            if not data or not data.moduleinfo then
                return
            end
            local output = json.decode(data.moduleinfo)
            if not output or not output.rules then
                return
            end
            local changed = false
            for _, rule in ipairs(output.rules) do
                if sanitize_names(rule.provides) then
                    changed = true
                end
                if sanitize_names(rule.requires) then
                    changed = true
                end
            end
            if changed then
                data.moduleinfo = json.encode(output)
                io.save(dependfile, data)
            end
        end

        -- 3) hook the toolchain scanner: the scan writes the depend file inside
        --    `scan_dependency_for`, so cleaning up right after it guarantees the
        --    parse + dag step that runs afterwards reads normalized names and the
        --    header lookups already worked because of step (1).
        local scanner = support.import_implementation_of(target, "scanner")
        if not scanner or not scanner.scan_dependency_for then
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