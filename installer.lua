local SYS_ROOT = "/iDar"
local IMAGE_URL = "https://github.com/DarThunder/iDar-OS/raw/refs/heads/main/images/rootfs.dmb"

local function unpack_u16(s, p) return (s:byte(p) * 256) + s:byte(p + 1), p + 2 end
local function unpack_u32(s, p)
    return (s:byte(p) * 16777216) + (s:byte(p + 1) * 65536) + (s:byte(p + 2) * 256) + s:byte(p + 3), p + 4
end

local function dmb_decompress(input)
    if not input or input:sub(1, 4) ~= "\27LZ7" then return nil end
    local out, out_len, i, len = {}, 0, 5, #input
    while i <= len do
        local c = input:sub(i, i)
        if c == "\255" then
            local next_c = input:sub(i + 1, i + 1)
            if next_c == "\0" then
                out_len = out_len + 1
                out[out_len] = "\255"
                i = i + 2
            else
                local match_len = next_c:byte()
                local dist = input:byte(i + 2) * 256 + input:byte(i + 3)
                local start_idx = out_len - dist + 1
                for j = 0, match_len - 1 do
                    out_len = out_len + 1
                    out[out_len] = out[start_idx + j]
                end
                i = i + 4
            end
        else
            out_len = out_len + 1
            out[out_len] = c
            i = i + 1
        end
    end
    return table.concat(out, "", 1, out_len)
end

local function dmb_extract(dmb_buffer, dest_root)
    local raw = dmb_decompress(dmb_buffer)
    if not raw or raw:sub(1, 4) ~= "IDMB" then return false end

    local total_files, pos = unpack_u16(raw, 5)
    for _ = 1, total_files do
        local path_len
        path_len, pos = unpack_u16(raw, pos)
        local rel_path = raw:sub(pos, pos + path_len - 1)
        pos = pos + path_len

        local file_size
        file_size, pos = unpack_u32(raw, pos)
        local content = raw:sub(pos, pos + file_size - 1)
        pos = pos + file_size

        local out_target = fs.combine(dest_root, rel_path)
        local folder = fs.getDir(out_target)
        if not fs.exists(folder) then fs.makeDir(folder) end

        local f = fs.open(out_target, "wb")
        if f then
            f.write(content)
            f.close()
        end
    end
    return true
end

print("-----------------------------------------")
print(" Instalador Base de iDar OS")
print("-----------------------------------------")

if not http then
    print("ERROR: Se requiere conexión HTTP.")
    return
end

print(":: Descargando imagen base del sistema...")
local res = http.get(IMAGE_URL, nil, true)
if not res or res.getResponseCode() ~= 200 then
    if res then res.close() end
    print("ERROR: Fallo al descargar rootfs.dmb")
    return
end

local raw_image = res.readAll()
res.close()

print(string.format(":: Desempaquetando imagen (%d bytes)...", #raw_image))
if not fs.exists(SYS_ROOT) then fs.makeDir(SYS_ROOT) end

if not dmb_extract(raw_image, SYS_ROOT) then
    print("ERROR: Imagen .dmb corrupta o inválida.")
    fs.delete(SYS_ROOT)
    return
end

print(":: Configurando MBR...")
local mbr = fs.open("startup.lua", "w")
mbr.write('local boot = require("iDar.boot.MBR")\n')
mbr.close()

local running_prog = fs.getName(shell.getRunningProgram())
if running_prog ~= "startup.lua" and fs.exists(running_prog) then
    fs.delete(running_prog)
end

print("-----------------------------------------")
print(" ¡Sistema desplegado con éxito!")
print(" Reinicia para arrancar iDar OS.")
print("-----------------------------------------")