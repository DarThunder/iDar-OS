local bit32 = require("bit32")
local math = require("math")

local fcntl = {}

fcntl.O_RDONLY = 0x00
fcntl.O_WRONLY = 0x01
fcntl.O_RDWR   = 0x02
fcntl.O_CREAT  = 0x40
fcntl.O_TRUNC  = 0x200
fcntl.O_APPEND = 0x400
fcntl.O_BINARY = 0x800

local function flags_to_mode(flags)
    local can_write = (bit32.band(flags, fcntl.O_WRONLY) > 0) or (bit32.band(flags, fcntl.O_RDWR) > 0)
    local append = (bit32.band(flags, fcntl.O_APPEND) > 0)
    local is_binary = (bit32.band(flags, fcntl.O_BINARY) > 0)

    local mode = "r"
    if append then mode = "a"
    elseif can_write then mode = "w" end

    if is_binary then mode = mode .. "b" end

    return mode
end

function fcntl.open(path, flags)
    local lua_mode = flags_to_mode(flags or fcntl.O_RDONLY)
    local fd = coroutine.yield({0x01, 0x02, path, lua_mode})
    return fd
end

return fcntl