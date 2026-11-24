--[[
    lunar.opt v2 | Roblox Android
    Delta / Arceus X / Codex / Hydrogen / Fluxus

    modos: leve | vivo | completo | manual
    modulos: desempenho, ambiente, clima, overlay, visual, camera
    nada privado replica: clone fica em Camera, hud em ScreenGui local
]]

local Players      = game:GetService("Players")
local Lighting     = game:GetService("Lighting")
local Workspace    = game:GetService("Workspace")
local RunService   = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local function refresh_local()
    LocalPlayer = Players.LocalPlayer or LocalPlayer
    return LocalPlayer
end

local genv = (getgenv and getgenv()) or {}
if genv.LunarOpt then pcall(genv.LunarOpt.destroy) end

local VERSION = "2.3"

print("[lunar.opt] carregando " .. VERSION .. " ...")

-- utilitarios ----------------------------------------------------------

local function put(obj, prop, value)
    if pcall(function() obj[prop] = value end) then return true end
    if sethiddenproperty then return (pcall(sethiddenproperty, obj, prop, value)) end
    return false
end

local function get(obj, prop)
    local ok, v = pcall(function() return obj[prop] end)
    if ok then return v end
    return nil
end

local function clamp01(x)
    return math.clamp(x, 0, 1)
end

local function color_from_hsv(h, s)
    return Color3.fromHSV((h % 360) / 360, 1, 1):Lerp(Color3.new(1, 1, 1), 1 - clamp01(s))
end

local function merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            merge(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

-- config ---------------------------------------------------------------

local CFG = {
    version = 2,
    mode = nil,
    tab = "desempenho",
    watchdog = true,
    perf = {
        enabled = true, shadows = true, post_fx = true, particles = true,
        lighting = true, quality = true, mesh = true, textures = false,
        terrain = true, audio = true, wind = true, cap = true, cap_value = 120,
    },
    env = {
        enabled = true, preset = "dia", clock = 14, brightness = 2, exposure = 0,
        env_diffuse = 0.4, env_spec = 0.3, fog_start = 100, fog_end = 600,
        atmosphere = 0.3, haze = 0, glare = 0.2, hue = 45, tint = 0.05,
        contrast = 0.05, saturation = 0.08, cc_bright = 0, bloom = 0.4,
        sunrays = 0.25, dof = 0, sky_ids = "",
    },
    climate = { kind = "nenhum", density = 1 },
    overlay = { vig = false, vig_strength = 0.45, bars = false, bars_size = 8,
                tint = false, tint_strength = 0.12, hue = 200 },
    vis = { aura = false, aura_color = 190, hide_acc = false, scale_on = false,
            scale = 1, fov = false, fov_value = 70, zoom = false, zoom_value = 1,
            ambience = false, ambience_id = "", ambience_vol = 0.4, replicated = false,
            persp = "terceira", persp_dist = 6 },
    mov = {
        fly = false, fly_speed = 55,
        jump = false, jump_power = 140,
        speed = false, speed_value = 55,
        noclip = false,
    },
    xitadu = {
        esp_box = false, esp_name = false, esp_health = false, esp_dist = false,
        esp_skel = false, esp_tracer = false, esp_glow = false, esp_box3d = false,
        esp_fov = false, esp_team = false, esp_hue = 0,
        aim = false, aim_fov = 140, aim_smooth = 0.45, aim_part = "Cabeca",
        aim_team = false, aim_wall = false, aim_auto = false,
        silent = false, silent_filter = "", silent_ghost = false,
        sticky = true,
        recoil = false,
    },
}

local CONFIG_DIR = "lunar_opt"
local function config_path()
    return CONFIG_DIR .. "/" .. tostring(game.PlaceId) .. ".json"
end

local function storage_ready()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function load_config()
    if not storage_ready() then return end
    pcall(function()
        if makefolder then makefolder(CONFIG_DIR) end
        local path = config_path()
        if isfile and isfile(path) then
            merge(CFG, HttpService:JSONDecode(readfile(path)))
        end
    end)
end

local function save_config()
    if not storage_ready() then return end
    pcall(function()
        if makefolder then makefolder(CONFIG_DIR) end
        writefile(config_path(), HttpService:JSONEncode(CFG))
    end)
end

-- medidor --------------------------------------------------------------

local Fps = { value = 0, frames = 0, t0 = os.clock(), base = 0, base_sum = 0, base_n = 0 }

local BOOT_CONNS = {}

BOOT_CONNS[#BOOT_CONNS + 1] = RunService.RenderStepped:Connect(function()
    Fps.frames += 1
    local now = os.clock()
    if now - Fps.t0 >= 1 then
        Fps.value = math.floor(Fps.frames / (now - Fps.t0) + 0.5)
        Fps.frames, Fps.t0 = 0, now
    end
end)

-- desempenho -----------------------------------------------------------

local Perf = { queue = {}, head = 1, seen = setmetatable({}, { __mode = "k" }), running = true }

local FX_CLASSES = {
    ParticleEmitter = true, Beam = true, Trail = true,
    Smoke = true, Fire = true, Sparkles = true,
}

local function is_lunar(inst)
    return inst.Name:sub(1, 5) == "Lunar"
end

function Perf.enqueue(inst)
    if Perf.seen[inst] then return end
    Perf.seen[inst] = true
    Perf.queue[#Perf.queue + 1] = inst
end

function Perf.enqueue_tree(root)
    Perf.enqueue(root)
    for _, d in ipairs(root:GetDescendants()) do Perf.enqueue(d) end
end

local function perf_process(inst)
    local p = CFG.perf
    local cls = inst.ClassName
    if is_lunar(inst) then return end

    if FX_CLASSES[cls] then
        if p.particles then put(inst, "Enabled", false) end
        return
    end

    if inst:IsA("BasePart") then
        if p.shadows then put(inst, "CastShadow", false) end
        if p.mesh and cls == "MeshPart" then
            put(inst, "RenderFidelity", Enum.RenderFidelity.Performance)
        end
        if p.textures and (cls == "Part" or cls == "WedgePart" or cls == "CornerWedgePart") then
            put(inst, "Material", Enum.Material.SmoothPlastic)
        end
        return
    end

    if p.textures then
        if cls == "Decal" or cls == "Texture" then
            put(inst, "Texture", "")
        elseif cls == "SurfaceAppearance" then
            pcall(inst.Destroy, inst)
        end
    end
end

task.spawn(function()
    while Perf.running do
        local n = 0
        while Perf.head <= #Perf.queue and n < 600 do
            local inst = Perf.queue[Perf.head]
            Perf.head += 1
            n += 1
            if inst.Parent then pcall(perf_process, inst) end
        end
        if Perf.head > #Perf.queue then
            Perf.queue, Perf.head = {}, 1
            task.wait(0.25)
        else
            RunService.Heartbeat:Wait()
        end
    end
end)

function Perf.apply_cap()
    local p = CFG.perf
    if not p.cap then return end
    if setfpscap then pcall(setfpscap, p.cap_value) end
    if setfflag then
        pcall(setfflag, "DFIntTaskSchedulerTargetFps", tostring(p.cap_value))
        pcall(setfflag, "FFlagTaskSchedulerLimitTargetFpsTo2402", "False")
    end
end

function Perf.apply_lighting()
    local p = CFG.perf
    if not p.lighting then return end
    put(Lighting, "GlobalShadows", false)
    put(Lighting, "ShadowSoftness", 0)
    put(Lighting, "Outlines", false)
    if p.quality then put(Lighting, "Technology", Enum.Technology.Voxel) end
end

function Perf.apply_post_fx()
    local classes = {
        BloomEffect = true, BlurEffect = true, SunRaysEffect = true,
        DepthOfFieldEffect = true, ColorCorrectionEffect = true,
        ColorGradingEffect = true, Atmosphere = true,
    }
    for _, c in ipairs(Lighting:GetChildren()) do
        if classes[c.ClassName] and not is_lunar(c) then
            if CFG.perf.post_fx then put(c, "Enabled", false) end
        end
    end
end

function Perf.apply_quality()
    local on = CFG.perf.quality
    pcall(function()
        settings().Rendering.QualityLevel = on and Enum.QualityLevel.Level01 or Enum.QualityLevel.Level10
    end)
    pcall(function()
        settings().Rendering.MeshPartDetail = on and 1 or 2
    end)
end

function Perf.apply_terrain()
    local t = Workspace:FindFirstChildOfClass("Terrain")
    if not t then return end
    local on = CFG.perf.terrain
    put(t, "WaterWaveSize", on and 0 or 1)
    put(t, "WaterWaveSpeed", on and 0 or 10)
    put(t, "WaterReflectance", on and 0 or 0.4)
    put(t, "Decoration", not on)
end

function Perf.apply_audio()
    if CFG.perf.audio then
        put(SoundService, "VolumetricAudio", Enum.VolumetricAudio.Disabled)
        put(SoundService, "AmbientReverb", Enum.ReverbType.NoReverb)
    end
end

function Perf.apply_wind()
    if CFG.perf.wind then put(Workspace, "GlobalWind", Vector3.zero) end
end

function Perf.rebuild()
    Perf.seen = setmetatable({}, { __mode = "k" })
    Perf.queue, Perf.head = {}, 1
    Perf.apply_cap()
    Perf.apply_lighting()
    Perf.apply_post_fx()
    Perf.apply_quality()
    Perf.apply_terrain()
    Perf.apply_audio()
    Perf.apply_wind()
    if CFG.perf.enabled then
        Perf.enqueue_tree(Workspace)
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl.Character then Perf.enqueue_tree(pl.Character) end
        end
    end
end

local perf_guard = false

Workspace.DescendantAdded:Connect(function(d)
    if not CFG.perf.enabled then return end
    Perf.enqueue(d)
    for _, c in ipairs(d:GetDescendants()) do Perf.enqueue(c) end
end)

Lighting.ChildAdded:Connect(function()
    if perf_guard then return end
    perf_guard = true
    task.delay(1, function()
        perf_guard = false
        Perf.apply_post_fx()
    end)
end)

Players.PlayerAdded:Connect(function(pl)
    pl.CharacterAdded:Connect(function(ch)
        task.wait(1)
        if CFG.perf.enabled then Perf.enqueue_tree(ch) end
    end)
end)

-- ambiente -------------------------------------------------------------

local Env = { objs = {}, originals = nil, applied = false }

local LIGHT_PROPS = {
    "ClockTime", "Brightness", "ExposureCompensation", "Ambient",
    "OutdoorAmbient", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
    "FogStart", "FogEnd", "FogColor",
}

local function capture_originals()
    if Env.originals then return end
    local o = {}
    for _, k in ipairs(LIGHT_PROPS) do o[k] = get(Lighting, k) end
    Env.originals = o
end

local function ensure_env_objects()
    if Env.objs.atmos and Env.objs.atmos.Parent then return end
    local function mk(class, name)
        local inst = Instance.new(class)
        inst.Name = name
        inst.Parent = Lighting
        return inst
    end
    Env.objs.atmos = mk("Atmosphere", "LunarAtmosphere")
    Env.objs.cc = mk("ColorCorrectionEffect", "LunarCC")
    Env.objs.bloom = mk("BloomEffect", "LunarBloom")
    Env.objs.sunrays = mk("SunRaysEffect", "LunarSunRays")
    Env.objs.dof = mk("DepthOfFieldEffect", "LunarDOF")
end

local function ensure_sky()
    if Env.objs.sky and Env.objs.sky.Parent then return Env.objs.sky end
    for _, c in ipairs(Lighting:GetChildren()) do
        if c:IsA("Sky") then
            Env.objs.sky = c
            return c
        end
    end
    local sky = Instance.new("Sky")
    sky.Name = "LunarSky"
    sky.Parent = Lighting
    Env.objs.sky = sky
    return sky
end

function Env.apply()
    local e = CFG.env
    if not e.enabled then
        if Env.applied and Env.originals then
            for k, v in pairs(Env.originals) do
                if v ~= nil then put(Lighting, k, v) end
            end
        end
        for _, c in ipairs(Lighting:GetChildren()) do
            if is_lunar(c) and c:IsA("PostEffect") then put(c, "Enabled", false) end
        end
        Env.applied = false
        return
    end

    capture_originals()
    ensure_env_objects()
    Env.applied = true

    put(Lighting, "ClockTime", e.clock)
    put(Lighting, "Brightness", e.brightness)
    put(Lighting, "ExposureCompensation", e.exposure)
    put(Lighting, "EnvironmentDiffuseScale", e.env_diffuse)
    put(Lighting, "EnvironmentSpecularScale", e.env_spec)
    put(Lighting, "FogStart", e.fog_start)
    put(Lighting, "FogEnd", e.fog_end)

    local at = Env.objs.atmos
    put(at, "Enabled", true)
    put(at, "Density", e.atmosphere)
    put(at, "Haze", e.haze)
    put(at, "Glare", e.glare)
    put(at, "Color", Color3.fromRGB(120, 150, 190):Lerp(Color3.new(1, 1, 1), 0.55))

    local cc = Env.objs.cc
    put(cc, "Enabled", true)
    put(cc, "TintColor", color_from_hsv(e.hue, e.tint))
    put(cc, "Contrast", e.contrast)
    put(cc, "Saturation", e.saturation)
    put(cc, "Brightness", e.cc_bright)

    local bl = Env.objs.bloom
    put(bl, "Enabled", e.bloom > 0.01)
    put(bl, "Intensity", e.bloom)
    put(bl, "Size", 24)

    local sr = Env.objs.sunrays
    put(sr, "Enabled", e.sunrays > 0.01)
    put(sr, "Intensity", e.sunrays)
    put(sr, "Spread", 0.6)

    local dof = Env.objs.dof
    put(dof, "Enabled", e.dof > 0.01)
    put(dof, "FarIntensity", e.dof)
    put(dof, "FocusDistance", 30)
    put(dof, "InFocusRadius", 20)

    if e.sky_ids and e.sky_ids ~= "" then
        local ids = {}
        for part in string.gmatch(e.sky_ids, "[^,]+") do
            local clean = (part:gsub("%s", ""))
            if clean ~= "" then ids[#ids + 1] = "rbxassetid://" .. clean end
        end
        if #ids >= 6 then
            local sky = ensure_sky()
            local faces = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
            for i = 1, 6 do put(sky, faces[i], ids[i]) end
        end
    end
end

local PRESETS = {
    dia = {
        clock = 14, brightness = 2, exposure = 0, atmosphere = 0.3, haze = 0,
        fog_start = 100, fog_end = 600, hue = 45, tint = 0.05, contrast = 0.05,
        saturation = 0.08, bloom = 0.4, sunrays = 0.25, env_diffuse = 0.4,
        env_spec = 0.3, climate = "nenhum",
    },
    entardecer = {
        clock = 18, brightness = 1.6, exposure = 0.1, atmosphere = 0.35, haze = 2,
        fog_start = 80, fog_end = 450, hue = 22, tint = 0.35, contrast = 0.12,
        saturation = 0.2, bloom = 0.8, sunrays = 0.6, env_diffuse = 0.35,
        env_spec = 0.25, climate = "nenhum",
    },
    noite = {
        clock = 0, brightness = 0.7, exposure = 0.2, atmosphere = 0.45, haze = 1,
        fog_start = 60, fog_end = 350, hue = 215, tint = 0.3, contrast = 0.15,
        saturation = -0.05, bloom = 0.5, sunrays = 0.05, env_diffuse = 0.2,
        env_spec = 0.15, climate = "nenhum",
    },
    inverno = {
        clock = 12, brightness = 1.9, exposure = 0.05, atmosphere = 0.5, haze = 3,
        fog_start = 40, fog_end = 300, hue = 200, tint = 0.28, contrast = 0.1,
        saturation = -0.15, bloom = 0.6, sunrays = 0.15, env_diffuse = 0.45,
        env_spec = 0.2, climate = "neve",
    },
    chuva = {
        clock = 10, brightness = 1.2, exposure = -0.05, atmosphere = 0.6, haze = 4,
        fog_start = 30, fog_end = 240, hue = 205, tint = 0.35, contrast = 0.18,
        saturation = -0.2, bloom = 0.3, sunrays = 0.05, env_diffuse = 0.25,
        env_spec = 0.15, climate = "chuva",
    },
    nevoa = {
        clock = 7, brightness = 1.2, exposure = 0, atmosphere = 0.65, haze = 6,
        fog_start = 10, fog_end = 130, hue = 200, tint = 0.22, contrast = 0.05,
        saturation = -0.1, bloom = 0.3, sunrays = 0.1, env_diffuse = 0.3,
        env_spec = 0.1, climate = "nenhum",
    },
    espaco = {
        clock = 0, brightness = 0.3, exposure = 0.3, atmosphere = 0.05, haze = 0,
        fog_start = 400, fog_end = 2000, hue = 260, tint = 0.3, contrast = 0.25,
        saturation = 0.1, bloom = 1, sunrays = 0, env_diffuse = 0.05,
        env_spec = 0.05, climate = "poeira",
    },
    synthwave = {
        clock = 20, brightness = 1.4, exposure = 0.2, atmosphere = 0.4, haze = 2,
        fog_start = 50, fog_end = 400, hue = 300, tint = 0.55, contrast = 0.3,
        saturation = 0.45, bloom = 1.4, sunrays = 0.4, env_diffuse = 0.3,
        env_spec = 0.4, climate = "poeira",
    },
}

local Climate = { part = nil, emitter = nil }

local CLIMATE_DEFS = {
    neve = {
        Rate = 90, Speed = 12, Lifetime = 6, Size = 0.35, Transparency = 0.25,
        Color = Color3.fromRGB(255, 255, 255), Spread = Vector2.new(180, 180),
        Accel = Vector3.new(0, -3, 0), Rot = 30, Emit = Enum.NormalId.Bottom,
    },
    chuva = {
        Rate = 220, Speed = 70, Lifetime = 0.8, Size = 0.12, Transparency = 0.45,
        Color = Color3.fromRGB(200, 220, 255), Spread = Vector2.new(4, 4),
        Accel = Vector3.new(0, -40, 0), Rot = 0, Emit = Enum.NormalId.Bottom,
    },
    poeira = {
        Rate = 40, Speed = 2, Lifetime = 10, Size = 0.2, Transparency = 0.5,
        Color = Color3.fromRGB(255, 240, 210), Spread = Vector2.new(180, 180),
        Accel = Vector3.new(0, 0.4, 0), Rot = 20,
    },
    brasa = {
        Rate = 60, Speed = 6, Lifetime = 4, Size = 0.25, Transparency = 0.2,
        Color = Color3.fromRGB(255, 140, 40), Spread = Vector2.new(180, 180),
        Accel = Vector3.new(0, 4, 0), Rot = 15,
    },
    vaga = {
        Rate = 25, Speed = 1.5, Lifetime = 12, Size = 0.22, Transparency = 0.3,
        Color = Color3.fromRGB(180, 255, 160), Spread = Vector2.new(180, 180),
        Accel = Vector3.new(0, 0.2, 0), Rot = 10,
    },
}

function Climate.ensure()
    if Climate.part and Climate.part.Parent then return true end
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    local part = Instance.new("Part")
    part.Name = "LunarWeather"
    part.Size = Vector3.new(140, 140, 140)
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Massless = true
    part.Parent = cam

    local em = Instance.new("ParticleEmitter")
    em.Name = "LunarEmitter"
    em.EmissionDirection = Enum.NormalId.Top
    em.Parent = part

    Climate.part, Climate.emitter = part, em
    return true
end

function Climate.apply()
    local c = CFG.climate
    if c.kind == "nenhum" or not CLIMATE_DEFS[c.kind] then
        if Climate.part then pcall(function() Climate.part:Destroy() end) end
        Climate.part, Climate.emitter = nil, nil
        return
    end
    if not Climate.ensure() then return end
    local def = CLIMATE_DEFS[c.kind]
    local em = Climate.emitter
    em.Rate = def.Rate * (c.density or 1)
    em.Speed = NumberRange.new(def.Speed * 0.7, def.Speed * 1.3)
    em.Lifetime = NumberRange.new(def.Lifetime * 0.6, def.Lifetime * 1.4)
    em.Size = NumberSequence.new(def.Size)
    em.Transparency = NumberSequence.new(def.Transparency)
    em.Color = ColorSequence.new(def.Color)
    em.SpreadAngle = def.Spread
    em.EmissionDirection = def.Emit or Enum.NormalId.Top
    em.Acceleration = def.Accel
    em.RotSpeed = NumberRange.new(def.Rot)
    em.LightEmission = 0.5
    em.Enabled = true
end

BOOT_CONNS[#BOOT_CONNS + 1] = RunService.RenderStepped:Connect(function()
    if Climate.part and Climate.part.Parent and Workspace.CurrentCamera then
        Climate.part.CFrame = Workspace.CurrentCamera.CFrame
    end
end)

-- overlay --------------------------------------------------------------

local Overlay = { gui = nil, vig = {}, bars = {}, tint = nil }

function Overlay.ensure()
    if Overlay.gui and Overlay.gui.Parent then return end
    local parent
    local ok = pcall(function()
        parent = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if not ok or not parent then
        parent = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    end
    if not parent then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LunarOverlay"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 60
    gui.Enabled = false
    gui.Parent = parent
    Overlay.gui = gui

    local function edge(name, size, pos, rot)
        local f = Instance.new("Frame")
        f.Name = name
        f.Size = size
        f.Position = pos
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        f.BorderSizePixel = 0
        f.Visible = false
        f.Parent = gui
        local g = Instance.new("UIGradient")
        g.Rotation = rot
        g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        g.Parent = f
        return f
    end

    Overlay.vig.top = edge("VigTop", UDim2.new(1, 0, 0, 110), UDim2.fromOffset(0, 0), 90)
    Overlay.vig.bottom = edge("VigBottom", UDim2.new(1, 0, 0, 110), UDim2.new(0, 0, 1, -110), 270)
    Overlay.vig.left = edge("VigLeft", UDim2.new(0, 110, 1, 0), UDim2.fromOffset(0, 0), 0)
    Overlay.vig.right = edge("VigRight", UDim2.new(0, 110, 1, 0), UDim2.new(1, -110, 0, 0), 180)

    local function bar(name, pos)
        local f = Instance.new("Frame")
        f.Name = name
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        f.BorderSizePixel = 0
        f.Visible = false
        f.Position = pos
        f.Size = UDim2.new(1, 0, 0, 16)
        f.Parent = gui
        return f
    end

    Overlay.bars.top = bar("BarTop", UDim2.fromOffset(0, 0))
    Overlay.bars.bottom = bar("BarBottom", UDim2.new(0, 0, 1, -16))
end

function Overlay.apply()
    local o = CFG.overlay
    if not (o.vig or o.bars or o.tint) then
        if Overlay.gui then Overlay.gui.Enabled = false end
        return
    end
    Overlay.ensure()
    if not Overlay.gui then return end
    Overlay.gui.Enabled = true

    for _, f in pairs(Overlay.vig) do
        f.Visible = o.vig
        f.BackgroundTransparency = 1 - (o.vig_strength or 0.45)
    end

    local size = (o.bars_size or 8) * 2
    Overlay.bars.top.Visible = o.bars
    Overlay.bars.top.Size = UDim2.new(1, 0, 0, size)
    Overlay.bars.bottom.Visible = o.bars
    Overlay.bars.bottom.Size = UDim2.new(1, 0, 0, size)
    Overlay.bars.bottom.Position = UDim2.new(0, 0, 1, -size)

    if not Overlay.tint then
        Overlay.tint = Instance.new("Frame")
        Overlay.tint.Name = "Tint"
        Overlay.tint.Size = UDim2.fromScale(1, 1)
        Overlay.tint.BorderSizePixel = 0
        Overlay.tint.Parent = Overlay.gui
    end
    Overlay.tint.Visible = o.tint
    Overlay.tint.BackgroundColor3 = Color3.fromHSV((o.hue or 200) / 360, 0.7, 1)
    Overlay.tint.BackgroundTransparency = 1 - (o.tint_strength or 0.12)
end

-- camera, aura, acessorios, escala -------------------------------------

local Cam = {}
local HideAcc = {}
local Scale = {}
local Ambience = { sound = nil }

function Ambience.apply()
    local v = CFG.vis
    if not (v.ambience and v.ambience_id ~= "") then
        if Ambience.sound then
            pcall(function() Ambience.sound:Destroy() end)
            Ambience.sound = nil
        end
        return
    end
    if not Ambience.sound or not Ambience.sound.Parent then
        local s = Instance.new("Sound")
        s.Name = "LunarAmbience"
        s.Looped = true
        s.Parent = SoundService
        Ambience.sound = s
    end
    Ambience.sound.SoundId = "rbxassetid://" .. tostring(v.ambience_id):gsub("%s", "")
    Ambience.sound.Volume = v.ambience_vol or 0.4
    if not Ambience.sound.IsPlaying then pcall(function() Ambience.sound:Play() end) end
end

function Cam.apply()
    refresh_local()
    local v = CFG.vis
    local cam = Workspace.CurrentCamera
    if not cam then return end
    if v.fov then put(cam, "FieldOfView", v.fov_value) end
    if v.zoom and LocalPlayer then
        put(LocalPlayer, "CameraMaxZoomDistance", 128 * (v.zoom_value or 1))
    end
end

local Aura = { emitter = nil }

local Persp = { bound = false }

local function persp_step()
    if CFG.vis.persp ~= "segunda" then return end
    refresh_local()
    local char = LocalPlayer and LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    local cam = Workspace.CurrentCamera
    if not head or not cam then return end
    pcall(function()
        local dist = CFG.vis.persp_dist or 6
        local eye = head.Position + head.CFrame.LookVector * dist + Vector3.new(0, 0.45, 0)
        cam.CFrame = CFrame.lookAt(eye, head.Position)
    end)
end

function Persp.apply()
    refresh_local()
    pcall(function() RunService:UnbindFromRenderStep("LunarPersp") end)
    Persp.bound = false
    if not LocalPlayer then return end

    local mode = CFG.vis.persp
    pcall(function() LocalPlayer.CameraMode = Enum.CameraMode.Classic end)
    put(LocalPlayer, "CameraMinZoomDistance", 0.5)

    if mode == "primeira" then
        pcall(function() LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson end)
        put(LocalPlayer, "CameraMaxZoomDistance", 0.5)
    elseif mode == "segunda" then
        put(LocalPlayer, "CameraMaxZoomDistance", 16)
        pcall(function()
            RunService:BindToRenderStep("LunarPersp", Enum.RenderPriority.Camera.Value + 3, persp_step)
        end)
        Persp.bound = true
    else
        put(LocalPlayer, "CameraMaxZoomDistance", 128)
    end
end

function Persp.release()
    pcall(function() RunService:UnbindFromRenderStep("LunarPersp") end)
    Persp.bound = false
end

function Aura.release()
    if Aura.emitter then
        pcall(function() Aura.emitter:Destroy() end)
        Aura.emitter = nil
    end
end

function Aura.apply()
    refresh_local()
    local v = CFG.vis
    local char = LocalPlayer and LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not v.aura or not root then
        Aura.release()
        return
    end
    if Aura.emitter and Aura.emitter.Parent == root then
        Aura.emitter.Color = ColorSequence.new(color_from_hsv(v.aura_color, 0.6))
        return
    end
    Aura.release()
    local em = Instance.new("ParticleEmitter")
    em.Name = "LunarAura"
    em.Rate = 25
    em.Speed = NumberRange.new(0.5, 2)
    em.Lifetime = NumberRange.new(0.6, 1.2)
    em.Size = NumberSequence.new(0.28)
    em.Transparency = NumberSequence.new(0.45)
    em.Color = ColorSequence.new(color_from_hsv(v.aura_color, 0.6))
    em.SpreadAngle = Vector2.new(180, 180)
    em.LightEmission = 1
    em.Parent = root
    Aura.emitter = em
end

function HideAcc.apply()
    refresh_local()
    local v = CFG.vis
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("Accessory") or d:IsA("Accoutrement") or d:IsA("Hat") then
            for _, h in ipairs(d:GetDescendants()) do
                if h:IsA("BasePart") then
                    put(h, "LocalTransparencyModifier", v.hide_acc and 1 or 0)
                end
            end
        end
    end
end

function Scale.apply()
    refresh_local()
    local v = CFG.vis
    local char = LocalPlayer and LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    for _, name in ipairs({
        "BodyDepthScale", "BodyWidthScale", "BodyHeightScale",
        "HeadScale", "BodyProportionScale",
    }) do
        local bs = hum:FindFirstChild(name)
        if bs then pcall(function() bs.Value = v.scale_on and v.scale or 1 end) end
    end
end

local Mov = { bv = nil, axis = { f = 0, u = 0 }, pad = nil, bound = false, tick = 0 }

function Mov.release()
    if Mov.bv then
        pcall(function() Mov.bv:Destroy() end)
        Mov.bv = nil
    end
    refresh_local()
    local char = LocalPlayer and LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.PlatformStand = false end) end
end

local function fly_step()
    refresh_local()
    local char = LocalPlayer and LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local cam = Workspace.CurrentCamera

    if not CFG.mov.fly then
        if Mov.bv then
            pcall(function() Mov.bv:Destroy() end)
            Mov.bv = nil
        end
        return
    end
    if not hum or not root or not cam then return end

    pcall(function() hum.PlatformStand = true end)

    if not Mov.bv or Mov.bv.Parent ~= root then
        if Mov.bv then pcall(function() Mov.bv:Destroy() end) end
        local bv = Instance.new("BodyVelocity")
        bv.Name = "LunarFly"
        bv.MaxForce = Vector3.new(100000, 100000, 100000)
        bv.P = 8000
        bv.Parent = root
        Mov.bv = bv
    end

    local speed = CFG.mov.fly_speed or 55
    local vel = cam.CFrame.LookVector * (Mov.axis.f * speed)
        + Vector3.new(0, Mov.axis.u * speed, 0)
    pcall(function() Mov.bv.Velocity = vel end)
end

local function slow_tick()
    refresh_local()
    local char = LocalPlayer and LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if CFG.mov.speed then
        pcall(function() hum.WalkSpeed = CFG.mov.speed_value end)
    end
    if CFG.mov.jump then
        pcall(function()
            hum.UseJumpPower = true
            hum.JumpPower = CFG.mov.jump_power
        end)
    end
    if CFG.mov.noclip then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then
                pcall(function() d.CanCollide = false end)
            end
        end
    end
end

function Mov.start()
    if Mov.bound then return end
    Mov.bound = true
    RunService.RenderStepped:Connect(function()
        pcall(fly_step)
        Mov.tick += 1
        if Mov.tick % 12 == 0 then pcall(slow_tick) end
    end)
end

function Mov.set_pad(visible)
    if Mov.pad then Mov.pad.Visible = visible end
end

-- copy skin ------------------------------------------------------------

local Skin = { clone = nil, links = {}, welds = {}, conn = nil, active = false }

function Skin.release()
    refresh_local()
    if Skin.conn then
        pcall(function() Skin.conn:Disconnect() end)
        Skin.conn = nil
    end
    local char = LocalPlayer and LocalPlayer.Character
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then pcall(function() d.LocalTransparencyModifier = 0 end) end
        end
    end
    if Skin.clone then
        pcall(function() Skin.clone:Destroy() end)
        Skin.clone = nil
    end
    Skin.links, Skin.welds = {}, {}
    Skin.active = false
end

local function strip_scripts(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("Script") then pcall(function() d:Destroy() end) end
    end
end

local function build_skin_links(clone, myChar)
    local links, welds = {}, {}
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            local acc = d:FindFirstAncestorOfClass("Accessory") or d:FindFirstAncestorOfClass("Accoutrement")
            local match = (not acc) and myChar:FindFirstChild(d.Name, true) or nil
            if match and match:IsA("BasePart") then
                links[#links + 1] = { dst = d, src = match }
            end
        elseif d:IsA("Weld") or d:IsA("Motor6D") then
            if d.Part0 and d.Part1 and d.Part1:IsA("BasePart") and d.Part0:IsA("BasePart") then
                welds[#welds + 1] = { part0 = d.Part0, c0 = d.C0, c1 = d.C1, part1 = d.Part1 }
            end
        end
    end
    return links, welds
end

function Skin.copy_from(target)
    refresh_local()
    if not target or not target.Character then return false, "sem personagem" end
    local srcHum = target.Character:FindFirstChildOfClass("Humanoid")
    if not srcHum then return false, "sem humanoid" end
    if not LocalPlayer or not LocalPlayer.Character then return false, "voce nao tem personagem" end

    local myChar = LocalPlayer.Character
    if not myChar:FindFirstChildOfClass("Humanoid") then return false, "voce esta morto" end

    local desc
    if not pcall(function() desc = srcHum:GetAppliedDescription() end) or not desc then
        return false, "descricao bloqueada"
    end

    Skin.release()

    local clone = myChar:Clone()
    clone.Name = "LunarSkin"
    strip_scripts(clone)

    local cloneHum = clone:FindFirstChildOfClass("Humanoid")
    if cloneHum then
        pcall(function() cloneHum:ApplyDescription(desc) end)
        pcall(function() cloneHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
    end

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            d.Massless = true
        end
    end

    local cam = Workspace.CurrentCamera
    if not cam then return false, "sem camera" end
    clone.Parent = cam

    Skin.links, Skin.welds = build_skin_links(clone, myChar)
    Skin.clone = clone
    Skin.active = true

    Skin.conn = RunService.RenderStepped:Connect(function()
        if not Skin.active then return end
        local chr = LocalPlayer and LocalPlayer.Character
        if not chr then return end
        for _, l in ipairs(Skin.links) do
            if l.dst and l.src then pcall(function() l.dst.CFrame = l.src.CFrame end) end
        end
        for _, w in ipairs(Skin.welds) do
            if w.part0 and w.part1 then
                pcall(function() w.part1.CFrame = w.part0.CFrame * w.c0 * w.c1:Inverse() end)
            end
        end
        for _, d in ipairs(chr:GetDescendants()) do
            if d:IsA("BasePart") then pcall(function() d.LocalTransparencyModifier = 1 end) end
        end
    end)

    return true, "skin aplicada (so voce ve)"
end

function Skin.copy_replicated(target)
    refresh_local()
    local srcHum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    if not srcHum then return false, "sem humanoid" end
    local myHum = LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not myHum then return false, "voce esta morto" end
    local desc
    if not pcall(function() desc = srcHum:GetAppliedDescription() end) or not desc then
        return false, "descricao bloqueada"
    end
    local ok = pcall(function() myHum:ApplyDescription(desc) end)
    if ok then return true, "skin replicada — todos veem" end
    return false, "servidor recusou"
end

-- viewer 3d ------------------------------------------------------------

local Viewer = { frame = nil, conn = nil, model = nil }

function Viewer.close()
    if Viewer.conn then
        pcall(function() Viewer.conn:Disconnect() end)
        Viewer.conn = nil
    end
    if Viewer.frame then
        pcall(function() Viewer.frame:Destroy() end)
        Viewer.frame = nil
    end
    Viewer.model = nil
end

function Viewer.open(target)
    Viewer.close()
    local char = target and target.Character
    if not char then return false end

    local holder
    local ok = pcall(function()
        holder = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if not ok or not holder then
        holder = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    end
    if not holder then return false end

    local frame = Instance.new("Frame")
    frame.Name = "LunarViewer"
    frame.Size = UDim2.fromOffset(200, 240)
    frame.Position = UDim2.new(0.5, -100, 0.5, -120)
    frame.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
    frame.BorderSizePixel = 0
    frame.Parent = holder
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local vp = Instance.new("ViewportFrame")
    vp.Size = UDim2.new(1, -12, 1, -42)
    vp.Position = UDim2.fromOffset(6, 6)
    vp.BackgroundColor3 = Color3.fromRGB(18, 21, 27)
    vp.BorderSizePixel = 0
    vp.Ambient = Color3.fromRGB(200, 200, 210)
    vp.LightColor = Color3.fromRGB(255, 255, 255)
    vp.Parent = frame
    local vc = Instance.new("UICorner")
    vc.CornerRadius = UDim.new(0, 8)
    vc.Parent = vp

    local world = Instance.new("WorldModel")
    world.Parent = vp

    local cam = Instance.new("Camera")
    cam.FieldOfView = 32
    cam.Parent = vp
    vp.CurrentCamera = cam

    local model = char:Clone()
    strip_scripts(model)
    model.Name = "LunarPreview"
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
        end
    end
    model:PivotTo(CFrame.new(0, 0, 0))
    model.Parent = world

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(1, -12, 0, 28)
    close.Position = UDim2.new(0, 6, 1, -34)
    close.BackgroundColor3 = Color3.fromRGB(30, 34, 42)
    close.BorderSizePixel = 0
    close.Font = Enum.Font.Code
    close.TextSize = 12
    close.TextColor3 = Color3.fromRGB(180, 190, 205)
    close.Text = "fechar"
    close.Parent = frame
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 6)
    cc.Parent = close
    close.MouseButton1Click:Connect(Viewer.close)

    local angle = 0
    Viewer.frame, Viewer.model = frame, model
    Viewer.conn = RunService.RenderStepped:Connect(function(dt)
        angle += dt * 0.55
        local focus = Vector3.new(0, 2.6, 0)
        local eye = focus + Vector3.new(math.sin(angle) * 11, 1.4, math.cos(angle) * 11)
        cam.CFrame = CFrame.new(eye, focus)
    end)

    return true
end

-- xitadu --------------------------------------------------------------

local DRAWING
if type(Drawing) == "table" then DRAWING = Drawing end

local Xitadu = {
    hooked = false,
    old_namecall = nil,
    draws = {},
    unwind = {},
    last_fire = 0,
    pre_cf = nil,
    pre_t = 0,
    fov_circle = nil,
    hl = {},
    box3d = {},
    locked = nil,
}

local SKEL_R15 = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}

local SKEL_R6 = {
    { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
    { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local function dnew(kind)
    if not DRAWING then return nil end
    local ok, obj = pcall(DRAWING.new, kind)
    if ok then return obj end
    return nil
end

local function dset(obj, prop, value)
    if not obj then return end
    pcall(function() obj[prop] = value end)
end

local function dremove(obj)
    if not obj then return end
    pcall(function() obj:Remove() end)
end

local function part_of(char, name)
    local p = char:FindFirstChild(name)
    if p and p:IsA("BasePart") then return p end
    return nil
end

function Xitadu.esp_active()
    local x = CFG.xitadu
    return x.esp_box or x.esp_name or x.esp_health or x.esp_dist
        or x.esp_skel or x.esp_tracer or x.esp_glow or x.esp_box3d or x.esp_fov
end

function Xitadu.find_part(char)
    local mode = CFG.xitadu.aim_part
    if mode == "Torso" then
        return part_of(char, "UpperTorso") or part_of(char, "Torso") or part_of(char, "HumanoidRootPart")
    elseif mode == "Raiz" then
        return part_of(char, "HumanoidRootPart")
    end
    return part_of(char, "Head") or part_of(char, "UpperTorso") or part_of(char, "HumanoidRootPart")
end

function Xitadu.valid(pl)
    refresh_local()
    if pl == LocalPlayer then return false end
    local x = CFG.xitadu
    local char = pl.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if x.aim_team and LocalPlayer and pl.Team and LocalPlayer.Team and pl.Team == LocalPlayer.Team then
        return false
    end
    local part = Xitadu.find_part(char)
    if not part then return false end
    if x.aim_wall then
        local cam = Workspace.CurrentCamera
        if not cam then return false end
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local filter = { char, cam }
        if LocalPlayer and LocalPlayer.Character then
            filter[#filter + 1] = LocalPlayer.Character
        end
        rp.FilterDescendantsInstances = filter
        local hit = Workspace:Raycast(cam.CFrame.Position, part.Position - cam.CFrame.Position, rp)
        if hit then return false end
    end
    return true, part
end

function Xitadu.pick_target()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local x = CFG.xitadu
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local best, best_d = nil, nil

    if x.sticky and Xitadu.locked then
        local ok, part = Xitadu.valid(Xitadu.locked)
        if ok and part then
            local sp, on = cam:WorldToViewportPoint(part.Position)
            if on then
                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if d <= x.aim_fov * 1.6 then
                    return { pl = Xitadu.locked, part = part }
                end
            end
        end
        Xitadu.locked = nil
    end

    for _, pl in ipairs(Players:GetPlayers()) do
        local ok, part = Xitadu.valid(pl)
        if ok then
            local sp, on = cam:WorldToViewportPoint(part.Position)
            if on then
                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if d <= x.aim_fov then
                    if not best_d or d < best_d then
                        best, best_d = { pl = pl, part = part }, d
                    end
                end
            end
        end
    end

    if best and x.sticky then Xitadu.locked = best.pl end
    return best
end

-- esp ------------------------------------------------------------------

local function proj(cam, v)
    local sp, on = cam:WorldToViewportPoint(v)
    return Vector2.new(sp.X, sp.Y), on, sp.Z
end

function Xitadu.clean(pl)
    local set = Xitadu.draws[pl]
    if set then
        for key, o in pairs(set) do
            if key ~= "skel" then dremove(o) end
        end
        for _, line in ipairs(set.skel or {}) do dremove(line) end
        Xitadu.draws[pl] = nil
    end
    if Xitadu.hl[pl] then
        pcall(function() Xitadu.hl[pl]:Destroy() end)
        Xitadu.hl[pl] = nil
    end
    if Xitadu.box3d[pl] then
        pcall(function() Xitadu.box3d[pl]:Destroy() end)
        Xitadu.box3d[pl] = nil
    end
end

local function build_set()
    local set = {
        box = dnew("Square"), name = dnew("Text"), dist = dnew("Text"),
        hp_bg = dnew("Square"), hp = dnew("Square"),
        tracer = dnew("Line"), skel = {},
    }
    dset(set.name, "Center", false)
    dset(set.name, "Outline", true)
    dset(set.name, "Size", 13)
    dset(set.dist, "Center", true)
    dset(set.dist, "Outline", true)
    dset(set.dist, "Size", 12)
    dset(set.box, "Filled", false)
    dset(set.box, "Thickness", 1)
    dset(set.hp_bg, "Filled", true)
    dset(set.hp_bg, "Thickness", 0)
    dset(set.hp, "Filled", true)
    dset(set.hp, "Thickness", 0)
    for i = 1, 14 do set.skel[i] = dnew("Line") end
    return set
end

local function col_for(pl)
    local x = CFG.xitadu
    if LocalPlayer and pl.Team and LocalPlayer.Team and pl.Team == LocalPlayer.Team then
        return Color3.fromRGB(120, 210, 160)
    end
    return Color3.fromHSV((x.esp_hue or 0) / 360, 0.75, 1)
end

function Xitadu.draw_one(pl)
    local x = CFG.xitadu
    local cam = Workspace.CurrentCamera
    local char = pl.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not cam or not char or not hum then
        Xitadu.clean(pl)
        return
    end

    if x.esp_team and LocalPlayer and pl.Team and LocalPlayer.Team
        and pl.Team == LocalPlayer.Team then
        Xitadu.clean(pl)
        return
    end

    local set = Xitadu.draws[pl]
    if not set then
        set = build_set()
        Xitadu.draws[pl] = set
    end

    local cf, size = char:GetBoundingBox()
    local half = size / 2
    local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
    local seen = false

    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                local v = cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
                local p, _, z = proj(cam, v)
                if z and z > 0 then
                    seen = true
                    if p.X < minx then minx = p.X end
                    if p.Y < miny then miny = p.Y end
                    if p.X > maxx then maxx = p.X end
                    if p.Y > maxy then maxy = p.Y end
                end
            end
        end
    end

    if not seen then
        Xitadu.clean(pl)
        return
    end

    local w = math.max(maxx - minx, 1)
    local h = math.max(maxy - miny, 1)
    local color = col_for(pl)
    local head = part_of(char, "Head") or part_of(char, "HumanoidRootPart")
    local root = part_of(char, "HumanoidRootPart")
    local dist = 0
    if root then
        dist = math.floor((cam.CFrame.Position - root.Position).Magnitude + 0.5)
    end

    dset(set.box, "Visible", x.esp_box)
    dset(set.box, "Position", Vector2.new(minx, miny))
    dset(set.box, "Size", Vector2.new(w, h))
    dset(set.box, "Color", color)

    dset(set.name, "Visible", x.esp_name)
    dset(set.name, "Text", pl.Name)
    dset(set.name, "Position", Vector2.new(minx, miny - 16))
    dset(set.name, "Color", color)

    dset(set.dist, "Visible", x.esp_dist)
    dset(set.dist, "Text", tostring(dist) .. "m")
    dset(set.dist, "Position", Vector2.new(minx + w / 2, maxy + 3))
    dset(set.dist, "Color", color)

    local hp_frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    dset(set.hp_bg, "Visible", x.esp_health)
    dset(set.hp_bg, "Position", Vector2.new(minx - 6, miny))
    dset(set.hp_bg, "Size", Vector2.new(3, h))
    dset(set.hp_bg, "Color", Color3.fromRGB(40, 40, 40))
    dset(set.hp, "Visible", x.esp_health)
    dset(set.hp, "Position", Vector2.new(minx - 6, miny + h * (1 - hp_frac)))
    dset(set.hp, "Size", Vector2.new(3, math.max(h * hp_frac, 1)))
    dset(set.hp, "Color", Color3.fromRGB(255 * (1 - hp_frac), 255 * hp_frac, 60))

    if x.esp_tracer and head then
        local hp_pos, on = proj(cam, head.Position)
        local vp = cam.ViewportSize
        dset(set.tracer, "Visible", on)
        dset(set.tracer, "From", Vector2.new(vp.X / 2, vp.Y))
        dset(set.tracer, "To", hp_pos)
        dset(set.tracer, "Color", color)
        dset(set.tracer, "Thickness", 1)
    else
        dset(set.tracer, "Visible", false)
    end

    local list = char:FindFirstChild("UpperTorso") and SKEL_R15 or SKEL_R6
    local idx = 0
    for _, pair in ipairs(list) do
        local a = part_of(char, pair[1])
        local b = part_of(char, pair[2])
        idx += 1
        local line = set.skel[idx]
        if x.esp_skel and a and b and line then
            local pa, on_a = proj(cam, a.Position)
            local pb, on_b = proj(cam, b.Position)
            dset(line, "Visible", on_a and on_b)
            dset(line, "From", pa)
            dset(line, "To", pb)
            dset(line, "Color", color)
            dset(line, "Thickness", 1)
        elseif line then
            dset(line, "Visible", false)
        end
    end

    if x.esp_glow then
        local hl = Xitadu.hl[pl]
        if not hl or hl.Parent ~= char then
            if hl then pcall(function() hl:Destroy() end) end
            hl = Instance.new("Highlight")
            hl.Name = "LunarXitadu"
            hl.Adornee = char
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillTransparency = 0.55
            hl.OutlineTransparency = 0
            hl.Parent = char
            Xitadu.hl[pl] = hl
        end
        hl.FillColor = color
        hl.OutlineColor = color
    elseif Xitadu.hl[pl] then
        pcall(function() Xitadu.hl[pl]:Destroy() end)
        Xitadu.hl[pl] = nil
    end

    if x.esp_box3d and root then
        local box = Xitadu.box3d[pl]
        if not box or box.Parent ~= root then
            if box then pcall(function() box:Destroy() end) end
            box = Instance.new("BoxHandleAdornment")
            box.Name = "LunarXitaduBox"
            box.Adornee = root
            box.AlwaysOnTop = true
            box.ZIndex = 5
            box.Transparency = 0.6
            box.Parent = root
            Xitadu.box3d[pl] = box
        end
        box.Size = Vector3.new(size.X, size.Y, size.Z)
        box.Color3 = color
    elseif Xitadu.box3d[pl] then
        pcall(function() Xitadu.box3d[pl]:Destroy() end)
        Xitadu.box3d[pl] = nil
    end
end

function Xitadu.esp_update()
    refresh_local()
    if not Xitadu.esp_active() then
        for pl in pairs(Xitadu.draws) do Xitadu.clean(pl) end
        if Xitadu.fov_circle then dset(Xitadu.fov_circle, "Visible", false) end
        return
    end

    local alive = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            if pcall(Xitadu.draw_one, pl) then alive[pl] = true end
        end
    end
    for pl in pairs(Xitadu.draws) do
        if not alive[pl] then Xitadu.clean(pl) end
    end

    if CFG.xitadu.esp_fov and DRAWING then
        local cam = Workspace.CurrentCamera
        if cam then
            if not Xitadu.fov_circle then
                Xitadu.fov_circle = dnew("Circle")
                dset(Xitadu.fov_circle, "Thickness", 1)
                dset(Xitadu.fov_circle, "NumSides", 60)
                dset(Xitadu.fov_circle, "Filled", false)
            end
            local vp = cam.ViewportSize
            dset(Xitadu.fov_circle, "Visible", true)
            dset(Xitadu.fov_circle, "Position", Vector2.new(vp.X / 2, vp.Y / 2))
            dset(Xitadu.fov_circle, "Radius", CFG.xitadu.aim_fov)
            dset(Xitadu.fov_circle, "Color", Color3.fromRGB(120, 210, 160))
        end
    elseif Xitadu.fov_circle then
        dset(Xitadu.fov_circle, "Visible", false)
    end
end

-- mira -----------------------------------------------------------------

local function camera_aim()
    local x = CFG.xitadu
    if not x.aim then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local target = Xitadu.pick_target()
    if not target then return end

    local look = CFrame.lookAt(cam.CFrame.Position, target.part.Position)
    local alpha = math.clamp(x.aim_smooth, 0.05, 1)
    cam.CFrame = cam.CFrame:Lerp(look, alpha)

    if x.aim_auto then
        local now = os.clock()
        if now - Xitadu.last_fire > 0.06 then
            Xitadu.last_fire = now
            local char = LocalPlayer and LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then pcall(function() tool:Activate() end) end
        end
    end
end

local function camera_recoil()
    if not CFG.xitadu.recoil then return end
    if not Xitadu.pre_cf then return end
    if os.clock() - Xitadu.pre_t > 0.4 then
        Xitadu.pre_cf = nil
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local kept = Xitadu.pre_cf
    cam.CFrame = CFrame.new(cam.CFrame.Position) * (kept - kept.Position)
end

local function on_input(input)
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        local cam = Workspace.CurrentCamera
        if cam then
            Xitadu.pre_cf = cam.CFrame
            Xitadu.pre_t = os.clock()
        end
    end
end

-- silent aim -----------------------------------------------------------

local SILENT_KEYS = {
    "fire", "shoot", "hit", "bullet", "attack", "damage",
    "click", "mouse", "gun", "weapon", "projectile", "tracer",
}

local function name_matches(name)
    if not name then return false end
    local low = string.lower(name)
    local list = CFG.xitadu.silent_filter
    if list and list ~= "" then
        for token in string.gmatch(list, "[^,]+") do
            local clean = string.lower((token:gsub("%s", "")))
            if clean ~= "" and string.find(low, clean, 1, true) then return true end
        end
        return false
    end
    for _, key in ipairs(SILENT_KEYS) do
        if string.find(low, key, 1, true) then return true end
    end
    return false
end

local function is_cframe(v)
    if v == nil then return false end
    local ok, r = pcall(function()
        return v.LookVector ~= nil and v.RightVector ~= nil and v.Position ~= nil
    end)
    return ok and r == true
end

local function is_vector3(v)
    if v == nil then return false end
    local ok, r = pcall(function()
        return type(v.X) == "number" and type(v.Y) == "number" and type(v.Z) == "number"
            and v.LookVector == nil
    end)
    return ok and r == true
end

function Xitadu.install_hook()
    if Xitadu.hooked then return end
    if not hookmetamethod or not getnamecallmethod then return end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local x = CFG.xitadu

        if x.silent_ghost and (method == "Raycast"
            or method == "FindPartOnRay"
            or method == "FindPartOnRayWithIgnoreList"
            or method == "FindPartOnRayWithWhitelist") then
            local target = Xitadu.pick_target()
            if target and target.part then
                local okp, pos = pcall(function() return target.part.Position end)
                if okp and pos then
                    return target.part, pos, Vector3.new(0, 1, 0), Enum.Material.Plastic
                end
            end
        end

        if (x.silent or x.silent_ghost) and (method == "FireServer" or method == "InvokeServer") then
            local remote_name = nil
            pcall(function() remote_name = self.Name end)
            if name_matches(remote_name) then
                local target = Xitadu.pick_target()
                if target then
                    local cam = Workspace.CurrentCamera
                    local aim_cf = cam and CFrame.lookAt(cam.CFrame.Position, target.part.Position) or nil
                    if aim_cf then
                        local args = table.pack(...)
                        for i = 1, args.n do
                            local v = args[i]
                            if is_cframe(v) then
                                args[i] = aim_cf
                            elseif x.silent_ghost and is_vector3(v) then
                                local okd, dist = pcall(function()
                                    return (v - cam.CFrame.Position).Magnitude
                                end)
                                if okd and dist and dist < 1200 then
                                    args[i] = target.part.Position
                                end
                            end
                        end
                        return old(self, table.unpack(args, 1, args.n))
                    end
                end
            end
        end
        return old(self, ...)
    end)
    Xitadu.old_namecall = old
    Xitadu.hooked = true
end

Xitadu.install_silent = Xitadu.install_hook

-- ciclo ----------------------------------------------------------------

function Xitadu.start()
    refresh_local()
    Xitadu.unwind[#Xitadu.unwind + 1] = RunService.RenderStepped:Connect(function()
        pcall(Xitadu.esp_update)
    end)
    Xitadu.unwind[#Xitadu.unwind + 1] = UIS.InputBegan:Connect(on_input)

    pcall(function() RunService:UnbindFromRenderStep("XitaduAim") end)
    pcall(function() RunService:UnbindFromRenderStep("XitaduRecoil") end)
    RunService:BindToRenderStep("XitaduAim", Enum.RenderPriority.Camera.Value + 1, camera_aim)
    RunService:BindToRenderStep("XitaduRecoil", Enum.RenderPriority.Camera.Value + 2, camera_recoil)

    Xitadu.install_hook()
end

function Xitadu.stop()
    for _, c in ipairs(Xitadu.unwind) do
        pcall(function() c:Disconnect() end)
    end
    Xitadu.unwind = {}
    pcall(function() RunService:UnbindFromRenderStep("XitaduAim") end)
    pcall(function() RunService:UnbindFromRenderStep("XitaduRecoil") end)
    for pl in pairs(Xitadu.draws) do Xitadu.clean(pl) end
    for _, hl in pairs(Xitadu.hl) do pcall(function() hl:Destroy() end) end
    for _, b in pairs(Xitadu.box3d) do pcall(function() b:Destroy() end) end
    Xitadu.hl, Xitadu.box3d = {}, {}
    if Xitadu.fov_circle then
        dremove(Xitadu.fov_circle)
        Xitadu.fov_circle = nil
    end
    if Xitadu.hooked and Xitadu.old_namecall and hookmetamethod then
        pcall(function() hookmetamethod(game, "__namecall", Xitadu.old_namecall) end)
        Xitadu.hooked = false
    end
end

function Xitadu.has_drawing()
    return DRAWING ~= nil
end

-- ui core --------------------------------------------------------------

local THEME = {
    bg = Color3.fromRGB(13, 15, 19),
    row = Color3.fromRGB(27, 31, 38),
    line = Color3.fromRGB(42, 48, 58),
    text = Color3.fromRGB(214, 222, 232),
    dim = Color3.fromRGB(122, 132, 146),
    accent = Color3.fromRGB(120, 210, 160),
    warn = Color3.fromRGB(240, 160, 90),
}

local UI = { conns = {}, refreshers = {}, pages = {} }
local ui_root, ui_frame, ui_body, ui_tabbar, ui_fps

local function ui_conn(c)
    UI.conns[#UI.conns + 1] = c
    return c
end

local function shade(color, alpha)
    return color:Lerp(Color3.new(0, 0, 0), alpha)
end

local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props) do inst[k] = v end
    inst.Parent = parent
    return inst
end

local function add_corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = inst
    return c
end

function UI.refresh_all()
    for _, fn in ipairs(UI.refreshers) do pcall(fn) end
end

function UI.header(parent, text)
    return new("TextLabel", {
        Size = UDim2.new(1, -8, 0, 24),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = THEME.dim,
        Text = "  " .. string.upper(text),
    }, parent)
end

function UI.label(parent, text, color, height)
    return new("TextLabel", {
        Size = UDim2.new(1, -8, 0, height or 30),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = color or THEME.dim,
        Text = text,
    }, parent)
end

function UI.toggle(parent, label, getv, setv)
    local row = new("TextButton", {
        Size = UDim2.new(1, -8, 0, 32),
        BackgroundColor3 = THEME.row,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Text = "",
    }, parent)
    add_corner(row, 6)

    local txt = new("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = THEME.text,
        Text = label,
    }, row)

    local pill = new("Frame", {
        Size = UDim2.fromOffset(32, 18),
        Position = UDim2.new(1, -42, 0.5, -9),
        BackgroundColor3 = Color3.fromRGB(46, 52, 62),
        BorderSizePixel = 0,
    }, row)
    add_corner(pill, 9)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = THEME.dim,
        BorderSizePixel = 0,
    }, pill)
    add_corner(knob, 7)

    local function paint()
        local on = getv()
        pill.BackgroundColor3 = on and shade(THEME.accent, 0.55) or Color3.fromRGB(46, 52, 62)
        knob.Position = on and UDim2.fromOffset(16, 2) or UDim2.fromOffset(2, 2)
        knob.BackgroundColor3 = on and THEME.accent or THEME.dim
        txt.TextColor3 = on and THEME.text or THEME.dim
    end

    row.MouseButton1Click:Connect(function()
        setv(not getv())
        paint()
    end)

    paint()
    UI.refreshers[#UI.refreshers + 1] = paint
    return row
end

function UI.slider(parent, label, minv, maxv, step, getv, setv)
    local row = new("Frame", {
        Size = UDim2.new(1, -8, 0, 44),
        BackgroundColor3 = THEME.row,
        BorderSizePixel = 0,
    }, parent)
    add_corner(row, 6)

    local txt = new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 22),
        Position = UDim2.fromOffset(10, 2),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = THEME.text,
        Text = label,
    }, row)

    local bar = new("Frame", {
        Size = UDim2.new(1, -20, 0, 8),
        Position = UDim2.new(0, 10, 1, -16),
        BackgroundColor3 = Color3.fromRGB(44, 50, 60),
        BorderSizePixel = 0,
    }, row)
    add_corner(bar, 4)

    local fill = new("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = THEME.accent,
        BorderSizePixel = 0,
    }, bar)
    add_corner(fill, 4)

    local dragging = false

    local function refresh()
        local span = maxv - minv
        local frac = span > 0 and ((getv() - minv) / span) or 0
        fill.Size = UDim2.fromScale(clamp01(frac), 1)
        if step >= 1 then
            txt.Text = string.format("%s   %d", label, math.floor(getv() + 0.5))
        else
            txt.Text = string.format("%s   %.2f", label, getv())
        end
    end

    local function commit(x)
        local span = math.max(bar.AbsoluteSize.X, 1)
        local frac = math.clamp((x - bar.AbsolutePosition.X) / span, 0, 1)
        local val = minv + frac * (maxv - minv)
        if step >= 1 then val = math.floor(val / step + 0.5) * step end
        setv(math.clamp(val, minv, maxv))
        refresh()
    end

    bar.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragging = true
            commit(input.Position.X)
        end
    end)

    ui_conn(UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseMovement then
            commit(input.Position.X)
        end
    end))

    ui_conn(UIS.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            if dragging then save_config() end
            dragging = false
        end
    end))

    refresh()
    UI.refreshers[#UI.refreshers + 1] = refresh
    return row
end

function UI.cycle(parent, label, options, getv, setv)
    local btn = new("TextButton", {
        Size = UDim2.new(1, -8, 0, 34),
        BackgroundColor3 = THEME.row,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = THEME.text,
    }, parent)
    add_corner(btn, 6)

    local function paint()
        btn.Text = "  " .. label .. ":  " .. tostring(getv())
    end

    btn.MouseButton1Click:Connect(function()
        local cur = getv()
        local idx = 1
        for i, o in ipairs(options) do
            if o == cur then idx = i end
        end
        idx = idx % #options + 1
        setv(options[idx])
        paint()
        save_config()
    end)

    paint()
    UI.refreshers[#UI.refreshers + 1] = paint
    return btn
end

function UI.button(parent, label, cb, color)
    local btn = new("TextButton", {
        Size = UDim2.new(1, -8, 0, 34),
        BackgroundColor3 = color or Color3.fromRGB(34, 74, 52),
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextColor3 = THEME.text,
        Text = "  " .. label,
    }, parent)
    add_corner(btn, 6)
    btn.MouseButton1Click:Connect(cb)
    return btn
end

function UI.input(parent, label, placeholder, cb, initial)
    UI.header(parent, label)
    local box = new("TextBox", {
        Size = UDim2.new(1, -8, 0, 34),
        BackgroundColor3 = THEME.row,
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = THEME.text,
        PlaceholderColor3 = THEME.dim,
        PlaceholderText = placeholder or "",
        Text = initial or "",
        ClearTextOnFocus = false,
    }, parent)
    add_corner(box, 6)
    box.FocusLost:Connect(function()
        cb(box.Text)
        save_config()
    end)
    return box
end

local Toast = { label = nil }

function Toast.show(text, seconds)
    if not ui_root then return end
    if not Toast.label or not Toast.label.Parent then
        Toast.label = new("TextLabel", {
            Size = UDim2.new(0.7, 0, 0, 30),
            Position = UDim2.new(0.15, 0, 0, 12),
            BackgroundColor3 = Color3.fromRGB(20, 23, 29),
            BackgroundTransparency = 0.1,
            Font = Enum.Font.Code,
            TextSize = 12,
            TextWrapped = true,
            TextColor3 = THEME.text,
            Text = "",
            ZIndex = 5,
        }, ui_root)
        add_corner(Toast.label, 8)
    end
    Toast.label.Text = text
    Toast.label.Visible = true
    task.delay(seconds or 3, function()
        if Toast.label then Toast.label.Visible = false end
    end)
end

local Watch = { pending = nil }

function Watch.arm(label)
    if not CFG.watchdog then return end
    Watch.pending = { label = label, fps = Fps.value }
    task.delay(8, function()
        local pend = Watch.pending
        if not pend or pend.label ~= label then return end
        Watch.pending = nil
        if pend.fps > 0 and Fps.value > 0 and Fps.value < pend.fps - 8 then
            Toast.show(string.format("%s custou %d fps. manter?", label, pend.fps - Fps.value), 4)
        end
    end)
end

-- janela ---------------------------------------------------------------

local function holder_gui()
    local parent
    local ok = pcall(function()
        parent = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if not ok or not parent then
        parent = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    end
    return parent
end

local function build_window()
    local parent = holder_gui()
    if not parent then return false end

    local root = Instance.new("ScreenGui")
    root.Name = "LunarOpt"
    root.ResetOnSpawn = false
    root.IgnoreGuiInset = true
    root.DisplayOrder = 999
    local hooked = pcall(function() root.Parent = parent end)
    if not hooked or not root.Parent then
        local lp = Players.LocalPlayer
        local pg = lp and lp:FindFirstChild("PlayerGui")
        if not pg and lp then
            pcall(function() pg = lp:WaitForChild("PlayerGui", 5) end)
        end
        if pg then pcall(function() root.Parent = pg end) end
    end
    if not root.Parent then
        print("[lunar.opt] sem container de interface")
        return false
    end
    ui_root = root

    local vw = (Camera and Camera.ViewportSize.X) or 360
    local width = math.clamp(math.floor(vw * 0.88), 280, 360)

    local frame = new("Frame", {
        Size = UDim2.fromOffset(width, 430),
        Position = UDim2.fromOffset(10, 54),
        BackgroundColor3 = THEME.bg,
        BackgroundTransparency = 0.03,
        BorderSizePixel = 0,
        Active = true,
    }, root)
    add_corner(frame, 12)
    new("UIStroke", { Color = THEME.line, Thickness = 1 }, frame)
    ui_frame = frame

    local header = new("TextLabel", {
        Size = UDim2.new(1, -80, 0, 34),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = THEME.text,
        Text = "  lunar.opt " .. VERSION,
    }, frame)

    ui_fps = new("TextLabel", {
        Size = UDim2.fromOffset(56, 34),
        Position = UDim2.new(1, -62, 0, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = THEME.accent,
        Text = "0 fps",
    }, frame)

    local min = new("TextButton", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, -30, 0, 4),
        BackgroundColor3 = Color3.fromRGB(30, 34, 42),
        BorderSizePixel = 0,
        Font = Enum.Font.Code,
        TextSize = 14,
        TextColor3 = THEME.dim,
        Text = "-",
    }, frame)
    add_corner(min, 6)

    local tabbar = new("ScrollingFrame", {
        Size = UDim2.new(1, -16, 0, 30),
        Position = UDim2.fromOffset(8, 36),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
    }, frame)
    ui_tabbar = tabbar

    local layout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, tabbar)

    local body = new("Frame", {
        Size = UDim2.new(1, -16, 1, -74),
        Position = UDim2.fromOffset(8, 70),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, frame)
    ui_body = body

    local collapsed = false
    min.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        body.Visible = not collapsed
        tabbar.Visible = not collapsed
        frame.Size = collapsed and UDim2.fromOffset(width, 34) or UDim2.fromOffset(width, 430)
        min.Text = collapsed and "+" or "-"
    end)

    local dragging, drag_start, frame_start
    header.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragging = true
            drag_start = input.Position
            frame_start = frame.Position
        end
    end)
    ui_conn(UIS.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
    ui_conn(UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseMovement then return end
        local d = input.Position - drag_start
        frame.Position = UDim2.fromOffset(frame_start.X.Offset + d.X, frame_start.Y.Offset + d.Y)
    end))

    task.spawn(function()
        while ui_root and ui_root.Parent do
            if ui_fps then ui_fps.Text = string.format("%d fps", Fps.value) end
            task.wait(0.4)
        end
    end)

    return true
end

local TAB_ORDER = { "desempenho", "ambiente", "visual", "xitadu", "movimento", "config" }
local tab_buttons = {}
local tab_pages = {}
local active_tab = nil

local function select_tab(name)
    if active_tab == name then return end
    active_tab = name
    CFG.tab = name
    for n, page in pairs(tab_pages) do
        page.Visible = (n == name)
    end
    for n, btn in pairs(tab_buttons) do
        btn.BackgroundColor3 = (n == name) and shade(THEME.accent, 0.62) or Color3.fromRGB(30, 34, 42)
        btn.TextColor3 = (n == name) and THEME.accent or THEME.dim
    end
end

local function build_tabs()
    for i, name in ipairs(TAB_ORDER) do
        local btn = new("TextButton", {
            Size = UDim2.fromOffset(0, 28),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = i,
            BackgroundColor3 = Color3.fromRGB(30, 34, 42),
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Font = Enum.Font.Code,
            TextSize = 11,
            TextColor3 = THEME.dim,
            Text = " " .. name .. " ",
        }, ui_tabbar)
        add_corner(btn, 6)
        tab_buttons[name] = btn

        local page = new("ScrollingFrame", {
            Name = name,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Color3.fromRGB(70, 78, 90),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
        }, ui_body)

        local list = new("UIListLayout", {
            Padding = UDim.new(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, page)

        local pad = new("UIPadding", {
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 14),
        }, page)

        tab_pages[name] = page
        btn.MouseButton1Click:Connect(function() select_tab(name) end)
    end
end

-- paginas --------------------------------------------------------------

local function page_desempenho(page)
    local p = CFG.perf

    UI.header(page, "desempenho")
    UI.toggle(page, "sombras", function() return p.shadows end, function(v)
        p.shadows = v; Perf.rebuild()
    end)
    UI.toggle(page, "pos-processamento", function() return p.post_fx end, function(v)
        p.post_fx = v; Perf.apply_post_fx()
    end)
    UI.toggle(page, "particulas e feixes", function() return p.particles end, function(v)
        p.particles = v; Perf.rebuild()
    end)
    UI.toggle(page, "luz de ambiente", function() return p.lighting end, function(v)
        p.lighting = v; Perf.apply_lighting()
    end)
    UI.toggle(page, "qualidade grafica", function() return p.quality end, function(v)
        p.quality = v; Perf.apply_quality(); Perf.apply_lighting()
    end)
    UI.toggle(page, "fidelidade de malha", function() return p.mesh end, function(v)
        p.mesh = v; Perf.rebuild()
    end)
    UI.toggle(page, "terreno e agua", function() return p.terrain end, function(v)
        p.terrain = v; Perf.apply_terrain()
    end)
    UI.toggle(page, "audio volumetrico", function() return p.audio end, function(v)
        p.audio = v; Perf.apply_audio()
    end)
    UI.toggle(page, "vento global", function() return p.wind end, function(v)
        p.wind = v; Perf.apply_wind()
    end)
    UI.toggle(page, "texturas e decals", function() return p.textures end, function(v)
        p.textures = v; Perf.rebuild()
    end)

    UI.header(page, "teto de quadros")
    UI.toggle(page, "travar fps", function() return p.cap end, function(v)
        p.cap = v; Perf.apply_cap()
    end)
    UI.slider(page, "teto", 30, 240, 5, function() return p.cap_value end, function(v)
        p.cap_value = v; Perf.apply_cap()
    end)
    UI.label(page, "no android o cliente trava em 60 por padrao. se o numero nao subir, o executor nao patcheia o frame limiter.", THEME.dim, 32)
end

local function page_ambiente(page)
    local e = CFG.env

    UI.header(page, "presets")
    for _, name in ipairs({ "dia", "entardecer", "noite", "inverno", "chuva", "nevoa", "espaco", "synthwave" }) do
        UI.button(page, name, function()
            local p = PRESETS[name]
            if not p then return end
            e.enabled = true
            e.preset = name
            e.clock = p.clock
            e.brightness = p.brightness
            e.exposure = p.exposure
            e.atmosphere = p.atmosphere
            e.haze = p.haze
            e.fog_start = p.fog_start
            e.fog_end = p.fog_end
            e.hue = p.hue
            e.tint = p.tint
            e.contrast = p.contrast
            e.saturation = p.saturation
            e.bloom = p.bloom
            e.sunrays = p.sunrays
            e.env_diffuse = p.env_diffuse
            e.env_spec = p.env_spec
            CFG.climate.kind = p.climate
            Env.apply()
            Climate.apply()
            UI.refresh_all()
            save_config()
        end, Color3.fromRGB(30, 36, 46))
    end

    UI.header(page, "luz")
    UI.toggle(page, "ambiente ativo", function() return e.enabled end, function(v)
        e.enabled = v; Env.apply()
    end)
    UI.slider(page, "hora do dia", 0, 24, 1, function() return e.clock end, function(v)
        e.clock = v; e.preset = "personalizado"; Env.apply()
    end)
    UI.slider(page, "brilho", 0, 4, 0.1, function() return e.brightness end, function(v)
        e.brightness = v; Env.apply()
    end)
    UI.slider(page, "exposicao", -1, 3, 0.1, function() return e.exposure end, function(v)
        e.exposure = v; Env.apply()
    end)

    UI.header(page, "atmosfera")
    UI.slider(page, "densidade", 0, 1, 0.05, function() return e.atmosphere end, function(v)
        e.atmosphere = v; Env.apply()
    end)
    UI.slider(page, "nevoa", 0, 10, 0.5, function() return e.haze end, function(v)
        e.haze = v; Env.apply()
    end)
    UI.slider(page, "reflexo", 0, 10, 0.5, function() return e.glare end, function(v)
        e.glare = v; Env.apply()
    end)

    UI.header(page, "cor")
    UI.slider(page, "matiz", 0, 360, 1, function() return e.hue end, function(v)
        e.hue = v; Env.apply()
    end)
    UI.slider(page, "intensidade", 0, 1, 0.05, function() return e.tint end, function(v)
        e.tint = v; Env.apply()
    end)
    UI.slider(page, "contraste", -1, 1, 0.05, function() return e.contrast end, function(v)
        e.contrast = v; Env.apply()
    end)
    UI.slider(page, "saturacao", -1, 1, 0.05, function() return e.saturation end, function(v)
        e.saturation = v; Env.apply()
    end)
    UI.slider(page, "brilho da imagem", -1, 1, 0.05, function() return e.cc_bright end, function(v)
        e.cc_bright = v; Env.apply()
    end)

    UI.header(page, "efeitos")
    UI.slider(page, "bloom", 0, 2, 0.05, function() return e.bloom end, function(v)
        e.bloom = v; Env.apply()
    end)
    UI.slider(page, "sunrays", 0, 2, 0.05, function() return e.sunrays end, function(v)
        e.sunrays = v; Env.apply()
    end)
    UI.slider(page, "profundidade", 0, 1, 0.05, function() return e.dof end, function(v)
        e.dof = v; Env.apply()
    end)

    UI.header(page, "ceu personalizado")
    UI.label(page, "cole seis ids de imagem separados por virgula: costas, baixo, frente, esquerda, direita, cima.", THEME.dim, 32)
    UI.input(page, "ids do ceu", "1234,5678,9012,...", function(v)
        e.sky_ids = v; Env.apply()
    end, e.sky_ids)

    UI.header(page, "clima")
    UI.cycle(page, "clima", { "nenhum", "neve", "chuva", "poeira", "brasa", "vaga" },
        function() return CFG.climate.kind end,
        function(v) CFG.climate.kind = v; Climate.apply(); Watch.arm("clima") end)
    UI.slider(page, "densidade", 0.2, 3, 0.1, function() return CFG.climate.density end, function(v)
        CFG.climate.density = v; Climate.apply()
    end)

    UI.header(page, "tela")
    UI.toggle(page, "vinheta", function() return CFG.overlay.vig end, function(v)
        CFG.overlay.vig = v; Overlay.apply()
    end)
    UI.slider(page, "forca da vinheta", 0.1, 1, 0.05, function() return CFG.overlay.vig_strength end, function(v)
        CFG.overlay.vig_strength = v; Overlay.apply()
    end)
    UI.toggle(page, "barras de cinema", function() return CFG.overlay.bars end, function(v)
        CFG.overlay.bars = v; Overlay.apply()
    end)
    UI.slider(page, "altura das barras", 2, 30, 1, function() return CFG.overlay.bars_size end, function(v)
        CFG.overlay.bars_size = v; Overlay.apply()
    end)
    UI.toggle(page, "tingir a tela", function() return CFG.overlay.tint end, function(v)
        CFG.overlay.tint = v; Overlay.apply()
    end)
    UI.slider(page, "cor da tela", 0, 360, 1, function() return CFG.overlay.hue end, function(v)
        CFG.overlay.hue = v; Overlay.apply()
    end)
    UI.slider(page, "forca do tingimento", 0.02, 0.6, 0.02, function() return CFG.overlay.tint_strength end, function(v)
        CFG.overlay.tint_strength = v; Overlay.apply()
    end)
end

local player_container = nil

local function hold_button(btn, on_hold, ms)
    local pressed_at = nil
    local fired = false
    btn.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            pressed_at = os.clock()
            fired = false
            task.delay((ms or 650) / 1000, function()
                if pressed_at and not fired then
                    fired = true
                    on_hold()
                end
            end)
        end
    end)
    btn.InputEnded:Connect(function(input)
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
            if not fired and pressed_at then
                pressed_at = nil
            end
            pressed_at = nil
        end
    end)
    return function() return fired end
end

local function refresh_players()
    if not player_container then return end
    for _, c in ipairs(player_container:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
            c:Destroy()
        end
    end

    local list = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then list[#list + 1] = pl end
    end

    for i, pl in ipairs(list) do
        local row = new("Frame", {
            Size = UDim2.new(1, -8, 0, 36),
            BackgroundColor3 = THEME.row,
            BorderSizePixel = 0,
            LayoutOrder = i,
        }, player_container)
        add_corner(row, 6)

        local name = new("TextButton", {
            Size = UDim2.new(1, -84, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.Code,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = THEME.text,
            Text = "  " .. pl.Name,
        }, row)

        local view_btn = new("TextButton", {
            Size = UDim2.fromOffset(38, 26),
            Position = UDim2.new(1, -80, 0.5, -13),
            BackgroundColor3 = Color3.fromRGB(38, 44, 54),
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Font = Enum.Font.Code,
            TextSize = 11,
            TextColor3 = THEME.dim,
            Text = "ver",
        }, row)
        add_corner(view_btn, 5)

        local copy_btn = new("TextButton", {
            Size = UDim2.fromOffset(38, 26),
            Position = UDim2.new(1, -38, 0.5, -13),
            BackgroundColor3 = shade(THEME.accent, 0.62),
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Font = Enum.Font.Code,
            TextSize = 11,
            TextColor3 = THEME.accent,
            Text = "copiar",
        }, row)
        add_corner(copy_btn, 5)

        view_btn.MouseButton1Click:Connect(function()
            if Viewer.open(pl) then
                Watch.arm("preview 3d")
            else
                Toast.show("nao consegui abrir o preview", 2)
            end
        end)

        copy_btn.MouseButton1Click:Connect(function()
            local ok, msg = Skin.copy_from(pl)
            Toast.show(msg, 3)
            if ok then
                UI.refresh_all()
            end
        end)

        hold_button(name, function()
            local ok, msg = Skin.copy_replicated(pl)
            Toast.show(msg, 3)
        end, 650)
    end

    if #list == 0 then
        new("TextLabel", {
            Size = UDim2.new(1, -8, 0, 30),
            BackgroundTransparency = 1,
            Font = Enum.Font.Code,
            TextSize = 11,
            TextColor3 = THEME.dim,
            Text = "  sozinho no servidor",
        }, player_container)
    end
end

local function page_visual(page)
    local v = CFG.vis

    UI.header(page, "skins")
    UI.label(page, "toca em copiar para vestir a skin de alguem. segura o nome por meio segundo para o modo replicado.", THEME.dim, 32)

    local wrap = new("Frame", {
        Size = UDim2.new(1, -8, 0, 180),
        BackgroundColor3 = Color3.fromRGB(18, 21, 27),
        BorderSizePixel = 0,
    }, page)
    add_corner(wrap, 8)

    player_container = new("ScrollingFrame", {
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.fromOffset(4, 4),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Color3.fromRGB(70, 78, 90),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, wrap)
    local pl = new("UIListLayout", { Padding = UDim.new(0, 4) }, player_container)

    refresh_players()

    UI.button(page, "soltar skin", function()
        Skin.release()
        Toast.show("skin solta", 2)
    end, Color3.fromRGB(44, 34, 34))

    UI.toggle(page, "modo replicado no toque longo", function() return v.replicated end, function(x)
        v.replicated = x
        if x then Toast.show("replicado: todos veem, e o servidor pode reverter", 3) end
    end)

    UI.header(page, "personagem")
    UI.toggle(page, "aura", function() return v.aura end, function(x)
        v.aura = x; Aura.apply()
    end)
    UI.slider(page, "cor da aura", 0, 360, 1, function() return v.aura_color end, function(x)
        v.aura_color = x; Aura.apply()
    end)
    UI.toggle(page, "esconder acessorios", function() return v.hide_acc end, function(x)
        v.hide_acc = x; HideAcc.apply()
    end)
    UI.toggle(page, "mudar escala", function() return v.scale_on end, function(x)
        v.scale_on = x; Scale.apply()
    end)
    UI.slider(page, "escala", 0.5, 1.5, 0.05, function() return v.scale end, function(x)
        v.scale = x; Scale.apply()
    end)

    UI.header(page, "visao")
    UI.cycle(page, "perspectiva", { "primeira", "segunda", "terceira" },
        function() return v.persp end,
        function(x)
            v.persp = x
            Persp.apply()
        end)
    UI.slider(page, "distancia da segunda", 2, 16, 1, function() return v.persp_dist end, function(x)
        v.persp_dist = x
    end)
    UI.label(page, "segunda pessoa poe a camera na frente do personagem olhando de volta. o movimento inverte, e isso e do modo, nao do script.", THEME.dim, 32)

    UI.header(page, "camera")
    UI.toggle(page, "campo de visao", function() return v.fov end, function(x)
        v.fov = x; Cam.apply()
    end)
    UI.slider(page, "fov", 40, 120, 1, function() return v.fov_value end, function(x)
        v.fov_value = x; Cam.apply()
    end)
    UI.toggle(page, "zoom maximo", function() return v.zoom end, function(x)
        v.zoom = x; Cam.apply()
    end)
    UI.slider(page, "multiplicador de zoom", 0.5, 3, 0.1, function() return v.zoom_value end, function(x)
        v.zoom_value = x; Cam.apply()
    end)

    UI.header(page, "som ambiente")
    UI.toggle(page, "ligar som", function() return v.ambience end, function(x)
        v.ambience = x; Ambience.apply()
    end)
    UI.input(page, "id do som", "id do audio", function(txt)
        v.ambience_id = txt; Ambience.apply()
    end, v.ambience_id)
    UI.slider(page, "volume", 0, 1, 0.05, function() return v.ambience_vol end, function(x)
        v.ambience_vol = x; Ambience.apply()
    end)

    Players.PlayerAdded:Connect(function()
        task.defer(refresh_players)
    end)
    Players.PlayerRemoving:Connect(function()
        task.defer(refresh_players)
    end)
end

-- pagina xitadu --------------------------------------------------------

local function page_xitadu(page)
    local x = CFG.xitadu

    UI.header(page, "xitadu")
    UI.label(page,
        Xitadu.has_drawing()
            and "desenho 2d ativo (Drawing). aimbot, silent e esp ficam em cima do render do cliente."
            or "sem Drawing neste executor: so glow 3d e caixa 3d funcionam.",
        THEME.dim, 32)

    UI.header(page, "esp")
    UI.toggle(page, "caixa 2d", function() return x.esp_box end, function(v)
        x.esp_box = v
    end)
    UI.toggle(page, "nome", function() return x.esp_name end, function(v)
        x.esp_name = v
    end)
    UI.toggle(page, "vida", function() return x.esp_health end, function(v)
        x.esp_health = v
    end)
    UI.toggle(page, "distancia", function() return x.esp_dist end, function(v)
        x.esp_dist = v
    end)
    UI.toggle(page, "esqueleto", function() return x.esp_skel end, function(v)
        x.esp_skel = v
    end)
    UI.toggle(page, "linha ate o alvo", function() return x.esp_tracer end, function(v)
        x.esp_tracer = v
    end)
    UI.toggle(page, "glow 3d", function() return x.esp_glow end, function(v)
        x.esp_glow = v
    end)
    UI.toggle(page, "caixa 3d no mundo", function() return x.esp_box3d end, function(v)
        x.esp_box3d = v
    end)
    UI.toggle(page, "circulo de fov", function() return x.esp_fov end, function(v)
        x.esp_fov = v
    end)
    UI.toggle(page, "marcar time", function() return x.esp_team end, function(v)
        x.esp_team = v
    end)
    UI.slider(page, "cor do esp", 0, 360, 1, function() return x.esp_hue end, function(v)
        x.esp_hue = v
    end)

    UI.header(page, "mira")
    UI.toggle(page, "aimbot", function() return x.aim end, function(v)
        x.aim = v
        if v then Watch.arm("aimbot") end
    end)
    UI.slider(page, "fov da mira", 20, 400, 5, function() return x.aim_fov end, function(v)
        x.aim_fov = v
    end)
    UI.slider(page, "suavidade", 0.05, 1, 0.05, function() return x.aim_smooth end, function(v)
        x.aim_smooth = v
    end)
    UI.cycle(page, "ponto da mira", { "Cabeca", "Torso", "Raiz" },
        function() return x.aim_part end,
        function(v) x.aim_part = v end)
    UI.toggle(page, "ignorar time", function() return x.aim_team end, function(v)
        x.aim_team = v
    end)
    UI.toggle(page, "exigir linha de visao", function() return x.aim_wall end, function(v)
        x.aim_wall = v
    end)
    UI.toggle(page, "grudar no alvo", function() return x.sticky end, function(v)
        x.sticky = v
        if not v then Xitadu.locked = nil end
    end)
    UI.toggle(page, "atirar sozinho", function() return x.aim_auto end, function(v)
        x.aim_auto = v
    end)

    UI.header(page, "silent aim")
    UI.toggle(page, "reescrever tiro", function() return x.silent end, function(v)
        x.silent = v
        if v then
            Xitadu.install_silent()
            if not Xitadu.hooked then
                Toast.show("este executor nao tem hookmetamethod", 3)
            end
        end
    end)
    UI.toggle(page, "bala fantasma (atravessa parede)", function() return x.silent_ghost end, function(v)
        x.silent_ghost = v
        if v then
            Xitadu.install_hook()
            if not Xitadu.hooked then
                Toast.show("este executor nao tem hookmetamethod", 3)
            end
        end
    end)
    UI.input(page, "nomes de remote", "fire,shoot,hit", function(txt)
        x.silent_filter = txt
    end, x.silent_filter)

    UI.header(page, "recoil")
    UI.toggle(page, "sem recuo", function() return x.recoil end, function(v)
        x.recoil = v
    end)

    UI.header(page, "controle")
    UI.button(page, "desligar tudo do xitadu", function()
        for key in pairs(x) do
            if type(x[key]) == "boolean" then x[key] = false end
        end
        Xitadu.stop()
        Xitadu.start()
        UI.refresh_all()
        save_config()
        Toast.show("xitadu zerado", 2)
    end, Color3.fromRGB(44, 34, 34))
end

local function page_movimento(page)
    local m = CFG.mov

    UI.header(page, "movimento")
    UI.toggle(page, "voar", function() return m.fly end, function(v)
        m.fly = v
        Mov.set_pad(v)
        if not v then
            Mov.axis.f, Mov.axis.u = 0, 0
            Mov.release()
        end
    end)
    UI.slider(page, "velocidade do voo", 10, 200, 5, function() return m.fly_speed end, function(v)
        m.fly_speed = v
    end)
    UI.label(page, "com o voo ligado aparece um painel de setas no canto. segura para andar, solta para parar.", THEME.dim, 30)

    UI.toggle(page, "super pulo", function() return m.jump end, function(v)
        m.jump = v
    end)
    UI.slider(page, "forca do pulo", 50, 400, 10, function() return m.jump_power end, function(v)
        m.jump_power = v
    end)

    UI.toggle(page, "super velocidade", function() return m.speed end, function(v)
        m.speed = v
    end)
    UI.slider(page, "velocidade", 20, 200, 2, function() return m.speed_value end, function(v)
        m.speed_value = v
    end)

    UI.toggle(page, "atravessar parede", function() return m.noclip end, function(v)
        m.noclip = v
        if not v then
            local char = LocalPlayer and LocalPlayer.Character
            if char then
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("BasePart") then pcall(function() d.CanCollide = true end) end
                end
            end
        end
    end)

    UI.header(page, "controles de voo")
    UI.button(page, "mostrar painel", function()
        if Mov.pad then
            Mov.pad.Visible = not Mov.pad.Visible
        else
            Toast.show("painel ainda nao montou", 2)
        end
    end, Color3.fromRGB(30, 36, 46))

    UI.label(page, "o servidor ainda simula colisao em alguns jogos. nesses, atravessar parede so funciona em game que confia no cliente.", THEME.dim, 34)
end

local function build_fly_pad()
    if not ui_root or Mov.pad then return end

    local pad = Instance.new("Frame")
    pad.Name = "LunarFlyPad"
    pad.Size = UDim2.fromOffset(116, 156)
    pad.Position = UDim2.new(1, -126, 1, -172)
    pad.BackgroundColor3 = Color3.fromRGB(13, 15, 19)
    pad.BackgroundTransparency = 0.15
    pad.BorderSizePixel = 0
    pad.Visible = false
    pad.Parent = ui_root
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = pad
    Mov.pad = pad

    local function hold(label, order, on, off)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 32)
        btn.Position = UDim2.fromOffset(6, 6 + (order - 1) * 36)
        btn.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Font = Enum.Font.Code
        btn.TextSize = 12
        btn.TextColor3 = Color3.fromRGB(200, 210, 225)
        btn.Text = label
        btn.Parent = pad
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 6)
        cc.Parent = btn

        btn.InputBegan:Connect(function(input)
            local t = input.UserInputType
            if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                btn.BackgroundColor3 = Color3.fromRGB(34, 74, 52)
                on()
            end
        end)
        btn.InputEnded:Connect(function(input)
            local t = input.UserInputType
            if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                btn.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
                off()
            end
        end)
    end

    hold("cima", 1, function() Mov.axis.u = 1 end, function() Mov.axis.u = 0 end)
    hold("frente", 2, function() Mov.axis.f = 1 end, function() Mov.axis.f = 0 end)
    hold("tras", 3, function() Mov.axis.f = -1 end, function() Mov.axis.f = 0 end)
    hold("baixo", 4, function() Mov.axis.u = -1 end, function() Mov.axis.u = 0 end)
end

local function page_config(page)
    UI.header(page, "modo")
    UI.cycle(page, "modo", { "leve", "vivo", "completo", "manual" },
        function() return CFG.mode or "manual" end,
        function(x)
            CFG.mode = x
            apply_mode(x)
        end)

    UI.header(page, "comportamento")
    UI.toggle(page, "vigia de fps", function() return CFG.watchdog end, function(x)
        CFG.watchdog = x
    end)
    UI.toggle(page, "desempenho ativo", function() return CFG.perf.enabled end, function(x)
        CFG.perf.enabled = x; Perf.rebuild()
    end)

    UI.header(page, "controle")
    UI.button(page, "restaurar tudo", function()
        destroy()
        Toast.show("script encerrado", 2)
    end, Color3.fromRGB(60, 36, 36))

    UI.button(page, "salvar agora", function()
        save_config()
        Toast.show("config salva", 2)
    end, Color3.fromRGB(30, 36, 46))

    UI.header(page, "sobre")
    UI.label(page, "lunar.opt " .. VERSION .. "  |  " .. tostring(game.PlaceId), THEME.dim, 20)
    UI.label(page, "tudo aqui e render local. nada que voce ligar altera o servidor ou o que os outros veem, com uma excecao: o modo replicado de skin.", THEME.dim, 42)
    UI.label(page, "o preview 3d e o clima custam frames. ligue um de cada vez e veja o medidor no topo.", THEME.dim, 32)
end

-- modo ----------------------------------------------------------------

local mode_modal = nil

function apply_mode(name)
    CFG.mode = name
    local p, e, o, v = CFG.perf, CFG.env, CFG.overlay, CFG.vis

    if name == "leve" then
        p.enabled = true
        p.shadows, p.post_fx, p.particles, p.lighting = true, true, true, true
        p.quality, p.mesh, p.terrain, p.audio, p.wind, p.cap = true, true, true, true, true, true
        p.textures = false
        e.enabled = false
        CFG.climate.kind = "nenhum"
        o.vig, o.bars, o.tint = false, false, false
        v.aura, v.fov, v.zoom, v.hide_acc, v.scale_on = false, false, false, false, false
    elseif name == "vivo" then
        p.enabled = true
        p.shadows, p.post_fx, p.particles, p.lighting = true, true, true, true
        p.quality, p.mesh, p.terrain, p.audio, p.wind, p.cap = true, true, true, true, true, true
        p.textures = false
        e.enabled = true
        e.clock, e.brightness, e.atmosphere, e.haze = 15, 2.1, 0.35, 1
        e.hue, e.tint, e.contrast, e.saturation = 40, 0.1, 0.08, 0.12
        e.bloom, e.sunrays = 0.5, 0.3
        CFG.climate.kind = "poeira"
        o.vig, o.bars, o.tint = true, false, false
        o.vig_strength = 0.35
        v.aura, v.fov, v.zoom, v.hide_acc, v.scale_on = false, false, false, false, false
    elseif name == "completo" then
        p.enabled = true
        p.textures = false
        e.enabled = true
        o.vig = true
        o.vig_strength = 0.35
        CFG.climate.kind = CFG.climate.kind or "nenhum"
        v.aura, v.fov = true, false
    end

    Perf.rebuild()
    Env.apply()
    Climate.apply()
    Overlay.apply()
    Cam.apply()
    Aura.apply()
    HideAcc.apply()
    Scale.apply()
    Ambience.apply()
    UI.refresh_all()
    save_config()

    if mode_modal then
        mode_modal:Destroy()
        mode_modal = nil
    end
end

local function show_mode_modal()
    local parent = holder_gui()
    if not parent then return end

    local modal = new("Frame", {
        Size = UDim2.fromOffset(260, 250),
        Position = UDim2.new(0.5, -130, 0.5, -125),
        BackgroundColor3 = THEME.bg,
        BorderSizePixel = 0,
        ZIndex = 10,
    }, parent)
    add_corner(modal, 12)
    new("UIStroke", { Color = THEME.line, Thickness = 1 }, modal)
    modal.ZIndex = 10
    mode_modal = modal

    new("TextLabel", {
        Size = UDim2.new(1, -20, 0, 34),
        Position = UDim2.fromOffset(10, 12),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = THEME.text,
        Text = "como voce quer usar?",
        ZIndex = 11,
    }, modal)

    local opts = {
        { "leve", "so desempenho" },
        { "vivo", "otimiza e deixa bonito" },
        { "completo", "tudo ligado" },
        { "manual", "eu escolho" },
    }

    for i, opt in ipairs(opts) do
        local btn = new("TextButton", {
            Size = UDim2.new(1, -20, 0, 40),
            Position = UDim2.fromOffset(10, 46 + (i - 1) * 46),
            BackgroundColor3 = THEME.row,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            Font = Enum.Font.Code,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = THEME.text,
            Text = "  " .. opt[2],
            ZIndex = 11,
        }, modal)
        add_corner(btn, 7)
        btn.MouseButton1Click:Connect(function()
            apply_mode(opt[1])
        end)
    end
end

-- boot ----------------------------------------------------------------

function destroy()
    Perf.running = false
    pcall(Xitadu.stop)
    pcall(Persp.release)
    pcall(Mov.release)
    Skin.release()
    Viewer.close()
    Aura.release()
    if Climate.part then pcall(function() Climate.part:Destroy() end) end
    if Overlay.gui then pcall(function() Overlay.gui:Destroy() end) end
    if Ambience.sound then pcall(function() Ambience.sound:Destroy() end) end
    if mode_modal then pcall(function() mode_modal:Destroy() end) end
    for _, c in ipairs(UI.conns) do pcall(function() c:Disconnect() end) end
    UI.conns = {}
    for _, c in ipairs(BOOT_CONNS) do pcall(function() c:Disconnect() end) end
    BOOT_CONNS = {}
    if ui_root then pcall(function() ui_root:Destroy() end) end
    ui_root = nil
    genv.LunarOpt = nil
end

genv.LunarOpt = {
    destroy = destroy,
    config = CFG,
    rebuild = Perf.rebuild,
    skin = Skin,
    env = Env,
    xitadu = Xitadu,
    persp = Persp,
    mov = Mov,
}

local function guard(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        print("[lunar.opt] falhou em " .. label .. ": " .. tostring(err))
    end
    return ok
end

guard("config", load_config)

local built = false
guard("janela", function() built = build_window() end)

if built then
    guard("abas", build_tabs)
    guard("aba desempenho", function() page_desempenho(tab_pages["desempenho"]) end)
    guard("aba ambiente", function() page_ambiente(tab_pages["ambiente"]) end)
    guard("aba visual", function() page_visual(tab_pages["visual"]) end)
    guard("aba xitadu", function() page_xitadu(tab_pages["xitadu"]) end)
    guard("aba movimento", function() page_movimento(tab_pages["movimento"]) end)
    guard("painel de voo", build_fly_pad)
    guard("aba config", function() page_config(tab_pages["config"]) end)
    guard("xitadu", Xitadu.start)

    local start = CFG.tab
    if not tab_pages[start] then start = "desempenho" end
    guard("selecionar aba", select_tab, start)

    guard("desempenho", Perf.rebuild)
    guard("ambiente", Env.apply)
    guard("clima", Climate.apply)
    guard("overlay", Overlay.apply)
    guard("som", Ambience.apply)
    guard("perspectiva", Persp.apply)
    guard("movimento", Mov.start)

    if LocalPlayer then
        LocalPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            Aura.apply()
            HideAcc.apply()
            Scale.apply()
            Cam.apply()
            Persp.apply()
            refresh_players()
        end)
    end

    if CFG.mode == nil then
        guard("seletor de modo", show_mode_modal)
    else
        Toast.show("lunar.opt " .. VERSION .. " pronto  |  " .. string.upper(CFG.mode), 3)
    end
else
    print("[lunar.opt] interface nao montou — rodando so os modulos")
    guard("desempenho", Perf.rebuild)
    guard("ambiente", Env.apply)
    guard("clima", Climate.apply)
    guard("overlay", Overlay.apply)
    guard("xitadu", Xitadu.start)
end

print(string.format("[lunar.opt] %s carregado — modo=%s — ui=%s",
    VERSION, tostring(CFG.mode), tostring(built)))
