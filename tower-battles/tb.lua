local CONFIG = {
    Name = "Tower Battles",
    Id = "tower-battles",
    Folder = "oklo scripts/towerbattles",
    ScriptUrl = "https://raw.githubusercontent.com/okdude42/main-scripts/main/tower-battles/tb-core.lua",
    UiUrl = "https://raw.githubusercontent.com/okdude42/main-scripts/main/oklo-uilib/OkloUI.luau",
    Discord = "https://discord.gg/oklo",
    Registry = "__TowerBattlesStop",
    Width = 640,
    Height = 420,
    GameName = "Tower Battles",
    HomePlace = 45146873,
    Places = "45146873,46955756,49707852,2470348319,2776257214,1241893197,45200529,5645832762,8652280014",
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
