local math = require("math")
local sha = require("Crypto.sha")
local bignum = require("Bignum.bigNum")
local string = require("string")
local stdio = require("Clib.stdio")
local RAW_GTABLE = nil

local ecc = {}

local G_cache = {}
local G_table = {}

local f = stdio.open("/lib/Crypto/secp256k1_gtable.bin", "r")
if f then
    RAW_GTABLE = f:read_all() or ""
    f:close()
else
    return nil
end

local ZERO = bignum("0")
local ONE = bignum("1")
local TWO = bignum("2")
local THREE = bignum("3")
local FOUR = bignum("4")
local SEVEN = bignum("7")
local EIGHT = bignum("8")
local P = bignum("115792089237316195423570985008687907853269984665640564039457584007908834671663")
local G = {x = bignum("55066263022277343669578718895168534326250603453777594175500187360389116729240"), y = bignum("32670510020758816978083085130507043184471273380659243275938904335757337482424")}
local N = bignum("115792089237316195423570985008687907852837564279074904382605163141518161494337")

local function hash_message(message)
    local _, bin_digest = sha.sha256(message)
    local z = ZERO.fromBytes(bin_digest)
    return z % N
end

local function generate_k(priv, z)
    local key = priv:toBytes()
    key = string.rep("\x00", 32 - #key) .. key

    local h1 = z:toBytes()
    h1 = string.rep("\x00", 32 - #h1) .. h1

    local K = string.rep("\x00", 32)
    local V = string.rep("\x01", 32)

    K = sha.hmac_sha256(K, V .. "\x00" .. key .. h1, true)
    V = sha.hmac_sha256(K, V, true)

    while true do
        V = sha.hmac_sha256(K, V, true)
        local k = ZERO.fromBytes(V)
        if k > ZERO and k < N then
            return k
        end
        K = sha.hmac_sha256(K, V .. "\x00", true)
        V = sha.hmac_sha256(K, V, true)
    end
end

local function modular_inverse(a, m)
    local x, y, u, v = ZERO, ONE, ONE, ZERO
    local b = m
    a = a % m
    while a ~= ZERO do
        local q = b / a
        local r = b % a
        local m_ = x - u * q
        local n = y - v * q
        b, a, x, y, u, v = a, r, u, v, m_, n
    end
    if b ~= ONE then return nil end
    return x % m
end

local function to_affine(p)
    if p.z == ONE or not p.z then return {x = p.x, y = p.y} end

    local zinv = modular_inverse(p.z, P)
    local zinv2 = (zinv * zinv) % P
    local zinv3 = (zinv2 * zinv) % P

    return {
        x = (p.x * zinv2) % P,
        y = (p.y * zinv3) % P
    }
end

local function is_on_curve(pt)
    if not pt then return false end
    if not pt.z or pt.z == ONE then
        local lhs = (pt.y * pt.y) % P
        local rhs = (pt.x * pt.x * pt.x + SEVEN) % P
        return lhs == rhs
    else
        local a = to_affine(pt)
        return is_on_curve(a)
    end
end

local function point_double(p)
    if p.y == ZERO then return nil end

    local pz = p.z or ONE
    local y2 = (p.y * p.y) % P
    local s = (FOUR * p.x * y2) % P
    local m = (THREE * p.x * p.x) % P
    local nx = (m * m - TWO * s) % P
    local ny = (m * (s - nx) - EIGHT * y2 * y2) % P
    local nz = (TWO * p.y * pz) % P

    return {x = nx, y = ny, z = nz}
end

local function point_add(p, q)
    if not p then return q end
    if not q then return p end

    if not q.z then q = {x = q.x, y = q.y, z = ONE} end
    if not p.z then p = {x = p.x, y = p.y, z = ONE} end

    local z1z1 = (p.z * p.z) % P
    local z2z2 = (q.z * q.z) % P
    local u1 = (p.x * z2z2) % P
    local u2 = (q.x * z1z1) % P
    local s1 = (p.y * q.z * z2z2) % P
    local s2 = (q.y * p.z * z1z1) % P

    if u1 == u2 then
        if s1 == s2 then
            return point_double(p)
        else
            return nil
        end
    end

    local h = (u2 - u1) % P
    local i = (FOUR * h * h) % P
    local j = (h * i) % P
    local r = (TWO * (s2 - s1)) % P
    local v = (u1 * i) % P

    local nx = (r * r - j - TWO * v) % P
    local ny = (r * (v - nx) - TWO * s1 * j) % P
    local nz = ((p.z + q.z) * (p.z + q.z) - z1z1 - z2z2) % P
    nz = (nz * h) % P

    return {x = nx, y = ny, z = nz}
end

local function point_add_affine(p, q)
    if not p then return {x = q.x, y = q.y, z = ONE} end
    if not q then return p end

    local z1z1 = (p.z * p.z) % P
    local u1 = p.x
    local u2 = (q.x * z1z1) % P
    local s1 = p.y
    local s2 = (q.y * p.z * z1z1) % P

    if u1 == u2 then
        if s1 == s2 then
            return point_double(p)
        else
            return nil
        end
    end

    local h = (u2 - u1) % P
    local hh = (h * h) % P
    local i = (FOUR * hh) % P
    local j = (h * i) % P
    local r = (TWO * (s2 - s1)) % P
    local v = (u1 * i) % P

    local nx = (r * r - j - TWO * v) % P
    local ny = (r * (v - nx) - TWO * s1 * j) % P
    local nz = (p.z * h) % P
    nz = (TWO * nz) % P

    return {x = nx, y = ny, z = nz}
end

--[[local function init_g_table()
    local base = { x = G.x, y = G.y, z = ONE }

    for i = 0, 63 do
        G_table[i] = {}

        local base_affine = to_affine(base)
        local cur = base

        G_table[i][1] = base_affine
        for d = 2, 15 do
            cur = point_add(cur, base_affine)
            G_table[i][d] = to_affine(cur)
        end

        for _ = 1, 4 do
            base = point_double(base)
            if not base then
                error("Error: point_double devolvió nil en la inicialización de G_table")
            end
        end
        base = to_affine(base)
        base.z = ONE
    end
end

local function export_table_binary(path)
    local f = stdio.open(path, "w")

    if not f then return end
    for i = 0, 63 do
        for d = 1, 15 do
            local pt = G_table[i][d]
            local x_b = pt.x:toBytes()
            local y_b = pt.y:toBytes()

            x_b = string.rep("\x00", 32 - #x_b) .. x_b
            y_b = string.rep("\x00", 32 - #y_b) .. y_b

            f:write(x_b .. y_b)
        end
    end
    f:close()
end
local f = stdio.open("/lib/Crypto/secp256k1_gtable.bin", "r")
if f then
    RAW_GTABLE = f:read_all() or ""
    f:close()
else
    init_g_table()
    export_table_binary("./secp256k1_gtable.bin")
end]]

local function to_wnaf4(k)
    local wnaf = {}
    local k_curr = k:clone()
    local idx = 1

    while k_curr > ZERO do
        if (k_curr.digits[1] % 2) ~= 0 then
            local val = (k_curr:clone():band(15)).digits[1] or 0
            if val >= 8 then
                val = val - 16
            end
            wnaf[idx] = val
            if val < 0 then
                k_curr = k_curr + bignum(tostring(-val))
            else
                k_curr = k_curr - bignum(tostring(val))
            end
        else
            wnaf[idx] = 0
        end
        k_curr = k_curr:rshift(1)
        idx = idx + 1
    end
    return wnaf
end

local function scalar_multiply(k, p)
    if not p or k == ZERO then return nil end

    local p_aff = to_affine(p)
    local p2 = point_double({x = p_aff.x, y = p_aff.y, z = ONE})
    local p2_aff = to_affine(p2)

    local table_pos = {
        [1] = p_aff,
        [3] = to_affine(point_add_affine(p2, p_aff)),
    }
    table_pos[5] = to_affine(point_add_affine(point_double(table_pos[3]), {x = table_pos[1].x, y = P - table_pos[1].y}))
    table_pos[7] = to_affine(point_add_affine(point_double(table_pos[5]), {x = table_pos[3].x, y = P - table_pos[3].y}))

    local wnaf = to_wnaf4(k)
    local R = nil

    for i = #wnaf, 1, -1 do
        if R then
            R = point_double(R)
        end

        local digit = wnaf[i]
        if digit and digit ~= 0 then
            local abs_d = math.abs(digit)
            local base_pt = table_pos[abs_d]
            local pt = base_pt

            if digit < 0 then
                pt = {x = base_pt.x, y = P - base_pt.y}
            end
            R = point_add_affine(R, pt)
        end
    end

    return R
end

local function double_scalar_multiply(k1, P1, k2, P2)
    local table = {}
    table[0] = {}
    for j = 0, 15 do table[0][j] = nil end

    local p1_prec = { [0] = nil, [1] = P1 }
    for i = 2, 15 do
        p1_prec[i] = point_add(p1_prec[i-1], P1)
    end

    local p2_prec = { [0] = nil, [1] = P2 }
    for i = 2, 15 do
        p2_prec[i] = point_add(p2_prec[i-1], P2)
    end

    local R = nil
    for i = 63, 0, -1 do
        if R then
            R = point_double(R)
            R = point_double(R)
            R = point_double(R)
            R = point_double(R)
        end

        local w1 = k1:clone():rshift(i*4):band(15)
        local w2 = k2:clone():rshift(i*4):band(15)
        local d1 = w1 ~= ZERO and (w1.digits[1] or 0) or 0
        local d2 = w2 ~= ZERO and (w2.digits[1] or 0) or 0

        if d1 > 0 then
            R = point_add(R, p1_prec[d1])
        end
        if d2 > 0 then
            R = point_add(R, p2_prec[d2])
        end
    end
    return R
end

local function get_precomputed_point(i, d)
    if d == 0 then return nil end
    local key = (i * 15) + (d - 1)

    if G_cache[key] then
        return G_cache[key]
    end

    local offset = key * 64 + 1
    local x_bytes = RAW_GTABLE:sub(offset, offset + 31)
    local y_bytes = RAW_GTABLE:sub(offset + 32, offset + 63)

    local pt = {
        x = ZERO.fromBytes(x_bytes),
        y = ZERO.fromBytes(y_bytes),
        z = ONE
    }

    G_cache[key] = pt
    return pt
end

function ecc.get_privk()
    local fd, err = stdio.open("/dev/random", "r")

    if not fd then
        error("Can't open /dev/random - " .. tostring(err))
    end

    local random_bytes = fd:read(32)

    fd:close()

    local k = ZERO.fromBytes(random_bytes)

    return k % (N - ONE) + ONE
end

function ecc.get_pubk(priv_key)
    local raw = priv_key:toBytes()
    if #raw < 32 then
        raw = string.rep("\x00", 32 - #raw) .. raw
    end

    local R = nil
    for byte_idx = 32, 1, -1 do
        local b = raw:byte(byte_idx)
        local low = b % 16
        local high = (b - low) / 16

        local win_idx = (32 - byte_idx) * 2
        if low > 0 then
            local pt = get_precomputed_point(win_idx, low)
            R = point_add_affine(R, pt)
        end
        if high > 0 then
            local pt = get_precomputed_point(win_idx + 1, high)
            R = point_add_affine(R, pt)
        end
    end
    return to_affine(R)
end

function ecc.get_shk(my_priv_key, their_pub_key)
    if not is_on_curve(their_pub_key) then return nil end
    local shared_point = scalar_multiply(my_priv_key, their_pub_key)
    if not shared_point then return nil end
    local affine = to_affine(shared_point)
    return affine.x
end

function ecc.sign_ecdsa(priv_key, message)
    local z = hash_message(message)

    local k = generate_k(priv_key, z)
    local R_affine = ecc.get_pubk(k)
    local r = R_affine.x % N
    local k_inv = modular_inverse(k, N)
    local term1 = (r * priv_key) % N
    local term2 = (z + term1) % N
    local s = (k_inv * term2) % N

    local HALF_N = N / TWO
    if s > HALF_N then
        s = N - s
    end

    return {r = r, s = s}
end

function ecc.sign_schnorr(priv_key, message, pub_key)
    local P_affine
    if pub_key then
        P_affine = pub_key
    else
        local P_proj = ecc.get_pubk(priv_key)
        P_affine = to_affine(P_proj)
    end

    local d = priv_key
    if (P_affine.y % TWO) ~= ZERO then
        d = N - d
    end

    local z = hash_message(message)
    local k = generate_k(d, z)

    local R_affine = ecc.get_pubk(k)

    if (R_affine.y % TWO) ~= ZERO then
        k = N - k
    end

    local function pad32(b)
        return string.rep("\x00", 32 - #b) .. b
    end

    local e_data = pad32(R_affine.x:toBytes()) .. pad32(P_affine.x:toBytes()) .. message
    local _, e_hash = sha.sha256(e_data)
    local e = ZERO.fromBytes(e_hash) % N

    local s = (k + (e * d) % N) % N

    return {r = R_affine.x, s = s}
end

function ecc.verify_ecdsa(pub_key, message, sign)
    if not is_on_curve(pub_key) then
        return {result = false, message = "Invalid public key"}
    end
    local z = hash_message(message)

    if sign.r < ONE or sign.r > N - ONE or sign.s < ONE or sign.s > N - ONE then
        return {result = false, message = "Invalid r or s range"}
    end

    local w = modular_inverse(sign.s, N)
    if not w then return {result = false, message = "Cannot calculate s inverse"} end
    local u1 = (z * w) % N
    local u2 = (sign.r * w) % N

    local P_pub_proj = {x = pub_key.x, y = pub_key.y, z = ONE}
    local R_prime_proj = double_scalar_multiply(u1, G, u2, P_pub_proj)

    if not R_prime_proj then
        return {result = false, message = "Point addition resulted in infinity"}
    end

    local R_prime_affine = to_affine(R_prime_proj)

    local r_prime = R_prime_affine.x % N

    return {result = sign.r == r_prime, message = "Signature verification result"}
end

function ecc.verify_schnorr(pub_key, message, sign)
    if not is_on_curve(pub_key) then
        return {result = false, message = "Invalid public key"}
    end

    local PK = {x = pub_key.x, y = pub_key.y}

    if (PK.y % TWO) ~= ZERO then
        PK.y = P - PK.y
    end

    local function pad32(b)
        return string.rep("\x00", 32 - #b) .. b
    end

    local e_data = pad32(sign.r:toBytes()) .. pad32(PK.x:toBytes()) .. message
    local _, e_hash = sha.sha256(e_data)
    local e = ZERO.fromBytes(e_hash) % N

    local minus_e = (N - e) % N
    local P_proj = {x = PK.x, y = PK.y, z = ONE}

    local R_prime_proj = double_scalar_multiply(sign.s, G, minus_e, P_proj)
    if not R_prime_proj then
        return {result = false, message = "Point addition resulted in infinity"}
    end

    local R_prime_affine = to_affine(R_prime_proj)

    if (R_prime_affine.y % TWO) ~= ZERO then
        return {result = false, message = "R.y is odd, invalid signature"}
    end

    return {result = sign.r == R_prime_affine.x, message = "Schnorr verification result"}
end

return ecc