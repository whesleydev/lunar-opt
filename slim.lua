-- lunar slim | mira, esp, camera, skin | roblox android
-- arquivo unico, sem lib, sem config salvo. se algo falhar, o painel no topo diz o que.

local VERSION = "slim 1.9"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local DRAWING = (type(Drawing) == "table") and Drawing or nil

local CFG = {
    aim = false, fov = 170, smooth = 0.55, part = "Head",
    lead = 1, speed = 1500, sticky = true, team = false, auto = false,
    esp_box = false, esp_name = false, esp_hp = false, esp_dist = false, esp_skel = false,
    persp = "livre", dist = 8,
    ac_on = false, ac_cps = 12, ac_limit = 0, ac_mode = "os dois",
    ac_x = 0, ac_y = 0,
    ghost = false, offmap = false,
    fly = false, fly_speed = 55, fly_smooth = 0.35, fly_cam = true,
    fly_noclip = false, pad_show = true,
    walk = false, walk_speed = 16,
    hide_tool = false, stow_tool = false, stow_radius = 35, offmap_height = 3000,
    graph = "auto", no_shadows = false, no_postfx = false,
    no_particles = false, no_textures = false, no_sound = false,
    fps_show = true,
}

local stats = { travadas = 0, erros = 0, alvos = 0, fps = 0 }
local last_error = nil

local function fail(tag, err)
    last_error = tag .. ": " .. tostring(err)
    stats.erros += 1
end

-- interface -----------------------------------------------------------

local function holder()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if pg then return pg end
    return game:GetService("CoreGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "LunarSlim"
gui.ResetOnSpawn = false
gui.DisplayOrder = 900
local okp = pcall(function() gui.Parent = holder() end)
if not okp or not gui.Parent then
    gui.Parent = lp:FindFirstChild("PlayerGui")
end

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(292, 430)
panel.Position = UDim2.fromOffset(14, 60)
panel.BackgroundColor3 = Color3.fromRGB(11, 13, 17)
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 10)
pc.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = Color3.fromRGB(17, 20, 26)
header.BorderSizePixel = 0
header.Parent = panel
local hc = Instance.new("UICorner")
hc.CornerRadius = UDim.new(0, 10)
hc.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 0, 20)
title.Position = UDim2.fromOffset(10, 3)
title.BackgroundTransparency = 1
title.Font = Enum.Font.Code
title.TextSize = 13
title.TextColor3 = Color3.fromRGB(130, 210, 165)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "lunar " .. VERSION
title.Parent = header

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -80, 0, 14)
status.Position = UDim2.fromOffset(10, 21)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Code
status.TextSize = 10
status.TextColor3 = Color3.fromRGB(120, 132, 148)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "iniciando"
status.Parent = header

local hide = Instance.new("TextButton")
hide.Size = UDim2.fromOffset(58, 24)
hide.Position = UDim2.new(1, -66, 0, 8)
hide.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
hide.BorderSizePixel = 0
hide.Font = Enum.Font.Code
hide.TextSize = 11
hide.TextColor3 = Color3.fromRGB(180, 190, 205)
hide.Text = "sumir"
hide.Parent = header
local hcc = Instance.new("UICorner")
hcc.CornerRadius = UDim.new(0, 6)
hcc.Parent = hide

local body = Instance.new("ScrollingFrame")
body.Size = UDim2.new(1, -12, 1, -48)
body.Position = UDim2.fromOffset(6, 44)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 3
body.ScrollBarImageColor3 = Color3.fromRGB(70, 78, 90)
body.CanvasSize = UDim2.new()
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = body

local order = 0
local function next_order()
    order += 1
    return order
end

local function mk(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = inst
end

local function section(text)
    local l = mk("TextLabel", {
        Size = UDim2.new(1, -4, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(96, 108, 124),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = string.upper(text),
        LayoutOrder = next_order(),
    }, body)
    return l
end

local function button(text, cb)
    local b = mk("TextButton", {
        Size = UDim2.new(1, -4, 0, 30),
        BackgroundColor3 = Color3.fromRGB(26, 30, 38),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(196, 206, 220),
        Text = text,
        LayoutOrder = next_order(),
    }, body)
    corner(b, 6)
    b.MouseButton1Click:Connect(function()
        local ok, err = pcall(cb)
        if not ok then fail("botao", err) end
    end)
    return b
end

local function toggle(text, getv, setv)
    local row = mk("TextButton", {
        Size = UDim2.new(1, -4, 0, 30),
        BackgroundColor3 = Color3.fromRGB(20, 23, 29),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        LayoutOrder = next_order(),
        Text = "",
    }, body)
    corner(row, 6)

    local label = mk("TextLabel", {
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.fromOffset(9, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(188, 198, 212),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = text,
    }, row)

    local state = mk("TextLabel", {
        Size = UDim2.fromOffset(48, 18),
        Position = UDim2.new(1, -56, 0.5, -9),
        BackgroundColor3 = Color3.fromRGB(34, 38, 46),
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 10,
        TextColor3 = Color3.fromRGB(120, 132, 148),
        Text = "off",
    }, row)
    corner(state, 5)

    local function paint()
        local on = getv()
        state.Text = on and "on" or "off"
        state.BackgroundColor3 = on and Color3.fromRGB(32, 74, 52) or Color3.fromRGB(34, 38, 46)
        state.TextColor3 = on and Color3.fromRGB(140, 220, 170) or Color3.fromRGB(120, 132, 148)
    end

    row.MouseButton1Click:Connect(function()
        local ok, err = pcall(function() setv(not getv()) end)
        if not ok then fail("toggle", err) end
        paint()
    end)
    paint()
    return paint
end

local function stepper(text, minv, maxv, stepv, getv, setv)
    local row = mk("Frame", {
        Size = UDim2.new(1, -4, 0, 30),
        BackgroundColor3 = Color3.fromRGB(20, 23, 29),
        BorderSizePixel = 0,
        LayoutOrder = next_order(),
    }, body)
    corner(row, 6)

    mk("TextLabel", {
        Size = UDim2.new(1, -110, 1, 0),
        Position = UDim2.fromOffset(9, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(188, 198, 212),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = text,
    }, row)

    local value = mk("TextLabel", {
        Size = UDim2.fromOffset(44, 22),
        Position = UDim2.new(1, -104, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(26, 30, 38),
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 10,
        TextColor3 = Color3.fromRGB(150, 210, 175),
        Text = tostring(getv()),
    }, row)
    corner(value, 5)

    local function nudge(dir)
        local v = getv() + dir * stepv
        if v < minv then v = minv end
        if v > maxv then v = maxv end
        v = math.floor(v / stepv + 0.5) * stepv
        setv(v)
        value.Text = tostring(v)
    end

    local minus = mk("TextButton", {
        Size = UDim2.fromOffset(24, 22),
        Position = UDim2.new(1, -132, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(32, 36, 44),
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(190, 200, 214),
        Text = "-",
    }, row)
    corner(minus, 5)

    local plus = mk("TextButton", {
        Size = UDim2.fromOffset(24, 22),
        Position = UDim2.new(1, -56, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(32, 36, 44),
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(190, 200, 214),
        Text = "+",
    }, row)
    corner(plus, 5)

    minus.MouseButton1Click:Connect(function() nudge(-1) end)
    plus.MouseButton1Click:Connect(function() nudge(1) end)

    local function held(btn, dir)
        local held = false
        btn.InputBegan:Connect(function(input)
            local t = input.UserInputType
            if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
            held = true
            task.spawn(function()
                task.wait(0.4)
                while held do
                    nudge(dir)
                    task.wait(0.08)
                end
            end)
        end)
        btn.InputEnded:Connect(function()
            held = false
        end)
    end

    held(minus, -1)
    held(plus, 1)

    return function(v)
        setv(v)
        value.Text = tostring(v)
    end
end

local function cycle(text, options, getv, setv)
    local row = mk("TextButton", {
        Size = UDim2.new(1, -4, 0, 30),
        BackgroundColor3 = Color3.fromRGB(20, 23, 29),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        LayoutOrder = next_order(),
        Text = "",
    }, body)
    corner(row, 6)

    mk("TextLabel", {
        Size = UDim2.new(1, -110, 1, 0),
        Position = UDim2.fromOffset(9, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(188, 198, 212),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = text,
    }, row)

    local value = mk("TextLabel", {
        Size = UDim2.fromOffset(92, 22),
        Position = UDim2.new(1, -100, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(26, 30, 38),
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 10,
        TextColor3 = Color3.fromRGB(150, 210, 175),
        Text = tostring(getv()),
    }, row)
    corner(value, 5)

    row.MouseButton1Click:Connect(function()
        local cur = getv()
        local idx = 1
        for i, opt in ipairs(options) do
            if tostring(opt) == tostring(cur) then idx = i end
        end
        idx = idx % #options + 1
        setv(options[idx])
        value.Text = tostring(options[idx])
    end)

    return function(v)
        setv(v)
        value.Text = tostring(v)
    end
end


local function free_stepper(text, floorv, getv, setv)
    local row = mk("Frame", {
        Size = UDim2.new(1, -4, 0, 30),
        BackgroundColor3 = Color3.fromRGB(20, 23, 29),
        BorderSizePixel = 0,
        LayoutOrder = next_order(),
    }, body)
    corner(row, 6)

    mk("TextLabel", {
        Size = UDim2.new(1, -200, 1, 0),
        Position = UDim2.fromOffset(9, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 10,
        TextColor3 = Color3.fromRGB(188, 198, 212),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = text,
    }, row)

    local value = mk("TextLabel", {
        Size = UDim2.fromOffset(62, 22),
        Position = UDim2.new(1, -132, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(26, 30, 38),
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 10,
        TextColor3 = Color3.fromRGB(150, 210, 175),
        Text = tostring(getv()),
    }, row)
    corner(value, 5)

    local function paint()
        value.Text = tostring(math.floor(getv()))
    end

    local function set(v)
        v = math.floor(v)
        if v < floorv then v = floorv end
        if v > 10000000 then v = 10000000 end
        setv(v)
        paint()
    end

    local function delta()
        local v = getv()
        if v < 100 then return 4 end
        if v < 1000 then return 25 end
        if v < 10000 then return 250 end
        if v < 100000 then return 2500 end
        return 25000
    end

    local function mkbtn(txt, off, cb)
        local b = mk("TextButton", {
            Size = UDim2.fromOffset(28, 22),
            Position = UDim2.new(1, off, 0.5, -11),
            BackgroundColor3 = Color3.fromRGB(32, 36, 44),
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = Enum.Font.Code,
            TextSize = 10,
            TextColor3 = Color3.fromRGB(190, 200, 214),
            Text = txt,
        }, row)
        corner(b, 5)
        b.MouseButton1Click:Connect(function() pcall(cb) end)
        return b
    end

    local menos = mkbtn("<", -162, function() set(getv() - delta()) end)
    local mais = mkbtn(">", -66, function() set(getv() + delta()) end)
    mkbtn("<10", -198, function() set(getv() / 10) end)
    mkbtn("10>", -34, function() set(getv() * 10) end)

    local function held(btn, dir)
        local on = false
        btn.InputBegan:Connect(function(input)
            local t = input.UserInputType
            if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
            on = true
            task.spawn(function()
                task.wait(0.4)
                while on do
                    set(getv() + dir * delta())
                    task.wait(0.08)
                end
            end)
        end)
        btn.InputEnded:Connect(function() on = false end)
    end

    held(menos, -1)
    held(mais, 1)

    paint()
    return paint
end

local function label(text)
    return mk("TextLabel", {
        Size = UDim2.new(1, -4, 0, 26),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 9,
        TextColor3 = Color3.fromRGB(96, 108, 124),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Text = text,
        LayoutOrder = next_order(),
    }, body)
end

-- mira -----------------------------------------------------------------

local locked = nil

local function same_team(pl)
    if not lp or not pl then return false end
    local a, b = pl.Team, lp.Team
    if a and b then return a == b end
    return false
end

local function part_of(char)
    return char:FindFirstChild(CFG.part)
        or char:FindFirstChild("Head")
        or char:FindFirstChild("HumanoidRootPart")
end

local function pick()
    if not cam or not lp then return nil end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

    if CFG.sticky and locked then
        local char = locked.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local part = char and part_of(char)
        if hum and hum.Health > 0 and part and not (CFG.team and same_team(locked)) then
            local sp, on = cam:WorldToViewportPoint(part.Position)
            if on and (Vector2.new(sp.X, sp.Y) - center).Magnitude <= CFG.fov * 1.5 then
                return part
            end
        end
        locked = nil
    end

    local best, bestd, bestpl
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= lp then
            local char = pl.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and not (CFG.team and same_team(pl)) then
                local part = part_of(char)
                if part then
                    local okp, sp, on = pcall(function()
                        return cam:WorldToViewportPoint(part.Position)
                    end)
                    if okp and on then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= CFG.fov and (not bestd or d < bestd) then
                            best, bestd, bestpl = part, d, pl
                        end
                    end
                end
            end
        end
    end

    if bestpl and CFG.sticky then locked = bestpl end
    return best
end

local function aim_loop()
    if not CFG.aim or not cam then return end
    local part = pick()
    if not part then return end

    local pos = part.Position
    if CFG.lead > 0 then
        local okv, vel = pcall(function() return part.AssemblyLinearVelocity end)
        if okv and vel then
            local travel = (pos - cam.CFrame.Position).Magnitude / math.max(CFG.speed, 1)
            pos = pos + vel * travel * CFG.lead
        end
    end

    local target_cf = CFrame.lookAt(cam.CFrame.Position, pos)
    local alpha = math.clamp(CFG.smooth, 0.05, 1)
    cam.CFrame = cam.CFrame:Lerp(target_cf, alpha)
    stats.travadas += 1

    if CFG.auto then
        local char = lp and lp.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            cam.CFrame = target_cf
            pcall(function() tool:Activate() end)
        end
    end
end

-- esp ------------------------------------------------------------------

local SKEL = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" },
}

local draws = {}

local function dnew(kind)
    if not DRAWING then return nil end
    local ok, o = pcall(function() return DRAWING.new(kind) end)
    if ok then return o end
    return nil
end

local function draw_clean(pl)
    local set = draws[pl]
    if not set then return end
    if set.skel then
        for _, line in pairs(set.skel) do
            pcall(function() line.Visible = false end)
        end
    end
    for k, o in pairs(set) do
        if k ~= "skel" then pcall(function() o.Visible = false end) end
    end
end

local function draw_one(pl)
    local char = pl.Character
    if not char then draw_clean(pl) return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then draw_clean(pl) return end
    if CFG.team and same_team(pl) then draw_clean(pl) return end

    local head = part_of(char)
    if not head or not cam then return end

    local set = draws[pl]
    if not set then
        set = { skel = {} }
        draws[pl] = set
    end
    if not set.box then set.box = dnew("Square") end
    if not set.name then set.name = dnew("Text") end
    if not set.hp then set.hp = dnew("Square") end
    if not set.dist then set.dist = dnew("Text") end
    if not set.line then set.line = dnew("Line") end

    local okb, cf, size = pcall(function() return char:GetBoundingBox() end)
    if not okb or not cf or not size then return end
    local okp, sp, on = pcall(function() return cam:WorldToViewportPoint(head.Position) end)
    if not okp or not on then return end
    if not on then return end

    local top = sp
    local ok2, bot = pcall(function() return cam:WorldToViewportPoint(cf.Position - Vector3.new(0, size.Y / 2, 0)) end)
    local h = 40
    if ok2 and bot then h = math.max(top.Y - bot.Y, 18) end
    local w = h * 0.55

    if set.box then
        set.box.Visible = CFG.esp_box
        set.box.Color = Color3.fromRGB(120, 215, 160)
        set.box.Thickness = 1
        set.box.Position = Vector2.new(top.X - w / 2, top.Y)
        set.box.Size = Vector2.new(w, h)
    end
    if set.name then
        set.name.Visible = CFG.esp_name
        set.name.Color = Color3.fromRGB(230, 240, 255)
        set.name.Size = 12
        set.name.Center = true
        set.name.Text = pl.Name
        set.name.Position = Vector2.new(top.X, top.Y - 6)
    end
    if set.hp then
        set.hp.Visible = CFG.esp_hp
        set.hp.Color = Color3.fromRGB(90, 200, 110)
        set.hp.Position = Vector2.new(top.X - w / 2 - 5, top.Y)
        set.hp.Size = Vector2.new(3, h * math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1))
    end
    if set.dist then
        local d = (cam.CFrame.Position - head.Position).Magnitude
        set.dist.Visible = CFG.esp_dist
        set.dist.Color = Color3.fromRGB(190, 200, 215)
        set.dist.Size = 11
        set.dist.Center = true
        set.dist.Text = string.format("%d m", math.floor(d + 0.5))
        set.dist.Position = Vector2.new(top.X, top.Y + h + 4)
    end
    if set.line then
        set.line.Visible = CFG.esp_dist and CFG.esp_skel
        set.line.Color = Color3.fromRGB(120, 215, 160)
        set.line.Thickness = 1
        set.line.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
        set.line.To = Vector2.new(top.X, top.Y + h / 2)
    end

    if CFG.esp_skel then
        for i, pair in ipairs(SKEL) do
            if not set.skel[i] then set.skel[i] = dnew("Line") end
            local a = char:FindFirstChild(pair[1])
            local b = char:FindFirstChild(pair[2])
            local line = set.skel[i]
            if line and a and b then
                local okA, sa = pcall(function() return cam:WorldToViewportPoint(a.Position) end)
                local okB, sb = pcall(function() return cam:WorldToViewportPoint(b.Position) end)
                if okA and okB and sa and sb then
                    line.Visible = true
                    line.Color = Color3.fromRGB(120, 215, 160)
                    line.Thickness = 1
                    line.From = Vector2.new(sa.X, sa.Y)
                    line.To = Vector2.new(sb.X, sb.Y)
                else
                    line.Visible = false
                end
            elseif line then
                line.Visible = false
            end
        end
    else
        for _, line in pairs(set.skel) do
            pcall(function() line.Visible = false end)
        end
    end
end

local function esp_active()
    return CFG.esp_box or CFG.esp_name or CFG.esp_hp or CFG.esp_dist or CFG.esp_skel
end

local function esp_loop()
    if not esp_active() then
        for pl in pairs(draws) do draw_clean(pl) end
        return
    end
    if not DRAWING then return end

    local alive = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= lp then
            local ok = pcall(draw_one, pl)
            if ok then alive[pl] = true end
        end
    end
    for pl in pairs(draws) do
        if not alive[pl] then draw_clean(pl) end
    end
end


-- invisibilidade -------------------------------------------------------

local offmap = { saved = nil, anchored = nil }
local ghost = { on = false }
local item = { hidden = {}, stowed = nil }

local function ghost_hide()
    local char = lp and lp.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            pcall(function()
                d.Transparency = 1
                d.CanQuery = false
                d.CanTouch = false
            end)
        elseif d:IsA("Decal") or d:IsA("Texture") then
            pcall(function() d.Transparency = 1 end)
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            hum.NameDisplayDistance = 0
            hum.HealthDisplayDistance = 0
        end)
    end
end

local function ghost_show()
    local char = lp and lp.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            pcall(function()
                d.Transparency = 0
                d.CanQuery = true
                d.CanTouch = true
            end)
        elseif d:IsA("Decal") or d:IsA("Texture") then
            pcall(function() d.Transparency = 0 end)
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
            hum.NameDisplayDistance = 100
            hum.HealthDisplayDistance = 100
        end)
    end
end

local function offmap_enter()
    local char = lp and lp.Character
    if not char then return end
    offmap.saved = char:GetPivot()
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            offmap.anchored = offmap.anchored or {}
            offmap.anchored[d] = d.Anchored
            pcall(function() d.Anchored = true end)
        end
    end
end

local function offmap_exit()
    local char = lp and lp.Character
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then
                pcall(function() d.Anchored = false end)
            end
        end
        if offmap.saved then
            pcall(function() char:PivotTo(offmap.saved) end)
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            pcall(function() root.AssemblyLinearVelocity = Vector3.new() end)
        end
    end
    offmap.saved = nil
    offmap.anchored = nil
end

local function item_parts(tool)
    local list = {}
    for _, d in ipairs(tool:GetDescendants()) do
        if d:IsA("BasePart") then list[#list + 1] = d end
    end
    return list
end

local function hide_item()
    local char = lp and lp.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return end
    for _, p in ipairs(item_parts(tool)) do
        if item.hidden[p] == nil then item.hidden[p] = p.Transparency end
        pcall(function()
            p.Transparency = 1
            p.CanQuery = false
            p.CanTouch = false
        end)
    end
end

local function show_item()
    for p, tr in pairs(item.hidden) do
        if p and p.Parent then
            pcall(function()
                p.Transparency = tr or 0
                p.CanQuery = true
                p.CanTouch = true
            end)
        end
    end
    item.hidden = {}
end

local function npc_near(maxd)
    local char = lp and lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m ~= char and not Players:GetPlayerFromCharacter(m) then
            local hum = m:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - root.Position).Magnitude <= maxd then
                    return true
                end
            end
        end
    end
    return false
end

local function stow_step()
    local char = lp and lp.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local pack = lp:FindFirstChild("Backpack")
    local tool = char:FindFirstChildOfClass("Tool")

    if CFG.stow_tool and npc_near(CFG.stow_radius or 35) then
        if tool and pack then
            item.stowed = tool
            pcall(function() tool.Parent = pack end)
        end
    elseif item.stowed then
        local t = item.stowed
        item.stowed = nil
        if t and t.Parent == pack and hum then
            pcall(function() hum:EquipTool(t) end)
        end
    end
end

local ghost_tick = 0

RunService.RenderStepped:Connect(function()
    if CFG.ghost then
        ghost_tick += 1
        if not ghost.on or ghost_tick % 20 == 0 then
            ghost.on = true
            pcall(ghost_hide)
        end
    elseif ghost.on then
        ghost.on = false
        pcall(ghost_show)
    end

    if CFG.hide_tool then
        pcall(hide_item)
    elseif next(item.hidden) then
        pcall(show_item)
    end

    if CFG.offmap then
        local char = lp and lp.Character
        if char then
            if not offmap.saved then offmap.saved = char:GetPivot() end
            local target = CFrame.new(0, CFG.offmap_height or 3000, 0)
            pcall(function() char:PivotTo(target) end)
        end
    end

    ghost_tick += 1
    if ghost_tick % 20 == 0 then
        pcall(stow_step)
    end
end)



-- velocidade de andar ---------------------------------------------------

local walk_tick = 0

RunService.Heartbeat:Connect(function()
    walk_tick += 1
    if walk_tick % 10 ~= 0 then return end
    local char = lp and lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if CFG.walk then
        pcall(function() hum.WalkSpeed = CFG.walk_speed end)
    elseif hum.WalkSpeed > 40 then
        pcall(function() hum.WalkSpeed = 16 end)
    end
end)


-- leveza ---------------------------------------------------------------

local perf = { saved = {} }

local function set_quality(level)
    return pcall(function()
        local us = UserSettings():GetService("UserGameSettings")
        if level == "auto" then
            us.SavedQualityLevel = Enum.SavedQualitySetting.Automatic
        else
            us.SavedQualityLevel = Enum.SavedQualitySetting["Q" .. tostring(level)]
        end
    end)
end

local function remember(inst, key, value)
    local k = tostring(inst)
    if perf.saved[k] == nil then
        perf.saved[k] = { inst = inst, key = key, value = value }
    end
end

local function apply_shadows()
    pcall(function()
        local light = game:GetService("Lighting")
        if CFG.no_shadows then
            light.GlobalShadows = false
        else
            light.GlobalShadows = true
        end
    end)
end

local function apply_postfx()
    pcall(function()
        local light = game:GetService("Lighting")
        for _, fx in ipairs(light:GetChildren()) do
            if fx:IsA("PostEffect") then
                if CFG.no_postfx then
                    remember(fx, "Enabled", fx.Enabled)
                    fx.Enabled = false
                elseif perf.saved[tostring(fx)] then
                    fx.Enabled = perf.saved[tostring(fx)].value
                end
            end
        end
    end)
end

local function sweep_world()
    local p = pcall(function()
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            n += 1
            if n > 6000 then break end
            if d:IsA("ParticleEmitter") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") then
                if CFG.no_particles then
                    remember(d, "Enabled", d.Enabled)
                    d.Enabled = false
                elseif perf.saved[tostring(d)] and perf.saved[tostring(d)].key == "Enabled" then
                    d.Enabled = perf.saved[tostring(d)].value
                end
            elseif d:IsA("Texture") or d:IsA("Decal") then
                if CFG.no_textures then
                    remember(d, "Transparency", d.Transparency)
                    d.Transparency = 1
                elseif perf.saved[tostring(d)] and perf.saved[tostring(d)].key == "Transparency" then
                    d.Transparency = perf.saved[tostring(d)].value
                end
            elseif d:IsA("Sound") then
                if CFG.no_sound then
                    remember(d, "Volume", d.Volume)
                    d.Volume = 0
                elseif perf.saved[tostring(d)] and perf.saved[tostring(d)].key == "Volume" then
                    d.Volume = perf.saved[tostring(d)].value
                end
            end
        end
    end)
    return p
end

local function apply_perf()
    set_quality(CFG.graph)
    apply_shadows()
    apply_postfx()
end

local perf_tick = 0

RunService.Heartbeat:Connect(function()
    perf_tick += 1
    if perf_tick % 300 ~= 0 then return end
    if CFG.no_particles or CFG.no_textures or CFG.no_sound then
        pcall(sweep_world)
    end
end)

-- voo ------------------------------------------------------------------

local fly = { bv = nil, up = 0, fwd = 0, side = 0, cur = Vector3.new() }
local pad = { gui = nil, frame = nil }

local function fly_off()
    if fly.bv then
        pcall(function() fly.bv:Destroy() end)
        fly.bv = nil
    end
    fly.cur = Vector3.new()
    fly.up, fly.fwd, fly.side = 0, 0, 0
end

local function fly_step()
    if not CFG.fly then
        if fly.bv then fly_off() end
        return
    end

    local char = lp and lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or not cam then return end

    if not fly.bv or fly.bv.Parent ~= root then
        fly_off()
        local bv = Instance.new("BodyVelocity")
        bv.Name = "LunarFly"
        bv.MaxForce = Vector3.new(1000000, 1000000, 1000000)
        bv.P = 1250
        bv.Parent = root
        fly.bv = bv
    end

    if hum.PlatformStand then
        pcall(function() hum.PlatformStand = false end)
    end

    local look = cam.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.01 then
        flat = Vector3.new(0, 0, -1)
    else
        flat = flat.Unit
    end
    local right = flat:Cross(Vector3.new(0, 1, 0))

    local md = hum.MoveDirection
    local fwd = md:Dot(flat) + fly.fwd
    local side = md:Dot(right) + fly.side
    local vert = fly.up

    local want
    if CFG.fly_cam then
        want = look * fwd + right * side + Vector3.new(0, vert, 0)
    else
        want = flat * fwd + right * side + Vector3.new(0, vert, 0)
    end

    if want.Magnitude > 0.01 then
        want = want.Unit * CFG.fly_speed
    else
        want = Vector3.new()
    end

    local alpha = math.clamp(CFG.fly_smooth, 0.05, 1)
    fly.cur = fly.cur:Lerp(want, alpha)
    pcall(function() fly.bv.Velocity = fly.cur end)

    if CFG.fly_noclip then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then
                pcall(function() d.CanCollide = false end)
            end
        end
    end
end

local function build_pad()
    if pad.gui then return end

    local g = Instance.new("ScreenGui")
    g.Name = "LunarFlyPad"
    g.ResetOnSpawn = false
    g.DisplayOrder = 1100
    pcall(function() g.Parent = holder() end)
    pad.gui = g

    local f = Instance.new("Frame")
    f.Size = UDim2.fromOffset(152, 152)
    f.Position = UDim2.new(1, -172, 1, -200)
    f.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
    f.BackgroundTransparency = 0.28
    f.BorderSizePixel = 0
    f.Active = true
    f.Visible = false
    f.Parent = g
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = f
    pad.frame = f

    local function hold(text, pos, on, off)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(42, 42)
        b.Position = UDim2.fromOffset(pos[1], pos[2])
        b.BackgroundColor3 = Color3.fromRGB(26, 30, 38)
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        b.Font = Enum.Font.Code
        b.TextSize = 13
        b.TextColor3 = Color3.fromRGB(190, 200, 215)
        b.Text = text
        b.Parent = f
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 8)
        cc.Parent = b

        b.InputBegan:Connect(function(input)
            local t = input.UserInputType
            if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                b.BackgroundColor3 = Color3.fromRGB(34, 74, 52)
                on()
            end
        end)
        b.InputEnded:Connect(function(input)
            local t = input.UserInputType
            if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                b.BackgroundColor3 = Color3.fromRGB(26, 30, 38)
                off()
            end
        end)
        return b
    end

    hold("^", { 55, 6 }, function() fly.up = 1 end, function() fly.up = 0 end)
    hold("<", { 8, 55 }, function() fly.side = -1 end, function() fly.side = 0 end)
    hold("=", { 55, 55 }, function() fly.fwd = 1 end, function() fly.fwd = 0 end)
    hold(">", { 102, 55 }, function() fly.side = 1 end, function() fly.side = 0 end)
    hold("v", { 55, 104 }, function() fly.fwd = -1 end, function() fly.fwd = 0 end)
    hold("ll", { 102, 104 }, function() fly.up = -1 end, function() fly.up = 0 end)

    local grab = Instance.new("TextLabel")
    grab.Size = UDim2.fromOffset(42, 42)
    grab.Position = UDim2.fromOffset(8, 6)
    grab.BackgroundTransparency = 1
    grab.Font = Enum.Font.Code
    grab.TextSize = 16
    grab.TextColor3 = Color3.fromRGB(90, 100, 116)
    grab.Text = "::"
    grab.Parent = f

    local dragging, startPos, startInput = false, nil, nil
    f.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragging = true
            startPos = f.Position
            startInput = input.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = input.Position - startInput
        f.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end)
    UIS.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

RunService.RenderStepped:Connect(function()
    local ok, err = pcall(fly_step)
    if not ok then fail("voo", err) end
    if pad.frame then
        pad.frame.Visible = CFG.fly and CFG.pad_show
    end
end)

-- camera ---------------------------------------------------------------

local function camera_loop()
    if CFG.offmap and offmap.saved then
        pcall(function()
            cam.CFrame = CFrame.new(offmap.saved.Position) * cam.CFrame.Rotation
        end)
        return
    end
    if CFG.persp == "livre" then return end
    local char = lp and lp.Character
    local head = char and char:FindFirstChild("Head")
    if not head or not cam then return end

    local ok = pcall(function()
        local rot = cam.CFrame.Rotation
        if CFG.persp == "primeira" then
            cam.CFrame = CFrame.new(head.Position + Vector3.new(0, 0.35, 0)) * rot
            head.LocalTransparencyModifier = 1
        elseif CFG.persp == "segunda" then
            local eye = head.Position + rot.LookVector * CFG.dist + Vector3.new(0, 0.35, 0)
            cam.CFrame = CFrame.lookAt(eye, head.Position)
            head.LocalTransparencyModifier = 0
        else
            local eye = head.Position - rot.LookVector * CFG.dist + Vector3.new(0, 1, 0)
            cam.CFrame = CFrame.new(eye) * rot
            head.LocalTransparencyModifier = 0
        end
    end)
    if not ok then fail("camera", "falhou") end
end

-- skin e preview -------------------------------------------------------

local viewer = { gui = nil, conn = nil }

local function viewer_close()
    if viewer.conn then
        pcall(function() viewer.conn:Disconnect() end)
        viewer.conn = nil
    end
    if viewer.gui then
        pcall(function() viewer.gui:Destroy() end)
        viewer.gui = nil
    end
end

local function viewer_open(target)
    viewer_close()
    local char = target and target.Character
    if not char then return false, "jogador sem personagem" end

    local g = Instance.new("ScreenGui")
    g.Name = "LunarSlimPreview"
    g.ResetOnSpawn = false
    g.DisplayOrder = 1200
    local ok = pcall(function() g.Parent = holder() end)
    if not ok or not g.Parent then return false, "container recusou" end
    viewer.gui = g

    local frame = mk("Frame", {
        Size = UDim2.fromOffset(210, 250),
        Position = UDim2.new(0.5, -105, 0.5, -125),
        BackgroundColor3 = Color3.fromRGB(12, 14, 18),
        BorderSizePixel = 0,
    }, g)
    corner(frame, 10)

    local vp = mk("ViewportFrame", {
        Size = UDim2.new(1, -12, 1, -42),
        Position = UDim2.fromOffset(6, 6),
        BackgroundColor3 = Color3.fromRGB(18, 21, 27),
        BorderSizePixel = 0,
        Ambient = Color3.fromRGB(190, 190, 200),
        LightColor = Color3.fromRGB(255, 255, 255),
    }, frame)
    corner(vp, 8)

    local world = mk("WorldModel", {}, vp)
    local vcam = mk("Camera", { FieldOfView = 35 }, vp)
    vp.CurrentCamera = vcam

    local okc, model = pcall(function() return char:Clone() end)
    if not okc or not model then
        viewer_close()
        return false, "clone falhou"
    end

    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:Destroy() end) end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
        end
    end
    local okpiv = pcall(function() model:PivotTo(CFrame.new()) end)
    if not okpiv then return false, "nao consegui posicionar" end
    model.Parent = world

    local focus = Vector3.new(0, 2.6, 0)
    local radius = 11
    local okb, bcf, bsize = pcall(function() return model:GetBoundingBox() end)
    if okb and bcf and bsize then
        focus = bcf.Position
        radius = math.max(bsize.Magnitude * 0.95, 5)
    end

    local close = mk("TextButton", {
        Size = UDim2.new(1, -12, 0, 28),
        Position = UDim2.new(0, 6, 1, -34),
        BackgroundColor3 = Color3.fromRGB(30, 34, 42),
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextColor3 = Color3.fromRGB(180, 190, 205),
        Text = "fechar",
    }, frame)
    corner(close, 6)
    close.MouseButton1Click:Connect(viewer_close)

    local angle = 0
    viewer.conn = RunService.RenderStepped:Connect(function(dt)
        angle += (dt or 0.016) * 0.7
        vcam.CFrame = CFrame.new(
            focus + Vector3.new(math.sin(angle) * radius, radius * 0.22, math.cos(angle) * radius),
            focus)
    end)

    return true
end


-- auto click -----------------------------------------------------------

local ac = { left = 0, clicks = 0, capturing = false }
local paint_ac = nil

local function click_once()
    local mode = CFG.ac_mode
    local pos = Vector2.new(CFG.ac_x, CFG.ac_y)

    if mode == "os dois" or mode == "ferramenta" then
        local char = lp and lp.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then pcall(function() tool:Activate() end) end
    end

    if mode == "os dois" or mode == "toque" then
        local ok = pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:ClickButton1(pos)
        end)
        if not ok then
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
                vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
            end)
        end
    end
end

local ac_budget = 0

RunService.Heartbeat:Connect(function(dt)
    if not CFG.ac_on then
        ac_budget = 0
        return
    end
    if CFG.ac_limit > 0 and ac.left <= 0 then
        CFG.ac_on = false
        ac_budget = 0
        if paint_ac then paint_ac() end
        return
    end

    ac_budget += (dt or 0.016) * math.clamp(CFG.ac_cps, 1, 1000)
    local n = math.floor(ac_budget)
    if n <= 0 then return end
    ac_budget -= n
    if n > 150 then n = 150 end

    for _ = 1, n do
        if CFG.ac_limit > 0 and ac.left <= 0 then break end
        pcall(click_once)
        ac.clicks += 1
        if CFG.ac_limit > 0 then ac.left -= 1 end
    end
end)

local list_box = nil

local function build_list()
    if not list_box then return end
    for _, c in ipairs(list_box:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end

    local n = 0
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= lp then
            n += 1
            local row = mk("TextButton", {
                Size = UDim2.new(1, -8, 0, 28),
                BackgroundColor3 = Color3.fromRGB(20, 23, 29),
                BorderSizePixel = 0,
                AutoButtonColor = false,
                LayoutOrder = n,
                Text = "",
            }, list_box)
            corner(row, 6)

            mk("TextLabel", {
                Size = UDim2.new(1, -96, 1, 0),
                Position = UDim2.fromOffset(8, 0),
                BackgroundTransparency = 1,
                Font = Enum.Font.Code,
                TextSize = 10,
                TextColor3 = Color3.fromRGB(196, 206, 220),
                TextXAlignment = Enum.TextXAlignment.Left,
                Text = " " .. pl.Name,
            }, row)

            local view = mk("TextButton", {
                Size = UDim2.fromOffset(40, 20),
                Position = UDim2.new(1, -88, 0.5, -10),
                BackgroundColor3 = Color3.fromRGB(38, 44, 54),
                BorderSizePixel = 0,
                Font = Enum.Font.Code,
                TextSize = 10,
                TextColor3 = Color3.fromRGB(190, 200, 215),
                Text = "3d",
            }, row)
            corner(view, 5)
            view.MouseButton1Click:Connect(function()
                local ok, msg = viewer_open(pl)
                if not ok then fail("preview", msg) end
            end)

            local copy = mk("TextButton", {
                Size = UDim2.fromOffset(40, 20),
                Position = UDim2.new(1, -44, 0.5, -10),
                BackgroundColor3 = Color3.fromRGB(34, 70, 50),
                BorderSizePixel = 0,
                Font = Enum.Font.Code,
                TextSize = 10,
                TextColor3 = Color3.fromRGB(150, 220, 175),
                Text = "copiar",
            }, row)
            corner(copy, 5)
            copy.MouseButton1Click:Connect(function()
                local char = pl.Character
                local src = char and char:FindFirstChildOfClass("Humanoid")
                local mine = lp and lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
                if not src or not mine then
                    fail("skin", "sem humanoid")
                    return
                end
                local desc
                if not pcall(function() desc = src:GetAppliedDescription() end) or not desc then
                    fail("skin", "descricao bloqueada")
                    return
                end
                local ok = pcall(function() mine:ApplyDescription(desc) end)
                if not ok then fail("skin", "servidor recusou") end
            end)
        end
    end
    if n == 0 then
        local empty = mk("TextLabel", {
            Size = UDim2.new(1, -8, 0, 24),
            BackgroundTransparency = 1,
            Font = Enum.Font.Code,
            TextSize = 9,
            TextColor3 = Color3.fromRGB(96, 108, 124),
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "  ninguem no servidor alem de voce",
        }, list_box)
        empty.LayoutOrder = 1
    end
    return n
end

-- montagem da interface ------------------------------------------------

label("mira - esp - fantasma - camera - auto click - andando - voo - leveza - skins")

section("mira")
local paint_aim = toggle("aimbot", function() return CFG.aim end, function(v) CFG.aim = v end)
toggle("atirar sozinho", function() return CFG.auto end, function(v) CFG.auto = v end)
toggle("grudar no alvo", function() return CFG.sticky end, function(v) CFG.sticky = v end)
toggle("ignorar o proprio time", function() return CFG.team end, function(v) CFG.team = v end)
cycle("ponto da mira", { "Head", "UpperTorso", "HumanoidRootPart" },
    function() return CFG.part end, function(v) CFG.part = v end)
local set_fov = stepper("fov", 40, 400, 10, function() return CFG.fov end, function(v) CFG.fov = v end)
local set_smooth = stepper("suavidade", 0.1, 1, 0.1, function() return CFG.smooth end, function(v) CFG.smooth = v end)
local set_lead = stepper("antecipacao", 0, 2, 0.1, function() return CFG.lead end, function(v) CFG.lead = v end)
local set_speed = stepper("velocidade da bala", 200, 3000, 100, function() return CFG.speed end, function(v) CFG.speed = v end)
label("bala instantanea: antecipacao em 0. bala de projetil: ajeita a velocidade e deixa em 1.")

section("esp")
local paint_box = toggle("caixa", function() return CFG.esp_box end, function(v) CFG.esp_box = v end)
local paint_name = toggle("nome", function() return CFG.esp_name end, function(v) CFG.esp_name = v end)
local paint_hp = toggle("vida", function() return CFG.esp_hp end, function(v) CFG.esp_hp = v end)
local paint_dist = toggle("distancia", function() return CFG.esp_dist end, function(v) CFG.esp_dist = v end)
toggle("esqueleto", function() return CFG.esp_skel end, function(v) CFG.esp_skel = v end)
if not DRAWING then
    label("este executor nao expoe a API Drawing. sem ela o esp 2d nao desenha nada.")
end

section("invisibilidade / fantasma")
toggle("modo fantasma (invisivel para npc)", function() return CFG.ghost end, function(v)
    CFG.ghost = v
    if not v then pcall(ghost_show) end
end)
toggle("sumir do mapa (npc que segue posicao)", function() return CFG.offmap end, function(v)
    if v then
        offmap_enter()
        CFG.offmap = true
    else
        CFG.offmap = false
        offmap_exit()
    end
end)
toggle("esconder item da mao", function() return CFG.hide_tool end, function(v)
    CFG.hide_tool = v
    if not v then pcall(show_item) end
end)
toggle("guardar item quando npc perto", function() return CFG.stow_tool end, function(v)
    CFG.stow_tool = v
end)
stepper("distancia pra guardar o item", 10, 120, 5, function() return CFG.stow_radius end, function(v) CFG.stow_radius = v end)
stepper("altura do sumir do mapa", 500, 6000, 100, function() return CFG.offmap_height end, function(v) CFG.offmap_height = v end)

label("invisivel para npc: o corpo some, raycast e toque atravessam voce, e some o nome e a barra de vida. e o que derruba npc que te avista ou te toca. sumir do mapa: o corpo vai pra 4000 studs e a camera fica no lugar, pra npc que ja te marcou e segue so pela posicao.")

section("camera")
cycle("perspectiva", { "livre", "primeira", "segunda", "terceira" },
    function() return CFG.persp end, function(v) CFG.persp = v end)
stepper("distancia", 2, 20, 1, function() return CFG.dist end, function(v) CFG.dist = v end)

section("auto click")
paint_ac = toggle("ligar auto click", function() return CFG.ac_on end, function(v)
    CFG.ac_on = v
    if v then
        ac.left = CFG.ac_limit > 0 and CFG.ac_limit or 0
    end
end)
cycle("modo", { "os dois", "ferramenta", "toque" },
    function() return CFG.ac_mode end, function(v) CFG.ac_mode = v end)
stepper("cliques por segundo", 1, 1000, 1, function() return CFG.ac_cps end, function(v) CFG.ac_cps = v end)
stepper("quantidade (0 = infinito)", 0, 500, 10, function() return CFG.ac_limit end, function(v) CFG.ac_limit = v end)

local coord_label = label("posicao: aguardando")

local function paint_coords()
    coord_label.Text = string.format("posicao: x %d  y %d", CFG.ac_x, CFG.ac_y)
end
paint_coords()

button("capturar posicao na tela", function()
    ac.capturing = false
    status.Text = "toque no ponto que voce quer clicar"
    task.delay(0.5, function() ac.capturing = true end)
    task.delay(6, function()
        if ac.capturing then
            ac.capturing = false
            status.Text = "captura cancelada"
        end
    end)
end)

button("usar o centro da tela", function()
    local c = workspace.CurrentCamera
    if not c then return end
    CFG.ac_x = math.floor(c.ViewportSize.X / 2)
    CFG.ac_y = math.floor(c.ViewportSize.Y / 2)
    paint_coords()
end)

label("o clique vai pro jogo, nao pra interface. escolhe um ponto fora do painel. segura o + para subir rapido.")

section("andando")
toggle("velocidade de andar", function() return CFG.walk end, function(v)
    CFG.walk = v
    if not v then
        local char = lp and lp.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.WalkSpeed = 16 end) end
    end
end)
free_stepper("velocidade", 16, function() return CFG.walk_speed end, function(v) CFG.walk_speed = v end)
label("sem teto. use o 10> para multiplicar por dez e o <10 para dividir. o limite pratico e o servidor, nao o menu.")

section("voo")
toggle("voar", function() return CFG.fly end, function(v)
    CFG.fly = v
    if v then
        pcall(build_pad)
    else
        pcall(fly_off)
    end
end)
free_stepper("velocidade do voo", 5, function() return CFG.fly_speed end, function(v) CFG.fly_speed = v end)
stepper("suavidade do voo", 0.1, 1, 0.05, function() return CFG.fly_smooth end, function(v) CFG.fly_smooth = v end)
toggle("voar para onde a camera olha", function() return CFG.fly_cam end, function(v) CFG.fly_cam = v end)
toggle("sem colisao voando", function() return CFG.fly_noclip end, function(v) CFG.fly_noclip = v end)
toggle("mostrar painel de setas", function() return CFG.pad_show end, function(v) CFG.pad_show = v end)
label("o direcional do jogo continua funcionando no ar. as setas do painel servem pra subir, descer e empurrar sem soltar o dedo do direcional. arrasta o painel pelo canto.")

section("leveza")
cycle("nivel grafico", { "auto", "10", "8", "6", "4", "2", "1" },
    function() return CFG.graph end,
    function(v)
        CFG.graph = v
        apply_perf()
    end)
toggle("sem sombras", function() return CFG.no_shadows end, function(v)
    CFG.no_shadows = v
    apply_shadows()
end)
toggle("sem pos processamento", function() return CFG.no_postfx end, function(v)
    CFG.no_postfx = v
    apply_postfx()
end)
toggle("sem particulas", function() return CFG.no_particles end, function(v)
    CFG.no_particles = v
    pcall(sweep_world)
end)
toggle("sem texturas e decais", function() return CFG.no_textures end, function(v)
    CFG.no_textures = v
    pcall(sweep_world)
end)
toggle("sem som", function() return CFG.no_sound end, function(v)
    CFG.no_sound = v
    pcall(sweep_world)
end)
toggle("mostrar fps no topo", function() return CFG.fps_show end, function(v) CFG.fps_show = v end)
button("modo leve (aplica tudo)", function()
    CFG.graph = "2"
    CFG.no_shadows = true
    CFG.no_postfx = true
    CFG.no_particles = true
    CFG.no_textures = true
    apply_perf()
    pcall(sweep_world)
    status.Text = "modo leve aplicado"
end, Color3.fromRGB(30, 46, 38))
button("restaurar o que deu", function()
    CFG.graph = "auto"
    CFG.no_shadows = false
    CFG.no_postfx = false
    CFG.no_particles = false
    CFG.no_textures = false
    CFG.no_sound = false
    apply_perf()
    pcall(sweep_world)
    status.Text = "restaurado"
end, Color3.fromRGB(40, 36, 44))
label("nivel grafico e o ajuste do proprio roblox. os outros mexem so no que roda no teu cliente. particulas e texturas precisam de uma varredura, entao voltam aos poucos.")

section("skins")
button("atualizar lista de jogadores", function()
    local n = build_list()
    status.Text = "lista: " .. tostring(n) .. " jogadores"
end)
list_box = mk("Frame", {
    Size = UDim2.new(1, -4, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    LayoutOrder = next_order(),
}, body)
mk("UIListLayout", { Padding = UDim.new(0, 4) }, list_box)
mk("UIPadding", {
    PaddingTop = UDim.new(0, 0),
}, list_box)

build_list()
task.delay(3, function()
    local ok = pcall(build_list)
    if ok then status.Text = "lista pronta" end
end)

-- lacoes ---------------------------------------------------------------

RunService:BindToRenderStep("LunarSlimAim", Enum.RenderPriority.Camera.Value + 1, function()
    local ok, err = pcall(aim_loop)
    if not ok then fail("mira", err) end
end)

RunService:BindToRenderStep("LunarSlimCam", Enum.RenderPriority.Camera.Value + 5, function()
    local ok, err = pcall(camera_loop)
    if not ok then fail("camera", err) end
end)

RunService.RenderStepped:Connect(function()
    local ok, err = pcall(esp_loop)
    if not ok then fail("esp", err) end
end)

local fps_frames, fps_time = 0, 0

RunService.Heartbeat:Connect(function(dt)
    fps_frames += 1
    fps_time += dt or 0.016
    if fps_time >= 1 then
        stats.fps = math.floor(fps_frames / fps_time + 0.5)
        fps_frames, fps_time = 0, 0
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        local alvos = 0
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= lp then
                local char = pl.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then alvos += 1 end
            end
        end
        stats.alvos = alvos
        local text = string.format("draw %s | alvos %d | travadas %d | erros %d",
            DRAWING and "ok" or "sem", alvos, stats.travadas, stats.erros)
        if CFG.fps_show then
            text = text .. string.format(" | fps %d", stats.fps)
        end
        if CFG.ac_on or ac.clicks > 0 then
            text = text .. string.format(" | cliques %d", ac.clicks)
        end
        if last_error then
            text = text .. "\n" .. string.sub(last_error, 1, 46)
        end
        status.Text = text
        status.Size = UDim2.new(1, -80, 0, last_error and 24 or 14)
    end
end)

Players.PlayerAdded:Connect(function() task.delay(2, function() pcall(build_list) end) end)
Players.PlayerRemoving:Connect(function() task.delay(2, function() pcall(build_list) end) end)

UIS.InputBegan:Connect(function(input)
    if not ac.capturing then return end
    local t = input.UserInputType
    if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
        CFG.ac_x = math.floor(input.Position.X)
        CFG.ac_y = math.floor(input.Position.Y)
        ac.capturing = false
        paint_coords()
        status.Text = string.format("posicao salva: %d, %d", CFG.ac_x, CFG.ac_y)
    end
end)

hide.MouseButton1Click:Connect(function()
    body.Visible = not body.Visible
    panel.Size = body.Visible and UDim2.fromOffset(292, 430) or UDim2.fromOffset(292, 44)
end)

print("[lunar] " .. VERSION .. " carregado")
