-- math3d.lua — матрицы 4x4 и проекции для 3D-рендера
-- Колонко-ориентированные матрицы (col-major), совместимы с большинством GPU API.

local M = {}

function M.identity()
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    }
end

-- Умножение матриц: c = a * b
function M.mul(a, b)
    local c = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    for i = 0, 3 do
        for j = 0, 3 do
            local s = 0
            for k = 0, 3 do
                s = s + a[k * 4 + i + 1] * b[j * 4 + k + 1]
            end
            c[j * 4 + i + 1] = s
        end
    end
    return c
end

-- Трансформация точки с помощью матрицы
function M.transform(m, x, y, z)
    return {
        x = m[1] * x + m[5] * y + m[9]  * z + m[13],
        y = m[2] * x + m[6] * y + m[10] * z + m[14],
        z = m[3] * x + m[7] * y + m[11] * z + m[15],
        w = m[4] * x + m[8] * y + m[12] * z + m[16],
    }
end

-- Перспективная проекция (правосторонняя)
function M.perspective(fovY, aspect, near, far)
    local f = 1 / math.tan(fovY / 2)
    local nf = 1 / (near - far)
    return {
        f / aspect, 0, 0,                         0,
        0,          f, 0,                         0,
        0, 0, (far + near) * nf,                 -1,
        0, 0, 2 * far * near * nf,                0,
    }
end

-- Look-at: камера смотрит на target с позиции eye, up — мировой "вверх"
function M.lookAt(eye, target, up)
    local zx, zy, zz = eye.x - target.x, eye.y - target.y, eye.z - target.z
    local zl = math.sqrt(zx * zx + zy * zy + zz * zz)
    if zl < 1e-6 then zx, zy, zz = 0, 0, 1 else zx, zy, zz = zx / zl, zy / zl, zz / zl end
    local xx = up.y * zz - up.z * zy
    local xy = up.z * zx - up.x * zz
    local xz = up.x * zy - up.y * zx
    local xl = math.sqrt(xx * xx + xy * xy + xz * xz)
    if xl < 1e-6 then xx, xy, xz = 1, 0, 0 else xx, xy, xz = xx / xl, xy / xl, xz / xl end
    local yx = zy * xz - zz * xy
    local yy = zz * xx - zx * xz
    local yz = zx * xy - zy * xx
    return {
        xx, yx, zx, 0,
        xy, yy, zy, 0,
        xz, yz, zz, 0,
        -(xx * eye.x + xy * eye.y + xz * eye.z),
        -(yx * eye.x + yy * eye.y + yz * eye.z),
        -(zx * eye.x + zy * eye.y + zz * eye.z),
        1,
    }
end

-- Вращение вокруг оси Y (yaw)
function M.rotationY(a)
    local c, s = math.cos(a), math.sin(a)
    return {
        c, 0, -s, 0,
        0, 1,  0, 0,
        s, 0,  c, 0,
        0, 0,  0, 1,
    }
end

-- Вращение вокруг оси X (pitch)
function M.rotationX(a)
    local c, s = math.cos(a), math.sin(a)
    return {
        1, 0,  0, 0,
        0, c,  s, 0,
        0,-s,  c, 0,
        0, 0,  0, 1,
    }
end

return M
