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
Changelog.DATE = "October 31, 2026"

type Group = { Mode: string, Added: { string }?, Changed: { string }?, Removed: { string }?, Fixed: { string }? }

Changelog.GROUPS = {
    {
        Mode = "General",
        Added = {
            "Released",
        },
    },
} :: { Group }

Changelog.HISTORY = {} :: { { Version: string, Date: string, Lines: { string }?, Groups: { Group }? } }

Changelog.CLOSING = "please join the discord server c:"

Changelog.OPEN = "General"

return Changelog
end
modules["context"] = function(...)

local import: (string) -> any = ...
local Game: typeof(require("./game")) = import("game")

local Context = {}

export type Context = {
    Game: typeof(Game),
    Folder: string,
    read: (flag: string) -> any,
    alias: (map: { [string]: string }, active: () -> boolean) -> (),
    set: (flag: string, value: any) -> (),
    notify: (text: string) -> (),
    connect: (signal: any, callback: (...any) -> ()) -> any,
    spawn: (callback: () -> ()) -> any,
    wait: (seconds: number) -> boolean,
    alive: () -> boolean,
}

export type Tab = {
    build: (self: Tab, ui: any) -> (),
    step: ((self: Tab, dt: number) -> ())?,
    frame: ((self: Tab, canvas: any) -> ())?,
    shutdown: (self: Tab) -> (),
}

Context.FOLDER = "oklo scripts/boogautilities"
Context.CONFIGS = "configs"

function Context.new(ui: () -> any, defaults: { [string]: any }): (Context, () -> ())
    local running = true
    local aliases: { [string]: string } = {}
    local aliasActive: (() -> boolean)? = nil
    local connections: { any } = {}
    local threads: { any } = {}
    local context: Context
    context = {
        Game = Game,
        Folder = Context.FOLDER,
        read = function(flag: string): any
            local other = aliases[flag]
            if other ~= nil and aliasActive ~= nil and aliasActive() then
                flag = other
            end
            local value = ui():get(flag)
            if value == nil then
                return defaults[flag]
            end
            return value
        end,
        alias = function(map: { [string]: string }, active: () -> boolean)
            for flag, other in map do
                aliases[flag] = other
            end
            aliasActive = active
        end,
        set = function(flag: string, value: any)
            ui():set(flag, value)
        end,
        notify = function(text: string)
            ui().Window:announce(text)
        end,
        connect = function(signal: any, callback: (...any) -> ()): any
            local link = signal:Connect(callback)
            table.insert(connections, link)
            return link
        end,
        spawn = function(callback: () -> ()): any
            local thread = task.spawn(function()
                if running then
                    callback()
                end
            end)
            table.insert(threads, thread)
            return thread
        end,
        wait = function(seconds: number): boolean
            task.wait(seconds)
            return running
        end,
        alive = function(): boolean
            return running
        end,
    }
    local function dispose()
        running = false
        for _, link in connections do
            pcall(function()
                link:Disconnect()
            end)
        end
        table.clear(connections)
        for _, thread in threads do
            pcall(task.cancel, thread)
        end
        table.clear(threads)
    end
    return context, dispose
end

return Context
end
modules["farm"] = function(...)

local import: (string) -> any = ...
local Link: any = import("goldfarm/link")
local Embed: any = import("goldfarm/webhook/embed")

local Farm = {}
Farm.__index = Farm

local SNAPSHOT_EVERY = 2
local DASH = "\u{2014}"

local GOOD = Color3.fromRGB(120, 210, 130)
local WARN = Color3.fromRGB(235, 190, 90)
local BAD = Color3.fromRGB(230, 110, 110)

local function onOff(value: boolean): (string, Color3?)
    if value then
        return "On", GOOD
    end
    return "Off", nil
end

function Farm.new(context: any): any
    return setmetatable({ Context = context, Cached = nil :: any, CachedAt = -math.huge }, Farm)
end

function Farm.snapshot(self: any): any
    local now = os.clock()
    if self.Cached ~= nil and now - self.CachedAt < SNAPSHOT_EVERY then
        return self.Cached
    end
    local webhook = Link.get(self.Context, "webhook")
    if webhook == nil then
        return nil
    end
    local ok, result = pcall(function()
        return webhook.Stats:snapshot()
    end)
    if ok then
        self.Cached = result
        self.CachedAt = now
    end
    return self.Cached
end

local function number(value: number?): string
    if value == nil then
        return DASH
    end
    return Embed.number(value)
end

function Farm.state(self: any): (string, Color3?)
    local gold = Link.get(self.Context, "gold")
    local read = self.Context.read
    if gold == nil or read("GoldStartPath") ~= true then
        return "Path is off", nil
    elseif gold.Press.Paused then
        return "Paused by Coin Press", WARN
    end
    local index = gold.Runner.Index
    local count = #gold.Paths.Points
    if index == nil then
        return "Path starting", WARN
    end
    return string.format("Running %s, point %d of %d", gold.Paths.Name, index, count), GOOD
end

function Farm.build(self: any): any
    local context = self.Context
    local read = context.read
    local gold = Link.get(context, "gold")
    local webhook = Link.get(context, "webhook")
    local stats = self:snapshot()
    local state, stateColor = self:state()

    local tiles: { any } = {}
    local cards: { any } = {}
    if stats ~= nil then
        table.insert(tiles, {
            Label = "Runtime",
            Value = Embed.duration(stats.runtime),
            Sub = stats.name,
        })
        table.insert(tiles, {
            Label = "Gold",
            Value = number(stats.chest.gold + stats.outside.gold),
            Sub = string.format("%s in chest", number(stats.chest.gold)),
        })
        table.insert(tiles, {
            Label = "Bars",
            Value = number(stats.chest.bars + stats.outside.bars),
            Sub = string.format("%s in chest", number(stats.chest.bars)),
        })
        table.insert(tiles, {
            Label = "Coins Pressed",
            Value = number(stats.pressed),
            Sub = if stats.perHour ~= nil then string.format("%s per hour", number(stats.perHour)) else "per hour after 1 min",
            Color = GOOD,
        })

        local hunger = if stats.hunger ~= nil then string.format("%d%%", math.floor(math.clamp(stats.hunger, 0, 100) + 0.5)) else DASH
        local last = DASH
        if stats.lastCycle ~= nil then
            last = Embed.duration(os.time() - stats.lastCycle) .. " ago"
        end
        table.insert(cards, {
            Title = "Coin Press",
            Rows = {
                { Label = "Cycles", Value = number(stats.cycles) },
                { Label = "Coins pressed", Value = number(stats.pressed) },
                { Label = "Press coins", Value = number(stats.pressCoins) },
                { Label = "Last cycle", Value = last },
            },
        })
        table.insert(cards, {
            Title = "Inventory",
            Rows = {
                { Label = "Gold outside", Value = number(stats.outside.gold) },
                { Label = "Bars outside", Value = number(stats.outside.bars) },
                { Label = "Hunger", Value = hunger },
                { Label = "Account coins", Value = number(stats.account) },
            },
        })
        table.insert(cards, {
            Title = "Chest",
            Rows = {
                { Label = "Gold", Value = number(stats.chest.gold) },
                { Label = "Bars", Value = number(stats.chest.bars) },
            },
        })
    end

    if gold ~= nil then
        local drops = gold.Drops
        table.insert(cards, {
            Title = "Gold Drops",
            Rows = {
                { Label = "In the chest", Value = number(drops.In), Color = GOOD },
                { Label = "Outside", Value = number(drops.Out), Color = if drops.Out > 0 then WARN else nil },
            },
        })
        local anti = gold:antiStuckText()
        table.insert(cards, {
            Title = "Route",
            Rows = {
                { Label = "State", Value = state, Color = stateColor },
                { Label = "Path", Value = gold.Paths.Name },
                { Label = "Anti-Stuck", Value = string.gsub(anti, "^Anti%-Stuck:? ?", "") },
            },
        })
    end

    if webhook ~= nil then
        local linked = webhook:linked()
        local cooldown = read("WebhookCooldown") - (os.clock() - webhook.LastAt)
        local sending, sendingColor = DASH, nil
        if webhook.Busy then
            sending, sendingColor = "Sending", WARN
        elseif cooldown > 0 then
            sending = string.format("Ready in %ds", math.ceil(cooldown))
        elseif linked then
            sending, sendingColor = "Ready", GOOD
        end
        local enabled, enabledColor = onOff(read("WebhookEnabled") == true)
        local link, linkColor = "Not set", nil
        if linked then
            link, linkColor = "Set", GOOD
            if webhook.Rejected == read("WebhookUrl") then
                link, linkColor = "Rejected", BAD
            end
        end
        local cycle, cycleColor = onOff(read("WebhookOnCycle") == true)
        table.insert(cards, {
            Title = "Webhook",
            Rows = {
                { Label = "Link", Value = link, Color = linkColor },
                { Label = "Enabled", Value = enabled, Color = enabledColor },
                { Label = "After every cycle", Value = cycle, Color = cycleColor },
                { Label = "Next send", Value = sending, Color = sendingColor },
            },
        })
    end

    local widgets: { any } = {}
    if gold ~= nil then
        local ok, list = pcall(function()
            return gold.Drops:widgets()
        end)
        if ok then
            widgets = list
        end
    end

    return { Tiles = tiles, Cards = cards, Status = state, Widgets = widgets }
end

function Farm.shutdown(self: any)
    self.Cached = nil
end

return Farm
end
modules["game"] = function(...)

local import: (string) -> any = ...
local Actions: typeof(require("@self/actions")) = import("game/actions")
local Chests: typeof(require("@self/chests")) = import("game/chests")
local Codec: typeof(require("@self/codec")) = import("game/codec")
local Constants: typeof(require("@self/constants")) = import("game/constants")
local Drive: typeof(require("@self/drive")) = import("game/drive")
local Finder: typeof(require("@self/finder")) = import("game/finder")
local Inventory: typeof(require("@self/inventory")) = import("game/inventory")
local Modules: typeof(require("@self/modules")) = import("game/modules")
local Movement: typeof(require("@self/movement")) = import("game/movement")
local Observer: typeof(require("@self/observer")) = import("game/observer")
local Packets: typeof(require("@self/packets")) = import("game/packets")
local Shape: typeof(require("@self/shape")) = import("game/shape")
local Template: typeof(require("@self/template")) = import("game/template")
local World: typeof(require("@self/world")) = import("game/world")

local Game = {}

export type Status = {
    source: string,
    error: string?,
    remote: boolean,
    packets: number,
    mode: string,
    format: string,
    server: string,
    private: boolean,
    inventory: boolean,
}

local DESTROY_KEY = Constants.GLOBAL_PREFIX .. "GameDestroy"
local REPORT_FILE = Constants.CACHE_FOLDER .. "/packet report.txt"
local REPORT_EVERY = 15

local REMOTES_EVERY = 300

local reporting = false
local reporters: { () -> { string } } = {}
local remotesLine: string? = nil
local remotesAt = 0
local lastReport: string? = nil

Game.VERSION = Constants.VERSION
Game.constants = Constants
Game.codec = Codec
Game.modules = Modules
Game.packets = Packets
Game.world = World
Game.finder = Finder
Game.inventory = Inventory
Game.movement = Movement
Game.drive = Drive
Game.actions = Actions
Game.chests = Chests
Game.observer = Observer
Game.shape = Shape
Game.template = Template

local function environment(): { [string]: any }?
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then
        return env
    end
    return nil
end

function Game.addReport(reporter: () -> { string })
    table.insert(reporters, reporter)
end

function Game.writeReport()
    pcall(function()
        local range = 300
        local boxes = Finder.plantBoxes(range, false)
        local empty = Finder.plantBoxes(range, true)
        local seed = Inventory.seedId("Bloodfruit")
        local extra: { string } = {
            "plant boxes within " .. range .. " studs: " .. #boxes .. " (empty: " .. #empty .. ")",
            "bushes within " .. range .. " studs: " .. #Finder.bushes(range),
            "loose items within " .. range .. " studs: " .. #Finder.items(range),
            "Bloodfruit seed id: " .. tostring(seed),
            "bag readable: " .. tostring(Inventory.ready()),
            "spawned: " .. tostring(World.isSpawned()),
        }
        local stats = Packets.stats()
        local remote = Packets.remote()
        table.insert(extra, "sniffer: " .. Observer.status())
        table.insert(extra, "remote: " .. (if remote then remote:GetFullName() .. " (" .. remote.ClassName .. ")" else "not found"))
        table.insert(extra, string.format("our sends: %d sent, %d failed, %d queued", stats.sent, stats.failed, stats.queued))
        local storage = Modules.service("ReplicatedStorage")
        if storage ~= nil and (remotesLine == nil or os.clock() - remotesAt >= REMOTES_EVERY) then
            local names: { string } = {}
            for _, item in storage:GetDescendants() do
                if item:IsA("RemoteEvent") or item:IsA("UnreliableRemoteEvent") or item:IsA("RemoteFunction") then
                    table.insert(names, item.ClassName .. " " .. item:GetFullName())
                end
            end
            table.sort(names)
            remotesLine = "remotes in ReplicatedStorage: " .. (if #names > 0 then table.concat(names, ", ") else "none")
            remotesAt = os.clock()
        end
        if remotesLine ~= nil then
            table.insert(extra, remotesLine)
        end
        local function describe(instance: any): string
            local parts: { string } = {}
            for _, child in instance:GetChildren() do
                table.insert(parts, child.Name .. " (" .. child.ClassName .. ")")
            end
            local attributes: { string } = {}
            local okAttributes, all = pcall(function(): any
                return instance:GetAttributes()
            end)
            if okAttributes and type(all) == "table" then
                for key, value in all do
                    table.insert(attributes, tostring(key) .. "=" .. tostring(value))
                end
            end
            table.sort(parts)
            table.sort(attributes)
            return instance.Name .. " | children: " .. (if #parts > 0 then table.concat(parts, ", ") else "none") .. " | attributes: " .. (if #attributes > 0 then table.concat(attributes, ", ") else "none")
        end
        for _, name in { "PlaceStructure", "InteractStructure", "Pickup" } do
            local lines = Shape.describe(Packets.object(name), 40)
            table.insert(extra, "packet shape " .. name .. ": " .. (if #lines > 0 then table.concat(lines, "; ") else "nothing readable"))
        end
        for _, line in Template.lines(Packets.object) do
            table.insert(extra, line)
        end
        for _, line in Packets.health() do
            table.insert(extra, line)
        end
        for _, name in { "SwingTool", "PlaceStructure" } do
            local id = Packets.id(name)
            local raw = if id then Packets.lastRaw(id) else nil
            table.insert(extra, "our last raw " .. name .. ": " .. (raw or "none sent"))
        end
        local nearby: { [string]: number } = {}
        for _, entry in Finder.resources(60) do
            nearby[entry.name] = (nearby[entry.name] or 0) + 1
        end
        local resourceNames: { string } = {}
        for name, count in nearby do
            table.insert(resourceNames, name .. " x" .. count)
        end
        table.sort(resourceNames)
        table.insert(extra, "resources within 60 studs: " .. (if #resourceNames > 0 then table.concat(resourceNames, ", ") else "none"))
        table.insert(extra, "gold nodes within 20 studs: " .. #Finder.resources(20, { contains = { "gold" } }))
        local held: { string } = {}
        for index, slot in Inventory.items() do
            if index <= 40 then
                table.insert(held, slot.name .. " x" .. slot.quantity .. " (layout " .. tostring(slot.layout) .. ", id " .. tostring(Inventory.itemId(slot.name)) .. ")")
            end
        end
        table.insert(extra, "bag: " .. (if #held > 0 then table.concat(held, ", ") else "nothing readable"))
        for _, line in Observer.gameValues() do
            table.insert(extra, line)
        end
        local bar: { string } = {}
        for index, name in Inventory.toolbar() do
            table.insert(bar, tostring(index) .. "=" .. name)
        end
        table.sort(bar)
        table.insert(extra, "toolbar as the script reads it: " .. (if #bar > 0 then table.concat(bar, ", ") else "nothing readable") .. " | holding: " .. tostring(Inventory.equippedName()))
        local idCount = 0
        for _ in Inventory.itemIds() do
            idCount += 1
        end
        local top = Inventory.topbar()
        table.insert(extra, string.format("hunger read: %s (100 also when unreadable), health read: %s, item ids readable: %d, topbar coins %s level %s", tostring(Inventory.hunger()), tostring(Inventory.healthPercent()), idCount, tostring(top.coins), tostring(top.level)))
        for _, reporter in reporters do
            local ok, lines = pcall(reporter)
            if ok and type(lines) == "table" then
                for _, line in lines do
                    table.insert(extra, line)
                end
            end
        end
        local crops = World.folder("Crops")
        local cropNames: { [string]: number } = {}
        if crops ~= nil then
            for _, child in crops:GetChildren() do
                cropNames[child.Name] = (cropNames[child.Name] or 0) + 1
            end
        end
        local cropList: { string } = {}
        for name, count in cropNames do
            table.insert(cropList, name .. " x" .. count)
        end
        table.sort(cropList)
        table.insert(extra, "crops folder: " .. (if crops ~= nil then #crops:GetChildren() .. " children, " .. (if #cropList > 0 then table.concat(cropList, ", ") else "empty") else "missing"))
        local found = Finder.bushes(200)
        local sample: { string } = {}
        for index = 1, math.min(5, #found) do
            sample[index] = found[index].name .. " id " .. tostring(found[index].entityId) .. " " .. math.floor(found[index].distance) .. " studs"
        end
        table.insert(extra, "grown bushes within 200 studs: " .. #found .. (if #sample > 0 then " (" .. table.concat(sample, "; ") .. ")" else ""))
        table.insert(extra, "")
        local space = World.workspace()
        if space ~= nil then
            local folders: { string } = {}
            for _, child in space:GetChildren() do
                if child:IsA("Folder") then
                    table.insert(folders, child.Name)
                end
            end
            table.sort(folders)
            table.insert(extra, "workspace folders: " .. table.concat(folders, ", "))
        end
        local shown = 0
        for _, entry in boxes do
            if shown < 3 and Finder.isPlanted(entry.instance) then
                shown += 1
                table.insert(extra, "planted box: " .. describe(entry.instance))
            end
        end
        for index = 1, math.min(2, #empty) do
            table.insert(extra, "empty box: " .. describe(empty[index].instance))
        end
        local counts: { [string]: number } = {}
        local deployables = World.folder("Deployables")
        if deployables ~= nil then
            for _, child in deployables:GetChildren() do
                counts[child.Name] = (counts[child.Name] or 0) + 1
            end
        end
        local kinds: { string } = {}
        for name, count in counts do
            table.insert(kinds, name .. " x" .. count)
        end
        table.sort(kinds)
        table.insert(extra, "deployables: " .. table.concat(kinds, ", "))
        for _, kind in { "Chest", "Coin Press", "Campfire" } do
            local nearest = Finder.deployables(range, { contains = { kind } })[1]
            if nearest == nil then
                table.insert(extra, "nearest " .. kind .. ": none within " .. range .. " studs")
            else
                local note = if kind == "Chest" then "seen as chest: " .. tostring(Finder.isChest(nearest.instance)) elseif kind == "Campfire" then "fuel read: " .. tostring(Finder.campfireFuel(nearest.instance)) else "entity: " .. tostring(nearest.entityId)
                table.insert(extra, "nearest " .. kind .. " (" .. note .. "): " .. describe(nearest.instance))
            end
        end
        table.insert(extra, "")
        for _, line in Observer.lines() do
            table.insert(extra, line)
        end
        local text = Packets.report(extra)
        if text == lastReport and isfile(REPORT_FILE) then
            return
        end
        if not isfolder("oklo scripts") then
            makefolder("oklo scripts")
        end
        if not isfolder(Constants.CACHE_FOLDER) then
            makefolder(Constants.CACHE_FOLDER)
        end
        writefile(REPORT_FILE, text)
        lastReport = text
    end)
end

local function startReport()
    if reporting then
        return
    end
    reporting = true
    task.spawn(function()
        while reporting do
            Game.writeReport()
            task.wait(REPORT_EVERY)
        end
    end)
end

function Game.send(name: string, ...: any): boolean
    return Packets.send(name, ...)
end

function Game.queue(name: string, ...: any): boolean
    return Packets.queue(name, ...)
end

function Game.init(): (boolean, string?)
    local env = environment()
    if env then
        local previous = env[DESTROY_KEY]
        if type(previous) == "function" and previous ~= Game.destroy then
            pcall(previous)
        end
        env[DESTROY_KEY] = Game.destroy
    end
    Template.provide("toolItem", function(): any
        local name = Inventory.equippedName()
        return if name then Inventory.itemId(name) else nil
    end)
    Template.provide("toolSlot", function(): any
        local name = Inventory.equippedName()
        if name == nil then
            return nil
        end
        for index, held in Inventory.toolbar() do
            if held == name then
                return index
            end
        end
        return nil
    end)
    Template.provide("frame", function(): any
        local root = World.root()
        return if root then root.CFrame else nil
    end)
    local resolved, problem = Packets.resolve()
    Observer.start()
    startReport()
    return resolved, problem
end

function Game.status(): Status
    local count = 0
    for _ in Packets.ids() do
        count += 1
    end
    return {
        source = Packets.source(),
        error = Packets.lastError(),
        remote = Packets.remote() ~= nil,
        packets = count,
        mode = Packets.getMode(),
        format = Packets.getCFrameFormat(),
        server = World.serverType(),
        private = World.isPrivateServer(),
        inventory = Inventory.ready(),
    }
end

function Game.destroy()
    reporting = false
    Observer.stop()
    Packets.destroy()
    Movement.destroy()
    Finder.reset()
    Actions.reset()
    for _, name in { "toolItem", "toolSlot", "frame" } do
        Template.provide(name, nil)
    end
    local env = environment()
    if env and env[DESTROY_KEY] == Game.destroy then
        env[DESTROY_KEY] = nil
    end
end

return Game
end
modules["game/actions"] = function(...)

local import: (string) -> any = ...
local Constants: typeof(require("./constants")) = import("game/constants")
local Finder: typeof(require("./finder")) = import("game/finder")
local Inventory: typeof(require("./inventory")) = import("game/inventory")
local Modules: typeof(require("./modules")) = import("game/modules")
local Packets: typeof(require("./packets")) = import("game/packets")
local World: typeof(require("./world")) = import("game/world")

local Actions = {}

type Entry = { instance: any, name: string, entityId: number?, position: Vector3, distance: number }
type PlayerQuery = { range: number?, origin: Vector3?, skipAllies: boolean?, skipDead: boolean?, skipGods: boolean?, tribes: { [string]: any }?, maxHeight: number? }

local harvested: { [number]: number } = {}

function Actions.entityOf(target: any): number?
    if type(target) == "number" then
        return target
    end
    if type(target) == "table" and type(target.entityId) == "number" then
        return target.entityId
    end
    if target ~= nil and type(target) ~= "string" and type(target) ~= "boolean" then
        return World.entityId(target)
    end
    return nil
end

function Actions.aim(positions: { Vector3 }): CFrame?
    local root = World.root()
    if root == nil then
        return nil
    end
    if #positions == 0 then
        return root.CFrame
    end
    local sum = Vector3.new(0, 0, 0)
    for _, position in positions do
        sum += position
    end
    local center = sum / #positions
    if (center - root.Position).Magnitude <= 0.01 then
        return root.CFrame
    end
    return CFrame.lookAt(root.Position, center)
end

function Actions.hit(entries: { Entry }, count: number?): number
    local limit = math.clamp(count or Constants.LIMITS.SwingTargetsSafe, 1, Constants.LIMITS.SwingTargets)
    local ids: { number } = {}
    local positions: { Vector3 } = {}
    for _, entry in entries do
        if entry.entityId then
            table.insert(ids, entry.entityId)
            table.insert(positions, entry.position)
            if #ids >= limit then
                break
            end
        end
    end
    if #ids == 0 then
        return 0
    end
    local frame = Actions.aim(positions)
    if frame == nil or not Packets.send("SwingTool", ids, frame) then
        return 0
    end
    return #ids
end

function Actions.pickup(targets: number | { number }, batched: boolean?): number
    local list: { number } = if type(targets) == "table" then targets else { targets }
    local sent = 0
    local useQueue = batched == true or #list > 1
    for _, id in list do
        local ok = if useQueue then Packets.queue("Pickup", id) else Packets.send("Pickup", id)
        if ok then
            sent += 1
        end
    end
    return sent
end

function Actions.pickupEntries(entries: { Entry }, limit: number?): number
    local ids: { number } = {}
    for _, entry in entries do
        if entry.entityId then
            table.insert(ids, entry.entityId)
            if limit and #ids >= limit then
                break
            end
        end
    end
    return Actions.pickup(ids, true)
end

function Actions.harvest(range: number?, fruit: string?, limit: number?): number
    local now = os.clock()
    local ids: { number } = {}
    for _, entry in Finder.bushes(range or 30, fruit) do
        local id = entry.entityId
        if id and now - (harvested[id] or 0) >= Constants.LIMITS.HarvestCooldown then
            harvested[id] = now
            table.insert(ids, id)
            if #ids >= (limit or 12) then
                break
            end
        end
    end
    for id, at in harvested do
        if now - at > 30 then
            harvested[id] = nil
        end
    end
    return Actions.pickup(ids, true)
end

function Actions.eat(itemName: string): boolean
    local slot = Inventory.find(itemName)
    local id = Inventory.itemId(itemName)
    if slot == nil or id == nil then
        return false
    end
    return Packets.send("UseBagItem", slot.layout, id)
end

function Actions.plant(box: any, fruit: string): boolean
    local entity = Actions.entityOf(box)
    local id = Inventory.seedId(fruit)
    if entity == nil or id == nil then
        return false
    end
    return Packets.send("InteractStructure", entity, id)
end

function Actions.pressCoin(press: any?): boolean
    local target = press
    if target == nil then
        local nearest = Finder.nearestCoinPress()
        target = if nearest then nearest.instance else nil
    end
    local entity = Actions.entityOf(target)
    local gold = Inventory.itemId("Gold")
    if entity == nil or gold == nil then
        return false
    end
    return Packets.send("InteractStructure", entity, gold)
end

function Actions.fuel(campfire: any?, fuelName: string?): boolean
    local target = campfire
    if target == nil then
        local nearest = Finder.campfires(35)[1]
        target = if nearest then nearest.instance else nil
    end
    local entity = Actions.entityOf(target)
    local name = fuelName
    if name == nil then
        for _, candidate in Constants.FUELS do
            if Inventory.has(candidate) then
                name = candidate
                break
            end
        end
    end
    local id = if name then Inventory.itemId(name) else nil
    if entity == nil or id == nil then
        return false
    end
    return Packets.send("InteractStructure", entity, id)
end

Actions.syntheticAt = 0

function Actions.pressSlotKey(slot: number): boolean
    local keys = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
    local key = keys[slot]
    local input = Modules.service("VirtualInputManager")
    if key == nil or input == nil then
        return false
    end
    Actions.syntheticAt = os.clock()
    local ok = pcall(function()
        input:SendKeyEvent(true, (Enum.KeyCode :: any)[key], false, game)
        task.wait(0.04)
        input:SendKeyEvent(false, (Enum.KeyCode :: any)[key], false, game)
    end)
    return ok
end

function Actions.place(name: string, frame: CFrame): boolean
    return Packets.send("PlaceStructure", name, frame)
end

function Actions.clickScreen(): boolean
    local input = Modules.service("VirtualInputManager")
    local camera = World.workspace().CurrentCamera
    if input == nil or camera == nil then
        return false
    end
    local size: Vector2 = camera.ViewportSize
    local x, y = size.X / 2, size.Y / 2
    Actions.syntheticAt = os.clock()
    return (pcall(function()
        input:SendMouseMoveEvent(x, y, game)
        input:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.03)
        input:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end))
end

function Actions.reset()
    table.clear(harvested)
end

return Actions
end
modules["game/builders"] = function(...)

local import: (string) -> any = ...
local Codec: typeof(require("./codec")) = import("game/codec")
local Constants: typeof(require("./constants")) = import("game/constants")

local Builders = {}

export type Settings = { format: string, stamp: () -> number }
export type Definition = {
    names: { string },
    layout: string,
    build: (id: number, settings: Settings, ...any) -> buffer?,
    module: ((packet: any, ...any) -> ())?,
    verified: boolean?,
}

local function unsigned(value: any, bits: number): number?
    local number = tonumber(value)
    if number == nil then
        return nil
    end
    number = math.floor(number)
    if Codec.isUnsigned(number, bits) then
        return number
    end
    return nil
end

local function positive(value: any, bits: number): number?
    local number = unsigned(value, bits)
    if number and number > 0 then
        return number
    end
    return nil
end

local function start(id: number, size: number): typeof(Codec.writer())
    local writer = Codec.writer(size)
    Codec.header(writer, id)
    return writer
end

function Builders.entity(id: number, entityId: any): buffer?
    local entity = positive(entityId, 32)
    if not entity then
        return nil
    end
    local writer = start(id, 6)
    Codec.u32(writer, entity)
    return Codec.finish(writer)
end

function Builders.word(id: number, value: any): buffer?
    local number = unsigned(value, 16)
    if not number then
        return nil
    end
    local writer = start(id, 4)
    Codec.u16(writer, number)
    return Codec.finish(writer)
end

function Builders.useBagItem(id: number, layout: any, itemId: any): buffer?
    local slot = unsigned(layout, 32)
    local item = unsigned(itemId, 16)
    if not slot or not item then
        return nil
    end
    local writer = start(id, 8)
    Codec.u32(writer, slot)
    Codec.u16(writer, item)
    return Codec.finish(writer)
end

function Builders.interactStructure(id: number, entityId: any, itemId: any): buffer?
    local entity = positive(entityId, 32)
    local item = unsigned(itemId, 16)
    if not entity or not item or id > 255 then
        return nil
    end
    local writer = Codec.writer(9)
    Codec.header(writer, id, 1)
    Codec.vlq(writer, entity)
    Codec.u16(writer, item)
    return Codec.finish(writer)
end

function Builders.targets(list: any, cap: number): { number }
    local clean: { number } = {}
    local seen: { [number]: boolean } = {}
    if type(list) ~= "table" then
        list = { list }
    end
    for _, value in list do
        local entity = positive(value, 32)
        if entity and not seen[entity] then
            seen[entity] = true
            table.insert(clean, entity)
            if #clean >= cap then
                break
            end
        end
    end
    return clean
end

function Builders.swingTool(id: number, frame: CFrame, targets: { number }, stamp: number, format: string): buffer?
    if #targets == 0 then
        return nil
    end
    local writer = start(id, 2 + Codec.cframeSize(format) + 1 + 5 * #targets + 8)
    Codec.cframe(writer, frame, format)
    Codec.u8(writer, #targets)
    for _, entity in targets do
        Codec.u8(writer, 0)
        Codec.u32(writer, entity)
    end
    Codec.f64(writer, stamp)
    return Codec.finish(writer)
end

function Builders.placeStructure(id: number, name: any, frame: CFrame, format: string): buffer?
    if type(name) ~= "string" or name == "" or #name > 65535 then
        return nil
    end
    local writer = start(id, 4 + #name + Codec.cframeSize(format))
    Codec.text(writer, name)
    Codec.cframe(writer, frame, format)
    return Codec.finish(writer)
end

function Builders.text(id: number, text: any): buffer?
    if type(text) ~= "string" or text == "" or #text > 65535 then
        return nil
    end
    local writer = start(id, 4 + #text)
    Codec.text(writer, text)
    return Codec.finish(writer)
end

function Builders.position(id: number, position: Vector3): buffer
    local writer = start(id, 14)
    Codec.vector(writer, position)
    return Codec.finish(writer)
end

function Builders.cast(id: number, target: Vector3, origin: Vector3): buffer
    local writer = start(id, 26)
    Codec.vector(writer, target)
    Codec.vector(writer, origin)
    return Codec.finish(writer)
end

local function vector(value: any): boolean
    return value ~= nil and type(value) ~= "number" and type(value) ~= "string" and type(value) ~= "boolean"
end

local function sendNumber(packet: any, value: any)
    packet.send(value)
end

Builders.DEFINITIONS = {
    SwingTool = {
        names = { "SwingTool" },
        layout = "hdr, cframe(18), u8 count, count x (u8 0, u32 entity), f64 stamp",
        build = function(id: number, settings: Settings, targets: any, frame: any, stamp: any): buffer?
            if not vector(frame) then
                return nil
            end
            local clean = Builders.targets(targets, Constants.LIMITS.SwingTargets)
            local time = tonumber(stamp) or settings.stamp()
            return Builders.swingTool(id, frame, clean, time, settings.format)
        end,
    },
    Pickup = {
        names = { "Pickup" },
        layout = "00, id, u32 entity",
        build = function(id: number, _settings: Settings, entityId: any): buffer?
            return Builders.entity(id, entityId)
        end,
        module = sendNumber,
        verified = true,
    },
    ForceInteract = {
        names = { "ForceInteract" },
        layout = "hdr, u32 entity",
        build = function(id: number, _settings: Settings, entityId: any): buffer?
            return Builders.entity(id, entityId)
        end,
        module = sendNumber,
    },
    OpenChest = {
        names = { "OpenChest", "OpenStorage", "OpenContainer", "InteractChest", "ToggleDoor" },
        layout = "hdr, u32 entity",
        build = function(id: number, _settings: Settings, entityId: any): buffer?
            return Builders.entity(id, entityId)
        end,
        module = sendNumber,
    },
    DropBagItem = {
        names = { "DropBagItem" },
        layout = "hdr, u16 layout",
        build = function(id: number, _settings: Settings, layout: any): buffer?
            return Builders.word(id, layout)
        end,
        module = sendNumber,
    },
    UseBagItem = {
        names = { "UseBagItem" },
        layout = "hdr, u32 layout, u16 itemId",
        build = function(id: number, _settings: Settings, layout: any, itemId: any): buffer?
            return Builders.useBagItem(id, layout, itemId)
        end,
        module = sendNumber,
    },
    InteractStructure = {
        names = { "InteractStructure" },
        layout = "01, id, vlq entity, u16 itemId",
        build = function(id: number, _settings: Settings, entityId: any, itemId: any): buffer?
            return Builders.interactStructure(id, entityId, itemId)
        end,
        module = function(packet: any, entityId: any, itemId: any)
            packet.send({ entityID = entityId, itemID = itemId })
        end,
        verified = true,
    },
    PlaceStructure = {
        names = { "PlaceStructure" },
        layout = "hdr, u16 length, name bytes, cframe(18)",
        build = function(id: number, settings: Settings, name: any, frame: any): buffer?
            if not vector(frame) then
                return nil
            end
            return Builders.placeStructure(id, name, frame, settings.format)
        end,
        module = function(packet: any, name: any, frame: any)
            packet.send({ buildingName = name, cframe = frame })
        end,
    },
} :: { [string]: Definition }

return Builders
end
modules["game/cache"] = function(...)

local import: (string) -> any = ...
local Constants: typeof(require("./constants")) = import("game/constants")
local Modules: typeof(require("./modules")) = import("game/modules")

local Cache = {}

local function json(): any
    return Modules.service("HttpService")
end

function Cache.load(): ({ [string]: number }?, string?)
    local ok, result = pcall(function()
        if not isfile(Constants.CACHE_FILE) then
            return nil
        end
        return json():JSONDecode(readfile(Constants.CACHE_FILE))
    end)
    if not ok or type(result) ~= "table" or type(result.packets) ~= "table" then
        return nil, nil
    end
    local map: { [string]: number } = {}
    for name, id in result.packets do
        if type(name) == "string" and type(id) == "number" and id > 0 then
            map[name] = id
        end
    end
    if next(map) == nil then
        return nil, nil
    end
    return map, if result.gameVersion ~= nil then tostring(result.gameVersion) else nil
end

function Cache.same(a: { [string]: number }?, b: { [string]: number }): boolean
    if a == nil then
        return false
    end
    for key, value in a do
        if b[key] ~= value then
            return false
        end
    end
    for key, value in b do
        if a[key] ~= value then
            return false
        end
    end
    return true
end

function Cache.save(map: { [string]: number }, gameVersion: string)
    pcall(function()
        if not isfolder("oklo scripts") then
            makefolder("oklo scripts")
        end
        if not isfolder(Constants.CACHE_FOLDER) then
            makefolder(Constants.CACHE_FOLDER)
        end
        writefile(Constants.CACHE_FILE, json():JSONEncode({ version = 1, gameVersion = gameVersion, savedAt = os.time(), packets = map }))
    end)
end

function Cache.clear(): boolean
    local ok = pcall(function()
        if isfile(Constants.CACHE_FILE) then
            delfile(Constants.CACHE_FILE)
        end
    end)
    return ok
end

return Cache
end
modules["game/chests"] = function(...)

local import: (string) -> any = ...
local Actions: typeof(require("./actions")) = import("game/actions")
local Constants: typeof(require("./constants")) = import("game/constants")
local Finder: typeof(require("./finder")) = import("game/finder")
local Inventory: typeof(require("./inventory")) = import("game/inventory")
local Packets: typeof(require("./packets")) = import("game/packets")
local World: typeof(require("./world")) = import("game/world")

local Chests = {}

export type Content = { instance: any, name: string, entityId: number?, quantity: number }

local ZERO = Vector3.new(0, 0, 0)
local MOVER = "BoogaUtilitiesChestMover"
local LIFT = 3
local ENTER = 3.5

local solid: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function partsOf(item: any): { any }
    local list: { any } = {}
    pcall(function()
        if item:IsA("BasePart") then
            table.insert(list, item)
        end
        for _, descendant in item:GetDescendants() do
            if descendant:IsA("BasePart") then
                table.insert(list, descendant)
            end
        end
    end)
    return list
end

local function ghost(item: any)
    for _, part in partsOf(item) do
        if solid[part] == nil then
            solid[part] = part.CanCollide
        end
        part.CanCollide = false
    end
end

local function restore(item: any)
    for _, part in partsOf(item) do
        local was = solid[part]
        if was ~= nil then
            part.CanCollide = was
            solid[part] = nil
        end
    end
end

local function resolve(chest: any): any
    if chest == nil then
        local nearest = Finder.nearestChest()
        return if nearest then nearest.instance else nil
    end
    if type(chest) == "table" and chest.instance ~= nil then
        return chest.instance
    end
    return chest
end

function Chests.contents(chest: any): { Content }
    local model = resolve(chest)
    local items: { Content } = {}
    local folder = if model then model:FindFirstChild("Contents") else nil
    if folder == nil then
        return items
    end
    for _, item in folder:GetChildren() do
        table.insert(items, {
            instance = item,
            name = item.Name,
            entityId = World.entityId(item),
            quantity = Inventory.quantityOf(item),
        })
    end
    return items
end

function Chests.count(chest: any, name: string): number
    local total = 0
    for _, item in Chests.contents(chest) do
        if Inventory.matches(name, item.name) then
            total += item.quantity
        end
    end
    return total
end

function Chests.dropPosition(chest: any): Vector3?
    local model = resolve(chest)
    if model == nil or model.Parent == nil then
        return nil
    end
    local folder = model:FindFirstChild("Contents")
    if folder then
        local total, count = Vector3.new(0, 0, 0), 0
        for _, item in folder:GetChildren() do
            local part = World.partOf(item)
            if part then
                total += part.Position
                count += 1
            end
        end
        if count > 0 then
            return total / count
        end
    end
    local ok, box = pcall(function()
        return model:GetBoundingBox()
    end)
    if ok and box then
        return box.Position
    end
    return World.positionOf(model)
end

function Chests.attract(item: any, chest: any): any
    local part = World.partOf(item)
    local destination = Chests.dropPosition(chest)
    if part == nil or destination == nil then
        return nil
    end
    local mover = part:FindFirstChild(MOVER)
    if mover == nil then
        mover = Instance.new("BodyPosition")
        mover.Name = MOVER
        mover.D = 1750
        mover.P = 42000
        mover.Parent = part
    end
    mover.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    local target = destination
    local model = resolve(chest)
    local ok, frame, size = pcall(function(): (any, any)
        return model:GetBoundingBox()
    end)
    if ok and frame ~= nil and size ~= nil then
        local flat = Vector3.new(part.Position.X - destination.X, 0, part.Position.Z - destination.Z).Magnitude
        if flat > ENTER then
            target = Vector3.new(destination.X, math.max(frame.Position.Y + size.Y / 2 + LIFT, destination.Y), destination.Z)
        end
    end
    mover.Position = target
    ghost(item)
    return mover
end

function Chests.release(item: any)
    restore(item)
    local part = World.partOf(item)
    local mover = if part then part:FindFirstChild(MOVER) else nil
    if mover then
        mover:Destroy()
    end
    if part then
        pcall(function()
            part.AssemblyLinearVelocity = Vector3.new(0, -1.5, 0)
            part.AssemblyAngularVelocity = ZERO
        end)
    end
end

function Chests.open(chest: any): boolean
    local entity = World.entityId(resolve(chest))
    return entity ~= nil and Packets.send("OpenChest", entity)
end

function Chests.take(chest: any, names: { string }?, limit: number?): number
    local ids: { number } = {}
    local model = resolve(chest)
    local folder = if model then model:FindFirstChild("Contents") else nil
    if folder ~= nil then
        for _, item in folder:GetChildren() do
            local wanted = names == nil
            if names then
                local itemName = item.Name
                for _, name in names do
                    if Inventory.matches(name, itemName) then
                        wanted = true
                        break
                    end
                end
            end
            if wanted then
                local entityId = World.entityId(item)
                if entityId then
                    table.insert(ids, entityId)
                    if limit and #ids >= limit then
                        break
                    end
                end
            end
        end
    end
    return Actions.pickup(ids, true)
end

function Chests.takeNearby(range: number?, names: { string }?, limit: number?): number
    local total = 0
    for _, entry in Finder.chests(range or 45) do
        total += Chests.take(entry.instance, names, if limit then limit - total else nil)
        if limit and total >= limit then
            break
        end
    end
    return total
end

function Chests.grab(item: any): boolean
    local entity = World.entityId(item)
    return entity ~= nil and Packets.send("ForceInteract", entity)
end

function Chests.isGold(item: any, wide: boolean?): boolean
    for _, name in Constants.GOLD_NAMES do
        if Inventory.matches(name, item.Name) then
            return true
        end
    end
    if wide == true then
        local lower = string.lower(item.Name)
        return string.find(lower, "gold", 1, true) ~= nil and string.find(lower, "bar", 1, true) ~= nil
    end
    return false
end

return Chests
end
modules["game/codec"] = function(...)

local Codec = {}

export type Writer = { data: buffer, size: number }
export type CFrameFormat = string

Codec.FORMATS = { "quat16", "euler16", "euler32" }

local function reserve(writer: Writer, count: number)
    local capacity = buffer.len(writer.data)
    local needed = writer.size + count
    if needed <= capacity then
        return
    end
    local grown = math.max(needed, capacity * 2, 16)
    local data = buffer.create(grown)
    buffer.copy(data, 0, writer.data, 0, writer.size)
    writer.data = data
end

function Codec.writer(capacity: number?): Writer
    return { data = buffer.create(math.max(capacity or 32, 1)), size = 0 }
end

function Codec.u8(writer: Writer, value: number)
    reserve(writer, 1)
    buffer.writeu8(writer.data, writer.size, value)
    writer.size += 1
end

function Codec.u16(writer: Writer, value: number)
    reserve(writer, 2)
    buffer.writeu16(writer.data, writer.size, value)
    writer.size += 2
end

function Codec.i16(writer: Writer, value: number)
    reserve(writer, 2)
    buffer.writei16(writer.data, writer.size, value)
    writer.size += 2
end

function Codec.u32(writer: Writer, value: number)
    reserve(writer, 4)
    buffer.writeu32(writer.data, writer.size, value)
    writer.size += 4
end

function Codec.f32(writer: Writer, value: number)
    reserve(writer, 4)
    buffer.writef32(writer.data, writer.size, value)
    writer.size += 4
end

function Codec.f64(writer: Writer, value: number)
    reserve(writer, 8)
    buffer.writef64(writer.data, writer.size, value)
    writer.size += 8
end

function Codec.bytes(writer: Writer, text: string)
    reserve(writer, #text)
    buffer.writestring(writer.data, writer.size, text)
    writer.size += #text
end

function Codec.text(writer: Writer, text: string)
    Codec.u16(writer, #text)
    Codec.bytes(writer, text)
end

function Codec.header(writer: Writer, id: number, flag: number?)
    Codec.u8(writer, if flag ~= nil then flag else math.floor(id / 256))
    Codec.u8(writer, id % 256)
end

function Codec.vlq(writer: Writer, value: number)
    local rest = math.floor(value)
    repeat
        local byte = rest % 128
        rest = math.floor(rest / 128)
        Codec.u8(writer, if rest > 0 then byte + 128 else byte)
    until rest == 0
end

function Codec.readVlq(data: buffer, offset: number): (number?, number)
    local value, shift, index = 0, 1, offset
    while index < buffer.len(data) and index - offset < 5 do
        local byte = buffer.readu8(data, index)
        value += (byte % 128) * shift
        shift *= 128
        index += 1
        if byte < 128 then
            return value, index
        end
    end
    return nil, index
end

function Codec.vector(writer: Writer, position: Vector3)
    Codec.f32(writer, position.X)
    Codec.f32(writer, position.Y)
    Codec.f32(writer, position.Z)
end

function Codec.half(value: number): number
    if value ~= value then
        return 0x7E00
    end
    local sign = 0
    if value < 0 or (value == 0 and 1 / value < 0) then
        sign = 0x8000
        value = -value
    end
    if value == math.huge then
        return sign + 0x7C00
    end
    if value == 0 then
        return sign
    end
    if value < 2 ^ -14 then
        local mantissa = math.floor(value / 2 ^ -24 + 0.5)
        if mantissa >= 1024 then
            return sign + 0x0400
        end
        return sign + mantissa
    end
    local mantissa, exponent = math.frexp(value)
    exponent -= 1
    local fraction = math.floor((mantissa * 2 - 1) * 1024 + 0.5)
    if fraction >= 1024 then
        fraction = 0
        exponent += 1
    end
    if exponent > 15 then
        return sign + 0x7C00
    end
    return sign + (exponent + 15) * 1024 + fraction
end

function Codec.unhalf(bits: number): number
    local sign = if bits >= 0x8000 then -1 else 1
    local exponent = math.floor(bits / 1024) % 32
    local fraction = bits % 1024
    if exponent == 0 then
        return sign * fraction * 2 ^ -24
    elseif exponent == 31 then
        return if fraction == 0 then sign * math.huge else 0 / 0
    end
    return sign * (1 + fraction / 1024) * 2 ^ (exponent - 15)
end

function Codec.quaternion(frame: CFrame): (number, number, number, number)
    local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = frame:GetComponents()
    local qx, qy, qz, qw
    local trace = r00 + r11 + r22
    if trace > 0 then
        local s = math.sqrt(trace + 1) * 2
        qw = 0.25 * s
        qx = (r21 - r12) / s
        qy = (r02 - r20) / s
        qz = (r10 - r01) / s
    elseif r00 > r11 and r00 > r22 then
        local s = math.sqrt(1 + r00 - r11 - r22) * 2
        qw = (r21 - r12) / s
        qx = 0.25 * s
        qy = (r01 + r10) / s
        qz = (r02 + r20) / s
    elseif r11 > r22 then
        local s = math.sqrt(1 + r11 - r00 - r22) * 2
        qw = (r02 - r20) / s
        qx = (r01 + r10) / s
        qy = 0.25 * s
        qz = (r12 + r21) / s
    else
        local s = math.sqrt(1 + r22 - r00 - r11) * 2
        qw = (r10 - r01) / s
        qx = (r02 + r20) / s
        qy = (r12 + r21) / s
        qz = 0.25 * s
    end
    local length = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
    if length <= 0 then
        return 0, 0, 0, 1
    end
    qx, qy, qz, qw = qx / length, qy / length, qz / length, qw / length
    if qw < 0 then
        qx, qy, qz, qw = -qx, -qy, -qz, -qw
    end
    return qx, qy, qz, qw
end

local function snorm(value: number): number
    return math.clamp(math.floor(value * 32767 + 0.5), -32768, 32767)
end

function Codec.cframe(writer: Writer, frame: CFrame, format: CFrameFormat)
    Codec.f32(writer, frame.X)
    Codec.f32(writer, frame.Y)
    Codec.f32(writer, frame.Z)
    if format == "quat16" then
        local qx, qy, qz = Codec.quaternion(frame)
        Codec.i16(writer, snorm(qx))
        Codec.i16(writer, snorm(qy))
        Codec.i16(writer, snorm(qz))
    elseif format == "euler16" then
        local rx, ry, rz = frame:ToEulerAnglesXYZ()
        Codec.u16(writer, Codec.half(rx))
        Codec.u16(writer, Codec.half(ry))
        Codec.u16(writer, Codec.half(rz))
    else
        local rx, ry, rz = frame:ToEulerAnglesXYZ()
        Codec.f32(writer, rx)
        Codec.f32(writer, ry)
        Codec.f32(writer, rz)
    end
end

function Codec.cframeSize(format: CFrameFormat): number
    return if format == "euler32" then 24 else 18
end

function Codec.finish(writer: Writer): buffer
    local data = buffer.create(writer.size)
    buffer.copy(data, 0, writer.data, 0, writer.size)
    return data
end

function Codec.concat(list: { buffer }): buffer
    local total = 0
    for _, part in list do
        total += buffer.len(part)
    end
    local data = buffer.create(total)
    local offset = 0
    for _, part in list do
        buffer.copy(data, offset, part, 0, buffer.len(part))
        offset += buffer.len(part)
    end
    return data
end

function Codec.hex(data: buffer): string
    local parts = table.create(buffer.len(data))
    for index = 0, buffer.len(data) - 1 do
        parts[index + 1] = string.format("%02X", buffer.readu8(data, index))
    end
    return table.concat(parts, " ")
end

function Codec.isUnsigned(value: any, bits: number): boolean
    return type(value) == "number" and value == value and value >= 0 and value < 2 ^ bits and math.floor(value) == value
end

return Codec
end
modules["game/constants"] = function(...)

local Constants = {}

Constants.VERSION = "1.0.0"
Constants.CACHE_FOLDER = "oklo scripts/boogautilities"
Constants.CACHE_FILE = "oklo scripts/boogautilities/packets.json"
Constants.LEARNED_FILE = "oklo scripts/boogautilities/learned.json"
Constants.REMOTE = "ByteNetReliable"
Constants.GLOBAL_PREFIX = "__BoogaUtilities"

Constants.PLACES = {
    Overworld = 11729688377,
    Void = 11879754496,
}

Constants.FOLDERS = {
    Resources = "Resources",
    Deployables = "Deployables",
    Items = "Items",
    DroppedItems = "DroppedItems",
    Critters = "Critters",
    Crops = "Crops",
    Players = "Players",
    Totems = "Totems",
    DialogNPCs = "DialogNPCs",
    MeteorParts = "MeteorParts",
    Rubble = "Rubble",
    UnbreakableResources = "UnbreakableResources",
}

Constants.ENTITY_ATTRIBUTES = { "EntityID", "NetworkId", "networkId", "NetworkID", "ID", "Id", "Eid", "EntityId", "entityId" }
Constants.QUANTITY_ATTRIBUTES = { "Count", "Amount", "Quantity", "Stack" }
Constants.ITEM_ID_ATTRIBUTES = { "ItemID", "itemID", "ID" }

Constants.MODULES = {
    Packets = "Packets",
    ItemIDS = "ItemIDS",
    GameUtil = "GameUtil",
    ColorData = "ColorData",
    ItemData = "ItemData",
}

Constants.PACKET_ID_MODULES = {
    { "ByteNet", "packets", "packetIDs" },
    { "ByteNet", "packets", "packetIds" },
    { "ByteNet", "packets", "PacketIDs" },
    { "ByteNet", "packetIDs" },
    { "ByteNet", "packetIds" },
    { "packetIDs" },
    { "packetIds" },
}

Constants.PACKET_ID_FIELDS = { "id", "Id", "_id", "packetId", "packetID", "ID" }

Constants.FALLBACK_IDS = {}

Constants.SEED_IDS = {}

Constants.LIMITS = {
    SwingTargets = 32,
    SwingTargetsSafe = 5,
    QueuePerFlush = 100,
    DropPerCall = 300,
    HarvestCooldown = 0.14,
    PurchaseDelay = 0.05,
    BoltBurst = 3,
    BoltDelay = 0.02,
    BoltVoodoo = 91,
    PressDelay = 0.04,
    PickupRange = 35,
    ChestRange = 15,
    PressRange = 20,
    CampfireRefill = 200,
}

Constants.SPEEDS = {
    Walk = 16,
    Path = 19,
    Cap = 21,
}

Constants.GUI = {
    Main = "MainGui",
    Topbar = "Topbar",
    Spawn = "SpawnGui",
    Floating = "FloatingBarsUI",
}

Constants.ANIMATIONS = {
    Swing = "rbxassetid://10761451679",
    IdleR6 = "rbxassetid://180435571",
    IdleR15 = "rbxassetid://507766666",
}

Constants.TEAMS = {
    NoTribe = "NoTribe",
}

Constants.ORES = { "Iron Node", "Coal Node", "Stone Node", "Adurite Node", "Gold Node", "Emerald Lode", "Pink Diamond Lode", "Crystal Lode" }

Constants.PLANT_FRUITS = {
    "Frostfruit", "Mango", "Watermelon", "Bloodfruit", "Bluefruit", "Lemon", "Coconut", "Jelly",
    "Banana", "Orange", "Oddberry", "Berry", "Strangefruit", "Strawberry", "Sunfruit", "Pumpkin",
    "Prickly Pear", "Apple", "Barley", "Cloudberry", "Carrot", "Corn", "Blossom",
}

Constants.HARVESTABLES = {
    "Bloodfruit", "Bluefruit", "Lemon", "Coconut", "Jelly", "Banana", "Orange",
    "Oddberry", "Berry", "Strangefruit", "Strawberry", "Sunfruit", "Pumpkin",
    "Prickly Pear", "Pear Cacti", "Apple", "Barley", "Cloudberry", "Carrot", "Corn", "Blossom",
    "Watermelon", "Mango", "Frostfruit",
}

Constants.FRUIT_IDS = {
    Bloodfruit = 94,
    Bluefruit = 377,
    Lemon = 99,
    Coconut = 1,
    Jelly = 604,
    Banana = 606,
    Orange = 602,
    Oddberry = 32,
    Berry = 35,
    Strangefruit = 302,
    Strawberry = 282,
    Sunfruit = 128,
    Pumpkin = 80,
    ["Prickly Pear"] = 378,
    Apple = 243,
    Barley = 247,
    Cloudberry = 101,
    Carrot = 147,
} :: { [string]: number }

Constants.TOOL_IDS = {
    ["God Axe"] = 454,
    ["God Pick"] = 132,
    ["Emerald Pick"] = 134,
    ["Pink Diamond Pick"] = 125,
    ["Void Pick"] = 496,
} :: { [string]: number }

Constants.FUELS = { "Wood", "Log", "Leaves", "Coal" }

Constants.GOLD_NAMES = { "Gold", "Gold Bar", "Gold_Bar", "Raw Gold", "Gold Ore" }
Constants.COOKED_GOLD_NAMES = { "Gold", "Gold Bar", "Gold_Bar" }
Constants.COIN_NAMES = { "Coin", "Coins", "Coin2", "Coin Stack" }
Constants.ITEM_ALIASES = {
    Leaves = { "Leaves", "Leaf" },
    Log = { "Log", "Logs" },
    Sunfruit = { "Sunfruit", "Sun Fruit" },
    Gold = { "Gold", "Gold Bar", "Gold_Bar" },
    ["Gold Bar"] = { "Gold Bar", "Gold", "Gold_Bar" },
} :: { [string]: { string } }

return Constants
end
modules["game/drive"] = function(...)

local import: (string) -> any = ...
local Constants: typeof(require("./constants")) = import("game/constants")
local World: typeof(require("./world")) = import("game/world")

local Drive = {}

local ZERO = Vector3.new(0, 0, 0)

local NAMES = { "BoogaUtilitiesAttachment", "BoogaUtilitiesVelocity", "BoogaUtilitiesOrientation" }
local LOOK_AHEAD = 4.25
local SIDE_OFFSETS = { -0.85, 0, 0.85 }
local LIFT_SPEED = 4.5
local LIFT_SECONDS = 0.16
local FLOOR_RAY = 16
local REBUILD_AFTER = 1

local builtAt = 0

type State = {
    root: any,
    humanoid: any,
    attachment: any,
    velocity: any,
    orientation: any,
    animate: any,
    animateDisabled: boolean?,
    idle: any,
    liftUntil: number,
    liftSpeed: number,
    pulling: boolean,
}

local state: State = {
    root = nil,
    humanoid = nil,
    attachment = nil,
    velocity = nil,
    orientation = nil,
    animate = nil,
    animateDisabled = nil,
    idle = nil,
    liftUntil = 0,
    liftSpeed = 0,
    pulling = false,
}

local ignored: { any } = {}

Drive.hover = 0.1

local loadedChecks: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function loadedByGame(module: any): boolean
    local known = loadedChecks[module]
    if known ~= nil then
        return known
    end
    local result = false
    local ok, list = pcall(function(): any
        return (getloadedmodules :: any)()
    end)
    if ok and type(list) == "table" then
        for _, item in list do
            if item == module then
                result = true
                break
            end
        end
    else
        result = true
    end
    loadedChecks[module] = result
    return result
end

function Drive.setControls(enabled: boolean)
    pcall(function()
        local player = World.LocalPlayer
        local scripts = player:FindFirstChild("PlayerScripts")
        local module = if scripts then scripts:FindFirstChild("PlayerModule") else nil
        if module and loadedByGame(module) then
            local loader: any = require
            local controls = loader(module):GetControls()
            if enabled then
                controls:Enable()
            else
                controls:Disable()
            end
        end
    end)
end

local cachedParams: any = nil
local cachedOwner: any = nil

local function build(root: any): any
    local exclude = { root.Parent }
    for _, item in ignored do
        table.insert(exclude, item)
    end
    local result = RaycastParams.new()
    result.FilterType = Enum.RaycastFilterType.Exclude
    result.FilterDescendantsInstances = exclude
    result.IgnoreWater = true
    pcall(function()
        result.RespectCanCollide = true
    end)
    return result
end

local function params(root: any): any
    local owner = root.Parent
    if cachedParams == nil or cachedOwner ~= owner or owner == nil then
        cachedParams = build(root)
        cachedOwner = owner
    end
    return cachedParams
end

local function raycast(origin: Vector3, direction: Vector3, rayParams: any): any
    return workspace:Raycast(origin, direction, rayParams)
end

local function cast(origin: Vector3, direction: Vector3, rayParams: any): any
    local ok, hit = pcall(raycast, origin, direction, rayParams)
    return if ok then hit else nil
end

function Drive.floorOffset(root: any): number?
    if root == nil then
        return nil
    end
    local rayParams = params(root)
    local humanoid = World.humanoidOf(root.Parent)
    local hip = if humanoid then tonumber(humanoid.HipHeight) or 2 else 2
    local half = if root.Size then root.Size.Y * 0.5 else 1
    local clearance = hip + half + Drive.hover
    local below = cast(root.Position + Vector3.new(0, 0.25, 0), Vector3.new(0, -FLOOR_RAY, 0), rayParams)
    if below and below.Normal.Y > 0.35 then
        return root.Position.Y - (below.Position.Y + clearance)
    end
    local above = cast(root.Position - Vector3.new(0, 0.25, 0), Vector3.new(0, FLOOR_RAY, 0), rayParams)
    if above and above.Normal.Y > 0.35 then
        return root.Position.Y - (above.Position.Y + clearance)
    end
    return nil
end

function Drive.obstacleLift(root: any, direction: Vector3): number?
    if direction.Magnitude <= 0.01 then
        return nil
    end
    local rayParams = params(root)
    local forward = direction.Unit * LOOK_AHEAD
    local sideways = Vector3.new(-direction.Z, 0, direction.X)
    local lower = root.Position - Vector3.new(0, 2.1, 0)
    local upper = root.Position + Vector3.new(0, 0.75, 0)
    local lowBlocked, highBlocked = false, false
    for _, lateral in SIDE_OFFSETS do
        local offset = sideways * lateral
        if cast(lower + offset, forward, rayParams) then
            lowBlocked = true
        end
        if cast(upper + offset, forward, rayParams) then
            highBlocked = true
        end
    end
    if highBlocked then
        state.liftSpeed = 0
        state.liftUntil = 0
    elseif lowBlocked then
        state.liftSpeed = LIFT_SPEED
        state.liftUntil = os.clock() + LIFT_SECONDS
    end
    if os.clock() < state.liftUntil then
        return state.liftSpeed
    end
    return nil
end

local function playIdle(humanoid: any, animate: any)
    pcall(function()
        for _, track in humanoid:GetPlayingAnimationTracks() do
            track:Stop(0.1)
        end
        local id: string? = nil
        local folder = if animate then (animate:FindFirstChild("idle") or animate:FindFirstChild("Idle")) else nil
        local configured = if folder then folder:FindFirstChildWhichIsA("Animation", true) else nil
        if configured then
            id = configured.AnimationId
        end
        if id == nil or id == "" then
            id = if humanoid.RigType == Enum.HumanoidRigType.R6 then Constants.ANIMATIONS.IdleR6 else Constants.ANIMATIONS.IdleR15
        end
        local animation = Instance.new("Animation")
        animation.AnimationId = id
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator == nil then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end
        local track = animator:LoadAnimation(animation)
        track.Looped = true
        track:Play(0.12, 1, 1)
        state.idle = track
    end)
end

function Drive.active(): boolean
    local root = state.root
    return root ~= nil and root.Parent ~= nil and state.velocity ~= nil and state.velocity.Parent == root
end

function Drive.begin(root: any): boolean
    if root == nil then
        return false
    end
    local humanoid = World.humanoidOf(root.Parent)
    if humanoid == nil then
        return false
    end
    if Drive.active() and state.root == root then
        return true
    end
    if state.root == root and os.clock() - builtAt < REBUILD_AFTER then
        return false
    end
    builtAt = os.clock()
    Drive.finish()
    state.root = root
    state.humanoid = humanoid
    local animate = root.Parent:FindFirstChild("Animate")
    state.animate = animate
    state.animateDisabled = if animate then animate.Disabled else nil
    if animate then
        animate.Disabled = true
    end
    playIdle(humanoid, animate)
    Drive.setControls(false)
    humanoid.Sit = false
    humanoid.AutoRotate = false
    humanoid.WalkSpeed = 0
    root.Anchored = false
    root.AssemblyLinearVelocity = ZERO
    root.AssemblyAngularVelocity = ZERO
    for _, name in NAMES do
        local stale = root:FindFirstChild(name)
        if stale then
            stale:Destroy()
        end
    end
    local attachment = Instance.new("Attachment")
    attachment.Name = NAMES[1]
    attachment.Parent = root
    local velocity = Instance.new("LinearVelocity")
    velocity.Name = NAMES[2]
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    velocity.VectorVelocity = ZERO
    pcall(function()
        velocity.ForceLimitsEnabled = false
    end)
    pcall(function()
        velocity.MaxForce = math.huge
    end)
    velocity.Parent = root
    local orientation = Instance.new("AlignOrientation")
    orientation.Name = NAMES[3]
    orientation.Attachment0 = attachment
    orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orientation.CFrame = root.CFrame - root.Position
    orientation.RigidityEnabled = true
    orientation.Responsiveness = 200
    orientation.MaxTorque = math.huge
    orientation.Parent = root
    state.attachment = attachment
    state.velocity = velocity
    state.orientation = orientation
    return true
end

local function blend(direction: Vector3, vertical: number, speed: number): Vector3
    local forward = math.sqrt(math.max(speed * speed - vertical * vertical, 0))
    return direction * forward + Vector3.new(0, vertical, 0)
end

function Drive.step(target: Vector3, speed: number): boolean
    local root = World.root()
    if root == nil or not Drive.begin(root) then
        return false
    end
    local offset = target - root.Position
    if offset.Magnitude <= 0.01 then
        state.velocity.VectorVelocity = ZERO
        return true
    end
    local velocity = offset.Unit * speed
    local flat = Vector3.new(offset.X, 0, offset.Z)
    local heading = if flat.Magnitude > 0.01 then flat.Unit else root.CFrame.LookVector
    if flat.Magnitude > 0.01 then
        local lift = Drive.obstacleLift(root, heading)
        if lift and lift > velocity.Y then
            velocity = blend(heading, math.min(lift, speed - 0.1), speed)
        end
    end
    local floor = Drive.floorOffset(root)
    if floor == nil then
        state.pulling = false
    elseif floor < -0.35 then
        state.pulling = false
        velocity = blend(heading, math.min(8, 2 + -floor * 4), speed)
    elseif state.pulling then
        if floor <= 0.1 then
            state.pulling = false
        end
    elseif floor > 0.45 and velocity.Y <= 1 then
        state.pulling = true
    end
    if state.pulling and floor then
        velocity = blend(heading, -math.min(12, 6 + math.max(floor - 0.45, 0) * 4), speed)
    end
    state.velocity.VectorVelocity = velocity
    return true
end

function Drive.turn(rotation: CFrame): boolean
    local root = state.root
    if root == nil or root.Parent == nil or state.orientation == nil then
        return false
    end
    state.orientation.CFrame = rotation
    root.CFrame = CFrame.new(root.Position) * rotation
    return true
end

function Drive.halt()
    if state.velocity ~= nil and state.velocity.Parent ~= nil then
        state.velocity.VectorVelocity = ZERO
    end
    local root = state.root
    if root ~= nil and root.Parent ~= nil then
        root.AssemblyLinearVelocity = ZERO
        root.AssemblyAngularVelocity = ZERO
    end
    state.pulling = false
end

function Drive.finish()
    Drive.halt()
    for _, mover in { state.velocity, state.orientation, state.attachment } do
        pcall(function()
            mover:Destroy()
        end)
    end
    if state.idle then
        pcall(function()
            state.idle:Stop(0.12)
        end)
    end
    local humanoid = state.humanoid
    if humanoid ~= nil and humanoid.Parent ~= nil then
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        humanoid.WalkSpeed = Constants.SPEEDS.Walk
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end
    local animate = state.animate
    if animate ~= nil and animate.Parent ~= nil then
        animate.Disabled = state.animateDisabled == true
    end
    if state.root ~= nil then
        Drive.setControls(true)
    end
    state.root = nil
    state.humanoid = nil
    state.attachment = nil
    state.velocity = nil
    state.orientation = nil
    state.animate = nil
    state.animateDisabled = nil
    state.idle = nil
    state.liftUntil = 0
    state.liftSpeed = 0
    state.pulling = false
    cachedParams = nil
    cachedOwner = nil
end

function Drive.camera()
    local camera = workspace.CurrentCamera
    local humanoid = World.humanoid()
    if camera and humanoid then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = humanoid
    end
end

return Drive
end
modules["game/finder"] = function(...)

local import: (string) -> any = ...
local Constants: typeof(require("./constants")) = import("game/constants")
local World: typeof(require("./world")) = import("game/world")

local Finder = {}

type Entry = { instance: any, name: string, entityId: number?, position: Vector3, distance: number }
type Query = {
    origin: Vector3?,
    range: number?,
    names: { string }?,
    contains: { string }?,
    match: ((any) -> boolean)?,
    requireId: boolean?,
    minimumId: number?,
    deepId: boolean?,
    limit: number?,
}

export type PlayerEntry = {
    player: any,
    character: any,
    root: any,
    humanoid: any,
    entityId: number?,
    position: Vector3,
    distance: number,
    health: number,
    maxHealth: number,
    ally: boolean,
    god: boolean,
}
export type PlayerQuery = { range: number?, origin: Vector3?, skipAllies: boolean?, skipDead: boolean?, skipGods: boolean?, tribes: { [string]: any }?, maxHeight: number? }

local function query(range: number?, extra: Query?): Query
    local result: Query = if extra then table.clone(extra) else {}
    if range then
        result.range = range
    end
    return result
end

local function first(list: { Entry }): Entry?
    return list[1]
end

local RESOURCE_MAX_AGE = 2

local resourceFolder: any = nil
local resourceLinks: { any } = {}
local resourceCache: { any } = {}
local resourceDirty = true
local resourceBuiltAt = 0

local function markResources()
    resourceDirty = true
end

local function unwatchResources()
    for _, link in resourceLinks do
        pcall(function()
            link:Disconnect()
        end)
    end
    table.clear(resourceLinks)
    resourceFolder = nil
    resourceCache = {}
    resourceDirty = true
    resourceBuiltAt = 0
end

local function scanResources(resources: any): { any }
    local list: { any } = {}
    for _, child in resources:GetChildren() do
        if child:IsA("Model") then
            table.insert(list, child)
        end
        local breakaway = child:FindFirstChild("Breakaway")
        if breakaway then
            for _, nested in breakaway:GetChildren() do
                if nested:IsA("Model") then
                    table.insert(list, nested)
                end
            end
        end
    end
    return list
end

function Finder.reset()
    unwatchResources()
end

function Finder.resourceModels(): { any }
    local list: { any } = {}
    local resources = World.folder("Resources")
    if resources then
        if resources ~= resourceFolder then
            unwatchResources()
            resourceFolder = resources
            table.insert(resourceLinks, resources.DescendantAdded:Connect(markResources))
            table.insert(resourceLinks, resources.DescendantRemoving:Connect(markResources))
        end
        local now = os.clock()
        if resourceDirty or now - resourceBuiltAt >= RESOURCE_MAX_AGE then
            resourceDirty = false
            resourceBuiltAt = now
            resourceCache = scanResources(resources)
        end
        for _, model in resourceCache do
            if model.Parent ~= nil then
                table.insert(list, model)
            end
        end
    elseif resourceFolder ~= nil then
        unwatchResources()
    end
    local space = World.workspace()
    if space then
        for _, child in space:GetChildren() do
            if child.Name == "Gold Node" and child:IsA("Model") then
                table.insert(list, child)
            end
        end
    end
    return list
end

function Finder.resources(range: number?, extra: Query?): { Entry }
    local options = query(range, extra)
    options.requireId = true
    return World.collect(Finder.resourceModels(), options)
end

function Finder.items(range: number?, names: { string }?): { Entry }
    return World.collect(World.children(World.itemsFolder(), false), query(range, { names = names, requireId = true }))
end

function Finder.coins(range: number?): { Entry }
    return Finder.items(range, Constants.COIN_NAMES)
end

function Finder.deployables(range: number?, extra: Query?): { Entry }
    return World.collect(World.children(World.folder("Deployables"), false), query(range, extra))
end

function Finder.isChest(model: any): boolean
    if model == nil or not model:IsA("Model") or model:FindFirstChild("Contents") == nil then
        return false
    end
    local name = model.Name
    if string.find(name, "Plant Box", 1, true) then
        return false
    end
    return string.find(name, "Chest", 1, true) ~= nil or string.find(name, "Box", 1, true) ~= nil
end

function Finder.chests(range: number?): { Entry }
    return Finder.deployables(range, { match = Finder.isChest })
end

function Finder.nearestChest(range: number?): Entry?
    return first(Finder.chests(range or Constants.LIMITS.ChestRange))
end

function Finder.chestFromPart(part: any): any
    local deployables = World.folder("Deployables")
    local current = part
    local space = World.workspace()
    while current ~= nil and current ~= space do
        if Finder.isChest(current) and (deployables == nil or current:IsDescendantOf(deployables)) then
            return current
        end
        current = current.Parent
    end
    return nil
end

function Finder.isPlanted(box: any): boolean
    return box ~= nil and box:FindFirstChild("Seed") ~= nil
end

function Finder.plantBoxes(range: number?, emptyOnly: boolean?): { Entry }
    return Finder.deployables(range, {
        names = { "Plant Box" },
        requireId = true,
        match = function(model: any): boolean
            return not emptyOnly or not Finder.isPlanted(model)
        end,
    })
end

function Finder.bushes(range: number?, fruit: string?): { Entry }
    local folders: { any } = {}
    local crops = World.folder("Crops")
    if crops then
        table.insert(folders, crops)
    else
        table.insert(folders, World.folder("Resources"))
        table.insert(folders, World.folder("Deployables"))
    end
    local list: { any } = {}
    for _, folder in folders do
        for _, model in World.children(folder, true) do
            table.insert(list, model)
        end
    end
    local contains = if fruit and fruit ~= "" and fruit ~= "All" then { fruit } else Constants.HARVESTABLES
    return World.collect(list, query(range, {
        contains = contains,
        requireId = true,
        deepId = true,
        match = function(model: any): boolean
            return model:IsA("Model") and model.Name ~= "Plant Box"
        end,
    }))
end

function Finder.coinPresses(range: number?): { Entry }
    return Finder.deployables(range, { contains = { "Coin Press", "CoinPress" }, requireId = true })
end

function Finder.nearestCoinPress(range: number?): Entry?
    return first(Finder.coinPresses(range or Constants.LIMITS.PressRange))
end

function Finder.campfires(range: number?): { Entry }
    return Finder.deployables(range, { contains = { "campfire" }, requireId = true })
end

function Finder.campfireFuel(model: any): number?
    if model == nil then
        return nil
    end
    local board = model:FindFirstChild("Board")
    local billboard = if board then board:FindFirstChild("Billboard") else nil
    local backdrop = if billboard then billboard:FindFirstChild("Backdrop") else nil
    local label = if backdrop then backdrop:FindFirstChild("TextLabel") else nil
    local value = if label then tonumber(string.match(tostring(label.Text), "%d+%.?%d*")) else nil
    if value then
        return value
    end
    for _, key in { "Fuel", "FuelAmount", "Fire" } do
        local attribute = tonumber(model:GetAttribute(key))
        if attribute then
            return attribute
        end
    end
    return nil
end

return Finder
end
modules["game/inventory"] = function(...)

local import: (string) -> any = ...
local Constants: typeof(require("./constants")) = import("game/constants")
local Modules: typeof(require("./modules")) = import("game/modules")
local World: typeof(require("./world")) = import("game/world")

local Inventory = {}

export type Slot = { name: string, layout: number, quantity: number, frame: any }
export type Topbar = { coins: number?, mojo: number?, level: number?, exp: string? }

local idCache: { [string]: number }? = nil
local nameCache: { [number]: string } = {}
local idsReadAt = 0

local function child(node: any, path: { string }): any
    for _, name in path do
        if node == nil then
            return nil
        end
        node = node:FindFirstChild(name)
    end
    return node
end

function Inventory.playerGui(): any
    local player = World.LocalPlayer
    return if player then player:FindFirstChild("PlayerGui") else nil
end

function Inventory.mainGui(): any
    return child(Inventory.playerGui(), { Constants.GUI.Main })
end

function Inventory.list(): any
    return child(Inventory.mainGui(), { "RightPanel", "Inventory", "List" })
end

function Inventory.parseNumber(text: any): number?
    local raw = string.gsub(tostring(text or ""), ",", "")
    local number, suffix = string.match(raw, "(%-?%d+%.?%d*)%s*([KkMmBb]?)")
    local value = tonumber(number)
    if value == nil then
        return nil
    end
    local scale = ({ k = 1e3, m = 1e6, b = 1e9 } :: { [string]: number })[string.lower(suffix or "")]
    return if scale then value * scale else value
end

function Inventory.quantityOf(frame: any): number
    for _, key in Constants.QUANTITY_ATTRIBUTES do
        local attribute = tonumber(frame:GetAttribute(key))
        if attribute then
            return math.max(0, attribute)
        end
        local value = frame:FindFirstChild(key)
        if value and value:IsA("ValueBase") and tonumber(value.Value) then
            return math.max(0, tonumber(value.Value) :: number)
        end
    end
    local text = child(frame, { "QuantityImage", "QuantityText" })
    if text then
        local amount = tonumber((string.gsub(tostring(text.Text), "%D", "")))
        if amount and amount > 0 then
            return amount
        end
    end
    return 1
end

function Inventory.normalize(name: any): string
    return World.normalize(name)
end

function Inventory.matches(wanted: string, actual: string): boolean
    local target = World.normalize(actual)
    if World.normalize(wanted) == target then
        return true
    end
    local aliases: { string } = Constants.ITEM_ALIASES[wanted] or {}
    for _, alias in aliases do
        if World.normalize(alias) == target then
            return true
        end
    end
    return false
end

function Inventory.items(): { Slot }
    local list = Inventory.list()
    local slots: { Slot } = {}
    if list == nil then
        return slots
    end
    for _, frame in list:GetChildren() do
        if frame:IsA("ImageLabel") or frame:IsA("ImageButton") then
            table.insert(slots, { name = frame.Name, layout = frame.LayoutOrder, quantity = Inventory.quantityOf(frame), frame = frame })
        end
    end
    table.sort(slots, function(a, b)
        return a.layout < b.layout
    end)
    return slots
end

function Inventory.slots(name: string): { Slot }
    local found: { Slot } = {}
    for _, slot in Inventory.items() do
        if Inventory.matches(name, slot.name) then
            table.insert(found, slot)
        end
    end
    return found
end

function Inventory.find(name: string): Slot?
    return Inventory.slots(name)[1]
end

function Inventory.layout(name: string): number?
    local slot = Inventory.find(name)
    return if slot then slot.layout else nil
end

function Inventory.count(name: string): number
    local total = 0
    for _, slot in Inventory.slots(name) do
        total += slot.quantity
    end
    return total
end

function Inventory.has(name: string, amount: number?): boolean
    return Inventory.count(name) >= (amount or 1)
end

function Inventory.names(): { string }
    local names: { string } = {}
    local seen: { [string]: boolean } = {}
    for _, slot in Inventory.items() do
        if not seen[slot.name] then
            seen[slot.name] = true
            table.insert(names, slot.name)
        end
    end
    table.sort(names)
    return names
end

function Inventory.ready(): boolean
    return Inventory.list() ~= nil
end

local function readIds(): { [string]: number }
    local map: { [string]: number } = {}
    local module = Modules.get(Constants.MODULES.ItemIDS)
    if type(module) == "table" then
        for key, value in module do
            if type(key) == "string" and type(value) == "number" then
                map[key] = value
            elseif type(key) == "number" and type(value) == "string" then
                map[value] = key
            end
        end
    else
        local folder = Modules.find({ Constants.MODULES.ItemIDS })
        if folder ~= nil and not folder:IsA("ModuleScript") then
            for _, value in folder:GetChildren() do
                if value:IsA("ValueBase") and tonumber(value.Value) then
                    map[value.Name] = tonumber(value.Value) :: number
                end
            end
        end
    end
    return map
end

function Inventory.itemIds(): { [string]: number }
    if idCache == nil or (next(idCache) == nil and os.clock() - idsReadAt >= 5) then
        idsReadAt = os.clock()
        idCache = readIds()
        table.clear(nameCache)
        for name, id in idCache :: { [string]: number } do
            nameCache[id] = name
        end
    end
    return idCache :: { [string]: number }
end

local function guiItemId(name: string): number?
    local slot = Inventory.find(name)
    if slot == nil then
        return nil
    end
    for _, key in Constants.ITEM_ID_ATTRIBUTES do
        local value = tonumber(slot.frame:GetAttribute(key))
        if value then
            return value
        end
    end
    return nil
end

function Inventory.itemId(name: string): number?
    local ids = Inventory.itemIds()
    if ids[name] then
        return ids[name]
    end
    local aliases: { string } = Constants.ITEM_ALIASES[name] or {}
    for _, alias in aliases do
        if ids[alias] then
            return ids[alias]
        end
    end
    return guiItemId(name) or Constants.FRUIT_IDS[name] or Constants.TOOL_IDS[name]
end

function Inventory.seedId(fruit: string): number?
    local ids = Inventory.itemIds()
    return ids[fruit .. " Seed"] or Inventory.itemId(fruit)
end

function Inventory.toolbar(): { [number]: string }
    local slots: { [number]: string } = {}
    local util = Modules.get(Constants.MODULES.GameUtil)
    local data = if util then util.Data else nil
    local toolbar = if type(data) == "table" then data.toolbar else nil
    if type(toolbar) ~= "table" then
        return slots
    end
    for index = 1, 9 do
        local entry = toolbar[index]
        if type(entry) == "table" and type(entry.name) == "string" then
            slots[index] = entry.name
        end
    end
    return slots
end

function Inventory.equipped(): { any }
    local tools: { any } = {}
    local character = World.character()
    if character == nil then
        return tools
    end
    local folder = character:FindFirstChild("Tools")
    if folder then
        for _, tool in folder:GetChildren() do
            table.insert(tools, tool)
        end
    end
    for _, item in character:GetChildren() do
        if item:IsA("Tool") then
            table.insert(tools, item)
        end
    end
    return tools
end

function Inventory.equippedName(): string?
    local tool = Inventory.equipped()[1]
    return if tool then tool.Name else nil
end

function Inventory.bar(name: string): number?
    local label = child(Inventory.mainGui(), { "Panels", "Stats", "Bars", name, "ValueLabel" })
    return if label then Inventory.parseNumber(label.Text) else nil
end

local function percent(value: any, maximum: any): number?
    local current, top = tonumber(value), tonumber(maximum)
    if current == nil then
        return nil
    end
    if top and top > 0 then
        return math.clamp(current / top * 100, 0, 100)
    end
    return math.clamp(current, 0, 100)
end

function Inventory.hunger(): number
    local bar = Inventory.bar("Hunger")
    if bar then
        return bar
    end
    local player = World.LocalPlayer
    local stats = if player then child(player, { "PlayerFolder", "Stats" }) else nil
    local hunger = if stats then stats:FindFirstChild("Hunger") else nil
    if hunger and hunger:IsA("ValueBase") then
        local maximum = stats:FindFirstChild("MaxHunger")
        return percent(hunger.Value, if maximum then maximum.Value else nil) or 100
    end
    local character = World.character()
    if character and character:GetAttribute("Hunger") ~= nil then
        return percent(character:GetAttribute("Hunger"), character:GetAttribute("MaxHunger")) or 100
    end
    return 100
end

function Inventory.health(): (number?, number?)
    local humanoid = World.humanoid()
    if humanoid == nil then
        return nil, nil
    end
    return humanoid.Health, humanoid.MaxHealth
end

function Inventory.healthPercent(): number?
    local health, maximum = Inventory.health()
    return percent(health, maximum)
end

function Inventory.topbar(): Topbar
    local root = child(Inventory.playerGui(), { Constants.GUI.Topbar, "Topbar" })
    local coins = child(root, { "Left", "Coins", "Label" })
    local mojo = child(root, { "Left", "Mojo", "Label" })
    local level = child(root, { "Right", "Level", "Level" })
    local exp = child(root, { "Right", "Level", "Exp" })
    return {
        coins = if coins then Inventory.parseNumber(coins.Text) else nil,
        mojo = if mojo then Inventory.parseNumber(mojo.Text) else nil,
        level = if level then Inventory.parseNumber(level.Text) else nil,
        exp = if exp then tostring(exp.Text) else nil,
    }
end

function Inventory.level(): number?
    return Inventory.topbar().level
end

return Inventory
end
modules["game/learned"] = function(...)

local import: (string) -> any = ...
local Constants: typeof(require("./constants")) = import("game/constants")
local Modules: typeof(require("./modules")) = import("game/modules")

local Learned = {}

export type Entry = { name: string, confirmed: boolean, id: number?, version: string? }

local entries: { [string]: Entry } = {}
local loaded = false

local function json(): any
    return Modules.service("HttpService")
end

local function read()
    loaded = true
    table.clear(entries)
    local ok, result = pcall(function()
        if not isfile(Constants.LEARNED_FILE) then
            return nil
        end
        return json():JSONDecode(readfile(Constants.LEARNED_FILE))
    end)
    if not ok or type(result) ~= "table" or type(result.names) ~= "table" then
        return
    end
    for logical, entry in result.names do
        if type(logical) == "string" and type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" then
            entries[logical] = {
                name = entry.name,
                confirmed = entry.confirmed == true,
                id = if type(entry.id) == "number" then entry.id else nil,
                version = if entry.version ~= nil then tostring(entry.version) else nil,
            }
        end
    end
end

local function write()
    pcall(function()
        if not isfolder("oklo scripts") then
            makefolder("oklo scripts")
        end
        if not isfolder(Constants.CACHE_FOLDER) then
            makefolder(Constants.CACHE_FOLDER)
        end
        writefile(Constants.LEARNED_FILE, json():JSONEncode({ version = 1, savedAt = os.time(), names = entries }))
    end)
end

function Learned.get(logical: string): Entry?
    if not loaded then
        read()
    end
    return entries[logical]
end

function Learned.set(logical: string, name: string, confirmed: boolean, id: number?, version: string?): boolean
    if not loaded then
        read()
    end
    local current = entries[logical]
    if current ~= nil and current.name == name and current.id == id and current.version == version and (current.confirmed or not confirmed) then
        return false
    end
    entries[logical] = { name = name, confirmed = confirmed, id = id, version = version }
    write()
    return true
end

function Learned.clear(): boolean
    table.clear(entries)
    loaded = true
    local ok = pcall(function()
        if isfile(Constants.LEARNED_FILE) then
            delfile(Constants.LEARNED_FILE)
        end
    end)
    return ok
end

return Learned
end
modules["game/modules"] = function(...)

local Modules = {}

local services: { [string]: any } = {}
local loaded: { [string]: any } = {}
local failures: { [string]: string } = {}

function Modules.service(name: string): any
    local cached = services[name]
    if cached ~= nil then
        return cached
    end
    local ok, result = pcall(function()
        return game:GetService(name)
    end)
    if ok and result ~= nil then
        services[name] = result
        return result
    end
    return nil
end

function Modules.folder(): any
    local storage = Modules.service("ReplicatedStorage")
    if not storage then
        return nil
    end
    return storage:FindFirstChild("Modules")
end

local index: { [string]: any }? = nil

local function child(node: any, name: string): any
    local direct = node:FindFirstChild(name)
    if direct then
        return direct
    end
    local lower = string.lower(name)
    for _, item in node:GetChildren() do
        if string.lower(item.Name) == lower then
            return item
        end
    end
    return nil
end

local function build(): { [string]: any }
    local map: { [string]: any } = {}
    local depth: { [string]: number } = {}
    local root = Modules.folder()
    if root then
        local ok, items = pcall(function(): { any }
            return root:GetDescendants()
        end)
        if ok then
            for _, item in items do
                if item:IsA("ModuleScript") then
                    local key = string.lower(item.Name)
                    local level = #string.split(item:GetFullName(), ".")
                    if map[key] == nil or level < (depth[key] or 0) then
                        map[key] = item
                        depth[key] = level
                    end
                end
            end
        end
    end
    return map
end

local found: { [string]: any } = {}
local missedAt: { [string]: number } = {}
local failedAt: { [string]: number } = {}
local RETRY = 10
local indexAt = 0

local function search(path: { string }): any
    local node = Modules.folder()
    for position, name in path do
        if not node then
            return nil
        end
        local match = child(node, name)
        if match == nil and position == 1 then
            if index == nil or os.clock() - indexAt >= RETRY then
                index = build()
                indexAt = os.clock()
            end
            match = (index :: { [string]: any })[string.lower(name)]
        end
        node = match
    end
    return node
end

function Modules.find(path: { string }): any
    local key = table.concat(path, "/")
    local cached = found[key]
    if cached ~= nil and cached.Parent ~= nil then
        return cached
    end
    found[key] = nil
    local missed = missedAt[key]
    if missed ~= nil and os.clock() - missed < RETRY then
        return nil
    end
    local result = search(path)
    if result ~= nil then
        found[key] = result
        missedAt[key] = nil
    else
        missedAt[key] = os.clock()
    end
    return result
end

function Modules.load(instance: any): (boolean, any)
    if instance == nil then
        return false, "module is missing"
    end
    local ok, result = pcall(require, instance)
    if not ok then
        return false, tostring(result)
    end
    return true, result
end

function Modules.get(name: string): any
    local cached = loaded[name]
    if cached ~= nil then
        return cached
    end
    local failed = failedAt[name]
    if failed ~= nil and os.clock() - failed < RETRY then
        return nil
    end
    local instance = Modules.find({ name })
    if instance == nil then
        failures[name] = "ReplicatedStorage.Modules." .. name .. " is missing"
        failedAt[name] = os.clock()
        return nil
    end
    local ok, result = Modules.load(instance)
    if not ok or type(result) ~= "table" then
        failures[name] = if ok then "module did not return a table" else tostring(result)
        failedAt[name] = os.clock()
        return nil
    end
    failures[name] = nil
    failedAt[name] = nil
    loaded[name] = result
    return result
end

function Modules.reset()
    table.clear(loaded)
    table.clear(failures)
    table.clear(found)
    table.clear(missedAt)
    table.clear(failedAt)
    index = nil
end

return Modules
end
modules["game/movement"] = function(...)

local import: (string) -> any = ...
local Constants: typeof(require("./constants")) = import("game/constants")
local Drive: typeof(require("./drive")) = import("game/drive")
local Modules: typeof(require("./modules")) = import("game/modules")
local World: typeof(require("./world")) = import("game/world")

local Movement = {}

export type Point = { position: Vector3, wait: number? }
export type PathOptions = {
    speed: number?,
    loop: boolean?,
    tolerance: number?,
    hover: number?,
    start: number?,
    stuckRadius: number?,
    stuckSeconds: number?,
    onReach: ((index: number, point: Point) -> ())?,
    onStuck: (() -> ())?,
    paused: (() -> boolean)?,
}
export type Runner = { stop: () -> (), running: () -> boolean, index: () -> number }
export type Detector = { update: (position: Vector3?) -> boolean, reset: (position: Vector3?) -> (), elapsed: () -> number }

local ZERO = Vector3.new(0, 0, 0)
local STEP = 0.05
local TOLERANCE = 1.15

local speedCap = Constants.SPEEDS.Cap
local tween: any = nil
local noclipLink: any = nil
local noclipParts: { [any]: boolean } = {}
local freezeLink: any = nil
local freezeRoot: any = nil
local freezeAnchored = false
local runners: { [Runner]: boolean } = {}
local walkVelocity: any = nil
local walkGyro: any = nil

Movement.drive = Drive

function Movement.clampSpeed(speed: number?): number
    return math.clamp(speed or Constants.SPEEDS.Path, 1, speedCap)
end

function Movement.cancelTween()
    if tween ~= nil then
        pcall(function()
            tween:Cancel()
        end)
        tween = nil
    end
end

function Movement.tweenToCFrame(target: CFrame, speed: number?): any
    local root = World.root()
    local service = Modules.service("TweenService")
    if root == nil or service == nil then
        return nil
    end
    Movement.cancelTween()
    local duration = (root.Position - target.Position).Magnitude / Movement.clampSpeed(speed)
    local ok, created = pcall(function()
        return service:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = target })
    end)
    if not ok or created == nil then
        return nil
    end
    tween = created
    created:Play()
    return created
end

function Movement.stopSmoothWalk()
    for _, mover in { walkVelocity, walkGyro } do
        pcall(function()
            mover:Destroy()
        end)
    end
    walkVelocity = nil
    walkGyro = nil
end

local function restoreCollision()
    for part, collide in noclipParts do
        if part.Parent ~= nil then
            part.CanCollide = collide
        end
    end
    table.clear(noclipParts)
end

function Movement.setNoclip(enabled: boolean)
    if noclipLink ~= nil then
        noclipLink:Disconnect()
        noclipLink = nil
    end
    if not enabled then
        restoreCollision()
        return
    end
    local run = Modules.service("RunService")
    if run == nil then
        return
    end
    noclipLink = run.Stepped:Connect(function()
        local character = World.character()
        if character == nil then
            return
        end
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") and part.CanCollide then
                if noclipParts[part] == nil then
                    noclipParts[part] = true
                end
                part.CanCollide = false
            end
        end
    end)
end

function Movement.unfreeze()
    if freezeLink ~= nil then
        freezeLink:Disconnect()
        freezeLink = nil
    end
    if freezeRoot ~= nil then
        local root = freezeRoot
        freezeRoot = nil
        pcall(function()
            root.Anchored = freezeAnchored
        end)
    end
end

function Movement.freeze(): boolean
    local root = World.root()
    local run = Modules.service("RunService")
    if root == nil or run == nil then
        return false
    end
    Movement.unfreeze()
    Movement.cancelTween()
    Drive.halt()
    local locked = root.CFrame
    freezeRoot = root
    freezeAnchored = root.Anchored
    root.Anchored = true
    freezeLink = run.Heartbeat:Connect(function()
        local current = World.root()
        if current ~= root then
            Movement.unfreeze()
            return
        end
        root.AssemblyLinearVelocity = ZERO
        root.AssemblyAngularVelocity = ZERO
        if (root.Position - locked.Position).Magnitude > 0.05 then
            root.CFrame = locked
        end
        local humanoid = World.humanoidOf(root.Parent)
        if humanoid then
            humanoid.Jump = false
            humanoid:Move(ZERO, false)
        end
    end)
    return true
end

function Movement.isFrozen(): boolean
    return freezeLink ~= nil
end

local groundParams: any = nil
local groundCharacter: any = nil

function Movement.groundBelow(position: Vector3, depth: number?): (Vector3?, any)
    local character = World.character()
    if groundParams == nil or groundCharacter ~= character then
        local created = RaycastParams.new()
        created.FilterType = Enum.RaycastFilterType.Exclude
        created.FilterDescendantsInstances = { character }
        groundParams = created
        groundCharacter = character
    end
    local rayParams = groundParams
    local ok, hit = pcall(function()
        return workspace:Raycast(position, Vector3.new(0, -(depth or 100), 0), rayParams)
    end)
    if ok and hit then
        return hit.Position, hit.Instance
    end
    return nil, nil
end

function Movement.stuckDetector(radius: number?, seconds: number?): Detector
    local distance = radius or 10
    local limit = seconds or 40
    local anchor: Vector3? = World.position()
    local since = os.clock()
    local detector: Detector
    detector = {
        reset = function(position: Vector3?)
            anchor = position or World.position()
            since = os.clock()
        end,
        elapsed = function(): number
            return os.clock() - since
        end,
        update = function(position: Vector3?): boolean
            local current = position or World.position()
            if current == nil then
                return false
            end
            if anchor == nil or (current - (anchor :: Vector3)).Magnitude >= distance then
                detector.reset(current)
                return false
            end
            return os.clock() - since >= limit
        end,
    }
    return detector
end

function Movement.nearestIndex(points: { Point }, position: Vector3): number
    local best, bestDistance = 1, math.huge
    for index, point in points do
        local distance = (point.position - position).Magnitude
        if distance < bestDistance then
            best, bestDistance = index, distance
        end
    end
    return best
end

function Movement.followPath(points: { Point }, options: PathOptions?): Runner
    local settings: PathOptions = options or {}
    local active = true
    local current = settings.start or 0
    local runner: Runner
    runner = {
        stop = function()
            active = false
        end,
        running = function(): boolean
            return active
        end,
        index = function(): number
            return current
        end,
    }
    runners[runner] = true
    task.spawn(function()
        local hover = settings.hover or Drive.hover
        local tolerance = settings.tolerance or TOLERANCE
        local speed = Movement.clampSpeed(settings.speed)
        local detector = Movement.stuckDetector(settings.stuckRadius, settings.stuckSeconds)
        local waitUntil: number? = nil
        while active and #points > 0 do
            local root = World.root()
            if root == nil or not World.isSpawned() or (settings.paused and settings.paused()) then
                Drive.halt()
                detector.reset()
                waitUntil = nil
            else
                if current < 1 or current > #points then
                    current = Movement.nearestIndex(points, root.Position)
                end
                local point = points[current]
                local target = point.position + Vector3.new(0, hover, 0)
                if (root.Position - target).Magnitude <= tolerance then
                    if waitUntil == nil then
                        waitUntil = os.clock() + math.max(point.wait or 0, 0)
                        if settings.onReach then
                            pcall(settings.onReach, current, point)
                        end
                        Drive.halt()
                    end
                    if os.clock() >= (waitUntil :: number) then
                        waitUntil = nil
                        if current >= #points and settings.loop == false then
                            active = false
                        else
                            current = current % #points + 1
                        end
                    end
                else
                    waitUntil = nil
                    Drive.step(target, speed)
                end
                if detector.update(root.Position) then
                    detector.reset(root.Position)
                    current = Movement.nearestIndex(points, root.Position)
                    if settings.onStuck then
                        pcall(settings.onStuck)
                    end
                end
            end
            task.wait(STEP)
        end
        active = false
        runners[runner] = nil
        Drive.finish()
    end)
    return runner
end

function Movement.stopAll()
    for runner in runners do
        runner.stop()
    end
    Movement.cancelTween()
    Movement.stopSmoothWalk()
    Drive.finish()
end

function Movement.destroy()
    Movement.stopAll()
    Movement.setNoclip(false)
    Movement.unfreeze()
    groundParams = nil
    groundCharacter = nil
end

return Movement
end
modules["game/observer"] = function(...)

local import: (string) -> any = ...
local Codec: typeof(require("./codec")) = import("game/codec")
local Constants: typeof(require("./constants")) = import("game/constants")
local Finder: typeof(require("./finder")) = import("game/finder")
local Packets: typeof(require("./packets")) = import("game/packets")
local Template: typeof(require("./template")) = import("game/template")
local World: typeof(require("./world")) = import("game/world")

local Observer = {}

type Listener = (string, string) -> ()
type Rule = {
    logical: string,
    length: number,
    votes: number,
    always: boolean,
    strict: boolean,
    vlq: boolean?,
    test: (entity: number, item: number) -> string?,
}

local KEY = Constants.GLOBAL_PREFIX .. "PacketObserver"
local OLD_KEY = Constants.GLOBAL_PREFIX .. "ChestObserver"
local RANGE = 80
local VANISH_AFTER = 0.6

local listener: Listener? = nil
local votes: { [string]: { [number]: number } } = {}
local sniffed: { [number]: { count: number, samples: { string }, kinds: { string } } } = {}
local SAMPLES = 3
local WATCHED = { "UseBagItem", "DropBagItem", "ForceInteract", "Pickup" }
local gameValues: { [string]: string } = {}
local status = "not started"
local HEX_BYTES = 40

local HINTS: { [string]: string } = {
    OpenChest = "open one chest by hand",
    InteractStructure = "plant one seed in a Plant Box by hand",
    Pickup = "pick up one item by hand",
}

local function environment(): { [string]: any }?
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then
        return env
    end
    return nil
end

local function present(list: { any }, entity: number): boolean
    for _, entry in list do
        if World.entityId(entry.instance) == entity then
            return true
        end
    end
    return false
end

local RULES: { Rule } = {
    {
        logical = "OpenChest",
        length = 6,
        votes = 1,
        always = false,
        strict = false,
        test = function(entity: number, _: number): string?
            return if present(Finder.chests(RANGE), entity) then "chest" else nil
        end,
    },
    {
        logical = "InteractStructure",
        length = 8,
        votes = 2,
        always = false,
        strict = true,
        vlq = true,
        test = function(entity: number, item: number): string?
            if item > 0 and present(Finder.deployables(RANGE, { names = { "Plant Box", "Coin Press" } }), entity) then
                return "structure"
            end
            return nil
        end,
    },
    {
        logical = "Pickup",
        length = 6,
        votes = 2,
        always = false,
        strict = true,
        test = function(entity: number, _: number): string?
            if present(Finder.items(RANGE), entity) then
                return "item"
            elseif present(Finder.bushes(RANGE), entity) then
                return "bush"
            end
            return nil
        end,
    },
}

local function hexOf(data: buffer): string
    local parts: { string } = {}
    for index = 0, math.min(buffer.len(data), HEX_BYTES) - 1 do
        table.insert(parts, string.format("%02X", buffer.readu8(data, index)))
    end
    return table.concat(parts, " ")
end

local function classify(entity: number): string
    local sources: { { any } } = {
        { "item", Finder.items(RANGE) },
        { "structure", Finder.deployables(RANGE) },
        { "bush", Finder.bushes(RANGE) },
        { "resource", Finder.resources(RANGE) },
    }
    for _, source in sources do
        for _, entry in source[2] do
            if World.entityId(entry.instance) == entity then
                return source[1] .. " " .. tostring(entry.name)
            end
        end
    end
    return "unknown target"
end

local function sniff(data: buffer)
    local size = buffer.len(data)
    if size < 2 then
        return
    end
    local id = buffer.readu8(data, 1)
    local record = sniffed[id]
    if record == nil then
        record = { count = 0, samples = {}, kinds = {} }
        sniffed[id] = record
    end
    record.count += 1
    if #record.samples < SAMPLES then
        table.insert(record.samples, string.format("%d bytes: %s", size, hexOf(data)))
        local packed = if buffer.readu8(data, 0) == 1 then Codec.readVlq(data, 2) else nil
        table.insert(record.kinds, if packed ~= nil then classify(packed) .. " (vlq " .. tostring(packed) .. ")" elseif size >= 6 then classify(buffer.readu32(data, 2)) else "no target")
    end
end

function Observer.lines(): { string }
    local ids: { number } = {}
    for id in sniffed do
        table.insert(ids, id)
    end
    table.sort(ids)
    local lines = { "packets the game sent itself (one entry per packet id, first samples):" }
    for _, id in ids do
        local record = sniffed[id]
        local name = Packets.nameOf(id)
        table.insert(lines, string.format("%d %s sent %d times", id, if name then name else "(no name)", record.count))
        for index, sample in record.samples do
            table.insert(lines, "    " .. sample .. "  ->  " .. record.kinds[index])
        end
    end
    if #ids == 0 then
        table.insert(lines, "    nothing yet")
    end
    return lines
end

local function accept(rule: Rule, id: number)
    local tally = votes[rule.logical]
    if tally == nil then
        tally = {}
        votes[rule.logical] = tally
    end
    tally[id] = (tally[id] or 0) + 1
    if tally[id] < rule.votes then
        return
    end
    local name = Packets.learn(rule.logical, id, rule.strict)
    if name ~= nil then
        votes[rule.logical] = nil
        if listener ~= nil then
            task.defer(listener, rule.logical, name)
        end
    end
end

local function learnLayout(data: buffer)
    local size = buffer.len(data)
    if size < 3 then
        return
    end
    local id = buffer.readu8(data, 1)
    for logical in Template.SUPPORTED do
        if Packets.id(logical) == id and Template.wants(logical) then
            local changed = Template.learn(logical, Packets.object(logical), data)
            if changed and listener ~= nil then
                task.defer(listener, logical, "layout")
            end
        end
    end
end

local function learnSent(logical: string, value: any)
    if (type(value) ~= "table" and type(value) ~= "number") or not Template.wants(logical) then
        return
    end
    if Template.learnValue(logical, value, "the game's own send") and listener ~= nil then
        task.defer(listener, logical, "layout")
    end
end

local function remember(logical: string, value: any)
    local text: string
    if type(value) == "table" then
        local parts: { string } = {}
        for key, field in value do
            if #parts < 6 then
                table.insert(parts, tostring(key) .. "=" .. typeof(field) .. " " .. string.sub(tostring(field), 1, 24))
            end
        end
        table.sort(parts)
        text = "table {" .. table.concat(parts, ", ") .. "}"
    else
        text = typeof(value) .. " " .. string.sub(tostring(value), 1, 40)
    end
    gameValues[logical] = text
end

function Observer.gameValues(): { string }
    local lines: { string } = {}
    for _, logical in WATCHED do
        table.insert(lines, "game's own " .. logical .. " value: " .. (gameValues[logical] or "not seen yet"))
    end
    return lines
end

local function unwrap(state: { [string]: any })
    local sends = state.sends
    if type(sends) ~= "table" then
        return
    end
    for object, original in sends do
        pcall(function()
            object.send = original
        end)
    end
    table.clear(sends)
end

local wrapAt = 0

local function wrap(state: { [string]: any })
    wrapAt = os.clock()
    if type(state.sends) ~= "table" then
        state.sends = {}
    end
    local sends = state.sends :: { [any]: any }
    local names: { string } = table.clone(WATCHED)
    for logical in Template.SUPPORTED do
        table.insert(names, logical)
    end
    for _, logical in names do
        local object = Packets.object(logical)
        if type(object) == "table" and sends[object] == nil then
            local original = rawget(object, "send")
            if type(original) == "function" then
                local learns = Template.SUPPORTED[logical] == true
                local watched = table.find(WATCHED, logical) ~= nil or not learns
                local function send(...: any): ...any
                    if state.active and not Packets.firing() and not Template.sending() then
                        local value = ...
                        if learns then
                            pcall(learnSent, logical, value)
                        end
                        if watched then
                            pcall(remember, logical, value)
                        end
                    end
                    return original(...)
                end
                local ok = pcall(function()
                    object.send = send
                end)
                if ok then
                    sends[object] = original
                end
            end
        end
    end
end

local current: { [string]: any }? = nil

local function inspect(data: any)
    if typeof(data) ~= "buffer" then
        return
    end
    pcall(Packets.saw, data)
    if Packets.firing() then
        return
    end
    local state = current
    if state ~= nil and os.clock() - wrapAt > 5 then
        pcall(wrap, state)
    end
    pcall(sniff, data)
    pcall(learnLayout, data)
    local size = buffer.len(data)
    if size < 6 then
        return
    end
    local id = buffer.readu8(data, 1)
    local plainEntity = buffer.readu32(data, 2)
    local plainItem = if size >= 8 then buffer.readu16(data, 6) else 0
    local packedEntity, after = Codec.readVlq(data, 2)
    local packedItem = if packedEntity ~= nil and after + 2 <= size then buffer.readu16(data, after) else 0
    for _, rule in RULES do
        local packed = rule.vlq == true
        local fits = if packed then packedEntity ~= nil and size == after + 2 else size == rule.length
        if fits and (rule.always or not Packets.named(rule.logical)) then
            local entity = if packed then packedEntity :: number else plainEntity
            local item = if packed then packedItem else plainItem
            local kind = rule.test(entity, item)
            if kind == "item" then
                task.delay(VANISH_AFTER, function()
                    if not present(Finder.items(RANGE), entity) then
                        accept(rule, id)
                    end
                end)
                return
            elseif kind ~= nil then
                accept(rule, id)
                return
            end
        end
    end
end

function Observer.hint(logical: string): string
    local text = HINTS[logical]
    if text == nil then
        return ""
    end
    return "Do this once by hand and the script learns it: " .. text
end

function Observer.listen(callback: Listener?)
    listener = callback
end

local function remoteName(remote: any): boolean
    local ok, name = pcall(function(): any
        return remote.Name
    end)
    return ok and name == Constants.REMOTE
end

local function feed(created: { [string]: any }, remote: any, first: any)
    if not created.active or not remoteName(remote) then
        return
    end
    local now = os.clock()
    if first == created.last and now - (created.lastAt or 0) < 0.002 then
        return
    end
    created.last = first
    created.lastAt = now
    pcall(created.inspect, first)
end

function Observer.status(): string
    return status
end

function Observer.start()
    local env = environment()
    if env == nil then
        status = "no environment"
        return
    end
    local old = env[OLD_KEY]
    if type(old) == "table" then
        old.active = false
    end
    local state = env[KEY]
    if type(state) == "table" then
        state.inspect = inspect
        state.active = true
        unwrap(state)
        current = state
        pcall(wrap, state)
        status = "reusing the hooks installed earlier in this session: " .. tostring(state.how)
        return
    end
    local created: { [string]: any } = { inspect = inspect, active = true, how = "", sends = {} }
    current = created
    pcall(wrap, created)
    local notes: { string } = {}
    if type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
        local original: any = nil
        local function hook(self: any, ...: any): ...any
            if created.active and getnamecallmethod() == "FireServer" then
                local first = ...
                feed(created, self, first)
            end
            return original(self, ...)
        end
        local installed: any = hook
        if type(newcclosure) == "function" then
            installed = newcclosure(hook)
        end
        local ok, previous = pcall(hookmetamethod, game, "__namecall", installed)
        if ok and previous ~= nil then
            original = previous
            table.insert(notes, "namecall hook")
        else
            table.insert(notes, "namecall hook failed: " .. tostring(previous))
        end
    else
        table.insert(notes, "hookmetamethod or getnamecallmethod missing")
    end
    if type(hookfunction) == "function" then
        local made, probe = pcall(Instance.new, "RemoteEvent")
        local fire: any = if made then probe.FireServer else nil
        if type(fire) == "function" then
            local original: any = nil
            local function wrapped(self: any, ...: any): ...any
                if created.active then
                    local first = ...
                    feed(created, self, first)
                end
                return original(self, ...)
            end
            local installed: any = wrapped
            if type(newcclosure) == "function" then
                installed = newcclosure(wrapped)
            end
            local ok, previous = pcall(hookfunction, fire, installed)
            if ok and previous ~= nil then
                original = previous
                table.insert(notes, "FireServer hook")
            else
                table.insert(notes, "FireServer hook failed: " .. tostring(previous))
            end
        else
            table.insert(notes, "FireServer function not reachable")
        end
    else
        table.insert(notes, "hookfunction missing")
    end
    created.how = table.concat(notes, ", ")
    status = created.how
    env[KEY] = created
end

function Observer.stop()
    local env = environment()
    local state = if env then env[KEY] else nil
    if type(state) == "table" then
        state.active = false
        unwrap(state)
    end
    current = nil
    listener = nil
    table.clear(votes)
    table.clear(sniffed)
end

return Observer
end
modules["game/packets"] = function(...)

local import: (string) -> any = ...
local Builders: typeof(require("./builders")) = import("game/builders")
local Cache: typeof(require("./cache")) = import("game/cache")
local Codec: typeof(require("./codec")) = import("game/codec")
local Constants: typeof(require("./constants")) = import("game/constants")
local Learned: typeof(require("./learned")) = import("game/learned")
local Template: typeof(require("./template")) = import("game/template")
local Modules: typeof(require("./modules")) = import("game/modules")

local Packets = {}

export type Mode = "raw" | "module"
export type Clock = "server" | "time"
export type Source = "live" | "cache" | "none"
export type Stats = { sent: number, failed: number, batches: number, queued: number }
type Settings = { format: string, stamp: () -> number }
type Definition = typeof(Builders.DEFINITIONS.SwingTool)

local ids: { [string]: number } = {}
local objects: { [string]: any } = {}
local queue: { buffer } = {}
local stats: Stats = { sent = 0, failed = 0, batches = 0, queued = 0 }
local source: Source = "none"
local lastError: string? = nil
local remote: any = nil
local connection: any = nil
local mode: Mode = "module"
local format: string = "quat16"
local clock: Clock = "server"
local fallbacks = true
local caching = true
local resolved = false
local firing = false
local sentSamples: { [number]: string } = {}
local via: { [string]: string } = {}
local resolvedAt = 0
local remoteMissAt: number? = nil
local brokenAt: { [string]: number } = {}
local silent: { [string]: boolean } = {}
local retried: { [string]: boolean } = {}
local verified: { [string]: boolean } = {}
local unseen: { [string]: boolean } = {}
local blocked: { [string]: boolean } = {}
local pending: { [string]: { id: number, since: number } } = {}
local noticedAt: { [string]: number } = {}
local layouts: { [string]: string? } = {}
local notifier: ((string) -> ())? = nil
local wireSeen = 0

local RESOLVE_EVERY = 3
local REMOTE_RETRY = 10
local BROKEN_FOR = 30
local VERIFY_WITHIN = 4
local NOTICE_EVERY = 60

Packets.DEFINITIONS = Builders.DEFINITIONS

function Packets.version(): string
    local ok, value = pcall(function(): any
        return game.PlaceVersion
    end)
    if ok and value ~= nil then
        return tostring(value)
    end
    return ""
end

local function readId(object: any): number?
    if type(object) ~= "table" then
        return nil
    end
    for _, field in Constants.PACKET_ID_FIELDS do
        local ok, value = pcall(function()
            return object[field]
        end)
        if ok and type(value) == "number" and value == value and value > 0 and math.floor(value) == value then
            return value
        end
    end
    return nil
end

local function liveMap(): ({ [string]: number }?, { [string]: any }?, string?)
    local instance = Modules.find({ Constants.MODULES.Packets })
    if instance == nil then
        return nil, nil, "ReplicatedStorage.Modules.Packets is missing"
    end
    local ok, packets = Modules.load(instance)
    if not ok or type(packets) ~= "table" then
        return nil, nil, "Packets could not be required: " .. tostring(packets)
    end
    local map: { [string]: number } = {}
    local found: { [string]: any } = {}
    for name, object in packets do
        if type(name) == "string" then
            found[name] = object
            local id = readId(object)
            if id then
                map[name] = id
            end
        end
    end
    for _, path in Constants.PACKET_ID_MODULES do
        local loadedOk, registry = Modules.load(Modules.find(path))
        if loadedOk and type(registry) == "table" then
            for key, value in registry do
                if type(key) == "number" then
                    for name, object in found do
                        if map[name] == nil and (object == value or (type(value) == "table" and value.name == name)) then
                            map[name] = key
                        end
                    end
                end
            end
            break
        end
    end
    if next(map) == nil then
        return nil, found, "no packet ids could be read from Packets"
    end
    return map, found, nil
end

local function known(logical: string): boolean
    local spec = Builders.DEFINITIONS[logical]
    if spec == nil then
        return ids[logical] ~= nil
    end
    for _, candidate in spec.names do
        if ids[candidate] ~= nil then
            return true
        end
    end
    return false
end

local function seed()
    for logical, id in Constants.SEED_IDS :: { [string]: number } do
        if Learned.get(logical) == nil and not known(logical) then
            for name, value in ids do
                if value == id then
                    Learned.set(logical, name, false)
                    break
                end
            end
        end
    end
end

function Packets.resolve(): (boolean, string?)
    local now = os.clock()
    if resolved and now - resolvedAt < RESOLVE_EVERY then
        return source ~= "none", lastError
    end
    resolvedAt = now
    resolved = true
    local cached, cachedVersion = nil, nil
    if caching then
        cached, cachedVersion = Cache.load()
    end
    local current = Packets.version()
    local map, found, problem = liveMap()
    table.clear(objects)
    if found then
        for name, object in found do
            objects[name] = object
        end
    end
    if map then
        table.clear(ids)
        for name, id in map do
            ids[name] = id
        end
        source = "live"
        lastError = nil
        if caching and (not Cache.same(cached, map) or cachedVersion ~= current) then
            Cache.save(map, current)
        end
        seed()
        return true, nil
    end
    lastError = problem
    if cached and cachedVersion ~= current then
        lastError = tostring(problem) .. "; the saved packet list is from game version " .. tostring(cachedVersion) .. ", not " .. current
        cached = nil
    end
    if cached then
        table.clear(ids)
        for name, id in cached do
            ids[name] = id
        end
        source = "cache"
        return true, problem
    end
    table.clear(ids)
    source = "none"
    return false, problem
end

local function ensure()
    if not resolved then
        Packets.resolve()
    end
end

local function definition(name: string): Definition?
    return Builders.DEFINITIONS[name]
end

function Packets.lookup(name: string): (number?, string, string?)
    ensure()
    local spec = definition(name)
    local learned = Learned.get(name)
    if learned ~= nil and learned.confirmed and ids[learned.name] then
        return ids[learned.name], "learned from your play", learned.name
    end
    if spec then
        for _, candidate in spec.names do
            local id = ids[candidate]
            if id then
                return id, "name " .. candidate, candidate
            end
        end
    elseif ids[name] then
        return ids[name], "name " .. name, name
    end
    if learned ~= nil and ids[learned.name] then
        return ids[learned.name], "learned name, unconfirmed", learned.name
    end
    if learned ~= nil and learned.id ~= nil and learned.version == Packets.version() then
        return learned.id, "learned id for this game version", nil
    end
    if fallbacks and source ~= "live" then
        local fallback = (Constants.FALLBACK_IDS :: { [string]: number })[name]
        if fallback then
            return fallback, "built-in fallback", nil
        end
    end
    return nil, "missing", nil
end

function Packets.id(name: string): number?
    local id = Packets.lookup(name)
    return id
end

function Packets.has(name: string): boolean
    return Packets.id(name) ~= nil
end

function Packets.nameOf(id: number): string?
    ensure()
    for name, value in ids do
        if value == id then
            return name
        end
    end
    return nil
end

function Packets.named(logical: string): boolean
    local _, how = Packets.lookup(logical)
    return how ~= "missing"
end

function Packets.learn(logical: string, id: number, strict: boolean?): string?
    ensure()
    local name = Packets.nameOf(id)
    if name == nil then
        if next(ids) ~= nil then
            return nil
        end
        local label = "id " .. tostring(id)
        Learned.set(logical, label, true, id, Packets.version())
        return label
    end
    for other, spec in Builders.DEFINITIONS do
        if other ~= logical and (strict == true or other ~= "ForceInteract") and table.find(spec.names, name) then
            return nil
        end
    end
    Learned.set(logical, name, true)
    return name
end

function Packets.report(extra: { string }?): string
    ensure()
    local count = 0
    for _ in ids do
        count += 1
    end
    local lines = {
        "Booga Utilities packet report",
        "game version: " .. Packets.version(),
        "packet list: " .. source .. ", " .. tostring(count) .. " packets",
        "send mode: " .. mode,
        "last problem: " .. tostring(lastError),
        "",
    }
    local names: { string } = {}
    for name in Builders.DEFINITIONS do
        table.insert(names, name)
    end
    table.sort(names)
    for _, name in names do
        local id, how = Packets.lookup(name)
        table.insert(lines, string.format("%-18s %-6s %s", name, if id then tostring(id) else "none", how))
    end
    if extra ~= nil then
        table.insert(lines, "")
        for _, line in extra do
            table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n")
end

function Packets.lastVia(name: string): string?
    return via[name]
end

function Packets.lastRaw(id: number): string?
    return sentSamples[id]
end

function Packets.firing(): boolean
    return firing
end

function Packets.ids(): { [string]: number }
    ensure()
    return table.clone(ids)
end

function Packets.object(name: string): any
    ensure()
    local spec = definition(name)
    local candidates: { string } = if spec then table.clone(spec.names) else { name }
    local learned = Learned.get(name)
    if learned ~= nil and learned.confirmed then
        table.insert(candidates, 1, learned.name)
    end
    for _, candidate in candidates do
        if objects[candidate] ~= nil then
            return objects[candidate]
        end
    end
    local _, _, resolved = Packets.lookup(name)
    if resolved ~= nil then
        return objects[resolved]
    end
    return nil
end

function Packets.source(): Source
    return source
end

function Packets.lastError(): string?
    return lastError
end

function Packets.remote(): any
    if remote ~= nil and remote.Parent ~= nil then
        return remote
    end
    remote = nil
    local storage = Modules.service("ReplicatedStorage")
    if not storage then
        return nil
    end
    local found = storage:FindFirstChild(Constants.REMOTE)
    if found == nil then
        if remoteMissAt ~= nil and os.clock() - remoteMissAt < REMOTE_RETRY then
            return nil
        end
        for _, descendant in storage:GetDescendants() do
            if descendant.Name == Constants.REMOTE and descendant:IsA("RemoteEvent") then
                found = descendant
                break
            end
        end
    end
    remoteMissAt = if found == nil then os.clock() else nil
    remote = found
    return found
end

function Packets.stamp(): number
    if clock == "time" then
        local ok, value = pcall(function()
            return time()
        end)
        if ok and type(value) == "number" then
            return value
        end
    end
    local ok, value = pcall(function()
        return workspace:GetServerTimeNow()
    end)
    if ok and type(value) == "number" then
        return value
    end
    return os.clock()
end

function Packets.settings(): Settings
    return { format = format, stamp = Packets.stamp }
end

function Packets.build(name: string, ...: any): buffer?
    local spec = definition(name)
    if not spec then
        return nil
    end
    local id = Packets.id(name)
    if not id or id > 65535 then
        return nil
    end
    local args = table.pack(...)
    local ok, result = pcall(function()
        return spec.build(id, Packets.settings(), table.unpack(args, 1, args.n))
    end)
    if ok then
        return result
    end
    lastError = tostring(result)
    return nil
end

function Packets.fire(data: buffer): boolean
    if buffer.len(data) >= 2 then
        local parts: { string } = {}
        for index = 0, math.min(buffer.len(data), 40) - 1 do
            table.insert(parts, string.format("%02X", buffer.readu8(data, index)))
        end
        sentSamples[buffer.readu8(data, 1)] = string.format("%d bytes: %s", buffer.len(data), table.concat(parts, " "))
    end
    local target = Packets.remote()
    if target == nil then
        lastError = Constants.REMOTE .. " is missing"
        stats.failed += 1
        return false
    end
    firing = true
    local ok, problem = pcall(function()
        target:FireServer(data)
    end)
    firing = false
    if ok then
        stats.sent += 1
        return true
    end
    lastError = tostring(problem)
    stats.failed += 1
    return false
end

function Packets.notify(callback: ((string) -> ())?)
    notifier = callback
end

local function notice(name: string, text: string)
    lastError = text
    local now = os.clock()
    local last = noticedAt[name]
    if last ~= nil and now - last < NOTICE_EVERY then
        return
    end
    noticedAt[name] = now
    local callback = notifier
    if callback ~= nil then
        task.defer(callback, text)
    end
end

function Packets.saw(data: buffer)
    wireSeen += 1
    if next(pending) == nil then
        return
    end
    local size = buffer.len(data)
    for name, entry in pending do
        local high, low = math.floor(entry.id / 256), entry.id % 256
        for index = 0, size - 2 do
            if buffer.readu8(data, index + 1) == low and (buffer.readu8(data, index) == high or (high == 0 and buffer.readu8(data, index) == 1)) then
                verified[name] = true
                unseen[name] = nil
                pending[name] = nil
                break
            end
        end
    end
end

local function track(name: string)
    if verified[name] or pending[name] ~= nil then
        return
    end
    local id = Packets.id(name)
    if id ~= nil then
        pending[name] = { id = id, since = os.clock() }
    end
end

local function rawAllowed(name: string): boolean
    local spec = definition(name)
    return spec ~= nil and spec.verified == true
end

local function refuseRaw(name: string): boolean
    if rawAllowed(name) then
        return false
    end
    blocked[name] = true
    stats.failed += 1
    via[name] = "nothing, the game's own send failed and the raw layout is not verified"
    notice(name, name .. ": the game's own send did not work and the raw layout is not verified, nothing was sent. Send packet report.txt")
    return true
end

local function checkSilent(name: string)
    local entry = pending[name]
    if entry == nil or wireSeen == 0 or os.clock() - entry.since < VERIFY_WITHIN then
        return
    end
    pending[name] = nil
    Template.distrust(name, layouts[name])
    if not rawAllowed(name) then
        unseen[name] = true
        return
    end
    silent[name] = true
    notice(name, name .. ": the game's own send never reached the server, the script sends the packet itself now")
end

local function moduleSend(name: string, ...: any): boolean?
    if mode ~= "module" then
        return nil
    end
    local spec = definition(name)
    local object = Packets.object(name)
    if not spec or type(object) ~= "table" or type(object.send) ~= "function" then
        return nil
    end
    if silent[name] and Template.SUPPORTED[name] and Template.has(name) and not retried[name] then
        retried[name] = true
        silent[name] = nil
    end
    checkSilent(name)
    if silent[name] then
        return nil
    end
    local broken = brokenAt[name]
    if broken ~= nil and os.clock() - broken < BROKEN_FOR then
        return nil
    end
    local args = table.pack(...)
    if Template.ready(name) then
        firing = true
        local sent, problem, label = Template.send(name, object, { table.unpack(args, 1, args.n) }, Packets.stamp())
        firing = false
        if sent then
            stats.sent += 1
            via[name] = "the game's own send, " .. tostring(label)
            layouts[name] = label
            track(name)
            return true
        elseif problem ~= nil then
            brokenAt[name] = os.clock()
            notice(name, name .. ": the game refused every layout, packet report.txt has the details (" .. string.sub(problem, 1, 120) .. ")")
            return nil
        end
    end
    if not spec.module then
        return nil
    end
    local sender = spec.module :: (any, ...any) -> ()
    firing = true
    local ok, problem = pcall(function()
        sender(object, table.unpack(args, 1, args.n))
    end)
    firing = false
    if ok then
        stats.sent += 1
        via[name] = "the game's own send"
        track(name)
        return true
    end
    brokenAt[name] = os.clock()
    notice(name, name .. ": the game refused the packet (" .. string.sub(tostring(problem), 1, 80) .. ")")
    return nil
end

function Packets.health(): { string }
    local lines: { string } = {}
    local names: { string } = {}
    for name in Builders.DEFINITIONS do
        table.insert(names, name)
    end
    table.sort(names)
    for _, name in names do
        local state = if silent[name] then "game send silent, raw" elseif brokenAt[name] ~= nil and os.clock() - brokenAt[name] < BROKEN_FOR then (if rawAllowed(name) then "game send refused, raw for now" else "game send refused, raw not verified so nothing sent") elseif verified[name] then "game send seen on the wire" elseif unseen[name] then "game send not seen on the wire (raw not verified, kept the game send)" elseif pending[name] ~= nil then "game send not seen yet" else "unused"
        table.insert(lines, "send " .. name .. ": " .. state .. (if rawAllowed(name) then " | raw layout verified" else " | raw layout not verified") .. (if blocked[name] then " | a raw send was blocked" else ""))
    end
    table.insert(lines, "ByteNet fires seen: " .. tostring(wireSeen))
    return lines
end

function Packets.send(name: string, ...: any): boolean
    local viaModule = moduleSend(name, ...)
    if viaModule then
        return true
    end
    if refuseRaw(name) then
        return false
    end
    local data = Packets.build(name, ...)
    if not data then
        stats.failed += 1
        via[name] = "nothing, the packet could not be built"
        return false
    end
    via[name] = "a raw buffer"
    local ok = Packets.fire(data)
    if not ok then
        notice(name, name .. " could not be sent: " .. tostring(lastError))
    end
    return ok
end

function Packets.flush(): number
    if #queue == 0 then
        return 0
    end
    local count = math.min(#queue, Constants.LIMITS.QueuePerFlush)
    local batch = table.move(queue, 1, count, 1, {})
    local total = #queue
    table.move(queue, count + 1, total, 1)
    for index = total - count + 1, total do
        queue[index] = nil
    end
    stats.queued = #queue
    if Packets.fire(Codec.concat(batch)) then
        stats.batches += 1
        stats.sent += count - 1
        return count
    end
    return 0
end

local function listen()
    if connection ~= nil then
        return
    end
    local run = Modules.service("RunService")
    if not run then
        return
    end
    connection = run.Heartbeat:Connect(function()
        Packets.flush()
    end)
end

function Packets.queue(name: string, ...: any): boolean
    if moduleSend(name, ...) then
        return true
    end
    if refuseRaw(name) then
        return false
    end
    local data = Packets.build(name, ...)
    if not data then
        stats.failed += 1
        return false
    end
    table.insert(queue, data)
    stats.queued = #queue
    listen()
    return true
end

function Packets.setMode(value: Mode)
    if value == "raw" or value == "module" then
        mode = value
    end
end

function Packets.getMode(): Mode
    return mode
end

function Packets.setCFrameFormat(value: string)
    if table.find(Codec.FORMATS, value) then
        format = value
    end
end

function Packets.getCFrameFormat(): string
    return format
end

function Packets.setCache(enabled: boolean)
    caching = enabled
end

function Packets.stats(): Stats
    return table.clone(stats)
end

function Packets.destroy()
    if connection ~= nil then
        pcall(function()
            connection:Disconnect()
        end)
        connection = nil
    end
    table.clear(queue)
    stats.queued = 0
    table.clear(pending)
    table.clear(layouts)
    notifier = nil
end

return Packets
end
modules["game/schema"] = function(...)

local import: (string) -> any = ...
local Modules: typeof(require("./modules")) = import("game/modules")

local Schema = {}

export type Node = { k: string, t: string?, fields: { [string]: Node }?, element: Node?, sample: any? }
type Result = { node: Node?, note: string }

local LIBRARY = { { "libraries", "byteNet", "dataTypes" }, { "byteNet", "dataTypes" }, { "ByteNet", "dataTypes" }, { "dataTypes" } }
local DEPTH = 6
local SEARCH = 3
local SCAN = 64
local KINDS: { [string]: string } = {
    struct = "table",
    array = "array",
    list = "array",
    optional = "optional",
    map = "map",
    dictionary = "map",
    cframe = "CFrame",
    vec3 = "Vector3",
    vector3 = "Vector3",
    string = "string",
    bool = "boolean",
    boolean = "boolean",
    nothing = "nothing",
}

local identity: { [any]: string } = {}
local prototypes: { [string]: string } = {}
local indexed = false
local indexNote = "not read yet"
local results: { [any]: Result } = {}

local function info(fn: any, what: string): (any, any)
    local lib: any = debug
    local ok, first, second = pcall(lib.info, fn, what)
    if not ok then
        return nil, nil
    end
    return first, second
end

local function protoKey(fn: any): string?
    if type(fn) ~= "function" then
        return nil
    end
    local source, line = info(fn, "sl")
    if type(source) ~= "string" or source == "[C]" or type(line) ~= "number" or line < 0 then
        return nil
    end
    return source .. ":" .. tostring(line)
end

local function arity(fn: any): number
    local count = info(fn, "a")
    return if type(count) == "number" then count else -1
end

local function sourceName(fn: any): string?
    local source = info(fn, "s")
    if type(source) ~= "string" or not string.find(string.lower(source), "datatypes", 1, true) then
        return nil
    end
    return string.match(source, "([%w_]+)$")
end

function Schema.kindOf(name: string): string
    local lower = string.lower(name)
    local mapped = KINDS[lower]
    if mapped ~= nil then
        return mapped
    end
    if lower == "vlq" or lower == "number" or string.match(lower, "^u?int%d*$") ~= nil or string.match(lower, "^float%d*$") ~= nil or string.match(lower, "vlq$") ~= nil then
        return "number"
    end
    return "other"
end

local function getter(): any
    local lib: any = debug
    if type(lib.getupvalues) == "function" then
        return lib.getupvalues
    end
    local ok, global = pcall(function(): any
        return getupvalues
    end)
    if ok and type(global) == "function" then
        return global
    end
    return nil
end

local function upvalues(fn: any): { any }
    local list: { any } = {}
    local get = getter()
    if get == nil or type(fn) ~= "function" then
        return list
    end
    local ok, values = pcall(get, fn)
    if not ok or type(values) ~= "table" then
        return list
    end
    local keys: { number } = {}
    for key in values do
        if type(key) == "number" then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    for _, key in keys do
        table.insert(list, values[key])
    end
    return list
end

local function field(value: any, name: string): any
    if type(value) ~= "table" then
        return nil
    end
    local ok, found = pcall(function(): any
        return value[name]
    end)
    return if ok then found else nil
end

local function register(name: string, value: any)
    for _, side in { "read", "write" } do
        local fn = field(value, side)
        if type(fn) == "function" then
            if identity[fn] == nil then
                identity[fn] = name
            end
            local key = protoKey(fn)
            if key ~= nil then
                local known = prototypes[key]
                if known == nil then
                    prototypes[key] = name
                elseif known ~= name then
                    prototypes[key] = ""
                end
            end
        end
    end
end

local function isType(value: any): boolean
    return type(field(value, "read")) == "function"
end

local function folder(): any
    for _, path in LIBRARY do
        local found = Modules.find(path)
        if found ~= nil then
            return found
        end
    end
    return nil
end

local function index()
    if indexed then
        return
    end
    indexed = true
    local root = folder()
    if root == nil then
        indexNote = "byteNet dataTypes folder not found, types are named from the code's source"
        return
    end
    local ok, children = pcall(function(): { any }
        return root:GetChildren()
    end)
    if not ok then
        indexNote = "byteNet dataTypes folder could not be listed"
        return
    end
    local constructors: { [string]: any } = {}
    local probe: any = nil
    local count = 0
    for _, child in children do
        local isModule = select(2, pcall(function(): boolean
            return child:IsA("ModuleScript")
        end))
        if isModule == true then
            local loaded, value = Modules.load(child)
            local name = tostring(child.Name)
            if loaded and isType(value) then
                register(name, value)
                probe = probe or value
                count += 1
            elseif loaded and type(value) == "function" then
                local made, result = pcall(value)
                if made and isType(result) then
                    register(name, result)
                    probe = probe or result
                    count += 1
                else
                    constructors[name] = value
                end
            end
        end
    end
    if probe ~= nil then
        for name, build in constructors do
            for _, args in { { probe }, { { zz = probe } }, { probe, probe } } do
                local made, result = pcall(build, table.unpack(args))
                if made and isType(result) then
                    register(name, result)
                    count += 1
                    break
                end
            end
        end
    end
    indexNote = tostring(count) .. " byteNet data types known"
end

local function classify(fn: any): string?
    if type(fn) ~= "function" then
        return nil
    end
    local name = identity[fn]
    if name ~= nil then
        return name
    end
    local key = protoKey(fn)
    if key ~= nil then
        local known = prototypes[key]
        if known ~= nil and known ~= "" then
            return known
        end
    end
    return sourceName(fn)
end

local function functionsOf(value: any): { any }
    local list: { any } = {}
    if type(value) == "function" then
        table.insert(list, value)
    elseif type(value) == "table" then
        for _, side in { "read", "write" } do
            local fn = field(value, side)
            if type(fn) == "function" then
                table.insert(list, fn)
            end
        end
    end
    return list
end

local describe: (value: any, depth: number) -> Node?

local function innerOf(fns: { any }, depth: number): Node?
    for pass = 1, 2 do
        for _, fn in fns do
            for _, value in upvalues(fn) do
                local fits = isType(value) or (type(value) == "function" and (pass == 2 or arity(value) == 2))
                if fits then
                    local node = describe(value, depth + 1)
                    if node ~= nil then
                        return node
                    end
                end
            end
        end
    end
    return nil
end

local function entryType(entry: { [any]: any }, depth: number): Node?
    local candidates: { any } = {}
    local keys: { any } = { 2, 3, 4, "value", "type", "dataType", "read" }
    for _, key in keys do
        local value = entry[key]
        if isType(value) or (type(value) == "function" and arity(value) == 2) then
            table.insert(candidates, 1, value)
        elseif type(value) == "function" then
            table.insert(candidates, value)
        end
    end
    for _, value in candidates do
        local node = describe(value, depth + 1)
        if node ~= nil then
            return node
        end
    end
    return nil
end

local function fieldsFrom(container: { [any]: any }, depth: number): ({ [string]: Node }, number)
    local fields: { [string]: Node } = {}
    local count = 0
    local scanned = 0
    for key, entry in container do
        scanned += 1
        if scanned > SCAN then
            break
        end
        local name: string? = nil
        local node: Node? = nil
        if type(key) == "string" and ((type(entry) == "function" and arity(entry) == 2) or isType(entry)) then
            name = key
            node = describe(entry, depth + 1)
        elseif type(entry) == "table" then
            local label = entry[1]
            if type(label) ~= "string" then
                label = entry.key or entry.name
            end
            if type(label) == "string" then
                name = label
                node = entryType(entry, depth)
            end
        end
        if name ~= nil and node ~= nil and fields[name] == nil then
            fields[name] = node
            count += 1
        end
    end
    return fields, count
end

local function zipped(values: { any }, depth: number): { [string]: Node }?
    local names: { string }? = nil
    local types: { any }? = nil
    for _, value in values do
        if type(value) == "table" and #value > 0 then
            if type(value[1]) == "string" and names == nil then
                names = value
            elseif (type(value[1]) == "function" or isType(value[1])) and types == nil then
                types = value
            end
        end
    end
    if names == nil or types == nil or #names ~= #types then
        return nil
    end
    local fields: { [string]: Node } = {}
    for position, name in names do
        local node = describe(types[position], depth + 1)
        if node == nil then
            return nil
        end
        fields[name] = node
    end
    return fields
end

local function structOf(fns: { any }, depth: number): { [string]: Node }?
    local best: { [string]: Node }? = nil
    local bestCount = 0
    for _, fn in fns do
        local values = upvalues(fn)
        for _, value in values do
            if type(value) == "table" and not isType(value) then
                local fields, count = fieldsFrom(value, depth)
                if count > bestCount then
                    best, bestCount = fields, count
                end
            end
        end
        if best == nil then
            best = zipped(values, depth)
        end
        if best ~= nil then
            return best
        end
    end
    return best
end

describe = function(value: any, depth: number): Node?
    if depth > DEPTH then
        return nil
    end
    local fns = functionsOf(value)
    local name: string? = nil
    for _, fn in fns do
        name = classify(fn)
        if name ~= nil then
            break
        end
    end
    if name == nil then
        return nil
    end
    local lower = string.lower(name)
    local kind = Schema.kindOf(lower)
    local node: Node = { k = kind, t = lower }
    if kind == "table" then
        local fields = structOf(fns, depth)
        if fields == nil then
            return nil
        end
        node.fields = fields
    elseif kind == "array" or kind == "optional" then
        local element = innerOf(fns, depth)
        if element == nil then
            return nil
        end
        node.element = element
    end
    return node
end

local function locate(value: any, depth: number, seen: { [any]: boolean }): Node?
    if value == nil or seen[value] or depth > SEARCH then
        return nil
    end
    seen[value] = true
    local node = describe(value, 1)
    if node ~= nil then
        return node
    end
    local nested = field(value, "value")
    if nested ~= nil then
        node = locate(nested, depth + 1, seen)
        if node ~= nil then
            return node
        end
    end
    for _, fn in functionsOf(value) do
        for _, inner in upvalues(fn) do
            if type(inner) == "function" or type(inner) == "table" then
                node = locate(inner, depth + 1, seen)
                if node ~= nil then
                    return node
                end
            end
        end
    end
    return nil
end

function Schema.of(object: any): (Node?, string)
    if type(object) ~= "table" then
        return nil, "no packet object"
    end
    local cached = results[object]
    if cached ~= nil then
        return cached.node, cached.note
    end
    local result: Result = { node = nil, note = "" }
    if getter() == nil then
        result.note = "the executor has no getupvalues"
    else
        index()
        local seen: { [any]: boolean } = {}
        local node = locate(field(object, "reader"), 1, seen)
        local how = "the packet's reader"
        if node == nil then
            node = locate(field(object, "send"), 0, seen)
            how = "the packet's send"
        end
        result.node = node
        result.note = if node ~= nil then "read from " .. how .. ", " .. indexNote else "nothing readable in the packet's reader or send, " .. indexNote
    end
    results[object] = result
    return result.node, result.note
end

local function sortedKeys(fields: { [string]: Node }): { string }
    local keys: { string } = {}
    for key in fields do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

function Schema.text(node: Node): string
    if node.k == "table" then
        local fields = node.fields or {}
        local parts: { string } = {}
        for _, key in sortedKeys(fields) do
            table.insert(parts, key .. ":" .. Schema.text(fields[key]))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif node.k == "array" and node.element ~= nil then
        return "[" .. Schema.text(node.element) .. "]"
    elseif node.k == "optional" and node.element ~= nil then
        return "?" .. Schema.text(node.element)
    end
    return node.t or node.k
end

function Schema.reset()
    table.clear(identity)
    table.clear(prototypes)
    table.clear(results)
    indexed = false
    indexNote = "not read yet"
end

return Schema
end
modules["game/shape"] = function(...)

local Shape = {}

local SKIP: { [string]: boolean } = {
    send = true,
    sendTo = true,
    sendToAll = true,
    sendToAllExcept = true,
    listen = true,
    listenOnce = true,
    queue = true,
    queueTo = true,
    connect = true,
    disconnect = true,
    id = true,
    reliabilityType = true,
}

local NAME_KEYS = { "structurename", "structure", "name", "itemname", "item", "type" }
local FRAME_KEYS = { "cframe", "frame", "cf", "location", "placement", "transform", "position", "pos" }

local function sorted(value: any): { any }
    local keys: { any } = {}
    for key in value do
        table.insert(keys, key)
    end
    table.sort(keys, function(a: any, b: any): boolean
        return tostring(a) < tostring(b)
    end)
    return keys
end

function Shape.describe(object: any, limit: number?): { string }
    local lines: { string } = {}
    local cap = limit or 60
    local seen: { [any]: boolean } = {}
    local function walk(value: any, path: string, depth: number)
        if type(value) ~= "table" or seen[value] or depth > 4 then
            return
        end
        seen[value] = true
        for _, key in sorted(value) do
            if #lines >= cap then
                return
            end
            local item = value[key]
            local label = path .. "." .. tostring(key)
            local kind = type(item)
            if kind == "table" then
                table.insert(lines, label .. " (table)")
                walk(item, label, depth + 1)
            elseif kind == "function" then
                table.insert(lines, label .. " (function)")
            else
                table.insert(lines, label .. " = " .. string.sub(tostring(item), 1, 40))
            end
        end
    end
    walk(object, "", 1)
    return lines
end

function Shape.keys(object: any): { string }
    local found: { string } = {}
    local seen: { [any]: boolean } = {}
    local function walk(value: any, depth: number)
        if type(value) ~= "table" or seen[value] or depth > 4 then
            return
        end
        seen[value] = true
        for _, key in sorted(value) do
            if type(key) == "string" and not SKIP[key] and type(value[key]) ~= "function" then
                table.insert(found, key)
            end
            walk(value[key], depth + 1)
        end
    end
    walk(object, 1)
    return found
end

local function pick(keys: { string }, patterns: { string }): string?
    for _, pattern in patterns do
        for _, key in keys do
            if string.lower(key) == pattern then
                return key
            end
        end
    end
    for _, pattern in patterns do
        for _, key in keys do
            if string.find(string.lower(key), pattern, 1, true) then
                return key
            end
        end
    end
    return nil
end

function Shape.placement(object: any, name: string, frame: any): { [string]: any }?
    local keys = Shape.keys(object)
    local nameKey = pick(keys, NAME_KEYS)
    local frameKey = pick(keys, FRAME_KEYS)
    if nameKey == nil or frameKey == nil or nameKey == frameKey then
        return nil
    end
    return { [nameKey] = name, [frameKey] = frame }
end

return Shape
end
modules["game/template"] = function(...)

local import: (string) -> any = ...
local Constants: typeof(require("./constants")) = import("game/constants")
local Modules: typeof(require("./modules")) = import("game/modules")
local Schema: typeof(require("./schema")) = import("game/schema")

local Template = {}

export type Node = { k: string, t: string?, fields: { [string]: Node }?, element: Node?, sample: any? }
type Entry = { label: string, node: Node }
type Chain = { object: any, version: number, list: { Entry } }

Template.SUPPORTED = {
    SwingTool = true,
    PlaceStructure = true,
    OpenChest = true,
    InteractStructure = true,
    Pickup = true,
    ForceInteract = true,
    DropBagItem = true,
    UseBagItem = true,
} :: { [string]: boolean }

local FILE = Constants.CACHE_FOLDER .. "/shapes.json"
local DEPTH = 4
local REFUSE_FOR = 30
local GAME_CODE = "layout read from the game's code"
local COPIED = "layout copied from the game's own send"
local BUILT_IN = "built-in layout"

local WORDS: { [string]: { string } } = {
    stamp = { "time", "stamp", "tick", "clock", "now" },
    slot = { "slot", "layout", "index", "idx", "bag" },
    item = { "item", "seed", "fuel", "tool", "weapon", "food" },
    quantity = { "amount", "quantity", "count", "qty" },
    entity = { "entity", "target", "obj", "hit", "structure", "chest", "door", "node", "id" },
}
local ORDER = { "stamp", "slot", "item", "quantity", "entity" }
local PREFER: { [string]: { string } } = {
    stamp = { "float64", "float32" },
    entity = { "vlq", "uint32", "float64", "int32", "number" },
    item = { "uint16", "vlq", "uint32", "number" },
    slot = { "uint8", "uint16", "vlq", "uint32", "number" },
    quantity = { "uint8", "uint16", "vlq", "uint32", "number" },
}
local ROLES: { [string]: { string } } = {
    SwingTool = { "stamp", "item", "slot" },
    PlaceStructure = {},
    OpenChest = { "entity" },
    InteractStructure = { "entity", "item" },
    Pickup = { "entity" },
    ForceInteract = { "entity" },
    DropBagItem = { "slot", "quantity" },
    UseBagItem = { "slot", "item" },
    entry = { "entity" },
}
local OPTIONAL: { [string]: { [string]: boolean } } = {
    SwingTool = { item = true, slot = true },
    DropBagItem = { quantity = true },
}
local PRIMARY: { [string]: string } = {
    OpenChest = "entity",
    InteractStructure = "entity",
    Pickup = "entity",
    ForceInteract = "entity",
    DropBagItem = "slot",
    UseBagItem = "slot",
    SwingTool = "entity",
    entry = "entity",
}
local NAME_WORDS = { "name", "building", "structure", "kind", "type" }

Template.DEFAULTS = {
    SwingTool = {
        k = "table",
        fields = {
            cframe = { k = "CFrame" },
            entityIDs = { k = "array", element = { k = "number", t = "vlq" } },
            timestamp = { k = "number", t = "float64", sample = 1792276952.5 },
        },
    },
    PlaceStructure = {
        k = "table",
        fields = {
            buildingName = { k = "string", sample = "Chest" },
            cframe = { k = "CFrame" },
        },
    },
    InteractStructure = {
        k = "table",
        fields = {
            entityID = { k = "number", sample = 0 },
            itemID = { k = "number", sample = 0 },
        },
    },
    OpenChest = { k = "number" },
    Pickup = { k = "number" },
    ForceInteract = { k = "number" },
    DropBagItem = { k = "number" },
    UseBagItem = { k = "number" },
} :: { [string]: Node }

local shapes: { [string]: Node } = {}
local notes: { [string]: string } = {}
local counts: { [string]: number } = {}
local chains: { [string]: Chain } = {}
local refusedAt: { [string]: { [string]: number } } = {}
local inUse: { [string]: string } = {}
local plans: { [Node]: { [string]: string } } = {}
local providers: { [string]: () -> any } = {}
local version = 0
local loaded = false

local function json(): any
    return Modules.service("HttpService")
end

local function kindOf(value: any): string
    local kind = typeof(value)
    if kind == "CFrame" or kind == "number" or kind == "string" or kind == "boolean" or kind == "Vector3" then
        return kind
    end
    if kind == "table" and type(value) == "table" then
        if rawget(value, "_p") ~= nil and rawget(value, "_r") ~= nil then
            return "CFrame"
        end
        return "table"
    end
    return "other"
end

local function describe(value: any, depth: number): Node?
    local kind: string = kindOf(value)
    if kind == "CFrame" or kind == "Vector3" or kind == "other" then
        local leaf: Node = { k = kind }
        return leaf
    elseif kind == "number" or kind == "string" or kind == "boolean" then
        local simple: Node = { k = kind, sample = value }
        return simple
    elseif kind == "table" and depth <= DEPTH then
        if value[1] ~= nil then
            local element = describe(value[1], depth + 1)
            if element == nil then
                return nil
            end
            return { k = "array", element = element }
        end
        local fields: { [string]: Node } = {}
        for key, item in value do
            if type(key) ~= "string" then
                return nil
            end
            local node = describe(item, depth + 1)
            if node == nil then
                return nil
            end
            fields[key] = node
        end
        return { k = "table", fields = fields }
    end
    return nil
end

local function sortedKeys(fields: { [string]: Node }): { string }
    local keys: { string } = {}
    for key in fields do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

function Template.fingerprint(node: Node): string
    if node.k == "table" then
        local parts: { string } = {}
        local fields = node.fields or {}
        for _, key in sortedKeys(fields) do
            table.insert(parts, key .. ":" .. Template.fingerprint(fields[key]))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif node.k == "array" and node.element ~= nil then
        return "[" .. Template.fingerprint(node.element) .. "]"
    elseif node.k == "optional" and node.element ~= nil then
        return "?" .. Template.fingerprint(node.element)
    end
    return node.k
end

local function emptyTable(node: Node): boolean
    return node.k == "table" and (node.fields == nil or next(node.fields) == nil)
end

local function repair(node: Node, reference: Node?): Node
    if reference == nil or node.k ~= "table" or reference.k ~= "table" or node.fields == nil or reference.fields == nil then
        return node
    end
    for key, child in node.fields do
        local known = reference.fields[key]
        if known ~= nil then
            if emptyTable(child) and known.k == "array" then
                node.fields[key] = known
            elseif child.k == "table" and known.k == "table" then
                repair(child, known)
            end
        end
    end
    return node
end

local function read()
    loaded = true
    table.clear(shapes)
    version += 1
    local ok, data = pcall(function(): any
        if not isfile(FILE) then
            return nil
        end
        return json():JSONDecode(readfile(FILE))
    end)
    if ok and type(data) == "table" and type(data.shapes) == "table" then
        for logical, node in data.shapes do
            if Template.SUPPORTED[logical] and type(node) == "table" and type(node.k) == "string" then
                shapes[logical] = repair(node, Template.DEFAULTS[logical])
            end
        end
    end
end

local function write()
    pcall(function()
        if not isfolder("oklo scripts") then
            makefolder("oklo scripts")
        end
        if not isfolder(Constants.CACHE_FOLDER) then
            makefolder(Constants.CACHE_FOLDER)
        end
        writefile(FILE, json():JSONEncode({ version = 1, savedAt = os.time(), shapes = shapes }))
    end)
end

function Template.has(logical: string): boolean
    if not loaded then
        read()
    end
    return shapes[logical] ~= nil
end

function Template.ready(logical: string): boolean
    return Template.SUPPORTED[logical] == true
end

function Template.provide(name: string, getter: (() -> any)?)
    providers[name] = getter :: any
end

function Template.reset()
    table.clear(shapes)
    table.clear(notes)
    table.clear(counts)
    table.clear(chains)
    table.clear(refusedAt)
    table.clear(inUse)
    table.clear(plans)
    Schema.reset()
    version += 1
    loaded = true
end

local function decode(object: any, data: buffer): (any, string)
    local problems: { string } = {}
    for _, cursor in { 2, 1, 0 } do
        local ok, value = pcall(object.reader, data, cursor)
        if ok and (type(value) == "table" or type(value) == "number") then
            return value, "reader at byte " .. tostring(cursor)
        end
        table.insert(problems, if ok then "got " .. type(value) else string.sub(tostring(value), 1, 60))
    end
    return nil, "reader failed: " .. table.concat(problems, " | ")
end

function Template.wants(logical: string): boolean
    local seen = (counts[logical] or 0) + 1
    counts[logical] = seen
    return seen <= 3 or seen % 25 == 0
end

function Template.learn(logical: string, object: any, data: buffer): boolean
    if not loaded then
        read()
    end
    if type(object) ~= "table" or type(object.reader) ~= "function" then
        notes[logical] = "the packet object has no reader function"
        return false
    end
    local value, how = decode(object, data)
    if value == nil then
        notes[logical] = how
        return false
    end
    return Template.learnValue(logical, value, how)
end

function Template.learnValue(logical: string, value: any, how: string): boolean
    if not loaded then
        read()
    end
    if not Template.SUPPORTED[logical] then
        return false
    end
    local node = describe(value, 1)
    if node == nil or (node.k ~= "table" and node.k ~= "number") then
        notes[logical] = how .. " but the value has parts that cannot be copied"
        return false
    end
    local current = shapes[logical]
    node = repair(node, current or Template.DEFAULTS[logical])
    if current ~= nil and Template.fingerprint(current) == Template.fingerprint(node) then
        notes[logical] = how .. ", same layout as before"
        return false
    end
    shapes[logical] = node
    version += 1
    notes[logical] = how .. ", layout learned"
    write()
    return true
end

local function summary(value: any, depth: number): string
    local kind = typeof(value)
    if kind == "number" or kind == "string" or kind == "boolean" then
        return kind .. "=" .. tostring(value)
    elseif kind == "table" and depth < 4 then
        local parts: { string } = {}
        for key, item in value do
            table.insert(parts, tostring(key) .. ":" .. summary(item, depth + 1))
            if #parts >= 6 then
                break
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return kind
end

local function matches(name: string, words: { string }): boolean
    local lower = string.lower(name)
    for _, word in words do
        if string.find(lower, word, 1, true) then
            return true
        end
    end
    return false
end

local function numeric(node: Node): Node?
    if node.k == "number" then
        return node
    elseif node.k == "optional" and node.element ~= nil and node.element.k == "number" then
        return node.element
    end
    return nil
end

local function plan(logical: string, node: Node): { [string]: string }
    local cached = plans[node]
    if cached ~= nil then
        return cached
    end
    local roles: { [string]: string } = {}
    local used: { [string]: boolean } = {}
    local allowed: { string } = ROLES[logical] or {}
    local optional: { [string]: boolean } = OPTIONAL[logical] or {}
    local fields = node.fields or {}
    local keys = sortedKeys(fields)
    for _, key in keys do
        if numeric(fields[key]) ~= nil then
            for _, role in ORDER do
                if not used[role] and table.find(allowed, role) ~= nil and matches(key, WORDS[role]) then
                    roles[key] = role
                    used[role] = true
                    break
                end
            end
        end
    end
    for _, role in allowed do
        if not used[role] and not optional[role] then
            local best: string? = nil
            local bestRank = math.huge
            for _, key in keys do
                local number = numeric(fields[key])
                if number ~= nil and roles[key] == nil then
                    local rank = table.find(PREFER[role], number.t or "number") or (if role == "stamp" then nil else 50)
                    if rank ~= nil and rank < bestRank then
                        best, bestRank = key, rank
                    end
                end
            end
            if best ~= nil then
                roles[best] = role
                used[role] = true
            end
        end
    end
    if logical == "PlaceStructure" then
        local named: string? = nil
        for _, key in keys do
            local child = fields[key]
            local text = child.k == "string" or (child.k == "optional" and child.element ~= nil and child.element.k == "string")
            if text and (named == nil or matches(key, NAME_WORDS)) then
                if named == nil or not matches(named, NAME_WORDS) then
                    named = key
                end
            end
        end
        if named ~= nil then
            roles[named] = "name"
        end
    end
    plans[node] = roles
    return roles
end

local function provided(params: { [string]: any }, name: string): any
    local cached = params["@" .. name]
    if cached ~= nil then
        return if cached == false then nil else cached
    end
    local getter = providers[name]
    local value: any = nil
    if getter ~= nil then
        local ok, result = pcall(getter)
        value = if ok then result else nil
    end
    params["@" .. name] = if value == nil then false else value
    return value
end

local function roleValue(logical: string, role: string, params: { [string]: any }): any
    if role == "stamp" then
        return params.stamp
    elseif role == "entity" then
        return params.entity or (if type(params.ids) == "table" then params.ids[1] else nil)
    elseif role == "item" then
        if logical == "SwingTool" then
            return provided(params, "toolItem")
        end
        return params.item
    elseif role == "slot" then
        if logical == "SwingTool" then
            return provided(params, "toolSlot")
        end
        return params.slot
    elseif role == "quantity" then
        return params.quantity or 1
    end
    return nil
end

local function frameOf(params: { [string]: any }): any
    return params.frame or provided(params, "frame")
end

local function hintField(hint: Node?, key: string): Node?
    if hint == nil or hint.k ~= "table" or hint.fields == nil then
        return nil
    end
    return hint.fields[key]
end

local fill: (logical: string, node: Node, name: string, params: { [string]: any }, hint: Node?, role: string?) -> any

local function sampleOf(node: Node, hint: Node?): any
    if hint ~= nil and hint.sample ~= nil and hint.k == node.k then
        return hint.sample
    end
    return node.sample
end

local function entityList(logical: string, node: Node, params: { [string]: any }, hint: Node?): { any }
    local list: { any } = {}
    local element = node.element :: Node
    local hintElement = if hint ~= nil and hint.k == "array" then hint.element else nil
    local ids: { any } = if type(params.ids) == "table" then params.ids elseif params.entity ~= nil then { params.entity } else {}
    for _, id in ids do
        if element.k == "number" then
            table.insert(list, id)
        elseif element.k == "table" then
            local entry = fill("entry", element, "", { entity = id, stamp = params.stamp, frame = params.frame }, hintElement, nil)
            table.insert(list, entry)
        end
    end
    return list
end

local function wantsEntities(logical: string, node: Node, name: string): boolean
    local element = node.element
    if element == nil or (element.k ~= "number" and element.k ~= "table") then
        return false
    end
    if logical == "SwingTool" then
        return true
    end
    return PRIMARY[logical] == "entity" and (name == "" or matches(name, WORDS.entity))
end

fill = function(logical: string, node: Node, name: string, params: { [string]: any }, hint: Node?, role: string?): any
    local kind = node.k
    if logical == "SwingTool" and emptyTable(node) and name ~= "" and matches(name, WORDS.entity) then
        node = (Template.DEFAULTS.SwingTool.fields :: { [string]: Node }).entityIDs
        kind = node.k
    end
    if kind == "number" then
        local wanted = role or (if name == "" then PRIMARY[logical] else nil)
        if wanted ~= nil then
            local value = roleValue(logical, wanted, params)
            if value ~= nil then
                return value
            end
        end
        return tonumber(sampleOf(node, hint)) or 0
    elseif kind == "CFrame" then
        return frameOf(params)
    elseif kind == "Vector3" then
        local frame = frameOf(params)
        return if frame ~= nil then frame.Position else nil
    elseif kind == "string" then
        if logical == "PlaceStructure" and params.name ~= nil and (name == "" or role == "name") then
            return params.name
        end
        local sample = sampleOf(node, hint)
        return if type(sample) == "string" then sample else ""
    elseif kind == "boolean" then
        return sampleOf(node, hint) == true
    elseif kind == "array" then
        if wantsEntities(logical, node, name) then
            return entityList(logical, node, params, hint)
        end
        return {}
    elseif kind == "optional" then
        local element = node.element
        if element == nil then
            return nil
        end
        if element.k == "number" then
            if role ~= nil then
                return roleValue(logical, role, params)
            end
            local sample = if hint ~= nil then hint.sample else nil
            return if type(sample) == "number" then sample else nil
        elseif element.k == "CFrame" or element.k == "Vector3" or element.k == "array" or element.k == "table" then
            return fill(logical, element, name, params, hint, role)
        elseif element.k == "string" and logical == "PlaceStructure" then
            return fill(logical, element, name, params, hint, role)
        end
        return nil
    elseif kind == "table" then
        local fields = node.fields or {}
        local roles = plan(logical, node)
        local out: { [string]: any } = {}
        for _, key in sortedKeys(fields) do
            out[key] = fill(logical, fields[key], key, params, hintField(hint, key), roles[key])
        end
        return out
    elseif kind == "map" then
        return {}
    end
    if hint ~= nil and hint.sample ~= nil then
        return hint.sample
    end
    return nil
end

function Template.params(logical: string, args: { any }, stamp: number): { [string]: any }?
    if logical == "SwingTool" then
        local ids = args[1]
        local frame = args[2]
        if type(ids) ~= "table" or frame == nil then
            return nil
        end
        return { ids = ids, frame = frame, stamp = tonumber(args[3]) or stamp }
    elseif logical == "PlaceStructure" then
        if type(args[1]) ~= "string" or args[2] == nil then
            return nil
        end
        return { name = args[1], frame = args[2], stamp = stamp }
    elseif logical == "OpenChest" or logical == "Pickup" or logical == "ForceInteract" then
        if type(args[1]) ~= "number" then
            return nil
        end
        return { entity = args[1], stamp = stamp }
    elseif logical == "InteractStructure" then
        if type(args[1]) ~= "number" or type(args[2]) ~= "number" then
            return nil
        end
        return { entity = args[1], item = args[2], stamp = stamp }
    elseif logical == "UseBagItem" then
        if type(args[1]) ~= "number" then
            return nil
        end
        return { slot = args[1], item = tonumber(args[2]), stamp = stamp }
    elseif logical == "DropBagItem" then
        if type(args[1]) ~= "number" then
            return nil
        end
        return { slot = args[1], quantity = tonumber(args[2]), stamp = stamp }
    end
    return nil
end

local function chainOf(logical: string, object: any): { Entry }
    if not loaded then
        read()
    end
    local cached = chains[logical]
    if cached ~= nil and cached.object == object and cached.version == version then
        return cached.list
    end
    local list: { Entry } = {}
    local seen: { [string]: boolean } = {}
    local function add(label: string, node: Node?)
        if node == nil then
            return
        end
        local mark = Template.fingerprint(node)
        if seen[mark] then
            return
        end
        seen[mark] = true
        table.insert(list, { label = label, node = node })
    end
    add(GAME_CODE, (Schema.of(object)))
    add(COPIED, shapes[logical])
    add(BUILT_IN, Template.DEFAULTS[logical])
    chains[logical] = { object = object, version = version, list = list }
    return list
end

local sending = false

function Template.sending(): boolean
    return sending
end

function Template.distrust(logical: string, label: string?)
    if label == nil then
        return
    end
    local refused = refusedAt[logical] or {}
    refusedAt[logical] = refused
    refused[label] = os.clock()
    notes[logical] = label .. " was sent but never seen on the wire, trying the next layout for a while"
end

function Template.send(logical: string, object: any, args: { any }, stamp: number): (boolean, string?, string?)
    if not Template.SUPPORTED[logical] or type(object) ~= "table" or type(object.send) ~= "function" then
        return false, nil, nil
    end
    local params = Template.params(logical, args, stamp)
    if params == nil then
        return false, nil, nil
    end
    local list = chainOf(logical, object)
    local refused = refusedAt[logical]
    local now = os.clock()
    local problems: { string } = {}
    for position, entry in list do
        local at = if refused ~= nil then refused[entry.label] else nil
        if at == nil or now - at >= REFUSE_FOR or position == #list then
            local payload = fill(logical, entry.node, "", params, if entry.label == COPIED then nil else shapes[logical], nil)
            if payload ~= nil or entry.node.k == "nothing" then
                sending = true
                local ok, problem = pcall(object.send, payload)
                sending = false
                if ok then
                    if inUse[logical] ~= entry.label then
                        inUse[logical] = entry.label
                        notes[logical] = "sent with the " .. entry.label
                    end
                    return true, nil, entry.label
                end
                local marks = refusedAt[logical] or {}
                refusedAt[logical] = marks
                marks[entry.label] = now
                table.insert(problems, entry.label .. " refused: " .. tostring(problem) .. " | sent " .. string.sub(summary(payload, 1), 1, 200))
            end
        end
    end
    if #problems == 0 then
        return false, nil, nil
    end
    inUse[logical] = nil
    notes[logical] = table.concat(problems, " || ")
    return false, problems[1], nil
end

function Template.lines(objectOf: ((string) -> any)?): { string }
    if not loaded then
        read()
    end
    local lines: { string } = {}
    local names: { string } = {}
    for logical in Template.SUPPORTED do
        table.insert(names, logical)
    end
    table.sort(names)
    for _, logical in names do
        local cached = chains[logical]
        local parts: { string } = {}
        local object = if cached ~= nil then cached.object elseif objectOf ~= nil then objectOf(logical) else nil
        local schemaNote = "not read yet (read on the first send)"
        if object ~= nil then
            local node, note = Schema.of(object)
            schemaNote = (if node ~= nil then Schema.text(node) .. ", " else "") .. note
        end
        table.insert(parts, "game code " .. schemaNote)
        local node = shapes[logical]
        table.insert(parts, "copied " .. (if node ~= nil then Template.fingerprint(node) else "nothing yet"))
        local default = Template.DEFAULTS[logical]
        table.insert(parts, "built-in " .. (if default ~= nil then Template.fingerprint(default) else "none"))
        table.insert(parts, "in use: " .. (inUse[logical] or "none yet"))
        table.insert(lines, "layout " .. logical .. ": " .. table.concat(parts, " | ") .. " | last try: " .. (notes[logical] or "none"))
    end
    return lines
end

return Template
end
modules["game/world"] = function(...)

local import: (string) -> any = ...
local Constants: typeof(require("./constants")) = import("game/constants")
local Modules: typeof(require("./modules")) = import("game/modules")

local World = {}

export type Entry = { instance: any, name: string, entityId: number?, position: Vector3, distance: number }
export type Query = {
    origin: Vector3?,
    range: number?,
    names: { string }?,
    contains: { string }?,
    match: ((any) -> boolean)?,
    requireId: boolean?,
    minimumId: number?,
    deepId: boolean?,
    limit: number?,
}
export type ServerType = "Overworld" | "Void" | "Unknown"

World.Players = Modules.service("Players")
World.LocalPlayer = if World.Players then World.Players.LocalPlayer else nil

function World.workspace(): any
    return Modules.service("Workspace")
end

function World.folder(name: string): any
    local space = World.workspace()
    if not space then
        return nil
    end
    local key = (Constants.FOLDERS :: { [string]: string })[name] or name
    return space:FindFirstChild(key)
end

function World.itemsFolder(): any
    return World.folder("Items") or World.folder("DroppedItems")
end

function World.character(player: any?): any
    local owner = player or World.LocalPlayer
    if not owner then
        return nil
    end
    local character = owner.Character
    if character ~= nil and character.Parent ~= nil then
        return character
    end
    local folder = World.folder("Players")
    local custom = if folder then folder:FindFirstChild(owner.Name) else nil
    if custom ~= nil and custom:IsA("Model") then
        return custom
    end
    return character
end

function World.rootOf(model: any): any
    if model == nil then
        return nil
    end
    return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

function World.humanoidOf(model: any): any
    if model == nil then
        return nil
    end
    return model:FindFirstChildOfClass("Humanoid")
end

function World.root(): any
    return World.rootOf(World.character())
end

function World.humanoid(): any
    return World.humanoidOf(World.character())
end

function World.position(): Vector3?
    local root = World.root()
    return if root then root.Position else nil
end

local function aliveIn(character: any): (boolean, any)
    local root = World.rootOf(character)
    local humanoid = World.humanoidOf(character)
    return root ~= nil and humanoid ~= nil and humanoid.Health > 0, root
end

function World.isAlive(): boolean
    return (aliveIn(World.character()))
end

function World.isSpawned(): boolean
    local player = World.LocalPlayer
    if player and player:GetAttribute("hasSpawned") == false then
        return false
    end
    local alive, root = aliveIn(World.character())
    if not alive or root == nil then
        return false
    end
    return root.Position.Y <= 800
end

function World.partOf(instance: any): any
    if instance == nil then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") then
        return instance.PrimaryPart
            or instance:FindFirstChild("HumanoidRootPart")
            or instance:FindFirstChild("Hitbox")
            or instance:FindFirstChildWhichIsA("BasePart", true)
    end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function pivotOf(instance: any): any
    return instance:GetPivot()
end

function World.positionOf(instance: any): Vector3?
    if instance == nil then
        return nil
    end
    local part = World.partOf(instance)
    if part then
        return part.Position
    end
    local ok, pivot = pcall(pivotOf, instance)
    if ok and pivot then
        return pivot.Position
    end
    return nil
end

local function wholeNumber(value: any, minimum: number): number?
    local number = tonumber(value)
    if number == nil or number ~= number then
        return nil
    end
    number = math.floor(number)
    if number > minimum and number < 2 ^ 32 then
        return number
    end
    return nil
end

local function attributeId(instance: any, minimum: number): number?
    for _, key in Constants.ENTITY_ATTRIBUTES do
        local id = wholeNumber(instance:GetAttribute(key), minimum)
        if id then
            return id
        end
    end
    local ok, attributes = pcall(function()
        return instance:GetAttributes()
    end)
    if ok and type(attributes) == "table" then
        for name, value in attributes do
            local lower = World.lower(tostring(name))
            if type(value) == "number" and (lower == "id" or lower == "eid" or string.find(lower, "entity", 1, true) or string.find(lower, "network", 1, true)) then
                local id = wholeNumber(value, minimum)
                if id then
                    return id
                end
            end
        end
    end
    for _, key in Constants.ENTITY_ATTRIBUTES do
        local child = instance:FindFirstChild(key)
        if child and (child:IsA("IntValue") or child:IsA("NumberValue")) then
            local id = wholeNumber(child.Value, minimum)
            if id then
                return id
            end
        end
    end
    return nil
end

local function isModelOf(instance: any): boolean
    return instance:IsA("Model")
end

function World.entityId(instance: any, minimum: number?, deep: boolean?): number?
    if instance == nil then
        return nil
    end
    local floor = minimum or 0
    local ok, id = pcall(attributeId, instance, floor)
    if ok and id then
        return id
    end
    local okModel, isModel = pcall(isModelOf, instance)
    if okModel and isModel and instance.PrimaryPart then
        local primary = select(2, pcall(attributeId, instance.PrimaryPart, floor))
        if type(primary) == "number" then
            return primary
        end
    end
    if deep then
        for _, descendant in instance:GetDescendants() do
            local found = select(2, pcall(attributeId, descendant, floor))
            if type(found) == "number" then
                return found
            end
        end
    end
    return nil
end

local MEMO_LIMIT = 4096
local normalized: { [string]: string } = {}
local normalizedCount = 0
local lowered: { [string]: string } = {}
local loweredCount = 0

function World.normalize(name: any): string
    local text = if type(name) == "string" then name else tostring(name)
    local cached = normalized[text]
    if cached ~= nil then
        return cached
    end
    local result = (string.gsub(string.lower(text), "[%s_%-]", ""))
    if normalizedCount >= MEMO_LIMIT then
        table.clear(normalized)
        normalizedCount = 0
    end
    normalized[text] = result
    normalizedCount += 1
    return result
end

function World.lower(text: string): string
    local cached = lowered[text]
    if cached ~= nil then
        return cached
    end
    local result = string.lower(text)
    if loweredCount >= MEMO_LIMIT then
        table.clear(lowered)
        loweredCount = 0
    end
    lowered[text] = result
    loweredCount += 1
    return result
end

local function nameMatches(name: string, names: { string }?, wantedNames: { string }?, pieces: { string }?): boolean
    if names == nil and pieces == nil then
        return true
    end
    if names and wantedNames then
        local normalizedName = World.normalize(name)
        for index, wanted in names do
            if wanted == name or wantedNames[index] == normalizedName then
                return true
            end
        end
    end
    if pieces then
        local lower = World.lower(name)
        for _, piece in pieces do
            if string.find(lower, piece, 1, true) then
                return true
            end
        end
    end
    return false
end

local function entryOf(instance: any, options: Query, origin: Vector3?, range: number, wantedNames: { string }?, pieces: { string }?): Entry?
    local name = instance.Name
    if not nameMatches(name, options.names, wantedNames, pieces) then
        return nil
    end
    if options.match and not options.match(instance) then
        return nil
    end
    local position = World.positionOf(instance)
    if position == nil then
        return nil
    end
    local distance = if origin then (position - origin).Magnitude else 0
    if distance > range then
        return nil
    end
    local id = World.entityId(instance, options.minimumId, options.deepId)
    if options.requireId and id == nil then
        return nil
    end
    return { instance = instance, name = name, entityId = id, position = position, distance = distance }
end

local function nearer(a: Entry, b: Entry): boolean
    return a.distance < b.distance
end

function World.collect(list: { any }, query: Query?): { Entry }
    local options: Query = query or {}
    local origin = options.origin or World.position()
    local range = options.range or math.huge
    local results: { Entry } = {}
    local seen: { [number]: boolean } = {}
    local wantedNames: { string }? = nil
    local names = options.names
    if names then
        local prepared: { string } = table.create(#names)
        for index, wanted in names do
            prepared[index] = World.normalize(wanted)
        end
        wantedNames = prepared
    end
    local pieces: { string }? = nil
    local contains = options.contains
    if contains then
        local prepared: { string } = table.create(#contains)
        for index, piece in contains do
            prepared[index] = string.lower(piece)
        end
        pieces = prepared
    end
    for _, instance in list do
        local ok, entry = pcall(entryOf, instance, options, origin, range, wantedNames, pieces)
        if ok and entry then
            local id = entry.entityId
            if id == nil or not seen[id] then
                if id then
                    seen[id] = true
                end
                table.insert(results, entry)
            end
        end
    end
    table.sort(results, nearer)
    local limit = options.limit
    if limit and #results > limit then
        for index = #results, limit + 1, -1 do
            results[index] = nil
        end
    end
    return results
end

local function walk(node: any, list: { any }, deep: boolean?)
    for _, child in node:GetChildren() do
        if child:IsA("Model") or child:IsA("BasePart") then
            table.insert(list, child)
        elseif deep and child:IsA("Folder") then
            walk(child, list, deep)
        end
    end
end

function World.children(folder: any, deep: boolean?): { any }
    if folder == nil then
        return {}
    end
    local list: { any } = {}
    walk(folder, list, deep)
    return list
end

function World.placeId(): number
    return game.PlaceId
end

function World.serverType(): ServerType
    local place = World.placeId()
    if place == Constants.PLACES.Overworld then
        return "Overworld"
    elseif place == Constants.PLACES.Void then
        return "Void"
    end
    return "Unknown"
end

function World.isPrivateServer(): boolean
    local ok, id = pcall(function()
        return ""
    end)
    if ok and id ~= "" then
        return true
    end
    local space = World.workspace()
    local attribute = if space then space:GetAttribute("privateServerId") else nil
    return attribute ~= nil and tostring(attribute) ~= ""
end

return World
end
modules["goldfarm/gold"] = function(...)

local import: (string) -> any = ...
local Loops: any = import("goldfarm/gold/loops")
local Paths: any = import("goldfarm/gold/paths")
local Runner: any = import("goldfarm/gold/runner")
local Options: any = import("goldfarm/gold/options")
local Dropwatch: any = import("goldfarm/gold/dropwatch")
local Pointer: any = import("goldfarm/gold/pointer")
local Ground: any = import("goldfarm/gold/ground")
local Editor: any = import("goldfarm/gold/editor")
local Chest: any = import("goldfarm/gold/chest")
local Press: any = import("goldfarm/gold/press")
local Slots: any = import("goldfarm/gold/slots")
local Utility: any = import("goldfarm/gold/utility")
local Items: any = import("goldfarm/gold/items")
local Link: any = import("goldfarm/link")

local Part = {}
Part.__index = Part

Part.Defaults = {
    GoldStartPath = false,
    GoldNodeDetect = false,
    GoldShowPath = false,
    GoldEditorStep = 1,
    GoldEditorDrag = "Ground",
    GoldEditorValidate = true,
    GoldEditorGap = 700,
    GoldAutoSelectChest = false,
    GoldAutoOpenChest = false,
    GoldEquipFirstSlot = false,
    GoldAutoStartPath = false,
    GoldChestAttract = true,
    GoldPauseNearPress = false,
    GoldHitAura = false,
    GoldSwitchSlots = false,
    GoldCoinPress = false,
    GoldPickupChest = false,
    GoldPickCoins = false,
    GoldPickupAir = false,
    GoldRefillCampfire = false,
    GoldAntiStuck = true,
    GoldWalkSpeedOn = false,
    GoldWalkSpeed = 19,
    GoldLockCamera = false,
} :: { [string]: any }

local COINS_POPUP = "boogagold:coins"
local AURA_RANGE = 20
local AURA_TARGETS = 2
local AIR_RANGE = 35
local AIR_LIMIT = 15
local COIN_RANGE = 35
local COIN_LIMIT = 100
local CHEST_RANGE = 45
local CHEST_LIMIT = 25
local CAMPFIRE_RANGE = 45
local FUEL_LIMIT = 200
local FUEL_ROUNDS = 15
local RETRY = 5
local EQUIP_DELAY = 1.5
local START_DELAY = 2.5

function Part.new(context: any): any
    local Game = context.Game
    local paths = Paths.new(context.Folder, Game.modules.service("HttpService"))
    paths:loadDefault()
    local self = setmetatable({
        Context = context,
        Game = Game,
        Paths = paths,
        Loops = Loops.new(context),
        CoinsConfirmed = false,
        Missing = {} :: { [string]: number },
        AuraSent = 0,
        Ui = nil :: any,
    }, Part)
    self.Runner = Runner.new(context, paths)
    self.Ground = Ground.new(context)
    self.Pointer = Pointer.new(context, self.Ground, function()
        self:clicked()
    end)
    self.Editor = Editor.new(context, paths, self.Pointer, self.Ground, {
        start = function(index: number)
            self:startFrom(index)
        end,
        runner = function(): number?
            return self.Runner.Index
        end,
    })
    self.Chest = Chest.new(context, self.Pointer)
    self.Press = Press.new(context)
    self.Slots = Slots.new(context)
    self.Drops = Dropwatch.new(context)
    Game.addReport(function(): { string }
        local equipped = Game.inventory.equippedName()
        return {
            "gold aura: holding " .. tostring(equipped) .. ", gold nodes within " .. AURA_RANGE .. " studs: " .. #Game.finder.resources(AURA_RANGE, { contains = { "gold" } }) .. ", swings sent: " .. self.AuraSent .. ", swing layout learned: " .. tostring(Game.template.has("SwingTool")) .. ", last swing went out as " .. tostring(Game.packets.lastVia("SwingTool")),
        }
    end)
    Game.observer.listen(function(logical: string, name: string)
        context.notify(logical .. " packet learned: " .. name)
    end)
    Game.packets.notify(function(text: string)
        context.notify(text)
    end)
    self.Utility = Utility.new(context)
    Link.set(context, "gold", self)
    return self
end

function Part.clicked(self: any)
    if self.Chest:click() then
        return
    end
    self.Editor:press()
end

function Part.startFrom(self: any, index: number)
    self.Runner.Pending = index
    if self.Context.read("GoldStartPath") == true then
        self.Runner:restart()
    else
        self.Context.set("GoldStartPath", true)
    end
end

function Part.packet(self: any, name: string, label: string): boolean
    local packets = self.Game.packets
    if packets.has(name) then
        self.Missing[name] = nil
        return true
    end
    local checked = self.Missing[name]
    if checked ~= nil and os.clock() - checked < RETRY then
        return false
    end
    packets.resolve()
    if packets.has(name) then
        self.Missing[name] = nil
        return true
    end
    if checked == nil then
        self.Context.notify(label .. ": game packet " .. name .. " not found. " .. self.Game.observer.hint(name))
    end
    self.Missing[name] = os.clock()
    return false
end

function Part.antiStuckText(self: any): string
    local read = self.Context.read
    if read("GoldStartPath") ~= true then
        return "Anti-Stuck: idle"
    elseif self.Press.Paused then
        return "Anti-Stuck: paused by Coin Press"
    elseif not self.Game.world.isSpawned() then
        return "Anti-Stuck: waiting for spawn"
    elseif read("GoldAntiStuck") ~= true then
        return "Anti-Stuck: off"
    end
    return "Anti-Stuck Timer: " .. tostring(self.Runner:stuckRemaining()) .. "s"
end

function Part.addLoops(self: any)
    local loops = self.Loops
    local Game = self.Game
    local read = self.Context.read

    loops:add({
        flag = "GoldStartPath",
        interval = 0.05,
        start = function(): boolean
            self.Runner:restart(false)
            return true
        end,
        body = function()
            local blocked = self.Press.Paused or Game.movement.isFrozen()
            self.Runner:tick(blocked, self.Chest:holding(), read("GoldAntiStuck") == true)
        end,
        stop = function()
            self.Runner:finish()
        end,
    })
    loops:add({
        flag = "GoldHitAura",
        interval = 0.08,
        body = function()
            if self:packet("SwingTool", "Gold Hit Aura") then
                if not self.SwingHinted and not Game.template.ready("SwingTool") then
                    self.SwingHinted = true
                    self.Context.notify("Gold Hit Aura: swing your pickaxe once by hand so the script learns the game's current swing format")
                end
                self.AuraSent += Game.actions.hit(Game.finder.resources(AURA_RANGE, { contains = { "gold" } }), AURA_TARGETS)
            end
        end,
    })
    loops:add({
        flag = "GoldAutoStartPath",
        interval = 0.25,
        body = function()
            if self.StartedPath then
                return
            end
            local value = read("GoldStartPath") == true
            if self.PathSeen == nil then
                self.PathSeen = value
            elseif value ~= self.PathSeen then
                self.StartedPath = true
                return
            end
            if not Game.world.isSpawned() then
                self.PathSpawnedSince = nil
                return
            end
            local now = os.clock()
            if self.PathSpawnedSince == nil then
                self.PathSpawnedSince = now
            end
            if now - self.PathSpawnedSince >= START_DELAY then
                self.StartedPath = true
                if read("GoldStartPath") ~= true then
                    self.Context.set("GoldStartPath", true)
                end
            end
        end,
    })
    loops:add({
        flag = "GoldEquipFirstSlot",
        interval = 0.25,
        body = function()
            if self.EquippedFirst then
                return
            end
            if not Game.world.isSpawned() then
                self.SpawnedSince = nil
                return
            end
            local now = os.clock()
            if self.SpawnedSince == nil then
                self.SpawnedSince = now
            end
            if now - self.SpawnedSince >= EQUIP_DELAY then
                self.EquippedFirst = true
                Game.actions.pressSlotKey(1)
            end
        end,
    })
    loops:add({
        flag = "GoldPickupAir",
        interval = 0.08,
        body = function()
            if self:packet("Pickup", "Pickup Gold Bars on Ground") then
                Game.actions.pickupEntries(Items.loose(Game, AIR_RANGE, true), AIR_LIMIT)
            end
        end,
    })
    loops:add({
        flag = "GoldPickCoins",
        interval = 0.08,
        body = function()
            if self:packet("Pickup", "Pick Coins") then
                local coins = Game.finder.coins(COIN_RANGE)
                Game.actions.pickupEntries(coins, COIN_LIMIT)
                local webhook = Link.get(self.Context, "webhook")
                if webhook ~= nil then
                    webhook.Stats:coins(coins, COIN_LIMIT)
                end
            end
        end,
    })
    loops:add({
        flag = "GoldPickupChest",
        interval = 0.08,
        body = function()
            if read("GoldCoinPress") == true and Game.finder.nearestCoinPress(CHEST_RANGE) ~= nil then
                return
            end
            if self:packet("Pickup", "Pickup Gold Bars from Chest") then
                Game.chests.takeNearby(CHEST_RANGE, Game.constants.COOKED_GOLD_NAMES, CHEST_LIMIT)
            end
        end,
    })
    loops:add({
        flag = "GoldAutoSelectChest",
        interval = 0.1,
        body = function()
            self.Chest:autoSelect()
        end,
    })
    loops:add({
        flag = "GoldAutoOpenChest",
        interval = 0.25,
        body = function()
            if self:packet("OpenChest", "Auto Open Chest") then
                self.Chest:autoOpen()
            end
        end,
    })
    loops:add({
        flag = "GoldChestAttract",
        interval = 0.1,
        body = function()
            if self:packet("ForceInteract", "Move Gold To Chest") then
                self.Chest:magnet()
            end
        end,
        stop = function()
            self.Chest:release()
        end,
    })
    loops:add({
        flag = "GoldCoinPress",
        interval = 0.04,
        body = function()
            if self:packet("InteractStructure", "Coin Press") then
                self.Press:tick()
            else
                self.Press:resume()
            end
        end,
        stop = function()
            self.Press:reset()
        end,
    })
    loops:add({
        flag = "GoldSwitchSlots",
        interval = 0.25,
        body = function()
            self.Slots:tick()
        end,
        stop = function()
            self.Slots:reset()
        end,
    })
    loops:add({
        flag = "GoldRefillCampfire",
        interval = 0.25,
        body = function()
            if self:packet("InteractStructure", "Refill Campfire") then
                self:refill()
            end
        end,
    })
end

function Part.refill(self: any)
    local Game = self.Game
    for _, fire in Game.finder.campfires(CAMPFIRE_RANGE) do
        local fuel = Game.finder.campfireFuel(fire.instance)
        if fuel == nil and not self.FuelUnreadable then
            self.FuelUnreadable = true
            self.Context.notify("Refill Campfire: the fuel of this campfire could not be read, send packet report.txt")
        end
        if fuel ~= nil and fuel <= FUEL_LIMIT then
            for _ = 1, FUEL_ROUNDS do
                local sent = false
                for _, name in { "Wood", "Leaves" } do
                    if Game.inventory.has(name) and Game.actions.fuel(fire.instance, name) then
                        sent = true
                    end
                end
                if not sent or not self.Context.wait(0.05) then
                    break
                end
                local now = Game.finder.campfireFuel(fire.instance)
                if now == nil or now > FUEL_LIMIT then
                    break
                end
            end
        end
    end
end

function Part.registerCoinsPopup(self: any, ui: any)
    ui:popup(COINS_POPUP, {
        Width = 340,
        Height = 236,
        Title = "",
        Locked = true,
        Render = function(kit: any, window: any)
            local top = kit:header("Pick Coins", "Please confirm", function()
                window:closePopup()
            end)
            kit:lines({
                "Pick Coins sends a pickup for every coin",
                "within 35 studs, up to 100 per tick.",
                "That is much faster than picking by hand.",
                "Turn it on?",
            }, top + 14, 17, 12)
            local half = (kit.Width - 40) / 2
            kit:button("gold:coins:yes", 16, kit.Height - 58, half, 32, function()
                self.CoinsConfirmed = true
                window:set(self.CoinsFlag or "GoldPickCoins", true)
                window:closePopup()
            end, { label = "Turn On", align = "center" })
            kit:button("gold:coins:no", 24 + half, kit.Height - 58, half, 32, function()
                window:closePopup()
            end, { label = "Cancel", align = "center" })
        end,
    })
end

function Part.coinsToggle(self: any, section: any, flag: string, disabled: (() -> boolean)?)
    local context = self.Context
    local ui = self.Ui
    section:toggle({
        Name = "Pick Coins",
        Flag = flag,
        Default = false,
        Disabled = disabled,
        Callback = function(on: boolean)
            if on and not self.CoinsConfirmed then
                context.set(flag, false)
                self.CoinsFlag = flag
                ui:openPopup(COINS_POPUP)
            elseif not on then
                self.CoinsConfirmed = false
            end
            self.Loops:sync()
        end,
    })
end

function Part.build(self: any, ui: any, tab: any)
    local context = self.Context
    self.Ui = ui
    for _, flag in { "GoldEditorStep", "GoldEditorDrag", "GoldEditorValidate", "GoldEditorGap" } do
        ui:flag(flag, Part.Defaults[flag], true)
    end
    self.Editor.Ui = ui
    self:registerCoinsPopup(ui)
    self:addLoops()
    local function kick()
        self.Loops:sync()
    end

    local gold = tab:section("GOLD")
    gold:label({ Text = "Route", Size = 12, Height = 28, Offset = 4 })

    local setup = {
        Flags = {
            HitAura = "GoldHitAura",
            SwitchSlots = "GoldSwitchSlots",
            CoinPress = "GoldCoinPress",
            PauseNearPress = "GoldPauseNearPress",
            RefillCampfire = "GoldRefillCampfire",
            AutoSelectChest = "GoldAutoSelectChest",
            ChestAttract = "GoldChestAttract",
            PickupChest = "GoldPickupChest",
            PickCoins = "GoldPickCoins",
            PickupAir = "GoldPickupAir",
        },
        Kick = kick,
        Read = context.read,
        ChestButton = function(section: any, disabled: (() -> boolean)?)
            section:button({
                Name = "Select Gold Chest",
                Label = function(): string
                    return self.Chest:label()
                end,
                Active = function(): boolean
                    return self.Chest.Listening or self.Chest:valid()
                end,
                Disabled = disabled,
                Callback = function()
                    self.Chest:toggleListening()
                end,
                Info = {
                    Title = "Select Gold Chest",
                    Lines = { "Press it, then click a chest in the world.", "Gold lying around flies into that chest." },
                    Width = 320,
                },
            })
        end,
        CoinsToggle = function(section: any, flag: string, disabled: (() -> boolean)?)
            self:coinsToggle(section, flag, disabled)
        end,
    }

    gold:toggle({
        Name = "Start Path",
        Flag = "GoldStartPath",
        Default = false,
        Key = "P",
        Callback = kick,
    })
    gold:toggle({
        Name = "Show Path",
        Flag = "GoldShowPath",
        Default = false,
        Bindable = false,
    })
    gold:toggle({
        Name = "Mine By Detection",
        Flag = "GoldNodeDetect",
        Default = false,
        Bindable = false,
        Callback = kick,
        Info = {
            Title = "Mine By Detection",
            Lines = {
                "The wait times of the dots are ignored. On the dot of a",
                "gold node it breaks the node and goes on the moment it is",
                "gone. After the last node it waits until every gold node",
                "of the path is back, then it goes on. The path is walked",
                "the same way as always. Turn it off for the timings.",
            },
            Width = 380,
        },
    })
    Options.route(gold, setup)
    Options.rest(gold, setup)
    if self.Paths.Restored then
        context.notify("Restored your unsaved changes of " .. self.Paths.Name)
    end
end

function Part.step(self: any, dt: number)
    self.Loops:sync()
    self.Editor:step(dt)
    self.Utility:step()
    self.Drops:step()
end

function Part.frame(self: any, canvas: any)
    self.Editor:frame(canvas)
    self.Drops:frame(canvas)
end

function Part.shutdown(self: any)
    self.Editor:shutdown()
    self.Loops:stop()
    self.Runner:finish()
    self.Press:reset()
    self.Slots:reset()
    self.Chest:shutdown()
    self.Utility:shutdown()
    self.Game.drive.finish()
end

return Part
end
modules["goldfarm/gold/chest"] = function(...)

local Chest = {}
Chest.__index = Chest

local ARRIVED = 0.9
local PROGRESS = 0.25
local STALL_SECONDS = 2.5
local AUTO_RANGE = 15

type Track = { best: number, at: number }

function Chest.new(context: any, pointer: any): any
    return setmetatable({
        Context = context,
        Game = context.Game,
        Pointer = pointer,
        Selected = nil :: any,
        Highlight = nil :: any,
        Listening = false,
        Tracked = {} :: { [any]: Track },
        Moved = 0,
        OpenedOnce = false,
        HoldUntil = 0,
    }, Chest)
end

function Chest.valid(self: any): boolean
    return self.Selected ~= nil and self.Selected.Parent ~= nil
end

function Chest.label(self: any): string
    if self.Listening then
        return "Click a chest in the world..."
    elseif self:valid() then
        return "Gold Chest: " .. self.Selected.Name
    end
    return "Select Gold Chest"
end

function Chest.release(self: any)
    for item in self.Tracked do
        if item.Parent ~= nil then
            self.Game.chests.release(item)
        end
    end
    table.clear(self.Tracked)
end

function Chest.clearHighlight(self: any)
    if self.Highlight then
        pcall(function()
            self.Highlight:Destroy()
        end)
        self.Highlight = nil
    end
end

function Chest.select(self: any, chest: any, marked: boolean?)
    self:clearHighlight()
    self:release()
    self.Selected = chest
    self.Listening = false
    if marked ~= false and chest ~= nil and chest.Parent ~= nil then
        local highlight = Instance.new("Highlight")
        highlight.Name = "BoogaUtilitiesGoldChest"
        highlight.Adornee = chest
        highlight.FillColor = Color3.fromRGB(212, 212, 212)
        highlight.FillTransparency = 0.75
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = chest
        self.Highlight = highlight
    end
end

function Chest.toggleListening(self: any)
    self.Listening = not self.Listening
    if self.Listening then
        self.Context.notify("Click a chest in the world")
    end
end

function Chest.click(self: any)
    if not self.Listening then
        return false
    end
    local hit = self.Pointer:hit()
    local chest = if hit and hit.Instance then self.Game.finder.chestFromPart(hit.Instance) else nil
    if chest == nil then
        self.Context.notify("That is not a chest")
        return true
    end
    self:select(chest)
    self.Context.notify("Gold chest selected: " .. chest.Name)
    return true
end

function Chest.autoSelect(self: any, single: boolean?)
    if self:valid() then
        return
    end
    if single == true then
        local all = self.Game.finder.chests(nil)
        if #all == 1 then
            self:select(all[1].instance)
            self.Context.notify("Auto Select Chest: the only chest in the server is selected (" .. all[1].name .. ")")
            return
        end
    end
    local near = self.Game.finder.nearestChest(AUTO_RANGE)
    if near then
        self:select(near.instance)
        if single == true then
            self.Context.notify("Auto Select Chest: the nearest chest is selected (" .. near.name .. ", " .. math.floor(near.distance + 0.5) .. " studs)")
        end
    elseif not self.Unrecognized and #self.Game.finder.deployables(AUTO_RANGE, { contains = { "Chest" } }) > 0 then
        self.Unrecognized = true
        self.Context.notify("Auto Select Chest: a chest is near but it has no Contents folder, send packet report.txt")
    end
end

function Chest.autoOpen(self: any)
    if self.OpenedOnce then
        return
    end
    local near = self.Game.finder.nearestChest(AUTO_RANGE)
    if near == nil then
        return
    end
    self.HoldUntil = os.clock() + 0.6
    if self.Game.chests.open(near.instance) then
        self.OpenedOnce = true
    end
end

function Chest.holding(self: any): boolean
    return os.clock() < self.HoldUntil
end

function Chest.magnet(self: any)
    if not self:valid() then
        self:release()
        return
    end
    local Game = self.Game
    local folder = Game.world.itemsFolder()
    local destination = Game.chests.dropPosition(self.Selected)
    if folder == nil or destination == nil then
        return
    end
    local now = os.clock()
    local wide = false
    for item, _ in self.Tracked do
        if item.Parent == nil then
            self.Tracked[item] = nil
            self.Moved += 1
        end
    end
    for _, item in folder:GetChildren() do
        if Game.chests.isGold(item, wide) then
            local part = Game.world.partOf(item)
            if part then
                local distance = (part.Position - destination).Magnitude
                local track = self.Tracked[item]
                if track ~= nil and distance > ARRIVED then
                    Game.chests.attract(item, self.Selected)
                end
                if distance <= ARRIVED then
                    if track then
                        self.Tracked[item] = nil
                        self.Moved += 1
                        Game.chests.release(item)
                    end
                elseif track == nil then
                    self.Tracked[item] = { best = distance, at = now }
                    Game.chests.attract(item, self.Selected)
                    Game.chests.grab(item)
                elseif distance < track.best - PROGRESS then
                    track.best = distance
                    track.at = now
                elseif now - track.at >= STALL_SECONDS then
                    track.at = now
                    Game.chests.grab(item)
                    Game.chests.attract(item, self.Selected)
                end
            end
        end
    end
end

function Chest.shutdown(self: any)
    self:release()
    self:clearHighlight()
    self.Selected = nil
    self.Listening = false

end

return Chest
end
modules["goldfarm/gold/dropwatch"] = function(...)

local import: (string) -> any = ...
local Items: any = import("goldfarm/gold/items")
local Link: any = import("goldfarm/link")
local Hud: any = import("goldfarm/hud")

local Dropwatch = {}
Dropwatch.__index = Dropwatch

local BEFORE = 1.5
local WINDOW = 5
local RADIUS = 30
local OWN = 45
local RESOLVE = 25
local SHOW = 12
local HISTORY = 10
local LINK_EVERY = 1
local CARD = 250
local SHOWN = 4

type Entry = { item: any, quantity: number, state: string }
type Drop = { position: Vector3, at: number, entries: { Entry }, done: number?, expected: number? }

function Dropwatch.new(context: any): any
    return setmetatable({
        Context = context,
        Game = context.Game,
        Resources = nil :: any,
        Space = nil :: any,
        Folder = nil :: any,
        LinkAt = 0,
        Recent = {} :: { { item: any, quantity: number, position: Vector3, at: number } },
        Drops = {} :: { Drop },
        History = {} :: { number },
        In = 0,
        Out = 0,
    }, Dropwatch)
end

function Dropwatch.enabled(self: any): boolean
    return self.Context.read("GoldChestAttract") == true
end

local function isNode(instance: any): boolean
    local ok, result = pcall(function(): boolean
        return instance:IsA("Model") and string.lower(instance.Name) == "gold node"
    end)
    return ok and result
end

local function isRaw(instance: any): boolean
    local ok, result = pcall(function(): boolean
        local name = Items.normalize(instance.Name)
        return name == "rawgold" or name == "goldore"
    end)
    return ok and result
end

function Dropwatch.expected(self: any): number?
    if #self.History == 0 then
        return nil
    end
    local sum = 0
    for _, value in self.History do
        sum += value
    end
    return math.floor(sum / #self.History + 0.5)
end

function Dropwatch.broken(self: any, instance: any)
    if not self:enabled() then
        return
    end
    local position = self.Game.world.positionOf(instance)
    local root = self.Game.world.root()
    if position == nil or root == nil or (position - root.Position).Magnitude > OWN then
        return
    end
    local now = os.clock()
    local drop: Drop = { position = position, at = now, entries = {}, done = nil, expected = self:expected() }
    for index = #self.Recent, 1, -1 do
        local seen = self.Recent[index]
        if now - seen.at <= BEFORE and (seen.position - position).Magnitude <= RADIUS and seen.item.Parent ~= nil then
            table.insert(drop.entries, { item = seen.item, quantity = seen.quantity, state = "flying" })
            table.remove(self.Recent, index)
        end
    end
    table.insert(self.Drops, drop)
end

function Dropwatch.added(self: any, item: any)
    if not self:enabled() or not isRaw(item) then
        return
    end
    local position = self.Game.world.positionOf(item)
    if position == nil then
        return
    end
    local now = os.clock()
    local quantity = math.max(1, self.Game.inventory.quantityOf(item))
    for _, drop in self.Drops do
        if now - drop.at <= WINDOW and (drop.position - position).Magnitude <= RADIUS then
            table.insert(drop.entries, { item = item, quantity = quantity, state = "flying" })
            return
        end
    end
    table.insert(self.Recent, { item = item, quantity = quantity, position = position, at = now })
    while #self.Recent > 60 do
        table.remove(self.Recent, 1)
    end
end

function Dropwatch.link(self: any, now: number)
    if now - self.LinkAt < LINK_EVERY then
        return
    end
    self.LinkAt = now
    local world = self.Game.world
    local resources = world.folder("Resources")
    if resources ~= nil and resources ~= self.Resources then
        self.Resources = resources
        self.Context.connect(resources.ChildRemoved, function(instance: any)
            if isNode(instance) then
                self:broken(instance)
            end
        end)
    end
    local space = world.workspace()
    if space ~= nil and space ~= self.Space then
        self.Space = space
        self.Context.connect(space.ChildRemoved, function(instance: any)
            if isNode(instance) then
                self:broken(instance)
            end
        end)
    end
    local folder = world.itemsFolder()
    if folder ~= nil and folder ~= self.Folder then
        self.Folder = folder
        self.Context.connect(folder.ChildAdded, function(item: any)
            self:added(item)
        end)
    end
end

function Dropwatch.step(self: any)
    local now = os.clock()
    self:link(now)
    local folder = self.Folder
    for index = #self.Drops, 1, -1 do
        local drop = self.Drops[index]
        local open = 0
        for _, entry in drop.entries do
            if entry.state == "flying" then
                if folder ~= nil and entry.item.Parent ~= folder then
                    entry.state = "in"
                    self.In += entry.quantity
                elseif now - drop.at >= RESOLVE then
                    entry.state = "out"
                    self.Out += entry.quantity
                else
                    open += 1
                end
            end
        end
        if open == 0 and now - drop.at >= WINDOW + 1 and drop.done == nil then
            drop.done = now
            local total = 0
            for _, entry in drop.entries do
                total += entry.quantity
            end
            if total > 0 then
                table.insert(self.History, total)
                while #self.History > HISTORY do
                    table.remove(self.History, 1)
                end
            end
        end
        if drop.done ~= nil and now - drop.done > SHOW and index < #self.Drops then
            table.remove(self.Drops, index)
        end
    end
end

function Dropwatch.totals(self: any): string
    return string.format("%d in the chest, %d outside", self.In, self.Out)
end

function Dropwatch.spec(self: any, drop: Drop, total: string?): any
    local dropped, inside, flying, outside = 0, 0, 0, 0
    for _, entry in drop.entries do
        dropped += entry.quantity
        if entry.state == "in" then
            inside += entry.quantity
        elseif entry.state == "out" then
            outside += entry.quantity
        else
            flying += entry.quantity
        end
    end
    return {
        title = "Gold node broken",
        sub = string.format("%d raw gold dropped%s", dropped, if drop.expected ~= nil then string.format(", about %d expected", drop.expected) else ""),
        rows = {
            { label = "In the chest", value = tostring(inside), color = Hud.palette().good, amount = inside },
            { label = "On the way", value = tostring(flying), color = nil, amount = flying },
            { label = "Outside", value = tostring(outside), color = if outside > 0 then Hud.palette().bad else nil, amount = outside },
        },
        dropped = dropped,
        total = total,
    }
end

function Dropwatch.mining(self: any, drop: Drop?): (any?, Vector3?)
    local miner: any = nil
    if miner == nil or not miner:enabled() or miner.Phase ~= "mine" or miner.Node == nil or miner.PresentSince == nil then
        return nil, nil
    end
    if drop ~= nil and miner.PresentSince <= drop.at then
        return nil, nil
    end
    local tracker = miner:tracker()
    local spot = if tracker ~= nil then tracker.Spots[miner.Node.key] else nil
    if spot == nil then
        return nil, nil
    end
    local expected = self:expected()
    return {
        title = "Mining gold node",
        sub = if expected ~= nil then string.format("About %d raw gold will drop", expected) else "The drop is learned from the first nodes",
        total = self:totals(),
    }, spot.position
end

local function widget(spec: any, fade: number): any
    local rows = {}
    for _, row in spec.rows or {} do
        table.insert(rows, { Label = row.label, Value = row.value, Color = row.color })
    end
    return { Title = spec.title, Sub = spec.sub, Rows = rows, Total = spec.total, TotalLabel = "All nodes", Fade = fade }
end

function Dropwatch.widgets(self: any): { any }
    local list = {}
    if not self:enabled() then
        return list
    end
    local now = os.clock()
    local last = self.Drops[#self.Drops]
    local mine = self:mining(last)
    if mine ~= nil then
        table.insert(list, widget(mine, 1))
        return list
    end
    for index = math.max(1, #self.Drops - SHOWN + 1), #self.Drops do
        local drop = self.Drops[index]
        local left = if drop.done ~= nil then drop.done + SHOW - now else math.huge
        local fade = math.clamp((now - drop.at) / 0.3, 0, 1) * math.clamp(left / 0.6, 0, 1)
        if fade > 0.01 then
            table.insert(list, widget(self:spec(drop, if drop == last then self:totals() else nil), fade))
        end
    end
    return list
end

function Dropwatch.frame(self: any, canvas: any)
    if not self:enabled() then
        return
    end
    local space = self.Game.world.workspace()
    local camera = if space then space.CurrentCamera else nil
    if camera == nil then
        return
    end
    local viewport = camera.ViewportSize
    local now = os.clock()
    local last = self.Drops[#self.Drops]
    local mine, at = self:mining(last)
    if mine ~= nil and at ~= nil then
        local screen, depth = canvas.project(at + Vector3.new(0, 2, 0))
        if screen ~= nil and depth > 0.1 then
            Hud.beside(canvas, screen, viewport, CARD, mine, 1)
        end
        return
    end
    local first = math.max(1, #self.Drops - SHOWN + 1)
    for index = first, #self.Drops do
        local drop = self.Drops[index]
        local left = if drop.done ~= nil then drop.done + SHOW - now else math.huge
        local fade = math.clamp((now - drop.at) / 0.3, 0, 1) * math.clamp(left / 0.6, 0, 1)
        if fade > 0.01 then
            local screen, depth = canvas.project(drop.position + Vector3.new(0, 2, 0))
            if screen ~= nil and depth > 0.1 then
                Hud.beside(canvas, screen, viewport, CARD, self:spec(drop, if drop == last then self:totals() else nil), fade)
            end
        end
    end
end

return Dropwatch
end
modules["goldfarm/gold/editor"] = function(...)

local import: (string) -> any = ...
local Overlay: any = import("goldfarm/gold/overlay")
local Validate: any = import("goldfarm/gold/validate")
local Preview: any = import("goldfarm/gold/preview")
local Panel: any = import("goldfarm/gold/panel")

local Editor = {}
Editor.__index = Editor

Editor.TAB = "Path Editor"
Editor.STEPS = { 0.5, 1, 5, 10 }
Editor.WAIT_STEP = 0.25
Editor.WAIT_PRESETS = { 0, 0.5, 1, 2, 5 }
Editor.GAP_STEP = 100

local DRAG_THRESHOLD = 5
local NAMES_TTL = 1.5
local CONFIRM_SECONDS = 3
local SIBLING = 4

export type Hooks = { start: (number) -> (), runner: () -> number? }

function Editor.new(context: any, paths: any, pointer: any, ground: any, hooks: Hooks): any
    local self = setmetatable({
        Context = context,
        Game = context.Game,
        Paths = paths,
        Pointer = pointer,
        Ground = ground,
        Hooks = hooks,
        Validate = Validate.new(ground),
        Preview = Preview.new(),
        Overlay = Overlay.new(),
        Ui = nil :: any,
        Selected = nil :: string?,
        Arm = false,
        Drag = nil :: any,
        Hover = nil :: number?,
        Aim = nil :: Vector3?,
        Issues = nil :: any,
        IssuesKey = "",
        ScrollTo = false,
        Confirming = nil :: any,
        Chosen = paths.Name :: string,
        Names = {} :: { string },
        NamesAt = -math.huge,
        Default = paths.BUILT_IN :: string,
        Clock = 0,
        NameInput = "",
        FromSelected = false,
        Positions = {} :: { Vector3 },
        PositionsVersion = -1,
        Fields = { X = "", Y = "", Z = "", Wait = "" } :: { [string]: string },
        FieldsKey = "",
    }, Editor)
    self.Panel = Panel.new(self)
    pointer.OnRelease = function()
        self:release()
    end
    return self
end

function Editor.active(self: any): boolean
    local ui = self.Ui
    if ui == nil then
        return false
    end
    local ok, shown = pcall(function(): boolean
        local state = ui.Window.State
        return state.Visible == true and (state.NextTab or state.CurrentTab) == Editor.TAB
    end)
    return ok and shown
end

function Editor.setting(self: any, flag: string): any
    return self.Context.read(flag)
end

function Editor.amount(self: any): number
    local value = tonumber(self:setting("GoldEditorStep")) or 1
    return value
end

function Editor.notify(self: any, text: string)
    self.Context.notify(text)
end

function Editor.index(self: any): number?
    return self.Paths:find(self.Selected)
end

function Editor.point(self: any): any
    return self.Paths:get(self.Selected)
end

function Editor.select(self: any, key: string?, scroll: boolean?)
    self.Selected = key
    if key ~= nil and scroll ~= false then
        self.ScrollTo = true
    end
end

function Editor.selectIndex(self: any, index: number, scroll: boolean?)
    local point = self.Paths.Points[index]
    if point then
        self:select(point.key, scroll)
    end
end

function Editor.need(self: any): any
    local point = self:point()
    if point == nil then
        self:notify("Select a dot first")
    end
    return point
end

function Editor.characterPosition(self: any): Vector3?
    local position = self.Game.world.position()
    if position == nil then
        self:notify("Character not found")
    end
    return position
end

function Editor.confirm(self: any, id: string, text: string): boolean
    local now = os.clock()
    local pending = self.Confirming
    if pending ~= nil and pending.id == id and now - pending.at < CONFIRM_SECONDS then
        self.Confirming = nil
        return true
    end
    self.Confirming = { id = id, at = now }
    self:notify(text)
    return false
end

function Editor.confirming(self: any, id: string): boolean
    local pending = self.Confirming
    return pending ~= nil and pending.id == id and os.clock() - pending.at < CONFIRM_SECONDS
end

function Editor.addAt(self: any, position: Vector3)
    local key = self.Paths:add(position, 0, self.Selected)
    self:select(key)
end

function Editor.addAtMe(self: any)
    local position = self:characterPosition()
    if position then
        self:addAt(position)
        self:notify("Dot added at your position")
    end
end

function Editor.toggleArm(self: any)
    self.Arm = not self.Arm
    if self.Arm then
        self:notify("Click in the world to place dots")
    else
        self.Aim = nil
    end
end

function Editor.insertAfter(self: any)
    local point = self:need()
    if point == nil then
        return
    end
    local points = self.Paths.Points
    local index = self:index() :: number
    local following = points[index % #points + 1]
    local position: Vector3 = if #points > 1 then point.position:Lerp(following.position, 0.5) else point.position + Vector3.new(SIBLING, 0, 0)
    position = self.Ground:snap(position) or position
    self:select(self.Paths:add(position, 0, point.key))
    self:notify("Dot inserted after the selected dot")
end

function Editor.duplicate(self: any)
    local point = self:need()
    if point == nil then
        return
    end
    local points = self.Paths.Points
    local following = points[(self:index() :: number) % #points + 1]
    local offset = following.position - point.position
    local direction = if offset.Magnitude > 0.5 then offset.Unit else Vector3.new(1, 0, 0)
    self:select(self.Paths:add(point.position + direction * 2, point.wait, point.key))
    self:notify("Dot duplicated")
end

function Editor.remove(self: any)
    local index = self:index()
    local point = self:need()
    if point == nil or index == nil then
        return
    end
    self.Paths:remove(point.key)
    local points = self.Paths.Points
    local neighbour = points[math.max(index - 1, 1)]
    self:select(if neighbour then neighbour.key else nil)
    self:notify("Dot deleted")
end

function Editor.moveToMe(self: any)
    local point = self:need()
    local position = if point then self:characterPosition() else nil
    if point and position then
        self.Paths:setPoint(point.key, position)
        self:notify("Dot moved to your position")
    end
end

function Editor.teleportTo(self: any, position: Vector3): boolean
    local root = self.Game.world.root()
    if root == nil then
        self:notify("Character not found")
        return false
    end
    return (pcall(function()
        root.CFrame = CFrame.new(position)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end))
end

function Editor.teleportToSelected(self: any)
    local point = self:need()
    if point and self:teleportTo(point.position) then
        self:notify("Teleported to the dot")
    end
end

function Editor.axis(axis: string, sign: number, amount: number): Vector3
    return Vector3.new(if axis == "X" then sign * amount else 0, if axis == "Y" then sign * amount else 0, if axis == "Z" then sign * amount else 0)
end

function Editor.nudge(self: any, axis: string, sign: number)
    local point = self:point()
    if point then
        self.Paths:setPoint(point.key, point.position + Editor.axis(axis, sign, self:amount()), nil, "nudge:" .. point.key)
    end
end

function Editor.shiftAll(self: any, axis: string, sign: number)
    local from: string? = nil
    if self.FromSelected then
        from = self.Selected
        if from == nil or self:index() == nil then
            self:notify("Select a dot first")
            return
        end
    end
    self.Paths:shift(Editor.axis(axis, sign, self:amount()), from, "shift")
end

function Editor.setWait(self: any, value: number, tag: string?)
    local point = self:point()
    if point then
        self.Paths:setPoint(point.key, nil, math.clamp(value, 0, 600), tag)
    end
end

function Editor.stepWait(self: any, sign: number)
    local point = self:point()
    if point then
        self:setWait(point.wait + sign * Editor.WAIT_STEP, "wait:" .. point.key)
    end
end

function Editor.snapAll(self: any)
    local positions: { [string]: Vector3 } = {}
    local missing = 0
    for _, point in self.Paths.Points do
        local snapped = self.Ground:snap(point.position)
        if snapped == nil then
            missing += 1
        elseif (snapped - point.position).Magnitude > 0.005 then
            positions[point.key] = snapped
        end
    end
    local count = self.Paths:place(positions)
    self:notify(string.format("Snapped %d dots to the ground, %d had no ground below", count, missing))
end

function Editor.reverse(self: any)
    self.Paths:reverse()
    self:notify("Path reversed")
end

function Editor.undo(self: any)
    if self.Paths:undo() then
        self:notify("Undo")
    end
end

function Editor.redo(self: any)
    if self.Paths:redo() then
        self:notify("Redo")
    end
end

function Editor.testFrom(self: any)
    local index = self:index()
    local point = self:need()
    if point == nil or index == nil then
        return
    end
    if self:teleportTo(point.position) then
        self.Hooks.start(index)
        self:notify(string.format("Testing the path from dot %d", index))
    end
end

function Editor.togglePreview(self: any)
    if self.Preview.Active then
        self.Preview:stop()
        return
    end
    local points = self.Paths.Points
    if #points == 0 then
        self:notify("The path has no dots")
        return
    end
    self.Preview:start(points, self:index() or 1)
end

function Editor.refreshIssues(self: any, force: boolean?)
    local live = self:setting("GoldEditorValidate") == true
    if not live and force ~= true then
        self.Issues = nil
        self.IssuesKey = ""
        return
    end
    local gap = tonumber(self:setting("GoldEditorGap")) or Validate.GAP
    local key = tostring(self.Paths.Version) .. ":" .. tostring(gap)
    if key ~= self.IssuesKey then
        self.IssuesKey = key
        self.Issues = self.Validate:run(self.Paths.Points, gap, Validate.JUMP)
    end
end

function Editor.nextIssue(self: any)
    self:refreshIssues(true)
    local issues = self.Issues
    if issues == nil or issues.Count == 0 then
        self:notify("No problems found")
        return
    end
    local current = self:index() or 0
    local target = issues.Indices[1]
    for _, index in issues.Indices do
        if index > current then
            target = index
            break
        end
    end
    self:selectIndex(target)
    self:notify(issues.Dots[target])
end

function Editor.fillFields(self: any)
    local point = self:point()
    local key = if point then string.format("%s:%d", point.key, self.Paths.Version) else ""
    if key == self.FieldsKey then
        return
    end
    self.FieldsKey = key
    if point == nil then
        self.Fields.X, self.Fields.Y, self.Fields.Z, self.Fields.Wait = "", "", "", ""
        return
    end
    self.Fields.X = Overlay.number(point.position.X)
    self.Fields.Y = Overlay.number(point.position.Y)
    self.Fields.Z = Overlay.number(point.position.Z)
    self.Fields.Wait = Overlay.number(point.wait)
end

function Editor.commitField(self: any, name: string, text: string)
    local point = self:point()
    local value = tonumber(text)
    if point == nil or value == nil then
        self:notify("Select a dot and type a number")
        return
    end
    if name == "Wait" then
        self.Paths:setPoint(point.key, nil, value)
    else
        local p: Vector3 = point.position
        self.Paths:setPoint(point.key, Vector3.new(if name == "X" then value else p.X, if name == "Y" then value else p.Y, if name == "Z" then value else p.Z))
    end
    self.FieldsKey = ""
end

function Editor.profiles(self: any): { string }
    if os.clock() - self.NamesAt > NAMES_TTL then
        self.NamesAt = os.clock()
        self.Names = self.Paths:list()
        self.Default = self.Paths:defaultName()
    end
    return self.Names
end

function Editor.invalidate(self: any)
    self.NamesAt = -math.huge
end

function Editor.reset(self: any)
    self.Selected = nil
    self.Drag = nil
    self.Preview:stop()
    self.FieldsKey = ""
    self.Chosen = self.Paths.Name
    self:invalidate()
end

function Editor.autoName(self: any): string
    local names: { [string]: boolean } = {}
    for _, name in self.Paths:list() do
        names[string.lower(name)] = true
    end
    local number = 1
    while names[string.lower("Path " .. tostring(number))] do
        number += 1
    end
    return "Path " .. tostring(number)
end

function Editor.save(self: any)
    if self.Paths.Name == self.Paths.BUILT_IN or (self.NameInput ~= "" and self.Paths.clean(self.NameInput) ~= self.Paths.Name) then
        self:saveAs()
        return
    end
    local _, message = self.Paths:save()
    self:notify(message)
    self:invalidate()
end

function Editor.saveAs(self: any)
    local typed = self.NameInput
    local name = if typed ~= "" then self.Paths.clean(typed) else self:autoName()
    if name ~= self.Paths.Name and self.Paths.Store:exists(name) and not self:confirm("overwrite", "A path named " .. name .. " exists. Press Save As again to overwrite it") then
        return
    end
    local ok, message = self.Paths:save(name)
    self:notify(message)
    if ok then
        self.Chosen = self.Paths.Name
        self.NameInput = ""
    end
    self:invalidate()
end

function Editor.guard(self: any, id: string): boolean
    if self.Paths:dirty() then
        return self:confirm(id, "Unsaved changes will be lost. Press again to confirm")
    end
    return true
end

function Editor.loadChosen(self: any)
    if not self:guard("load") then
        return
    end
    local ok, message = self.Paths:load(self.Chosen)
    self:notify(message)
    if ok then
        self:reset()
    end
end

function Editor.newPath(self: any)
    if not self:guard("new") then
        return
    end
    local typed = self.NameInput
    local name = if typed ~= "" then self.Paths.clean(typed) else self:autoName()
    if self.Paths.Store:exists(name) or name == self.Paths.BUILT_IN then
        name = self:autoName()
    end
    self.Paths:blank(name)
    self.NameInput = ""
    self:notify("New empty path " .. name .. ". Add your dots, then press Save")
    self:reset()
end

function Editor.revert(self: any)
    if self.Paths:dirty() and not self:confirm("revert", "This drops your unsaved changes. Press Revert again to confirm") then
        return
    end
    local ok, message = self.Paths:load(self.Paths.Name)
    self:notify(message)
    if ok then
        self:reset()
    end
end

function Editor.defaultChosen(self: any)
    if self.Chosen ~= self.Paths.Name and not self:guard("default") then
        return
    end
    local ok, message = self.Paths:setDefault(self.Chosen)
    self:notify(message)
    if ok then
        self:reset()
    end
end

function Editor.deleteChosen(self: any)
    if not self:confirm("delete", "Press Delete again to remove " .. self.Chosen) then
        return
    end
    local ok, message = self.Paths:delete(self.Chosen)
    self:notify(message)
    if ok then
        self.Chosen = self.Paths.Name
    end
    self:invalidate()
end

function Editor.renameChosen(self: any)
    if self.NameInput == "" then
        self:notify("Type the new name first")
        return
    end
    local ok, message = self.Paths:rename(self.Chosen, self.NameInput)
    self:notify(message)
    if ok then
        self.Chosen = self.Paths.clean(self.NameInput)
        self.NameInput = ""
    end
    self:invalidate()
end

function Editor.duplicateChosen(self: any)
    local _, message = self.Paths:duplicate(self.Chosen)
    self:notify(message)
    self:invalidate()
end

function Editor.overUi(self: any): boolean
    return self.Pointer:overUi(self.Ui)
end

function Editor.aimAt(self: any, height: number?, flip: boolean): Vector3?
    local level = (self:setting("GoldEditorDrag") == "Level") ~= flip
    if level and height ~= nil then
        return self.Pointer:plane(height)
    end
    local hit = self.Pointer:hit()
    if hit ~= nil and hit.Position ~= nil then
        return hit.Position + Vector3.new(0, self.Ground:clearance(), 0)
    end
    return nil
end

function Editor.press(self: any)
    if not self:active() or self:overUi() then
        return
    end
    if self.Arm then
        local position = self:aimAt(nil, false)
        if position then
            self:addAt(position)
        end
        return
    end
    local index = self.Pointer:nearest(self:positions(), self:index())
    if index == nil then
        return
    end
    self:selectIndex(index)
    local point = self.Paths.Points[index]
    self.Drag = { key = point.key, start = self.Pointer:location(), moved = false, height = point.position.Y }
end

function Editor.release(self: any)
    self.Drag = nil
    self.Paths:seal()
end

function Editor.positions(self: any): { Vector3 }
    if self.PositionsVersion ~= self.Paths.Version then
        self.PositionsVersion = self.Paths.Version
        local list: { Vector3 } = table.create(#self.Paths.Points)
        for index, point in self.Paths.Points do
            list[index] = point.position
        end
        self.Positions = list
    end
    return self.Positions
end

function Editor.holdingShift(self: any): boolean
    return self.Pointer:holding(Enum.KeyCode.LeftShift) or self.Pointer:holding(Enum.KeyCode.RightShift)
end

function Editor.dragStep(self: any)
    local drag = self.Drag
    if not self.Pointer:down() then
        self:release()
        return
    end
    local spot = self.Pointer:location()
    if not drag.moved and spot ~= nil and drag.start ~= nil and (spot - drag.start).Magnitude >= DRAG_THRESHOLD then
        drag.moved = true
    end
    if drag.moved then
        local position = self:aimAt(drag.height, self:holdingShift())
        if position and not self.Paths:setPoint(drag.key, position, nil, "drag") then
            self.Drag = nil
        end
    end
end

function Editor.step(self: any, dt: number)
    self.Clock += dt
    if self.Selected ~= nil and self.Paths:find(self.Selected) == nil then
        self.Selected = nil
    end
    local open = self:active()
    if not open then
        self.Arm = false
        self.Aim = nil
        self.Hover = nil
        if self.Drag then
            self:release()
        end
    else
        local over = self:overUi()
        if self.Drag then
            self:dragStep()
        end
        self.Hover = if self.Drag == nil and not over then self.Pointer:nearest(self:positions(), nil) else nil
        self.Aim = if self.Arm and not over then self:aimAt(nil, false) else nil
        self:fillFields()
    end
    self.Preview:step(self.Paths.Points, dt)
    self:refreshIssues()
    self.Paths:flush()
end

function Editor.frame(self: any, canvas: any)
    local open = self:active()
    local view = self.View
    if view == nil then
        view = {}
        self.View = view
    end
    view.Visible = open or self.Context.read("GoldShowPath") == true
    view.Edit = open
    view.Points = self.Paths.Points
    view.Version = self.Paths.Version
    view.Camera = self.Pointer:camera()
    view.Selected = self:index()
    view.Hover = self.Hover
    view.Run = if self.Context.read("GoldStartPath") == true then self.Hooks.runner() else nil
    view.Issues = if open then self.Issues else nil
    view.Aim = self.Aim
    view.Ghost = if self.Preview.Active then self.Preview.Position else nil
    view.GhostIndex = if self.Preview.Active then self.Preview.Target else nil
    self.Overlay:frame(canvas, view)
end

function Editor.shutdown(self: any)
    self.Drag = nil
    self.Arm = false
    self.Preview:stop()
    self.Paths:flush(true)
end

return Editor
end
modules["goldfarm/gold/ground"] = function(...)

local Ground = {}
Ground.__index = Ground

local LIFT = 8
local DEPTH = 800
local FALLBACK = 3.1

function Ground.new(context: any): any
    return setmetatable({ Context = context, Game = context.Game }, Ground)
end

function Ground.clearance(self: any): number
    local World = self.Game.world
    local root = World.root()
    local humanoid = World.humanoid()
    if root == nil or humanoid == nil then
        return FALLBACK
    end
    local hip = tonumber(humanoid.HipHeight) or 2
    local half = if root.Size then root.Size.Y * 0.5 else 1
    return hip + half + self.Game.drive.hover
end

function Ground.params(self: any): any
    local World = self.Game.world
    local ignore: { any } = {}
    local character = World.character()
    if character ~= nil then
        table.insert(ignore, character)
    end
    local players = World.folder("Players")
    if players ~= nil then
        table.insert(ignore, players)
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true
    return params
end

function Ground.cast(self: any, origin: Vector3, direction: Vector3): any
    local space = self.Game.world.workspace()
    if space == nil then
        return nil
    end
    local ok, result = pcall(function()
        return space:Raycast(origin, direction, self:params())
    end)
    if ok then
        return result
    end
    return nil
end

function Ground.below(self: any, position: Vector3): Vector3?
    local hit = self:cast(position + Vector3.new(0, self:clearance() + LIFT, 0), Vector3.new(0, -DEPTH, 0))
    if hit ~= nil and hit.Position ~= nil then
        return hit.Position
    end
    return nil
end

function Ground.snap(self: any, position: Vector3): Vector3?
    local floor = self:below(position)
    if floor == nil then
        return nil
    end
    return Vector3.new(position.X, floor.Y + self:clearance(), position.Z)
end

function Ground.height(self: any, position: Vector3): number?
    local floor = self:below(position)
    if floor == nil then
        return nil
    end
    return position.Y - (floor.Y + self:clearance())
end

return Ground
end
modules["goldfarm/gold/items"] = function(...)

local Items = {}

local GOLD = { gold = true, rawgold = true, goldore = true }

local LIMIT = 2048
local normalized: { [string]: string } = {}
local normalizedCount = 0
local kinds: { [string]: string | false } = {}
local kindCount = 0

function Items.normalize(name: string): string
    local cached = normalized[name]
    if cached ~= nil then
        return cached
    end
    local result = (string.gsub(string.lower(name), "[%s_%-]", ""))
    if normalizedCount >= LIMIT then
        table.clear(normalized)
        normalizedCount = 0
    end
    normalized[name] = result
    normalizedCount += 1
    return result
end

function Items.isBar(name: string): boolean
    local lower = string.lower(name)
    return string.find(lower, "gold", 1, true) ~= nil and string.find(lower, "bar", 1, true) ~= nil
end

function Items.kind(name: string): string?
    local cached = kinds[name]
    if cached == false then
        return nil
    elseif cached ~= nil then
        return cached :: string
    end
    local result: string? = nil
    if Items.isBar(name) then
        result = "bar"
    elseif GOLD[Items.normalize(name)] then
        result = "gold"
    end
    if kindCount >= LIMIT then
        table.clear(kinds)
        kindCount = 0
    end
    kinds[name] = result or false
    kindCount += 1
    return result
end

local function inChest(Game: any, instance: any): boolean
    local node = instance.Parent
    for _ = 1, 6 do
        if node == nil then
            return false
        end
        if Game.finder.isChest(node) then
            return true
        end
        node = node.Parent
    end
    return false
end

local RAW = { rawgold = true, goldore = true }

function Items.loose(Game: any, range: number?, cooked: boolean?): { any }
    local world = Game.world
    local folder = world.itemsFolder()
    if folder == nil then
        return {}
    end
    return world.collect(world.children(folder, false), {
        range = range,
        requireId = true,
        match = function(instance: any): boolean
            if Items.kind(instance.Name) == nil or inChest(Game, instance) then
                return false
            end
            return not (cooked == true and RAW[Items.normalize(instance.Name)] == true)
        end,
    })
end

return Items
end
modules["goldfarm/gold/legacy"] = function(...)

return {
    { -140.75302124023438, -29.985698699951172, -190.17254638671875, 2 },
    { -119.31350708007812, -25.793699264526367, -194.75294494628906, 1.5 },
    { -107.11988830566406, -14.877410888671875, -185.7013702392578, 0 },
    { -91.96001434326172, -6.04759407043457, -176.57630920410156, 0 },
    { -36.64952087402344, -2.8125057220458984, -133.5755157470703, 0 },
    { 449.4616394042969, -3.3163070678710938, 138.77236938476562, 0 },
    { 457.09320068359375, 12.64422607421875, 140.4607391357422, 0 },
    { 464.60321044921875, 16.41159439086914, 143.6938018798828, 0 },
    { 476.8289489746094, 12.090450286865234, 151.6466064453125, 0.5 },
    { 474.3323974609375, 16.277469635009766, 200.78839111328125, 0 },
    { 469.9004211425781, 11.689022064208984, 233.28887939453125, 1 },
    { 475.97784423828125, 12.661579132080078, 241.33673095703125, 0 },
    { 490.5067138671875, -3, 252.75474548339844, 0 },
    { 729.6565551757812, -2.999999523162842, 365.05615234375, 0 },
    { 1057.869384765625, 3.9935264587402344, 511.57806396484375, 0 },
    { 1162.157470703125, -3.3144607543945312, 566.8117065429688, 0 },
    { 1215.233642578125, -12.017799377441406, 531.7390747070312, 0 },
    { 1241.5537109375, -15.78512191772461, 569.8186645507812, 1 },
    { 1286.194091796875, -15.509637832641602, 613.6463012695312, 0 },
    { 1315.987060546875, -19.050758361816406, 600.4512329101562, 1 },
    { 1294.0362548828125, -15.575050354003906, 621.3857421875, 0 },
    { 1307.613037109375, -15.25442123413086, 656.8776245117188, 0 },
    { 1280.750244140625, -18.851194381713867, 687.6311645507812, 1 },
    { 1307.6617431640625, -15.256404876708984, 656.7553100585938, 0 },
    { 1305.692626953125, -15.763208389282227, 649.06640625, 0 },
    { 1241.618896484375, -15.779075622558594, 569.8116455078125, 0 },
    { 1215.2764892578125, -12.026765823364258, 531.7905883789062, 0 },
    { 1185.540771484375, -15.456033706665039, 461.4212646484375, 1 },
    { 1192.3968505859375, -15.762460708618164, 475.7747802734375, 0 },
    { 1207.5888671875, -20.595199584960938, 470.5138244628906, 0 },
    { 1275.562255859375, -23.544275283813477, 456.6135559082031, 0 },
    { 1273.831298828125, -18.170045852661133, 435.40045166015625, 0 },
    { 1263.4959716796875, -15.671236038208008, 417.3788146972656, 0 },
    { 1202.037841796875, -1.7144832611083984, 334.905517578125, 0 },
    { 1188.07373046875, -2.035244941711426, 319.68603515625, 0 },
    { 716.411376953125, -3.9945693016052246, -142.5128173828125, 0 },
    { 694.3192138671875, 17.386688232421875, -161.43527221679688, 0 },
    { 683.3438110351562, 32.30760192871094, -167.1634521484375, 0 },
    { 660.0833740234375, 32.245208740234375, -186.8964080810547, 1 },
    { 699.4446411132812, 28.500442504882812, -201.92117309570312, 0 },
    { 715.6201782226562, 26.26921844482422, -217.4705352783203, 0 },
    { 727.9087524414062, 23.044580459594727, -244.2185516357422, 0 },
    { 702.0609741210938, 34.193241119384766, -309.710205078125, 0 },
    { 687.6783447265625, 54.375221252441406, -330.9793701171875, 0 },
    { 682.963623046875, 62.84449768066406, -354.2230224609375, 0 },
    { 682.5621337890625, 74.81529235839844, -363.08709716796875, 0 },
    { 679.9118041992188, 80.4763412475586, -372.0174255371094, 0 },
    { 678.1869506835938, 79.29402923583984, -378.5758972167969, 1 },
    { 593.1503295898438, 22.726726531982422, -359.16217041015625, 0 },
    { 593.8072509765625, -4.893863201141357, -353.7864074707031, 1 },
    { 623.1016845703125, -7.344945907592773, -358.8044738769531, 0.25 },
    { 630.2095947265625, -7.541135787963867, -379.7254333496094, 2 },
    { 554.26904296875, 12.96484375, -398.23663330078125, 0 },
    { 464.4996032714844, -5, -419.7094421386719, 0 },
    { 19.623218536376953, -6.068264484405518, -550.6239013671875, 0 },
    { -21.722415924072266, -3.0084075927734375, -557.9688110351562, 0 },
    { -57.53821563720703, -3.388853073120117, -570.225341796875, 0 },
    { -179.04275512695312, -1.5733046531677246, -621.7989501953125, 0 },
    { -198.27664184570312, 6.366794586181641, -625.4280395507812, 0 },
    { -206.7178497314453, 19.34856605529785, -626.2610473632812, 0 },
    { -212.7473602294922, 19.61411476135254, -621.0771484375, 1 },
    { -227.88816833496094, 2.816864013671875, -618.2684326171875, 0 },
    { -365.38031005859375, -3.0617294311523438, -611.3173828125, 0 },
    { -387.54278564453125, -11.44034194946289, -609.9725952148438, 0 },
    { -399.1018371582031, -22.568632125854492, -609.0355834960938, 0 },
    { -409.27484130859375, -39.42827606201172, -554.4389038085938, 0 },
    { -387.3904724121094, -43.19425582885742, -555.9221801757812, 1 },
    { -315.548583984375, -49.17181396484375, -569.5033569335938, 0 },
    { -281.66156005859375, -56.85545349121094, -558.1670532226562, 0 },
    { -230.5189971923828, -59, -539.8056640625, 0 },
    { -214.7939453125, -59.485443115234375, -526.3626708984375, 0 },
    { -201.5225830078125, -60.20200729370117, -541.5321044921875, 0 },
    { -174.5003204345703, -63.09870910644531, -563.3765258789062, 0 },
    { -157.77098083496094, -64.46682739257812, -593.5687866210938, 0 },
    { -207.91184997558594, -61.69873046875, -625.405517578125, 1 },
    { -157.7576446533203, -64.44625854492188, -593.5261840820312, 0 },
    { -174.50450134277344, -63.100341796875, -563.4628295898438, 0 },
    { -165.35691833496094, -63.074806213378906, -511.9172058105469, 0 },
    { -180.05520629882812, -69.2813491821289, -453.8267517089844, 0 },
    { -171.56483459472656, -73.43494415283203, -456.92535400390625, 0 },
    { -156.2505645751953, -99.44965362548828, -478.06658935546875, 0 },
    { -164.91696166992188, -99.43761444091797, -502.3164367675781, 0 },
    { -183.961181640625, -102.99999237060547, -505.1149597167969, 0 },
    { -192.162109375, -103.27455139160156, -496.7663879394531, 0 },
    { -189.58489990234375, -104.05291748046875, -456.0731201171875, 2 },
    { -192.1395263671875, -103.26908111572266, -496.70355224609375, 0 },
    { -183.95126342773438, -103, -505.1314392089844, 0 },
    { -164.86270141601562, -99.4522476196289, -502.3470153808594, 0 },
    { -146.2549591064453, -97.43460845947266, -495.0435485839844, 0 },
    { 7.541040420532227, -103, -423.418212890625, 0 },
    { 34.360626220703125, -99.18365478515625, -371.1417541503906, 0 },
    { 55.09477996826172, -99, -359.40777587890625, 1 },
    { 19.69225311279297, -99, -391.58526611328125, 0 },
    { 11.900020599365234, -102.96358489990234, -415.3416748046875, 0 },
    { -45.130699157714844, -104.36945343017578, -389.5151672363281, 0 },
    { -92.34864044189453, -103, -353.9851379394531, 0 },
    { -123.5248794555664, -90.99566650390625, -291.9811706542969, 0 },
    { -159.88336181640625, -87.26156616210938, -263.26336669921875, 0 },
    { -245.3988494873047, -83, -248.14662170410156, 1 },
    { -230.7689666748047, -83.02196502685547, -257.0267639160156, 0 },
    { -232.29132080078125, -80.01478576660156, -268.34808349609375, 0 },
    { -262.0515441894531, -79, -298.0277404785156, 0 },
    { -262.7806091308594, -78.65348815917969, -323.1799621582031, 0 },
    { -304.8475036621094, -79, -368.1495056152344, 1 },
    { -262.7782897949219, -78.65474700927734, -323.1613464355469, 0 },
    { -262.1943054199219, -79, -297.93939208984375, 0 },
    { -232.17462158203125, -80.07608032226562, -268.10711669921875, 0 },
    { -230.7614288330078, -83.02151489257812, -256.96624755859375, 0 },
    { -234.27493286132812, -90.60616302490234, -217.21533203125, 0 },
    { -234.24928283691406, -88.4429702758789, -177.45703125, 0 },
    { -298.5879211425781, -93, -76.40196228027344, 0 },
    { -336.71014404296875, -91.015625, -47.368873596191406, 1 },
    { -322.3817138671875, -85.93417358398438, -103.84822082519531, 0 },
    { -312.7877502441406, -80.29764556884766, -107.85237884521484, 0 },
    { -291.18798828125, -72.95791625976562, -96.05986785888672, 0 },
    { -258.7352600097656, -71.40682220458984, -83.00981140136719, 0 },
    { -237.53225708007812, -71.65625, -83.11640167236328, 1 },
    { -264.6081237792969, -74.92657470703125, -74.37799072265625, 0 },
    { -271.8966369628906, -93, -69.28028106689453, 0 },
    { -244.89463806152344, -93, -94.01403045654297, 0 },
    { -234.6796417236328, -86.08658599853516, -96.06693267822266, 0 },
    { -208.53977966308594, -89.05722045898438, -92.98556518554688, 0 },
    { -186.21617126464844, -93, -86.48092651367188, 0 },
    { -23.464744567871094, -91.06700134277344, -6.431948661804199, 1 },
    { -54.05946731567383, -93, -34.732177734375, 0 },
    { -64.57084655761719, -83.93140411376953, -67.21971130371094, 0 },
    { -56.27317810058594, -75.80343627929688, -74.03585052490234, 0 },
    { -25.429244995117188, -75.0190658569336, -49.47193145751953, 0 },
    { -20.472515106201172, -75.26667785644531, -41.99848937988281, 0 },
    { 3.372006416320801, -75.00245666503906, -37.93674087524414, 0 },
    { 9.361078262329102, -75, -45.16803741455078, 0 },
    { 2.1956307888031006, -83, -81.34650421142578, 1 },
    { 7.540444850921631, -77.6328125, -91.84691619873047, 0 },
    { 10.9675931930542, -73.97479248046875, -100.1095962524414, 0 },
    { 21.415082931518555, -70.9155044555664, -110.52931213378906, 0 },
    { 48.723270416259766, -75, -125.2779541015625, 0 },
    { 63.05690383911133, -75.3080062866211, -130.89697265625, 0 },
    { 70.77178192138672, -72.12876892089844, -118.96957397460938, 0 },
    { 74.71022033691406, -60.7221565246582, -90.87541961669922, 0 },
    { 67.58888244628906, -48.76361083984375, -62.624996185302734, 0 },
    { 45.71700668334961, -36.125831604003906, -57.280296325683594, 0 },
    { -40.736576080322266, -35.00068664550781, -100.33395385742188, 0 },
    { -106.33723449707031, -35.000003814697266, -160.429931640625, 1 },
    { -125.25753784179688, -35.04928970336914, -160.6648406982422, 1 },
    { -144.2646484375, -34.70026397705078, -160.45301818847656, 1 },
    { -144.25091552734375, -34.70109558105469, -160.4765625, 0 },
} :: { { number } }
end
modules["goldfarm/gold/loops"] = function(...)

local Loops = {}
Loops.__index = Loops

export type Spec = {
    flag: string,
    interval: number | () -> number,
    body: () -> (),
    start: (() -> boolean)?,
    stop: (() -> ())?,
}

function Loops.new(context: any): any
    return setmetatable({ Context = context, Specs = {} :: { Spec }, Active = {} :: { [string]: boolean }, Enabled = true }, Loops)
end

function Loops.add(self: any, spec: Spec)
    table.insert(self.Specs, spec)
end

local function delay(spec: Spec): number
    local interval = spec.interval
    if type(interval) == "function" then
        return interval()
    end
    return interval
end

function Loops.launch(self: any, spec: Spec)
    local context = self.Context
    if self.Active[spec.flag] or not self.Enabled or context.read(spec.flag) ~= true then
        return
    end
    self.Active[spec.flag] = true
    context.spawn(function()
        local ready = true
        if spec.start then
            local ok, result = pcall(spec.start)
            ready = ok and result == true
        end
        while ready and self.Enabled and context.alive() and context.read(spec.flag) == true do
            if not pcall(spec.body) then
                context.wait(0.2)
            end
            if not context.wait(delay(spec)) then
                break
            end
        end
        self.Active[spec.flag] = nil
        if spec.stop then
            pcall(spec.stop)
        end
    end)
end

function Loops.ensure(self: any, flag: string)
    for _, spec in self.Specs do
        if spec.flag == flag then
            self:launch(spec)
        end
    end
end

function Loops.sync(self: any)
    for _, spec in self.Specs do
        if not self.Active[spec.flag] then
            self:launch(spec)
        end
    end
end

function Loops.running(self: any, flag: string): boolean
    return self.Active[flag] == true
end

function Loops.stop(self: any)
    self.Enabled = false
end

return Loops
end
modules["goldfarm/gold/options"] = function(...)

local Options = {}

export type Flags = {
    HitAura: string,
    SwitchSlots: string,
    CoinPress: string,
    PauseNearPress: string,
    RefillCampfire: string,
    AutoSelectChest: string,
    ChestAttract: string,
    PickupChest: string,
    PickCoins: string,
    PickupAir: string,
}

export type Setup = {
    Flags: Flags,
    Kick: () -> (),
    Read: (string) -> any,
    Disabled: (() -> boolean)?,
    ChestButton: (any, (() -> boolean)?) -> (),
    CoinsToggle: (any, string, (() -> boolean)?) -> (),
}

function Options.disabled(setup: Setup, extra: (() -> boolean)?): (() -> boolean)?
    local base = setup.Disabled
    if base == nil then
        return extra
    end
    if extra == nil then
        return base
    end
    return function(): boolean
        return base() or extra()
    end
end

local function heading(section: any, text: string)
    section:label({ Text = text, Size = 12, Height = 28, Offset = 4 })
end

function Options.route(section: any, setup: Setup)
    local flags = setup.Flags
    local disabled = Options.disabled(setup, nil)
    section:toggle({
        Name = "Gold Hit Aura",
        Flag = flags.HitAura,
        Default = false,
        Bindable = false,
        Callback = setup.Kick,
        Disabled = disabled,
    })
    section:toggle({
        Name = "Switch Slot 1/2",
        Flag = flags.SwitchSlots,
        Default = false,
        Bindable = false,
        Callback = setup.Kick,
        Disabled = disabled,
        Info = {
            Title = "Switch Slot 1/2",
            Lines = {
                "Equips the hoe (slot 2) when you come within 15 studs",
                "of a plant box and the pickaxe (slot 1) when you leave.",
            },
            Width = 360,
        },
    })
end

function Options.rest(section: any, setup: Setup)
    local flags = setup.Flags
    local disabled = Options.disabled(setup, nil)
    local function pauseDisabled(): boolean
        return setup.Read(flags.CoinPress) ~= true
    end

    heading(section, "Coin Press")
    section:toggle({
        Name = "Coin Press",
        Flag = flags.CoinPress,
        Default = false,
        Callback = setup.Kick,
        Disabled = disabled,
        Info = {
            Title = "Coin Press",
            Lines = {
                "Near a Coin Press (12 studs) presses your gold",
                "every 0.04 s until the bag has none left.",
                "With Pickup Gold Bars from Chest on, chest gold is taken first.",
            },
            Width = 340,
        },
    })
    section:toggle({
        Name = "Pause Near Press",
        Flag = flags.PauseNearPress,
        Default = false,
        Disabled = Options.disabled(setup, pauseDisabled),
        Info = {
            Title = "Pause Near Press",
            Lines = {
                "Holds your character at a Coin Press (12 studs) while",
                "your bag still has gold to press. With Pickup Gold Bars from Chest on",
                "the gold in nearby chests counts too. The path continues",
                "when nothing is left, or after 120 s at the latest.",
            },
            Width = 360,
        },
    })
    section:toggle({
        Name = "Refill Campfire",
        Flag = flags.RefillCampfire,
        Default = false,
        Callback = setup.Kick,
        Disabled = disabled,
        Info = {
            Title = "Refill Campfire",
            Lines = { "Feeds Wood and Leaves to campfires within 45", "studs whenever their fuel is 200 or lower." },
            Width = 320,
        },
    })

    heading(section, "Chest")
    setup.ChestButton(section, disabled)
    section:toggle({ Name = "Auto Select Chest", Flag = flags.AutoSelectChest, Default = false, Callback = setup.Kick, Disabled = disabled })
    section:toggle({
        Name = "Move Gold To Chest",
        Flag = flags.ChestAttract,
        Default = true,
        Callback = setup.Kick,
        Disabled = disabled,
        Info = {
            Title = "Move Gold To Chest",
            Lines = { "Pulls dropped gold into the selected chest.", "Auto Select Chest picks the nearest chest within 15 studs." },
            Width = 340,
        },
    })

    heading(section, "Pickup")
    section:toggle({
        Name = "Pickup Gold Bars from Chest",
        Flag = flags.PickupChest,
        Default = false,
        Callback = setup.Kick,
        Disabled = disabled,
        Info = {
            Title = "Pickup Gold Bars from Chest",
            Lines = { "Takes the gold bars out of chests within 45 studs.", "Raw gold stays in the chest. Paused near a Coin Press", "while Coin Press is on, the press takes them then." },
            Width = 360,
        },
    })
    setup.CoinsToggle(section, flags.PickCoins, disabled)
    section:toggle({
        Name = "Pickup Gold Bars on Ground",
        Flag = flags.PickupAir,
        Default = false,
        Callback = setup.Kick,
        Disabled = disabled,
        Info = {
            Title = "Pickup Gold Bars on Ground",
            Lines = { "Picks up the gold bars lying on the ground within", "35 studs, 15 at a time. Raw gold is left alone." },
            Width = 340,
        },
    })
end

return Options
end
modules["goldfarm/gold/overlay"] = function(...)

local import: (string) -> any = ...
local Hud: any = import("goldfarm/hud")

local Overlay = {}
Overlay.__index = Overlay

local LINE = Color3.fromRGB(190, 190, 195)
local DOT = Color3.fromRGB(245, 245, 245)
local WAIT = Color3.fromRGB(120, 200, 255)
local SELECT = Color3.fromRGB(255, 205, 70)
local HOST = "Booga Utilities"
local BAD = Color3.fromRGB(235, 70, 70)
local RUN = Color3.fromRGB(110, 220, 130)
local GHOST = Color3.fromRGB(90, 235, 235)
local INK = Color3.fromRGB(22, 22, 24)
local WHITE = Color3.new(1, 1, 1)
local FADE_SPEED = 8
local DOT_RANGE = 900
local NUMBERED = 70
local ARROWS = 110
local RADIUS = 7
local ARROW_GAP = 30

type Item = { index: number, screen: Vector2, distance: number }

function Overlay.new(): any
    return setmetatable({
        Fade = 0,
        FadeAt = os.clock(),
        Line = {} :: { Vector3 },
        LineVersion = -1,
    }, Overlay)
end

local function number(value: number): string
    local text = string.format("%.2f", value)
    text = string.gsub(text, "0+$", "")
    text = string.gsub(text, "%.$", "")
    if text == "-0" or text == "" then
        return "0"
    end
    return text
end

Overlay.number = number

local function follow()
    local instances = getgenv().OkloUIInstances
    local ui = if type(instances) == "table" then instances[HOST] else nil
    local pal = if ui ~= nil and ui.Window ~= nil then ui.Window.Pal else nil
    if pal == nil then
        return
    end
    DOT = pal.Text
    WAIT = pal.Accent
    SELECT = pal.Accent:Lerp(WHITE, 0.6)
    INK = pal.Main
    local palette = Hud.palette()
    LINE = palette.line
    BAD = palette.bad
    RUN = palette.good
    GHOST = palette.ghost
end

local function onScreen(screen: Vector2?, depth: number, size: Vector2): boolean
    return screen ~= nil and depth > 0.1 and screen.X > -40 and screen.Y > -40 and screen.X < size.X + 40 and screen.Y < size.Y + 40
end

function Overlay.arrows(self: any, canvas: any, view: any, screens: { [number]: Vector2 }, fade: number)
    local points = view.Points
    local count = #points
    if count < 2 then
        return
    end
    local drawn = 0
    for index, from in screens do
        local to = screens[index % count + 1]
        if to ~= nil and drawn < ARROWS and (to - from).Magnitude > ARROW_GAP then
            local unit = (to - from).Unit
            local side = Vector2.new(-unit.Y, unit.X)
            local center = (from + to) / 2
            local color = if view.Issues and view.Issues.Segments[index] then BAD else LINE
            canvas.filledTriangle(center + unit * 7, center - unit * 4 + side * 5, center - unit * 4 - side * 5, color, 0.9 * fade)
            drawn += 1
        end
    end
end

function Overlay.marker(self: any, canvas: any, view: any, item: Item, labelled: boolean, fade: number)
    local index = item.index
    local point = view.Points[index]
    local screen = item.screen
    local edit = view.Edit
    local issue = view.Issues ~= nil and view.Issues.Dots[index] ~= nil
    local chosen = index == view.Selected
    local color = DOT
    if issue then
        color = BAD
    elseif point.wait > 0 then
        color = WAIT
    end
    if chosen then
        color = SELECT
    end
    if not edit then
        canvas.filledCircle(screen, 4, color, fade)
        canvas.circle(screen, 5.5, color, 0.6 * fade, 1)
        return
    end
    local radius = if labelled or chosen then RADIUS else 5
    if index == view.Hover and not chosen then
        canvas.circle(screen, radius + 5, DOT, 0.9 * fade, 1.5)
    end
    if index == view.Run then
        canvas.circle(screen, radius + 6, RUN, 0.95 * fade, 2.5)
    end
    if index == view.GhostIndex then
        canvas.circle(screen, radius + 4, GHOST, 0.8 * fade, 1.5)
    end
    if chosen then
        canvas.circle(screen, radius + 6, SELECT, 0.95 * fade, 2)
    elseif issue then
        canvas.circle(screen, radius + 4, BAD, 0.9 * fade, 2)
    end
    canvas.filledCircle(screen, radius + 1.5, INK, 0.85 * fade)
    canvas.filledCircle(screen, radius, color, fade)
    if labelled or chosen then
        if point.wait > 0 then
            Hud.tag(canvas, Vector2.new(screen.X, screen.Y + radius + 16), number(point.wait) .. "s", WAIT, fade, 13)
        end
    end
end

function Overlay.frame(self: any, canvas: any, view: any)
    local now = os.clock()
    local goal = if view.Visible then 1 else 0
    self.Fade += (goal - self.Fade) * math.min(1, (now - self.FadeAt) * FADE_SPEED)
    self.FadeAt = now
    local fade = self.Fade
    if fade < 0.02 then
        return
    end
    local points = view.Points
    local count = #points
    local camera = view.Camera
    if count == 0 or camera == nil then
        return
    end
    follow()
    if self.LineVersion ~= view.Version then
        self.LineVersion = view.Version
        local line: { Vector3 } = {}
        for index, point in points do
            line[index] = point.position
        end
        line[count + 1] = points[1].position
        self.Line = line
    end
    local origin = camera.CFrame.Position
    local size = camera.ViewportSize
    canvas.worldPath(self.Line, LINE, 0.55 * fade, 1.5)
    if view.Issues then
        for index in view.Issues.Segments do
            canvas.worldPath({ points[index].position, points[index % count + 1].position }, BAD, 0.95 * fade, 3)
        end
    end
    local items: { Item } = {}
    for index, point in points do
        local distance = (point.position - origin).Magnitude
        if distance <= DOT_RANGE or index == view.Selected then
            local screen, depth = canvas.project(point.position)
            if screen ~= nil and onScreen(screen, depth, size) then
                table.insert(items, { index = index, screen = screen, distance = distance })
            end
        end
    end
    table.sort(items, function(a: Item, b: Item): boolean
        return a.distance > b.distance
    end)
    if view.Edit then
        local screens: { [number]: Vector2 } = {}
        for _, item in items do
            screens[item.index] = item.screen
        end
        self:arrows(canvas, view, screens, fade)
    end
    local total = #items
    local selected: Item? = nil
    for position, item in items do
        if item.index == view.Selected then
            selected = item
        else
            self:marker(canvas, view, item, total - position < NUMBERED, fade)
        end
    end
    if selected then
        self:marker(canvas, view, selected, true, fade)
        local point = points[selected.index]
        local text = string.format("Dot %d   wait %ss", selected.index, number(point.wait))
        Hud.tag(canvas, Vector2.new(selected.screen.X, selected.screen.Y - 38), text, SELECT, fade, 14)
        local issue = if view.Issues then view.Issues.Dots[selected.index] else nil
        if issue then
            Hud.tag(canvas, Vector2.new(selected.screen.X, selected.screen.Y - 68), issue, BAD, fade, 13)
        end
    end
    if view.Aim then
        local screen, depth = canvas.project(view.Aim)
        if screen ~= nil and onScreen(screen, depth, size) then
            canvas.circle(screen, RADIUS + 3, SELECT, 0.9 * fade, 2)
            canvas.line(screen - Vector2.new(5, 0), screen + Vector2.new(5, 0), SELECT, fade, 1.5)
            canvas.line(screen - Vector2.new(0, 5), screen + Vector2.new(0, 5), SELECT, fade, 1.5)
        end
    end
    if view.Ghost then
        local screen, depth = canvas.project(view.Ghost)
        if screen ~= nil and onScreen(screen, depth, size) then
            canvas.filledCircle(screen, 7, GHOST, 0.9 * fade)
            canvas.circle(screen, 11, GHOST, 0.8 * fade, 2)
            Hud.tag(canvas, Vector2.new(screen.X, screen.Y - 32), "Preview", GHOST, fade, 13)
        end
    end
end

return Overlay
end
modules["goldfarm/gold/panel"] = function(...)

local Panel = {}
Panel.__index = Panel

local TOP = 44
local ROW = 26
local BODY = 308
local SIDE = 240
local SPLIT = 10
local MIN_LIST = 72
local HOLD_DELAY = 0.4
local HOLD_REPEAT = 0.07
local GAP = 6

local WAIT = Color3.fromRGB(120, 200, 255)
local WARN = Color3.fromRGB(255, 205, 70)
local BAD = Color3.fromRGB(235, 90, 90)
local DANGER = Color3.fromRGB(200, 70, 70)

Panel.PAGE_HEIGHT = TOP + 28 + 6 + BODY

local STEPS = { 0.5, 1, 5, 10 }
local STEP_LABELS = { "0.5", "1", "5", "10" }
local DRAGS = { "Ground", "Level" }
local TABS = { "Dot", "Path", "Files" }
local AXES = {
    { axis = "X", sign = -1, label = "X-" },
    { axis = "X", sign = 1, label = "X+" },
    { axis = "Y", sign = -1, label = "Y-" },
    { axis = "Y", sign = 1, label = "Y+" },
    { axis = "Z", sign = -1, label = "Z-" },
    { axis = "Z", sign = 1, label = "Z+" },
}

local HINTS: { [string]: string } = {
    undo = "Undo the last change. 100 levels, nothing is lost by trying.",
    redo = "Bring back the change you just undid.",
    add_me = "Adds a dot where your character stands, after the selected dot.",
    add_click = "Stays armed: every click in the world places a dot. Press again to stop.",
    insert = "Adds a dot halfway between the selected dot and the next one.",
    duplicate = "Copies the selected dot, placed 2 studs further along the path.",
    move_me = "Moves the selected dot to where your character stands.",
    teleport = "Teleports your character onto the selected dot.",
    delete = "Removes the selected dot. Undo brings it back.",
    wait_minus = "Shorter wait at this dot. Hold the button to repeat.",
    wait_plus = "Longer wait at this dot. Hold the button to repeat.",
    shift_all = "Moves every dot of the path by the step. Hold to repeat.",
    shift_scope_all = "The shift pad moves all dots.",
    shift_scope_end = "The shift pad moves the selected dot and every dot after it.",
    snap = "Drops every dot onto the terrain below it. Use this after a game update.",
    reverse = "Walks the same path in the opposite direction.",
    preview = "A ghost walks the path from the selected dot. Your character stays put.",
    test = "Teleports you to the selected dot and starts Start Path from there.",
    check = "Marks dots that are too far apart, jump in height or float in red.",
    next_problem = "Selects the next red dot, one problem after another.",
    gap_minus = "Legs shorter than this are fine.",
    gap_plus = "Legs longer than this are marked red.",
    save = "Saves the working path under the typed name, or its current name when none is typed.",
    save_as = "Saves a copy. Empty name picks Path 1, Path 2 and so on.",
    revert = "Throws away unsaved changes and reloads the saved file.",
    load = "Loads the highlighted path from the list.",
    default = "Loads the highlighted path every time the script starts.",
    delete_path = "Deletes the highlighted path file. Press twice.",
    rename = "Gives the highlighted path the name typed above.",
    duplicate_path = "Makes a copy of the highlighted path.",
    new_path = "Starts a new empty path with no dots. The typed name is used when it is free, else Path 1, Path 2 and so on.",
}

function Panel.new(editor: any): any
    return setmetatable({
        Editor = editor,
        Tab = 1,
        Hold = nil :: any,
        WasDown = false,
        Clock = 0,
    }, Panel)
end

function Panel.input(self: any, window: any)
    local down = window.LeftDown == true
    if down and not self.WasDown then
        local key = window.HoverKey
        self.Hold = if type(key) == "string" then { key = key, next = self.Editor.Clock, fired = 0 } else nil
    elseif not down and self.WasDown then
        self.Hold = nil
        self.Editor.Paths:seal()
    end
    self.WasDown = down
end

function Panel.held(self: any, window: any, key: string): boolean
    local hold = self.Hold
    if hold == nil or hold.key ~= key or window.HoverKey ~= key then
        return false
    end
    local now = self.Editor.Clock
    if now < hold.next then
        return false
    end
    hold.next = now + (if hold.fired == 0 then HOLD_DELAY else HOLD_REPEAT)
    hold.fired += 1
    return true
end

local function view(kit: any, ox: number, oy: number, width: number, height: number): any
    local proxy: any = { Width = width, Height = height, App = kit.App }
    function proxy.rect(_self: any, x: number, y: number, w: number, h: number, color: Color3, alpha: number?, rounding: number?)
        kit:rect(x + ox, y + oy, w, h, color, alpha, rounding)
    end
    function proxy.text(_self: any, text: string, x: number, y: number, size: number, color: Color3, center: boolean?, middle: boolean?, font: number?)
        kit:text(text, x + ox, y + oy, size, color, center, middle, font)
    end
    function proxy.button(_self: any, key: string, x: number, y: number, w: number, h: number, onClick: () -> (), options: { [string]: any }?)
        return kit:button(key, x + ox, y + oy, w, h, onClick, options)
    end
    function proxy.input(_self: any, key: string, x: number, y: number, w: number, h: number, shown: string, onFocus: () -> (), base: Color3?)
        kit:input(key, x + ox, y + oy, w, h, shown, onFocus, base)
    end
    function proxy.segment(_self: any, key: string, x: number, y: number, w: number, h: number, labels: { string }, selected: number, onSelect: (number) -> ())
        kit:segment(key, x + ox, y + oy, w, h, labels, selected, onSelect)
    end
    function proxy.switchRow(_self: any, key: string, x: number, y: number, w: number, h: number, label: string, on: boolean, onClick: () -> ())
        kit:switchRow(key, x + ox, y + oy, w, h, label, on, onClick)
    end
    function proxy.scroll(_self: any, key: string, x: number, y: number, w: number, h: number, rowHeight: number, count: number, draw: (number, number, number, number) -> ())
        return kit:scroll(key, x + ox, y + oy, w, h, rowHeight, count, function(index: number, rx: number, ry: number, rw: number)
            draw(index, rx - ox, ry - oy, rw)
        end)
    end
    function proxy.measure(_self: any, text: string, size: number): number
        return kit:measure(text, size)
    end
    return proxy
end

local function press(kit: any, name: string, x: number, y: number, w: number, h: number, label: string, action: () -> (), options: { [string]: any }?)
    local opts: { [string]: any } = options or {}
    opts.label = label
    opts.size = opts.size or 12
    opts.align = "center"
    local app = kit.App
    if opts.textColor ~= nil and app ~= nil and opts.textColor == app.Pal.Disabled then
        opts.disabled = true
    end
    kit:button("pe:" .. name, x, y, w, h, action, opts)
end

function Panel.hold(self: any, kit: any, window: any, name: string, x: number, y: number, w: number, h: number, label: string, action: () -> (), options: { [string]: any }?)
    press(kit, name, x, y, w, h, label, function() end, options)
    if self:held(window, "pe:" .. name) then
        action()
    end
end

local function columns(width: number, count: number, gap: number): number
    return (width - gap * (count - 1)) / count
end

local function wrap(text: string, limit: number): { string }
    local lines: { string } = {}
    local line = ""
    for word in string.gmatch(text, "%S+") do
        if line ~= "" and #line + #word + 1 > limit then
            table.insert(lines, line)
            line = word
        else
            line = if line == "" then word else line .. " " .. word
        end
    end
    if line ~= "" then
        table.insert(lines, line)
    end
    return lines
end

function Panel.hint(self: any, window: any): string
    local ed = self.Editor
    local key = window.HoverKey
    if type(key) == "string" and string.sub(key, 1, 3) == "pe:" then
        local hint = HINTS[string.sub(key, 4)]
        if hint then
            return hint
        end
    end
    if ed.Arm then
        return "Placing dots: click in the world. Press Add Where I Click again to stop."
    elseif ed.Drag and ed.Drag.moved then
        return "Release the mouse to drop the dot."
    elseif ed:index() ~= nil then
        return "Drag the dot in the world to move it. Hold Shift to flip Ground and Level."
    end
    return "Click a dot in the world or in the list to select it."
end

function Panel.top(self: any, kit: any, window: any)
    local ed = self.Editor
    local paths = ed.Paths
    local width = kit.Width
    local pal = window.Pal
    local name = paths.Name
    if #name > 26 then
        name = string.sub(name, 1, 25) .. "."
    end
    kit:text(name, 2, 15, 14, pal.Text, false, true)
    local at = 2 + kit:measure(name, 14) + 8
    if paths:dirty() then
        kit:text("unsaved", at, 15, 11, WARN, false, true)
        at += kit:measure("unsaved", 11) + 8
    end
    kit:text(tostring(#paths.Points) .. " dots", at, 15, 11, pal.Sub, false, true)
    local undo, redo = paths:undoLevels(), paths:redoLevels()
    local half = 66
    press(kit, "undo", width - half * 2 - GAP, 0, half, 28, "Undo", function()
        ed:undo()
    end, { textColor = if undo > 0 then nil else pal.Disabled, size = 12 })
    press(kit, "redo", width - half, 0, half, 28, "Redo", function()
        ed:redo()
    end, { textColor = if redo > 0 then nil else pal.Disabled, size = 12 })
    local lines = wrap(self:hint(window), math.floor(width / 5.4))
    if lines[1] ~= nil then
        kit:text(lines[1], 2, 38, 10, pal.Sub, false, true)
    end
end

local function describe(point: any): string
    return string.format("%.1f   %.1f   %.1f", point.position.X, point.position.Y, point.position.Z)
end

function Panel.list(self: any, kit: any, window: any, y: number, height: number)
    local ed = self.Editor
    local points = ed.Paths.Points
    local pal = window.Pal
    local width = kit.Width
    local selected = ed:index()
    local issues = ed.Issues
    kit:rect(0, y, width, height, pal.Main, 0.5, 12)
    if #points == 0 then
        kit:text("No dots yet. Use Add At My Position below.", width / 2, y + height / 2, 12, pal.Sub, true, true)
    end
    kit:scroll("pe:list", 0, y + 2, width, height - 4, ROW, #points, function(index: number, rx: number, ry: number, rw: number)
        local point = points[index]
        local chosen = index == selected
        local flagged = issues ~= nil and issues.Dots[index] ~= nil
        local color = if flagged then BAD else nil
        kit:button("pe:row:" .. tostring(index), rx + 2, ry + 1, rw - 4, ROW - 2, function()
            ed:selectIndex(index, false)
        end, { label = string.format("%3d    %s", index, describe(point)), size = 11, active = chosen, textColor = color, align = "left", rounding = 10 })
        if point.wait > 0 then
            local text = string.format("%gs", point.wait)
            kit:text(text, rx + rw - 12 - kit:measure(text, 11), ry + ROW / 2, 11, if chosen then pal.Panel else WAIT, false, true)
        end
    end)
    if ed.ScrollTo then
        ed.ScrollTo = false
        local cell = if window.Scrolls then window.Scrolls["pe:list"] else nil
        if cell and selected then
            local top = (selected - 1) * ROW
            if top < cell.Pos or top + ROW > cell.Pos + height - 4 then
                cell.Target = math.clamp(top - (height - 4 - ROW) / 2, 0, math.max(0, #points * ROW - (height - 4)))
            end
        end
    end
end

function Panel.settings(self: any, kit: any, window: any, y: number)
    local ed = self.Editor
    local pal = window.Pal
    local width = kit.Width
    kit:text("Step", 2, y + 14, 11, pal.Sub, false, true)
    local current = 2
    local step = tonumber(ed:setting("GoldEditorStep")) or 1
    for index, value in STEPS do
        if value == step then
            current = index
        end
    end
    kit:segment("pe:step", 40, y, width - 40, 28, STEP_LABELS, current, function(index: number)
        window:set("GoldEditorStep", STEPS[index])
    end)
    kit:text("Drag", 2, y + 34 + 14, 11, pal.Sub, false, true)
    local drag = if ed:setting("GoldEditorDrag") == "Level" then 2 else 1
    kit:segment("pe:drag", 40, y + 34, width - 40, 28, DRAGS, drag, function(index: number)
        window:set("GoldEditorDrag", DRAGS[index])
    end)
end

function Panel.dot(self: any, kit: any, window: any, top: number)
    local ed = self.Editor
    local pal = window.Pal
    local width = kit.Width
    local has = ed:index() ~= nil
    local dim = if has then nil else pal.Disabled
    local half = (width - GAP) / 2
    local y = top
    press(kit, "add_me", 0, y, half, 28, "Add At My Position", function()
        ed:addAtMe()
    end)
    press(kit, "add_click", half + GAP, y, half, 28, if ed.Arm then "Placing... (stop)" else "Add Where I Click", function()
        ed:toggleArm()
    end, { active = ed.Arm })
    y += 34
    press(kit, "insert", 0, y, half, 28, "Insert After Selected", function()
        ed:insertAfter()
    end, { textColor = dim })
    press(kit, "duplicate", half + GAP, y, half, 28, "Duplicate", function()
        ed:duplicate()
    end, { textColor = dim })
    y += 34
    press(kit, "move_me", 0, y, half, 28, "TP Selected To Me", function()
        ed:moveToMe()
    end, { textColor = dim })
    press(kit, "teleport", half + GAP, y, half, 28, "TP Me To Selected", function()
        ed:teleportToSelected()
    end, { textColor = dim })
    y += 34
    press(kit, "delete", 0, y, width, 28, "Delete Selected", function()
        ed:remove()
    end, { textColor = dim, hoverColor = DANGER, hoverText = pal.Text })
    y += 38
    kit:text("Move selected dot by the step", 2, y + 4, 10, pal.Sub, false, true)
    y += 14
    local cell = columns(width, 6, 4)
    for index, axis in AXES do
        self:hold(kit, window, "nudge_" .. axis.label, (index - 1) * (cell + 4), y, cell, 34, axis.label, function()
            ed:nudge(axis.axis, axis.sign)
        end, { textColor = dim, size = 13 })
    end
    y += 44
    local point = ed:point()
    local wait = if point then point.wait else 0
    kit:text("Wait time at selected dot", 2, y + 4, 10, pal.Sub, false, true)
    y += 14
    self:hold(kit, window, "wait_minus", 0, y, 56, 30, "-", function()
        ed:stepWait(-1)
    end, { textColor = dim, size = 16 })
    self:hold(kit, window, "wait_plus", width - 56, y, 56, 30, "+", function()
        ed:stepWait(1)
    end, { textColor = dim, size = 16 })
    kit:rect(62, y, width - 124, 30, pal.Main, 0.6, 10)
    kit:text(if point then string.format("%g s", wait) else "-", width / 2, y + 15, 13, if wait > 0 then WAIT else pal.Text, true, true)
    y += 36
    local presets = ed.WAIT_PRESETS
    local presetWidth = columns(width, #presets, 4)
    for index, value in presets do
        press(kit, "wait_" .. tostring(index), (index - 1) * (presetWidth + 4), y, presetWidth, 26, string.format("%gs", value), function()
            ed:setWait(value)
        end, { active = point ~= nil and math.abs(wait - value) < 1e-6, textColor = dim, size = 11 })
    end
    y += 36
    kit:text("Exact values (optional)", 2, y + 4, 10, pal.Sub, false, true)
    y += 14
    local fieldWidth = columns(width, 4, 4)
    for index, name in { "X", "Y", "Z", "Wait" } do
        local key = "pe:field:" .. name
        local shown = if has then name .. "  " .. ed.Fields[name] else name
        kit:input(key, (index - 1) * (fieldWidth + 4), y, fieldWidth, 26, shown, function()
            if has then
                window:beginInput(key, ed.Fields[name], {
                    numeric = true,
                    maxLength = 14,
                    commit = function(value: string)
                        ed:commitField(name, value)
                    end,
                })
            end
        end)
    end
    return y + 30
end

function Panel.path(self: any, kit: any, window: any, top: number)
    local ed = self.Editor
    local pal = window.Pal
    local width = kit.Width
    local half = (width - GAP) / 2
    local y = top
    kit:text("Shift the path (uses the step)", 2, y + 4, 10, pal.Sub, false, true)
    y += 14
    kit:segment("pe:scope", 0, y, width, 28, { "All Dots", "Selected To End" }, if ed.FromSelected then 2 else 1, function(index: number)
        ed.FromSelected = index == 2
    end)
    y += 34
    local cell = columns(width, 6, 4)
    for index, axis in AXES do
        self:hold(kit, window, "shift_" .. axis.label, (index - 1) * (cell + 4), y, cell, 34, axis.label, function()
            ed:shiftAll(axis.axis, axis.sign)
        end, { size = 13 })
    end
    y += 44
    press(kit, "snap", 0, y, width, 30, "Snap All Dots To Ground", function()
        ed:snapAll()
    end)
    y += 36
    press(kit, "reverse", 0, y, half, 30, "Reverse Path", function()
        ed:reverse()
    end)
    press(kit, "preview", half + GAP, y, half, 30, if ed.Preview.Active then "Stop Preview" else "Preview Run", function()
        ed:togglePreview()
    end, { active = ed.Preview.Active })
    y += 36
    press(kit, "test", 0, y, width, 30, "Test From Here", function()
        ed:testFrom()
    end, { textColor = if ed:index() then nil else pal.Disabled })
    y += 40
    local on = ed:setting("GoldEditorValidate") == true
    kit:switchRow("pe:check", 0, y, width, 32, "Check Path (marks errors red)", on, function()
        window:set("GoldEditorValidate", not on)
    end)
    y += 38
    local gap = tonumber(ed:setting("GoldEditorGap")) or 700
    kit:text("Longest leg: " .. tostring(gap), 2, y + 14, 12, pal.Text, false, true)
    local small = 44
    self:hold(kit, window, "gap_minus", width - small * 2 - GAP, y, small, 28, "-", function()
        window:set("GoldEditorGap", math.max(100, gap - ed.GAP_STEP))
    end, { size = 15 })
    self:hold(kit, window, "gap_plus", width - small, y, small, 28, "+", function()
        window:set("GoldEditorGap", math.min(3000, gap + ed.GAP_STEP))
    end, { size = 15 })
    y += 34
    press(kit, "next_problem", 0, y, width, 28, "Next Problem", function()
        ed:nextIssue()
    end)
    y += 34
    local issues = ed.Issues
    local text: string
    if issues == nil then
        text = "Turn on Check Path to find problems."
    elseif issues.Count == 0 then
        text = "No problems found."
    else
        text = string.format("%d dots look wrong. %s", issues.Count, issues.Dots[issues.Indices[1]])
    end
    for index, line in wrap(text, math.floor(width / 5.4)) do
        if index <= 2 then
            kit:text(line, 2, y + 6 + (index - 1) * 13, 10, if issues ~= nil and issues.Count > 0 then BAD else pal.Sub, false, true)
        end
    end
    return y + 36
end

function Panel.files(self: any, kit: any, window: any, top: number)
    local ed = self.Editor
    local paths = ed.Paths
    local pal = window.Pal
    local width = kit.Width
    local y = top
    kit:text("Name (for Save As and Rename)", 2, y + 4, 10, pal.Sub, false, true)
    y += 14
    kit:input("pe:name", 0, y, width, 28, if ed.NameInput == "" then "tap to type a name" else ed.NameInput, function()
        window:beginInput("pe:name", ed.NameInput, {
            maxLength = 32,
            commit = function(value: string)
                ed.NameInput = value
            end,
        })
    end)
    y += 34
    local third = columns(width, 3, GAP)
    press(kit, "save", 0, y, third, 30, "Save", function()
        ed:save()
    end)
    press(kit, "save_as", third + GAP, y, third, 30, if ed:confirming("overwrite") then "Press Again" else "Save As", function()
        ed:saveAs()
    end)
    press(kit, "revert", (third + GAP) * 2, y, third, 30, if ed:confirming("revert") then "Press Again" else "Revert", function()
        ed:revert()
    end)
    y += 38
    kit:text("Saved paths", 2, y + 4, 10, pal.Sub, false, true)
    local loaded = "loaded: " .. paths.Name
    kit:text(loaded, width - 2 - kit:measure(loaded, 10), y + 4, 10, pal.Sub, false, true)
    y += 14
    local names = ed:profiles()
    kit:rect(0, y, width, 96, pal.Main, 0.5, 12)
    kit:scroll("pe:profiles", 0, y + 2, width, 92, 28, #names, function(index: number, rx: number, ry: number, rw: number)
        local name = names[index]
        local label = name
        if name == ed.Default then
            label ..= "   (default)"
        end
        if name == paths.Name then
            label ..= "   loaded"
        end
        kit:button("pe:profile:" .. name, rx + 2, ry + 1, rw - 4, 26, function()
            ed.Chosen = name
        end, { label = label, size = 12, active = name == ed.Chosen, align = "left", rounding = 10 })
    end)
    y += 104
    press(kit, "load", 0, y, third, 30, if ed:confirming("load") then "Press Again" else "Load", function()
        ed:loadChosen()
    end)
    press(kit, "default", third + GAP, y, third, 30, if ed:confirming("default") then "Press Again" else "Set Default", function()
        ed:defaultChosen()
    end)
    press(kit, "delete_path", (third + GAP) * 2, y, third, 30, if ed:confirming("delete") then "Press Again" else "Delete", function()
        ed:deleteChosen()
    end, { hoverColor = DANGER, hoverText = pal.Text })
    y += 36
    press(kit, "rename", 0, y, third, 30, "Rename", function()
        ed:renameChosen()
    end)
    press(kit, "duplicate_path", third + GAP, y, third, 30, "Duplicate", function()
        ed:duplicateChosen()
    end)
    press(kit, "new_path", (third + GAP) * 2, y, third, 30, if ed:confirming("new") then "Press Again" else "New Path", function()
        ed:newPath()
    end)
    return y + 30
end

function Panel.render(self: any, kit: any, window: any)
    self:input(window)
    local width = kit.Width
    local side = math.min(SIDE, math.floor(width * 0.45))
    self:top(view(kit, 0, 0, width, TOP), window)
    local body = kit.Height - TOP
    local left = view(kit, 0, TOP, side, body)
    local list = math.max(MIN_LIST, body - 62 - GAP)
    self:list(left, window, 0, list)
    self:settings(left, window, list + GAP)
    local right = view(kit, side + SPLIT, TOP, width - side - SPLIT, body)
    right:segment("pe:tab", 0, 0, right.Width, 28, TABS, self.Tab, function(index: number)
        self.Tab = index
    end)
    local top = 28 + GAP
    local shown = body - top
    local tab = self.Tab
    local heights = self.Heights
    if heights == nil then
        heights = {}
        self.Heights = heights
    end
    right:scroll("pe:right:" .. tostring(tab), 0, top, right.Width, shown, math.max(shown, heights[tab] or shown), 1, function(_index: number, rx: number, ry: number, rw: number)
        local sub = view(right, rx, ry, rw, shown)
        if tab == 1 then
            heights[tab] = self:dot(sub, window, 0)
        elseif tab == 2 then
            heights[tab] = self:path(sub, window, 0)
        else
            heights[tab] = self:files(sub, window, 0)
        end
    end)
end

return Panel
end
modules["goldfarm/gold/paths"] = function(...)

local import: (string) -> any = ...
local Store: any = import("goldfarm/gold/store")

local Paths = {}
Paths.__index = Paths

Paths.BUILT_IN = Store.BUILT_IN
Paths.clean = Store.clean
Paths.LEVELS = 100

local FLUSH_DELAY = 1.2

export type Point = { position: Vector3, wait: number, key: string }

local function round(value: number): number
    return math.floor(value * 100 + 0.5) / 100
end

local function rounded(position: Vector3): Vector3
    return Vector3.new(round(position.X), round(position.Y), round(position.Z))
end

Paths.rounded = rounded

local function copy(list: { Point }): { Point }
    local result: { Point } = table.create(#list)
    for index, point in list do
        result[index] = point
    end
    return result
end

local function indexIn(list: { Point }, key: string?): number?
    if key == nil then
        return nil
    end
    for index, point in list do
        if point.key == key then
            return index
        end
    end
    return nil
end

function Paths.new(folder: string, http: any): any
    local points: { Point } = Store.builtIn()
    return setmetatable({
        Store = Store.new(folder, http),
        Http = http,
        Points = points,
        Saved = points :: { Point }?,
        Name = Paths.BUILT_IN,
        Version = 0,
        Serial = 0,
        Undo = {} :: { { Point } },
        Redo = {} :: { { Point } },
        Tag = nil :: string?,
        Written = 0,
        WrittenAt = 0,
        Restored = false,
    }, Paths)
end

function Paths.dirty(self: any): boolean
    return self.Points ~= self.Saved
end

function Paths.find(self: any, key: string?): number?
    return indexIn(self.Points, key)
end

function Paths.get(self: any, key: string?): Point?
    local index = indexIn(self.Points, key)
    return if index then self.Points[index] else nil
end

function Paths.newKey(self: any): string
    self.Serial += 1
    local ok, guid = pcall(function()
        return self.Http:GenerateGUID(false)
    end)
    if ok and type(guid) == "string" then
        return guid
    end
    return string.format("p%d_%d", os.time(), self.Serial)
end

function Paths.edit(self: any, tag: string?, apply: ({ Point }) -> ())
    if tag == nil or tag ~= self.Tag then
        table.insert(self.Undo, self.Points)
        if #self.Undo > Paths.LEVELS then
            table.remove(self.Undo, 1)
        end
        table.clear(self.Redo)
    end
    self.Tag = tag
    local list = copy(self.Points)
    apply(list)
    self.Points = list
    self.Version += 1
end

function Paths.seal(self: any)
    self.Tag = nil
end

function Paths.undoLevels(self: any): number
    return #self.Undo
end

function Paths.redoLevels(self: any): number
    return #self.Redo
end

function Paths.undo(self: any): boolean
    local previous = table.remove(self.Undo)
    if previous == nil then
        return false
    end
    table.insert(self.Redo, self.Points)
    self.Points = previous
    self.Tag = nil
    self.Version += 1
    return true
end

function Paths.redo(self: any): boolean
    local following = table.remove(self.Redo)
    if following == nil then
        return false
    end
    table.insert(self.Undo, self.Points)
    self.Points = following
    self.Tag = nil
    self.Version += 1
    return true
end

function Paths.add(self: any, position: Vector3, wait: number?, afterKey: string?): string
    local key = self:newKey()
    self:edit(nil, function(list: { Point })
        local at = (indexIn(list, afterKey) or #list) + 1
        table.insert(list, at, { position = rounded(position), wait = math.max(wait or 0, 0), key = key })
    end)
    return key
end

function Paths.setPoint(self: any, key: string, position: Vector3?, wait: number?, tag: string?): boolean
    local index = indexIn(self.Points, key)
    if index == nil then
        return false
    end
    local current: Point = self.Points[index]
    local target = if position then rounded(position) else current.position
    local delay = if wait then math.max(round(wait * 100) / 100, 0) else current.wait
    if (target - current.position).Magnitude < 1e-6 and delay == current.wait then
        return true
    end
    self:edit(tag, function(list: { Point })
        list[index] = { position = target, wait = delay, key = key }
    end)
    return true
end

function Paths.remove(self: any, key: string): boolean
    if indexIn(self.Points, key) == nil then
        return false
    end
    self:edit(nil, function(list: { Point })
        local index = indexIn(list, key)
        if index then
            table.remove(list, index)
        end
    end)
    return true
end

function Paths.shift(self: any, offset: Vector3, fromKey: string?, tag: string?): number
    local start = if fromKey then indexIn(self.Points, fromKey) else 1
    if start == nil or #self.Points == 0 then
        return 0
    end
    self:edit(tag, function(list: { Point })
        for index = start, #list do
            local point = list[index]
            list[index] = { position = rounded(point.position + offset), wait = point.wait, key = point.key }
        end
    end)
    return #self.Points - start + 1
end

function Paths.place(self: any, positions: { [string]: Vector3 }): number
    local count = 0
    for key in positions do
        if indexIn(self.Points, key) then
            count += 1
        end
    end
    if count == 0 then
        return 0
    end
    self:edit(nil, function(list: { Point })
        for index, point in list do
            local target = positions[point.key]
            if target then
                list[index] = { position = rounded(target), wait = point.wait, key = point.key }
            end
        end
    end)
    return count
end

function Paths.reverse(self: any)
    if #self.Points < 2 then
        return
    end
    self:edit(nil, function(list: { Point })
        local count = #list
        for index = 1, math.floor(count / 2) do
            list[index], list[count - index + 1] = list[count - index + 1], list[index]
        end
    end)
end

function Paths.adopt(self: any, name: string, points: { Point })
    self.Points = points
    self.Saved = points
    self.Name = name
    table.clear(self.Undo)
    table.clear(self.Redo)
    self.Tag = nil
    self.Version += 1
    self.Written = self.Version
    self.Store:clearWorking()
end

function Paths.blank(self: any, name: string)
    self:adopt(name, {})
end

function Paths.load(self: any, name: string): (boolean, string)
    local cleaned = Store.clean(name)
    local points = self.Store:read(cleaned)
    if points == nil then
        return false, "Path not found: " .. cleaned
    end
    self:adopt(cleaned, points)
    return true, "Loaded path: " .. cleaned
end

function Paths.loadDefault(self: any)
    self.Store:ensure()
    local name, points = self.Store:readWorking()
    if not self:load(self.Store:default()) then
        self:load(Paths.BUILT_IN)
    end
    if name ~= nil and points ~= nil and #points > 0 then
        self.Saved = self.Store:read(name) or {}
        self.Points = points
        self.Name = name
        self.Version += 1
        self.Written = self.Version
        self.Restored = true
        self.Store:writeWorking(name, points)
    end
end

function Paths.save(self: any, name: string?): (boolean, string)
    local target = Store.clean(name or self.Name)
    if target == Paths.BUILT_IN then
        return false, "Built-in is the original route. Use Save As to keep your copy."
    end
    if not self.Store:write(target, self.Points) then
        return false, "Path save failed."
    end
    self.Name = target
    self.Saved = self.Points
    self.Written = self.Version
    self.Store:clearWorking()
    return true, "Saved path: " .. target
end

function Paths.list(self: any): { string }
    return self.Store:names()
end

function Paths.defaultName(self: any): string
    return self.Store:default()
end

function Paths.setDefault(self: any, name: string): (boolean, string)
    local cleaned = Store.clean(name)
    if not self.Store:exists(cleaned) then
        return false, "Save this path before setting it as default."
    end
    if not self.Store:setDefault(cleaned) then
        return false, "Could not write the default path file."
    end
    if cleaned ~= self.Name then
        self:load(cleaned)
    end
    return true, "Default path: " .. cleaned
end

function Paths.delete(self: any, name: string): (boolean, string)
    local cleaned = Store.clean(name)
    if cleaned == Paths.BUILT_IN then
        return false, "The built-in path cannot be deleted."
    end
    if not self.Store:remove(cleaned) then
        return false, "Delete failed."
    end
    if self.Store:default() == cleaned then
        self.Store:setDefault(Paths.BUILT_IN)
        if self.Name == cleaned then
            self:load(Paths.BUILT_IN)
        end
    end
    if self.Name == cleaned then
        self.Name = Paths.BUILT_IN
        self.Saved = nil
    end
    return true, "Deleted path: " .. cleaned
end

function Paths.rename(self: any, name: string, target: string): (boolean, string)
    local from, to = Store.clean(name), Store.clean(target)
    if from == Paths.BUILT_IN or to == Paths.BUILT_IN then
        return false, "The built-in path cannot be renamed."
    end
    if from == to then
        return false, "That is already its name."
    end
    if self.Store:exists(to) then
        return false, "A path named " .. to .. " exists."
    end
    local points = self.Store:read(from)
    if points == nil or not self.Store:write(to, points) then
        return false, "Rename failed."
    end
    self.Store:remove(from)
    if self.Store:default() == from then
        self.Store:setDefault(to)
    end
    if self.Name == from then
        self.Name = to
    end
    return true, "Renamed to " .. to
end

function Paths.duplicate(self: any, name: string): (boolean, string)
    local from = Store.clean(name)
    local points = self.Store:read(from)
    if points == nil then
        return false, "Path not found: " .. from
    end
    local target = from .. " copy"
    local number = 1
    while self.Store:exists(target) do
        number += 1
        target = from .. " copy " .. tostring(number)
    end
    target = string.sub(target, 1, 48)
    if not self.Store:write(target, points) then
        return false, "Duplicate failed."
    end
    return true, "Created " .. target
end

function Paths.flush(self: any, force: boolean?)
    if self.Written == self.Version then
        return
    end
    if force ~= true and os.clock() - self.WrittenAt < FLUSH_DELAY then
        return
    end
    self.WrittenAt = os.clock()
    self.Written = self.Version
    if self:dirty() then
        self.Store:writeWorking(self.Name, self.Points)
    else
        self.Store:clearWorking()
    end
end

return Paths
end
modules["goldfarm/gold/pointer"] = function(...)

local Pointer = {}
Pointer.__index = Pointer

local RANGE = 1500
local PICK_RADIUS = 22
local TIE = 6

function Pointer.new(context: any, ground: any, onClick: () -> ()): any
    local self = setmetatable({
        Context = context,
        Ground = ground,
        OnClick = onClick,
        OnRelease = nil :: (() -> ())?,
    }, Pointer)
    local input: any = self:service()
    if input then
        context.connect(input.InputBegan, function(event: any, processed: boolean)
            if not processed and event.UserInputType == Enum.UserInputType.MouseButton1 then
                self.OnClick()
            end
        end)
        context.connect(input.InputEnded, function(event: any)
            if event.UserInputType == Enum.UserInputType.MouseButton1 and self.OnRelease then
                self.OnRelease()
            end
        end)
    end
    return self
end

function Pointer.service(self: any): any
    return self.Context.Game.modules.service("UserInputService")
end

function Pointer.location(self: any): Vector2?
    local input: any = self:service()
    if input == nil then
        return nil
    end
    local ok, spot = pcall(function()
        return input:GetMouseLocation()
    end)
    if ok then
        return spot
    end
    return nil
end

function Pointer.down(self: any): boolean
    local input: any = self:service()
    if input == nil then
        return false
    end
    local ok, pressed = pcall(function()
        return input:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    end)
    return ok and pressed == true
end

function Pointer.holding(self: any, key: any): boolean
    local input: any = self:service()
    if input == nil then
        return false
    end
    local ok, pressed = pcall(function()
        return input:IsKeyDown(key)
    end)
    return ok and pressed == true
end

function Pointer.camera(self: any): any
    local space = self.Context.Game.world.workspace()
    return if space then space.CurrentCamera else nil
end

function Pointer.ray(self: any): (Vector3?, Vector3?)
    local camera = self:camera()
    local spot = self:location()
    if camera == nil or spot == nil then
        return nil, nil
    end
    local ok, ray = pcall(function()
        return camera:ViewportPointToRay(spot.X, spot.Y)
    end)
    if ok and ray then
        return ray.Origin, ray.Direction
    end
    return nil, nil
end

function Pointer.hit(self: any): any
    local origin, direction = self:ray()
    if origin == nil or direction == nil then
        return nil
    end
    return self.Ground:cast(origin, direction * RANGE)
end

function Pointer.plane(self: any, height: number): Vector3?
    local origin, direction = self:ray()
    if origin == nil or direction == nil or math.abs(direction.Y) < 1e-4 then
        return nil
    end
    local along = (height - origin.Y) / direction.Y
    if along <= 0 or along * direction.Magnitude > RANGE then
        return nil
    end
    return origin + direction * along
end

function Pointer.nearest(self: any, points: { Vector3 }, prefer: number?): number?
    local camera = self:camera()
    local spot = self:location()
    if camera == nil or spot == nil then
        return nil
    end
    local best: number? = nil
    local bestDistance = PICK_RADIUS
    local preferDistance = math.huge
    pcall(function()
        for index, point in points do
            local screen = camera:WorldToViewportPoint(point)
            if screen.Z > 0 then
                local distance = (Vector2.new(screen.X, screen.Y) - spot).Magnitude
                if index == prefer then
                    preferDistance = distance
                end
                if distance <= bestDistance then
                    best, bestDistance = index, distance
                end
            end
        end
    end)
    if prefer ~= nil and best ~= nil and preferDistance <= PICK_RADIUS and preferDistance <= bestDistance + TIE then
        return prefer
    end
    return best
end

local function inside(point: Vector2, position: Vector2, size: Vector2): boolean
    return point.X >= position.X and point.X <= position.X + size.X and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

function Pointer.overUi(self: any, ui: any): boolean
    local spot = self:location()
    if spot == nil or ui == nil then
        return false
    end
    local over = false
    pcall(function()
        local window: any = ui.Window
        local unit = math.max(0.2, window.Scale or 1)
        if window.Panels then
            for _, panel in window.Panels do
                if panel.Pos and panel.Anim > 0.01 and inside(spot, panel.Pos, Vector2.new(panel.Width * unit, panel.Height * unit)) then
                    over = true
                end
            end
        end
        if window.State.Visible == true and window.WindowPos and window.WindowSize and inside(spot, window.WindowPos, window.WindowSize) then
            over = true
        end
    end)
    return over
end

return Pointer
end
modules["goldfarm/gold/press"] = function(...)

local Press = {}
Press.__index = Press

local FIND_RANGE = 20
local PRESS_RANGE = 12
local CHEST_RANGE = 45
local CHEST_LIMIT = 30
local PRESSABLE = "Gold"
local GRACE = 0.6
local SEND_EVERY = 0.04
local SCAN_EVERY = 0.08
local PAUSE_LIMIT = 120

function Press.new(context: any): any
    return setmetatable({
        Context = context,
        Game = context.Game,
        Paused = false,
        PausedAt = 0,
        Session = nil :: any,
        TimedOut = false,
        BusyAt = 0,
        ChestGold = 0,
        NextScan = 0,
        NextSend = 0,
        Working = false,
        Round = 0,
        LastBag = 0,
        Listeners = {} :: { (any) -> () },
    }, Press)
end

function Press.onCycle(self: any, listener: (any) -> ())
    table.insert(self.Listeners, listener)
end

function Press.finish(self: any)
    local info = { gold = self.Round, at = os.time() }
    self.Working = false
    self.Round = 0
    for _, listener in self.Listeners do
        pcall(listener, info)
    end
end

function Press.resume(self: any)
    if self.Paused then
        self.Paused = false
        self.Game.movement.unfreeze()
    end
end

function Press.reset(self: any)
    self:resume()
    self.Session = nil
    self.TimedOut = false
    self.BusyAt = 0
    self.ChestGold = 0
    self.Working = false
    self.Round = 0
end

function Press.scan(self: any, now: number)
    if now < self.NextScan then
        return
    end
    self.NextScan = now + SCAN_EVERY
    local Game = self.Game
    local gold = 0
    for _, entry in Game.finder.chests(CHEST_RANGE) do
        for _, name in Game.constants.COOKED_GOLD_NAMES do
            gold += Game.chests.count(entry.instance, name)
        end
    end
    self.ChestGold = gold
    if gold > 0 then
        Game.chests.takeNearby(CHEST_RANGE, Game.constants.COOKED_GOLD_NAMES, CHEST_LIMIT)
    end
end

function Press.hold(self: any, now: number, wanted: boolean)
    if wanted and self.Paused and now - self.PausedAt >= PAUSE_LIMIT then
        self.TimedOut = true
        self:resume()
        self.Context.notify("Pause Near Press: still gold after 120 s, the path continues")
        return
    end
    if not wanted or self.TimedOut then
        self:resume()
    elseif not self.Paused and self.Game.movement.freeze() then
        self.Paused = true
        self.PausedAt = now
    end
end

function Press.tick(self: any)
    local Game = self.Game
    local read = self.Context.read
    local press = Game.finder.nearestCoinPress(FIND_RANGE)
    if press == nil or not Game.world.isSpawned() then
        self:reset()
        return
    end
    if self.Session ~= press.instance then
        self.Session = press.instance
        self.TimedOut = false
        self.BusyAt = 0
        self.ChestGold = 0
        self.NextScan = 0
    end
    if self.Paused and not Game.movement.isFrozen() then
        self.Paused = false
    end
    local now = os.clock()
    if read("GoldPickupChest") == true then
        self:scan(now)
    else
        self.ChestGold = 0
    end
    local near = press.distance <= PRESS_RANGE
    local bag = Game.inventory.count(PRESSABLE)
    if bag > 0 or self.ChestGold > 0 then
        self.BusyAt = now
    end
    if near and bag > 0 and now >= self.NextSend then
        self.NextSend = now + SEND_EVERY
        if Game.actions.pressCoin(press.instance) then
            self.Working = true
        end
    end
    if self.Working and bag < self.LastBag then
        self.Round += self.LastBag - bag
    end
    self.LastBag = bag
    local pending = now - self.BusyAt < GRACE and self.BusyAt > 0
    if not near then
        self.Working = false
        self.Round = 0
    elseif self.Working and not pending then
        self:finish()
    end
    self:hold(now, near and read("GoldPauseNearPress") == true and pending)
end

return Press
end
modules["goldfarm/gold/preview"] = function(...)

local Preview = {}
Preview.__index = Preview

local SPEED = 19

function Preview.new(): any
    return setmetatable({
        Active = false,
        Position = Vector3.new(0, 0, 0),
        Target = 1,
        Pause = 0,
    }, Preview)
end

function Preview.start(self: any, points: { any }, from: number)
    local point = points[from]
    if point == nil then
        return
    end
    self.Active = true
    self.Position = point.position
    self.Pause = point.wait
    self.Target = from % #points + 1
end

function Preview.stop(self: any)
    self.Active = false
end

function Preview.step(self: any, points: { any }, dt: number)
    if not self.Active then
        return
    end
    local count = #points
    if count == 0 then
        self.Active = false
        return
    end
    local left = dt
    if self.Pause > 0 then
        local used = math.min(self.Pause, left)
        self.Pause -= used
        left -= used
    end
    local guard = 0
    while left > 0 and self.Pause <= 0 and guard <= count do
        guard += 1
        if self.Target > count then
            self.Target = 1
        end
        local point = points[self.Target]
        local offset: Vector3 = point.position - self.Position
        local reach = SPEED * left
        if offset.Magnitude > reach then
            self.Position += offset.Unit * reach
            left = 0
        else
            left -= offset.Magnitude / SPEED
            self.Position = point.position
            self.Pause = point.wait
            self.Target = self.Target % count + 1
            if count == 1 and self.Pause <= 0 then
                left = 0
            end
        end
    end
end

return Preview
end
modules["goldfarm/gold/route"] = function(...)

return {
    { "r1", -141.89999389648438, -19.149999618530273, -195.3699951171875, 2 },
    { "F1328602-04B3-4681-B632-E5B61326167C", -130.0800018310547, -21.420000076293945, -199.7899932861328, 0 },
    { "r2", -119.31350708007812, -25.793699264526367, -194.75294494628906, 1.5 },
    { "r3", -107.11988830566406, -14.877410888671875, -185.7013702392578, 0 },
    { "r4", -91.96001434326172, -6.04759407043457, -176.57630920410156, 0 },
    { "r5", -36.64952087402344, -2.8125057220458984, -133.5755157470703, 0 },
    { "AD90B04B-58C7-43A1-819A-7E7459DBE72A", -18.1299991607666, -2.009999990463257, -119.04000091552734, 0 },
    { "5AFFA252-7099-4D1C-A079-4911FF584E89", 5.050000190734863, -1.3700000047683716, -116.47000122070312, 0 },
    { "B67D2196-342D-468B-B1C1-2DD677311866", 91.55999755859375, -0.4000000059604645, -66.26000213623047, 0 },
    { "CE93D61D-41C1-4265-A22B-C1D0EC2091F0", 113.87000274658203, -7.110000133514404, -41.900001525878906, 0 },
    { "3FEB215D-C0E0-4A92-99D7-B5785A1B13C8", 271.4599914550781, -4.760000228881836, 82.87999725341797, 0 },
    { "r6", 410.7699890136719, -11.470000267028809, 193.61000061035156, 0 },
    { "r13", 563.97998046875, -2.9000000953674316, 305.760009765625, 0 },
    { "DA85994E-A97C-4B4F-8E33-E502D5B49EC1", 571.3200073242188, 15.1899995803833, 308.510009765625, 0 },
    { "BCF981E3-3B1B-44CD-8F46-8EDBB0109707", 588.1500244140625, 13.119999885559082, 322.489990234375, 1 },
    { "D1B4AB4A-E0FB-4D0A-A5B5-A412A3D2B7E5", 604.97998046875, 13.6899995803833, 336.4800109863281, 0 },
    { "7B382A39-52DC-4271-A124-D1152FDC2D9A", 581.3400268554688, 11.850000381469727, 393.6000061035156, 1.5 },
    { "r14", 630.489990234375, 12.649999618530273, 354.45001220703125, 0 },
    { "A2868BDD-4152-407D-91CE-A3A6BC404B46", 698.9099731445312, 10.350000381469727, 362.5899963378906, 0 },
    { "90D9015B-B2FB-4744-AEBF-FABA79E177BB", 723.239990234375, -2.9000000953674316, 362.04998779296875, 0 },
    { "CD3BBD5E-39C8-4D6F-9546-2E62BDA5B1CA", 774.9099731445312, -2.9000000953674316, 365.1300048828125, 0 },
    { "EB7D7235-9CA8-479A-9B26-0375AA57A255", 1008.9400024414062, 0.3499999940395355, 458.80999755859375, 0 },
    { "r15", 1104.9000244140625, 0.03999999910593033, 471.4100036621094, 0 },
    { "r16", 1200.1700439453125, -2.25, 567.3200073242188, 0 },
    { "r17", 1261.68994140625, -11.670000076293945, 512.4000244140625, 0 },
    { "r18", 1296.1800537109375, -13.90999984741211, 558.0800170898438, 1 },
    { "r19", 1307.719970703125, -15.460000038146973, 579.72998046875, 0 },
    { "r20", 1337.449951171875, -15.859999656677246, 603.8300170898438, 0 },
    { "r21", 1363.010009765625, -18.760000228881836, 580.3900146484375, 1 },
    { "r22", 1340.43994140625, -15.449999809265137, 603.4500122070312, 0 },
    { "r23", 1362.3900146484375, -15.779999732971191, 646.760009765625, 0 },
    { "r24", 1330.760009765625, -18.920000076293945, 672.219970703125, 1 },
    { "r25", 1365.2900390625, -15.739999771118164, 647.4600219726562, 0 },
    { "r26", 1318.9599609375, -15.279999732971191, 586.4000244140625, 0 },
    { "r27", 1296.010009765625, -15.770000457763672, 567.2999877929688, 0 },
    { "r28", 1281.9300537109375, -12.119999885559082, 534.7100219726562, 0 },
    { "r29", 1235.780029296875, -15.430000305175781, 444.2099914550781, 1 },
    { "E88F633A-D4BA-4BFA-8ADB-0289CB3C023B", 1243.0899658203125, -15.09000015258789, 466.6300048828125, 0 },
    { "r30", 1269.6800537109375, -23.34000015258789, 444.1300048828125, 0 },
    { "r31", 1339.0400390625, -26.829999923706055, 448.54998779296875, 0 },
    { "r32", 1334.550048828125, -20.6200008392334, 418.5299987792969, 0 },
    { "r33", 1304.75, -16.770000457763672, 386.42999267578125, 0 },
    { "r34", 1202.0400390625, -4.309999942779541, 348.1600036621094, 0 },
    { "r35", 1179.5699462890625, -1.8600000143051147, 318.75, 0 },
    { "r36", 716.411376953125, -3.9945693016052246, -142.5128173828125, 0 },
    { "r37", 694.3192138671875, 17.386688232421875, -161.43527221679688, 0 },
    { "r38", 683.3438110351562, 32.30760192871094, -167.1634521484375, 0 },
    { "r39", 660.0833740234375, 32.245208740234375, -186.8964080810547, 1 },
    { "r40", 699.4446411132812, 28.500442504882812, -201.92117309570312, 0 },
    { "r41", 715.6201782226562, 26.26921844482422, -217.4705352783203, 0 },
    { "r42", 726.97998046875, 23.309999465942383, -244.5, 0 },
    { "0A67F864-92EF-4FDE-9BEB-6E1DD804084E", 725.239990234375, 22.950000762939453, -284.5, 0 },
    { "r43", 702.0609741210938, 34.193241119384766, -309.710205078125, 0 },
    { "C17DA2C2-39E1-4ADA-BE9A-D11741A1B188", 694.8699951171875, 43.54999923706055, -320.3399963378906, 0 },
    { "r44", 687.9099731445312, 59.84000015258789, -336.3599853515625, 0 },
    { "r45", 682.963623046875, 62.84449768066406, -354.2230224609375, 0 },
    { "r46", 682.5621337890625, 74.81529235839844, -363.08709716796875, 0 },
    { "r47", 679.9118041992188, 80.4763412475586, -372.0174255371094, 0 },
    { "r48", 679.9000244140625, 79.76000213623047, -378.6300048828125, 1 },
    { "AC7E593C-BA8D-4565-9054-C367ECA5CAE6", 672.6599731445312, 78.16999816894531, -375.45001220703125, 0 },
    { "22B5D0D7-FC2A-4477-8365-8FF5296C80EB", 663.989990234375, 71.83999633789062, -376.1400146484375, 0 },
    { "F3E97F3E-C995-4096-9D89-BEE10BE049CC", 660.75, 64.63999938964844, -370.94000244140625, 0 },
    { "7E0FCB3C-6674-4B36-8D80-BBF123AB8D56", 656.1400146484375, 56.470001220703125, -358.79998779296875, 0 },
    { "4FEE8585-A636-432D-B0BA-71C33AE8C55C", 631.5999755859375, 47.72999954223633, -357.8900146484375, 0 },
    { "r49", 592.7100219726562, 24.270000457763672, -360.0799865722656, 0 },
    { "r50", 580.9199829101562, 19.190000534057617, -358.5799865722656, 0 },
    { "0D2F20D0-B367-4A4E-B1FE-E9C5698669B9", 584.719970703125, 14.390000343322754, -347.94000244140625, 0 },
    { "D5F6A7CA-039E-4435-BD7D-CEC448F2B26C", 598.3099975585938, -7.090000152587891, -353.45001220703125, 1 },
    { "r51", 623.1016845703125, -7.344945907592773, -358.8044738769531, 0.25 },
    { "r52", 631.27001953125, -7, -369.57000732421875, 2 },
    { "2633BA0F-C089-442D-B553-EB8622341C73", 615.22998046875, -7.079999923706055, -385.4200134277344, 1 },
    { "r53", 554.26904296875, 12.96484375, -398.23663330078125, 0 },
    { "r54", 464.4996032714844, -5, -419.7094421386719, 0 },
    { "r55", 19.623218536376953, -6.068264484405518, -550.6239013671875, 0 },
    { "r56", -21.722415924072266, -3.0084075927734375, -557.9688110351562, 0 },
    { "r57", -57.53821563720703, -3.388853073120117, -570.225341796875, 0 },
    { "r58", -179.04275512695312, -1.5733046531677246, -621.7989501953125, 0 },
    { "r59", -198.27664184570312, 6.366794586181641, -625.4280395507812, 0 },
    { "r60", -206.7178497314453, 19.34856605529785, -626.2610473632812, 0 },
    { "r61", -212.7473602294922, 19.61411476135254, -621.0771484375, 1 },
    { "r62", -227.88816833496094, 2.816864013671875, -618.2684326171875, 0 },
    { "r63", -365.38031005859375, -3.0617294311523438, -611.3173828125, 0 },
    { "r64", -387.54278564453125, -11.44034194946289, -609.9725952148438, 0 },
    { "r65", -399.1018371582031, -22.568632125854492, -609.0355834960938, 0 },
    { "r66", -409.27484130859375, -39.42827606201172, -554.4389038085938, 0 },
    { "r67", -387.3904724121094, -43.19425582885742, -555.9221801757812, 1 },
    { "r68", -315.548583984375, -49.17181396484375, -569.5033569335938, 0 },
    { "r69", -281.66156005859375, -56.85545349121094, -558.1670532226562, 0 },
    { "r70", -230.5189971923828, -59, -539.8056640625, 0 },
    { "r71", -214.7939453125, -59.485443115234375, -526.3626708984375, 0 },
    { "r72", -201.5225830078125, -60.20200729370117, -541.5321044921875, 0 },
    { "r73", -174.5003204345703, -63.09870910644531, -563.3765258789062, 0 },
    { "r74", -157.77098083496094, -64.46682739257812, -593.5687866210938, 0 },
    { "r75", -207.91184997558594, -61.69873046875, -625.405517578125, 2 },
    { "r76", -157.7576446533203, -64.44625854492188, -593.5261840820312, 0 },
    { "r77", -174.50450134277344, -63.100341796875, -563.4628295898438, 0 },
    { "r78", -165.35691833496094, -63.074806213378906, -511.9172058105469, 0 },
    { "r79", -180.05520629882812, -69.2813491821289, -453.8267517089844, 0 },
    { "r80", -171.56483459472656, -73.43494415283203, -456.92535400390625, 0 },
    { "r81", -156.2505645751953, -99.44965362548828, -478.06658935546875, 0 },
    { "r82", -164.91696166992188, -99.43761444091797, -502.3164367675781, 0 },
    { "r83", -183.961181640625, -102.99999237060547, -505.1149597167969, 0 },
    { "r84", -192.162109375, -103.27455139160156, -496.7663879394531, 0 },
    { "r85", -189.58489990234375, -104.05291748046875, -456.0731201171875, 2 },
    { "r86", -192.1395263671875, -103.26908111572266, -496.70355224609375, 0 },
    { "r87", -183.95126342773438, -103, -505.1314392089844, 0 },
    { "r88", -164.86270141601562, -99.4522476196289, -502.3470153808594, 0 },
    { "r89", -146.2549591064453, -97.43460845947266, -495.0435485839844, 0 },
    { "r90", 7.541040420532227, -103, -423.418212890625, 0 },
    { "r91", 34.360626220703125, -99.18365478515625, -371.1417541503906, 0 },
    { "r92", 55.09477996826172, -99, -359.40777587890625, 1 },
    { "r93", 19.69225311279297, -99, -391.58526611328125, 0 },
    { "r94", 11.900020599365234, -102.96358489990234, -415.3416748046875, 0 },
    { "r95", -45.130699157714844, -104.36945343017578, -389.5151672363281, 0 },
    { "r96", -92.34864044189453, -103, -353.9851379394531, 0 },
    { "r97", -123.5248794555664, -90.99566650390625, -291.9811706542969, 0 },
    { "r98", -159.88336181640625, -87.26156616210938, -263.26336669921875, 0 },
    { "r99", -245.3988494873047, -83, -248.14662170410156, 1 },
    { "r100", -230.7689666748047, -83.02196502685547, -257.0267639160156, 0 },
    { "r101", -232.29132080078125, -80.01478576660156, -268.34808349609375, 0 },
    { "r102", -262.0515441894531, -79, -298.0277404785156, 0 },
    { "r103", -262.7806091308594, -78.65348815917969, -323.1799621582031, 0 },
    { "r104", -304.8475036621094, -79, -368.1495056152344, 1 },
    { "r105", -262.7782897949219, -78.65474700927734, -323.1613464355469, 0 },
    { "r106", -262.1943054199219, -79, -297.93939208984375, 0 },
    { "r107", -232.17462158203125, -80.07608032226562, -268.10711669921875, 0 },
    { "r108", -230.7614288330078, -83.02151489257812, -256.96624755859375, 0 },
    { "r109", -234.27493286132812, -90.60616302490234, -217.21533203125, 0 },
    { "r110", -234.24928283691406, -88.4429702758789, -177.45703125, 0 },
    { "r111", -298.5879211425781, -93, -76.40196228027344, 0 },
    { "r112", -336.71014404296875, -91.015625, -47.368873596191406, 1 },
    { "r113", -322.3817138671875, -85.93417358398438, -103.84822082519531, 0 },
    { "r114", -312.7877502441406, -80.29764556884766, -107.85237884521484, 0 },
    { "r115", -291.18798828125, -72.95791625976562, -96.05986785888672, 0 },
    { "r116", -258.7352600097656, -71.40682220458984, -83.00981140136719, 0 },
    { "r117", -237.53225708007812, -71.65625, -83.11640167236328, 1 },
    { "r118", -264.6081237792969, -74.92657470703125, -74.37799072265625, 0 },
    { "r119", -271.8966369628906, -93, -69.28028106689453, 0 },
    { "r120", -244.89463806152344, -93, -94.01403045654297, 0 },
    { "r121", -234.6796417236328, -86.08658599853516, -96.06693267822266, 0 },
    { "r122", -208.53977966308594, -89.05722045898438, -92.98556518554688, 0 },
    { "r123", -186.21617126464844, -93, -86.48092651367188, 0 },
    { "r124", -23.464744567871094, -91.06700134277344, -6.431948661804199, 1 },
    { "r125", -54.05946731567383, -93, -34.732177734375, 0 },
    { "r126", -64.57084655761719, -83.93140411376953, -67.21971130371094, 0 },
    { "r127", -56.27317810058594, -75.80343627929688, -74.03585052490234, 0 },
    { "r128", -25.429244995117188, -75.0190658569336, -49.47193145751953, 0 },
    { "r129", -20.472515106201172, -75.26667785644531, -41.99848937988281, 0 },
    { "r130", 3.372006416320801, -75.00245666503906, -37.93674087524414, 0 },
    { "r131", 9.361078262329102, -75, -45.16803741455078, 0 },
    { "r132", 2.1956307888031006, -83, -81.34650421142578, 1 },
    { "r133", 7.540444850921631, -77.6328125, -91.84691619873047, 0 },
    { "r134", 10.9675931930542, -73.97479248046875, -100.1095962524414, 0 },
    { "r135", 21.415082931518555, -70.9155044555664, -110.52931213378906, 0 },
    { "r136", 48.723270416259766, -75, -125.2779541015625, 0 },
    { "r137", 63.05690383911133, -75.3080062866211, -130.89697265625, 0 },
    { "r138", 70.77178192138672, -72.12876892089844, -118.96957397460938, 0 },
    { "r139", 74.71022033691406, -60.7221565246582, -90.87541961669922, 0 },
    { "r140", 67.58888244628906, -48.76361083984375, -62.624996185302734, 0 },
    { "r141", 45.71700668334961, -36.125831604003906, -57.280296325683594, 0 },
    { "r142", -40.736576080322266, -35.00068664550781, -100.33395385742188, 0 },
    { "r143", -106.33723449707031, -35.000003814697266, -160.429931640625, 1 },
    { "r144", -125.25753784179688, -35.04928970336914, -160.6648406982422, 1 },
    { "r145", -148.1999969482422, -33.75, -163.85000610351562, 2 },
    { "3474892F-9127-405C-8FFA-8EEDBDE0FD09", -140.66000366210938, -34.86000061035156, -163.07000732421875, 0 },
    { "460B1BA7-1BAF-4EAF-ACAE-20DFBF65CC09", -140.1999969482422, -32.7400016784668, -181.36000061035156, 0 },
} :: { { any } }
end
modules["goldfarm/gold/runner"] = function(...)

local Runner = {}
Runner.__index = Runner

local SPEED = 19
local REACH = 1.15
local STUCK_RADIUS = 10
local STUCK_SECONDS = 40
local HIT_WAIT = 2
local HIT_RANGE = 15
local HIT_DELAY = 0.3
local CLICK_DELAY = 0.25
local SCAN_SECONDS = 1.5
local SWING_EVERY = 0.15
local CLICK_EVERY = 0.4
local BREAK_MAX = 30
local LOG = "dot hit log.txt"
local LOG_LINES = 40

function Runner.new(context: any, paths: any): any
    local game = context.Game
    return setmetatable({
        Context = context,
        Game = game,
        Paths = paths,
        Index = nil :: number?,
        Reached = false,
        WaitUntil = 0,
        Version = -1,
        Root = nil :: any,
        Detector = game.movement.stuckDetector(STUCK_RADIUS, STUCK_SECONDS),
        StuckCheckAt = 0,
        Restarts = 0,
        Pending = nil :: number?,
        HitAt = nil :: number?,
        ClickAt = nil :: number?,
        CheckAt = nil :: number?,
        Miner = nil :: any,
        Held = false,
        Mining = false,
        Target = nil :: any,
        ScanUntil = nil :: number?,
        BreakStart = 0,
        SwingAt = 0,
    }, Runner)
end

function Runner.drive(self: any, position: Vector3)
    self.Game.drive.step(position + Vector3.new(0, self.Game.drive.hover, 0), SPEED)
end

function Runner.restart(self: any, first: boolean?)
    local World, Drive = self.Game.world, self.Game.drive
    Drive.finish()
    local root = if World.isSpawned() then World.root() else nil
    if root then
        Drive.begin(root)
        self.Index = self.Game.movement.nearestIndex(self.Paths.Points, root.Position)
    else
        self.Index = nil
    end
    local pending = self.Pending
    self.Pending = nil
    if root and pending and self.Paths.Points[pending] then
        self.Index = pending
    end
    if root and first == true and #self.Paths.Points > 0 then
        self.Index = 1
    end
    self.Root = root
    self.Reached = false
    self.WaitUntil = 0
    self:endHit()
    self.Version = self.Paths.Version
    self.Detector.reset(if root then root.Position else nil)
    self.Restarts += 1
    self.Held = false
    if self.Miner ~= nil then
        self.Miner:reset()
    end
end

function Runner.stuckRemaining(self: any): number
    return math.max(0, math.ceil(STUCK_SECONDS - self.Detector.elapsed()))
end

function Runner.advance(self: any, points: { any })
    self.Index = (self.Index :: number) % #points + 1
    self.Reached = false
    self:drive(points[self.Index].position)
end

function Runner.log(self: any, text: string)
    pcall(function()
        local path = self.Context.Folder .. "/" .. LOG
        local lines: { string } = {}
        if isfile(path) then
            for line in string.gmatch(readfile(path), "[^\n]+") do
                table.insert(lines, line)
            end
        end
        table.insert(lines, os.date("%H:%M:%S") .. "  " .. text)
        while #lines > LOG_LINES do
            table.remove(lines, 1)
        end
        writefile(path, table.concat(lines, "\n") .. "\n")
    end)
end

function Runner.endHit(self: any)
    self.HitAt = nil
    self.ClickAt = nil
    self.Target = nil
    self.ScanUntil = nil
end

function Runner.breaking(self: any): boolean
    return self.Target ~= nil
end

function Runner.breakNode(self: any, point: any)
    if not self.Reached or point.wait < HIT_WAIT or self.ScanUntil == nil then
        return
    end
    local now = os.clock()
    if self.Target == nil then
        if now > self.ScanUntil then
            self.ScanUntil = nil
            return
        end
        local nearest: any = nil
        for _, entry in self.Game.finder.resources(HIT_RANGE, { contains = { "gold" } }) do
            if nearest == nil or entry.distance < nearest.distance then
                nearest = entry
            end
        end
        if nearest ~= nil then
            self.Target = nearest
            self.BreakStart = now
            self.SwingAt = 0
            self:log(string.format("dot %s: breaking the gold node %.1f studs away", tostring(self.Index), nearest.distance))
        end
        return
    end
    local node = self.Target.instance
    if node == nil or node.Parent == nil then
        self:log(string.format("dot %s: gold node broken after %.1f s", tostring(self.Index), now - self.BreakStart))
        self.Target = nil
        self.ScanUntil = nil
        return
    end
    if now - self.BreakStart > BREAK_MAX then
        self:log(string.format("dot %s: gold node not broken after %d s, moving on", tostring(self.Index), BREAK_MAX))
        self.Target = nil
        self.ScanUntil = nil
        return
    end
    local game = self.Game
    if not game.packets.has("SwingTool") then
        game.packets.resolve()
    end
    if game.packets.has("SwingTool") then
        if now - self.SwingAt >= SWING_EVERY then
            self.SwingAt = now
            game.actions.hit({ self.Target }, 1)
        end
    elseif now - self.SwingAt >= CLICK_EVERY then
        self.SwingAt = now
        game.actions.clickScreen()
    end
end

function Runner.hitGold(self: any)
    local World = self.Game.world
    local root = World.root()
    if root == nil then
        return
    end
    local nearest: any = nil
    for _, entry in self.Game.finder.resources(HIT_RANGE, { contains = { "gold" } }) do
        if nearest == nil or entry.distance < nearest.distance then
            nearest = entry
        end
    end
    if nearest == nil then
        self:log("dot " .. tostring(self.Index) .. ": no gold node within " .. HIT_RANGE .. " studs, no click")
        return
    end
    self.ClickAt = os.clock() + CLICK_DELAY
    local game = self.Game
    local input = game.modules.service("UserInputService")
    local space = game.world.workspace()
    local camera = if space then space.CurrentCamera else nil
    self:log(string.format(
        "hit dot %s: gold node %.1f studs away, holding: %s, camera type: %s, mouse behavior: %s, swing layout learned: %s",
        tostring(self.Index), nearest.distance, tostring(game.inventory.equippedName()),
        tostring(if camera then camera.CameraType else nil), tostring(if input then input.MouseBehavior else nil),
        tostring(game.template.has("SwingTool"))
    ))
end

function Runner.arrive(self: any, point: any)
    self.Reached = true
    local miner = self.Miner
    if miner ~= nil and miner:enabled() then
        self.WaitUntil = 0
        self.HitAt = nil
        self.ClickAt = nil
    elseif point.wait > 0 then
        self.Game.drive.halt()
        self.WaitUntil = os.clock() + point.wait
        self.HitAt = if point.wait >= HIT_WAIT then os.clock() + HIT_DELAY else nil
        self.ClickAt = nil
        self.Target = nil
        self.ScanUntil = if point.wait >= HIT_WAIT then os.clock() + SCAN_SECONDS else nil
    else
        self.WaitUntil = 0
        self.HitAt = nil
        self.ClickAt = nil
    end
end

function Runner.tick(self: any, blocked: boolean, holding: boolean, antiStuck: boolean)
    local World, Drive = self.Game.world, self.Game.drive
    if not World.isSpawned() then
        self.Index = nil
        if Drive.active() then
            Drive.finish()
        end
        self.Detector.reset(nil)
        return
    end
    if blocked then
        self.Detector.reset(World.position())
        return
    end
    local root = World.root()
    local points = self.Paths.Points
    if root == nil or #points == 0 then
        Drive.halt()
        return
    end
    if self.Root ~= root or self.Version ~= self.Paths.Version then
        self.Root = root
        self.Version = self.Paths.Version
        self.Index = nil
    end
    if holding then
        Drive.halt()
        self.Detector.reset(root.Position)
        return
    end
    if self.Index == nil or points[self.Index] == nil then
        self.Index = self.Game.movement.nearestIndex(points, root.Position)
        self.Reached = false
        self.WaitUntil = 0
    end
    local point = points[self.Index]
    local target = point.position + Vector3.new(0, Drive.hover, 0)
    local miner = self.Miner
    local mining = miner ~= nil and miner:enabled()
    if mining ~= self.Mining then
        self.Mining = mining
        self.Held = false
        self.WaitUntil = 0
        if miner ~= nil then
            miner:reset()
        end
    end
    if self.Held and miner ~= nil and miner:enabled() then
        local keep, approach = miner:holding(self.Index, root, os.clock())
        if keep then
            if approach ~= nil then
                Drive.step(approach, SPEED)
            else
                Drive.halt()
            end
        else
            self.Held = false
            self:advance(points)
        end
    elseif (root.Position - target).Magnitude <= REACH then
        if not self.Reached then
            self:arrive(point)
        end
        if self.HitAt ~= nil and os.clock() >= self.HitAt then
            self.HitAt = nil
            self:hitGold()
        end
        if self.ClickAt ~= nil and os.clock() >= self.ClickAt then
            self.ClickAt = nil
            local sent = self.Game.actions.clickScreen()
            self:endHit()
            self:log("click sent: " .. tostring(sent))
            self.CheckAt = os.clock() + 1
        end
        if self.CheckAt ~= nil and os.clock() >= self.CheckAt then
            self.CheckAt = nil
            self:log("one second after the click, swing layout learned: " .. tostring(self.Game.template.has("SwingTool")))
        end
        self:breakNode(point)
        if os.clock() >= self.WaitUntil and not self:breaking() then
            local keep, approach = false, nil
            if miner ~= nil and miner:enabled() then
                keep, approach = miner:holding(self.Index, root, os.clock())
            end
            if keep then
                self.Held = true
                if approach ~= nil then
                    Drive.step(approach, SPEED)
                else
                    Drive.halt()
                end
            else
                self.Held = false
                self:advance(points)
            end
        end
    else
        self.Reached = false
        self.Held = false
        self:drive(point.position)
    end
    local waiting = self.Reached and (os.clock() < self.WaitUntil or self.Held or self:breaking())
    if not antiStuck or waiting then
        self.Detector.reset(root.Position)
    elseif os.clock() >= self.StuckCheckAt then
        self.StuckCheckAt = os.clock() + 1
        if self.Detector.update(root.Position) then
            self:restart()
        end
    end
end

function Runner.finish(self: any)
    self.Game.drive.finish()
    self.Index = nil
    self.Root = nil
    self.Reached = false
    self.WaitUntil = 0
    self.Held = false
    self:endHit()
    if self.Miner ~= nil then
        self.Miner:reset()
    end
end

return Runner
end
modules["goldfarm/gold/slots"] = function(...)

local Slots = {}
Slots.__index = Slots

local PICKAXE_SLOT = 1
local HOE_SLOT = 2
local ENTER_RANGE = 15
local LEAVE_RANGE = 18
local DEBOUNCE = 0.5
local MANUAL_PAUSE = 4
local EXPECT_WINDOW = 1.5
local RETRY_AFTER = 1.2
local ATTEMPTS = 2
local NODE_RANGE = 11

function Slots.new(context: any): any
    return setmetatable({
        Context = context,
        Game = context.Game,
        Near = nil :: boolean?,
        Candidate = nil :: boolean?,
        CandidateSince = 0,
        Pending = false,
        Attempts = 0,
        RetryAt = 0,
        Held = nil :: string?,
        Watching = false,
        Expect = nil :: string?,
        ExpectUntil = 0,
        ManualUntil = 0,
        Warned = false,
    }, Slots)
end

function Slots.reset(self: any)
    self.Near = nil
    self.Candidate = nil
    self.Pending = false
    self.Attempts = 0
    self.Watching = false
    self.Held = nil
    self.Expect = nil
    self.ExpectUntil = 0
    self.ManualUntil = 0
end

function Slots.distance(self: any): number?
    local nearest: number? = nil
    for _, box in self.Game.finder.plantBoxes(LEAVE_RANGE, false) do
        if nearest == nil or box.distance < nearest then
            nearest = box.distance
        end
    end
    return nearest
end

function Slots.watch(self: any, now: number)
    local held = self.Game.inventory.equippedName()
    if not self.Watching then
        self.Watching = true
        self.Held = held
        return
    end
    if held == self.Held then
        return
    end
    self.Held = held
    if now < self.ExpectUntil then
        if held == self.Expect then
            self.Expect = nil
            self.ExpectUntil = 0
        end
        return
    end
    self.ManualUntil = now + MANUAL_PAUSE
    self.Pending = false
end

function Slots.nodeClose(self: any): boolean
    return false
end

function Slots.follow(self: any, now: number)
    local distance = self:distance()
    local near: boolean
    if self.Near == true then
        near = distance ~= nil
    else
        near = distance ~= nil and distance <= ENTER_RANGE
    end
    if near and self:nodeClose() then
        near = false
    end
    if self.Near == nil then
        self.Near = near
        return
    end
    if near == self.Near then
        self.Candidate = nil
        return
    end
    if self.Candidate ~= near then
        self.Candidate = near
        self.CandidateSince = now
        return
    end
    if now - self.CandidateSince < DEBOUNCE then
        return
    end
    self.Near = near
    self.Candidate = nil
    self.Attempts = 0
    self.Pending = now >= self.ManualUntil
end

function Slots.apply(self: any, now: number)
    if not self.Pending or now < self.ManualUntil or now < self.RetryAt then
        return
    end
    local inventory = self.Game.inventory
    local toolbar = inventory.toolbar()
    local pickaxe, hoe = toolbar[PICKAXE_SLOT], toolbar[HOE_SLOT]
    if pickaxe == nil or hoe == nil then
        self.Pending = false
        if not self.Warned then
            self.Warned = true
            self.Context.notify("Switch Slot 1/2: slots 1 and 2 are not readable")
        end
        return
    end
    local slot, tool = PICKAXE_SLOT, pickaxe
    if self.Near == true then
        slot, tool = HOE_SLOT, hoe
    end
    local held = inventory.equippedName()
    if held == tool or (held ~= nil and held ~= pickaxe and held ~= hoe) or self.Attempts >= ATTEMPTS then
        self.Pending = false
        return
    end
    self.Attempts += 1
    self.RetryAt = now + RETRY_AFTER
    self.Expect = tool
    self.ExpectUntil = now + EXPECT_WINDOW
    self.Game.actions.pressSlotKey(slot)
end

function Slots.tick(self: any)
    if not self.Game.world.isSpawned() then
        self:reset()
        return
    end
    local now = os.clock()
    self:watch(now)
    self:follow(now)
    self:apply(now)
end

return Slots
end
modules["goldfarm/gold/store"] = function(...)

local import: (string) -> any = ...
local Route: { { any } } = import("goldfarm/gold/route")
local Legacy: { { number } } = import("goldfarm/gold/legacy")

local Store = {}
Store.__index = Store

Store.BUILT_IN = "built-in"
Store.FORMAT = 2
Store.REVISION = 6

export type Point = { position: Vector3, wait: number, key: string }

local function clean(name: any): string
    local text = string.gsub(tostring(name or ""), "[^%w%-_ ]", "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    if text == "" then
        text = "default"
    end
    return string.sub(text, 1, 48)
end

Store.clean = clean

function Store.new(folder: string, http: any): any
    return setmetatable({
        Folder = folder .. "/paths",
        DefaultFile = folder .. "/default_path.json",
        WorkingFile = folder .. "/working_path.json",
        Http = http,
    }, Store)
end

local function legacy(data: any): { Point }
    local edits: any = if type(data.pathEdits) == "table" then data.pathEdits else {}
    local points: { Point } = {}
    for index, base in Legacy do
        local edit: any = edits[tostring(index)]
        local x, y, z, wait = base[1], base[2], base[3], base[4]
        if type(edit) == "table" then
            x = tonumber(edit.x) or x
            y = tonumber(edit.y) or y
            z = tonumber(edit.z) or z
            wait = tonumber(edit.wait) or wait
        end
        table.insert(points, { position = Vector3.new(x, y, z), wait = math.max(wait, 0), key = "r" .. tostring(index) })
    end
    if type(data.pathAddedPoints) == "table" then
        for index, entry in data.pathAddedPoints do
            if type(entry) == "table" and entry.deleted ~= true then
                local x, y, z = tonumber(entry.x), tonumber(entry.y), tonumber(entry.z)
                if x and y and z then
                    table.insert(points, {
                        position = Vector3.new(x, y, z),
                        wait = math.max(tonumber(entry.wait) or 0, 0),
                        key = tostring(entry.id or ("a" .. tostring(index))),
                    })
                end
            end
        end
    end
    return points
end

local function explicit(list: any): { Point }
    local points: { Point } = {}
    local seen: { [string]: boolean } = {}
    for index, entry in list do
        if type(entry) == "table" then
            local x, y, z = tonumber(entry.x), tonumber(entry.y), tonumber(entry.z)
            if x and y and z then
                local key = tostring(entry.id or ("p" .. tostring(index)))
                if seen[key] then
                    key ..= "_" .. tostring(index)
                end
                seen[key] = true
                table.insert(points, {
                    position = Vector3.new(x, y, z),
                    wait = math.max(tonumber(entry.wait) or 0, 0),
                    key = key,
                })
            end
        end
    end
    return points
end

function Store.decode(data: any): { Point }
    if type(data) ~= "table" then
        return legacy({})
    end
    if type(data.points) == "table" then
        return explicit(data.points)
    end
    return legacy(data)
end

function Store.pack(points: { Point }): { any }
    local list: { any } = {}
    for index, point in points do
        list[index] = {
            id = point.key,
            x = point.position.X,
            y = point.position.Y,
            z = point.position.Z,
            wait = point.wait,
        }
    end
    return list
end

function Store.builtIn(): { Point }
    local points: { Point } = {}
    for _, entry in Route do
        table.insert(points, { position = Vector3.new(entry[2], entry[3], entry[4]), wait = math.max(entry[5], 0), key = entry[1] })
    end
    return points
end

function Store.file(self: any, name: string): string
    return self.Folder .. "/" .. clean(name) .. ".json"
end

function Store.ensure(self: any): boolean
    return (pcall(function()
        local path = ""
        for _, piece in string.split(self.Folder, "/") do
            path = if path == "" then piece else path .. "/" .. piece
            if not isfolder(path) then
                makefolder(path)
            end
        end
        local builtIn = self:file(Store.BUILT_IN)
        if not isfile(builtIn) then
            writefile(builtIn, self.Http:JSONEncode({ pathEdits = {}, pathAddedPoints = {} }))
        end
        if not isfile(self.DefaultFile) then
            writefile(self.DefaultFile, self.Http:JSONEncode({ name = Store.BUILT_IN }))
        end
    end))
end

function Store.names(self: any): { string }
    local names: { string } = { Store.BUILT_IN }
    local seen: { [string]: boolean } = { [Store.BUILT_IN] = true }
    self:ensure()
    pcall(function()
        for _, path in listfiles(self.Folder) do
            local name = string.match(tostring(path), "([^/\\]+)%.json$")
            if name and not seen[name] then
                seen[name] = true
                table.insert(names, name)
            end
        end
    end)
    table.sort(names, function(a: string, b: string): boolean
        if a == Store.BUILT_IN then
            return true
        elseif b == Store.BUILT_IN then
            return false
        end
        return string.lower(a) < string.lower(b)
    end)
    return names
end

function Store.exists(self: any, name: string): boolean
    local cleaned = clean(name)
    if cleaned == Store.BUILT_IN then
        return true
    end
    local found = false
    pcall(function()
        found = isfile(self:file(cleaned))
    end)
    return found
end

function Store.read(self: any, name: string): { Point }?
    local cleaned = clean(name)
    if cleaned == Store.BUILT_IN then
        return Store.builtIn()
    end
    self:ensure()
    local ok, data = pcall(function()
        local path = self:file(cleaned)
        if not isfile(path) then
            return nil
        end
        return self.Http:JSONDecode(readfile(path))
    end)
    if not ok or type(data) ~= "table" then
        return nil
    end
    return Store.decode(data)
end

function Store.write(self: any, name: string, points: { Point }): boolean
    if not self:ensure() then
        return false
    end
    return (pcall(function()
        writefile(self:file(name), self.Http:JSONEncode({
            format = Store.FORMAT,
            points = Store.pack(points),
            pathEdits = {},
            pathAddedPoints = {},
        }))
    end))
end

function Store.remove(self: any, name: string): boolean
    return (pcall(function()
        local path = self:file(name)
        if isfile(path) then
            delfile(path)
        end
    end))
end

function Store.default(self: any): string
    local name = Store.BUILT_IN
    pcall(function()
        if isfile(self.DefaultFile) then
            local marker = self.Http:JSONDecode(readfile(self.DefaultFile))
            if type(marker) == "table" and marker.name ~= nil then
                name = clean(marker.name)
            end
        end
    end)
    return name
end

function Store.setDefault(self: any, name: string): boolean
    self:ensure()
    return (pcall(function()
        writefile(self.DefaultFile, self.Http:JSONEncode({ name = clean(name) }))
    end))
end

function Store.writeWorking(self: any, name: string, points: { Point }): boolean
    if not self:ensure() then
        return false
    end
    return (pcall(function()
        writefile(self.WorkingFile, self.Http:JSONEncode({ format = Store.FORMAT, name = name, base = if name == Store.BUILT_IN then Store.REVISION else nil, dirty = true, points = Store.pack(points) }))
    end))
end

function Store.readWorking(self: any): (string?, { Point }?)
    local ok, data = pcall(function()
        if not isfile(self.WorkingFile) then
            return nil
        end
        return self.Http:JSONDecode(readfile(self.WorkingFile))
    end)
    if not ok or type(data) ~= "table" or data.dirty ~= true or type(data.points) ~= "table" then
        return nil, nil
    end
    local name = clean(data.name)
    if name == Store.BUILT_IN and data.base ~= Store.REVISION then
        return nil, nil
    end
    return name, explicit(data.points)
end

function Store.clearWorking(self: any)
    pcall(function()
        if isfile(self.WorkingFile) then
            delfile(self.WorkingFile)
        end
    end)
end

return Store
end
modules["goldfarm/gold/utility"] = function(...)

local Utility = {}
Utility.__index = Utility

local PITCH = math.rad(-36)
local YAW = math.rad(120)
local LOOK = Vector3.new(-math.cos(PITCH) * math.sin(YAW), math.sin(PITCH), -math.cos(PITCH) * math.cos(YAW))
local HEADING = CFrame.lookAt(Vector3.new(0, 0, 0), Vector3.new(LOOK.X, 0, LOOK.Z).Unit)

function Utility.new(context: any): any
    return setmetatable({
        Context = context,
        Game = context.Game,
        WalkApplied = false,
        Faced = false,
    }, Utility)
end

function Utility.walk(self: any)
    local Game = self.Game
    local humanoid = Game.world.humanoid()
    if humanoid == nil then
        return
    end
    local on = self.Context.read("GoldWalkSpeedOn") == true
    if on then
        if not Game.drive.active() then
            humanoid.WalkSpeed = math.clamp(tonumber(self.Context.read("GoldWalkSpeed")) or 19, 10, 19)
            self.WalkApplied = true
        end
    elseif self.WalkApplied then
        self.WalkApplied = false
        if not Game.drive.active() then
            humanoid.WalkSpeed = Game.constants.SPEEDS.Walk
        end
    end
end

function Utility.camera(self: any)
    if self.Context.read("GoldLockCamera") ~= true or self.Context.read("GoldStartPath") ~= true then
        self.Faced = false
        return
    end
    if not self.Game.drive.active() then
        self.Faced = false
    elseif not self.Faced then
        self.Faced = self.Game.drive.turn(HEADING)
    end
    local space = self.Game.world.workspace()
    local camera = if space then space.CurrentCamera else nil
    if camera == nil or camera.CameraType == Enum.CameraType.Scriptable then
        return
    end
    local position = camera.CFrame.Position
    camera.CFrame = CFrame.lookAt(position, position + LOOK)
end

function Utility.step(self: any)
    self:walk()
    self:camera()
end

function Utility.shutdown(self: any)
    if self.WalkApplied then
        self.WalkApplied = false
        local humanoid = self.Game.world.humanoid()
        if humanoid ~= nil and not self.Game.drive.active() then
            humanoid.WalkSpeed = self.Game.constants.SPEEDS.Walk
        end
    end
end

return Utility
end
modules["goldfarm/gold/validate"] = function(...)

local Validate = {}
Validate.__index = Validate

Validate.GAP = 400
Validate.JUMP = 40
Validate.FLOAT = 30

type Cached = { position: Vector3, height: number | boolean }

function Validate.new(ground: any): any
    return setmetatable({ Ground = ground, Cache = {} :: { [string]: Cached } }, Validate)
end

function Validate.height(self: any, point: any): number?
    local cached = self.Cache[point.key]
    if cached == nil or (cached.position - point.position).Magnitude > 1e-6 then
        local height = self.Ground:height(point.position)
        cached = { position = point.position, height = if height then height else false }
        self.Cache[point.key] = cached
    end
    if type(cached.height) == "number" then
        return cached.height
    end
    return nil
end

function Validate.run(self: any, points: { any }, gap: number, jump: number): any
    local dots: { [number]: string } = {}
    local segments: { [number]: boolean } = {}
    local count = #points
    local function flag(index: number, text: string)
        if dots[index] == nil then
            dots[index] = text
        end
    end
    for index = 1, count do
        local point = points[index]
        local following = (index % count) + 1
        if count > 1 then
            local other = points[following]
            local offset = other.position - point.position
            if offset.Magnitude > gap then
                segments[index] = true
                local text = string.format("Dot %d to %d is %d studs long", index, following, math.floor(offset.Magnitude + 0.5))
                flag(index, text)
                flag(following, text)
            end
            if math.abs(offset.Y) > jump then
                segments[index] = true
                local text = string.format("Dot %d to %d changes height by %d studs", index, following, math.floor(math.abs(offset.Y) + 0.5))
                flag(index, text)
                flag(following, text)
            end
        end
        local height = self:height(point)
        if height ~= nil and height > Validate.FLOAT then
            flag(index, string.format("Dot %d floats %d studs above the ground", index, math.floor(height + 0.5)))
        end
    end
    local alive: { [string]: boolean } = {}
    for _, point in points do
        alive[point.key] = true
    end
    for key in self.Cache do
        if not alive[key] then
            self.Cache[key] = nil
        end
    end
    local indices: { number } = {}
    for index in dots do
        table.insert(indices, index)
    end
    table.sort(indices)
    return { Dots = dots, Segments = segments, Indices = indices, Count = #indices }
end

return Validate
end
modules["goldfarm/hud"] = function(...)

local Hud = {}

local HOST = "Booga Utilities"
local FALLBACK_MAIN = Color3.fromRGB(20, 20, 22)
local FALLBACK_TEXT = Color3.fromRGB(240, 240, 240)
local FALLBACK_ACCENT = Color3.fromRGB(255, 205, 70)

export type Row = { label: string, value: string, color: Color3?, amount: number? }
export type Spec = { title: string, sub: string?, rows: { Row }?, dropped: number?, total: string? }

export type Palette = { line: Color3, dot: Color3, good: Color3, bad: Color3, warn: Color3, ghost: Color3, dim: Color3 }

local cachedPalette: Palette? = nil
local cachedText: Color3? = nil
local cachedAccent: Color3? = nil
local cachedDim: Color3? = nil

function Hud.palette(): Palette
    local _, text, accent, dim = Hud.theme()
    if cachedPalette ~= nil and cachedText == text and cachedAccent == accent and cachedDim == dim then
        return cachedPalette
    end
    cachedText, cachedAccent, cachedDim = text, accent, dim
    local palette: Palette = {
        line = accent:Lerp(text, 0.3),
        dot = text,
        good = Color3.fromRGB(110, 220, 130):Lerp(accent, 0.2),
        bad = Color3.fromRGB(235, 90, 90):Lerp(accent, 0.15),
        warn = accent:Lerp(Color3.new(1, 1, 1), 0.55),
        ghost = accent:Lerp(text, 0.55),
        dim = dim,
    }
    cachedPalette = palette
    return palette
end

function Hud.theme(): (Color3, Color3, Color3, Color3)
    local instances = getgenv().OkloUIInstances
    local ui = if type(instances) == "table" then instances[HOST] else nil
    local pal = if ui ~= nil and ui.Window ~= nil then ui.Window.Pal else nil
    local main = if pal ~= nil then pal.Main else FALLBACK_MAIN
    local text = if pal ~= nil then pal.Text else FALLBACK_TEXT
    local accent = if pal ~= nil then pal.Accent else FALLBACK_ACCENT
    return main, text, accent, text:Lerp(main, 0.45)
end

local ARC = 3
local RADIUS = 18

local function radius(height: number): number
    local instances = getgenv().OkloUIInstances
    local ui = if type(instances) == "table" then instances[HOST] else nil
    local state = if ui ~= nil and ui.Window ~= nil then ui.Window.State else nil
    local roundness = if state ~= nil then tonumber(state.Roundness) else nil
    return math.clamp(math.floor(RADIUS * (roundness or 0.46) + 0.5), 2, math.floor(height / 2))
end

local function frame(canvas: any, left: number, top: number, width: number, height: number, main: Color3, accent: Color3, fade: number)
    local tint = main:Lerp(accent, 0.1)
    local r = radius(height)
    local right, bottom = left + width, top + height
    local fill = 0.92 * fade
    canvas.filledRect(Vector2.new(left + r, top), Vector2.new(width - r * 2, height), tint, fill)
    canvas.filledRect(Vector2.new(left, top + r), Vector2.new(r, height - r * 2), tint, fill)
    canvas.filledRect(Vector2.new(right - r, top + r), Vector2.new(r, height - r * 2), tint, fill)
    local edge = accent:Lerp(main, 0.35)
    local a = 0.75 * fade
    local corners = {
        { Vector2.new(left + r, top + r), math.pi },
        { Vector2.new(right - r, top + r), math.pi * 1.5 },
        { Vector2.new(right - r, bottom - r), 0 },
        { Vector2.new(left + r, bottom - r), math.pi * 0.5 },
    }
    for _, corner in corners do
        local center: Vector2 = corner[1]
        canvas.filledCircle(center, r, tint, fill)
        local previous = nil
        for step = 0, ARC do
            local angle = corner[2] + (math.pi / 2) * step / ARC
            local point = center + Vector2.new(math.cos(angle), math.sin(angle)) * r
            if previous ~= nil then
                canvas.line(previous, point, edge, a, 1)
            end
            previous = point
        end
    end
    canvas.line(Vector2.new(left + r, top), Vector2.new(right - r, top), edge, a, 1)
    canvas.line(Vector2.new(left + r, bottom), Vector2.new(right - r, bottom), edge, a, 1)
    canvas.line(Vector2.new(left, top + r), Vector2.new(left, bottom - r), edge, a, 1)
    canvas.line(Vector2.new(right, top + r), Vector2.new(right, bottom - r), edge, a, 1)
end

function Hud.tag(canvas: any, center: Vector2, text: string, color: Color3?, fade: number, size: number?)
    local main, _, accent = Hud.theme()
    local font = size or 14
    local bounds = canvas.measure(text, font)
    local width, height = math.floor(bounds.X + 28), math.floor(bounds.Y + 12)
    local left, top = math.floor(center.X - width / 2), math.floor(center.Y - height / 2)
    frame(canvas, left, top, width, height, main, color or accent, fade)
    canvas.text(Vector2.new(left + 14, top + 6), font, color or accent, fade, text, false)
end

function Hud.banner(canvas: any, viewport: Vector2, text: string, color: Color3?, fade: number?)
    Hud.tag(canvas, Vector2.new(viewport.X / 2, 96), text, color, fade or 1, 16)
end

function Hud.height(spec: Spec): number
    local rows = if spec.rows ~= nil then #spec.rows else 0
    local height = 14 + 20 + (if spec.sub ~= nil then 18 else 4)
    if rows > 0 then
        height += 8 + 6 + 8 + rows * 20
    end
    if spec.total ~= nil then
        height += 1 + 8 + 18
    end
    return height + 12
end

function Hud.card(canvas: any, left: number, top: number, width: number, spec: Spec, fade: number)
    local main, text, accent, dim = Hud.theme()
    local height = Hud.height(spec)
    local inner, right = left + 16, left + width - 16
    local y = top
    frame(canvas, left, top, width, height, main, accent, fade)
    y += 14
    canvas.text(Vector2.new(inner, y), 16, accent, fade, spec.title, false)
    y += 20
    if spec.sub ~= nil then
        canvas.text(Vector2.new(inner, y), 13, dim, fade, spec.sub, false)
        y += 18
    else
        y += 4
    end
    local rows = spec.rows
    if rows ~= nil and #rows > 0 then
        y += 8
        local span = right - inner
        canvas.filledRect(Vector2.new(inner, y), Vector2.new(span, 6), text, 0.12 * fade)
        local at = inner
        local total = math.max(1, spec.dropped or 0)
        for _, row in rows do
            local part = math.floor(span * (row.amount or 0) / total + 0.5)
            if part > 0 and at + part <= right + 1 then
                canvas.filledRect(Vector2.new(at, y), Vector2.new(part, 6), row.color or accent, 0.95 * fade)
                at += part
            end
        end
        y += 6 + 8
        for _, row in rows do
            canvas.text(Vector2.new(inner, y), 14, dim, fade, row.label, false)
            local value = canvas.measure(row.value, 14)
            canvas.text(Vector2.new(right - value.X, y), 14, row.color or text, fade, row.value, false)
            y += 20
        end
    end
    if spec.total ~= nil then
        canvas.filledRect(Vector2.new(inner, y), Vector2.new(right - inner, 1), text, 0.14 * fade)
        y += 8
        canvas.text(Vector2.new(inner, y), 13, dim, fade, "All nodes", false)
        local value = canvas.measure(spec.total, 13)
        canvas.text(Vector2.new(right - value.X, y), 13, text, fade, spec.total, false)
    end
end

function Hud.beside(canvas: any, screen: Vector2, viewport: Vector2, width: number, spec: Spec, fade: number)
    local height = Hud.height(spec)
    local gap = 46
    local left = screen.X + gap
    if left + width > viewport.X - 8 then
        left = screen.X - gap - width
    end
    left = math.floor(math.clamp(left, 8, math.max(8, viewport.X - width - 8)))
    local top = math.floor(math.clamp(screen.Y - height / 2, 8, math.max(8, viewport.Y - height - 8)))
    local _, _, accent = Hud.theme()
    local edge = if left > screen.X then left else left + width
    canvas.line(screen, Vector2.new(edge, math.clamp(screen.Y, top + 8, top + height - 8)), accent, 0.55 * fade, 1)
    canvas.filledCircle(screen, 3, accent, 0.9 * fade)
    Hud.card(canvas, left, top, width, spec, fade)
end

return Hud
end
modules["goldfarm/link"] = function(...)

local Link = {}

local owners: { [any]: { [string]: any } } = setmetatable({}, { __mode = "k" }) :: any

function Link.set(context: any, name: string, object: any)
    local entry = owners[context]
    if entry == nil then
        entry = {}
        owners[context] = entry
    end
    entry[name] = object
end

function Link.get(context: any, name: string): any
    local entry = owners[context]
    return if entry then entry[name] else nil
end

return Link
end
modules["goldfarm/materials"] = function(...)

local import: (string) -> any = ...
local Loops: any = import("goldfarm/materials/loops")
local Bushes: any = import("goldfarm/materials/bushes")
local Drop: any = import("goldfarm/materials/drop")

local Part = {}
Part.__index = Part

Part.Defaults = {
    MatSunFarm = false,
    MatDropUntil = false,
    MatDropKeep = 500,
} :: { [string]: any }

local SUN_RANGE = 45
local EAT_BELOW = 67
local DELETE_RANGE = 35
local HARVEST_LIMIT = 12
local DROPS_PER_FRAME = 15
local DROP_PLAN_EVERY = 0.2
local EAT_COOLDOWN = 3
local SINK = CFrame.new(0, -500, 0)
local PLANT_RETRY = 1.5

function Part.new(context: any): any
    local Game = context.Game
    return setmetatable({
        Context = context,
        Game = Game,
        Loops = Loops.new(context),
        Bushes = Bushes.new(Game),
        Drop = Drop.new(Game),
        DropPlannedAt = 0,
        Deleting = {} :: { [any]: boolean },
        PlantedAt = {} :: { [number]: number },
        LastSunEat = 0,
    }, Part)
end

local function flag(self: any, name: string): any
    return self.Context.read(name)
end

local function number(self: any, name: string): number
    return tonumber(flag(self, name)) or Part.Defaults[name]
end

local function plant(self: any, fruit: string, range: number, label: string): number
    if not self.Loops:packet("InteractStructure", label) then
        return 0
    end
    local Game = self.Game
    local id = Game.inventory.itemId(fruit)
    if id == nil then
        self.Loops:warnOnce("item:" .. fruit, label .. ": item id of " .. fruit .. " not found")
        return 0
    end
    local planted = 0
    local now = os.clock()
    for box, at in self.PlantedAt do
        if now - at > PLANT_RETRY * 4 then
            self.PlantedAt[box] = nil
        end
    end
    for _, box in Game.finder.plantBoxes(range, true) do
        local last = self.PlantedAt[box.entityId]
        if (last == nil or now - last >= PLANT_RETRY) and Game.queue("InteractStructure", box.entityId, id) then
            self.PlantedAt[box.entityId] = now
            planted += 1
        end
    end
    return planted
end

local function harvest(self: any, fruit: string, range: number, label: string): number
    if not self.Loops:packet("Pickup", label) then
        return 0
    end
    return self.Bushes:harvest(fruit, range, HARVEST_LIMIT)
end

local function eat(self: any, fruit: string, label: string): boolean
    if not self.Loops:packet("UseBagItem", label) then
        return false
    end
    return self.Game.actions.eat(fruit)
end

local function ownsPart(part: any): boolean?
    local env: any = getgenv()
    local check = if env then env.isnetworkowner else nil
    if type(check) ~= "function" then
        return nil
    end
    local ok, result = pcall(check, part)
    return ok and result == true
end

local function deleteItem(self: any, item: any)
    local context = self.Context
    local Game = self.Game
    self.Deleting[item] = true
    context.spawn(function()
        for _ = 1, 20 do
            if not context.alive() or item.Parent == nil then
                break
            end
            Game.chests.grab(item)
            local part = Game.world.partOf(item)
            local owned = if part then ownsPart(part) else nil
            if owned == nil then
                self.Loops:warnOnce("isnetworkowner", "Drop Materials: this executor has no isnetworkowner")
            elseif owned then
                pcall(function()
                    item:PivotTo(SINK)
                end)
                break
            end
            if not context.wait(0.05) then
                return
            end
        end
        self.Deleting[item] = nil
    end)
end

local function addLoops(self: any)
    local loops = self.Loops
    local Game = self.Game

    loops:add("sunPlant", {
        active = function(): boolean
            return flag(self, "MatSunFarm") == true
        end,
        interval = 0.05,
        body = function()
            plant(self, "Sunfruit", SUN_RANGE, "Farm Sunfruit")
        end,
    })
    loops:add("sunHarvest", {
        active = function(): boolean
            return flag(self, "MatSunFarm") == true
        end,
        interval = 0.08,
        body = function()
            harvest(self, "Sunfruit", SUN_RANGE, "Farm Sunfruit")
        end,
    })
    loops:add("sunEat", {
        active = function(): boolean
            return flag(self, "MatSunFarm") == true
        end,
        interval = 0.2,
        body = function()
            local threshold = EAT_BELOW
            local health = Game.inventory.healthPercent() or 100
            local hunger = Game.inventory.hunger()
            if (health <= threshold or hunger <= threshold) and os.clock() - self.LastSunEat >= EAT_COOLDOWN then
                if eat(self, "Sunfruit", "Farm Sunfruit") then
                    self.LastSunEat = os.clock()
                end
            end
        end,
    })

    loops:add("drop", {
        active = function(): boolean
            return flag(self, "MatDropUntil") == true
        end,
        interval = 0,
        start = function()
            self.Drop:clear()
            self.DropPlannedAt = 0
        end,
        body = function()
            if not loops:packet("DropBagItem", "Drop Materials") then
                return
            end
            self.Drop:send(DROPS_PER_FRAME)
            if os.clock() - self.DropPlannedAt >= DROP_PLAN_EVERY then
                self.DropPlannedAt = os.clock()
                self.Drop:plan(number(self, "MatDropKeep"))
            end
        end,
        stop = function()
            self.Drop:clear()
        end,
    })
    loops:add("delete", {
        active = function(): boolean
            return flag(self, "MatDropUntil") == true
        end,
        interval = 0.1,
        body = function()
            if not loops:packet("ForceInteract", "Drop Materials") then
                return
            end
            for _, entry in Game.finder.items(DELETE_RANGE, Drop.NAMES) do
                if entry.entityId and not self.Deleting[entry.instance] then
                    deleteItem(self, entry.instance)
                end
            end
        end,
    })
end

function Part.build(self: any, _ui: any, tab: any)
    addLoops(self)
    local function kick()
        self.Loops:ensure()
    end
    local materials = tab:section("MATERIALS")
    materials:label({ Text = "Sunfruit", Size = 12, Height = 28, Offset = 4 })
    materials:toggle({
        Name = "Farm Sunfruit",
        Flag = "MatSunFarm",
        Default = false,
        Callback = kick,
        Info = {
            Title = "Farm Sunfruit",
            Lines = {
                "plants Sunfruit into every empty Plant Box within 45 studs",
                "and harvests every Sunfruit bush within 45 studs,",
                "up to 12 bushes per tick, each bush at most every 0.14 s",
                "eats a Sunfruit when health or hunger is at or below 67%,",
                "at most once every 3 seconds",
            },
            Width = 360,
        },
    })
    materials:label({ Text = "Drop Materials", Size = 12, Height = 28, Offset = 4 })
    materials:toggle({
        Name = "Drop Materials",
        Flag = "MatDropUntil",
        Default = false,
        Callback = kick,
        Info = {
            Title = "Drop Materials",
            Lines = {
                "drops Wood, Log, Leaves and Sunfruit",
                "until you hold Keep Amount of each, 15 drops per frame",
                "also grabs the dropped materials within 35 studs and",
                "sinks them under the map once you own them",
                "(needs isnetworkowner in the executor)",
            },
            Width = 340,
        },
    })
    materials:slider({ Name = "Keep Amount", Flag = "MatDropKeep", Min = 50, Max = 1000, Default = 500, Step = 10 })
end

function Part.step(self: any, _dt: number)
    self.Loops:ensure()
    if self.Bushes.Active then
        if flag(self, "MatSunFarm") ~= true then
            self.Bushes:stop()
        end
    end
end

function Part.shutdown(self: any)
    self.Loops:shutdown()
    self.Drop:clear()
    self.Bushes:stop()
    table.clear(self.Deleting)
    table.clear(self.PlantedAt)
end

return Part
end
modules["goldfarm/materials/bushes"] = function(...)

local Bushes = {}
Bushes.__index = Bushes

export type Bush = { instance: any, part: any, entityId: number, position: Vector3, distance: number }

local COOLDOWN = 0.14
local FRUITS: { [string]: string } = { Sunfruit = "sunfruit" }

function Bushes.new(Game: any)
    return setmetatable({
        Game = Game,
        Models = { Sunfruit = {} } :: { [string]: { [any]: boolean } },
        Cursor = { Sunfruit = 1 } :: { [string]: number },
        Sent = {} :: { [number]: number },
        Links = {} :: { any },
        Active = false,
    }, Bushes)
end

type Self = typeof(Bushes.new(nil))

local function modelOf(object: any): any
    local ok, model = pcall(function()
        if object:IsA("Model") then
            return object
        end
        return object:FindFirstAncestorOfClass("Model")
    end)
    return if ok then model else nil
end

local function fruitOf(self: Self, model: any): string?
    local World = self.Game.world
    local space = World.workspace()
    local current = model
    while current ~= nil and current ~= space do
        local name = World.normalize(current.Name)
        for fruit, key in FRUITS do
            if string.find(name, key, 1, true) then
                return fruit
            end
        end
        current = current.Parent
    end
    return nil
end

function Bushes.register(self: Self, object: any)
    local model = modelOf(object)
    if model == nil then
        return
    end
    local players = self.Game.world.folder("Players")
    if players ~= nil and model:IsDescendantOf(players) then
        return
    end
    local fruit = fruitOf(self, model)
    if fruit then
        self.Models[fruit][model] = true
    end
end

function Bushes.unregister(self: Self, object: any)
    local model = modelOf(object)
    if model == nil then
        return
    end
    for _, set in self.Models do
        set[model] = nil
    end
end

function Bushes.start(self: Self)
    if self.Active then
        return
    end
    local World = self.Game.world
    local space = World.folder("Crops") or World.workspace()
    if space == nil then
        return
    end
    self.Active = true
    for _, descendant in space:GetDescendants() do
        self:register(descendant)
    end
    table.insert(self.Links, space.DescendantAdded:Connect(function(object: any)
        self:register(object)
    end))
    table.insert(self.Links, space.DescendantRemoving:Connect(function(object: any)
        self:unregister(object)
    end))
end

function Bushes.stop(self: Self)
    for _, link in self.Links do
        pcall(function()
            link:Disconnect()
        end)
    end
    table.clear(self.Links)
    for _, set in self.Models do
        table.clear(set)
    end
    table.clear(self.Sent)
    self.Cursor.Sunfruit = 1
    self.Active = false
end

function Bushes.list(self: Self, fruit: string, range: number): { Bush }
    self:start()
    local World = self.Game.world
    local root = World.root()
    local set = self.Models[fruit]
    local found: { Bush } = {}
    if root == nil or set == nil then
        return found
    end
    local seen: { [number]: boolean } = {}
    for model in set do
        if model.Parent == nil then
            set[model] = nil
        else
            local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local distance = (part.Position - root.Position).Magnitude
                if distance <= range then
                    local id = World.entityId(model, nil, true)
                    if id and not seen[id] then
                        seen[id] = true
                        table.insert(found, { instance = model, part = part, entityId = id, position = part.Position, distance = distance })
                    end
                end
            end
        end
    end
    table.sort(found, function(a: Bush, b: Bush)
        return a.distance < b.distance
    end)
    return found
end

function Bushes.harvest(self: Self, fruit: string, range: number, limit: number): number
    local bushes = self:list(fruit, range)
    if #bushes == 0 then
        self.Cursor[fruit] = 1
        return 0
    end
    local now = os.clock()
    local cursor = self.Cursor[fruit] or 1
    local ids: { number } = {}
    for _ = 1, math.min(#bushes, limit) do
        if cursor > #bushes then
            cursor = 1
        end
        local id = bushes[cursor].entityId
        if now - (self.Sent[id] or 0) >= COOLDOWN then
            self.Sent[id] = now
            table.insert(ids, id)
        end
        cursor += 1
    end
    self.Cursor[fruit] = cursor
    for id, at in self.Sent do
        if now - at > 30 then
            self.Sent[id] = nil
        end
    end
    if #ids == 0 then
        return 0
    end
    return self.Game.actions.pickup(ids, true)
end

return Bushes
end
modules["goldfarm/materials/drop"] = function(...)

local Drop = {}
Drop.__index = Drop

Drop.NAMES = { "Leaves", "Leaf", "Log", "Wood", "Sunfruit", "Sun Fruit" }

local LOOKUP: { [string]: boolean } = {}
for _, name in Drop.NAMES do
    LOOKUP[name] = true
end

local SETTLE = 0.4

type Order = { layout: number, name: string }
type Sent = { name: string, at: number }

function Drop.new(Game: any)
    return setmetatable({
        Game = Game,
        Queue = {} :: { Order },
        Pending = {} :: { [string]: number },
        Sent = {} :: { Sent },
    }, Drop)
end

type Self = typeof(Drop.new(nil))

local function settling(self: Self, now: number): { [string]: number }
    local counts: { [string]: number } = {}
    local kept: { Sent } = {}
    for _, entry in self.Sent do
        if now - entry.at < SETTLE then
            counts[entry.name] = (counts[entry.name] or 0) + 1
            table.insert(kept, entry)
        end
    end
    self.Sent = kept
    return counts
end

function Drop.plan(self: Self, keep: number): number
    local counts: { [string]: number } = {}
    local stacks: { [string]: { { layout: number, quantity: number } } } = {}
    for _, slot in self.Game.inventory.items() do
        if LOOKUP[slot.name] then
            counts[slot.name] = (counts[slot.name] or 0) + slot.quantity
            stacks[slot.name] = stacks[slot.name] or {}
            table.insert(stacks[slot.name], { layout = slot.layout, quantity = slot.quantity })
        end
    end
    local inflight = settling(self, os.clock())
    local added = 0
    for name, count in counts do
        local excess = count - (self.Pending[name] or 0) - (inflight[name] or 0) - keep
        for _, stack in stacks[name] do
            if excess <= 0 then
                break
            end
            local amount = math.min(excess, stack.quantity)
            for _ = 1, amount do
                table.insert(self.Queue, { layout = stack.layout, name = name })
            end
            self.Pending[name] = (self.Pending[name] or 0) + amount
            excess -= amount
            added += amount
        end
    end
    return added
end

function Drop.send(self: Self, limit: number): number
    local sent = 0
    local now = os.clock()
    for _ = 1, limit do
        local order = table.remove(self.Queue, 1)
        if order == nil then
            break
        end
        if self.Game.queue("DropBagItem", order.layout) then
            sent += 1
            table.insert(self.Sent, { name = order.name, at = now })
        end
        self.Pending[order.name] = math.max(0, (self.Pending[order.name] or 0) - 1)
    end
    return sent
end

function Drop.clear(self: Self)
    table.clear(self.Queue)
    table.clear(self.Pending)
    table.clear(self.Sent)
end

return Drop
end
modules["goldfarm/materials/loops"] = function(...)

local Loops = {}
Loops.__index = Loops

export type Spec = {
    active: () -> boolean,
    interval: number | () -> number,
    body: () -> (),
    start: (() -> ())?,
    stop: (() -> ())?,
}

function Loops.new(context: any)
    return setmetatable({
        Context = context,
        Specs = {} :: { [string]: Spec },
        Order = {} :: { string },
        Running = {} :: { [string]: boolean },
        Warned = {} :: { [string]: boolean },
    }, Loops)
end

type Self = typeof(Loops.new(nil))

local function interval(spec: Spec): number
    local value = spec.interval
    if type(value) == "function" then
        return math.max(0, value())
    end
    return math.max(0, value :: number)
end

function Loops.add(self: Self, name: string, spec: Spec)
    self.Specs[name] = spec
    table.insert(self.Order, name)
end

function Loops.running(self: Self, name: string): boolean
    return self.Running[name] == true
end

function Loops.start(self: Self, name: string)
    local spec = self.Specs[name]
    if spec == nil or self.Running[name] or not self.Context.alive() then
        return
    end
    self.Running[name] = true
    table.clear(self.Warned)
    if spec.start then
        pcall(spec.start)
    end
    self.Context.spawn(function()
        while self.Running[name] and spec.active() do
            pcall(spec.body)
            if not self.Context.wait(interval(spec)) then
                return
            end
        end
        self.Running[name] = nil
        if spec.stop then
            pcall(spec.stop)
        end
    end)
end

function Loops.ensure(self: Self)
    for _, name in self.Order do
        local spec = self.Specs[name]
        if not self.Running[name] then
            local ok, on = pcall(spec.active)
            if ok and on then
                self:start(name)
            end
        end
    end
end

function Loops.warnOnce(self: Self, key: string, text: string)
    if self.Warned[key] then
        return
    end
    self.Warned[key] = true
    pcall(self.Context.notify, text)
end

function Loops.clearWarning(self: Self, key: string)
    self.Warned[key] = nil
end

function Loops.packet(self: Self, name: string, label: string): boolean
    local Game = self.Context.Game
    if Game.packets.has(name) then
        self:clearWarning("packet:" .. name)
        return true
    end
    if self.Warned["packet:" .. name] then
        return false
    end
    Game.packets.resolve()
    if Game.packets.has(name) then
        return true
    end
    self:warnOnce("packet:" .. name, label .. ": game packet " .. name .. " not found")
    return false
end

function Loops.shutdown(self: Self)
    for _, name in self.Order do
        if self.Running[name] then
            self.Running[name] = nil
            local spec = self.Specs[name]
            if spec.stop then
                pcall(spec.stop)
            end
        end
    end
end

return Loops
end
modules["goldfarm/patheditor"] = function(...)

local import: (string) -> any = ...
local Link: any = import("goldfarm/link")
local Panel: any = import("goldfarm/gold/panel")

local DEFAULT_HEIGHT = 450

local Part = {}
Part.__index = Part

Part.Defaults = {} :: { [string]: any }

function Part.new(context: any): any
    return setmetatable({ Context = context }, Part)
end

function Part.build(self: any, _ui: any, tab: any)
    local gold = Link.get(self.Context, "gold")
    if gold == nil then
        return
    end
    local page = tab:section("PATH EDITOR")
    local height = { Value = Panel.PAGE_HEIGHT }
    page:custom({
        Height = height,
        Render = function(kit: any, window: any)
            height.Value = math.max(Panel.PAGE_HEIGHT, math.floor(window.M.Height - DEFAULT_HEIGHT + Panel.PAGE_HEIGHT))
            gold.Editor.Panel:render(kit, window)
        end,
    })
end

return Part
end
modules["goldfarm/performance"] = function(...)

local Performance = {}
Performance.__index = Performance

local CAP = 25
local CHUNK = 250
local BUDGET = 120

type Record = { [string]: any }

function Performance.new(context: any): any
    return setmetatable({
        Context = context,
        Game = context.Game,
        CapSaved = false,
        PrevCap = nil :: number?,
        Light = nil :: Record?,
        Heavy = false,
        Epoch = 0,
        Decals = (setmetatable({}, { __mode = "k" }) :: any) :: { [any]: number },
        Queue = {} :: { any },
        Grass = nil :: Record?,
        On = false,
        Dark = false,
        Link = nil :: any,
        Warned = false,
    }, Performance)
end

function Performance.setCap(self: any, value: number?)
    local globals: any = getgenv()
    local set = if globals then globals.setfpscap else nil
    if type(set) ~= "function" then
        if value ~= nil and not self.Warned then
            self.Warned = true
            self.Context.notify("This executor has no FPS cap function")
        end
        return
    end
    if value ~= nil then
        if not self.CapSaved then
            local get = globals.getfpscap
            if type(get) == "function" then
                local ok, current = pcall(get)
                if ok and type(current) == "number" then
                    self.PrevCap = current
                end
            end
            self.CapSaved = true
        end
        pcall(set, value)
    elseif self.CapSaved then
        pcall(set, self.PrevCap or 0)
        self.CapSaved = false
        self.PrevCap = nil
    end
end

function Performance.lighten(self: any)
    if self.Light ~= nil then
        return
    end
    local lighting: any = self.Game.modules.service("Lighting")
    local space = self.Game.world.workspace()
    local terrain: any = if space then space:FindFirstChildOfClass("Terrain") else nil
    local saved: Record = { Effects = {} :: { [any]: boolean } }
    pcall(function()
        if lighting then
            saved.Shadows = lighting.GlobalShadows
            saved.Fog = lighting.FogEnd
            lighting.GlobalShadows = false
            lighting.FogEnd = 9e9
            for _, child in lighting:GetChildren() do
                if child:IsA("PostEffect") then
                    saved.Effects[child] = child.Enabled
                    child.Enabled = false
                end
            end
        end
        if terrain then
            saved.Terrain = terrain
            saved.WaveSize = terrain.WaterWaveSize
            saved.WaveSpeed = terrain.WaterWaveSpeed
            saved.Reflectance = terrain.WaterReflectance
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
        end
    end)
    self.Light = saved
end

function Performance.restoreLight(self: any)
    local saved = self.Light
    if saved == nil then
        return
    end
    self.Light = nil
    local lighting: any = self.Game.modules.service("Lighting")
    pcall(function()
        if lighting and saved.Shadows ~= nil then
            lighting.GlobalShadows = saved.Shadows
            lighting.FogEnd = saved.Fog
        end
        for effect, enabled in saved.Effects do
            if effect.Parent then
                effect.Enabled = enabled
            end
        end
        local terrain = saved.Terrain
        if terrain and terrain.Parent then
            terrain.WaterWaveSize = saved.WaveSize
            terrain.WaterWaveSpeed = saved.WaveSpeed
            terrain.WaterReflectance = saved.Reflectance
        end
    end)
end

function Performance.owned(self: any, instance: any): boolean
    local players: any = self.Game.modules.service("Players")
    local player: any = if players then players.LocalPlayer else nil
    local character: any = if player then player.Character else nil
    return character ~= nil and instance:IsDescendantOf(character)
end

local function lowerOne(self: any, instance: any)
    if not (instance:IsA("Decal") or instance:IsA("Texture")) then
        return
    end
    if self.Decals[instance] == nil then
        if self:owned(instance) then
            return
        end
        self.Decals[instance] = instance.Transparency
    end
    instance.Transparency = 1
end

function Performance.lower(self: any, instance: any)
    pcall(lowerOne, self, instance)
end

function Performance.drain(self: any)
    local queue = self.Queue
    for _ = 1, BUDGET do
        local instance = table.remove(queue)
        if instance == nil then
            return
        end
        self:lower(instance)
    end
end

function Performance.flatten(self: any)
    if self.Heavy then
        return
    end
    self.Heavy = true
    self.Epoch += 1
    local epoch = self.Epoch
    local space = self.Game.world.workspace()
    if space == nil then
        return
    end
    self.Link = self.Context.connect(space.DescendantAdded, function(instance: any)
        if instance:IsA("Decal") or instance:IsA("Texture") then
            table.insert(self.Queue, instance)
        end
    end)
    self.Context.spawn(function()
        for index, instance in space:GetDescendants() do
            if self.Epoch ~= epoch then
                return
            end
            self:lower(instance)
            if index % CHUNK == 0 and not self.Context.wait(0) then
                return
            end
        end
    end)
end

function Performance.restoreHeavy(self: any)
    if not self.Heavy then
        return
    end
    self.Heavy = false
    self.Epoch += 1
    if self.Link then
        pcall(function()
            self.Link:Disconnect()
        end)
        self.Link = nil
    end
    table.clear(self.Queue)
    for instance, transparency in self.Decals do
        if instance.Parent ~= nil then
            pcall(function()
                instance.Transparency = transparency
            end)
        end
    end
    table.clear(self.Decals)
end

function Performance.writeGrass(self: any, terrain: any, value: boolean)
    if pcall(function()
        terrain.Decoration = value
    end) then
        return
    end
    local globals: any = getgenv()
    local hidden = if globals then globals.sethiddenproperty else nil
    if type(hidden) == "function" then
        pcall(hidden, terrain, "Decoration", value)
    end
end

local function decorationOf(terrain: any): any
    return terrain.Decoration
end

function Performance.readGrass(self: any, terrain: any): boolean
    local ok, value = pcall(decorationOf, terrain)
    if ok and type(value) == "boolean" then
        return value
    end
    local globals: any = getgenv()
    local hidden = if globals then globals.gethiddenproperty else nil
    if type(hidden) == "function" then
        local read, result = pcall(hidden, terrain, "Decoration")
        if read and type(result) == "boolean" then
            return result
        end
    end
    return true
end

function Performance.hideGrass(self: any)
    local space = self.Game.world.workspace()
    local terrain: any = if space then space:FindFirstChildOfClass("Terrain") else nil
    if terrain == nil then
        return
    end
    local saved = self.Grass
    if saved ~= nil and saved.Terrain ~= terrain then
        self:showGrass()
        saved = nil
    end
    if saved == nil then
        saved = { Terrain = terrain, Original = self:readGrass(terrain) }
        self.Grass = saved
    end
    if self:readGrass(terrain) then
        self:writeGrass(terrain, false)
    end
end

function Performance.showGrass(self: any)
    local saved = self.Grass
    if saved == nil then
        return
    end
    self.Grass = nil
    local terrain = saved.Terrain
    if terrain.Parent ~= nil then
        self:writeGrass(terrain, saved.Original)
    end
end

function Performance.setRendering(self: any, enabled: boolean)
    local run: any = self.Game.modules.service("RunService")
    if run ~= nil then
        self.Dark = not enabled
        pcall(function()
            run:Set3dRenderingEnabled(enabled)
        end)
    end
end

function Performance.listen(self: any)
    local input: any = self.Game.modules.service("UserInputService")
    if input == nil then
        return
    end
    self.Context.connect(input.WindowFocusReleased, function()
        if self.Context.read("GoldCpuMode") == true then
            self:setRendering(false)
        end
    end)
    self.Context.connect(input.WindowFocused, function()
        self:setRendering(true)
    end)
    self.Context.connect(input.InputBegan, function(event: any)
        local kind = event.UserInputType
        local click = kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2
        if click and self.Dark and os.clock() - self.Game.actions.syntheticAt > 0.8 then
            self:setRendering(true)
        end
    end)
end

function Performance.sync(self: any)
    local cpu = self.Context.read("GoldCpuMode") == true
    if cpu then
        if not self.On then
            self.On = true
            self:setCap(CAP)
            self:lighten()
            self:flatten()
        end
        self:hideGrass()
        self:drain()
    elseif self.On then
        self.On = false
        self:setCap(nil)
        self:restoreLight()
        self:restoreHeavy()
        self:showGrass()
        self:setRendering(true)
    end
end

function Performance.shutdown(self: any)
    self.On = false
    self:restoreHeavy()
    self:restoreLight()
    self:showGrass()
    self:setCap(nil)
    self:setRendering(true)
end

return Performance
end
modules["goldfarm/placements"] = function(...)

local import: (string) -> any = ...
local Hud: any = import("goldfarm/hud")
local Place: any = import("goldfarm/placements/place")
local Store: any = import("goldfarm/placements/store")
local Spot: any = import("goldfarm/placements/spot")

local DEFAULT = {
    Section = "PLACEMENTS",
    Report = "placements",
    Rows = nil :: { { any } }?,
    Buttons = {
        {
            Name = "Place Plants",
            Kinds = { "plant" },
            Label = "plant boxes",
            Lines = {
                "Shows a dot where the first plant box goes. Walk to it",
                "(within 3 studs), then every spot is drawn and the script",
                "walks to each one and places the plant box 1:1. You need",
                "Plant Boxes in your bag, it places as many as you have.",
                "Turn Start Path off first. Spots that are done are skipped,",
                "so you can press it again after crafting more.",
            },
        },
        {
            Name = "Place Others",
            Kinds = { "campfire", "press", "chest" },
            Label = "campfires, coin press and chest",
            Lines = {
                "Same as Place Plants for the campfires, the coin press and",
                "the chest of the gold farm base. You need them in your bag.",
                "Beds you place yourself. Turn Start Path off first.",
            },
        },
    },
}

local function define(config: any): any
    local Part = {}
    Part.__index = Part

    Part.Defaults = {} :: { [string]: any }

    local PENDING = Color3.fromRGB(235, 235, 240)
    local GOOD = Color3.fromRGB(110, 220, 130)
    local BAD = Color3.fromRGB(235, 70, 70)
    local SKIPPED = Color3.fromRGB(140, 140, 146)
    local FOCUS = Color3.fromRGB(255, 205, 70)
    local RING = 3
    local HALF = 1.6
    local TRACE_COLOR = Color3.fromRGB(90, 200, 255)
    local TRACE_EVERY = 0.12
    local TRACE_STEP = 3
    local TRACE_MAX = 80
    local TRACE_LIFT = 0.5
    local TRACE_SKY = 120
    local TRACE_DEPTH = 600

    local function follow()
        local palette = Hud.palette()
        PENDING = palette.dot
        GOOD = palette.good
        BAD = palette.bad
        SKIPPED = palette.dim
        FOCUS = palette.warn
        TRACE_COLOR = palette.line
    end

    function Part.new(context: any): any
        local store = Store.new(context, config.Rows)
        local self = setmetatable({
            Context = context,
            Game = context.Game,
            Store = store,
            Place = nil :: any,
            Running = nil :: string?,
            Viewing = nil :: string?,
            Spot = Spot.new(context),
            Trace = nil :: any,
            TraceAt = -10,
            TraceTo = nil :: Vector3?,
        }, Part)
        self.Place = Place.new(context, store, config.Report)
        context.Game.addReport(function(): { string }
            return self.Place:report()
        end)
        self.Place.Status = (if store.FromFile then "Test scan file: " else "Ready: ") .. store:summary()
        return self
    end

    function Part.status(self: any): string
        if #self.Store.Entries == 0 then
            return "No structures are built in yet"
        end
        return self.Place.Status
    end

    function Part.build(self: any, _ui: any, tab: any)
        local placements = tab:section(config.Section)
        for _, button in config.Buttons do
            local noun = string.gsub(button.Name, "^Place ", "")
            placements:button({
                Name = button.Name,
                Align = "center",
                Label = function(): string
                    if self.Place:active() and self.Running == button.Name then
                        return "Stop Placing " .. noun
                    end
                    return button.Name
                end,
                Active = function(): boolean
                    return self.Place:active() and self.Running == button.Name
                end,
                Disabled = function(): boolean
                    return self.Place:active() and self.Running ~= button.Name
                end,
                Callback = function()
                    if self.Place:active() then
                        if self.Running == button.Name then
                            self.Place:stop()
                        end
                        return
                    end
                    self.Spot:stop()
                    self.Running = button.Name
                    self.Place:start(button.Kinds, button.Label)
                end,
                Info = { Title = button.Name, Lines = button.Lines, Width = 400 },
            })
        end
        for _, button in config.Buttons do
            local noun = string.gsub(button.Name, "^Place ", "")
            local name = "View " .. noun
            placements:button({
                Name = name,
                Align = "center",
                Label = function(): string
                    if self.Spot:active() and self.Viewing == name then
                        return "Stop Viewing " .. noun
                    end
                    return name
                end,
                Active = function(): boolean
                    return self.Spot:active() and self.Viewing == name
                end,
                Disabled = function(): boolean
                    return self.Place:active()
                end,
                Callback = function()
                    if self.Spot:active() and self.Viewing == name then
                        self.Spot:stop()
                        return
                    end
                    local entries: { any } = {}
                    for _, entry in self.Store.Entries do
                        if table.find(button.Kinds, entry.kind) then
                            table.insert(entries, entry)
                        end
                    end
                    if self.Spot:start(entries, button.Label) then
                        self.Viewing = name
                    end
                end,
                Info = {
                    Title = name,
                    Lines = {
                        "Puts your camera at the dot where " .. button.Label .. " go,",
                        "like a freecam, so you can look around the spot before",
                        "walking there. Hold right mouse to look, WASD to fly,",
                        "Q and E for down and up, Shift for faster. Your character",
                        "stays where it is. Press the same button again to come back.",
                    },
                    Width = 400,
                },
            })
        end
        placements:label({
            Center = true,
            Accent = true,
            Label = function(): string
                return self:status()
            end,
        })
    end

    function Part.step(self: any, dt: number)
        self.Place:tick()
        self.Spot:step(dt)
    end

    local function onScreen(screen: any, depth: number, size: Vector2): boolean
        return screen ~= nil and depth > 0.1 and screen.X > -40 and screen.Y > -40 and screen.X < size.X + 40 and screen.Y < size.Y + 40
    end

    function Part.params(self: any): any
        local World = self.Game.world
        local ignore: { any } = {}
        local character = World.character()
        if character ~= nil then
            table.insert(ignore, character)
        end
        local players = World.folder("Players")
        if players ~= nil then
            table.insert(ignore, players)
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignore
        params.IgnoreWater = true
        return params
    end

    function Part.cast(self: any, origin: Vector3, direction: Vector3, params: any): any
        local space = self.Game.world.workspace()
        if space == nil then
            return nil
        end
        local ok, result = pcall(function()
            return space:Raycast(origin, direction, params)
        end)
        return if ok then result else nil
    end

    function Part.trace(self: any, target: Vector3): any
        local now = os.clock()
        local from = self.Game.world.position()
        if from == nil then
            return nil
        end
        local cached = self.Trace
        if cached ~= nil and self.TraceTo == target and now - self.TraceAt < TRACE_EVERY then
            return cached
        end
        self.TraceAt = now
        self.TraceTo = target
        local params = self:params()
        local delta = target - from
        local count = math.clamp(math.ceil(delta.Magnitude / TRACE_STEP), 2, TRACE_MAX)
        local top = math.max(from.Y, target.Y) + TRACE_SKY
        local ground: { Vector3 } = {}
        for step = 0, count do
            local point = from + delta * (step / count)
            local hit = self:cast(Vector3.new(point.X, top, point.Z), Vector3.new(0, -TRACE_DEPTH, 0), params)
            local height = if hit ~= nil and hit.Position ~= nil then hit.Position.Y + TRACE_LIFT else point.Y
            table.insert(ground, Vector3.new(point.X, height, point.Z))
        end
        local blocked: Vector3? = nil
        local block = self:cast(from, delta, params)
        if block ~= nil and block.Position ~= nil and (block.Position - target).Magnitude > 2 then
            blocked = block.Position
        end
        cached = { from = from, target = target, ground = ground, blocked = blocked, length = delta.Magnitude }
        self.Trace = cached
        return cached
    end

    function Part.drawTrace(self: any, canvas: any, target: Vector3, size: Vector2)
        local trace = self:trace(target)
        if trace == nil then
            return
        end
        canvas.worldPath(trace.ground, TRACE_COLOR, 0.9, 2)
        local blocked = trace.blocked
        if blocked ~= nil then
            canvas.worldPath({ trace.from, blocked }, FOCUS, 0.8, 1.5)
            canvas.worldPath({ blocked, trace.target }, BAD, 0.55, 1.5)
            local screen, depth = canvas.project(blocked)
            if onScreen(screen, depth, size) then
                canvas.filledCircle(screen, 4, BAD, 0.95)
                canvas.circle(screen, 8, BAD, 0.8, 1.5)
            end
        end
        local middle = trace.ground[math.ceil(#trace.ground / 2)]
        local screen, depth = canvas.project(middle + Vector3.new(0, 1.2, 0))
        if onScreen(screen, depth, size) then
            Hud.tag(canvas, Vector2.new(screen.X, screen.Y - 16), string.format("%d studs%s", math.floor(trace.length + 0.5), if blocked ~= nil then ", terrain in the way" else ""), if blocked ~= nil then BAD else nil, 1, 13)
        end
    end

    function Part.guide(self: any, canvas: any, view: any, size: Vector2)
        local now = os.clock()
        local distance = math.floor(view.distance + 0.5)
        Hud.banner(canvas, size, string.format("Walk to the dot to start placing %s (%d studs)", view.label, distance), nil, 1)
        local ring: { Vector3 } = {}
        for step = 0, 16 do
            local angle = step / 16 * math.pi * 2
            table.insert(ring, view.start + Vector3.new(math.cos(angle) * RING, 0.3, math.sin(angle) * RING))
        end
        canvas.worldPath(ring, FOCUS, 0.9, 2)
        self:drawTrace(canvas, view.start, size)
        local screen, depth = canvas.project(view.start + Vector3.new(0, 1.5, 0))
        if onScreen(screen, depth, size) then
            local pulse = 0.5 + 0.5 * math.sin(now * 4)
            canvas.filledCircle(screen, 8, FOCUS, 0.95)
            canvas.circle(screen, 13 + pulse * 6, FOCUS, 0.8, 2)
            Hud.tag(canvas, Vector2.new(screen.X, screen.Y - 38), "Start here", nil, 1, 13)
        end
    end

    function Part.run(self: any, canvas: any, view: any, size: Vector2)
        Hud.banner(canvas, size, self.Place.Status .. ": " .. view.label, nil, 1)
        if view.current ~= nil then
            local c = view.current.c
            self:drawTrace(canvas, Vector3.new(c[1], c[2], c[3]), size)
        end
        for entry, state in view.state do
            local c = entry.c
            local position = Vector3.new(c[1], c[2], c[3])
            local screen, depth = canvas.project(position + Vector3.new(0, 0.6, 0))
            if onScreen(screen, depth, size) then
                local color = if state == "placed" then GOOD elseif state == "failed" then BAD elseif state == "skipped" then SKIPPED else PENDING
                local look = Vector3.new(-c[6], 0, -c[12])
                if look.Magnitude > 0.01 then
                    local direction = look.Unit * HALF
                    canvas.worldPath({ position - direction + Vector3.new(0, 0.6, 0), position + direction + Vector3.new(0, 0.6, 0) }, color, 0.85, 2)
                end
                canvas.filledCircle(screen, if entry == view.current then 6 else 3.5, color, 0.95)
                if entry == view.current then
                    canvas.circle(screen, 11, FOCUS, 0.95, 2)
                end
            end
        end
    end

    function Part.frame(self: any, canvas: any)
        follow()
        local place = self.Place
        local view = place.View
        local camera = workspace.CurrentCamera
        if camera == nil then
            return
        end
        local size = camera.ViewportSize
        self.Spot:frame(canvas, size, FOCUS)
        if view == nil then
            return
        end
        if place.Phase == "guide" then
            self:guide(canvas, view, size)
        elseif place.Phase == "run" then
            self:run(canvas, view, size)
        end
    end

    function Part.shutdown(self: any)
        self.Spot:stop()
        self.Place.Cancel = true
        self.Place.Phase = nil
        self.Place.View = nil
    end


    return Part
end

local Default = define(DEFAULT)
Default.define = define
Default.DEFAULT = DEFAULT

return Default
end
modules["goldfarm/placements/blueprint"] = function(...)

return {
    { "campfire", "Campfire", -48.483, -38.709, -115.391, -0.186, 0, 0.983, 0.002, 1, 0, -0.983, 0.002, -0.186 },
    { "chest", "Chest", -52.906, -38.719, -121.904, -0.719, -0.001, -0.695, -0.002, 1, 0.001, 0.695, 0.002, -0.719 },
    { "campfire", "Campfire", -47.701, -38.603, -125.974, -0.186, 0, 0.983, 0.002, 1, 0, -0.983, 0.002, -0.186 },
    { "press", "Coin Press", -62.541, -38.718, -111.513, 0.696, 0, -0.718, 0, 1, 0, 0.718, 0, 0.696 },
    { "campfire", "Campfire", -58.238, -38.508, -127.052, -0.186, 0, 0.983, 0.002, 1, 0, -0.983, 0.002, -0.186 },
    { "campfire", "Campfire", -43.293, -38.719, -120.618, -0.186, 0, 0.983, 0.002, 1, 0, -0.983, 0.002, -0.186 },
    { "campfire", "Campfire", -52.481, -38.188, -131.228, -0.186, 0, 0.983, 0.002, 1, 0, -0.983, 0.002, -0.186 },
    { "plant", "Plant Box", 7.132, -7.049, -111.218, 0.853, 0, -0.522, 0, 1, 0, 0.522, 0, 0.853 },
    { "plant", "Plant Box", 13.319, -7.028, -107.702, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 18.11, -7.129, -105.169, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 25.318, -7.025, -101.141, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 30.003, -6.874, -98.347, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 34.463, -6.905, -95.87, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 38.979, -6.407, -93.192, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 43.341, -6.122, -90.651, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 48.752, -6, -87.484, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 53.421, -6, -84.526, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 58.721, -6, -81.432, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 63.097, -6, -78.736, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 68.335, -6, -75.632, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 74.346, -6, -72.355, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 79.353, -6, -69.261, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 84.28, -6, -66.388, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 89.537, -6, -63.501, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 93.262, -6, -69.415, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 88.433, -6, -72.087, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 83.979, -6, -74.474, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 79.206, -6, -77.117, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 74.022, -6, -79.975, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 68.658, -6, -82.948, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 62.823, -6, -86.179, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 57.943, -6, -88.916, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 53.192, -6, -91.653, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 48, -6, -94.603, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 43.252, -6, -97.305, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 38.862, -6.032, -99.789, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 34.046, -6.189, -102.487, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 29.015, -6.298, -105.497, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 23.679, -6.506, -108.643, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 19.313, -6.839, -111.192, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 14.434, -7.202, -114.112, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 9.949, -7.03, -116.696, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 4.25, -7.35, -120.099, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 0.916, -7.057, -114.496, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", -5.108, -7.378, -115.615, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", -2.036, -7.461, -122.032, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", -10.897, -7.612, -116.501, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", -8.848, -7.642, -121.88, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", -17.126, -7.767, -116.844, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", -14.958, -7.522, -122.14, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", -23.291, -7.362, -118.62, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", -21.444, -7.701, -124.241, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", -27.356, -7.616, -126.697, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 99.436, -6, -65.986, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 96.111, -6, -60.437, 0.862, 0, -0.507, 0, 1, 0, 0.507, 0, 0.862 },
    { "plant", "Plant Box", 144.15, -6, -22.076, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 140.186, -6, -17.08, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 148.798, -6.007, -18.511, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 154.135, -6.115, -14.543, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 158.541, -6.296, -11.265, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 163.899, -6.486, -7.278, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 168.345, -6.083, -3.508, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 172.96, -6.012, -0.08, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 177.904, -6, 3.598, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 182.83, -6, 7.264, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 186.882, -6, 10.281, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 192.182, -6, 14.423, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 196.988, -6, 18.199, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 202.753, -6, 22.589, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 208.011, -6, 26.652, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 212.541, -6, 30.262, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 217.414, -6, 34.006, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 223.253, -6, 38.582, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 228.131, -6, 42.433, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 232.116, -6, 45.589, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 236.527, -6, 49.077, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 241.692, -6, 53.147, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 245.994, -6, 56.542, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 250.381, -6, 59.985, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 254.381, -6, 63.117, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 258.715, -6, 66.605, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 263.703, -6, 70.797, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 267.855, -6.83, 74.322, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 273.227, -7.827, 79.08, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 269.963, -7.713, 84.465, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 265.512, -7.177, 80.295, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 260.313, -6.062, 76.803, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 255.384, -6, 73.245, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 250.116, -6, 69.251, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 244.386, -6, 64.9, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 239.924, -6, 61.527, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 234.581, -6, 57.502, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 229.738, -6, 53.849, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 224.511, -6, 49.84, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 220.21, -6, 46.398, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 214.977, -6, 42.254, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 210.678, -6, 38.872, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 206.252, -6, 35.422, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 201.084, -6, 31.399, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 196.278, -6, 27.68, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 191.01, -6, 23.593, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 186.696, -6, 20.157, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 181.431, -6, 15.958, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 177.065, -6, 12.527, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 172.779, -6, 9.153, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 168.79, -6.008, 6.02, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 164.5, -6.002, 2.65, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 160.183, -6.031, -0.744, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 156.254, -6.186, -3.837, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 151.088, -6.366, -7.896, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
    { "plant", "Plant Box", 145.687, -6.163, -12.111, 0.792, 0, -0.611, 0, 1, 0, 0.611, 0, 0.792 },
} :: { { any } }
end
modules["goldfarm/placements/place"] = function(...)

local import: (string) -> any = ...
local Shape: any = import("game/shape")
local Store: any = import("goldfarm/placements/store")

local Place = {}
Place.__index = Place

local SPEED = 19
local START_RADIUS = 3
local START_HEIGHT = 10
local NEAR = 5
local CLOSE = 2.5
local CHECK_EVERY = 0.1
local CHECK_FOR = 1.6
local PACE = 0.08
local MATCH = 3
local LOG = "placements log.txt"
local LOG_LINES = 200

function Place.new(context: any, store: any, name: string?): any
    return setmetatable({
        Context = context,
        Game = context.Game,
        Store = store,
        Name = name or "placements",
        Phase = nil :: string?,
        View = nil :: any,
        Cancel = false,
        Status = "Placements idle",
        Placed = 0,
        Failed = 0,
        Skipped = 0,
        Strategy = nil :: string?,
        Told = {} :: { [string]: boolean },
        Lacking = {} :: { [string]: boolean },
        Probed = {} :: { [string]: boolean },
        NoBag = {} :: { [string]: boolean },
    }, Place)
end

function Place.active(self: any): boolean
    return self.Phase ~= nil
end

function Place.log(self: any, text: string)
    pcall(function()
        local path = self.Context.Folder .. "/" .. LOG
        local lines: { string } = {}
        if isfile(path) then
            for line in string.gmatch(readfile(path), "[^\n]+") do
                table.insert(lines, line)
            end
        end
        table.insert(lines, os.date("%H:%M:%S") .. "  " .. text)
        while #lines > LOG_LINES do
            table.remove(lines, 1)
        end
        writefile(path, table.concat(lines, "\n") .. "\n")
    end)
end

function Place.report(self: any): { string }
    local lines: { string } = {}
    local counts: { [string]: number } = {}
    local filled: { [string]: number } = {}
    local first: any = nil
    for _, entry in self.Store.Entries do
        counts[entry.kind] = (counts[entry.kind] or 0) + 1
        if self:found(entry) ~= nil then
            filled[entry.kind] = (filled[entry.kind] or 0) + 1
        elseif first == nil then
            first = entry
        end
    end
    local parts: { string } = {}
    for _, kind in Store.KINDS do
        if counts[kind] then
            table.insert(parts, string.format("%s %d of %d", Store.LABELS[kind], filled[kind] or 0, counts[kind]))
        end
    end
    table.insert(lines, self.Name .. ": " .. (if self.Store.FromFile then "scan file" else "built-in") .. ", already in the world: " .. (if #parts > 0 then table.concat(parts, ", ") else "nothing saved"))
    if first ~= nil then
        local position = Store.position(first)
        local folder = self.Game.world.folder("Deployables")
        local nearest, nearestAt = math.huge, nil :: Vector3?
        if folder ~= nil then
            for _, model in folder:GetChildren() do
                if model.Name == first.name and model:IsA("Model") then
                    local ok, at = pcall(function(): Vector3
                        return model:GetPivot().Position
                    end)
                    if ok and (at - position).Magnitude < nearest then
                        nearest, nearestAt = (at - position).Magnitude, at
                    end
                end
            end
        end
        table.insert(lines, string.format("first spot not filled: %s at %.1f, %.1f, %.1f; nearest %s in the world: %s", first.name, position.X, position.Y, position.Z, first.name, if nearestAt then string.format("%.1f studs away at %.1f, %.1f, %.1f", nearest, nearestAt.X, nearestAt.Y, nearestAt.Z) else "none"))
    end
    table.insert(lines, "bag count of Plant Box as the script reads it: " .. tostring(self.Game.inventory.count("Plant Box")))
    return lines
end

function Place.stopped(self: any): boolean
    return self.Cancel or not self.Context.alive()
end

function Place.stop(self: any)
    if self.Phase == "guide" then
        self.Phase = nil
        self.View = nil
        self.Status = "Cancelled"
        return
    end
    self.Cancel = true
end

function Place.found(self: any, entry: any): any
    local folder = self.Game.world.folder("Deployables")
    if folder == nil then
        return nil
    end
    local wanted = Store.position(entry)
    for _, model in folder:GetChildren() do
        if model.Name == entry.name and model:IsA("Model") then
            local ok, distance = pcall(function(): number
                return (model:GetPivot().Position - wanted).Magnitude
            end)
            if ok and distance <= MATCH then
                return model
            end
        end
    end
    return nil
end

function Place.targets(self: any, kinds: { string }?): { any }
    local list: { any } = {}
    for _, entry in self.Store.Entries do
        if kinds == nil or table.find(kinds, entry.kind) then
            if self:found(entry) == nil then
                table.insert(list, entry)
            end
        end
    end
    return list
end

function Place.sendModule(self: any, entry: any): boolean
    local packets = self.Game.packets
    local object = packets.object("PlaceStructure")
    if type(object) ~= "table" or type(object.send) ~= "function" then
        return false
    end
    local frame = Store.frame(entry)
    if self.Game.template.send("PlaceStructure", object, { entry.name, frame }, packets.stamp()) then
        return true
    end
    local payload = Shape.placement(object, entry.name, frame)
    if payload == nil then
        if not self.Told.shape then
            self.Told.shape = true
            self:log("module send skipped: no field names found in the PlaceStructure packet")
        end
        return false
    end
    return (pcall(object.send, payload))
end

function Place.sendRaw(self: any, entry: any): boolean
    local packets = self.Game.packets
    local spec = packets.DEFINITIONS.PlaceStructure
    if spec == nil or spec.verified ~= true then
        if not self.Told.raw then
            self.Told.raw = true
            self:log("raw send skipped: the PlaceStructure byte layout is not verified for this game version")
        end
        return false
    end
    local data = packets.build("PlaceStructure", entry.name, Store.frame(entry))
    if data == nil then
        return false
    end
    return packets.fire(data)
end

function Place.verify(self: any, entry: any): boolean
    local waited = 0
    while waited < CHECK_FOR do
        if self:found(entry) ~= nil then
            return true
        end
        if not self.Context.wait(CHECK_EVERY) or self.Cancel then
            return false
        end
        waited += CHECK_EVERY
    end
    return self:found(entry) ~= nil
end

function Place.attempt(self: any, entry: any): boolean
    local order = { "module", "raw" }
    if self.Strategy == "raw" then
        order = { "raw", "module" }
    end
    for _, strategy in order do
        local sent = if strategy == "module" then self:sendModule(entry) else self:sendRaw(entry)
        if sent and self:verify(entry) then
            if self.Strategy ~= strategy then
                self.Strategy = strategy
                self:log("placing works through the " .. strategy .. " send")
            end
            return true
        end
        if self:stopped() then
            return false
        end
    end
    return false
end

function Place.travel(self: any, target: Vector3, tolerance: number): boolean
    local Game = self.Game
    local start = Game.world.position()
    local limit = os.clock() + 15 + (if start then (start - target).Magnitude / 8 else 0)
    while not self:stopped() do
        local root = Game.world.root()
        if root == nil or not Game.world.isSpawned() then
            Game.drive.halt()
            if not self.Context.wait(0.2) then
                return false
            end
        else
            local goal = Vector3.new(target.X, target.Y + Game.drive.hover, target.Z)
            if (root.Position - goal).Magnitude <= tolerance then
                Game.drive.halt()
                return true
            end
            Game.drive.step(goal, SPEED)
            if not self.Context.wait(0.05) then
                return false
            end
        end
        if os.clock() > limit then
            Game.drive.halt()
            return false
        end
    end
    return false
end

function Place.bag(self: any, name: string): boolean
    local inventory = self.Game.inventory
    if not inventory.ready() then
        return true
    end
    return inventory.count(name) >= 1
end

function Place.mark(self: any, entry: any, state: string)
    local view = self.View
    if view ~= nil then
        view.state[entry] = state
    end
end

function Place.walk(self: any, entries: { any })
    local Game = self.Game
    local total = #entries
    local lacking: { [string]: boolean } = {}
    for index, entry in entries do
        if self:stopped() then
            break
        end
        local view = self.View
        if view == nil then
            break
        end
        view.current = entry
        self.Status = string.format("Placing %d of %d", index, total)
        local position = Store.position(entry)
        local probing = false
        if self:found(entry) == nil and not lacking[entry.name] and not self.NoBag[entry.name] and not self:bag(entry.name) and not self.Probed[entry.name] then
            self.Probed[entry.name] = true
            probing = true
            self:log("the bag shows no " .. entry.name .. ", trying one anyway")
        end
        if self:found(entry) ~= nil then
            self:mark(entry, "placed")
        elseif lacking[entry.name] or (not probing and not self.NoBag[entry.name] and not self:bag(entry.name)) then
            if not lacking[entry.name] then
                lacking[entry.name] = true
                self.Lacking[entry.name] = true
                self:log("no " .. entry.name .. " left in the bag, the rest of them are skipped")
            end
            self.Skipped += 1
            self:mark(entry, "skipped")
        else
            local at = Game.world.position()
            if at == nil then
                break
            end
            if (position - at).Magnitude > NEAR then
                self:travel(position, NEAR)
            end
            local done = self:attempt(entry)
            if not done and not self:stopped() then
                self:travel(position, CLOSE)
                done = self:attempt(entry)
            end
            if probing and not done then
                lacking[entry.name] = true
                self.Lacking[entry.name] = true
                self:log("it did not place, so there is no " .. entry.name .. " in the bag, the rest of them are skipped")
                self.Skipped += 1
                self:mark(entry, "skipped")
            elseif done then
                if probing then
                    self.NoBag[entry.name] = true
                    self:log("it placed, so the bag count of " .. entry.name .. " is read wrong, the bag is ignored for it")
                end
                self.Placed += 1
                self:mark(entry, "placed")
                self:log(string.format("placed %s at %.1f, %.1f, %.1f", entry.name, position.X, position.Y, position.Z))
            else
                self.Failed += 1
                self:mark(entry, "failed")
                self:log(string.format("could not place %s at %.1f, %.1f, %.1f", entry.name, position.X, position.Y, position.Z))
            end
            self.Context.wait(PACE)
        end
    end
end

function Place.begin(self: any)
    local Game = self.Game
    local view = self.View
    local entries = view.entries
    local label = view.label
    local notify = self.Context.notify
    self.Phase = "run"
    self.Cancel = false
    self.Placed, self.Failed, self.Skipped = 0, 0, 0
    table.clear(self.Lacking)
    table.clear(self.Probed)
    local total = #entries
    self:log(string.format("start: %s, %d to place", label, total))
    self.Context.spawn(function()
        local ok, problem = pcall(Place.walk, self, entries)
        Game.drive.finish()
        local text = string.format("Placed %d of %d %s", self.Placed, total, label)
        local names: { string } = {}
        for name in self.Lacking do
            table.insert(names, name)
        end
        table.sort(names)
        if #names > 0 then
            text = text .. ", out of " .. table.concat(names, " and ")
        end
        if self.Failed > 0 then
            text = text .. string.format(", %d would not place", self.Failed)
        end
        if not ok then
            text = text .. " (stopped by an error: " .. tostring(problem) .. ")"
        elseif self.Cancel then
            text = text .. " (stopped)"
        end
        self.Status = text
        self.Phase = nil
        self.View = nil
        self.Cancel = false
        self:log("Placements: " .. text)
        notify("Placements: " .. text)
    end)
end

function Place.tick(self: any)
    if self.Phase ~= "guide" then
        return
    end
    local Game = self.Game
    local view = self.View
    if view == nil then
        self.Phase = nil
        return
    end
    if not Game.world.isSpawned() or self.Context.read("GoldStartPath") == true then
        self.Phase = nil
        self.View = nil
        self.Status = "Cancelled"
        return
    end
    local at = Game.world.position()
    if at == nil then
        return
    end
    local offset = view.start - at
    local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
    view.distance = flat
    self.Status = string.format("Walk to the dot, %d studs away", math.floor(flat + 0.5))
    if flat <= START_RADIUS and math.abs(offset.Y) <= START_HEIGHT then
        self:begin()
    end
end

function Place.start(self: any, kinds: { string }?, label: string)
    local Game = self.Game
    local read = self.Context.read
    local notify = self.Context.notify
    if self.Phase ~= nil then
        notify("Placements: already running")
        return
    end
    if not Game.world.isSpawned() then
        notify("Placements: spawn first")
        return
    end
    if read("GoldStartPath") == true then
        notify("Placements: turn Start Path off first, both would drive the character")
        return
    end
    local saved = 0
    for _, entry in self.Store.Entries do
        if kinds == nil or table.find(kinds, entry.kind) then
            saved += 1
        end
    end
    if saved == 0 then
        notify("Placements: no " .. label .. " are saved for this yet, nothing to place. Run Placements Scanner on your base first")
        return
    end
    local pending = self:targets(kinds)
    if #pending == 0 then
        notify("Placements: " .. label .. " are all in place already")
        return
    end
    if not Game.packets.has("PlaceStructure") then
        notify("Placements: the PlaceStructure packet was not found. " .. Game.observer.hint("PlaceStructure"))
        return
    end
    local state: { [any]: string } = {}
    for _, entry in self.Store.Entries do
        if kinds == nil or table.find(kinds, entry.kind) then
            state[entry] = if self:found(entry) ~= nil then "placed" else "pending"
        end
    end
    self.View = { entries = pending, state = state, label = label, start = Store.position(pending[1]), current = nil, distance = 0 }
    self.Phase = "guide"
    self.Cancel = false
    self.Status = "Walk to the dot"
    notify("Placements: walk to the dot to start placing " .. label)
    self:tick()
end

return Place
end
modules["goldfarm/placements/spot"] = function(...)

local import: (string) -> any = ...
local Hud: any = import("goldfarm/hud")
local Store: any = import("goldfarm/placements/store")

local Spot = {}
Spot.__index = Spot

local ACTION = "BoogaViewSpot"
local SPEED = 28
local FAST = 3
local SENSITIVITY = 0.0028
local LIMIT = math.rad(85)
local RAISE = Vector3.new(0, 14, 16)

function Spot.new(context: any): any
    return setmetatable({
        Context = context,
        Active = false,
        Saved = nil :: any,
        Yaw = 0,
        Pitch = 0,
        Position = Vector3.zero,
        Label = "",
        Entries = {} :: { any },
    }, Spot)
end

function Spot.service(self: any, name: string): any
    return self.Context.Game.modules.service(name)
end

function Spot.camera(self: any): any
    local space = self.Context.Game.world.workspace()
    return if space then space.CurrentCamera else nil
end

function Spot.active(self: any): boolean
    return self.Active
end

function Spot.sink(self: any, on: boolean)
    local actions: any = self:service("ContextActionService")
    if actions == nil then
        return
    end
    pcall(function()
        if on then
            actions:BindActionAtPriority(ACTION, function()
                return Enum.ContextActionResult.Sink
            end, false, Enum.ContextActionPriority.High.Value + 10,
                Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Q, Enum.KeyCode.E,
                Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.LeftControl, Enum.KeyCode.Up, Enum.KeyCode.Down,
                Enum.KeyCode.Left, Enum.KeyCode.Right)
        else
            actions:UnbindAction(ACTION)
        end
    end)
end

function Spot.start(self: any, entries: { any }, label: string): boolean
    local camera = self:camera()
    if camera == nil or #entries == 0 then
        self.Context.notify("View Spot: nothing to look at yet")
        return false
    end
    if self.Active then
        self:stop()
    end
    local target = Store.position(entries[1])
    self.Saved = { Type = camera.CameraType, CFrame = camera.CFrame, Subject = camera.CameraSubject, Behavior = nil }
    self.Position = target + RAISE
    local look = CFrame.lookAt(self.Position, target)
    local x, y = look:ToOrientation()
    self.Pitch = x
    self.Yaw = y
    self.Label = label
    self.Entries = entries
    self.Active = true
    pcall(function()
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = look
    end)
    self:sink(true)
    self.Context.notify("View Spot: hold right mouse to look, WASD to fly, Shift is faster. Press Stop Viewing to leave")
    return true
end

function Spot.stop(self: any)
    if not self.Active then
        return
    end
    self.Active = false
    self:sink(false)
    local input: any = self:service("UserInputService")
    if input ~= nil then
        pcall(function()
            input.MouseBehavior = Enum.MouseBehavior.Default
        end)
    end
    local camera = self:camera()
    local saved = self.Saved
    self.Saved = nil
    self.Entries = {}
    if camera ~= nil and saved ~= nil then
        pcall(function()
            camera.CameraType = saved.Type
            camera.CFrame = saved.CFrame
            if saved.Subject ~= nil then
                camera.CameraSubject = saved.Subject
            end
        end)
    end
end

function Spot.step(self: any, dt: number)
    if not self.Active then
        return
    end
    local camera = self:camera()
    local input: any = self:service("UserInputService")
    if camera == nil or input == nil then
        self:stop()
        return
    end
    if not self.Context.alive() then
        self:stop()
        return
    end
    local looking = input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    pcall(function()
        input.MouseBehavior = if looking then Enum.MouseBehavior.LockCurrentPosition else Enum.MouseBehavior.Default
    end)
    if looking then
        local delta = input:GetMouseDelta()
        self.Yaw -= delta.X * SENSITIVITY
        self.Pitch = math.clamp(self.Pitch - delta.Y * SENSITIVITY, -LIMIT, LIMIT)
    end
    local rotation = CFrame.fromOrientation(self.Pitch, self.Yaw, 0)
    local move = Vector3.zero
    local function down(key: any): boolean
        return input:IsKeyDown(key)
    end
    if down(Enum.KeyCode.W) then
        move += rotation.LookVector
    end
    if down(Enum.KeyCode.S) then
        move -= rotation.LookVector
    end
    if down(Enum.KeyCode.D) then
        move += rotation.RightVector
    end
    if down(Enum.KeyCode.A) then
        move -= rotation.RightVector
    end
    if down(Enum.KeyCode.E) or down(Enum.KeyCode.Space) then
        move += Vector3.yAxis
    end
    if down(Enum.KeyCode.Q) or down(Enum.KeyCode.LeftControl) then
        move -= Vector3.yAxis
    end
    if move.Magnitude > 0 then
        local speed = SPEED * (if down(Enum.KeyCode.LeftShift) then FAST else 1)
        self.Position += move.Unit * speed * dt
    end
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.new(self.Position) * rotation
end

function Spot.frame(self: any, canvas: any, size: Vector2, color: Color3)
    if not self.Active then
        return
    end
    Hud.banner(canvas, size, "Viewing " .. self.Label .. ": right mouse look, WASD fly, Shift fast", nil, 1)
    for index, entry in self.Entries do
        local position = Store.position(entry)
        local screen, depth = canvas.project(position + Vector3.new(0, 0.6, 0))
        if screen ~= nil and depth > 0.1 then
            canvas.filledCircle(screen, if index == 1 then 6 else 3.5, color, 0.95)
            if index == 1 then
                canvas.circle(screen, 12, color, 0.9, 2)
                Hud.tag(canvas, Vector2.new(screen.X, screen.Y - 34), "First spot", nil, 1, 13)
            end
        end
    end
end

return Spot
end
modules["goldfarm/placements/store"] = function(...)

local import: (string) -> any = ...
local Built: { { any } } = import("goldfarm/placements/blueprint")

local Store = {}
Store.__index = Store

Store.FOLDER = "placements"
Store.FILE = "blueprint.json"

export type Entry = { name: string, kind: string, c: { number } }

Store.KINDS = { "campfire", "press", "chest", "plant" }
Store.LABELS = {
    campfire = "campfires",
    press = "coin presses",
    chest = "chests",
    plant = "plant boxes",
} :: { [string]: string }

function Store.new(context: any, rows: { { any } }?): any
    local self = setmetatable({
        Context = context,
        Entries = {} :: { Entry },
        FromFile = false,
        Rows = rows,
    }, Store)
    self:load()
    return self
end

function Store.http(self: any): any
    return self.Context.Game.modules.service("HttpService")
end

function Store.path(self: any): string
    return self.Context.Folder .. "/" .. Store.FOLDER .. "/" .. Store.FILE
end

function Store.frame(entry: Entry): CFrame
    local c = entry.c
    return CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
end

function Store.position(entry: Entry): Vector3
    return Vector3.new(entry.c[1], entry.c[2], entry.c[3])
end

function Store.counts(entries: { Entry }): { [string]: number }
    local counts: { [string]: number } = {}
    for _, entry in entries do
        counts[entry.kind] = (counts[entry.kind] or 0) + 1
    end
    return counts
end

local function valid(kind: any): boolean
    return type(kind) == "string" and Store.LABELS[kind] ~= nil
end

function Store.fromFile(self: any): { Entry }
    local list: { Entry } = {}
    local ok, data = pcall(function(): any
        if not isfile(self:path()) then
            return nil
        end
        return self:http():JSONDecode(readfile(self:path()))
    end)
    if not ok or type(data) ~= "table" or type(data.entries) ~= "table" then
        return list
    end
    for _, item in data.entries do
        if type(item) == "table" and type(item.name) == "string" and valid(item.kind) and type(item.c) == "table" and #item.c == 12 then
            local clean = true
            for _, value in item.c do
                if type(value) ~= "number" then
                    clean = false
                end
            end
            if clean then
                table.insert(list, { name = item.name, kind = item.kind, c = item.c })
            end
        end
    end
    return list
end

function Store.builtIn(given: { { any } }?): { Entry }
    local list: { Entry } = {}
    local rows: { { any } } = if given ~= nil then given else Built
    local ok, env = pcall(getgenv)
    if given == nil and ok and type(env) == "table" and type(env.__BoogaPlacementsBuiltIn) == "table" then
        rows = env.__BoogaPlacementsBuiltIn
    end
    for _, row in rows do
        if valid(row[1]) and type(row[2]) == "string" and #row == 14 then
            table.insert(list, { name = row[2], kind = row[1], c = { table.unpack(row, 3, 14) } })
        end
    end
    return list
end

function Store.load(self: any)
    local built = Store.builtIn(self.Rows)
    if self.Rows ~= nil then
        self.FromFile = false
        self.Entries = built
        return
    end
    if #built > 0 then
        self.FromFile = false
        self.Entries = built
        return
    end
    local saved = self:fromFile()
    self.FromFile = #saved > 0
    self.Entries = saved
end

function Store.summary(self: any): string
    local counts = Store.counts(self.Entries)
    local parts: { string } = {}
    for _, kind in Store.KINDS do
        if counts[kind] then
            table.insert(parts, tostring(counts[kind]) .. " " .. Store.LABELS[kind])
        end
    end
    return table.concat(parts, ", ")
end

return Store
end
modules["goldfarm/utility"] = function(...)

local import: (string) -> any = ...
local Link: any = import("goldfarm/link")
local Performance: any = import("goldfarm/performance")

local Part = {}
Part.__index = Part

Part.Defaults = {
    GoldCpuMode = false,
} :: { [string]: any }

function Part.new(context: any): any
    return setmetatable({
        Context = context,
        Gold = Link.get(context, "gold"),
        Performance = Performance.new(context),
    }, Part)
end

function Part.build(self: any, _ui: any, tab: any)
    local context = self.Context
    local gold = self.Gold
    local function kick()
        gold.Loops:sync()
    end
    local function off(flag: string): () -> boolean
        return function(): boolean
            return context.read(flag) ~= true
        end
    end

    local utility = tab:section("UTILITY")
    utility:label({ Text = "Walkspeed", Size = 12, Height = 28, Offset = 4 })
    self.Performance:listen()
    utility:pair({
        Type = "Toggle",
        Name = "Walkspeed",
        Flag = "GoldWalkSpeedOn",
        Default = false,
        Bindable = false,
        Info = {
            Title = "Walkspeed",
            Lines = { "Only applies while a path runs. It is not", "your normal walk speed, that is in Character." },
            Width = 320,
        },
    }, {
        Type = "Slider",
        Name = "Speed",
        Flag = "GoldWalkSpeed",
        Min = 10,
        Max = 19,
        Step = 1,
        Default = 19,
        Disabled = off("GoldWalkSpeedOn"),
    })
    utility:label({ Text = "Farming", Size = 12, Height = 28, Offset = 4 })
    utility:toggle({
        Name = "Anti-Stuck",
        Flag = "GoldAntiStuck",
        Default = true,
        Info = {
            Title = "Anti-Stuck",
            Lines = { "If the path moved you less than 10 studs in 40", "seconds, the run restarts at the nearest dot." },
            Width = 320,
        },
    })
    utility:label({
        Center = true,
        Accent = true,
        Label = function(): string
            return gold:antiStuckText()
        end,
    })
    utility:toggle({ Name = "Auto Open Chest", Flag = "GoldAutoOpenChest", Default = false, Callback = kick })
    utility:label({ Text = "Performance", Size = 12, Height = 28, Offset = 4 })
    utility:pair({
        Type = "Toggle",
        Name = "CPU Mode",
        Flag = "GoldCpuMode",
        Default = false,
        Bindable = false,
        Callback = function()
            self.Performance:sync()
        end,
        Info = {
            Title = "CPU Mode",
            Lines = {
                "While on: caps the frame rate at 25, turns off",
                "shadows, fog, post effects and water waves, hides",
                "every decal and texture and removes the terrain",
                "grass. Everything is restored when you turn it off.",
                "Also turns 3D rendering off while the game window",
                "is not focused and back on when you return.",
            },
            Width = 380,
        },
    }, {
        Type = "Toggle",
        Name = "Lock Camera",
        Flag = "GoldLockCamera",
        Default = false,
        Bindable = false,
        Info = {
            Title = "Lock Camera",
            Lines = { "Keeps the camera at a fixed downward angle", "while Start Path is on, so the view does not", "drift while you farm. It does nothing otherwise." },
            Width = 300,
        },
    })
    utility:label({ Text = "Startup", Size = 12, Height = 28, Offset = 4 })
    utility:toggle({
        Name = "Auto Start Path",
        Flag = "GoldAutoStartPath",
        Default = false,
        Bindable = false,
        Callback = kick,
        Info = {
            Title = "Auto Start Path",
            Lines = { "After you spawn it turns Start Path on once and then", "never does anything again until the script is", "loaded again. Saved with your config." },
            Width = 340,
        },
    })
    utility:toggle({
        Name = "Equip 1st Slot",
        Flag = "GoldEquipFirstSlot",
        Default = false,
        Bindable = false,
        Callback = kick,
        Info = {
            Title = "Equip 1st Slot",
            Lines = { "After you spawn it equips slot 1 once and then", "never does anything again until the script is", "loaded again." },
            Width = 340,
        },
    })
end

function Part.step(self: any, _dt: number)
    self.Performance:sync()
end

function Part.shutdown(self: any)
    self.Performance:shutdown()
end

return Part
end
modules["goldfarm/webhook"] = function(...)

local import: (string) -> any = ...
local Stats: any = import("goldfarm/webhook/stats")
local Embed: any = import("goldfarm/webhook/embed")
local Send: any = import("goldfarm/webhook/send")
local Vault: any = import("goldfarm/webhook/vault")
local Popup: any = import("goldfarm/webhook/popup")
local Link: any = import("goldfarm/link")

local Part = {}
Part.__index = Part

Part.Defaults = {
    WebhookUrl = "",
    WebhookEnabled = false,
    WebhookOnCycle = true,
    WebhookUsername = true,
    WebhookCooldown = 20,
} :: { [string]: any }

local BUSY_DELAY = 1
local CONFIRM_SECONDS = 3
local LABEL_LENGTH = 14

local DESCRIPTIONS = {
    cycle = "Coin press cycle %d finished",
    test = "Test message, the webhook works",
    now = "Manual report",
}

function Part.new(context: any): any
    local Game = context.Game
    local gold = Link.get(context, "gold")
    local self = setmetatable({
        Context = context,
        Game = Game,
        Stats = Stats.new(context, gold),
        Sender = Send.new(context, Game.modules.service("HttpService")),
        Ui = nil :: any,
        Vault = Vault.new(context.Folder, Game.modules.service("HttpService"), Send.valid),
        Draft = { Name = "", Url = "" },
        Confirm = nil :: { kind: string, name: string, url: string, at: number }?,
        LastAt = -math.huge,
        Busy = false,
        Waiting = false,
        Pending = nil :: string?,
        Rejected = nil :: string?,
        Failed = {} :: { [string]: boolean },
        Message = "",
    }, Part)
    Link.set(context, "webhook", self)
    if gold ~= nil then
        gold.Press:onCycle(function(info: any)
            self:cycle(info)
        end)
    end
    return self
end

function Part.linked(self: any): boolean
    return Send.valid(self.Context.read("WebhookUrl"))
end

function Part.cycle(self: any, info: any)
    self.Stats:cycle(info)
    local read = self.Context.read
    if read("WebhookEnabled") == true and read("WebhookOnCycle") == true then
        self:request("cycle", false)
    end
end

function Part.schedule(self: any, delay: number)
    if self.Waiting then
        return
    end
    self.Waiting = true
    self.Context.spawn(function()
        local alive = self.Context.wait(delay)
        self.Waiting = false
        local reason = self.Pending
        self.Pending = nil
        if alive and reason ~= nil and self.Context.read("WebhookEnabled") == true then
            self:request(reason, false)
        end
    end)
end

function Part.request(self: any, reason: string, manual: boolean)
    local context = self.Context
    local url = context.read("WebhookUrl")
    if not Send.valid(url) then
        if manual then
            context.notify("Webhook: set a Discord webhook link first")
        end
        return
    end
    if not manual and url == self.Rejected then
        return
    end
    local remaining = context.read("WebhookCooldown") - (os.clock() - self.LastAt)
    if remaining > 0 or self.Busy then
        if manual then
            context.notify(string.format("Webhook: wait %d s before sending again", math.ceil(math.max(remaining, BUSY_DELAY))))
        else
            self.Pending = reason
            self:schedule(math.max(remaining, BUSY_DELAY))
        end
        return
    end
    self.Busy = true
    self.LastAt = os.clock()
    context.spawn(function()
        local ok = pcall(function()
            self:deliver(url, reason, manual)
        end)
        if not ok then
            self:report("failed", nil, manual)
        end
        self.Busy = false
    end)
end

function Part.color(self: any): any
    local ok, color = pcall(function(): any
        return self.Ui.Window.Pal.Accent
    end)
    return if ok then color else nil
end

function Part.deliver(self: any, url: string, reason: string, manual: boolean)
    local context = self.Context
    local stats = self.Stats:snapshot()
    local now = stats.at
    local description = string.format(DESCRIPTIONS[reason] or DESCRIPTIONS.now, self.Stats.Cycles)
    local options = {
        showName = context.read("WebhookUsername") == true,
        avatar = self.Sender:avatar(stats.userId),
        color = self:color(),
        description = description,
        clock = os.date("%H:%M", now),
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ", now),
    }
    local result, code = self.Sender:post(url, Embed.build(stats, options))
    if result == "invalid" then
        self.Rejected = url
    end
    self:report(result, code, manual)
end

function Part.report(self: any, result: string, code: number?, manual: boolean)
    local context = self.Context
    if result == "ok" then
        table.clear(self.Failed)
        if manual then
            context.notify("Webhook: sent")
        end
        return
    end
    if self.Failed[result] then
        return
    end
    self.Failed[result] = true
    if result == "invalid" then
        context.notify("Webhook: Discord rejected the link, set it again")
    elseif result == "limited" then
        context.notify("Webhook: Discord rate limit, raise the cooldown")
    else
        context.notify("Webhook: sending failed" .. (if code ~= nil then " (HTTP " .. tostring(code) .. ")" else ""))
    end
end

function Part.tick(self: any)
    local confirm = self.Confirm
    if confirm ~= nil and os.clock() - confirm.at >= CONFIRM_SECONDS then
        self.Confirm = nil
    end
end

function Part.armed(self: any, kind: string, name: string?): boolean
    local confirm = self.Confirm
    if confirm == nil or confirm.kind ~= kind or os.clock() - confirm.at >= CONFIRM_SECONDS then
        return false
    end
    return name == nil or confirm.name == name
end

function Part.arm(self: any, kind: string, name: string, url: string)
    self.Confirm = { kind = kind, name = name, url = url, at = os.clock() }
end

function Part.draftName(self: any, text: string)
    self.Draft.Name = Vault.cleanName(text)
    self.Confirm = nil
end

function Part.draftUrl(self: any, text: string)
    local value = string.match(text, "^%s*(.-)%s*$") or ""
    if value == "" then
        return
    end
    self.Confirm = nil
    if Send.valid(value) then
        self.Draft.Url = value
        self.Message = "Link ready, press Save"
    else
        self.Draft.Url = ""
        self.Message = "That is not a Discord webhook link"
    end
end

function Part.persist(self: any)
    if not self.Vault:write() then
        self.Message = "Could not write " .. Vault.FILE
    end
end

function Part.activate(self: any, url: string)
    self.Rejected = nil
    table.clear(self.Failed)
    self.Context.set("WebhookUrl", url)
end

function Part.saveEntry(self: any)
    local vault = self.Vault
    local url: string = self.Draft.Url
    if url == "" then
        self.Message = "Paste a Discord webhook link first"
        return
    end
    local name = Vault.cleanName(self.Draft.Name)
    if name == "" then
        name = vault:autoName()
    end
    local index = vault:index(name)
    if index ~= nil then
        name = vault.Entries[index].name
        local confirm = self.Confirm
        if not (self:armed("save", name) and confirm ~= nil and confirm.url == url) then
            self:arm("save", name, url)
            self.Message = "Press Save again to replace " .. name
            return
        end
    elseif vault:count() >= Vault.LIMIT then
        self.Message = string.format("Limit of %d reached, delete one first", Vault.LIMIT)
        return
    end
    self.Confirm = nil
    vault:put(name, url)
    if vault.ActiveName == name then
        self:activate(url)
    end
    self.Draft.Name, self.Draft.Url = "", ""
    self.Message = "Saved " .. name
    self:persist()
end

function Part.loadEntry(self: any, name: string)
    local url = self.Vault:urlOf(name)
    if url == nil then
        return
    end
    self.Confirm = nil
    self:activate(url)
    self.Vault.ActiveName = name
    self.Message = "Loaded " .. name
    self:persist()
end

function Part.deleteEntry(self: any, name: string)
    if not self:armed("delete", name) then
        self:arm("delete", name, "")
        return
    end
    self.Confirm = nil
    local wasActive = self.Vault.ActiveName == name
    self.Vault:remove(name)
    if wasActive then
        self.Rejected = nil
        self.Context.set("WebhookUrl", "")
    end
    self.Message = "Deleted " .. name
    self:persist()
end

function Part.label(self: any): string
    if not self:linked() then
        return "Webhook: Not Set"
    end
    local name: string? = self.Vault:nameOfUrl(self.Context.read("WebhookUrl"))
    if name == nil then
        return "Webhook: Set"
    end
    local length = utf8.len(name)
    if length ~= nil and length > LABEL_LENGTH then
        name = string.sub(name, 1, (utf8.offset(name, LABEL_LENGTH + 1) :: number) - 1) .. "…"
    end
    return "Webhook: " .. name
end

function Part.status(self: any): string
    local read = self.Context.read
    if not self:linked() then
        return "Webhook: not set"
    elseif read("WebhookEnabled") ~= true then
        return "Webhook set, turned off"
    elseif read("WebhookOnCycle") == true then
        return "Webhook set, sends after every press cycle"
    end
    return "Webhook set, manual sends only"
end

function Part.matchAccount(self: any)
    local player = self.Game.world.LocalPlayer
    if player == nil then
        return
    end
    for _, candidate in { player.Name, player.DisplayName } do
        local index = self.Vault:index(tostring(candidate))
        if index ~= nil then
            self.Vault.ActiveName = self.Vault.Entries[index].name
            return
        end
    end
end

function Part.build(self: any, ui: any, tab: any)
    local context = self.Context
    self.Ui = ui
    ui:flag("WebhookUrl", "", false)
    self:matchAccount()
    local stored = self.Vault:activeUrl()
    if stored ~= nil then
        context.set("WebhookUrl", stored)
    end
    Popup.register(self, ui)

    local webhook = tab:section("WEBHOOK")
    webhook:label({ Text = "Connection", Size = 12, Height = 28, Offset = 4 })
    webhook:button({
        Name = "Webhook URL",
        Label = function(): string
            return self:label()
        end,
        Callback = function()
            self.Message = ""
            ui:openPopup(Popup.NAME)
        end,
        Info = {
            Title = "Webhook",
            Lines = {
                "Sends one Discord embed: coins in your account, in the",
                "press and calculated coins, gold in and outside of the",
                "chest (with the gold bars), gold pressed, hunger, time",
                "sent, account, runtime and press cycles, with your Roblox",
                "avatar on the right when it can be loaded.",
                "Calculated coins are the picked up coins times 5.",
                "With Send Username on, the name is shown as a Discord",
                "spoiler, hidden until clicked.",
                "Save as many webhooks as you like with a name each, for",
                "example one per account, and press Load on the one to use.",
                "Saved webhooks live in webhooks.json in the script folder,",
                "never in a config or a config code. Only a short snippet",
                "of each link is shown and it is never put in a message.",
            },
            Width = 400,
        },
    })
    webhook:label({
        Center = true,
        Accent = true,
        Label = function(): string
            return self:status()
        end,
    })
    webhook:label({ Text = "Sending", Size = 12, Height = 28, Offset = 4 })
    webhook:pair({
        Type = "Toggle",
        Name = "Enable Webhook",
        Flag = "WebhookEnabled",
        Default = false,
        Bindable = false,
        Info = {
            Title = "Enable Webhook",
            Lines = { "Allows the automatic sends. The Send Test and", "Send Now buttons work without it." },
            Width = 330,
        },
    }, {
        Type = "Toggle",
        Name = "Send Username",
        Flag = "WebhookUsername",
        Default = true,
        Bindable = false,
        Info = {
            Title = "Send Username",
            Lines = { "On: the report shows your name as a spoiler, hidden", "until clicked. Off: the report says Hidden." },
            Width = 340,
        },
    })
    webhook:toggle({
        Name = "Send On Press Cycle",
        Flag = "WebhookOnCycle",
        Default = true,
        Bindable = false,
        Info = {
            Title = "Send On Press Cycle",
            Lines = {
                "Sends the report when the coin press is done: the",
                "path paused at the press, everything was pressed and",
                "the pause ended. Works without Pause Near Press too,",
                "it then sends when the gold in the bag and chest ran out.",
            },
            Width = 380,
        },
    })
    webhook:slider({
        Name = "Cooldown",
        Flag = "WebhookCooldown",
        Min = 5,
        Max = 300,
        Step = 5,
        Default = 20,
        Format = function(value: number): string
            return tostring(value) .. "s"
        end,
        Info = {
            Title = "Cooldown",
            Lines = { "Least seconds between two sends. A cycle that ends", "sooner is sent once the cooldown is over." },
            Width = 340,
        },
    })
    webhook:label({ Text = "Actions", Size = 12, Height = 28, Offset = 4 })
    webhook:pair({
        Type = "Button",
        Name = "Send Test",
        Callback = function()
            self:request("test", true)
        end,
    }, {
        Type = "Button",
        Name = "Send Now",
        Callback = function()
            self:request("now", true)
        end,
    })
    webhook:button({
        Name = "Reset Stats",
        Callback = function()
            self.Stats:reset()
            context.notify("Webhook: stats reset")
        end,
        Info = {
            Title = "Reset Stats",
            Lines = { "Starts a new session: runtime, press cycles, gold", "pressed and calculated coins begin at zero." },
            Width = 340,
        },
    })
end

function Part.shutdown(self: any)
    self.Pending = nil
end

return Part
end
modules["goldfarm/webhook/embed"] = function(...)

local Embed = {}

local TITLE = "Booga Utilities"
local REPORT = "Gold Farm Report"
local FALLBACK_COLOR = 0x7DA0D7
local DASH = "\u{2014}"

function Embed.number(value: number): string
    local text = tostring(math.floor(value + 0.5))
    local sign = ""
    if string.sub(text, 1, 1) == "-" then
        sign = "-"
        text = string.sub(text, 2)
    end
    local grouped = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
    if string.sub(grouped, 1, 1) == "," then
        grouped = string.sub(grouped, 2)
    end
    return sign .. grouped
end

function Embed.duration(seconds: number): string
    local total = math.max(0, math.floor(seconds))
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local rest = total % 60
    if hours > 0 then
        return string.format("%dh %02dm %02ds", hours, minutes, rest)
    elseif minutes > 0 then
        return string.format("%dm %02ds", minutes, rest)
    end
    return string.format("%ds", rest)
end

function Embed.color(color: any): number
    local ok, value = pcall(function(): number
        return math.floor(color.R * 255 + 0.5) * 65536 + math.floor(color.G * 255 + 0.5) * 256 + math.floor(color.B * 255 + 0.5)
    end)
    return if ok then value else FALLBACK_COLOR
end

local function line(label: string, value: string): string
    return string.format("%s: %s", label, value)
end

local function amount(value: number?): string
    return if value ~= nil then Embed.number(value) else DASH
end

function Embed.build(stats: any, options: any): any
    local hunger = if stats.hunger ~= nil then string.format("%d%%", math.floor(math.clamp(stats.hunger, 0, 100) + 0.5)) else DASH
    local username = if options.showName then "||" .. stats.name .. "||" else "Hidden"
    local cycles = Embed.number(stats.cycles)
    if stats.lastCycle ~= nil then
        cycles = string.format("%s, last <t:%d:R>", cycles, stats.lastCycle)
    end
    local groups = {
        {
            line("Account", username),
            line("Runtime", Embed.duration(stats.runtime)),
            line("Press Cycles", cycles),
        },
        {
            line("Hunger", hunger),
            line("Time Sent", stats.time),
        },
        {
            line("Gold In Chest", Embed.number(stats.chest.gold)),
            line("Gold Outside", Embed.number(stats.outside.gold)),
            line("Bars In Chest", Embed.number(stats.chest.bars)),
            line("Bars Outside", Embed.number(stats.outside.bars)),
        },
        {
            line("Coins In Account", amount(stats.account)),
            line("Coins In Press", amount(stats.pressCoins)),
            line("Calculated Coins", Embed.number(stats.calculatedCoins)),
            line("Gold Pressed", Embed.number(stats.pressed)),
            line("Per Hour", amount(stats.perHour)),
        },
    }
    local blocks = {}
    for _, group in groups do
        table.insert(blocks, table.concat(group, "\n"))
    end
    local embed: { [string]: any } = {
        author = { name = REPORT },
        description = options.description .. "\n\n" .. table.concat(blocks, "\n\n"),
        color = Embed.color(options.color),
    }
    if options.avatar ~= nil then
        embed.image = { url = options.avatar }
    end
    return { username = TITLE, embeds = { embed } }
end

return Embed
end
modules["goldfarm/webhook/popup"] = function(...)

local import: (string) -> any = ...
local Vault: any = import("goldfarm/webhook/vault")

local Popup = {}

Popup.NAME = "boogawebhook:manager"

local NAME_KEY = "boogawebhook:name"
local URL_KEY = "boogawebhook:url"
local WIDTH = 420
local HEIGHT = 420
local MARGIN = 16
local ROW = 42
local ROW_BODY = 38
local VISIBLE = 5
local URL_LENGTH = 300
local URL_HINT = "https://discord.com/api/webhooks/…"
local NAME_HINT = "Name (optional)"
local DANGER = Color3.fromRGB(235, 110, 110)

local function field(kit: any, window: any, key: string, x: number, y: number, w: number, h: number, shown: string, hint: string, size: number, secret: boolean, onFocus: () -> ())
    local pal = window.Pal
    local focused = window.Focus == key
    kit:rect(x, y, w, h, if focused then pal.Off else pal.Panel, 1, 10)
    if kit:hovered(key) and not focused then
        kit:rect(x, y, w, h, pal.Accent, 0.12, 10)
    end
    local text, color = shown, pal.Text
    if focused then
        local buffer: string = window.Buffers[key] or ""
        text = if secret then string.format("Pasting… %d characters|", #buffer) else buffer .. "|"
    elseif shown == "" then
        text, color = hint, pal.Sub
    end
    kit:text(text, x + w / 2, y + h / 2, size, color, true, true)
    kit:hit(key, x, y, w, h, onFocus)
end

local function row(kit: any, window: any, part: any, index: number, x: number, y: number, w: number)
    local pal = window.Pal
    local entry = part.Vault.Entries[index]
    if entry == nil then
        return
    end
    local active = part.Vault.ActiveName == entry.name
    kit:rect(x, y, w, ROW_BODY, pal.Panel, 1, 12)
    if active then
        kit:rect(x, y, w, ROW_BODY, pal.Accent, 0.16, 12)
    end
    local deleteX = x + w - 66 - 6
    local loadX = deleteX - 6 - 54
    kit:text(entry.name, x + 12, y + 13, 12, pal.Text, false, true)
    local preview = Vault.preview(entry.url)
    kit:text(preview, x + 12, y + 27, 9, pal.Sub, false, true)
    if active then
        kit:text("Active", x + 12 + kit:measure(preview, 9) + 8, y + 27, 9, pal.Accent, false, true)
    end
    kit:button("boogawebhook:load:" .. index, loadX, y + 6, 54, 26, function()
        part:loadEntry(entry.name)
    end, { label = "Load", size = 11, rounding = 10, base = pal.Main, align = "center" })
    local sure = part:armed("delete", entry.name)
    kit:button("boogawebhook:delete:" .. index, deleteX, y + 6, 66, 26, function()
        part:deleteEntry(entry.name)
    end, {
        label = if sure then "Sure?" else "Delete",
        size = 11,
        rounding = 10,
        base = pal.Main,
        textColor = if sure then DANGER else pal.Text,
        align = "center",
    })
end

function Popup.register(part: any, ui: any)
    ui:popup(Popup.NAME, {
        Width = WIDTH,
        Height = HEIGHT,
        Title = "",
        Render = function(kit: any, window: any)
            part:tick()
            local pal = window.Pal
            local top = kit:header("Webhooks", "Saved on this device, never in configs", function()
                window:closePopup()
            end)
            local inner = WIDTH - MARGIN * 2
            local nameWidth = 132
            local y = top + 6
            field(kit, window, NAME_KEY, MARGIN, y, nameWidth, 30, part.Draft.Name, NAME_HINT, 12, false, function()
                window:beginInput(NAME_KEY, part.Draft.Name, {
                    maxLength = Vault.NAME_LENGTH,
                    commit = function(text: string)
                        part:draftName(text)
                    end,
                })
            end)
            local shown = if part.Draft.Url ~= "" then Vault.preview(part.Draft.Url) else ""
            field(kit, window, URL_KEY, MARGIN + nameWidth + 8, y, inner - nameWidth - 8, 30, shown, URL_HINT, 11, true, function()
                window:beginInput(URL_KEY, "", {
                    maxLength = URL_LENGTH,
                    commit = function(text: string)
                        part:draftUrl(text)
                    end,
                })
            end)
            y += 38
            kit:text(part.Message, MARGIN + 2, y + 14, 10, pal.Accent, false, true)
            kit:button("boogawebhook:save", WIDTH - MARGIN - 110, y, 110, 28, function()
                part:saveEntry()
            end, { label = if part:armed("save", nil) then "Replace?" else "Save", size = 12, align = "center", rounding = 12 })
            y += 40
            local count = part.Vault:count()
            kit:text("SAVED WEBHOOKS", MARGIN + 2, y + 6, 10, pal.Sub, false, true)
            local total = string.format("%d / %d", count, Vault.LIMIT)
            kit:text(total, WIDTH - MARGIN - 2 - kit:measure(total, 10), y + 6, 10, pal.Sub, false, true)
            y += 18
            if count == 0 then
                kit:text("Nothing saved yet", WIDTH / 2, y + ROW * 2, 11, pal.Sub, true, true)
            end
            kit:scroll("boogawebhook:list", MARGIN, y, inner, ROW * VISIBLE, ROW, count, function(index: number, rx: number, ry: number, rw: number)
                row(kit, window, part, index, rx, ry, rw)
            end, 6)
        end,
    })
end

return Popup
end
modules["goldfarm/webhook/press"] = function(...)

local Reader = {}

local PRESS_NAMES = { "Coin Press", "CoinPress" }
local PART_NAME = "CoinPart"
local RADIUS = 40

type Entry = { instance: any, position: Vector3 }

function Reader.presses(Game: any): { Entry }
    return Game.finder.deployables(nil, { contains = PRESS_NAMES })
end

local function anchorOf(entry: Entry): Vector3
    local part = entry.instance:FindFirstChild(PART_NAME, true)
    if part and part:IsA("BasePart") then
        return part.Position
    end
    return entry.position
end

function Reader.read(Game: any): number?
    local presses = Reader.presses(Game)
    local press = presses[1]
    if press == nil then
        return nil
    end
    local anchor = anchorOf(press)
    local total = 0
    for _, coin in Game.finder.coins(nil) do
        if (coin.position - anchor).Magnitude <= RADIUS then
            total += 1
        end
    end
    return total
end

return Reader
end
modules["goldfarm/webhook/send"] = function(...)

local Send = {}
Send.__index = Send

local AVATAR_URL = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=150x150&format=Png&isCircular=false"
local AVATAR_RETRY = 120
local RETRY_LIMIT = 30
local ATTEMPTS = 2

local HOSTS = { "discord.com", "discordapp.com" }
local PATHS = { "/api/webhooks/%d+/[%w_%-]+$", "/api/v%d+/webhooks/%d+/[%w_%-]+$" }

function Send.valid(url: any): boolean
    if type(url) ~= "string" or #url > 300 then
        return false
    end
    for _, host in HOSTS do
        local escaped = string.gsub(host, "%.", "%%.")
        for _, path in PATHS do
            if string.match(url, "^https://" .. escaped .. path) or string.match(url, "^https://%w+%." .. escaped .. path) then
                return true
            end
        end
    end
    return false
end

function Send.new(context: any, http: any): any
    return setmetatable({
        Context = context,
        Http = http,
        AvatarUrl = nil :: string?,
        AvatarFailedAt = nil :: number?,
        AvatarUser = 0,
    }, Send)
end

local function call(options: { [string]: any }): any
    local fn = request
    if type(fn) ~= "function" then
        return nil
    end
    local ok, response = pcall(fn, options)
    return if ok then response else nil
end

function Send.avatar(self: any, userId: number): string?
    if self.AvatarUrl ~= nil and self.AvatarUser == userId then
        return self.AvatarUrl
    end
    local failed = self.AvatarFailedAt
    if failed ~= nil and self.AvatarUser == userId and os.clock() - failed < AVATAR_RETRY then
        return nil
    end
    self.AvatarUser = userId
    local response = call({ Url = string.format(AVATAR_URL, userId), Method = "GET" })
    if response ~= nil and response.StatusCode == 200 then
        local ok, decoded = pcall(function(): any
            return self.Http:JSONDecode(response.Body)
        end)
        local entry = if ok and type(decoded) == "table" and type(decoded.data) == "table" then decoded.data[1] else nil
        if type(entry) == "table" and type(entry.imageUrl) == "string" and entry.imageUrl ~= "" then
            self.AvatarUrl = entry.imageUrl
            self.AvatarFailedAt = nil
            return entry.imageUrl
        end
    end
    self.AvatarFailedAt = os.clock()
    return nil
end

function Send.retryAfter(self: any, response: any): number
    local seconds: number? = nil
    local ok, decoded = pcall(function(): any
        return self.Http:JSONDecode(response.Body)
    end)
    if ok and type(decoded) == "table" then
        seconds = tonumber(decoded.retry_after)
    end
    if seconds == nil and type(response.Headers) == "table" then
        seconds = tonumber(response.Headers["retry-after"] or response.Headers["Retry-After"])
    end
    return math.clamp(seconds or 2, 0.5, RETRY_LIMIT)
end

function Send.post(self: any, url: string, payload: any): (string, number?)
    local body = self.Http:JSONEncode(payload)
    local code: number? = nil
    for attempt = 1, ATTEMPTS do
        local response = call({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        })
        if response == nil then
            return "failed", nil
        end
        code = tonumber(response.StatusCode)
        if code ~= nil and code >= 200 and code < 300 then
            return "ok", code
        elseif code == 429 and attempt < ATTEMPTS then
            if not self.Context.wait(self:retryAfter(response)) then
                return "failed", code
            end
        elseif code == 401 or code == 403 or code == 404 then
            return "invalid", code
        else
            return if code == 429 then "limited" else "failed", code
        end
    end
    return "failed", code
end

return Send
end
modules["goldfarm/webhook/stats"] = function(...)

local import: (string) -> any = ...
local Items: any = import("goldfarm/gold/items")
local PressReader: any = import("goldfarm/webhook/press")

local Stats = {}
Stats.__index = Stats

local COIN_VALUE = 5
local COIN_TRACK_LIMIT = 400
local CHEST_RANGE = 60

export type Counts = { gold: number, bars: number }

function Stats.new(context: any, gold: any): any
    return setmetatable({
        Context = context,
        Game = context.Game,
        Gold = gold,
        StartedAt = os.time(),
        Cycles = 0,
        Pressed = 0,
        LastCycle = nil :: number?,
        CoinPickups = 0,
        Tracked = {} :: { [number]: any },
        TrackedCount = 0,
    }, Stats)
end

function Stats.reset(self: any)
    self.StartedAt = os.time()
    self.Cycles = 0
    self.Pressed = 0
    self.LastCycle = nil
    self.CoinPickups = 0
    table.clear(self.Tracked)
    self.TrackedCount = 0
end

function Stats.cycle(self: any, info: any)
    self.Cycles += 1
    self.Pressed += info.gold
    self.LastCycle = info.at
end

function Stats.coins(self: any, entries: { any }, limit: number)
    local tracked = self.Tracked
    for id, instance in tracked do
        if instance.Parent == nil then
            tracked[id] = nil
            self.TrackedCount -= 1
            self.CoinPickups += 1
        end
    end
    local sent = 0
    for _, entry in entries do
        local id = entry.entityId
        if id ~= nil then
            sent += 1
            if sent > limit then
                break
            end
            if tracked[id] == nil and self.TrackedCount < COIN_TRACK_LIMIT then
                tracked[id] = entry.instance
                self.TrackedCount += 1
            end
        end
    end
end

function Stats.chests(self: any): { any }
    local selected = if self.Gold ~= nil then self.Gold.Chest.Selected else nil
    if selected ~= nil and selected.Parent ~= nil then
        return { selected }
    end
    local list = {}
    for _, entry in self.Game.finder.chests(CHEST_RANGE) do
        table.insert(list, entry.instance)
    end
    return list
end

local function add(counts: Counts, name: string, amount: number)
    local kind = Items.kind(name)
    if kind == "gold" then
        counts.gold += amount
    elseif kind == "bar" then
        counts.bars += amount
    end
end

function Stats.inChest(self: any): Counts
    local counts = { gold = 0, bars = 0 }
    for _, chest in self:chests() do
        for _, item in self.Game.chests.contents(chest) do
            add(counts, item.name, item.quantity)
        end
    end
    return counts
end

function Stats.outside(self: any): Counts
    local Game = self.Game
    local counts = { gold = 0, bars = 0 }
    for _, slot in Game.inventory.items() do
        add(counts, slot.name, slot.quantity)
    end
    for _, entry in Items.loose(Game, nil) do
        add(counts, entry.name, Game.inventory.quantityOf(entry.instance))
    end
    return counts
end

function Stats.pressCoins(self: any): number?
    return PressReader.read(self.Game)
end

function Stats.snapshot(self: any): any
    local Game = self.Game
    local now = os.time()
    local runtime = math.max(0, now - self.StartedAt)
    local player = Game.world.LocalPlayer
    return {
        runtime = runtime,
        chest = self:inChest(),
        outside = self:outside(),
        pressCoins = self:pressCoins(),
        calculatedCoins = self.CoinPickups * COIN_VALUE,
        hunger = Game.inventory.hunger(),
        account = Game.inventory.topbar().coins,
        time = os.date("%H:%M", now),
        cycles = self.Cycles,
        pressed = self.Pressed,
        perHour = if runtime >= 60 then self.Pressed / runtime * 3600 else nil,
        lastCycle = self.LastCycle,
        name = if player ~= nil then player.Name else "Unknown",
        userId = if player ~= nil then player.UserId else 0,
        at = now,
    }
end

return Stats
end
modules["goldfarm/webhook/vault"] = function(...)

local Vault = {}
Vault.__index = Vault

Vault.LIMIT = 30
Vault.NAME_LENGTH = 24
Vault.FILE = "webhooks.json"

local FORMAT = 1
local PREVIEW_DIGITS = 6

export type Entry = { name: string, url: string }

function Vault.cleanName(text: any): string
    local value = string.match(tostring(text or ""), "^%s*(.-)%s*$") or ""
    value = string.gsub(value, "%c", " ")
    if utf8.len(value) == nil then
        return string.sub(value, 1, Vault.NAME_LENGTH)
    end
    local cut = utf8.offset(value, Vault.NAME_LENGTH + 1)
    if cut ~= nil then
        value = string.sub(value, 1, cut - 1)
    end
    return string.match(value, "^(.-)%s*$") or value
end

function Vault.preview(url: string): string
    local id = string.match(url, "/webhooks/(%d+)/") or ""
    return "…/webhooks/" .. string.sub(id, 1, PREVIEW_DIGITS) .. "…"
end

function Vault.new(folder: string, http: any, valid: (any) -> boolean): any
    local self = setmetatable({
        Folder = folder,
        Path = folder .. "/" .. Vault.FILE,
        Http = http,
        Valid = valid,
        Entries = {} :: { Entry },
        ActiveName = nil :: string?,
    }, Vault)
    self:read()
    return self
end

function Vault.index(self: any, name: string): number?
    local key = string.lower(name)
    for index, entry in self.Entries do
        if string.lower(entry.name) == key then
            return index
        end
    end
    return nil
end

function Vault.has(self: any, name: string): boolean
    return self:index(name) ~= nil
end

function Vault.count(self: any): number
    return #self.Entries
end

function Vault.urlOf(self: any, name: string): string?
    local index = self:index(name)
    return if index then self.Entries[index].url else nil
end

function Vault.nameOfUrl(self: any, url: any): string?
    if type(url) ~= "string" or url == "" then
        return nil
    end
    for _, entry in self.Entries do
        if entry.url == url then
            return entry.name
        end
    end
    return nil
end

function Vault.autoName(self: any): string
    local number = #self.Entries + 1
    while self:has("Account " .. tostring(number)) do
        number += 1
    end
    return "Account " .. tostring(number)
end

function Vault.put(self: any, name: string, url: string): boolean
    local index = self:index(name)
    if index ~= nil then
        self.Entries[index].url = url
        return true
    end
    if #self.Entries >= Vault.LIMIT then
        return false
    end
    table.insert(self.Entries, { name = name, url = url })
    return true
end

function Vault.remove(self: any, name: string)
    local index = self:index(name)
    if index == nil then
        return
    end
    local removed = self.Entries[index].name
    table.remove(self.Entries, index)
    if self.ActiveName ~= nil and string.lower(self.ActiveName) == string.lower(removed) then
        self.ActiveName = nil
    end
end

function Vault.activeUrl(self: any): string?
    local name = self.ActiveName
    return if name ~= nil then self:urlOf(name) else nil
end

function Vault.read(self: any)
    table.clear(self.Entries)
    self.ActiveName = nil
    local ok, data = pcall(function(): any
        if not isfile(self.Path) then
            return nil
        end
        return self.Http:JSONDecode(readfile(self.Path))
    end)
    if not ok or type(data) ~= "table" or type(data.entries) ~= "table" then
        return
    end
    for _, item in data.entries do
        if type(item) == "table" and type(item.url) == "string" and self.Valid(item.url) then
            local name = Vault.cleanName(item.name)
            if name ~= "" and #self.Entries < Vault.LIMIT then
                self:put(name, item.url)
            end
        end
    end
    if type(data.active) == "string" and self:has(data.active) then
        local index = self:index(data.active) :: number
        self.ActiveName = self.Entries[index].name
    end
end

function Vault.write(self: any): boolean
    return (pcall(function()
        local path = ""
        for _, piece in string.split(self.Folder, "/") do
            path = if path == "" then piece else path .. "/" .. piece
            if not isfolder(path) then
                makefolder(path)
            end
        end
        local list = {}
        for _, entry in self.Entries do
            table.insert(list, { name = entry.name, url = entry.url })
        end
        writefile(self.Path, self.Http:JSONEncode({ version = FORMAT, active = self.ActiveName, entries = list }))
    end))
end

return Vault
end
modules["main"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")
local Changelog: typeof(require("./changelog")) = import("changelog")
local Game: typeof(require("./game")) = import("game")
local FarmMode: any = import("farm")
local Presets: typeof(require("./presets")) = import("presets")
local Rocks: typeof(require("./rocks")) = import("rocks")
local SpawnGate: typeof(require("./spawngate")) = import("spawngate")
local Tabs: { { Name: string, Module: any } } = import("tabs/index")

local REGISTRY = "__BoogaUtilitiesStop"
local HUB_HOOK = "__BoogaOnScriptUnloaded"

type Map = { [string]: any }

local function stopPrevious()
    local previous = getgenv()[REGISTRY]
    if type(previous) == "function" then
        pcall(previous)
    end
end

return function(OkloUI: any, reload: () -> (), Loader: any): Map?
    stopPrevious()
    local running = true
    local ui: any
    local defaults: Map = {}
    for _, entry in Tabs do
        for flag, value in entry.Module.Defaults do
            defaults[flag] = value
        end
    end
    local context, dispose = Context.new(function()
        return ui
    end, defaults)
    Game.init()

    local objects: { any } = {}
    local function stop()
        if not running then
            return
        end
        running = false
        getgenv()[REGISTRY] = nil
        dispose()
        for index = #objects, 1, -1 do
            pcall(function()
                objects[index]:shutdown()
            end)
        end
        Game.destroy()
        local hook = getgenv()[HUB_HOOK]
        if type(hook) == "function" then
            pcall(hook, "Booga Utilities")
        end
    end

    local farmMode = FarmMode.new(context)

    ui = OkloUI.new({
        Title = "oklo: BU",
        Subtitle = "booga booga",
        Version = Changelog.VERSION,
        Changelog = Changelog,
        Id = "Booga Utilities",
        Folder = Context.FOLDER,
        ConfigFolder = Context.CONFIGS,
        Logo = { Emblem = true },
        Footer = "oklo",
        Discord = "https://discord.gg/oklo",
        FirstRunInvite = true,
        Thanks = true,
        Width = 879,
        CompactSidebar = false,
        SidebarWidth = 192,
        Height = 605,
        Theme = "Rosewood",
        FarmMode = function(): any
            return farmMode:build()
        end,
        OnUnload = stop,
        OnReload = reload,
    })

    Presets.install(Context.FOLDER .. "/" .. Context.CONFIGS)

    for _, entry in Tabs do
        local ok, object = pcall(entry.Module.new, context)
        if ok then
            table.insert(objects, object)
            pcall(function()
                object:build(ui)
            end)
        end
    end

    local runService: any = game:GetService("RunService")
    context.connect(runService.RenderStepped, function(dt: number)
        for _, object in objects do
            if object.step then
                pcall(object.step, object, dt)
            end
        end
    end)
    ui:onFrame(function(frame: Map)
        for _, object in objects do
            if object.frame then
                pcall(object.frame, object, frame.Canvas)
            end
        end
    end)
    ui:home({
        QuickLabel = "Quick Settings",
        QuickStart = {
            { Title = "Start Path", Icon = "map-pin", Flag = "GoldStartPath" },
            { Title = "Hit Aura", Icon = "swords", Flag = "GoldHitAura" },
            { Title = "Auto Plant", Icon = "wheat", Flag = "FarmAutoPlant" },
            { Title = "Auto Harvest", Icon = "hand", Flag = "FarmAutoHarvest" },
        },
    })
    ui:start()
    SpawnGate.start(context, ui, SpawnGate.flags(Tabs))
    Rocks.start(context)
    getgenv()[REGISTRY] = function()
        ui:unload()
    end

    local api: Map = {}
    api.Game = Game
    function api.Stop()
        ui:unload()
    end
    return api
end
end
modules["plantfarm/farm"] = function(...)

local import: (string) -> any = ...
local Field: typeof(require("./field")) = import("plantfarm/field")
local Fruits: typeof(require("./fruits")) = import("plantfarm/fruits")
local Mover: typeof(require("./mover")) = import("plantfarm/mover")

local Farm = {}
Farm.__index = Farm

Farm.MOVEMENT_FLAGS = { "FarmTweenBox", "FarmTweenBush", "FarmTweenBoth" }

local MODES: { [string]: string } = { FarmTweenBox = "box", FarmTweenBush = "bush", FarmTweenBoth = "both" }

local HARVEST_RANGE = 30
local ACTION_EVERY = 0.04
local IDLE_EVERY = 0.1
local BLOCKED_EVERY = 0.2
local NOT_READY = 0.3
local PLANT_PER_TICK = 20
local STOCK_EVERY = 0.15
local COUNT_EVERY = 0.5
local FAIL_MEMORY = Field.FAIL_MEMORY
local REACH_START = 12
local REACH_MIN = 5
local REACH_MAX = 24
local PLANT_REACH_START = 12
local PLANT_REACH_MIN = 4

function Farm.new(context: any): any
    local self = setmetatable({
        ctx = context,
        Game = context.Game,
        Field = Field.new(),
        Mover = Mover.new(),
        Rotation = 0,
        Seeds = {} :: { any },
        SeedsAt = 0,
        Wanted = {} :: { string },
        AllFruits = false,
        FruitSnapshot = nil :: any,
        FruitList = {} :: { string },
        WantedFn = nil :: any,
        ActionAt = 0,
        CountAt = 0,
        Reach = REACH_START,
        PlantReach = PLANT_REACH_START,
        Running = false,
        Warned = {} :: { [string]: boolean },
    }, Farm)
    self.WantedFn = function(bush: any): boolean
        if self.AllFruits or (bush.box ~= nil and bush.box.ours) then
            return true
        end
        for _, fruit in self.Wanted do
            if string.find(bush.name, fruit, 1, true) then
                return true
            end
        end
        return false
    end
    self.Field.OnHarvest = function(bush: any, _now: number)
        if bush.farFail > 0 and bush.sentFrom < bush.farFail - 0.5 then
            self.Reach = math.clamp(math.min(self.Reach, bush.farFail - 2), REACH_MIN, REACH_MAX)
        elseif bush.sentFrom >= self.Reach - 3 then
            self.Reach = math.clamp(self.Reach + 1, REACH_MIN, REACH_MAX)
        end
    end
    self.Field.OnPlant = function(box: any, planted: boolean)
        local limit = self:plantRange()
        if planted then
            if box.sentFrom >= self.PlantReach - 2 then
                self.PlantReach = math.clamp(self.PlantReach + 1, PLANT_REACH_MIN, limit)
            end
        else
            self.PlantReach = math.clamp(math.min(self.PlantReach, box.sentFrom - 1.5), PLANT_REACH_MIN, limit)
        end
    end
    return self
end

local function on(self: any, flag: string): boolean
    return self.ctx.read(flag) == true
end

local function number(self: any, flag: string, minimum: number, maximum: number, fallback: number): number
    local value = tonumber(self.ctx.read(flag)) or fallback
    return math.clamp(value, minimum, maximum)
end

function Farm.searchRange(self: any): number
    return math.floor(number(self, "FarmSearchRange", 10, 200, 120))
end

function Farm.plantRange(self: any): number
    return math.floor(number(self, "FarmPlantRange", 5, 25, 18))
end

function Farm.moveSpeed(self: any): number
    return math.floor(number(self, "FarmMoveSpeed", 16, 20, 18))
end

function Farm.batch(self: any): number
    return math.floor(number(self, "FarmHarvestBatch", 5, 50, 25))
end

function Farm.mode(self: any): string?
    for _, flag in Farm.MOVEMENT_FLAGS do
        if on(self, flag) then
            return MODES[flag]
        end
    end
    return nil
end

local function anyOn(self: any): boolean
    return on(self, "FarmAutoPlant") or on(self, "FarmAutoHarvest") or Farm.mode(self) ~= nil
end

local function warnOnce(self: any, key: string, text: string)
    if self.Warned[key] then
        return
    end
    self.Warned[key] = true
    self.ctx.notify(text)
end

local function packetReady(self: any, name: string, feature: string): boolean
    local Game = self.Game
    if Game.packets.has(name) then
        self.Warned[name] = nil
        return true
    end
    local status = Game.status()
    warnOnce(self, name, string.format("%s: %s packet not found (ids: %s). %s", feature, name, tostring(status.source), Game.observer.hint(name)))
    return false
end

local function unchanged(self: any, value: any): boolean
    local snapshot = self.FruitSnapshot
    if snapshot == nil then
        return false
    end
    if type(value) ~= "table" then
        return snapshot.map == nil and snapshot.value == value
    end
    local map = snapshot.map
    if map == nil or snapshot.value ~= value then
        return false
    end
    local count = 0
    for key, on in value do
        count += 1
        if map[key] ~= on then
            return false
        end
    end
    return count == snapshot.count
end

local function remember(self: any, value: any)
    if type(value) ~= "table" then
        self.FruitSnapshot = { value = value, map = nil, count = 0 }
        return
    end
    local map: { [any]: any } = {}
    local count = 0
    for key, on in value do
        map[key] = on
        count += 1
    end
    self.FruitSnapshot = { value = value, map = map, count = count }
end

local function readFruits(self: any)
    local value = self.ctx.read("FarmPlantFruit")
    if unchanged(self, value) then
        return self.FruitList
    end
    local list = Fruits.selected(value)
    self.AllFruits = #list >= #self.Game.constants.PLANT_FRUITS
    local lower: { string } = {}
    for _, fruit in list do
        table.insert(lower, string.lower(fruit))
    end
    self.Wanted = lower
    self.FruitList = list
    remember(self, value)
    return list
end

function Farm.seeds(self: any, now: number): { any }
    if now >= self.SeedsAt then
        self.SeedsAt = now + STOCK_EVERY
        self.Seeds = Fruits.stock(readFruits(self), self.Field:inflight())
    end
    return self.Seeds
end

function Farm.canPlant(self: any, now: number): boolean
    for _, seed in self:seeds(now) do
        if seed.left > 0 then
            return true
        end
    end
    return false
end

local function nextSeed(self: any, seeds: { any }): any
    local count = #seeds
    for offset = 1, count do
        local index = (self.Rotation + offset - 1) % count + 1
        local seed = seeds[index]
        if seed.left > 0 then
            self.Rotation = index
            return seed
        end
    end
    return nil
end

function Farm.plantBox(self: any, box: any, distance: number, now: number): boolean
    if not packetReady(self, "InteractStructure", "Plant Farm") then
        return false
    end
    local seed = nextSeed(self, self:seeds(now))
    if seed == nil then
        return false
    end
    if not self.Game.queue("InteractStructure", box.id, seed.id) then
        return false
    end
    seed.left -= 1
    box.sentAt = now
    box.sentFrom = distance
    box.confirming = true
    box.fruit = seed.fruit
    return true
end

function Farm.plantAround(self: any, origin: Vector3, range: number, now: number): number
    if not self:canPlant(now) then
        return 0
    end
    local sent = 0
    for _, entry in self.Field:emptyBoxes(origin, math.min(range, self.PlantReach), now) do
        local box = entry.box
        local remembered = box.failFrom > 0 and now - box.sentAt < FAIL_MEMORY
        if not remembered or entry.distance < box.failFrom - 0.5 then
            if not self:plantBox(box, entry.distance, now) then
                break
            end
            sent += 1
            if sent >= PLANT_PER_TICK then
                break
            end
        end
    end
    return sent
end

local function mark(bush: any, distance: number, now: number)
    bush.sentAt = now
    bush.sentFrom = distance
    bush.tries += 1
    bush.checked = false
end

function Farm.pickup(self: any, bush: any, distance: number, now: number): boolean
    if not packetReady(self, "Pickup", "Plant Farm") then
        return false
    end
    if self.Game.actions.pickup({ bush.id }, true) > 0 then
        mark(bush, distance, now)
        return true
    end
    return false
end

function Farm.harvestAround(self: any, origin: Vector3, range: number, now: number, wanted: ((any) -> boolean)?, careful: boolean): number
    if not packetReady(self, "Pickup", "Plant Farm") then
        return 0
    end
    local limit = self:batch()
    local ids: { number } = {}
    local picked: { any } = {}
    for _, entry in self.Field:readyBushes(origin, range, now, wanted) do
        local bush = entry.bush
        local remembered = careful and bush.farFail > 0 and now - bush.sentAt < FAIL_MEMORY
        if not remembered or entry.distance < bush.farFail - 0.5 then
            table.insert(ids, bush.id)
            table.insert(picked, entry)
            if #ids >= limit then
                break
            end
        end
    end
    if #ids == 0 or self.Game.actions.pickup(ids, true) == 0 then
        return 0
    end
    for _, entry in picked do
        mark(entry.bush, entry.distance, now)
    end
    return #ids
end

local function ready(self: any): boolean
    local World = self.Game.world
    return World.root() ~= nil and World.isSpawned()
end

local function tick(self: any): number
    local Game = self.Game
    if not ready(self) then
        self.Mover:release()
        return NOT_READY
    end
    if Game.world.folder("Deployables") == nil then
        warnOnce(self, "deployables", "Plant Farm: no Deployables folder in this world")
    else
        self.Warned.deployables = nil
    end
    local now = os.clock()
    local field = self.Field
    field:start()
    field:refresh(now)
    readFruits(self)
    local root = Game.world.root()
    local origin: Vector3 = root.Position
    local mode = self:mode()
    if now >= self.CountAt then
        self.CountAt = now + COUNT_EVERY
        field:count(origin, self:searchRange())
    end
    if now >= self.ActionAt then
        self.ActionAt = now + ACTION_EVERY
        local chasing = mode == "bush" or mode == "both"
        if on(self, "FarmAutoHarvest") then
            self:harvestAround(origin, HARVEST_RANGE, now, nil, chasing)
        end
        if chasing then
            self:harvestAround(origin, self.Reach, now, self.WantedFn, true)
        end
        if on(self, "FarmAutoPlant") or mode == "box" or mode == "both" then
            self:plantAround(origin, self:plantRange(), now)
        end
    end
    if mode == nil then
        self.Mover:release()
        return IDLE_EVERY
    end
    if on(self, "GoldStartPath") or Game.movement.isFrozen() then
        self.Mover:release()
        return BLOCKED_EVERY
    end
    return self.Mover:tick(self, mode, root, now)
end

local function cleanup(self: any)
    self.Mover:reset()
    self.Field:stop()
    self.Seeds = {}
    self.SeedsAt = 0
    self.FruitSnapshot = nil
    self.ActionAt = 0
    self.CountAt = 0
end

function Farm.sync(self: any)
    if self.Running or not self.ctx.alive() or not anyOn(self) then
        return
    end
    self.Running = true
    self.ctx.spawn(function()
        while self.Running and self.ctx.alive() and anyOn(self) do
            local ok, delay = pcall(tick, self)
            if not self.ctx.wait(if ok and type(delay) == "number" then delay else 0.25) then
                break
            end
        end
        if self.Running then
            self.Running = false
            cleanup(self)
        end
    end)
end

function Farm.counts(self: any): any
    return self.Field.Counts
end

function Farm.shutdown(self: any)
    self.Running = false
    cleanup(self)
    table.clear(self.Warned)
end

return Farm
end
modules["plantfarm/field"] = function(...)

local import: (string) -> any = ...
local Game: typeof(require("../game")) = import("game")

local Field = {}
Field.__index = Field

export type Box = {
    model: any,
    id: number,
    position: Vector3,
    sentAt: number,
    sentFrom: number,
    failFrom: number,
    confirming: boolean,
    fruit: string?,
    strikes: number,
    skipUntil: number,
    plantedAt: number?,
    seenAt: number?,
    ours: boolean,
    planted: boolean,
    bush: Bush?,
}

export type Bush = {
    model: any,
    id: number,
    position: Vector3,
    name: string,
    box: Box?,
    sentAt: number,
    sentFrom: number,
    tries: number,
    skipUntil: number,
    farFail: number,
    checked: boolean,
}

export type Counts = { boxes: number, empty: number, growing: number, grown: number }

local BOX_NAME = "plantbox"
local LINK_FLAT = 5
local LINK_HEIGHT = 10
local BOX_RESCAN = 3
local BUSH_RESCAN = 1
local RETRY_ID = 0.4
local UPDATE_EVERY = 0.08
local CONFIRM = 0.6
local STRIKES = 3
local STRIKE_SKIP = 8
local HOLD = 0.45
local PERSIST_TRIES = 3
local PERSIST_SKIP = 2.5

local LOWER_HARVESTABLES: { string } = {}
for _, name in Game.constants.HARVESTABLES do
    table.insert(LOWER_HARVESTABLES, string.lower(name))
end

Field.HOLD = HOLD
Field.FAIL_MEMORY = 4

function Field.new()
    return setmetatable({
        Boxes = {} :: { [any]: Box },
        Bushes = {} :: { [any]: Bush },
        Retry = {} :: { [any]: number },
        NotBush = setmetatable({}, { __mode = "k" }) :: any,
        IsBush = setmetatable({}, { __mode = "k" }) :: any,
        Seen = {} :: { [any]: boolean },
        EmptyList = {} :: { any },
        EmptyPool = {} :: { any },
        ReadyList = {} :: { any },
        ReadyPool = {} :: { any },
        Links = {} :: { any },
        Watched = {} :: { [any]: boolean },
        BoxDirty = true,
        BushDirty = true,
        BoxAt = 0,
        BushAt = 0,
        UpdateAt = 0,
        Active = false,
        Counts = { boxes = 0, empty = 0, growing = 0, grown = 0 } :: Counts,
        OnHarvest = nil :: ((Bush, number) -> ())?,
        OnPlant = nil :: ((Box, boolean) -> ())?,
    }, Field)
end

local function flat(a: Vector3, b: Vector3): number
    local dx, dz = a.X - b.X, a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

Field.flat = flat

local function bushCheck(model: any): boolean
    if not model:IsA("Model") or Game.world.normalize(model.Name) == BOX_NAME then
        return false
    end
    local lower = Game.world.lower(model.Name)
    for _, piece in LOWER_HARVESTABLES do
        if string.find(lower, piece, 1, true) then
            return true
        end
    end
    return false
end

local function isBush(self: any, model: any): boolean
    if self.NotBush[model] then
        return false
    end
    local name = self.IsBush[model]
    if name ~= nil and name == model.Name then
        return true
    end
    local ok, result = pcall(bushCheck, model)
    if not ok or not result then
        self.IsBush[model] = nil
        self.NotBush[model] = true
        return false
    end
    self.IsBush[model] = model.Name
    return true
end

local function bushFolders(): ({ any }, boolean)
    local World = Game.world
    local crops = World.folder("Crops")
    if crops ~= nil then
        return { crops }, true
    end
    local list: { any } = {}
    for _, name in { "Resources", "Deployables" } do
        local folder = World.folder(name)
        if folder ~= nil then
            table.insert(list, folder)
        end
    end
    return list, false
end

local function link(self: any, bush: Bush)
    local best: Box? = nil
    local bestDistance = LINK_FLAT
    for _, box in self.Boxes :: { [any]: Box } do
        if math.abs(box.position.Y - bush.position.Y) <= LINK_HEIGHT then
            local distance = flat(box.position, bush.position)
            if distance <= bestDistance and (box.bush == nil or box.bush == bush) then
                best, bestDistance = box, distance
            end
        end
    end
    if best ~= nil then
        bush.box = best
        best.bush = bush
    end
end

local function dropBush(self: any, model: any, now: number)
    local bush: Bush? = self.Bushes[model]
    if bush == nil then
        return
    end
    self.Bushes[model] = nil
    local box = bush.box
    if box ~= nil and box.bush == bush then
        box.bush = nil
    end
    if bush.sentAt > 0 and now - bush.sentAt <= 2 and self.OnHarvest ~= nil then
        self.OnHarvest(bush, now)
    end
end

local function dropBox(self: any, model: any)
    local box: Box? = self.Boxes[model]
    if box == nil then
        return
    end
    self.Boxes[model] = nil
    local bush = box.bush
    if bush ~= nil and bush.box == box then
        bush.box = nil
    end
end

local function watch(self: any, folder: any, kind: string)
    if folder == nil or self.Watched[folder] then
        return
    end
    self.Watched[folder] = true
    local function dirty(child: any)
        if kind == "box" then
            if Game.world.normalize(child.Name) == BOX_NAME then
                self.BoxDirty = true
            end
        else
            self.BushDirty = true
        end
    end
    if kind == "box" then
        table.insert(self.Links, folder.ChildAdded:Connect(dirty))
        table.insert(self.Links, folder.ChildRemoved:Connect(function(child: any)
            if self.Boxes[child] ~= nil then
                dropBox(self, child)
            end
        end))
    else
        table.insert(self.Links, folder.DescendantAdded:Connect(dirty))
        table.insert(self.Links, folder.DescendantRemoving:Connect(function(child: any)
            if self.Bushes[child] ~= nil then
                dropBush(self, child, os.clock())
            end
            self.BushDirty = true
        end))
    end
end

local function unwatch(self: any)
    for _, connection in self.Links do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(self.Links)
    table.clear(self.Watched)
end

function Field.start(self: any)
    self.Active = true
end

function Field.stop(self: any)
    unwatch(self)
    table.clear(self.Boxes)
    table.clear(self.Bushes)
    table.clear(self.Retry)
    self.NotBush = setmetatable({}, { __mode = "k" })
    self.IsBush = setmetatable({}, { __mode = "k" })
    table.clear(self.Seen)
    table.clear(self.EmptyList)
    table.clear(self.EmptyPool)
    table.clear(self.ReadyList)
    table.clear(self.ReadyPool)
    self.BoxDirty = true
    self.BushDirty = true
    self.BoxAt = 0
    self.BushAt = 0
    self.UpdateAt = 0
    self.Active = false
    self.Counts = { boxes = 0, empty = 0, growing = 0, grown = 0 }
end

local function scanBoxes(self: any, now: number)
    local World = Game.world
    local folder = World.folder("Deployables")
    if folder == nil then
        return
    end
    watch(self, folder, "box")
    local seen: { [any]: boolean } = self.Seen
    table.clear(seen)
    local added = false
    for _, child in folder:GetChildren() do
        if Game.world.normalize(child.Name) == BOX_NAME then
            seen[child] = true
            if self.Boxes[child] == nil then
                local retry = self.Retry[child]
                if retry == nil or now >= retry then
                    local id = World.entityId(child)
                    local part = World.partOf(child)
                    if id ~= nil and part ~= nil then
                        self.Retry[child] = nil
                        self.Boxes[child] = {
                            model = child,
                            id = id,
                            position = part.Position,
                            sentAt = 0,
                            sentFrom = 0,
                            failFrom = 0,
                            confirming = false,
                            fruit = nil,
                            strikes = 0,
                            skipUntil = 0,
                            plantedAt = nil,
                            seenAt = nil,
                            ours = false,
                            planted = false,
                            bush = nil,
                        }
                        added = true
                    else
                        self.Retry[child] = now + RETRY_ID
                        self.BoxDirty = true
                    end
                end
            end
        end
    end
    for model in self.Boxes do
        if not seen[model] or model.Parent == nil then
            dropBox(self, model)
        end
    end
    if added then
        for _, bush in self.Bushes :: { [any]: Bush } do
            if bush.box == nil then
                link(self, bush)
            end
        end
    end
end

local function scanBushes(self: any, now: number)
    local World = Game.world
    local folders, crops = bushFolders()
    local seen: { [any]: boolean } = self.Seen
    table.clear(seen)
    for _, folder in folders do
        if crops then
            watch(self, folder, "bush")
        end
        for _, model in World.children(folder, true) do
            if isBush(self, model) then
                seen[model] = true
                if self.Bushes[model] == nil then
                    local retry = self.Retry[model]
                    if retry == nil or now >= retry then
                        local id = World.entityId(model, nil, true)
                        local position = World.positionOf(model)
                        if id ~= nil and position ~= nil then
                            self.Retry[model] = nil
                            local bush: Bush = {
                                model = model,
                                id = id,
                                position = position,
                                name = string.lower(tostring(model.Name)),
                                box = nil,
                                sentAt = 0,
                                sentFrom = 0,
                                tries = 0,
                                skipUntil = 0,
                                farFail = 0,
                                checked = true,
                            }
                            self.Bushes[model] = bush
                            link(self, bush)
                        else
                            self.Retry[model] = now + RETRY_ID
                            self.BushDirty = true
                        end
                    end
                end
            end
        end
    end
    for model in self.Bushes do
        if not seen[model] or model.Parent == nil then
            dropBush(self, model, now)
        end
    end
    for model in self.Retry do
        if model.Parent == nil then
            self.Retry[model] = nil
        end
    end
end

local function updateBoxes(self: any, now: number)
    for model, box in self.Boxes :: { [any]: Box } do
        if model.Parent == nil then
            dropBox(self, model)
            continue
        end
        local planted = model:FindFirstChild("Seed") ~= nil
        box.planted = planted
        if box.confirming then
            if planted or box.bush ~= nil then
                box.confirming = false
                box.strikes = 0
                box.failFrom = 0
                box.plantedAt = box.sentAt
                box.ours = true
                if self.OnPlant ~= nil then
                    self.OnPlant(box, true)
                end
            elseif now - box.sentAt >= CONFIRM then
                box.confirming = false
                box.failFrom = box.sentFrom
                box.strikes += 1
                if self.OnPlant ~= nil then
                    self.OnPlant(box, false)
                end
                if box.strikes >= STRIKES then
                    box.strikes = 0
                    box.skipUntil = now + STRIKE_SKIP
                end
            end
        end
        if planted or box.bush ~= nil then
            if box.seenAt == nil then
                box.seenAt = now
            end
        elseif not box.confirming then
            box.plantedAt = nil
            box.seenAt = nil
            box.ours = false
        end
    end
end

local function updateBushes(self: any, now: number)
    for model, bush in self.Bushes :: { [any]: Bush } do
        if model.Parent == nil then
            dropBush(self, model, now)
        elseif bush.sentAt > 0 and now - bush.sentAt >= HOLD then
            if not bush.checked then
                bush.checked = true
                bush.farFail = bush.sentFrom
            end
            if bush.tries >= PERSIST_TRIES then
                bush.tries = 0
                bush.skipUntil = now + PERSIST_SKIP
            end
        end
    end
end

function Field.refresh(self: any, now: number)
    if not self.Active then
        return
    end
    if self.BoxDirty or now >= self.BoxAt then
        self.BoxDirty = false
        self.BoxAt = now + BOX_RESCAN
        scanBoxes(self, now)
    end
    if self.BushDirty or now >= self.BushAt then
        self.BushDirty = false
        self.BushAt = now + BUSH_RESCAN
        scanBushes(self, now)
    end
    if now >= self.UpdateAt then
        self.UpdateAt = now + UPDATE_EVERY
        updateBoxes(self, now)
        updateBushes(self, now)
    end
end

function Field.empty(box: Box, now: number): boolean
    return not box.planted and box.bush == nil and not box.confirming and box.skipUntil <= now and box.model.Parent ~= nil
end

local function nearer(a: any, b: any): boolean
    return a.distance < b.distance
end

function Field.emptyBoxes(self: any, origin: Vector3, range: number, now: number): { { box: Box, distance: number } }
    local list: { { box: Box, distance: number } } = self.EmptyList
    local pool: { any } = self.EmptyPool
    table.clear(list)
    local count = 0
    for _, box in self.Boxes :: { [any]: Box } do
        if Field.empty(box, now) then
            local distance = (box.position - origin).Magnitude
            if distance <= range then
                count += 1
                local entry = pool[count]
                if entry == nil then
                    entry = { box = box, distance = distance }
                    pool[count] = entry
                else
                    entry.box = box
                    entry.distance = distance
                end
                list[count] = entry
            end
        end
    end
    table.sort(list, nearer)
    return list
end

function Field.ready(bush: Bush, now: number): boolean
    return bush.checked and bush.skipUntil <= now and now - bush.sentAt >= HOLD and bush.model.Parent ~= nil
end

function Field.readyBushes(self: any, origin: Vector3, range: number, now: number, wanted: ((Bush) -> boolean)?): { { bush: Bush, distance: number } }
    local list: { { bush: Bush, distance: number } } = self.ReadyList
    local pool: { any } = self.ReadyPool
    table.clear(list)
    local count = 0
    for _, bush in self.Bushes :: { [any]: Bush } do
        if Field.ready(bush, now) and (wanted == nil or wanted(bush)) then
            local distance = (bush.position - origin).Magnitude
            if distance <= range then
                count += 1
                local entry = pool[count]
                if entry == nil then
                    entry = { bush = bush, distance = distance }
                    pool[count] = entry
                else
                    entry.bush = bush
                    entry.distance = distance
                end
                list[count] = entry
            end
        end
    end
    table.sort(list, nearer)
    return list
end

function Field.inflight(self: any): { [string]: number }
    local counts: { [string]: number } = {}
    for _, box in self.Boxes :: { [any]: Box } do
        local fruit = box.fruit
        if box.confirming and fruit ~= nil then
            counts[fruit] = (counts[fruit] or 0) + 1
        end
    end
    return counts
end

function Field.oldest(self: any, origin: Vector3, range: number): Box?
    local best: Box? = nil
    local bestKey = math.huge
    local bestOurs = false
    for _, box in self.Boxes :: { [any]: Box } do
        if (box.planted or box.bush ~= nil) and (box.position - origin).Magnitude <= range then
            local key = box.plantedAt or box.seenAt or math.huge
            local better = false
            if best == nil then
                better = true
            elseif box.ours ~= bestOurs then
                better = box.ours
            else
                better = key < bestKey
            end
            if better then
                best, bestKey, bestOurs = box, key, box.ours
            end
        end
    end
    return best
end

function Field.count(self: any, origin: Vector3, range: number): Counts
    local counts: Counts = { boxes = 0, empty = 0, growing = 0, grown = 0 }
    for _, box in self.Boxes :: { [any]: Box } do
        if (box.position - origin).Magnitude <= range then
            counts.boxes += 1
            if box.bush ~= nil then
                counts.grown += 1
            elseif box.planted or box.confirming then
                counts.growing += 1
            else
                counts.empty += 1
            end
        end
    end
    self.Counts = counts
    return counts
end

return Field
end
modules["plantfarm/fruits"] = function(...)

local import: (string) -> any = ...
local Game: typeof(require("../game")) = import("game")

local Fruits = {}

Fruits.DEFAULT = "Bloodfruit"

export type Seed = { fruit: string, id: number, left: number }

function Fruits.selected(value: any): { string }
    local list: { string } = {}
    if type(value) == "table" then
        for key, on in value do
            if type(key) == "string" and key ~= "" and on == true then
                table.insert(list, key)
            elseif type(key) == "number" and type(on) == "string" and on ~= "" then
                table.insert(list, on)
            end
        end
    elseif type(value) == "string" and value ~= "" then
        table.insert(list, value)
    end
    table.sort(list)
    if #list == 0 then
        table.insert(list, Fruits.DEFAULT)
    end
    return list
end

function Fruits.summary(value: any): string
    local list = Fruits.selected(value)
    if #list == 1 then
        return list[1]
    end
    if #list >= #Game.constants.PLANT_FRUITS then
        return "All"
    end
    return list[1] .. " +" .. tostring(#list - 1)
end

function Fruits.copy(value: any): { [string]: boolean }
    local result: { [string]: boolean } = {}
    for _, fruit in Fruits.selected(value) do
        result[fruit] = true
    end
    return result
end

local function held(): { [string]: number }?
    local Inventory = Game.inventory
    if not Inventory.ready() then
        return nil
    end
    local counts: { [string]: number } = {}
    for _, slot in Inventory.items() do
        local key = Inventory.normalize(slot.name)
        counts[key] = (counts[key] or 0) + slot.quantity
    end
    return counts
end

local function amount(counts: { [string]: number }, name: string): number
    local Inventory = Game.inventory
    local total = counts[Inventory.normalize(name)] or 0
    local aliases: { string } = Game.constants.ITEM_ALIASES[name] or {}
    for _, alias in aliases do
        total += counts[Inventory.normalize(alias)] or 0
    end
    return total
end

function Fruits.stock(list: { string }, inflight: { [string]: number }): { Seed }
    local counts = held()
    local seeds: { Seed } = {}
    for _, fruit in list do
        local id = Game.inventory.seedId(fruit)
        if id ~= nil then
            local left = math.huge
            if counts ~= nil then
                left = amount(counts, fruit) + amount(counts, fruit .. " Seed") - (inflight[fruit] or 0)
            end
            if left > 0 then
                table.insert(seeds, { fruit = fruit, id = id, left = left })
            end
        end
    end
    return seeds
end

return Fruits
end
modules["plantfarm/mover"] = function(...)

local import: (string) -> any = ...
local Game: typeof(require("../game")) = import("game")
local Field: typeof(require("./field")) = import("plantfarm/field")

local Mover = {}
Mover.__index = Mover

local MOVE_TICK = 0.03
local IDLE_TICK = 0.12
local REPICK = 0.2
local ARRIVE = 2.5
local CLOSE_EXTRA = 1.5
local HEIGHT = 12
local IDLE_RELEASE = 1.5
local GOAL_SKIP = 4
local BUSH_SKIP = 6
local BOX_SKIP = 8
local GROUND_DEPTH = 40
local CHAIN = 4

local PRIORITY: { [string]: number } = { bush = 1, box = 2, wait = 3 }

type Target = {
    kind: string,
    model: any,
    item: any,
    goal: Vector3,
    closeReach: number,
    close: boolean,
    sends: number,
}

function Mover.new()
    return setmetatable({
        Target = nil :: Target?,
        Root = nil :: any,
        Owns = false,
        IdleSince = 0,
        RepickAt = 0,
        Skipped = {} :: { [any]: number },
    }, Mover)
end

local function groundY(position: Vector3, lift: number): number?
    local hit = Game.movement.groundBelow(position + Vector3.new(0, lift, 0), lift + GROUND_DEPTH)
    return if hit then hit.Y else nil
end

local function edge(model: any, center: Vector3, near: Vector3): Vector3?
    local part = Game.world.partOf(model)
    if part == nil then
        return nil
    end
    local size: Vector3 = part.Size
    local approach = center
    local offset = Vector3.new(near.X - center.X, 0, near.Z - center.Z)
    if offset.Magnitude > 0.5 then
        approach = center + offset.Unit * (math.max(size.X, size.Z) * 0.5 + 2.5)
    end
    local ground = groundY(approach, math.max(size.Y, 8))
    return Vector3.new(approach.X, if ground then ground + 3 else center.Y + 1, approach.Z)
end

local function goalOf(kind: string, item: any, near: Vector3): Vector3?
    if kind == "bush" then
        local box = item.box
        if box ~= nil and box.model.Parent ~= nil then
            return edge(box.model, box.position, near)
        end
        local position: Vector3 = item.position
        local ground = groundY(position, 4)
        return Vector3.new(position.X, if ground then ground + 1 else position.Y + 1, position.Z)
    end
    return edge(item.model, item.position, near)
end

local function makeTarget(self: any, kind: string, item: any, origin: Vector3, now: number): Target?
    local goal = goalOf(kind, item, origin)
    if goal == nil then
        self.Skipped[item.model] = now + GOAL_SKIP
        return nil
    end
    local position: Vector3 = item.position
    local failed = if kind == "bush" then item.farFail elseif kind == "box" then item.failFrom else 0
    return {
        kind = kind,
        model = item.model,
        item = item,
        goal = goal,
        closeReach = Field.flat(goal, position) + CLOSE_EXTRA,
        close = failed > 0 and now - item.sentAt < Field.FAIL_MEMORY,
        sends = 0,
    }
end

local function skipped(self: any, model: any, now: number): boolean
    local until_ = self.Skipped[model]
    if until_ == nil then
        return false
    end
    if now >= until_ then
        self.Skipped[model] = nil
        return false
    end
    return true
end

local function choose(self: any, farm: any, mode: string, origin: Vector3, now: number): Target?
    local field = farm.Field
    local range = farm:searchRange()
    if mode ~= "box" then
        for _, entry in field:readyBushes(origin, range, now, farm.WantedFn) do
            if not skipped(self, entry.bush.model, now) then
                local target = makeTarget(self, "bush", entry.bush, origin, now)
                if target ~= nil then
                    return target
                end
            end
        end
    end
    if mode ~= "bush" and farm:canPlant(now) then
        for _, entry in field:emptyBoxes(origin, range, now) do
            if not skipped(self, entry.box.model, now) then
                local target = makeTarget(self, "box", entry.box, origin, now)
                if target ~= nil then
                    return target
                end
            end
        end
    end
    local oldest = field:oldest(origin, range)
    if oldest ~= nil and not skipped(self, oldest.model, now) then
        return makeTarget(self, "wait", oldest, origin, now)
    end
    return nil
end

local function valid(self: any, farm: any, target: Target, now: number): boolean
    local model = target.model
    if model.Parent == nil or skipped(self, model, now) then
        return false
    end
    local field = farm.Field
    local item = target.item
    if target.kind == "bush" then
        return field.Bushes[model] == item and item.skipUntil <= now
    end
    if field.Boxes[model] ~= item then
        return false
    end
    if target.kind == "wait" then
        return item.planted or item.bush ~= nil
    end
    if item.planted or item.bush ~= nil or item.skipUntil > now then
        return false
    end
    if item.confirming then
        return target.close
    end
    return farm:canPlant(now)
end

function Mover.release(self: any)
    self.Target = nil
    self.IdleSince = 0
    self.RepickAt = 0
    if self.Owns then
        self.Owns = false
        Game.drive.finish()
    end
end

function Mover.reset(self: any)
    self:release()
    self.Root = nil
    table.clear(self.Skipped)
end

local function act(self: any, farm: any, target: Target, distance: number, now: number): boolean
    local item = target.item
    if target.kind == "wait" then
        return false
    end
    local bush = target.kind == "bush"
    local pending = if bush then now - item.sentAt < Field.HOLD else item.confirming
    if pending then
        if not target.close then
            return true
        end
        target.sends = math.max(target.sends, 1)
        return false
    end
    if target.sends > 0 then
        item.skipUntil = now + (if bush then BUSH_SKIP else BOX_SKIP)
        return true
    end
    local sent = if bush then farm:pickup(item, distance, now) else farm:plantBox(item, distance, now)
    if not sent then
        self.Skipped[target.model] = now + GOAL_SKIP
        return true
    end
    target.sends = 1
    return not target.close
end

local function reachOf(farm: any, target: Target): number
    if target.close then
        return target.closeReach
    end
    if target.kind == "bush" then
        return math.max(farm.Reach, target.closeReach)
    end
    return math.max(math.min(farm.PlantReach, farm:plantRange()) - 1, target.closeReach)
end

local function better(current: Target, candidate: Target?): boolean
    if candidate == nil then
        return false
    end
    local a, b = PRIORITY[current.kind], PRIORITY[candidate.kind]
    if b < a then
        return true
    end
    return current.kind == "wait" and candidate.kind == "wait" and candidate.model ~= current.model
end

function Mover.tick(self: any, farm: any, mode: string, root: any, now: number): number
    if self.Root ~= root then
        self.Target = nil
        self.Root = root
    end
    local origin: Vector3 = root.Position
    for _ = 1, CHAIN do
        local target: Target? = self.Target
        if target ~= nil and not valid(self, farm, target, now) then
            target = nil
            self.Target = nil
        end
        if target ~= nil and now >= self.RepickAt then
            self.RepickAt = now + REPICK
            local candidate = choose(self, farm, mode, origin, now)
            if better(target, candidate) then
                target = candidate
                self.Target = candidate
            end
        end
        if target == nil then
            self.RepickAt = now + REPICK
            target = choose(self, farm, mode, origin, now)
            self.Target = target
        end
        if target == nil then
            if self.Owns then
                Game.drive.halt()
            end
            if self.IdleSince == 0 then
                self.IdleSince = now
            elseif now - self.IdleSince >= IDLE_RELEASE then
                self:release()
            end
            return IDLE_TICK
        end
        self.IdleSince = 0
        local position: Vector3 = if target.kind == "wait" then target.goal else target.item.position
        local distance = Field.flat(origin, position)
        local reach = if target.kind == "wait" then ARRIVE else reachOf(farm, target)
        if distance > reach or math.abs(origin.Y - position.Y) > HEIGHT then
            self.Owns = true
            Game.drive.step(target.goal + Vector3.new(0, Game.drive.hover, 0), farm:moveSpeed())
            return MOVE_TICK
        end
        if self.Owns and (target.kind ~= "box" or target.close) then
            Game.drive.halt()
        end
        if not act(self, farm, target, (target.item.position - origin).Magnitude, now) then
            return MOVE_TICK
        end
        self.Target = nil
    end
    return MOVE_TICK
end

return Mover
end
modules["presets"] = function(...)

local Presets = {}

local NAME = "premade main gold farm"
local OLD = "premade gold farm"

local DATA = [==[{"AccentCol":"#EF7896","OptionKeybinds":{"GoldAutoSelectChest":"None","GoldAntiStuck":"None","MatDelete":"None","GoldStartPath":"P","GoldPickupAir":"None","NodeFarm":"None","MatSunEat":"None","MatSunMove":"None","GoldPickCoins":"None","MatSunFarm":"None","FarmTweenBox":"None","MatDropUntil":"None","FarmTweenBush":"None","GoldPauseNearPress":"None","FarmAutoHarvest":"None","FarmAutoPlant":"None","GoldChestAttract":"None","FarmTweenBoth":"None","GoldAutoOpenChest":"None","GoldRefillCampfire":"None","GoldPickupChest":"None","NodeIce":"None","GoldCoinPress":"None","NodeGold":"None"},"NavSide":"Left","AnimationIntensity":"1","AnimationsEnabled":"true","LightMode":"false","MainCol":"#211216","UIScale":"0.86","Roundness":"0.46","PremiumEffects":"true","UILayoutVersion":"1","ToggleRoundness":"0.55","Keybind":"RightShift","SnowAmount":"40","SnowTrans":"0.4","SnowSize":"2","UITrans":"1","Flags":{"GoldEditorDrag":"Ground","FarmSearchRange":"120","GoldAutoStartPath":"false","GoldEditorValidate":"true","MatDropKeep":"500","GoldPickupAir":"true","GoldWalkSpeed":"19","WebhookCooldown":"20","MatSunFarm":"true","FarmAutoHarvest":"false","FarmAutoPlant":"false","FarmTweenBoth":"false","GoldRefillCampfire":"true","FarmHarvestBatch":"50","WebhookOnCycle":"true","GoldEditorGap":"700","GoldPickupChest":"true","GoldShowPath":"true","GoldAntiStuck":"true","FarmPlantFruit":{"Bloodfruit":true},"WebhookEnabled":"false","FarmMoveSpeed":"18","GoldEditorStep":"1","GoldLockCamera":"false","GoldHitAura":"true","GoldAutoSelectChest":"true","MatDropUntil":"true","GoldAutoOpenChest":"false","GoldChestAttract":"true","GoldStartPath":"false","FarmPlantRange":"18","GoldSwitchSlots":"true","GoldWalkSpeedOn":"false","GoldPauseNearPress":"true","GoldEquipFirstSlot":"false","FarmTweenBush":"false","GoldPickCoins":"false","WebhookUsername":"true","FarmTweenBox":"false","GoldNodeDetect":"true","GoldCoinPress":"true","GoldCpuMode":"false"},"SnowSpeed":"20","UIFont":"1","Transparent":"false","HighPerformanceMode":"false","BackgroundEffect":"None","ButtonTrans":"1","SnowCol":"#FFFFFF"}]==]

function Presets.install(folder: string)
    pcall(function()
        if not isfolder(folder) then
            makefolder(folder)
        end
        writefile(folder .. "/" .. NAME .. ".json", DATA)
        local old = folder .. "/" .. OLD .. ".json"
        if isfile(old) then
            delfile(old)
        end
    end)
end

return Presets
end
modules["rocks"] = function(...)

local Rocks = {}

local NAME = "big rock"
local CHUNK = 1500

local function isRock(instance: any): boolean
    local ok, result = pcall(function(): boolean
        return string.lower(instance.Name) == NAME
    end)
    return ok and result
end

local function remove(instance: any)
    pcall(function()
        instance:Destroy()
    end)
end

function Rocks.start(context: any)
    local space = context.Game.world.workspace()
    if space == nil then
        return
    end
    context.connect(space.DescendantAdded, function(instance: any)
        if isRock(instance) then
            remove(instance)
        end
    end)
    context.spawn(function()
        local seen = 0
        for _, descendant in space:GetDescendants() do
            seen += 1
            if seen % CHUNK == 0 then
                task.wait()
            end
            if isRock(descendant) then
                remove(descendant)
            end
        end
    end)
end

return Rocks
end
modules["spawngate"] = function(...)

local SpawnGate = {}

local DELAY = 1.5
local POLL = 0.2

SpawnGate.TABS = { "gold", "materials", "utility", "farming" }

SpawnGate.EXEMPT = {
    GoldAutoStartPath = true,
    GoldEquipFirstSlot = true,
    GoldCpuMode = true,
    WebhookEnabled = true,
    WebhookOnCycle = true,
    WebhookUsername = true,
} :: { [string]: boolean }

function SpawnGate.flags(tabs: { { Name: string, Module: any } }): { string }
    local list: { string } = {}
    for _, entry in tabs do
        if table.find(SpawnGate.TABS, entry.Name) then
            for flag, value in entry.Module.Defaults do
                if type(value) == "boolean" and not SpawnGate.EXEMPT[flag] then
                    table.insert(list, flag)
                end
            end
        end
    end
    table.sort(list)
    return list
end

function SpawnGate.start(context: any, ui: any, flags: { string })
    context.spawn(function()
        local held: { [string]: boolean } = {}
        local since: number? = nil
        while context.alive() do
            if context.Game.world.isSpawned() then
                local now = os.clock()
                local began = since or now
                since = began
                if now - began >= DELAY and next(held) ~= nil then
                    local restore = held
                    held = {}
                    for flag in restore do
                        if ui:get(flag) ~= true then
                            ui:set(flag, true)
                        end
                    end
                end
            else
                since = nil
                for _, flag in flags do
                    if not held[flag] and ui:get(flag) == true then
                        held[flag] = true
                        ui:set(flag, false)
                    end
                end
            end
            if not context.wait(POLL) then
                return
            end
        end
    end)
end

return SpawnGate
end
modules["tabs/compose"] = function(...)

local Compose = {}
Compose.__index = Compose

type Part = { Defaults: { [string]: any }, new: (any) -> any }

function Compose.defaults(parts: { Part }): { [string]: any }
    local merged: { [string]: any } = {}
    for _, part in parts do
        for flag, value in part.Defaults do
            merged[flag] = value
        end
    end
    return merged
end

function Compose.make(name: string, group: string, parts: { Part })
    local Tab = {}
    Tab.__index = Tab
    Tab.Defaults = Compose.defaults(parts)

    function Tab.new(context: any): any
        local objects: { any } = {}
        for _, part in parts do
            local ok, object = pcall(part.new, context)
            if ok then
                table.insert(objects, object)
            end
        end
        return setmetatable({ Objects = objects }, Tab)
    end

    function Tab.build(self: any, ui: any)
        local tab = ui:tab(name, { Group = name })
        for _, object in self.Objects do
            pcall(function()
                object:build(ui, tab)
            end)
        end
    end

    function Tab.step(self: any, dt: number)
        for _, object in self.Objects do
            if object.step then
                pcall(object.step, object, dt)
            end
        end
    end

    function Tab.frame(self: any, canvas: any)
        for _, object in self.Objects do
            if object.frame then
                pcall(object.frame, object, canvas)
            end
        end
    end

    function Tab.shutdown(self: any)
        for index = #self.Objects, 1, -1 do
            pcall(function()
                self.Objects[index]:shutdown()
            end)
        end
    end

    return Tab
end

return Compose
end
modules["tabs/farming"] = function(...)

local import: (string) -> any = ...
local Farm: typeof(require("../plantfarm/farm")) = import("plantfarm/farm")
local Fruits: typeof(require("../plantfarm/fruits")) = import("plantfarm/fruits")

local Tab = {}
Tab.__index = Tab

Tab.Defaults = {
    FarmAutoPlant = false,
    FarmPlantFruit = { Bloodfruit = true },
    FarmAutoHarvest = false,
    FarmTweenBox = false,
    FarmTweenBush = false,
    FarmTweenBoth = false,
    FarmHarvestBatch = 25,
    FarmPlantRange = 18,
    FarmSearchRange = 120,
    FarmMoveSpeed = 18,
} :: { [string]: any }

local POPUP = "plantfarm:fruits"
local POPUP_WIDTH = 520
local POPUP_COLUMNS = 3
local POPUP_ROW = 26
local POPUP_GAP = 3

function Tab.new(context: any): any
    return setmetatable({
        ctx = context,
        Farm = Farm.new(context),
    }, Tab)
end

function Tab.sync(self: any)
    self.Farm:sync()
end

local function exclusive(self: any, keep: string)
    for _, flag in Farm.MOVEMENT_FLAGS do
        if flag ~= keep and self.ctx.read(flag) == true then
            self.ctx.set(flag, false)
        end
    end
end

local function movementToggle(self: any, flag: string): (boolean) -> ()
    return function(value: boolean)
        if value then
            exclusive(self, flag)
        end
        self:sync()
    end
end

local function registerPopup(ui: any, list: { string })
    local rows = math.ceil(#list / POPUP_COLUMNS)
    local column = (POPUP_WIDTH - 32 - (POPUP_COLUMNS - 1) * 8) / POPUP_COLUMNS
    ui:popup(POPUP, {
        Width = POPUP_WIDTH,
        Height = 58 + 8 + rows * (POPUP_ROW + POPUP_GAP) + 50,
        Title = "",
        Render = function(kit: any, window: any)
            local top = kit:header("Plant Fruit", "Seeds Auto Plant rotates through, bushes the tween follows", function()
                window:closePopup()
            end)
            local selected = Fruits.copy(ui:get("FarmPlantFruit"))
            for index, fruit in list do
                local col = (index - 1) % POPUP_COLUMNS
                local row = math.floor((index - 1) / POPUP_COLUMNS)
                kit:switchRow(POPUP .. ":" .. fruit, 16 + col * (column + 8), top + 8 + row * (POPUP_ROW + POPUP_GAP), column, POPUP_ROW, fruit, selected[fruit] == true, function()
                    local result = Fruits.copy(ui:get("FarmPlantFruit"))
                    if result[fruit] then
                        result[fruit] = nil
                    else
                        result[fruit] = true
                    end
                    if next(result) == nil then
                        result[Fruits.DEFAULT] = true
                    end
                    ui:set("FarmPlantFruit", result)
                end)
            end
        end,
    })
end

local function studs(value: number): string
    return string.format("%d studs", value)
end

local function speed(value: number): string
    return string.format("%d studs/s", value)
end

local function whole(value: number): string
    return string.format("%d", value)
end

local function status(self: any): string
    if not self.Farm.Running then
        return "Boxes are scanned while a feature is on"
    end
    local counts = self.Farm:counts()
    return string.format("Boxes %d   Empty %d   Growing %d   Grown %d", counts.boxes, counts.empty, counts.growing, counts.grown)
end

function Tab.build(self: any, ui: any)
    ui:flag("FarmPlantFruit", Fruits.copy(Tab.Defaults.FarmPlantFruit))
    registerPopup(ui, self.ctx.Game.constants.PLANT_FRUITS)
    local page = ui:tab("Plant Farm", { Group = "Plant Farm" })
    local sync = function()
        self:sync()
    end

    local farm = page:section("PLANT FARM")
    farm:label({ Text = "Planting and Harvest", Size = 12, Height = 28, Offset = 4 })
    farm:toggle({
        Name = "Auto Plant",
        Flag = "FarmAutoPlant",
        Default = false,
        Callback = sync,
        Info = { Title = "Auto Plant", Lines = { "Plants a seed into every empty Plant Box within", "Planting Range at once, nearest first, rotating", "through the selected Plant Fruit you carry. Each", "box is sent once and checked, a box that did not", "take the seed is tried again from closer." }, Width = 330 },
    })
    farm:button({
        Name = "Plant Fruit",
        Label = function(): string
            return "Plant Fruit: " .. Fruits.summary(ui:get("FarmPlantFruit"))
        end,
        Callback = function()
            ui:openPopup(POPUP)
        end,
    })
    farm:toggle({
        Name = "Auto Harvest",
        Flag = "FarmAutoHarvest",
        Default = false,
        Callback = sync,
        Info = { Title = "Auto Harvest", Lines = { "Picks every grown bush within 30 studs, up to", "Harvest Batch Size at once. A bush is sent once", "and only sent again if it is still there." }, Width = 320 },
    })

    farm:label({
        Label = function(): string
            return status(self)
        end,
    })

    farm:label({ Text = "Movement", Size = 12, Height = 28, Offset = 4 })
    farm:toggle({
        Name = "Tween To Plant Box",
        Flag = "FarmTweenBox",
        Default = false,
        Callback = movementToggle(self, "FarmTweenBox"),
        Info = { Title = "Tween To Plant Box", Lines = { "Glides to the nearest empty Plant Box within Search", "Range and plants every empty box in Planting Range", "on the way. When all are planted or no seeds are", "left it waits at the box planted first." }, Width = 340 },
    })
    farm:toggle({
        Name = "Tween To Bush",
        Flag = "FarmTweenBush",
        Default = false,
        Callback = movementToggle(self, "FarmTweenBush"),
        Info = { Title = "Tween To Bush", Lines = { "Goes from grown bush to the nearest next grown bush", "(the selected Plant Fruit and every box it planted)", "and picks each on arrival. With none grown it waits", "at the box that was planted first." }, Width = 340 },
    })
    farm:toggle({
        Name = "Tween To Plants And Bushes",
        Flag = "FarmTweenBoth",
        Default = false,
        Callback = movementToggle(self, "FarmTweenBoth"),
        Info = { Title = "Tween To Plants And Bushes", Lines = { "A grown bush first, else the next empty Plant Box,", "else it waits at the box planted first. Plants and", "picks everything in range on the way, so it never", "walks back for a box." }, Width = 340 },
    })

    farm:label({ Text = "Speed and Range", Size = 12, Height = 28, Offset = 4 })
    farm:slider({ Name = "Move Speed", Flag = "FarmMoveSpeed", Min = 16, Max = 20, Step = 1, Default = 18, Format = speed })
    farm:slider({ Name = "Search Range", Flag = "FarmSearchRange", Min = 10, Max = 200, Step = 5, Default = 120, Format = studs })
    farm:slider({ Name = "Planting Range", Flag = "FarmPlantRange", Min = 5, Max = 25, Step = 1, Default = 18, Format = studs })
    farm:slider({ Name = "Harvest Batch Size", Flag = "FarmHarvestBatch", Min = 5, Max = 50, Step = 5, Default = 25, Format = whole })
end

function Tab.step(self: any, _dt: number)
    if self.ctx.alive() then
        self:sync()
    end
end

function Tab.shutdown(self: any)
    self.Farm:shutdown()
end

return Tab
end
modules["tabs/gold"] = function(...)

local import: (string) -> any = ...
local Compose: typeof(require("./compose")) = import("tabs/compose")

return Compose.make("Main Gold Farm", "Gold Farm", {
    import("goldfarm/gold"),
    import("goldfarm/placements"),
})
end
modules["tabs/index"] = function(...)

local import: (string) -> any = ...

return {
    { Name = "gold", Module = import("tabs/gold") },
    { Name = "materials", Module = import("tabs/materials") },
    { Name = "patheditor", Module = import("tabs/patheditor") },
    { Name = "utility", Module = import("tabs/utility") },
    { Name = "webhook", Module = import("tabs/webhook") },
    { Name = "farming", Module = import("tabs/farming") },
    { Name = "updates", Module = import("tabs/updates") },
}
end
modules["tabs/materials"] = function(...)

local import: (string) -> any = ...
local Compose: typeof(require("./compose")) = import("tabs/compose")

return Compose.make("Gold Fruit Farm", "Gold Farm", {
    import("goldfarm/materials"),
})
end
modules["tabs/patheditor"] = function(...)

local import: (string) -> any = ...
local Compose: typeof(require("./compose")) = import("tabs/compose")

return Compose.make("Path Editor", "Gold Farm", {
    import("goldfarm/patheditor"),
})
end
modules["tabs/updates"] = function(...)

local import: (string) -> any = ...
local Changelog: typeof(require("../changelog")) = import("changelog")

local Tab = {}
Tab.__index = Tab

Tab.Defaults = {} :: { [string]: any }

function Tab.new(_context: any): any
    return setmetatable({}, Tab)
end

function Tab.build(_self: any, ui: any)
    ui:updates({ Version = Changelog.VERSION, Date = Changelog.DATE, Groups = Changelog.GROUPS, History = Changelog.HISTORY, Closing = Changelog.CLOSING })
end

return Tab
end
modules["tabs/utility"] = function(...)

local import: (string) -> any = ...
local Compose: typeof(require("./compose")) = import("tabs/compose")

return Compose.make("Utility", "Others", {
    import("goldfarm/utility"),
})
end
modules["tabs/webhook"] = function(...)

local import: (string) -> any = ...
local Compose: typeof(require("./compose")) = import("tabs/compose")

return Compose.make("Webhook", "Others", {
    import("goldfarm/webhook"),
})
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

local function globals()
    local ok, env = pcall(getgenv)
    return if ok and type(env) == "table" then env else _G
end

local function loadUi()
    local source = globals().__OkloUiPrefetch or fetch(UI_URL)
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

