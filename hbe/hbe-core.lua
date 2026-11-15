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
modules["blacklist"] = function(...)

local import: (string) -> any = ...
local World: typeof(require("./world")) = import("world")

local Blacklist = {}

local workspaceService: any = game:GetService("Workspace")

local WIDTH, HEIGHT = 420, 440
local ROW = 34
local ADD_KEY = "blacklist:add"
local FILTER_KEY = "blacklist:filter"

type Session = { Spectating: any, Tab: number, Filter: string, Detected: { { Name: string, Count: number, Parent: string, Model: any } }, Scanned: number }

local session: Session = { Spectating = nil, Tab = 1, Filter = "", Detected = {}, Scanned = -1000 }

local function words(ui: any): { string }
    local list: { string } = {}
    for _, word in ui:get("NpcBlacklist") do
        table.insert(list, word)
    end
    table.sort(list)
    return list
end

local function store(ui: any, list: { string })
    ui:set("NpcBlacklist", list)
end

local function add(ui: any, text: string)
    local list = words(ui)
    for _, piece in string.split(text, ",") do
        local clean = string.lower(string.match(piece, "^%s*(.-)%s*$") or "")
        if clean ~= "" and not table.find(list, clean) then
            table.insert(list, clean)
        end
    end
    store(ui, list)
end

local function remove(ui: any, word: string)
    local list = words(ui)
    local at = table.find(list, word)
    if at then
        table.remove(list, at)
    end
    store(ui, list)
end

local function scan(paths: any)
    local roots: { any } = {}
    if type(paths) == "table" then
        for _, path in paths do
            local found = World.resolve(path)
            if found then
                table.insert(roots, found)
            end
        end
    end
    if #roots == 0 then
        roots = { workspaceService }
    end
    local groups: { [string]: { Name: string, Count: number, Parent: string, Model: any } } = {}
    local descendants: { any } = {}
    for _, root in roots do
        for _, descendant in root:GetDescendants() do
            table.insert(descendants, descendant)
        end
    end
    for _, descendant in descendants do
        if descendant:IsA("Humanoid") then
            local model = descendant.Parent
            if model and model:IsA("Model") and not World.Players:GetPlayerFromCharacter(model) then
                local group = groups[model.Name]
                if group then
                    group.Count += 1
                else
                    groups[model.Name] = { Name = model.Name, Count = 1, Parent = if model.Parent then model.Parent.Name else "?", Model = model }
                end
            end
        end
    end
    local list: { { Name: string, Count: number, Parent: string, Model: any } } = {}
    for _, group in groups do
        table.insert(list, group)
    end
    table.sort(list, function(a: any, b: any)
        return string.lower(a.Name) < string.lower(b.Name)
    end)
    session.Detected = list
    session.Scanned = os.clock()
end

local function release()
    session.Spectating = nil
    local camera = World.camera()
    local character = World.LocalPlayer.Character
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    if camera and humanoid then
        camera.CameraSubject = humanoid
    end
end

local function spectate(model: any)
    local humanoid = if model and model.Parent then World.humanoidOf(model) else nil
    if session.Spectating == model or not humanoid then
        release()
        return
    end
    local camera = World.camera()
    if camera then
        camera.CameraSubject = humanoid
        session.Spectating = model
    end
end

local function keywords(kit: any, window: any, ui: any)
    local pal = window.Pal
    local focused = window.Focus == ADD_KEY
    kit:input(ADD_KEY, 16, 98, WIDTH - 32 - 70, 28, if focused then "" else "Add keywords, separated by commas", function()
        window:beginInput(ADD_KEY, "", {
            commit = function(text: string)
                add(ui, text)
            end,
        })
    end)
    kit:button("blacklist:add", WIDTH - 16 - 64, 98, 64, 28, function() end, { label = "Add", size = 12, rounding = 12 })
    local list = words(ui)
    kit:text("Active keywords (" .. tostring(#list) .. ")", 18, 144, 12, pal.Accent, false, true)
    kit:button("blacklist:clear", WIDTH - 16 - 80, 132, 80, 24, function()
        store(ui, {})
    end, { label = "Clear All", size = 11, rounding = 12 })
    if #list == 0 then
        kit:text("No keywords currently blacklisted", WIDTH / 2, 240, 12, pal.Sub, true, true)
        return
    end
    kit:scroll("blacklist:words", 16, 164, WIDTH - 32, HEIGHT - 180, ROW, #list, function(index: number, x: number, y: number, width: number)
        local word = list[index]
        kit:listRow("blacklist:word:" .. index, x, y, width - 70, ROW - 4, { badge = "K", title = word })
        kit:button("blacklist:remove:" .. index, x + width - 64, y, 64, ROW - 4, function()
            remove(ui, word)
        end, { label = "Remove", size = 11, rounding = 12 })
    end)
end

local function detected(kit: any, window: any, ui: any)
    local pal = window.Pal
    if ui:get("ExpandNpc") ~= true then
        kit:text("Turn on NPC Hitbox to scan for models", WIDTH / 2, 240, 12, pal.Sub, true, true)
        return
    end
    local focused = window.Focus == FILTER_KEY
    local filter = string.lower(if focused then window.Buffers[FILTER_KEY] or "" else session.Filter)
    kit:input(FILTER_KEY, 16, 98, WIDTH - 32 - 70, 28, if session.Filter == "" then "Filter models..." else session.Filter, function()
        window:beginInput(FILTER_KEY, session.Filter, {
            commit = function(text: string)
                session.Filter = text
            end,
        })
    end)
    kit:button("blacklist:rescan", WIDTH - 16 - 64, 98, 64, 28, function()
        scan(ui:get("NpcScanPaths"))
    end, { label = "Scan", size = 12, rounding = 12 })
    if session.Scanned < 0 then
        scan(ui:get("NpcScanPaths"))
    end
    local blocked = words(ui)
    local shown: { { Name: string, Count: number, Parent: string, Model: any } } = {}
    for _, entry in session.Detected do
        if filter == "" or string.find(string.lower(entry.Name), filter, 1, true) then
            table.insert(shown, entry)
        end
    end
    kit:text("Detected models (" .. tostring(#shown) .. ")", 18, 144, 12, pal.Accent, false, true)
    if #shown == 0 then
        kit:text(if filter == "" then "No humanoid models detected in the scan path" else "No models match the filter", WIDTH / 2, 240, 12, pal.Sub, true, true)
        return
    end
    kit:scroll("blacklist:models", 16, 164, WIDTH - 32, HEIGHT - 180, ROW, #shown, function(index: number, x: number, y: number, width: number)
        local entry = shown[index]
        local word = string.lower(entry.Name)
        local isBlocked = table.find(blocked, word) ~= nil
        kit:listRow("blacklist:model:" .. index, x, y, width - 172, ROW - 4, {
            badge = tostring(entry.Count),
            title = entry.Name,
            sub = "in " .. entry.Parent,
        })
        local watching = session.Spectating ~= nil and session.Spectating == entry.Model
        kit:button("blacklist:spectate:" .. index, x + width - 164, y, 84, ROW - 4, function()
            spectate(entry.Model)
        end, { label = if watching then "Unspectate" else "Spectate", size = 11, rounding = 12, active = watching })
        kit:button("blacklist:block:" .. index, x + width - 74, y, 74, ROW - 4, function()
            if isBlocked then
                remove(ui, word)
            else
                add(ui, word)
            end
        end, { label = if isBlocked then "Blocked" else "Block", size = 11, rounding = 12, active = isBlocked })
    end)
end

function Blacklist.release()
    release()
end

function Blacklist.open(ui: any)
    session.Scanned = -1000
    ui:openPopup("blacklist")
end

function Blacklist.register(ui: any)
    ui:popup("blacklist", {
        Width = WIDTH,
        Height = HEIGHT,
        Title = "",
        Render = function(kit: any, window: any)
            kit:header("NPC Blacklist", "Models whose name contains a keyword are skipped", function()
                window:closePopup()
            end)
            kit:segment("blacklist:tab", 16, 62, WIDTH - 32, 28, { "Keywords", "Detected Models" }, session.Tab, function(index: number)
                session.Tab = index
            end)
            if session.Tab == 1 then
                keywords(kit, window, ui)
            else
                detected(kit, window, ui)
            end
        end,
    })
end

return Blacklist
end
modules["changelog"] = function(...)

local Changelog = {}

Changelog.VERSION = "1"
Changelog.DATE = "October 27, 2026"

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
modules["config"] = function(...)

local Config = {}

export type Settings = { [string]: any }

Config.TARGET_PARTS = {
    { Name = "HumanoidRootPart", Rig = "Core" },
    { Name = "Head", Rig = "Core" },
    { Name = "Torso", Rig = "R6" },
    { Name = "UpperTorso", Rig = "R15" },
    { Name = "LowerTorso", Rig = "R15" },
    { Name = "Left Arm", Rig = "R6" },
    { Name = "Right Arm", Rig = "R6" },
    { Name = "Left Leg", Rig = "R6" },
    { Name = "Right Leg", Rig = "R6" },
    { Name = "LeftUpperArm", Rig = "R15" },
    { Name = "LeftLowerArm", Rig = "R15" },
    { Name = "LeftHand", Rig = "R15" },
    { Name = "RightUpperArm", Rig = "R15" },
    { Name = "RightLowerArm", Rig = "R15" },
    { Name = "RightHand", Rig = "R15" },
    { Name = "LeftUpperLeg", Rig = "R15" },
    { Name = "LeftLowerLeg", Rig = "R15" },
    { Name = "LeftFoot", Rig = "R15" },
    { Name = "RightUpperLeg", Rig = "R15" },
    { Name = "RightLowerLeg", Rig = "R15" },
    { Name = "RightFoot", Rig = "R15" },
}

Config.ARSENAL_PLACE = 286090429
Config.ARSENAL_PARTS = { "Hitbox", "HeadHB" }

function Config.partFlag(name: string): string
    return "Size_" .. string.gsub(name, "%s", "")
end

Config.PRESETS = {
    { Name = "HRP", Parts = { "HumanoidRootPart" } },
    { Name = "Head", Parts = { "Head" } },
    { Name = "Torso", Parts = { "Torso", "UpperTorso", "LowerTorso" } },
    { Name = "R6", Parts = { "HumanoidRootPart", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } },
    {
        Name = "R15",
        Parts = {
            "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand",
            "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
            "RightUpperLeg", "RightLowerLeg", "RightFoot",
        },
    },
}

Config.RANGE_COUNT = 10
Config.RANGE_DEFAULTS = {
    { 0, 50, 15 }, { 50, 100, 25 }, { 100, 200, 20 }, { 200, 400, 15 }, { 400, 800, 10 },
    { 800, 1500, 8 }, { 1500, 2500, 6 }, { 2500, 4000, 4 }, { 4000, 6000, 2 }, { 6000, 10000, 1 },
}

Config.DEFAULTS = {
    Enabled = false,
    HoldMode = false,
    VehicleFix = true,
    HoldKey = "None",
    Mode = "All",
    Targets = {},
    Whitelist = {},
    HitboxSize = 10,
    TargetParts = { HumanoidRootPart = true },
    PartSizesEnabled = false,
    CustomDimensions = false,
    DimX = 12,
    DimY = 12,
    DimZ = 12,
    DynamicSize = false,
    ExtraRanges = false,
    DynamicSingleTarget = false,
    DisableBeyondMax = false,

    TeamCheck = true,
    DeadCheck = true,
    ForcefieldCheck = true,
    InvisibleCheck = true,
    WallCheck = false,
    DistanceLimit = false,
    MaxDistance = 300,
    IgnoreFriends = false,
    FovCheck = false,
    FovRadius = 150,
    ShowFovCircle = false,
    FovCircleColor = Color3.fromRGB(212, 212, 212),
    FovSingleTarget = false,
    VisOutsideFov = false,
    VisOutsideDistance = false,
    FovAnim = "Static",
    FovSpeed = 3,
    FovDots = 100,
    FovThickness = 1.5,
    FovTrans = 0,

    VisualizerEnabled = true,
    VisualizerMode = "3D",
    LineWidth = 1.5,
    LineColor = Color3.fromRGB(255, 255, 255),
    LineTransparency = 0.25,
    FillColor = Color3.fromRGB(255, 255, 255),
    FillTransparency = 0.85,
    TargetIndicator = false,
    ShowNames = true,
    ShowHealth = false,
    ShowDistance = false,
    TextColor = Color3.fromRGB(240, 240, 240),
    TextTransparency = 0,

    ExpandNpc = false,
    NpcHitboxSize = 14,
    NpcTargetParts = { HumanoidRootPart = true },
    NpcDeadCheck = true,
    NpcDistanceLimit = false,
    MaxNpcDistance = 250,
    NpcScanPaths = {},
    NpcDeadPaths = {},
    NpcBlacklist = {},
    NpcVisualizerEnabled = true,
    NpcShowNames = true,
    NpcLineColor = Color3.fromRGB(255, 255, 255),
    NpcFillColor = Color3.fromRGB(255, 255, 255),
    NpcLineTransparency = 0.25,
    NpcFillTransparency = 0.85,
    NpcLineWidth = 1.5,
    NpcTextColor = Color3.fromRGB(240, 240, 240),
    NpcTextTransparency = 0,
} :: Settings

for _, entry in Config.TARGET_PARTS do
    Config.DEFAULTS[Config.partFlag(entry.Name)] = 12
end

for index, range in Config.RANGE_DEFAULTS do
    Config.DEFAULTS["RangeMin" .. index] = range[1]
    Config.DEFAULTS["RangeMax" .. index] = range[2]
    Config.DEFAULTS["RangeSize" .. index] = range[3]
end

local TYPED_MAX = 5000
local SIZE_FLAGS: { [string]: boolean } = { HitboxSize = true }

function Config.read(ui: any): Settings
    local settings: Settings = {}
    for key, default in Config.DEFAULTS do
        local value = ui:get(key)
        if value == nil then
            value = default
        end
        if SIZE_FLAGS[key] and type(value) == "number" then
            value = math.clamp(value, 1, TYPED_MAX)
        end
        settings[key] = value
    end
    return settings
end

return Config
end
modules["expander"] = function(...)

local Expander = {}
Expander.__index = Expander

type Fix = { Mine: any? }

local ROOT_PRIORITY, PART_PRIORITY = -126, -127
local MIN_DENSITY = 0.0001
local FIX_SECONDS = 0.25

type Visual = {
    Model: any,
    Real: any,
    Copy: any,
    Pairs: { [any]: any },
    Shown: { any },
}

type Tags = { Humanoid: any, Display: any, Health: any }

type Record = {
    Model: any,
    Tags: Tags?,
    Priorities: { [any]: number },
    Parts: { [any]: { [string]: any } },
    Visual: Visual?,
    NextFix: number,
}

local FOLDER_NAME = "HBEVisuals"
local BIND_NAME = "HBEVisualSync"
local workspaceService: any = game:GetService("Workspace")
local runService: any = game:GetService("RunService")

function Expander.new()
    return setmetatable({ Records = {} :: { [any]: Record } }, Expander)
end

type Self = typeof(Expander.new())

local function remember(part: any): { [string]: any }
    local decals: { any } = {}
    for _, child in part:GetChildren() do
        if child:IsA("Decal") or child:IsA("Texture") then
            table.insert(decals, { Instance = child, Transparency = child.Transparency })
        end
    end
    return {
        Size = part.Size,
        CanCollide = part.CanCollide,
        CanQuery = part.CanQuery,
        Massless = part.Massless,
        Physical = part.CustomPhysicalProperties,
        Current = part.CurrentPhysicalProperties,
        Mass = part.Mass,
        Transparency = part.Transparency,
        Modifier = part.LocalTransparencyModifier,
        Decals = decals,
    }
end

local function folder(): any
    local camera = workspaceService.CurrentCamera
    if not camera then
        return nil
    end
    local found = camera:FindFirstChild(FOLDER_NAME)
    if not found then
        found = Instance.new("Folder")
        found.Name = FOLDER_NAME
        found.Parent = camera
    end
    return found
end

local function hideAll(part: any)
    part.Transparency = 1
    for _, child in part:GetDescendants() do
        if child:IsA("Decal") or child:IsA("Texture") then
            child.Transparency = 1
        end
    end
end

local DESTROYED = { "Script", "LocalScript", "ModuleScript", "JointInstance", "Constraint", "BodyMover", "Accessory", "Tool", "ForceField", "Sound", "Animator", "TouchTransmitter", "Highlight" }

local function strip(copy: any, tags: Tags?)
    for _, descendant in copy:GetDescendants() do
        for _, class in DESTROYED do
            if descendant:IsA(class) then
                pcall(function()
                    descendant:Destroy()
                end)
                break
            end
        end
    end
    local humanoid = copy:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = if tags then tags.Display else Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = if tags then tags.Health else Enum.HumanoidHealthDisplayType.AlwaysOff
        humanoid.BreakJointsOnDeath = false
    end
end

local function sameParts(first: { any }, second: { any }): boolean
    if #first ~= #second then
        return false
    end
    for index, part in first do
        if second[index] ~= part then
            return false
        end
    end
    return true
end

local function buildVisual(model: any, parts: { any }, originals: { [any]: { [string]: any } }, tags: Tags?): Visual?
    local host = folder()
    if not host then
        return nil
    end
    local archivable = model.Archivable
    model.Archivable = true
    local copy = model:Clone()
    model.Archivable = archivable
    if not copy then
        return nil
    end
    strip(copy, tags)
    local wanted: { [any]: any } = {}
    for _, part in parts do
        local counterpart = copy:FindFirstChild(part.Name, true)
        if counterpart and counterpart:IsA("BasePart") then
            wanted[counterpart] = part
        end
    end
    local pairs_: { [any]: any } = {}
    for _, descendant in copy:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            descendant.Massless = true
            local real = wanted[descendant]
            if real then
                local original = originals[real]
                descendant.Size = original.Size
                descendant.Transparency = original.Transparency
                descendant.CFrame = real.CFrame
                local own: { any } = {}
                for _, child in descendant:GetChildren() do
                    if child:IsA("Decal") or child:IsA("Texture") then
                        table.insert(own, child)
                    end
                end
                for index, entry in original.Decals do
                    if own[index] then
                        own[index].Transparency = entry.Transparency
                    end
                end
                pairs_[real] = descendant
            else
                hideAll(descendant)
            end
        end
    end
    copy.Name = "Visual_" .. model.Name
    copy.Parent = host
    return { Model = copy, Pairs = pairs_, Shown = table.clone(parts), Real = model:FindFirstChildOfClass("Humanoid"), Copy = copy:FindFirstChildOfClass("Humanoid") }
end

local function destroyVisual(visual: Visual?)
    if visual and visual.Model then
        pcall(function()
            visual.Model:Destroy()
        end)
    end
end

local function revert(part: any, original: { [string]: any })
    if not part.Parent then
        return
    end
    pcall(function()
        part.Size = original.Size
        part.CanCollide = original.CanCollide
        part.CanQuery = original.CanQuery
        part.Massless = original.Massless
        part.CustomPhysicalProperties = original.Physical
        part.Transparency = original.Transparency
        part.LocalTransparencyModifier = original.Modifier
        for _, entry in original.Decals do
            if entry.Instance.Parent then
                entry.Instance.Transparency = entry.Transparency
            end
        end
    end)
end

local function restorePriorities(record: Record)
    local priorities = record.Priorities
    record.Priorities = {}
    for part, priority in priorities do
        if part.Parent then
            pcall(function()
                part.RootPriority = priority
            end)
        end
    end
end

local function restoreTags(record: Record)
    local tags = record.Tags
    record.Tags = nil
    if tags and tags.Humanoid.Parent then
        pcall(function()
            tags.Humanoid.DisplayDistanceType = tags.Display
            tags.Humanoid.HealthDisplayType = tags.Health
        end)
    end
end

function Expander.apply(self: Self, key: any, model: any, parts: { any }, size: Vector3, partSizes: { [any]: Vector3 }?, fix: Fix?)
    local current: Record? = self.Records[key]
    if current and current.Model ~= model then
        self:restore(key)
        current = nil
    end
    local record: Record = current or { Model = model, Tags = nil, Priorities = {}, Parts = {}, Visual = nil, NextFix = 0 }
    self.Records[key] = record
    local wanted: { [any]: boolean } = {}
    for _, part in parts do
        wanted[part] = true
    end
    for part, original in record.Parts do
        if not wanted[part] then
            revert(part, original)
            record.Parts[part] = nil
        end
    end
    for _, part in parts do
        if not record.Parts[part] then
            record.Parts[part] = remember(part)
        end
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local headOut = false
    for _, part in parts do
        if part.Name == "Head" then
            headOut = true
        end
    end
    if headOut and humanoid and not record.Tags then
        record.Tags = { Humanoid = humanoid, Display = humanoid.DisplayDistanceType, Health = humanoid.HealthDisplayType }
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    elseif not headOut and record.Tags then
        restoreTags(record)
    end

    local visual = record.Visual
    local shown: { any } = {}
    for _, part in parts do
        if part.Name ~= "HumanoidRootPart" then
            table.insert(shown, part)
        end
    end
    if #shown == 0 then
        destroyVisual(visual)
        record.Visual = nil
    elseif not visual or not visual.Model.Parent or not sameParts(visual.Shown, shown) then
        destroyVisual(visual)
        local ok, built = pcall(buildVisual, model, shown, record.Parts, record.Tags)
        record.Visual = if ok then built else nil
    end

    if fix then
        local now = os.clock()
        if now >= record.NextFix then
            record.NextFix = now + FIX_SECONDS
            for _, descendant in model:GetDescendants() do
                if descendant:IsA("BasePart") then
                    if record.Priorities[descendant] == nil then
                        record.Priorities[descendant] = descendant.RootPriority
                    end
                    local goal = if descendant.Name == "HumanoidRootPart" then ROOT_PRIORITY else PART_PRIORITY
                    if descendant.RootPriority ~= goal then
                        descendant.RootPriority = goal
                    end
                end
            end
        end
    else
        record.NextFix = 0
        if next(record.Priorities) ~= nil then
            restorePriorities(record)
        end
    end

    local mineRoot = if fix and fix.Mine then fix.Mine.AssemblyRootPart else nil
    for _, part in parts do
        local original = record.Parts[part]
        local target = if partSizes and partSizes[part] then partSizes[part] else size
        if part.Size ~= target then
            part.Size = target
        end
        if part.CanCollide then
            part.CanCollide = false
        end
        if fix then
            if part.Name == "HumanoidRootPart" then
                if part.Massless ~= original.Massless then
                    part.Massless = original.Massless
                end
                local props = original.Current
                local density = math.max(MIN_DENSITY, original.Mass / math.max(0.001, target.X * target.Y * target.Z))
                local goal = PhysicalProperties.new(density, props.Friction, props.Elasticity, props.FrictionWeight, props.ElasticityWeight)
                if part.CustomPhysicalProperties ~= goal then
                    part.CustomPhysicalProperties = goal
                end
            elseif not part.Massless then
                part.Massless = true
            end
            local query = if mineRoot and part.AssemblyRootPart == mineRoot then false else original.CanQuery
            if part.CanQuery ~= query then
                part.CanQuery = query
            end
        else
            if part.Massless ~= original.Massless then
                part.Massless = original.Massless
            end
            if part.CanQuery ~= original.CanQuery then
                part.CanQuery = original.CanQuery
            end
            if part.CustomPhysicalProperties ~= original.Physical then
                part.CustomPhysicalProperties = original.Physical
            end
        end
        if part.Transparency ~= 1 then
            part.Transparency = 1
        end
        if part.LocalTransparencyModifier ~= 1 then
            part.LocalTransparencyModifier = 1
        end
        for _, entry in original.Decals do
            local decal = entry.Instance
            if decal.Parent and decal.Transparency ~= 1 then
                decal.Transparency = 1
            end
        end
    end
end

function Expander.sync(self: Self)
    for _, record in self.Records do
        local visual = record.Visual
        if visual then
            if visual.Real and visual.Copy and visual.Real.Parent and visual.Copy.Parent then
                if visual.Copy.MaxHealth ~= visual.Real.MaxHealth then
                    visual.Copy.MaxHealth = visual.Real.MaxHealth
                end
                if visual.Copy.Health ~= visual.Real.Health then
                    visual.Copy.Health = visual.Real.Health
                end
            end
            for real, copy in visual.Pairs do
                if real.Parent and copy.Parent then
                    local frame = real.CFrame
                    if copy.CFrame ~= frame then
                        copy.CFrame = frame
                    end
                    if real.Transparency ~= 1 then
                        real.Transparency = 1
                    end
                end
            end
        end
    end
end

function Expander.solidOff(self: Self)
    for _, record in self.Records do
        for part in record.Parts do
            if part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end

function Expander.restore(self: Self, key: any)
    local record = self.Records[key]
    if not record then
        return
    end
    self.Records[key] = nil
    for part, original in record.Parts do
        revert(part, original)
    end
    restoreTags(record)
    restorePriorities(record)
    destroyVisual(record.Visual)
end

function Expander.restoreAll(self: Self)
    for key in self.Records do
        self:restore(key)
    end
end

function Expander.keys(self: Self): { any }
    local list: { any } = {}
    for key in self.Records do
        table.insert(list, key)
    end
    return list
end

function Expander.originalTransparency(self: Self, key: any, part: any): number?
    local record = self.Records[key]
    local original = record and record.Parts[part]
    return if original then original.Transparency else nil
end

function Expander.has(self: Self, key: any): boolean
    return self.Records[key] ~= nil
end

local bindCount = 0

function Expander.bindSync(expanders: { any }): () -> ()
    bindCount += 1
    local bindName = BIND_NAME .. bindCount .. "_" .. string.format("%x", math.floor(os.clock() * 1000))
    local function sync()
        for _, expander in expanders do
            expander:sync()
        end
    end
    local function noCollide()
        for _, expander in expanders do
            expander:solidOff()
        end
    end
    local before = runService.Stepped:Connect(noCollide)
    local after = runService.Heartbeat:Connect(noCollide)
    local bound = pcall(function()
        runService:BindToRenderStep(bindName, Enum.RenderPriority.Last.Value, sync)
    end)
    local fallback = nil
    if not bound then
        fallback = runService.RenderStepped:Connect(sync)
    end
    return function()
        before:Disconnect()
        after:Disconnect()
        if bound then
            pcall(function()
                runService:UnbindFromRenderStep(bindName)
            end)
        elseif fallback then
            fallback:Disconnect()
        end
        local host = folder()
        if host then
            host:Destroy()
        end
    end
end

return Expander
end
modules["explorer"] = function(...)

local import: (string) -> any = ...
local World: typeof(require("./world")) = import("world")

local Explorer = {}

local workspaceService: any = game:GetService("Workspace")

local WIDTH, HEIGHT = 470, 410
local ROW = 24
local INDENT = 14
local SEARCH_KEY = "explorer:search"
local DOUBLE_CLICK = 0.35
local REFRESH_SECONDS = 1
local MAX_CHILDREN = 1500
local MAX_RESULTS = 400

type Entry = { Instance: any, Depth: number, Info: string? }
type Session = {
    Flag: string,
    Query: string,
    Applied: string,
    Expanded: { [any]: boolean? },
    Selected: { [any]: boolean },
    LastClick: { Instance: any, Time: number }?,
    Rows: { Entry },
    Built: number,
    Dirty: boolean,
}

local session: Session = { Flag = "NpcScanPaths", Query = "", Applied = "", Expanded = {}, Selected = {}, LastClick = nil, Rows = {}, Built = 0, Dirty = true }

local COLORS = {
    Folder = Color3.fromRGB(232, 184, 64),
    Model = Color3.fromRGB(110, 160, 255),
    Part = Color3.fromRGB(176, 176, 188),
    Humanoid = Color3.fromRGB(236, 124, 164),
    Script = Color3.fromRGB(110, 204, 126),
    Other = Color3.fromRGB(140, 140, 152),
}

local function kindOf(instance: any): string
    if instance:IsA("Folder") then
        return "Folder"
    elseif instance:IsA("Model") then
        return "Model"
    elseif instance:IsA("BasePart") then
        return "Part"
    elseif instance:IsA("Humanoid") then
        return "Humanoid"
    elseif instance:IsA("LuaSourceContainer") then
        return "Script"
    end
    return "Other"
end

local function icon(kit: any, instance: any, x: number, y: number)
    local kind = kindOf(instance)
    local color: Color3 = COLORS[kind]
    local dark = Color3.new(color.R * 0.55, color.G * 0.55, color.B * 0.55)
    if kind == "Folder" then
        kit:solid(x, y + 1, 7, 4, color, 2)
        kit:solid(x, y + 3, 14, 10, color, 3)
    elseif kind == "Model" then
        kit:solid(x + 1, y + 1, 12, 12, color, 4)
        kit:solid(x + 4, y + 4, 6, 6, dark, 2)
    elseif kind == "Part" then
        kit:solid(x + 1, y + 2, 12, 10, color, 3)
        kit:solid(x + 3, y + 4, 8, 3, Color3.new(1, 1, 1), 2, 0.55)
    elseif kind == "Humanoid" then
        kit:solid(x + 4, y, 6, 6, color, 3)
        kit:solid(x + 2, y + 7, 10, 6, color, 3)
    elseif kind == "Script" then
        kit:solid(x + 2, y, 10, 14, color, 3)
        kit:solid(x + 4, y + 4, 6, 1.5, dark, 1)
        kit:solid(x + 4, y + 8, 6, 1.5, dark, 1)
    else
        kit:solid(x + 4, y + 4, 6, 6, color, 3)
    end
end

local function chevron(kit: any, x: number, y: number, open: boolean, color: Color3)
    if open then
        kit:line(x, y + 3, x + 3.5, y + 6.5, color, 1.6)
        kit:line(x + 3.5, y + 6.5, x + 7, y + 3, color, 1.6)
    else
        kit:line(x + 2, y, x + 5.5, y + 3.5, color, 1.6)
        kit:line(x + 5.5, y + 3.5, x + 2, y + 7, color, 1.6)
    end
end

local function flatten(root: any, depth: number, out: { Entry })
    table.insert(out, { Instance = root, Depth = depth })
    if session.Expanded[root] then
        local children = root:GetChildren()
        for index, child in children do
            if index > MAX_CHILDREN then
                break
            end
            flatten(child, depth + 1, out)
        end
    end
end

local function search(query: string): { Entry }
    local found: { Entry } = {}
    for _, descendant in workspaceService:GetDescendants() do
        if string.find(string.lower(descendant.Name), query, 1, true) then
            table.insert(found, { Instance = descendant, Depth = 0, Info = if descendant.Parent then World.pathOf(descendant.Parent) else nil })
            if #found >= MAX_RESULTS then
                break
            end
        end
    end
    return found
end

local function rows(query: string): { Entry }
    local now = os.clock()
    if session.Dirty or now - session.Built > REFRESH_SECONDS then
        session.Dirty = false
        session.Built = now
        if query ~= "" then
            session.Rows = search(query)
        else
            local list: { Entry } = {}
            flatten(workspaceService, 0, list)
            session.Rows = list
        end
    end
    return session.Rows
end

local TITLES: { [string]: { string } } = {
    NpcScanPaths = { "NPC Scan Locations", "Nothing selected scans the whole Workspace" },
    NpcDeadPaths = { "Dead NPC Folders", "NPCs inside a selected folder count as dead" },
}

local function count(): number
    local total = 0
    for instance in session.Selected do
        if instance.Parent then
            total += 1
        end
    end
    return total
end

local function toggle(instance: any)
    if instance == workspaceService then
        return
    end
    session.Selected[instance] = if session.Selected[instance] then nil else true
end

function Explorer.open(ui: any, flag: string)
    session.Flag = flag
    session.Query = ""
    session.Applied = ""
    session.Selected = {}
    session.LastClick = nil
    session.Expanded = { [workspaceService] = true }
    local saved = ui:get(flag)
    if type(saved) == "table" then
        for _, path in saved do
            local instance = World.resolve(path)
            if instance then
                session.Selected[instance] = true
                local walk = instance.Parent
                while walk and walk ~= workspaceService and walk ~= game do
                    session.Expanded[walk] = true
                    walk = walk.Parent
                end
            end
        end
    end
    session.Dirty = true
    ui:openPopup("explorer")
end

local function shorten(kit: any, text: string, limit: number, size: number): string
    if kit:measure(text, size) <= limit then
        return text
    end
    local cut = #text
    while cut > 1 and kit:measure(string.sub(text, 1, cut) .. "..", size) > limit do
        cut -= 1
    end
    return string.sub(text, 1, cut) .. ".."
end

local function checkbox(kit: any, pal: any, x: number, y: number, on: boolean)
    if on then
        kit:solid(x, y, 14, 14, pal.Accent, 4)
        kit:line(x + 3.5, y + 7.5, x + 6, y + 10, pal.Panel, 1.8)
        kit:line(x + 6, y + 10, x + 10.5, y + 4, pal.Panel, 1.8)
    else
        kit:solid(x, y, 14, 14, pal.Main, 4)
        kit:border(x, y, 14, 14, 4, pal.Sub, 0.6, 1.2)
    end
end

function Explorer.register(ui: any)
    ui:popup("explorer", {
        Width = WIDTH,
        Height = HEIGHT,
        Title = "",
        Render = function(kit: any, window: any)
            local pal = window.Pal
            local flag = session.Flag
            local copy = TITLES[flag] or TITLES.NpcScanPaths
            local picked = count()
            kit:header(copy[1], tostring(picked) .. " selected. " .. copy[2], function()
                window:closePopup()
            end)
            local focused = window.Focus == SEARCH_KEY
            local query = string.lower(if focused then window.Buffers[SEARCH_KEY] or "" else session.Query)
            kit:input(SEARCH_KEY, 16, 60, WIDTH - 32, 28, if session.Query == "" then "Search..." else session.Query, function()
                window:beginInput(SEARCH_KEY, session.Query, {
                    commit = function(text: string)
                        session.Query = text
                        session.Dirty = true
                    end,
                })
            end, pal.Panel)
            if query ~= session.Applied then
                session.Applied = query
                session.Dirty = true
            end
            local list = rows(query)
            if #list == 0 then
                kit:text("Nothing found", WIDTH / 2, 200, 12, pal.Sub, true, true)
            end
            kit:scroll("explorer:tree", 16, 96, WIDTH - 32, HEIGHT - 96 - 82, ROW, #list, function(index: number, x: number, y: number, width: number)
                local entry = list[index]
                local instance = entry.Instance
                if not instance.Parent and instance ~= workspaceService then
                    return
                end
                local key = "explorer:row:" .. index
                local hovered = kit:hovered(key)
                local chosen = session.Selected[instance] == true
                local fill = if chosen then pal.Accent elseif hovered then pal.Panel else nil
                if fill then
                    kit:rect(x, y, width, ROW - 2, fill, if chosen then 0.28 else 1, 8)
                end
                local left = x + 6 + entry.Depth * INDENT
                local kids = #instance:GetChildren()
                local expandable = kids > 0 and query == ""
                local open = session.Expanded[instance] == true
                if instance ~= workspaceService then
                    checkbox(kit, pal, left, y + ROW / 2 - 8, chosen)
                end
                if expandable then
                    chevron(kit, left + 22, y + ROW / 2 - 4, open, if hovered then pal.Text else pal.Sub)
                end
                icon(kit, instance, left + 36, y + ROW / 2 - 7)
                local textLeft = left + 56
                local suffix = if kids > 0 then tostring(kids) else ""
                local room = x + width - 8 - textLeft
                local name = shorten(kit, instance.Name, room - kit:measure(suffix, 10) - 4, 12)
                kit:text(name, textLeft, y + ROW / 2 - 1, 12, pal.Text, false, true)
                local nameWidth = kit:measure(name, 12)
                if entry.Info then
                    kit:text(shorten(kit, entry.Info, room - nameWidth - 12, 10), textLeft + nameWidth + 8, y + ROW / 2, 10, pal.Sub, false, true)
                elseif kids > 0 then
                    kit:text(suffix, textLeft + nameWidth + 8, y + ROW / 2, 10, pal.Sub, false, true)
                end
                kit:region(key, x, y, width, ROW - 2, function()
                    local now = os.clock()
                    local last = session.LastClick
                    toggle(instance)
                    if last and last.Instance == instance and now - last.Time <= DOUBLE_CLICK then
                        toggle(instance)
                        session.LastClick = nil
                        if expandable then
                            session.Expanded[instance] = not open
                            session.Dirty = true
                        end
                        return
                    end
                    session.LastClick = { Instance = instance, Time = now }
                end)
                if expandable then
                    kit:region(key .. ":arrow", left + 18, y, 20, ROW - 2, function()
                        session.Expanded[instance] = not open
                        session.Dirty = true
                    end)
                end
            end)
            kit:text("Click to select. Double click to open or close.", 18, HEIGHT - 62, 11, pal.Sub, false, true)
            local gap = 6
            local buttonWidth = (WIDTH - 32 - gap * 2) / 3
            kit:button("explorer:clear", 16, HEIGHT - 44, buttonWidth, 30, function()
                session.Selected = {}
            end, { label = "Clear", size = 12, rounding = 12 })
            kit:button("explorer:collapse", 16 + buttonWidth + gap, HEIGHT - 44, buttonWidth, 30, function()
                session.Expanded = { [workspaceService] = true }
                session.Dirty = true
            end, { label = "Collapse All", size = 12, rounding = 12 })
            kit:button("explorer:apply", 16 + (buttonWidth + gap) * 2, HEIGHT - 44, buttonWidth, 30, function()
                local paths: { string } = {}
                for instance in session.Selected do
                    if instance.Parent then
                        table.insert(paths, World.pathOf(instance))
                    end
                end
                table.sort(paths)
                ui:set(flag, paths)
                window:closePopup()
            end, { label = "Apply (" .. tostring(picked) .. ")", size = 12, rounding = 12, active = true })
        end,
    })
end

return Explorer
end
modules["filters"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")
local World: typeof(require("./world")) = import("world")

local Filters = {}

local userInput: any = game:GetService("UserInputService")
local workspaceService: any = game:GetService("Workspace")

local INVISIBLE_AT = 0.95
local partFlags: { [string]: string } = {}
local TORSO_NAMES = { "UpperTorso", "Torso" }

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.IgnoreWater = true

local function blockedByWall(origin: Vector3, root: any, ignore: { any }): boolean
    local params = wallParams
    params.FilterDescendantsInstances = ignore
    local result = workspaceService:Raycast(origin, root.Position - origin, params)
    return result ~= nil and result.Instance ~= nil and result.Instance.CanCollide
end

function Filters.screenDistance(camera: any, root: any): number?
    local screen, onScreen = camera:WorldToViewportPoint(root.Position)
    if not onScreen or screen.Z <= 0 then
        return nil
    end
    return (Vector2.new(screen.X, screen.Y) - userInput:GetMouseLocation()).Magnitude
end

local function transparencyOf(part: any, original: ((any) -> number?)?): number
    local known = if original then original(part) else nil
    return known or part.Transparency
end

function Filters.invisible(character: any, original: ((any) -> number?)?): boolean
    local head = character:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") or transparencyOf(head, original) < INVISIBLE_AT then
        return false
    end
    for _, name in TORSO_NAMES do
        local torso = character:FindFirstChild(name)
        if torso and torso:IsA("BasePart") then
            return transparencyOf(torso, original) >= INVISIBLE_AT
        end
    end
    return true
end

local function listed(list: any, player: any): boolean
    return type(list) == "table" and list[player.Name] == true
end

function Filters.held(settings: { [string]: any }, keys: any, pressed: { [string]: boolean? }): boolean
    if not settings.HoldMode then
        return true
    end
    local name = keys.normalize(settings.HoldKey)
    return name ~= "" and name ~= "None" and pressed[name] == true
end

function Filters.player(settings: { [string]: any }, player: any, camera: any, mineRoot: any, original: ((any) -> number?)?, skipField: boolean?): (boolean, number, any, string?)
    local localPlayer = World.LocalPlayer
    if not player or player == localPlayer then
        return false, 0, nil, "self"
    end
    if listed(settings.Whitelist, player) then
        return false, 0, nil, "whitelist"
    end
    if settings.Mode == "Target" and not listed(settings.Targets, player) then
        return false, 0, nil, "target"
    end
    if settings.TeamCheck and localPlayer.Team and player.Team == localPlayer.Team then
        return false, 0, nil, "team"
    end
    if settings.IgnoreFriends and localPlayer:IsFriendsWith(player.UserId) then
        return false, 0, nil, "friend"
    end
    local character = player.Character
    if not character then
        return false, 0, nil, "character"
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if settings.DeadCheck and (not humanoid or humanoid.Health <= 0) then
        return false, 0, nil, "dead"
    end
    if settings.ForcefieldCheck and character:FindFirstChildOfClass("ForceField") then
        return false, 0, nil, "forcefield"
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not mineRoot then
        return false, 0, nil, "root"
    end
    if settings.InvisibleCheck and Filters.invisible(character, original) then
        return false, 0, nil, "invisible"
    end
    local distance = (root.Position - mineRoot.Position).Magnitude
    if settings.DistanceLimit and distance > settings.MaxDistance then
        return false, distance, root, "distance"
    end
    if settings.WallCheck and blockedByWall(camera.CFrame.Position, root, { localPlayer.Character, character, camera }) then
        return false, distance, root, "wall"
    end
    local targeted = settings.Mode == "Target"
    if settings.FovCheck and not skipField and not targeted then
        local away = Filters.screenDistance(camera, root)
        if not away or away > settings.FovRadius then
            return false, distance, root, "fov"
        end
    end
    return true, distance, root, nil
end

local function rangeSize(settings: { [string]: any }, distance: number): (number?, boolean)
    local count = if settings.ExtraRanges then Config.RANGE_COUNT else 5
    local furthest = 0
    for index = 1, count do
        local first = tonumber(settings["RangeMin" .. index]) or 0
        local second = tonumber(settings["RangeMax" .. index]) or 0
        local lower, upper = math.min(first, second), math.max(first, second)
        furthest = math.max(furthest, upper)
        if distance >= lower and distance <= upper then
            return tonumber(settings["RangeSize" .. index]), true
        end
    end
    return nil, not (settings.DisableBeyondMax and distance > furthest)
end

function Filters.edge(settings: { [string]: any }, distance: number): number?
    if not settings.DynamicSize then
        return settings.HitboxSize
    end
    local size, allowed = rangeSize(settings, distance)
    if not allowed then
        return nil
    end
    return size or settings.HitboxSize
end

function Filters.box(settings: { [string]: any }, edge: number): Vector3
    if not settings.CustomDimensions then
        return Vector3.new(edge, edge, edge)
    end
    local factor = edge / math.max(1, settings.HitboxSize)
    return Vector3.new(settings.DimX * factor, settings.DimY * factor, settings.DimZ * factor)
end

function Filters.partSizes(settings: { [string]: any }, parts: { any }): { [any]: Vector3 }?
    if not settings.PartSizesEnabled or settings.DynamicSize then
        return nil
    end
    local sizes: { [any]: Vector3 } = {}
    for _, part in parts do
        local name = part.Name
        local flag = partFlags[name]
        if not flag then
            flag = Config.partFlag(name)
            partFlags[name] = flag
        end
        sizes[part] = Filters.box(settings, tonumber(settings[flag]) or settings.HitboxSize)
    end
    return sizes
end

return Filters
end
modules["fov"] = function(...)

local Fov = {}

local SOLID_AT = 100
local BREATHE = 0.06
local SPIN_RATE = 0.4
local FILL = 0.55

local function onCircle(center: Vector2, radius: number, angle: number): Vector2
    return center + Vector2.new(math.cos(angle), math.sin(angle)) * radius
end

function Fov.draw(canvas: any, center: Vector2, settings: { [string]: any }, now: number)
    local alpha = 1 - math.clamp(settings.FovTrans, 0, 1)
    if alpha <= 0.004 then
        return
    end
    local radius: number = settings.FovRadius
    if settings.FovAnim == "Breathe" then
        radius *= 1 + BREATHE * math.sin(now * settings.FovSpeed)
    end
    local dots = math.floor(settings.FovDots)
    if dots >= SOLID_AT then
        canvas.circle(center, radius, settings.FovCircleColor, alpha, settings.FovThickness)
        return
    end
    local spin = if settings.FovAnim == "Spin" then now * settings.FovSpeed * SPIN_RATE else 0
    local step = (math.pi * 2) / math.max(4, dots)
    for index = 0, math.max(4, dots) - 1 do
        local from = spin + index * step
        canvas.line(onCircle(center, radius, from), onCircle(center, radius, from + step * FILL), settings.FovCircleColor, alpha, settings.FovThickness)
    end
end

return Fov
end
modules["interface"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")
local Parts: typeof(require("./parts")) = import("parts")
local Changelog: typeof(require("./changelog")) = import("changelog")

local Interface = {}

type Actions = {
    chooseParts: () -> (),
    chooseNpcParts: () -> (),
    choosePath: (flag: string) -> (),
    blacklist: () -> (),
    scan: () -> (),
    detected: () -> number,
    playerList: (list: string) -> (),
    ranges: () -> (),
    distance: () -> (),
}

local MAX_SIZE = 100

local function countLabel(prefix: string, list: any, empty: string): string
    local total = if type(list) == "table" then #list else 0
    return prefix .. ": " .. (if total == 0 then empty else tostring(total))
end

local function header(section: any, text: string)
    section:label({ Text = text, Size = 12, Height = 28, Offset = 4 })
end

local function resetFlags(ui: any, flags: { string }): () -> ()
    return function()
        for _, flag in flags do
            ui:set(flag, Config.DEFAULTS[flag])
        end
    end
end

local function toggle(name: string, flag: string, extra: { [string]: any }?): { [string]: any }
    local descriptor: { [string]: any } = { Type = "Toggle", Name = name, Flag = flag, Default = Config.DEFAULTS[flag], Bindable = false }
    local overrides: { [string]: any } = extra or {}
    for key, value in overrides do
        descriptor[key] = value
    end
    return descriptor
end

local function slider(name: string, flag: string, min: number, max: number, extra: { [string]: any }?): { [string]: any }
    local descriptor: { [string]: any } = { Type = "Slider", Name = name, Flag = flag, Min = min, Max = max, Default = Config.DEFAULTS[flag], Step = 1, Unclamped = flag == "HitboxSize" }
    local overrides: { [string]: any } = extra or {}
    for key, value in overrides do
        descriptor[key] = value
    end
    return descriptor
end

local function hitbox(ui: any, actions: Actions)
    local tab = ui:tab("Hitbox", { Group = "Hitbox", Label = "Hitbox" })
    local section = tab:section("HITBOX")
    local defaults = Config.DEFAULTS
    header(section, "Expander")
    section:toggle({ Name = "Hitbox Expander", Flag = "Enabled", Default = defaults.Enabled })
    section:toggle({ Name = "Visualize", Flag = "VisualizerEnabled", Default = defaults.VisualizerEnabled })
    section:toggle({ Name = "Team Check", Flag = "TeamCheck", Default = defaults.TeamCheck })
    ui:flag("HoldKey", defaults.HoldKey)
    header(section, "Hold Mode")
    section:pair(toggle("Hold To Expand", "HoldMode", {
        Info = { Title = "Hold To Expand", Lines = { "Turn the Hitbox Expander on first. With hold mode", "on, hitboxes only grow while the hold key is down", "and go back to normal when you let go." }, Width = 320 },
    }), {
        Type = "Button",
        Name = "Hold Key",
        Label = function(window: any): string
            if window.Focus == window.CAPTURE_PREFIX .. "HoldKey" then
                return "Press a key..."
            end
            return "Hold Key: " .. window:shortKey(ui:get("HoldKey"))
        end,
        Callback = function(window: any)
            window:beginCapture(window.CAPTURE_PREFIX .. "HoldKey", function(key: string)
                ui:set("HoldKey", key)
            end)
        end,
    })
    section:toggle(toggle("Vehicle Fix", "VehicleFix", {
        Info = { Title = "Vehicle Fix", Lines = { "Stops expanded players from changing how vehicles", "drive. Their hitbox parts stop adding weight, and", "players sitting in a seat stop blocking raycasts." }, Width = 330 },
    }))
    header(section, "Size")
    section:slider(slider("Hitbox Size", "HitboxSize", 1, MAX_SIZE, {
        Disabled = function(window: any): boolean
            return window:get("DynamicSize") == true or window:get("CustomDimensions") == true
        end,
    }))
    ui:flag("TargetParts", defaults.TargetParts)
    section:button({
        Name = "Select Target Parts",
        Label = function()
            if Parts.arsenal() then
                return "Arsenal uses its own hitbox parts"
            end
            return "Target Parts: " .. Parts.label(ui:get("TargetParts"))
        end,
        Disabled = Parts.arsenal,
        Callback = actions.chooseParts,
    })
end

local function targeting(ui: any, actions: Actions)
    local tab = ui:tab("Targeting", { Group = "Targeting", Label = "Targeting" })
    local section = tab:section("TARGETING & FILTERS")
    local defaults = Config.DEFAULTS
    ui:flag("Targets", defaults.Targets)
    ui:flag("Whitelist", defaults.Whitelist)
    header(section, "Targets")
    section:dropdown({ Name = "Target Mode", Flag = "Mode", Values = { "All", "Target" }, Default = defaults.Mode })
    section:button({
        Name = "Target Player",
        Callback = function()
            actions.playerList("Targets")
        end,
    })
    section:button({
        Name = "Whitelist Player",
        Callback = function()
            actions.playerList("Whitelist")
        end,
    })
    header(section, "Checks")
    section:pair(toggle("Forcefield Check", "ForcefieldCheck"), toggle("Wall Check", "WallCheck"))
    section:pair(toggle("Dead Check", "DeadCheck"), toggle("Invisible Check", "InvisibleCheck"))
    section:toggle(toggle("Ignore Friends", "IgnoreFriends"))
end

local PART_GROUPS = {
    { Title = "CORE", Names = { "HumanoidRootPart", "Head" } },
    { Title = "R6", Names = { "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } },
    { Title = "R15 BODY", Names = { "UpperTorso", "LowerTorso" } },
    { Title = "R15 ARMS", Names = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" } },
    { Title = "R15 LEGS", Names = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" } },
}

local function partSizes(ui: any)
    local tab = ui:tab("Parts", { Group = "Parts", Label = "Parts" })
    local function off(name: string): (any) -> boolean
        return function(window: any): boolean
            if Parts.arsenal() or window:get("PartSizesEnabled") ~= true or window:get("DynamicSize") == true then
                return true
            end
            local selected = window:get("TargetParts")
            return type(selected) ~= "table" or (selected["All Parts"] ~= true and selected[name] ~= true)
        end
    end
    for index, group in PART_GROUPS do
        local section = tab:section(group.Title)
        if index == 1 then
            section:toggle({
                Name = "Part Sizes",
                Flag = "PartSizesEnabled",
                Default = Config.DEFAULTS.PartSizesEnabled,
                Disabled = function(window: any): boolean
                    return window:get("DynamicSize") == true
                end,
                Info = { Title = "Part Sizes", Lines = { "Every part has its own size. Only the parts you", "pick in Select Target Parts are expanded." }, Width = 320 },
            })
        end
        section:label({
            Text = "The part must be enabled in Hitbox > Targeting > Target Parts.",
            Label = function()
                return if Parts.arsenal() then "Arsenal uses its own hitbox parts, these sizes are not used." else "The part must be enabled in Hitbox > Targeting > Target Parts."
            end,
            Size = 11,
            Height = 20,
        })
        for _, name in group.Names do
            section:slider(slider(name .. " Size", Config.partFlag(name), 1, MAX_SIZE, { Disabled = off(name) }))
        end
    end
end

local function field(ui: any)
    local tab = ui:tab("FOV", { Group = "FOV", Label = "FOV" })
    local defaults = Config.DEFAULTS
    local hitboxSection = tab:section("FOV HITBOX")
    hitboxSection:toggle({ Name = "FOV Hitbox", Flag = "FovCheck", Default = defaults.FovCheck })
    hitboxSection:toggle({
        Name = "Single Target",
        Flag = "FovSingleTarget",
        Default = defaults.FovSingleTarget,
        Info = { Title = "Single Target", Lines = { "If enabled, this will make only one person", "have an extended hitbox and it's whoever is", "in the FOV, closest to the mouse." }, Width = 280 },
    })
    hitboxSection:slider(slider("FOV Size", "FovRadius", 10, 800))
    hitboxSection:pair(
        { Type = "Toggle", Name = "Show FOV", Flag = "ShowFovCircle", Default = defaults.ShowFovCircle, Bindable = false },
        { Type = "Color", Name = "Edit FOV Color", Flag = "FovCircleColor", Default = defaults.FovCircleColor }
    )
    hitboxSection:toggle(toggle("Names Visible Outside FOV", "VisOutsideFov", {
        Disabled = function(window: any): boolean
            return window:get("FovSingleTarget") == true
        end,
    }))

    local look = tab:section("FOV CUSTOMIZATION")
    look:dropdown({ Name = "FOV Animation", Flag = "FovAnim", Values = { "Static", "Breathe", "Spin" }, Default = defaults.FovAnim })
    look:slider(slider("FOV Speed", "FovSpeed", 1, 10))
    look:slider(slider("FOV Dots", "FovDots", 4, 100))
    look:slider(slider("FOV Thickness", "FovThickness", 1, 5, { Step = 0.5, Format = function(value: number): string
        return string.format("%.1f", value)
    end }))
    look:slider(slider("FOV Transparency", "FovTrans", 0, 1, { Step = 0.05 }))
end

local function dynamic(ui: any, actions: Actions)
    local tab = ui:tab("Dynamic", { Group = "Dynamic", Label = "Dynamic" })
    local section = tab:section("DYNAMIC")
    local defaults = Config.DEFAULTS
    local function limited(window: any): boolean
        return window:get("DistanceLimit") == true
    end
    for index = 1, Config.RANGE_COUNT do
        ui:flag("RangeMin" .. index, defaults["RangeMin" .. index])
        ui:flag("RangeMax" .. index, defaults["RangeMax" .. index])
        ui:flag("RangeSize" .. index, defaults["RangeSize" .. index])
    end
    ui:flag("ExtraRanges", defaults.ExtraRanges)
    ui:flag("MaxDistance", defaults.MaxDistance)
    ui:flag("VisOutsideDistance", defaults.VisOutsideDistance)
    header(section, "Dynamic Size")
    section:toggle({ Name = "Dynamic Size", Flag = "DynamicSize", Default = defaults.DynamicSize, Disabled = limited })
    section:toggle({
        Name = "Single Target",
        Flag = "DynamicSingleTarget",
        Default = defaults.DynamicSingleTarget,
        Disabled = limited,
        Info = { Title = "Single Target", Lines = { "If enabled, this will make only one person", "have an extended hitbox and it's whoever is", "in the FOV, closest to the mouse." }, Width = 280 },
    })
    section:toggle({
        Name = "Disable after max studs",
        Flag = "DisableBeyondMax",
        Default = defaults.DisableBeyondMax,
        Disabled = limited,
        Info = { Title = "Disable Info", Lines = { "If players are outside of the 1st to 5th", "max stud range they will not have extended", "hitboxes." }, Width = 280 },
    })
    header(section, "Distance")
    section:toggle({
        Name = "Limit Distance",
        Flag = "DistanceLimit",
        Default = defaults.DistanceLimit,
        Disabled = function(window: any): boolean
            return window:get("DynamicSize") == true
        end,
        Side = { Label = "...", OnClick = actions.distance },
    })
    section:button({ Name = "Stud Ranges", Callback = actions.ranges, Disabled = limited })
end

local function dimensions(ui: any)
    local tab = ui:tab("Dimensions", { Group = "Dimensions", Label = "Dimensions" })
    local section = tab:section("CUSTOM DIMENSIONS")
    section:toggle({ Name = "Custom Dimensions", Flag = "CustomDimensions", Default = Config.DEFAULTS.CustomDimensions })
    section:slider(slider("X Size", "DimX", 1, MAX_SIZE))
    section:slider(slider("Y Size", "DimY", 1, MAX_SIZE))
    section:slider(slider("Z Size", "DimZ", 1, MAX_SIZE))
end

local function npc(ui: any, actions: Actions)
    local tab = ui:tab("NPC", { Group = "NPC", Label = "NPC Hitbox" })
    local defaults = Config.DEFAULTS
    local section = tab:section("NPC HITBOX")
    header(section, "Expander")
    section:toggle({ Name = "NPC Hitbox", Flag = "ExpandNpc", Default = defaults.ExpandNpc, Bindable = false })
    section:slider(slider("NPC Hitbox Size", "NpcHitboxSize", 1, MAX_SIZE))
    ui:flag("NpcScanPaths", defaults.NpcScanPaths)
    ui:flag("NpcDeadPaths", defaults.NpcDeadPaths)
    ui:flag("NpcBlacklist", defaults.NpcBlacklist)
    local find = tab:section("NPC DETECTION")
    find:pair({
        Type = "Button",
        Name = "Scan Locations",
        Label = function(): string
            return countLabel("Scan Locations", ui:get("NpcScanPaths"), "All")
        end,
        Callback = function()
            actions.choosePath("NpcScanPaths")
        end,
    }, {
        Type = "Button",
        Name = "Dead Folders",
        Label = function(): string
            return countLabel("Dead Folders", ui:get("NpcDeadPaths"), "None")
        end,
        Callback = function()
            actions.choosePath("NpcDeadPaths")
        end,
    })
    find:pair({
        Type = "Button",
        Name = "Blacklist",
        Label = function(): string
            return countLabel("Blacklist", ui:get("NpcBlacklist"), "None")
        end,
        Callback = actions.blacklist,
    }, {
        Type = "Button",
        Name = "Rescan Now",
        Label = function(): string
            return "Rescan (" .. tostring(actions.detected()) .. " found)"
        end,
        Callback = actions.scan,
    })
    ui:flag("NpcTargetParts", defaults.NpcTargetParts)
    section:button({
        Name = "Select NPC Target Parts",
        Label = function()
            return "Target Parts: " .. Parts.label(ui:get("NpcTargetParts"))
        end,
        Callback = actions.chooseNpcParts,
    })
    header(section, "Checks")
    section:pair(toggle("NPC Dead Check", "NpcDeadCheck"), toggle("NPC Distance Limit", "NpcDistanceLimit"))
    section:slider(slider("Max NPC Distance", "MaxNpcDistance", 50, 600, { Step = 10 }))
end

local function npcVisuals(ui: any)
    local tab = ui:tab("NPCVisuals", { Group = "NPCVisuals", Label = "NPC Visuals" })
    local defaults = Config.DEFAULTS
    local section = tab:section("NPC VISUALIZER")
    header(section, "Display")
    section:pair(toggle("Visualize NPCs", "NpcVisualizerEnabled"), toggle("Show NPC Names", "NpcShowNames"))
    header(section, "Colors")
    section:pair(
        { Type = "Color", Name = "Edit NPC Outline", Flag = "NpcLineColor", Default = defaults.NpcLineColor },
        { Type = "Color", Name = "Edit NPC Fill", Flag = "NpcFillColor", Default = defaults.NpcFillColor }
    )
    header(section, "Transparency")
    section:slider(slider("Outline Transparency", "NpcLineTransparency", 0, 1, { Step = 0.05 }))
    section:slider(slider("Fill Transparency", "NpcFillTransparency", 0, 1, { Step = 0.05 }))
    section:pair(
        { Type = "Button", Name = "Reset NPC Colors", Callback = resetFlags(ui, { "NpcFillColor", "NpcLineColor", "NpcTextColor" }) },
        { Type = "Button", Name = "Reset NPC Transparency", Callback = resetFlags(ui, { "NpcFillTransparency", "NpcLineTransparency", "NpcTextTransparency" }) }
    )
    section:pair(
        { Type = "Color", Name = "Edit NPC Text Color", Flag = "NpcTextColor", Default = defaults.NpcTextColor },
        slider("Outline Width", "NpcLineWidth", 1, 5, { Step = 0.5 })
    )
    section:slider(slider("Text Transparency", "NpcTextTransparency", 0, 1, { Step = 0.05 }))
end

local function visualizer(ui: any)
    local tab = ui:tab("Visualizer", { Group = "Visualizer", Label = "Visualizer" })
    local defaults = Config.DEFAULTS
    local section = tab:section("VISUALIZER")
    header(section, "Display")
    section:pair(
        { Type = "Dropdown", Name = "Visualizer Style", Flag = "VisualizerMode", Values = { "3D", "2D" }, Default = defaults.VisualizerMode },
        toggle("Show Names", "ShowNames")
    )
    section:pair(toggle("Show Health", "ShowHealth"), toggle("Show Distance", "ShowDistance"))
    header(section, "Colors")
    section:pair(
        { Type = "Color", Name = "Edit Line Color", Flag = "LineColor", Default = defaults.LineColor },
        { Type = "Color", Name = "Edit Fill Color", Flag = "FillColor", Default = defaults.FillColor }
    )
    section:pair(
        { Type = "Color", Name = "Edit Text Color", Flag = "TextColor", Default = defaults.TextColor },
        { Type = "Button", Name = "Reset Colors", Callback = resetFlags(ui, { "FillColor", "LineColor", "TextColor" }) }
    )
    header(section, "Transparency")
    section:slider(slider("Line Transparency", "LineTransparency", 0, 1, { Step = 0.05 }))
    section:slider(slider("Fill Transparency", "FillTransparency", 0, 1, { Step = 0.05 }))
    section:button({ Name = "Reset Trans Defaults", Callback = resetFlags(ui, { "LineTransparency", "FillTransparency", "TextTransparency" }) })
    section:slider(slider("Text Transparency", "TextTransparency", 0, 1, { Step = 0.05 }))
    header(section, "Outline")
    section:slider(slider("Line Width", "LineWidth", 1, 5, { Step = 0.5 }))
    section:toggle({ Name = "Center Target Indicator", Flag = "TargetIndicator", Default = defaults.TargetIndicator })
end

local function changelog(ui: any)
    ui:updates({ Version = Changelog.VERSION, Date = Changelog.DATE, Groups = Changelog.GROUPS, History = Changelog.HISTORY, Closing = Changelog.CLOSING })
end

function Interface.build(ui: any, actions: Actions)
    hitbox(ui, actions)
    visualizer(ui)
    targeting(ui, actions)
    partSizes(ui)
    field(ui)
    dynamic(ui, actions)
    dimensions(ui)
    npc(ui, actions)
    ui:home({
        QuickLabel = "Quick Settings",
        QuickStart = {
            { Title = "Hitbox Expander", Icon = "box", Flag = "Enabled" },
            { Title = "Visualize", Icon = "eye", Flag = "VisualizerEnabled" },
            { Title = "Team Check", Icon = "shield-check", Flag = "TeamCheck" },
            { Title = "Part Sizes", Icon = "sliders-horizontal", Flag = "PartSizesEnabled" },
        },
    })
    npcVisuals(ui)
    changelog(ui)
end

return Interface
end
modules["lists"] = function(...)

local import: (string) -> any = ...
local World: typeof(require("./world")) = import("world")

local Lists = {}

type Map = { [string]: any }

local SEARCH_KEY = "playerlist:search"
local WIDTH, HEIGHT = 660, 410
local COLUMNS, COLUMN_GAP = 2, 6
local CARD_HEIGHT, CARD_GAP = 44, 5
local AVATAR = 32
local OUTLINE = 2
local SEARCH_HEIGHT = 28
local ACTION_WIDTH = 66
local TOP_EDGE = 6
local TITLES: { [string]: string } = { Targets = "Target Player", Whitelist = "Whitelist Player" }

local function thumbnail(userId: number): string
    return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", userId)
end

local function count(active: { [string]: boolean }): number
    local total = 0
    for _ in active do
        total += 1
    end
    return total
end

local function tail(kit: any, text: string, limit: number): string
    local cut = 1
    while cut < #text and kit:measure(string.sub(text, cut), 13) > limit do
        cut += 1
    end
    return string.sub(text, cut)
end

local function card(kit: any, window: Map, entry: Map, active: boolean, x: number, y: number, width: number, toggle: () -> ())
    local pal = window.Pal
    local lit = kit:ease("playerlist:lit:" .. entry.Name, if active then 1 else 0, 14)
    local inset = OUTLINE * lit
    kit:rect(x, y, width, CARD_HEIGHT, pal.Accent, lit, 8)
    kit:rect(x + inset, y + inset, width - inset * 2, CARD_HEIGHT - inset * 2, pal.Panel:Lerp(pal.Off, lit), 1, 8 - inset * 0.5)
    local top = y + (CARD_HEIGHT - AVATAR) / 2
    kit:rect(x + 6, top, AVATAR, AVATAR, pal.Off, 1, 6)
    kit:text(string.upper(string.sub(entry.Display, 1, 1)), x + 6 + AVATAR / 2, top + AVATAR / 2, 13, pal.Sub, true, true)
    if entry.UserId then
        kit:image(thumbnail(entry.UserId), x + 6, top, AVATAR, AVATAR, 6)
    end
    local textLeft = AVATAR + 16
    kit:text(string.sub(entry.Display, 1, 28), x + textLeft, y + 14, 13, pal.Text, false, true)
    kit:text(if entry.Online then "@" .. entry.Name else "@" .. entry.Name .. "  -  not in the server", x + textLeft, y + 30, 10, pal.Sub, false, true)
    kit:hit("playerlist:card:" .. entry.Name, x, y, width, CARD_HEIGHT, toggle)
    kit:miniSwitch("playerlist:switch:" .. entry.Name, x + width - 12 - 36, y + (CARD_HEIGHT - 20) / 2, active, toggle)
end

local function entries(active: { [string]: boolean }): ({ Map }, { Map })
    local online: { Map } = {}
    local known: { [string]: Map } = {}
    for _, player in World.Players:GetPlayers() do
        if player ~= World.LocalPlayer then
            local entry = { Name = player.Name, Display = player.DisplayName, UserId = player.UserId, Online = true }
            known[player.Name] = entry
            table.insert(online, entry)
        end
    end
    table.sort(online, function(a: Map, b: Map): boolean
        return string.lower(a.Display) < string.lower(b.Display)
    end)
    local listed: { Map } = {}
    for name in active do
        table.insert(listed, known[name] or { Name = name, Display = name, UserId = nil, Online = false })
    end
    table.sort(listed, function(a: Map, b: Map): boolean
        return string.lower(a.Display) < string.lower(b.Display)
    end)
    return online, listed
end

function Lists.register(ui: any)
    local views: { [string]: number } = { Targets = 1, Whitelist = 1 }
    local query = ""
    ui:popup("playerlist", {
        Width = WIDTH,
        Height = HEIGHT,
        Title = "",
        Render = function(kit: any, window: Map, arg: any)
            local pal = window.Pal
            local flag = if arg == "Whitelist" then "Whitelist" else "Targets"
            local active: { [string]: boolean } = ui:get(flag) or {}
            local online, listed = entries(active)

            local top = kit:header(TITLES[flag], tostring(count(active)) .. " active, " .. tostring(#online) .. " in the server", function()
                window:closePopup()
            end)
            local focused = window.Focus == SEARCH_KEY
            kit:input(SEARCH_KEY, 16, top, WIDTH - 32, SEARCH_HEIGHT, if query == "" then "Search..." else tail(kit, query, WIDTH - 48), function()
                window:beginInput(SEARCH_KEY, query, {
                    commit = function(text: string)
                        query = text
                    end,
                })
            end)
            if focused then
                query = window.Buffers[SEARCH_KEY] or ""
            end

            local view = views[flag]
            local tabY = top + SEARCH_HEIGHT + 8
            kit:segment("playerlist:view", 16, tabY, 220, 26, {
                "In Server (" .. tostring(#online) .. ")",
                "Active (" .. tostring(#listed) .. ")",
            }, view, function(index: number)
                views[flag] = index
            end)
            local wanted = string.lower(query)
            local list: { Map } = {}
            local source = if view == 1 then online else listed
            for _, entry in source do
                if wanted == "" or string.find(string.lower(entry.Name), wanted, 1, true) or string.find(string.lower(entry.Display), wanted, 1, true) then
                    table.insert(list, entry)
                end
            end
            kit:button("playerlist:all", WIDTH - 16 - ACTION_WIDTH * 2 - 6, tabY, ACTION_WIDTH, 26, function()
                local updated: { [string]: boolean } = table.clone(active)
                for _, entry in list do
                    updated[entry.Name] = true
                end
                ui:set(flag, updated)
            end, { label = "Add All", size = 11, rounding = 12, disabled = view ~= 1 or #list == 0 })
            kit:button("playerlist:clear", WIDTH - 16 - ACTION_WIDTH, tabY, ACTION_WIDTH, 26, function()
                ui:set(flag, {})
            end, { label = "Clear", size = 11, rounding = 12, disabled = count(active) == 0 })

            local listTop = tabY + 36
            local listHeight = HEIGHT - listTop - 14
            if #list == 0 then
                local text = if wanted ~= "" then "No players match your search" elseif view == 1 then "Nobody else is in the server" else "No active players yet"
                kit:text(text, WIDTH / 2, listTop + listHeight / 2, 12, pal.Sub, true, true)
                return
            end
            kit:scroll("playerlist:list:" .. flag .. ":" .. tostring(view), 16, listTop, WIDTH - 32, listHeight, CARD_HEIGHT + CARD_GAP, math.ceil(#list / COLUMNS), function(row: number, x: number, y: number, width: number)
                local cardWidth = (width - (COLUMNS - 1) * COLUMN_GAP) / COLUMNS
                for column = 1, COLUMNS do
                    local entry = list[(row - 1) * COLUMNS + column]
                    if entry then
                        kit:nest("card:" .. entry.Name, function()
                            card(kit, window, entry, active[entry.Name] == true, x + (column - 1) * (cardWidth + COLUMN_GAP), y, cardWidth, function()
                                local updated: { [string]: boolean } = table.clone(active)
                                if updated[entry.Name] then
                                    updated[entry.Name] = nil
                                else
                                    updated[entry.Name] = true
                                end
                                ui:set(flag, updated)
                            end)
                        end)
                    end
                end
            end, TOP_EDGE)
        end,
    })
end

return Lists
end
modules["main"] = function(...)

local import: (string) -> any = ...
local Blacklist: typeof(require("./blacklist")) = import("blacklist")
local Changelog: typeof(require("./changelog")) = import("changelog")
local Config: typeof(require("./config")) = import("config")
local Expander: typeof(require("./expander")) = import("expander")
local Explorer: typeof(require("./explorer")) = import("explorer")
local Filters: typeof(require("./filters")) = import("filters")
local Fov: typeof(require("./fov")) = import("fov")
local Interface: typeof(require("./interface")) = import("interface")
local Lists: typeof(require("./lists")) = import("lists")
local Npcs: typeof(require("./npcs")) = import("npcs")
local Parts: typeof(require("./parts")) = import("parts")
local Picker: typeof(require("./picker")) = import("picker")
local Ranges: typeof(require("./ranges")) = import("ranges")
local Visual: typeof(require("./visual")) = import("visual")
local World: typeof(require("./world")) = import("world")

local REGISTRY = "__HitboxExpanderStop"
local HUB_HOOK = "__BoogaOnScriptUnloaded"
local NPC_SCAN_SECONDS = 1
local SETTINGS_SECONDS = 0.05
local STEP_SECONDS = 1 / 90

type Map = { [string]: any }
type Shown = { Root: any, Size: Vector3, Npc: boolean, Box: boolean, Text: string? }
type Candidate = { Player: any, Distance: number, Root: any, Edge: number, Health: number? }

local function stopPrevious()
    local previous = getgenv()[REGISTRY]
    if type(previous) == "function" then
        pcall(previous)
    end
end

return function(OkloUI: any, reload: () -> (), Loader: any): Map?
    stopPrevious()
    local players: any = World.Players
    local runService: any = game:GetService("RunService")
    local playerExpander = Expander.new()
    local npcExpander = Expander.new()
    local connections: { any } = {}
    local settings: Map = table.clone(Config.DEFAULTS)
    local shown: { Shown } = {}
    local indicator: { Position: Vector2, Root: any, Name: string, Distance: number }? = nil
    local npcs: { any } = {}
    local lastScan = -math.huge
    local lastRead = -math.huge
    local lastStep = -math.huge
    local running = true
    local Keys: any = OkloUI.Keys
    local unbindSync: (() -> ())? = nil

    local ui: any
    local function stop()
        if not running then
            return
        end
        running = false
        getgenv()[REGISTRY] = nil
        for _, link in connections do
            pcall(function()
                link:Disconnect()
            end)
        end
        table.clear(connections)
        playerExpander:restoreAll()
        npcExpander:restoreAll()
        Blacklist.release()
        if unbindSync then
            unbindSync()
        end
        local hook = getgenv()[HUB_HOOK]
        if type(hook) == "function" then
            pcall(hook, "Expander")
        end
    end

    ui = OkloUI.new({
        Title = "oklo: HBE",
        Subtitle = "universal",
        Version = Changelog.VERSION,
        Changelog = Changelog,
        Id = "Hitbox Expander",
        Folder = "oklo scripts/hitboxexpander",
        Logo = { Emblem = true },
        Footer = "oklo",
        Discord = "https://discord.gg/oklo",
        FirstRunInvite = true,
        Thanks = true,
        Width = 700,
        CompactSidebar = false,
        Height = 460,
        Theme = "Neon Tokyo",
        OnUnload = stop,
        OnReload = reload,
    })

    local actions = {
        chooseParts = function()
            ui:openPopup("targetparts")
        end,
        chooseNpcParts = function()
            ui:openPopup("npcparts")
        end,
        choosePath = function(flag: string)
            Explorer.open(ui, flag)
        end,
        blacklist = function()
            Blacklist.open(ui)
        end,
        scan = function()
            lastScan = -math.huge
        end,
        detected = function(): number
            return #npcs
        end,
        playerList = function(list: string)
            ui:openPopup("playerlist", list)
        end,
        ranges = function()
            ui:openPopup("ranges")
        end,
        distance = function()
            ui:openPopup("maxdistance")
        end,
    }
    Interface.build(ui, actions)
    Picker.register(ui)
    Explorer.register(ui)
    Blacklist.register(ui)
    Lists.register(ui)
    Ranges.register(ui)
    Ranges.registerDistance(ui)

    local SIZE_EASE = 20

    local function primary(parts: { any }, root: any): any
        if table.find(parts, root) then
            return root
        end
        return parts[1] or root
    end

    local function considerIndicator(root: any, name: string, distance: number, camera: any, center: Vector2, best: number): number
        local screen, onScreen = camera:WorldToViewportPoint(root.Position)
        if not onScreen or screen.Z <= 0.1 then
            return best
        end
        local point = Vector2.new(screen.X, screen.Y)
        local away = (point - center).Magnitude
        if away < best then
            indicator = { Position = point, Root = root, Name = name, Distance = distance }
            return away
        end
        return best
    end

    local lookupKey: any = nil
    local function originalOf(part: any): number?
        return playerExpander:originalTransparency(lookupKey, part)
    end

    local function caption(name: string, health: number?, distance: number): string?
        local pieces: { string } = {}
        if settings.ShowNames then
            table.insert(pieces, name)
        end
        if settings.ShowHealth and health then
            table.insert(pieces, string.format("%d HP", math.floor(health + 0.5)))
        end
        if settings.ShowDistance then
            table.insert(pieces, string.format("%d studs", math.floor(distance)))
        end
        if #pieces == 0 then
            return nil
        end
        return table.concat(pieces, " - ")
    end

    local function healthOf(character: any): number?
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        return if humanoid then humanoid.Health else nil
    end

    local function pick(candidates: { Candidate }, camera: any): Candidate?
        local best: Candidate? = nil
        local bestAway = math.huge
        for _, candidate in candidates do
            local away = Filters.screenDistance(camera, candidate.Root)
            if away and (not (settings.FovCheck and settings.FovSingleTarget) or away <= settings.FovRadius) and away < bestAway then
                best, bestAway = candidate, away
            end
        end
        return best
    end

    local function expandPlayer(candidate: Candidate, camera: any, center: Vector2, best: number): number
        local player = candidate.Player
        local character = player.Character
        local parts = Parts.forPlayer(character, settings.TargetParts)
        local size = Filters.box(settings, candidate.Edge)
        local sizes = Filters.partSizes(settings, parts)
        local fix: { Mine: any? }? = if settings.VehicleFix then { Mine = World.localRoot() } else nil
        playerExpander:apply(player, character, parts, size, sizes, fix)
        local text = caption(player.DisplayName, candidate.Health, candidate.Distance)
        local main = primary(parts, candidate.Root)
        table.insert(shown, { Root = main, Size = if sizes and sizes[main] then sizes[main] else size, Npc = false, Box = true, Text = text })
        if settings.TargetIndicator then
            return considerIndicator(candidate.Root, player.DisplayName, candidate.Distance, camera, center, best)
        end
        return best
    end

    local function step()
        if not running then
            return
        end
        local clock = os.clock()
        if clock - lastStep < STEP_SECONDS then
            return
        end
        lastStep = clock
        if clock - lastRead >= SETTINGS_SECONDS then
            lastRead = clock
            settings = Config.read(ui)
        end
        local camera = World.camera()
        local mineRoot = World.localRoot()
        table.clear(shown)
        indicator = nil
        if not camera then
            return
        end
        local viewport = camera.ViewportSize
        local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
        local best = math.huge
        local active = settings.Enabled and Filters.held(settings, Keys, Keys.pressed(true))
        local single = (settings.FovCheck and settings.FovSingleTarget) or (settings.DynamicSize and settings.DynamicSingleTarget)
        local skipField = settings.FovCheck and settings.FovSingleTarget

        if active then
            local candidates: { Candidate } = {}
            for _, player in players:GetPlayers() do
                lookupKey = player
                local valid, distance, root, reason = Filters.player(settings, player, camera, mineRoot, originalOf, skipField)
                local edge = if valid then Filters.edge(settings, distance) else nil
                if valid and edge then
                    table.insert(candidates, { Player = player, Distance = distance, Root = root, Edge = edge, Health = healthOf(player.Character) })
                else
                    playerExpander:restore(player)
                    local outside = (reason == "distance" and settings.VisOutsideDistance) or (reason == "fov" and settings.VisOutsideFov)
                    if outside and root then
                        local text = caption(player.DisplayName, healthOf(player.Character), distance)
                        if text then
                            table.insert(shown, { Root = root, Size = Vector3.new(4, 5, 2), Npc = false, Box = false, Text = text })
                        end
                    end
                end
            end
            local chosen: Candidate? = if single then pick(candidates, camera) else nil
            for _, candidate in candidates do
                if not single or candidate == chosen then
                    best = expandPlayer(candidate, camera, center, best)
                else
                    playerExpander:restore(candidate.Player)
                end
            end
        else
            playerExpander:restoreAll()
        end

        if settings.ExpandNpc and (not settings.HoldMode or active) then
            local now = os.clock()
            if now - lastScan > NPC_SCAN_SECONDS then
                lastScan = now
                npcs = Npcs.scan(settings)
            end
            local alive: { [any]: boolean } = {}
            for _, model in npcs do
                if model.Parent then
                    alive[model] = true
                    local valid, distance, root = Npcs.valid(settings, model, mineRoot)
                    if valid then
                        local size = Vector3.new(settings.NpcHitboxSize, settings.NpcHitboxSize, settings.NpcHitboxSize)
                        local parts = Parts.forNpc(model, settings.NpcTargetParts)
                        npcExpander:apply(model, model, parts, size, nil, if settings.VehicleFix then { Mine = mineRoot } else nil)
                        table.insert(shown, { Root = primary(parts, root), Size = size, Npc = true, Box = true, Text = if settings.NpcShowNames then model.Name else nil })
                        if settings.TargetIndicator then
                            best = considerIndicator(root, model.Name, distance, camera, center, best)
                        end
                    else
                        npcExpander:restore(model)
                    end
                end
            end
            for _, key in npcExpander:keys() do
                if not alive[key] then
                    npcExpander:restore(key)
                end
            end
        else
            npcExpander:restoreAll()
        end
    end

    local smoothed: { [any]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
    local lastDraw = os.clock()

    local function glide(root: any, goal: Vector3, dt: number): Vector3
        local current = smoothed[root]
        if not current then
            smoothed[root] = goal
            return goal
        end
        local nextSize = current:Lerp(goal, 1 - math.exp(-SIZE_EASE * dt))
        if (nextSize - goal).Magnitude < 0.01 then
            nextSize = goal
        end
        smoothed[root] = nextSize
        return nextSize
    end

    local drawStyles: { Player: any, Npc: any } = {
        Player = { Mode = "3D", FillColor = Color3.new(), FillTransparency = 1, LineColor = Color3.new(), LineTransparency = 1, LineWidth = 1 },
        Npc = { Mode = "3D", FillColor = Color3.new(), FillTransparency = 1, LineColor = Color3.new(), LineTransparency = 1, LineWidth = 1 },
    }
    local drawTag = { Text = "", Color = Color3.new(), Alpha = 1 }

    local function draw(frame: Map)
        local drawNow = os.clock()
        local dt = math.min(drawNow - lastDraw, 0.1)
        lastDraw = drawNow
        local canvas = frame.Canvas
        local camera = frame.Camera
        if settings.ShowFovCircle then
            Fov.draw(canvas, frame.Mouse, settings, frame.Now)
        end
        if not camera then
            return
        end
        local playerStyle = drawStyles.Player
        local npcStyle = drawStyles.Npc
        playerStyle.Mode = settings.VisualizerMode
        playerStyle.FillColor = settings.FillColor
        playerStyle.FillTransparency = settings.FillTransparency
        playerStyle.LineColor = settings.LineColor
        playerStyle.LineTransparency = settings.LineTransparency
        playerStyle.LineWidth = settings.LineWidth
        npcStyle.Mode = settings.VisualizerMode
        npcStyle.FillColor = settings.NpcFillColor
        npcStyle.FillTransparency = settings.NpcFillTransparency
        npcStyle.LineColor = settings.NpcLineColor
        npcStyle.LineTransparency = settings.NpcLineTransparency
        npcStyle.LineWidth = settings.NpcLineWidth
        for _, entry in shown do
            if entry.Root.Parent then
                local npc = entry.Npc
                local tag: { Text: string, Color: Color3, Alpha: number }? = nil
                if entry.Text then
                    tag = drawTag
                    drawTag.Text = entry.Text
                    drawTag.Color = if npc then settings.NpcTextColor else settings.TextColor
                    drawTag.Alpha = 1 - (if npc then settings.NpcTextTransparency else settings.TextTransparency)
                end
                if entry.Box and (if npc then settings.NpcVisualizerEnabled else settings.VisualizerEnabled) then
                    local style = if npc then npcStyle else playerStyle
                    Visual.box(canvas, camera, entry.Root, glide(entry.Root, entry.Size, dt), style, tag)
                elseif tag then
                    Visual.label(canvas, entry.Root, entry.Size, tag)
                end
            end
        end
        local target = indicator
        if target and target.Root.Parent then
            local viewport = camera.ViewportSize
            canvas.line(Vector2.new(viewport.X * 0.5, viewport.Y * 0.5), target.Position, settings.LineColor, 1, 1)
            canvas.text(target.Position + Vector2.new(0, 14), 12, Color3.new(1, 1, 1), 1, string.format("%s - %d studs", target.Name, math.floor(target.Distance)), true, nil)
        end
    end

    table.insert(connections, runService.RenderStepped:Connect(step))
    table.insert(connections, players.PlayerRemoving:Connect(function(player: any)
        playerExpander:restore(player)
    end))
    unbindSync = Expander.bindSync({ playerExpander, npcExpander })
    ui:onFrame(draw)
    ui:start()
    getgenv()[REGISTRY] = function()
        ui:unload()
    end

    local api: Map = {}
    function api.Stop()
        ui:unload()
    end
    return api
end
end
modules["npcs"] = function(...)

local import: (string) -> any = ...
local World: typeof(require("./world")) = import("world")

local Npcs = {}

local workspaceService: any = game:GetService("Workspace")

function Npcs.blacklisted(settings: { [string]: any }, model: any): boolean
    if not model or not model.Name then
        return false
    end
    local name = string.lower(model.Name)
    for _, word in settings.NpcBlacklist do
        if word ~= "" and string.find(name, word, 1, true) then
            return true
        end
    end
    return false
end

local scanRoots: { any } = {}
local deadFolders: { any } = {}

local function resolveAll(paths: any): { any }
    local list: { any } = {}
    if type(paths) == "table" then
        for _, path in paths do
            local found = World.resolve(path)
            if found and found.Parent then
                table.insert(list, found)
            end
        end
    end
    return list
end

local function within(model: any, folders: { any }): boolean
    for _, folder in folders do
        if model == folder or model:IsDescendantOf(folder) then
            return true
        end
    end
    return false
end

function Npcs.scan(settings: { [string]: any }): { any }
    local found: { any } = {}
    local seen: { [any]: boolean } = {}
    scanRoots = resolveAll(settings.NpcScanPaths)
    deadFolders = resolveAll(settings.NpcDeadPaths)
    local roots = if #scanRoots > 0 then scanRoots else { workspaceService }
    for _, root in roots do
        for _, descendant in root:GetDescendants() do
            if descendant:IsA("Humanoid") then
                local model = descendant.Parent
                if model and model:IsA("Model") and not seen[model] and not model:IsDescendantOf(workspaceService.CurrentCamera) then
                    seen[model] = true
                    if not World.Players:GetPlayerFromCharacter(model) and not Npcs.blacklisted(settings, model) and not within(model, deadFolders) then
                        table.insert(found, model)
                    end
                end
            end
        end
    end
    return found
end

function Npcs.valid(settings: { [string]: any }, model: any, mineRoot: any): (boolean, number, any)
    if not model or not model:IsA("Model") or not model.Parent or model:IsDescendantOf(workspaceService.CurrentCamera) then
        return false, 0, nil
    end
    if World.Players:GetPlayerFromCharacter(model) or Npcs.blacklisted(settings, model) then
        return false, 0, nil
    end
    if within(model, deadFolders) then
        return false, 0, nil
    end
    if #scanRoots > 0 and not within(model, scanRoots) then
        return false, 0, nil
    end
    local humanoid = World.humanoidOf(model)
    if not humanoid or (settings.NpcDeadCheck and humanoid.Health <= 0) then
        return false, 0, nil
    end
    local root = World.rootOf(model)
    if not root or not root:IsA("BasePart") or not mineRoot then
        return false, 0, nil
    end
    local distance = (root.Position - mineRoot.Position).Magnitude
    if settings.NpcDistanceLimit and distance > settings.MaxNpcDistance then
        return false, 0, nil
    end
    return true, distance, root
end

return Npcs
end
modules["parts"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")

local Parts = {}

local ALL_NAMES = {
    "HumanoidRootPart", "Head", "Torso", "UpperTorso", "LowerTorso",
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local ARM_FALLBACKS: { [string]: string } = {
    ["Left Arm"] = "LeftUpperArm",
    ["Right Arm"] = "RightUpperArm",
    ["Left Leg"] = "LeftUpperLeg",
    ["Right Leg"] = "RightUpperLeg",
}

local function isPart(object: any): boolean
    return object ~= nil and object:IsA("BasePart")
end

local function add(list: { any }, part: any)
    if isPart(part) and not table.find(list, part) then
        table.insert(list, part)
    end
end

local IS_ARSENAL = game.PlaceId == Config.ARSENAL_PLACE

function Parts.arsenal(): boolean
    return IS_ARSENAL
end

function Parts.forPlayer(character: any, selected: { [string]: boolean }): { any }
    local list: { any } = {}
    if Parts.arsenal() then
        for _, name in Config.ARSENAL_PARTS do
            add(list, character:FindFirstChild(name))
        end
        if #list == 0 then
            add(list, character:FindFirstChild("HumanoidRootPart"))
        end
        return list
    end
    if selected["All Parts"] then
        for _, name in ALL_NAMES do
            add(list, character:FindFirstChild(name))
        end
        return list
    end
    for _, entry in Config.TARGET_PARTS do
        local name = entry.Name
        if selected[name] then
            if name == "Torso" then
                add(list, character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("LowerTorso"))
            else
                local found = character:FindFirstChild(name)
                if isPart(found) then
                    add(list, found)
                elseif ARM_FALLBACKS[name] then
                    add(list, character:FindFirstChild(ARM_FALLBACKS[name]))
                end
            end
        end
    end
    if #list == 0 then
        add(list, character:FindFirstChild("HumanoidRootPart"))
    end
    return list
end

function Parts.forNpc(model: any, selected: { [string]: boolean }): { any }
    local list: { any } = {}
    if selected["All Parts"] then
        for _, descendant in model:GetDescendants() do
            add(list, descendant)
        end
    else
        for _, part in Parts.forPlayer(model, selected) do
            add(list, part)
        end
    end
    if #list == 0 then
        add(list, model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("Head") or model.PrimaryPart)
    end
    return list
end

function Parts.label(selected: { [string]: boolean }): string
    if selected["All Parts"] then
        return "All Parts"
    end
    local names: { string } = {}
    for _, entry in Config.TARGET_PARTS do
        if selected[entry.Name] then
            table.insert(names, entry.Name)
        end
    end
    if #names == 0 then
        return "HumanoidRootPart"
    elseif #names == 1 then
        return names[1]
    end
    return tostring(#names) .. " parts"
end

return Parts
end
modules["picker"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")

local Picker = {}

local WIDTH, HEIGHT = 442, 430
local COLUMN = (WIDTH - 32 - 8) / 2
local ROW = 26

local function copy(parts: { [string]: boolean }): { [string]: boolean }
    local clone: { [string]: boolean } = {}
    for name, value in parts do
        clone[name] = value
    end
    return clone
end

local function build(ui: any, popup: string, flag: string, subtitle: string)
    ui:popup(popup, {
        Width = WIDTH,
        Height = HEIGHT,
        Title = "",
        Render = function(kit: any, window: any)
            kit:header("Target Parts", subtitle, function()
                window:closePopup()
            end)
            local selected: { [string]: boolean } = ui:get(flag)
            local presets = { { Name = "All", Parts = nil :: { string }? } }
            for _, preset in Config.PRESETS do
                table.insert(presets, preset)
            end
            table.insert(presets, { Name = "Reset", Parts = { "HumanoidRootPart" } })
            local chip = (WIDTH - 32 - (#presets - 1) * 5) / #presets
            for index, preset in presets do
                kit:button(popup .. ":preset:" .. index, 16 + (index - 1) * (chip + 5), 62, chip, 26, function()
                    local result: { [string]: boolean } = {}
                    if preset.Parts then
                        for _, name in preset.Parts do
                            result[name] = true
                        end
                    else
                        for _, entry in Config.TARGET_PARTS do
                            result[entry.Name] = true
                        end
                        result["All Parts"] = true
                    end
                    ui:set(flag, result)
                end, { label = preset.Name, size = 11, rounding = 12 })
            end
            for index, entry in Config.TARGET_PARTS do
                local column = (index - 1) % 2
                local row = math.floor((index - 1) / 2)
                local name = entry.Name
                kit:switchRow(popup .. ":part:" .. index, 16 + column * (COLUMN + 8), 100 + row * (ROW + 3), COLUMN, ROW, name, selected[name] == true, function()
                    local result = copy(selected)
                    result["All Parts"] = nil
                    if result[name] then
                        result[name] = nil
                    else
                        result[name] = true
                    end
                    if next(result) == nil then
                        result["HumanoidRootPart"] = true
                    end
                    ui:set(flag, result)
                end)
            end
        end,
    })
end

function Picker.register(ui: any)
    build(ui, "targetparts", "TargetParts", "Parts of the character that grow")
    build(ui, "npcparts", "NpcTargetParts", "Parts of the NPC that grow")
end

return Picker
end
modules["ranges"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")

local Ranges = {}

local WIDTH = 420
local SWITCH_Y, SWITCH_HEIGHT = 60, 28
local TOP = 124
local STEP = 28
local CARD = 25
local BASE_ROWS = 5
local FIELD = 78
local EASE = 11

local COLUMNS = {
    { Key = "RangeMin", Label = "From", X = 98 },
    { Key = "RangeMax", Label = "To", X = 188 },
    { Key = "RangeSize", Label = "Size", X = 278 },
}

local shown = 0
local clock = os.clock()

local function advance(extra: boolean): number
    local now = os.clock()
    local dt = math.min(now - clock, 0.05)
    clock = now
    local goal = if extra then 1 else 0
    shown += (goal - shown) * (1 - math.exp(-EASE * dt))
    if math.abs(goal - shown) < 0.002 then
        shown = goal
    end
    return shown
end

local function rowCount(): number
    return BASE_ROWS + (Config.RANGE_COUNT - BASE_ROWS) * shown
end

function Ranges.register(ui: any)
    ui:popup("ranges", {
        Width = WIDTH,
        Height = 360,
        Title = "",
        Size = function(): (number, number)
            advance(ui:get("ExtraRanges") == true)
            return WIDTH, math.floor(TOP + rowCount() * STEP + 50)
        end,
        Render = function(kit: any, window: any)
            local pal = window.Pal
            kit:header("Stud Ranges", "Hitbox size for every distance range", function()
                window:closePopup()
            end)
            kit:switchRow("ranges:extra", 16, SWITCH_Y, WIDTH - 32, SWITCH_HEIGHT, "Extra Ranges (10)", ui:get("ExtraRanges") == true, function()
                ui:set("ExtraRanges", not ui:get("ExtraRanges"))
            end)
            kit:rect(16, TOP - 28, WIDTH - 32, 22, pal.Panel, 1, 10)
            for _, column in COLUMNS do
                kit:text(column.Label, column.X + FIELD / 2, TOP - 17, 11, pal.Sub, true, true)
            end
            local rows = rowCount()
            local baseAlpha = kit.Alpha
            for index = 1, Config.RANGE_COUNT do
                local fade = math.clamp(rows - (index - 1), 0, 1)
                if fade > 0.02 then
                    kit.Alpha = baseAlpha * fade
                    local y = TOP + (index - 1) * STEP
                    kit:scope("ranges:row:" .. index)
                    kit:rect(16, y, WIDTH - 32, CARD, pal.Panel, 1, 12)
                    kit:text("Range " .. index, 30, y + CARD / 2, 12, pal.Sub, false, true)
                    for _, column in COLUMNS do
                        local flag = column.Key .. index
                        local key = "ranges:" .. flag
                        kit:input(key, column.X, y + 2, FIELD, CARD - 4, tostring(ui:get(flag)), function()
                            window:beginInput(key, tostring(ui:get(flag)), {
                                numeric = true,
                                maxLength = 5,
                                commit = function(text: string)
                                    local value = tonumber(text)
                                    if value then
                                        ui:set(flag, math.clamp(value, 0, 100000))
                                    end
                                end,
                            })
                        end, pal.Main)
                    end
                    kit:scope(nil)
                end
            end
            kit.Alpha = baseAlpha
            kit:button("ranges:reset", 16, TOP + rows * STEP + 4, WIDTH - 32, 30, function()
                for index, range in Config.RANGE_DEFAULTS do
                    ui:set("RangeMin" .. index, range[1])
                    ui:set("RangeMax" .. index, range[2])
                    ui:set("RangeSize" .. index, range[3])
                end
            end, { label = "Reset Ranges", size = 12, rounding = 12 })
        end,
    })
end

local DISTANCE_MIN, DISTANCE_MAX = 10, 5000
local DISTANCE_WIDTH = 400

function Ranges.registerDistance(ui: any)
    ui:popup("maxdistance", {
        Width = DISTANCE_WIDTH,
        Height = 270,
        Title = "",
        Render = function(kit: any, window: any)
            local pal = window.Pal
            kit:header("Distance Limit", "Stops extending hitboxes past a distance", function()
                window:closePopup()
            end)
            kit:rect(16, 62, DISTANCE_WIDTH - 32, 52, pal.Panel, 1, 14)
            kit:text("Players further away than this keep", 30, 78, 12, pal.Text, false, true)
            kit:text("their normal hitbox. Useful on big maps.", 30, 96, 12, pal.Sub, false, true)

            local distance: number = ui:get("MaxDistance")
            local shown = tostring(math.floor(distance + 0.5))
            local sliderWidth = DISTANCE_WIDTH - 32
            kit:text("Maximum Distance", 18, 128, 13, pal.Text, false, true)
            kit:slider("maxdistance:slider", 16, 142, sliderWidth, 25, "", (distance - DISTANCE_MIN) / (DISTANCE_MAX - DISTANCE_MIN), "", function(fraction: number)
                ui:set("MaxDistance", math.floor(DISTANCE_MIN + (DISTANCE_MAX - DISTANCE_MIN) * math.clamp(fraction, 0, 1) + 0.5))
            end)
            local key = "maxdistance:input"
            kit:input(key, 16 + sliderWidth - 47, 142 + 6, 35, 18, shown, function()
                window:beginInput(key, shown, {
                    numeric = true,
                    maxLength = 5,
                    commit = function(text: string)
                        local value = tonumber(text)
                        if value then
                            ui:set("MaxDistance", math.clamp(value, DISTANCE_MIN, DISTANCE_MAX))
                        end
                    end,
                })
            end, pal.Main)
            kit:switchRow("maxdistance:outside", 16, 180, DISTANCE_WIDTH - 32, 36, "Names Visible Outside Distance", ui:get("VisOutsideDistance") == true, function()
                ui:set("VisOutsideDistance", not ui:get("VisOutsideDistance"))
            end)
            kit:button("maxdistance:done", 16, 228, DISTANCE_WIDTH - 32, 30, function()
                window:closePopup()
            end, { label = "Close", size = 12, rounding = 12, align = "center" })
        end,
    })
end

return Ranges
end
modules["visual"] = function(...)

local Visual = {}

local FACES = {
    { 1, 2, 3, 4 },
    { 5, 6, 7, 8 },
    { 1, 2, 6, 5 },
    { 2, 3, 7, 6 },
    { 3, 4, 8, 7 },
    { 4, 1, 5, 8 },
}

local EDGES = {
    { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 },
    { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 },
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 },
}

local MIN_DEPTH = 0.1
local TAG_LIFT = 1.2
local TAG_SIZE = 13

export type Style = {
    Mode: string,
    FillColor: Color3,
    FillTransparency: number,
    LineColor: Color3,
    LineTransparency: number,
    LineWidth: number,
}

local worldCorners: { Vector3 } = {}
local screenPoints: { Vector2? } = {}
local screenDepths: { number } = {}

local function corners(frame: CFrame, half: Vector3): { Vector3 }
    local position = frame.Position
    local right, up, look = frame.RightVector * half.X, frame.UpVector * half.Y, frame.LookVector * half.Z
    worldCorners[1] = position + right + up + look
    worldCorners[2] = position - right + up + look
    worldCorners[3] = position - right + up - look
    worldCorners[4] = position + right + up - look
    worldCorners[5] = position + right - up + look
    worldCorners[6] = position - right - up + look
    worldCorners[7] = position - right - up - look
    worldCorners[8] = position + right - up - look
    return worldCorners
end

local function drawRect(canvas: any, topLeft: Vector2, bottomRight: Vector2, style: Style)
    local size = bottomRight - topLeft
    if style.FillTransparency < 1 then
        canvas.filledRect(topLeft, size, style.FillColor, 1 - style.FillTransparency)
    end
    if style.LineTransparency < 1 and style.LineWidth > 0 then
        canvas.rect(topLeft, size, style.LineColor, 1 - style.LineTransparency, style.LineWidth)
    end
end

local function flat(canvas: any, camera: any, frame: CFrame, size: Vector3, points: { Vector2? }, depths: { number }, style: Style)
    local viewport = camera.ViewportSize
    local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
    local allFront = true
    for index = 1, 8 do
        local point = points[index]
        if point and depths[index] > MIN_DEPTH then
            left, top, right, bottom = math.min(left, point.X), math.min(top, point.Y), math.max(right, point.X), math.max(bottom, point.Y)
        else
            allFront = false
        end
    end
    if allFront then
        if right > 0 and left < viewport.X and bottom > 0 and top < viewport.Y and right - left < viewport.X * 1.5 and bottom - top < viewport.Y * 1.5 then
            drawRect(canvas, Vector2.new(left, top), Vector2.new(right, bottom), style)
        end
        return
    end
    local center, depth = canvas.project(frame.Position)
    if center and depth > MIN_DEPTH then
        local largest = math.max(size.X, size.Y, size.Z)
        local extent = largest / (depth * math.tan(math.rad(camera.FieldOfView) * 0.5) * 2) * viewport.Y
        if extent > 4 and extent < viewport.X * 0.95 and extent < viewport.Y * 0.95 then
            local half = Vector2.new(extent * 0.5, extent * 0.5)
            drawRect(canvas, center - half, center + half, style)
        end
    end
end

local function solid(canvas: any, points: { Vector2? }, depths: { number }, style: Style)
    if style.FillTransparency < 1 then
        for _, face in FACES do
            local a, b, c, d = face[1], face[2], face[3], face[4]
            local pa, pb, pc, pd = points[a], points[b], points[c], points[d]
            if pa and pb and pc and pd and depths[a] > MIN_DEPTH and depths[b] > MIN_DEPTH and depths[c] > MIN_DEPTH and depths[d] > MIN_DEPTH then
                canvas.filledQuad(pa, pb, pc, pd, style.FillColor, 1 - style.FillTransparency)
            end
        end
    end
    if style.LineTransparency < 1 and style.LineWidth > 0 then
        for _, edge in EDGES do
            local from, to = points[edge[1]], points[edge[2]]
            if from and to and depths[edge[1]] > MIN_DEPTH and depths[edge[2]] > MIN_DEPTH then
                canvas.line(from, to, style.LineColor, 1 - style.LineTransparency, style.LineWidth)
            end
        end
    end
end

local function inside(camera: any, frame: CFrame, half: Vector3): boolean
    local relative = frame:PointToObjectSpace(camera.CFrame.Position)
    return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

export type Tag = { Text: string, Color: Color3, Alpha: number }

function Visual.label(canvas: any, root: any, size: Vector3, tag: Tag)
    canvas.worldText(root.CFrame.Position + Vector3.new(0, size.Y * 0.5 + TAG_LIFT, 0), TAG_SIZE, tag.Color, tag.Alpha, tag.Text, nil)
end

local function upright(frame: CFrame): CFrame
    local position = frame.Position
    local look = frame.LookVector
    local flatLook = Vector3.new(look.X, 0, look.Z)
    if flatLook.Magnitude < 0.2 then
        local right = frame.RightVector
        flatLook = Vector3.new(-right.Z, 0, right.X)
    end
    if flatLook.Magnitude < 0.001 then
        return CFrame.new(position)
    end
    return CFrame.lookAt(position, position + flatLook)
end

function Visual.box(canvas: any, camera: any, root: any, size: Vector3, style: Style, tag: Tag?)
    local frame = upright(root.CFrame)
    local half = size * 0.5
    local covered = inside(camera, frame, half)
    if not covered then
        local world = corners(frame, half)
        local points = screenPoints
        local depths = screenDepths
        local visible = 0
        for index = 1, 8 do
            local point, depth = canvas.project(world[index])
            points[index], depths[index] = point, depth
            if point and depth > MIN_DEPTH then
                visible += 1
            end
        end
        if visible > 0 then
            if style.Mode == "2D" then
                flat(canvas, camera, frame, size, points, depths, style)
            else
                solid(canvas, points, depths, style)
            end
        end
    end
    if tag then
        Visual.label(canvas, root, size, tag)
    end
end

return Visual
end
modules["world"] = function(...)

local World = {}

local players: any = game:GetService("Players")
local workspaceService: any = game:GetService("Workspace")

World.Players = players
World.LocalPlayer = players.LocalPlayer

function World.camera(): any
    return workspaceService.CurrentCamera
end

function World.rootOf(model: any): any
    if not model then
        return nil
    end
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Head")
        or model.PrimaryPart
end

function World.humanoidOf(model: any): any
    if not model then
        return nil
    end
    return model:FindFirstChildOfClass("Humanoid")
end

function World.localRoot(): any
    local character = World.LocalPlayer.Character
    return if character then character:FindFirstChild("HumanoidRootPart") else nil
end

function World.pathOf(instance: any): string
    local names: { string } = {}
    local current = instance
    while current and current ~= workspaceService and current ~= game do
        table.insert(names, 1, current.Name)
        current = current.Parent
    end
    table.insert(names, 1, "Workspace")
    return table.concat(names, ".")
end

function World.resolve(path: string): any
    if path == "" or path == "Workspace" then
        return nil
    end
    local current: any = workspaceService
    for index, name in string.split(path, ".") do
        if not (index == 1 and name == "Workspace") then
            current = current:FindFirstChild(name)
            if not current then
                return nil
            end
        end
    end
    return current
end

return World
end
local UI_URL = "https://gitlab.com/okdude42/main-scripts/-/raw/main/oklo-uilib/OkloUI.luau?ref_type=heads"
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
        error("could not download the ui lib from gitlab", 0)
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

