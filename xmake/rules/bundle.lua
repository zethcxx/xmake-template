-- Fetch release data/assets when missing.
--
--   add_rules("bundle.fetch")
--   set_values("bundle.entries", bundle.fetch {
--       url          = "...",      -- required; local path or URL
--       dest         = ".",        -- required; extraction directory
--       check        = { "data/x.dat" },  -- required; files that must exist
--       kind         = nil,        -- "file" | "archive" (default: from url)
--       strip        = nil,        -- leading path components to strip
--       only         = nil,        -- extract only these members
--       marker       = nil,        -- extra marker file
--       sha256       = nil,        -- expected 64-char hex digest
--       auth         = nil,        -- only "gh"
--       check_strict = false,      -- require every check entry
--   })
--
-- Accepts one table or a list of tables. Download and verification are
-- delegated to lang.bundle.

bundle = bundle or {}

local _fields = {"url", "dest", "check", "kind", "strip", "only", "marker", "sha256", "auth", "check_strict"}
local _fieldset = {}
for _, name in ipairs(_fields) do
    _fieldset[name] = true
end

local function _valid_fields()
    return table.concat(_fields, ", ")
end

local function _string(cfg, where, name, required)
    local v = cfg[name]
    if v == nil then
        if required then
            raise("%s: missing required field '%s'", where, name)
        end
        return nil
    end
    if type(v) ~= "string" or v == "" then
        raise("%s: '%s' must be a non-empty string, got %s", where, name, type(v))
    end
    return v
end

local function _string_list(cfg, where, name, required)
    local v = cfg[name]
    if v == nil then
        if required then
            raise("%s: missing required field '%s'", where, name)
        end
        return nil
    end
    if type(v) == "string" then
        return {v}
    end
    if type(v) ~= "table" then
        raise("%s: '%s' must be a string or a list of strings, got %s", where, name, type(v))
    end
    local out = {}
    for i, item in ipairs(v) do
        if type(item) ~= "string" then
            raise("%s: '%s[%d]' must be a string, got %s", where, name, i, type(item))
        end
        out[i] = item
    end
    if #out == 0 then
        raise("%s: '%s' must not be empty", where, name)
    end
    return out
end

local function _validate(cfg, idx)
    local where = string.format("bundle.fetch[%d]", idx)
    if type(cfg) ~= "table" or cfg[1] ~= nil then
        raise("%s: expected a {...} table with fields", where)
    end
    for key in pairs(cfg) do
        if not _fieldset[key] then
            raise("%s: unknown field '%s' (valid: %s)", where, key, _valid_fields())
        end
    end

    local entry = {}
    entry.url   = _string(cfg, where, "url",   true)
    entry.dest  = _string(cfg, where, "dest",  true)
    entry.check = _string_list(cfg, where, "check", true)

    local kind = cfg.kind
    if kind ~= nil and kind ~= "file" and kind ~= "archive" then
        raise("%s: 'kind' must be \"file\" or \"archive\", got %s", where, tostring(kind))
    end
    if kind then
        entry.kind = kind
    end

    local strip = cfg.strip
    if strip ~= nil then
        if type(strip) == "string" then
            strip = tonumber(strip)
        end
        if type(strip) ~= "number" or strip < 0 or strip % 1 ~= 0 then
            raise("%s: 'strip' must be a non-negative integer", where)
        end
        entry.strip = strip
    end

    local only = cfg.only
    if only ~= nil then
        entry.only = _string_list(cfg, where, "only", false)
    end

    local marker = _string(cfg, where, "marker", false)
    if marker then
        entry.marker = marker
    end

    local sha256 = _string(cfg, where, "sha256", false)
    if sha256 then
        if not sha256:match("^[%x]+$") or #sha256 ~= 64 then
            raise("%s: 'sha256' must be a 64-character hex digest", where)
        end
        entry.sha256 = sha256
    end

    local auth = _string(cfg, where, "auth", false)
    if auth then
        if auth ~= "gh" then
            raise("%s: 'auth' must be \"gh\", got %s", where, auth)
        end
        entry.auth = auth
    end

    local check_strict = cfg["check_strict"]
    if check_strict ~= nil then
        if type(check_strict) ~= "boolean" then
            raise("%s: 'check_strict' must be a boolean, got %s", where, type(check_strict))
        end
        entry.check_strict = check_strict
    end
    return entry
end

function bundle.fetch(cfg)
    local entries = {}
    if type(cfg) == "table" and cfg[1] ~= nil then
        for i, c in ipairs(cfg) do
            entries[i] = _validate(c, i)
        end
    else
        entries[1] = _validate(cfg, 1)
    end
    return entries
end

rule("bundle.fetch")
    on_load(function (target)
        local bundle = import("lang.bundle")
        bundle.fetch_missing(target)
    end)