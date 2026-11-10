local modules = {}
local loaded = {}
local function import(name)
    local cached = loaded[name]
    if cached ~= nil then
        return cached
    end
    local build = modules[name]
    if not build then
        error("module is missing: " .. tostring(name))
    end
    local value = build(import)
    loaded[name] = value
    return value
end
modules["changelog"] = function(...)

local Changelog = {}

Changelog.VERSION = "1"
Changelog.DATE = "November 9, 2026"

type Group = { Mode: string, Added: { string }?, Changed: { string }?, Removed: { string }?, Fixed: { string }? }

Changelog.GROUPS = {
    {
        Mode = "General",
        Added = {
            "First release",
        },
    },
} :: { Group }

Changelog.HISTORY = {} :: { { Version: string, Date: string, Lines: { string }?, Groups: { Group }? } }

Changelog.CLOSING = "please join the discord server c:"

Changelog.OPEN = "General"

return Changelog
end
modules["defaults"] = function(...)

return [==[
{
    "Schema": 1,
    "Updated": "2026-11-09",
    "Scripts": [
        {
            "Id": "tower-battles",
            "Name": "Tower Battles",
            "Category": "Games",
            "Description": "Auto Vote Map, Macros, Auto Upgrade and more for Tower Battles",
            "Registry": "__TowerBattlesStop",
            "HomePlace": 45146873,
            "Places": [
                45146873,
                46955756,
                49707852,
                2470348319,
                2776257214,
                1241893197,
                45200529,
                5645832762,
                8652280014
            ],
            "Status": "live",
            "Config": {
                "Id": "tower-battles",
                "Name": "Tower Battles",
                "Folder": "oklo scripts/towerbattles",
                "ScriptUrl": "https://raw.githubusercontent.com/okdude42/main-scripts/main/tower-battles/tb-core.lua",
                "Registry": "__TowerBattlesStop",
                "Width": 640,
                "Height": 420,
                "GameName": "Tower Battles",
                "HomePlace": 45146873,
                "Places": "45146873,46955756,49707852,2470348319,2776257214,1241893197,45200529,5645832762,8652280014"
            },
            "Info": {
                "Tagline": "Keyless, Auto Vote Map, Macros, Auto Upgrade and more",
                "Groups": [
                    {
                        "Title": "Lobby",
                        "Items": [
                            "Auto Queue",
                            "Queue Again"
                        ]
                    },
                    {
                        "Title": "Match",
                        "Items": [
                            "Auto Vote Map with veto and fallback",
                            "Auto Ready",
                            "Place Best Spot",
                            "Upgrade All and Sell All",
                            "Auto Upgrade with Delay",
                            "Sell Everything At Wave"
                        ]
                    },
                    {
                        "Title": "Macros",
                        "Items": [
                            "Record",
                            "save and play back with a speed slider",
                            "Auto Play Macro"
                        ]
                    },
                    {
                        "Title": "Versus",
                        "Items": [
                            "Auto Send"
                        ]
                    },
                    {
                        "Title": "Player",
                        "Items": [
                            "Unlimited Zoom",
                            "Fullbright"
                        ]
                    }
                ]
            }
        },
        {
            "Id": "classic-tower-battles",
            "Name": "Classic Tower Battles",
            "Category": "Games",
            "Description": "Autofarm, Macros, Auto Place and more for Classic Tower Battles",
            "Registry": "__ClassicTowerBattlesStop",
            "HomePlace": 14289388505,
            "Places": [
                14289388505,
                14289717382
            ],
            "Status": "live",
            "Config": {
                "Id": "classic-tower-battles",
                "Name": "Classic Tower Battles",
                "Folder": "oklo scripts/classictowerbattles",
                "ScriptUrl": "https://raw.githubusercontent.com/okdude42/main-scripts/main/classic-tb/ctb-core.lua",
                "Registry": "__ClassicTowerBattlesStop",
                "Width": 700,
                "Height": 460,
                "GameName": "Classic Tower Battles",
                "HomePlace": 14289388505,
                "Places": "14289388505,14289717382"
            },
            "Info": {
                "Tagline": "Keyless, Autofarm, Macros, Auto Place and more",
                "Groups": [
                    {
                        "Title": "Autofarm",
                        "Items": [
                            "Auto Queue",
                            "vote and start",
                            "Auto Place your build on the best spots",
                            "Auto Upgrade",
                            "Auto Rejoin after teleport"
                        ]
                    },
                    {
                        "Title": "Macros",
                        "Items": [
                            "Record and play back per wave"
                        ]
                    },
                    {
                        "Title": "Tools",
                        "Items": [
                            "Place Tower Anywhere",
                            "Tower Manager",
                            "Abilities and Target Cycling",
                            "Versus Auto Send",
                            "Auto Redeem Codes",
                            "Tower Equip",
                            "Anti AFK"
                        ]
                    },
                    {
                        "Title": "Visuals",
                        "Items": [
                            "Range Circles",
                            "Tower Labels",
                            "Enemy Health",
                            "Path Line",
                            "HUD"
                        ]
                    }
                ]
            }
        },
        {
            "Id": "practical-basketball",
            "Name": "Practical Basketball",
            "Category": "Games",
            "Description": "Auto Green, Auto Dunk, Auto Guard and more for Practical Basketball",
            "Registry": "__PracticalBasketballStop",
            "HomePlace": 80681221431821,
            "GameId": 7529591378,
            "Places": [
                78438427735992,
                79672855812610,
                80681221431821,
                85576197307056,
                104645279125178,
                106120159518740,
                113883239895081,
                115491614485922,
                115776365257536,
                118669925076970,
                119587547774646,
                133311125103681,
                137269396533485,
                137939444694121,
                138505112166361
            ],
            "Status": "live",
            "Config": {
                "Id": "practical-basketball",
                "Name": "Practical Basketball",
                "Folder": "oklo scripts/practicalbasketball",
                "ScriptUrl": "https://raw.githubusercontent.com/okdude42/main-scripts/main/practical-basketball/pb-core.lua",
                "Registry": "__PracticalBasketballStop",
                "Width": 560,
                "Height": 420,
                "GameName": "Practical Basketball",
                "HomePlace": 80681221431821,
                "Places": "78438427735992,79672855812610,80681221431821,85576197307056,104645279125178,106120159518740,113883239895081,115491614485922,115776365257536,118669925076970,119587547774646,133311125103681,137269396533485,137939444694121,138505112166361",
                "GameId": 7529591378
            },
            "Info": {
                "Tagline": "Keyless, Auto Green, Auto Dunk, Auto Guard and more",
                "Groups": [
                    {
                        "Title": "Offense",
                        "Items": [
                            "Auto Green with dunk support",
                            "Auto Shoot",
                            "Auto Dunk with Auto Move and Dunk Type",
                            "Auto Pass To Teammates",
                            "Auto Dribble when Guarded",
                            "Dribble Combo",
                            "Shot Glide"
                        ]
                    },
                    {
                        "Title": "Defense",
                        "Items": [
                            "Auto Steal",
                            "Auto Guard with Move Towards",
                            "Auto Block",
                            "Auto Rebound",
                            "Ball Magnet"
                        ]
                    },
                    {
                        "Title": "Player",
                        "Items": [
                            "Always Full Speed",
                            "Always Sprint",
                            "Custom Walkspeed",
                            "No Stun",
                            "No Debounce",
                            "No Cold Zone"
                        ]
                    },
                    {
                        "Title": "Visuals",
                        "Items": [
                            "Visuals for features",
                            "players and court parts"
                        ]
                    }
                ]
            }
        },
        {
            "Id": "booga-utilities",
            "Name": "Booga Utilities",
            "Category": "Games",
            "Description": "Gold Farm, Auto Plant, Auto Harvest and more for Booga Booga",
            "Registry": "__BoogaUtilitiesStop",
            "HomePlace": 11729688377,
            "Places": [
                11729688377,
                11879754496
            ],
            "Status": "live",
            "Config": {
                "Id": "booga-utilities",
                "Name": "Booga Utilities",
                "Folder": "oklo scripts/boogautilities",
                "ScriptUrl": "https://raw.githubusercontent.com/okdude42/main-scripts/main/boogautilities/boogautils-core.lua",
                "Registry": "__BoogaUtilitiesStop",
                "Width": 740,
                "Height": 450,
                "GameName": "Booga Booga",
                "HomePlace": 11729688377,
                "Places": "11729688377,11879754496"
            },
            "Info": {
                "Tagline": "Keyless, Gold Farm, Auto Plant, Auto Harvest and more",
                "Groups": [
                    {
                        "Title": "Gold Farm",
                        "Items": [
                            "Start Path with Show Path",
                            "Mine By Detection",
                            "Gold Hit Aura",
                            "Coin Press",
                            "Move Gold To Chest",
                            "Path Editor",
                            "Halloween Gold"
                        ]
                    },
                    {
                        "Title": "Plant Farm",
                        "Items": [
                            "Auto Plant",
                            "Auto Harvest",
                            "Tween To Plant Box and Bush",
                            "Custom Move Speed"
                        ]
                    },
                    {
                        "Title": "Materials",
                        "Items": [
                            "Farm Sunfruit",
                            "Drop Materials"
                        ]
                    },
                    {
                        "Title": "Utility",
                        "Items": [
                            "Auto Open Chest",
                            "Anti Stuck",
                            "CPU Mode",
                            "Lock Camera",
                            "Auto Start Path",
                            "Discord Webhook report"
                        ]
                    }
                ]
            }
        },
        {
            "Id": "saktk51",
            "Name": "SAKTK51",
            "Category": "Games",
            "Description": "Get Guns, Kill All, Killer Picker and more for Area 51",
            "Registry": "__Area51SuiteStop",
            "HomePlace": 155382109,
            "GameId": 73754455,
            "Places": [
                155382109,
                1076129670,
                2092166489,
                2092167559,
                2675280735,
                3182083477,
                3508248007,
                4631179692,
                4678052190,
                5740483929,
                6054929905,
                10886353373,
                11798285011
            ],
            "Status": "live",
            "Config": {
                "Id": "saktk51",
                "Name": "SAKTK51",
                "Folder": "oklo scripts/saktk51",
                "ScriptUrl": "https://raw.githubusercontent.com/okdude42/main-scripts/main/saktk51/saktk51-core.lua",
                "Registry": "__Area51SuiteStop",
                "Width": 720,
                "Height": 470,
                "GameName": "SAKTK51",
                "HomePlace": 155382109,
                "Places": "155382109,1076129670,2092166489,2092167559,2675280735,3182083477,3508248007,4631179692,4678052190,5740483929,6054929905,10886353373,11798285011",
                "GameId": 73754455
            },
            "Info": {
                "Tagline": "Keyless, Get Guns, Kill All, Killer Picker and more",
                "Groups": [
                    {
                        "Title": "Combat",
                        "Items": [
                            "Get Guns for each gamemode",
                            "Killer Hitbox",
                            "Killer Reroll with Killer Picker",
                            "Kill All",
                            "Kill Specified"
                        ]
                    },
                    {
                        "Title": "Gamemodes",
                        "Items": [
                            "Endless",
                            "Classic",
                            "Juggernaut"
                        ]
                    },
                    {
                        "Title": "Visuals",
                        "Items": [
                            "ESP for entities",
                            "World and Camera settings"
                        ]
                    },
                    {
                        "Title": "Player",
                        "Items": [
                            "Movement options",
                            "Protections"
                        ]
                    }
                ]
            }
        },
        {
            "Id": "hitbox-expander",
            "Name": "Hitbox Expander",
            "Category": "Universal",
            "Description": "Bigger Hitboxes for players and NPCs, works in any game",
            "Registry": "__HitboxExpanderStop",
            "Universal": true,
            "Places": [],
            "Status": "live",
            "Config": {
                "Id": "hitbox-expander",
                "Name": "Hitbox Expander",
                "Folder": "oklo scripts/hitboxexpander",
                "ScriptUrl": "https://raw.githubusercontent.com/okdude42/main-scripts/main/hbe/hbe-core.lua",
                "Registry": "__HitboxExpanderStop",
                "Width": 700,
                "Height": 460
            },
            "Info": {
                "Tagline": "Keyless, Universal, Hitbox Expander, Filters and more",
                "Groups": [
                    {
                        "Title": "Hitbox",
                        "Items": [
                            "Bigger hitboxes for players and NPCs",
                            "Part Picker"
                        ]
                    },
                    {
                        "Title": "Filters",
                        "Items": [
                            "Team",
                            "Friends",
                            "Blacklist keywords",
                            "Detected models"
                        ]
                    },
                    {
                        "Title": "Visuals",
                        "Items": [
                            "Hitbox Visualizer",
                            "Dex Style Explorer popup"
                        ]
                    }
                ]
            }
        },
        {
            "Id": "player-utilities",
            "Name": "Player Utilities",
            "Category": "Universal",
            "Description": "Player tracker, maybe remade from scratch later.",
            "Loader": "https://raw.githubusercontent.com/okdude42/main-scripts/main/playerutils/playerutils.lua",
            "Registry": "__BoogaPlayerTrackerStop",
            "Universal": true,
            "Places": [],
            "Status": "hidden",
            "Config": {}
        }
    ],
    "LoaderUrl": "https://raw.githubusercontent.com/okdude42/main-scripts/main/loader/loader.lua"
}
]==] :: string
end
modules["icons"] = function(...)

local import: (string) -> any = ...
local Registry: typeof(require("./registry")) = import("registry")

local Icons = {}

local THUMBNAILS = "https://thumbnails.roblox.com/v1/places/gameicons?returnPolicy=PlaceHolder&size=256x256&format=Png&isCircular=false&placeIds="

local assets: { [string]: string } = {}
local folder = ""

local function isImage(body: string): boolean
    return string.sub(body, 1, 4) == "\137PNG" or string.sub(body, 1, 3) == "\255\216\255"
end

local function asset(path: string): string?
    local ok, value = pcall(getcustomasset, path)
    return if ok and type(value) == "string" and value ~= "" then value else nil
end

local function cached(entry: Registry.Entry): string?
    local path = folder .. "/" .. entry.Id .. ".png"
    if isfile(path) then
        return asset(path)
    end
    return nil
end

local function save(entry: Registry.Entry, url: string)
    local body = Registry.fetch(url)
    if not body or not isImage(body) then
        return
    end
    local path = folder .. "/" .. entry.Id .. ".png"
    if pcall(writefile, path, body) then
        assets[entry.Id] = asset(path) or assets[entry.Id]
    end
end

function Icons.start(entries: { Registry.Entry }, icons: string)
    folder = icons
    pcall(function()
        if not isfolder(folder) then
            makefolder(folder)
        end
    end)
    local missing: { Registry.Entry } = {}
    for _, entry in entries do
        local found = cached(entry)
        if found then
            assets[entry.Id] = found
        elseif entry.HomePlace then
            table.insert(missing, entry)
        end
    end
    if #missing == 0 then
        return
    end
    task.spawn(function()
        local places: { string } = {}
        for _, entry in missing do
            table.insert(places, tostring(entry.HomePlace))
        end
        local body = Registry.fetch(THUMBNAILS .. table.concat(places, ","))
        local ok, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(body or "")
        end)
        if not ok or type(data) ~= "table" or type(data.data) ~= "table" then
            return
        end
        for _, row in data.data do
            for _, entry in missing do
                if type(row) == "table" and row.targetId == entry.HomePlace and type(row.imageUrl) == "string" then
                    save(entry, row.imageUrl)
                end
            end
        end
    end)
end

function Icons.get(entry: Registry.Entry): string?
    return assets[entry.Id]
end

return Icons
end
modules["launcher"] = function(...)

local import: (string) -> any = ...
local Registry: typeof(require("./registry")) = import("registry")

local Launcher = {}

local STARTING_SECONDS = 20
local starting: { [string]: number } = {}

function Launcher.starting(entry: Registry.Entry): boolean
    local since = starting[entry.Id]
    if since and (os.clock() - since > STARTING_SECONDS or Registry.running(entry)) then
        starting[entry.Id] = nil
        return false
    end
    return since ~= nil
end

function Launcher.run(entry: Registry.Entry, base: { [string]: any }?, ui: any?, announce: (string) -> ())
    if Launcher.starting(entry) then
        return
    end
    if not Registry.safe(entry) then
        announce("Link check failed")
        return
    end
    starting[entry.Id] = os.clock()
    task.spawn(function()
        local body = Registry.fetch(Registry.LoaderUrl)
        local chunk = if body then loadstring(body, "oklo loader") else nil
        if not chunk then
            starting[entry.Id] = nil
            announce("Could not download the loader, try again in a minute")
            return
        end
        local config: { [string]: any } = {}
        for key, value in base or {} do
            config[key] = value
        end
        config.Hub = nil
        pcall(function()
            local window = ui.Window
            local scale = window.State.UIScale or 1
            config.FromWidth, config.FromHeight = window.M.Width * scale, window.M.Height * scale
            local at = window.MenuPos
            if at then
                config.FromX, config.FromY = at.X + config.FromWidth / 2, at.Y + config.FromHeight / 2
            end
            local pos, size = window.WindowPos, window.WindowSize
            if pos and size and size.X > 0 then
                config.FromWidth, config.FromHeight = size.X, size.Y
                config.FromX, config.FromY = pos.X + size.X / 2, pos.Y + size.Y / 2
            end
            config.FromRadius = math.max(12, math.round(36 * (window.Scale or scale))) * math.clamp(tonumber(window.State.Roundness) or 0.46, 0, 0.6)
            config.FromMain = window.Pal.Main
        end)
        config.RegistryUrl = nil
        for key, value in entry.Config do
            config[key] = value
        end
        local failed = false
        getgenv().__OkloCardUp = nil
        task.spawn(function()
            if not pcall(chunk, config) then
                failed = true
                starting[entry.Id] = nil
                announce("Could not start " .. entry.Name)
            end
        end)
        local waited = os.clock()
        while getgenv().__OkloCardUp ~= true and not failed and os.clock() - waited < 4 do
            task.wait()
        end
        if ui and not failed then
            pcall(function()
                ui:destroy()
            end)
        end
        getgenv().__OkloCardUp = nil
    end)
end

return Launcher
end
modules["main"] = function(...)

local import: (string) -> any = ...
local Changelog: typeof(require("./changelog")) = import("changelog")
local Icons: typeof(require("./icons")) = import("icons")
local Launcher: typeof(require("./launcher")) = import("launcher")
local Registry: typeof(require("./registry")) = import("registry")

local REGISTRY = "__ScriptHubStop"
local FOLDER = "oklo scripts/scripthub"
local ROW, OPEN, SMALL, LARGE, GAP = 54, 108, 40, 76, 6

local INVITE = "https://discord.gg/oklo"

local function joinDiscord()
    pcall(function()
        setclipboard(INVITE)
    end)
    task.spawn(function()
        local http = game:GetService("HttpService")
        local body = http:JSONEncode({ cmd = "INVITE_BROWSER", args = { code = "oklo" }, nonce = http:GenerateGUID(false) })
        for port = 6463, 6472 do
            local ok, response = pcall(function()
                return request({
                    Url = "http://127.0.0.1:" .. tostring(port) .. "/rpc?v=1",
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json", ["Origin"] = "https://discord.com" },
                    Body = body,
                })
            end)
            if ok and type(response) == "table" and tonumber(response.StatusCode) == 200 then
                return
            end
        end
    end)
end

local function stopPrevious()
    local previous = getgenv()[REGISTRY]
    if type(previous) == "function" then
        pcall(previous)
    end
end

local function cut(kit: any, text: string, size: number, width: number): string
    if kit:measure(text, size) <= width then
        return text
    end
    while #text > 1 and kit:measure(text .. "..", size) > width do
        text = string.sub(text, 1, #text - 1)
    end
    return text .. ".."
end

local function build(OkloUI: any, reload: () -> (), entries: { Registry.Entry }, live: boolean, base: { [string]: any }?): { [string]: any }
    local ui: any
    local running = true
    local selected: string? = nil

    local function stop()
        if not running then
            return
        end
        running = false
        getgenv()[REGISTRY] = nil
    end

    local listWidth = 400

    local detected: Registry.Entry? = nil
    for _, entry in entries do
        if Registry.matches(entry) then
            detected = entry
            break
        end
    end

    ui = OkloUI.new({
        Title = "Script Hub",
        Subtitle = "all scripts",
        Version = Changelog.VERSION,
        Changelog = Changelog,
        Id = "Script Hub",
        Folder = FOLDER,
        Logo = { Emblem = true },
        Footer = "oklo",
        Discord = "https://discord.gg/oklo",
        FirstRunInvite = true,
        Thanks = true,
        Width = 700,
        Height = 460,
        Theme = "Default",
        NoSettings = true,
        NoSidebar = true,
        TopNav = true,
        HeaderLogo = true,
        Status = function(): string?
            if detected then
                return detected.Name .. " detected"
            end
            return if live then nil else "Offline, showing the saved list"
        end,
        OnUnload = stop,
        OnReload = reload,
    })
    Icons.start(entries, FOLDER .. "/icons")

    local function announce(text: string)
        pcall(function()
            ui.Window:announce(text)
        end)
    end

    local function find(id: string?): Registry.Entry?
        for _, entry in entries do
            if entry.Id == id then
                return entry
            end
        end
        return nil
    end

    local function icon(kit: any, window: any, entry: Registry.Entry, x: number, y: number, size: number, alpha: number)
        local pal = window.Pal
        local asset = Icons.get(entry)
        if asset then
            kit:image(asset, x, y, size, size, size * 0.22, alpha)
        else
            kit:solid(x, y, size, size, pal.Panel, size * 0.22, alpha)
            if window.LogoAsset then
                kit:image(window.LogoAsset, x + size * 0.07, y + size * 0.07, size * 0.86, size * 0.86, 0, alpha, pal.Accent)
            else
                kit:text(string.upper(string.sub(entry.Name, 1, 1)), x + size / 2, y + size / 2, size * 0.45, pal.Sub, true, true)
            end
        end
    end

    local function wrap(kit: any, text: string, size: number, width: number): { string }
        local lines: { string } = {}
        local current = ""
        for word in string.gmatch(text, "%S+") do
            local try = if current == "" then word else current .. " " .. word
            if kit:measure(try, size) > width and current ~= "" then
                table.insert(lines, current)
                current = word
            else
                current = try
            end
        end
        if current ~= "" then
            table.insert(lines, current)
        end
        if #lines > 2 then
            lines = { lines[1], cut(kit, table.concat(lines, " ", 2), size, width) }
        end
        return lines
    end

    local function line(kit: any, window: any, id: string, entry: Registry.Entry, y: number, open: number): number
        local pal = window.Pal
        local key = id .. ":" .. entry.Id
        local width = listWidth
        local hover = kit:ease(key .. ":hover", if kit:hovered(key) then 1 else 0, 16)
        local height = ROW + (OPEN - ROW) * open
        local body = height - GAP
        y += 3
        local t = math.clamp((open - 0.4) / 0.6, 0, 1)
        local shown = t * t * (3 - 2 * t)
        local size = SMALL + (LARGE - SMALL) * open
        local textX = 12 + size + 14
        local dot: Color3? = nil
        if Registry.running(entry) then
            dot = Color3.fromRGB(255, 255, 255)
        elseif Registry.matches(entry) then
            dot = Color3.fromRGB(255, 255, 255)
        end
        kit:hit(key, 2, y, width - 4, body, function()
            selected = if selected == entry.Id then nil else entry.Id
        end)
        kit:nest("hub:" .. key, function()
            kit:solid(2, y, width - 4, body, pal.Off, 10, math.clamp(0.3 + hover * 0.2 + open * 0.25, 0, 1))
            kit:border(2, y, width - 4, body, 10, pal.Accent, open * 0.6, 1.5)
            icon(kit, window, entry, 12, y + 4 + 9 * open, size, 1)
            kit:text(cut(kit, entry.Name, 13, width - textX - 90), textX, y + 17 + 5 * open, 13, pal.Text, false, true)
            kit:text(if entry.HomePlace then "ID " .. tostring(entry.HomePlace) else "Universal", textX, y + 33 + 7 * open, 10, pal.Sub, false, true)
            local steady = kit.Alpha
            local running = Registry.running(entry)
            local word = if running then "Running" elseif dot then "This game" else " "
            local tagWidth = kit:measure(word, 10) + 16
            local tagX, tagY = width - 16 - tagWidth, y + 9
            kit.Alpha = steady * (if dot then 0.2 else 0)
            kit:solid(tagX, tagY, tagWidth, 20, dot or pal.Off, 10, 1)
            kit.Alpha = steady * (if dot then 1 else 0)
            kit:text(word, tagX + tagWidth / 2, tagY + 10, 10, dot or pal.Sub, true, true)
            kit.Alpha = steady
            local lines = wrap(kit, entry.Description, 11, width - (12 + LARGE + 14) - 150)
            for index, text in lines do
                local at = y + 62 + (index - 1) * 16
                kit.Alpha = steady * shown * math.clamp((y + body - 8 - at) / 12, 0, 1)
                kit:text(text, textX, at, 11, pal.Sub, false, true)
            end
            kit.Alpha = steady
            if shown > 0.01 then
                kit.Alpha = steady * shown
                local starting = Launcher.starting(entry)
                local label = if starting then "Starting..." elseif running then "Reload" else "Execute"
                local options: any = { label = label, align = "center", size = 12, disabled = starting, rounding = 16 }
                local edge = if running or starting then 0.18 else 0.55
                if running or starting then
                    options.base, options.textColor, options.hoverColor, options.hoverText = pal.Off, pal.Sub, pal.Panel, pal.Text
                else
                    options.base, options.textColor, options.hoverColor, options.hoverText = pal.Panel:Lerp(pal.Accent, 0.1), pal.Text, pal.Accent:Lerp(pal.Panel, 0.2), Color3.fromRGB(16, 16, 20)
                end
                kit:border(width - 136, y + body - 42, 120, 32, 16, pal.Accent, steady * shown * edge, 1.2)
                kit:button(key .. ":run", width - 136, y + body - 42, 120, 32, function()
                    Launcher.run(entry, base, ui, announce)
                end, options)
                kit.Alpha = steady
            end
        end)
        return height
    end

    local function holds(entry: Registry.Entry, query: string): boolean
        for _, text in { entry.Name, entry.Description, entry.Category, tostring(entry.HomePlace or "") } do
            if string.find(string.lower(text), query, 1, true) then
                return true
            end
        end
        return false
    end

    local function pick(filter: (Registry.Entry) -> boolean): { Registry.Entry }
        local list: { Registry.Entry } = {}
        for _, entry in entries do
            if filter(entry) then
                table.insert(list, entry)
            end
        end
        return list
    end

    local function flow(kit: any, text: string, size: number, width: number): { string }
        local lines: { string } = {}
        local current = ""
        for word in string.gmatch(text, "%S+") do
            local try = if current == "" then word else current .. " " .. word
            if kit:measure(try, size) > width and current ~= "" then
                table.insert(lines, current)
                current = word
            else
                current = try
            end
        end
        if current ~= "" then
            table.insert(lines, current)
        end
        return lines
    end

    local function panel(kit: any, window: any, x: number, y: number, width: number, height: number)
        local pal = window.Pal
        local pad = 12
        local inner = width - pad * 2
        local entry = find(selected) or detected
        kit:solid(x, y, width, height, pal.Off, 12, 0.35)
        kit:border(x, y, width, height, 12, pal.Off, 0.6, 1)
        local logo = 36
        local logoX, logoY = x + pad, y + pad
        if entry then
            icon(kit, window, entry, logoX, logoY, logo, 1)
        elseif window.LogoAsset then
            kit:image(window.LogoAsset, logoX, logoY, logo, logo, 0, 1, pal.Accent)
        end
        local textX = logoX + logo + 10
        local textWidth = x + width - pad - textX
        local info = if entry then entry.Info else nil
        local title = if entry then entry.Name else "Script Hub"
        local short = if entry then (if entry.HomePlace then "ID " .. tostring(entry.HomePlace) else "Universal") else "Pick a script"
        local titleSize = if kit:measure(title, 13) > textWidth then 11.5 else 13
        kit:text(cut(kit, title, titleSize, textWidth), textX, logoY + 11, titleSize, pal.Text, false, true)
        kit:text(cut(kit, short, 10, textWidth), textX, logoY + 27, 10, pal.Sub, false, true)
        local footer = y + height - 30
        kit:solid(x + pad, footer, inner, 1, pal.Off, 0, 0.9)
        kit:text("oklo", x + pad, footer + 15, 12, pal.Text, false, true)
        local inviteHover = kit:ease("hub:invite:hover", if kit:hovered("hub:invite") then 1 else 0, 14)
        local inviteWidth = kit:measure("discord.gg/oklo", 11)
        kit:hit("hub:invite", x + width - pad - inviteWidth - 4, footer + 5, inviteWidth + 8, 20, function()
            joinDiscord()
            announce("Invite copied")
        end)
        kit:text("discord.gg/oklo", x + width - pad - inviteWidth, footer + 15, 11, pal.Sub:Lerp(pal.Accent, 0.4 + inviteHover * 0.6), false, true)
        local top = logoY + logo + 10
        kit:solid(x + pad, top, inner, 1, pal.Off, 0, 0.9)
        local lines: { { Text: string, Size: number, Color: Color3, Gap: number, Bold: boolean? } } = {}
        if entry then
            for _, text in flow(kit, if info and info.Tagline then info.Tagline else entry.Description, 10, inner) do
                table.insert(lines, { Text = text, Size = 10, Color = pal.Sub, Gap = 14 })
            end
            for _, group in (if info and info.Groups then info.Groups else {}) do
                table.insert(lines, { Text = string.upper(group.Title), Size = 9, Color = pal.Accent, Gap = 20, Bold = true })
                for _, text in flow(kit, table.concat(group.Items, ", "), 10, inner) do
                    table.insert(lines, { Text = text, Size = 10, Color = pal.Text, Gap = 13 })
                end
            end
        else
            for _, text in flow(kit, "Pick a script on the left to see what it does, then press Execute.", 10, inner) do
                table.insert(lines, { Text = text, Size = 10, Color = pal.Sub, Gap = 14 })
            end
        end
        local cursor = top + 6
        local limit = footer - 8
        for index, line in lines do
            local at = cursor + (if index == 1 then 7 else line.Gap)
            if at + 6 > limit then
                break
            end
            local nextLine = lines[index + 1]
            local text = line.Text
            if nextLine and at + nextLine.Gap + 6 > limit then
                if line.Size < 10 then
                    break
                end
                while #text > 1 and kit:measure(text .. "..", line.Size) > inner do
                    text = string.sub(text, 1, #text - 1)
                end
                text ..= ".."
            end
            kit:text(text, x + pad, at, line.Size, line.Color, false, true, if line.Bold then kit:boldFace() else nil)
            cursor = at
        end
    end

    local pages: { { Name: string, List: { Registry.Entry }, Empty: string } } = {
        { Name = "All Scripts", List = entries, Empty = "No scripts yet" },
        { Name = "This Game", List = pick(Registry.here), Empty = "Nothing for this game yet" },
        {
            Name = "Games",
            List = pick(function(entry)
                return entry.Category == "Games"
            end),
            Empty = "No game scripts yet",
        },
        {
            Name = "Universal",
            List = pick(function(entry)
                return entry.Category == "Universal"
            end),
            Empty = "No universal scripts yet",
        },
    }
    local current = 1

    local PANEL, PAD = 188, 8
    local tab = ui:tab("Script Hub", { Group = "Script Hub", Label = "Script Hub", OwnSearch = true, Noun = "games" })

    local function render(kit: any, window: any, index: number, height: { Value: number })
        if index ~= current then
            current = index
            selected = nil
        end
        local pal = window.Pal
        listWidth = kit.Width - PANEL - 10
        local list = pages[index].List
        local query: string = window.SearchText or ""
        local count = 0
        for _, entry in list do
            if query == "" or holds(entry, query) then
                count += 1
            end
        end
        window.OwnCount = count
        local listEnd = 170
        if count == 0 then
            local note = kit:ease("hub:none:" .. index, 1, 10)
            kit:text(if query == "" then pages[index].Empty else "No Results", listWidth / 2, 60 + (1 - note) * 6, 14, pal.Sub:Lerp(pal.Off, 1 - note), true, true)
            if query ~= "" then
                kit:text('Nothing here matches "' .. query .. '"', listWidth / 2, 82, 11, pal.Sub:Lerp(pal.Off, 1 - note * 0.8), true, true)
            end
        else
            local y = 0
            for _, entry in list do
                if query == "" or holds(entry, query) then
                    local open = kit:ease("hub:" .. entry.Id .. ":open", if selected == entry.Id then 1 else 0, 9)
                    y += line(kit, window, "hub", entry, y, open)
                end
            end
            listEnd = y
        end
        local factor = kit.ScreenSize.X / kit.Width
        local top, bottom = 3, math.max(listEnd, 300)
        local box = window.ContentBox
        if box then
            top = math.max(3, (box[2] - kit.Position.Y) / factor + PAD + 3)
            bottom = (box[4] - kit.Position.Y) / factor - PAD - 3
        end
        panel(kit, window, kit.Width - PANEL, top, PANEL, math.max(160, bottom - top))
        height.Value = listEnd + 4
    end

    for index, page in pages do
        local height = { Value = 200 }
        tab:section(page.Name):add({
            Type = "Custom",
            Name = "hub:" .. page.Name,
            Height = height,
            OwnSearch = true,
            Render = function(kit: any, window: any)
                render(kit, window, index, height)
            end,
        })
    end

    ui:start()
    getgenv()[REGISTRY] = stop
    return { stop = stop }
end

return function(OkloUI: any, reload: () -> (), Loader: any): { [string]: any }?
    stopPrevious()
    local entries, live = Registry.load()
    return build(OkloUI, reload, entries, live, if type(Loader) == "table" then Loader.config else nil)
end
end
modules["registry"] = function(...)

local import: (string) -> any = ...
local Defaults: string = import("defaults")

local Registry = {}

Registry.LoaderUrl = ""

local URL = "https://raw.githubusercontent.com/okdude42/main-scripts/main/hub/registry.json"
local PREFIX = "https://raw.githubusercontent.com/okdude42/main-scripts/main/"

export type Entry = {
    Id: string,
    Name: string,
    Category: string,
    Description: string,
    Config: { [string]: any },
    Registry: string,
    HomePlace: number?,
    GameId: number?,
    Places: { number },
    Universal: boolean?,
    Status: string,
    Info: { Tagline: string?, Groups: { { Title: string, Items: { string } } }? }?,
}

function Registry.fetch(url: string): string?
    local ok, response = pcall(request, { Url = url, Method = "GET" })
    if ok and type(response) == "table" and type(response.Body) == "string" and response.Body ~= "" and (tonumber(response.StatusCode) or 200) < 400 then
        return response.Body
    end
    local got, body = pcall(game.HttpGet, game, url)
    return if got and type(body) == "string" and body ~= "" then body else nil
end

local function decode(text: string): { Entry }?
    local ok, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(text)
    end)
    if not ok or type(data) ~= "table" or data.Schema ~= 1 or type(data.Scripts) ~= "table" then
        return nil
    end
    Registry.LoaderUrl = if type(data.LoaderUrl) == "string" then data.LoaderUrl else Registry.LoaderUrl
    local list: { Entry } = {}
    for _, entry in data.Scripts do
        if type(entry) == "table" and type(entry.Id) == "string" and type(entry.Name) == "string" and type(entry.Config) == "table" and type(entry.Config.ScriptUrl) == "string" and entry.Status ~= "hidden" then
            entry.Places = if type(entry.Places) == "table" then entry.Places else {}
            entry.Category = if type(entry.Category) == "string" then entry.Category else "Games"
            entry.Description = if type(entry.Description) == "string" then entry.Description else ""
            entry.Registry = if type(entry.Registry) == "string" then entry.Registry else ""
            table.insert(list, entry)
        end
    end
    return if #list > 0 then list else nil
end

function Registry.load(): ({ Entry }, boolean)
    local body = Registry.fetch(URL .. "?t=" .. tostring(math.floor(os.time() / 300)))
    local live = if body then decode(body) else nil
    if live then
        return live, true
    end
    return decode(Defaults) or {}, false
end

function Registry.matches(entry: Entry): boolean
    if entry.GameId and entry.GameId == game.GameId then
        return true
    end
    return table.find(entry.Places, game.PlaceId) ~= nil
end

function Registry.here(entry: Entry): boolean
    return entry.Universal == true or Registry.matches(entry)
end

function Registry.running(entry: Entry): boolean
    return entry.Registry ~= "" and type(getgenv()[entry.Registry]) == "function"
end

function Registry.safe(entry: Entry): boolean
    local url = entry.Config.ScriptUrl
    return type(url) == "string" and string.sub(url, 1, #PREFIX) == PREFIX and string.sub(Registry.LoaderUrl, 1, #PREFIX) == PREFIX
end

return Registry
end
local UI_URL = "https://raw.githubusercontent.com/okdude42/main-scripts/main/oklo-uilib/OkloUI.luau"
local Loader = (...) or { teleport = function() end }

local function fetch(url)
    local ok, response = pcall(request, { Url = url, Method = "GET" })
    if ok and type(response) == "table" and type(response.Body) == "string" and response.Body ~= "" and (tonumber(response.StatusCode) or 200) < 400 then
        return response.Body
    end
    local got, body = pcall(game.HttpGet, game, url)
    return if got and type(body) == "string" and body ~= "" then body else nil
end

local function loadUi()
    local source = getgenv().__OkloUiPrefetch or fetch(UI_URL)
    local chunk = source and loadstring(source, "OkloUI")
    if chunk then
        return chunk()
    end
    error("could not download the ui lib from github", 0)
end

local OkloUI = loadUi()

local function launch()
    table.clear(loaded)
    loaded.ui = OkloUI
    return import("main")(OkloUI, launch, Loader)
end

return launch()
