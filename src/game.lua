-- game.lua — главный игровой цикл: ввод, движение, физика, рендер.

local world = require("world")
local renderer = require("renderer")
local optimizer = require("optimizer")

local M = {}

local function now() return os.epoch and os.epoch("utc") or os.clock() * 1000 end

function M.run(monitor, term, opts)
    opts = opts or {}
    local w, h = monitor.getSize()
    local state = renderer.newState(w, h)

    local W = world.new(opts.seed or 1337)
    local O = optimizer.new(W, {
        chunkDist = opts.chunkDist or 3,
        skipDistance = opts.skipDistance or 5,
        targetFPS = opts.targetFPS or 20,
    })

    local player = {
        x = 8, y = 24, z = 8,
        yaw = 0, pitch = 0,
        vy = 0,
        onGround = false,
    }

    local lastT = now()
    local running = true
    local frame = 1
    local lastStats = ""

    -- HUD: маленькая строка поверх кадра (без мерцания)
    local function drawHud(fps, faces, tris)
        local hud = string.format("FPS:%2d F:%4d T:%5d D:%.2f  WASD/Space/Arrows/Q",
            math.floor(fps), faces, tris, O.detailLevel)
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColour(colours.black)
        monitor.setTextColour(colours.white)
        monitor.write(hud)
    end

    -- Один шаг физики: гравитация + проверка коллизий с миром
    local function physics(dt)
        player.vy = player.vy - 24 * dt
        -- Движение
        local step = 4 * dt
        local dx = 0
        local dz = 0
        if keys.isDown and keys.isDown("w") then dx = dx + math.cos(player.yaw) * step end
        if keys.isDown and keys.isDown("s") then dx = dx - math.cos(player.yaw) * step end
        if keys.isDown and keys.isDown("a") then dz = dz - math.sin(player.yaw) * step end
        if keys.isDown and keys.isDown("d") then dz = dz + math.sin(player.yaw) * step end
        if keys.isDown and keys.isDown("space") and player.onGround then
            player.vy = 8
            player.onGround = false
        end

        player.x = player.x + dx
        player.z = player.z + dz
        player.y = player.y + player.vy * dt

        -- Простая коллизия: если в блоке — вытолкнуть вверх
        local bx, by, bz = math.floor(player.x), math.floor(player.y), math.floor(player.z)
        if W:blockAt(bx, by, bz) ~= 0 or W:blockAt(bx, by - 1, bz) ~= 0 then
            -- ищем безопасную Y вверх
            for _ = 1, 4 do
                player.y = player.y + 1
                if W:blockAt(bx, by, bz) == 0 then break end
            end
            player.vy = 0
            player.onGround = true
        else
            player.onGround = false
        end
    end

    -- Главный цикл
    local mouseAttached = false
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "mouse" then mouseAttached = true; break end
    end

    local tasks = {
        function() -- render loop
            local physAccum = 0
            while running do
                local t0 = now()
                -- Физика: фиксированный шаг 1/30 с
                physAccum = physAccum + (1 / 60)
                while physAccum >= 1 / 30 do
                    physics(1 / 30)
                    physAccum = physAccum - 1 / 30
                end
                local img, stats = renderer.render(state, W, player, O, " ")
                monitor.setBackgroundColour(colours.black)
                monitor.clear()
                monitor.setCursorPos(1, 1)
                monitor.write(img)
                lastStats = stats
                local dt = (now() - t0) / 1000
                O:tick(dt)
                frame = frame + 1
                if frame % 6 == 0 then
                    drawHud(O.fps, stats.faces, stats.tris)
                end
                -- Cap FPS: чтобы CPU не горел. Можно убрать.
                local target = 1 / O.targetFPS
                local spent = (now() - t0) / 1000
                if spent < target then sleep(target - spent) end
            end
        end,
        function() -- input loop (клавиатура + мышь)
            while running do
                local e, a, b, c, d = os.pullEvent()
                if e == "key" then
                    if a == keys.q or a == keys.escape then running = false
                    elseif a == keys.left then player.yaw = player.yaw - 0.1
                    elseif a == keys.right then player.yaw = player.yaw + 0.1
                    elseif a == keys.up then player.pitch = math.min(math.pi / 2 - 0.01, player.pitch + 0.05)
                    elseif a == keys.down then player.pitch = math.max(-math.pi / 2 + 0.01, player.pitch - 0.05)
                    end
                elseif e == "mouse_move" and mouseAttached then
                    -- a = side (1), b = x, c = y
                    player.yaw = player.yaw - b * 0.005
                    player.pitch = math.max(-math.pi / 2 + 0.01,
                        math.min(math.pi / 2 - 0.01, player.pitch - c * 0.005))
                elseif e == "terminate" then
                    running = false
                end
            end
        end,
    }
    parallel.waitForAny(table.unpack and table.unpack(tasks) or unpack(tasks))
end

return M
