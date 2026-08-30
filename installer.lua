-- installer.lua — установщик Minecraft 3D для CC:Tweaked.
-- Возможности:
--   1. Выбор директории установки (по умолчанию /minecraft3d)
--   2. Список устанавливаемых файлов с размерами
--   3. Прогресс-бар копирования
--   4. Проверка зависимостей (Advanced Monitor)
--   5. Создание startup-скрипта (опционально)
--   6. FPS-настройки и seed

local function clear() term.clear() term.setCursorPos(1, 1) end
local function center(y, text)
    local w, _ = term.getSize()
    term.setCursorPos(math.floor((w - #text) / 2) + 1, y)
    term.write(text)
end

-- Определяем "своё" местоположение: ищем installer.lua в текущей директории
local function scriptDir()
    local info = debug.getinfo(1, "S").source
    -- "=installer" → "/"
    if info:sub(1, 1) == "@" then
        local path = info:sub(2)
        return fs.getDir(path) or "/"
    end
    return "/"
end

local SRC_DIR = scriptDir()
print("Источник: " .. SRC_DIR)

-- Список файлов для копирования
local FILES = {
    {src = "minecraft3d.lua",   dst = "minecraft3d.lua",   required = true},
    {src = "src/math3d.lua",    dst = "src/math3d.lua",    required = true},
    {src = "src/framebuffer.lua", dst = "src/framebuffer.lua", required = true},
    {src = "src/raster.lua",    dst = "src/raster.lua",    required = true},
    {src = "src/noise.lua",     dst = "src/noise.lua",     required = true},
    {src = "src/world.lua",     dst = "src/world.lua",     required = true},
    {src = "src/optimizer.lua", dst = "src/optimizer.lua", required = true},
    {src = "src/renderer.lua",  dst = "src/renderer.lua",  required = true},
    {src = "src/game.lua",      dst = "src/game.lua",      required = true},
}

-- Считаем размер всех исходных файлов
local function totalSize()
    local s = 0
    for _, f in ipairs(FILES) do
        if fs.exists(SRC_DIR .. f.src) then
            s = s + fs.getSize(SRC_DIR .. f.src)
        end
    end
    return s
end

-- Проверка всех файлов
local function checkFiles()
    local missing = {}
    for _, f in ipairs(FILES) do
        if not fs.exists(SRC_DIR .. f.src) then
            missing[#missing + 1] = f.src
        end
    end
    return missing
end

-- Проверка зависимостей
local function checkDeps()
    local hasAdv = false
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "monitor" then
            local p = peripheral.wrap(name)
            if p and p.setTextScale then hasAdv = true; break end
        end
    end
    return hasAdv
end

-- Рисуем прогресс-бар
local function drawBar(x, y, w, ratio, label)
    local fill = math.floor(w * math.max(0, math.min(1, ratio)))
    term.setCursorPos(x, y)
    term.write("[")
    term.setBackgroundColour(colours.green)
    term.write(string.rep(" ", fill))
    term.setBackgroundColour(colours.grey)
    term.write(string.rep(" ", w - fill))
    term.setBackgroundColour(colours.black)
    term.write("] " .. string.format("%3d%%", math.floor(ratio * 100)))
    if label then
        term.setCursorPos(x, y + 1)
        term.write(label)
    end
end

-- Копирование одного файла с прогрессом
local function copyFile(src, dst, onChunk)
    local inp = fs.open(src, "rb")
    if not inp then return false, "Не удалось открыть " .. src end
    -- Убедимся, что директория назначения существует
    local dir = dst:match("^(.*)/")
    if dir and dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
    local out = fs.open(dst, "wb")
    if not out then inp.close(); return false, "Не удалось создать " .. dst end

    local data = inp.readAll()
    inp.close()
    -- Пишем чанками, чтобы не зависнуть на больших файлах
    local chunk = 512
    local written = 0
    while written < #data do
        local slice = data:sub(written + 1, math.min(written + chunk, #data))
        out.write(slice)
        written = written + #slice
        if onChunk then onChunk(#slice) end
    end
    out.close()
    return true
end

-- Главный процесс установки
local function doInstall(targetDir, options)
    clear()
    center(1, "=== Установка Minecraft 3D ===")
    print()
    print("Целевая директория: " .. targetDir)
    print()

    -- Проверка файлов
    local missing = checkFiles()
    if #missing > 0 then
        term.setTextColour(colours.red)
        print("ОШИБКА: Не найдены исходные файлы:")
        for _, m in ipairs(missing) do print("  - " .. m) end
        term.setTextColour(colours.white)
        return false
    end

    -- Проверка зависимостей
    local hasAdv = checkDeps()
    if not hasAdv then
        term.setTextColour(colours.yellow)
        print("ВНИМАНИЕ: Advanced Monitor не найден.")
        print("Для запуска нужен Advanced Monitor рядом с компьютером.")
        term.setTextColour(colours.white)
        print()
    end

    -- Создаём директорию
    if not fs.exists(targetDir) then
        fs.makeDir(targetDir)
    end
    if not fs.exists(targetDir .. "/src") then
        fs.makeDir(targetDir .. "/src")
    end

    local total = totalSize()
    local done = 0
    local startY = 8

    term.setCursorPos(1, startY)
    print("Копирование файлов...")

    for i, f in ipairs(FILES) do
        term.setCursorPos(1, startY + 1)
        term.write(string.format("[%2d/%2d] %-25s", i, #FILES, f.dst))
        local src = SRC_DIR .. f.src
        local dst = targetDir .. "/" .. f.dst
        local ok, err = copyFile(src, dst, function(n) done = done + n end)
        if not ok then
            term.setTextColour(colours.red)
            print(" ОШИБКА: " .. err)
            term.setTextColour(colours.white)
            return false
        end
        -- обновляем прогресс-бар
        drawBar(1, startY + 3, 40, done / total)
    end

    print()
    term.setTextColour(colours.lime)
    center(startY + 5, "Установка завершена!")
    term.setTextColour(colours.white)

    -- Опционально: startup
    if options.startup then
        local startup = targetDir .. "/startup"
        local f = fs.open(startup, "w")
        f.write("shell.run(\"" .. targetDir .. "/minecraft3d.lua\")\n")
        f.close()
        print("Создан startup: " .. startup)
    end

    -- Сохраняем конфиг
    if options.saveConfig then
        local cfg = fs.open(targetDir .. "/config.cfg", "w")
        cfg.write("seed=" .. tostring(options.seed) .. "\n")
        cfg.write("chunkDist=" .. tostring(options.chunkDist) .. "\n")
        cfg.write("skipDistance=" .. tostring(options.skipDistance) .. "\n")
        cfg.write("targetFPS=" .. tostring(options.targetFPS) .. "\n")
        cfg.write("textScale=" .. tostring(options.textScale) .. "\n")
        cfg.close()
        print("Сохранён конфиг: " .. targetDir .. "/config.cfg")
    end

    print()
    center(startY + 8, "Запуск: " .. targetDir .. "/minecraft3d.lua")
    print()
    print("Нажмите любую клавишу...")
    os.pullEvent("key")
    return true
end

-- === UI: выбор пути установки ===
local function uiChoosePath()
    clear()
    center(1, "=== Minecraft 3D — Установщик ===")
    print()
    print("Куда установить игру?")
    print()
    print("  1) /minecraft3d         (по умолчанию)")
    print("  2) /games/minecraft3d   (в /games)")
    print("  3) /")
    print("  4) Свой путь...")
    print()
    write("Выбор [1]: ")
    local ch = read()
    if ch == "" or ch == "1" then return "/minecraft3d"
    elseif ch == "2" then return "/games/minecraft3d"
    elseif ch == "3" then return "/"
    elseif ch == "4" then
        write("Введите путь: ")
        local p = read()
        if p == "" then return "/minecraft3d" end
        if p:sub(-1) == "/" then p = p:sub(1, -2) end
        return p
    end
    return "/minecraft3d"
end

-- === UI: опции ===
local function uiOptions()
    clear()
    center(1, "=== Настройки ===")
    print()
    local opts = {
        seed = 1337,
        chunkDist = 3,
        skipDistance = 5,
        targetFPS = 20,
        textScale = 0.5,
        startup = false,
        saveConfig = true,
    }
    write("Сид мира [1337]: ")
    local v = read()
    if v ~= "" then opts.seed = tonumber(v) or opts.seed end
    write("Радиус загрузки чанков [3]: ")
    v = read()
    if v ~= "" then opts.chunkDist = tonumber(v) or opts.chunkDist end
    write("Дальность прорисовки (чанков) [5]: ")
    v = read()
    if v ~= "" then opts.skipDistance = tonumber(v) or opts.skipDistance end
    write("Целевой FPS [20]: ")
    v = read()
    if v ~= "" then opts.targetFPS = tonumber(v) or opts.targetFPS end
    write("Масштаб текста монитора 0.5/1/2 [0.5]: ")
    v = read()
    if v ~= "" then opts.textScale = tonumber(v) or opts.textScale end
    write("Запускать при старте компьютера? (y/n) [n]: ")
    v = read()
    if v == "y" or v == "Y" then opts.startup = true end
    return opts
end

-- === Главное меню ===
local function main()
    -- Проверка файлов прямо при старте
    local missing = checkFiles()
    if #missing > 0 then
        term.setTextColour(colours.red)
        print("ОШИБКА: Рядом с installer.lua должны лежать исходные файлы.")
        for _, m in ipairs(missing) do print("  - " .. m) end
        term.setTextColour(colours.white)
        return
    end

    while true do
        clear()
        center(1, "=== Minecraft 3D — Установщик ===")
        center(2, "Софт-рендер на ASCII-мониторе CC:Tweaked")
        print()
        print("  1) Установить")
        print("  2) Удалить (/minecraft3d)")
        print("  3) Справка")
        print("  4) Выход")
        print()
        write("Выбор: ")
        local ch = read()
        if ch == "1" then
            local target = uiChoosePath()
            local opts = uiOptions()
            doInstall(target, opts)
        elseif ch == "2" then
            clear()
            center(1, "=== Удаление ===")
            print()
            if fs.exists("/minecraft3d") then
                print("Удаляю /minecraft3d ...")
                fs.delete("/minecraft3d")
                print("Готово.")
            else
                print("Папка /minecraft3d не найдена.")
            end
            print()
            print("Нажмите любую клавишу...")
            os.pullEvent("key")
        elseif ch == "3" then
            clear()
            center(1, "=== Справка ===")
            print()
            print("Minecraft 3D — воксельный 3D-движок для CC:Tweaked.")
            print()
            print("Особенности оптимизации:")
            print("  - Greedy meshing (склейка смежных граней)")
            print("  - Frustum culling (отсечение за пирамидой видимости)")
            print("  - Distance culling (LOD по дальности)")
            print("  - Z-буфер для скрытия невидимых поверхностей")
            print("  - Back-face culling (отсечение обратных граней)")
            print("  - Адаптивный FPS: автоснижение детализации")
            print("  - Кэш чанков и сеток")
            print()
            print("Управление:")
            print("  WASD — движение, Space — прыжок")
            print("  Стрелки или мышь — поворот камеры")
            print("  Q/Esc — выход")
            print()
            print("Требования: Advanced Monitor.")
            print()
            print("Нажмите любую клавишу...")
            os.pullEvent("key")
        elseif ch == "4" then
            return
        end
    end
end

parallel = parallel or {waitForAny = function(...) return ... end}
main()
