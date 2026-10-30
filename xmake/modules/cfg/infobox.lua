-- Shared "pinfo" info-box renderer.
-- Items: {label, value}, {label, list}, {label, value, children}, or raw string.

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

