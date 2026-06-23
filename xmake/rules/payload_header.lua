function _format_hex(data)
    local parts = {}
    for i = 1, #data do
        parts[#parts + 1] = string.format("0x%02X", data:byte(i))
    end
    local lines = {}
    for i = 1, #parts, 16 do
        local chunk = table.concat(parts, ", ", i, math.min(i + 15, #parts))
        lines[#lines + 1] = "            " .. chunk
    end
    return table.concat(lines, ",\n")
end

function _write_file(outdir, basename, lang, data)
    local ext = lang == "c" and ".h" or ".hpp"
    local header = path.join(outdir, basename .. ext)
    local size = data and #data or 0
    local hexstr = size > 0 and _format_hex(data) or ""

    if lang == "c" then
        local body = size > 0 and ("\n" .. hexstr .. "\n") or ""
        io.writefile(header, string.format([[
#pragma once

unsigned char %s[] = {%s};
unsigned int %s_size = %d;
]], basename, body, basename, size))
    else
        local body = size > 0 and ("\n" .. hexstr .. "\n        ") or ""
        io.writefile(header, string.format([[
#pragma once

#include <array>
#include <cstddef>

namespace %s {
    consteval auto data() {
        constexpr std::array<unsigned char, %d> raw = {%s};
        return raw;
    }
    consteval std::size_t size() { return %d; }
}
]], basename, size, body, size))
    end
end

function main(target, outdir, basename, lang, data)
    _write_file(outdir, basename, lang, data)
end

function write_placeholder(target)
    local hdr = target:values("payload.header")
    if not hdr or #hdr == 0 then return end

    local lang = hdr[1] or "cxx"
    local relpath = hdr[2] or "generated/"
    relpath = relpath:gsub("%${root}", os.projectdir())

    local targetdir = target:targetdir()
    if targetdir then
        relpath = relpath:gsub("%${build}", targetdir)
    end

    local outdir = targetdir and path.join(targetdir, relpath)
    if not outdir then return end

    os.mkdir(outdir)
    if not os.isdir(outdir) then
        os.execv("mkdir", {"-p", outdir})
    end

    local basename = path.basename(target:values("payload.output") or target:name())
    _write_file(outdir, basename, lang, nil)
    target:values_set("payload.generated_dir", outdir)
end

function write_real(target, out, data)
    local hdr = target:values("payload.header")
    if not hdr or #hdr == 0 then return end

    local lang = hdr[1] or "cxx"
    local relpath = hdr[2] or "generated/"
    relpath = relpath:gsub("%${root}", os.projectdir())
    relpath = relpath:gsub("%${build}", path.directory(out))

    local outdir = path.join(path.directory(out), relpath)

    os.mkdir(outdir)
    if not os.isdir(outdir) then
        os.execv("mkdir", {"-p", outdir})
    end

    local basename = path.basename(out)
    _write_file(outdir, basename, lang, data)
    target:values_set("payload.generated_dir", outdir)
end
