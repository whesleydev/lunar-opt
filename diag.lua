-- diag | lunar.opt
local BASE = "https://raw.githubusercontent.com/whesleydev/lunar-opt/main/lunar_opt.lua"

local function log(...)
    print("[diag]", ...)
end

log("inicio")
log("executor:", tostring(identifyexecutor and identifyexecutor() or "desconhecido"))
log("loadstring:", tostring(type(loadstring)))
log("httpget:", tostring(type(game.HttpGet)))

local ok, body = pcall(function() return game:HttpGet(BASE) end)
if not ok then
    log("falha no download:", tostring(body))
    return
end
log("baixou bytes:", #body)

local chunk, err = loadstring(body)
log("compilou:", tostring(chunk ~= nil), tostring(err))
if not chunk then return end

local pl = game:GetService("Players").LocalPlayer

local function try_parent(label, parent)
    if not parent then
        log(label, "sem container")
        return
    end
    local sg = Instance.new("ScreenGui")
    sg.Name = "LunarDiag"
    sg.ResetOnSpawn = false
    local a, b = pcall(function() sg.Parent = parent end)
    log(label, tostring(a and sg.Parent ~= nil), tostring(b))
    if sg.Parent then
        local f = Instance.new("Frame")
        f.Size = UDim2.fromOffset(170, 56)
        f.Position = UDim2.fromOffset(20, 120)
        f.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
        f.BorderSizePixel = 0
        f.Parent = sg
        local t = Instance.new("TextLabel")
        t.Size = UDim2.fromScale(1, 1)
        t.BackgroundTransparency = 1
        t.TextColor3 = Color3.fromRGB(120, 210, 160)
        t.Font = Enum.Font.Code
        t.TextSize = 14
        t.Text = "diag ok"
        t.Parent = f
    end
end

if gethui then
    local okg, h = pcall(gethui)
    try_parent("gethui", okg and h or nil)
end
try_parent("coregui", game:GetService("CoreGui"))
if pl then
    local okp, pg = pcall(function() return pl:WaitForChild("PlayerGui", 5) end)
    try_parent("playergui", okp and pg or nil)
end

log("fim")
