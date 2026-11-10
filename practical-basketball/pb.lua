local CONFIG = {
    Name = "Practical Basketball",
    Id = "practical-basketball",
    Folder = "oklo scripts/practicalbasketball",
    ScriptUrl = "https://raw.githubusercontent.com/okdude42/main-scripts/main/practical-basketball/pb-core.lua",
    UiUrl = "https://raw.githubusercontent.com/okdude42/main-scripts/main/oklo-uilib/OkloUI.luau",
    Discord = "https://discord.gg/oklo",
    Registry = "__PracticalBasketballStop",
    Width = 700,
    Height = 470,
    GameName = "Practical Basketball",
    HomePlace = 80681221431821,
    Places = "78438427735992,79672855812610,80681221431821,85576197307056,104645279125178,106120159518740,113883239895081,115491614485922,115776365257536,118669925076970,119587547774646,133311125103681,137269396533485,137939444694121,138505112166361",
    GameId = 7529591378,
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
