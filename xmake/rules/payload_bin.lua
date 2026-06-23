rule("payload_bin")
    on_config(function(target)
        local defaults = {
            ["payload.copy"] = true,
        }
        for key, val in pairs(defaults) do
            if target:values(key) == nil then
                target:values_set(key, val)
            end
        end
    end)

    after_build(function(target)
        if not target:values("payload.copy") then
            return
        end

        local targetfile = target:targetfile()
        if not targetfile or not os.isfile(targetfile) then
            return
        end

        local binname = target:values("payload.output") or (path.basename(targetfile) .. ".bin")
        local out = path.join(path.directory(targetfile), binname)

        os.cp(targetfile, out)

        local hdr = target:values("payload.header")
        if hdr and #hdr > 0 then
            local lang = hdr[1] or "cxx"
            local relpath = hdr[2] or "generated/"
            relpath = relpath:gsub("%${root}", os.projectdir())
            relpath = relpath:gsub("%${build}", path.directory(out))

            local outdir = path.join(path.directory(out), relpath)
            if is_host("windows") then
                os.execv("cmd.exe", {"/c", "mkdir \"" .. outdir .. "\""})
            else
                os.execv("mkdir", {"-p", outdir})
            end

            local basename = path.basename(out)
            local ext = lang == "c" and ".h" or ".hpp"
            local header = path.join(outdir, basename .. ext)

            local f = io.open(out, "rb")
            if f then
                local data = f:read("*all")
                f:close()

                local hex = {}
                for i = 1, #data do
                    hex[#hex + 1] = string.format("0x%02X", data:byte(i))
                end
                local hexstr = table.concat(hex, ", ")

                if lang == "c" then
                    io.writefile(header, string.format([[
#pragma once

unsigned char %s[] = { %s };
unsigned int %s_size = %d;
]], basename, hexstr, basename, #data))
                else
                    io.writefile(header, string.format([[
#pragma once

#include <array>
#include <cstddef>

namespace %s {
    consteval auto data() {
        constexpr std::array<unsigned char, %d> raw = { %s };
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
