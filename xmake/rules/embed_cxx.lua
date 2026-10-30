-- Embed static files as C++ or C.
--
--   add_rules("embed_cxx")
--   set_values("embed.<id>", {
--       mode        = "header",   -- "header" (default) | "module" | "c-header"
--       module      = nil,        -- module name; "module" mode only (default "embed.<id>")
--       namespace   = nil,        -- C++ only
--       consteval   = false,      -- C++ only; consteval accessors instead of arrays
--       incbin      = false,      -- copy via the assembler (.incbin)
--       embed_macro = false,      -- copy via #embed
--       entries     = { { "name", "path/to/file" }, ... },  -- required
--       output      = nil,        -- output file name
--       outdir      = nil,        -- output directory
--       asm         = nil,        -- assembler file name; incbin only
--   })
--
-- All keys are optional except entries. incbin and embed_macro are mutually
-- exclusive; incbin cannot be combined with consteval; module mode rejects
-- embed_macro.
rule("embed_cxx")
    on_config(function(target)
        import("embed_gen").generate(target)
    end)
