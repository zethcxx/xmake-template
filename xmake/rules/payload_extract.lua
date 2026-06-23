rule("payload_extract")
    on_config(function(target)
        if target:values("payload.objcopy") == nil then
            local tool = import("lib.detect.find_tool")
            local found = tool("llvm-objcopy") or tool("objcopy") or tool("gobjcopy")
            target:values_set("payload.objcopy", found and found.program or "llvm-objcopy")
        end
        local defaults = {
            ["payload.extract"]      = true,
            ["payload.section"]      = ".text",
            ["payload.freestanding"] = true,
        }
        for key, val in pairs(defaults) do
            if target:values(key) == nil then
                target:values_set(key, val)
            end
        end
    end)

    after_build(function(target)
        if not target:values("payload.extract") then
            return
        end

        local section = target:values("payload.section") or ".text"
        local targetfile = target:targetfile()
        if not targetfile or not os.isfile(targetfile) then
            return
        end

        local objcopy = target:values("payload.objcopy")

        local binname = target:values("payload.output") or (path.basename(targetfile) .. ".bin")
        local out = path.join(path.directory(targetfile), binname)

        os.execv(objcopy, {
            "--dump-section", section .. "=" .. out,
            targetfile
        })

        -- Strip trailing fill bytes before applying alignment
        if target:values("payload.strip") then
            local f = io.open(out, "rb")
            if f then
                local data = f:read("*all")
                f:close()
                local fill = target:values("payload.fill_byte") or 0x00
                local i = #data
                while i > 0 and data:byte(i) == fill do
                    i = i - 1
                end
                if i < #data then
                    local f = io.open(out, "wb")
                    if f then
                        f:write(data:sub(1, i))
                        f:close()
                    end
                end
            end
        end

        local align = target:values("payload.align")
        if align and align > 1 then
            local f = io.open(out, "rb")
            if not f then return end
            local data = f:read("*all")
            f:close()

            local fill = target:values("payload.fill_byte") or 0x00
            local pad = (align - #data % align) % align
            if pad > 0 then
                local f = io.open(out, "ab")
                if f then
                    f:write(string.rep(string.char(fill), pad))
                    f:close()
                end
            end
        end

        local hdr = target:values("payload.header")
        if hdr and #hdr > 0 then
            local lang = hdr[1] or "cxx"
            local relpath = hdr[2] or "generated/"
            relpath = relpath:gsub("%${root}", os.projectdir())
            relpath = relpath:gsub("%${build}", path.directory(out))

            local outdir = path.join(path.directory(out), relpath)
            os.mkdir(outdir)

            local basename = path.basename(out)
            local ext = lang == "c" and ".h" or ".hpp"
            local header = path.join(outdir, basename .. ext)

            local f = io.open(out, "rb")
            if f then
                local data = f:read("*all")
                f:close()

            local parts = {}
            for i = 1, #data do
                parts[#parts + 1] = string.format("0x%02X", data:byte(i))
            end
            local lines = {}
            for i = 1, #parts, 16 do
                local chunk = table.concat(parts, ", ", i, math.min(i + 11, #parts))
                lines[#lines + 1] = "            " .. chunk
            end
            local hexstr = table.concat(lines, ",\n")

                if lang == "c" then
                    io.writefile(header, string.format([[
#pragma once

unsigned char %s[] = {
%s
};
unsigned int %s_size = %d;
]], basename, hexstr, basename, #data))
                else
                    io.writefile(header, string.format([[
#pragma once

#include <array>
#include <cstddef>

namespace %s {
    consteval auto data() {
        constexpr std::array<unsigned char, %d> raw = {
%s
        };
        return raw;
    }
    consteval std::size_t size() { return %d; }
}
]], basename, #data, hexstr, #data))
                end

                target:values_set("payload.generated_dir", outdir)
            end
        end
    end)

