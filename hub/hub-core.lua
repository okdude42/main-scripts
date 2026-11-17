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
                "Width": 838,
                "Height": 562,
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
                "Width": 879,
                "Height": 605,
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
                "Width": 760,
                "Height": 500,
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
local ROW, SMALL, GAP = 56, 38, 6

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
        Title = "oklo: Hub",
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
        Dock = true,
        Width = 400,
        Height = 432,
        Theme = "Default",
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

    local function line(kit: any, window: any, id: string, entry: Registry.Entry, y: number): number
        local pal = window.Pal
        local key = id .. ":" .. entry.Id
        local width = listWidth
        local hover = kit:ease(key .. ":hover", if kit:hovered(key) then 1 else 0, 16)
        local open = kit:ease(key .. ":open", if selected == entry.Id then 1 else 0, 12)
        local body = ROW - GAP
        kit:hit(key, 0, y, width, body, function()
            selected = if selected == entry.Id then nil else entry.Id
        end)
        kit:nest("hub:" .. key, function()
            kit:solid(0, y, width, body, pal.Panel:Lerp(pal.Text, 0.025 + hover * 0.035 + open * 0.035), 12, 1)
            kit:border(0, y, width, body, 12, pal.Accent, open * 0.5, 1.2)
            icon(kit, window, entry, 9, y + (body - SMALL) / 2, SMALL, 1)
            local running = Registry.running(entry)
            local dot = running or Registry.matches(entry)
            local textX = 9 + SMALL + 12
            local steady = kit.Alpha
            kit:text(cut(kit, entry.Name, 15, width - textX - 22 - 80 * open), textX, y + body / 2, 15, pal.Text, false, true)
            kit.Alpha = steady * (1 - open) * (if dot then 1 else 0)
            kit:solid(width - 20, y + body / 2 - 3.5, 7, 7, if running then pal.Accent else pal.Sub, 3.5, 1)
            kit.Alpha = steady * open
            if open > 0.01 then
                local starting = Launcher.starting(entry)
                local label = if starting then "Starting.." elseif running then "Reload" else "Execute"
                local options: any = { label = label, align = "center", size = 12, disabled = starting, rounding = 14 }
                if running or starting then
                    options.base, options.textColor, options.hoverColor, options.hoverText = pal.Off, pal.Sub, pal.Panel, pal.Text
                else
                    options.base, options.textColor, options.hoverColor, options.hoverText = pal.Panel:Lerp(pal.Accent, 0.12), pal.Text, pal.Accent:Lerp(pal.Panel, 0.2), Color3.fromRGB(16, 16, 20)
                end
                kit:button(key .. ":run", width - 84, y + (body - 28) / 2, 74, 28, function()
                    Launcher.run(entry, base, ui, announce)
                end, options)
            end
            kit.Alpha = steady
        end)
        return ROW
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

    local function render(kit: any, window: any, index: number, height: { Value: number })
        local pal = window.Pal
        listWidth = kit.Width
        local list = pages[index].List
        local query: string = window.SearchText or ""
        local y = 0
        local count = 0
        for _, entry in list do
            if query == "" or holds(entry, query) then
                count += 1
                y += line(kit, window, "hub", entry, y)
            end
        end
        if count == 0 then
            kit:text(if query == "" then pages[index].Empty else "No Results", kit.Width / 2, 60, 13, pal.Sub, true, true)
            y = 120
        end
        height.Value = y + 2
    end

    local quick: { any } = {}
    local ordered: { Registry.Entry } = {}
    if detected then
        table.insert(ordered, detected)
    end
    for _, entry in entries do
        if entry ~= detected then
            table.insert(ordered, entry)
        end
    end
    for index = 1, math.min(4, #ordered) do
        local entry = ordered[index]
        table.insert(quick, {
            Title = entry.Name,
            Text = entry.Description,
            Icon = "rocket",
            Callback = function()
                Launcher.run(entry, base, ui, announce)
            end,
            Active = function(): boolean
                return Registry.running(entry)
            end,
        })
    end

    for index, page in pages do
        local height = { Value = 200 }
        local tab = ui:tab(page.Name, { Label = page.Name })
        tab:section(page.Name):add({
            Type = "Custom",
            Bare = true,
            Name = "hub:" .. page.Name,
            Height = height,
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
    local got, body = pcall(function()
        return game:HttpGet(url)
    end)
    return if got and type(body) == "string" and body ~= "" then body else nil
end

local function globals()
    local ok, env = pcall(getgenv)
    return if ok and type(env) == "table" then env else _G
end

local function loadUi()
    local env = globals()
    local source = env.__OkloUiPrefetch
    if type(source) ~= "string" or not string.find(source, "copyConfigCode", 1, true) then
        source = fetch(UI_URL) or (if type(source) == "string" then source else nil)
    end
    env.__OkloUiPrefetch = nil
    if not source then
        error("could not download the ui lib from github", 0)
    end
    local chunk, problem = loadstring(source, "OkloUI")
    if not chunk then
        error("could not compile the ui lib: " .. tostring(problem), 0)
    end
    return chunk()
end

local OkloUI = loadUi()

local function launch()
    table.clear(loaded)
    loaded.ui = OkloUI
    return import("main")(OkloUI, launch, Loader)
end

return launch()


