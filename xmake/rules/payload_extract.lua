-- Extract a section (or address range) from a built binary.
--
--   add_rules("payload_extract")
--   set_values("payload.cfg.<name>", {
--       mode         = "header",   -- "header" (default) | "module" | "c"
--       section      = ".text",    -- section to dump
--       addr         = nil,        -- { start, end } byte range into the dump
--       strip        = false,      -- drop trailing fill bytes
--       align        = nil,        -- pad to this size with fill_byte
--       fill_byte    = 0x00,       -- byte used to strip/pad
--       only_gen_bin = false,      -- write only the raw .bin
--       binfile      = nil,        -- .bin path (default next to the target)
--       namespace    = nil,        -- C++ only
--       consteval    = false,      -- C++ only
--   })
--
-- All keys are optional. Generated code goes to <targetdir>/include and is
-- reused via embed_gen. With only_gen_bin, pair it with embed_cxx to choose the
-- final representation.

local PREFIX = "payload.cfg."

local function build_opts(cfg)
    return {
        mode      = cfg.mode or "header",
        lang      = cfg.mode == "c" and "c" or "cxx",
        consteval = cfg.consteval == true,
        namespace = cfg.namespace,
    }
end

local function artifact_ext(cfg)
    if cfg.mode == "c" then
        return ".h"
    elseif cfg.mode == "module" then
        return ".cppm"
    end

    return ".hpp"
end

local function output_location(target)
    local target_dir = target:targetdir()
    if not target_dir then
        return nil
    end
    return path.join(target_dir, "include")
end

local function collect_payloads(target)
    local configs = {}

    local all = target:get("values")
    if type(all) ~= "table" then
        return configs
    end

    for key, cfg in pairs(all) do
        if type(key) == "string" and key:sub(1, #PREFIX) == PREFIX and type(cfg) == "table" then
            local name = key:sub(#PREFIX + 1)
            if name ~= "" then
                configs[#configs + 1] = {name, cfg}
            end
        end
    end

    table.sort(configs, function(a, b) return a[1] < b[1] end)

    return configs
end

local function register_artifact(target, include_root, cfg, name)
    target:add("includedirs", include_root, {interface = true})
    target:values_set("payload.generated_dir", include_root)

    local artifact = path.join(include_root, name .. artifact_ext(cfg))
    if cfg.mode == "module" then
        target:add("files", artifact)
    else
        target:add("headerfiles", artifact)
    end
end

-- Defaults next to the linked binary; binfile pins a path usable from xmake.lua.
local function bin_path(target_file, name, cfg)
    if cfg.binfile then
        return path.absolute(cfg.binfile)
    end
    if not target_file then
        return nil
    end
    return path.join(path.directory(target_file), name .. ".bin")
end

local function apply_addr_range(os, data, addr)
    if not addr then
        return data
    end

    local start_offset, end_offset = addr[1], addr[2]
    if not start_offset or not end_offset then
        os.raise("payload_extract: 'addr' must be {start, end}")
    end

    if start_offset > #data then
        return ""
    end

    return data:sub(start_offset + 1, math.min(end_offset, #data))
end

local function strip_fill(data, fill_byte)
    local index = #data
    while index > 0 and data:byte(index) == fill_byte do
        index = index - 1
    end

    return data:sub(1, index)
end

local function pad_align(data, align, fill_byte)
    local pad = (align - #data % align) % align
    if pad > 0 then
        data = data .. string.rep(string.char(fill_byte), pad)
    end

    return data
end

-- Dumps a section with objcopy, applies crop/strip/pad, and rewrites the .bin.
-- os/io are passed in because file-scope helpers see a restricted environment.
local function extract(os, io, objcopy, target_file, bin_file, cfg)
    os.mkdir(path.directory(bin_file))
    os.execv(objcopy, {
        "--dump-section", (cfg.section or ".text") .. "=" .. bin_file,
        target_file,
    })

    local handle = io.open(bin_file, "rb")
    if not handle then
        os.raise("payload_extract: objcopy did not produce %s", bin_file)
    end
    local data = handle:read("*all")
    handle:close()
    if not data then
        os.raise("payload_extract: unable to read %s", bin_file)
    end

    data = apply_addr_range(os, data, cfg.addr)
    if cfg.strip then
        data = strip_fill(data, cfg.fill_byte or 0x00)
    end
    if cfg.align and cfg.align > 1 then
        data = pad_align(data, cfg.align, cfg.fill_byte or 0x00)
    end

    -- Persist the cropped/padded bytes overwriting objcopy's raw section dump.
    local out = io.open(bin_file, "wb")
    if not out then
        os.raise("payload_extract: unable to rewrite %s", bin_file)
    end
    out:write(data)
    out:close()

    return data
end

rule("payload_extract")
    on_config(function(target)
        if target:values("payload.objcopy") == nil then
            local tool = import("lib.detect.find_tool")
            local found = tool("llvm-objcopy") or tool("objcopy") or tool("gobjcopy")
            target:values_set("payload.objcopy", found and found.program or "llvm-objcopy")
        end

        target:set("policy", "build.fence", true)

        local include_root = output_location(target)
        for _, item in ipairs(collect_payloads(target)) do
            local name, cfg = item[1], item[2]
            if cfg.only_gen_bin then
                local bin = cfg.binfile and path.absolute(cfg.binfile) or nil
                if bin then
                    os.mkdir(path.directory(bin))
                    target:values_set("payload.bin." .. name, bin)
                end
            elseif include_root then
                -- Zero-length placeholder until after_build writes the real bytes.
                import("embed_gen").write_file(include_root, name, build_opts(cfg), nil)
                register_artifact(target, include_root, cfg, name)
            end
        end
    end)

    after_build(function(target)
        local target_file = target:targetfile()
        if not target_file or not os.isfile(target_file) then
            return
        end

        local objcopy = target:values("payload.objcopy")
        local include_root = output_location(target)

        for _, item in ipairs(collect_payloads(target)) do
            local name, cfg = item[1], item[2]
            local bin = bin_path(target_file, name, cfg)
            local data = extract(os, io, objcopy, target_file, bin, cfg)

            if cfg.only_gen_bin then
                target:values_set("payload.bin." .. name, bin)
            elseif include_root then
                import("embed_gen").write_file(include_root, name, build_opts(cfg), data)
                register_artifact(target, include_root, cfg, name)
            end
        end
    end)

