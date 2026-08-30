-- get.lua — установщик Minecraft 3D ОДНОЙ КОМАНДОЙ.
-- Скачивает все файлы и сразу предлагает запустить игру.
-- Больше НЕ запускает installer.lua — он не нужен, файлы уже на месте.
--
-- Запуск:
--   wget https://raw.githubusercontent.com/vanyachickenganidanya-lgtm/minecraftforcctweaked/main/get.lua /get
--   /get

local REPO = "vanyachickenganidanya-lgtm/minecraftforcctweaked"
local BRANCH = "main"
local BASE = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local DEST = "/minecraft3d"

local function say(s) term.setTextColour(colours.cyan); print(s); term.setTextColour(colours.white) end
local function ok(s) term.setTextColour(colours.lime); print(s); term.setTextColour(colours.white) end
local function err(s) term.setTextColour(colours.red); print(s); term.setTextColour(colours.white) end

-- Список файлов (все, кроме installer.lua и get.lua — они не нужны игре)
local FILES = {
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

-- Скачивание через wget (встроен в CC:Tweaked, поддерживает HTTPS)
local function downloadWget(url, dst)
    local ok_run, err_msg = pcall(function()
        local result = shell.run("wget", url, dst)
        if not result then error("wget вернул false") end
    end)
    return ok_run, err_msg
end

-- Резерв: через http.get
local function downloadHttp(url, dst)
    if not http or not http.get then return false, "http API недоступен" end
    local ok_run, err_msg = pcall(function()
        local resp = http.get(url)
        if not resp then error("http.get вернул nil") end
        local code = resp.getResponseCode()
        if code ~= 200 then
            resp.close()
            error("HTTP " .. tostring(code))
        end
        local data = resp.readAll()
        resp.close()
        if not data or #data == 0 then error("пустой ответ") end
        local fh = fs.open(dst, "wb")
        if not fh then error("не удалось открыть " .. dst) end
        fh.write(data)
        fh.close()
    end)
    return ok_run, err_msg
end

local function download(url, dst)
    local ok1, e1 = downloadWget(url, dst)
    if ok1 and fs.exists(dst) and fs.getSize(dst) > 0 then
        return "wget"
    end
    local ok2, e2 = downloadHttp(url, dst)
    if ok2 and fs.exists(dst) and fs.getSize(dst) > 0 then
        return "http"
    end
    return nil, "wget: " .. tostring(e1) .. " | http: " .. tostring(e2)
end

-- Создаём директории
say("[*] Создаю " .. DEST .. " и " .. DEST .. "/src ...")
if not fs.exists(DEST) then fs.makeDir(DEST) end
if not fs.exists(DEST .. "/src") then fs.makeDir(DEST .. "/src") end

print()
say("[*] Скачиваю " .. #FILES .. " файлов из GitHub...")
print()

local failed = 0
for i, f in ipairs(FILES) do
    local rel, dst = f[1], f[2]
    local url = BASE .. "/" .. rel
    io.write(string.format("  [%2d/%2d] %-22s ", i, #FILES, rel))
    io.flush()

    local method, err_msg = download(url, dst)
    if method then
        local size = fs.getSize(dst)
        io.write(string.format("OK (%s, %d B)\n", method, size))
    else
        io.write("FAIL\n")
        err("        " .. tostring(err_msg))
        failed = failed + 1
    end
end

print()
if failed > 0 then
    err("[X] Скачано с ошибками: " .. failed .. " из " .. #FILES)
    print()
    say("Проверь, что:")
    print("  1) На компьютере включён HTTP/HTTPS")
    print("  2) Версия CC:Tweaked >= 1.95")
    return
end

-- Проверяем Advanced Monitor
local hasAdv = false
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        local p = peripheral.wrap(name)
        if p and p.setTextScale then hasAdv = true; break end
    end
end

ok("[OK] Все файлы скачаны в " .. DEST)
print()
if not hasAdv then
    term.setTextColour(colours.yellow)
    print("[!] ВНИМАНИЕ: Advanced Monitor не найден.")
    print("    Поставь Advanced Monitor рядом с компьютером для запуска игры.")
    term.setTextColour(colours.white)
    print()
end

say("[*] Запустить игру сейчас? (y/n)")
local ans = read()
if ans == "y" or ans == "Y" or ans == "" then
    if hasAdv then
        -- Переходим в директорию игры и запускаем оттуда (важно для require())
        shell.setDir(DEST)
        shell.run(DEST .. "/minecraft3d")
    else
        err("Не могу запустить: нет Advanced Monitor.")
    end
end
