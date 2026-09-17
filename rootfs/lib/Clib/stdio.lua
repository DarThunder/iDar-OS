local unistd = require("Clib.unistd")
local fcntl = require("Clib.fcntl")
local keys = require("keys")
local math = require("math")
local string = require("string")

local io = {}

io.colors = {
    white = "\27[37m", orange = "\27[33m", magenta = "\27[35m",
    lightBlue = "\27[36m", yellow = "\27[33m", lime = "\27[32m",
    pink = "\27[35m", gray = "\27[90m", lightGray = "\27[37m",
    cyan = "\27[36m", purple = "\27[35m", blue = "\27[34m",
    brown = "\27[33m", green = "\27[32m", red = "\27[31m",
    black = "\27[30m", reset = "\27[0m"
}

local err_strings = {
    [1]  = "Operation not permitted",
    [2]  = "No such file or directory",
    [5]  = "I/O error",
    [9]  = "Bad file descriptor",
    [13] = "Permission denied",
    [17] = "File exists",
    [20] = "Not a directory",
    [22] = "Invalid argument",
    [38] = "Function not implemented"
}

local mode_flags = {
    w = fcntl.O_WRONLY,
    r = fcntl.O_RDONLY,
    a = fcntl.O_APPEND,
    wb = fcntl.O_WRONLY + fcntl.O_BINARY,
    rb = fcntl.O_RDONLY + fcntl.O_BINARY,
    ab = fcntl.O_APPEND + fcntl.O_BINARY
}

local function get_err_str(code)
    if not code then return "Unknown error" end
    code = math.abs(code)
    return err_strings[code] or ("Unknown error code (" .. tostring(code) .. ")")
end

local function stdout_write(str)
    unistd.write(1, str)
end

function io.write(str)
    stdout_write(tostring(str))
end

function io.print(...)
    local args = table.pack(...)
    local output = {}
    for i = 1, args.n do
        table.insert(output, tostring(args[i]))
    end
    stdout_write(table.concat(output, "\t") .. "\n")
end

function io.read(prompt_text, prompt_color, history_table, completion_fn, replace_char)
    completion_fn = completion_fn or function(_) end
    history_table = history_table or {}
    local input = ""
    local cursor_pos = 1
    local ctrl_held = false
    local history_index = #history_table + 1
    local draft_input = ""

    if replace_char ~= " " then
        stdout_write("\27[?25h")
    end

    stdout_write("\27[s")

    local function redraw()
        local display_input = input
        if replace_char then display_input = string.rep(replace_char, #input) end

        stdout_write("\27[u\27[0J")
        local p_color = prompt_color or io.colors.yellow
        stdout_write(p_color .. prompt_text)
        stdout_write(io.colors.white .. display_input)

        local move_back = #input - cursor_pos + 1
        if move_back > 0 then
            stdout_write("\27[" .. move_back .. "D")
        end
    end

    redraw()

    while true do
        local params = unistd.read(0)

        if type(params) ~= "table" and params < 0 then
            coroutine.yield({0x03, 0.1})
        else
            local event = params[1]
            local param = params[2]
            local needs_draw = false

            if event == "key" then
                if param == keys.leftCtrl or param == keys.rightCtrl then
                    ctrl_held = true
                elseif param == keys.l and ctrl_held then
                    stdout_write("\27[2J\27[1;1H\27[s")
                    needs_draw = true
                elseif param == keys.d and ctrl_held then
                    return "exit"
                elseif param == keys.a and ctrl_held then
                    cursor_pos = 1
                    needs_draw = true
                elseif param == keys.e and ctrl_held then
                    cursor_pos = #input + 1
                    needs_draw = true
                elseif param == keys.k and ctrl_held then
                    input = input:sub(1, cursor_pos - 1)
                    needs_draw = true
                elseif param == keys.left and cursor_pos > 1 then
                    cursor_pos = cursor_pos - 1
                    needs_draw = true
                elseif param == keys.right and cursor_pos <= #input then
                    cursor_pos = cursor_pos + 1
                    needs_draw = true
                elseif param == keys.up then
                    if history_index > 1 then
                        if history_index == #history_table + 1 then draft_input = input end
                        history_index = history_index - 1
                        input = history_table[history_index]
                        cursor_pos = #input + 1
                        needs_draw = true
                    end
                elseif param == keys.down then
                    if history_index < #history_table then
                        history_index = history_index + 1
                        input = history_table[history_index]
                        cursor_pos = #input + 1
                        needs_draw = true
                    elseif history_index == #history_table then
                        history_index = history_index + 1
                        input = draft_input
                        cursor_pos = #input + 1
                        needs_draw = true
                    end
                elseif param == keys.backspace and cursor_pos > 1 then
                    input = input:sub(1, cursor_pos - 2) .. input:sub(cursor_pos)
                    cursor_pos = cursor_pos - 1
                    needs_draw = true
                elseif param == keys.tab then
                    if completion_fn then
                        local text_before_cursor = input:sub(1, cursor_pos - 1)
                        local matches, partial, common = completion_fn(text_before_cursor)

                        if matches then
                            if #matches == 1 then
                                local completion = matches[1]
                                input = input:sub(1, cursor_pos - 1) .. completion .. input:sub(cursor_pos)
                                cursor_pos = cursor_pos + #completion
                                needs_draw = true
                            elseif #matches > 1 then
                                if common and #common > 0 then
                                    input = input:sub(1, cursor_pos - 1) .. common .. input:sub(cursor_pos)
                                    cursor_pos = cursor_pos + #common
                                    needs_draw = true
                                else
                                    stdout_write("\n")
                                    local full_matches = {}
                                    for _, m in ipairs(matches) do table.insert(full_matches, partial .. m:gsub("%s$", "")) end
                                    stdout_write(io.colors.cyan .. table.concat(full_matches, "   ") .. io.colors.reset .. "\n")
                                    stdout_write("\27[s")
                                    needs_draw = true
                                end
                            end
                        end
                    end
                elseif param == keys.enter or param == keys.numPadEnter then
                    if not params[3] then
                        stdout_write("\n")
                        stdout_write("\27[?25l")
                        return input
                    end
                end
            elseif event == "char" then
                if cursor_pos == #input + 1 then
                    input = input .. param
                    cursor_pos = cursor_pos + 1
                    if replace_char then stdout_write(replace_char) else stdout_write(param) end
                else
                    input = input:sub(1, cursor_pos - 1) .. param .. input:sub(cursor_pos)
                    cursor_pos = cursor_pos + 1
                    needs_draw = true
                end
            elseif event == "key_up" then
                if param == keys.leftCtrl or param == keys.rightCtrl then ctrl_held = false end
            end

            if needs_draw then redraw() end
        end
    end
end

io.file_methods = {}

function io.file_methods:close()
    if self.fd then
        local res = unistd.close(self.fd)
        self.fd = nil
        if type(res) == "number" and res < 0 then
            return nil, get_err_str(res)
        end
        return true
    end
    return nil, "File already closed"
end

function io.file_methods:read(size)
    size = size and size > 0 and size or 1
    self.buffer = {}
    local data = unistd.read(self.fd)

    if type(data) == "number" and data < 0 then
        return nil, get_err_str(data)
    elseif not data or data == "" then
        return ""
    else
        table.insert(self.buffer, data)
    end

    return self.buffer[1] ~= "" and table.concat(self.buffer, ""):sub(1, size) or nil
end

function io.file_methods:read_line()
    if not self._line_buffer then
        local all_data = self:read_all()
        if not all_data then return nil end
        self._line_buffer = all_data
        self._line_pos = 1
    end

    if self._line_pos > #self._line_buffer then return nil end

    local s, e = string.find(self._line_buffer, "\n", self._line_pos, true)

    if s then
        local line = string.sub(self._line_buffer, self._line_pos, s - 1)
        if string.sub(line, -1) == "\r" then line = string.sub(line, 1, -2) end
        self._line_pos = e + 1
        return line
    else
        local line = string.sub(self._line_buffer, self._line_pos)
        self._line_pos = #self._line_buffer + 1
        return line
    end
end

function io.file_methods:read_all()
    self.buffer = {}

    while not self.eof do
        local data = unistd.read(self.fd)
        if type(data) == "number" and data < 0 then
            return nil, get_err_str(data)
        elseif not data or data == "" then
            self.eof = true
        else
            table.insert(self.buffer, data)
        end
    end

    return self.buffer[1] ~= nil and table.concat(self.buffer, "") or nil
end

function io.file_methods:write(data)
    if not self.fd then return nil, "File closed" end

    local res = unistd.write(self.fd, data)

    if type(res) == "number" and res < 0 then
        return nil, get_err_str(res)
    end
    return res
end

function io.open(path, mode)
    mode = mode or "r"

    local fd = fcntl.open(path, mode_flags[mode])

    if type(fd) == "number" and fd < 0 then
        return nil, get_err_str(fd)
    end
    if not fd then return nil, "Unknown error" end

    local file_obj = {
        fd = fd,
        mode = mode,
        buffer = {},
        eof = false
    }

    setmetatable(file_obj, { __index = io.file_methods })
    return file_obj
end

return io