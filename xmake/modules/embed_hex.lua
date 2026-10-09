-- Hex encoding for byte-array generation.
--
-- Produces "0xNN" tokens, 16 per line, comma-separated, with configurable
-- leading indent.  Empty input yields "".
--
-- Separators are emitted *before* each token instead of after it, so the final
-- element never carries a dangling comma and no line ends in trailing
-- whitespace.  (Writing them after the token leaves the last one as ", ".)
-- The comma that separates two lines is written ahead of the newline, since
-- a line break is not a separator by itself.
--
-- The in-memory and streaming entry points used to be separate implementations
-- and they disagreed on the trailing separator; the tokenizer below is now the
-- only one.

local PER_LINE = 16

-- Byte -> "0xNN" lookup table, built once.
local _byte_to_hex
local function byte_to_hex()
    if not _byte_to_hex then
        _byte_to_hex = {}
        for byte_value = 0, 255 do
            _byte_to_hex[string.char(byte_value)] = string.format("0x%02X", byte_value)
        end
    end
    return _byte_to_hex
end

-- Writes the tokens for `data`, wrapping every PER_LINE bytes.  `column` and
-- `started` carry the line state so a caller feeding several buffers in a row
-- resumes on the same line.  Returns the new state.
local function write_bytes(write, data, indent, column, started)
    local lookup = byte_to_hex()
    for index = 1, #data do
        if column == 0 then
            -- Opening a line.  Anything already written is a complete element
            -- that still needs its separating comma, so close it before the
            -- newline; the very first line has no predecessor to close.
            if started then
                write(",\n" .. indent)
            else
                write(indent)
                started = true
            end
        else
            write(", ")
        end
        write(lookup[data:sub(index, index)])
        column = column + 1
        if column == PER_LINE then
            column = 0
        end
    end
    return column, started
end

-- Builds hex-array text from raw bytes in memory.
function hex_body(data, indent)
    local parts = {}
    write_bytes(function(s) parts[#parts + 1] = s end, data, indent or "            ", 0, false)
    return table.concat(parts)
end
