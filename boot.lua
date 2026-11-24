-- lunar boot | sempre baixa a versao mais nova, sem cache
local base = "https://raw.githubusercontent.com/whesleydev/lunar-opt/main/"
local stamp = tostring(math.floor(os.time())) .. tostring(math.random(1000, 9999))
local url = base .. "slim.lua?nocache=" .. stamp

local ok, src = pcall(function() return game:HttpGet(url, true) end)
if not ok or type(src) ~= "string" or #src < 1000 then
    ok, src = pcall(function() return game:HttpGet(url) end)
end
if (not ok or type(src) ~= "string" or #src < 1000) then
    ok, src = pcall(function() return game:HttpGet(base .. "slim.lua?fallback=" .. stamp) end)
end
if not ok or type(src) ~= "string" or #src < 1000 then
    warn("[lunar] nao consegui baixar o script: " .. tostring(src))
    return
end

print("[lunar] baixados " .. #src .. " bytes")

local chunk, err = loadstring(src)
if not chunk then
    warn("[lunar] erro de sintaxe: " .. tostring(err))
    return
end
chunk()
