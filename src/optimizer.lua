-- optimizer.lua — оптимизации 3D-движка:
--  * Frustum culling — отсечение чанков за пределами пирамиды видимости
--  * Distance culling — LOD: дальние чанки рендерим реже / пропускаем
--  * Mesh cache — кэш построенной геометрии чанка
--  * Back-face culling — глобальный флаг для растеризатора
--  * Adaptive FOV/Detail — снижение детализации при падении FPS

local M = {}

-- Вычисляем 6 плоскостей фрустума (A,B,C,D) из матрицы MVP
function M.extractFrustum(mvp)
    local planes = {}
    -- Левая
    planes[1] = {mvp[4] + mvp[1], mvp[8] + mvp[5], mvp[12] + mvp[9],  mvp[16] + mvp[13]}
    -- Правая
    planes[2] = {mvp[4] - mvp[1], mvp[8] - mvp[5], mvp[12] - mvp[9],  mvp[16] - mvp[13]}
    -- Нижняя
    planes[3] = {mvp[4] + mvp[2], mvp[8] + mvp[6], mvp[12] + mvp[10], mvp[16] + mvp[14]}
    -- Верхняя
    planes[4] = {mvp[4] - mvp[2], mvp[8] - mvp[6], mvp[12] - mvp[10], mvp[16] - mvp[14]}
    -- Ближняя
    planes[5] = {mvp[4] + mvp[3], mvp[8] + mvp[7], mvp[12] + mvp[11], mvp[16] + mvp[15]}
    -- Дальняя
    planes[6] = {mvp[4] - mvp[3], mvp[8] - mvp[7], mvp[12] - mvp[11], mvp[16] - mvp[15]}
    for i = 1, 6 do
        local p = planes[i]
        local l = math.sqrt(p[1] * p[1] + p[2] * p[2] + p[3] * p[3])
        if l > 1e-6 then p[1], p[2], p[3], p[4] = p[1] / l, p[2] / l, p[3] / l, p[4] / l end
    end
    return planes
end

-- AABB-точка в фрустуме: AABB чанка (x0,y0,z0)-(x1,y1,z1)
function M.aabbInFrustum(planes, x0, y0, z0, x1, y1, z1)
    for i = 1, 6 do
        local p = planes[i]
        -- p-нормаль направлена внутрь; если все 8 углов снаружи — отсекаем
        local nx, ny, nz = p[1], p[2], p[3]
        local px = nx >= 0 and x1 or x0
        local py = ny >= 0 and y1 or y0
        local pz = nz >= 0 and z1 or z0
        if nx * px + ny * py + nz * pz + p[4] < 0 then return false end
    end
    return true
end

-- Класс оптимизатора: держит кэш сеток, считает FPS, адаптирует детализацию
function M.new(world, opts)
    opts = opts or {}
    return setmetatable({
        world = world,
        meshCache = {}, -- "cx,cy,cz" -> faces
        lastBuild = {},
        chunkDist = opts.chunkDist or 3, -- радиус загрузки чанков
        skipDistance = opts.skipDistance or 5, -- дальше этого — пропускаем вершины
        targetFPS = opts.targetFPS or 20,
        detailLevel = 1, -- 1=полный, 0.5=средний, 0.25=низкий
        fps = 60,
        frameTimes = {},
    }, {__index = M})
end

function M:getMesh(cx, cy, cz)
    local key = cx .. "," .. cy .. "," .. cz
    local m = self.meshCache[key]
    if m then return m end
    m = self.world:chunkMesh(cx, cy, cz)
    self.meshCache[key] = m
    return m
end

-- Отдать список граней в радиусе вокруг игрока, с фильтрацией фрустума
function M:gatherMeshes(player, frustum)
    local px = math.floor(player.x / self.world.CHUNK_X)
    local py = math.floor(player.y / self.world.CHUNK_Y)
    local pz = math.floor(player.z / self.world.CHUNK_Z)
    local out = {}
    local r = self.chunkDist
    local sx, sy, sz = self.world.CHUNK_X, self.world.CHUNK_Y, self.world.CHUNK_Z
    for cx = px - r, px + r do
        for cz = pz - r, pz + r do
            for cy = math.max(0, py - 1), py + 1 do
                local x0, y0, z0 = cx * sx, cy * sy, cz * sz
                local x1, y1, z1 = x0 + sx, y0 + sy, z0 + sz
                if M.aabbInFrustum(frustum, x0, y0, z0, x1, y1, z1) then
                    local mesh = self:getMesh(cx, cy, cz)
                    -- Distance culling
                    local d = math.max(math.abs(cx - px), math.abs(cz - pz))
                    if d <= self.skipDistance then
                        out[#out + 1] = {faces = mesh, dist = d}
                    end
                end
            end
        end
    end
    -- Сортируем по дальности — ближние рисуем последними (без z-сортировки треугольников
    -- друг относительно друга; z-буфер решит). Но экономим время: дальние пропустим
    -- через detailLevel.
    return out
end

-- Адаптивный детектор FPS. Сохраняет время кадра, считает среднее и снижает детализацию.
function M:tick(dt)
    self.frameTimes[#self.frameTimes + 1] = dt
    if #self.frameTimes > 30 then table.remove(self.frameTimes, 1) end
    local sum = 0
    for _, t in ipairs(self.frameTimes) do sum = sum + t end
    local avg = sum / #self.frameTimes
    if avg > 0 then self.fps = 1 / avg end

    -- Подстраиваем детализацию
    if self.fps < self.targetFPS * 0.7 and self.detailLevel > 0.25 then
        self.detailLevel = math.max(0.25, self.detailLevel - 0.1)
    elseif self.fps > self.targetFPS * 1.3 and self.detailLevel < 1 then
        self.detailLevel = math.min(1, self.detailLevel + 0.05)
    end
end

-- Возвращает шаг пропуска вершин грани (для LOD)
function M:faceStride()
    if self.detailLevel >= 0.9 then return 1 end
    if self.detailLevel >= 0.6 then return 2 end
    return 3
end

return M
