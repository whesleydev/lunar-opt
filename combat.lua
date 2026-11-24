-- combat.lua | teste de vida do combate | aimbot + esp minimo
-- roda sozinho, sem lib, sem menu. se isso funcionar, o problema esta no script grande.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local DRAWING = (type(Drawing) == "table") and Drawing or nil

local CFG = { aim = true, fov = 170, part = "Head", team = true, esp = true }

local hl = {}
local draws = {}

local function same_team(pl)
    if not lp or not pl then return false end
    local a, b = pl.Team, lp.Team
    if a and b then return a == b end
    return false
end

local function part_of(char)
    local p = char:FindFirstChild(CFG.part) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    return p
end

local function pick()
    if not cam or not lp then return nil end
    local c = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local best, bestd
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= lp and pl.Character then
            local hum = pl.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and not (CFG.team and same_team(pl)) then
                local p = part_of(pl.Character)
                if p then
                    local sp, on = cam:WorldToViewportPoint(p.Position)
                    if on then
                        local d = (Vector2.new(sp.X, sp.Y) - c).Magnitude
                        if d <= CFG.fov and (not bestd or d < bestd) then
                            best, bestd = p, d
                        end
                    end
                end
            end
        end
    end
    return best
end

local hits, errs = 0, 0

RunService:BindToRenderStep("combatTestAim", Enum.RenderPriority.Camera.Value + 1, function()
    if not CFG.aim or not cam then return end
    local ok, part = pcall(pick)
    if not ok then errs += 1 return end
    if part then
        local ok2 = pcall(function()
            cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, part.Position), 0.35)
        end)
        if ok2 then hits += 1 else errs += 1 end
    end
end)

local function mk(kind)
    if not DRAWING then return nil end
    local ok, o = pcall(function() return DRAWING.new(kind) end)
    if ok then return o end
    return nil
end

local function clean(pl)
    local set = draws[pl]
    if not set then return end
    for _, o in pairs(set) do pcall(function() o.Visible = false end) end
end

local function draw(pl)
    local char = pl.Character
    if not char then clean(pl) return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then clean(pl) return end
    if CFG.team and same_team(pl) then clean(pl) return end

    local head = part_of(char)
    if not head then return end

    local set = draws[pl]
    if not set then set = {} draws[pl] = set end
    if not set.box then set.box = mk("Square") end
    if not set.name then set.name = mk("Text") end
    if not set.hp then set.hp = mk("Square") end

    local sp = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 2, 0))
    if set.box then
        local size = 2400 / math.max((cam.CFrame.Position - head.Position).Magnitude, 1)
        set.box.Visible = CFG.esp
        set.box.Color = Color3.fromRGB(120, 220, 150)
        set.box.Thickness = 1
        set.box.Position = Vector2.new(sp.X - size / 2, sp.Y - size)
        set.box.Size = Vector2.new(size, size * 1.6)
    end
    if set.name then
        set.name.Visible = CFG.esp
        set.name.Color = Color3.fromRGB(220, 240, 255)
        set.name.Size = 13
        set.name.Center = true
        set.name.Text = pl.Name
        set.name.Position = Vector2.new(sp.X, sp.Y - 6)
    end
    if set.hp then
        set.hp.Visible = CFG.esp
        set.hp.Color = Color3.fromRGB(90, 200, 110)
        set.hp.Position = Vector2.new(sp.X - 26, sp.Y + 4)
        set.hp.Size = Vector2.new(4, 30 * (hum.Health / math.max(hum.MaxHealth, 1)))
    end
end

RunService.RenderStepped:Connect(function()
    if not CFG.esp then
        for pl in pairs(draws) do clean(pl) end
        return
    end

    local alive = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= lp then
            local ok = pcall(draw, pl)
            if ok then alive[pl] = true else errs += 1 end
        end
    end
    for pl in pairs(draws) do
        if not alive[pl] then clean(pl) end
    end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "CombatTest"
gui.ResetOnSpawn = false
local host = (gethui and select(2, pcall(gethui))) or game:GetService("CoreGui")
gui.Parent = host

local box = Instance.new("TextButton")
box.Size = UDim2.fromOffset(200, 54)
box.Position = UDim2.fromOffset(10, 90)
box.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
box.BackgroundTransparency = 0.15
box.BorderSizePixel = 0
box.Font = Enum.Font.Code
box.TextSize = 10
box.TextColor3 = Color3.fromRGB(140, 210, 170)
box.TextXAlignment = Enum.TextXAlignment.Left
box.Text = ""
box.Parent = gui

task.spawn(function()
    while true do
        task.wait(1)
        local alvos = 0
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= lp and pl.Character and pl.Character:FindFirstChildOfClass("Humanoid") then
                alvos += 1
            end
        end
        box.Text = string.format(
            "combate teste\nmira %s  esp %s\ndraw %s  alvos %d\ntravadas %d  erros %d",
            CFG.aim and "on" or "off",
            CFG.esp and "on" or "off",
            DRAWING and "ok" or "sem",
            alvos, hits, errs)
    end
end)

box.MouseButton1Click:Connect(function()
    CFG.aim = not CFG.aim
end)
