-- noise.lua — простой 3D-шум на хешах для генерации мира.
-- Полностью детерминирован, ограничен диапазоном [0,1], работает в Lua 5.1/5.2/5.3.

local M = {}

-- Целочисленный хеш по 3D-координатам. Всегда возвращает 0..2^31-1.
local function hash3(x, y, z, seed)
    -- Используем только умножение и XOR, избегаем больших констант.
    local h = (x * 73856093) ~ (y * 19349663) ~ (z * 83492791) ~ ((seed or 1337) * 265443569)
    h = (h ~ (h >> 13)) * 1274126177
    h = h ~ (h >> 16)
    -- h может быть отрицательным после ~, делаем положительным.
    if h < 0 then h = -h end
    return h % 1000003
end

local function lerp(a, b, t) return a + (b - a) * t end
local function smoothstep(t) return t * t * (3 - 2 * t) end

-- Value noise 3D, 4 октавы. Возвращает число в [0, 1].
function M.noise(x, y, z, seed)
    seed = seed or 1337
    local amp, freq, sum, max = 1, 1, 0, 0
    for o = 1, 4 do
        local xs = x * freq
        local ys = y * freq
        local zs = z * freq
        local x0 = math.floor(xs)
        local y0 = math.floor(ys)
        local z0 = math.floor(zs)
        local fx = smoothstep(xs - x0)
        local fy = smoothstep(ys - y0)
        local fz = smoothstep(zs - z0)
        -- 8 угловых значений
        local v000 = (hash3(x0,   y0,   z0,   seed) % 1000) / 1000
        local v100 = (hash3(x0+1, y0,   z0,   seed) % 1000) / 1000
        local v010 = (hash3(x0,   y0+1, z0,   seed) % 1000) / 1000
        local v110 = (hash3(x0+1, y0+1, z0,   seed) % 1000) / 1000
        local v001 = (hash3(x0,   y0,   z0+1, seed) % 1000) / 1000
        local v101 = (hash3(x0+1, y0,   z0+1, seed) % 1000) / 1000
        local v011 = (hash3(x0,   y0+1, z0+1, seed) % 1000) / 1000
        local v111 = (hash3(x0+1, y0+1, z0+1, seed) % 1000) / 1000
        local x00 = lerp(v000, v100, fx)
        local x10 = lerp(v010, v110, fx)
        local x01 = lerp(v001, v101, fx)
        local x11 = lerp(v011, v111, fx)
        local y0v = lerp(x00, x10, fy)
        local y1v = lerp(x01, x11, fy)
        local v = lerp(y0v, y1v, fz)
        sum = sum + v * amp
        max = max + amp
        amp = amp * 0.5
        freq = freq * 2
    end
    if max == 0 then return 0 end
    return sum / max
end

return M
