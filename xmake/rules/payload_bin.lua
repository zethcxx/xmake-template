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

        import("payload_header").write_placeholder(target)
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
            local f = io.open(out, "rb")
            if f then
                local data = f:read("*all")
                f:close()
                import("payload_header").write_real(target, out, data)
            end
        end
    end)
