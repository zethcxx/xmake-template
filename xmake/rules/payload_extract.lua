rule("payload_extract")
    on_config(function(target)
        if target:values("payload.objcopy") == nil then
            local triple = import("cfg.triple").get(target)
            local find_program = import("lib.detect.find_program")

            local objcopy
            if triple and triple.abi == "msvc" then
                -- PE/COFF: prefer llvm-objcopy (GNU objcopy can't dump custom sections)
                objcopy = find_program("llvm-objcopy")
                    or find_program("objcopy")
                    or find_program("gobjcopy")
                    or "llvm-objcopy"
            else
                -- ELF: any objcopy works
                objcopy = find_program("objcopy")
                    or find_program("gobjcopy")
                    or "objcopy"
            end
            target:values_set("payload.objcopy", objcopy)
        end
        local defaults = {
            ["payload.extract"]      = true,
            ["payload.section"]      = ".text",
            ["freestanding"] = true,
        }
        for key, val in pairs(defaults) do
            if target:values(key) == nil then
                target:values_set(key, val)
            end
        end

        import("payload_header").write_placeholder(target)
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
            local f = io.open(out, "rb")
            if f then
                local data = f:read("*all")
                f:close()
                import("payload_header").write_real(target, out, data)
            end
        end
    end)

