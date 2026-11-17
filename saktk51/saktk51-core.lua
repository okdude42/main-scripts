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
modules["aim"] = function(...)

local import: (string) -> any = ...
local AimParts: typeof(require("./aimparts")) = import("aimparts")
local Context: typeof(require("./context")) = import("context")
local Targets: typeof(require("./targets")) = import("targets")
local Weapons: typeof(require("./weapons")) = import("weapons")

local Aim = {}

local MAX_RAY_STEPS = 128
local RAY_LENGTH = 2000

local cycle: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any

Aim.NativeRayCallback = nil :: any

function Aim.center(): Vector2
    local camera = Context.camera()
    local viewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
    local middle = Vector2.new(viewport.X / 2, viewport.Y / 2)
    local locked = false
    pcall(function()
        local behavior = Context.UserInput.MouseBehavior
        locked = behavior == Enum.MouseBehavior.LockCenter or behavior == Enum.MouseBehavior.LockCurrentPosition
    end)
    if locked or Weapons.equipped() ~= nil then
        return middle
    end
    return Context.mouse()
end

function Aim.liveTarget(part: any, weapon: any): boolean
    if not part or typeof(part) ~= "Instance" then
        return false
    end
    local owner = Context.characterOfPart(part)
    if owner and not Targets.hostile(owner) then
        return false
    end
    if type(weapon) == "table" then
        local check = weapon.missile_check
        if type(check) == "function" then
            local ok, result = pcall(check, weapon, part)
            if ok then
                return result ~= nil and result ~= false
            end
        end
    end
    local model, humanoid = Context.characterOfPart(part)
    if not model or not humanoid or humanoid.Health <= 0 or model == Context.LocalPlayer.Character then
        return false
    end
    local player = Context.Players:GetPlayerFromCharacter(model)
    if player and player ~= Context.LocalPlayer then
        return true
    end
    return Targets.isSurvivor(model) or Targets.isKiller(model)
end

function Aim.canDamage(weapon: any, part: any): boolean
    if not part or typeof(part) ~= "Instance" then
        return false
    end
    local model, humanoid = Context.characterOfPart(part)
    if not model or not humanoid or humanoid.Health <= 0 or model == Context.LocalPlayer.Character or not Targets.hostile(model) then
        return false
    end
    if Targets.isKiller(model) or Targets.isSurvivor(model) then
        return true
    end
    local check = if type(weapon) == "table" then weapon.missile_check else nil
    local player = Context.Players:GetPlayerFromCharacter(model)
    if player and player ~= Context.LocalPlayer then
        if type(check) == "function" then
            local ok, result = pcall(check, weapon, part)
            if ok and result ~= nil then
                return result ~= false
            end
        end
        return true
    end
    if type(check) == "function" then
        local ok, result = pcall(check, weapon, part)
        return ok and result ~= nil and result ~= false
    end
    return false
end

local function addModel(list: { any }, seen: { [any]: boolean }, model: any)
    if not model or not model:IsA("Model") or seen[model] then
        return
    end
    seen[model] = true
    table.insert(list, model)
end

local function addFrom(container: any, list: { any }, seen: { [any]: boolean })
    if not container then
        return
    end
    if container:IsA("Model") then
        addModel(list, seen, container)
    end
    for _, object in container:GetDescendants() do
        if object:IsA("Humanoid") then
            local model = object.Parent
            if model and model:IsA("Model") then
                addModel(list, seen, model)
            end
        end
    end
end

local SCAN_SECONDS = 0.2
local scanned: { any } = {}
local scanAt = -math.huge

local function scanModels(): { any }
    local now = os.clock()
    if now - scanAt < SCAN_SECONDS then
        return scanned
    end
    scanAt = now
    local list: { any } = {}
    local seen: { [any]: boolean } = {}
    local mine = Context.LocalPlayer.Character
    for _, player in Context.Players:GetPlayers() do
        if player ~= Context.LocalPlayer and player.Character and player.Character ~= mine then
            addModel(list, seen, player.Character)
        end
    end
    addFrom(Context.folder("Characters to kill"), list, seen)
    addFrom(Context.folder("Killers"), list, seen)
    addFrom(Targets.boss(), list, seen)
    for _, model in Targets.killers() do
        addModel(list, seen, model)
    end
    for _, model in Targets.creatures() do
        addModel(list, seen, model)
    end
    scanned = list
    return list
end

local function targets(): { any }
    local list: { any } = {}
    for _, model in scanModels() do
        if Targets.hostile(model) then
            table.insert(list, model)
        end
    end
    return list
end

local function aimPart(model: any): any
    if not model then
        return nil
    end
    return Targets.aimPoint(model)
end

local function silentParts(model: any, selected: { [string]: boolean }?): { any }
    if Targets.boss() == model then
        return { aimPart(model) }
    end
    local list = AimParts.forModel(model, selected)
    if #list == 0 then
        local fallback = aimPart(model)
        if fallback then
            table.insert(list, fallback)
        end
    end
    return list
end

function Aim.best(weapon: any, radius: number): any
    local camera = Context.camera()
    if not camera then
        return nil
    end
    local settings = Context.S
    local cursor = Aim.center()
    local candidates: { { Part: any, Distance: number } } = {}
    for _, model in targets() do
        local pick, pickDistance = nil, radius
        for _, part in silentParts(model, settings.SilentAimParts) do
            if part:IsDescendantOf(Context.Workspace) and Aim.canDamage(weapon, part) then
                local screen, onScreen = camera:WorldToViewportPoint(part.Position)
                if onScreen and screen.Z > 0 then
                    local distance = (Vector2.new(screen.X, screen.Y) - cursor).Magnitude
                    if distance <= pickDistance then
                        pick, pickDistance = part, distance
                    end
                end
            end
        end
        if pick then
            table.insert(candidates, { Part = pick, Distance = pickDistance })
        end
    end
    if #candidates == 0 then
        return nil
    end
    table.sort(candidates, function(a, b)
        return a.Distance < b.Distance
    end)
    if settings.TargetCycling and #candidates > 1 then
        local nextIndex = ((cycle[weapon] or 0) % #candidates) + 1
        cycle[weapon] = nextIndex
        return candidates[nextIndex].Part
    end
    cycle[weapon] = 0
    return candidates[1].Part
end

local function blocker(result: any, weapon: any): boolean
    if not result then
        return false
    end
    local part = result.Instance
    if Aim.liveTarget(part, weapon) then
        return true
    end
    if Aim.NativeRayCallback then
        local ok, stop = pcall(Aim.NativeRayCallback, result)
        if ok then
            return stop == true
        end
    end
    if not part or not part:IsA("BasePart") then
        return false
    end
    local threshold = (type(weapon) == "table" and tonumber(rawget(weapon, "hit_transparency_threshold"))) or 0.99
    return part.Transparency < threshold and part.CanCollide and part.CollisionGroup ~= "SurvivorsKillersNoClip"
end

local function visible(camera: any, part: any, weapon: any): boolean
    if Context.S.Wallbang then
        return true
    end
    local origin = camera.CFrame.Position
    local model = Context.characterOfPart(part)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filter: { any } = {}
    if Context.LocalPlayer.Character then
        table.insert(filter, Context.LocalPlayer.Character)
    end
    params.FilterDescendantsInstances = filter
    for _ = 1, MAX_RAY_STEPS do
        local result = Context.Workspace:Raycast(origin, part.Position - origin, params)
        if not result then
            return true
        end
        if result.Instance == part or (model ~= nil and result.Instance:IsDescendantOf(model)) then
            return true
        end
        if blocker(result, weapon) then
            return false
        end
        table.insert(filter, result.Instance)
        params.FilterDescendantsInstances = filter
    end
    return false
end

function Aim.triggerTarget(weapon: any, radius: number): any
    local camera = Context.camera()
    if not camera then
        return nil
    end
    local center = Aim.center()
    local best, bestDistance = nil, radius
    for _, model in targets() do
        local part = aimPart(model)
        if part and part:IsDescendantOf(Context.Workspace) then
            local screen, onScreen = camera:WorldToViewportPoint(part.Position)
            if onScreen and screen.Z > 0 then
                local distance = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                if distance <= bestDistance and Aim.canDamage(weapon, part) and visible(camera, part, weapon) then
                    best, bestDistance = part, distance
                end
            end
        end
    end
    return best
end

function Aim.lineOfSight(weapon: any): any
    local camera = Context.camera()
    if not camera then
        return nil
    end
    local cursor = Context.mouse()
    local ok, ray = pcall(function()
        return camera:ViewportPointToRay(cursor.X, cursor.Y)
    end)
    if not ok or not ray then
        return nil
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filter: { any } = {}
    if Context.LocalPlayer.Character then
        table.insert(filter, Context.LocalPlayer.Character)
    end
    params.FilterDescendantsInstances = filter
    local direction = ray.Direction * RAY_LENGTH
    for _ = 1, MAX_RAY_STEPS do
        local result = Context.Workspace:Raycast(ray.Origin, direction, params)
        if not result then
            return nil
        end
        if blocker(result, weapon) then
            return if Aim.liveTarget(result.Instance, weapon) then result.Instance else nil
        end
        local ignored = params.FilterDescendantsInstances
        table.insert(ignored, result.Instance)
        params.FilterDescendantsInstances = ignored
    end
    return nil
end

return Aim
end
modules["aimparts"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")

local AimParts = {}

local WIDTH, HEIGHT = 440, 430
local COLUMN = (WIDTH - 32 - 8) / 2
local ROW = 26

local FALLBACKS: { [string]: string } = {
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

local function copy(parts: { [string]: boolean }): { [string]: boolean }
    local clone: { [string]: boolean } = {}
    for name, value in parts do
        clone[name] = value
    end
    return clone
end

function AimParts.forModel(model: any, selected: { [string]: boolean }?): { any }
    local list: { any } = {}
    local chosen = selected or { HumanoidRootPart = true }
    for _, entry in Config.AIM_PARTS do
        local name = entry.Name
        if chosen[name] or chosen["All Parts"] then
            if name == "Torso" then
                add(list, model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso") or model:FindFirstChild("LowerTorso"))
            else
                local found = model:FindFirstChild(name)
                if isPart(found) then
                    add(list, found)
                elseif FALLBACKS[name] then
                    add(list, model:FindFirstChild(FALLBACKS[name]))
                end
            end
        end
    end
    return list
end

function AimParts.label(selected: { [string]: boolean }?): string
    local chosen = selected or {}
    if chosen["All Parts"] then
        return "All Parts"
    end
    local names: { string } = {}
    for _, entry in Config.AIM_PARTS do
        if chosen[entry.Name] then
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

function AimParts.open(ui: any)
    ui:openPopup("aimparts")
end

function AimParts.register(ui: any)
    ui:popup("aimparts", {
        Width = WIDTH,
        Height = HEIGHT,
        Title = "",
        Render = function(kit: any, window: any)
            kit:header("Silent Aim Parts", "Parts of the target that silent aim shoots at", function()
                window:closePopup()
            end)
            local selected: { [string]: boolean } = ui:get("SilentAimParts") or {}
            local presets = { { Name = "All", Parts = nil :: { string }? } }
            for _, preset in Config.AIM_PRESETS do
                table.insert(presets, preset)
            end
            table.insert(presets, { Name = "Reset", Parts = { "HumanoidRootPart" } })
            local chip = (WIDTH - 32 - (#presets - 1) * 5) / #presets
            for index, preset in presets do
                kit:button("aimparts:preset:" .. index, 16 + (index - 1) * (chip + 5), 62, chip, 26, function()
                    local result: { [string]: boolean } = {}
                    if preset.Parts then
                        for _, name in preset.Parts do
                            result[name] = true
                        end
                    else
                        for _, entry in Config.AIM_PARTS do
                            result[entry.Name] = true
                        end
                        result["All Parts"] = true
                    end
                    ui:set("SilentAimParts", result)
                end, { label = preset.Name, size = 11, rounding = 12 })
            end
            for index, entry in Config.AIM_PARTS do
                local column = (index - 1) % 2
                local row = math.floor((index - 1) / 2)
                local name = entry.Name
                kit:switchRow("aimparts:part:" .. index, 16 + column * (COLUMN + 8), 100 + row * (ROW + 3), COLUMN, ROW, name, selected[name] == true, function()
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
                    ui:set("SilentAimParts", result)
                end)
            end
        end,
    })
end

return AimParts
end
modules["changelog"] = function(...)

local Changelog = {}

Changelog.VERSION = "1.2.2"
Changelog.DATE = "October 29, 2026"

type Group = { Mode: string, Added: { string }?, Changed: { string }?, Removed: { string }?, Fixed: { string }? }

Changelog.GROUPS = {
    {
        Mode = "Juggernaut",
        Added = {
            "Kill All",
        },
    },
    {
        Mode = "General",
        Added = {
            "Kill Specified for the gamemodes which have Kill All",
        },
        Changed = {
            "Further changes to organization and option placements, it's also now fully consistent across all gamemodes",
            "More UI changes",
            "Fully reworked Get Guns and now has support for each gamemode",
        },
    },
} :: { Group }

Changelog.HISTORY = {
    {
        Version = "1.2.1",
        Date = "October 29, 2026",
        Groups = {
            {
                Mode = "Infection Mode",
                Added = {
                    "Take Gun, pick the guns on the map from a live list with their icons",
                    "Killer and gun icons, saved locally so they load instantly",
                },
                Changed = {
                    "Kill All keeps going after you respawn",
                },
                Fixed = {
                    "Killer icons not loading in Reset Character Until",
                },
            },
            {
                Mode = "Killer Mode",
                Added = {
                    "Kill Aura in Killer Mode",
                    "Take All Guns for Killer Mode",
                },
            },
            {
                Mode = "General",
                Changed = {
                    "Big optimizations",
                },
            },
        },
    },
    {
        Version = "1.2",
        Date = "October 28, 2026",
        Groups = {
            {
                Mode = "Endless",
                Added = {
                    "Kill Aura with adjustable distance in studs and a visualizer",
                    "Map Traps Immunity",
                    "Auto buy all perks and mystery box",
                    "Auto revive teammates",
                    "Round info HUD, enemies alive, nearest enemy,and your points",
                    "Instant hit report so damage is instantly received",
                    "Anti trip, killers and traps can't knock you down",
                    "No tails screen + No Ink",
                    "Mystery Box ESP",
                    "Triggerbot reworked to work for NPCs and now has it's own FOV",
                    "Auto Replank, Auto Open Doors (when points available), Auto Interact and Auto Buy Guns",
                },
                Changed = {
                    "Hitbox Expander reworked and now works for killers",
                    "Silent Aim reworked",
                    "Dead NPCs no longer show in ESP",
                    "Kill Aura reports it's shots straight to the server due to speeds and hit chance",
                    "Minigun mode reworked and now bursts constantly for all guns",
                },
                Removed = {
                    "Secret Area Markers, Surveillance Cameras ESP, Keycards, Papers, Auto Collect Keycards and Collectibles ESP, none of them exist in Endless",
                },
                Fixed = {
                    "Hitbox Expander no longer desyncs and lags your instance",
                },
            },
            {
                Mode = "Classic",
                Added = {
                    "Kill Aura with adjustable distance in studs and a visualizer",
                    "Complete All Quests button",
                    "Complete halloween quests and auto collect every candy and potions",
                    "Sewer Vault Code HUD",
                    "Auto Open Doors",
                    "Killer Proximity Warning",
                    "Block Forced Teleports",
                    "Get All Guns",
                    "No tails screen + No Ink",
                },
                Changed = {
                    "Boss ESP finds the Giant Zombie killer",
                },
                Fixed = {
                    "Keycards and Papers ESP now show the real pickups",
                    "Auto Collect Keycards now uses the pickup prompts",
                },
            },
            {
                Mode = "Juggernaut",
                Added = {
                    "Auto Open Doors, Auto Collect Keycards, Block Forced Teleports and Get All Guns",
                    "Juggernaut ability buttons: Lock Nearest Door, Rage Mode and Blackout",
                    "Kill Aura, Killer Proximity Warning and the facility HUDs now work here like in Classic",
                },
            },
            {
                Mode = "Infection Mode",
                Added = {
                    "Kill Aura with adjustable distance in studs and a visualizer",
                    "Kill All As Killer",
                    "Auto Open Doors, Block Forced Teleports and Get All Guns",
                    "No tails screen + No Ink",
                },
            },
            {
                Mode = "Boss Rush",
                Added = {
                    "Kill Aura with adjustable distance in studs and a visualizer",
                    "Silent Aim and Triggerbot aim at the boss weak point",
                    "Boss Attack Immunity for the Kraken, the tentacles, waves and knockback can no longer hurt you",
                    "Kill Aura, Silent Aim and Triggerbot also target the creatures that spawn in the arena",
                },
                Removed = {
                    "Weapon ESP, NPC ESP, map and facility markers, Hitbox Expander and the killer screen options, none of them exist in Boss Rush",
                },
            },
            {
                Mode = "Area 51 Storming",
                Added = {
                    "Kill Aura, Silent Aim and Triggerbot also target the creatures that spawn in the arena",
                    "Take Raygun",
                    "Player options removed, nobody fights each other here",
                },
            },
            {
                Mode = "General",
                Added = {
                    "Triggerbot FOV slider and circle in every mode",
                    "Teamcheck and forcefield checks for everything",
                    "Loader and executor compatibility support detection",
                },
                Changed = {
                    "Various UI improvements",
                },
                Fixed = {
                    "Remove Bullets and Remove Ammo Clips now delete the parts for real, bullets pile up in Workspace no more",
                },
            },
        },
    },
    {
        Version = "1.1",
        Date = "October 27, 2026",
        Lines = {
            "Fully reworked almost all options",
            "Completely reorganized everything",
            "Fixed all UI flaws",
            "Removed unused and impossible to make features",
            "Options now only show depending on gamemode and what they're suitable for",
            "Everything is 10x better and properly working now",
        },
    },
    {
        Version = "1.0",
        Date = "October 26, 2026",
        Lines = {
            "First release",
        },
    },
} :: { { Version: string, Date: string, Lines: { string }?, Groups: { Group }? } }

Changelog.CLOSING = "please join the discord server c:"

Changelog.OPEN = "Infection Mode"

return Changelog
end
modules["classic"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")
local Modes: typeof(require("./modes")) = import("modes")

local Classic = {}

local STEP_SECONDS = 0.5
local DOOR_PAD = 2

local started = false
local lastStep = 0
local doorCooldown: { [any]: number } = {}
local links: { any } = {}

function Classic.start()
    if started or not (Modes.facility() or Modes.storming()) then
        return
    end
    started = true
end

local function autoDoors(root: any)
    local doors = Context.folder("Doors")
    if not doors then
        return
    end
    local reach = tonumber(Context.S.AutoOpenDoorRange) or 10
    local now = os.clock()
    for _, object in doors:GetDescendants() do
        if object:IsA("ProximityPrompt") and object.Enabled and (doorCooldown[object] or 0) <= now then
            local holder = object.Parent
            if holder and holder:IsA("Attachment") then
                holder = holder.Parent
            end
            if holder and holder:IsA("BasePart") and (holder.Position - root.Position).Magnitude <= math.min(reach, object.MaxActivationDistance + DOOR_PAD) then
                doorCooldown[object] = now + 1.5
                pcall(fireproximityprompt, object)
            end
        end
    end
end

local function owns(name: string): boolean
    local character = Context.LocalPlayer.Character
    local backpack = Context.LocalPlayer:FindFirstChildOfClass("Backpack")
    return (character ~= nil and character:FindFirstChild(name) ~= nil) or (backpack ~= nil and backpack:FindFirstChild(name) ~= nil)
end

local visiting = false

local savedGroup: string? = nil

local function pauseCheck(character: any)
    local torso = character and character:FindFirstChild("Torso")
    if not torso or savedGroup then
        return
    end
    pcall(function()
        savedGroup = torso.CollisionGroup
        torso.CollisionGroup = "NoClip"
    end)
    Context.RunService.Heartbeat:Wait()
    Context.RunService.Heartbeat:Wait()
end

local function resumeCheck(character: any)
    local torso = character and character:FindFirstChild("Torso")
    if torso and savedGroup then
        pcall(function()
            torso.CollisionGroup = savedGroup
        end)
    end
    savedGroup = nil
end

local function visit(prompt: any, press: boolean): boolean
    local character = Context.LocalPlayer.Character
    local root = Context.root(character)
    local holder = prompt.Parent
    if holder and holder:IsA("Attachment") then
        holder = holder.Parent
    end
    if not character or not root or not holder or not holder:IsA("BasePart") then
        return false
    end
    local home = character:GetPivot()
    pauseCheck(character)
    pcall(function()
        character:PivotTo(CFrame.new(holder.Position + Vector3.new(0, 3, 0)))
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end)
    task.wait(0.3)
    if press then
        pcall(fireproximityprompt, prompt)
    end
    task.wait(0.2)
    pcall(function()
        character:PivotTo(home)
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end)
    task.wait(0.1)
    resumeCheck(character)
    return true
end

function Classic.pickup(prompt: any)
    if visiting then
        return
    end
    visiting = true
    task.spawn(function()
        pcall(visit, prompt, true)
        visiting = false
    end)
end

local HAZARD_WORDS = { "kill", "lava", "death", "damage", "acid", "trap", "laser", "fire", "void", "spike", "hurt", "poison" }

local function hazardNear(hitbox: any): string?
    local parts = Context.Workspace:GetPartBoundsInRadius(hitbox.Position, 8)
    for _, part in parts do
        local lower = string.lower(part.Name)
        for _, word in HAZARD_WORDS do
            if string.find(lower, word, 1, true) and not part:IsDescendantOf(hitbox.Parent) then
                return part.Name
            end
        end
    end
    return nil
end

local function touchable(character: any, value: boolean)
    for _, part in character:GetDescendants() do
        if part:IsA("BasePart") then
            pcall(function()
                part.CanTouch = value
            end)
        end
    end
end

local MAX_PICKED = 2
local picked: { string } = {}
local listed: { string } = {}
local listedAt = 0

local function wanted(only: any, name: string): boolean
    if only == nil then
        return true
    elseif type(only) == "table" then
        return table.find(only, name) ~= nil
    end
    return only == name
end

function Classic.available(): { string }
    local now = os.clock()
    if now - listedAt < 0.5 then
        return listed
    end
    listedAt = now
    local names: { string } = {}
    local seen: { [string]: boolean } = {}
    local folder = Context.folder("Weapons")
    if folder then
        for _, gun in folder:GetChildren() do
            local hitbox = gun:FindFirstChild("Hitbox")
            if not seen[gun.Name] and hitbox and hitbox:FindFirstChildOfClass("ProximityPrompt") then
                seen[gun.Name] = true
                table.insert(names, gun.Name)
            end
        end
    end
    table.sort(names)
    listed = names
    for index = #picked, 1, -1 do
        if not seen[picked[index]] then
            table.remove(picked, index)
        end
    end
    return names
end

function Classic.pickedGuns(): { string }
    return picked
end

function Classic.owned(name: string): boolean
    return owns(name)
end

function Classic.togglePicked(name: string)
    local at = table.find(picked, name)
    if at then
        table.remove(picked, at)
        return
    end
    if Modes.Current ~= "Killer Mode" and Modes.Current ~= "Classic" and #picked >= MAX_PICKED then
        table.remove(picked, 1)
    end
    table.insert(picked, name)
end

function Classic.takeAll(report: (string) -> ())
    Classic.available()
    Classic.getAllGuns(report, nil)
end

function Classic.takePicked(report: (string) -> ())
    Classic.available()
    if #picked == 0 then
        report("Select a gun first")
        return
    end
    Classic.getAllGuns(report, table.clone(picked))
end

function Classic.getAllGuns(report: (string) -> (), only: any)
    local folder = Context.folder("Weapons")
    if not folder then
        report("No weapons folder")
        return
    end
    if visiting then
        report("Already running")
        return
    end
    local targets: { any } = {}
    local skipped = 0
    for _, gun in folder:GetChildren() do
        if wanted(only, gun.Name) and not owns(gun.Name) then
            local hitbox = gun:FindFirstChild("Hitbox")
            local prompt = hitbox and hitbox:FindFirstChildOfClass("ProximityPrompt")
            if prompt and hitbox:IsA("BasePart") then
                local hazard = nil
                pcall(function()
                    hazard = hazardNear(hitbox)
                end)
                if hazard then
                    skipped += 1
                else
                    table.insert(targets, prompt)
                end
            end
        end
    end
    if #targets == 0 then
        report("No safe gun pickup found")
        return
    end
    local character = Context.LocalPlayer.Character
    local root = Context.root(character)
    if not character or not root then
        report("No character")
        return
    end
    visiting = true
    task.spawn(function()
        local total = #targets
        local tried = 0
        local deadAt = ""
        local home = character:GetPivot()
        local okPing, ping = pcall(function()
            return Context.LocalPlayer:GetNetworkPing()
        end)
        local settle = math.clamp((if okPing then ping else 0.1) * 2 + 0.08, 0.12, 0.45)
        touchable(character, false)
        pauseCheck(character)
        for _, prompt in targets do
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not Context.Running or not character.Parent or not humanoid or humanoid.Health <= 0 then
                break
            end
            if not prompt.Parent then
                continue
            end
            tried += 1
            report("Picking up guns " .. tried .. "/" .. total)
            local hitbox = prompt.Parent
            pcall(function()
                local look = hitbox.CFrame.LookVector
                local flat = Vector3.new(look.X, 0, look.Z)
                if flat.Magnitude < 0.3 then
                    local away = home.Position - hitbox.Position
                    flat = Vector3.new(away.X, 0, away.Z)
                end
                flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, 1)
                local spot = hitbox.Position + flat * 3 + Vector3.new(0, 1.5, 0)
                character:PivotTo(CFrame.lookAt(spot, Vector3.new(hitbox.Position.X, spot.Y, hitbox.Position.Z)))
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                prompt.Enabled = true
                prompt.HoldDuration = 0
            end)
            local gunName = if hitbox.Parent then hitbox.Parent.Name else ""
            task.wait(settle)
            for _ = 1, 3 do
                pcall(fireproximityprompt, prompt)
                local deadline = os.clock() + settle
                repeat
                    Context.RunService.Heartbeat:Wait()
                until gunName == "" or owns(gunName) or not prompt.Parent or os.clock() >= deadline
                if gunName == "" or owns(gunName) or not prompt.Parent then
                    break
                end
            end
            local after = character:FindFirstChildOfClass("Humanoid")
            if not after or after.Health <= 0 then
                deadAt = prompt.Parent.Parent.Name
                break
            end
        end
        pcall(function()
            character:PivotTo(home)
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end)
        task.wait(0.1)
        resumeCheck(character)
        touchable(character, true)
        visiting = false
        if deadAt ~= "" then
            report("Died at " .. deadAt .. ", something there kills")
        else
            report("Visited " .. tried .. " guns" .. (if skipped > 0 then ", skipped " .. skipped .. " near hazards" else ""))
        end
    end)
end

local ABILITY_COSTS = { LockDoor = 50, RageMode = 100, Blackout = 150 }
local ABILITY_LABELS = { LockDoor = "Lock Door", RageMode = "Rage Mode", Blackout = "Blackout" }
local abilityBusy = false

local function remoteFunction(name: string): any
    local storage = game:GetService("ReplicatedStorage")
    local folder = storage:FindFirstChild("Remote Functions")
    return folder and folder:FindFirstChild(name)
end

function Classic.points(): number?
    local remote = remoteFunction("Get Player Points")
    if not remote then
        return nil
    end
    local ok, value = pcall(function()
        return remote:InvokeServer()
    end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

local function nearestDoor(root: any): any
    local doors = workspace:FindFirstChild("Doors")
    if not doors then
        return nil
    end
    local best, bestDistance = nil, math.huge
    for _, door in doors:GetChildren() do
        local ok, pivot = pcall(function()
            return door:GetPivot().Position
        end)
        if ok then
            local distance = (pivot - root.Position).Magnitude
            if distance < bestDistance then
                best, bestDistance = door, distance
            end
        end
    end
    return best
end

function Classic.useAbility(name: string, report: (string) -> ())
    local label = ABILITY_LABELS[name] or name
    local remote = remoteFunction("RequestAbility")
    if not remote then
        report("Not available in this mode")
        return
    end
    if abilityBusy then
        report("Wait for the last ability")
        return
    end
    abilityBusy = true
    task.spawn(function()
        local points = Classic.points()
        local cost = ABILITY_COSTS[name]
        if points and cost and points < cost then
            report(label .. " needs " .. cost .. " points, you have " .. points)
            abilityBusy = false
            return
        end
        local argument = nil
        if name == "LockDoor" then
            local root = Context.root(Context.LocalPlayer.Character)
            argument = root and nearestDoor(root)
            if not argument then
                report("No door found")
                abilityBusy = false
                return
            end
        end
        local ok, result = pcall(function()
            return remote:InvokeServer(name, argument)
        end)
        if not ok then
            report(label .. " failed")
        elseif result then
            report(label .. " used")
        else
            report(label .. " refused, on cooldown or not the Juggernaut")
        end
        abilityBusy = false
    end)
end

function Classic.step()
    if not started then
        return
    end
    local now = os.clock()
    if now - lastStep < STEP_SECONDS then
        return
    end
    lastStep = now
    local settings = Context.S
    local root = Context.root(Context.LocalPlayer.Character)
    if not root then
        return
    end
    if settings.ClassicAutoDoors then
        autoDoors(root)
    end
end

function Classic.stop()
    started = false
    for _, link in links do
        pcall(function()
            link:Disconnect()
        end)
    end
    table.clear(links)
    table.clear(doorCooldown)
end

return Classic
end
modules["clienteffects"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")

local ClientEffects = {}

local EFFECT_FOLDERS: { [string]: boolean } = {
    debris = true, effects = true, ignore = true, trash = true, fx = true, temp = true, bullets = true,
    shells = true, clips = true, projectiles = true, particles = true, ejected = true,
}
local CLIP_WORDS = { "clip", "magazine", "casing", "shell", "brass" }
local VISUALS = { "Trail", "Beam", "ParticleEmitter", "PointLight", "SpotLight", "SurfaceLight", "Smoke", "Fire", "Sparkles", "Decal", "Texture" }

local BULLET_LIFE = 2.5
local SWEEP_INTERVAL = 2

local link: any = nil
local sweeping = false
local born: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any

local function loose(part: any): boolean
    local parent = part.Parent
    if parent == Context.Workspace then
        return true
    end
    if parent == nil or not parent:IsA("Folder") then
        return false
    end
    return EFFECT_FOLDERS[string.lower(parent.Name)] == true
end

local function bulletName(name: string): boolean
    return name == "bullet" or string.match(name, "^s[1-6]$") ~= nil
end

local function isBullet(part: any): boolean
    return bulletName(string.lower(part.Name))
end

local function stray(part: any): boolean
    if part.Anchored then
        return false
    end
    local node = part.Parent
    while node and node ~= Context.Workspace do
        if node:IsA("Tool") or node:FindFirstChildOfClass("Humanoid") then
            return false
        end
        node = node.Parent
    end
    return node == Context.Workspace
end

local function clipName(name: string): boolean
    if name == "mag" then
        return true
    end
    for _, word in CLIP_WORDS do
        if string.find(name, word, 1, true) then
            return true
        end
    end
    return false
end

local function isClip(part: any): boolean
    return clipName(string.lower(part.Name))
end

local function hide(part: any)
    pcall(function()
        part.Transparency = 1
        part.LocalTransparencyModifier = 1
        part.CastShadow = false
    end)
    for _, child in part:GetDescendants() do
        for _, class in VISUALS do
            if child:IsA(class) then
                pcall(function()
                    child.Enabled = false
                end)
                pcall(function()
                    child.Transparency = 1
                end)
                break
            end
        end
    end
end

local function remove(object: any)
    if object.Parent then
        pcall(function()
            object:Destroy()
        end)
    end
end

local function handle(part: any)
    if not (part:IsA("BasePart") or part:IsA("Model")) then
        return
    end
    local settings = Context.S
    if settings.RemoveBullets and part:IsA("BasePart") and isBullet(part) and (loose(part) or stray(part)) then
        born[part] = os.clock()
        task.defer(hide, part)
        task.delay(BULLET_LIFE, remove, part)
    elseif settings.RemoveClips and loose(part) and isClip(part) then
        task.defer(remove, part)
    end
end

local candidates: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function remember(object: any)
    if object:IsA("BasePart") or object:IsA("Model") then
        local name = string.lower(object.Name)
        if bulletName(name) or clipName(name) then
            candidates[object] = true
        end
    end
end

local function sweep()
    local settings = Context.S
    local now = os.clock()
    for object in candidates do
        if not object.Parent then
            candidates[object] = nil
        elseif settings.RemoveBullets and object:IsA("BasePart") and isBullet(object) and (loose(object) or stray(object)) then
            local created = born[object]
            if not created or now - created >= BULLET_LIFE then
                remove(object)
            end
        elseif settings.RemoveClips and (object:IsA("BasePart") or object:IsA("Model")) and loose(object) and isClip(object) then
            remove(object)
        end
    end
end

local SCREEN_EFFECTS: { [string]: string } = { Ink = "RemoveInk", TailsPopup = "RemoveTailsPopup" }
local guiLink: any = nil

local function muteScreens()
    local playerGui = Context.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return
    end
    for name, flag in SCREEN_EFFECTS do
        local gui = playerGui:FindFirstChild(name)
        if gui and gui:IsA("ScreenGui") then
            local hidden = Context.S[flag] == true
            if gui.Enabled == hidden then
                gui.Enabled = not hidden
            end
        end
    end
end

function ClientEffects.start()
    if link then
        return
    end
    sweeping = true
    local playerGui = Context.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        guiLink = playerGui.ChildAdded:Connect(function(child: any)
            local flag = SCREEN_EFFECTS[child.Name]
            if flag and Context.S[flag] and child:IsA("ScreenGui") then
                child.Enabled = false
            end
        end)
    end
    task.spawn(function()
        while sweeping and Context.Running do
            pcall(muteScreens)
            task.wait(0.15)
        end
    end)
    task.spawn(function()
        while sweeping and Context.Running do
            if Context.S.RemoveBullets or Context.S.RemoveClips then
                pcall(sweep)
            end
            task.wait(SWEEP_INTERVAL)
        end
    end)
    task.spawn(function()
        local started = os.clock()
        for _, object in Context.Workspace:GetDescendants() do
            remember(object)
            if os.clock() - started > 0.0008 then
                task.wait()
                started = os.clock()
            end
        end
    end)
    link =Context.Workspace.DescendantAdded:Connect(function(object: any)
        if not Context.Running then
            return
        end
        remember(object)
        local settings = Context.S
        if settings.RemoveBullets or settings.RemoveClips then
            handle(object)
        end
    end)
end

function ClientEffects.stop()
    sweeping = false
    if guiLink then
        pcall(function()
            guiLink:Disconnect()
        end)
        guiLink = nil
    end
    for name in SCREEN_EFFECTS do
        local playerGui = Context.LocalPlayer:FindFirstChildOfClass("PlayerGui")
        local gui = playerGui and playerGui:FindFirstChild(name)
        if gui and gui:IsA("ScreenGui") then
            gui.Enabled = true
        end
    end
    if link then
        pcall(function()
            link:Disconnect()
        end)
        link = nil
    end
end

return ClientEffects
end
modules["config"] = function(...)

local Config = {}

export type Settings = { [string]: any }

Config.KILLERS = {
    "Alien", "Ao Oni", "Captain Zombie", "Chucky", "Eyeless Jack", "Fishface",
    "Freddy Krueger", "Ghostface", "Granny", "Jack Torrance", "Jason", "Jeff",
    "Leatherface", "Michael Myers", "Pennywise", "Pinhead", "Rake", "Robot",
    "Slenderman", "Smile Dog", "Sonic.exe", "Tails Doll", "Wendigo", "Yeti", "Zombie",
}

Config.INTERNAL_KILLERS = { "Fuwatti", "Giant", "Jane" }

Config.KILLER_ALIASES = {
    giantzombie = "Giant",
    therake = "Rake",
    jeffthekiller = "Jeff",
    janethekiller = "Jane",
    jasonvoorhees = "Jason",
    captainzombie = "Captain Zombie",
    eyelessjack = "Eyeless Jack",
    michaelmyers = "Michael Myers",
    michael = "Michael Myers",
    myers = "Michael Myers",
    michaelmyers2018 = "Michael Myers",
    michaelmyerskiller = "Michael Myers",
    freddykrueger = "Freddy Krueger",
    jacktorrance = "Jack Torrance",
    smiledog = "Smile Dog",
    tailsdoll = "Tails Doll",
    aooni = "Ao Oni",
    sonicexe = "Sonic.exe",
} :: { [string]: string }

Config.VISUAL_MODES = { "Outline", "Fill", "Outline + Fill", "2D Box", "3D Box", "Text Only" }
Config.TRACER_ORIGINS = { "Mouse", "Center", "Bottom" }

Config.COLORS = {
    Tracer = Color3.fromRGB(235, 235, 235),
    Background = Color3.fromRGB(16, 16, 18),
    Text = Color3.fromRGB(245, 245, 245),
    Box = Color3.fromRGB(212, 212, 212),
}

Config.AIM_PARTS = {
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

Config.AIM_PRESETS = {
    { Name = "HRP", Parts = { "HumanoidRootPart" } },
    { Name = "Head", Parts = { "Head" } },
    { Name = "Torso", Parts = { "Torso", "UpperTorso", "LowerTorso" } },
}

Config.DEFAULTS = {
    InfAmmo = false,
    InfStoredAmmo = false,
    InstantReload = false,
    FastWeaponEquip = false,
    NoRecoil = false,
    NoSpread = false,
    AlwaysFullAuto = false,
    RapidFire = false,
    CustomFireRate = 0,
    MinigunMode = false,
    MinigunFireBoost = 0,
    ShotMultiplier = false,
    ShotMultiplierCount = 2,
    CustomBulletTravel = false,
    BulletTravelTime = 0,
    ExtendedProjectileRange = false,
    ProjectileRangeMultiplier = 4,
    CustomPelletCount = false,
    PelletCount = 12,
    Wallbang = false,
    SilentAim = false,
    ShowSilentAimFOV = false,
    SilentAimFOV = 120,
    SilentAimParts = { HumanoidRootPart = true },
    TargetCycling = false,
    AutoShoot = false,
    ShowTriggerFOV = false,
    TriggerFOV = 60,
    RemoveBullets = false,
    RemoveClips = false,
    RemoveInk = false,
    RemoveTailsPopup = false,
    MuteGunSounds = false,

    KillerHitbox = false,
    KillerHitboxVisualizer = false,
    KillerHitboxSize = 15,
    KillerHitboxLineColor = Color3.fromRGB(255, 255, 255),
    KillerHitboxLineTransparency = 0.2,
    KillerHitboxFillColor = Color3.fromRGB(255, 255, 255),
    KillerHitboxFillTransparency = 0.85,

    VisualWeaponESP = false,
    VisualWeaponTracers = false,
    VisualWeaponShowDistance = true,
    VisualWeaponOffscreen = false,
    VisualNearestWeaponHUD = false,
    VisualWeaponHUDCoordinates = false,
    VisualWeaponHUDCount = 6,
    AliveHUD = false,
    AliveHUDCount = 8,
    VisualKillerESP = false,
    VisualKillerTracers = false,
    VisualKillerShowHealth = true,
    VisualKillerShowDistance = true,
    VisualSurvivorESP = false,
    VisualSurvivorTracers = false,
    VisualSurvivorShowHealth = true,
    VisualSurvivorShowDistance = true,
    VisualNPCESP = false,
    VisualNPCTracers = false,
    VisualNPCShowHealth = true,
    VisualNPCShowDistance = true,
    VisualBossESP = false,
    VisualBossTracers = false,
    VisualBossShowHealth = true,
    VisualBossShowDistance = true,
    VisualNPCOffscreen = false,
    VisualKillerOffscreen = false,
    VisualSurvivorOffscreen = false,
    VisualBossOffscreen = false,
    VisualKeycardESP = false,
    VisualPaperESP = false,
    VisualPickupShowDistance = true,
    VisualLandmarkESP = false,
    VisualSecretAreaESP = false,
    VisualPackAPunchESP = false,
    VisualInteractableESP = false,
    VisualSurveillanceESP = false,
    VisualMapShowDistance = true,
    VisualFacilityObjectiveESP = false,
    VisualFacilityShowDistance = true,
    VisualAlienCodeHUD = false,
    VisualCleanerHUD = false,
    VisualVaultScreenHUD = false,
    VisualKillerWarning = false,
    KillerWarningRange = 60,
    ClassicAutoDoors = false,
    NoForcedTeleport = false,
    VisualEndlessPerksESP = false,
    VisualMysteryBoxESP = false,
    VisualTrapESP = false,
    VisualEndlessShowDistance = true,

    VisualMode = "Outline",
    VisualThroughWalls = true,
    VisualTracerOrigin = "Mouse",
    VisualTracerThickness = 1.5,
    VisualTracerTransparency = 0,
    VisualOffscreenArrowSize = 16,
    VisualHighlightFillTransparency = 0.78,
    VisualHighlightOutlineTransparency = 0.08,
    VisualLabelBackgroundTransparency = 0.28,
    VisualBillboardOffset = 2.3,
    ESPTextSize = 13,
    VisualBoxThickness = 1.5,
    ColorTracer = Config.COLORS.Tracer,
    ColorBackground = Config.COLORS.Background,
    ColorText = Config.COLORS.Text,
    ColorBox = Config.COLORS.Box,

    Fullbright = false,
    RemoveFog = false,
    VisualNoShadows = false,

    DoorNoclip = false,
    Fly = false,
    FlySpeed = 50,
    UnlockCamera = false,
    CustomWalkSpeed = false,
    WalkSpeedValue = 16,
    AutoCollectKeycards = false,

    NoInk = false,
    NoTrip = false,
    TrapImmunity = false,
    InstantHit = false,
    KillAura = false,
    ShowKillAuraCircle = true,
    AutoBuyPerks = false,
    AutoBuyMysteryBox = false,
    AutoRevive = false,
    AutoReplank = false,
    AutoOpenDoors = false,
    AutoOpenDoorRange = 10,
    AutoInteract = false,
    AutoBuyGuns = false,
    RoundHUD = false,
    KillAuraRange = 150,
    KillAuraTargets = 3,
    KillAll = false,
    KillSpecified = false,
    BossImmunity = false,
} :: Settings

function Config.fresh(): Settings
    local copy: Settings = {}
    for key, value in Config.DEFAULTS do
        copy[key] = value
    end
    return copy
end

function Config.refresh(ui: any, into: Settings)
    local window = ui.Window
    local flags = if type(window) == "table" then window.Flags else nil
    if type(flags) == "table" then
        for key, default in Config.DEFAULTS do
            local value = flags[key]
            if value == nil then
                value = default
            end
            into[key] = value
        end
        return
    end
    for key, default in Config.DEFAULTS do
        local value = ui:get(key)
        if value == nil then
            value = default
        end
        into[key] = value
    end
end

return Config
end
modules["context"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")

local Context = {}

Context.Players = game:GetService("Players")
Context.Workspace = game:GetService("Workspace")
Context.ReplicatedStorage = game:GetService("ReplicatedStorage")
Context.Lighting = game:GetService("Lighting")
Context.UserInput = game:GetService("UserInputService")
Context.RunService = game:GetService("RunService")
Context.TextService = game:GetService("TextService")
Context.GuiService = game:GetService("GuiService")
Context.LocalPlayer = Context.Players.LocalPlayer
Context.S = Config.fresh()
Context.Running = true

function Context.camera(): any
    return Context.Workspace.CurrentCamera
end

function Context.mouse(): Vector2
    local input = Context.UserInput
    local ok, position = pcall(input.GetMouseLocation, input)
    if ok and position then
        return position
    end
    local camera = Context.camera()
    local viewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
    return Vector2.new(viewport.X / 2, viewport.Y / 2)
end

function Context.root(character: any): any
    if not character then
        return nil
    end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
end

function Context.humanoid(character: any): any
    if not character then
        return nil
    end
    return character:FindFirstChildOfClass("Humanoid")
end

function Context.folder(name: string): any
    return Context.Workspace:FindFirstChild(name)
end

function Context.characterOfPart(part: any): (any, any)
    local node = part
    while node and node ~= Context.Workspace do
        if node:IsA("Model") then
            local humanoid = node:FindFirstChildOfClass("Humanoid")
            if humanoid then
                return node, humanoid
            end
        end
        node = node.Parent
    end
    return nil, nil
end

return Context
end
modules["debug"] = function(...)

local Debug = {}

local INTERVAL = 3

local counts: { [string]: number } = {}
local samples: { [string]: string } = {}
local order: { string } = {}
local nextReport = 0

local ON_SECONDS = 0.25
local onValue = false
local onAt = -math.huge

function Debug.on(): boolean
    local now = os.clock()
    if now - onAt >= ON_SECONDS then
        onAt = now
        onValue = getgenv().SAKTK51Debug == true
    end
    return onValue
end

function Debug.count(key: string, sample: any?)
    if not Debug.on() then
        return
    end
    if counts[key] == nil then
        counts[key] = 0
        table.insert(order, key)
    end
    counts[key] += 1
    if sample ~= nil then
        samples[key] = tostring(sample)
    end
end

function Debug.describe(part: any): string
    if not Debug.on() then
        return ""
    end
    if typeof(part) ~= "Instance" then
        return tostring(part)
    end
    local ok, name = (pcall :: any)(function()
        return part:GetFullName()
    end)
    return if ok then name else part.Name
end

function Debug.tick()
    if not Debug.on() then
        return
    end
    local now = os.clock()
    if now < nextReport then
        return
    end
    nextReport = now + INTERVAL
    local lines: { string } = {}
    for _, key in order do
        if counts[key] > 0 then
            local line = key .. "=" .. tostring(counts[key])
            if samples[key] then
                line ..= " (" .. samples[key] .. ")"
            end
            table.insert(lines, line)
            counts[key] = 0
        end
    end
    if #lines > 0 then
        print("[SAKTK51 debug] " .. table.concat(lines, " | "))
    end
end

return Debug
end
modules["endless"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")
local PromptWatch: typeof(require("./promptwatch")) = import("promptwatch")
local Targets: typeof(require("./targets")) = import("targets")

local Endless = {}

local INTERVAL = 0.2

local press: any = fireproximityprompt
local BUY_INTERVAL = 1
local REVIVE_RANGE = 25
local lastBuy = 0
local last = 0
local saved: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function points(): number
    local stats = Context.LocalPlayer:FindFirstChild("leaderstats")
    local value = stats and stats:FindFirstChild("Points")
    return if value and value:IsA("ValueBase") then tonumber((value :: any).Value) or 0 else 0
end

local function promptOf(model: any): any
    for _, object in model:GetDescendants() do
        if object:IsA("ProximityPrompt") and object.Enabled then
            return object
        end
    end
    return nil
end

local function costOf(model: any): number
    local cost = model:FindFirstChild("Cost", true)
    return if cost and cost:IsA("ValueBase") then tonumber((cost :: any).Value) or 0 else 0
end

local function buy()
    if type(press) ~= "function" then
        return
    end
    local settings = Context.S
    local balance = points()
    if settings.AutoBuyPerks then
        local perks = Context.folder("Perks")
        local owned = Context.LocalPlayer:FindFirstChild("Perks")
        if perks then
            for _, perk in perks:GetChildren() do
                local flag = owned and owned:FindFirstChild(perk.Name)
                local have = flag ~= nil and flag:IsA("BoolValue") and flag.Value
                local prompt = if perk:IsA("Model") then promptOf(perk) else nil
                if prompt and not have and balance >= costOf(perk) then
                    pcall(press, prompt)
                    balance -= costOf(perk)
                end
            end
        end
    end
    if settings.AutoBuyMysteryBox then
        local boxes = Context.folder("Mystery Box")
        local box = boxes and boxes:FindFirstChild("Box")
        local prompt = box and promptOf(box)
        if prompt and (not box or balance >= costOf(box)) then
            pcall(press, prompt)
        end
    end
end

local function revive()
    local root = Context.root(Context.LocalPlayer.Character)
    if not root or type(press) ~= "function" then
        return
    end
    for object in PromptWatch.Set do
        if not object.Parent then
            PromptWatch.Set[object] = nil
        elseif object.Enabled and string.find(string.lower(object.ActionText), "revive", 1, true) then
            local parent = object.Parent
            local position = if parent and parent:IsA("BasePart") then parent.Position elseif parent and parent:IsA("Attachment") then parent.WorldPosition else nil
            if position and (position - root.Position).Magnitude <= REVIVE_RANGE then
                pcall(press, object)
            end
        end
    end
end

local PLANK_WORDS = { "plank", "rebuild", "repair", "barricade", "board" }
local PLANK_PARTS = { planks = true, window = true, ["invisible wall"] = true, barricade = true }
local DOOR_RANGE_PAD = 0.5
local COOLDOWN = 1
local ACTION_INTERVAL = 0.3
local prompts = PromptWatch.Set
local cooldown: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any
local lastAction = 0

local function startTracking()
    PromptWatch.hold("endless")
end

local function stopTracking()
    PromptWatch.release("endless")
end

local function positionOf(prompt: any): Vector3?
    local parent = prompt.Parent
    if parent and parent:IsA("BasePart") then
        return parent.Position
    end
    if parent and parent:IsA("Attachment") then
        return parent.WorldPosition
    end
    return nil
end

local function kindOf(prompt: any): string
    local doors = Context.folder("Doors")
    local weapons = Context.folder("Weapons")
    if doors and prompt:IsDescendantOf(doors) then
        return "door"
    end
    if weapons and prompt:IsDescendantOf(weapons) then
        return "gun"
    end
    local text = string.lower(prompt.ActionText .. " " .. prompt.ObjectText)
    for _, word in PLANK_WORDS do
        if string.find(text, word, 1, true) then
            return "plank"
        end
    end
    local node = prompt.Parent
    while node and node ~= Context.Workspace do
        if PLANK_PARTS[string.lower(node.Name)] then
            return "plank"
        end
        node = node.Parent
    end
    return "other"
end

local function costAbove(prompt: any): number
    local node = prompt.Parent
    for _ = 1, 4 do
        if not node or node == Context.Workspace then
            break
        end
        local cost = node:FindFirstChild("Cost")
        if cost and cost:IsA("ValueBase") then
            return tonumber((cost :: any).Value) or 0
        end
        node = node.Parent
    end
    return 0
end

local function owns(name: string): boolean
    local character = Context.LocalPlayer.Character
    local backpack = Context.LocalPlayer:FindFirstChildOfClass("Backpack")
    return (character ~= nil and character:FindFirstChild(name) ~= nil) or (backpack ~= nil and backpack:FindFirstChild(name) ~= nil)
end

local function hasHint(prompt: any): boolean
    local hint = prompt:FindFirstChild("CustomHint")
    return hint ~= nil and hint:IsA("StringValue") and hint.Value ~= ""
end

local function interact()
    local settings = Context.S
    local root = Context.root(Context.LocalPlayer.Character)
    if not root or type(press) ~= "function" then
        return
    end
    local now = os.clock()
    local balance = points()
    for prompt in prompts do
        if not prompt.Parent then
            prompts[prompt] = nil
        elseif prompt.Enabled and (cooldown[prompt] or 0) <= now and not hasHint(prompt) then
            local position = positionOf(prompt)
            if position then
                local kind = kindOf(prompt)
                local reach = prompt.MaxActivationDistance + DOOR_RANGE_PAD
                local wanted = false
                if kind == "door" then
                    reach = math.min(reach, tonumber(settings.AutoOpenDoorRange) or 10)
                    wanted = settings.AutoOpenDoors == true
                elseif kind == "plank" then
                    wanted = settings.AutoReplank == true
                elseif kind == "gun" then
                    local gun = prompt:FindFirstAncestorWhichIsA("Model")
                    local weapons = Context.folder("Weapons")
                    while gun and gun.Parent ~= weapons do
                        gun = gun.Parent
                    end
                    wanted = settings.AutoBuyGuns == true and gun ~= nil and not owns(gun.Name) and balance >= costAbove(prompt)
                else
                    wanted = settings.AutoInteract == true and not string.find(string.lower(prompt.ActionText), "revive", 1, true) and balance >= costAbove(prompt)
                end
                if wanted and (position - root.Position).Magnitude <= reach then
                    cooldown[prompt] = now + COOLDOWN
                    balance -= costAbove(prompt)
                    pcall(press, prompt)
                end
            end
        end
    end
end

local function trapImmunity(enabled: boolean)
    local traps = Context.folder("Traps")
    if enabled then
        if not traps then
            return
        end
        for _, object in traps:GetDescendants() do
            if object:IsA("BasePart") and object.CanTouch and saved[object] == nil then
                saved[object] = true
                pcall(function()
                    object.CanTouch = false
                end)
            end
        end
    else
        for object in saved do
            if object.Parent then
                pcall(function()
                    object.CanTouch = true
                end)
            end
            saved[object] = nil
        end
    end
end

function Endless.step()
    local now = os.clock()
    if now - last < INTERVAL then
        return
    end
    last = now
    local settings = Context.S
    trapImmunity(settings.TrapImmunity == true)
    local interacting = settings.AutoReplank or settings.AutoOpenDoors or settings.AutoInteract or settings.AutoBuyGuns
    if settings.AutoRevive or interacting then
        startTracking()
    end
    if settings.AutoRevive then
        revive()
    end
    if interacting then
        if now - lastAction >= ACTION_INTERVAL then
            lastAction = now
            interact()
        end
    elseif not settings.AutoRevive and PromptWatch.holding("endless") then
        stopTracking()
    end
    if (settings.AutoBuyPerks or settings.AutoBuyMysteryBox) and now - lastBuy >= BUY_INTERVAL then
        lastBuy = now
        buy()
    end
end

function Endless.lines(): { string }
    if not Context.S.RoundHUD then
        return {}
    end
    local alive = 0
    local nearest = math.huge
    local root = Context.root(Context.LocalPlayer.Character)
    for _, model in Targets.killers() do
        if Targets.alive(model) then
            alive += 1
            local part = model:FindFirstChild("HumanoidRootPart")
            if root and part and part:IsA("BasePart") then
                nearest = math.min(nearest, (part.Position - root.Position).Magnitude)
            end
        end
    end
    return {
        "Enemies alive: " .. alive,
        "Nearest enemy: " .. (if nearest == math.huge then "none" else string.format("%d studs", nearest)),
        "Points: " .. points(),
    }
end

function Endless.stop()
    trapImmunity(false)
    stopTracking()
end

return Endless
end
modules["environment"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")

local Environment = {}

type Base = {
    Ambient: Color3,
    OutdoorAmbient: Color3,
    Brightness: number,
    ClockTime: number,
    FogStart: number,
    FogEnd: number,
    GlobalShadows: boolean,
}

local FOG_LIMIT = 100000
local FAR_FOG = 1000000
local FULL_AMBIENT = Color3.fromRGB(255, 255, 255)
local FULL_BRIGHTNESS = 2
local FULL_CLOCK = 14
local UPDATE_SECONDS = 0.14
local FADE_SPEED = 7

local base: Base? = nil
local atmospheres: { [any]: { Density: number, Haze: number, Glare: number } } = setmetatable({}, { __mode = "k" }) :: any
local links: { any } = {}
local last = 0
local lastFrame = 0
local blends = { Light = 0, Fog = 0 }

local function approach(current: number, goal: number, dt: number): number
    local value = current + (goal - current) * (1 - math.exp(-FADE_SPEED * dt))
    if math.abs(goal - value) < 0.002 then
        return goal
    end
    return value
end

local function capture()
    if base then
        return
    end
    local lighting = Context.Lighting
    base = {
        Ambient = lighting.Ambient,
        OutdoorAmbient = lighting.OutdoorAmbient,
        Brightness = lighting.Brightness,
        ClockTime = lighting.ClockTime,
        FogStart = lighting.FogStart,
        FogEnd = lighting.FogEnd,
        GlobalShadows = lighting.GlobalShadows,
    }
end

local function restoreLighting()
    local saved = base
    if not saved then
        return
    end
    local lighting = Context.Lighting
    pcall(function()
        lighting.Ambient = saved.Ambient
        lighting.OutdoorAmbient = saved.OutdoorAmbient
        lighting.Brightness = saved.Brightness
        lighting.ClockTime = saved.ClockTime
        lighting.FogStart = saved.FogStart
        lighting.FogEnd = saved.FogEnd
        lighting.GlobalShadows = saved.GlobalShadows
    end)
    base = nil
end

local function atmosphere(amount: number)
    for _, child in Context.Lighting:GetChildren() do
        if child:IsA("Atmosphere") then
            if amount > 0 then
                local original = atmospheres[child]
                if not original then
                    original = { Density = child.Density, Haze = child.Haze, Glare = child.Glare }
                    atmospheres[child] = original
                end
                local keep = 1 - amount
                child.Density, child.Haze, child.Glare = original.Density * keep, original.Haze * keep, original.Glare * keep
            elseif atmospheres[child] then
                local original = atmospheres[child]
                pcall(function()
                    child.Density, child.Haze, child.Glare = original.Density, original.Haze, original.Glare
                end)
                atmospheres[child] = nil
            end
        end
    end
end

local function fade(from: number, to: number, amount: number): number
    return from + (to - from) * amount
end

local function fogEnd(from: number, amount: number): number
    local start = math.max(from, 1)
    return start * (FAR_FOG / start) ^ amount
end

function Environment.lighting()
    local settings = Context.S
    local light, fog = blends.Light, blends.Fog
    local active = settings.Fullbright or settings.RemoveFog or settings.VisualNoShadows or light > 0 or fog > 0
    if active then
        capture()
    end
    local saved = base
    local lighting = Context.Lighting
    if saved then
        lighting.Ambient = saved.Ambient:Lerp(FULL_AMBIENT, light)
        lighting.OutdoorAmbient = saved.OutdoorAmbient:Lerp(FULL_AMBIENT, light)
        lighting.Brightness = fade(saved.Brightness, FULL_BRIGHTNESS, light)
        lighting.ClockTime = fade(saved.ClockTime, FULL_CLOCK, light)
        lighting.FogStart = fade(saved.FogStart, 0, fog)
        lighting.FogEnd = fogEnd(saved.FogEnd, fog)
        lighting.GlobalShadows = if settings.VisualNoShadows or light > 0.5 then false else saved.GlobalShadows
    end
    atmosphere(fog)
    if not active then
        restoreLighting()
    end
end

function Environment.tick()
    local now = os.clock()
    local dt = math.min(now - lastFrame, 0.1)
    lastFrame = now
    local settings = Context.S
    local light = approach(blends.Light, if settings.Fullbright then 1 else 0, dt)
    local fog = approach(blends.Fog, if settings.RemoveFog then 1 else 0, dt)
    local moving = light ~= blends.Light or fog ~= blends.Fog
    blends.Light, blends.Fog = light, fog
    if moving or now - last >= UPDATE_SECONDS then
        last = now
        Environment.lighting()
    end
end

local function hookAtmosphere(child: any)
    if child and child:IsA("Atmosphere") then
        table.insert(links, child:GetPropertyChangedSignal("Density"):Connect(function()
            if Context.Running and Context.S.RemoveFog and blends.Fog >= 1 and child.Density > 0 then
                child.Density, child.Haze, child.Glare = 0, 0, 0
            end
        end))
    end
end

function Environment.start()
    local lighting = Context.Lighting
    table.insert(links, lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
        if Context.Running and Context.S.RemoveFog and blends.Fog >= 1 and lighting.FogEnd < FOG_LIMIT then
            lighting.FogEnd = FAR_FOG
        end
    end))
    table.insert(links, lighting:GetPropertyChangedSignal("FogStart"):Connect(function()
        if Context.Running and Context.S.RemoveFog and blends.Fog >= 1 and lighting.FogStart > 0 then
            lighting.FogStart = 0
        end
    end))
    for _, child in lighting:GetChildren() do
        hookAtmosphere(child)
    end
    table.insert(links, lighting.ChildAdded:Connect(function(child: any)
        hookAtmosphere(child)
        if Context.Running and child:IsA("Atmosphere") and blends.Fog > 0 then
            atmosphere(blends.Fog)
        end
    end))
end

function Environment.stop()
    for _, link in links do
        pcall(function()
            link:Disconnect()
        end)
    end
    table.clear(links)
    blends.Light, blends.Fog = 0, 0
    restoreLighting()
    for child, original in atmospheres do
        if child and child.Parent then
            pcall(function()
                child.Density, child.Haze, child.Glare = original.Density, original.Haze, original.Glare
            end)
        end
        atmospheres[child] = nil
    end
end

return Environment
end
modules["esp"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")
local Modes: typeof(require("./modes")) = import("modes")
local Registry: typeof(require("./registry")) = import("registry")
local Targets: typeof(require("./targets")) = import("targets")

local ESP = {}

type Map = { [string]: any }

local MAX_DISTANCE = 5000
local MIN_DEPTH = 0.05
local BOUNDS_CACHE = 0.25
local IGNORED_PARTS = { "hitbox", "projectile", "bullet", "grenade", "puddle", "slime", "trail", "particle" }

local EDGES = {
    { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 },
    { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 },
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 },
}

local idle = false
local LABEL_SECONDS = 0.1

local CHARACTER_KINDS: { [string]: boolean } = { killer = true, survivor = true, npc = true, boss = true }

type Kind = {
    Enabled: string,
    Highlight: boolean,
    Tracer: string?,
    Distance: string,
    Health: string?,
    Offscreen: string?,
    Styled: boolean,
}

local KINDS: { [string]: Kind } = {
    weapon = { Enabled = "VisualWeaponESP", Highlight = true, Tracer = "VisualWeaponTracers", Distance = "VisualWeaponShowDistance", Offscreen = "VisualWeaponOffscreen", Styled = true },
    killer = { Enabled = "VisualKillerESP", Highlight = true, Tracer = "VisualKillerTracers", Distance = "VisualKillerShowDistance", Health = "VisualKillerShowHealth", Offscreen = "VisualKillerOffscreen", Styled = true },
    survivor = { Enabled = "VisualSurvivorESP", Highlight = true, Tracer = "VisualSurvivorTracers", Distance = "VisualSurvivorShowDistance", Health = "VisualSurvivorShowHealth", Offscreen = "VisualSurvivorOffscreen", Styled = true },
    npc = { Enabled = "VisualNPCESP", Highlight = true, Tracer = "VisualNPCTracers", Distance = "VisualNPCShowDistance", Health = "VisualNPCShowHealth", Offscreen = "VisualNPCOffscreen", Styled = true },
    boss = { Enabled = "VisualBossESP", Highlight = true, Tracer = "VisualBossTracers", Distance = "VisualBossShowDistance", Health = "VisualBossShowHealth", Offscreen = "VisualBossOffscreen", Styled = true },
    keycard = { Enabled = "VisualKeycardESP", Highlight = true, Distance = "VisualPickupShowDistance", Styled = true },
    paper = { Enabled = "VisualPaperESP", Highlight = true, Distance = "VisualPickupShowDistance", Styled = true },
    landmark = { Enabled = "VisualLandmarkESP", Highlight = false, Distance = "VisualMapShowDistance", Styled = false },
    secret = { Enabled = "VisualSecretAreaESP", Highlight = false, Distance = "VisualMapShowDistance", Styled = false },
    pack = { Enabled = "VisualPackAPunchESP", Highlight = true, Distance = "VisualMapShowDistance", Styled = false },
    camera = { Enabled = "VisualSurveillanceESP", Highlight = false, Distance = "VisualMapShowDistance", Styled = false },
    prompt = { Enabled = "VisualInteractableESP", Highlight = false, Distance = "VisualMapShowDistance", Styled = false },
    facility_objective = { Enabled = "VisualFacilityObjectiveESP", Highlight = true, Distance = "VisualFacilityShowDistance", Styled = false },
    perk = { Enabled = "VisualEndlessPerksESP", Highlight = true, Distance = "VisualEndlessShowDistance", Styled = false },
    mystery = { Enabled = "VisualMysteryBoxESP", Highlight = true, Distance = "VisualEndlessShowDistance", Styled = false },
    trap = { Enabled = "VisualTrapESP", Highlight = true, Distance = "VisualEndlessShowDistance", Styled = false },
}

local function usable(part: any, rootParent: any, rootPosition: Vector3): boolean
    if not part or not part:IsA("BasePart") or not part.Parent then
        return false
    end
    if part.Transparency >= 0.98 and part.LocalTransparencyModifier >= 0.98 then
        return false
    end
    local node = part.Parent
    while node and node ~= rootParent do
        if node:IsA("Tool") then
            return false
        end
        node = node.Parent
    end
    local lowered = string.lower(part.Name)
    for _, word in IGNORED_PARTS do
        if string.find(lowered, word, 1, true) then
            return false
        end
    end
    local size = part.Size
    if size.X > 40 or size.Y > 40 or size.Z > 40 then
        return false
    end
    return (part.Position - rootPosition).Magnitude <= 30
end

local function characterBounds(model: any, root: any): (CFrame?, Vector3?)
    local basis = root.CFrame
    local rootParent, rootPosition = root.Parent, root.Position
    local lowX, lowY, lowZ = math.huge, math.huge, math.huge
    local highX, highY, highZ = -math.huge, -math.huge, -math.huge
    local found = false
    for _, part in model:GetDescendants() do
        if usable(part, rootParent, rootPosition) then
            local half = part.Size * 0.5
            local frame = part.CFrame
            local hx, hy, hz = half.X, half.Y, half.Z
            for sx = -1, 1, 2 do
                for sy = -1, 1, 2 do
                    for sz = -1, 1, 2 do
                        local point = basis:PointToObjectSpace(frame:PointToWorldSpace(Vector3.new(hx * sx, hy * sy, hz * sz)))
                        local px, py, pz = point.X, point.Y, point.Z
                        lowX, lowY, lowZ = math.min(lowX, px), math.min(lowY, py), math.min(lowZ, pz)
                        highX, highY, highZ = math.max(highX, px), math.max(highY, py), math.max(highZ, pz)
                        found = true
                    end
                end
            end
        end
    end
    if not found then
        return nil, nil
    end
    local low = Vector3.new(lowX, lowY, lowZ)
    local high = Vector3.new(highX, highY, highZ)
    local size = high - low
    if size.X > 0.1 and size.Y > 0.1 and size.Z > 0.1 then
        return basis * CFrame.new((low + high) * 0.5), size
    end
    return nil, nil
end

local function boundsOf(entry: Map): (CFrame?, Vector3?)
    local now = os.clock()
    if entry.BoundsAt and now - entry.BoundsAt < BOUNDS_CACHE and entry.BoundsFrame then
        return entry.BoundsFrame, entry.BoundsSize
    end
    local frame, size = nil, nil
    local target = entry.Target
    if target:IsA("BasePart") then
        frame, size = target.CFrame, target.Size
    elseif target:IsA("Tool") then
        local handle = target:FindFirstChild("Handle", true)
        if handle and handle:IsA("BasePart") then
            frame, size = handle.CFrame, handle.Size
        end
    elseif target:IsA("Model") then
        local humanoid = target:FindFirstChildOfClass("Humanoid")
        local root = target:FindFirstChild("HumanoidRootPart", true) or target:FindFirstChild("UpperTorso", true) or target:FindFirstChild("Torso", true)
        if humanoid and root and root:IsA("BasePart") then
            frame, size = characterBounds(target, root)
        end
        if not frame then
            local ok, boxFrame, boxSize = pcall(function()
                local cframe, extent = target:GetBoundingBox()
                return cframe, extent
            end)
            if ok then
                frame, size = boxFrame, boxSize
            end
        end
    end
    if not frame then
        local adornee = entry.Adornee
        if adornee and adornee:IsA("BasePart") then
            frame, size = adornee.CFrame, adornee.Size
        end
    end
    entry.BoundsAt, entry.BoundsFrame, entry.BoundsSize = now, frame, size
    return frame, size
end

local function drawBox(canvas: any, entry: Map, mode: string, settings: Map)
    local frame, size = boundsOf(entry)
    if not frame or not size then
        return
    end
    local half = size * 0.5
    local points: { Vector2? } = {}
    local depths: { number } = {}
    local anyFront = false
    local offsets = {
        Vector3.new(-half.X, -half.Y, -half.Z), Vector3.new(half.X, -half.Y, -half.Z),
        Vector3.new(half.X, half.Y, -half.Z), Vector3.new(-half.X, half.Y, -half.Z),
        Vector3.new(-half.X, -half.Y, half.Z), Vector3.new(half.X, -half.Y, half.Z),
        Vector3.new(half.X, half.Y, half.Z), Vector3.new(-half.X, half.Y, half.Z),
    }
    for index = 1, 8 do
        local point, depth = canvas.project(frame:PointToWorldSpace(offsets[index]))
        points[index], depths[index] = point, depth
        if point and depth > MIN_DEPTH then
            anyFront = true
        end
    end
    if not anyFront then
        return
    end
    local color: Color3 = settings.ColorBox
    local alpha = 1 - math.clamp(settings.VisualHighlightOutlineTransparency, 0, 1)
    local thickness = math.max(1, settings.VisualBoxThickness)
    if mode == "2D Box" then
        local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
        for index = 1, 8 do
            local point = points[index]
            if point and depths[index] > MIN_DEPTH then
                left, top, right, bottom = math.min(left, point.X), math.min(top, point.Y), math.max(right, point.X), math.max(bottom, point.Y)
            end
        end
        if right > left and bottom > top then
            canvas.rect(Vector2.new(left, top), Vector2.new(right - left, bottom - top), color, alpha, thickness)
        end
        return
    end
    for _, edge in EDGES do
        local from, to = points[edge[1]], points[edge[2]]
        if from and to and depths[edge[1]] > MIN_DEPTH and depths[edge[2]] > MIN_DEPTH then
            canvas.line(from, to, color, alpha, thickness)
        end
    end
end

local function format(entry: Map, kind: Kind, distance: number, settings: Map): string
    local name: string = entry.DisplayName or entry.Target.Name or "Object"
    local studs = tostring(math.floor(distance + 0.5)) .. " studs"
    local showDistance = settings[kind.Distance]
    if entry.Kind == "weapon" then
        return if showDistance then "[" .. name .. "]  -  " .. studs else "[" .. name .. "]"
    end
    if CHARACTER_KINDS[entry.Kind] then
        local pieces = { name }
        if kind.Health and settings[kind.Health] and entry.Target:IsA("Model") then
            local humanoid = entry.Target:FindFirstChildOfClass("Humanoid")
            if humanoid then
                table.insert(pieces, string.format("%d/%d HP", math.floor(humanoid.Health + 0.5), math.floor(humanoid.MaxHealth + 0.5)))
            end
        end
        if showDistance then
            table.insert(pieces, studs)
        end
        return table.concat(pieces, "  -  ")
    end
    if entry.Kind == "prompt" and entry.Meta then
        local action = tostring(entry.Meta.Action or "Interact")
        local object = tostring(entry.Meta.Object or name)
        return if showDistance then action .. " - " .. object .. "  -  " .. studs else action .. " - " .. object
    end
    return if showDistance then name .. "  -  " .. studs else name
end

local function highlight(entry: Map, on: boolean, mode: string, settings: Map)
    local object = entry.Highlight
    if not object then
        entry.HighlightOn = false
        return
    end
    local outline = mode == "Outline" or mode == "Outline + Fill"
    local fill = mode == "Fill" or mode == "Outline + Fill"
    local shown = on and (outline or fill)
    if not shown then
        if entry.HighlightOn ~= false then
            entry.HighlightOn = false
            object.Enabled = false
        end
        return
    end
    entry.HighlightOn = true
    local color: Color3 = settings.ColorBox
    local fillAlpha = if fill then math.clamp(settings.VisualHighlightFillTransparency, 0, 1) else 1
    local outlineAlpha = if outline then math.clamp(settings.VisualHighlightOutlineTransparency, 0, 1) else 1
    local depth = if settings.VisualThroughWalls then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
    if object.Enabled ~= true then
        object.Enabled = true
    end
    if entry.HighlightColor ~= color then
        entry.HighlightColor = color
        object.FillColor = color
        object.OutlineColor = color
    end
    if entry.HighlightFill ~= fillAlpha then
        entry.HighlightFill = fillAlpha
        object.FillTransparency = fillAlpha
    end
    if entry.HighlightOutline ~= outlineAlpha then
        entry.HighlightOutline = outlineAlpha
        object.OutlineTransparency = outlineAlpha
    end
    if entry.HighlightDepth ~= depth then
        entry.HighlightDepth = depth
        object.DepthMode = depth
    end
end

local function offscreen(canvas: any, camera: any, position: Vector3, settings: Map)
    local screen = camera:WorldToViewportPoint(position)
    if screen.Z > 0 and screen.X >= 0 and screen.X <= camera.ViewportSize.X and screen.Y >= 0 and screen.Y <= camera.ViewportSize.Y then
        return
    end
    local viewport = camera.ViewportSize
    local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
    local dx, dy = screen.X - center.X, screen.Y - center.Y
    if screen.Z < 0 then
        dx, dy = -dx, -dy
    end
    local magnitude = math.sqrt(dx * dx + dy * dy)
    if magnitude < 0.001 then
        dx, dy, magnitude = 0, -1, 1
    end
    dx, dy = dx / magnitude, dy / magnitude
    local margin = math.max(22, settings.VisualOffscreenArrowSize)
    local limitX, limitY = math.max(1, center.X - margin), math.max(1, center.Y - margin)
    local scale = math.min(limitX / math.max(math.abs(dx), 0.001), limitY / math.max(math.abs(dy), 0.001))
    local tip = center + Vector2.new(dx, dy) * scale
    local half = settings.VisualOffscreenArrowSize * 0.5
    local side = Vector2.new(-dy, dx)
    local forward = Vector2.new(dx, dy)
    canvas.filledTriangle(tip + forward * half, tip - forward * half + side * half * 0.8, tip - forward * half - side * half * 0.8, settings.ColorBox, 1)
end

local FORCEFIELD_FILL = Color3.fromRGB(70, 165, 225)
local FORCEFIELD_LIGHT = Color3.fromRGB(150, 220, 255)
local FORCEFIELD_WHITE = Color3.fromRGB(255, 255, 255)

local function wanted(kind: Kind, settings: Map): (boolean, boolean, boolean)
    local enabled = settings[kind.Enabled] == true
    local tracer = enabled and kind.Tracer ~= nil and settings[kind.Tracer] == true
    local arrow = kind.Offscreen ~= nil and settings[kind.Offscreen] == true and (enabled or kind.Offscreen ~= "VisualWeaponOffscreen")
    return enabled, tracer, arrow
end

local function update(canvas: any, camera: any, entry: Map, settings: Map, origin: Vector2, cameraPosition: Vector3, lift: Vector3)
    local kind = KINDS[entry.KindKey]
    if not kind then
        return
    end
    local enabled, tracer, arrow = wanted(kind, settings)
    local mode = if kind.Styled then settings.VisualMode else "Outline"
    if not enabled and not tracer and not arrow then
        highlight(entry, false, mode, settings)
        return
    end
    local position = Registry.positionOf(entry)
    if not position then
        return
    end
    local distance = (position - cameraPosition).Magnitude
    local within = distance <= MAX_DISTANCE
    highlight(entry, enabled and within and kind.Highlight, mode, settings)
    if enabled and within then
        if kind.Styled and (mode == "2D Box" or mode == "3D Box") and kind.Highlight then
            drawBox(canvas, entry, mode, settings)
        end
        local point, depth = canvas.project(position + lift)
        if point and depth > MIN_DEPTH then
            local backgroundAlpha = 1 - math.clamp(settings.VisualLabelBackgroundTransparency, 0, 1)
            local clock = os.clock()
            if not entry.LabelText or clock - (entry.LabelAt or 0) >= LABEL_SECONDS then
                entry.LabelAt = clock
                entry.LabelText = format(entry, kind, distance, settings)
            end
            canvas.label(point, settings.ESPTextSize, settings.ColorText, entry.LabelText, settings.ColorBackground, backgroundAlpha)
            if entry.Shielded then
                local lift = settings.ESPTextSize + 12
                canvas.glowLabel(point - Vector2.new(0, lift - 2), settings.ESPTextSize, "(FORCEFIELD)", FORCEFIELD_FILL, FORCEFIELD_LIGHT, FORCEFIELD_WHITE, os.clock())
            end
        end
    end
    if tracer and within then
        local point, depth = canvas.project(position)
        if point and depth > 0 then
            canvas.line(origin, point, settings.ColorTracer, 1 - math.clamp(settings.VisualTracerTransparency, 0, 1), math.max(1, settings.VisualTracerThickness))
        end
    end
    if arrow and within then
        offscreen(canvas, camera, position, settings)
    end
end

local UPKEEP_SECONDS = 0.15
local lastUpkeep = -math.huge

local BUCKET_KINDS: { [string]: { string } } = {
    Weapons = { "weapon" },
    Killers = { "killer", "npc" },
    Survivors = { "survivor" },
    Bosses = { "boss" },
    Keycards = { "keycard" },
    Papers = { "paper" },
    Landmarks = { "landmark" },
    Secrets = { "secret" },
    PackAPunch = { "pack" },
    Cameras = { "camera" },
    Prompts = { "prompt" },
    FacilityObjectives = { "facility_objective" },
    EndlessPerks = { "perk" },
    MysteryBox = { "mystery" },
    Traps = { "trap" },
}

local live: { [string]: boolean } = {}
local bucketLive: { [string]: boolean } = {}
local bucketWas: { [string]: boolean } = {}

local function bucketOn(name: string): boolean
    local kinds = BUCKET_KINDS[name]
    if not kinds then
        return true
    end
    for _, kind in kinds do
        if live[kind] then
            return true
        end
    end
    return false
end

local function upkeep()
    for bucket, registry in Registry.All do
        if not bucketLive[bucket] then
            continue
        end
        local stale: { any } = {}
        for key, entry in registry do
            if Registry.isSelf(entry.Target) or not Registry.alive(entry) then
                table.insert(stale, key)
            else
                local npcKiller = entry.Kind == "killer" and (not Modes.canReroll() or Context.Players:GetPlayerFromCharacter(entry.Target) == nil)
                local name = if npcKiller then "npc" else entry.Kind
                entry.KindKey = if KINDS[name] then name else nil
                local dead = CHARACTER_KINDS[entry.Kind] == true and entry.Target:IsA("Model") and Targets.dead(entry.Target)
                entry.Dead = dead
                if entry.Kind == "killer" then
                    entry.Shielded = entry.Target:FindFirstChildOfClass("ForceField") ~= nil
                end
                if dead and entry.Highlight and entry.HighlightOn ~= false then
                    entry.HighlightOn = false
                    entry.Highlight.Enabled = false
                end
            end
        end
        for _, key in stale do
            local entry = registry[key]
            if entry and entry.Highlight then
                pcall(function()
                    entry.Highlight:Destroy()
                end)
            end
            registry[key] = nil
        end
    end
end

function ESP.frame(canvas: any, camera: any)
    if not camera then
        return
    end
    local settings = Context.S
    local active = false
    for name, kind in KINDS do
        local enabled, tracer, arrow = wanted(kind, settings)
        local shown = enabled or tracer or arrow
        live[name] = shown
        if shown then
            active = true
        end
    end
    if not active then
        if not idle then
            idle = true
            ESP.hideAll()
            table.clear(bucketWas)
        end
        return
    end
    idle = false
    local woke = false
    for bucket in Registry.All do
        local on = bucketOn(bucket)
        if on and not bucketWas[bucket] then
            woke = true
        end
        bucketLive[bucket] = on
    end
    local now = os.clock()
    if woke or now - lastUpkeep >= UPKEEP_SECONDS then
        lastUpkeep = now
        upkeep()
    end
    local origin = Context.mouse()
    local cameraPosition = camera.CFrame.Position
    local lift = Vector3.new(0, settings.VisualBillboardOffset, 0)
    for bucket, registry in Registry.All do
        local on = bucketLive[bucket]
        if on or bucketWas[bucket] then
            for _, entry in registry do
                local name = entry.KindKey
                if name and not entry.Dead then
                    if live[name] then
                        update(canvas, camera, entry, settings, origin, cameraPosition, lift)
                    elseif entry.HighlightOn ~= false then
                        highlight(entry, false, "Outline", settings)
                    end
                end
            end
        end
        bucketWas[bucket] = on
    end
end

function ESP.hideAll()
    for _, registry in Registry.All do
        for _, entry in registry do
            if entry.Highlight then
                entry.Highlight.Enabled = false
            end
        end
    end
end

return ESP
end
modules["guns"] = function(...)

local import: (string) -> any = ...
local Aim: typeof(require("./aim")) = import("aim")
local Context: typeof(require("./context")) = import("context")
local Debug: typeof(require("./debug")) = import("debug")
local Projectiles: typeof(require("./projectiles")) = import("projectiles")
local Targets: typeof(require("./targets")) = import("targets")
local Weapons: typeof(require("./weapons")) = import("weapons")

local Guns = {}

type Map = { [string]: any }

local TRIGGER_MINIMUM = 0.025
local MINIGUN_INTERVAL = 0.035
local AURA_INTERVAL = 0.06

local class: any = nil
local originals: Map = {}
local utilities: any = nil
local originalCastRay: any = nil
local flameThreads: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local fireBusy: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local triggerBusy: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lastTrigger: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any
local mutedSounds: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any
local lastMinigun = 0
local lastAura = 0
local auraThreads: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local lastMoment = 0
local lastBullets = 1

local function space(weapon: any)
    local bullets = 1
    if type(weapon) == "table" then
        local count = rawget(weapon, "bullet_count")
        if type(count) == "number" and count >= 1 then
            bullets = math.floor(count)
        end
    end
    local now = math.floor(tick() * 1000)
    if now < lastMoment + lastBullets then
        task.wait()
        now = math.floor(tick() * 1000)
    end
    lastMoment = now + 1
    lastBullets = bullets
end

local METHODS = {
    "reload", "fire", "button1down", "update_ammo_gui", "new", "move_camera", "compute_inaccuracy",
    "play_animation", "screen_to_target", "missile_hit", "target_ray_callback",
}

local function unpackResults(results: any): ...any
    return table.unpack(results, 2, results.n)
end

local function cameraProvider(): Vector2
    return Context.mouse()
end

local function recoverLegacy(getter: any): any
    if type(getter) ~= "function" then
        return getter
    end
    local found: any = nil
    local function inspect(value: any)
        if type(value) == "function" and value ~= getter and not found then
            found = value
        elseif type(value) == "table" and rawget(value, "InfAmmo") ~= nil and rawget(value, "InfStoredAmmo") ~= nil then
            value.InfAmmo = false
            value.InfStoredAmmo = false
        end
    end
    local ok, upvalues = pcall((debug :: any).getupvalues, getter)
    if ok and type(upvalues) == "table" then
        for _, value in upvalues do
            inspect(value)
        end
    end
    return found or getter
end

local function hookUtilities()
    if utilities then
        return
    end
    local utilitiesScript = Context.ReplicatedStorage:FindFirstChild("Utilities")
    if not utilitiesScript or not utilitiesScript:IsA("ModuleScript") then
        return
    end
    local ok, loaded = pcall(require, utilitiesScript)
    if not ok or type(loaded) ~= "table" or type(loaded.cast_ray) ~= "function" then
        return
    end
    utilities = loaded
    originalCastRay = loaded.cast_ray
    loaded.cast_ray = function(self: any, params: any, origin: any, direction: any, callback: any, ...)
        local thread = coroutine.running()
        local weapon = thread and flameThreads[thread] or nil
        if Context.S.Wallbang and weapon then
            local function passThrough(result: any): boolean
                local part = result and result.Instance
                return part ~= nil and Aim.liveTarget(part, weapon)
            end
            return originalCastRay(self, params, origin, direction, passThrough, ...)
        end
        return originalCastRay(self, params, origin, direction, callback, ...)
    end
end

local function hookClass(weaponClass: any)
    class = weaponClass
    for _, method in METHODS do
        local value = weaponClass[method]
        originals[method] = if type(value) == "function" then value else nil
    end
    Aim.NativeRayCallback = originals.target_ray_callback

    local packets = weaponClass.weapon_packets
    local fireSend = type(packets) == "table" and type(packets.fire) == "table" and packets.fire.send or nil
    if type(fireSend) == "function" then
        pcall(function()
            packets.fire.send = function(data: any, ...)
                if type(data) == "table" and type(data.moment) == "number" then
                    Projectiles.lastMoment = data.moment
                end
                return fireSend(data, ...)
            end
            originals.fire_send = fireSend
        end)
    end

    if originals.new then
        weaponClass.new = function(self: any, tool: any, ...)
            local arguments = table.pack(...)
            local weapon = originals.new(self, tool, table.unpack(arguments, 1, arguments.n))
            Weapons.track(weapon, tool, arguments)
            Weapons.applyAmmo(weapon)
            return weapon
        end
    end

    if originals.fire then
        weaponClass.fire = function(self: any, provider: any, ...)
            Weapons.track(self)
            Debug.count("fire")
            if fireBusy[self] then
                space(self)
                Projectiles.begin(self, provider)
                return originals.fire(self, provider, ...)
            end
            local meta = Weapons.Meta[self]
            local count = 1
            local settings = Context.S
            if settings.ShotMultiplier and (not meta or meta.moduleName ~= "Flamethrower") then
                count = math.clamp(math.floor(tonumber(settings.ShotMultiplierCount) or 2), 1, 10)
            end
            if count <= 1 then
                space(self)
                Projectiles.begin(self, provider)
                return originals.fire(self, provider, ...)
            end
            local arguments = table.pack(...)
            fireBusy[self] = true
            local ok, first = pcall(function()
                local firstResult: any = nil
                for index = 1, count do
                    Weapons.applyAmmo(self)
                    space(self)
                    Projectiles.begin(self, provider)
                    local result = table.pack(originals.fire(self, provider, table.unpack(arguments, 1, arguments.n)))
                    if index == 1 then
                        firstResult = result
                    end
                    Weapons.applyAmmo(self)
                end
                return firstResult or { n = 0 }
            end)
            fireBusy[self] = nil
            if not ok then
                error(first, 0)
            end
            return table.unpack(first, 1, first.n or 0)
        end
    end

    if originals.move_camera then
        weaponClass.move_camera = function(self: any, ...)
            if Context.S.NoRecoil then
                return
            end
            return originals.move_camera(self, ...)
        end
    end

    if originals.compute_inaccuracy then
        weaponClass.compute_inaccuracy = function(self: any, ...)
            if Context.S.NoSpread then
                return 0
            end
            return originals.compute_inaccuracy(self, ...)
        end
    end

    if originals.play_animation then
        weaponClass.play_animation = function(self: any, name: any, ...)
            if (name == "Fire" or name == "Bolt") and (Context.S.MinigunMode or Context.S.RapidFire) and not Weapons.isFlame(self) then
                return
            end
            if Context.S.FastWeaponEquip and name == "Takeout" then
                local animations: any = rawget(self, "animations")
                local takeout = type(animations) == "table" and animations.Takeout or nil
                if type(takeout) == "table" then
                    local finalFrame: any = nil
                    for index = #takeout, 1, -1 do
                        if type(takeout[index]) == "table" then
                            finalFrame = takeout[index]
                            break
                        end
                    end
                    if finalFrame then
                        animations.Takeout = { finalFrame, 0 }
                        local results = table.pack(pcall(originals.play_animation, self, name, ...))
                        animations.Takeout = takeout
                        if not results[1] then
                            error(results[2], 0)
                        end
                        return unpackResults(results)
                    end
                end
            end
            return originals.play_animation(self, name, ...)
        end
    end

    if originals.screen_to_target then
        weaponClass.screen_to_target = function(self: any, provider: any, ...)
            Weapons.track(self)
            local settings = Context.S
            local thread = coroutine.running()
            local forced = thread and auraThreads[thread] or nil
            if forced and forced.Parent then
                return forced.Position
            end
            if settings.SilentAim then
                local target = Aim.best(self, settings.SilentAimFOV)
                if target and target.Parent and target:IsDescendantOf(Context.Workspace) then
                    Debug.count("silentAimTarget", Debug.describe(target))
                    return target.Position
                end
                Debug.count("silentAimNoTarget")
            end
            return originals.screen_to_target(self, provider, ...)
        end
    end

    if originals.missile_hit then
        weaponClass.missile_hit = function(self: any, missile: any, moment: any, hitPart: any, hitPosition: any, ...)
            local settings = Context.S
            local boss = Targets.boss()
            if boss and typeof(hitPart) == "Instance" and hitPart.Name ~= "WeakPoint" and hitPart:IsDescendantOf(boss) then
                local weak = Targets.aimPoint(boss)
                if weak and weak.Name == "WeakPoint" then
                    hitPart, hitPosition = weak, weak.Position
                end
            end
            if settings.Wallbang and hitPart and not Aim.liveTarget(hitPart, self) then
                Debug.count("hitIgnoredByWallbang", Debug.describe(hitPart))
                return
            end
            Debug.count("hitPassed", Debug.describe(hitPart))
            return originals.missile_hit(self, missile, moment, hitPart, hitPosition, ...)
        end
    end

    if originals.target_ray_callback then
        weaponClass.target_ray_callback = function(result: any, ...)
            if not Context.S.Wallbang then
                return originals.target_ray_callback(result, ...)
            end
            local part = result and result.Instance
            if part and Aim.liveTarget(part, Weapons.equipped()) then
                return true
            end
            return false
        end
    end

    if originals.button1down then
        weaponClass.button1down = function(self: any, ...)
            Weapons.track(self)
            local tool = rawget(self, "instance")
            if typeof(tool) == "Instance" and not tool:FindFirstAncestorOfClass("Model") then
                return
            end
            Weapons.applyState(self)
            Weapons.applyAmmo(self)
            local automatic, burst = self.is_auto, self.is_burst
            local forced = Context.S.AlwaysFullAuto
            if forced then
                rawset(self, "is_auto", true)
                rawset(self, "is_burst", false)
                pcall(function()
                    self:update_fire_mode()
                end)
            end
            local results = table.pack(pcall(originals.button1down, self, ...))
            if forced then
                rawset(self, "is_auto", automatic)
                rawset(self, "is_burst", burst)
                pcall(function()
                    self:update_fire_mode()
                end)
            end
            Weapons.applyAmmo(self)
            if not results[1] then
                error(results[2], 0)
            end
            return unpackResults(results)
        end
    end

    if originals.update_ammo_gui then
        weaponClass.update_ammo_gui = function(self: any, ...)
            Weapons.track(self)
            Weapons.applyAmmo(self)
            return originals.update_ammo_gui(self, ...)
        end
    end

    if originals.reload then
        weaponClass.reload = function(self: any, ...)
            Weapons.track(self)
            Weapons.applyState(self)
            Weapons.applyAmmo(self)
            if not (Context.S.InstantReload or Context.S.InfAmmo) then
                local results = table.pack(pcall(originals.reload, self, ...))
                Weapons.applyAmmo(self)
                if not results[1] then
                    error(results[2], 0)
                end
                return unpackResults(results)
            end
            local own = rawget(self, "reload_wait")
            rawset(self, "reload_wait", function()
                return 0
            end)
            local results = table.pack(pcall(originals.reload, self, ...))
            rawset(self, "reload_wait", own)
            Weapons.applyAmmo(self)
            if not results[1] then
                error(results[2], 0)
            end
            return unpackResults(results)
        end
    end

    Weapons.discover()
end

local patchedScripts: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any

local function patchModule(moduleScript: any)
    local ok, loaded = pcall(require, moduleScript)
    if ok and type(loaded) == "table" and Weapons.Modules[loaded] then
        patchedScripts[moduleScript] = loaded
    end
    if not ok or type(loaded) ~= "table" or type(rawget(loaded, "get_stats")) ~= "function" or Weapons.Modules[loaded] then
        return
    end
    patchedScripts[moduleScript] = loaded
    local current = loaded.get_stats
    if rawget(loaded, "__PatchedSuite") then
        current = recoverLegacy(current)
        loaded.get_stats = current
        rawset(loaded, "__PatchedSuite", nil)
    end
    local original = current
    Weapons.Modules[loaded] = original
    loaded.get_stats = function(self: any, pap: any, ...)
        local stats = original(self, pap, ...)
        if type(stats) == "table" then
            local settings = Context.S
            local delay = Weapons.fireDelay()
            if delay and moduleScript.Name ~= "Flamethrower" then
                stats.shoot_wait = delay
            end
            if settings.CustomPelletCount and Weapons.SHOTGUNS[moduleScript.Name] then
                stats.bullet_count = math.clamp(math.floor(tonumber(settings.PelletCount) or 12), 1, 50)
            end
        end
        return stats
    end
    rawset(loaded, "__PatchedSuite", true)

    local customHit = rawget(loaded, "missile_hit")
    if type(customHit) == "function" and customHit ~= originals.missile_hit then
        Weapons.Extra[loaded] = Weapons.Extra[loaded] or {}
        Weapons.Extra[loaded].missile_hit = customHit
        local index = if moduleScript.Name == "Flamethrower" then 1 else 3
        loaded.missile_hit = function(self: any, ...)
            local arguments = table.pack(...)
            local part = arguments[index]
            local settings = Context.S
            if settings.Wallbang and part and not Aim.liveTarget(part, self) then
                Debug.count("hitIgnoredByWallbang", Debug.describe(part))
                return
            end
            Debug.count("hitPassed", Debug.describe(part))
            return customHit(self, table.unpack(arguments, 1, arguments.n))
        end
    end

    if moduleScript.Name == "Flamethrower" then
        local customFire = rawget(loaded, "fire")
        if type(customFire) == "function" then
            Weapons.Extra[loaded] = Weapons.Extra[loaded] or {}
            if not Weapons.Extra[loaded].fire then
                Weapons.Extra[loaded].fire = customFire
                loaded.fire = function(self: any, ...)
                    local thread = coroutine.running()
                    if thread then
                        flameThreads[thread] = self
                    end
                    local results = table.pack(pcall(customFire, self, ...))
                    if thread then
                        flameThreads[thread] = nil
                    end
                    if not results[1] then
                        error(results[2], 0)
                    end
                    return unpackResults(results)
                end
            end
        end
    end
end

function Guns.patch()
    local folder = Context.ReplicatedStorage:FindFirstChild("Weapon")
    hookUtilities()
    if folder and folder:IsA("ModuleScript") and not class then
        local ok, loaded = pcall(require, folder)
        if ok and type(loaded) == "table" then
            hookClass(loaded)
        end
    end
    if folder then
        for _, child in folder:GetChildren() do
            local done = patchedScripts[child]
            if not (done and Weapons.Modules[done]) and child:IsA("ModuleScript") then
                patchModule(child)
            end
        end
    end
    for weapon in Weapons.Tracked do
        Weapons.applyAmmo(weapon)
    end
end

local SOUND_SECONDS = 1
local gunLinks: { [any]: any } = {}
local soundLinks: { [any]: any } = {}
local soundsAt = -math.huge

local function muteOne(sound: any, gun: any)
    if mutedSounds[sound] == nil then
        mutedSounds[sound] = sound.Volume
    end
    if sound.Volume ~= 0 then
        sound.Volume = 0
    end
    if not soundLinks[sound] then
        soundLinks[sound] = sound:GetPropertyChangedSignal("Volume"):Connect(function()
            if sound.Volume ~= 0 and Context.S.MuteGunSounds and sound:IsDescendantOf(gun) then
                sound.Volume = 0
            end
        end)
    end
end

local function hookGun(instance: any)
    for _, object in instance:GetDescendants() do
        if object:IsA("Sound") then
            muteOne(object, instance)
        end
    end
    gunLinks[instance] = instance.DescendantAdded:Connect(function(object: any)
        if object:IsA("Sound") and Context.S.MuteGunSounds then
            muteOne(object, instance)
        end
    end)
end

local function dropLinks(links: { [any]: any })
    for key, link in links do
        pcall(function()
            link:Disconnect()
        end)
        links[key] = nil
    end
end

local function muteSounds()
    if Context.S.MuteGunSounds then
        local now = os.clock()
        if now - soundsAt < SOUND_SECONDS then
            return
        end
        soundsAt = now
        for weapon in Weapons.Tracked do
            local instance = type(weapon) == "table" and rawget(weapon, "instance") or nil
            if instance and typeof(instance) == "Instance" and not gunLinks[instance] then
                hookGun(instance)
            end
        end
        for instance, link in gunLinks do
            if not instance.Parent then
                pcall(function()
                    link:Disconnect()
                end)
                gunLinks[instance] = nil
            end
        end
        for sound, link in soundLinks do
            if not sound.Parent then
                pcall(function()
                    link:Disconnect()
                end)
                soundLinks[sound] = nil
            end
        end
    else
        if next(gunLinks) ~= nil or next(soundLinks) ~= nil then
            dropLinks(gunLinks)
            dropLinks(soundLinks)
            soundsAt = -math.huge
        end
        for sound, volume in mutedSounds do
            if sound and sound.Parent then
                pcall(function()
                    sound.Volume = volume
                end)
            end
            mutedSounds[sound] = nil
        end
    end
end

local function minigunShot(weapon: any, fire: any)
    local settings = Context.S
    if not Context.Running or not settings.MinigunMode then
        return
    end
    if rawget(weapon, "equipped") ~= true or rawget(weapon, "ready") ~= true or rawget(weapon, "reloading") then
        return
    end
    Weapons.applyAmmo(weapon)
    pcall(fire, weapon, cameraProvider)
    Weapons.applyAmmo(weapon)
end

local function minigun(weapon: any)
    if not Context.S.MinigunMode or type(weapon) ~= "table" or Weapons.isFlame(weapon) then
        return
    end
    if rawget(weapon, "equipped") ~= true or rawget(weapon, "ready") ~= true or rawget(weapon, "reloading") then
        return
    end
    if not Context.UserInput:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        return
    end
    local now = os.clock()
    if now - lastMinigun < MINIGUN_INTERVAL then
        return
    end
    lastMinigun = now
    local fire = weapon.fire
    if type(fire) ~= "function" then
        return
    end
    local meta = Weapons.metaOf(weapon)
    local boost = math.clamp(math.floor(tonumber(Context.S.MinigunFireBoost) or 0), 0, 10)
    local count = if meta and meta.moduleName == "Flamethrower" then 1 else 2 + boost
    for _ = 1, count do
        task.spawn(minigunShot, weapon, fire)
    end
end

local function directHit(weapon: any, part: any, moment: number)
    local packets = class and class.weapon_packets
    local touch = type(packets) == "table" and type(packets.touch) == "table" and packets.touch.send or nil
    local instance = rawget(weapon, "instance")
    if type(touch) ~= "function" or typeof(instance) ~= "Instance" or not part.Parent then
        return
    end
    local count = rawget(weapon, "bullet_count")
    local bullets = if type(count) == "number" then math.clamp(math.floor(count), 1, 12) else 1
    for index = 0, bullets - 1 do
        pcall(touch, { hit = part, missile_position = part.Position, tool_name = instance.Name, moment = moment + index, instant = true })
    end
end

local AURA_SKIP: { [string]: boolean } = { giant = true, giantzombie = true, jane = true, janethekiller = true }
local auraSkipMemo: { [string]: boolean } = {}
local auraSkipCount = 0

local function auraSkipped(model: any): boolean
    local raw = model.Name
    local known = auraSkipMemo[raw]
    if known ~= nil then
        return known
    end
    local result = AURA_SKIP[string.gsub(string.lower(raw), "[^%a]", "")] == true
    if auraSkipCount >= 256 then
        auraSkipMemo, auraSkipCount = {}, 0
    end
    auraSkipMemo[raw] = result
    auraSkipCount += 1
    return result
end

local function aura(weapon: any)
    local settings = Context.S
    if not settings.KillAura or type(weapon) ~= "table" or Weapons.isFlame(weapon) then
        return
    end
    if rawget(weapon, "equipped") ~= true or rawget(weapon, "ready") ~= true or rawget(weapon, "reloading") then
        return
    end
    local now = os.clock()
    if now - lastAura < AURA_INTERVAL then
        return
    end
    lastAura = now
    local fire = weapon.fire
    local root = Context.root(Context.LocalPlayer.Character)
    if type(fire) ~= "function" or not root then
        return
    end
    local range = math.max(10, tonumber(settings.KillAuraRange) or 150)
    local wanted = math.clamp(math.floor(tonumber(settings.KillAuraTargets) or 3), 1, 30)
    local found: { { Part: any, Distance: number } } = {}
    local function consider(model: any)
        if not model or not model:IsA("Model") or auraSkipped(model) or not Targets.hostile(model) or Targets.shielded(model) then
            return
        end
        local part = Targets.aimPoint(model)
        if part and part:IsA("BasePart") then
            local distance = (part.Position - root.Position).Magnitude
            if distance <= range or model == Targets.boss() then
                table.insert(found, { Part = part, Distance = distance })
            end
        end
    end
    for _, model in Targets.enemies() do
        consider(model)
    end
    table.sort(found, function(a, b)
        return a.Distance < b.Distance
    end)
    for index = 1, math.min(wanted, #found) do
        local part = found[index].Part
        task.spawn(function()
            if not Context.Running or not Context.S.KillAura or rawget(weapon, "equipped") ~= true then
                return
            end
            local thread = coroutine.running()
            auraThreads[thread] = part
            Weapons.applyAmmo(weapon)
            local before = Projectiles.lastMoment
            pcall(fire, weapon, cameraProvider)
            Weapons.applyAmmo(weapon)
            auraThreads[thread] = nil
            local moment = Projectiles.lastMoment
            if moment ~= 0 and moment ~= before then
                directHit(weapon, part, moment)
            end
        end)
    end
end

local function trigger(weapon: any, part: any)
    if type(weapon) ~= "table" or triggerBusy[weapon] then
        return
    end
    if rawget(weapon, "equipped") ~= true or rawget(weapon, "ready") ~= true or rawget(weapon, "reloading") or rawget(weapon, "shooting") then
        return
    end
    local now = os.clock()
    local delay = math.max(tonumber(weapon.shoot_wait) or 0.1, TRIGGER_MINIMUM)
    if now - (lastTrigger[weapon] or 0) < delay then
        return
    end
    lastTrigger[weapon] = now
    triggerBusy[weapon] = true
    local function provider(): Vector2
        local camera = Context.camera()
        if part and part.Parent and camera then
            local point = camera:WorldToViewportPoint(part.Position)
            return Vector2.new(point.X, point.Y)
        end
        local viewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
        return Vector2.new(viewport.X / 2, viewport.Y / 2)
    end
    task.spawn(function()
        task.delay(math.max(tonumber(weapon.shoot_wait) or 0.05, 0.05), function()
            pcall(function()
                weapon:button1up()
            end)
        end)
        pcall(function()
            weapon:button1down(provider)
        end)
        pcall(function()
            weapon:button1up()
        end)
        triggerBusy[weapon] = nil
    end)
end

local lastReload = 0

local function autoReload(weapon: any)
    if type(weapon) ~= "table" or rawget(weapon, "ammo") ~= 0 then
        return
    end
    if rawget(weapon, "equipped") ~= true or rawget(weapon, "ready") ~= true or rawget(weapon, "reloading") then
        return
    end
    local now = os.clock()
    if now - lastReload < 0.3 then
        return
    end
    lastReload = now
    task.spawn(function()
        pcall(function()
            weapon:reload()
        end)
    end)
end

local STATE_SECONDS = 0.15
local lastState = -math.huge

function Guns.update()
    local settings = Context.S
    local equipped = Weapons.equipped()
    local now = os.clock()
    if now - lastState >= STATE_SECONDS then
        lastState = now
        for weapon in Weapons.Tracked do
            Weapons.applyState(weapon)
        end
    elseif equipped then
        Weapons.applyState(equipped)
    end
    muteSounds()
    if settings.InfAmmo and equipped then
        autoReload(equipped)
    end
    if settings.MinigunMode and equipped then
        minigun(equipped)
    end
    if settings.KillAura and equipped then
        aura(equipped)
    end
    if settings.AutoShoot and equipped then
        local target = Aim.triggerTarget(equipped, math.max(1, tonumber(settings.TriggerFOV) or 60))
        if target then
            trigger(equipped, target)
        end
    end
end

local RING_POINTS = 72

local function drawAuraRing(canvas: any)
    local root = Context.root(Context.LocalPlayer.Character)
    if not root then
        return
    end
    local radius = math.max(10, tonumber(Context.S.KillAuraRange) or 150)
    local center = root.Position - Vector3.new(0, 2.8, 0)
    local points: { Vector3 } = table.create(RING_POINTS + 1)
    for index = 0, RING_POINTS do
        local angle = index / RING_POINTS * math.pi * 2
        points[index + 1] = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
    end
    canvas.worldPath(points, Context.S.ColorBox, 0.9, 1.5)
end

function Guns.drawFov(canvas: any)
    local settings = Context.S
    if settings.KillAura and settings.ShowKillAuraCircle then
        drawAuraRing(canvas)
    end
    if settings.AutoShoot and settings.ShowTriggerFOV then
        canvas.circle(Aim.center(), math.max(1, tonumber(settings.TriggerFOV) or 60), settings.ColorBox, 0.6, 1)
    end
    if settings.ShowSilentAimFOV then
        canvas.circle(Aim.center(), math.max(1, tonumber(settings.SilentAimFOV) or 120), settings.ColorBox, 0.9, 1.5)
    end
end

function Guns.restore()
    Context.S.MuteGunSounds = false
    muteSounds()
    if utilities and originalCastRay then
        pcall(function()
            utilities.cast_ray = originalCastRay
        end)
    end
    table.clear(flameThreads)
    table.clear(auraThreads)
    if class then
        local packets = class.weapon_packets
        if type(originals.fire_send) == "function" and type(packets) == "table" and type(packets.fire) == "table" then
            pcall(function()
                packets.fire.send = originals.fire_send
            end)
        end
        originals.fire_send = nil
        for method, original in originals do
            if type(original) == "function" and method ~= "fire_send" then
                pcall(function()
                    class[method] = original
                end)
            end
        end
    end
    for loaded, methods in Weapons.Extra do
        for name, original in methods do
            if type(original) == "function" then
                pcall(function()
                    loaded[name] = original
                end)
            end
        end
    end
    for loaded, original in Weapons.Modules do
        if type(original) == "function" then
            pcall(function()
                loaded.get_stats = original
                rawset(loaded, "__PatchedSuite", nil)
            end)
        end
    end
    Weapons.normalize()
    table.clear(Weapons.Modules)
    table.clear(Weapons.Extra)
    Aim.NativeRayCallback = nil
    class, utilities, originalCastRay = nil, nil, nil
    table.clear(originals)
end

return Guns
end
modules["huds"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")
local Endless: typeof(require("./endless")) = import("endless")
local Modes: typeof(require("./modes")) = import("modes")
local Registry: typeof(require("./registry")) = import("registry")
local Targets: typeof(require("./targets")) = import("targets")

local Huds = {}

type Map = { [string]: any }
type Panel = { Handle: any, Lines: { string }, Shown: boolean, Width: number, Height: number }

local WIDTH = 250
local LINE_HEIGHT = 16
local CHROME_HEIGHT = 56
local UPDATE_SECONDS = 0.14
local CHAR_WIDTH = 6.6
local SIDE_PADDING = 36
local MAX_WIDTH = 560
local MAX_DISTANCE = 5000

local panels: { [string]: Panel } = {}
local last = 0

local function reading(area: any, flag: string): { string }
    local lines: { string } = {}
    if flag == "VisualAlienCodeHUD" then
        local model = area:FindFirstChild("CodeModel")
        local code = model and model:FindFirstChild("Code")
        if code and code:IsA("StringValue") then
            table.insert(lines, "Alien Code: " .. tostring(code.Value))
        end
    elseif flag == "VisualCleanerHUD" then
        local combination = area:FindFirstChild("CombinaisonModel")
        local values = combination and combination:FindFirstChild("CombinaisonValues")
        if values then
            local bits: { string } = {}
            for index = 1, 5 do
                local value = values:FindFirstChild(tostring(index))
                if not value or not value:IsA("BoolValue") then
                    return lines
                end
                bits[index] = if value.Value then "1" else "0"
            end
            table.insert(lines, "Cleaner: " .. table.concat(bits, ""))
        end
    elseif flag == "VisualVaultScreenHUD" then
        local sewer = area:FindFirstChild("SewerVaultRoom")
        if sewer then
            table.insert(lines, "Vault Code: 1947")
        end
    end
    return lines
end

local function nearest(cameraPosition: Vector3): { string }
    local settings = Context.S
    if not settings.VisualNearestWeaponHUD or not Registry.WeaponsFolder then
        return {}
    end
    local list: { { Name: string, Distance: number, Position: Vector3 } } = {}
    for _, entry in Registry.All.Weapons do
        local position = Registry.positionOf(entry)
        if position then
            local distance = (position - cameraPosition).Magnitude
            if distance <= MAX_DISTANCE then
                table.insert(list, { Name = entry.DisplayName, Distance = distance, Position = position })
            end
        end
    end
    table.sort(list, function(a, b)
        return a.Distance < b.Distance
    end)
    local lines: { string } = {}
    local wanted = math.clamp(math.floor(tonumber(settings.VisualWeaponHUDCount) or 6), 1, 12)
    for index = 1, math.min(#list, wanted) do
        local item = list[index]
        local text = string.format("%d. %s  -  %d studs", index, item.Name, math.floor(item.Distance + 0.5))
        if settings.VisualWeaponHUDCoordinates then
            text ..= string.format("  -  X:%d Z:%d", math.floor(item.Position.X + 0.5), math.floor(item.Position.Z + 0.5))
        end
        table.insert(lines, text)
    end
    return lines
end

local function warning(): { string }
    local settings = Context.S
    if not settings.VisualKillerWarning then
        return {}
    end
    local root = Context.root(Context.LocalPlayer.Character)
    if not root then
        return {}
    end
    local range = tonumber(settings.KillerWarningRange) or 60
    local list: { { Name: string, Distance: number } } = {}
    for _, model in Targets.killers() do
        local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
        if part and part:IsA("BasePart") then
            local distance = (part.Position - root.Position).Magnitude
            if distance <= range then
                table.insert(list, { Name = model.Name, Distance = distance })
            end
        end
    end
    table.sort(list, function(a, b)
        return a.Distance < b.Distance
    end)
    local lines: { string } = {}
    for index = 1, math.min(#list, 4) do
        table.insert(lines, string.format("DANGER %s  -  %d studs", list[index].Name, math.floor(list[index].Distance + 0.5)))
    end
    return lines
end

local function facility(): { string }
    local settings = Context.S
    if not Modes.facility() then
        return {}
    end
    local area = Context.folder("AREA51")
    if not area then
        return {}
    end
    local lines: { string } = {}
    for _, flag in { "VisualAlienCodeHUD", "VisualCleanerHUD", "VisualVaultScreenHUD" } do
        if settings[flag] then
            for _, line in reading(area, flag) do
                table.insert(lines, line)
            end
        end
    end
    for _, line in warning() do
        table.insert(lines, line)
    end
    return lines
end

local function alive(cameraPosition: Vector3): { string }
    local settings = Context.S
    if not settings.AliveHUD then
        return {}
    end
    local root = Context.root(Context.LocalPlayer.Character)
    local origin = if root then root.Position else cameraPosition
    local list: { { Name: string, Distance: number, Health: number } } = {}
    for _, model in Targets.enemies() do
        local part = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if part and part:IsA("BasePart") and humanoid then
            table.insert(list, { Name = model.Name, Distance = (part.Position - origin).Magnitude, Health = humanoid.Health })
        end
    end
    table.sort(list, function(a, b)
        return a.Distance < b.Distance
    end)
    local lines: { string } = { "Alive: " .. #list }
    local wanted = math.clamp(math.floor(tonumber(settings.AliveHUDCount) or 8), 1, 15)
    for index = 1, math.min(#list, wanted) do
        local item = list[index]
        table.insert(lines, string.format("%d. %s  -  %d studs  -  %d HP", index, item.Name, math.floor(item.Distance + 0.5), math.floor(item.Health + 0.5)))
    end
    if #list > wanted then
        table.insert(lines, string.format("+%d more", #list - wanted))
    end
    return lines
end

local function create(ui: any, id: string, title: string, x: number, y: number)
    local panel: Panel = { Handle = nil, Lines = {}, Shown = false, Width = 0, Height = 0 }
    panel.Handle = ui:panel({
        Id = id,
        Title = title,
        Width = WIDTH,
        Height = CHROME_HEIGHT + LINE_HEIGHT,
        MinWidth = 180,
        MinHeight = CHROME_HEIGHT,
        Persistent = true,
        Render = function(kit: any, window: any)
            local pal = window.Pal
            for index, line in panel.Lines do
                kit:text(line, 4, 8 + (index - 1) * LINE_HEIGHT, 11, pal.Text, false, true)
            end
        end,
    })
    panel.Handle.setPosition(Vector2.new(x, y))
    panels[id] = panel
end

function Huds.register(ui: any)
    create(ui, "weapons-nearest", "Nearest Weapons", 40, 120)
    create(ui, "facility-intel", "Facility Intel", 40, 40)
    create(ui, "round-info", "Round Info", 40, 200)
    create(ui, "alive-list", "Alive Enemies", 300, 120)
end

local function show(panel: Panel, lines: { string })
    panel.Lines = lines
    if #lines > 0 then
        local longest = 0
        for _, line in lines do
            longest = math.max(longest, #line)
        end
        local width = math.clamp(longest * CHAR_WIDTH + SIDE_PADDING, WIDTH, MAX_WIDTH)
        local height = CHROME_HEIGHT + #lines * LINE_HEIGHT
        if width ~= panel.Width or height ~= panel.Height then
            panel.Width, panel.Height = width, height
            panel.Handle.setSize(width, height)
        end
        if not panel.Shown then
            panel.Shown = true
            panel.Handle.open()
        end
    else
        if panel.Handle.isOpen() then
            panel.Handle.close()
        end
        panel.Shown = false
    end
end

function Huds.update(cameraPosition: Vector3)
    local now = os.clock()
    if now - last < UPDATE_SECONDS then
        return
    end
    last = now
    show(panels["weapons-nearest"], nearest(cameraPosition))
    show(panels["facility-intel"], facility())
    show(panels["round-info"], if Modes.Current == "Endless" then Endless.lines() else {})
    show(panels["alive-list"], alive(cameraPosition))
end

function Huds.closeAll()
    for _, panel in panels do
        panel.Handle.close()
    end
end

return Huds
end
modules["interface"] = function(...)

local import: (string) -> any = ...
local AimParts: typeof(require("./aimparts")) = import("aimparts")
local Changelog: typeof(require("./changelog")) = import("changelog")
local Classic: typeof(require("./classic")) = import("classic")
local Config: typeof(require("./config")) = import("config")
local Modes: typeof(require("./modes")) = import("modes")
local Movement: typeof(require("./movement")) = import("movement")
local KillAll: typeof(require("./killall")) = import("killall")
local Portraits: typeof(require("./portraits")) = import("portraits")
local Reroll: typeof(require("./reroll")) = import("reroll")

local Interface = {}

type Actions = {
    pick: () -> (),
    chooseAimParts: () -> (),
}

local D = Config.DEFAULTS


local function on(requires: any): ((window: any) -> boolean)?
    if requires == nil then
        return nil
    end
    local flags: { string } = if type(requires) == "table" then requires else { requires }
    return function(window: any): boolean
        for _, flag in flags do
            if window:get(flag) then
                return true
            end
        end
        return false
    end
end

local function both(first: string, second: string): (window: any) -> boolean
    return function(window: any): boolean
        return window:get(first) == true and window:get(second) == true
    end
end

local switchNames: { [string]: string } = {}
local switchRows: { [string]: any } = {}
local switchFirst: { [string]: boolean } = {}
local headed: { [any]: boolean } = {}
local captioned: { [any]: string? } = {}

local function gate(section: any, requires: any)
    if type(requires) ~= "string" or not switchNames[requires] then
        local last = captioned[section]
        if last and requires == nil then
            section:label({ Text = "", Height = 6, Show = on(last) })
        end
        captioned[section] = nil
        return
    end
    if captioned[section] ~= requires then
        captioned[section] = requires
        if switchFirst[requires] then
            return
        end
        local rows = section.Spec.rows
        local index = table.find(rows, switchRows[requires])
        section:label({ Text = switchNames[requires] .. " Settings", Size = 12, Height = 28, Offset = 4, Show = on(requires) })
        if index then
            table.insert(rows, index, table.remove(rows))
        end
    end
end

local function toggle(section: any, name: string, flag: string, shown: any?, keywords: string?)
    if shown == nil then
        switchNames[flag] = name
        switchFirst[flag] = headed[section] == true
    end
    gate(section, shown)
    headed[section] = false
    section:toggle({ Name = name, Flag = flag, Default = D[flag], Show = on(shown), Keywords = keywords })
    if shown == nil then
        switchRows[flag] = section.Spec.rows[#section.Spec.rows]
    end
end

local function slider(section: any, name: string, flag: string, min: number, max: number, step: number, format: ((number) -> string)?, shown: any?)
    gate(section, shown)
    section:slider({ Name = name, Flag = flag, Min = min, Max = max, Step = step, Default = D[flag], Format = format, Show = if type(shown) == "function" then shown else on(shown) })
end

local function twin(section: any, left: { string }, right: { string }, shown: any?)
    local show = on(shown)
    gate(section, shown)
    section:pair(
        { Type = "Toggle", Name = left[1], Flag = left[2], Default = D[left[2]], Keywords = left[3], Show = show },
        { Type = "Toggle", Name = right[1], Flag = right[2], Default = D[right[2]], Keywords = right[3], Show = show }
    )
end

local function header(section: any, text: string)
    captioned[section] = nil
    headed[section] = true
    section:label({ Text = text, Size = 12, Height = 28, Offset = 4 })
end

local function whole(value: number): string
    return string.format("%d", math.floor(value + 0.5))
end

local function seconds(value: number): string
    return string.format("%.2f", value)
end

local function bossRush(): boolean
    return Modes.Current == "Boss Rush"
end

local function guns(ui: any)
    local section = ui:tab("Guns"):section("GUNS")
    header(section, "Ammo")
    twin(section, { "Infinite Clip Ammo", "InfAmmo" }, { "Infinite Reserve Ammo", "InfStoredAmmo" })
    twin(section, { "Instant Reload", "InstantReload", "fast reload" }, { "Instant Equip", "FastWeaponEquip", "weapon equip" })
    header(section, "Handling")
    twin(section, { "No Recoil", "NoRecoil", "camera recoil" }, { "No Spread", "NoSpread", "zero bullet spread" })
    twin(section, { "Always Full Auto", "AlwaysFullAuto", "automatic" }, { "Wallbang", "Wallbang", "raycast walls" })
    header(section, "Fire Rate")
    toggle(section, "Rapid Fire", "RapidFire", nil, "fire rate override")
    slider(section, "Fire Delay (Seconds)", "CustomFireRate", 0, 0.5, 0.01, seconds, "RapidFire")
    toggle(section, "Minigun Mode", "MinigunMode", nil, "extreme fire rate")
    slider(section, "Minigun Fire Rate Boost", "MinigunFireBoost", 0, 10, 1, whole, "MinigunMode")
    toggle(section, "Shot Multiplier", "ShotMultiplier")
    slider(section, "Shots Per Fire", "ShotMultiplierCount", 1, 10, 1, whole, "ShotMultiplier")
end

local function aim(ui: any, actions: Actions, killAura: boolean, hitbox: boolean)
    local section = ui:tab("Aim"):section("AIM")
    header(section, "Targeting")
    toggle(section, "Silent Aim", "SilentAim")
    twin(section, { "Show FOV Circle", "ShowSilentAimFOV", "silent aim fov" }, { "Cycle Targets", "TargetCycling", "silent aim" }, "SilentAim")
    slider(section, "Silent Aim FOV (Px)", "SilentAimFOV", 30, 400, 5, whole, "SilentAim")
    ui:flag("SilentAimParts", D.SilentAimParts)
    gate(section, "SilentAim")
    section:button({
        Name = "Select Silent Aim Parts",
        Label = function()
            return "Aim Parts: " .. AimParts.label(ui:get("SilentAimParts"))
        end,
        Callback = actions.chooseAimParts,
        Show = on("SilentAim"),

    })
    toggle(section, "Triggerbot", "AutoShoot", nil, "auto shoot")
    toggle(section, "Show Triggerbot FOV Circle", "ShowTriggerFOV", "AutoShoot")
    slider(section, "Triggerbot FOV (Px)", "TriggerFOV", 10, 400, 5, whole, "AutoShoot")
    if killAura then
        toggle(section, "Kill Aura", "KillAura", nil, "hold a gun")
        local shown = on("KillAura")
        gate(section, "KillAura")
        section:pair(
            { Type = "Slider", Name = "Distance (Studs)", Flag = "KillAuraRange", Min = 10, Max = 1000, Step = 10, Default = D.KillAuraRange, Format = whole, Show = shown, Keywords = "kill aura" },
            { Type = "Slider", Name = "Targets Per Burst", Flag = "KillAuraTargets", Min = 1, Max = 30, Step = 1, Default = D.KillAuraTargets, Format = whole, Show = shown, Keywords = "kill aura" }
        )
        toggle(section, "Show Kill Aura Circle", "ShowKillAuraCircle", "KillAura")
    end
    if hitbox then
        toggle(section, "Hitbox Expander", "KillerHitbox", nil, "hbe killer")
        slider(section, "Hitbox Size (Studs)", "KillerHitboxSize", 1, 3000, 1, whole, "KillerHitbox")
        toggle(section, "Show Hitbox Visualizer", "KillerHitboxVisualizer", "KillerHitbox")
        local drawn = both("KillerHitbox", "KillerHitboxVisualizer")
        section:pair(
            { Type = "Color", Name = "Box Fill Color", Flag = "KillerHitboxFillColor", Default = D.KillerHitboxFillColor, Show = drawn },
            { Type = "Color", Name = "Outline Color", Flag = "KillerHitboxLineColor", Default = D.KillerHitboxLineColor, Show = drawn }
        )
        section:pair(
            { Type = "Slider", Name = "Fill Trans", Flag = "KillerHitboxFillTransparency", Min = 0, Max = 1, Step = 0.05, Default = D.KillerHitboxFillTransparency, Show = drawn },
            { Type = "Slider", Name = "Outline Trans", Flag = "KillerHitboxLineTransparency", Min = 0, Max = 1, Step = 0.05, Default = D.KillerHitboxLineTransparency, Show = drawn }
        )
    end
    header(section, "Bullets")
    toggle(section, "Custom Bullet Travel Time", "CustomBulletTravel")
    slider(section, "Bullet Travel Time (0 = Instant)", "BulletTravelTime", 0, 30, 0.05, seconds, "CustomBulletTravel")
    toggle(section, "Instant Hit Report", "InstantHit", "CustomBulletTravel")
    toggle(section, "Extended Projectile Range", "ExtendedProjectileRange")
    slider(section, "Projectile Range Multiplier", "ProjectileRangeMultiplier", 1, 20, 1, whole, "ExtendedProjectileRange")
    toggle(section, "Custom Shotgun Pellets", "CustomPelletCount", nil, "pellet count")
    slider(section, "Shotgun Pellets Per Shot", "PelletCount", 1, 50, 1, whole, "CustomPelletCount")
end

local gunStatus = "Select up to two guns"

local PICK_ROW = 34
local PICK_SLOTS = 40
local PLAYER_SLOTS = 32

local function gunRow(index: number): any
    return {
        Type = "Custom",
        Height = PICK_ROW,
        Show = function()
            return #Classic.available() >= index
        end,
        Render = function(kit: any, app: any)
            local name = Classic.available()[index]
            if not name then
                return
            end
            local pal = app.Pal
            local slot = table.find(Classic.pickedGuns(), name)
            local key = "saktk51:gun:" .. index
            local hover = if kit:hovered(key) then 0.14 else 0
            local width, height = kit.Width, PICK_ROW - 2
            kit:rect(0, 1, width, height, Color3.new(pal.Panel.R, pal.Panel.G, pal.Panel.B):Lerp(pal.Accent, if slot then 0.2 else hover), 1, 12)
            local picture = Portraits.image(name)
            local iconW, iconH = 34, height - 8
            kit:rect(8, 5, iconW, iconH, pal.Off, 1, 8)
            if picture then
                kit:image(picture, 8, 5, iconW, iconH, 8)
            end
            kit:text(name, 48, 1 + height / 2, 12, if slot then pal.Text else pal.Sub, false, true)
            local box = 16
            local bx, by = width - box - 10, 1 + (height - box) / 2
            if slot then
                kit:rect(bx, by, box, box, pal.Accent, 1, 6)
            else
                kit:border(bx, by, box, box, 6, pal.Sub, 0.7, 1.5)
            end
            kit:hit(key, 0, 1, width, height, function()
                Classic.togglePicked(name)
            end)
        end,
    }
end

local function playerRow(index: number): any
    return {
        Type = "Custom",
        Height = PICK_ROW,
        Show = function(window: any)
            return window:get("KillSpecified") == true and #KillAll.players() >= index
        end,
        Render = function(kit: any, app: any)
            local name = KillAll.players()[index]
            if not name then
                return
            end
            local pal = app.Pal
            local selected = table.find(KillAll.picked(), name) ~= nil
            local key = "saktk51:target:" .. index
            local hover = if kit:hovered(key) then 0.14 else 0
            local width, height = kit.Width, PICK_ROW - 2
            kit:rect(0, 1, width, height, Color3.new(pal.Panel.R, pal.Panel.G, pal.Panel.B):Lerp(pal.Accent, if selected then 0.2 else hover), 1, 12)
            local status = KillAll.status(name)
            local side = height - 8
            kit:rect(8, 5, side, side, pal.Off, 1, side / 2)
            local picture = KillAll.avatar(name)
            if picture then
                kit:image(picture, 8, 5, side, side, side / 2)
            end
            kit:text(name, 8 + side + 10, 1 + height / 2, 12, if selected then pal.Text else pal.Sub, false, true)
            local box = 16
            local bx, by = width - box - 10, 1 + (height - box) / 2
            if status then
                kit:text(status, bx - 8 - kit:measure(status, 11), 1 + height / 2, 11, pal.Sub, false, true)
            end
            if selected then
                kit:rect(bx, by, box, box, pal.Accent, 1, 6)
            else
                kit:border(bx, by, box, box, 6, pal.Sub, 0.7, 1.5)
            end
            kit:hit(key, 0, 1, width, height, function()
                KillAll.togglePlayer(name)
            end)
        end,
    }
end

local function notPlaying(): boolean
    return not KillAll.playing()
end

local function killControls(section: any)
    header(section, "Kill")
    section:toggle({ Name = "Kill All", Flag = "KillAll", Default = D.KillAll, Disabled = notPlaying })
    section:toggle({ Name = "Kill Specified", Flag = "KillSpecified", Default = D.KillSpecified, Disabled = notPlaying, Keywords = "players targets" })
    for index = 1, PLAYER_SLOTS, 2 do
        local left, right = playerRow(index), playerRow(index + 1)
        left.NoStack, right.NoStack = true, true
        section:pair(left, right)
    end
    section:button({ Name = "Clear Selection", Callback = KillAll.clearPicked, Show = on("KillSpecified") })
end

local function killers(ui: any, actions: Actions)
    local section = ui:tab("Killers"):section("KILLERS")
    header(section, "Killer Reroll")
    section:pair(
        { Type = "Button", Name = "Reset Character Until...", Callback = actions.pick },
        {
            Type = "Button",
            Name = "Cancel",
            Disabled = function()
                return not Reroll.active()
            end,
            Callback = function()
                Reroll.stop("Reroll cancelled.")
            end,
        }
    )
    section:label({ Label = Reroll.status, Height = 26, Size = 11, Accent = true, Boxed = true })
    killControls(section)
    Portraits.preload(Config.KILLERS)
    return section
end

local function juggernaut(ui: any)
    local section = ui:tab("Juggernaut"):section("JUGGERNAUT")
    killControls(section)
    return section
end

local function armory(section: any)
    Portraits.prepare()
    local every = Modes.Current == "Killer Mode" or Modes.Current == "Classic"
    section:label({
        Height = 28,
        Size = 12,
        Offset = 4,
        Label = function()
            local count = #Classic.available()
            if count == 0 then
                return "No guns right now, it is intermission"
            end
            if every then
                return "Guns on the map (" .. #Classic.pickedGuns() .. " selected)"
            end
            return "Guns on the map (" .. #Classic.pickedGuns() .. "/2 selected)"
        end,
    })
    for index = 1, PICK_SLOTS, 2 do
        local left, right = gunRow(index), gunRow(index + 1)
        left.NoStack, right.NoStack = true, true
        section:pair(left, right)
    end
    local function stocked(): boolean
        return #Classic.available() > 0
    end
    section:label({ Label = function()
        return gunStatus
    end, Height = 26, Size = 11, Accent = true, Boxed = true, Show = stocked })
    local function take()
        Classic.takePicked(function(text: string)
            gunStatus = text
        end)
    end
    if every then
        section:pair({ Type = "Button", Name = "Take Selected Guns", Callback = take, Show = stocked }, {
            Type = "Button",
            Name = "Take All Guns",
            Show = stocked,
            Callback = function()
                Classic.takeAll(function(text: string)
                    gunStatus = text
                end)
            end,
        })
    else
        section:button({ Name = "Take Selected Guns", Callback = take, Show = stocked })
    end
end

local function espRow(name: string, prefix: string, label: string, arrowsNeedEsp: boolean?, health: boolean?): any
    local esp = "Visual" .. prefix .. "ESP"
    return {
        Name = name,
        Cells = {
            { Flag = esp, Name = label .. " ESP", Default = D[esp] },
            { Flag = "Visual" .. prefix .. "Tracers", Name = label .. " Tracers", Default = D["Visual" .. prefix .. "Tracers"], Requires = esp },
            { Flag = "Visual" .. prefix .. "Offscreen", Name = label .. " Offscreen Arrows", Default = D["Visual" .. prefix .. "Offscreen"], Requires = if arrowsNeedEsp then esp else nil },
            if health == false then nil else { Flag = "Visual" .. prefix .. "ShowHealth", Name = label .. " Show Health", Default = D["Visual" .. prefix .. "ShowHealth"], Requires = esp },
            { Flag = "Visual" .. prefix .. "ShowDistance", Name = label .. " Show Distance", Default = D["Visual" .. prefix .. "ShowDistance"], Requires = esp },
        },
    }
end

local function chip(name: string, flag: string, short: string?, requires: any?): any
    return { Name = name, Short = short, Flag = flag, Default = D[flag], Requires = requires }
end

local MAP_FLAGS = { "VisualLandmarkESP", "VisualSecretAreaESP", "VisualPackAPunchESP", "VisualInteractableESP", "VisualSurveillanceESP" }

local function esp(section: any, hunting: boolean)
    local rows: { any } = {}
    if not bossRush() then
        table.insert(rows, espRow("NPCs", "NPC", "NPC / Monster"))
        if hunting then
            table.insert(rows, espRow("Killers", "Killer", "Killers / Infected"))
        end
    end
    if not Modes.storming() then
        table.insert(rows, espRow("Survivors", "Survivor", "Survivors / Players"))
    end
    if bossRush() then
        table.insert(rows, espRow("Boss", "Boss", "Boss"))
    else
        table.insert(rows, espRow("Weapons", "Weapon", "Weapon", true, false))
    end
    header(section, "Characters")
    section:matrix({ Columns = { "ESP", "Tracers", "Arrows", "Health", "Distance" }, Rows = rows })

    if not hunting and not bossRush() then
        local classic = Modes.Current == "Classic"
        local endless = Modes.Current == "Endless"
        local items: { any } = {}
        if classic then
            table.insert(items, chip("Keycards ESP", "VisualKeycardESP", "Keycards"))
            table.insert(items, chip("Papers ESP", "VisualPaperESP", "Papers"))
        end
        table.insert(items, chip("Important Room Markers", "VisualLandmarkESP", "Rooms"))
        if classic then
            table.insert(items, chip("Secret Area Markers", "VisualSecretAreaESP", "Secret Areas"))
            table.insert(items, chip("Facility Objective Markers", "VisualFacilityObjectiveESP", "Objectives"))
        end
        table.insert(items, chip("Pack a Punch ESP", "VisualPackAPunchESP", "Pack a Punch"))
        table.insert(items, chip("Interactables ESP", "VisualInteractableESP", "Interactables"))
        if not endless then
            table.insert(items, chip("Surveillance Cameras ESP", "VisualSurveillanceESP", "Cameras"))
        end
        if endless then
            table.insert(items, chip("Perks ESP", "VisualEndlessPerksESP", "Perks"))
            table.insert(items, chip("Traps ESP", "VisualTrapESP", "Traps"))
            table.insert(items, chip("Mystery Box ESP", "VisualMysteryBoxESP", "Mystery Box"))
        end
        if classic then
            table.insert(items, chip("Pickup Show Distance", "VisualPickupShowDistance", "Pickup Distance", { "VisualKeycardESP", "VisualPaperESP" }))
        end
        table.insert(items, chip("Map Show Distance", "VisualMapShowDistance", "Map Distance", MAP_FLAGS))
        if classic then
            table.insert(items, chip("Show Marker Distance", "VisualFacilityShowDistance", "Objective Distance", "VisualFacilityObjectiveESP"))
        end
        if endless then
            table.insert(items, chip("Endless Show Distance", "VisualEndlessShowDistance", "Endless Distance", { "VisualEndlessPerksESP", "VisualTrapESP", "VisualMysteryBoxESP" }))
        end
        header(section, "Map")
        section:chips({ Items = items })
    end

end

local function look(section: any)
    local look = section:advanced("Look and Colors")
    look:dropdown({ Name = "Visualizer Mode", Flag = "VisualMode", Values = Config.VISUAL_MODES, Default = D.VisualMode })
    look:toggle({ Name = "ESP Through Walls", Flag = "VisualThroughWalls", Default = D.VisualThroughWalls })
    local function lookSlider(name: string, flag: string, min: number, max: number, step: number, format: ((number) -> string)?)
        look:slider({ Name = name, Flag = flag, Min = min, Max = max, Step = step, Default = D[flag], Format = format })
    end
    lookSlider("Text Size (Px)", "ESPTextSize", 9, 22, 1, whole)
    lookSlider("Box Thickness (Px)", "VisualBoxThickness", 1, 5, 0.5)
    lookSlider("Box Transparency", "VisualHighlightOutlineTransparency", 0, 1, 0.05)
    lookSlider("Fill Transparency", "VisualHighlightFillTransparency", 0, 1, 0.05)
    lookSlider("Tracer Thickness (Px)", "VisualTracerThickness", 1, 5, 0.5)
    lookSlider("Tracer Transparency", "VisualTracerTransparency", 0, 1, 0.05)
    lookSlider("Offscreen Arrow Size", "VisualOffscreenArrowSize", 10, 40, 1, whole)
    lookSlider("Label Background Transparency", "VisualLabelBackgroundTransparency", 0, 1, 0.05)
    lookSlider("Label Height (Studs)", "VisualBillboardOffset", 0, 8, 0.1)
    look:pair(
        { Type = "Color", Name = "Tracer Color", Flag = "ColorTracer", Default = D.ColorTracer },
        { Type = "Color", Name = "Background Color", Flag = "ColorBackground", Default = D.ColorBackground }
    )
    look:pair(
        { Type = "Color", Name = "Text Color", Flag = "ColorText", Default = D.ColorText },
        { Type = "Color", Name = "Box Color", Flag = "ColorBox", Default = D.ColorBox }
    )
end

local function visuals(section: any, hunting: boolean)
    if not bossRush() then
        header(section, "HUD")
        toggle(section, "Nearest Weapons HUD", "VisualNearestWeaponHUD")
        section:pair(
            { Type = "Toggle", Name = "Show Coordinates", Flag = "VisualWeaponHUDCoordinates", Default = D.VisualWeaponHUDCoordinates, Show = on("VisualNearestWeaponHUD"), Keywords = "hud" },
            { Type = "Slider", Name = "Weapons Listed", Flag = "VisualWeaponHUDCount", Min = 1, Max = 12, Step = 1, Default = D.VisualWeaponHUDCount, Format = whole, Show = on("VisualNearestWeaponHUD"), Keywords = "hud" }
        )
        toggle(section, "Alive Enemies HUD", "AliveHUD")
        slider(section, "Alive Enemies Listed", "AliveHUDCount", 1, 15, 1, whole, "AliveHUD")
        if Modes.Current == "Endless" then
            toggle(section, "Round Info HUD", "RoundHUD")
        end
        if Modes.facility() then
            toggle(section, "Killer Proximity Warning", "VisualKillerWarning")
            slider(section, "Warning Distance (Studs)", "KillerWarningRange", 20, 300, 10, whole, "VisualKillerWarning")
        end
        if Modes.Current == "Classic" then
            header(section, "Facility Codes")
            section:chips({ Items = {
                chip("Alien Keypad Code HUD", "VisualAlienCodeHUD", "Alien Keypad"),
                chip("Cleaner Combination HUD", "VisualCleanerHUD", "Cleaner Combination"),
                chip("Sewer Vault Code HUD", "VisualVaultScreenHUD", "Sewer Vault"),
            } })
        end
    end
    header(section, "Screen")
    local items = {
        chip("Fullbright", "Fullbright"),
        chip("Remove Fog / Atmosphere", "RemoveFog", "No Fog"),
        chip("No Global Shadows", "VisualNoShadows", "No Shadows"),
        chip("Remove Bullets (Client Side)", "RemoveBullets", "No Bullets"),
        chip("Remove Ammo Clips (Client Side)", "RemoveClips", "No Ammo Clips"),
        chip("Mute Gun Sounds (Client Side)", "MuteGunSounds", "Mute Guns"),
    }
    if hunting or Modes.facility() then
        table.insert(items, chip("Remove Ink Screen (Eyeless Jack)", if hunting then "NoInk" else "RemoveInk", "No Ink Screen"))
        table.insert(items, chip("Remove Tails Doll Image", "RemoveTailsPopup", "No Tails Doll"))
    end
    section:chips({ Items = items })
end

local function player(ui: any, hunting: boolean)
    local section = ui:tab("Player"):section("PLAYER")
    if bossRush() then
        header(section, "Boss Rush")
        if Modes.bossName() == "Kraken" then
            toggle(section, "Boss Attack Immunity (Kraken)", "BossImmunity")
        end
        toggle(section, "Unlock Camera", "UnlockCamera")
        toggle(section, "Custom Walk Speed", "CustomWalkSpeed")
        slider(section, "Walk Speed", "WalkSpeedValue", 16, 100, 1, whole, "CustomWalkSpeed")
        return
    end
    header(section, "Movement")
    twin(section, { "Door Noclip", "DoorNoclip" }, { "Anti Trip", "NoTrip" })
    toggle(section, "Survivor Fly Mode", "Fly")
    slider(section, "Fly Speed", "FlySpeed", 15, 150, 5, whole, "Fly")
    if hunting or Modes.Current == "Endless" then
        return
    end
    if Modes.facility() then
        header(section, "Automation")
        toggle(section, "Auto Open Doors", "ClassicAutoDoors")
        slider(section, "Door Open Distance", "AutoOpenDoorRange", 4, 20, 1, whole, "ClassicAutoDoors")
        twin(section, { "Block Teleports", "NoForcedTeleport", "forced teleport" }, { "Auto Collect Keycards", "AutoCollectKeycards" })
    elseif Modes.storming() then
        header(section, "Pickups")
        local status = "Picks up every gun in the map"
        section:button({
            Name = "Get All Guns",
            Callback = function()
                Movement.getAllGuns(function(text: string)
                    status = text
                end)
            end,
        })
        section:label({ Label = function(): string
            return status
        end, Height = 24, Size = 11.5, Offset = 2 })
    end
end

local function auto(ui: any)
    local section = ui:tab("Auto"):section("AUTO")
    header(section, "Survival")
    twin(section, { "Trap Immunity", "TrapImmunity" }, { "Auto Revive Teammates", "AutoRevive" })
    twin(section, { "Auto Replank", "AutoReplank" }, { "Auto Interact", "AutoInteract" })
    header(section, "Doors")
    toggle(section, "Auto Open Doors", "AutoOpenDoors")
    slider(section, "Door Open Distance", "AutoOpenDoorRange", 4, 20, 1, whole, "AutoOpenDoors")
    header(section, "Auto Buy")
    section:chips({ Items = {
        chip("Auto Buy Perks", "AutoBuyPerks", "Perks"),
        chip("Auto Buy Mystery Box", "AutoBuyMysteryBox", "Mystery Box"),
        chip("Auto Buy Guns", "AutoBuyGuns", "Guns"),
    } })
end

local function home(ui: any, hunting: boolean)
    local seen = if bossRush() then "VisualBossESP" elseif hunting then "VisualKillerESP" else "VisualNPCESP"
    local seenTitle = if bossRush() then "Boss ESP" elseif hunting then "Killer ESP" else "NPC ESP"
    ui:home({
        QuickLabel = "Quick Settings",
        QuickStart = {
            { Title = "Silent Aim", Icon = "crosshair", Flag = "SilentAim" },
            { Title = "Infinite Ammo", Icon = "zap", Flag = "InfAmmo" },
            { Title = seenTitle, Icon = "eye", Flag = seen },
            { Title = "No Recoil", Icon = "target", Flag = "NoRecoil" },
        },
    })
end

local function changelog(ui: any)
    ui:updates({ Version = Changelog.VERSION, Date = Changelog.DATE, Groups = Changelog.GROUPS, History = Changelog.HISTORY, Closing = Changelog.CLOSING })
end

function Interface.build(ui: any, actions: Actions)
    local hunting = Modes.canReroll()
    local lobby = Modes.Current == "Lobby"
    local killAura = not lobby and (hunting or Modes.Current == "Endless" or Modes.facility() or Modes.storming() or bossRush())
    local hitbox = not bossRush() and not lobby
    home(ui, hunting)
    guns(ui)
    aim(ui, actions, killAura, hitbox)
    if hunting then
        armory(killers(ui, actions))
    elseif Modes.Current == "Juggernaut" then
        armory(juggernaut(ui))
    elseif Modes.Current == "Classic" then
        armory(ui:tab("Armory"):section("ARMORY"))
    end
    local page = ui:tab("Visuals"):section("VISUALS")
    esp(page, hunting)
    visuals(page, hunting)
    look(page)
    if not lobby then
        player(ui, hunting)
        if Modes.Current == "Endless" then
            auto(ui)
        end
    end
    changelog(ui)
end

return Interface
end
modules["killall"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")
local Targets: typeof(require("./targets")) = import("targets")

local KillAll = {}

local touch: any = firetouchinterest

local FIND_INTERVAL = 5
local IDLE_WAIT = 0.2
local SWING_DISTANCE = 2
local MIN_SPAM, MAX_SPAM = 0.05, 0.25
local MAX_STAY = 10
local SIDES = 8
local SPIN_SPEED = 3.5
local GROUND_DEPTH = 8
local BODY_PARTS = { "HumanoidRootPart", "Torso", "UpperTorso" }

local running = false
local picked: { string } = {}
local listed: { string } = {}
local listedAt = -10
local lastFind = 0
local cached: any = nil
local cachedFor: any = nil

local function myKiller(): any
    local character = Context.LocalPlayer.Character
    if character and Targets.isKiller(character) and Targets.alive(character) then
        return character
    end
    return nil
end

function KillAll.playing(): boolean
    return myKiller() ~= nil
end

local function findObject(character: any): any
    if cachedFor == character and cached and rawget(cached, "model") == character then
        return cached
    end
    local fresh = cachedFor ~= character
    cached, cachedFor = nil, character
    local now = os.clock()
    if not fresh and now - lastFind < FIND_INTERVAL then
        return nil
    end
    lastFind = now
    local ok, objects = pcall(getgc, true)
    if not ok or type(objects) ~= "table" then
        return nil
    end
    for _, object in objects do
        if type(object) == "table" and rawget(object, "model") == character and rawget(object, "attacking") ~= nil then
            cached = object
            return object
        end
    end
    return nil
end

local function spamInterval(): number
    local ok, ping = pcall(function()
        return Context.LocalPlayer:GetNetworkPing()
    end)
    return math.clamp((if ok then ping else 0.1) * 2, MIN_SPAM, MAX_SPAM)
end

local function active(): boolean
    return Context.S.KillAll == true or Context.S.KillSpecified == true
end

local function gone(model: any): boolean
    local killers, survivors = Context.folder("Killers"), Context.folder("Characters to kill")
    if not killers and not survivors then
        return false
    end
    local parent = model.Parent
    return parent == nil or (parent ~= killers and parent ~= survivors)
end

function KillAll.players(): { string }
    local now = os.clock()
    if now - listedAt > 0.5 then
        listedAt = now
        local names: { string } = {}
        for _, player in Context.Players:GetPlayers() do
            if player ~= Context.LocalPlayer then
                table.insert(names, player.Name)
            end
        end
        table.sort(names, function(a: string, b: string): boolean
            return string.lower(a) < string.lower(b)
        end)
        listed = names
    end
    return listed
end

function KillAll.status(name: string): string?
    local player = Context.Players:FindFirstChild(name)
    local character = player and (player :: any).Character
    if not character or gone(character) or not Targets.alive(character) then
        return "Dead"
    end
    if Targets.isKiller(character) then
        return "Killer"
    end
    return nil
end

function KillAll.avatar(name: string): string?
    local player: any = Context.Players:FindFirstChild(name)
    if not player then
        return nil
    end
    return "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=100&h=100"
end

function KillAll.picked(): { string }
    for index = #picked, 1, -1 do
        if not Context.Players:FindFirstChild(picked[index]) then
            table.remove(picked, index)
        end
    end
    return picked
end

function KillAll.togglePlayer(name: string)
    local at = table.find(picked, name)
    if at then
        table.remove(picked, at)
    else
        table.insert(picked, name)
    end
end

function KillAll.clearPicked()
    table.clear(picked)
end

local function victims(root: any): { any }
    local list: { any } = {}
    local chosen = KillAll.picked()
    for _, model in Targets.enemies() do
        local player = Context.Players:GetPlayerFromCharacter(model)
        local allowed = true
        if player and gone(model) then
            allowed = false
        end
        if not Context.S.KillAll and (not player or not table.find(chosen, player.Name)) then
            allowed = false
        end
        if allowed and Context.root(model) and not Targets.shielded(model) then
            table.insert(list, model)
        end
    end
    table.sort(list, function(a: any, b: any): boolean
        return (Context.root(a).Position - root.Position).Magnitude < (Context.root(b).Position - root.Position).Magnitude
    end)
    return list
end

local function swing(character: any, object: any, victim: any, attack: boolean)
    if attack and object then
        pcall(function()
            local flag = rawget(object, "attacking")
            if flag then
                flag.Value = false
            end
            object:attack()
        end)
    end
    local tool = character:FindFirstChildOfClass("Tool")
    local handle = tool and tool:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then
        for _, name in BODY_PARTS do
            local body = victim:FindFirstChild(name)
            if body and body:IsA("BasePart") then
                pcall(function()
                    touch(handle, body, 0)
                    touch(handle, body, 1)
                end)
            end
        end
    end
end

local function standPoint(character: any, victim: any, target: any, angle: number): (Vector3, number)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character, victim }
    params.RespectCanCollide = true
    local origin = target.Position
    for step = 0, SIDES - 1 do
        local used = angle + step / SIDES * math.pi * 2
        local spot = origin + Vector3.new(math.cos(used), 0, math.sin(used)) * SWING_DISTANCE
        if not workspace:Raycast(origin, spot - origin, params) and workspace:Raycast(spot, Vector3.new(0, -GROUND_DEPTH, 0), params) then
            return spot, used
        end
    end
    return origin, angle
end

local function dead(victim: any): boolean
    local humanoid = victim.Parent and victim:FindFirstChildOfClass("Humanoid")
    return not humanoid or humanoid.Health <= 0
end

local function strike(character: any, root: any, victim: any, object: any)
    local interval = spamInterval()
    local started = os.clock()
    local lastAttack = 0
    local angle = 0
    local last = os.clock()
    while active() and character.Parent and root.Parent and Targets.alive(character) and not dead(victim) and not Targets.shielded(victim) and os.clock() - started < MAX_STAY do
        local target = Context.root(victim)
        if not target then
            return
        end
        local spot
        local now = os.clock()
        angle += (now - last) * SPIN_SPEED
        last = now
        spot, angle = standPoint(character, victim, target, angle)
        root.CFrame = CFrame.lookAt(spot, Vector3.new(target.Position.X, spot.Y, target.Position.Z))
        root.AssemblyLinearVelocity = Vector3.zero
        local attack = now - lastAttack >= interval
        if attack then
            lastAttack = now
        end
        swing(character, object, victim, attack)
        Context.RunService.Heartbeat:Wait()
    end
end

local function cycle(): boolean
    local character = myKiller()
    local root = character and Context.root(character)
    if not character or not root then
        return false
    end
    local list = victims(root)
    if #list == 0 then
        return false
    end
    local home = root.CFrame
    for _, victim in list do
        if not active() or not root.Parent or not Targets.alive(character) then
            break
        end
        pcall(strike, character, root, victim, findObject(character))
    end
    if root.Parent and Targets.alive(character) then
        root.CFrame = home
        root.AssemblyLinearVelocity = Vector3.zero
    end
    return true
end

local function loop()
    while Context.Running and active() do
        local ok, worked = pcall(cycle)
        if ok and worked then
            Context.RunService.Heartbeat:Wait()
        else
            task.wait(IDLE_WAIT)
        end
    end
    running = false
end

function KillAll.step()
    if running or not active() then
        return
    end
    running = true
    task.spawn(function()
        pcall(loop)
        running = false
    end)
end

function KillAll.stop()
    cached, cachedFor = nil, nil
end

return KillAll
end
modules["killerhitbox"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")
local Debug: typeof(require("./debug")) = import("debug")
local Targets: typeof(require("./targets")) = import("targets")
local Visual: typeof(require("./visual")) = import("visual")

local KillerHitbox = {}

local touch: any = firetouchinterest

local SCAN_INTERVAL = 0.25
local TOUCH_INTERVAL = 0.12
local MIN_SIZE, MAX_SIZE = 1, 3000
local LINE_WIDTH = 1.5

type Entry = { Size: Vector3, CanCollide: boolean }

local entries: { [any]: Entry } = {}
local active: { [any]: boolean } = {}
local last = 0
local lastTouch = 0

local function friendly(model: any): boolean
    return not model or not Targets.hostile(model)
end

local function targetPart(model: any): any
    if not model or not model:IsA("Model") then
        return nil
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return nil
    end
    local root = model:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") and root.Transparency >= 0.5 then
        return root
    end
    Debug.count("hitboxSkipped", model.Name)
    return nil
end

local function weaponHandle(): any
    local character = Context.LocalPlayer.Character
    local killers = Context.folder("Killers")
    if not character or not killers or character.Parent ~= killers then
        return nil
    end
    local tool = character:FindFirstChildOfClass("Tool")
    local handle = tool and tool:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then
        return handle
    end
    for _, name in { "RightHand", "Right Arm", "RightLowerArm" } do
        local limb = character:FindFirstChild(name)
        if limb and limb:IsA("BasePart") then
            return limb
        end
    end
    return nil
end

local function strike(edge: number)
    local now = os.clock()
    if now - lastTouch < TOUCH_INTERVAL or not Context.UserInput:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        return
    end
    lastTouch = now
    local handle = weaponHandle()
    local root = Context.root(Context.LocalPlayer.Character)
    if not handle or not root then
        return
    end
    local reach = edge * 0.87
    for part in entries do
        if part.Parent and (part.Position - root.Position).Magnitude <= reach then
            pcall(function()
                touch(handle, part, 0)
                touch(handle, part, 1)
            end)
        end
    end
end

function KillerHitbox.restore()
    for part, entry in entries do
        if part.Parent then
            pcall(function()
                part.Size = entry.Size
                part.CanCollide = entry.CanCollide
            end)
        end
    end
    table.clear(entries)
    table.clear(active)
end

local function consider(model: any, size: Vector3, seen: { [any]: boolean })
    if not model or not model:IsA("Model") or not model:IsDescendantOf(Context.Workspace) or seen[model] then
        return
    end
    seen[model] = true
    if friendly(model) then
        return
    end
    local part = targetPart(model)
    if not part then
        return
    end
    active[part] = true
    if not entries[part] then
        entries[part] = { Size = part.Size, CanCollide = part.CanCollide }
    end
    pcall(function()
        part.Size = size
        part.CanCollide = false
        part.CanTouch = true
        part.CanQuery = true
    end)
end

function KillerHitbox.step()
    local settings = Context.S
    if not settings.KillerHitbox then
        if next(entries) ~= nil then
            KillerHitbox.restore()
        end
        return
    end
    local edge = math.clamp(tonumber(settings.KillerHitboxSize) or 15, MIN_SIZE, MAX_SIZE)
    local size = Vector3.new(edge, edge, edge)
    strike(edge)
    local now = os.clock()
    if now - last < SCAN_INTERVAL then
        for part in entries do
            if part.Parent and part.Size ~= size then
                pcall(function()
                    part.Size = size
                    part.CanCollide = false
                end)
            end
        end
        return
    end
    last = now
    table.clear(active)
    local seen: { [any]: boolean } = {}
    for _, model in Targets.killers() do
        consider(model, size, seen)
    end
    for _, player in Context.Players:GetPlayers() do
        if player ~= Context.LocalPlayer then
            consider(player.Character, size, seen)
        end
    end
    for part, entry in entries do
        if not active[part] or not part.Parent then
            if part.Parent then
                pcall(function()
                    part.Size = entry.Size
                    part.CanCollide = entry.CanCollide
                end)
            end
            entries[part] = nil
        end
    end
end

function KillerHitbox.draw(canvas: any, camera: any)
    local settings = Context.S
    if not settings.KillerHitbox or not settings.KillerHitboxVisualizer or not camera then
        return
    end
    local style = {
        Mode = "3D",
        FillColor = settings.KillerHitboxFillColor,
        FillTransparency = settings.KillerHitboxFillTransparency,
        LineColor = settings.KillerHitboxLineColor,
        LineTransparency = settings.KillerHitboxLineTransparency,
        LineWidth = LINE_WIDTH,
    }
    for part in entries do
        if part.Parent then
            Visual.box(canvas, camera, part, part.Size, style, nil)
        end
    end
end

return KillerHitbox
end
modules["killerpicker"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")
local Portraits: typeof(require("./portraits")) = import("portraits")
local Reroll: typeof(require("./reroll")) = import("reroll")

local KillerPicker = {}

local WIDTH, HEIGHT = 580, 434
local COLUMNS = 5
local GAP = 10
local TILE_HEIGHT = 100
local VIEW_ROWS = 3

local selection: { [string]: boolean } = {}

local function count(): number
    local total = 0
    for _, name in Config.KILLERS do
        if selection[name] then
            total += 1
        end
    end
    return total
end

local function tile(kit: any, window: any, name: string, x: number, y: number, width: number)
    local pal = window.Pal
    kit:scope("tile:" .. name)
    local key = "killerpicker:" .. name
    local picked = selection[name] == true
    local hover = kit:hovered(key)
    local height = TILE_HEIGHT - GAP
    local fill = pal.Panel:Lerp(pal.Accent, if picked then 0.2 elseif hover then 0.07 else 0)
    kit:rect(x, y, width, height, fill, 1, 12)
    if picked then
        if kit.border then
            kit:border(x, y, width, height, 12, pal.Accent, 1, 1.5)
        else
            kit:rect(x, y, width, height, pal.Accent, 0.35, 12)
        end
    end
    local picture = Portraits.image(name)
    local size = 48
    local left = x + (width - size) / 2
    kit:rect(left, y + 10, size, size, pal.Off, 1, 10)
    if picture then
        kit:image(picture, left, y + 10, size, size, 10)
    else
        local state = Portraits.state(name)
        kit:text(if state == "failed" then "?" else string.sub(name, 1, 1), left + size / 2, y + 10 + size / 2, 17, pal.Sub, true, true)
    end
    kit:text(name, x + width / 2, y + height - 17, 11, if picked then pal.Text else pal.Sub, true, true)
    if picked then
        local control, label = kit.ZControl, kit.ZText
        kit.ZControl, kit.ZText = label + 1, label + 2
        local bx, by = x + width - 25, y + 8
        kit:rect(bx, by, 17, 17, pal.Accent, 1, 9)
        kit:line(bx + 4.5, by + 8.8, bx + 7.4, by + 11.7, Color3.new(1, 1, 1), 1.7)
        kit:line(bx + 7.4, by + 11.7, bx + 12.6, by + 5.4, Color3.new(1, 1, 1), 1.7)
        kit.ZControl, kit.ZText = control, label
    end
    kit:hit(key, x, y, width, height, function()
        if picked then
            selection[name] = nil
        else
            selection[name] = true
        end
    end)
end

function KillerPicker.open(ui: any)
    Portraits.prepare()
    Portraits.retry()
    ui:openPopup("killerpicker")
end

function KillerPicker.register(ui: any)
    ui:popup("killerpicker", {
        Width = WIDTH,
        Height = HEIGHT,
        Title = "",
        Render = function(kit: any, window: any)
            local pal = window.Pal
            kit:header("Reset Character Until...", "Reroll stops as soon as ANY selected killer appears", function()
                window:closePopup()
            end)
            local rows = math.ceil(#Config.KILLERS / COLUMNS)
            kit:scroll("killerpicker:grid", 16, 62, WIDTH - 32, TILE_HEIGHT * VIEW_ROWS - GAP, TILE_HEIGHT, rows, function(row: number, x: number, y: number, rowWidth: number)
                local tileWidth = (rowWidth - (COLUMNS - 1) * GAP) / COLUMNS
                for column = 1, COLUMNS do
                    local name = Config.KILLERS[(row - 1) * COLUMNS + column]
                    if name then
                        tile(kit, window, name, x + (column - 1) * (tileWidth + GAP), y, tileWidth)
                    end
                end
            end)
            local picked = count()
            kit:text(tostring(picked) .. " selected", 20, HEIGHT - 30, 12, pal.Sub, false, true)
            kit:button("killerpicker:clear", WIDTH - 16 - 280, HEIGHT - 46, 100, 32, function()
                table.clear(selection)
            end, { label = "Clear", size = 12, rounding = 12, align = "center" })
            kit:button("killerpicker:start", WIDTH - 16 - 170, HEIGHT - 46, 170, 32, function()
                if picked > 0 then
                    Reroll.start(selection)
                    window:closePopup()
                end
            end, { label = if picked > 0 then "Start Reroll (" .. tostring(picked) .. ")" else "Select killers", size = 12, rounding = 12, active = picked > 0, align = "center" })
        end,
    })
end

return KillerPicker
end
modules["main"] = function(...)

local import: (string) -> any = ...
local AimParts: typeof(require("./aimparts")) = import("aimparts")
local ClientEffects: typeof(require("./clienteffects")) = import("clienteffects")
local Changelog: typeof(require("./changelog")) = import("changelog")
local Config: typeof(require("./config")) = import("config")
local Context: typeof(require("./context")) = import("context")
local Debug: typeof(require("./debug")) = import("debug")
local Endless: typeof(require("./endless")) = import("endless")
local Environment: typeof(require("./environment")) = import("environment")
local ESP: typeof(require("./esp")) = import("esp")
local Guns: typeof(require("./guns")) = import("guns")
local Huds: typeof(require("./huds")) = import("huds")
local Interface: typeof(require("./interface")) = import("interface")
local KillerHitbox: typeof(require("./killerhitbox")) = import("killerhitbox")
local KillAll: typeof(require("./killall")) = import("killall")
local KillerPicker: typeof(require("./killerpicker")) = import("killerpicker")
local Modes: typeof(require("./modes")) = import("modes")
local Movement: typeof(require("./movement")) = import("movement")
local Projectiles: typeof(require("./projectiles")) = import("projectiles")
local Protection: typeof(require("./protection")) = import("protection")
local Registry: typeof(require("./registry")) = import("registry")
local Reroll: typeof(require("./reroll")) = import("reroll")
local Warning: typeof(require("./warning")) = import("warning")

local REGISTRY = "__Area51SuiteStop"
local HUB_HOOK = "__BoogaOnScriptUnloaded"
local PATCH_SECONDS = 1.0

type Map = { [string]: any }

local function stopPrevious()
    local previous = getgenv()[REGISTRY]
    if type(previous) == "function" then
        pcall(previous)
    end
end

return function(OkloUI: any, reload: () -> (), Loader: any): Map?
    stopPrevious()
    Context.Running = true
    local connections: { any } = {}
    local watcher: thread? = nil
    local lastPatch = -math.huge
    local ui: any

    local function stop()
        if not Context.Running then
            return
        end
        Context.Running = false
        getgenv()[REGISTRY] = nil
        for _, link in connections do
            pcall(function()
                link:Disconnect()
            end)
        end
        table.clear(connections)
        if watcher then
            pcall(task.cancel, watcher)
        end
        pcall(Guns.restore)
        pcall(Protection.stop)
        pcall(Projectiles.stop)
        pcall(ClientEffects.stop)
        pcall(Movement.stop)
        pcall(ESP.hideAll)
        pcall(Registry.stop)
        pcall(Environment.stop)
        pcall(Endless.stop)
        pcall(KillerHitbox.restore)
        pcall(KillAll.stop)
        pcall(Huds.closeAll)
        Reroll.stop("")
        local hook = getgenv()[HUB_HOOK]
        if type(hook) == "function" then
            pcall(hook, "SAKTK51")
        end
    end

    ui = OkloUI.new({
        Title = "oklo: SAKTK51",
        Subtitle = "Area 51",
        Version = Changelog.VERSION,
        Changelog = Changelog,
        Id = "SAKTK51",
        Folder = "oklo scripts/saktk51",
        Footer = "oklo",
        Discord = "https://discord.gg/oklo",
        FirstRunInvite = true,
        Thanks = true,
        Watermark = true,
        Logo = { Emblem = true },
        Width = 760,
        Height = 500,
        QuietBinds = true,
        Theme = "Winter Frost",
        BoldTitles = true,
        Status = function(): string?
            local boss = if Modes.Current == "Boss Rush" then Modes.bossName() else nil
            return "Instance: " .. Modes.Current .. if boss then ": " .. boss else ""
        end,
        OnUnload = stop,
        OnReload = reload,
    })

    Modes.refresh()
    Interface.build(ui, {
        pick = function()
            KillerPicker.open(ui)
        end,
        chooseAimParts = function()
            AimParts.open(ui)
        end,
    })
    KillerPicker.register(ui)
    AimParts.register(ui)
    Huds.register(ui)
    Warning.register(ui, OkloUI.Fonts)

    Config.refresh(ui, Context.S)

    local function frame()
        if not Context.Running then
            return
        end
        Config.refresh(ui, Context.S)
        local now = os.clock()
        if now - lastPatch >= PATCH_SECONDS then
            lastPatch = now
            pcall(Guns.patch)
        end
        pcall(Guns.update)
        pcall(Debug.tick)
        pcall(Protection.step)
        pcall(Registry.tick)
        pcall(KillerHitbox.step)
        pcall(KillAll.step)
        pcall(Environment.tick)
        pcall(Endless.step)
        local camera = Context.camera()
        if camera then
            pcall(Huds.update, camera.CFrame.Position)
        end
    end

    table.insert(connections, Context.RunService.RenderStepped:Connect(frame))
    table.insert(connections, Context.RunService.Stepped:Connect(Movement.stepped))
    table.insert(connections, Context.RunService.Heartbeat:Connect(Movement.heartbeat))

    ui:onFrame(function(info: Map)
        local canvas = info.Canvas
        local camera = info.Camera
        ESP.frame(canvas, camera)
        KillerHitbox.draw(canvas, camera)
        Guns.drawFov(canvas)
    end)

    Registry.start()
    Environment.start()
    Protection.start()
    Projectiles.start()
    ClientEffects.start()
    Movement.start()
    watcher = Reroll.watch()
    ui:start()
    task.delay(0.5, function()
        if Context.Running then
            pcall(function()
                ui.Window.State.UIFont = tostring(OkloUI.Fonts.find("Gotham Medium"))
            end)
        end
    end)
    Warning.show(ui)
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
modules["modes"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")
local Context: typeof(require("./context")) = import("context")

local Modes = {}

local KILLER_SET: { [string]: boolean } = {}
for _, name in Config.KILLERS do
    KILLER_SET[name] = true
end
for _, name in Config.INTERNAL_KILLERS do
    KILLER_SET[name] = true
end

local PLACE_ID = 1556154

local PLACE_MODES: { [number]: string } = {
    [155382109] = "Lobby",
    [1076129670] = "Infection Mode",
    [2092166489] = "Classic",
    [3182083477] = "Classic",
    [5740483929] = "Classic",
    [2092167559] = "Killer Mode",
    [2675280735] = "Endless",
    [3508248007] = "Area 51 Storming",
    [4631179692] = "Killhouse",
    [4678052190] = "Juggernaut",
    [6054929905] = "Boss Rush",
}

Modes.Current = "Detecting..."

local function normalize(name: any): string?
    if type(name) ~= "string" then
        return nil
    end
    local lowered = string.lower(name)
    local cleaned = string.gsub(lowered, "[^%w]", "")
    return cleaned
end

function Modes.resolveKiller(name: any): string?
    if type(name) ~= "string" or name == "" then
        return nil
    end
    if KILLER_SET[name] then
        return name
    end
    local wanted = normalize(name)
    if not wanted then
        return nil
    end
    local alias = Config.KILLER_ALIASES[wanted]
    if alias then
        return alias
    end
    for _, profile in Config.KILLERS do
        if normalize(profile) == wanted then
            return profile
        end
    end
    return nil
end

local function hasNamed(root: any, name: string): boolean
    if not root then
        return false
    end
    local ok, found = pcall(function()
        return root:FindFirstChild(name, true)
    end)
    return ok and found ~= nil
end

function Modes.isGame(): boolean
    if game.PlaceId == PLACE_ID then
        return true
    end
    local workspaceService = Context.Workspace
    return workspaceService:FindFirstChild("Killers") ~= nil
        or workspaceService:FindFirstChild("AREA51") ~= nil
        or workspaceService:FindFirstChild("Characters to kill") ~= nil
        or workspaceService:FindFirstChild("PACKAPUNCH") ~= nil
        or Context.ReplicatedStorage:FindFirstChild("Character Remotes") ~= nil
end

function Modes.detect(): string
    if not Modes.isGame() then
        return "Non-SAKTK Game"
    end
    local known = PLACE_MODES[game.PlaceId]
    if known then
        return known
    end
    local player = Context.LocalPlayer
    local playerScripts = player:FindFirstChild("PlayerScripts")
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    local starterPlayer = game:GetService("StarterPlayer")
    local starterScripts = starterPlayer and starterPlayer:FindFirstChild("StarterPlayerScripts")
    local replicatedStarter = Context.ReplicatedStorage:FindFirstChild("StarterGui")
    if hasNamed(playerGui and playerGui:FindFirstChild("GameScreen"), "Kills Manager")
        or hasNamed(replicatedStarter and replicatedStarter:FindFirstChild("GameScreen"), "Kills Manager") then
        return "Killer Mode"
    end
    if (playerScripts and playerScripts:FindFirstChild("LocalDeathRagdoll")) or (starterScripts and starterScripts:FindFirstChild("LocalDeathRagdoll")) then
        return "Juggernaut"
    end
    local workspaceService = Context.Workspace
    if workspaceService:FindFirstChild("Perks") or workspaceService:FindFirstChild("Mystery Box") or workspaceService:FindFirstChild("Traps") then
        return "Endless"
    end
    if (playerScripts and playerScripts:FindFirstChild("Checks")) or (starterScripts and starterScripts:FindFirstChild("Checks")) then
        return "Infection Mode"
    end
    return "Classic"
end

function Modes.bossName(): string?
    local area = Context.folder("AREA51")
    local map = area and area:FindFirstChild("Map")
    if not map then
        return nil
    end
    if map:FindFirstChild("MakeWave") then
        return "Kraken"
    end
    if map:FindFirstChild("GrabEvent") or map:FindFirstChild("OverflowEvent") then
        return "Aberration"
    end
    return nil
end

function Modes.refresh(): boolean
    local detected = Modes.detect()
    local changed = detected ~= Modes.Current
    Modes.Current = detected
    return changed
end

function Modes.facility(mode: string?): boolean
    local current = mode or Modes.Current
    return current == "Classic" or current == "Juggernaut" or current == "Infection Mode"
end

function Modes.storming(mode: string?): boolean
    return (mode or Modes.Current) == "Area 51 Storming"
end

function Modes.canReroll(mode: string?): boolean
    local current = mode or Modes.Current
    return current == "Infection Mode" or current == "Killer Mode"
end

function Modes.currentKiller(): string?
    local character = Context.LocalPlayer.Character
    local killers = Context.Workspace:FindFirstChild("Killers")
    if character and killers and character.Parent == killers then
        return Modes.resolveKiller(character.Name)
    end
    return nil
end

function Modes.roleOf(character: any): (boolean, string?)
    if not character then
        return false, nil
    end
    local killers = Context.Workspace:FindFirstChild("Killers")
    local survivors = Context.Workspace:FindFirstChild("Characters to kill")
    local parent = character.Parent
    if killers and parent == killers then
        return true, Modes.resolveKiller(character.Name)
    end
    if survivors and parent == survivors then
        return true, nil
    end
    if parent then
        if parent.Name == "Killers" then
            return true, Modes.resolveKiller(character.Name)
        elseif parent.Name == "Characters to kill" then
            return true, nil
        end
    end
    return false, nil
end

return Modes
end
modules["movement"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")
local Modes: typeof(require("./modes")) = import("modes")
local Classic: typeof(require("./classic")) = import("classic")
local PromptWatch: typeof(require("./promptwatch")) = import("promptwatch")

local Movement = {}

local VOID_HEIGHT = -15
local FALLBACK_SPAWN = CFrame.new(245, 4, 155)
local SPAWN_DELAY = 0.25
local CARD_INTERVAL = 1.5
local CARD_NAMES: { [string]: boolean } = { Card1 = true, Card2 = true, Card3 = true, Card4 = true }

local doors: { [any]: boolean } = {}
local doorOriginals: { [any]: boolean } = {}
local doorsOn = false
local safeFrame: CFrame? = nil
local lastCards = 0
local velocity: any = nil
local gyro: any = nil
local links: { any } = {}

local function isDoorPart(object: any, folder: any): boolean
    if not object:IsA("BasePart") or not object:IsDescendantOf(folder) then
        return false
    end
    local parent = object.Parent
    return parent ~= nil and parent:IsA("Model") and parent.Name == "Door" and string.match(object.Name, "^Door%d*$") ~= nil
end

local function openDoors()
    local folder = Context.folder("Doors")
    if not folder then
        return
    end
    for _, object in folder:GetDescendants() do
        if isDoorPart(object, folder) then
            if doorOriginals[object] == nil then
                doorOriginals[object] = object.CanCollide
            end
            doors[object] = true
            pcall(function()
                object.CanCollide = false
            end)
        end
    end
end

local function closeDoors()
    for part in doors do
        if part and part.Parent then
            local original = doorOriginals[part]
            pcall(function()
                part.CanCollide = if original == nil then true else original
            end)
        end
    end
    table.clear(doors)
    table.clear(doorOriginals)
end

local function respawned(character: any)
    task.delay(SPAWN_DELAY, function()
        if character and character.Parent then
            local root = character:FindFirstChild("HumanoidRootPart")
            if root and root.Position.Y > -10 then
                safeFrame = character:GetPivot()
            end
        end
    end)
end

function Movement.getAllGuns(report: (string) -> (), only: string?)
    Classic.getAllGuns(report, only)
end

function Movement.useAbility(name: string, report: (string) -> ())
    Classic.useAbility(name, report)
end

function Movement.stepped()
    if not Context.Running then
        return
    end
    local settings = Context.S
    if settings.DoorNoclip ~= doorsOn then
        doorsOn = settings.DoorNoclip
        if doorsOn then
            openDoors()
        else
            closeDoors()
        end
    end
    local character = Context.LocalPlayer.Character
    if not character then
        return
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if doorsOn then
        for part in doors do
            if part and part.Parent and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
    if Modes.Current ~= "Non-SAKTK Game" and root and root.Position.Y < VOID_HEIGHT then
        local target = safeFrame or FALLBACK_SPAWN
        pcall(function()
            character:PivotTo(target + Vector3.new(0, 3, 0))
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end)
    end
    Classic.step()
    local now = os.clock()
    if settings.AutoCollectKeycards then
        PromptWatch.hold("cards")
        if root and now - lastCards >= CARD_INTERVAL then
            lastCards = now
            for object in PromptWatch.Set do
                local holder = object.Parent
                if not holder then
                    PromptWatch.Set[object] = nil
                elseif object.Enabled then
                    if holder:IsA("Attachment") then
                        holder = holder.Parent
                    end
                    if holder and (CARD_NAMES[holder.Name] or holder.Name == "Card") then
                        Classic.pickup(object)
                    end
                end
            end
        end
    elseif PromptWatch.holding("cards") then
        PromptWatch.release("cards")
    end
end

local function dropFly()
    if velocity then
        pcall(function()
            velocity:Destroy()
        end)
        velocity = nil
    end
    if gyro then
        pcall(function()
            gyro:Destroy()
        end)
        gyro = nil
    end
end

local DEFAULT_WALK_SPEED = 16

local function unlockCamera(character: any)
    local camera = Context.camera()
    local humanoid = Context.humanoid(character)
    if not camera or not humanoid then
        return
    end
    pcall(function()
        Context.RunService:UnbindFromRenderStep("camera")
    end)
    if camera.CameraType ~= Enum.CameraType.Custom then
        camera.CameraType = Enum.CameraType.Custom
    end
    if camera.CameraSubject ~= humanoid then
        camera.CameraSubject = humanoid
    end
end

local function boostSpeed(character: any, dt: number)
    local humanoid = Context.humanoid(character)
    local root = Context.root(character)
    if not humanoid or not root or humanoid.MoveDirection.Magnitude == 0 then
        return
    end
    local extra = Context.S.WalkSpeedValue - DEFAULT_WALK_SPEED
    if extra > 0 then
        root.CFrame += humanoid.MoveDirection.Unit * extra * dt
    end
end

function Movement.heartbeat(dt: number?)
    if not Context.Running then
        return
    end
    local settings = Context.S
    local character = Context.LocalPlayer.Character
    if character and Modes.Current == "Boss Rush" then
        if settings.UnlockCamera then
            unlockCamera(character)
        end
        if settings.CustomWalkSpeed then
            boostSpeed(character, dt or 1 / 60)
        end
    end
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local camera = Context.camera()
    if not settings.Fly or not root or not camera then
        dropFly()
        return
    end
    if not velocity or velocity.Parent ~= root then
        dropFly()
        velocity = Instance.new("BodyVelocity")
        velocity.Velocity = Vector3.new(0, 0, 0)
        velocity.MaxForce = Vector3.new(100000, 100000, 100000)
        velocity.Parent = root
        gyro = Instance.new("BodyGyro")
        gyro.MaxTorque = Vector3.new(100000, 100000, 100000)
        gyro.CFrame = root.CFrame
        gyro.Parent = root
    end
    local input = Context.UserInput
    local frame = camera.CFrame
    local move = Vector3.new(0, 0, 0)
    if not input:GetFocusedTextBox() then
        if input:IsKeyDown(Enum.KeyCode.W) then
            move += frame.LookVector
        end
        if input:IsKeyDown(Enum.KeyCode.S) then
            move -= frame.LookVector
        end
        if input:IsKeyDown(Enum.KeyCode.A) then
            move -= frame.RightVector
        end
        if input:IsKeyDown(Enum.KeyCode.D) then
            move += frame.RightVector
        end
        if input:IsKeyDown(Enum.KeyCode.Space) then
            move += Vector3.new(0, 1, 0)
        end
        if input:IsKeyDown(Enum.KeyCode.LeftControl) then
            move -= Vector3.new(0, 1, 0)
        end
    end
    velocity.Velocity = if move.Magnitude > 0 then move.Unit * settings.FlySpeed else Vector3.new(0, 0, 0)
    gyro.CFrame = frame
end

function Movement.start()
    Classic.start()
    table.insert(links, Context.LocalPlayer.CharacterAdded:Connect(respawned))
    if Context.LocalPlayer.Character then
        respawned(Context.LocalPlayer.Character)
    end
end

function Movement.stop()
    Classic.stop()
    PromptWatch.release("cards")
    for _, link in links do
        pcall(function()
            link:Disconnect()
        end)
    end
    table.clear(links)
    dropFly()
    closeDoors()
    doorsOn = false
end

return Movement
end
modules["portraits"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")

local Portraits = {}

local FOLDER = "oklo scripts/saktk51/decals"
local MAX_TRIES = 4
local RETRY_DELAY = 6
local WIKI_API = "https://saktkia51.fandom.com/api.php?action=query&format=json&redirects=1&origin=*"
local EXTENSIONS = { "png", "jpg" }
local HEADERS = { ["User-Agent"] = "Mozilla/5.0", ["Accept"] = "image/png,image/jpeg,application/json,*/*;q=0.5" }

local FILE_CANDIDATES: { [string]: { string } } = {
    ["Alien"] = { "Alien headshot icon" },
    ["Ao Oni"] = { "Ao Oni", "Ao Oni Headshot Icon" },
    ["Captain Zombie"] = { "CaptainZombieUpdatedHeadshot", "Captain Zombie" },
    ["Chucky"] = { "ChuckyNew", "Chucky" },
    ["Eyeless Jack"] = { "Eyeless Jack headshot icon", "Eyeless Jack" },
    ["Fishface"] = { "Fishface headshot icon", "Fishface" },
    ["Freddy Krueger"] = { "Freddy Krueger" },
    ["Ghostface"] = { "Scream", "Ghostface" },
    ["Granny"] = { "Granny" },
    ["Jack Torrance"] = { "Jack Torrance headshot icon", "Jack Torrance" },
    ["Jason"] = { "New Jason headshot", "Jason" },
    ["Jeff"] = { "Jeff the Killer headshot icon", "Jeff" },
    ["Leatherface"] = { "CurrentLeatherFaceHeadShot", "Leatherface" },
    ["Michael Myers"] = { "New Michael headshot", "Michael Myers" },
    ["Pennywise"] = { "Pennywise" },
    ["Pinhead"] = { "PinheadUpdatedGridHeadshot", "Pinhead" },
    ["Rake"] = { "Rake headshot icon new", "Rake headshot icon", "Rake" },
    ["Robot"] = { "Robot headshot icon", "Robot" },
    ["Slenderman"] = { "Slenderman headshot icon", "Slenderman" },
    ["Smile Dog"] = { "SAKTK Smile Dog Case File Icon Off.", "SAKTK Smile Dog Case File Icon Off", "Smile Dog" },
    ["Sonic.exe"] = { "AnotherNewSonicexeHeadshot", "Sonic.exe", "Sonic exe" },
    ["Tails Doll"] = { "Tails Doll", "Tails Doll headshot icon" },
    ["Wendigo"] = { "Wendigo headshot icon", "Wendigo" },
    ["Yeti"] = { "YetiHeadshot", "Yeti" },
    ["Zombie"] = { "Zombie headshot icon", "Zombie" },
}

local assets: { [string]: string } = {}
local state: { [string]: string } = {}
local tries: { [string]: number } = {}
local queue: { string } = {}
local workers = 0
local WORKERS = 6
local lastStage = "unknown"

local function safeName(name: string): string
    local lowered = string.lower(name)
    local cleaned = string.gsub(lowered, "[^%w]+", "_")
    return cleaned
end

local function decode(body: string): any
    local ok, value = pcall(function()
        return game:GetService("HttpService"):JSONDecode(body)
    end)
    return if ok then value else nil
end

local function fetch(url: string): string?
    local sender: any = request or http_request or (syn and syn.request) or (http and http.request)
    if sender then
        local ok, response = pcall(function()
            return sender({ Url = url, Method = "GET", Headers = HEADERS })
        end)
        if ok and type(response) == "table" then
            local status = tonumber(response.StatusCode) or 0
            if (status == 0 or (status >= 200 and status < 400)) and type(response.Body) == "string" and response.Body ~= "" then
                return response.Body
            end
        end
    end
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    return if ok and type(body) == "string" and body ~= "" then body else nil
end

local function imageExtension(body: string): string?
    if #body < 8 then
        return nil
    end
    if string.sub(body, 1, 4) == "\137PNG" then
        return "png"
    end
    if string.byte(body, 1) == 0xFF and string.byte(body, 2) == 0xD8 and string.byte(body, 3) == 0xFF then
        return "jpg"
    end
    return nil
end

local function encode(text: string): string
    return game:GetService("HttpService"):UrlEncode(text)
end

local function infoUrl(fileTitle: string): string?
    local decoded = decode(fetch(WIKI_API .. "&prop=imageinfo&iiprop=url&iiurlwidth=320&titles=" .. encode(fileTitle)) or "")
    local pages = decoded and decoded.query and decoded.query.pages
    if type(pages) ~= "table" then
        return nil
    end
    for _, page in pages do
        local info = type(page) == "table" and page.imageinfo and page.imageinfo[1]
        if type(info) == "table" then
            local url = info.url or info.thumburl
            if type(url) == "string" and url ~= "" then
                return url
            end
        end
    end
    return nil
end

local function pageImage(title: string): string?
    local decoded = decode(fetch(WIKI_API .. "&prop=pageimages&piprop=thumbnail%7Coriginal&pithumbsize=320&titles=" .. encode(title)) or "")
    local pages = decoded and decoded.query and decoded.query.pages
    if type(pages) ~= "table" then
        return nil
    end
    for _, page in pages do
        if type(page) == "table" then
            local url = (page.original and page.original.source) or (page.thumbnail and page.thumbnail.source)
            if type(url) == "string" and url ~= "" then
                return url
            end
        end
    end
    return nil
end

local function bestGalleryImage(title: string, killer: string, minimum: number): string?
    local decoded = decode(fetch(WIKI_API .. "&prop=images&imlimit=100&titles=" .. encode(title)) or "")
    local pages = decoded and decoded.query and decoded.query.pages
    if type(pages) ~= "table" then
        return nil
    end
    local wanted = string.gsub(string.lower(killer), "[^%w]", "")
    local best, bestScore = nil, -math.huge
    for _, page in pages do
        for _, item in if type(page) == "table" and page.images then page.images else {} do
            local name = item and item.title
            if type(name) == "string" then
                local lower = string.lower(name)
                local normalized = string.gsub(lower, "[^%w]", "")
                local score = 0
                if string.find(lower, "headshot", 1, true) then
                    score += 100
                end
                if string.find(lower, "icon", 1, true) then
                    score += 35
                end
                if wanted ~= "" and string.find(normalized, wanted, 1, true) then
                    score += 55
                end
                if string.find(lower, "case", 1, true) then
                    score -= 50
                end
                if string.find(lower, "location", 1, true) or string.find(lower, "fanart", 1, true) then
                    score -= 80
                end
                if score > bestScore then
                    best, bestScore = name, score
                end
            end
        end
    end
    return if best and bestScore >= minimum then infoUrl(best) else nil
end

local WIKI_TITLES: { [string]: string } = { RayGun = "Ray Gun" }

local function resolveUrl(name: string): string?
    local killer = WIKI_TITLES[name] or name
    local headshot = bestGalleryImage(killer, killer, 100)
    if headshot then
        return headshot
    end
    local direct = pageImage(killer)
    if direct then
        return direct
    end
    local candidates: { string } = FILE_CANDIDATES[killer] or {}
    for _, base in candidates do
        for _, extension in { "png", "jpg", "jpeg" } do
            local url = infoUrl("File:" .. base .. "." .. extension)
            if url then
                return url
            end
        end
    end
    return bestGalleryImage(killer, killer, -math.huge)
end

local function asset(path: string): string?
    local ok, value = pcall(getcustomasset, path)
    if ok and type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function cached(killer: string): string?
    local base = safeName(killer)
    for _, folder in { FOLDER } do
        for _, extension in EXTENSIONS do
            local path = folder .. "/" .. base .. "." .. extension
            local ok, exists = pcall(isfile, path)
            if ok and exists then
                local found = asset(path)
                if found then
                    return found
                end
            end
        end
    end
    return nil
end

local function download(killer: string): string?
    local url = resolveUrl(killer)
    if not url then
        lastStage = "no picture found on the wiki"
        return nil
    end
    local original = url .. (if string.find(url, "?", 1, true) then "&" else "?") .. "format=original"
    local body = fetch(original)
    if not body then
        lastStage = "picture download failed " .. url
        return nil
    end
    local extension = imageExtension(body)
    if not extension then
        lastStage = "picture is not png or jpg " .. url
        return nil
    end
    local path = FOLDER .. "/" .. safeName(killer) .. "." .. extension
    if not pcall(writefile, path, body) then
        lastStage = "writefile failed"
        return nil
    end
    local made = asset(path)
    if not made then
        lastStage = "getcustomasset failed"
    end
    return made
end

local wake: () -> ()

local function load(killer: string)
    local found = cached(killer) or download(killer)
    if not found and tries[killer] == nil then
        warn("[SAKTK51] icon for " .. killer .. " could not be loaded: " .. tostring(lastStage))
    end
    if found then
        assets[killer] = found
        state[killer] = "ready"
    else
        local used = (tries[killer] or 0) + 1
        tries[killer] = used
        if used < MAX_TRIES then
            state[killer] = "loading"
            task.delay(RETRY_DELAY * used, function()
                if Context.Running and state[killer] == "loading" then
                    table.insert(queue, killer)
                    wake()
                end
            end)
        else
            state[killer] = "failed"
        end
    end
end

local function drain()
    workers += 1
    while Context.Running and #queue > 0 do
        local killer = table.remove(queue, 1) :: string
        if state[killer] == "loading" then
            load(killer)
        end
    end
    workers -= 1
end

wake = function()
    while workers < WORKERS and workers < #queue do
        task.spawn(drain)
    end
end

function Portraits.prepare()
    local ok = pcall(function()
        local built = ""
        for part in string.gmatch(FOLDER, "[^/\\]+") do
            built = if built == "" then part else built .. "/" .. part
            if not isfolder(built) then
                makefolder(built)
            end
        end
    end)
    local _ = ok
end

function Portraits.image(killer: string): string?
    local ready = assets[killer]
    if ready then
        return ready
    end
    if state[killer] == nil then
        local saved = cached(killer)
        if saved then
            assets[killer] = saved
            state[killer] = "ready"
            return saved
        end
        state[killer] = "loading"
        table.insert(queue, killer)
        wake()
    end
    return nil
end

function Portraits.preload(names: { string })
    for _, name in names do
        Portraits.image(name)
    end
end

function Portraits.state(killer: string): string
    return state[killer] or "idle"
end

function Portraits.retry()
    for killer, value in state do
        if value == "failed" then
            state[killer] = nil
            tries[killer] = nil
        end
    end
end

return Portraits
end
modules["projectiles"] = function(...)

local import: (string) -> any = ...
local Aim: typeof(require("./aim")) = import("aim")
local Context: typeof(require("./context")) = import("context")
local Debug: typeof(require("./debug")) = import("debug")
local Weapons: typeof(require("./weapons")) = import("weapons")

local Projectiles = {}

Projectiles.lastMoment = 0

type Shot = { weapon: any, moduleName: string?, origin: Vector3, aimPoint: Vector3, created: number }

local SHOT_LIFETIME = 0.35
local MAX_SHOTS = 96
local SPAWN_RADIUS = 40
local BULLET_RADIUS = 8
local ALIGNMENT = 0.35
local MIN_SPEED = 8
local INSTANT_SPEED = 40
local INSIDE_DEPTH = 0.5
local CENTER_SNAP = 3
local MAX_RAY_HOPS = 24

local shots: { Shot } = {}
local adjusted: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local link: any = nil

local function purge(now: number)
    local expired = 0
    for _, shot in shots do
        if now - shot.created <= SHOT_LIFETIME then
            break
        end
        expired += 1
    end
    if expired == 0 then
        return
    end
    local keep: { Shot } = table.create(#shots - expired)
    for index = expired + 1, #shots do
        table.insert(keep, shots[index])
    end
    shots = keep
end

local MUZZLE_SECONDS = 0.5
local muzzleCache: { [any]: { Part: any, Scoped: boolean, At: number } } = setmetatable({}, { __mode = "k" }) :: any

local function muzzle(weapon: any): Vector3
    local instance = type(weapon) == "table" and rawget(weapon, "instance") or nil
    if instance and typeof(instance) == "Instance" then
        local scoped = rawget(weapon, "aiming") == true and rawget(weapon, "has_scope") == true
        local now = os.clock()
        local cached = muzzleCache[instance]
        if cached and cached.Scoped == scoped and now - cached.At < MUZZLE_SECONDS and cached.Part.Parent and cached.Part:IsDescendantOf(instance) then
            return cached.Part.Position
        end
        local preferred = (if scoped then instance:FindFirstChild("Aim") else nil)
            or instance:FindFirstChild("Flash")
            or instance:FindFirstChild("Muzzle", true)
            or instance:FindFirstChild("Barrel", true)
            or instance:FindFirstChild("Handle", true)
        if preferred and preferred:IsA("BasePart") then
            muzzleCache[instance] = { Part = preferred, Scoped = scoped, At = now }
            return preferred.Position
        end
        for _, object in instance:GetDescendants() do
            if object:IsA("BasePart") then
                return object.Position
            end
        end
    end
    local camera = Context.camera()
    if camera then
        return camera.CFrame.Position
    end
    local head = Context.LocalPlayer.Character and Context.LocalPlayer.Character:FindFirstChild("Head")
    return if head then head.Position else Vector3.new(0, 0, 0)
end

function Projectiles.begin(weapon: any, provider: any)
    local settings = Context.S
    if (not settings.CustomBulletTravel and not settings.ExtendedProjectileRange) or type(weapon) ~= "table" then
        return
    end
    local meta = Weapons.metaOf(weapon)
    if meta and meta.moduleName == "Flamethrower" then
        return
    end
    local source = provider
    if type(source) ~= "function" then
        source = function()
            return Context.mouse()
        end
    end
    local aimPoint: Vector3? = nil
    local convert = weapon.screen_to_target
    if type(convert) == "function" then
        local ok, point = pcall(convert, weapon, source)
        local kind = typeof(point)
        if ok and kind == "Vector3" then
            aimPoint = point
        end
    end
    if not aimPoint then
        local camera = Context.camera()
        if not camera then
            return
        end
        aimPoint = camera.CFrame.Position + camera.CFrame.LookVector * 2000
    end
    purge(os.clock())
    table.insert(shots, { weapon = weapon, moduleName = meta and meta.moduleName, origin = muzzle(weapon), aimPoint = aimPoint :: Vector3, created = os.clock() })
    while #shots > MAX_SHOTS do
        table.remove(shots, 1)
    end
end

local function velocityOf(part: any): Vector3
    local assembly = part.AssemblyLinearVelocity
    if assembly.Magnitude > 1 then
        return assembly
    end
    local body = part:FindFirstChildOfClass("BodyVelocity")
    if body and body.Velocity.Magnitude > 1 then
        return body.Velocity
    end
    local linear = part:FindFirstChildOfClass("LinearVelocity")
    if linear then
        local ok, value = pcall(function()
            return linear.VectorVelocity
        end)
        local kind = typeof(value)
        if ok and kind == "Vector3" and value.Magnitude > 1 then
            return value
        end
    end
    return assembly
end

local function push(part: any, velocity: Vector3)
    pcall(function()
        part.AssemblyLinearVelocity = velocity
    end)
    local body = part:FindFirstChildOfClass("BodyVelocity")
    if body then
        pcall(function()
            body.Velocity = velocity
        end)
    end
    local linear = part:FindFirstChildOfClass("LinearVelocity")
    if linear then
        pcall(function()
            linear.VectorVelocity = velocity
        end)
    end
end

local function match(part: any, velocity: Vector3): Shot?
    local now = os.clock()
    purge(now)
    local position = part.Position
    local direction = if velocity.Magnitude > 0.01 then velocity.Unit else nil
    local best, bestScore = nil, -math.huge
    for index = #shots, 1, -1 do
        local shot = shots[index]
        local age = now - shot.created
        local spawn = (position - shot.origin).Magnitude
        local radius = if part.Name == "Bullet" then BULLET_RADIUS else SPAWN_RADIUS
        if age <= SHOT_LIFETIME and spawn <= radius then
            local wanted = shot.aimPoint - position
            if wanted.Magnitude > 0.01 then
                local alignment = if direction then direction:Dot(wanted.Unit) else 1
                if alignment >= ALIGNMENT then
                    local score = alignment * 100 - spawn - age * 100
                    if score > bestScore then
                        best, bestScore = shot, score
                    end
                end
            end
        end
    end
    return best
end

local function instantDestination(shot: Shot, projectile: any): Vector3
    local origin = projectile.Position
    local target = shot.aimPoint
    local delta = target - origin
    local distance = delta.Magnitude
    if distance <= 0.01 then
        return target
    end
    local direction = delta.Unit
    local ignore: { any } = {}
    if Context.LocalPlayer.Character then
        table.insert(ignore, Context.LocalPlayer.Character)
    end
    local instance = type(shot.weapon) == "table" and rawget(shot.weapon, "instance") or nil
    if instance and typeof(instance) == "Instance" then
        table.insert(ignore, instance)
    end
    table.insert(ignore, projectile)
    local from = origin
    local remaining = distance
    for _ = 1, MAX_RAY_HOPS do
        if remaining <= 0.01 then
            break
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ignore
        params.IgnoreWater = true
        local result = Context.Workspace:Raycast(from, direction * remaining, params)
        if not result then
            return target
        end
        if not Context.S.Wallbang or Aim.liveTarget(result.Instance, shot.weapon) then
            return result.Position
        end
        table.insert(ignore, result.Instance)
        local advanced = (result.Position - from).Magnitude + 0.05
        remaining -= advanced
        from = result.Position + direction * 0.05
    end
    return target
end

local function reportHit(shot: Shot, part: any, destination: Vector3)
    if not Context.S.InstantHit or Projectiles.lastMoment == 0 then
        return
    end
    local weapon = shot.weapon
    if type(weapon) ~= "table" or type(weapon.missile_hit) ~= "function" then
        return
    end
    for _, candidate in Context.Workspace:GetPartBoundsInRadius(destination, 3) do
        if candidate ~= part and Aim.liveTarget(candidate, weapon) then
            Debug.count("instantHit", candidate.Name)
            pcall(weapon.missile_hit, weapon, part, Projectiles.lastMoment, candidate, destination)
            return
        end
    end
end

local function adjust(part: any)
    local settings = Context.S
    if not Context.Running or (not settings.CustomBulletTravel and not settings.ExtendedProjectileRange) then
        return
    end
    if not part or not part:IsA("BasePart") or part.Anchored or adjusted[part] then
        return
    end
    local character = Context.LocalPlayer.Character
    if character and part:IsDescendantOf(character) then
        return
    end
    local velocity = velocityOf(part)
    for _ = 1, 4 do
        if velocity.Magnitude > MIN_SPEED then
            break
        end
        Context.RunService.Heartbeat:Wait()
        if not part.Parent or adjusted[part] then
            return
        end
        velocity = velocityOf(part)
    end
    if velocity.Magnitude <= MIN_SPEED then
        return
    end
    local shot = match(part, velocity)
    if not shot then
        Debug.count("projectileUnmatched", part.Name)
        return
    end
    Debug.count("projectileMatched", part.Name)
    adjusted[part] = true
    local delta = shot.aimPoint - part.Position
    local distance = delta.Magnitude
    if distance <= 0.01 then
        return
    end
    local direction = if velocity.Magnitude > 0.01 then velocity.Unit else delta.Unit
    if direction:Dot(delta.Unit) < ALIGNMENT then
        direction = delta.Unit
    end
    if settings.CustomBulletTravel then
        local travel = math.max(0, tonumber(settings.BulletTravelTime) or 0)
        if travel <= 0.0001 then
            local destination = instantDestination(shot, part)
            Debug.count("instantShot", (destination - shot.aimPoint).Magnitude)
            local toward = destination - part.Position
            local heading = if toward.Magnitude > 0.01 then toward.Unit else direction
            local inside = destination + heading * INSIDE_DEPTH
            if (shot.aimPoint - destination).Magnitude <= CENTER_SNAP then
                inside = shot.aimPoint
            end
            pcall(function()
                part.CFrame = CFrame.lookAt(inside, inside + heading)
            end)
            push(part, heading * INSTANT_SPEED)
            reportHit(shot, part, destination)
            return
        end
        push(part, direction * math.max(0.25, distance / travel))
        return
    end
    if settings.ExtendedProjectileRange then
        push(part, velocity * math.clamp(tonumber(settings.ProjectileRangeMultiplier) or 4, 1, 20))
    end
end

function Projectiles.start()
    if link then
        return
    end
    link = Context.Workspace.DescendantAdded:Connect(function(object: any)
        local settings = Context.S
        if (not settings.CustomBulletTravel and not settings.ExtendedProjectileRange) or not Context.Running then
            return
        end
        if object:IsA("BasePart") then
            task.spawn(function()
                pcall(adjust, object)
            end)
        end
    end)
end

function Projectiles.stop()
    if link then
        pcall(function()
            link:Disconnect()
        end)
        link = nil
    end
    table.clear(shots)
end

return Projectiles
end
modules["promptwatch"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")

local PromptWatch = {}

PromptWatch.Set = {} :: { [any]: boolean }

local holders: { [string]: boolean } = {}
local link: any = nil

local function track(object: any)
    if object:IsA("ProximityPrompt") then
        PromptWatch.Set[object] = true
    end
end

function PromptWatch.hold(owner: string)
    holders[owner] = true
    if link then
        return
    end
    link = Context.Workspace.DescendantAdded:Connect(track)
    task.spawn(function()
        local started = os.clock()
        for _, object in Context.Workspace:GetDescendants() do
            track(object)
            if os.clock() - started > 0.0008 then
                task.wait()
                started = os.clock()
            end
        end
    end)
end

function PromptWatch.holding(owner: string): boolean
    return holders[owner] == true
end

function PromptWatch.release(owner: string)
    holders[owner] = nil
    if link and next(holders) == nil then
        pcall(function()
            link:Disconnect()
        end)
        link = nil
        table.clear(PromptWatch.Set)
    end
end

return PromptWatch
end
modules["protection"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")
local Modes: typeof(require("./modes")) = import("modes")
local Reroll: typeof(require("./reroll")) = import("reroll")

local Protection = {}

local TICK_SECONDS = 0.10

local lastTick = 0
local patched = false
local links: { any } = {}

local function removeInk()
    local settings = Context.S
    if not settings.NoInk then
        return
    end
    local gui = Context.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not gui then
        return
    end
    for _, child in gui:GetChildren() do
        local name = string.lower(child.Name)
        if settings.NoInk and (name == "ink" or name == "inked") then
            pcall(function()
                child:Destroy()
            end)
        end
    end
end

local blockedRemotes: { [string]: boolean } = {}

local function setBlocked(name: string, blocked: boolean)
    if blocked == (blockedRemotes[name] == true) then
        return
    end
    local getconnections = (getgenv() :: any).getconnections
    local remotes = Context.ReplicatedStorage:FindFirstChild("Character Remotes")
    local event = remotes and remotes:FindFirstChild(name)
    if type(getconnections) ~= "function" or not event or not event:IsA("RemoteEvent") then
        return
    end
    local ok, connections = pcall(getconnections, event.OnClientEvent)
    if not ok or type(connections) ~= "table" then
        return
    end
    for _, connection in connections do
        pcall(function()
            if blocked then
                connection:Disable()
            else
                connection:Enable()
            end
        end)
    end
    blockedRemotes[name] = blocked
end

local HOOK_KEY = "__SAKTK51BossHook"
local bossHooked = false
local hookState: { On: boolean }? = nil

local function hookBossDamage()
    if bossHooked then
        return
    end
    local env = getgenv() :: any
    local shared = env[HOOK_KEY]
    if type(shared) == "table" then
        bossHooked = true
        hookState = shared
        return
    end
    local hook, getMethod, wrap = env.hookmetamethod, env.getnamecallmethod, env.newcclosure
    if type(hook) ~= "function" or type(getMethod) ~= "function" then
        return
    end
    bossHooked = true
    local state = { On = false }
    local original: any
    local function handler(self: any, ...: any): any
        if state.On and getMethod() == "FireServer" and typeof(self) == "Instance" and self.Name == "MakeWave" then
            return nil
        end
        return original(self, ...)
    end
    local ok, previous = pcall(hook, game, "__namecall", if type(wrap) == "function" then wrap(handler) else handler)
    if ok then
        original = previous
        hookState = state
        env[HOOK_KEY] = state
    end
end

local function syncHook()
    local wanted = Context.Running and Context.S.BossImmunity == true
    if wanted and not bossHooked then
        hookBossDamage()
    end
    local state = hookState
    if state and state.On ~= wanted then
        state.On = wanted
    end
end

local immune = false

local function switchConnections(signal: any, enable: boolean)
    local getconnections = (getgenv() :: any).getconnections
    if type(getconnections) ~= "function" then
        return
    end
    local ok, connections = pcall(getconnections, signal)
    if not ok or type(connections) ~= "table" then
        return
    end
    for _, connection in connections do
        pcall(function()
            if enable then
                connection:Enable()
            else
                connection:Disable()
            end
        end)
    end
end

local function bossImmunity(on: boolean)
    if not on and not immune then
        return
    end
    immune = on
    local area = Context.folder("AREA51")
    local map = area and area:FindFirstChild("Map")
    if not map then
        return
    end
    if Modes.bossName() == "Kraken" then
        for _, name in { "MakeWave", "Expel" } do
            local remote = map:FindFirstChild(name)
            if remote and remote:IsA("RemoteEvent") then
                switchConnections(remote.OnClientEvent, not on)
            end
        end
        local character = Context.LocalPlayer.Character
        for _, name in { "HeadCollision", "Torso" } do
            local part = character and character:FindFirstChild(name)
            if part then
                switchConnections(part.Touched, not on)
            end
        end
    end
end

function Protection.start()
    patched = true
    syncHook()
    task.spawn(function()
        local gui = Context.LocalPlayer:FindFirstChildOfClass("PlayerGui") or Context.LocalPlayer:WaitForChild("PlayerGui", 5)
        if gui and Context.Running then
            table.insert(links, gui.DescendantAdded:Connect(function()
                task.defer(removeInk)
            end))
        end
    end)
end

function Protection.step()
    if not patched then
        return
    end
    syncHook()
    local now = os.clock()
    if now - lastTick < TICK_SECONDS then
        return
    end
    lastTick = now
    Reroll.setDetected(Modes.currentKiller())
    removeInk()
    setBlocked("ServerTrip", Context.S.NoTrip == true)
    setBlocked("ServerTeleport", Context.S.NoForcedTeleport == true)
    bossImmunity(Modes.Current == "Boss Rush" and Context.S.BossImmunity == true)
end

function Protection.stop()
    patched = false
    if hookState then
        hookState.On = false
    end
    bossImmunity(false)
    setBlocked("ServerTrip", false)
    setBlocked("ServerTeleport", false)
    for _, link in links do
        pcall(function()
            link:Disconnect()
        end)
    end
    table.clear(links)
end

return Protection
end
modules["registry"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")
local Modes: typeof(require("./modes")) = import("modes")
local Targets: typeof(require("./targets")) = import("targets")

local Registry = {}

type Map = { [string]: any }
type Entry = {
    Key: any,
    Target: any,
    Adornee: any,
    Kind: string,
    DisplayName: string,
    Meta: Map?,
    Highlight: any,
}

local LANDMARKS: { [string]: string } = {
    RayGunRoom = "Ray Gun Room",
    AmmoRoom = "Ammo Room",
    WeaponFabricRoom = "Weapon Fabric Room",
    PackAPunchSquareRoom = "Pack a Punch Room",
    SewerVaultRoom = "Sewer Vault",
    CodeDoorRoom = "Alien Code Door",
    SurveillanceCamerasRoom = "Surveillance Room",
    AlienLabRoom = "Alien Lab",
    Armory1Room = "Armory 1",
    Amory2Room = "Armory 2",
    SVDRoom = "SVD Room",
    VaultShotgun = "Vault Shotgun",
    ExperimentRoom = "Experiment Room",
    SecretCleanerRoom = "Secret Cleaner Room",
    TeleporterRoom = "Teleporter Room",
    UFORoom = "UFO Room",
}

local DEEP_FLAGS = { "VisualKeycardESP", "VisualPaperESP", "VisualInteractableESP" }
local DEEP_BATCH = 180
local ROOT_REFRESH = 1.0

Registry.All = {
    Weapons = {},
    Killers = {},
    Survivors = {},
    Bosses = {},
    Keycards = {},
    Papers = {},
    Landmarks = {},
    Secrets = {},
    PackAPunch = {},
    Cameras = {},
    Prompts = {},
    FacilityObjectives = {},
    EndlessPerks = {},
    MysteryBox = {},
    Traps = {},
} :: { [string]: { [any]: Entry } }

Registry.WeaponsFolder = nil :: any
Registry.KillersFolder = nil :: any

local folderLinks: { [string]: { any } } = {}
local deepStarted = false
local lastRefresh = -math.huge
local listeners: { any } = {}
local promptLinks: { [any]: any } = {}
local bossWanted = false
local facilityWanted = false

function Registry.prettyName(name: any): string
    local text = tostring(name or "Object")
    text = string.gsub(text, "SecretPath", "Secret Path ")
    text = string.gsub(text, "(%l)(%u)", "%1 %2")
    text = string.gsub(text, "Room$", " Room")
    text = string.gsub(text, "%s+", " ")
    return text
end

function Registry.count(name: string): number
    local total = 0
    local registry: { [any]: Entry } = Registry.All[name] or {}
    for _ in registry do
        total += 1
    end
    return total
end

function Registry.isSelf(target: any): boolean
    local character = Context.LocalPlayer.Character
    if not character or not target or typeof(target) ~= "Instance" then
        return false
    end
    return target == character or target:IsDescendantOf(character)
end

function Registry.adorneeOf(target: any): any
    if not target or typeof(target) ~= "Instance" then
        return nil
    end
    if target:IsA("Attachment") or target:IsA("BasePart") then
        return target
    end
    if target:IsA("ProximityPrompt") then
        local parent = target.Parent
        if parent and (parent:IsA("Attachment") or parent:IsA("BasePart")) then
            return parent
        end
        return if parent then Registry.adorneeOf(parent) else nil
    end
    if target:IsA("Tool") then
        return target:FindFirstChild("Handle") or target:FindFirstChildWhichIsA("BasePart", true)
    end
    if target:IsA("Model") then
        local hitbox = target:FindFirstChild("Hitbox", true)
        if hitbox and hitbox:IsA("BasePart") then
            return hitbox
        end
        if target.PrimaryPart and target.PrimaryPart:IsA("BasePart") then
            return target.PrimaryPart
        end
        local root = target:FindFirstChild("HumanoidRootPart", true) or target:FindFirstChild("Head", true) or target:FindFirstChild("Handle", true)
        if root and root:IsA("BasePart") then
            return root
        end
        return target:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

function Registry.positionOf(entry: Entry): Vector3?
    local adornee = entry.Adornee
    if not adornee or not adornee.Parent then
        return nil
    end
    if adornee:IsA("Attachment") then
        return adornee.WorldPosition
    elseif adornee:IsA("BasePart") then
        return adornee.Position
    end
    return nil
end

function Registry.alive(entry: Entry): boolean
    if not entry.Target or not entry.Adornee or not entry.Target.Parent or not entry.Adornee.Parent then
        return false
    end
    return entry.Target:IsDescendantOf(Context.Workspace) or entry.Adornee:IsDescendantOf(Context.Workspace)
end

local function highlightTarget(target: any, adornee: any): any
    if target:IsA("Model") or target:IsA("BasePart") then
        return target
    end
    return adornee
end

function Registry.add(name: string, key: any, target: any, kind: string, displayName: string?, meta: Map?): Entry?
    local registry = Registry.All[name]
    if not registry or not key or not target or typeof(target) ~= "Instance" or Registry.isSelf(target) then
        return nil
    end
    local existing = registry[key]
    if existing then
        if displayName then
            existing.DisplayName = displayName
        end
        if meta then
            existing.Meta = meta
        end
        return existing
    end
    local adornee = Registry.adorneeOf(target)
    if not adornee then
        return nil
    end
    local highlight: any = nil
    if (target:IsA("Model") or target:IsA("BasePart")) and kind ~= "prompt" then
        highlight = Instance.new("Highlight")
        highlight.Name = "SAKTK51_ESP_Highlight"
        highlight.Enabled = false
        highlight.Adornee = highlightTarget(target, adornee)
        pcall(function()
            highlight.Parent = target
        end)
        if not highlight.Parent then
            highlight.Parent = Context.Workspace
        end
    end
    local entry: Entry = {
        Key = key,
        Target = target,
        Adornee = adornee,
        Kind = kind,
        DisplayName = displayName or target.Name,
        Meta = meta,
        Highlight = highlight,
    }
    registry[key] = entry
    return entry
end

function Registry.destroy(name: string, key: any)
    local registry = Registry.All[name]
    local entry = registry and registry[key]
    if not entry then
        return
    end
    if entry.Highlight then
        pcall(function()
            entry.Highlight:Destroy()
        end)
    end
    registry[key] = nil
end

function Registry.clear(name: string)
    local keys: { any } = {}
    for key in Registry.All[name] do
        table.insert(keys, key)
    end
    for _, key in keys do
        Registry.destroy(name, key)
    end
end

local function unlink(slot: string)
    local links = folderLinks[slot]
    if links then
        for _, link in links do
            pcall(function()
                link:Disconnect()
            end)
        end
    end
    folderLinks[slot] = nil
end

local function bind(slot: string, registryName: string, folderName: string, current: any, accept: (any) -> ()): any
    local folder = Context.Workspace:FindFirstChild(folderName)
    if folder == current then
        return current
    end
    unlink(slot)
    Registry.clear(registryName)
    if not folder then
        return nil
    end
    for _, child in folder:GetChildren() do
        accept(child)
    end
    folderLinks[slot] = {
        folder.ChildAdded:Connect(accept),
        folder.ChildRemoved:Connect(function(child: any)
            Registry.destroy(registryName, child)
        end),
    }
    return folder
end

function Registry.bossModel(): any
    local area = Context.folder("AREA51")
    if not area then
        return nil
    end
    local map = area:FindFirstChild("Map")
    local boss = map and map:FindFirstChild("Boss")
    if boss and boss:IsA("Model") then
        return boss
    end
    local candidate = area:FindFirstChild("Boss", true)
    if candidate and candidate:IsA("Model") then
        return candidate
    end
    return nil
end

local function refreshSurvivors()
    local wanted: { [any]: boolean } = {}
    local killers = Context.folder("Killers")
    for _, player in Context.Players:GetPlayers() do
        if player ~= Context.LocalPlayer then
            local character = player.Character
            if character and character ~= Context.LocalPlayer.Character and character.Parent and not (killers and character:IsDescendantOf(killers)) then
                wanted[character] = true
                Registry.add("Survivors", character, character, "survivor", player.DisplayName, { Source = "player", Player = player })
            end
        end
    end
    local stale: { any } = {}
    for key, entry in Registry.All.Survivors do
        if entry.Meta and entry.Meta.Source == "player" and not wanted[key] then
            table.insert(stale, key)
        end
    end
    for _, key in stale do
        Registry.destroy("Survivors", key)
    end
end

local function refreshMap()
    local area = Context.folder("AREA51")
    if area then
        for source, pretty in LANDMARKS do
            local object = area:FindFirstChild(source)
            if object and object:IsA("Model") then
                Registry.add("Landmarks", object, object, "landmark", pretty)
            end
        end
        for _, object in area:GetChildren() do
            local lower = string.lower(object.Name)
            if object:IsA("Model") and (string.find(lower, "secretpath", 1, true) or string.find(lower, "secretroom", 1, true)) then
                Registry.add("Secrets", object, object, "secret", Registry.prettyName(object.Name))
            end
        end
        local code = area:FindFirstChild("CodeModel")
        if code then
            Registry.add("FacilityObjectives", code, code, "facility_objective", "Alien Code")
        end
        local combination = area:FindFirstChild("CombinaisonModel")
        if combination then
            Registry.add("FacilityObjectives", combination, combination, "facility_objective", "Cleaner Combination")
        end
        local sewer = facilityWanted and area:FindFirstChild("SewerVaultRoom")
        local keypad = sewer and sewer:FindFirstChild("Keypad", true)
        if keypad then
            Registry.add("FacilityObjectives", keypad, keypad, "facility_objective", "Sewer Vault Keypad")
        end
    end
    local pack = Context.folder("PACKAPUNCH")
    if pack then
        Registry.add("PackAPunch", pack, pack, "pack", "Pack a Punch")
    end
    local cameras = Context.folder("Surveillance Cameras")
    if cameras then
        for _, object in cameras:GetChildren() do
            if object:IsA("Model") or object:IsA("BasePart") then
                Registry.add("Cameras", object, object, "camera", "Camera - " .. Registry.prettyName(object.Name))
            end
        end
    end
    local boss = bossWanted and Modes.Current ~= "Juggernaut" and Registry.bossModel()
    if boss then
        Registry.add("Bosses", boss, boss, "boss", boss.Name)
    end
end

local function refreshEndless()
    local perks = Context.folder("Perks")
    if perks then
        for _, object in perks:GetChildren() do
            if object:IsA("Model") or object:IsA("BasePart") then
                Registry.add("EndlessPerks", object, object, "perk", Registry.prettyName(object.Name))
            end
        end
    end
    local boxes = Context.folder("Mystery Box")
    local box = boxes and boxes:FindFirstChild("Box")
    if box then
        Registry.add("MysteryBox", box, box, "mystery", "Mystery Box")
    end
    local traps = Context.folder("Traps")
    if traps then
        for _, object in traps:GetChildren() do
            if object:IsA("Model") or object:IsA("BasePart") then
                Registry.add("Traps", object, object, "trap", "Trap - " .. Registry.prettyName(object.Name))
            end
        end
    end
end

local function worldTool(tool: any): boolean
    if not tool or not tool:IsA("Tool") or not tool:IsDescendantOf(Context.Workspace) then
        return false
    end
    local model = tool:FindFirstAncestorWhichIsA("Model")
    return not (model and model:FindFirstChildOfClass("Humanoid"))
end

local function classify(object: any)
    if not object or typeof(object) ~= "Instance" then
        return
    end
    if object:IsA("Tool") and worldTool(object) then
        local name = object.Name
        if name == "Card1" or name == "Card2" or name == "Card3" or name == "Card4" then
            Registry.add("Keycards", object, object, "keycard", name)
        elseif string.match(name, "^Paper%d+$") then
            Registry.add("Papers", object, object, "paper", name)
        end
    elseif object:IsA("ProximityPrompt") then
        local parent = object.Parent
        local holder = if parent and parent:IsA("Attachment") then parent.Parent else parent
        local lower = if holder then string.lower(holder.Name) else ""
        local list: string? = nil
        local kind = ""
        if string.match(lower, "^card%d*$") then
            list, kind = "Keycards", "keycard"
        elseif string.match(lower, "^paper%d*$") then
            list, kind = "Papers", "paper"
        end
        if list and holder then
            local room = holder.Parent
            local label = (if room and room.Name ~= "AREA51" then Registry.prettyName(room.Name) .. " " else "") .. Registry.prettyName(holder.Name)
            local bucket = list
            local kindName = kind
            local function sync()
                if not Context.Running then
                    return
                end
                if object.Enabled then
                    Registry.add(bucket, holder, holder, kindName, label)
                else
                    Registry.destroy(bucket, holder)
                end
            end
            local previous = promptLinks[object]
            if previous then
                pcall(function()
                    previous:Disconnect()
                end)
            end
            promptLinks[object] = object:GetPropertyChangedSignal("Enabled"):Connect(sync)
            sync()
            return
        end
        local name = if object.ObjectText ~= "" then object.ObjectText else (if parent then parent.Name else "Interactable")
        local action = if object.ActionText ~= "" then object.ActionText else "Interact"
        Registry.add("Prompts", object, object, "prompt", name, { Action = action, Object = name })
    end
end

function Registry.ensureDeepScan()
    if deepStarted then
        return
    end
    deepStarted = true
    task.spawn(function()
        local stack: { any } = { Context.Workspace }
        local processed = 0
        while Context.Running and #stack > 0 do
            local node = table.remove(stack) :: any
            local ok, children = pcall(function()
                return node:GetChildren()
            end)
            if ok then
                for _, child in children do
                    classify(child)
                    stack[#stack + 1] = child
                    processed += 1
                    if processed >= DEEP_BATCH then
                        processed = 0
                        Context.RunService.Heartbeat:Wait()
                    end
                end
            end
        end
    end)
end

local function deepWanted(): boolean
    for _, flag in DEEP_FLAGS do
        if Context.S[flag] then
            return true
        end
    end
    return false
end

function Registry.refresh()
    Registry.WeaponsFolder = bind("Weapons", "Weapons", "Weapons", Registry.WeaponsFolder, function(object: any)
        if object:IsA("Model") or object:IsA("Tool") then
            Registry.add("Weapons", object, object, "weapon", object.Name)
        end
    end)
    Registry.KillersFolder = bind("Killers", "Killers", "Killers", Registry.KillersFolder, function(object: any)
        if object:IsA("Model") and object ~= Context.LocalPlayer.Character and not Targets.whitelisted(object) then
            Registry.add("Killers", object, object, "killer", object.Name)
        end
    end)
    refreshSurvivors()
    refreshMap()
    refreshEndless()
    if deepWanted() then
        Registry.ensureDeepScan()
    end
    for prompt, link in promptLinks do
        if not prompt.Parent then
            pcall(function()
                link:Disconnect()
            end)
            promptLinks[prompt] = nil
        end
    end
end

function Registry.tick()
    local settings = Context.S
    local boss = settings.VisualBossESP == true or settings.VisualBossOffscreen == true
    local facility = settings.VisualFacilityObjectiveESP == true
    local woke = (boss and not bossWanted) or (facility and not facilityWanted)
    bossWanted, facilityWanted = boss, facility
    local now = os.clock()
    if woke or now - lastRefresh >= ROOT_REFRESH then
        lastRefresh = now
        Registry.refresh()
    end
end

function Registry.start()
    table.insert(listeners, Context.Workspace.DescendantAdded:Connect(function(object: any)
        if deepStarted then
            classify(object)
        end
    end))
    table.insert(listeners, Context.Workspace.ChildAdded:Connect(function(object: any)
        local name = object.Name
        if name == "Weapons" or name == "Killers" or name == "PACKAPUNCH" or name == "Surveillance Cameras"
            or name == "Perks" or name == "Mystery Box" or name == "Traps" then
            task.defer(function()
                if Context.Running then
                    Registry.refresh()
                end
            end)
        end
    end))
    Registry.refresh()
end

function Registry.stop()
    for _, link in listeners do
        pcall(function()
            link:Disconnect()
        end)
    end
    table.clear(listeners)
    for _, link in promptLinks do
        pcall(function()
            link:Disconnect()
        end)
    end
    table.clear(promptLinks)
    for slot in folderLinks do
        unlink(slot)
    end
    for name in Registry.All do
        Registry.clear(name)
    end
    Registry.WeaponsFolder, Registry.KillersFolder = nil, nil
    deepStarted = false
end

return Registry
end
modules["reroll"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")
local Context: typeof(require("./context")) = import("context")
local Modes: typeof(require("./modes")) = import("modes")

local Reroll = {}

local RESPAWN_TIMEOUT = 4.0
local CLASSIFY_TIMEOUT = 1.35
local POLL_SECONDS = 0.03
local ROUND_END_SECONDS = 1.25
local WATCH_SECONDS = 0.25

type Run = {
    Active: boolean,
    Targets: { [string]: boolean },
    Order: { string },
    Attempts: number,
    Token: number,
    InFlight: boolean,
}

local run: Run = { Active = false, Targets = {}, Order = {}, Attempts = 0, Token = 0, InFlight = false }
local text = ""
local detected: string? = nil

local function formatOrder(order: { string }): string
    local count = #order
    if count == 0 then
        return "no killers"
    elseif count == 1 then
        return order[1]
    elseif count == 2 then
        return order[1] .. " / " .. order[2]
    elseif count == 3 then
        return order[1] .. " / " .. order[2] .. " / " .. order[3]
    end
    return order[1] .. " / " .. order[2] .. " +" .. tostring(count - 2) .. " more"
end

function Reroll.active(): boolean
    return run.Active
end

function Reroll.status(): string
    if run.Active or text ~= "" then
        return text
    end
    if not Modes.canReroll() then
        if Modes.Current == "Non-SAKTK Game" then
            return "Reset Until is available in SAKTK51 (Killer/Infection Mode)."
        elseif Modes.Current == "Classic" then
            return "Reset Until is available in Killer Mode and Infection Mode."
        end
        return "Reset Until is unavailable in " .. Modes.Current .. " (Killer/Infection only)."
    end
    return if detected then ("Current Killer: " .. detected) else "Current Killer: survivor / unknown"
end

function Reroll.setDetected(name: string?)
    detected = name
end

function Reroll.stop(reason: string?)
    run.Active = false
    run.InFlight = false
    run.Token += 1
    run.Targets = {}
    run.Order = {}
    run.Attempts = 0
    text = reason or ""
    detected = Modes.currentKiller()
end

local function requestReset(): boolean
    local character = Context.LocalPlayer.Character
    if not character then
        return false
    end
    local humanoid = Context.humanoid(character)
    local remotes = Context.ReplicatedStorage:FindFirstChild("Character Remotes")
    local died = remotes and remotes:FindFirstChild("ClientDied")
    local requested = false
    if died and died:IsA("RemoteEvent") then
        requested = pcall(function()
            died:FireServer(character)
        end) or requested
    end
    if humanoid then
        pcall(function()
            humanoid.Health = 0
        end)
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Dead)
        end)
        requested = true
    end
    pcall(function()
        character:BreakJoints()
    end)
    return requested
end

local function waitForResult(oldCharacter: any, targets: { [string]: boolean }, token: number): (boolean, string?, string)
    local started = os.clock()
    local fresh: any = nil
    while Context.Running and run.Active and run.Token == token and os.clock() - started < RESPAWN_TIMEOUT do
        local current = Context.LocalPlayer.Character
        if current and current ~= oldCharacter then
            fresh = current
            break
        end
        task.wait(POLL_SECONDS)
    end
    if not fresh then
        return false, nil, "timeout"
    end
    local classifyStart = os.clock()
    while Context.Running and run.Active and run.Token == token and os.clock() - classifyStart < CLASSIFY_TIMEOUT do
        local settled, killer = Modes.roleOf(fresh)
        if settled then
            if killer and targets[killer] then
                return true, killer, "found"
            end
            return false, killer, if killer then "wrong_killer" else "survivor"
        end
        local direct = Modes.currentKiller()
        if direct and targets[direct] then
            return true, direct, "found"
        end
        task.wait(POLL_SECONDS)
    end
    local direct = Modes.currentKiller()
    if direct and targets[direct] then
        return true, direct, "found"
    end
    return false, direct, "unclassified"
end

function Reroll.start(selection: { [string]: boolean })
    if not Modes.canReroll() then
        text = "Reset Until requires SAKTK51 Killer or Infection Mode (Current: " .. Modes.Current .. ")."
        return
    end
    local targets: { [string]: boolean } = {}
    local order: { string } = {}
    for _, name in Config.KILLERS do
        if selection[name] then
            targets[name] = true
            table.insert(order, name)
        end
    end
    if #order == 0 then
        text = "Select at least one killer."
        return
    end
    if not Modes.roleOf(Context.LocalPlayer.Character) then
        text = "Round is not active - reroll not started."
        return
    end
    run.Token += 1
    run.Active = true
    run.Targets, run.Order, run.Attempts, run.InFlight = targets, order, 0, false
    local token = run.Token
    local label = formatOrder(order)
    text = "Rerolling -> " .. label .. " - starting..."
    task.spawn(function()
        while Context.Running and run.Active and run.Token == token do
            if not Modes.canReroll() then
                Reroll.stop("Instance changed - reroll cancelled.")
                return
            end
            local current = Modes.currentKiller()
            if current and targets[current] then
                run.Active = false
                text = "Found " .. current .. " after " .. tostring(run.Attempts) .. " reset(s)."
                detected = current
                return
            end
            run.Attempts += 1
            text = "Rerolling -> " .. label .. " - reset " .. tostring(run.Attempts)
            local old = Context.LocalPlayer.Character
            run.InFlight = true
            if not requestReset() then
                run.InFlight = false
                text = "Reset retry -> " .. label .. " - " .. tostring(run.Attempts)
                task.wait(0.20)
            else
                local found, killer, result = waitForResult(old, targets, token)
                run.InFlight = false
                if not run.Active or run.Token ~= token then
                    return
                end
                if found then
                    run.Active = false
                    text = "Found " .. tostring(killer) .. " after " .. tostring(run.Attempts) .. " reset(s)."
                    detected = killer
                    return
                end
                if result == "unclassified" then
                    task.wait(0.35)
                    if not Modes.roleOf(Context.LocalPlayer.Character) then
                        Reroll.stop("Round ended - reroll cancelled.")
                        return
                    end
                end
                task.wait(if result == "timeout" then 0.20 else 0.06)
            end
        end
    end)
end

function Reroll.watch(): thread
    return task.spawn(function()
        local outside: number? = nil
        while Context.Running do
            if Modes.refresh() and run.Active and not Modes.canReroll() then
                Reroll.stop("Instance changed - reroll cancelled.")
            end
            if run.Active and not run.InFlight then
                local settled = Modes.roleOf(Context.LocalPlayer.Character)
                if settled then
                    outside = nil
                elseif Context.LocalPlayer.Character then
                    outside = outside or os.clock()
                    if os.clock() - (outside :: number) > ROUND_END_SECONDS then
                        Reroll.stop("Round ended - reroll cancelled.")
                        outside = nil
                    end
                end
            else
                outside = nil
            end
            task.wait(WATCH_SECONDS)
        end
    end)
end

return Reroll
end
modules["targets"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")
local Modes: typeof(require("./modes")) = import("modes")

local Targets = {}

local function inside(model: any, container: any): boolean
    return container ~= nil and (model == container or model:IsDescendantOf(container))
end

local WHITELIST: { [string]: boolean } = { jane = true, janethekiller = true, giant = true, giantzombie = true }
local whitelistMemo: { [string]: boolean } = {}
local whitelistCount = 0

function Targets.whitelisted(model: any): boolean
    if Modes.Current ~= "Classic" or not model then
        return false
    end
    local raw = model.Name
    local known = whitelistMemo[raw]
    if known ~= nil then
        return known
    end
    local name = string.gsub(string.lower(raw), "[^%a]", "")
    local result = WHITELIST[name] == true
    if whitelistCount >= 256 then
        whitelistMemo, whitelistCount = {}, 0
    end
    whitelistMemo[raw] = result
    whitelistCount += 1
    return result
end

function Targets.boss(): any
    local area = Context.folder("AREA51")
    local map = area and area:FindFirstChild("Map")
    return map and map:FindFirstChild("Boss")
end

function Targets.aimPoint(model: any): any
    if not model then
        return nil
    end
    local weak = Targets.boss() == model and model:FindFirstChild("WeakPoint", true)
    if weak and weak:IsA("BasePart") then
        return weak
    end
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("UpperTorso")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("Head")
        or model:FindFirstChild("HeadCollision")
        or model:FindFirstChildWhichIsA("BasePart", true)
end

function Targets.killers(): { any }
    local list: { any } = {}
    local folder = Context.folder("Killers")
    if folder then
        for _, child in folder:GetChildren() do
            if not Targets.whitelisted(child) then
                table.insert(list, child)
            end
        end
    end
    local aliens = if Modes.storming() then Context.Workspace:FindFirstChild("Aliens") else nil
    if aliens then
        for _, child in aliens:GetChildren() do
            if child:IsA("Model") then
                table.insert(list, child)
            end
        end
    end
    local boss = Targets.boss()
    if boss and boss:IsA("Model") and not Targets.whitelisted(boss) then
        table.insert(list, boss)
    end
    return list
end

function Targets.survivors(): { any }
    if Modes.storming() then
        return {}
    end
    local folder = Context.folder("Characters to kill")
    return if folder then folder:GetChildren() else {}
end

function Targets.isKiller(model: any): boolean
    return inside(model, Context.folder("Killers")) or inside(model, Targets.boss()) or (Modes.storming() and inside(model, Context.Workspace:FindFirstChild("Aliens")))
end

function Targets.isSurvivor(model: any): boolean
    return inside(model, Context.folder("Characters to kill"))
end

function Targets.alive(model: any): boolean
    if not model then
        return false
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end
    return humanoid:GetState() ~= Enum.HumanoidStateType.Dead
end

function Targets.dead(model: any): boolean
    local humanoid = model and model:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and (humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead)
end

function Targets.shielded(model: any): boolean
    return model ~= nil and model:FindFirstChildWhichIsA("ForceField") ~= nil
end

function Targets.hostile(model: any): boolean
    if not model or not Targets.alive(model) or Targets.whitelisted(model) then
        return false
    end
    local mine = Context.LocalPlayer.Character
    if mine and (model == mine or model:IsDescendantOf(mine)) then
        return false
    end
    local player = Context.Players:GetPlayerFromCharacter(model)
    if player and Modes.storming() then
        return false
    end
    if player then
        local team = Context.LocalPlayer.Team
        if team and player.Team == team then
            return false
        end
    end
    local iAmKiller = mine ~= nil and Targets.isKiller(mine)
    if Targets.isKiller(model) then
        return not iAmKiller
    end
    if Targets.isSurvivor(model) then
        return iAmKiller
    end
    if player then
        local team = Context.LocalPlayer.Team
        return team == nil or player.Team ~= team
    end
    return true
end

local CREATURE_INTERVAL = 1
local creatureCache: { any } = {}
local creatureScan = 0

function Targets.creatures(): { any }
    if Modes.Current ~= "Boss Rush" then
        return {}
    end
    local now = os.clock()
    if now - creatureScan < CREATURE_INTERVAL then
        return creatureCache
    end
    creatureScan = now
    local list: { any } = {}
    local function add(model: any)
        if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") and Context.Players:GetPlayerFromCharacter(model) == nil then
            table.insert(list, model)
        end
    end
    local function scan(container: any, deep: boolean)
        local children = if deep then container:GetDescendants() else container:GetChildren()
        for _, child in children do
            add(child)
        end
    end
    scan(Context.Workspace, false)
    local killers = Context.folder("Killers")
    if killers then
        scan(killers, true)
    end
    local area = Context.folder("AREA51")
    local map = area and area:FindFirstChild("Map")
    if map then
        scan(map, false)
    end
    creatureCache = list
    return list
end

function Targets.enemies(): { any }
    local list: { any } = {}
    local seen: { [any]: boolean } = {}
    local function add(model: any)
        if model and not seen[model] and model:IsA("Model") and Targets.hostile(model) then
            seen[model] = true
            table.insert(list, model)
        end
    end
    for _, model in Targets.killers() do
        add(model)
    end
    for _, model in Targets.survivors() do
        add(model)
    end
    for _, model in Targets.creatures() do
        add(model)
    end
    for _, player in Context.Players:GetPlayers() do
        add(player.Character)
    end
    return list
end

return Targets
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

local function corners(frame: CFrame, half: Vector3): { Vector3 }
    local position = frame.Position
    local right, up, look = frame.RightVector * half.X, frame.UpVector * half.Y, frame.LookVector * half.Z
    return {
        position + right + up + look,
        position - right + up + look,
        position - right + up - look,
        position + right + up - look,
        position + right - up + look,
        position - right - up + look,
        position - right - up - look,
        position + right - up - look,
    }
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

function Visual.box(canvas: any, camera: any, root: any, size: Vector3, style: Style, tag: Tag?)
    local frame = root.CFrame
    local half = size * 0.5
    local covered = inside(camera, frame, half)
    if not covered then
        local world = corners(frame, half)
        local points: { Vector2? } = {}
        local depths: { number } = {}
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
modules["warning"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")

local Warning = {}

local FOLDER = "oklo scripts/saktk51"
local PATH = FOLDER .. "/warning.txt"
local WIDTH, HEIGHT = 440, 248
local ITALIC = "Source Sans Italic"

local LINES = {
    "Certain options can be detected and may cause",
    "your account to be shadow banned from SAKTK51!",
    "Use on an alt or with caution.",
}
local ITALIC_LINES = { "not responsible for any bans or", "account related problems." }

local dontShow = false

local function load(): boolean
    local ok, exists = pcall(isfile, PATH)
    if not ok or not exists then
        return false
    end
    local read, content = pcall(readfile, PATH)
    if not read or type(content) ~= "string" then
        return false
    end
    local value = string.match(string.lower(content), "dontshowagain%s*=%s*(%a+)")
    return value == "true"
end

local function save()
    local built = ""
    for part in string.gmatch(FOLDER, "[^/]+") do
        built = if built == "" then part else built .. "/" .. part
        local ok, exists = pcall(isfolder, built)
        if ok and not exists then
            pcall(makefolder, built)
        end
    end
    pcall(writefile, PATH, "dontshowagain = " .. tostring(dontShow) .. "\n")
end

function Warning.register(ui: any, fonts: any)
    dontShow = load()
    local italic = fonts.find(ITALIC)
    ui:popup("warning", {
        Width = WIDTH,
        Height = HEIGHT,
        Title = "Warning",
        Locked = true,
        Render = function(kit: any, window: any)
            local pal = window.Pal
            for index, line in LINES do
                kit:text(line, WIDTH / 2, 56 + (index - 1) * 22, 13, pal.Text, true, true)
            end
            for index, line in ITALIC_LINES do
                kit:text(line, WIDTH / 2, 134 + (index - 1) * 20, 13, pal.Sub, true, true, italic)
            end
            kit:text("Have fun!", WIDTH / 2, 184, 13, pal.Accent, true, true)
            kit:switchRow("warning:never", 14, 204, WIDTH - 28, 30, "Don't show again", dontShow, function()
                dontShow = not dontShow
                save()
            end)
        end,
    })
end

function Warning.show(ui: any)
    if dontShow then
        return
    end
    if Context.Running then
        ui:openPopup("warning")
    end
end

return Warning
end
modules["weapons"] = function(...)

local import: (string) -> any = ...
local Context: typeof(require("./context")) = import("context")

local Weapons = {}

type Map = { [string]: any }
type Loose = { [any]: any }

Weapons.SHOTGUNS = { ["DB Shotgun"] = true, ["M1014"] = true, ["R870"] = true } :: { [string]: boolean }

Weapons.Tracked = setmetatable({}, { __mode = "k" }) :: any
Weapons.Meta = setmetatable({}, { __mode = "k" }) :: any
Weapons.Modules = {} :: { [any]: any }
Weapons.Extra = {} :: { [any]: { [string]: any } }

local discovered = false

local function moduleNameOf(weapon: any, tool: any): string?
    local name: any = nil
    if tool and typeof(tool) == "Instance" then
        name = tool.Name
    end
    if not name then
        local instance = type(weapon) == "table" and rawget(weapon, "instance") or nil
        if instance and typeof(instance) == "Instance" then
            name = instance.Name
        end
    end
    if type(name) ~= "string" then
        return nil
    end
    if string.sub(name, 1, 3) == "PAP" then
        name = string.sub(name, 4)
    end
    return name
end

local function statsArguments(weapon: any, packed: any): Loose
    if type(packed) == "table" and packed.n ~= nil then
        local copy: Loose = { n = packed.n }
        for index = 1, packed.n do
            copy[index] = packed[index]
        end
        return copy
    end
    local name: any = if type(weapon) == "table" then rawget(weapon, "name") else nil
    if name == "M203" then
        return { n = 1, [1] = true }
    elseif name == "M16A2" then
        return { n = 1, [1] = false }
    end
    return { n = 0 }
end

function Weapons.track(weapon: any, tool: any?, packed: any?): any
    if type(weapon) ~= "table" then
        return weapon
    end
    Weapons.Tracked[weapon] = true
    local meta = Weapons.Meta[weapon]
    if not meta then
        meta = {
            moduleName = moduleNameOf(weapon, tool),
            statsArgs = statsArguments(weapon, packed),
            actualPap = rawget(weapon, "is_pap") == true,
            lastDesiredPap = nil,
        }
        Weapons.Meta[weapon] = meta
    else
        if not meta.moduleName then
            meta.moduleName = moduleNameOf(weapon, tool)
        end
        if packed and packed.n ~= nil then
            meta.statsArgs = statsArguments(weapon, packed)
        end
    end
    return weapon
end

function Weapons.metaOf(weapon: any): Map?
    if type(weapon) ~= "table" then
        return nil
    end
    if not Weapons.Meta[weapon] then
        Weapons.track(weapon)
    end
    return Weapons.Meta[weapon]
end

function Weapons.equipped(): any
    local character = Context.LocalPlayer.Character
    for weapon in Weapons.Tracked do
        if type(weapon) == "table" and rawget(weapon, "equipped") == true then
            local instance = rawget(weapon, "instance")
            if instance and (not character or instance.Parent == character or instance:IsDescendantOf(character)) then
                return weapon
            end
        end
    end
    for weapon in Weapons.Tracked do
        if type(weapon) == "table" and rawget(weapon, "equipped") == true then
            return weapon
        end
    end
    return nil
end

function Weapons.isFlame(weapon: any): boolean
    local meta = Weapons.Meta[weapon]
    return meta ~= nil and meta.moduleName == "Flamethrower"
end

function Weapons.fireDelay(): number?
    local settings = Context.S
    if settings.MinigunMode then
        return 0
    elseif settings.RapidFire then
        return math.max(0, tonumber(settings.CustomFireRate) or 0)
    end
    return nil
end

function Weapons.applyAmmo(weapon: any)
    if type(weapon) ~= "table" then
        return
    end
    local settings = Context.S
    if settings.InfAmmo or settings.InfStoredAmmo then
        local stored = rawget(weapon, "stored_ammo")
        local maximum = rawget(weapon, "max_stored")
        if type(stored) == "number" and stored <= 0 and type(maximum) == "number" and maximum > 0 then
            rawset(weapon, "stored_ammo", maximum)
        end
    end
end

local MODULE_SECONDS = 1
local STATS_SECONDS = 0.15
local moduleCache: { [string]: { Loaded: any, At: number } } = {}

local function findModule(name: string): any
    local now = os.clock()
    local cached = moduleCache[name]
    if cached and now - cached.At < MODULE_SECONDS then
        return cached.Loaded
    end
    local loaded: any = nil
    local folder = Context.ReplicatedStorage:FindFirstChild("Weapon")
    local moduleScript = folder and folder:FindFirstChild(name)
    if moduleScript and moduleScript:IsA("ModuleScript") then
        local ok, result = pcall(require, moduleScript)
        if ok and type(result) == "table" then
            loaded = result
        end
    end
    moduleCache[name] = { Loaded = loaded, At = now }
    return loaded
end

local function moduleOf(weapon: any): (any, Map?)
    local meta = Weapons.metaOf(weapon)
    local name = meta and meta.moduleName or moduleNameOf(weapon, nil)
    if not name then
        return nil, nil
    end
    local loaded = findModule(name)
    if not loaded then
        return nil, nil
    end
    return loaded, meta
end

local function originalStats(weapon: any, pap: boolean): Map?
    local own = Weapons.Meta[weapon]
    local now = os.clock()
    if own and own.statsAt and now - own.statsAt < STATS_SECONDS and own.statsPap == pap and own.statsFor == own.statsArgs then
        return own.statsCache
    end
    local stats: Map? = nil
    local loaded, meta = moduleOf(weapon)
    if loaded and meta then
        local getter = Weapons.Modules[loaded] or rawget(loaded, "get_stats")
        if type(getter) == "function" then
            local arguments = meta.statsArgs or { n = 0 }
            local result = table.pack(pcall(getter, loaded, pap, table.unpack(arguments, 1, arguments.n or 0)))
            if result[1] and type(result[2]) == "table" then
                stats = result[2]
            end
        end
    end
    if meta then
        meta.statsAt, meta.statsPap, meta.statsFor, meta.statsCache = now, pap, meta.statsArgs, stats
    end
    return stats
end

function Weapons.applyState(weapon: any)
    if type(weapon) ~= "table" then
        return
    end
    local meta = Weapons.metaOf(weapon)
    if not meta then
        return
    end
    local settings = Context.S
    local actual = rawget(weapon, "is_pap") == true
    meta.actualPap = actual
    local desired = actual
    local stats = originalStats(weapon, desired)
    if stats then
        local previous = meta.lastDesiredPap
        local changed = previous ~= nil and previous ~= desired
        if type(stats.ammo) == "number" then
            rawset(weapon, "max_ammo", stats.ammo)
            if changed and desired then
                rawset(weapon, "ammo", stats.ammo)
            elseif changed and not desired then
                local ammo = rawget(weapon, "ammo")
                if type(ammo) == "number" and ammo > stats.ammo then
                    rawset(weapon, "ammo", stats.ammo)
                end
            end
        end
        if type(stats.stored_ammo) == "number" then
            rawset(weapon, "max_stored", stats.stored_ammo)
            if changed and desired then
                rawset(weapon, "stored_ammo", stats.stored_ammo)
            elseif changed and not desired then
                local stored = rawget(weapon, "stored_ammo")
                if type(stored) == "number" and stored > stats.stored_ammo then
                    rawset(weapon, "stored_ammo", stats.stored_ammo)
                end
            end
        end
        rawset(weapon, "bullet_count", stats.bullet_count)
        if settings.CustomPelletCount and Weapons.SHOTGUNS[meta.moduleName] then
            rawset(weapon, "bullet_count", math.clamp(math.floor(tonumber(settings.PelletCount) or 12), 1, 50))
        end
        if stats.burst_count ~= nil then
            rawset(weapon, "burst_count", stats.burst_count)
        end
        if stats.is_grenade ~= nil then
            rawset(weapon, "is_grenade", stats.is_grenade == true)
        elseif meta.moduleName == "M1911" then
            rawset(weapon, "is_grenade", false)
        end
        rawset(weapon, "shoot_wait", (if meta.moduleName == "Flamethrower" then nil else Weapons.fireDelay()) or stats.shoot_wait)
        if meta.moduleName == "Flamethrower" then
            rawset(weapon, "max_heat", if desired then 75 else 60)
        end
        meta.lastDesiredPap = desired
    else
        local delay = Weapons.fireDelay()
        if delay and not Weapons.isFlame(weapon) then
            rawset(weapon, "shoot_wait", delay)
        end
    end
    Weapons.applyAmmo(weapon)
end

function Weapons.discover()
    if discovered then
        return
    end
    discovered = true
    task.delay(3, Weapons.scan)
end

function Weapons.scan()
    local ok, objects = pcall(getgc, true)
    if not ok or type(objects) ~= "table" then
        return
    end
    local count = 0
    for _, object in objects do
        count += 1
        if count % 4000 == 0 then
            task.wait()
        end
        if type(object) == "table"
            and type(rawget(object, "ammo")) == "number"
            and type(rawget(object, "stored_ammo")) == "number"
            and type(rawget(object, "max_ammo")) == "number"
            and type(rawget(object, "max_stored")) == "number"
            and rawget(object, "instance") ~= nil then
            Weapons.track(object)
        end
    end
end

function Weapons.normalize()
    local settings = Context.S
    local rapid, minigun = settings.RapidFire, settings.MinigunMode
    settings.RapidFire, settings.MinigunMode = false, false
    for weapon in Weapons.Tracked do
        pcall(function()
            local meta = Weapons.Meta[weapon]
            if meta then
                meta.lastDesiredPap = true
            end
            Weapons.applyState(weapon)
        end)
    end
    settings.RapidFire, settings.MinigunMode = rapid, minigun
end

return Weapons
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


