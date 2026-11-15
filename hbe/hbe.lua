local CONFIG = {
    Name = "Hitbox Expander",
    Id = "hitbox-expander",
    Folder = "oklo scripts/hitboxexpander",
    ScriptUrl = "https://raw.githubusercontent.com/okdude42/main-scripts/main/hbe/hbe-core.lua",
    UiUrl = "https://raw.githubusercontent.com/okdude42/main-scripts/main/oklo-uilib/OkloUI.luau",
    Discord = "https://discord.gg/oklo",
    Registry = "__HitboxExpanderStop",
    Width = 700,
    Height = 460,
}

local URL = "https://raw.githubusercontent.com/okdude42/main-scripts/main/loader/loader.lua"

local function fetch(url)
    local ok, response = pcall(request, { Url = url, Method = "GET" })
    if ok and type(response) == "table" and type(response.Body) == "string" and response.Body ~= "" and (tonumber(response.StatusCode) or 200) < 400 then
        return response.Body
    end
    local got, body = pcall(game.HttpGet, game, url)
    return if got and type(body) == "string" and body ~= "" then body else nil
end

local source = fetch(URL)
local chunk = source and loadstring(source, "loader")
if not chunk then
    warn(CONFIG.Name .. " loader: could not download the loader from github, you may be ratelimited, try again later or use a VPN")
    return
end
return chunk(CONFIG)
