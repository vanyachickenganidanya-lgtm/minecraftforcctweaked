-- minecraft3d.lua — точка входа после установки.
-- Запускает игру, привязываясь к ближайшему Advanced Monitor.

local game = dofile("src/game.lua")

-- Ищем монитор
local function findMonitor()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "monitor" then
            local p = peripheral.wrap(name)
            -- Проверяем, что это Advanced Monitor (не обычный)
            if p and p.getTextScale and p.setTextScale then
                return p
            end
        end
    end
    return nil
end

local monitor = findMonitor()
if not monitor then
    print("Ошибка: Advanced Monitor не найден.")
    print("Поставьте Advanced Monitor и положите его рядом с компьютером.")
    return
end

-- Уменьшаем масштаб текста, чтобы получить больше FPS (больше пикселей на символ = быстрее)
monitor.setTextScale(0.5)

local w, h = monitor.getSize()
print("Запуск Minecraft 3D на мониторе " .. w .. "x" .. h)

-- Перенаправляем вывод в монитор: term = monitor
local origTerm = term
term = monitor
term.clear()
term.setCursorPos(1, 1)

-- Запуск игры
game.run(monitor, monitor, {
    seed = 1337,
    chunkDist = 3,
    skipDistance = 5,
    targetFPS = 20,
})

term = origTerm
print("Игра завершена.")
