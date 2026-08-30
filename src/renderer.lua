-- renderer.lua — основной 3D-рендерер.
-- Пайплайн:
--   1. worldViewProj = projection * view
--   2. frustum = optimizer.extractFrustum(wvp)
--   3. meshes = optimizer:gatherMeshes(player, frustum)
--   4. для каждой грани: split → 2 треугольника → transform → clip → raster
--   5. блютим framebuffer на монитор

local math3d = require("math3d")
local framebuffer = require("framebuffer")
local raster = require("raster")
local optimizer = require("optimizer")

local M = {}

-- Локальный кэш объектов, чтобы не аллоцировать каждый кадр
local function newState(w, h)
    return {
        fb = framebuffer.new(w, h),
        fovY = math.rad(75),
        aspect = w / h,
        near = 0.1,
        far = 200,
        proj = nil,
    }
end

-- Готовим кадр
-- Возвращает: ASCII-строку для монитора, статистику
function M.render(state, world, player, optim, bgChar)
    local w, h = state.fb.w, state.fb.h
    state.fb:clear(bgChar or " ")

    local view = math3d.lookAt(
        {x = player.x, y = player.y, z = player.z},
        {x = player.x + math.cos(player.yaw) * math.cos(player.pitch),
         y = player.y + math.sin(player.pitch),
         z = player.z + math.sin(player.yaw) * math.cos(player.pitch)},
        {x = 0, y = 1, z = 0}
    )
    state.proj = state.proj or math3d.perspective(state.fovY, state.aspect, state.near, state.far)
    local mvp = math3d.mul(state.proj, view)
    local frustum = optimizer.extractFrustum(mvp)

    local meshes = optim:gatherMeshes(player, frustum)
    local stats = {tris = 0, culled = 0, faces = 0}

    local stride = optim:faceStride()
    -- Сортировка не нужна (z-буфер), но сначала дальние чанки — экономим работу
    table.sort(meshes, function(a, b) return a.dist > b.dist end)

    for _, m in ipairs(meshes) do
        for i = 1, #m.faces, stride do
            local f = m.faces[i]
            stats.faces = stats.faces + 1
            -- Четыре вершины в мировых координатах + смещение чанка в мировые
            -- (наши координаты в world.lua уже мировые)
            local v = {f.p0, f.p1, f.p2, f.p3}
            local projected = {}
            local visibleCount = 0
            for j = 1, 4 do
                local p = math3d.transform(mvp, v[j].x - player.x, v[j].y - player.y, v[j].z - player.z)
                if p.w > state.near then
                    local invW = 1 / p.w
                    local sx = (p.x * invW * 0.5 + 0.5) * w
                    local sy = (1 - (p.y * invW * 0.5 + 0.5)) * h
                    local sz = p.z * invW -- 0..1
                    projected[j] = {x = sx, y = sy, z = sz, s = f.shade}
                    visibleCount = visibleCount + 1
                else
                    projected[j] = nil
                end
            end
            if visibleCount == 4 then
                local p0, p1, p2, p3 = projected[1], projected[2], projected[3], projected[4]
                raster.triangle(state.fb, p0, p1, p2, true)
                raster.triangle(state.fb, p0, p2, p3, true)
                stats.tris = stats.tris + 2
            else
                stats.culled = stats.culled + 1
            end
        end
    end

    return state.fb:render(), stats
end

M.newState = newState
return M
