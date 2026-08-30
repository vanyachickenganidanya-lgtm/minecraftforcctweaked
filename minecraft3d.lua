-- minecraft3d.lua — точка входа после установки.
-- Запускает игру, привязываясь к ближайшему Advanced Monitor.

-- Определяем свою директорию (работает и при запуске из /, и из /minecraft3d)
local function scriptDir()
    local info = debug.getinfo(1, "S").source
    if info:sub(1, 1) == "@" then
        local path = info:sub(2)
        return fs.getDir(path) or "/"
    end
    return "/"
end

local SCRIPT_DIR = scriptDir()
print("[minecraft3d] Скрипт в: " .. SCRIPT_DIR)
local SRC_DIR = SCRIPT_DIR .. "src/"
print("[minecraft3d] Модули в: " .. SRC_DIR)

-- Свой загрузчик модулей, чтобы не зависеть от require() и его хитрого поведения
-- в CC:Tweaked (которая ищет модули относительно текущей программы).
-- Используем обычный dofile с абсолютным путём + кеш.
local moduleCache = {}
local function loadModule(name)
    if moduleCache[name] then return moduleCache[name] end
    local path = SRC_DIR .. name .. ".lua"
    if not fs.exists(path) then
        error("Модуль не найден: " .. path)
    end
    -- Загружаем в чистое окружение, чтобы не наследовать локалки
    local chunk, err = loadfile(path)
    if not chunk then error("Ошибка загрузки " .. path .. ": " .. tostring(err)) end
    local ok, result = pcall(chunk)
    if not ok then error("Ошибка выполнения " .. path .. ": " .. tostring(result)) end
    moduleCache[name] = result
    return result
end

-- Эмулируем require() через наш загрузчик
local origRequire = require
local function myRequire(name)
    -- Пробуем наш загрузчик
    local ok, mod = pcall(loadModule, name)
    if ok then return mod end
    -- Fallback к стандартному require
    return origRequire(name)
end

-- Ищем монитор
local function findMonitor()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "monitor" then
            local p = peripheral.wrap(name)
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

-- Уменьшаем масштаб текста
monitor.setTextScale(0.5)

local w, h = monitor.getSize()
print("Запуск Minecraft 3D на мониторе " .. w .. "x" .. h)

-- Подменяем term на монитор
local origTerm = term
term = monitor
term.clear()
term.setCursorPos(1, 1)

-- Подменяем глобальный require на наш загрузчик
_G.require = myRequire
_G.moduleCache = moduleCache
_G.SRC_DIR = SRC_DIR

-- Загружаем game.lua абсолютным путём
local gamePath = SRC_DIR .. "game.lua"
print("[minecraft3d] Загружаю: " .. gamePath)
local gameChunk, err = loadfile(gamePath)
if not gameChunk then
    term = origTerm
    print("Ошибка загрузки " .. gamePath .. ": " .. tostring(err))
    return
end
local ok, gameOrErr = pcall(gameChunk)
if not ok then
    term = origTerm
    print("Ошибка выполнения " .. gamePath .. ":")
    print(gameOrErr)
    return
end
local game = gameOrErr

if type(game) ~= "table" or type(game.run) ~= "function" then
    term = origTerm
    print("Ошибка: game.lua не вернул таблицу с функцией run")
    return
end

-- Запуск игры
game.run(monitor, monitor, {
    seed = 1337,
    chunkDist = 3,
    skipDistance = 5,
    targetFPS = 20,
})

term = origTerm
print("Игра завершена.")

