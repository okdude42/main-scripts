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
modules["aero"] = function(...)

local import: (string) -> any = ...
local Env: typeof(require("./env")) = import("env")

local Aero = {}

type Map = { [string]: any }

local NAME = "__PBInputWrap"
local VERSION = 1
local WRAP = { "Shoot", "Sprint", "Steal", "Pass", "Dribble", "Jump", "Clutch", "HoldG" }
local CANDIDATES = { "Meter", "Gui", "Player", "UserInput", "Replication", "Team" }
local GC_CHUNK = 4000

local players: any = game:GetService("Players")

local function inputOf(services: any): any?
    if type(services) ~= "table" then
        return nil
    end
    local input = rawget(services, "InputService")
    if type(input) ~= "table" then
        return nil
    end
    local shoot = rawget(input, "Shoot")
    if type(shoot) ~= "table" or type(rawget(shoot, "Fire")) ~= "function" then
        return nil
    end
    return input
end

local function servicesOf(value: any): any?
    return value.Services
end

local function load(module: any): (boolean, any)
    local ok, value = pcall(require, module)
    if ok and type(value) == "table" then
        return ok, value
    end
    local set, get = Env.setidentity, Env.getidentity
    if not set then
        return ok, value
    end
    local before: any = nil
    if get then
        local read, level = pcall(get)
        before = if read then level else nil
    end
    pcall(set, 2)
    local again, result = pcall(require, module)
    pcall(set, if type(before) == "number" then before else 8)
    return again, result
end

local function fromModule(module: any): any?
    if typeof(module) ~= "Instance" or not module:IsA("ModuleScript") then
        return nil
    end
    local ok, value = load(module)
    if not ok or type(value) ~= "table" then
        return nil
    end
    local got, services = pcall(servicesOf, value)
    return if got then inputOf(services) else nil
end

local function controllers(): { any }
    local list = {}
    local player = players.LocalPlayer
    local scripts = if player then player:FindFirstChild("PlayerScripts") else nil
    local root = if scripts then scripts:FindFirstChild("Aero") else nil
    local folder = if root then root:FindFirstChild("Controllers") else nil
    if folder then
        for _, name in CANDIDATES do
            local child = folder:FindFirstChild(name)
            if child then
                table.insert(list, child)
            end
        end
    end
    local modules = if root then root:FindFirstChild("Modules") else nil
    local components = if modules then modules:FindFirstChild("Components") else nil
    local input = if components then components:FindFirstChild("Input") else nil
    if input then
        for _, name in { "Keyboard", "Gamepad", "Mobile" } do
            local child = input:FindFirstChild(name)
            if child then
                table.insert(list, child)
            end
        end
    end
    return list
end

local function fromGc(): any?
    local filter = Env.filtergc
    if filter then
        local ok, found = pcall(filter, "table", { Keys = { "InputService", "GameplayService" } }, true)
        if ok then
            return inputOf(found)
        end
        return nil
    end
    local walk = Env.getgc
    if not walk then
        return nil
    end
    local ok, list = pcall(walk, true)
    if not ok or type(list) ~= "table" then
        return nil
    end
    for index, value in list do
        if type(value) == "table" then
            local found = inputOf(value)
            if found then
                return found
            end
        end
        if index % GC_CHUNK == 0 then
            task.wait()
        end
    end
    return nil
end

function Aero.find(light: boolean?): any?
    local existing = Env.get(NAME)
    if type(existing) == "table" and existing.Version == VERSION and type(existing.Input) == "table" then
        return existing.Input
    end
    for _, module in controllers() do
        local input = fromModule(module)
        if input then
            return input
        end
    end
    if light then
        return nil
    end
    return fromGc()
end

function Aero.install(handler: (string, ...any) -> boolean, light: boolean?): (Map?, string?)
    local input = Aero.find(light)
    if not input then
        return nil, "unsupported"
    end
    local existing = Env.get(NAME)
    local reuse = type(existing) == "table" and existing.Version == VERSION and existing.Input == input
    if reuse then
        for name, wrapper in existing.Wrappers do
            local signal = rawget(input, name)
            if type(signal) ~= "table" or rawget(signal, "Fire") ~= wrapper then
                reuse = false
            end
        end
    end
    if type(existing) == "table" and not reuse then
        existing.Off = true
        existing.Handler = nil
    end
    local state: Map = if reuse then existing else { Version = VERSION, Input = input, Originals = {}, Wrappers = {} }
    state.Handler = handler
    state.Off = nil
    for _, name in WRAP do
        local signal = rawget(input, name)
        local current = if type(signal) == "table" then rawget(signal, "Fire") else nil
        if type(current) == "function" and current ~= state.Wrappers[name] then
            local original = current
            local function wrapper(self: any, ...: any): ...any
                if not state.Off then
                    local handle = state.Handler
                    if handle then
                        local ok, hold = pcall(handle, name, ...)
                        if ok and hold == true then
                            return
                        end
                    end
                end
                return original(self, ...)
            end
            state.Originals[name] = original
            state.Wrappers[name] = wrapper
            rawset(signal, "Fire", wrapper)
        end
    end
    Env.set(NAME, state)
    return state, nil
end

function Aero.intact(): boolean
    local state = Env.get(NAME)
    if type(state) ~= "table" or state.Off or type(state.Input) ~= "table" then
        return false
    end
    local signal = rawget(state.Input, "Shoot")
    return type(signal) == "table" and rawget(signal, "Fire") == state.Wrappers.Shoot
end

function Aero.remove()
    local state = Env.get(NAME)
    if type(state) ~= "table" or state.Version ~= VERSION then
        return
    end
    state.Off = true
    state.Handler = nil
    local input = state.Input
    local clean = true
    for name, wrapper in state.Wrappers do
        local signal = if type(input) == "table" then rawget(input, name) else nil
        if type(signal) == "table" then
            if rawget(signal, "Fire") == wrapper then
                rawset(signal, "Fire", state.Originals[name])
            else
                clean = false
            end
        end
    end
    if clean then
        Env.set(NAME, nil)
    end
end

return Aero
end
modules["autoblock"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")

local AutoBlock = {}
AutoBlock.__index = AutoBlock

type Map = { [string]: any }

local COOLDOWN = 0.9
local REACT_MIN = 0.02
local REACT_MAX = 0.07
local SLOW_CHANCE = 0.2
local SLOW_MIN = 0.03
local SLOW_MAX = 0.08
local RELEASE = 0.48
local BLOCK_PEAK = 0.35
local REACT_LEAD = 0.04
local FAKE_HOLD = 0.3
local FLIP_WINDOW = 0.6
local LIFT = 0.8
local BALL_REACH = 5
local SHOOTER_FACING = 0.25
local OWN_FACING = -0.2
local POINT_BLANK = 2.5
local MAX_HEIGHT = 6

local SHOTS: { [string]: boolean } = { Shooting = true, MovingShot = true }
local FINISHES: { [string]: number } = { Layup = 7, ContactLayup = 7, ClutchLayup = 7, Dunking = 6 }

local random = Random.new()

function AutoBlock.new(read: (string) -> any): any
    return setmetatable({ Read = read, Last = -math.huge, State = {} :: { [any]: Map }, Spare = {} :: { [any]: Map } }, AutoBlock)
end

local function jump(remote: any)
    local copied = Court.copied("Jump")
    if type(copied) == "table" then
        Court.send(remote, table.unpack(copied, 1, copied.n or #copied))
    else
        Court.send(remote)
    end
end

local function react(): number
    local value = REACT_MIN + random:NextNumber() * (REACT_MAX - REACT_MIN)
    if random:NextNumber() < SLOW_CHANCE then
        value += SLOW_MIN + random:NextNumber() * (SLOW_MAX - SLOW_MIN)
    end
    return value
end

local function metered(character: any): boolean
    for _, child in character:GetChildren() do
        if child:IsA("BillboardGui") and child.Enabled and string.sub(child.Name, -5) == "Meter" then
            return true
        end
    end
    return false
end

local function reachable(root: any, character: any, theirs: any, reach: number, finish: boolean): boolean
    local here: Vector3 = root.Position
    local there: Vector3 = theirs.Position
    if math.abs(there.Y - here.Y) > MAX_HEIGHT then
        return false
    end
    local toMe = Court.flat(here - there)
    local distance = toMe.Magnitude
    if distance > reach then
        return false
    end
    if distance < POINT_BLANK then
        return true
    end
    local direction = toMe / distance
    local look = Court.flat(theirs.CFrame.LookVector)
    if look.Magnitude > 0.01 and look.Unit:Dot(direction) < SHOOTER_FACING then
        local goal = Court.goal(character)
        local aim = if goal then Court.flat(goal.Position - there) else Vector3.zero
        if aim.Magnitude < 0.01 or aim.Unit:Dot(direction) < SHOOTER_FACING then
            return false
        end
    end
    local mine = Court.flat(root.CFrame.LookVector)
    if mine.Magnitude > 0.01 and mine.Unit:Dot(-direction) < OWN_FACING then
        return false
    end
    if finish then
        local rimDistance, rim = Court.rimDistance(there)
        if rimDistance and rim then
            local center: Vector3 = rim.Position
            if Court.flat(center - here).Magnitude > rimDistance + 1 then
                return false
            end
        end
    end
    return true
end

function AutoBlock.step(self: any, now: number)
    local read = self.Read
    local state: { [any]: Map } = self.State
    local spare: { [any]: Map } = self.Spare
    if read("AutoBlock") ~= true or not Court.Mine then
        if next(state) ~= nil then
            table.clear(state)
        end
        return
    end
    local mine = Court.Mine
    local root = Court.Root
    local action = Court.Action
    local ready = root ~= nil and not Court.HasBall and (action == "" or action == nil) and Court.free(mine)
        and not Court.Forced and not Court.HandsOff and not Court.Dead and mine:GetAttribute("InAir") ~= true and now - self.Last >= COOLDOWN
    local range = read("BlockRange") or 10
    local extra = (read("BlockDelay") or 0) / 1000
    local readFakes = read("ReadFakes") == true
    local ping = Court.Ping
    local chars, roots, foe, carry = Court.Chars, Court.Roots, Court.Foe, Court.Carry
    for index = 1, Court.Count do
        if foe[index] then
            local character = chars[index]
            local theirs = roots[index]
            local entry = state[character]
            if not entry then
                entry = {}
            end
            spare[character] = entry
            local released = character:GetAttribute("ReleasedShot")
            if entry.Released == true and released == false then
                entry.FlipAt = now
            end
            entry.Released = released
            local kind = character:GetAttribute("Action")
            local finish = if type(kind) == "string" then FINISHES[kind] else nil
            if not (type(kind) == "string" and SHOTS[kind]) and not finish then
                entry.Start = nil
                if character:GetAttribute("InAir") ~= true then
                    entry.Floor = theirs.Position.Y
                end
            else
                if entry.Start == nil then
                    entry.Start = now
                    entry.Done = false
                    entry.SawFalse = false
                    entry.Wait = nil
                end
                if released == false then
                    entry.SawFalse = true
                end
                if released == true and entry.SawFalse then
                    entry.Done = true
                end
                if ready and not entry.Done then
                    local elapsed = now - entry.Start
                    local flip = entry.FlipAt
                    local fresh = released == false and flip ~= nil and flip >= entry.Start - FLIP_WINDOW
                    local confirmed = finish ~= nil or fresh or metered(character)
                    local wait = entry.Wait
                    if not wait then
                        if finish then
                            wait = react() * 0.5 + extra
                        else
                            local speed = character:GetAttribute("ShotSpeed")
                            local release = RELEASE / (if type(speed) == "number" and speed > 0.05 then speed else 1)
                            wait = math.max(0, release - BLOCK_PEAK - ping - REACT_LEAD) + react() + extra
                        end
                        entry.Wait = wait
                    end
                    local go = elapsed >= wait and released ~= true
                    if go and not confirmed and readFakes then
                        local floor = entry.Floor
                        local up = character:GetAttribute("InAir") == true or (floor ~= nil and theirs.Position.Y - floor > LIFT)
                        go = elapsed >= FAKE_HOLD and up
                    end
                    if go and not carry[index] and Court.ballNear(theirs.Position, BALL_REACH) ~= true then
                        go = false
                    end
                    if go and reachable(root, character, theirs, if finish then math.min(range, finish) else range, finish ~= nil) then
                        local remote = Court.input("Jump")
                        if remote then
                            self.Last = now
                            entry.Done = true
                            jump(remote)
                            ready = false
                        end
                    end
                end
            end
        end
    end
    table.clear(state)
    self.State = spare
    self.Spare = state
end

return AutoBlock
end
modules["autodribble"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")
local Env: typeof(require("./env")) = import("env")

local AutoDribble = {}
AutoDribble.__index = AutoDribble

type Map = { [string]: any }

local COOLDOWN_MIN = 1.0
local COOLDOWN_MAX = 1.6
local REACT_MIN = 0.2
local REACT_MAX = 0.4
local RIM_CLEAR = 24

local random = Random.new()

local FORMS: { (any) -> ...any } = {
    function(context: any): ...any
        return context.Key, context.Sprint, context.Heading
    end,
    function(_: any): ...any
        return "H"
    end,
    function(_: any): ...any
        return { Input = "H" }
    end,
}

local function moved(context: Map): boolean
    local mine = context.Mine
    if mine.Parent == nil then
        return false
    end
    local action = mine:GetAttribute("Action")
    return mine:GetAttribute("LastDribblePackage") ~= context.Before or (action ~= "" and action ~= "Dribbling" and action ~= nil)
end

function AutoDribble.new(read: (string) -> any): any
    return setmetatable({ Read = read, Last = -math.huge, Wait = COOLDOWN_MIN, Since = nil :: number?, React = REACT_MIN, Index = 0, Keys = {} :: { string }, Context = {} :: Map }, AutoDribble)
end

function AutoDribble.step(self: any, now: number)
    local read = self.Read
    local mine, root = Court.Mine, Court.Root
    if read("AutoDribble") ~= true or read("DribbleCombo") == true or not mine or not root or not Court.HasBall then
        self.Since = nil
        return
    end
    local here: Vector3 = root.Position
    local rimDistance = Court.rimDistance(here)
    if (rimDistance and rimDistance < RIM_CLEAR) or Court.nearestFoe(here) > (read("DribbleRange") or 7) then
        self.Since = nil
        return
    end
    if not self.Since then
        self.Since = now
        self.React = REACT_MIN + random:NextNumber() * (REACT_MAX - REACT_MIN)
    end
    if now - self.Since < self.React or now - self.Last < self.Wait then
        return
    end
    local action = Court.Action
    if (action ~= "" and action ~= nil) or not Court.free(mine) or Court.HandsOff then
        return
    end
    local remote = Court.input("Dribble")
    if not remote then
        return
    end
    local direction: Vector3 = Court.heading() or Court.flat(root.CFrame.LookVector)
    if direction.Magnitude < 0.01 then
        return
    end
    direction = direction.Unit
    self.Last = now
    self.Wait = COOLDOWN_MIN + random:NextNumber() * (COOLDOWN_MAX - COOLDOWN_MIN)
    local hook = Env.get("__PBShootHook")
    local copied = if type(hook) == "table" and type(hook.Dribbles) == "table" then hook.Dribbles else nil
    local keys: { string } = self.Keys
    table.clear(keys)
    if copied then
        for key in copied do
            if type(key) == "string" then
                table.insert(keys, key)
            end
        end
    end
    if #keys > 0 then
        table.sort(keys)
        self.Index = self.Index % #keys + 1
        local args = copied[keys[self.Index]]
        local count = args.n or #args
        local sent: { any } = table.create(count)
        for index = 1, count do
            local value = args[index]
            local kind = typeof(value)
            if kind == "Vector3" and value.Magnitude > 0.01 and value.Magnitude < 1.5 then
                value = direction * value.Magnitude
            end
            sent[index] = value
        end
        Court.send(remote, table.unpack(sent, 1, count))
        return
    end
    self.Index = self.Index % 2 + 1
    local left = mine:GetAttribute("Hand") == "L"
    local context: Map = self.Context
    context.Mine = mine
    context.Key = if (self.Index == 1) == left then "C" else "Z"
    context.Sprint = Court.sprintHeld() or mine:GetAttribute("Sprinting") == true
    context.Heading = Court.heading() or Vector3.zero
    context.Before = mine:GetAttribute("LastDribblePackage")
    Court.fire("Dribble", FORMS, moved, nil, context)
end

return AutoDribble
end
modules["autodunk"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")
local Config: typeof(require("./config")) = import("config")
local Drive: typeof(require("./drive")) = import("drive")

local AutoDunk = {}
AutoDunk.__index = AutoDunk

local COOLDOWN = 2
local WINDOW_MIN = 4.6
local WINDOW_MAX = 11
local DRIVE_START = 20
local DRIVE_SWITCH = 14
local DRIVE_MIN = 6
local DRIVE_MAX = 13
local DRIVE_PACE = 15.5
local STAND_AT = 8
local RUN_SPEED = 16.8
local FACING = 0.35
local FRONT_CONE = 0.34
local FRONT_AIM = 0.6

local RELEASE_SPACE = { Shoot = false, Input = "E", UseSpace = true }
local PRESS_SPACE = { Shoot = true, Input = "E", UseSpace = true }

local flat = Court.flat

function AutoDunk.new(read: (string) -> any, autoGreen: any, player: any): any
    return setmetatable({
        Read = read,
        AutoGreen = autoGreen,
        Player = player,
        Last = -math.huge,
        Run = false,
        Holding = false,
        Owned = false,
        FiredAt = 0,
        SeenAt = nil :: number?,
        HoldGoal = nil :: Vector3?,
        Defense = nil :: any,
    }, AutoDunk)
end

function AutoDunk.idle(self: any)
    self.Run = false
    Court.hold("Dunk", false)
    Drive.clear("Dunk")
end

function AutoDunk.finish(self: any, now: number, on: boolean)
    local lost = not Court.HasBall and Court.Action ~= "Dunking" and now - self.FiredAt >= 0.2
    if not self.SeenAt and (Court.Action == "Dunking" or now - self.FiredAt >= 1.2 or not on or lost) then
        self.SeenAt = now
    end
    local seen: number? = self.SeenAt
    if seen and now - seen >= 0.15 then
        if not self.Owned then
            local remote = Court.input("Shoot")
            if remote then
                Court.send(remote, RELEASE_SPACE)
            end
        end
        self.Holding = false
        self.Owned = false
        self.HoldGoal = nil
        self.SeenAt = nil
    end
end

function AutoDunk.step(self: any, now: number)
    local read = self.Read
    local on = read("AutoDunk") == true
    if self.Holding then
        self:finish(now, on)
    end
    if not on then
        self.Run = false
    end
    local move = on and read("DunkMove") == true
    local goal: Vector3? = if self.Holding then self.HoldGoal else nil
    local run = false
    if self.Holding and (Court.Action == "Dunking" or Court.Action == "Shooting") then
        goal = nil
    end
    if on and now - self.Last >= COOLDOWN and not self.Holding then
        goal, run = self:plan(now, move)
    elseif self.Holding and goal then
        run = true
    end
    if move and goal then
        Drive.set("Dunk", goal, RUN_SPEED, false, true)
        Court.hold("Dunk", run)
    else
        Court.hold("Dunk", false)
        Drive.clear("Dunk")
    end
end

function AutoDunk.plan(self: any, now: number, move: boolean): (Vector3?, boolean)
    local read = self.Read
    local mine, root = Court.Mine, Court.Root
    if not mine or not root or not Court.HasBall then
        self.Run = false
        return nil, false
    end
    local action = Court.Action
    if (action ~= "" and action ~= "Dribbling" and action ~= "Pushing" and action ~= nil) or mine:GetAttribute("Stunned") == true or Court.Forced or Court.HandsOff then
        return nil, false
    end
    local auto = move and not Court.steering(mine)
    local rim, distance = Court.facingRim(root, FACING, read("DunkRange") or 30)
    local defense = self.Defense
    local attack = if defense then defense:attackRim() else nil
    if attack and rim ~= attack then
        rim = nil
    end
    if not rim and auto then
        local near: number?, closest: any? = nil, attack
        if closest then
            near = flat(closest.Position - root.Position).Magnitude
        else
            near, closest = Court.rimDistance(root.Position)
        end
        if near and closest and near <= (read("DunkRange") or 30) then
            rim, distance = closest, near
        end
    end
    if not rim then
        self.Run = false
        return nil, false
    end
    if read("DunkOpenOnly") == true and Court.nearestFoe(root.Position) <= (read("OpenRange") or 6) then
        return nil, false
    end
    local here: Vector3 = root.Position
    local rimAt = Vector3.new(rim.Position.X, here.Y, rim.Position.Z)
    local out = flat(here - rimAt)
    local side = if distance > 0.1 then out / distance else -flat(root.CFrame.LookVector)
    local front = Court.front(rim)
    local cone = if front then side:Dot(front) else 1
    local aim = side
    if front and cone < FRONT_AIM then
        local across = side - front * cone
        local bent = if across.Magnitude > 0.05 then front * FRONT_AIM + across.Unit * math.sqrt(1 - FRONT_AIM * FRONT_AIM) else front
        aim = bent.Unit
    end
    local inFront = cone >= FRONT_CONE
    self.Player.WantSprint = now + 0.4
    local part = Court.proxy()
    local velocity = if part then part.AssemblyLinearVelocity else Vector3.zero
    local planar = flat(velocity)
    local pace = planar.Magnitude
    local mode = read("DunkType") or Config.DUNK_BOTH
    local driving = mode == Config.DUNK_DRIVING or (mode == Config.DUNK_BOTH and (distance >= DRIVE_SWITCH or self.Run == true or pace >= DRIVE_PACE - 3))
    local goal: Vector3? = nil
    if not driving then
        self.Run = false
        if distance < WINDOW_MIN or distance > WINDOW_MAX or not inFront then
            return if auto then rimAt + aim * STAND_AT else nil, false
        end
        if pace >= 2 then
            return nil, false
        end
    else
        if not self.Run and auto then
            if distance < DRIVE_START or not inFront then
                return rimAt + aim * (DRIVE_START + 4), false
            end
            self.Run = true
        end
        goal = if auto then rimAt + aim * 2.5 else nil
        local toward = if distance > 0.1 then -planar:Dot(side) else 0
        if distance > DRIVE_MAX or distance < DRIVE_MIN or pace < DRIVE_PACE or toward < DRIVE_PACE * 0.8 or not inFront then
            if distance < DRIVE_MIN or (self.Run and not inFront) then
                self.Run = false
            end
            return goal, self.Run == true
        end
    end
    if mine:GetAttribute("Sprinting") ~= true or action == "Dribbling" or mine:GetAttribute("CanMove") == false then
        return goal, self.Run == true
    end
    self.Last = now
    self.Holding = true
    self.FiredAt = now
    self.SeenAt = nil
    self.HoldGoal = goal
    self.Run = false
    self.Owned = self.AutoGreen:begin(true)
    if not self.Owned then
        local shoot = Court.input("Shoot")
        if shoot then
            Court.send(shoot, PRESS_SPACE)
        end
    end
    local jump = Court.input("Jump")
    if jump then
        Court.send(jump)
    end
    return goal, goal ~= nil
end

function AutoDunk.claims(self: any, distance: number): boolean
    if self.Holding or self.Run then
        return true
    end
    local read = self.Read
    if distance > (read("DunkRange") or 30) then
        return false
    end
    if read("DunkMove") == true then
        return true
    end
    local root = Court.Root
    local rim = if root then Court.facingRim(root, FACING, read("DunkRange") or 30) else nil
    if not rim then
        return false
    end
    local ahead, aside = Court.frontOf(rim, root.Position)
    if ahead and ahead < FRONT_CONE * math.sqrt(ahead * ahead + aside * aside) then
        return false
    end
    local mode = read("DunkType") or Config.DUNK_BOTH
    local part = Court.proxy()
    local velocity = if part then flat(part.AssemblyLinearVelocity) else Vector3.zero
    local pace = velocity.Magnitude
    local toRim = flat(rim.Position - root.Position)
    if mode ~= Config.DUNK_STANDING and toRim.Magnitude > 0.1 and velocity:Dot(toRim.Unit) >= 8 then
        return true
    end
    if mode ~= Config.DUNK_DRIVING and distance >= WINDOW_MIN and distance <= WINDOW_MAX and pace < 2 then
        return true
    end
    return mode ~= Config.DUNK_STANDING and distance >= DRIVE_MIN and distance <= DRIVE_START and pace >= DRIVE_PACE - 3
end

function AutoDunk.shutdown(self: any)
    if self.Holding and not self.Owned then
        local remote = Court.input("Shoot")
        if remote then
            Court.send(remote, RELEASE_SPACE)
        end
    end
    self.Holding = false
    self.Owned = false
    self.HoldGoal = nil
    self:idle()
end

return AutoDunk
end
modules["autogreen"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")
local Court: typeof(require("./court")) = import("court")
local Env: typeof(require("./env")) = import("env")
local Hook: typeof(require("./hook")) = import("hook")

local AutoGreen = {}
AutoGreen.__index = AutoGreen

type Map = { [string]: any }

local LEARNED = "__PBPeaks"
local PEAK_FILE = "oklo scripts/practicalbasketball/peaks.json"
local TIMING_PERFECT = 5

local TAP_TIMEOUT = 0.8
local HOLD_TIMEOUT = 4.5
local DUNK_TIMEOUT = 0.9
local LAYUP_RANGE = 13
local LOST_GRACE = 0.3
local SERVER_STEP = 1 / 60
local STALL = 0.075

local METERED: { [string]: boolean } = { Shooting = true, Dunking = true, ContactLayup = true, ClutchLayup = true }
local PRESHOT: { [string]: boolean } = { Gathering = true, CatchingPass = true, PassTransition = true, CatchingLob = true, AwaitingPass = true }
local WAITING: { [string]: boolean } = { Dribbling = true, Gathering = true, CatchingPass = true, PassTransition = true, CatchingLob = true, AwaitingPass = true }

local PRESS = { Shoot = true, Input = "E" }
local PRESS_SPACE = { Shoot = true, Input = "E", UseSpace = true }
local RELEASE = { Shoot = false }

local LOG_FILE = "oklo scripts/practicalbasketball/greenlog.txt"
local LOG_LIMIT = 6000

AutoGreen.METERED = METERED
AutoGreen.PRESHOT = PRESHOT

local function learned(): Map
    local store = Env.get(LEARNED)
    if type(store) ~= "table" then
        store = Env.readJson(PEAK_FILE) or {}
        Env.set(LEARNED, store)
    end
    return store
end

local function shotSpeed(character: any): number
    local value = character:GetAttribute("ShotSpeed")
    return if type(value) == "number" and value > 0.05 then value else 1
end

local function meterKind(character: any, meters: { any }): string?
    for index = #meters, 1, -1 do
        local gui = meters[index]
        if not gui:IsDescendantOf(character) then
            table.remove(meters, index)
        elseif gui.Enabled and string.sub(gui.Name, -5) == "Meter" then
            return string.sub(gui.Name, 1, -6)
        end
    end
    return nil
end

local function liveShot(character: any, action: any, meters: { any }): boolean
    if METERED[action] then
        return true
    end
    if character:GetAttribute("ReleasedShot") ~= false or WAITING[action] then
        return false
    end
    return meterKind(character, meters) ~= nil
end

AutoGreen.liveShot = liveShot

function AutoGreen.trace(self: any, text: string)
    if self.Tracing ~= true then
        return
    end
    local lines = self.TraceLines
    if not lines then
        lines = {}
        self.TraceLines = lines
        self.TraceZero = os.clock()
    end
    if #lines >= LOG_LIMIT then
        return
    end
    local line = string.format("%8.3f  %s", os.clock() - self.TraceZero, text)
    lines[#lines + 1] = line
    self.TraceDirty = true
    print("[PBGreen] " .. line)
end

function AutoGreen.traceState(self: any, now: number, action: any)
    local shot: any = self.Shot
    local rimText = ""
    local root = Court.Root
    if root then
        local distance, rim = Court.rimDistance(root.Position)
        if distance and rim and distance <= 20 then
            local ahead, aside = Court.frontOf(rim, root.Position)
            rimText = string.format(" rim=%d ahead=%d side=%d", distance, ahead or -99, aside or -99)
        end
    end
    local text = string.format(
        "state action=%s ball=%s armed=%s press=%s held=%s own=%s holdOk=%s early=%s pending=%s key=%s hook=%s shot=%s%s",
        tostring(action), tostring(Court.HasBall), tostring(self.Armed), tostring(self.Press ~= nil), tostring(self.Held ~= nil),
        tostring(self.Own), tostring(self.HoldOk), tostring(self.EarlyAt ~= nil), tostring(self.PressPending == true),
        tostring(self.KeyDown), tostring(self.HookMode or self.HookFailed), if shot then (shot.Kind or "?") else "none",
        if shot and shot.Fired then " fired" else ""
    ) .. rimText
    if text ~= self.TraceLast then
        self.TraceLast = text
        self:trace(text)
    end
    if self.TraceDirty and now - (self.TraceFlush or 0) > 0.5 then
        self.TraceFlush = now
        self.TraceDirty = false
        if type(writefile) == "function" then
            pcall(writefile, LOG_FILE, table.concat(self.TraceLines, "\n"))
        end
    end
end

function AutoGreen.new(read: (string) -> any, notify: (string) -> ()): any
    return setmetatable({
        Read = read,
        Notify = notify,
        Links = {} :: { any },
        Meters = {} :: { any },
        Character = nil :: any,
        Shot = nil :: any,
        LastAuto = -math.huge,
        LastPress = -math.huge,
        IdleAt = 0,
        LostAt = nil :: any,
        Warned = {} :: Map,
        Press = nil :: any,
        Held = nil :: any,
        Own = false,
        Armed = false,
        HasBall = false,
        HoldOk = false,
        KeyDown = nil :: any,
        LastKind = nil :: any,
        Hooked = false,
        HookBound = false,
        HookMode = nil :: any,
        TriedHook = false,
        Binding = false,
        HookCheck = 0,
        HookFailed = nil :: any,
        Stopped = false,
        Feedback = nil :: any,
        Stats = { Total = 0, Perfect = 0, Streak = 0, Last = "-" },
        Rates = {} :: { [string]: number },
        StatsText = nil :: any,
    }, AutoGreen)
end

function AutoGreen.allowed(self: any): boolean
    local root = Court.Root
    if not root then
        return true
    end
    local read = self.Read
    if read("AutoShoot") ~= true then
        return true
    end
    if read("OpenOnly") == true and Court.nearestFoe(root.Position) <= (read("OpenRange") or 6) then
        return false
    end
    local minimum = read("MinShot") or 0
    local maximum = read("MaxShot") or 120
    if minimum > 0 or maximum < 120 then
        local best = Court.rimDistance(root.Position)
        if best and (best < minimum or best > maximum) then
            return false
        end
    end
    return true
end

function AutoGreen.peak(self: any, kind: string): number?
    local value = Config.PEAKS[kind] or learned()[kind]
    return if type(value) == "number" then value else nil
end

function AutoGreen.canHold(self: any): boolean
    return self:allowed()
end

function AutoGreen.fire(self: any, args: Map): boolean
    local remote = Court.input("Shoot")
    if not remote then
        if not self.Warned.Remote then
            self.Warned.Remote = true
            self.Notify("The shoot remote was not found, Auto Green cannot release")
        end
        return false
    end
    return Court.send(remote, args)
end

function AutoGreen.send(self: any)
    self:trace("  SEND release")
    self.Planned = self.NextPlan
    self.NextPlan = nil
    self.Press = nil
    self.Held = nil
    self.Own = false
    self.LostAt = nil
    local shot: any = self.Shot
    if shot then
        shot.Fired = true
    end
    if self:fire(RELEASE) then
        self.LastAuto = os.clock()
    end
end

function AutoGreen.settle(self: any)
    self:trace("  settle held=" .. tostring(self.Held ~= nil))
    if self.Held ~= nil then
        self:send()
    else
        self.Press = nil
        self.Own = false
        self.LostAt = nil
    end
end

function AutoGreen.release(self: any)
    local shot: any = self.Shot
    if not shot or shot.Fired then
        return
    end
    shot.Fired = true
    local character = self.Character
    if not character or not liveShot(character, character:GetAttribute("Action"), self.Meters) then
        self:settle()
        return
    end
    local steady = (shot.Gap or 0) < STALL and (shot.LongFrame or 0) < STALL
    self.NextPlan = { Kind = shot.Kind, Clean = shot.ReleaseAt ~= nil and shot.Timed == true and shot.Sloppy == nil and steady }
    self:send()
    if shot.NewRate and shot.Kind then
        local store = learned()
        store["#" .. shot.Kind] = shot.NewRate
        Env.writeJson(PEAK_FILE, store)
    end
end

function AutoGreen.onPress(self: any)
    local read = self.Read
    if self.Stopped or read("AutoGreen") ~= true then
        self:trace("  onPress ignored, Auto Green off")
        return
    end
    local mine = Court.mine()
    if not mine or (not Court.holds(mine) and not PRESHOT[mine:GetAttribute("Action")]) then
        if mine and (self.KeyDown == true or self.Held ~= nil) then
            self.EarlyAt = os.clock()
        end
        self:trace("  onPress no ball yet, early=" .. tostring(self.EarlyAt ~= nil))
        return
    end
    self.EarlyAt = nil
    local shot: any = self.Shot
    if shot and shot.Fired then
        self:trace("  onPress ignored, shot already fired")
        return
    end
    if self.Press ~= nil then
        self:trace("  onPress repeat, already owned")
        return
    end
    local now = os.clock()
    self.Press = now
    self.LastPress = now
    self.IdleAt = now
    self.LostAt = nil
    self.HoldOk = false
    self:trace("  onPress OWNED, hold E")
end

function AutoGreen.begin(self: any, useSpace: boolean?): boolean
    if self.Stopped or self.Read("AutoGreen") ~= true or self.Press ~= nil or not self:canHold() then
        return false
    end
    self:onPress()
    local press = self.Press
    if press == nil then
        return false
    end
    if not self:fire(if useSpace then PRESS_SPACE else PRESS) then
        self.Press = nil
        return false
    end
    self.Held = press
    self.DunkPress = useSpace == true
    self.Own = true
    self.HoldOk = true
    return true
end

function AutoGreen.earlyWindow(self: any): number
    return math.max(0.3, math.min(Court.Ping, 0.6) + 0.15)
end

function AutoGreen.holding(self: any): boolean
    if self.Armed ~= true then
        return false
    end
    local early = self.EarlyAt
    if early ~= nil and self.Press == nil and os.clock() - early < self:earlyWindow() then
        return true
    end
    if self.PressPending == true and self.Press == nil then
        return self.HoldMode ~= true
    end
    return self.Press ~= nil and self.HoldOk == true
end

function AutoGreen.shootCall(self: any, data: any): boolean
    if type(data) ~= "table" then
        return false
    end
    local flag = rawget(data, "Shoot")
    if self.Tracing then
        self:trace(string.format("CALL Shoot=%s Input=%s UseSpace=%s", tostring(flag), tostring(rawget(data, "Input")), tostring(rawget(data, "UseSpace"))))
    end
    if flag == true then
        self.KeyDown = true
        self.DunkPress = rawget(data, "UseSpace") == true
        self:onPress()
        return false
    end
    if flag ~= false then
        return false
    end
    self.KeyDown = false
    if rawget(data, "Input") ~= nil then
        self.TapAt = os.clock()
        self.TapPending = true
        return false
    end
    if self:holding() then
        if self.Held == nil then
            self.Held = os.clock()
        end
        self:trace("  release HELD back")
        return true
    end
    self:trace("  release passed through")
    self:passed()
    return false
end

function AutoGreen.passed(self: any)
    if self.Held == nil then
        self.Press = nil
        self.LostAt = nil
    end
end

function AutoGreen.sample(self: any, character: any)
    if character ~= self.Character then
        return
    end
    local offset: any = character:GetAttribute("meterOffset")
    local kindOf = typeof(offset)
    if kindOf ~= "Vector2" then
        return
    end
    local value: number = offset.Y
    local action = character:GetAttribute("Action")
    if not liveShot(character, action, self.Meters) then
        self.Shot = nil
        return
    end
    local now = os.clock()
    local read = self.Read
    local shot: any = self.Shot
    if not shot then
        local sloppy: number? = nil
        if math.random() > (read("PerfectChance") or 100) / 100 then
            sloppy = (if math.random() < 0.5 then -1 else 1) * (0.04 + math.random() * 0.05)
        end
        local nearRim = false
        if not self.Own and read("LayupGreen") == false then
            local root = Court.root(character)
            local rimAt = if root then Court.rimDistance(root.Position) else nil
            nearRim = rimAt ~= nil and rimAt <= LAYUP_RANGE
        end
        self.Shot = {
            T0 = now,
            V0 = value,
            Low = value,
            Scale = shotSpeed(character),
            Fired = false,
            Kind = nil,
            Sloppy = sloppy,
            Timed = not nearRim and self:allowed(),
            DunkAt = if action == "Dunking" then now + DUNK_TIMEOUT else nil,
        }
        return
    end
    if value < shot.Low then
        shot.Low = value
    end
    if not shot.Fired then
        shot.Gap = math.max(shot.Gap or 0, now - (shot.SeenAt or now))
        shot.SeenAt = now
    end
    if value - shot.Low > 0.012 then
        shot.Turned = true
    elseif not shot.Turned and now > shot.T0 then
        local at = now - shot.T0
        if not shot.Ln then
            shot.Ln, shot.Lt, shot.Lv, shot.Ltt, shot.Ltv = 1, 0, shot.V0, 0, 0
        end
        shot.Ln += 1
        shot.Lt += at
        shot.Lv += value
        shot.Ltt += at * at
        shot.Ltv += at * value
    end
    if shot.Fired then
        if shot.Kind and not shot.NewRate and not shot.Turned and (shot.Ln or 0) >= 8 then
            self:learnRate(shot)
        end
        return
    end
    if read("AutoGreen") ~= true or not shot.Timed then
        if self.Held ~= nil then
            self:release()
        end
        return
    end
    local elapsed = now - shot.T0
    if elapsed < 0.02 then
        if now == shot.T0 then
            shot.V0 = value
        end
        return
    end
    local kind: string = shot.Kind or meterKind(character, self.Meters) or ""
    if kind == "" then
        if elapsed < 0.12 then
            return
        end
        kind = if action == "Dunking" then "Dunk" else "Shot"
    end
    if not shot.Kind then
        shot.Kind = kind
        self.LastKind = kind
    end
    local peak = self:peak(kind)
    if not peak then
        if value - shot.Low > 0.012 then
            local store = learned()
            store[kind] = shot.Low
            Env.writeJson(PEAK_FILE, store)
            self:release()
        end
        return
    end
    if value - shot.Low > 0.012 then
        self:release()
        return
    end
    shot.Peak = peak
    shot.Latest = value
    shot.Fresh = true
end

function AutoGreen.plan(self: any, now: number)
    local shot: any = self.Shot
    shot.Fresh = false
    local value: number = shot.Latest
    local peak: number = shot.Peak
    local kind: string = shot.Kind
    local read = self.Read
    local elapsed = now - shot.T0
    if not shot.N then
        shot.N, shot.St, shot.Sv, shot.Stt, shot.Stv = 1, 0, shot.V0, 0, 0
    end
    shot.N += 1
    shot.St += elapsed
    shot.Sv += value
    shot.Stt += elapsed * elapsed
    shot.Stv += elapsed * value
    local speed = (value - shot.V0) / elapsed
    local level = value
    local spread = shot.N * shot.Stt - shot.St * shot.St
    local saved = learned()["#" .. kind]
    local scale: number = shot.Scale or 1
    local base: number? = self.Rates[kind] or (if type(saved) == "number" then saved else nil)
    local known: number? = if base then base * scale else nil
    if shot.N >= 6 and spread > 1e-9 then
        speed = (shot.N * shot.Stv - shot.St * shot.Sv) / spread
        level = (shot.Sv - speed * shot.St) / shot.N + speed * elapsed
        if shot.N >= 8 then
            local measured = speed / scale
            self.Rates[kind] = if base then base + (measured - base) * 0.5 else measured
            shot.NewRate = self.Rates[kind]
        end
    elseif known then
        speed = known
        level = (shot.Sv - speed * shot.St) / shot.N + speed * elapsed
    elseif shot.N >= 4 and spread > 1e-9 then
        speed = (shot.N * shot.Stv - shot.St * shot.Sv) / spread
        level = (shot.Sv - speed * shot.St) / shot.N + speed * elapsed
    end
    if speed >= -0.05 or shot.Frozen then
        return
    end
    local remaining = (peak - level) / speed
    local delay = remaining - math.min(self.FrameDt or 0, 1 / 60) * 0.5 - SERVER_STEP * 0.5 - Court.Ping * (read("PingComp") or 100) / 100 + (read("GreenOffset") or 0) / 1000 + (shot.Sloppy or 0) + self:bias(kind)
    shot.Value = value
    shot.SampleAt = now
    shot.Speed = speed
    shot.Peak = peak
    local trusted = shot.N >= 6 or known ~= nil
    if not trusted and shot.N < 3 then
        return
    end
    shot.ReleaseAt = now + delay
    if delay <= 0 then
        self:release()
    elseif delay < 0.03 and trusted then
        shot.Frozen = true
    end
end

function AutoGreen.learnRate(self: any, shot: any)
    local n = shot.Ln
    local spread = n * shot.Ltt - shot.Lt * shot.Lt
    if spread <= 1e-9 then
        return
    end
    local speed = (n * shot.Ltv - shot.Lt * shot.Lv) / spread
    if speed >= -0.05 then
        return
    end
    local kind: string = shot.Kind
    local measured = speed / (shot.Scale or 1)
    local saved = learned()["#" .. kind]
    local base: number? = self.Rates[kind] or (if type(saved) == "number" then saved else nil)
    self.Rates[kind] = if base then base + (measured - base) * 0.5 else measured
    shot.NewRate = self.Rates[kind]
    local store = learned()
    store["#" .. kind] = shot.NewRate
    Env.writeJson(PEAK_FILE, store)
end

function AutoGreen.bias(self: any, kind: string): number
    if self.Read("AutoCalibrate") == false then
        return 0
    end
    local value = learned()["~" .. kind]
    return if type(value) == "number" then value else 0
end

local CALIBRATION = { [1] = 0.018, [2] = 0.009, [3] = 0.0035, [6] = -0.0035, [7] = -0.009, [8] = -0.018 }

function AutoGreen.calibrate(self: any, kind: string?, timing: number)
    local step = CALIBRATION[timing]
    if not kind or kind == "" or not step or self.Read("AutoCalibrate") == false then
        return
    end
    local store = learned()
    local key = "~" .. kind
    local current = if type(store[key]) == "number" then store[key] else 0
    store[key] = math.clamp(current * 0.97 + step, -0.08, 0.08)
    Env.writeJson(PEAK_FILE, store)
end

function AutoGreen.resetCalibration(self: any)
    local store = learned()
    local keys: { string } = {}
    for key, value in store do
        if type(key) == "string" and (string.sub(key, 1, 1) == "~" or type(value) == "number") then
            table.insert(keys, key)
        end
    end
    for _, key in keys do
        store[key] = nil
    end
    local saved = Env.writeJson(PEAK_FILE, store)
    pcall(self.Notify, if saved then "Calibration reset" else "Calibration reset, could not save the file")
end

function AutoGreen.rated(self: any, timing: number)
    local shot: any = self.Shot
    local mine = os.clock() - self.LastAuto < 2
    local plan: any = self.Planned
    self.Planned = nil
    if mine and plan and plan.Clean and plan.Kind then
        self:calibrate(plan.Kind, timing)
    end
    if shot and shot.Kind and timing == TIMING_PERFECT and not self:peak(shot.Kind) then
        local store = learned()
        store[shot.Kind] = shot.Low
        Env.writeJson(PEAK_FILE, store)
    end
    local record = self.Stats
    self.StatsText = nil
    record.Total += 1
    record.Last = Config.TIMINGS[timing] or "?"
    if self.Read("NotifyRelease") == true and mine then
        self.Notify(record.Last)
    end
    if timing == TIMING_PERFECT then
        record.Perfect += 1
        record.Streak += 1
    else
        record.Streak = 0
    end
end

function AutoGreen.detach(self: any)
    for _, link in self.Links do
        pcall(link.Disconnect, link)
    end
    table.clear(self.Links)
    table.clear(self.Meters)
    if self.Press ~= nil or self.Held ~= nil then
        self:settle()
    end
    self.Character = nil
    self.Shot = nil
end

function AutoGreen.attach(self: any, character: any)
    self:detach()
    if not character or self.Stopped then
        return
    end
    self.Character = character
    local links: { any } = self.Links
    local meters: { any } = self.Meters
    local function consider(descendant: any)
        if descendant:IsA("BillboardGui") and not table.find(meters, descendant) then
            table.insert(meters, descendant)
        end
    end
    table.insert(links, character:GetAttributeChangedSignal("meterOffset"):Connect(function()
        self:sample(character)
    end))
    table.insert(links, character:GetAttributeChangedSignal("Action"):Connect(function()
        if self.Character == character and self.Shot and not liveShot(character, character:GetAttribute("Action"), meters) then
            self.Shot = nil
        end
    end))
    table.insert(links, character:GetAttributeChangedSignal("ReleasedShot"):Connect(function()
        local shot: any = self.Shot
        if shot and self.Character == character and character:GetAttribute("ReleasedShot") == true then
            shot.ReleasedAt = os.clock()
        end
    end))
    table.insert(links, character.DescendantAdded:Connect(consider))
    for _, descendant in character:GetDescendants() do
        consider(descendant)
    end
end

function AutoGreen.step(self: any, now: number, dt: number)
    local on = self.Read("AutoGreen") == true
    local action0 = Court.Action
    local character = Court.Mine
    if character ~= self.Character then
        self:attach(character)
    end
    self.Armed = on and character ~= nil
    self.HasBall = on and Court.HasBall
    self.Tracing = Env.get("PBGreenLog") == true
    if self.Tracing then
        self:traceState(now, action0)
    end
    self.HoldMode = true
    if self.Hooked then
        Hook.drain()
    end
    self.FrameDt = math.min(dt, 0.1)
    local watch: any = self.WatchHook
    if watch then
        watch.Sum += dt
        watch.Count += 1
        if now >= watch.Until then
            self.WatchHook = nil
            local average = watch.Sum / math.max(watch.Count, 1)
            if average > math.max(watch.Base * 1.8, 1 / 30) and self.HookMode == "hook" then
                pcall(Hook.remove)
                self.HookBound = false
                self.HookMode = nil
                self.HookFailed = "slow"
                self.Warned.Hook = true
                self.Notify("Auto Green turned its hook off, it slowed this executor down. Hold the shoot key until the green")
            end
        end
    else
        self.FrameAvg = (self.FrameAvg or dt) + (math.min(dt, 0.25) - (self.FrameAvg or dt)) * 0.05
    end
    if self.PressPending then
        self.PressPending = false
        self:onPress()
        if self.Held ~= nil and self.Press ~= nil and self.HoldOk ~= true then
            self:send()
        end
    end
    if self.TapPending then
        self.TapPending = false
        if on and self.Read("TapShoot") == true and Court.HasBall and self.Press == nil and self.Held == nil and self.Shot == nil
            and self.KeyDown ~= true and action0 ~= "Dribbling" and action0 ~= "Dunking" and action0 ~= "Shooting" then
            self:trace("  TAP turned into a shot, action=" .. tostring(action0))
            self:begin()
        else
            self:trace("  TAP left as it is, action=" .. tostring(action0))
        end
    end
    local early: number? = self.EarlyAt
    if early then
        if now - early > self:earlyWindow() or (self.KeyDown ~= true and self.Held == nil) or not on then
            self.EarlyAt = nil
        elseif Court.HasBall then
            self.EarlyAt = nil
            self:onPress()
        end
    end
    if self.Hooked and not self.HookFailed and now >= self.HookCheck then
        self.HookCheck = now + 2
        if self.HookBound and not Hook.owned(self) then
            self.HookBound = false
            self.Hooked = false
        end
    end
    if on and self.HookFailed and not self.Binding and now >= (self.WrapRetry or 0) and (self.Retries or 0) < 8 then
        self.Retries = (self.Retries or 0) + 1
        self.WrapRetry = now + 5 * self.Retries
        task.spawn(function()
            if self.Stopped or self.HookBound or self.Binding then
                return
            end
            self.Binding = true
            local ok, mode = Hook.bind(self, false, true)
            self.Binding = false
            if self.Stopped then
                pcall(Hook.remove)
            elseif ok then
                self.HookBound = true
                self.HookMode = mode
                self.HookFailed = nil
            end
        end)
    end
    if on and self.HookFailed and not self.HoldMode and not self.Warned.Hook and now >= (self.WarnAt or 0) then
        if not self.WarnAt then
            self.WarnAt = now + 1.5
        else
            self.Warned.Hook = true
            self.Notify("Hold the shoot key until the green on this executor, Auto Green lets go for you")
        end
    end
    local action = action0
    local live = character ~= nil and liveShot(character, action, self.Meters)
    local shot: any = self.Shot
    if shot then
        if not live or (shot.ReleasedAt and now - shot.ReleasedAt >= 1.5) then
            self.Shot = nil
            shot = nil
        elseif not shot.Fired and on then
            shot.LongFrame = math.max(shot.LongFrame or 0, dt)
            if shot.Fresh then
                self:plan(now)
            end
            local at: number? = if shot.Fired then nil else shot.ReleaseAt
            if at then
                if now + math.min(dt, 0.05) * 0.5 >= at then
                    self:release()
                end
            elseif shot.Timed and shot.DunkAt and now >= shot.DunkAt then
                self:release()
            end
        end
    end
    local press: number? = self.Press
    if press then
        if not on or not character then
            self:settle()
        else
            local waiting = WAITING[action] == true and (action ~= "Dribbling" or now - press < 1.2)
            local busy = self.Shot ~= nil or live or waiting
            if busy then
                self.IdleAt = now
            end
            local lost = self.Held ~= nil and not busy and not Court.HasBall
            if not lost then
                self.LostAt = nil
            elseif not self.LostAt then
                self.LostAt = now
            end
            local limit = TAP_TIMEOUT
            if Court.HasBall and not busy then
                local root = Court.Root
                local rimAt = if root then Court.rimDistance(root.Position) else nil
                if rimAt ~= nil and rimAt <= 45 then
                    limit = 2
                end
            end
            if action == "Dunking" and self.Held ~= nil then
                self.DunkSince = self.DunkSince or now
                if now - self.DunkSince >= 0.9 then
                    self.DunkSince = nil
                    self:send()
                    return
                end
            else
                self.DunkSince = nil
            end
            if now - self.IdleAt >= limit or now - press >= HOLD_TIMEOUT or (lost and now - self.LostAt >= LOST_GRACE) then
                self:settle()
            end
        end
    elseif self.Held ~= nil and self.EarlyAt == nil then
        self:send()
    end
end

function AutoGreen.greenWindow(self: any, now: number): boolean
    local shot: any = self.Shot
    if shot and not shot.Fired and shot.ReleaseAt and math.abs(shot.ReleaseAt - now) <= 0.08 then
        return true
    end
    return now - self.LastAuto < 0.35
end

function AutoGreen.hook(self: any, allowHook: boolean?)
    if self.Stopped or self.Binding or self.HookBound then
        return
    end
    if self.Hooked and (self.TriedHook or allowHook ~= true) then
        return
    end
    self.Binding = true
    local ok, mode = Hook.bind(self, allowHook == true)
    self.Binding = false
    if self.Stopped then
        pcall(Hook.remove)
        return
    end
    self.Hooked = true
    self.TriedHook = allowHook == true
    if ok then
        self.HookBound = true
        self.HookMode = mode
        self.HookFailed = nil
        if mode == "hook" then
            self.WatchHook = { Until = os.clock() + 3, Base = self.FrameAvg or (1 / 60), Sum = 0, Count = 0 }
        end
    else
        self.HookMode = nil
        self.HookFailed = mode or "unsupported"
    end
end

function AutoGreen.bind(self: any)
    task.spawn(function()
        local folder = Court.service("InterfaceService")
        local waited = 0
        while not folder and waited < 30 and not self.Stopped do
            waited += task.wait(1)
            folder = Court.service("InterfaceService")
        end
        if not folder or self.Stopped then
            return
        end
        local ok, remote = pcall(folder.WaitForChild, folder, "ShowFeedback", 30)
        if not ok or not remote or self.Stopped then
            return
        end
        self.Feedback = remote.OnClientEvent:Connect(function(character: any, _: any, timing: any)
            if character ~= nil and character == self.Character then
                local index = tonumber(timing)
                if index then
                    self:rated(index)
                end
            end
        end)
    end)
end

function AutoGreen.shutdown(self: any)
    self.Stopped = true
    self.Armed = false
    self.HasBall = false
    pcall(self.detach, self)
    self.Press = nil
    self.Held = nil
    local feedback = self.Feedback
    if feedback then
        self.Feedback = nil
        pcall(feedback.Disconnect, feedback)
    end
    pcall(Hook.remove)
end

return AutoGreen
end
modules["autopass"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")

local AutoPass = {}
AutoPass.__index = AutoPass

type Map = { [string]: any }

local players: any = game:GetService("Players")

local COOLDOWN = 1.5
local RETRY = 0.15
local OPEN = 8
local REACT_MIN = 0.2
local REACT_MAX = 0.4

local random = Random.new()

local function retarget(value: any, context: Map, depth: number): any
    local target, mine = context.Target, context.Mine
    local folder = mine.Parent
    if typeof(value) == "Instance" then
        if value:IsA("Player") then
            return players:FindFirstChild(target.Name) or value
        end
        if folder and value.Parent == folder and value ~= mine then
            return target
        end
        if folder and value:IsDescendantOf(folder) and not value:IsDescendantOf(mine) then
            return target:FindFirstChild(value.Name) or value
        end
        return value
    end
    if type(value) == "string" and folder and value ~= mine.Name and folder:FindFirstChild(value) then
        return target.Name
    end
    local kind = typeof(value)
    if kind == "Vector3" then
        local vector: any = value
        local theirs = Court.root(target)
        if theirs and vector.Magnitude > 2 then
            return theirs.Position
        end
        if theirs and vector.Magnitude > 0.01 then
            local aim = theirs.Position - context.Root.Position
            return if aim.Magnitude > 0.01 then aim.Unit * vector.Magnitude else vector
        end
        return vector
    end
    if type(value) == "table" and depth < 6 then
        local copy = {}
        for key, inner in value do
            copy[key] = retarget(inner, context, depth + 1)
        end
        return copy
    end
    return value
end

local function adapt(args: any, context: Map): any
    return retarget(args, context, 0)
end

local FORMS: { (any) -> ...any } = {
    function(context: any): ...any
        return { Player = context.Target.Name, PassType = 1 }
    end,
    function(context: any): ...any
        return context.Target
    end,
    function(context: any): ...any
        return context.Target.Name
    end,
}

local function passing(context: Map): boolean
    local mine = context.Mine
    return mine.Parent ~= nil and mine:GetAttribute("Action") == "Passing"
end

function AutoPass.new(read: (string) -> any): any
    return setmetatable({ Read = read, Last = -math.huge, Since = nil :: number?, React = REACT_MIN, Context = {} :: Map }, AutoPass)
end

local function pick(here: Vector3, openRange: number): any?
    local best: any? = nil
    local bestScore = -math.huge
    local chars, roots, foe = Court.Chars, Court.Roots, Court.Foe
    for index = 1, Court.Count do
        if not foe[index] then
            local theirs: Vector3 = roots[index].Position
            local distance = (theirs - here).Magnitude
            if distance >= 6 and distance <= 60 then
                local open = Court.nearestFoe(theirs)
                if open > openRange then
                    local rim = Court.rimDistance(theirs)
                    local score = math.min(open, 20) * 2 - distance * 0.4 - (rim or 0) * 0.3
                    if score > bestScore then
                        best = chars[index]
                        bestScore = score
                    end
                end
            end
        end
    end
    return best
end

function AutoPass.step(self: any, now: number)
    local read = self.Read
    if read("AutoPass") ~= true or now - self.Last < COOLDOWN then
        self.Since = nil
        return
    end
    local mine, root = Court.Mine, Court.Root
    if not mine or not root or not Court.HasBall then
        self.Since = nil
        return
    end
    local action = Court.Action
    if action == "Dribbling" then
        return
    end
    if (action ~= "" and action ~= nil) or not Court.free(mine) or Court.HandsOff then
        self.Since = nil
        return
    end
    local here: Vector3 = root.Position
    if Court.nearestFoe(here) > (read("PassPressure") or 6) then
        self.Since = nil
        return
    end
    local since = self.Since
    if not since then
        self.Since = now
        self.React = REACT_MIN + random:NextNumber() * (REACT_MAX - REACT_MIN)
        return
    end
    if now - since < self.React then
        return
    end
    self.Since = nil
    local target = pick(here, OPEN)
    if not target then
        self.Last = now - COOLDOWN + RETRY
        return
    end
    self.Last = now
    local context: Map = self.Context
    context.Target = target
    context.Mine = mine
    context.Root = root
    Court.fire("Pass", FORMS, passing, adapt, context)
end

return AutoPass
end
modules["autorebound"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")

local AutoRebound = {}
AutoRebound.__index = AutoRebound

local COOLDOWN = 1.2
local REACT_MIN = 0.08
local REACT_MAX = 0.2

local random = Random.new()

function AutoRebound.new(read: (string) -> any): any
    return setmetatable({ Read = read, Last = -math.huge, Since = nil :: number?, React = REACT_MIN }, AutoRebound)
end

local function ready(self: any): boolean
    local root = Court.Root
    local mine = Court.Mine
    if not root or not mine or Court.HasBall or Court.TeamBall or Court.FoeBall or Court.Dead or Court.HandsOff then
        return false
    end
    local action = Court.Action
    if (action ~= "" and action ~= nil) or not Court.free(mine) then
        return false
    end
    local ball = Court.ball()
    if not ball then
        return false
    end
    local where: Vector3 = ball.Position
    local velocity: Vector3 = ball.AssemblyLinearVelocity
    local offset: Vector3 = where - root.Position
    local high = offset.Y
    if math.sqrt(offset.X * offset.X + offset.Z * offset.Z) > (self.Read("ReboundRange") or 8) or high < 2 or high > 12 or velocity.Y > 4 then
        return false
    end
    local _, rim = Court.rimDistance(where)
    if rim then
        local toRim = Vector3.new(rim.Position.X - where.X, 0, rim.Position.Z - where.Z)
        local away = toRim.Magnitude
        if away > 0.5 and away < 30 and where.Y > rim.Position.Y - 1.5 and (velocity.X * toRim.X + velocity.Z * toRim.Z) / away > 2 then
            return false
        end
    end
    return true
end

function AutoRebound.step(self: any, now: number)
    if self.Read("AutoRebound") ~= true or now - self.Last < COOLDOWN or not ready(self) then
        self.Since = nil
        return
    end
    local since = self.Since
    if not since then
        self.Since = now
        self.React = REACT_MIN + random:NextNumber() * (REACT_MAX - REACT_MIN)
        return
    end
    if now - since < self.React then
        return
    end
    local remote = Court.input("Jump")
    if not remote then
        return
    end
    self.Last = now
    self.Since = nil
    Court.send(remote)
end

return AutoRebound
end
modules["autoshoot"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")

local AutoShoot = {}
AutoShoot.__index = AutoShoot

local COOLDOWN = 1.6
local RETRY = 0.25
local LAYUP_RANGE = 13
local JITTER = 0.15
local SETTLE = 0.2

local random = Random.new()

function AutoShoot.new(read: (string) -> any, autoGreen: any): any
    return setmetatable({ Read = read, AutoGreen = autoGreen, AutoDunk = nil :: any, Defense = nil :: any, Contest = nil :: any, Last = -math.huge, Since = nil :: number?, GroundAt = nil :: number?, Jitter = 0 }, AutoShoot)
end

local function target(root: any, range: number, attack: any?): (any?, number)
    local near, closest = Court.rimDistance(root.Position)
    if not near or not closest or (attack and closest ~= attack) then
        return nil, math.huge
    end
    local rim, distance = Court.facingRim(root, 0.2, range)
    if rim == closest then
        return rim, distance
    end
    if near <= LAYUP_RANGE then
        return closest, near
    end
    return nil, math.huge
end

local function grounded(mine: any, root: any): boolean
    local humanoid = Court.humanoid(mine)
    if humanoid and humanoid.FloorMaterial == Enum.Material.Air and math.abs(root.AssemblyLinearVelocity.Y) > 2 then
        return false
    end
    return true
end

function AutoShoot.step(self: any, now: number)
    local read = self.Read
    if read("AutoShoot") ~= true or read("AutoGreen") ~= true then
        self.Since = nil
        return
    end
    local mine, root = Court.Mine, Court.Root
    if not mine or not root or not Court.HasBall then
        self.Since = nil
        self.GroundAt = nil
        return
    end
    if not self.Since then
        self.Since = now
        self.Jitter = random:NextNumber(-JITTER, JITTER)
    end
    if not grounded(mine, root) then
        self.GroundAt = nil
        return
    end
    if not self.GroundAt then
        self.GroundAt = now
    end
    local hold = math.max(0, (read("ShootDelay") or 300) * (1 + self.Jitter))
    if now - self.Last < COOLDOWN or now - self.Since < hold / 1000 or now - self.GroundAt < SETTLE then
        return
    end
    local action = Court.Action
    if (action ~= "" and action ~= "Dribbling" and action ~= nil) or not Court.free(mine) or Court.forced(mine) or Court.HandsOff then
        return
    end
    local defense = self.Defense
    local rim, distance = target(root, read("ShootRange") or 24, if defense then defense:attackRim() else nil)
    if not rim then
        return
    end
    local dunk = self.AutoDunk
    if dunk and read("AutoDunk") == true and dunk:claims(distance) then
        return
    end
    if distance < (read("MinShot") or 0) or distance > (read("ShootRange") or 24) then
        return
    end
    if distance <= LAYUP_RANGE then
        local ahead = Court.frontOf(rim, root.Position)
        if ahead and ahead < -1 then
            return
        end
    end
    if Court.nearestFoe(root.Position) <= (read("OpenRange") or 6) then
        return
    end
    local contest = self.Contest
    if contest and contest:estimate(root) > (tonumber(read("MaxContest")) or 35) / 100 then
        return
    end
    if self.AutoGreen:begin(false) then
        self.Last = now
    else
        self.Last = now - COOLDOWN + RETRY
    end
end

return AutoShoot
end
modules["ballmagnet"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")
local Drive: typeof(require("./drive")) = import("drive")

local BallMagnet = {}
BallMagnet.__index = BallMagnet

local BUSY: { [string]: boolean } = { Passing = true, CatchingPass = true, AwaitingPass = true, PassTransition = true, CatchingLob = true, Shooting = true, Inbounding = true, Gathering = true }
local SPRINT_BONUS = 3.35
local SLOW = 6

function BallMagnet.new(read: (string) -> any): any
    return setmetatable({ Read = read, Chasing = false, LastBusy = -math.huge, LastLive = -math.huge }, BallMagnet)
end

local function busy(action: any): boolean
    if type(action) ~= "string" then
        return false
    end
    return BUSY[action] == true or string.find(action, "Inbound", 1, true) ~= nil
end

local function inFlight(): boolean
    if busy(Court.Action) then
        return true
    end
    local chars = Court.Chars
    for index = 1, Court.Count do
        if busy(chars[index]:GetAttribute("Action")) then
            return true
        end
    end
    return false
end

function BallMagnet.stop(self: any)
    if self.Chasing then
        self.Chasing = false
        Drive.clear("Magnet")
    end
end

function BallMagnet.step(self: any, now: number)
    if self.Read("BallMagnet") ~= true then
        self:stop()
        return
    end
    local mine, root = Court.Mine, Court.Root
    if not mine or not root then
        self:stop()
        return
    end
    if inFlight() then
        self.LastBusy = now
    end
    local action = Court.Action
    if Court.HasBall or Court.TeamBall or Court.FoeBall or Court.Dead or Court.HandsOff or now - self.LastBusy < 2 or (action ~= "" and action ~= nil) or not Court.free(mine) then
        self:stop()
        return
    end
    local ball = Court.ball()
    if not ball then
        self:stop()
        return
    end
    local here: Vector3 = root.Position
    local where: Vector3 = ball.Position
    local velocity: Vector3 = ball.AssemblyLinearVelocity
    if velocity.Magnitude < 1 and not self.Chasing and now - self.LastLive > 1.5 then
        return
    end
    if velocity.Magnitude >= 1 then
        self.LastLive = now
    end
    local height = if self.Chasing then 6 else 4
    local fast = if self.Chasing then 30 else 22
    local distance = (where - here).Magnitude
    if distance > (self.Read("MagnetRange") or 12) or where.Y - here.Y > height or velocity.Magnitude > fast then
        self:stop()
        return
    end
    local drift = Vector3.new(velocity.X, 0, velocity.Z)
    local rolling = drift.Magnitude
    if rolling > SLOW then
        local toMe = Vector3.new(here.X - where.X, 0, here.Z - where.Z)
        if toMe.Magnitude >= 0.5 and drift:Dot(toMe.Unit) < rolling * 0.4 then
            self:stop()
            return
        end
    end
    local walk = mine:GetAttribute("WalkSpeed")
    local speed = math.clamp(if type(walk) == "number" then walk else 14, 8, 17)
    if distance > 6 and mine:GetAttribute("Sprinting") == true then
        speed += SPRINT_BONUS
    end
    self.Chasing = true
    Drive.set("Magnet", Vector3.new(where.X + velocity.X * 0.15, here.Y, where.Z + velocity.Z * 0.15), speed, true, false)
end

function BallMagnet.shutdown(self: any)
    self:stop()
end

return BallMagnet
end
modules["changelog"] = function(...)

local Changelog = {}

Changelog.VERSION = "1.2"
Changelog.DATE = "November 10, 2026"

type Group = { Mode: string, Added: { string }?, Changed: { string }?, Removed: { string }?, Fixed: { string }? }

Changelog.GROUPS = {
    {
        Mode = "General",
        Added = {
            "Added Presets, Casual, Legit and Full",
            "Added Auto Dunk, runs you to the rim and dunks for you",
            "Added Dunk support for Auto Green",
            "Added Shot Contest, shows how open your shot is",
            "Added Max Contest for Auto Shoot, it waits for an open shot",
            "Added Move Keys, your own key for every dribble move",
            "Added Play Combo, plays the combo once per key press",
            "Added Guard Only When Facing for Auto Guard",
            "Added Dribble Moves When Guarded",
            "Added separate settings for every glide",
            "Added stamina and ball handler to the ESP",
        },
        Changed = {
            "Reworked Auto Green, now press to green and works on more executors",
            "Reworked Auto Guard, moves you with W A S D and keeps a gap",
            "Reworked Move With Him, closes out and slides with your man",
            "Reworked Auto Block, faster and ignores pump fakes",
            "Reworked Auto Shoot, Auto Pass and Auto Dunk, they pick better moments",
            "Reworked Glides, each one follows its own move",
            "Reworked court visuals, ESP and the menu",
        },
        Removed = {
            "Removed Stamina Lock, the server keeps its own stamina",
            "Removed Tap Rescue, a quick tap of E stays a pump fake",
            "Removed Shot Stats and Meter Overlay",
        },
        Fixed = {
            "Fixed Auto Shoot shooting from your own half or while contested",
            "Fixed Auto Guard not walking to the player and stopping every possession",
            "Fixed Auto Steal in the tutorial",
            "Fixed Shot Glide doing nothing on a running shot",
            "Fixed fake shot into step back shooting",
            "Fixed layup jelly",
            "Fixed freezing after a foul or dead ball",
            "Fixed low FPS with the court visuals and ESP on",
        },
    },
} :: { Group }

Changelog.HISTORY = {
    {
        Version = "1",
        Date = "November 4, 2026",
        Groups = {
            {
                Mode = "General",
                Added = {
                    "Released",
                },
            },
            {
                Mode = "Offense",
                Added = {
                    "Auto Green",
                    "Auto Shoot",
                    "Auto Pass To Teammates",
                    "Auto Dribble when Guarded",
                },
            },
            {
                Mode = "Defense",
                Added = {
                    "Auto Steal",
                    "Auto Guard",
                    "Auto Block",
                    "Auto Rebound",
                    "Ball Magnet",
                },
            },
            {
                Mode = "Player",
                Added = {
                    "Always Sprint",
                    "Custom Walkspeed",
                    "No Stun",
                    "No Debounce",
                    "No Cold Zone",
                },
            },
            {
                Mode = "Visuals",
                Added = {
                    "Visuals for features, players and court parts",
                },
            },
        },
    },
} :: { { Version: string, Date: string, Lines: { string }?, Groups: { Group }? } }

Changelog.CLOSING = "please join the discord server c:"

Changelog.OPEN = "General"

return Changelog
end
modules["combo"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")
local Court: typeof(require("./court")) = import("court")

local Combo = {}
Combo.__index = Combo

local INPUTS = Config.MOVE_INPUTS

local START = 0.45
local GAP_MIN = 0.15
local GAP_MAX = 0.3
local REST = 0.4
local RIM_CLEAR = 24
local ONCE_WAIT = 1.2

local random = Random.new()

function Combo.new(read: (string) -> any, set: ((string, any) -> ())?): any
    return setmetatable({ Read = read, Set = set, Index = 0, WaitUntil = 0, Seen = true, Done = false, FreeAt = nil :: number?, Rest = false, Gap = GAP_MIN, Once = nil :: number? }, Combo)
end

function Combo.reset(self: any)
    self.Index = 0
    self.Rest = false
    self.FreeAt = nil
end

function Combo.playOnce(self: any)
    self.Once = os.clock()
    self.Done = false
    self:reset()
end

function Combo.finish(self: any)
    self.Done = false
    self:reset()
    if self.Once then
        self.Once = nil
        return
    end
    local set = self.Set
    if set then
        pcall(set, "DribbleCombo", false)
    end
end

function Combo.step(self: any, now: number)
    local read = self.Read
    local mine, root = Court.Mine, Court.Root
    local once: number? = self.Once
    local looping = read("DribbleCombo") == true
    if not looping and not once then
        self.Done = false
        self:reset()
        return
    end
    local function stop()
        if self.Done then
            self:finish()
        end
        self:reset()
        if once and self.Index == 0 and now - once > ONCE_WAIT then
            self.Once = nil
        end
    end
    if not mine or not root or not Court.HasBall then
        stop()
        return
    end
    local here: Vector3 = root.Position
    local rimDistance = Court.rimDistance(here)
    if rimDistance and rimDistance < RIM_CLEAR then
        stop()
        return
    end
    if not once and read("ComboGuarded") == true and Court.nearestFoe(here) > (read("DribbleRange") or 7) then
        stop()
        return
    end
    local action = Court.Action
    if action ~= "" and action ~= nil then
        self.Seen = true
        self.FreeAt = nil
        return
    end
    if mine:GetAttribute("CanMove") == false or mine:GetAttribute("Debounce") == true or mine:GetAttribute("Stunned") == true or Court.HandsOff then
        return
    end
    if not self.Seen and now < self.WaitUntil then
        return
    end
    if self.Done and (once or read("ComboOnce") == true) then
        self:finish()
        return
    end
    local free: number = self.FreeAt or now
    self.FreeAt = free
    if now - free < (if self.Rest then REST else self.Gap) then
        return
    end
    local remote = Court.input("Dribble")
    if not remote then
        return
    end
    local chain = Config.COMBOS[read("ComboMoves")] or Config.COMBOS[Config.COMBO_NAMES[1]]
    self.Index = self.Index % #chain + 1
    self.Rest = self.Index == #chain
    if self.Rest and (once or read("ComboOnce") == true) then
        self.Done = true
    end
    local keys = INPUTS[chain[self.Index]]
    self.Gap = GAP_MIN + random:NextNumber() * (GAP_MAX - GAP_MIN)
    self.Seen = false
    self.WaitUntil = now + START
    self.FreeAt = nil
    if not keys then
        return
    end
    local sprint = Court.sprintHeld() or mine:GetAttribute("Sprinting") == true
    Court.send(remote, keys[if mine:GetAttribute("Hand") == "L" then "L" else "R"], sprint, Court.heading() or Vector3.zero)
end

return Combo
end
modules["config"] = function(...)

local Config = {}

Config.PEAKS = {
    Bat = -0.99,
    Funnel2 = -0.985,
    Rocket = -0.91,
    Vertical = -1.48,
} :: { [string]: number }

Config.GUARD_BALL = "Ball Handler"
Config.GUARD_NEAREST = "Nearest Player"
Config.GUARD_TARGETS = { Config.GUARD_BALL, Config.GUARD_NEAREST }

Config.COMBO_NAMES = { "Cross Tween", "Hesi Cross", "Behind Back Spin", "Double Cross Snatch", "Breakdown Stepback", "Half Spin Cross" }
Config.COMBOS = {
    ["Cross Tween"] = { "Crossover", "Tween", "Crossover" },
    ["Hesi Cross"] = { "Hesitation", "Crossover", "Hesitation" },
    ["Behind Back Spin"] = { "BehindBack", "Spin" },
    ["Double Cross Snatch"] = { "DoubleCrossover", "SnatchBack" },
    ["Breakdown Stepback"] = { "Breakdown", "Crossover", "StepBack" },
    ["Half Spin Cross"] = { "HalfSpin", "Crossover" },
} :: { [string]: { string } }

Config.MOVE_INPUTS = {
    Crossover = { R = "Z", L = "C" },
    Hesitation = { R = "C", L = "Z" },
    Tween = { R = "ZZ", L = "CC" },
    DoubleCrossover = { R = "CC", L = "ZZ" },
    BehindBack = { R = "CX", L = "ZX" },
    Spin = { R = "CXZ", L = "ZXC" },
    StepBack = { R = "X", L = "X" },
    SnatchBack = { R = "XX", L = "XX" },
    HalfSpin = { R = "V", L = "V" },
    Breakdown = { R = "VC", L = "VZ" },
} :: { [string]: { [string]: string } }

Config.MOVE_KEYS = {
    { "Crossover", "Crossover" },
    { "Hesitation", "Hesitation" },
    { "Tween", "Tween" },
    { "Double Cross", "DoubleCrossover" },
    { "Behind Back", "BehindBack" },
    { "Spin", "Spin" },
    { "Step Back", "StepBack" },
    { "Snatch Back", "SnatchBack" },
    { "Half Spin", "HalfSpin" },
    { "Breakdown", "Breakdown" },
} :: { { string } }


Config.DUNK_BOTH = "Both"
Config.DUNK_DRIVING = "Driving Only"
Config.DUNK_STANDING = "Standing Only"
Config.DUNK_TYPES = { Config.DUNK_BOTH, Config.DUNK_DRIVING, Config.DUNK_STANDING }

Config.CONTEST_STYLES = { "Percent", "Bar" }
Config.CONTEST_COLORS = { "Contest Colors", "Custom" }

Config.TIMINGS = { "Very Early", "Early", "Slightly Early", "Good", "Perfect", "Slightly Late", "Late", "Very Late" }

Config.PARENT = {
    OpenShotGlow = "OpenShot", OpenShotNumber = "OpenShot", OpenShotBall = "OpenShot",
    ContestWho = "OpenShot", ContestFoeMark = "OpenShot",
    OpenOnly = "AutoShoot",
    DunkMove = "AutoDunk", DunkOpenOnly = "AutoDunk",
    GuardMove = "AutoGuard", GuardFacing = "AutoGuard",
    StealFacing = "AutoSteal", AvoidFouls = "AutoSteal",
    ReadFakes = "AutoBlock",
    BallMagnet = "AutoRebound",
    BlockDribbleKeys = "MoveKeys",
    ComboOnce = "DribbleCombo", ComboGuarded = "DribbleCombo",
    TapShoot = "AutoGreen", AutoCalibrate = "AutoGreen", RimFront = "AutoGreen", NotifyRelease = "AutoGreen", SafeMode = "AutoGreen",
    DribbleGlideSteer = "DribbleGlide", GatherGlideSteer = "GatherGlide", ShotGlideSteer = "ShotGlide",
    EspTeam = "Esp", EspStamina = "Esp", EspBallOnly = "Esp",
} :: { [string]: string }

Config.DEFAULTS = {
    AutoGreen = false,
    GreenOffset = 0,
    PingComp = 100,
    AutoCalibrate = true,
    SafeMode = false,
    TapShoot = false,
    LayupGreen = true,
    RimFront = true,
    NotifyRelease = false,
    PerfectChance = 100,
    OpenOnly = false,
    OpenRange = 6,
    MaxContest = 35,
    MinShot = 0,
    MaxShot = 120,
    AutoShoot = false,
    AutoDunk = false,
    DunkRange = 30,
    DunkType = "Both",
    DunkMove = false,
    DunkOpenOnly = false,
    ShootRange = 24,
    ShootDelay = 300,
    AutoSteal = false,
    StealRange = 8,
    AutoGuard = false,
    GuardRange = 7,
    GuardTarget = "Ball Handler",
    GuardMove = true,
    GuardGap = 16,
    GuardFacing = false,
    ReadFakes = true,
    StealFacing = true,
    AvoidFouls = true,
    AlwaysSprint = false,
    CustomSpeed = false,
    WalkSpeed = 16,
    NoStun = false,
    NoDebounce = false,
    NoCold = false,
    ThreePointLine = false,
    DunkZones = false,
    RangeViz = false,
    ShotRangeViz = false,
    ShotColor = Color3.fromRGB(255, 255, 255),
    StealColor = Color3.fromRGB(255, 90, 90),
    GuardColor = Color3.fromRGB(90, 160, 255),
    BlockColor = Color3.fromRGB(255, 200, 70),
    FullSpeed = false,
    AutoBlock = false,
    BlockRange = 10,
    BlockDelay = 0,
    AutoRebound = false,
    ReboundRange = 8,
    BallMagnet = false,
    MagnetRange = 12,
    AutoPass = false,
    PassPressure = 6,
    AutoDribble = false,
    DribbleRange = 7,
    DribbleCombo = false,
    ComboMoves = "Cross Tween",
    ComboGuarded = true,
    DribbleGlide = false,
    GatherGlide = false,
    ShotGlide = false,
    DribbleGlideSpeed = 5,
    DribbleGlideTime = 240,
    DribbleGlideStrength = 30,
    DribbleGlideSteer = false,
    GatherGlideSpeed = 14,
    GatherGlideTime = 500,
    GatherGlideStrength = 100,
    GatherGlideSteer = false,
    ShotGlideSpeed = 10,
    ShotGlideTime = 440,
    ShotGlideStrength = 60,
    ShotGlideSteer = false,
    ComboOnce = true,
    MoveKeys = false,
    BlockDribbleKeys = false,
    OpenShot = false,
    OpenShotGlow = true,
    OpenShotNumber = false,
    ContestStyle = "Percent",
    ContestWho = true,
    ContestFoeMark = false,
    ContestTextSize = 13,
    ContestHeight = 4.2,
    ContestColorMode = "Contest Colors",
    ContestLabelColor = Color3.fromRGB(255, 255, 255),
    ContestViewRange = 120,
    ContestOpacity = 0.85,
    GlowStrength = 60,
    OpenShotBall = true,
    ContestRange = 6,
    InfStamina = false,
    Esp = false,
    EspTeam = false,
    EspStamina = true,
    EspBallOnly = false,
    EspDistance = 300,
    EspTextSize = 13,
    EspBackground = 0.2,
    ColorEnemy = Color3.fromRGB(255, 105, 105),
    ColorTeam = Color3.fromRGB(105, 235, 135),
    ColorHolder = Color3.fromRGB(255, 215, 80),
    ColorBackground = Color3.fromRGB(16, 16, 22),
} :: { [string]: any }

return Config
end
modules["contest"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")
local Env: typeof(require("./env")) = import("env")

local Contest = {}
Contest.__index = Contest

local OPEN = Color3.fromRGB(70, 230, 110)
local CLOSE = Color3.fromRGB(255, 200, 70)
local TIGHT = Color3.fromRGB(255, 80, 80)
local DARK = Color3.fromRGB(14, 16, 20)
local EASE = 10
local FADE = 6
local FILL = 0.84
local OUTLINE = 0.3
local OPEN_BELOW = 0.35

local function holder(): any?
    local hui = Env.gethui
    if hui then
        local ok, folder = pcall(hui)
        if ok and folder then
            return folder
        end
    end
    local ok, core = pcall(game.GetService, game, "CoreGui")
    return if ok then core else nil
end

local function mix(from: Color3, to: Color3, share: number): Color3
    return Color3.new(from.R + (to.R - from.R) * share, from.G + (to.G - from.G) * share, from.B + (to.B - from.B) * share)
end

function Contest.new(read: (string) -> any, autoGreen: any?): any
    return setmetatable({ Read = read, AutoGreen = autoGreen, Light = nil :: any, Color = OPEN, Glow = 0, Value = 0, Gap = math.huge, Open = true }, Contest)
end

function Contest.measure(self: any, root: any): (number, number)
    local range: number = self.Read("ContestRange") or 6
    local here: Vector3 = root.Position
    local _, rim = Court.rimDistance(here)
    local toRim: Vector3? = nil
    if rim then
        local flat = Court.flat(rim.Position - here)
        toRim = if flat.Magnitude > 0.5 then flat.Unit else nil
    end
    local worst, gap = 0, math.huge
    local who, whoRoot = nil, nil
    local roots, foe, chars = Court.Roots, Court.Foe, Court.Chars
    for index = 1, Court.Count do
        if foe[index] then
            local offset = Court.flat(roots[index].Position - here)
            local distance = offset.Magnitude
            if distance < gap then
                gap = distance
            end
            if distance < range * 1.5 + 2 then
                local away = if distance > 0.1 then offset / distance else Vector3.zero
                local theirRoot = roots[index]
                local motion = Court.flat(theirRoot.AssemblyLinearVelocity)
                local closing = math.clamp(-motion:Dot(away), -6, 12)
                local effective = math.max(distance - closing * 0.15, 0)
                local closeness = math.clamp((range * 1.5 - effective) / range, 0, 1)
                local front = 0.6
                if toRim and distance > 0.1 then
                    front = 0.35 + 0.65 * math.clamp(away:Dot(toRim) * 0.5 + 0.5, 0, 1)
                end
                local look = Court.flat(theirRoot.CFrame.LookVector)
                local facing = if look.Magnitude > 0.1 and distance > 0.1 then math.clamp(-look.Unit:Dot(away) * 0.5 + 0.5, 0, 1) else 0.5
                local share = closeness * front * (0.6 + 0.4 * facing)
                if share > worst then
                    worst = share
                    who, whoRoot = chars[index], theirRoot
                end
            end
        end
    end
    self.Who, self.WhoRoot = who, whoRoot
    return worst, gap
end

function Contest.estimate(self: any, root: any): number
    local value, gap = self:measure(root)
    self.Value, self.Gap = value, gap
    return value
end

function Contest.clear(self: any)
    local light = self.Light
    if light then
        self.Light = nil
        pcall(light.Destroy, light)
    end
end

function Contest.shade(self: any): Color3
    if self.Open then
        return OPEN
    end
    return if self.Value < 0.65 then CLOSE else TIGHT
end

function Contest.step(self: any, now: number, dt: number)
    local read = self.Read
    local mine, root = Court.Mine, Court.Root
    local contestOn = read("OpenShot") == true
    if not mine or not root or not contestOn then
        if root and read("AutoShoot") == true then
            self:estimate(root)
        end
        self.Shown = false
        self.Glow = 0
        self:clear()
        return
    end
    local step = math.min(dt, 0.1)
    local value, gap = self:measure(root)
    self.Value, self.Gap = value, gap
    if self.Open then
        self.Open = value < OPEN_BELOW + 0.05
    else
        self.Open = value < OPEN_BELOW - 0.05
    end
    local ball = Court.HasBall
    local showing = contestOn and (read("OpenShotBall") ~= true or ball)
    self.Shown = showing
    local goal: Color3? = nil
    if showing and read("OpenShotGlow") == true then
        goal = self:shade()
    end
    self.Goal = goal
    if goal then
        self.Color = mix(self.Color, goal, 1 - math.exp(-EASE * step))
    end
    local strength = if goal then 1 else 0
    self.Glow += math.clamp(strength - self.Glow, -FADE * step, FADE * step)
    if self.Glow <= 0.005 then
        self:clear()
        return
    end
    local light = self.Light
    if (not light or light.Parent == nil or light.Adornee ~= mine) and now >= (self.RetryAt or 0) then
        self:clear()
        self.RetryAt = now + 2
        local ok, made = pcall(function(): any
            local item = Instance.new("Highlight")
            item.Name = "OpenShot"
            item.DepthMode = Enum.HighlightDepthMode.Occluded
            item.FillTransparency = 1
            item.OutlineTransparency = 1
            item.Adornee = mine
            item.Parent = holder() or mine
            return item
        end)
        light = if ok then made else nil
        self.Light = light
    end
    if light then
        local strength = math.clamp((tonumber(self.Read("GlowStrength")) or 60) / 100, 0.05, 1)
        local glow = self.Glow * strength
        light.FillColor = self.Color
        light.OutlineColor = self.Color
        light.FillTransparency = 1 - (1 - FILL) * glow
        light.OutlineTransparency = 1 - (1 - OUTLINE) * glow
    end
end

local function percentOf(value: number): string
    return math.floor(value * 100 + 0.5) .. "%"
end

local function wording(open: boolean, value: number): string
    if open then
        return "OPEN"
    end
    return if value < 0.65 then "CONTESTED" else "SMOTHERED"
end

local FOLLOW = 12
local REACH = 4

local function lift(self: any, key: string, want: number, dt: number): number
    local alpha: number = self[key] or 0
    alpha += math.clamp(want - alpha, -REACH * dt, REACH * dt)
    self[key] = alpha
    return alpha
end

function Contest.draw(self: any, canvas: any, chip: any)
    local read = self.Read
    local now = os.clock()
    local dt = math.clamp(now - (self.DrawAt or now), 0, 0.1)
    self.DrawAt = now
    local root = Court.Root
    local height = tonumber(read("ContestHeight")) or 4.2
    local range = tonumber(read("ContestViewRange")) or 120
    local opacity = math.clamp(tonumber(read("ContestOpacity")) or 0.85, 0.1, 1)
    local labelOn = self.Shown and root ~= nil and canvas ~= nil and chip ~= nil and read("OpenShotNumber") == true
    local point: Vector2? = nil
    local want = 0
    if labelOn then
        local found, depth = canvas.project(root.Position + Vector3.new(0, height, 0))
        if found and type(depth) == "number" and depth > 0 and depth <= range then
            point, want = found, opacity
        end
    end
    local alpha = lift(self, "LabelAlpha", want, dt)
    local follow = 1 - math.exp(-FOLLOW * dt)
    self.Eased = (self.Eased or self.Value) + (self.Value - (self.Eased or self.Value)) * follow
    local custom: any = read("ContestLabelColor")
    local goal = if read("ContestColorMode") == "Custom" and typeof(custom) == "Color3" then custom else self:shade()
    self.Tone = if self.Tone then mix(self.Tone, goal, follow) else goal
    local scale = math.clamp(tonumber(read("ContestTextSize")) or 13, 8, 30) / 13
    local number = percentOf(self.Eased)
    local tone: Color3 = self.Tone
    if alpha > 0.01 and point and chip then
        local who = self.Who
        local runs = { { Text = number, Color = "Text" } }
        if read("ContestWho") == true and who and not self.Open then
            runs[2] = { Text = "by " .. tostring(who.Name), Color = "Sub" }
        end
        self.LastPoint = point
        local shown = Vector2.new(point.X, point.Y - (1 - math.clamp(alpha / math.max(want, 0.1), 0, 1)) * 8)
        if read("ContestStyle") == "Bar" then
            chip("contest", shown, {}, alpha, scale, { Value = self.Eased, Color = tone, Only = true })
        else
            chip("contest", shown, { { { Text = wording(self.Open, self.Value), Color = tone } }, runs }, alpha, scale, nil)
        end
    end
    local theirs = self.WhoRoot
    local marking = labelOn and read("ContestFoeMark") == true and theirs ~= nil and not self.Open and theirs.Parent ~= nil
    local markPoint: Vector2? = nil
    local markWant = 0
    if marking then
        local found, depth = canvas.project(theirs.Position + Vector3.new(0, height, 0))
        if found and type(depth) == "number" and depth > 0 and depth <= range then
            markPoint, markWant = found, opacity
        end
    end
    local markAlpha = lift(self, "MarkAlpha", markWant, dt)
    if markAlpha > 0.01 and chip then
        local at = markPoint or self.MarkPoint
        if at then
            self.MarkPoint = at
            if read("ContestStyle") == "Bar" then
                chip("mark", at, {}, markAlpha, scale * 0.8, { Value = self.Eased, Color = tone, Only = true })
            else
                chip("mark", at, { { { Text = number, Color = tone } } }, markAlpha, scale * 0.8, nil)
            end
        end
    end
end

function Contest.shutdown(self: any)
    self.Shown = false
    self.Glow = 0
    self:clear()
end

return Contest
end
modules["court"] = function(...)

local import: (string) -> any = ...
local Env: typeof(require("./env")) = import("env")

local Court = {}

type Map = { [string]: any }

local players: any = game:GetService("Players")
local replicatedStorage: any = game:GetService("ReplicatedStorage")
local userInput: any = game:GetService("UserInputService")
local stats: any = game:GetService("Stats")

local MOVE_KEYS = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right }
local FAR_RIM = 30
local HOOK = "__PBShootHook"
local BALL_REACH = 6

Court.Now = 0
Court.Mine = nil :: any
Court.Root = nil :: any
Court.Action = nil :: any
Court.HasBall = false
Court.Count = 0
Court.Chars = {} :: { any }
Court.Roots = {} :: { any }
Court.Foe = {} :: { boolean }
Court.Carry = {} :: { boolean }
Court.TeamBall = false
Court.FoeBall = false
Court.Ping = 0.08
Court.Sending = 0
Court.Held = false
Court.Keys = false
Court.KeysOff = -math.huge
Court.Focused = true
Court.UserMoving = false
Court.Dead = false
Court.Forced = false
Court.HandsOff = false
Court.WalkAt = -math.huge
Court.FreeAt = -math.huge
Court.Foul = false
Court.Ball = {} :: { boolean }
Court.FoeHeld = false
Court.Touched = {} :: { string }

local function flat(vector: Vector3): Vector3
    return Vector3.new(vector.X, 0, vector.Z)
end

Court.flat = flat

local records: { [any]: Map } = setmetatable({}, { __mode = "k" }) :: any

local function record(character: any): Map
    local entry = records[character]
    if not entry then
        entry = {}
        records[character] = entry
    end
    return entry
end

function Court.root(character: any): any?
    local entry = record(character)
    local root = entry.Root
    if root and root.Parent == character then
        return root
    end
    root = character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        entry.Root = root
        return root
    end
    entry.Root = nil
    return nil
end

function Court.humanoid(character: any): any?
    local entry = record(character)
    local humanoid = entry.Humanoid
    if humanoid and humanoid.Parent == character then
        return humanoid
    end
    humanoid = character:FindFirstChildOfClass("Humanoid")
    entry.Humanoid = humanoid
    return humanoid
end

function Court.holds(character: any): boolean
    local entry = record(character)
    local inner = entry.Inner
    if not inner or not inner:IsDescendantOf(character) then
        local folder = character:FindFirstChild("Attributes")
        inner = if folder then folder:FindFirstChild("Basketball") else nil
        entry.Inner = inner
    end
    if inner and inner:IsA("ObjectValue") and inner.Value ~= nil then
        return true
    end
    local outer = entry.Outer
    if not outer or outer.Parent ~= character then
        outer = character:FindFirstChild("Basketball")
        entry.Outer = outer
    end
    if outer and outer:IsA("ObjectValue") and outer.Value ~= nil then
        return true
    end
    local carried = character:GetAttribute("Basketball")
    if carried ~= nil and carried ~= false and carried ~= "" then
        return true
    end
    return character:GetAttribute("TripleThreat") == true or character:GetAttribute("Action") == "Dribbling"
end

function Court.free(character: any): boolean
    if character:GetAttribute("Stunned") == true then
        return false
    end
    return character:GetAttribute("CanMove") ~= false or character:GetAttribute("Action") == "Dribbling"
end

local OWN_MOVES: { [string]: boolean } = {
    Dribbling = true, Shooting = true, Gathering = true, Dunking = true, ContactLayup = true, Layup = true, Passing = true,
    Stealing = true, Blocking = true, Jumping = true, Rebounding = true, CatchingPass = true, PassTransition = true,
    CatchingLob = true, AwaitingPass = true, Diving = true, Pushing = true, MovingShot = true,
}

function Court.forced(character: any): boolean
    if not character then
        return false
    end
    local action = character:GetAttribute("Action")
    if action == "Moving" or action == "Fouled" or action == "Inbounding" or action == "Stunned" then
        return true
    end
    if character:GetAttribute("CanMove") == false then
        return not (type(action) == "string" and OWN_MOVES[action])
    end
    return false
end

local WALKS: { [string]: boolean } = { Moving = true, Fouled = true, Inbounding = true }

function Court.walking(character: any): boolean
    if not character then
        return false
    end
    local action = character:GetAttribute("Action")
    return type(action) == "string" and WALKS[action] == true
end

local GRACE = 0.5
Court.GRACE = GRACE

function Court.held(character: any): boolean
    if not character then
        return false
    end
    if Court.walking(character) or character:GetAttribute("Stunned") == true or character:GetAttribute("Action") == "Stunned" then
        return true
    end
    return os.clock() - (Court.FreeAt or -math.huge) < GRACE
end

function Court.handsOff(character: any): boolean
    if not character then
        return false
    end
    return Court.forced(character) or Court.held(character)
end

function Court.touch(what: string)
    local list = Court.Touched
    if #list < 24 and not table.find(list, what) then
        table.insert(list, what)
    end
end

function Court.enemy(mine: any, character: any): boolean
    if character:GetAttribute("TeamIndex") ~= mine:GetAttribute("TeamIndex") then
        return true
    end
    local theirs = character:GetAttribute("Team")
    return string.sub(character.Name, 1, 2) == "AI" and theirs ~= nil and theirs ~= mine:GetAttribute("Team")
end

local roster: { any } = {}
local rosterFolder: any = nil
local rosterLinks: { any } = {}
local nextSync = 0
local ROSTER_SYNC = 0.5

local function unbindRoster()
    for _, link in rosterLinks do
        pcall(link.Disconnect, link)
    end
    table.clear(rosterLinks)
    table.clear(roster)
    rosterFolder = nil
end

local function bindRoster(folder: any)
    unbindRoster()
    if not folder then
        return
    end
    rosterFolder = folder
    for _, child in folder:GetChildren() do
        table.insert(roster, child)
    end
    rosterLinks[1] = folder.ChildAdded:Connect(function(child: any)
        if not table.find(roster, child) then
            table.insert(roster, child)
        end
    end)
    rosterLinks[2] = folder.ChildRemoved:Connect(function(child: any)
        local index = table.find(roster, child)
        if index then
            local last = #roster
            roster[index] = roster[last]
            roster[last] = nil
        end
    end)
end

local function characters(now: number): any?
    local folder = rosterFolder
    if not folder or folder.Parent ~= workspace then
        folder = workspace:FindFirstChild("Characters")
        bindRoster(folder)
        nextSync = now + ROSTER_SYNC
        return folder
    end
    if now >= nextSync then
        nextSync = now + ROSTER_SYNC
        table.clear(roster)
        for _, child in folder:GetChildren() do
            table.insert(roster, child)
        end
    end
    return folder
end

function Court.mine(): any?
    local folder = rosterFolder
    if not folder or folder.Parent ~= workspace then
        folder = workspace:FindFirstChild("Characters")
    end
    local player = players.LocalPlayer
    if not folder or not player then
        return nil
    end
    return folder:FindFirstChild(player.Name)
end

local pingItem: any = nil
local nextPing = 0
local pingSeeded = false
local PING_SMOOTH = 0.2

local pingWindow: { number } = {}
local PING_WINDOW = 6

local function samplePing(value: number)
    local clamped = math.min(value, 0.6)
    table.insert(pingWindow, clamped)
    if #pingWindow > PING_WINDOW then
        table.remove(pingWindow, 1)
    end
    local sorted = table.clone(pingWindow)
    table.sort(sorted)
    local half = math.ceil(#sorted / 2)
    local low = 0
    for index = 1, half do
        low += sorted[index]
    end
    low /= half
    if pingSeeded then
        Court.Ping += (low - Court.Ping) * PING_SMOOTH
    else
        pingSeeded = true
        Court.Ping = low
    end
end

local function dataPing(): number
    local item = pingItem
    if not item then
        item = stats.Network.ServerStatsItem["Data Ping"]
        pingItem = item
    end
    return item:GetValue()
end

local function networkPing(): number
    return players.LocalPlayer:GetNetworkPing()
end

local function updatePing(now: number)
    if now < nextPing then
        return
    end
    nextPing = now + 0.25
    local ok, value = pcall(dataPing)
    if ok and type(value) == "number" and value == value and value > 0 then
        samplePing(value / 1000)
        return
    end
    pingItem = nil
    local got, seconds = pcall(networkPing)
    if got and type(seconds) == "number" and seconds == seconds and seconds > 0 then
        samplePing(seconds * 2)
    end
end

local serviceFolder: any = nil
local inputs: { [string]: any } = {}

local function service(name: string): any?
    local aero = replicatedStorage:FindFirstChild("Aero")
    local remotes = if aero then aero:FindFirstChild("AeroRemoteServices") else nil
    return if remotes then remotes:FindFirstChild(name) else nil
end

Court.service = service

function Court.input(name: string): any?
    local remote = inputs[name]
    if remote and remote.Parent ~= nil then
        return remote
    end
    local folder = serviceFolder
    if not folder or folder.Parent == nil then
        folder = service("InputService")
        serviceFolder = folder
    end
    remote = if folder then folder:FindFirstChild(name) else nil
    inputs[name] = remote
    return remote
end

local function shotRelease(remote: any, first: any): boolean
    return remote.Name == "Shoot" and type(first) == "table" and rawget(first, "Shoot") == false
end

Court.Closing = false

function Court.send(remote: any, ...: any): boolean
    if Court.HandsOff and not Court.Closing and not shotRelease(remote, (...)) then
        Court.touch("held back " .. tostring(remote.Name))
        return false
    end
    Court.Sending += 1
    local ok = pcall(remote.FireServer, remote, ...)
    Court.Sending -= 1
    return ok
end

function Court.copied(name: string): any?
    local hook = Env.get(HOOK)
    if type(hook) ~= "table" then
        return nil
    end
    if name == "Sprint" and hook.SprintOn then
        return hook.SprintOn
    end
    local press = hook.Press
    return if type(press) == "table" then press[name] else nil
end

local learnedForm: { [string]: number } = {}
local tryForm: { [string]: number } = {}
local trials: { [string]: Map } = {}

function Court.fire(name: string, forms: { (any) -> ...any }, check: ((any) -> boolean)?, adapt: ((any, any) -> any)?, context: any): boolean
    if Court.HandsOff and not Court.Closing then
        Court.touch("held back " .. name)
        return false
    end
    local remote = Court.input(name)
    if not remote then
        return false
    end
    local copied = Court.copied(name)
    if type(copied) == "table" then
        local args = if adapt then adapt(copied, context) else copied
        return Court.send(remote, table.unpack(args, 1, args.n or #args))
    end
    local index = learnedForm[name] or tryForm[name] or 1
    if index > #forms then
        index = 1
    end
    local sent = Court.send(remote, forms[index](context))
    if check and not learnedForm[name] then
        local trial = trials[name]
        if not trial then
            trial = {}
            trials[name] = trial
        end
        trial.Index = index
        trial.Count = #forms
        trial.Until = os.clock() + 0.6
        trial.Check = check
        trial.Context = context
        trial.Live = true
    end
    return sent
end

local function settleTrials(now: number)
    for name, trial in trials do
        if trial.Live then
            local ok, worked = pcall(trial.Check, trial.Context)
            if ok and worked == true then
                learnedForm[name] = trial.Index
                trial.Live = false
                trial.Context = nil
            elseif not ok or now >= trial.Until then
                tryForm[name] = trial.Index % trial.Count + 1
                trial.Live = false
                trial.Context = nil
            end
        end
    end
end

local virtualInput: any = nil
local virtualTried = false
local keyChannel = 0
local keyDead = false

local KEYS: { [string]: { any } } = {
    W = { Enum.KeyCode.W, 0x57 },
    A = { Enum.KeyCode.A, 0x41 },
    S = { Enum.KeyCode.S, 0x53 },
    D = { Enum.KeyCode.D, 0x44 },
}
local pressed: { [string]: boolean } = {}

local function virtualKey(down: boolean, code: any)
    virtualInput:SendKeyEvent(down, code, false, game)
end

local function channel(): number
    if keyChannel ~= 0 then
        return keyChannel
    end
    if not virtualTried then
        virtualTried = true
        local ok, found = pcall(game.GetService, game, "VirtualInputManager")
        if ok and found then
            virtualInput = found
        end
    end
    if virtualInput then
        keyChannel = 1
    elseif Env.keypress and Env.keyrelease then
        keyChannel = 2
    end
    return keyChannel
end

local function send(name: string, down: boolean): boolean
    local entry = KEYS[name]
    local way = channel()
    if way == 1 then
        if pcall(virtualKey, down, entry[1]) then
            return true
        end
        virtualInput = nil
        keyChannel = 0
        way = channel()
    end
    if way == 2 then
        if not down or Court.Focused then
            return (pcall(if down then Env.keypress else Env.keyrelease, entry[2]))
        end
        return false
    end
    keyDead = true
    return false
end

local holders: { [string]: { [string]: boolean } } = {}

local function applyKeys()
    local wanted: { [string]: boolean } = {}
    for _, set in holders do
        for name, down in set do
            if down then
                wanted[name] = true
            end
        end
    end
    if keyDead or Court.Forced or Court.HandsOff or not Court.Focused or userInput.KeyboardEnabled == false or userInput:GetFocusedTextBox() ~= nil then
        table.clear(wanted)
    end
    for name in KEYS do
        local want = wanted[name] == true
        if (pressed[name] == true) ~= want then
            if want then
                pressed[name] = send(name, true) or nil
            else
                pressed[name] = nil
                send(name, false)
            end
        end
    end
    Court.Held = pressed.W == true
    local any = next(pressed) ~= nil
    if Court.Keys and not any then
        Court.KeysOff = os.clock()
    end
    Court.Keys = any
end

local function applyKey()
    applyKeys()
end

function Court.hold(owner: string, down: boolean)
    if not down and not holders[owner] then
        return
    end
    holders[owner] = if down then { W = true } else nil
    applyKeys()
end

function Court.canPress(): boolean
    return not keyDead and channel() ~= 0 and Court.Focused and userInput.KeyboardEnabled ~= false
end

function Court.keysIgnored()
    keyDead = true
    applyKeys()
end

function Court.holdKeys(owner: string, set: { [string]: boolean }?)
    if not set and not holders[owner] then
        return
    end
    holders[owner] = set
    applyKeys()
end

function Court.steering(mine: any): boolean
    if Court.UserMoving then
        return true
    end
    if not Court.Keys and os.clock() - Court.KeysOff > 0.3 then
        local humanoid = Court.humanoid(mine)
        if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
            return true
        end
    end
    return Court.userKeys()
end

function Court.userKeys(): boolean
    if userInput:GetFocusedTextBox() then
        return false
    end
    for _, key in MOVE_KEYS do
        local own = (pressed.W and (key == Enum.KeyCode.W)) or (pressed.A and key == Enum.KeyCode.A) or (pressed.S and key == Enum.KeyCode.S) or (pressed.D and key == Enum.KeyCode.D)
        if not own and userInput:IsKeyDown(key) then
            return true
        end
    end
    return false
end
local proxyPart: any = nil
local proxyMover: any = nil

function Court.proxy(): (any?, any?)
    local part = proxyPart
    if not part or part.Parent ~= workspace then
        part = workspace:FindFirstChild("ProxyCharacter")
        proxyPart = part
        proxyMover = nil
    end
    if not part or not part:IsA("BasePart") then
        return nil, nil
    end
    local mover = proxyMover
    if not mover or mover.Parent ~= part then
        mover = part:FindFirstChild("MovementVelocity")
        proxyMover = if mover and mover:IsA("BodyVelocity") then mover else nil
        mover = proxyMover
    end
    return part, mover
end

function Court.heading(): Vector3?
    if userInput:GetFocusedTextBox() then
        return nil
    end
    local camera = workspace.CurrentCamera
    if not camera then
        return nil
    end
    local x, z = 0, 0
    if userInput:IsKeyDown(Enum.KeyCode.W) or userInput:IsKeyDown(Enum.KeyCode.Up) then
        z += 1
    end
    if userInput:IsKeyDown(Enum.KeyCode.S) or userInput:IsKeyDown(Enum.KeyCode.Down) then
        z -= 1
    end
    if userInput:IsKeyDown(Enum.KeyCode.D) then
        x += 1
    end
    if userInput:IsKeyDown(Enum.KeyCode.A) then
        x -= 1
    end
    if x == 0 and z == 0 then
        return nil
    end
    local frame = camera.CFrame
    local forward = flat(frame.LookVector)
    if forward.Magnitude < 0.01 then
        forward = flat(frame.UpVector)
    end
    if forward.Magnitude < 0.01 then
        return nil
    end
    forward = forward.Unit
    local right = Vector3.new(-forward.Z, 0, forward.X)
    return (forward * z + right * x).Unit
end

function Court.sprintHeld(): boolean
    local hook = Env.get(HOOK)
    local calls = if type(hook) == "table" then hook.Calls else nil
    local last = if type(calls) == "table" then calls.Sprint else nil
    if type(last) == "table" and last[1] == true then
        return true
    end
    return userInput:GetFocusedTextBox() == nil and userInput:IsKeyDown(Enum.KeyCode.LeftShift)
end

local rimCache: { any } = {}
local fronts: { [any]: any } = {}
local hoopsFolder: any = nil
local nextRimScan = 0
local rimWait = 0.5

local function clearRims()
    table.clear(rimCache)
    table.clear(fronts)
    hoopsFolder = nil
end

function Court.rims(): { any }
    if rimCache[1] then
        return rimCache
    end
    local now = os.clock()
    if now < nextRimScan then
        return rimCache
    end
    local hoops = workspace:FindFirstChild("Hoops", true)
    if hoops then
        hoopsFolder = hoops
        for _, descendant in hoops:GetDescendants() do
            if descendant.Name == "Rim" and descendant:IsA("BasePart") then
                table.insert(rimCache, descendant)
            end
        end
    end
    rimWait = if rimCache[1] then 0.5 else math.min(rimWait * 1.5, 4)
    nextRimScan = now + rimWait
    return rimCache
end

function Court.rimDistance(position: Vector3): (number?, any?)
    local best: number? = nil
    local bestRim: any? = nil
    for _, rim in Court.rims() do
        local offset = rim.Position - position
        local distance = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
        if not best or distance < best then
            best = distance
            bestRim = rim
        end
    end
    return best, bestRim
end

function Court.facingRim(root: any, facing: number, range: number): (any?, number)
    local look = flat(root.CFrame.LookVector)
    local origin = root.Position
    local best: any? = nil
    local bestDistance = math.huge
    for _, rim in Court.rims() do
        local toRim = flat(rim.Position - origin)
        local away = toRim.Magnitude
        local dot = if away > 0.01 then look:Dot(toRim) / away else 1
        if dot >= facing and away <= range and away < bestDistance then
            best = rim
            bestDistance = away
        end
    end
    return best, bestDistance
end

local function boardFront(rim: any): (Vector3?, Vector3?)
    local hoops = hoopsFolder
    if not hoops then
        return nil, nil
    end
    local model = rim
    while model.Parent and model.Parent ~= hoops do
        model = model.Parent
    end
    if model == rim or model.Parent ~= hoops then
        return nil, nil
    end
    local origin = rim.Position
    local board: any = nil
    local sum = Vector3.zero
    local weight = 0
    for _, descendant in model:GetDescendants() do
        if descendant ~= rim and descendant:IsA("BasePart") then
            local offset = flat(descendant.Position - origin)
            if offset.Magnitude > 14 then
                return nil, nil
            end
            local name = string.lower(descendant.Name)
            if not board and (string.find(name, "board", 1, true) or string.find(name, "glass", 1, true)) then
                board = descendant
            end
            if name ~= "rim" and not string.find(name, "net", 1, true) then
                local size = descendant.Size
                local volume = size.X * size.Y * size.Z
                sum += offset * volume
                weight += volume
            end
        end
    end
    local named: Vector3? = nil
    if board then
        local away = flat(origin - board.Position)
        if away.Magnitude > 0.3 then
            named = away.Unit
        end
    end
    local massed: Vector3? = nil
    if weight > 0 then
        local away = sum / -weight
        if away.Magnitude > 0.3 then
            massed = away.Unit
        end
    end
    return named, massed
end

local function oppositeFront(rim: any): (Vector3?, boolean)
    local origin = rim.Position
    local first: any = nil
    local best: any = nil
    local bestDistance = math.huge
    local single = true
    for _, other in rimCache do
        if other ~= rim then
            local distance = flat(other.Position - origin).Magnitude
            if distance >= FAR_RIM then
                if not first then
                    first = other
                elseif (other.Position - first.Position).Magnitude > 25 then
                    single = false
                end
                if distance < bestDistance then
                    best = other
                    bestDistance = distance
                end
            end
        end
    end
    if not best then
        return nil, false
    end
    return flat(best.Position - origin).Unit, single
end

function Court.front(rim: any): Vector3?
    local known = fronts[rim]
    if known ~= nil then
        return if known then known else nil
    end
    local found: Vector3? = nil
    local ok, named, massed = pcall(boardFront, rim)
    local across, single = oppositeFront(rim)
    if ok and named then
        found = named
    elseif across and single then
        found = across
    elseif ok and massed then
        found = massed
    else
        found = across
    end
    fronts[rim] = found or false
    return found
end

function Court.frontOf(rim: any, position: Vector3): (number?, number)
    local front = Court.front(rim)
    if not front then
        return nil, 0
    end
    local offset = flat(position - rim.Position)
    local ahead = offset:Dot(front)
    return ahead, (offset - front * ahead).Magnitude
end

function Court.goal(character: any): any?
    local entry = record(character)
    local value = entry.Goal
    if not value or not value:IsDescendantOf(character) then
        local folder = character:FindFirstChild("Attributes")
        value = if folder then folder:FindFirstChild("Goal") else nil
        entry.Goal = value
    end
    if not value or not value:IsA("ObjectValue") then
        return nil
    end
    local target = value.Value
    local position: Vector3? = nil
    if target and target:IsA("BasePart") then
        position = target.Position
    elseif target and target:IsA("Model") then
        position = target:GetPivot().Position
    end
    if not position then
        return nil
    end
    local distance, rim = Court.rimDistance(position)
    return if distance and distance < 20 then rim else nil
end

function Court.nearestFoe(position: Vector3): number
    local best = math.huge
    local roots = Court.Roots
    local foe = Court.Foe
    for index = 1, Court.Count do
        if foe[index] then
            local distance = (roots[index].Position - position).Magnitude
            if distance < best then
                best = distance
            end
        end
    end
    return best
end

local ballFolder: any = nil
local ballPart: any = nil
local nextBall = 0

function Court.ball(): any?
    local now = Court.Now
    local ball = ballPart
    if ball and now < nextBall and ballFolder and ball:IsDescendantOf(ballFolder) then
        return ball
    end
    nextBall = now + 0.25
    ballPart = nil
    local folder = ballFolder
    if not folder or folder.Parent ~= workspace then
        folder = workspace:FindFirstChild("Basketballs")
        ballFolder = folder
    end
    if not folder then
        return nil
    end
    local origin = if Court.Root then Court.Root.Position else nil
    local bestDistance = math.huge
    for _, child in folder:GetChildren() do
        local part: any = nil
        if child:IsA("BasePart") then
            part = child
        elseif child:IsA("Model") then
            part = child.PrimaryPart
        end
        if part then
            local distance = if origin then (part.Position - origin).Magnitude else 0
            if distance < bestDistance then
                bestDistance = distance
                ballPart = part
            end
        end
    end
    return ballPart
end

function Court.ballNear(position: Vector3, reach: number): boolean?
    Court.ball()
    local folder = ballFolder
    if not folder then
        return nil
    end
    local any = false
    for _, child in folder:GetChildren() do
        local part: any = nil
        if child:IsA("BasePart") then
            part = child
        elseif child:IsA("Model") then
            part = child.PrimaryPart
        end
        if part then
            any = true
            if (part.Position - position).Magnitude <= reach then
                return true
            end
        end
    end
    return if any then false else nil
end

local lastBall: Vector3? = nil

local function trackDead(inbound: boolean)
    if inbound then
        Court.Dead = true
    elseif Court.TeamBall or Court.FoeBall then
        Court.Dead = false
        lastBall = nil
        return
    end
    local ball = Court.ball()
    if not ball then
        lastBall = nil
        return
    end
    local where: Vector3 = ball.Position
    local before = lastBall
    lastBall = where
    if not before or where.Y >= before.Y then
        return
    end
    for _, rim in Court.rims() do
        local center: Vector3 = rim.Position
        local dx, dz = where.X - center.X, where.Z - center.Z
        if dx * dx + dz * dz < 1.44 and before.Y >= center.Y - 0.3 and where.Y < center.Y - 0.3 then
            Court.Dead = true
        end
    end
end

local function trim(list: { any }, from: number, to: number)
    for index = from, to do
        list[index] = nil
    end
end

function Court.refresh(now: number)
    Court.Now = now
    updatePing(now)
    settleTrials(now)
    local first = rimCache[1]
    if first and not first:IsDescendantOf(workspace) then
        clearRims()
    end
    local folder = characters(now)
    local player = players.LocalPlayer
    local mine = if folder and player then folder:FindFirstChild(player.Name) else nil
    local root = if mine then Court.root(mine) else nil
    Court.Mine = mine
    Court.Root = root
    Court.Action = if mine then mine:GetAttribute("Action") else nil
    Court.HasBall = mine ~= nil and Court.holds(mine)
    local forced = Court.forced(mine)
    if mine and (Court.walking(mine) or mine:GetAttribute("Stunned") == true or Court.Action == "Stunned") then
        Court.FreeAt = now
    end
    if mine and Court.walking(mine) then
        Court.WalkAt = now
    end
    local hands = mine ~= nil and (forced or now - (Court.FreeAt or -math.huge) < GRACE)
    if not hands then
        table.clear(Court.Touched)
    end
    if forced ~= Court.Forced or hands ~= Court.HandsOff then
        Court.Forced = forced
        Court.HandsOff = hands
        applyKeys()
    end
    local chars, roots, foe, carry, held = Court.Chars, Court.Roots, Court.Foe, Court.Carry, Court.Ball
    local count = 0
    local teamBall = Court.HasBall
    local foeBall = false
    local foul = Court.Action == "Fouled"
    local inbound = Court.Action == "Inbounding"
    if folder and mine then
        for _, character in roster do
            if character ~= mine and character.Parent == folder and character:GetAttribute("TeamIndex") ~= nil then
                local other = Court.root(character)
                if other then
                    count += 1
                    local theirAction = character:GetAttribute("Action")
                    if theirAction == "Inbounding" or character:GetAttribute("Inbounding") == true then
                        inbound = true
                    end
                    if theirAction == "Fouled" then
                        foul = true
                    end
                    local enemy = Court.enemy(mine, character)
                    local has = Court.holds(character)
                    chars[count] = character
                    roots[count] = other
                    foe[count] = enemy
                    carry[count] = has
                    held[count] = has and Court.ballNear(other.Position, BALL_REACH) ~= false
                    if has then
                        if enemy then
                            foeBall = true
                        else
                            teamBall = true
                        end
                    end
                end
            end
        end
    end
    local before = Court.Count
    if before > count then
        trim(chars, count + 1, before)
        trim(roots, count + 1, before)
        trim(foe, count + 1, before)
        trim(carry, count + 1, before)
        trim(held, count + 1, before)
    end
    Court.Count = count
    Court.TeamBall = teamBall
    Court.FoeBall = foeBall
    Court.Foul = foul
    local foeHeld = false
    for index = 1, count do
        if foe[index] and held[index] then
            foeHeld = true
            break
        end
    end
    Court.FoeHeld = foeHeld
    trackDead(inbound)
end

local links: { any } = {}

function Court.start()
    local ok = pcall(function()
        table.insert(links, userInput.WindowFocusReleased:Connect(function()
            Court.Focused = false
            applyKey()
        end))
        table.insert(links, userInput.WindowFocused:Connect(function()
            Court.Focused = true
        end))
    end)
    if not ok then
        Court.Focused = true
    end
end

function Court.stop()
    table.clear(holders)
    applyKey()
    for _, link in links do
        pcall(link.Disconnect, link)
    end
    table.clear(links)
    unbindRoster()
    table.clear(trials)
end

return Court
end
modules["defense"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")
local Config: typeof(require("./config")) = import("config")
local Drive: typeof(require("./drive")) = import("drive")
local Env: typeof(require("./env")) = import("env")

local players: any = game:GetService("Players")

local Defense = {}
Defense.__index = Defense

type Map = { [string]: any }

local STEAL_COOLDOWN_MIN = 1.0
local STEAL_COOLDOWN_MAX = 1.4
local REACT_MIN = 0.12
local REACT_MAX = 0.25
local STILL_SPEED = 2
local STILL_TIME = 0.35
local STILL_DRIFT = 0.35
local BALL_REACH = 6
local BOT_BUSY: { [string]: boolean } = { Shooting = true, Dunking = true, Layup = true, ContactLayup = true, Gathering = true, Passing = true, AwaitingPass = true, CatchingPass = true, MovingShot = true }
local LAG = 0.08
local TRAIL = 32
local READ_RATE = 12
local AHEAD = 0.15
local ARRIVE = 3.6
local STAND_IN = 0.45
local STAND_OUT = 1.1
local NEAR = 2.5
local STANCE = 0.85
local SPRINT_EXTRA = 3
local SLOW_DOWN = 40
local PACE_LOW = 0.9
local PACE_MIN = 0.6
local PACE_MAX = 1.4
local KEY_ON = 1.6
local KEY_OFF = 0.8
local KEY_CHANGE = 0.12
local KEY_TURN_BACK = 0.24
local GAP = 3
local GAP_LOW = 2.8
local GAP_HIGH = 3.4
local WANDER = 0.2
local WANDER_RATE = 1.3
local REACH = 16
local START_MIN = 0.16
local START_MAX = 0.28
local SWITCH_MIN = 0.06
local SWITCH_MAX = 0.14
local RAMP = 0.3
local RAMP_FLOOR = 0.45
local CHOP = 5
local EXTRA = 2.5
local EASE_TIME = 0.35
local SQUARE = 0.2
local SQUARED = 0.75
local SHADE = 0.9
local PICKUP_MIN = 0.15
local PICKUP_MAX = 0.3
local RECOVER = 5
local RECOVERED = 3.5
local SECTOR = math.pi / 4
local KEYSETS: { [number]: { [string]: boolean } } = {
    [0] = { W = true },
    [1] = { W = true, D = true },
    [2] = { D = true },
    [3] = { S = true, D = true },
    [4] = { S = true },
    [5] = { S = true, A = true },
    [6] = { A = true },
    [7] = { W = true, A = true },
}
local HOLD_ANGLE = math.rad(34)
local USER_GRACE = 0.4
local FACING = 0.35
local FOLLOW_SLACK = 1.1

local HOLD_ON = { HoldingG = true }
local HOLD_OFF = { HoldingG = false }
local NO_FOLLOW: { [string]: boolean } = { Shooting = true, Dunking = true, Layup = true, Gathering = true, Stealing = true, Blocking = true, Jumping = true, Rebounding = true, Passing = true, Inbounding = true, Stunned = true, Fouled = true, Diving = true }
local SHOOTING: { [string]: boolean } = { Shooting = true, Dunking = true }

local flat = Court.flat
local random = Random.new()

local STEAL_FORMS: { (any) -> ...any } = {
    function(_: any): ...any
        return
    end,
    function(_: any): ...any
        return { Steal = true }
    end,
    function(_: any): ...any
        return { Stealing = true }
    end,
}

local function stealing(mine: any): boolean
    return mine.Parent ~= nil and mine:GetAttribute("Action") == "Stealing"
end

function Defense.new(read: (string) -> any, player: any?): any
    return setmetatable({
        Read = read,
        Player = player,
        Recovering = false,
        LastSteal = -math.huge,
        StealWait = STEAL_COOLDOWN_MIN,
        InRange = nil :: any,
        InRangeAt = 0,
        React = REACT_MIN,
        Trail = table.create(TRAIL, Vector3.zero) :: { Vector3 },
        TrailAt = table.create(TRAIL, -math.huge) :: { number },
        TrailIndex = 0,
        Guarding = false,
        GuardOn = nil :: any,
        GuardAt = 0,
        Handler = nil :: any,
        Target = nil :: any,
        Following = false,
        Spot = nil :: Vector3?,
        SpotFor = nil :: any,
        SeenFor = nil :: any,
        SeenAt = Vector3.zero,
        Velocity = Vector3.zero,
        FoeRim = nil :: any,
        FoeAt = -math.huge,
        TeamRim = nil :: any,
        TeamAt = -math.huge,
        Guess = nil :: any,
        EngageFor = nil :: any,
        EngageAt = 0,
        Gap = GAP,
        Checked = {} :: { [any]: boolean },
        GoalScore = 0,
        Standing = false,
        Pace = 1,
    }, Defense)
end

local function nearest(origin: Vector3, range: number, holderOnly: boolean, current: any): any?
    local best: any? = nil
    local bestDistance = range
    local chars, roots, foe, held = Court.Chars, Court.Roots, Court.Foe, Court.Ball
    for index = 1, Court.Count do
        if foe[index] and (not holderOnly or held[index]) then
            local distance = (roots[index].Position - origin).Magnitude
            if chars[index] == current then
                distance -= 2
            end
            if distance <= bestDistance then
                best = chars[index]
                bestDistance = distance
            end
        end
    end
    return best
end

local function isFoe(character: any): boolean
    local chars, foe = Court.Chars, Court.Foe
    for index = 1, Court.Count do
        if chars[index] == character then
            return foe[index]
        end
    end
    return false
end

local HOLD_GAP = 0.3

function Defense.setGuard(self: any, on: boolean, again: boolean?, urgent: boolean?): boolean
    if self.Guarding == on and not again then
        return false
    end
    local now = os.clock()
    if not urgent and now - (self.HoldAt or -math.huge) < HOLD_GAP then
        return false
    end
    self.HoldAt = now
    self.Guarding = on
    local remote = Court.input("HoldG")
    if remote then
        Court.send(remote, if on then HOLD_ON else HOLD_OFF)
    end
    return true
end

function Defense.rest(self: any)
    self.Recovering = false
    self:settle()
    self.Following = false
    self.Spot = nil
    self.SpotFor = nil
    self.SeenFor = nil
    self.Standing = false
    self.Top = nil
    self.EaseUntil = nil
end

function Defense.settle(self: any)
    self.Sector = nil
    Court.holdKeys("Guard", nil)
    Drive.clear("Guard")
end

function Defense.learn(self: any, now: number)
    local checked = self.Checked
    for character in checked do
        if character.Parent == nil or not SHOOTING[character:GetAttribute("Action")] then
            checked[character] = nil
        end
    end
    local chars, roots, foe = Court.Chars, Court.Roots, Court.Foe
    for index = 1, Court.Count do
        if SHOOTING[chars[index]:GetAttribute("Action")] then
            local distance, rim = Court.rimDistance(roots[index].Position)
            if distance and rim and distance < 45 then
                self:check(chars[index], rim)
                if foe[index] then
                    self.FoeRim, self.FoeAt = rim, now
                else
                    self.TeamRim, self.TeamAt = rim, now
                end
            end
        end
    end
    if SHOOTING[Court.Action] and Court.Root then
        local distance, rim = Court.rimDistance(Court.Root.Position)
        if distance and rim and distance < 45 then
            self:check(Court.Mine, rim)
            self.TeamRim, self.TeamAt = rim, now
        end
    end
end

function Defense.check(self: any, character: any, rim: any)
    if self.Checked[character] then
        return
    end
    self.Checked[character] = true
    local goal = Court.goal(character)
    if goal then
        self.GoalScore += if goal == rim then 1 else -2
    end
end

function Defense.goal(self: any, character: any?): any?
    if not character or self.GoalScore < 0 then
        return nil
    end
    return Court.goal(character)
end

local function farthestFrom(rim: any): any?
    local best: any? = nil
    local bestDistance = 30
    for _, other in Court.rims() do
        local distance = (other.Position - rim.Position).Magnitude
        if distance > bestDistance then
            best = other
            bestDistance = distance
        end
    end
    return best
end

function Defense.known(self: any): (any?, any?)
    if self.FoeRim and self.FoeRim.Parent == nil then
        self.FoeRim = nil
    end
    if self.TeamRim and self.TeamRim.Parent == nil then
        self.TeamRim = nil
    end
    return self.FoeRim, self.TeamRim
end

function Defense.attackRim(self: any): any?
    local own = self:goal(Court.Mine)
    if own then
        return own
    end
    local foeRim, teamRim = self:known()
    if teamRim and (not foeRim or self.TeamAt >= self.FoeAt) then
        return teamRim
    end
    if foeRim then
        return farthestFrom(foeRim)
    end
    return nil
end

function Defense.rimFor(self: any, theirs: Vector3, mine: Vector3, target: any?): any?
    local rims = Court.rims()
    local count = #rims
    if count == 0 then
        return nil
    end
    if count == 1 then
        return rims[1]
    end
    local goal = self:goal(target)
    if goal then
        return goal
    end
    local foeRim, teamRim = self:known()
    if foeRim and (not teamRim or self.FoeAt >= self.TeamAt) then
        return foeRim
    end
    if teamRim then
        local other = farthestFrom(teamRim)
        if other then
            return other
        end
    end
    if foeRim then
        return foeRim
    end
    local moving = self.Velocity
    if moving.Magnitude > 8 then
        for _, rim in rims do
            local toward = flat(rim.Position - theirs)
            if toward.Magnitude > 2 and toward.Unit:Dot(moving.Unit) > 0.75 then
                self.Guess = rim
                return rim
            end
        end
    end
    local best: any? = nil
    local bestScore = math.huge
    local guessScore: number? = nil
    for _, rim in rims do
        local score = flat(rim.Position - mine).Magnitude - flat(rim.Position - theirs).Magnitude
        if score < bestScore then
            best = rim
            bestScore = score
        end
        if rim == self.Guess then
            guessScore = score
        end
    end
    if guessScore and guessScore - bestScore < 6 then
        return self.Guess
    end
    if self.Guess and moving.Magnitude > 4 then
        local toward = flat(self.Guess.Position - theirs)
        if toward.Magnitude > 2 and toward.Unit:Dot(moving.Unit) > 0.3 then
            return self.Guess
        end
    end
    self.Guess = best
    return best
end

function Defense.easeOut(self: any, root: any, now: number)
    local moving = Drive.velocity("Guard")
    if not moving or moving.Magnitude < 0.4 then
        self:rest()
        return
    end
    if not self.EaseUntil then
        self.EaseUntil = now + EASE_TIME
    elseif now > self.EaseUntil then
        self:rest()
        return
    end
    self.Following = false
    self.Standing = false
    Drive.set("Guard", root.Position, self.Top or 14, false, false, Vector3.zero)
    self:steerKeys(now, Drive.velocity("Guard"), Vector3.zero)
end

function Defense.follow(self: any, mine: any, root: any, target: any?, now: number, dt: number)
    local read = self.Read
    local action = Court.Action
    if (type(action) == "string" and NO_FOLLOW[action]) or mine:GetAttribute("CanMove") == false or mine:GetAttribute("Stunned") == true or Court.handsOff(mine) then
        self.EngageFor = nil
        self:rest()
        return
    end
    if Court.steering(mine) then
        self.UserAt = now
    end
    if now - (self.UserAt or -math.huge) < USER_GRACE then
        self.EngageFor = nil
        self:rest()
        return
    end
    local theirRoot = if target and read("GuardMove") == true then Court.root(target) else nil
    if not target or not theirRoot or target:GetAttribute("Action") == "Passing" then
        self.EngageFor = nil
        self:easeOut(root, now)
        return
    end
    if self.EngageFor ~= target then
        local recent = self.Following or now - (self.FollowedAt or -math.huge) < 1.5
        self.EngageFor = target
        self.EngageAt = now + (if recent then random:NextNumber(SWITCH_MIN, SWITCH_MAX) else random:NextNumber(START_MIN, START_MAX))
        self.Gap = random:NextNumber(GAP_LOW, GAP_HIGH)
        self.Phase = random:NextNumber(0, math.pi * 2)
        self.Ramp = if recent then 1 else 0
    end
    local theirs: Vector3 = theirRoot.Position
    local here: Vector3 = root.Position
    local offset = flat(theirs - here)
    local distance = offset.Magnitude
    local trail, trailAt = self.Trail, self.TrailAt
    local fresh = self.SeenFor ~= target
    if fresh then
        for index = 1, TRAIL do
            trailAt[index] = -math.huge
        end
    end
    local slot = self.TrailIndex % TRAIL + 1
    self.TrailIndex = slot
    trail[slot] = theirs
    trailAt[slot] = now
    local seen: Vector3 = theirs
    for back = 0, TRAIL - 1 do
        local index = (slot - back - 1) % TRAIL + 1
        local at = trailAt[index]
        if now - at > 0.5 then
            break
        end
        seen = trail[index]
        if at <= now - LAG then
            break
        end
    end
    if not fresh and dt > 0 then
        self.Velocity = self.Velocity:Lerp(flat(seen - self.SeenAt) / dt, 1 - math.exp(-READ_RATE * math.min(dt, 0.1)))
    else
        self.Velocity = Vector3.zero
        self.Standing = false
    end
    self.SeenFor = target
    self.SeenAt = seen
    if now < self.EngageAt then
        self:easeOut(root, now)
        return
    end
    local lead: Vector3 = self.Velocity
    local theirSpeed = lead.Magnitude
    local direction: Vector3? = nil
    local wanted = (self.Gap or GAP) + math.sin(now * WANDER_RATE + (self.Phase or 0)) * WANDER
    local gap = wanted
    local rim = self:rimFor(theirs, here, target)
    if rim then
        local toRim = flat(rim.Position - theirs)
        local length = toRim.Magnitude
        if length > 1.5 then
            direction = toRim / length
            gap = math.min(wanted, math.max(length - 1.5, 1))
        end
    end
    if not direction then
        direction = if distance > 0.5 then offset / -distance else -flat(root.CFrame.LookVector)
    end
    local raw: Vector3 = seen + lead * AHEAD + (direction :: Vector3) * gap
    local hand = target:GetAttribute("Hand")
    if hand == "L" or hand == "R" then
        local right = flat(theirRoot.CFrame.RightVector)
        if right.Magnitude > 0.1 then
            raw += right.Unit * (if hand == "R" then SHADE else -SHADE)
        end
    end
    local spot: Vector3? = self.Spot
    if not spot or self.SpotFor ~= target or (raw - spot).Magnitude > 12 then
        spot = raw
    else
        spot = spot:Lerp(raw, 1 - math.exp(-12 * math.min(dt, 0.1)))
    end
    self.Spot = spot
    self.SpotFor = target
    self.Following = true
    self.FollowedAt = now
    self.EaseUntil = nil
    local toSpot = flat((spot :: Vector3) - here)
    local span = toSpot.Magnitude
    if not self.Recovering and span > RECOVER and theirSpeed > 6 then
        self.Recovering = true
        self.GuardOn = nil
    elseif self.Recovering and span < RECOVERED then
        self.Recovering = false
    end
    if self.Player and (self.Recovering or span > RECOVER + 3) then
        self.Player.WantSprint = now + 0.3
    end
    if now >= (self.PaceAt or 0) then
        self.PaceAt = now + PACE_MIN + random:NextNumber() * (PACE_MAX - PACE_MIN)
        self.PaceWant = PACE_LOW + random:NextNumber() * (1 - PACE_LOW)
    end
    self.Pace = (self.Pace or 1) + ((self.PaceWant or 1) - (self.Pace or 1)) * (1 - math.exp(-2 * math.min(dt, 0.1)))
    local walk = mine:GetAttribute("WalkSpeed")
    local top = math.clamp(if type(walk) == "number" then walk else 14, 8, 17)
    if mine:GetAttribute("HoldingG") == true or (self.WantHold and not self.Recovering) then
        top *= STANCE
    elseif self.Recovering and mine:GetAttribute("Sprinting") == true then
        top += SPRINT_EXTRA
    end
    top *= self.Pace
    local ramp = math.min((self.Ramp or 1) + dt / RAMP, 1)
    self.Ramp = ramp
    top *= RAMP_FLOOR + (1 - RAMP_FLOOR) * ramp * ramp * (3 - 2 * ramp)
    local before: number? = self.Top
    if before and top < before then
        top = math.max(top, before - SLOW_DOWN * math.min(dt, 0.1))
    end
    self.Top = top
    local mySpeed = flat(root.AssemblyLinearVelocity).Magnitude
    if self.Standing then
        if span > STAND_OUT or theirSpeed > 1.5 then
            self.Standing = false
        end
    elseif span < STAND_IN and theirSpeed < 1 and mySpeed < 1.5 then
        self.Standing = true
    end
    local want: Vector3 = Vector3.zero
    if not self.Standing then
        local cap = top
        if span < CHOP then
            cap = math.min(top, math.max(theirSpeed + EXTRA, span * ARRIVE + 1.5))
        end
        local close = if span > 0.01 then toSpot / span * math.min(span * ARRIVE, cap) else Vector3.zero
        local sum = lead + close
        if sum.Magnitude > cap and lead.Magnitude > 0.01 then
            local low, high = 0, 1
            for _ = 1, 8 do
                local mid = (low + high) / 2
                if (close + lead * mid).Magnitude > cap then
                    high = mid
                else
                    low = mid
                end
            end
            sum = close + lead * low
        end
        want = sum
    end
    local turning = false
    if self.Standing and distance > 0.5 then
        local facing = flat(root.CFrame.LookVector):Dot(offset / distance)
        if self.FaceWant == true or facing < (if self.Squaring then SQUARED else SQUARE) then
            turning = true
        end
    end
    self.Squaring = turning
    if turning then
        want = offset / distance * 2.5
    end
    if distance > 0.05 then
        local out = offset / -distance
        local mine0: Vector3 = Drive.velocity("Guard") or flat(root.AssemblyLinearVelocity)
        local closing = math.max((lead - mine0):Dot(out), 0)
        local room = NEAR + closing * 0.15
        if distance < room then
            local into = -want:Dot(out)
            if into > 0 then
                want += out * into
            end
            want += out * ((room - distance) * 6)
        end
    end
    if not turning and span > 1.5 then
        local heading = toSpot / span
        local pushX, pushZ = 0, 0
        local chars, roots = Court.Chars, Court.Roots
        for index = 1, Court.Count do
            if chars[index] ~= target then
                local away = flat(roots[index].Position - here)
                local ahead = away:Dot(heading)
                if ahead > 0.5 and ahead < math.min(span, 5) then
                    local side = away - heading * ahead
                    local off = side.Magnitude
                    if off < 3 then
                        local out = if off > 0.2 then side / -off else Vector3.new(-heading.Z, 0, heading.X)
                        local push = (3 - off) / 3 * 1.4
                        pushX += out.X * push
                        pushZ += out.Z * push
                    end
                end
            end
        end
        if pushX ~= 0 or pushZ ~= 0 then
            local size = want.Magnitude
            want = Vector3.new(want.X + pushX * size * 0.5, 0, want.Z + pushZ * size * 0.5)
        end
    end
    Drive.set("Guard", spot :: Vector3, top, false, false, want)
    self:steerKeys(now, if turning then want else Drive.velocity("Guard"), want)
end

function Defense.steerKeys(self: any, now: number, moving: Vector3?, want: Vector3)
    local camera = workspace.CurrentCamera
    if not Court.canPress() or not camera or not moving then
        self.Sector = nil
        Court.holdKeys("Guard", nil)
        return
    end
    local speed = moving.Magnitude
    local current: number? = self.Sector
    if current == nil and speed < KEY_ON then
        return
    end
    if current ~= nil and speed < KEY_OFF and want.Magnitude < KEY_OFF then
        self.Sector = nil
        Court.holdKeys("Guard", nil)
        return
    end
    local forward = flat(camera.CFrame.LookVector)
    if forward.Magnitude < 0.01 or speed < 0.05 then
        return
    end
    forward = forward.Unit
    local right = Vector3.new(-forward.Z, 0, forward.X)
    local angle = math.atan2(moving:Dot(right), moving:Dot(forward))
    local sector = math.round(angle / SECTOR) % 8
    if current ~= nil and sector ~= current then
        local off = math.abs((angle - current * SECTOR + math.pi) % (2 * math.pi) - math.pi)
        local back = math.abs((sector - current + 4) % 8 - 4) >= 3
        if off < HOLD_ANGLE or now - (self.SectorAt or -math.huge) < (if back then KEY_TURN_BACK else KEY_CHANGE) then
            sector = current
        end
    end
    if sector ~= current then
        self.SectorAt = now
    end
    self.Sector = sector
    Court.holdKeys("Guard", KEYSETS[sector])
end

function Defense.stealOk(self: any, root: any, handlerRoot: any, handler: any): string?
    local toHandler = flat(handlerRoot.Position - root.Position)
    local length = toHandler.Magnitude
    if length < 0.5 then
        return nil
    end
    local direction = toHandler / length
    if self.Read("StealFacing") == true then
        local facing = flat(root.CFrame.LookVector):Dot(direction)
        if facing < 0.35 then
            return string.format("Only When Facing: you are not facing him (%.2f)", facing)
        end
    end
    if self.Read("AvoidFouls") == true then
        local action = handler:GetAttribute("Action")
        if action == "Shooting" or action == "Gathering" or action == "Layup" or action == "Dunking" then
            return "Avoid Fouls: he is " .. tostring(action)
        end
        if flat(handlerRoot.CFrame.LookVector):Dot(direction) > 0.6 then
            return "Avoid Fouls: you are behind him"
        end
    end
    return nil
end

function Defense.step(self: any, now: number, dt: number)
    local mine, root = Court.Mine, Court.Root
    local read = self.Read
    local guardOn = read("AutoGuard") == true
    local stealOn = read("AutoSteal") == true
    self:learn(now)
    if not mine or not root or (not guardOn and not stealOn) then
        self.FaceWant = false
        if mine then
            self:setGuard(false, false, true)
        else
            self.Guarding = false
        end
        self.GuardOn = nil
        self.Handler = nil
        self.Target = nil
        self.InRange = nil
        self:rest()
        return
    end
    if Court.HandsOff then
        self.Guarding = mine:GetAttribute("HoldingG") == true
        self.GuardOn = nil
        self.SeenTarget = nil
        self.FaceWant = false
        self.WantHold = false
        self.Target = nil
        self.InRange = nil
        self:rest()
        return
    end
    local here: Vector3 = root.Position
    local guardRange = read("GuardRange") or 0
    local moveOn = guardOn and read("GuardMove") == true
    local gap: number = if moveOn then read("GuardGap") or REACH else 0
    local slack = if self.Following then FOLLOW_SLACK else 1
    local walkTo = gap * slack
    local holdTo = if self.Guarding then guardRange * 1.1 else guardRange
    local search = math.max(walkTo, holdTo)
    local handler = if stealOn then nearest(here, math.huge, true, self.Handler) else nil
    self.Handler = handler
    local target: any = nil
    if guardOn and not Court.HasBall and not Court.TeamBall and not Court.Dead then
        if read("GuardTarget") == Config.GUARD_NEAREST then
            if Court.FoeHeld then
                target = nearest(here, search, false, self.Target)
            end
        else
            target = nearest(here, search, true, self.Target)
        end
    end
    self.Target = target
    local guarding = false
    local chasing = false
    local facing = true
    if target then
        local theirRoot = Court.root(target)
        if theirRoot then
            local distance = (theirRoot.Position - here).Magnitude
            guarding = distance <= holdTo
            chasing = moveOn and distance <= walkTo
            if guarding and read("GuardFacing") == true then
                local toward = flat(theirRoot.Position - here)
                local length = toward.Magnitude
                if length > 0.5 then
                    facing = flat(root.CFrame.LookVector):Dot(toward / length) >= (if self.Guarding then 0 else FACING)
                end
            end
        end
    end
    self.FaceWant = guarding and not facing
    local holding = guarding and facing
    self.WantHold = holding
    local action0 = Court.Action
    local canPress = Court.free(mine) and (action0 == "" or action0 == nil)
    if holding and self.SeenTarget ~= target then
        self.SeenTarget = target
        local switched = self.GuardOn ~= nil or now - (self.DroppedAt or -math.huge) < 1.5
        self.PressAt = now + (if switched then PICKUP_MIN + random:NextNumber() * (PICKUP_MAX - PICKUP_MIN) else 0)
    end
    if not holding then
        if self.GuardOn ~= nil then
            self.DroppedAt = now
        end
        self.GuardOn = nil
        self.SeenTarget = nil
        self:setGuard(false, false, target == nil)
    elseif self.Recovering then
        if self.Guarding then
            self:setGuard(false)
        end
    elseif canPress and now >= (self.PressAt or 0) and (self.GuardOn ~= target or now - self.GuardAt > 2) then
        if self:setGuard(true, true) then
            self.GuardOn, self.GuardAt = target, now
        end
    end
    self:follow(mine, root, if chasing then target else nil, now, dt)
    if not stealOn then
        self.InRange = nil
        return
    end
    if not handler then
        self.InRange = nil
        self:stealNote(now, "nobody on the other team holds the ball")
        return
    end
    local skip = self:steal(now, mine, root, here, handler)
    if skip then
        self:stealNote(now, skip, handler)
    end
end

function Defense.stealNote(self: any, now: number, reason: string, handler: any?)
    if Env.get("PBDebug") ~= true then
        return
    end
    local line = reason .. (if handler then " | " .. tostring(handler.Name) else "")
    if line == self.NoteLine and now - (self.NoteAt or -math.huge) < 1 then
        return
    end
    if now - (self.NoteAt or -math.huge) < 0.25 then
        return
    end
    self.NoteLine, self.NoteAt = line, now
    print("[PB steal] " .. line)
end

local function isBot(character: any): boolean
    return players:FindFirstChild(character.Name) == nil
end

function Defense.steal(self: any, now: number, mine: any, root: any, here: Vector3, handler: any): string?
    local read = self.Read
    local handlerRoot = Court.root(handler)
    if not handlerRoot then
        self.InRange = nil
        return "no root part on the ball handler"
    end
    local distance = (handlerRoot.Position - here).Magnitude
    local range = read("StealRange") or 0
    if distance > range then
        self.InRange = nil
        return string.format("out of Steal Range, %.1f studs of %d", distance, range)
    end
    if self.InRange ~= handler then
        self.InRange = handler
        self.InRangeAt = now
        self.React = REACT_MIN + random:NextNumber() * (REACT_MAX - REACT_MIN)
    end
    if now - self.InRangeAt < self.React then
        return nil
    end
    local handlerAction = handler:GetAttribute("Action")
    local inHands = Court.ballNear(handlerRoot.Position, BALL_REACH) ~= false
    if not Court.holds(handler) or not inHands then
        self.StillSince = now
        return "the ball is not in his hands"
    end
    local bot = isBot(handler)
    if bot then
        if type(handlerAction) == "string" and BOT_BUSY[handlerAction] then
            return "the bot is busy: " .. handlerAction
        end
    else
        local spot = flat(handlerRoot.Position)
        if self.StillFor ~= handler or not self.Anchor then
            self.StillFor = handler
            self.Anchor = spot
            self.StillSince = now
        end
        if (spot - self.Anchor).Magnitude > STILL_DRIFT then
            self.Anchor = spot
            self.StillSince = now
        end
        local motion = handlerRoot.AssemblyLinearVelocity
        local speed = Vector3.new(motion.X, 0, motion.Z).Magnitude
        if speed >= STILL_SPEED then
            self.StillSince = now
            return string.format("he is moving, %.1f studs/s", speed)
        end
        if handlerAction ~= "" and handlerAction ~= nil then
            self.StillSince = now
            return "his Action is " .. tostring(handlerAction)
        end
        if now - self.StillSince < STILL_TIME then
            return "waiting for him to stand still"
        end
    end
    local action = Court.Action
    if action ~= "" and action ~= nil then
        return "your Action is " .. tostring(action)
    end
    if not Court.free(mine) then
        return "you cannot move right now"
    end
    if Court.Dead then
        return "dead ball"
    end
    if now - self.LastSteal < self.StealWait then
        return nil
    end
    local why = self:stealOk(root, handlerRoot, handler)
    if why then
        return why
    end
    self.LastSteal = now
    self.StealWait = STEAL_COOLDOWN_MIN + random:NextNumber() * (STEAL_COOLDOWN_MAX - STEAL_COOLDOWN_MIN)
    Court.fire("Steal", STEAL_FORMS, stealing, nil, mine)
    if Env.get("PBDebug") == true then
        local how = if type(Court.copied("Steal")) == "table" then "your own steal press copied" else "a guessed steal call"
        print(string.format("[PB steal] sent on %s at %.1f studs, %s", tostring(handler.Name), distance, how))
    end
    return nil
end

function Defense.shutdown(self: any)
    pcall(self.setGuard, self, false, false, true)
    self.GuardOn = nil
    self.Handler = nil
    self.Target = nil
    self:rest()
end

return Defense
end
modules["drive"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")

local Drive = {}

type Map = { [string]: any }

local LIMIT = 27
local TURN = 140
local FRESH = 0.12

local PROFILES: { [string]: Map } = {
    Dunk = { Priority = 3, Accel = 38, Base = 6, Gain = 1.6, Stop = 2, Resume = 4 },
    Guard = { Priority = 2, Accel = 75, Brake = 200, Base = 1.5, Gain = 5, Stop = 0.8, Resume = 1.6, Direct = true, Turn = math.rad(280) },
    Magnet = { Priority = 1, Accel = 60, Base = 5, Gain = 3, Stop = 1, Resume = 1.5 },
}

local owner: string? = nil
local goal = Vector3.zero
local topSpeed = 0
local useKey = false
local forced = false
local setAt = -math.huge
local pace: number? = nil
local moving = false
local last: Vector3? = nil
local lastAt = -math.huge
local userAt = -math.huge
local feed: Vector3? = nil
local seenNative = 0
local seenAt = -math.huge

function Drive.set(name: string, target: Vector3, speed: number, key: boolean, force: boolean, match: Vector3?)
    local now = os.clock()
    local current = owner
    if current and current ~= name and now - setAt < FRESH and PROFILES[current].Priority > PROFILES[name].Priority then
        return
    end
    if current ~= name then
        moving = false
        pace = nil
    end
    owner = name
    goal = target
    topSpeed = speed
    useKey = key
    forced = force
    feed = match
    setAt = now
end

function Drive.clear(name: string)
    if owner == name then
        owner = nil
    end
end

function Drive.moving(name: string): boolean
    return owner == name and moving
end

function Drive.velocity(name: string): Vector3?
    if owner == name and moving then
        return last
    end
    return nil
end

function Drive.since(now: number): number
    return now - lastAt
end

function Drive.active(): boolean
    return owner ~= nil and moving
end

local function halt(mover: any, hands: boolean?)
    local keyed = Court.Held or os.clock() - Court.KeysOff < FRESH
    moving = false
    pace = nil
    Court.hold("Drive", false)
    local written = last
    if written and hands then
        last = nil
    elseif written then
        last = nil
        local steering = Court.Mine ~= nil and Court.steering(Court.Mine)
        if mover and not steering and (mover.Velocity - written).Magnitude < 0.05 then
            mover.Velocity = Vector3.zero
        elseif mover and keyed and not (Court.Mine and Court.steering(Court.Mine)) then
            if mover.Velocity.Magnitude > written.Magnitude + 1 then
                mover.Velocity = written
            end
        end
    end
end

function Drive.begin(now: number)
    local _, mover = Court.proxy()
    if not mover then
        Court.UserMoving = false
        return
    end
    if not Court.Keys and now - Court.KeysOff > 0.3 then
        local incoming = mover.Velocity
        local x, z = incoming.X, incoming.Z
        local speed = math.sqrt(x * x + z * z)
        if speed > 1 then
            local written = last
            local own = false
            if written and now - lastAt <= FRESH then
                local size = written.Magnitude
                own = size > 0.5 and speed <= size * 1.25 + 0.5 and x * written.X + z * written.Z >= 0.8 * speed * size
            end
            if not own then
                userAt = now
            end
        end
    end
    Court.UserMoving = now - userAt < 0.25
end

function Drive.finish(now: number, dt: number)
    local part, mover = Court.proxy()
    local name = owner
    local live = name ~= nil and now - setAt < FRESH and part ~= nil and mover ~= nil
    if live and not forced then
        local mine = Court.Mine
        live = mine ~= nil and not Court.steering(mine)
    end
    if Court.Forced or Court.HandsOff or (Court.Mine ~= nil and Court.handsOff(Court.Mine)) then
        owner = nil
        halt(mover, true)
        return
    end
    if not live or not name or not part or not mover then
        halt(mover)
        return
    end
    local profile = PROFILES[name]
    if profile.Direct then
        local want = feed or Vector3.zero
        local wx, wz = want.X, want.Z
        local native: Vector3 = mover.Velocity
        local nativeSpeed = math.sqrt(native.X * native.X + native.Z * native.Z)
        if Court.Keys and nativeSpeed > 4 and (not last or (native - last).Magnitude > 0.05) then
            seenNative, seenAt = nativeSpeed, now
        end
        local cap = math.min(topSpeed, LIMIT)
        if Court.Keys and now - seenAt < 0.5 then
            cap = math.min(cap, seenNative + 0.3)
        end
        local wantSize = math.sqrt(wx * wx + wz * wz)
        if wantSize > cap then
            wx, wz = wx / wantSize * cap, wz / wantSize * cap
            wantSize = cap
        end
        local velocity = part.AssemblyLinearVelocity
        local vx, vz = velocity.X, velocity.Z
        local stepX, stepZ = wx - vx, wz - vz
        local span = math.min(dt, 0.05)
        local before = math.sqrt(vx * vx + vz * vz)
        if before > 2 then
            local ux, uz = vx / before, vz / before
            local along = stepX * ux + stepZ * uz
            local px, pz = stepX - ux * along, stepZ - uz * along
            local side = math.sqrt(px * px + pz * pz)
            local sideMost = before * profile.Turn * span
            if side > sideMost then
                px, pz = px / side * sideMost, pz / side * sideMost
            end
            stepX, stepZ = ux * along + px, uz * along + pz
        end
        local step = math.sqrt(stepX * stepX + stepZ * stepZ)
        local most = (if wantSize < 0.05 and profile.Brake then profile.Brake else profile.Accel) * span
        if step > most then
            stepX, stepZ = stepX / step * most, stepZ / step * most
        end
        local nx, nz = vx + stepX, vz + stepZ
        local after = math.sqrt(nx * nx + nz * nz)
        if after > cap then
            nx, nz = nx / after * cap, nz / after * cap
            after = cap
        end
        local write = Vector3.new(nx, 0, nz)
        if wantSize < 0.05 and after < 0.4 then
            if not Court.Keys then
                halt(mover)
                return
            end
            write = Vector3.zero
            after = 0
        end
        moving = true
        pace = after
        mover.Velocity = write
        last = write
        lastAt = now
        Court.hold("Drive", false)
        return
    end
    local position = part.Position
    local dx, dz = goal.X - position.X, goal.Z - position.Z
    local away = math.sqrt(dx * dx + dz * dz)
    local match = feed
    if match and profile.Follow then
        local mx, mz = match.X, match.Z
        local matchSpeed = math.sqrt(mx * mx + mz * mz)
        if matchSpeed < 1 and away <= profile.Stop then
            halt(mover)
            return
        end
        local top = topSpeed
        local native: Vector3 = mover.Velocity
        local nativeSpeed = math.sqrt(native.X * native.X + native.Z * native.Z)
        if useKey and Court.Held and nativeSpeed > 4 and (not last or (native - last).Magnitude > 0.05) then
            seenNative, seenAt = nativeSpeed, now
        end
        local nativeCap = math.huge
        if useKey and now - seenAt < 0.5 then
            nativeCap = seenNative + 0.3
            top = math.min(top, nativeCap)
        end
        local pull = profile.Follow * math.min(away, 6)
        local wantX = mx + (if away > 0.05 then dx / away * pull else 0)
        local wantZ = mz + (if away > 0.05 then dz / away * pull else 0)
        local want = math.sqrt(wantX * wantX + wantZ * wantZ)
        local cap = math.min(top, LIMIT)
        if want > cap then
            wantX, wantZ = wantX / want * cap, wantZ / want * cap
        end
        local velocity = part.AssemblyLinearVelocity
        local stepX, stepZ = wantX - velocity.X, wantZ - velocity.Z
        local step = math.sqrt(stepX * stepX + stepZ * stepZ)
        local most = profile.Accel * math.min(dt, 0.05)
        if step > most then
            stepX, stepZ = stepX / step * most, stepZ / step * most
        end
        local write = Vector3.new(velocity.X + stepX, 0, velocity.Z + stepZ)
        local size = write.Magnitude
        if size > nativeCap then
            write = write * (nativeCap / size)
        end
        moving = true
        pace = write.Magnitude
        mover.Velocity = write
        last = write
        lastAt = now
        Court.hold("Drive", useKey)
        return
    end
    if moving then
        if away <= profile.Stop then
            moving = false
        end
    elseif away > profile.Resume then
        moving = true
    end
    if not moving then
        halt(mover)
        return
    end
    local velocity = part.AssemblyLinearVelocity
    local current = math.sqrt(velocity.X * velocity.X + velocity.Z * velocity.Z)
    local speed = math.max(pace or current, current)
    local top = topSpeed
    local native: Vector3 = mover.Velocity
    local nativeSpeed = math.sqrt(native.X * native.X + native.Z * native.Z)
    if useKey and Court.Held and nativeSpeed > 4 and (not last or (native - last).Magnitude > 0.05) then
        top = math.min(top, nativeSpeed + 0.3)
    end
    speed = math.min(speed + profile.Accel * math.min(dt, 0.05), top)
    pace = speed
    local scale = math.min(speed, profile.Base + away * profile.Gain, LIMIT) / away
    local write = Vector3.new(dx * scale, 0, dz * scale)
    local before = part.AssemblyLinearVelocity
    local change = Vector3.new(write.X - before.X, 0, write.Z - before.Z)
    local most = TURN * math.min(dt, 0.05)
    if change.Magnitude > most then
        write = Vector3.new(before.X, 0, before.Z) + change.Unit * most
    end
    mover.Velocity = write
    last = write
    lastAt = now
    if useKey then
        Court.hold("Drive", true)
    else
        Court.hold("Drive", false)
    end
end

function Drive.stop()
    owner = nil
    local _, mover = Court.proxy()
    halt(mover)
end

return Drive
end
modules["env"] = function(...)

local Env = {}

local httpService: any = game:GetService("HttpService")

local function pick(value: any): any
    return if type(value) == "function" then value else nil
end

local globals: any = nil
if type(getgenv) == "function" then
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then
        globals = env
    end
end
if type(globals) ~= "table" then
    globals = if type(_G) == "table" then _G else {}
end

Env.G = globals
Env.hookmetamethod = pick(hookmetamethod)
Env.newcclosure = pick(newcclosure)
Env.clonefunction = pick(clonefunction)
Env.restorefunction = pick(restorefunction)
Env.getnamecallmethod = pick(getnamecallmethod)
Env.getrawmetatable = pick(getrawmetatable)
Env.setreadonly = pick(setreadonly)
Env.checkcaller = pick(checkcaller)
Env.keypress = pick(keypress)
Env.keyrelease = pick(keyrelease)
Env.filtergc = pick(filtergc)
Env.gethui = pick(gethui)
Env.getgc = pick(getgc)
Env.setidentity = pick(setthreadidentity) or pick(set_thread_identity) or pick(setidentity)
Env.getidentity = pick(getthreadidentity) or pick(get_thread_identity) or pick(getidentity)

local canRead = type(isfile) == "function" and type(readfile) == "function"
local canWrite = type(writefile) == "function"

function Env.get(name: string): any
    return globals[name]
end

function Env.set(name: string, value: any)
    globals[name] = value
end

local function readJson(path: string): any
    if not isfile(path) then
        return nil
    end
    return httpService:JSONDecode(readfile(path))
end

function Env.readJson(path: string): any
    if not canRead then
        return nil
    end
    local ok, value = pcall(readJson, path)
    return if ok and type(value) == "table" then value else nil
end

local function writeJson(path: string, value: any)
    writefile(path, httpService:JSONEncode(value))
end

function Env.writeJson(path: string, value: any): boolean
    if not canWrite then
        return false
    end
    return (pcall(writeJson, path, value))
end

return Env
end
modules["esp"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")
local Config: typeof(require("./config")) = import("config")

local Esp = {}
Esp.__index = Esp

type Map = { [string]: any }

local LIFT = Vector3.new(0, 3.4, 0)
local DROP = Vector3.new(0, 2.8, 0)
local BAR_HEIGHT = 3
local TRACK = Color3.fromRGB(30, 32, 38)
local SEGMENTS = 32
local OFF_SCREEN = 220

local circleX: { number } = table.create(SEGMENTS + 1)
local circleZ: { number } = table.create(SEGMENTS + 1)
for index = 0, SEGMENTS do
    local angle = index / SEGMENTS * math.pi * 2
    circleX[index + 1] = math.cos(angle)
    circleZ[index + 1] = math.sin(angle)
end
local points: { Vector3 } = table.create(SEGMENTS + 1)

local function tint(read: (string) -> any, flag: string): Color3
    local color: any = read(flag)
    local kind = typeof(color)
    return if kind == "Color3" then color else Config.DEFAULTS[flag]
end

function Esp.new(read: (string) -> any): any
    return setmetatable({ Read = read, Labels = setmetatable({}, { __mode = "k" }) :: any }, Esp)
end

local function label(labels: { [any]: Map }, character: any, holder: boolean): string
    local entry = labels[character]
    if not entry then
        entry = {}
        labels[character] = entry
    end
    local role = character:GetAttribute("Position")
    if entry.Text and entry.Role == role and entry.Holder == holder and entry.Name == character.Name then
        return entry.Text
    end
    local text = if role then string.format("%s  ·  %s", character.Name, tostring(role)) else character.Name
    if holder then
        text = "● " .. text
    end
    entry.Text = text
    entry.Role = role
    entry.Holder = holder
    entry.Name = character.Name
    return text
end

local function floorRing(canvas: any, center: Vector3, color: Color3, alpha: number)
    for index = 1, SEGMENTS + 1 do
        points[index] = Vector3.new(center.X + circleX[index] * 1.8, center.Y, center.Z + circleZ[index] * 1.8)
    end
    canvas.worldPath(points, color, 0.15 * alpha, 6)
    canvas.worldPath(points, color, 0.8 * alpha, 2)
end

local function segments(labels: { [any]: Map }, character: any, holder: boolean, color: Color3): any
    local entry = labels[character]
    if not entry then
        entry = {}
        labels[character] = entry
    end
    local role = character:GetAttribute("Position")
    if entry.Runs and entry.RunRole == role and entry.RunHolder == holder and entry.RunColor == color and entry.RunName == character.Name then
        return entry.Runs
    end
    local runs: { any } = { { Text = character.Name, Color = color } }
    if role then
        runs[2] = { Text = tostring(role), Color = "Sub" }
    end
    local built = { runs }
    entry.Runs, entry.RunRole, entry.RunHolder, entry.RunColor, entry.RunName = built, role, holder, color, character.Name
    return built
end

function Esp.draw(self: any, canvas: any, chip: any?)
    local read = self.Read
    local root = Court.Root
    if read("Esp") ~= true or not canvas or not root then
        return
    end
    local here: Vector3 = root.Position
    local maxDistance = read("EspDistance") or 300
    local showTeam = read("EspTeam") == true
    local showStamina = read("EspStamina") == true
    local size = read("EspTextSize") or 13
    local background = read("EspBackground") or 0.2
    local enemyColor = tint(read, "ColorEnemy")
    local teamColor = tint(read, "ColorTeam")
    local holderColor = tint(read, "ColorHolder")
    local backColor = tint(read, "ColorBackground")
    local onlyBall = read("EspBallOnly") == true
    local opacity = math.clamp(tonumber(read("ContestOpacity")) or 0.85, 0.1, 1)
    local chars, roots, foe, carry = Court.Chars, Court.Roots, Court.Foe, Court.Carry
    local margin = OFF_SCREEN * math.max(1, size / 13)
    local viewW, viewH = math.huge, math.huge
    pcall(function()
        local view = workspace.CurrentCamera.ViewportSize
        viewW, viewH = view.X + margin, view.Y + margin
    end)
    local labels = self.Labels
    for index = 1, Court.Count do
        local enemy = foe[index]
        local holder = carry[index]
        local other = roots[index]
        if (enemy or showTeam) and (holder or not onlyBall) and other.Parent ~= nil then
            local where: Vector3 = other.Position
            local distance = (where - here).Magnitude
            if distance <= maxDistance then
                local fade = math.clamp((maxDistance - distance) / (maxDistance * 0.2), 0, 1)
                local color = if holder then holderColor elseif enemy then enemyColor else teamColor
                if holder then
                    floorRing(canvas, where - DROP, holderColor, fade)
                end
                local point, depth = canvas.project(where + LIFT)
                if point and depth > 0 and point.X > -margin and point.Y > -margin and point.X < viewW and point.Y < viewH then
                    local character = chars[index]
                    local stamina = if showStamina then character:GetAttribute("Stamina") else nil
                    if chip then
                        local runs = segments(labels, character, holder, color)
                        local entry = labels[character]
                        local name = character.Name
                        if entry.KeyName ~= name then
                            entry.KeyName, entry.Key = name, "esp:" .. name
                        end
                        local bar: any = nil
                        if type(stamina) == "number" then
                            bar = entry.Bar or {}
                            entry.Bar = bar
                            bar.Value, bar.Color = math.clamp(stamina / 100, 0, 1), color
                        end
                        chip(entry.Key, point, runs, fade * opacity, size / 13, bar)
                    else
                        canvas.label(point, size, color, label(labels, character, holder), backColor, background * fade)
                        if type(stamina) == "number" then
                            local share = math.clamp(stamina / 100, 0, 1)
                            local width = math.max(size * 3.2, 34)
                            local corner = Vector2.new(point.X - width / 2, point.Y + size * 0.75 + 2)
                            canvas.filledRect(corner, Vector2.new(width, BAR_HEIGHT), TRACK, 0.7 * fade)
                            canvas.filledRect(corner, Vector2.new(width * share, BAR_HEIGHT), color, 0.9 * fade)
                        end
                    end
                end
            end
        end
    end
end

return Esp
end
modules["glide"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")

local Glide = {}
Glide.__index = Glide

local ACTIONS: { [string]: string } = { Dribbling = "DribbleGlide", Gathering = "GatherGlide", Shooting = "ShotGlide" }

local LIMIT = 27

function Glide.new(read: (string) -> any): any
    return setmetatable({ Read = read, Action = nil :: any, Direction = nil :: Vector3?, Speed = 0 }, Glide)
end

function Glide.physics(self: any)
    local mine = Court.Mine
    local action = if mine then mine:GetAttribute("Action") else nil
    local flag = if type(action) == "string" then ACTIONS[action] else nil
    local part, mover = Court.proxy()
    local now = os.clock()
    if not flag and part then
        local velocity = part.AssemblyLinearVelocity
        local planar = Vector3.new(velocity.X, 0, velocity.Z)
        if planar.Magnitude > 2 then
            self.Ran, self.RanAt, self.RanSpeed = planar.Unit, now, planar.Magnitude
        end
    end
    if not mine or not flag or self.Read(flag) ~= true or mine:GetAttribute("CanMove") == true then
        self.Action = nil
        return
    end
    if not part or not mover then
        return
    end
    local dt = math.min(now - (self.Last or now), 0.1)
    self.Last = now
    if self.Action ~= action then
        self.Action = action
        self.Since = now
        local velocity = part.AssemblyLinearVelocity
        local planar = Vector3.new(velocity.X, 0, velocity.Z)
        self.Speed = planar.Magnitude
        self.Entry = math.min(planar.Magnitude, LIMIT)
        self.Direction = if planar.Magnitude > 1 then planar.Unit else nil
        if planar.Magnitude < 2 and self.RanAt and now - self.RanAt < 0.7 then
            self.Speed = self.RanSpeed
            self.Entry = math.min(self.RanSpeed, LIMIT)
            self.Direction = self.Ran
        end
    end
    local heading = Court.heading()
    local direction: Vector3? = heading or self.Direction
    if not direction then
        return
    end
    local limit: number = self.Read(flag .. "Speed") or 10
    if action == "Shooting" then
        limit = math.min(limit, 8)
        if now - (self.Since or now) > 0.3 then
            return
        end
    end
    if not heading then
        self.Speed = self.Speed * math.exp(-3 * dt)
    end
    local entry: number = self.Entry or limit
    local cap = limit + math.max(entry - limit, 0) * math.exp(-10 * (now - (self.Since or now)))
    local speed: number = math.min(self.Speed, cap)
    if speed < 2 then
        return
    end
    if action == "Shooting" then
        local distance, rim = Court.rimDistance(part.Position)
        if distance and rim and distance < 24 then
            local toRim = Vector3.new(rim.Position.X - part.Position.X, 0, rim.Position.Z - part.Position.Z)
            if distance < 4.5 or (toRim.Magnitude > 0.1 and toRim.Unit:Dot(direction) < 0.2) then
                return
            end
            speed = math.min(speed, distance * 2.5)
        end
    end
    mover.Velocity = direction * math.min(speed, LIMIT)
end

return Glide
end
modules["hook"] = function(...)

local import: (string) -> any = ...
local Env: typeof(require("./env")) = import("env")
local Court: typeof(require("./court")) = import("court")
local Aero: typeof(require("./aero")) = import("aero")

local Hook = {}

type Map = { [string]: any }

local NAME = "__PBShootHook"
local VERSION = 6

local CAPTURE = { Sprint = true, Steal = true, Pass = true, Dribble = true, Jump = true, Clutch = true, HoldG = true }

local getMethod: any = Env.getnamecallmethod
local ours: any = Env.checkcaller
local stopped = false

local function isPress(args: any): boolean
    for index = 1, args.n do
        local value = args[index]
        if type(value) == "boolean" then
            return value
        end
        if type(value) == "table" then
            for _, inner in value do
                if type(inner) == "boolean" then
                    return inner
                end
            end
        end
    end
    return true
end

local function dribbleKey(args: any): string
    for index = 1, args.n do
        local value = args[index]
        if type(value) == "string" then
            return value
        end
        if type(value) == "table" then
            for _, inner in value do
                if type(inner) == "string" then
                    return inner
                end
            end
        end
    end
    return "any"
end

local function capture(state: Map, name: string, args: any)
    local press = isPress(args)
    state.Calls[name] = args
    if press then
        state.Press[name] = args
    end
    if name == "Dribble" then
        local key = dribbleKey(args)
        if press or not state.Dribbles[key] then
            state.Dribbles[key] = args
        end
    end
    if name == "Sprint" and press then
        task.wait(0.25)
        local mine = Court.mine()
        if mine ~= nil and mine:GetAttribute("Sprinting") == true then
            state.SprintOn = args
        end
    end
end

local function watch(state: Map, remote: any, ...: any): boolean
    if not getMethod or getMethod() ~= "FireServer" or typeof(remote) ~= "Instance" then
        return false
    end
    if Court.Sending > 0 or (ours and ours()) then
        return false
    end
    local parent = remote.Parent
    if not parent or parent.Name ~= "InputService" then
        return false
    end
    local name = remote.Name
    if CAPTURE[name] then
        local args = table.pack(...)
        local queue = state.Queue
        if #queue < 32 then
            queue[#queue + 1] = { name, args }
        end
        local owner = state.Owner
        if name == "Dribble" and type(owner) == "table" and type(owner.BlockDribble) == "function" then
            return owner.BlockDribble(args) == true
        end
        return false
    end
    if name ~= "Shoot" then
        return false
    end
    local owner = state.Owner
    if type(owner) ~= "table" then
        return false
    end
    local data = ...
    if type(data) ~= "table" then
        return false
    end
    local flag = rawget(data, "Shoot")
    if flag == true then
        owner.KeyDown = true
        owner.PressPending = true
        owner.DunkPress = rawget(data, "UseSpace") == true
        return false
    end
    if flag ~= false then
        return false
    end
    owner.KeyDown = false
    if rawget(data, "Input") ~= nil then
        return false
    end
    if owner.holding(owner) then
        if owner.Held == nil then
            owner.Held = os.clock()
        end
        return true
    end
    owner.passed(owner)
    return false
end

local function wrapped(state: Map, name: string, ...: any): boolean
    if CAPTURE[name] then
        local args = table.pack(...)
        task.spawn(capture, state, name, args)
        local owner = state.Owner
        if name == "Dribble" and type(owner) == "table" and type(owner.BlockDribble) == "function" then
            return owner.BlockDribble(args) == true
        end
        return false
    end
    if name ~= "Shoot" then
        return false
    end
    local owner = state.Owner
    if type(owner) ~= "table" or type(owner.shootCall) ~= "function" then
        return false
    end
    return owner:shootCall((...)) == true
end

local function rawNamecall(): any
    local getMeta = Env.getrawmetatable
    if not getMeta then
        return nil
    end
    local ok, meta = pcall(getMeta, game)
    if ok and type(meta) == "table" then
        return rawget(meta, "__namecall")
    end
    return nil
end

local function writeNamecall(target: any): boolean
    local getMeta = Env.getrawmetatable
    if not getMeta or type(target) ~= "function" then
        return false
    end
    return (pcall(function()
        local meta = getMeta(game)
        local lock = Env.setreadonly
        if lock then
            lock(meta, false)
        end
        rawset(meta, "__namecall", target)
        if lock then
            lock(meta, true)
        end
    end))
end

local function probe(): boolean
    local folder = Instance.new("Folder")
    folder.Name = "probe"
    local found = folder:FindFirstChild("none")
    local isFolder = folder:IsA("Folder")
    local isPart = folder:IsA("BasePart")
    local service = game:GetService("Players")
    local children = workspace:GetChildren()
    folder:Destroy()
    return found == nil and isFolder == true and isPart == false and typeof(service) == "Instance" and type(children) == "table"
end

local function live(state: Map): (boolean, boolean)
    local seen = false
    local before, off = state.Watch, state.Off
    state.Watch = function(): boolean
        seen = true
        return false
    end
    state.Off = nil
    local ok, works = pcall(probe)
    state.Watch = before
    state.Off = off
    return seen, ok and works == true
end

local function putBack(state: Map)
    local target: any = state.Clean or state.Original
    if type(target) ~= "function" then
        return
    end
    local hookMeta = Env.hookmetamethod
    if hookMeta then
        pcall(hookMeta, game, "__namecall", target)
    end
    local current = rawNamecall()
    if current ~= nil and current == state.Wrapped then
        writeNamecall(target)
    end
end

function Hook.install(): (any?, string?)
    local existing = Env.get(NAME)
    if type(existing) == "table" and existing.Mode == "wrap" then
        existing.Owner = nil
        Env.set(NAME, nil)
        existing = nil
    end
    if type(existing) == "table" then
        if existing.Version ~= VERSION or existing.Broken then
            existing.Owner = nil
            return nil, if existing.Broken then "broken" else "old"
        end
        local _, answers = live(existing)
        if answers then
            existing.Claim = Hook
            existing.Watch = watch
            existing.Off = nil
            return existing, nil
        end
        existing.Off = true
        existing.Owner = nil
        Env.set(NAME, nil)
    end
    local hookMeta = Env.hookmetamethod
    local original: any = rawNamecall()
    if not getMethod or (not hookMeta and (type(original) ~= "function" or not Env.setreadonly)) then
        return nil, "unsupported"
    end
    local clean: any = original
    if type(original) == "function" and Env.clonefunction then
        local cloned, copy = pcall(Env.clonefunction, original)
        if cloned and type(copy) == "function" then
            clean = copy
        end
    end
    local state: Map = {
        Owner = nil,
        Version = VERSION,
        Watch = watch,
        SprintOn = nil,
        Calls = {},
        Queue = {},
        Press = {},
        Dribbles = {},
        Original = original,
        Clean = clean,
        Claim = Hook,
    }
    local old: any = clean
    local function body(self: any, ...: any): ...any
        if not state.Off and getMethod and getMethod() == "FireServer" then
            local ok, hold = pcall(state.Watch, state, self, ...)
            if ok and hold == true then
                return
            end
        end
        return (old or clean)(self, ...)
    end
    if stopped then
        return nil, "stopped"
    end
    local why = "unsupported"
    local wrappers: { any } = {}
    if Env.newcclosure then
        table.insert(wrappers, Env.newcclosure)
    end
    table.insert(wrappers, false)
    Env.set(NAME, state)
    for _, wrap in wrappers do
        local wrapped: any = body
        if wrap then
            local made, closure = pcall(wrap, body)
            wrapped = if made and type(closure) == "function" then closure else nil
        end
        if wrapped then
            state.Wrapped = wrapped
            state.Off = nil
            old = clean
            local placed = false
            if hookMeta then
                local hookedOk, hooked = pcall(hookMeta, game, "__namecall", wrapped)
                placed = hookedOk
                if hookedOk and type(hooked) == "function" and hooked ~= wrapped then
                    old = hooked
                    if type(state.Clean) ~= "function" then
                        state.Clean = hooked
                        clean = hooked
                    end
                end
            elseif type(clean) == "function" then
                placed = writeNamecall(wrapped)
            end
            local seen, works = live(state)
            local fine = placed and works
            if stopped then
                state.Off = true
                old = clean
                putBack(state)
                if live(state) then
                    state.Broken = true
                else
                    Env.set(NAME, nil)
                end
                return nil, "stopped"
            end
            if fine then
                return state, nil
            end
            why = "broken"
            state.Off = true
            old = clean
            if seen or not works then
                putBack(state)
                if live(state) then
                    state.Broken = true
                    state.Owner = nil
                    return nil, "broken"
                end
            end
        end
    end
    Env.set(NAME, nil)
    return nil, why
end

function Hook.drain()
    local state = Env.get(NAME)
    if type(state) ~= "table" or state.Claim ~= Hook then
        return
    end
    local queue = state.Queue
    if type(queue) ~= "table" or #queue == 0 then
        return
    end
    state.Queue = {}
    for _, item in queue do
        task.spawn(capture, state, item[1], item[2])
    end
end

local function bindWrap(owner: any, light: boolean?): boolean
    local existing = Env.get(NAME)
    local state: Map = if type(existing) == "table" and existing.Mode == "wrap" and existing.Version == VERSION
        then existing
        else { Version = VERSION, Mode = "wrap", SprintOn = nil, Calls = {}, Queue = {}, Press = {}, Dribbles = {} }
    if type(existing) == "table" and existing ~= state then
        existing.Owner = nil
    end
    local installed = Aero.install(function(name: string, ...: any): boolean
        return wrapped(state, name, ...)
    end, light)
    if not installed then
        return false
    end
    state.Claim = Hook
    state.Off = nil
    state.Owner = owner
    Env.set(NAME, state)
    return true
end

function Hook.bind(owner: any, allowHook: boolean?, light: boolean?): (boolean, string?)
    local done, wrappedOk = pcall(bindWrap, owner, light)
    if done and wrappedOk then
        return true, "wrap"
    end
    if allowHook == false then
        return false, "safe"
    end
    local ok, state, why = pcall(Hook.install)
    if ok and type(state) == "table" then
        state.Owner = owner
        return true, "hook"
    end
    return false, if ok then why else "broken"
end

function Hook.owned(owner: any): boolean
    local state = Env.get(NAME)
    if type(state) ~= "table" or state.Claim ~= Hook or state.Owner ~= owner or state.Off then
        return false
    end
    if state.Mode == "wrap" then
        return Aero.intact()
    end
    return true
end

function Hook.mode(): string?
    local state = Env.get(NAME)
    if type(state) ~= "table" or state.Claim ~= Hook or state.Off then
        return nil
    end
    return if state.Mode == "wrap" then "wrap" else "hook"
end

function Hook.remove()
    stopped = true
    local state = Env.get(NAME)
    if type(state) ~= "table" or state.Version ~= VERSION or state.Claim ~= Hook then
        return
    end
    if state.Mode == "wrap" then
        state.Off = true
        state.Owner = nil
        Aero.remove()
        Env.set(NAME, nil)
        return
    end
    state.Off = true
    state.Owner = nil
    if state.Broken then
        return
    end
    local current = rawNamecall()
    if current == nil or current ~= state.Wrapped then
        return
    end
    putBack(state)
    local seen = live(state)
    state.Off = true
    if not seen then
        Env.set(NAME, nil)
    end
end

return Hook
end
modules["interface"] = function(...)

local import: (string) -> any = ...
local Changelog: typeof(require("./changelog")) = import("changelog")
local Config: typeof(require("./config")) = import("config")

local Interface = {}

local function studs(value: number): string
    local text = string.format("%.1f", value)
    return (string.gsub(text, "%.0$", "")) .. " studs"
end

local function fraction(value: number): string
    return string.format("%.2f", value)
end

local function milliseconds(value: number): string
    return string.format("%+d ms", math.floor(value + 0.5))
end

local function percent(value: number): string
    return string.format("%d%%", math.floor(value + 0.5))
end

local function number(value: number): string
    return tostring(math.floor(value + 0.5))
end

local function length(value: number): string
    return string.format("%d ms", math.floor(value + 0.5))
end

local function delay(value: number): string
    return if value <= 0 then "Instant" else string.format("%d ms", math.floor(value + 0.5))
end

local PRESET_FLAGS = {
    "AutoGreen", "PerfectChance", "AutoCalibrate", "OpenShot", "AutoShoot", "AutoDunk",
    "AutoGuard", "GuardMove", "AutoSteal", "AutoBlock", "AutoRebound",
    "MoveKeys", "BlockDribbleKeys", "DribbleCombo", "AutoPass", "AutoDribble",
    "DribbleGlide", "DribbleGlideSteer", "GatherGlide", "GatherGlideSteer", "ShotGlide", "ShotGlideSteer",
    "AlwaysSprint", "FullSpeed", "NoStun", "NoDebounce", "NoCold",
    "Esp", "EspTeam", "EspStamina", "ThreePointLine", "DunkZones", "ShotRangeViz", "RangeViz",
}

local function preset(on: { [string]: any }): { [string]: any }
    local values: { [string]: any } = {}
    for _, flag in PRESET_FLAGS do
        local default = Config.DEFAULTS[flag]
        values[flag] = if on[flag] ~= nil then on[flag] elseif type(default) == "boolean" and not Config.PARENT[flag] then false else default
    end
    return values
end

function Interface.build(ui: any, actions: { [string]: any }?)
    local defaults = Config.DEFAULTS
    local function act(name: string, ...: any)
        local run = if actions then actions[name] else nil
        if type(run) == "function" then
            pcall(run, ...)
        end
    end

    local presets = {
        { Name = "Off", Values = preset({}) },
        { Name = "Casual", Values = preset({ AutoGreen = true, PerfectChance = 85, AutoCalibrate = true, OpenShot = true }) },
        { Name = "Legit", Values = preset({ AutoGreen = true, PerfectChance = 100, AutoCalibrate = true, OpenShot = true, AutoGuard = true, GuardMove = true, DribbleGlide = true }) },
        {
            Name = "Full",
            Values = preset({
                AutoGreen = true, PerfectChance = 100, AutoCalibrate = true, OpenShot = true, AutoShoot = true, AutoDunk = true,
                AutoGuard = true, GuardMove = true, AutoSteal = true, AutoBlock = true, AutoRebound = true,
                MoveKeys = false, BlockDribbleKeys = false, DribbleCombo = false, AutoPass = true, AutoDribble = true,
                DribbleGlide = true, DribbleGlideSteer = true, GatherGlide = true, GatherGlideSteer = true, ShotGlide = true, ShotGlideSteer = true,
                AlwaysSprint = false, FullSpeed = true, NoStun = true, NoDebounce = true, NoCold = true,
                Esp = true, EspTeam = true, EspStamina = true, ThreePointLine = true, DunkZones = true, ShotRangeViz = true, RangeViz = true,
            }),
        },
    }
    local function presetCard(index: number, text: string, icon: string): { [string]: any }
        local values = presets[index].Values
        local function matches(): boolean
            for flag, value in values do
                if ui:get(flag) ~= value then
                    return false
                end
            end
            return true
        end
        return {
            Title = presets[index].Name,
            Icon = icon,
            Text = text,
            Active = matches,
            Callback = function(window: any)
                for flag, value in values do
                    ui:set(flag, value)
                end
                window:announce(presets[index].Name .. " preset applied")
            end,
        }
    end
    ui:home({
        QuickStart = {
            presetCard(2, "Auto Green, sometimes misses", "target"),
            presetCard(3, "Green, guard and glide", "shield"),
            presetCard(4, "Every helper, visual and status option on", "zap"),
            presetCard(1, "Every feature off", "eye"),
        },
    })

    local function toggle(name: string, flag: string): { [string]: any }
        return { Name = name, Flag = flag, Default = defaults[flag] }
    end
    local function slider(name: string, flag: string, low: number, high: number, step: number, format: ((number) -> string)?): { [string]: any }
        return { Name = name, Flag = flag, Min = low, Max = high, Step = step, Default = defaults[flag], Format = format }
    end

    local shootTab = ui:tab("Shoot")
    local shoot = shootTab:section("SHOOT")
    shoot:presets({ Name = "Preset", Presets = presets })
    shoot:cards({
        Columns = 2,
        Items = {
            {
                Title = "Auto Green",
                Text = "Lets go of your shot on the green",
                Flag = "AutoGreen",
                Default = defaults.AutoGreen,
                Keywords = "release perfect timing shoot",
                Controls = {
                    slider("Release Timing", "GreenOffset", -60, 60, 1, milliseconds),
                },
                Advanced = {
                    slider("Perfect Chance", "PerfectChance", 0, 100, 5, percent),
                    slider("Ping Compensation", "PingComp", 0, 100, 5, percent),
                    toggle("Tap To Shoot", "TapShoot"),
                    toggle("Self Calibrate", "AutoCalibrate"),
                    {
                        Type = "Button",
                        Name = "Reset Calibration",
                        Label = "Reset",
                        Callback = function()
                            act("resetCalibration")
                        end,
                    },
                    toggle("Time Layups and Dunks", "LayupGreen"),
                    toggle("Stay In Front Of Rim", "RimFront"),
                    {
                        Name = "Compatibility Fix",
                        Keywords = "safe mode compatibility executor hook",
                        Flag = "SafeMode",
                        Default = defaults.SafeMode,
                        Info = {
                            Title = "Compatibility Fix",
                            Lines = {
                                "Auto Green normally hooks into the game to let go",
                                "at the perfect time. Some executors cant do that.",
                                "",
                                "This turns the hook off. It only presses and",
                                "releases the shoot key, so it works on any executor.",
                                "",
                                "Turn it on if Auto Green errors or does nothing.",
                                "Your shots might be a tiny bit less perfect.",
                                },
                            Width = 360,
                        },
                    },
                },
            },
            {
                Title = "Shot Contest",
                Name = "Shot Contest",
                Text = "Shows how contested your shot is: open, contested or smothered",
                Flag = "OpenShot",
                Default = defaults.OpenShot,
                Keywords = "shot contest contested open look number defender",
                Controls = {
                    toggle("Contest Label Over Head", "OpenShotNumber"),
                    toggle("Contest Colors On Character", "OpenShotGlow"),
                },
                Advanced = {
                    slider("Glow Strength", "GlowStrength", 10, 100, 5, percent),
                    toggle("Only With Ball", "OpenShotBall"),
                    slider("Contest Range", "ContestRange", 3, 15, 0.5, studs),
                    { Type = "Dropdown", Name = "Label Style", Flag = "ContestStyle", Values = Config.CONTEST_STYLES, Default = defaults.ContestStyle },
                    toggle("Show Who Contests", "ContestWho"),
                    toggle("Mark The Contester", "ContestFoeMark"),
                    slider("Label Size", "ContestTextSize", 9, 24, 1, number),
                    slider("Label Height", "ContestHeight", 2, 8, 0.2, studs),
                    { Type = "Dropdown", Name = "Label Color", Flag = "ContestColorMode", Values = Config.CONTEST_COLORS, Default = defaults.ContestColorMode },
                    { Type = "Color", Name = "Custom Label Color", Flag = "ContestLabelColor", Default = defaults.ContestLabelColor },
                    slider("Label View Distance", "ContestViewRange", 20, 300, 10, studs),
                    slider("Label Opacity", "ContestOpacity", 0.2, 1, 0.05, fraction),
                },
            },
            {
                Title = "Auto Shoot",
                Text = "Takes the shot when you are open and in range",
                Flag = "AutoShoot",
                Default = defaults.AutoShoot,
                Controls = { slider("Shoot Range", "ShootRange", 8, 45, 1, studs) },
                Advanced = {
                    slider("Shoot Delay", "ShootDelay", 0, 1500, 50, delay),
                    toggle("Only When Open", "OpenOnly"),
                    slider("Open Range", "OpenRange", 2, 30, 1, studs),
                    slider("Max Contest", "MaxContest", 0, 100, 5, percent),
                    slider("Min Shot Distance", "MinShot", 0, 60, 1, studs),
                    slider("Max Shot Distance", "MaxShot", 10, 120, 1, studs),
                },
            },
            {
                Title = "Auto Dunk",
                Text = "Dunks from the right spot when a rim is ahead",
                Flag = "AutoDunk",
                Default = defaults.AutoDunk,
                Controls = {
                    { Type = "Dropdown", Name = "Dunk Type", Flag = "DunkType", Values = Config.DUNK_TYPES, Default = defaults.DunkType, Segment = true },
                },
                Advanced = {
                    toggle("Move Me To The Rim (!)", "DunkMove"),
                    slider("Dunk Range", "DunkRange", 10, 60, 1, studs),
                    toggle("Only When Open", "DunkOpenOnly"),
                },
            },
        },
    })

    local defendTab = ui:tab("Defend")
    local defend = defendTab:section("DEFEND")
    defend:cards({
        Columns = 2,
        Items = {
            {
                Title = "Auto Guard",
                Text = "Holds guard on your man once he is close and slides with him between him and the rim",
                Flag = "AutoGuard",
                Default = defaults.AutoGuard,
                Controls = {
                    toggle("Move With Him", "GuardMove"),
                    { Type = "Dropdown", Name = "Guard", Flag = "GuardTarget", Values = Config.GUARD_TARGETS, Default = defaults.GuardTarget, Segment = true },
                },
                Advanced = {
                    slider("Guard Range", "GuardRange", 5, 40, 1, studs),
                    slider("Move Distance", "GuardGap", 5, 30, 1, studs),
                    toggle("Guard Only When Facing", "GuardFacing"),
                },
            },
            {
                Title = "Auto Steal",
                Text = "Reaches in when the handler stands still next to you",
                Flag = "AutoSteal",
                Default = defaults.AutoSteal,
                Controls = { slider("Steal Range", "StealRange", 3, 15, 1, studs) },
                Advanced = {
                    toggle("Only When Facing", "StealFacing"),
                    toggle("Avoid Fouls", "AvoidFouls"),
                },
            },
            {
                Title = "Auto Block",
                Text = "Jumps when someone close to you starts a shot",
                Flag = "AutoBlock",
                Default = defaults.AutoBlock,
                Controls = { slider("Block Range", "BlockRange", 4, 20, 1, studs) },
                Advanced = {
                    toggle("Read Fakes", "ReadFakes"),
                    slider("Block Delay", "BlockDelay", 0, 400, 10, delay),
                },
            },
            {
                Title = "Auto Rebound",
                Text = "Jumps for a ball coming off the rim",
                Flag = "AutoRebound",
                Default = defaults.AutoRebound,
                Controls = { slider("Rebound Range", "ReboundRange", 3, 16, 1, studs) },
                Advanced = {
                    toggle("Ball Magnet (!)", "BallMagnet"),
                    slider("Magnet Range", "MagnetRange", 5, 50, 1, studs),
                },
            },
        },
    })

    local handleTab = ui:tab("Handle")
    local handle = handleTab:section("HANDLE")
    handle:cards({
        Columns = 2,
        Items = {
            {
                Title = "Move Keys",
                Text = "Press your own key to play a dribble move, bind them below",
                Flag = "MoveKeys",
                Default = defaults.MoveKeys,
                Name = "Move Keybinds",
                Keywords = "dribble crossover hesitation spin keys",
                Controls = {
                    toggle("Block Game Dribble Keys", "BlockDribbleKeys"),
                    { Type = "Note", Text = "On: the game's own dribble keys are fully turned off.\nOff: only the keys you bind here replace the game's, the rest still work." },
                },
            },
            {
                Title = "Combos",
                Text = "Plays a chain of moves once per key press",
                Controls = {
                    { Type = "Dropdown", Name = "Combo", Flag = "ComboMoves", Values = Config.COMBO_NAMES, Default = defaults.ComboMoves },
                    { Type = "Button", Name = "Play Combo", Label = "Play", Bind = "PlayCombo", Callback = function()
                        act("playCombo")
                    end },
                },
                Advanced = {
                    toggle("Loop Combo", "DribbleCombo"),
                    toggle("Stop After One Loop", "ComboOnce"),
                    toggle("Only When Guarded", "ComboGuarded"),
                },
            },
        },
    })
    local names: { [string]: string } = {}
    for _, entry in Config.MOVE_KEYS do
        names[entry[2]] = entry[1]
    end
    local tiles = {}
    for _, move in { "Crossover", "Hesitation", "Tween", "DoubleCrossover", "BehindBack", "Spin", "HalfSpin", "StepBack", "SnatchBack", "Breakdown" } do
        local inputs = Config.MOVE_INPUTS[move]
        table.insert(tiles, {
            Name = names[move] or move,
            Sub = "Right hand: " .. inputs.R .. "\nLeft hand: " .. inputs.L,
            Bind = "Move" .. move,
            Callback = function()
                act("playMove", move)
            end,
        })
    end
    handle:grid({ Items = tiles, Columns = 3, TileHeight = 78 })
    handle:cards({
        Columns = 2,
        Items = {
            {
                Title = "Ball Handler",
                Text = "Passes and moves for you when a defender is on you",
                Controls = { toggle("Pass To Open Teammate", "AutoPass"), toggle("Moves When Guarded", "AutoDribble") },
                Advanced = {
                    slider("Pressure Distance", "PassPressure", 2, 15, 1, studs),
                    slider("Guarded Distance", "DribbleRange", 3, 15, 1, studs),
                },
            },
            {
                Title = "Dribble Glide",
                Text = "Keeps a bit of your speed through a dribble move. It only follows the way the move already goes",
                Flag = "DribbleGlide",
                Default = defaults.DribbleGlide,
                Controls = { slider("Strength", "DribbleGlideStrength", 10, 90, 5, percent) },
                Advanced = {
                    slider("Top Speed", "DribbleGlideSpeed", 4, 12, 1, number),
                    slider("Length", "DribbleGlideTime", 100, 600, 20, length),
                    toggle("Steer With Keys", "DribbleGlideSteer"),
                },
            },
            {
                Title = "Gather Step Glide",
                Text = "Keeps your full run speed through a hop step or gather toward the rim, then eases off. It stays off inside layup range",
                Flag = "GatherGlide",
                Default = defaults.GatherGlide,
                Controls = { slider("Strength", "GatherGlideStrength", 10, 100, 5, percent) },
                Advanced = {
                    slider("Top Speed", "GatherGlideSpeed", 4, 16, 1, number),
                    slider("Length", "GatherGlideTime", 100, 600, 20, length),
                    toggle("Steer With Keys", "GatherGlideSteer"),
                },
            },
            {
                Title = "Shot Glide",
                Text = "Keeps you moving on your line as the shot starts, then eases off. It never carries you into layup range",
                Flag = "ShotGlide",
                Default = defaults.ShotGlide,
                Controls = { slider("Strength", "ShotGlideStrength", 10, 90, 5, percent) },
                Advanced = {
                    slider("Top Speed", "ShotGlideSpeed", 3, 16, 1, number),
                    slider("Length", "ShotGlideTime", 100, 600, 20, length),
                    toggle("Steer With Keys", "ShotGlideSteer"),
                },
            },
        },
    })

    local playerTab = ui:tab("Player")
    local player = playerTab:section("PLAYER")
    player:cards({
        Columns = 2,
        Items = {
            {
                Title = "Speed And Stamina",
                Text = "Sprinting and staying fast when tired",
                Controls = { toggle("Always Sprint", "AlwaysSprint"), toggle("Always Full Speed", "FullSpeed"), toggle("Full Stamina Bar (client only)", "InfStamina") },
                Advanced = { toggle("Custom Walk Speed (!)", "CustomSpeed"), slider("Walk Speed", "WalkSpeed", 8, 20, 1, number) },
            },
            {
                Title = "Status",
                Text = "Clears what the game slows you down with",
                Controls = { toggle("No Stun", "NoStun"), toggle("No Debounce", "NoDebounce"), toggle("No Cold Zone", "NoCold") },
            },
        },
    })

    local visualTab = ui:tab("Visuals")
    local visual = visualTab:section("VISUALS")
    visual:cards({
        Columns = 2,
        Items = {
            {
                Title = "Court",
                Text = "Lines and zones drawn on the floor",
                Controls = { toggle("Three Point Line", "ThreePointLine"), toggle("Dunk Zones", "DunkZones"), toggle("Auto Shot Range", "ShotRangeViz"), toggle("My Ranges", "RangeViz") },
            },
            {
                Title = "Players",
                Text = "Names, positions and stamina over players",
                Flag = "Esp",
                Name = "Player ESP",
                Default = defaults.Esp,
                Controls = { toggle("Show Teammates", "EspTeam"), toggle("Show Stamina", "EspStamina"), toggle("Ball Handler Only", "EspBallOnly") },
                Advanced = {
                    slider("Max Distance", "EspDistance", 50, 600, 10, studs),
                    slider("Text Size", "EspTextSize", 9, 22, 1, number),
                },
            },
        },
    })
    visual:palette({
        Title = "Colors",
        Text = "The colors of the lines, rings and labels",
        Items = {
            { Type = "Color", Name = "Enemy", Flag = "ColorEnemy", Default = defaults.ColorEnemy },
            { Type = "Color", Name = "Teammate", Flag = "ColorTeam", Default = defaults.ColorTeam },
            { Type = "Color", Name = "Ball Holder", Flag = "ColorHolder", Default = defaults.ColorHolder },
            { Type = "Color", Name = "Steal Range", Flag = "StealColor", Default = defaults.StealColor },
            { Type = "Color", Name = "Guard Range", Flag = "GuardColor", Default = defaults.GuardColor },
            { Type = "Color", Name = "Block Range", Flag = "BlockColor", Default = defaults.BlockColor },
            { Type = "Color", Name = "Shot Range And Lines", Flag = "ShotColor", Default = defaults.ShotColor },
        },
    })

    ui:updates({ Version = Changelog.VERSION, Date = Changelog.DATE, Groups = Changelog.GROUPS, History = Changelog.HISTORY, Closing = Changelog.CLOSING })
end

return Interface
end
modules["main"] = function(...)

local import: (string) -> any = ...
local Changelog: typeof(require("./changelog")) = import("changelog")
local Config: typeof(require("./config")) = import("config")
local Court: typeof(require("./court")) = import("court")
local Drive: typeof(require("./drive")) = import("drive")
local Env: typeof(require("./env")) = import("env")
local AutoGreen: typeof(require("./autogreen")) = import("autogreen")
local AutoShoot: typeof(require("./autoshoot")) = import("autoshoot")
local AutoDunk: typeof(require("./autodunk")) = import("autodunk")
local AutoBlock: typeof(require("./autoblock")) = import("autoblock")
local AutoRebound: typeof(require("./autorebound")) = import("autorebound")
local AutoPass: typeof(require("./autopass")) = import("autopass")
local AutoDribble: typeof(require("./autodribble")) = import("autodribble")
local BallMagnet: typeof(require("./ballmagnet")) = import("ballmagnet")
local Combo: typeof(require("./combo")) = import("combo")
local Contest: typeof(require("./contest")) = import("contest")
local Defense: typeof(require("./defense")) = import("defense")
local Esp: typeof(require("./esp")) = import("esp")
local Glide: typeof(require("./glide")) = import("glide")
local Interface: typeof(require("./interface")) = import("interface")
local Moves: typeof(require("./moves")) = import("moves")
local Player: typeof(require("./player")) = import("player")
local RimGuard: typeof(require("./rimguard")) = import("rimguard")
local Rings: typeof(require("./rings")) = import("rings")

local REGISTRY = "__PracticalBasketballStop"
local READER = "__PBRead"
local TELEPORT_URL = "https://raw.githubusercontent.com/okdude42/main-scripts/main/practical-basketball/pb.lua"
local GAME_ID = 7529591378
local MENU_ID = "Practical Basketball"
local HOOK_DELAY = 0.8

local COPY_FLAGS = { "AutoGreen", "AlwaysSprint", "AutoDribble", "DribbleCombo", "BlockDribbleKeys", "MoveKeys" }
local WATCHED = { "Action", "CanMove", "Stunned", "Debounce", "DodgeDebounce", "BoxoutPushDebounce", "Cold", "Stamina", "Sprinting", "HoldingG" }

type Map = { [string]: any }

local function stopPrevious()
    local previous = Env.get(REGISTRY)
    local instances = Env.get("OkloUIInstances")
    local menu = if type(instances) == "table" then instances[MENU_ID] else nil
    if type(menu) == "table" and type(menu.teardown) == "function" then
        pcall(menu.teardown, menu)
    end
    if type(previous) == "function" then
        pcall(previous)
    end
end

return function(OkloUI: any, reload: () -> (), Loader: any): Map?
    stopPrevious()
    Court.Closing = false
    local running = true
    local hookAt = os.clock() + HOOK_DELAY
    local ui: any

    local function raw(flag: string): any
        local value = ui:get(flag)
        if value == nil then
            return Config.DEFAULTS[flag]
        end
        return value
    end

    local function read(flag: string): any
        if not running or not ui then
            return false
        end
        local value = raw(flag)
        local parent = Config.PARENT[flag]
        if parent and value == true and raw(parent) ~= true then
            return false
        end
        return value
    end

    local function notify(text: string)
        if running and ui then
            pcall(ui.Window.announce, ui.Window, text)
        end
    end

    local function write(flag: string, value: any)
        if running and ui then
            pcall(ui.set, ui, flag, value)
        end
    end

    Env.set(READER, read)

    local autoGreen = AutoGreen.new(read, notify)
    local player = Player.new(read)
    local defense = Defense.new(read, player)
    local autoShoot = AutoShoot.new(read, autoGreen)
    local autoBlock = AutoBlock.new(read)
    local autoRebound = AutoRebound.new(read)
    local autoPass = AutoPass.new(read)
    local autoDribble = AutoDribble.new(read)
    local ballMagnet = BallMagnet.new(read)
    local combo = Combo.new(read, write)
    local glide = Glide.new(read, function(character: any, action: string): boolean
        return AutoGreen.liveShot(character, action, autoGreen.Meters)
    end)
    local esp = Esp.new(read)
    local rings = Rings.new(read)
    local contest = Contest.new(read, autoGreen)
    local moves = Moves.new(read)
    autoGreen.BlockDribble = function(args: any): boolean
        return moves:blocks(args)
    end
    local autoDunk = AutoDunk.new(read, autoGreen, player)
    autoShoot.AutoDunk = autoDunk
    autoShoot.Defense = defense
    autoShoot.Contest = contest
    autoDunk.Defense = defense
    local rimGuard = RimGuard.new(read, autoGreen)
    local connections: { any } = {}
    local parts: { any } = { autoGreen, defense, autoShoot, autoDunk, autoBlock, autoRebound, autoPass, autoDribble, combo, ballMagnet, player, contest }
    local partNames: { string } = { "autogreen", "defense", "autoshoot", "autodunk", "autoblock", "autorebound", "autopass", "autodribble", "combo", "ballmagnet", "player", "contest" }
    local closing: { any } = { defense, autoDunk, ballMagnet, player, contest, autoGreen }

    local function sweep()
        for _, part in closing do
            pcall(part.shutdown, part)
        end
        pcall(Drive.stop)
        pcall(Court.stop)
    end

    local function stop()
        if not running then
            return
        end
        running = false
        Court.Closing = true
        if Env.get(REGISTRY) ~= nil then
            Env.set(REGISTRY, nil)
        end
        for _, link in connections do
            pcall(link.Disconnect, link)
        end
        table.clear(connections)
        sweep()
        if Env.get(READER) == read then
            Env.set(READER, nil)
        end
        task.delay(0.6, sweep)
    end

    ui = OkloUI.new({
        Title = "oklo: PB",
        Subtitle = "basketball",
        Version = Changelog.VERSION,
        Changelog = Changelog,
        Id = MENU_ID,
        Folder = "oklo scripts/practicalbasketball",
        Logo = { Emblem = true },
        Footer = "oklo",
        Discord = "https://discord.gg/oklo",
        FirstRunInvite = true,
        Thanks = true,
        Width = 820,
        Height = 540,
        SidebarWidth = 200,
        BoldTitles = true,
        Theme = "Default",
        OnUnload = stop,
        OnReload = reload,
    })

    if type(Loader) == "table" and type(Loader.teleport) == "function" then
        local ok, queued = pcall(Loader.teleport, TELEPORT_URL, GAME_ID)
        if ok and queued then
            table.insert(connections, queued)
        end
    end

    local built, failure = pcall(Interface.build, ui, {
        resetCalibration = function()
            autoGreen:resetCalibration()
        end,
        playCombo = function()
            combo:playOnce()
        end,
        playMove = function(move: string)
            moves:play(move)
        end,
        status = function(): string
            if read("AutoGreen") ~= true then
                return "Auto Green is off"
            end
            return "Auto Green: on, hold E and it lets go on the green"
        end,
    })
    if not built then
        warn("[PB] menu build: " .. tostring(failure))
    end
    pcall(Court.start)
    pcall(autoGreen.bind, autoGreen)

    local walkLog: Map = { On = false, Start = 0, At = 0, From = nil :: Vector3?, Game = nil :: Vector3? }
    local function snapshot(mine: any): { [string]: any }
        local values: { [string]: any } = {}
        for _, name in WATCHED do
            values[name] = mine:GetAttribute(name)
        end
        return values
    end
    local function compare(mine: any, before: { [string]: any }, who: string)
        for _, name in WATCHED do
            if mine:GetAttribute(name) ~= before[name] then
                Court.touch(who .. " wrote " .. name)
            end
        end
    end
    local function walkLine(mine: any, now: number)
        local part = Court.proxy()
        local where: Vector3? = if part then part.Position else nil
        if Env.get("PBDebug") ~= true or not mine then
            walkLog.On = false
            return
        end
        if Court.HandsOff and not walkLog.On then
            walkLog.On, walkLog.Start, walkLog.At, walkLog.From = true, now, -math.huge, where
        elseif not Court.HandsOff then
            if walkLog.On then
                local moved = if where and walkLog.From then Court.flat(where - walkLog.From).Magnitude else 0
                print(string.format("[PB walk] over after %.1fs, the game moved you %.1f studs", now - walkLog.Start, moved))
            end
            walkLog.On = false
            return
        end
        if now - walkLog.At < 0.25 then
            return
        end
        walkLog.At = now
        local game0: Vector3? = walkLog.Game
        local speed = if game0 then Court.flat(game0).Magnitude else 0
        local yours = Court.userKeys()
        local touched = Court.Touched
        local line = string.format(
            "[PB walk] %.2fs Action=%s CanMove=%s Stunned=%s HoldingG=%s Sprinting=%s | game velocity %.1f | your keys %s, PB keys %s | PB: %s",
            now - walkLog.Start, tostring(mine:GetAttribute("Action")), tostring(mine:GetAttribute("CanMove")), tostring(mine:GetAttribute("Stunned")),
            tostring(mine:GetAttribute("HoldingG")), tostring(mine:GetAttribute("Sprinting")), speed, if yours then "down" else "up",
            if Court.Keys then "DOWN" else "up", if #touched > 0 then table.concat(touched, ", ") else "nothing"
        )
        table.clear(touched)
        print(line)
    end

    local runService: any = game:GetService("RunService")
    table.insert(connections, runService.Heartbeat:Connect(function(delta: any)
        if not running then
            return
        end
        local now = os.clock()
        local dt = if type(delta) == "number" then delta else 1 / 60
        pcall(Court.refresh, now)
        if not autoGreen.HookBound and not autoGreen.Binding and now >= hookAt then
            local wanted = false
            for _, flag in COPY_FLAGS do
                if read(flag) == true then
                    wanted = true
                    break
                end
            end
            local allowHook = false
            if wanted and (not autoGreen.Hooked or (allowHook and not autoGreen.TriedHook)) then
                task.spawn(autoGreen.hook, autoGreen, allowHook)
            end
        end
        local mine = Court.Mine
        local watch = mine ~= nil and Court.HandsOff and Env.get("PBDebug") == true
        for index, part in parts do
            local before = if watch then snapshot(mine) else nil
            pcall(part.step, part, now, dt)
            if before then
                compare(mine, before, partNames[index])
            end
        end
        if watch or walkLog.On then
            pcall(walkLine, mine, now)
        end
    end))
    local function beforePhysics(first: any, second: any)
        if not running then
            return
        end
        local dt = if type(second) == "number" then second elseif type(first) == "number" then first else 1 / 60
        local now = os.clock()
        local mine = Court.Mine
        local hands = mine ~= nil and Court.held(mine)
        local _, mover = Court.proxy()
        walkLog.Game = if mover then mover.Velocity else nil
        local function run(name: string, fn: any, ...: any)
            local before: Vector3? = if hands and mover then mover.Velocity else nil
            pcall(fn, ...)
            if before and mover.Velocity ~= before then
                Court.touch(name .. " wrote velocity")
            end
        end
        run("drive begin", Drive.begin, now)
        if not hands then
            run("glide", glide.physics, glide)
            run("player speed", player.physics, player)
        end
        run("drive", Drive.finish, now, dt)
        if not hands then
            run("rimguard", rimGuard.physics, rimGuard)
        end
    end
    local stepped, signal = pcall(function(): any
        return runService.PreSimulation
    end)
    pcall(function()
        table.insert(connections, (if stepped and signal then signal else runService.Stepped):Connect(beforePhysics))
    end)
    ui:onFrame(function(frame: Map)
        if not running then
            return
        end
        local canvas = frame.Canvas
        pcall(esp.draw, esp, canvas, frame.Chip)
        pcall(rings.draw, rings, canvas)
        pcall(contest.draw, contest, canvas, frame.Chip)
    end)
    ui:start()
    Env.set(REGISTRY, function()
        stop()
        pcall(ui.unload, ui)
    end)

    local api: Map = {}
    function api.Stop()
        stop()
        pcall(ui.unload, ui)
    end
    function api.PlayMove(move: string): boolean
        return moves:play(move)
    end
    function api.PlayCombo()
        combo:playOnce()
    end
    function api.Contest(): (number, number, boolean)
        return contest.Value, contest.Gap, contest.Open
    end
    function api.Glow(): number
        return contest.Glow
    end
    return api
end
end
modules["moves"] = function(...)

local import: (string) -> any = ...
local Config: typeof(require("./config")) = import("config")
local Court: typeof(require("./court")) = import("court")

local Moves = {}
Moves.__index = Moves

local GAP = 0.18

function Moves.new(read: (string) -> any): any
    return setmetatable({ Read = read, Last = -math.huge }, Moves)
end

function Moves.play(self: any, move: string): boolean
    if self.Read("MoveKeys") ~= true then
        return false
    end
    local mine = Court.Mine
    local keys = Config.MOVE_INPUTS[move]
    if not mine or not keys or not Court.HasBall then
        return false
    end
    local action = mine:GetAttribute("Action")
    if (action ~= "" and action ~= nil) or not Court.free(mine) or mine:GetAttribute("Debounce") == true or Court.HandsOff then
        return false
    end
    local now = os.clock()
    if now - self.Last < GAP then
        return false
    end
    local remote = Court.input("Dribble")
    if not remote then
        return false
    end
    self.Last = now
    local sprint = Court.sprintHeld() or mine:GetAttribute("Sprinting") == true
    return Court.send(remote, keys[if mine:GetAttribute("Hand") == "L" then "L" else "R"], sprint, Court.heading() or Vector3.zero)
end

function Moves.blocks(self: any, args: any): boolean
    if self.Read("BlockDribbleKeys") ~= true or type(args) ~= "table" then
        return false
    end
    local keys = args[1]
    return type(keys) == "string" and string.match(keys, "^[ZCXV]+$") ~= nil
end

return Moves
end
modules["player"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")
local Drive: typeof(require("./drive")) = import("drive")

local Player = {}
Player.__index = Player

local DEBOUNCES = { "Debounce", "DodgeDebounce", "BoxoutPushDebounce" }

local FORMS: { (any) -> ...any } = {
    function(_: any): ...any
        return true
    end,
    function(_: any): ...any
        return { Sprinting = true }
    end,
    function(_: any): ...any
        return { Sprint = true }
    end,
}
local RELEASES: { any } = { false, { Sprinting = false }, { Sprint = false } }

local GAME_CAP = 17
local LIMIT = 27
local MAX_STAMINA = 100
local FREED_TIME = 2
local STUN_WAIT = 0.4
local WALK_CLEAR = 1

local function sprinting(mine: any): boolean
    return mine.Parent ~= nil and mine:GetAttribute("Sprinting") == true
end

function Player.new(read: (string) -> any): any
    return setmetatable({
        Read = read,
        LastSprint = -math.huge,
        LastRelease = -math.huge,
        Releases = 0,
        Pressed = false,
        WantSprint = 0,
        Native = {} :: { [string]: number },
        Watched = nil :: any,
        Link = nil :: any,
        Real = nil :: number?,
        RealAt = 0,
        Sent = nil :: Vector3?,
    }, Player)
end

function Player.fill(self: any, mine: any)
    local value = mine:GetAttribute("Stamina")
    if type(value) ~= "number" or Court.HandsOff or Court.handsOff(mine) then
        return
    end
    local top = mine:GetAttribute("MaxStamina")
    local full = if type(top) == "number" and top > 0 then top else MAX_STAMINA
    if value < full - 0.01 then
        self.WroteAt = os.clock()
        self.Wrote = full
        mine:SetAttribute("Stamina", full)
    end
end

function Player.step(self: any, now: number)
    local mine = Court.Mine
    if not mine then
        return
    end
    local read = self.Read
    local infinite = read("InfStamina") == true
    if read("FullSpeed") == true or infinite then
        self:watch(mine)
    elseif self.Link then
        self:unwatch()
    end
    if infinite then
        self:fill(mine)
    end
    local action = mine:GetAttribute("Action")
    local walked = action == "Moving" or action == "Fouled" or action == "Inbounding"
    local freed = self.Freed
    if freed and (freed.Character ~= mine or now - freed.At > FREED_TIME) then
        freed = nil
        self.Freed = nil
    end
    local stunned = mine:GetAttribute("Stunned") == true
    if not stunned then
        self.StunAt = nil
    elseif not self.StunAt then
        self.StunAt = now
    end
    if walked or Court.Dead then
        if freed and walked then
            self.Freed = nil
            if mine:GetAttribute("Stunned") == false then
                mine:SetAttribute("Stunned", true)
            end
            if freed.CanMove and mine:GetAttribute("CanMove") == true then
                mine:SetAttribute("CanMove", false)
            end
        end
    elseif read("NoStun") == true and stunned and now - (self.StunAt or now) >= STUN_WAIT and not Court.Foul and now - Court.WalkAt >= WALK_CLEAR then
        mine:SetAttribute("Stunned", false)
        local gave = false
        if mine:GetAttribute("CanMove") == false and (action == "" or action == nil or action == "Stunned") then
            mine:SetAttribute("CanMove", true)
            gave = true
        end
        self.Freed = { Character = mine, At = now, CanMove = gave }
    end
    if Court.HandsOff or Court.handsOff(mine) then
        return
    end
    if read("NoDebounce") == true then
        for _, name in DEBOUNCES do
            if mine:GetAttribute(name) == true then
                mine:SetAttribute(name, false)
            end
        end
    end
    if read("NoCold") == true and mine:GetAttribute("Cold") == true then
        mine:SetAttribute("Cold", false)
    end
    if read("AlwaysSprint") == true or now < self.WantSprint then
        self:sprint(mine, now)
    elseif self.Pressed then
        self:release(mine, now)
    end
end

function Player.unwatch(self: any)
    local link = self.Link
    if link then
        self.Link = nil
        pcall(link.Disconnect, link)
    end
    self.Watched = nil
    self.Real = nil
end

function Player.watch(self: any, mine: any)
    if self.Watched == mine then
        return
    end
    self:unwatch()
    self.Watched = mine
    self.Link = mine:GetAttributeChangedSignal("Stamina"):Connect(function()
        local value = mine:GetAttribute("Stamina")
        if type(value) ~= "number" then
            return
        end
        local now = os.clock()
        if value == self.Wrote and now - (self.WroteAt or -math.huge) < 0.1 then
            return
        end
        self.Real = value
        self.RealAt = now
        if self.Read("InfStamina") == true then
            self:fill(mine)
        end
    end)
end

function Player.physics(self: any)
    local read = self.Read
    local custom = read("CustomSpeed") == true
    local infinite = read("InfStamina") == true
    local lock = read("FullSpeed") == true or infinite
    if not custom and not lock then
        return
    end
    local mine = Court.Mine
    if not mine or mine:GetAttribute("CanMove") ~= true or Court.handsOff(mine) then
        self.Boost = 0
        self.Ratio = 1
        self.PhysicsAt = nil
        return
    end
    local part, mover = Court.proxy()
    if not part or not mover then
        return
    end
    local velocity: Vector3 = mover.Velocity
    local speed = velocity.Magnitude
    if speed < 1 or Drive.active() or Drive.since(os.clock()) < 0.15 then
        self.Ratio = 1
        self.Boost = 0
        self.PhysicsAt = nil
        return
    end
    if velocity == self.Sent then
        return
    end
    local now = os.clock()
    local dt = math.clamp(now - (self.PhysicsAt or now), 0, 0.1)
    self.PhysicsAt = now
    local target = speed
    local real: number? = self.Real
    local boost = 0
    if lock and real and now - self.RealAt < 3 then
        local running = mine:GetAttribute("Sprinting") == true or (infinite and Court.sprintHeld())
        local key = if running then "Sprint" else "Walk"
        local native: { [string]: number } = self.Native
        local known = native[key]
        if real >= 85 then
            if speed >= 5 and speed <= 20 and mine:GetAttribute("HoldingG") ~= true then
                native[key] = if known then math.max(known * 0.999, speed) else speed
            end
        elseif known and mine:GetAttribute("HoldingG") ~= true and speed >= known * 0.55 then
            local share = if infinite then 0.99 else 0.95
            boost = math.clamp(known * share - speed, 0, if infinite then 6 else 3.5)
        end
    end
    local current: number = self.Boost or 0
    current += math.clamp(boost - current, -14 * dt, 7 * dt)
    self.Boost = current
    if current > 0.05 then
        target = speed + current
    end
    if custom then
        local base = mine:GetAttribute("WalkSpeed")
        if type(base) == "number" and base > 1 then
            local want = (read("WalkSpeed") or 16) / math.min(base, GAME_CAP)
            local ratio: number = self.Ratio or 1
            ratio += math.clamp(want - ratio, -3 * dt, 1.6 * dt)
            self.Ratio = ratio
            target *= ratio
        end
    end
    if math.abs(target - speed) < 0.05 then
        return
    end
    local scaled = velocity.Unit * math.min(target, LIMIT)
    mover.Velocity = scaled
    self.Sent = scaled
end

local function released(args: any): any
    local copy: any = table.clone(args)
    for index = 1, args.n or #args do
        local value = args[index]
        if type(value) == "boolean" then
            copy[index] = false
        elseif type(value) == "table" then
            local inner: any = table.clone(value)
            for key, item in inner do
                if type(item) == "boolean" then
                    inner[key] = false
                end
            end
            copy[index] = inner
        end
    end
    return copy
end

function Player.release(self: any, mine: any, now: number)
    if mine:GetAttribute("Sprinting") ~= true or self.Releases >= 4 then
        self.Pressed = false
        self.Releases = 0
        return
    end
    if now - self.LastRelease < 0.5 then
        return
    end
    if Court.sprintHeld() then
        self.Pressed = false
        self.Releases = 0
        return
    end
    self.LastRelease = now
    self.Releases += 1
    local remote = Court.input("Sprint")
    if not remote then
        return
    end
    local copied = Court.copied("Sprint")
    if type(copied) == "table" then
        local args = released(copied)
        Court.send(remote, table.unpack(args, 1, args.n or #args))
    else
        Court.send(remote, RELEASES[(self.Releases - 1) % #RELEASES + 1])
    end
end

function Player.sprint(self: any, mine: any, now: number)
    if mine:GetAttribute("Sprinting") == true then
        return
    end
    local action = Court.Action
    if (action ~= "" and action ~= "Dribbling" and action ~= nil) or mine:GetAttribute("CanMove") == false or now - self.LastSprint < 0.7 then
        return
    end
    local stamina = mine:GetAttribute("Stamina")
    if mine:GetAttribute("HoldingG") == true or (type(stamina) == "number" and stamina < 3) then
        return
    end
    local root = Court.Root
    local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
    if now >= self.WantSprint and not Court.steering(mine) and velocity.X * velocity.X + velocity.Z * velocity.Z <= 16 then
        return
    end
    self.LastSprint = now
    self.Pressed = true
    self.Releases = 0
    Court.fire("Sprint", FORMS, sprinting, nil, mine)
end

function Player.shutdown(self: any)
    self:unwatch()
    local mine = Court.mine()
    if mine and self.Pressed and not Court.sprintHeld() and mine:GetAttribute("Sprinting") == true then
        local remote = Court.input("Sprint")
        local copied = Court.copied("Sprint")
        if remote then
            if type(copied) == "table" then
                local args = released(copied)
                Court.send(remote, table.unpack(args, 1, args.n or #args))
            else
                Court.send(remote, false)
            end
        end
    end
    self.Pressed = false
end

return Player
end
modules["rimguard"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")

local RimGuard = {}
RimGuard.__index = RimGuard

local RANGE = 13
local FRONT_MIN = 2.6
local SLOPE = 0.4
local BUSY: { [string]: boolean } = { Shooting = true, Gathering = true, Dunking = true, ContactLayup = true, ClutchLayup = true, Layup = true, Dribbling = true }

function RimGuard.new(read: (string) -> any, autoGreen: any): any
    return setmetatable({ Read = read, AutoGreen = autoGreen }, RimGuard)
end

function RimGuard.physics(self: any)
    if self.Read("RimFront") ~= true then
        return
    end
    local mine = Court.Mine
    if not mine or not Court.HasBall then
        return
    end
    local green = self.AutoGreen
    if green.Press == nil or green.DunkPress == true or (green.Shot and green.Shot.Fired) then
        return
    end
    local action = mine:GetAttribute("Action")
    if (type(action) == "string" and BUSY[action]) or mine:GetAttribute("CanMove") ~= true or Court.handsOff(mine) then
        return
    end
    local part, mover = Court.proxy()
    if not part or not mover then
        return
    end
    local position: Vector3 = part.Position
    local distance, rim = Court.rimDistance(position)
    if not distance or not rim or distance > RANGE then
        return
    end
    local front = Court.front(rim)
    if not front then
        return
    end
    local offsetX, offsetZ = position.X - rim.Position.X, position.Z - rim.Position.Z
    local ahead = offsetX * front.X + offsetZ * front.Z
    if ahead <= 0 then
        return
    end
    local sideX, sideZ = offsetX - front.X * ahead, offsetZ - front.Z * ahead
    local need = math.max(FRONT_MIN, math.sqrt(sideX * sideX + sideZ * sideZ) * SLOPE)
    local velocity: Vector3 = mover.Velocity
    local closing = -(velocity.X * front.X + velocity.Z * front.Z)
    local limit = math.max((ahead - need) * 6, 0)
    if closing > limit then
        if green.Tracing then green:trace(string.format("  RIMGUARD slows the run, ahead=%.1f closing=%.1f limit=%.1f", ahead, closing, limit)) end
        mover.Velocity = velocity + front * (closing - limit)
    end
end

return RimGuard
end
modules["rings"] = function(...)

local import: (string) -> any = ...
local Court: typeof(require("./court")) = import("court")

local Rings = {}
Rings.__index = Rings

local SEGMENTS = 32
local ARC_PIECES = 16
local ARC_SEGMENTS = 96
local LINE_PIECE = 6
local LINE_TOLERANCE = 0.05
local DISC_ALPHA = 0.05
local RIM_ALPHA = 1 - (1 - DISC_ALPHA) * (1 - 0.09)
local FILL_Z = 1
local LEVEL_EVERY = 0.1
local HOOPS_EVERY = 0.5
local STEAL = Color3.fromRGB(255, 90, 90)
local GUARD = Color3.fromRGB(90, 160, 255)
local BLOCK = Color3.fromRGB(255, 200, 70)
local SHOT = Color3.fromRGB(110, 255, 140)
local LINE = Color3.fromRGB(255, 255, 255)
local DUNK_STAND = Color3.fromRGB(110, 255, 140)
local DUNK_DRIVE = Color3.fromRGB(90, 160, 255)
local STAND_IN, STAND_OUT = 4.6, 11
local DRIVE_IN, DRIVE_OUT = 6, 13
local NEAR = 60
local EASE = 12
local LIFT = 0.05
local SAME_HOOP = 6

local RAYS = 360
local REACH = 60
local SPAN = 6
local SNAP_TRACE = math.cos(math.rad(2))
local SNAP_COURT = math.cos(math.rad(10))
local SNAP_GUESS = math.cos(math.rad(45))

local circleX: { number } = table.create(SEGMENTS + 1)
local circleZ: { number } = table.create(SEGMENTS + 1)
for index = 0, SEGMENTS do
    local angle = index / SEGMENTS * math.pi * 2
    circleX[index + 1] = math.cos(angle)
    circleZ[index + 1] = math.sin(angle)
end

local distinct: { any } = {}

function Rings.new(read: (string) -> any): any
    return setmetatable({ Read = read, Radius = {} :: { [string]: number }, Last = os.clock() }, Rings)
end

local fast = false
local slowProject: any = nil
local camX, camY, camZ = 0, 0, 0
local m00, m01, m02, m10, m11, m12, m20, m21, m22 = 1, 0, 0, 0, 1, 0, 0, 0, 1
local focalX, focalY, middleX, middleY = 1, 1, 0, 0
local viewW, viewH = 1e5, 1e5

local function refPoint(lx: number, ly: number, lz: number): Vector3
    return Vector3.new(camX + m00 * lx + m01 * ly + m02 * lz, camY + m10 * lx + m11 * ly + m12 * lz, camZ + m20 * lx + m21 * ly + m22 * lz)
end

local function beginView(canvas: any): boolean
    fast = false
    slowProject = canvas.project
    if not slowProject then
        return false
    end
    viewW, viewH = 1e5, 1e5
    local camera = workspace.CurrentCamera
    if not camera then
        return true
    end
    local ok = pcall(function()
        local size = camera.ViewportSize
        viewW, viewH = size.X, size.Y
        camX, camY, camZ, m00, m01, m02, m10, m11, m12, m20, m21, m22 = camera.CFrame:GetComponents()
    end)
    if not ok then
        viewW, viewH = 1e5, 1e5
        return true
    end
    local a, depthA = slowProject(refPoint(-6, -4, -20))
    local b, depthB = slowProject(refPoint(6, 4, -20))
    local c, depthC = slowProject(refPoint(3, -5, -30))
    if not (a and b and c) or type(depthA) ~= "number" or type(depthC) ~= "number" then
        return true
    end
    focalX, middleX = (b.X - a.X) / 0.6, (a.X + b.X) / 2
    focalY, middleY = (a.Y - b.Y) / 0.4, (a.Y + b.Y) / 2
    local guessX, guessY = middleX + focalX * 0.1, middleY + focalY * (5 / 30)
    fast = focalX > 0 and focalY > 0 and math.abs(depthA - 20) < 0.05 and math.abs(depthC - 30) < 0.05 and math.abs(c.X - guessX) < 0.5 and math.abs(c.Y - guessY) < 0.5
    return true
end

local function screen(x: number, y: number, z: number): (number, number, boolean)
    if fast then
        local dx, dy, dz = x - camX, y - camY, z - camZ
        local depth = -(m02 * dx + m12 * dy + m22 * dz)
        if depth <= 0.01 then
            return 0, 0, false
        end
        return middleX + focalX * (m00 * dx + m10 * dy + m20 * dz) / depth, middleY - focalY * (m01 * dx + m11 * dy + m21 * dz) / depth, true
    end
    local point, depth = slowProject(Vector3.new(x, y, z))
    if point and type(depth) == "number" and depth > 0 then
        return point.X, point.Y, true
    end
    return 0, 0, false
end

type Buffer = { X: { number }, Y: { number }, Ok: { boolean }, Count: number }
local function buffer(): Buffer
    return { X = table.create(SEGMENTS + 1), Y = table.create(SEGMENTS + 1), Ok = table.create(SEGMENTS + 1), Count = 0 }
end
local nearBuf, farBuf = buffer(), buffer()
local corners: { any } = table.create(SEGMENTS)

local function projectPath(into: Buffer, path: { Vector3 })
    local xs, ys, oks = into.X, into.Y, into.Ok
    local count = #path
    for index = 1, count do
        local point = path[index]
        xs[index], ys[index], oks[index] = screen(point.X, point.Y, point.Z)
    end
    into.Count = count
end

local function projectCircle(into: Buffer, x: number, y: number, z: number, radius: number)
    local xs, ys, oks = into.X, into.Y, into.Ok
    for index = 1, SEGMENTS + 1 do
        xs[index], ys[index], oks[index] = screen(x + circleX[index] * radius, y, z + circleZ[index] * radius)
    end
    into.Count = SEGMENTS + 1
end

local names: { [string]: { [string]: string } } = {}
local function named(base: string, part: string): string
    local row = names[base]
    if not row then
        row = {}
        names[base] = row
    end
    local key = row[part]
    if not key then
        key = base .. ":" .. part
        row[part] = key
    end
    return key
end

local hoopTags: { string } = {}
local function hoopTag(index: number): string
    local tag = hoopTags[index]
    if not tag then
        tag = "pb:hoop" .. index
        hoopTags[index] = tag
    end
    return tag
end

local function enter(canvas: any, key: string?, z: number?)
    local scope, layer = canvas.scope, canvas.layer
    if scope then
        scope(key)
    end
    if layer then
        layer(z)
    end
end

local function beyond(ax: number, ay: number, bx: number, by: number, cx: number, cy: number, dx: number, dy: number): boolean
    return (ax < 0 and bx < 0 and cx < 0 and dx < 0)
        or (ay < 0 and by < 0 and cy < 0 and dy < 0)
        or (ax > viewW and bx > viewW and cx > viewW and dx > viewW)
        or (ay > viewH and by > viewH and cy > viewH and dy > viewH)
end

local function fillBand(canvas: any, near: Buffer, far: Buffer, key: string, color: Color3, alpha: number)
    local quad = canvas.filledQuad
    if not quad then
        return
    end
    enter(canvas, key, FILL_Z)
    local nx, ny, nok, fx, fy, fok = near.X, near.Y, near.Ok, far.X, far.Y, far.Ok
    local lastNear: Vector2? = nil
    local lastFar: Vector2? = nil
    local previous = 0
    for index = 1, math.min(near.Count, far.Count) do
        if not (nok[index] and fok[index]) then
            previous, lastNear, lastFar = 0, nil, nil
        else
            if previous ~= 0 then
                local p = previous
                if beyond(nx[p], ny[p], nx[index], ny[index], fx[index], fy[index], fx[p], fy[p]) then
                    lastNear, lastFar = nil, nil
                else
                    local a = lastNear or Vector2.new(nx[p], ny[p])
                    local d = lastFar or Vector2.new(fx[p], fy[p])
                    local b, c = Vector2.new(nx[index], ny[index]), Vector2.new(fx[index], fy[index])
                    quad(a, b, c, d, color, alpha, 0)
                    lastNear, lastFar = b, c
                end
            end
            previous = index
        end
    end
end

local function mirror(index: number): number
    return (SEGMENTS + 1 - index) % SEGMENTS + 1
end

local function fillSlices(canvas: any, edge: Buffer, key: string, color: Color3, alpha: number)
    local quad, triangle = canvas.filledQuad, canvas.filledTriangle
    if not quad then
        return
    end
    enter(canvas, key, FILL_Z)
    local xs, ys, oks = edge.X, edge.Y, edge.Ok
    for index = 1, SEGMENTS do
        corners[index] = if oks[index] then Vector2.new(xs[index], ys[index]) else false
    end
    for index = 1, SEGMENTS // 2 do
        local a, b, c, d = corners[index], corners[index + 1], corners[mirror(index + 1)], corners[mirror(index)]
        if a and b and c and d and not beyond(a.X, a.Y, b.X, b.Y, c.X, c.Y, d.X, d.Y) then
            if index == 1 then
                if triangle then
                    triangle(a, b, c, color, alpha, 0)
                else
                    quad(a, b, c, c, color, alpha, 0)
                end
            elseif index == SEGMENTS // 2 then
                if triangle then
                    triangle(a, b, d, color, alpha, 0)
                else
                    quad(a, b, d, d, color, alpha, 0)
                end
            else
                quad(a, b, c, d, color, alpha, 0)
            end
        end
    end
end

local function ring(canvas: any, key: string, x: number, y: number, z: number, radius: number, color: Color3)
    projectCircle(farBuf, x, y, z, radius)
    projectCircle(nearBuf, x, y, z, radius * 0.82)
    fillSlices(canvas, nearBuf, named(key, "disc"), color, DISC_ALPHA)
    fillBand(canvas, nearBuf, farBuf, named(key, "rim"), color, RIM_ALPHA)
end

local function arc(list: { Vector3 }, center: Vector3, front: Vector3, radius: number, y: number): { Vector3 }
    local fx, fz = front.X, front.Z
    for index = 0, ARC_PIECES do
        local angle = (index / ARC_PIECES - 0.5) * math.pi
        local cos, sin = math.cos(angle), math.sin(angle)
        local dx, dz = fx * cos - fz * sin, fz * cos + fx * sin
        list[index + 1] = Vector3.new(center.X + dx * radius, y, center.Z + dz * radius)
    end
    return list
end

local function band(canvas: any, key: string, near: { Vector3 }, far: { Vector3 }, color: Color3, alpha: number)
    projectPath(nearBuf, near)
    projectPath(farBuf, far)
    fillBand(canvas, nearBuf, farBuf, named(key, "fill"), color, alpha)
end

type Strip = { Near: { Vector3 }, Far: { Vector3 } }
local strips: { [any]: Strip } = setmetatable({}, { __mode = "k" }) :: any
local function stripOf(run: { Vector3 }, rimPos: Vector3): Strip
    local kept = strips[run]
    if kept then
        return kept
    end
    local count = #run
    local near: { Vector3 } = { run[1] }
    local from = 1
    while from < count do
        local reach = from + 1
        local a = run[from]
        for to = from + 2, count do
            local b = run[to]
            local dx, dz = b.X - a.X, b.Z - a.Z
            local length = math.sqrt(dx * dx + dz * dz)
            if length > LINE_PIECE then
                break
            end
            local fits = true
            if length > 0.001 then
                for middle = from + 1, to - 1 do
                    local point = run[middle]
                    if math.abs((point.X - a.X) * dz - (point.Z - a.Z) * dx) / length > LINE_TOLERANCE then
                        fits = false
                        break
                    end
                end
            end
            if not fits then
                break
            end
            reach = to
        end
        table.insert(near, run[reach])
        from = reach
    end
    local far: { Vector3 } = table.create(#near)
    for index, point in near do
        local ox, oz = point.X - rimPos.X, point.Z - rimPos.Z
        local length = math.max(math.sqrt(ox * ox + oz * oz), 0.001)
        far[index] = Vector3.new(point.X + ox / length * 0.6, point.Y, point.Z + oz / length * 0.6)
    end
    local made = { Near = near, Far = far }
    strips[run] = made
    return made
end

local floorParams = RaycastParams.new()
floorParams.RespectCanCollide = true
floorParams.FilterType = Enum.RaycastFilterType.Exclude
local nextIgnore = 0

local function floorBelow(x: number, top: number, z: number, depth: number): number?
    local now = os.clock()
    if now >= nextIgnore then
        nextIgnore = now + 1
        local ignore: { any } = {}
        for _, name in { "Characters", "Basketballs", "InvisCharacter" } do
            local folder = workspace:FindFirstChild(name)
            if folder then
                table.insert(ignore, folder)
            end
        end
        local root = Court.Root
        if root and root.Parent then
            table.insert(ignore, root.Parent)
        end
        floorParams.FilterDescendantsInstances = ignore
    end
    local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -depth, 0), floorParams)
    return if hit then hit.Position.Y else nil
end

local levelY: number? = nil
local nextLevel = 0

local function level(root: any): number
    local now = os.clock()
    if levelY and now < nextLevel then
        return levelY :: number
    end
    nextLevel = now + LEVEL_EVERY
    local position = root.Position
    local found = floorBelow(position.X, position.Y, position.Z, 16)
    if found and position.Y - found > 0.5 then
        levelY = found
    elseif not levelY then
        levelY = position.Y - 2.8
    end
    return levelY :: number
end

local function smoothWeight(x: number): number
    local t = math.clamp(x, 0, 1)
    return t * t * (3 - 2 * t)
end

local function axesOf(parts: { any }): { number }
    local list: { number } = {}
    for _, part in parts do
        local ok, frame = pcall(function(): any
            return part.CFrame
        end)
        if ok and frame then
            for _, vector in { frame.RightVector, frame.UpVector, frame.LookVector } do
                local flat = math.sqrt(vector.X * vector.X + vector.Z * vector.Z)
                if flat > 0.95 then
                    table.insert(list, vector.X / flat)
                    table.insert(list, vector.Z / flat)
                end
            end
        end
    end
    return list
end

local function snap(x: number, z: number, axes: { number }, limit: number): (number, number)
    local bestX, bestZ, best = x, z, limit
    for index = 1, #axes, 2 do
        local ax, az = axes[index], axes[index + 1]
        local dot = x * ax + z * az
        if dot > best then
            bestX, bestZ, best = ax, az, dot
        elseif -dot > best then
            bestX, bestZ, best = -ax, -az, -dot
        end
    end
    return bestX, bestZ
end

local function frontFrom(ox: { [number]: number }, oz: { [number]: number }, axes: { number }): (number?, number?)
    local sx, sz = 0, 0
    for index = 1, RAYS do
        local x = ox[index]
        if x then
            sx += x
            sz += oz[index]
        end
    end
    local length = math.sqrt(sx * sx + sz * sz)
    if length < 1 then
        return nil, nil
    end
    return snap(sx / length, sz / length, axes, SNAP_TRACE)
end

local function median(list: { number }): number?
    local count = #list
    if count == 0 then
        return nil
    end
    table.sort(list)
    if count % 2 == 1 then
        return list[(count + 1) // 2]
    end
    return (list[count // 2] + list[count // 2 + 1]) / 2
end

local function fitLine(ox: { [number]: number }, oz: { [number]: number }, depth: { [number]: number }, fx: number, fz: number): ({ number }?, { number }?)
    local sx, sz = -fz, fx
    local ahead: { [number]: number } = {}
    local across: { [number]: number } = {}
    local total = 0
    for index = 1, RAYS do
        local x = ox[index]
        if x then
            local z = oz[index]
            ahead[index] = x * fx + z * fz
            across[index] = x * sx + z * sz
            total += 1
        end
    end
    if total < 40 then
        return nil, nil
    end
    local function angleOf(a: number, b: number): number
        return math.deg(math.atan2(math.abs(b), a))
    end
    local function corners(ca: number, cb: number): (number?, { number })
        local left: { number } = {}
        local right: { number } = {}
        local thick: { number } = {}
        for index = 1, RAYS do
            local a = ahead[index]
            if a then
                local b = across[index] - cb
                local angle = angleOf(a - ca, b)
                if angle >= 80 and angle <= 100 then
                    table.insert(if b < 0 then left else right, math.abs(b))
                    if depth[index] then
                        table.insert(thick, depth[index])
                    end
                end
            end
        end
        local function straight(list: { number }): number?
            local middle = median(list)
            if not middle then
                return nil
            end
            local close = 0
            for _, value in list do
                if math.abs(value - middle) <= 0.25 then
                    close += 1
                end
            end
            return if close >= #list * 0.6 then middle else nil
        end
        local l, r = straight(left), straight(right)
        local c = if l and r then (l + r) / 2 else l or r
        return c, thick
    end
    local corner = corners(0, 0)
    local round: { [number]: number } = {}
    for index = 1, RAYS do
        local a = ahead[index]
        if a then
            local b = across[index]
            if a > 0.5 and angleOf(a, b) <= 90 and (not corner or math.abs(b) < corner - 0.75) then
                round[index] = math.sqrt(a * a + b * b)
            end
        end
    end
    local tips: { number } = {}
    for index = 1, RAYS do
        local away = round[index]
        if away then
            local top = true
            for step = -2, 2 do
                local other = round[(index + step - 1) % RAYS + 1]
                if step ~= 0 and (not other or other > away + 1e-4) then
                    top = false
                    break
                end
            end
            if top then
                table.insert(tips, index)
            end
        end
    end
    local ca, cb, radius = 0, 0, 0
    local fitted = false
    if #tips >= 5 then
        local sxx, sxy, syy, sx1, sy1, n, rx, ry, r1 = 0, 0, 0, 0, 0, 0, 0, 0, 0
        for _, index in tips do
            local x, y = ahead[index], across[index]
            local w = x * x + y * y
            sxx += x * x
            sxy += x * y
            syy += y * y
            sx1 += x
            sy1 += y
            n += 1
            rx -= x * w
            ry -= y * w
            r1 -= w
        end
        local det = sxx * (syy * n - sy1 * sy1) - sxy * (sxy * n - sy1 * sx1) + sx1 * (sxy * sy1 - syy * sx1)
        if math.abs(det) > 1e-6 then
            local d = (rx * (syy * n - sy1 * sy1) - sxy * (ry * n - sy1 * r1) + sx1 * (ry * sy1 - syy * r1)) / det
            local e = (sxx * (ry * n - sy1 * r1) - rx * (sxy * n - sy1 * sx1) + sx1 * (sxy * r1 - ry * sx1)) / det
            local f = (sxx * (syy * r1 - ry * sy1) - sxy * (sxy * r1 - ry * sx1) + rx * (sxy * sy1 - syy * sx1)) / det
            local midA, midB = -d / 2, -e / 2
            local square = midA * midA + midB * midB - f
            if square > 16 and midA * midA + midB * midB < 9 then
                local r = math.sqrt(square)
                local spread = 0
                for _, index in tips do
                    local a, b = ahead[index] - midA, across[index] - midB
                    spread += (math.sqrt(a * a + b * b) - r) ^ 2
                end
                if math.sqrt(spread / #tips) < 0.5 then
                    ca, cb, radius, fitted = midA, midB, r, true
                end
            end
        end
    end
    if not fitted then
        for _, away in round do
            radius = math.max(radius, away)
        end
    end
    if radius < 4 then
        return nil, nil
    end
    local roundThick: { number } = {}
    for _, index in tips do
        if depth[index] then
            table.insert(roundThick, depth[index])
        end
    end
    local side, sideThick = corners(ca, cb)
    local roundHalf = math.min(median(roundThick) or 0, 3) / 2
    local sideHalf = math.min(median(sideThick) or 0, 3) / 2
    local widest = 0
    local ends: { number } = {}
    local endAngle = 0
    for _, sign in { -1, 1 } do
        local first, second = math.huge, math.huge
        for index = 1, RAYS do
            local a0 = ahead[index]
            if a0 then
                local a, b = a0 - ca, (across[index] - cb) * sign
                local angle = angleOf(a, b)
                widest = math.max(widest, angle)
                if side and b > 0 and angle >= 60 and b >= side - 0.75 then
                    endAngle = math.max(endAngle, angle)
                    if a < first then
                        first, second = a, first
                    elseif a < second then
                        second = a
                    end
                end
            end
        end
        if first < math.huge then
            table.insert(ends, if second < math.huge then first - math.min(second - first, 1) / 2 else first)
        end
    end
    local baseline: number? = nil
    if #ends > 0 then
        baseline = (ends[1] + (ends[2] or ends[1])) / 2
    end
    local good, counted = 0, 0
    for index = 1, RAYS do
        local a0 = ahead[index]
        if a0 then
            local a, b = a0 - ca, math.abs(across[index] - cb)
            if a >= (baseline or 0) - 0.5 and (not baseline or angleOf(a, b) <= endAngle + 0.5) then
                counted += 1
                local miss = math.abs(math.sqrt(a * a + b * b) - radius)
                if side then
                    miss = math.min(miss, math.abs(b - side))
                end
                if miss <= 2.5 then
                    good += 1
                end
            end
        end
    end
    if counted < 40 or good < counted * 0.85 then
        return nil, nil
    end
    local r = radius + roundHalf
    local listA: { number } = {}
    local listB: { number } = {}
    local function put(a: number, b: number)
        table.insert(listA, ca + a)
        table.insert(listB, cb + b)
    end
    local reach = math.rad(math.min(widest, 90))
    local c: number? = nil
    if side and baseline then
        c = side + sideHalf
        if side >= radius - 0.3 then
            c = r
        end
    end
    local turn, joint = reach, 0
    if c then
        turn = if c < r then math.asin(c / r) else math.pi / 2
        joint = if c < r then math.sqrt(r * r - c * c) else 0
    end
    local straight = c ~= nil and (baseline :: number) < joint - 0.25
    if straight then
        for step = 0, 7 do
            put(baseline :: number + (joint - (baseline :: number)) * step / 8, -(c :: number))
        end
    end
    local count = math.max(16, math.floor(ARC_SEGMENTS * turn / (math.pi / 2) + 0.5))
    for step = 0, count do
        local angle = -turn + 2 * turn * step / count
        put(r * math.cos(angle), r * math.sin(angle))
    end
    if straight then
        for step = 1, 8 do
            put(joint + ((baseline :: number) - joint) * step / 8, c :: number)
        end
    end
    return listA, listB
end

local function rawLine(ox: { [number]: number }, oz: { [number]: number }, origin: Vector3, y: number): { { Vector3 } }
    local radius = 0
    for index = 1, RAYS do
        local x = ox[index]
        if x then
            radius = math.max(radius, math.sqrt(x * x + oz[index] ^ 2))
        end
    end
    local runs: { { Vector3 } } = {}
    local run: { Vector3 }? = nil
    local first: Vector3? = nil
    local last: Vector3? = nil
    for index = 1, RAYS do
        local x = ox[index]
        if x then
            local z = oz[index]
            local away = math.sqrt(x * x + z * z)
            if away > 0.01 then
                local goal = away + (radius - away) * smoothWeight((away - (radius - 2)) / 1.5)
                x, z = x / away * goal, z / away * goal
            end
            local point = Vector3.new(origin.X + x, y, origin.Z + z)
            if run and last and (point - last).Magnitude > 12 then
                run = nil
            end
            local open: { Vector3 } = run or {}
            if not run then
                run = open
                table.insert(runs, open)
            end
            table.insert(open, point)
            if index == 1 then
                first = point
            end
            last = point
        else
            run = nil
            last = nil
        end
    end
    if run and first and last and (first - last).Magnitude <= 12 then
        table.insert(run :: { Vector3 }, first)
    end
    return runs
end

type Survey = { Runs: { { Vector3 } }, Front: Vector3?, Fitted: boolean, Floor: number? }

local function survey(rim: any, folder: any, fallbackY: number): Survey?
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { folder }
    local origin = rim.Position
    local hits: { [number]: any } = {}
    local counts: { [any]: number } = {}
    for index = 1, RAYS do
        local angle = (index - 1) / RAYS * math.pi * 2
        local hit = workspace:Raycast(origin, Vector3.new(math.cos(angle), 0, math.sin(angle)) * REACH, params)
        if hit then
            hits[index] = hit
            counts[hit.Instance] = (counts[hit.Instance] or 0) + 1
        end
    end
    local wall: any = nil
    local most = 0
    for part, count in counts do
        if count > most then
            wall, most = part, count
        end
    end
    if not wall then
        return nil
    end
    local furthest = 0
    for _, hit in hits do
        if hit.Instance == wall then
            furthest = math.max(furthest, hit.Distance)
        end
    end
    local ox: { [number]: number } = {}
    local oz: { [number]: number } = {}
    local depth: { [number]: number } = {}
    for index = 1, RAYS do
        local hit = hits[index]
        if hit and hit.Distance <= furthest + 2 then
            local position = hit.Position
            ox[index] = position.X - origin.X
            oz[index] = position.Z - origin.Z
            local angle = (index - 1) / RAYS * math.pi * 2
            local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
            local back = workspace:Raycast(position + direction * SPAN, direction * -SPAN, params)
            if back and back.Instance == hit.Instance then
                local thick = SPAN - back.Distance
                if thick > 0.02 and thick < SPAN - 0.1 then
                    depth[index] = thick
                end
            end
        end
    end
    local fx, fz = frontFrom(ox, oz, axesOf({ wall, rim }))
    local front = if fx and fz then Vector3.new(fx, 0, fz) else nil
    local floor: number? = nil
    if front then
        local spot = origin + front * 6
        local found = floorBelow(spot.X, origin.Y, spot.Z, 30)
        if found and origin.Y - found > 3 then
            floor = found
        end
    end
    local y = (floor or fallbackY) + LIFT
    local listA, listB = nil, nil
    if fx and fz then
        listA, listB = fitLine(ox, oz, depth, fx, fz)
    end
    if listA and listB and front then
        local side = Vector3.new(-front.Z, 0, front.X)
        local path: { Vector3 } = table.create(#listA)
        for index, a in listA do
            local offset = front * a + side * listB[index]
            path[index] = Vector3.new(origin.X + offset.X, y, origin.Z + offset.Z)
        end
        return { Runs = { path }, Front = front, Fitted = true, Floor = floor }
    end
    return { Runs = rawLine(ox, oz, origin, y), Front = front, Fitted = false, Floor = floor }
end

local surveys: { [any]: Survey } = setmetatable({}, { __mode = "k" }) :: any
local nextSurvey: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any

local zoneFolder: any = nil
local nextZoneScan = 0
local nextDeepScan = 0

local function zones(): any?
    if zoneFolder and zoneFolder:IsDescendantOf(workspace) then
        return zoneFolder
    end
    zoneFolder = nil
    if os.clock() < nextZoneScan then
        return nil
    end
    nextZoneScan = os.clock() + 1
    local assets = workspace:FindFirstChild("Assets")
    local functionals = if assets then assets:FindFirstChild("Functionals") else nil
    local area = if functionals then functionals:FindFirstChild("Zones") else nil
    zoneFolder = if area then area:FindFirstChild("ThreePoint") else nil
    if not zoneFolder and os.clock() >= nextDeepScan then
        nextDeepScan = os.clock() + 5
        zoneFolder = workspace:FindFirstChild("ThreePoint", true)
    end
    return zoneFolder
end

local function surveyOf(rim: any, fallbackY: number): Survey?
    local known = surveys[rim]
    if known then
        return known
    end
    local now = os.clock()
    if now < (nextSurvey[rim] or 0) then
        return nil
    end
    nextSurvey[rim] = now + 1
    local folder = zones()
    if not folder then
        return nil
    end
    local ok, result = pcall(survey, rim, folder, fallbackY)
    if ok and result and #result.Runs > 0 then
        surveys[rim] = result
        return result
    end
    return nil
end

local nextHoops = 0
local function hoops(): { any }
    local now = os.clock()
    if now < nextHoops then
        return distinct
    end
    nextHoops = now + HOOPS_EVERY
    table.clear(distinct)
    for _, rim in Court.rims() do
        if rim.Parent then
            local position = rim.Position
            local copy = false
            for _, kept in distinct do
                local other = kept.Position
                local dx, dz = position.X - other.X, position.Z - other.Z
                if dx * dx + dz * dz < SAME_HOOP * SAME_HOOP then
                    copy = true
                    break
                end
            end
            if not copy then
                table.insert(distinct, rim)
            end
        end
    end
    return distinct
end

local chosen: { [any]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
local chosenBy: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local function frontOf(rim: any, root: any, surveyed: Survey?): Vector3?
    local source: any = surveyed or false
    local kept = chosen[rim]
    if kept and chosenBy[rim] == source then
        return kept
    end
    local found: Vector3? = nil
    if surveyed and surveyed.Fitted then
        found = surveyed.Front
    end
    if not found then
        local known = Court.front(rim)
        if known then
            local x, z = snap(known.X, known.Z, axesOf({ rim }), SNAP_COURT)
            found = Vector3.new(x, 0, z)
        end
    end
    if not found and surveyed then
        found = surveyed.Front
    end
    if not found and kept then
        found = kept
    elseif not found then
        local toward = Vector3.new(root.Position.X - rim.Position.X, 0, root.Position.Z - rim.Position.Z)
        if toward.Magnitude < 1 then
            return nil
        end
        local unit = toward.Unit
        local x, z = snap(unit.X, unit.Z, axesOf({ rim }), SNAP_GUESS)
        found = Vector3.new(x, 0, z)
    end
    chosen[rim] = found :: Vector3
    chosenBy[rim] = source
    return found
end

local rimFloor: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any
local nextRimFloor: { [any]: number } = setmetatable({}, { __mode = "k" }) :: any
local function floorAt(rim: any, front: Vector3, surveyed: Survey?, fallback: number): number
    if surveyed and surveyed.Floor then
        return surveyed.Floor
    end
    local known = rimFloor[rim]
    if known then
        return known
    end
    local now = os.clock()
    if now >= (nextRimFloor[rim] or 0) then
        nextRimFloor[rim] = now + 1
        local origin = rim.Position
        local spot = origin + front * 6
        local found = floorBelow(spot.X, origin.Y, spot.Z, 30)
        if found and origin.Y - found > 3 then
            rimFloor[rim] = found
            return found
        end
    end
    return fallback
end

type Shapes = { Front: Vector3, Y: number, StandIn: { Vector3 }, StandOut: { Vector3 }, DriveIn: { Vector3 }, DriveOut: { Vector3 }, Shot: { Vector3 }, ShotIn: { Vector3 }, ShotRadius: number }
local shapes: { [any]: Shapes } = setmetatable({}, { __mode = "k" }) :: any
local function shapesOf(rim: any, front: Vector3, y: number): Shapes
    local kept = shapes[rim]
    if kept and kept.Front == front and math.abs(kept.Y - y) < 0.01 then
        return kept
    end
    local made: Shapes = kept or {
        Front = front,
        Y = y,
        StandIn = table.create(ARC_PIECES + 1),
        StandOut = table.create(ARC_PIECES + 1),
        DriveIn = table.create(ARC_PIECES + 1),
        DriveOut = table.create(ARC_PIECES + 1),
        Shot = table.create(ARC_PIECES + 1),
        ShotIn = table.create(ARC_PIECES + 1),
        ShotRadius = -1,
    }
    local center = rim.Position
    made.Front, made.Y, made.ShotRadius = front, y, -1
    arc(made.StandIn, center, front, STAND_IN, y)
    arc(made.StandOut, center, front, STAND_OUT, y)
    arc(made.DriveIn, center, front, DRIVE_IN, y)
    arc(made.DriveOut, center, front, DRIVE_OUT, y)
    shapes[rim] = made
    return made
end

function Rings.tint(self: any, flag: string, fallback: Color3): Color3
    local color: any = self.Read(flag)
    local kind = typeof(color)
    return if kind == "Color3" then color else fallback
end

function Rings.radius(self: any, key: string, goal: number, dt: number): number
    local current = self.Radius[key]
    if not current then
        current = goal
    else
        current += (goal - current) * (1 - math.exp(-EASE * dt))
        if math.abs(goal - current) < 0.001 then
            current = goal
        end
    end
    self.Radius[key] = current
    return current
end

function Rings.draw(self: any, canvas: any)
    if not canvas then
        return
    end
    local now = os.clock()
    local dt = math.clamp(now - self.Last, 0, 0.1)
    self.Last = now
    local read = self.Read
    local viz = read("RangeViz") == true
    local shot = read("ShotRangeViz") == true
    local line = read("ThreePointLine") == true
    local dunk = read("DunkZones") == true
    if not viz and not shot and not line and not dunk then
        return
    end
    local root = Court.Root
    if not root or root.Parent == nil then
        return
    end
    if not beginView(canvas) then
        return
    end
    local ok, problem = pcall(self.paint, self, canvas, root, read, dt, viz, shot, line, dunk)
    enter(canvas, nil, nil)
    if not ok then
        error(problem, 0)
    end
end

function Rings.paint(self: any, canvas: any, root: any, read: (string) -> any, dt: number, viz: boolean, shot: boolean, line: boolean, dunk: boolean)
    local position = root.Position
    local floor = level(root)
    if line or dunk or shot then
        local lineColor = self:tint("ShotColor", LINE)
        local shotColor = self:tint("ShotColor", SHOT)
        local shotRadius = if shot then self:radius("Shoot", read("ShootRange") or 24, dt) else 0
        for index, rim in hoops() do
            local tag = hoopTag(index)
            local surveyed = surveyOf(rim, floor)
            if line and surveyed then
                local key = named(tag, "line")
                local rimPos = rim.Position
                for number, run in surveyed.Runs do
                    local strip = stripOf(run, rimPos)
                    projectPath(nearBuf, strip.Near)
                    projectPath(farBuf, strip.Far)
                    fillBand(canvas, nearBuf, farBuf, named(key, "strip" .. number), lineColor, 0.4)
                end
            end
            if dunk or shot then
                local center = rim.Position
                local dx, dz = center.X - position.X, center.Z - position.Z
                local front = if dx * dx + dz * dz < NEAR * NEAR then frontOf(rim, root, surveyed) else nil
                if front then
                    local made = shapesOf(rim, front, floorAt(rim, front, surveyed, floor) + LIFT)
                    if dunk then
                        band(canvas, named(tag, "drive"), made.DriveIn, made.DriveOut, DUNK_DRIVE, 0.07)
                        band(canvas, named(tag, "stand"), made.StandIn, made.StandOut, DUNK_STAND, 0.12)
                    end
                    if shot then
                        if math.abs(made.ShotRadius - shotRadius) > 0.001 then
                            made.ShotRadius = shotRadius
                            arc(made.Shot, center, front, shotRadius, made.Y)
                            arc(made.ShotIn, center, front, math.max(shotRadius - 3, 0), made.Y)
                        end
                        band(canvas, named(tag, "shot"), made.ShotIn, made.Shot, shotColor, 0.09)
                    end
                end
            end
        end
    end
    if viz then
        local x, y, z = position.X, floor + LIFT, position.Z
        if read("AutoSteal") == true then
            ring(canvas, "pb:steal", x, y, z, self:radius("Steal", read("StealRange") or 8, dt), self:tint("StealColor", STEAL))
        end
        if read("AutoGuard") == true then
            ring(canvas, "pb:guard", x, y, z, self:radius("Guard", read("GuardRange") or 16, dt), self:tint("GuardColor", GUARD))
        end
        if read("AutoBlock") == true then
            ring(canvas, "pb:block", x, y, z, self:radius("Block", read("BlockRange") or 10, dt), self:tint("BlockColor", BLOCK))
        end
    end
end

return Rings
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

