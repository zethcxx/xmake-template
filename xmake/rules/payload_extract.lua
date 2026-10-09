-- Extracts a section (or an address range within it) from a built binary.
--
-- By default it also emits the extracted bytes as a generated C/C++ header or
-- module, reusing embed_gen's writers.  With `only_gen_bin` it stops after
-- writing the raw .bin, leaving the choice of representation to embed_cxx
-- (hex, #embed or .incbin) -- see "Feeding the result to embed_cxx" below.
--
-- Configure one or more payloads with add_values("payload.cfg.<name>", {...}):
--
--     add_rules("payload_extract")
--     set_values("payload.cfg.code", {
--         mode         = "header",          -- "header"|"module"|"c"; ignored when
--                                            -- only_gen_bin is set
--         consteval    = true,              -- optional, C++ only, default false
--         namespace    = "boot",
--         section      = ".text",           -- section to dump (default ".text")
--         addr         = {0x100, 0x200},    -- optional crop offsets into the dump
--         strip        = true,              -- drop trailing fill bytes
--         align        = 16,                -- pad to alignment with fill_byte
--         fill_byte    = 0xFF,
--         only_gen_bin = true,              -- write just the .bin, no code
--         binfile      = "build/code.bin",  -- optional; where to put the .bin
--     })
--
-- The generated artifact is written into <targetdir>/include/<name>.<ext> and
-- that directory is added to the target includes, so dependents that list this
-- target via add_deps inherit it automatically.
--
-- Feeding the result to embed_cxx
--   Extraction happens in after_build, but embed_cxx generates in on_config, so
--   on a tree that has never been built there is no .bin yet to embed.  embed_cxx
--   already handles that: a group whose sources are missing is skipped and
--   retried on the next configure.  So the first build produces the .bin and a
--   second `xmake f` picks it up.  Point both rules at the same path:
--
--       set_values("payload.cfg.code", { section = ".text", only_gen_bin = true,
--                                        binfile = "build/gen/code.bin" })
--       set_values("embed.code", { mode = "header", namespace = "code",
--                                  incbin = true,
--                                  entries = { {"code", "build/gen/code.bin"} } })
--
--   Prefer binfile over the default location: the default sits next to the
--   linked binary, whose path is not knowable while writing xmake.lua.

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

-- Collects payload.cfg.<name> values (set via add_values) into an ordered list.
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

-- Where the extracted bytes land.  Defaults next to the linked binary, which is
-- only knowable once the target file path is; `binfile` lets the caller pin it to
-- something it can also reference from xmake.lua.
local function bin_path(target_file, name, cfg)
    if cfg.binfile then
        return path.absolute(cfg.binfile)
    end
    if not target_file then
        return nil
    end
    return path.join(path.directory(target_file), name .. ".bin")
end

-- Crops the dumped bytes to the configured address range.  `os` is passed in for
-- the same reason as in extract() below.
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

-- Strips trailing fill bytes.
local function strip_fill(data, fill_byte)
    local index = #data
    while index > 0 and data:byte(index) == fill_byte do
        index = index - 1
    end

    return data:sub(1, index)
end

-- Pads the data to the given alignment with fill_byte.
local function pad_align(data, align, fill_byte)
    local pad = (align - #data % align) % align
    if pad > 0 then
        data = data .. string.rep(string.char(fill_byte), pad)
    end

    return data
end

-- Dumps `section` with objcopy, applies the crop/strip/pad pipeline, and writes
-- the result back over bin_file so the bytes on disk are the ones asked for.
--
-- `os` and `io` are parameters rather than globals on purpose.  A rule file is
-- evaluated in a restricted environment where `os` and `io` are stripped down, and
-- a helper defined at file scope captures that environment, so `os.mkdir` and
-- `io.open` read back as nil inside it.  The hook bodies do get the full API, so
-- both are handed down from there instead.
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

    -- objcopy left the raw section in bin_file; the pipeline above is what the
    -- caller actually asked for, so persist it.  Without this only_gen_bin would
    -- silently hand out untrimmed bytes, since nothing else consumes `data`.
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
                -- No code to stub out, so nothing to register either.  Make sure
                -- the directory exists and publish the path, which is all a
                -- consumer needs to name the same file in its own config.
                local bin = cfg.binfile and path.absolute(cfg.binfile) or nil
                if bin then
                    os.mkdir(path.directory(bin))
                    target:values_set("payload.bin." .. name, bin)
                end
            elseif include_root then
                -- A zero-length placeholder, so dependents can #include this
                -- header before after_build has produced the real bytes.
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

