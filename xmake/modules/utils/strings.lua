function clean_template(str)
    str = str:gsub("^%\n", "")
    local indent = str:match("^([ \t]*)")
    if indent and #indent > 0 then
        str = str:gsub("\n" .. indent, "\n")
        str = str:gsub("^" .. indent, "")
    end
    str = str:gsub("[ \t]+\n", "\n")
    str = str:gsub("[ \t]+$", "")
    return str
end

