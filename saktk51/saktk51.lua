local CONFIG = {
    Name = "SAKTK51",
    Id = "saktk51",
    Folder = "oklo scripts/saktk51",
    ScriptUrl = "https://raw.githubusercontent.com/okdude42/main-scripts/main/saktk51/saktk51-core.lua",
    UiUrl = "https://raw.githubusercontent.com/okdude42/main-scripts/main/oklo-uilib/OkloUI.luau",
    Discord = "https://discord.gg/oklo",
    Registry = "__Area51SuiteStop",
    Width = 720,
    Height = 470,
    GameName = "SAKTK51",
    HomePlace = 155382109,
    Places = "155382109,1076129670,2092166489,2092167559,2675280735,3182083477,3508248007,4631179692,4678052190,5740483929,6054929905,10886353373,11798285011",
    GameId = 73754455,
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
