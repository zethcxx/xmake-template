-- Fetch data/ and assets/ from a release bundle when they are not present.
--
-- The heavy payload (prebuilt emojis/glyphs/lang .dat + the Noto colour font)
-- ships as one GitHub Release asset instead of being committed: the repo stays
-- small, and data updates never cost a git commit.  This rule mirrors the
-- bundle on demand during the configure step:
--
--   * all required files present -> no-op (the common case)
--   * anything missing           -> download the latest bundle and unpack it
--   * refresh after upstream set -> rm -rf data assets && xmake f
--
-- The asset is reached through the stable "releases/latest/download" URL, so
-- re-running scripts/make-bundle.pl --push against a new release is enough.
--
-- A target opts in with:
--
--     add_rules("bundle.fetch")
--     set_values("bundle.entries", bundle.fetch {
--         url   = "https://github.com/zethcxx/emoji-picker/releases/latest/download/emoji-picker-bundle.tar.gz",
--         dest  = ".",
--         check = { "data/emojis.dat", "assets/fonts/NotoColorEmoji.ttf" },
--     })
--
-- bundle.fetch(...) validates one entry (or a list of entries) and returns the
-- tables verbatim -- no string serialization, unlike the perl rule, because no
-- subprocess needs them.  The on_load hook then delegates to the lang.bundle
-- engine, which downloads on demand, strips/selects archive members and
-- verifies an optional sha256 digest.  Using a local path as the url (offline
-- builds, tests) behaves exactly like the public release asset.

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

-- Validates one entry (or a list of entries) and always returns a list, ready
-- for set_values("bundle.entries", ...).
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