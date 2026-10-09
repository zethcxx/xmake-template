-- Reusable "pinfo" info-box renderer. Any target kind (C/C++, perl, python,
-- tcl, ...) can build a list of key/value items -- or fully custom lines --
-- and this module draws the whole bordered box, so every target shares a
-- single format.
--
--   cfg.infobox.render("gen-data", "scripts/gen-emoji.pl", {
--       {label = "perl",   value = "v5.42.3 (/usr/bin/perl)"},
--   {label = "script", value = "scripts/gen-emoji.pl", children = {
--       {label = "root", value = "scripts"},
--       {label = "args", list  = {"--output", "../data/emojis.dat"}},
--   }},
--       "${bright}    a fully custom line${clear}",
--   })
--
-- Item shapes:
--   * {label = L, value = V}                 key/value line
--   * {label = L, list  = {...}}             key + one numbered line per list item
--   * {label = L, value = V, children = {...}}  key/value + nested sub-items (deeper indent)
--   * "string"                               raw custom line (caller controls colors and padding)

local function render_group(entries, indent)
    local w = 0
    for _, e in ipairs(entries) do
        if type(e) == "table" and e.label then
            w = math.max(w, #e.label)
        end
    end

    for _, e in ipairs(entries) do
        if type(e) == "string" then
            cprint("${white}│${#223}" .. e)
        elseif e.list then
            cprint("${white}│${#223}" .. string.rep(" ", indent) .. ("%-" .. w .. "s :"), e.label)
            for i, item in ipairs(e.list) do
                cprint("${white}│${#223}" .. string.rep(" ", indent) .. ("    [%d]: ${white}%s"):format(i - 1, tostring(item)))
            end
        elseif e.label then
            cprint("${white}│${#223}" .. string.rep(" ", indent) .. ("%-" .. w .. "s : ${white}%s"), e.label, e.value or "")
            if e.children then
                render_group(e.children, indent + 4)
            end
        end
    end
end

function render(name, subtitle, entries)
    cprint("${white}┌${#216}[ ${bright}%s${reset}${#216}: %s ]", name, subtitle or "")
    render_group(entries or {}, 4)
    cprint("${white}└─${clear}")
end

