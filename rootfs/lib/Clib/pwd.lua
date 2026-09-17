local stdio = require("Clib.stdio")
local textutils = require("textutils")

local pwd = {}

function pwd.getpwuid(target_uid)
    local passwd_file = stdio.open("/etc/passwd", "r")
    if not passwd_file then return nil end

    local content = passwd_file:read_all()
    passwd_file:close()

    if not content or content == "" then return nil end

    local passwd_data = textutils.unserialize(content) or {}

    for username, uinfo in pairs(passwd_data) do
        if uinfo.uid == target_uid then
            return {
                name = username,
                uid = uinfo.uid,
                home = uinfo.home or ("/" .. username)
            }
        end
    end

    return nil
end

function pwd.getpwnam(target_username)
    local passwd_file = stdio.open("/etc/passwd", "r")
    if not passwd_file then return nil end

    local content = passwd_file:read_all()
    passwd_file:close()

    local passwd_data = textutils.unserialize(content) or {}
    local uinfo = passwd_data[target_username]

    if uinfo then
        return {
            name = target_username,
            uid = uinfo.uid,
            home = uinfo.home or ("/" .. target_username)
        }
    end
    return nil
end

return pwd