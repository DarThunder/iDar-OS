local unistd = require("Clib.unistd")

local stdlib = {}

function stdlib.getenv(key)
    if not _G.__environ then return nil end

    return _G.__environ[key]
end

function stdlib.setenv(key, value)
    if not _G.__environ then return nil end

    _G.__environ[key] = tostring(value)

    return 0
end

function stdlib.unsetenv(key)
    if _G.__environ then
        _G.__environ[key] = nil
    end

    return 0
end

function stdlib.system(command, options, ...)
    local child_pid = unistd.execve(command, options, ...)

    if child_pid then
        unistd.assign_tty(child_pid)
        unistd.wait(child_pid)
        unistd.assign_tty(unistd.getpid())

        return 0
    end

    return child_pid
end

function stdlib.exit(exit_code)
    unistd.exit(exit_code)
end

function stdlib.parse_args(args, expects_value, known_flags, idx)
    expects_value = expects_value or {}
    known_flags = known_flags or {}
    local flags = {}
    local pos_args = {}

    local i = idx or 1
    local parsing_flags = true

    while i <= #args do
        local arg = args[i]

        if parsing_flags and arg == "--" then
            parsing_flags = false
            i = i + 1
        elseif parsing_flags and arg:sub(1, 2) == "--" and #arg > 2 then
            local key, val = arg:match("^%-%-([^=]+)=(.*)$")
            if key then
                flags[key] = val
            else
                local flag_name = arg:sub(3)
                if expects_value["--" .. flag_name] or expects_value[flag_name] then
                    i = i + 1
                    flags[flag_name] = args[i] or true
                else
                    flags[flag_name] = true
                end
            end
            i = i + 1
        elseif parsing_flags and arg:sub(1, 1) == "-" and #arg > 1 then
            local name = arg:sub(2)
            if expects_value[arg] or expects_value[name] then
                i = i + 1
                flags[name] = args[i]
            elseif known_flags[name] then
                flags[name] = true
            else
                for c = 2, #arg do
                    flags[arg:sub(c, c)] = true
                end
            end
            i = i + 1
        else
            table.insert(pos_args, arg)
            i = i + 1
        end
    end

    return flags, pos_args
end

return stdlib