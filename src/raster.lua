-- raster.lua — растеризатор треугольников с z-буфером и освещением
-- Все координаты уже в screen-space (после проекции). Z — линейная глубина.

local M = {}

-- Кэш символов освещения (от тёмного к светлому)
local SHADE = {" ", ".", ":", "-", "=", "+", "*", "#", "%", "@"}

-- Бликующий символ по нормали (в псевдо-фонге)
local function shadeChar(ndotl)
    if ndotl < 0 then ndotl = 0 end
    if ndotl > 1 then ndotl = 1 end
    local idx = math.floor(ndotl * (#SHADE - 1)) + 1
    return SHADE[idx]
end

-- Отрисовка одного треугольника.
-- v0,v1,v2: {{x,y,z,shade}, ...}, где shade — нормаль/яркость (0..1) или nil.
-- Если shade == nil — берётся средняя яркость по плоской нормали.
-- cull: true = back-face culling.
function M.triangle(fb, v0, v1, v2, cull)
    -- Площадь для back-face culling
    local area = (v1.x - v0.x) * (v2.y - v0.y) - (v1.y - v0.y) * (v2.x - v0.x)
    if cull and area <= 0 then return end

    local minX = math.max(1, math.floor(math.min(v0.x, v1.x, v2.x)))
    local maxX = math.min(fb.w, math.ceil(math.max(v0.x, v1.x, v2.x)))
    local minY = math.max(1, math.floor(math.min(v0.y, v1.y, v2.y)))
    local maxY = math.min(fb.h, math.ceil(math.max(v0.y, v1.y, v2.y)))

    if maxX < minX or maxY < minY then return end

    -- Атрибуты в вершинах
    local a0, a1, a2 = v0.s or 0.5, v1.s or 0.5, v2.s or 0.5
    local z0, z1, z2 = v0.z, v1.z, v2.z

    -- Шаг по (1/area) — оптимизация: 1/area считаем один раз
    local inv = 1 / area
    for y = minY, maxY do
        for x = minX, maxX do
            -- Барицентрические координаты
            local w0 = ((v1.x - x) * (v2.y - y) - (v1.y - y) * (v2.x - x)) * inv
            local w1 = ((v2.x - x) * (v0.y - y) - (v2.y - y) * (v0.x - x)) * inv
            local w2 = 1 - w0 - w1
            if w0 >= 0 and w1 >= 0 and w2 >= 0 then
                local z = w0 * z0 + w1 * z1 + w2 * z2
                local s = w0 * a0 + w1 * a1 + w2 * a2
                fb:put(x, y, shadeChar(s), z)
            end
        end
    end
end

return M
