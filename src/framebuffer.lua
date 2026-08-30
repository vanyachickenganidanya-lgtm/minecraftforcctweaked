-- framebuffer.lua — программный Z-буфер + цветовой буфер
-- Цель: при большом количестве треугольников отсекать дальние пиксели.

local M = {}

function M.new(w, h)
    return setmetatable({
        w = w,
        h = h,
        color = {},
        z = {},
    }, {__index = M})
end

function M:clear(ch, bgColor)
    local cw, chh = self.w, self.h
    for y = 1, chh do
        local row = {}
        local zrow = {}
        for x = 1, cw do
            row[x] = bgColor or " "
            zrow[x] = 1e9
        end
        self.color[y] = row
        self.z[y] = zrow
    end
end

-- Точка с z-тестом. Если z <= текущего — рисуем.
function M:put(x, y, ch, z)
    x, y = math.floor(x), math.floor(y)
    if x < 1 or y < 1 or x > self.w or y > self.h then return end
    if z and z > self.z[y][x] then return end
    self.color[y][x] = ch
    if z then self.z[y][x] = z end
end

-- Линия (Bresenham) — нужна для wireframe
function M:line(x0, y0, x1, y1, ch, z0, z1)
    local dx = math.abs(x1 - x0)
    local dy = -math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx + dy
    local steps = math.max(dx, -dy) + 1
    for i = 0, steps do
        local t = steps > 0 and (i / steps) or 0
        local z = z0 and (z0 + (z1 - z0) * t) or nil
        self:put(x0, y0, ch, z)
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 >= dy then err = err + dy; x0 = x0 + sx end
        if e2 <= dx then err = err + dx; y0 = y0 + sy end
    end
end

-- Сборка ASCII-строк для блиттера монитора
function M:render()
    local out = {}
    for y = 1, self.h do
        out[y] = table.concat(self.color[y])
    end
    return table.concat(out, "\n")
end

return M
