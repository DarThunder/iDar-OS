local math = require("math")
local string = require("string")
local bit = require("bit32")

local B = {}
local mt = { __index = B }
local BASE = 67108864

local function zero_digits()
    return {0}
end

local function normalize(digits)
    local n = #digits
    while n > 1 and digits[n] == 0 do
        digits[n] = nil
        n = n - 1
    end
    return digits
end

local function is_zero(digits)
    return #digits == 1 and digits[1] == 0
end

local function compare_abs(a_digits, b_digits)
    if #a_digits > #b_digits then return 1 end
    if #a_digits < #b_digits then return -1 end
    for i = #a_digits, 1, -1 do
        if (a_digits[i] or 0) > (b_digits[i] or 0) then return 1 end
        if (a_digits[i] or 0) < (b_digits[i] or 0) then return -1 end
    end
    return 0
end

local function add_abs(a_digits, b_digits)
    local carry = 0
    local maxLen = math.max(#a_digits, #b_digits)

    for i = 1, maxLen do
        local sum = (a_digits[i] or 0) + (b_digits[i] or 0) + carry
        a_digits[i] = sum % BASE
        carry = math.floor(sum / BASE)
    end

    if carry > 0 then
        a_digits[maxLen + 1] = carry
    end

    return a_digits
end

local function sub_abs(a_digits, b_digits)
    local borrow = 0
    local maxLen = #a_digits

    for i = 1, maxLen do
        local diff = (a_digits[i] or 0) - (b_digits[i] or 0) - borrow
        if diff < 0 then
            diff = diff + BASE
            borrow = 1
        else
            borrow = 0
        end
        a_digits[i] = diff
    end

    return normalize(a_digits)
end

local function mul_abs(a_digits, b_digits)
    if is_zero(a_digits) or is_zero(b_digits) then return zero_digits() end

    local result = {}
    for i = 1, #a_digits do
        local carry = 0
        for j = 1, #b_digits do
            local k = i + j - 1
            local prod = (a_digits[i] * b_digits[j]) + (result[k] or 0) + carry
            result[k] = prod % BASE
            carry = math.floor(prod / BASE)
        end
        result[i + #b_digits] = carry
    end
    return normalize(result)
end

local function lshift_digits(digits, n)
    if n <= 0 or is_zero(digits) then return digits end

    for i = #digits, 1, -1 do
        digits[i + n] = digits[i]
    end
    for i = 1, n do
        digits[i] = 0
    end

    return normalize(digits)
end

local function mul_by_small(digits, n)
    local carry = 0
    local result = {}
    for i = 1, #digits do
        local prod = (digits[i] * n) + carry
        result[i] = prod % BASE
        carry = math.floor(prod / BASE)
    end
    while carry > 0 do
        table.insert(result, carry % BASE)
        carry = math.floor(carry / BASE)
    end
    return result
end

local function add_small(digits, n)
    local result = {}
    local sum = digits[1] + n
    result[1] = sum % BASE
    local carry = math.floor(sum / BASE)

    local i = 2
    while i <= #digits or carry > 0 do
        sum = (digits[i] or 0) + carry
        result[i] = sum % BASE
        carry = math.floor(sum / BASE)
        i = i + 1
    end
    return result
end

local function divmod_by_small(digits, n)
    local remainder = 0
    local quotient = {}

    for i = #digits, 1, -1 do
        local value = digits[i] + remainder * BASE
        local q = math.floor(value / n)
        quotient[i] = q
        remainder = value % n
    end

    return normalize(quotient), remainder
end

local function divmod_abs(a_digits, b_digits)
    if is_zero(b_digits) then error("Division by zero", 2) end
    if compare_abs(a_digits, b_digits) < 0 then
        return zero_digits(), normalize({table.unpack(a_digits)})
    end

    local n, m = #a_digits, #b_digits
    local quotient = {}
    local remainder = {}

    for i = 1, n do remainder[i] = a_digits[i] end

    local norm = math.floor(BASE / (b_digits[m] + 1))
    if norm > 1 then
        remainder = mul_by_small(remainder, norm)
        b_digits = mul_by_small(b_digits, norm)
    end

    n = #remainder
    m = #b_digits

    for i = n - m, 0, -1 do
        local r_hi = remainder[i + m + 1] or 0
        local r_lo = remainder[i + m] or 0
        local num = r_hi * BASE + r_lo
        local den = b_digits[m]
        local q_hat = math.floor(num / den)

        if q_hat >= BASE then q_hat = BASE - 1 end

        local prod = mul_by_small(b_digits, q_hat)
        prod = lshift_digits(prod, i)

        while q_hat > 0 and compare_abs(remainder, prod) < 0 do
            q_hat = q_hat - 1
            prod = mul_by_small(b_digits, q_hat)
            prod = lshift_digits(prod, i)
        end

        remainder = sub_abs(remainder, prod)
        quotient[i + 1] = q_hat
    end

    if norm > 1 then
        remainder, _ = divmod_by_small(remainder, norm)
    end

    return normalize(quotient), normalize(remainder)
end

local function fromString(str)
    local digits = zero_digits()
    for i = 1, #str do
        local digit_val = str:byte(i) - 48
        if digit_val < 0 or digit_val > 9 then
            error("Invalid number string: " .. str, 2)
        end
        digits = mul_by_small(digits, 10)
        digits = add_small(digits, digit_val)
    end
    return digits
end

local function toString(digits, sign)
    if is_zero(digits) then return "0" end

    local s = {}
    local temp_digits = digits

    while not is_zero(temp_digits) do
        local remainder
        temp_digits, remainder = divmod_by_small(temp_digits, 10)
        table.insert(s, 1, string.char(remainder + 48))
    end

    local prefix = (sign < 0) and "-" or ""
    return prefix .. table.concat(s)
end

function B.new(n, format)
    if type(n) == "table" and getmetatable(n) == mt then
        return n
    end

    if format == "bytes" or format == "raw" then
        return B.fromBytes(n)
    elseif format == "bin" or format == "binary" then
        return B.fromBinary(n)
    elseif format == "hex" then
        local hex = n:gsub("^0[xX]", "")
        return B.fromHex and B.fromHex(hex) or fromString(hex)
    end

    local n_type = type(n)

    if n_type == "string" then
        if n:find("[%z\x01-\x08\x0e-\x1f\x7f-\xff]") then
            return B.fromBytes(n)
        end

        local sign = 1
        if n:sub(1, 1) == "-" then
            sign = -1
            n = n:sub(2)
        end

        if n:sub(1, 2):lower() == "0b" then
            local obj = B.fromBinary(n:sub(3))
            obj.sign = sign
            return obj
        elseif n:sub(1, 2):lower() == "0x" and B.fromHex then
            local obj = B.fromHex(n:sub(3))
            obj.sign = sign
            return obj
        end

        local obj = { sign = sign, digits = fromString(n) }
        setmetatable(obj, mt)
        if is_zero(obj.digits) then obj.sign = 1 end
        return obj

    elseif n_type == "number" then
        local obj = { sign = 1, digits = zero_digits() }
        setmetatable(obj, mt)

        if n < 0 then
            obj.sign = -1
            n = -n
        end
        local d = {}
        local i = 1
        while n > 0 do
            d[i] = n % BASE
            n = math.floor(n / BASE)
            i = i + 1
        end
        obj.digits = #d > 0 and d or zero_digits()
        return obj
    else
        error("Cannot create bignum from type: " .. n_type, 2)
    end
end

function B.fromBinary(binaryString)
    local obj = { sign = 1, digits = {0} }
    setmetatable(obj, mt)
    local temp_digits = {0}

    for i = 1, #binaryString do
        local bit_val = binaryString:byte(i) - 48
        temp_digits = mul_by_small(temp_digits, 2)

        if bit_val == 1 then
            temp_digits = add_small(temp_digits, 1)
        elseif bit_val ~= 0 then
            error("Invalid binary string: " .. binaryString, 2)
        end
    end

    obj.digits = temp_digits
    if is_zero(obj.digits) then obj.sign = 1 end
    return obj
end

function B.fromBytes(str)
    local obj = { sign = 1, digits = {0} }
    setmetatable(obj, mt)
    if str == nil or #str == 0 then return obj end

    local temp_digits = {0}
    for i = 1, #str do
        temp_digits = mul_by_small(temp_digits, 256)
        temp_digits = add_small(temp_digits, str:byte(i))
    end

    obj.digits = normalize(temp_digits)
    if is_zero(obj.digits) then obj.sign = 1 end
    return obj
end

function B:toBytes()
    if is_zero(self.digits) then return string.rep("\0", 32) end

    local chars = {}
    local temp = self.digits
    while not is_zero(temp) do
        local remainder
        temp, remainder = divmod_by_small(temp, 256)
        table.insert(chars, 1, string.char(remainder))
    end

    local raw = table.concat(chars)
    if #raw < 32 then
        raw = string.rep("\0", 32 - #raw) .. raw
    end
    return raw
end

function B:toString()
    return toString(self.digits, self.sign)
end

function B:clone()
    local c = { sign = self.sign, digits = {} }
    for i = 1, #self.digits do
        c.digits[i] = self.digits[i]
    end
    setmetatable(c, mt)
    return c
end

function B:raw_negate()
    local c = self:clone()
    if not is_zero(c.digits) then
        c.sign = -c.sign
    end
    return c
end

function B:raw_abs()
    local c = self:clone()
    c.sign = 1
    return c
end

function B:bitLength()
    if is_zero(self.digits) then return 0 end

    local last_digit = self.digits[#self.digits]
    local bits_in_last = 0

    while last_digit > 0 do
        last_digit = math.floor(last_digit / 2)
        bits_in_last = bits_in_last + 1
    end

    return (#self.digits - 1) * 26 + bits_in_last
end

function B:add(other)
    local b = B.new(other)

    if self.sign == b.sign then
        add_abs(self.digits, b.digits)
    else
        local cmp = compare_abs(self.digits, b.digits)
        if cmp >= 0 then
            sub_abs(self.digits, b.digits)
        else
            local new_digits = {}
            for i = 1, #b.digits do new_digits[i] = b.digits[i] end
            sub_abs(new_digits, self.digits)
            self.digits = new_digits
            self.sign = b.sign
        end
    end

    if is_zero(self.digits) then self.sign = 1 end

    return self
end

function B:sub(other)
    local b = B.new(other)

    if self.sign ~= b.sign then
        add_abs(self.digits, b.digits)
    else
        local cmp = compare_abs(self.digits, b.digits)
        if cmp >= 0 then
            sub_abs(self.digits, b.digits)
        else
            local new_digits = {}
            for i = 1, #b.digits do new_digits[i] = b.digits[i] end
            sub_abs(new_digits, self.digits)
            self.digits = new_digits
            self.sign = -self.sign
        end
    end

    if is_zero(self.digits) then self.sign = 1 end

    return self
end

function B:mul(other)
    local a, b = self, B.new(other)
    local result = { sign = 1, digits = zero_digits() }
    setmetatable(result, mt)

    result.digits = mul_abs(a.digits, b.digits)
    result.sign = a.sign * b.sign

    if is_zero(result.digits) then result.sign = 1 end
    return result
end

function B:divmod(other)
    local a, b = self, B.new(other)
    local q = { sign = 1, digits = zero_digits() }
    local r = { sign = 1, digits = zero_digits() }
    setmetatable(q, mt); setmetatable(r, mt)

    q.digits, r.digits = divmod_abs(a.digits, b.digits)
    q.sign = a.sign * b.sign
    r.sign = a.sign

    if is_zero(q.digits) then q.sign = 1 end
    if is_zero(r.digits) then r.sign = 1 end
    return q, r
end

function B:div(other)
    local q, r = self:divmod(B.new(other))
    return q
end

function B:mod(other)
    local b_obj = B.new(other)
    local _, r = self:divmod(b_obj)

    if r.sign < 0 then
        r = r + b_obj
    end

    return r
end

function B:pow(exp)
    local base = self:clone()
    local exp_obj = B.new(exp)
    local result = B.new(1)

    if exp_obj.sign < 0 then
        if self:toString() == "1" then return B.new(1) end
        if self:toString() == "-1" then return exp_obj:mod(2):toString() == "0" and B.new(1) or B.new(-1) end
        return B.new(0)
    end

    local ZERO = B.new(0)
    local ONE = B.new(1)
    local TWO = B.new(2)

    while exp_obj > ZERO do
        if (exp_obj % TWO) == ONE then
            result = result * base
        end
        exp_obj = exp_obj / TWO
        base = base * base
    end
    return result
end

function B:sqrt()
    local ZERO = B.new(0)
    local ONE = B.new(1)
    local TWO = B.new(2)
    local n = self

    if n < ZERO then error("Square root of negative number", 2) end
    if n == ZERO then return ZERO end

    local num_bits = n:bitLength()
    local x = ONE:lshift(math.ceil(num_bits / 2))

    local prev_x
    local iterations = 0

    repeat
        prev_x = x
        x = (x + (n / x)) / TWO
        iterations = iterations + 1
    until x >= prev_x
    return prev_x
end

function B:modExp(exp, mod)
    local base = self:clone()
    local exp_obj = B.new(exp)
    local mod_obj = B.new(mod)

    local result = B.new(1)
    base = base % mod_obj

    local ZERO = B.new(0)
    local ONE = B.new(1)
    local TWO = B.new(2)

    while exp_obj > ZERO do

        if (exp_obj % TWO) == ONE then
            result = (result * base) % mod_obj
        end
        exp_obj = exp_obj / TWO
        base = (base * base) % mod_obj
    end

    if result.sign < 0 then
        result = result + mod_obj
    end
    return result
end

function B:band(other)
    local b_digits = B.new(other).digits
    local maxLen = math.max(#self.digits, #b_digits)

    for i = 1, maxLen do
        self.digits[i] = bit.band(self.digits[i] or 0, b_digits[i] or 0)
    end

    self.digits = normalize(self.digits)
    self.sign = 1

    return self
end

function B:bor(other)
    local b_digits = B.new(other).digits
    local maxLen = math.max(#self.digits, #b_digits)

    for i = 1, maxLen do
        self.digits[i] = bit.bor(self.digits[i] or 0, b_digits[i] or 0)
    end

    self.digits = normalize(self.digits)
    self.sign = 1

    return self
end

function B:bxor(other)
    local b_digits = B.new(other).digits
    local maxLen = math.max(#self.digits, #b_digits)

    for i = 1, maxLen do
        self.digits[i] = bit.bxor(self.digits[i] or 0, b_digits[i] or 0)
    end

    self.digits = normalize(self.digits)
    self.sign = 1

    return self
end

function B:lshift(n)
    if n <= 0 or is_zero(self.digits) then return self end

    local n_digits = math.floor(n / 26)
    local n_bits = n % 26

    if n_digits > 0 then
        for i = #self.digits, 1, -1 do
            self.digits[i + n_digits] = self.digits[i]
        end
        for i = 1, n_digits do
            self.digits[i] = 0
        end
    end
    if n_bits > 0 then
        local multiplier = 2 ^ n_bits
        local carry = 0
        local len = #self.digits

        for i = 1, len do
            local val = (self.digits[i] or 0) * multiplier + carry
            self.digits[i] = val % BASE
            carry = math.floor(val / BASE)
        end

        if carry > 0 then
            self.digits[len + 1] = carry
        end
    end

    self.digits = normalize(self.digits)

    return self
end

function B:rshift(n)
    if n <= 0 or is_zero(self.digits) then return self end

    local n_digits = math.floor(n / 26)
    local n_bits = n % 26
    local old_len = #self.digits

    if n_digits > 0 then
        if n_digits >= old_len then
            self.digits = {0}
            self.sign = 1
            return self
        end

        for i = 1, old_len - n_digits do
            self.digits[i] = self.digits[i + n_digits]
        end
        for i = old_len - n_digits + 1, old_len do
            self.digits[i] = nil
        end
    end

    if n_bits > 0 then
        local divisor = 2 ^ n_bits
        local carry = 0

        for i = #self.digits, 1, -1 do
            local val = (self.digits[i] or 0) + carry * BASE
            self.digits[i] = math.floor(val / divisor)
            carry = val % divisor
        end
    end

    self.digits = normalize(self.digits)
    if is_zero(self.digits) then self.sign = 1 end

    return self
end

mt.__add = function(a, b) return B.new(a):clone():add(b) end
mt.__sub = function(a, b) return B.new(a):clone():sub(b) end
mt.__mul = function(a, b) return B.new(a):mul(B.new(b)) end
mt.__div = function(a, b) return B.new(a):div(B.new(b)) end
mt.__mod = function(a, b) return B.new(a):mod(B.new(b)) end
mt.__pow = function(a, b) return B.new(a):pow(B.new(b)) end
mt.__unm = function(a) return B.new(a):raw_negate() end
mt.__tostring = function(a) return a:toString() end

mt.__eq = function(a, b)
    local a_obj, b_obj = B.new(a), B.new(b)
    if a_obj.sign ~= b_obj.sign then return false end
    return compare_abs(a_obj.digits, b_obj.digits) == 0
end

mt.__lt = function(a, b)
    local a_obj, b_obj = B.new(a), B.new(b)
    if a_obj.sign ~= b_obj.sign then
        return a_obj.sign < b_obj.sign
    end
    if a_obj.sign > 0 then
        return compare_abs(a_obj.digits, b_obj.digits) < 0
    else
        return compare_abs(a_obj.digits, b_obj.digits) > 0
    end
end

mt.__le = function(a, b)
    local a_obj, b_obj = B.new(a), B.new(b)
    if a_obj.sign ~= b_obj.sign then
        return a_obj.sign < b_obj.sign
    end
    if a_obj.sign > 0 then
        return compare_abs(a_obj.digits, b_obj.digits) <= 0
    else
        return compare_abs(a_obj.digits, b_obj.digits) >= 0
    end
end

return function(n, format)
    return B.new(n, format)
end