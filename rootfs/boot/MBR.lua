local function lz77_decompress(input)
    local out = ""
    local i = 1
    local len = #input
    while i <= len do
        local next_idx = string.find(input, "\255", i, true)
        if not next_idx then
            out = out .. string.sub(input, i)
            break
        end

        out = out .. string.sub(input, i, next_idx - 1)
        local next_c = string.byte(input, next_idx + 1)

        if next_c == 0 then
            out = out .. "\255"
            i = next_idx + 2
        else
            local m_len, d_hi, d_lo = string.byte(input, next_idx + 1, next_idx + 3)
            local dist = (d_hi * 256) + d_lo
            local start_idx = #out - dist + 1
            out = out .. string.sub(out, start_idx, start_idx + m_len - 1)
            i = next_idx + 4
        end
    end
    return out
end

local handle = fs.open("/iDar/boot/vmloomz", "rb")
if not handle then error("MBR: Failed to load /boot/vmloomz") end
local content = handle.readAll()
handle.close()

local kernel_source = content
if string.sub(content, 1, 4) == "\27LZ7" then
    kernel_source = lz77_decompress(string.sub(content, 5))
end

if not _G.package then
    _G.package = {
        preload = {},
        loaded = {}
    }
end

if not _G.require then
    _G.require = function(mod_name)
        if _G.package.loaded[mod_name] then
            return _G.package.loaded[mod_name]
        end

        local loader = _G.package.preload[mod_name]
        if not loader then
            error("MBR Module Loader: module '" .. tostring(mod_name) .. "' not found in bundle", 2)
        end

        local result = loader(mod_name)
        if result == nil then
            result = true
        end

        _G.package.loaded[mod_name] = result
        return result
    end
end

local kernel_init, err = load(kernel_source, "loom.img", "t")
if not kernel_init then error("MBR Kernel Panic: " .. tostring(err)) end

local loom = kernel_init()

loom.launch("/boot/init")

term.clear()
term.setCursorPos(1, 1)

loom.execute()