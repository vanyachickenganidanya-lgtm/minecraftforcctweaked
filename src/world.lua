-- world.lua — воксельный мир с кэшем чанков и greedy meshing.
-- Чанк 16x32x16. Типы блоков: 0 воздух, 1 трава/земля, 2 камень, 3 песок, 4 вода.
-- Координаты: мир — целочисленные с любой стороны; внутри чанка — локальные 0..15 (XZ), 0..31 (Y).

local noise = require("noise")

local M = {}

local CHUNK_X, CHUNK_Y, CHUNK_Z = 16, 32, 16
local SEA_LEVEL = 12

-- Высота поверхности в мировых координатах (для Y=0..31)
local function surfaceHeight(wx, wz, seed)
    local n = noise.noise(wx * 0.05, 0, wz * 0.05, seed or 1337)
    return math.floor(8 + n * 10) -- 8..18
end

-- Тип блока по мировым координатам
local function blockAt(wx, wy, wz, seed)
    if wy < 0 or wy >= CHUNK_Y then return 0 end
    local h = surfaceHeight(wx, wz, seed)
    if wy > h then
        if wy <= SEA_LEVEL then return 4 end -- вода
        return 0
    end
    if wy == h then
        if h > SEA_LEVEL + 1 then return 1 -- трава
        else return 3 end -- песок на берегу
    end
    if wy > h - 3 then return 3 end -- песчаный слой
    return 2 -- камень
end

-- Генерация чанка в локальных координатах
local function genChunk(cx, cy, cz, seed)
    local blocks = {}
    for y = 0, CHUNK_Y - 1 do
        for z = 0, CHUNK_Z - 1 do
            for x = 0, CHUNK_X - 1 do
                local wx = cx * CHUNK_X + x
                local wy = cy * CHUNK_Y + y
                local wz = cz * CHUNK_Z + z
                blocks[y * CHUNK_Z * CHUNK_X + z * CHUNK_X + x + 1] = blockAt(wx, wy, wz, seed)
            end
        end
    end
    return blocks
end

function M.new(seed)
    return setmetatable({
        seed = seed or 1337,
        chunkCache = {}, -- ключ "cx,cy,cz" -> блоки
    }, {__index = M})
end

function M:getChunk(cx, cy, cz)
    local key = cx .. "," .. cy .. "," .. cz
    local c = self.chunkCache[key]
    if c then return c end
    c = genChunk(cx, cy, cz, self.seed)
    self.chunkCache[key] = c
    return c
end

function M:blockAt(wx, wy, wz)
    if wy < 0 or wy >= CHUNK_Y then return 0 end
    local cx = math.floor(wx / CHUNK_X)
    local cy = math.floor(wy / CHUNK_Y)
    local cz = math.floor(wz / CHUNK_Z)
    local chunk = self:getChunk(cx, cy, cz)
    local lx = wx - cx * CHUNK_X
    local ly = wy - cy * CHUNK_Y
    local lz = wz - cz * CHUNK_Z
    if lx < 0 or lx >= CHUNK_X or ly < 0 or ly >= CHUNK_Y or lz < 0 or lz >= CHUNK_Z then return 0 end
    return chunk[ly * CHUNK_Z * CHUNK_X + lz * CHUNK_X + lx + 1] or 0
end

-- Цветовая яркость блока
function M:brightness(b)
    if b == 1 then return 0.75 -- трава
    elseif b == 2 then return 0.5 -- камень
    elseif b == 3 then return 0.9 -- песок
    elseif b == 4 then return 0.7 -- вода
    end
    return 1
end

-- Greedy meshing: возвращает список квадратных граней {p0,p1,p2,p3,shade} в мировых координатах.
-- Логика:
--   * для каждой из 6 осей мы смотрим на блоки на текущей грани (d=0 — нижний слой, d=1 — верхний)
--   * маска 2D: mask[v][u] = id блока-соседа, ЕСЛИ блок непрозрачный и сосед прозрачный
--   * иначе 0
--   * greedy-склейка прямоугольников с одинаковым id
local function addFace(faces, p0, p1, p2, p3, shade)
    faces[#faces + 1] = {p0 = p0, p1 = p1, p2 = p2, p3 = p3, shade = shade}
end

function M:chunkMesh(cx, cy, cz)
    local faces = {}
    local wox = cx * CHUNK_X
    local woy = cy * CHUNK_Y
    local woz = cz * CHUNK_Z

    -- Описываем каждую из 6 граней:
    --   face: "x+", "x-", "y+", "y-", "z+", "z-"
    --   Для каждой грани: du, dv — размеры маски, axisLen — сколько слоёв блоков вдоль нормали
    --   Для грани "+": идём от d=0 до d=axisLen-1 (блок на этой позиции)
    --   Сосед: d+1 для "+", d-1 для "-"
    --   Локальные координаты блока на слое d, индексах (u, v):
    --     x+: lx = d+1, ly = v, lz = u   (плоскость перпендикулярна X, блок "за" плоскостью)
    --     y+: lx = u, ly = d+1, lz = v
    --     z+: lx = u, ly = v, lz = d+1
    --     x-: lx = d, ly = v, lz = u
    --     y-: lx = u, ly = d, lz = v
    --     z-: lx = u, ly = v, lz = d

    local function getBlockAndNeighbor(face, d, u, v)
        local lx, ly, lz
        local nx, ny, nz
        if face == "x+" then
            lx, ly, lz = d, v, u
            nx, ny, nz = lx + 1, ly, lz
        elseif face == "x-" then
            lx, ly, lz = d, v, u
            nx, ny, nz = lx - 1, ly, lz
        elseif face == "y+" then
            lx, ly, lz = u, d, v
            nx, ny, nz = lx, ly + 1, lz
        elseif face == "y-" then
            lx, ly, lz = u, d, v
            nx, ny, nz = lx, ly - 1, lz
        elseif face == "z+" then
            lx, ly, lz = u, v, d
            nx, ny, nz = lx, ly, lz + 1
        else -- "z-"
            lx, ly, lz = u, v, d
            nx, ny, nz = lx, ly, lz - 1
        end
        return self:blockAt(wox + lx, woy + ly, woz + lz),
               self:blockAt(wox + nx, woy + ny, woz + nz),
               lx, ly, lz
    end

    -- Получить 4 угла квадрата грани в мировых координатах.
    -- (u, v) — это индексы ЛОКАЛЬНЫЕ (в маске).
    local function faceCorners(face, d, u, v, w, h)
        local function blk(d_, u_, v_)
            local _, _, lx, ly, lz = getBlockAndNeighbor(face, d_, u_, v_)
            return wox + lx, woy + ly, woz + lz
        end
        local x0, y0, z0 = blk(d, u,     v    )
        local x1, y1, z1 = blk(d, u,     v + h)
        local x2, y2, z2 = blk(d, u + w, v + h)
        local x3, y3, z3 = blk(d, u + w, v    )
        return {x = x0, y = y0, z = z0},
               {x = x1, y = y1, z = z1},
               {x = x2, y = y2, z = z2},
               {x = x3, y = y3, z = z3}
    end

    local FACES = {
        -- {face, du, dv, axisLen}
        -- axisLen — сколько слоёв блоков вдоль оси грани (все оси, кроме той, что перпендикулярна грани)
        {face = "x+", du = CHUNK_Z, dv = CHUNK_Y, axisLen = CHUNK_X},
        {face = "x-", du = CHUNK_Z, dv = CHUNK_Y, axisLen = CHUNK_X},
        {face = "y+", du = CHUNK_X, dv = CHUNK_Z, axisLen = CHUNK_Y},
        {face = "y-", du = CHUNK_X, dv = CHUNK_Z, axisLen = CHUNK_Y},
        {face = "z+", du = CHUNK_X, dv = CHUNK_Y, axisLen = CHUNK_Z},
        {face = "z-", du = CHUNK_X, dv = CHUNK_Y, axisLen = CHUNK_Z},
    }

    for _, f in ipairs(FACES) do
        local face, du, dv, axisLen = f.face, f.du, f.dv, f.axisLen
        for d = 0, axisLen - 1 do
            local mask = {}
            for v = 0, dv - 1 do mask[v] = {} end
            for v = 0, dv - 1 do
                for u = 0, du - 1 do
                    local b, bN = getBlockAndNeighbor(face, d, u, v)
                    if b ~= 0 and bN == 0 then
                        mask[v][u] = b
                    else
                        mask[v][u] = 0
                    end
                end
            end
            for v = 0, dv - 1 do
                local u = 0
                while u < du do
                    local id = mask[v][u]
                    if id == 0 then
                        u = u + 1
                    else
                        local w = 1
                        while u + w < du and mask[v][u + w] == id do
                            w = w + 1
                        end
                        local h = 1
                        while v + h < dv do
                            local ok = true
                            for i = 0, w - 1 do
                                if mask[v + h][u + i] ~= id then ok = false; break end
                            end
                            if not ok then break end
                            h = h + 1
                        end
                        for i = 0, h - 1 do
                            for j = 0, w - 1 do mask[v + i][u + j] = 0 end
                        end
                        local p0, p1, p2, p3 = faceCorners(face, d, u, v, w, h)
                        addFace(faces, p0, p1, p2, p3, self:brightness(id))
                        u = u + w
                    end
                end
            end
        end
    end

    return faces
end

M.CHUNK_X, M.CHUNK_Y, M.CHUNK_Z = CHUNK_X, CHUNK_Y, CHUNK_Z
return M
