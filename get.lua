-- get.lua — скачивает Minecraft 3D и все зависимости ОДНОЙ КОМАНДОЙ.
-- Запуск:
--   wget https://raw.githubusercontent.com/vanyachickenganidanya-lgtm/minecraftforcctweaked/main/get.lua /get
--   /get
--
-- Скрипт скачает сам себя повторно (чтобы получить актуальный список файлов),
-- затем построчно загрузит каждый файл из репозитория и положит в /minecraft3d/.

local REPO = "vanyachickenganidanya-lgtm/minecraftforcctweaked"
local BRANCH = "main"
local BASE = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local DEST = "/minecraft3d"

local function say(s) term.setTextColour(colours.cyan); print(s); term.setTextColour(colours.white) end
local function ok(s) term.setTextColour(colours.lime); print(s); term.setTextColour(colours.white) end
local function err(s) term.setTextColour(colours.red); print(s); term.setTextColour(colours.white) end

-- Список файлов: {относительный путь в репо, путь на диске}
local FILES = {
    {"installer.lua",            DEST .. "/installer.lua"},
    {"minecraft3d.lua",          DEST .. "/minecraft3d.lua"},
    {"src/math3d.lua",           DEST .. "/src/math3d.lua"},
    {"src/framebuffer.lua",      DEST .. "/src/framebuffer.lua"},
    {"src/raster.lua",           DEST .. "/src/raster.lua"},
    {"src/noise.lua",            DEST .. "/src/noise.lua"},
    {"src/world.lua",            DEST .. "/src/world.lua"},
    {"src/optimizer.lua",        DEST .. "/src/optimizer.lua"},
    {"src/renderer.lua",         DEST .. "/src/renderer.lua"},
    {"src/game.lua",             DEST .. "/src/game.lua"},
}

-- Создаём директории
say("[*] Создаю " .. DEST .. " и " .. DEST .. "/src ...")
if not fs.exists(DEST) then fs.makeDir(DEST) end
if not fs.exists(DEST .. "/src") then fs.makeDir(DEST .. "/src") end

local function bar(pct)
    local w = 30
    local fill = math.floor(w * pct)
    io.write("[")
    io.write(string.rep("=", fill))
    io.write(string.rep(" ", w - fill))
    io.write("] " .. string.format("%3d%%", math.floor(pct * 100)))
end

say("[*] Скачиваю " .. #FILES .. " файлов из GitHub (" .. REPO .. "@" .. BRANCH .. ") ...")
print()

for i, f in ipairs(FILES) do
    local rel, dst = f[1], f[2]
    local url = BASE .. "/" .. rel
    io.write(string.format("  [%2d/%2d] %-22s ", i, #FILES, rel))
    io.flush()
    local ok_run, err_msg = pcall(function()
        -- CC:Tweaked wget: shell.run("wget", url, dst) ИЛИ http.get(url)
        -- Используем http.get — он работает с raw.githubusercontent.com
        local resp = http.get(url)
        if not resp then error("HTTP запрос не удался") end
        local code = resp.getResponseCode()
        if code ~= 200 then
            resp.close()
            error("HTTP " .. tostring(code))
        end
        local data = resp.readAll()
        resp.close()
        if not data or #data == 0 then error("пустой ответ") end
        local fh = fs.open(dst, "wb")
        if not fh then error("не удалось открыть " .. dst .. " для записи") end
        fh.write(data)
        fh.close()
    end)
    if ok_run then
        io.write("OK\n")
    else
        err("FAIL: " .. tostring(err_msg))
        error("Прерываю — файл " .. rel .. " не скачался")
    end
end

print()
ok("[✓] Все файлы скачаны в " .. DEST)
print()
say("[*] Запускаю установщик...")
print()

-- Запускаем установщик
shell.run(DEST .. "/installer")
