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
modules["core/color"] = function(...)

local Color = {}

local WHITE = Color3.new(1, 1, 1)

function Color.lerp(from: Color3?, to: Color3?, alpha: number): Color3
    if not from or not to then
        return WHITE
    end
    return Color3.new(
        from.R + (to.R - from.R) * alpha,
        from.G + (to.G - from.G) * alpha,
        from.B + (to.B - from.B) * alpha
    )
end

function Color.lighten(color: Color3, amount: number): Color3
    return Color3.new(
        math.clamp(color.R + (1 - color.R) * amount, 0, 1),
        math.clamp(color.G + (1 - color.G) * amount, 0, 1),
        math.clamp(color.B + (1 - color.B) * amount, 0, 1)
    )
end

function Color.fromHSV(hue: number?, saturation: number?, value: number?): Color3
    local h = ((hue or 0) % 1) * 6
    local s = math.clamp(saturation or 0, 0, 1)
    local v = math.clamp(value or 0, 0, 1)

    local sector = math.floor(h)
    local fraction = h - sector
    local p = v * (1 - s)
    local q = v * (1 - s * fraction)
    local t = v * (1 - s * (1 - fraction))

    if sector == 0 then
        return Color3.new(v, t, p)
    elseif sector == 1 then
        return Color3.new(q, v, p)
    elseif sector == 2 then
        return Color3.new(p, v, t)
    elseif sector == 3 then
        return Color3.new(p, q, v)
    elseif sector == 4 then
        return Color3.new(t, p, v)
    end
    return Color3.new(v, p, q)
end

function Color.channel(value: number): number
    return math.clamp(math.floor(value * 255 + 0.5), 0, 255)
end

function Color.toHex(color: Color3): string
    local r = math.clamp(math.floor(color.R * 255), 0, 255)
    local g = math.clamp(math.floor(color.G * 255), 0, 255)
    local b = math.clamp(math.floor(color.B * 255), 0, 255)
    return string.format("#%02X%02X%02X", r, g, b)
end

function Color.fromHex(text: any): Color3?
    if type(text) ~= "string" then
        return nil
    end
    local digits = string.gsub(text, "#", "")
    if #digits ~= 6 then
        return nil
    end
    local r = tonumber(string.sub(digits, 1, 2), 16)
    local g = tonumber(string.sub(digits, 3, 4), 16)
    local b = tonumber(string.sub(digits, 5, 6), 16)
    if r and g and b then
        return Color3.fromRGB(r, g, b)
    end
    return nil
end

return Color
end
modules["core/storage"] = function(...)

local Storage = {}

function Storage.encode(value: any): string
    local ok, text = pcall(function()
        return game:GetService("HttpService"):JSONEncode(value)
    end)
    if ok and type(text) == "string" then
        return text
    end
    return ""
end

function Storage.decode(text: string): any
    local ok, value = pcall(function()
        return game:GetService("HttpService"):JSONDecode(text)
    end)
    if ok then
        return value
    end
    return nil
end

function Storage.isFile(path: string): boolean
    local ok, result = pcall(isfile, path)
    return ok and result == true
end

function Storage.isFolder(path: string): boolean
    local ok, result = pcall(isfolder, path)
    return ok and result == true
end

function Storage.ensureFolder(path: string): boolean
    local built = ""
    for part in string.gmatch(path, "[^/\\]+") do
        built = if built == "" then part else built .. "/" .. part
        if not Storage.isFolder(built) then
            pcall(makefolder, built)
        end
    end
    return Storage.isFolder(path)
end

function Storage.read(path: string): string?
    if not Storage.isFile(path) then
        return nil
    end
    local ok, content = pcall(readfile, path)
    if ok and type(content) == "string" then
        return content
    end
    return nil
end

function Storage.write(path: string, content: string): boolean
    return (pcall(writefile, path, content))
end

function Storage.delete(path: string)
    if Storage.isFile(path) then
        pcall(delfile, path)
    end
end

function Storage.readJson(path: string): any
    local content = Storage.read(path)
    if content == nil then
        return nil
    end
    return Storage.decode(content)
end

function Storage.writeJson(path: string, value: any): boolean
    local text = Storage.encode(value)
    if text == "" then
        return false
    end
    return Storage.write(path, text)
end

function Storage.list(folder: string): { string }
    local ok, files = pcall(listfiles, folder)
    if ok and type(files) == "table" then
        return files
    end
    return {}
end

return Storage
end
modules["core/theme"] = function(...)

local Theme = {
    BgBase = Color3.fromRGB(29, 32, 33),
    PanelBg = Color3.fromRGB(50, 48, 47),
    Accent = Color3.fromRGB(215, 153, 33),
    AccentBright = Color3.fromRGB(250, 189, 47),
    AccentOff = Color3.fromRGB(80, 73, 69),
    TextMain = Color3.fromRGB(235, 219, 178),
    TextSub = Color3.fromRGB(168, 153, 132),
    Disabled = Color3.fromRGB(102, 92, 84),
}

export type Preset = {
    Name: string,
    Disabled: Color3?,
    Sky: Color3?,
    Cycle: { Color3 }?,
    Glass: number?,
    Buttons: number?,
    Motion: { [string]: any }?,
    Rim: { Color3 }?,
    Fx: string?,
    Grad: string?,
    Light: { [string]: Color3 }?,
    Main: Color3,
    Panel: Color3,
    Off: Color3,
    Text: Color3,
    Sub: Color3,
    Accent: Color3,
}

local function rgb(r: number, g: number, b: number): Color3
    return Color3.fromRGB(r, g, b)
end

Theme.Presets = {} :: { [string]: Preset }



local function mix(a: Color3, b: Color3, amount: number): Color3
    return Color3.new(a.R + (b.R - a.R) * amount, a.G + (b.G - a.G) * amount, a.B + (b.B - a.B) * amount)
end

local MOTIONS: { [string]: { [string]: any } } = {
    Drift = { Rate = 0.012, Swing = 0.06, SwingSpeed = 0.05, Bend = 0.045, BendSpeed = 0.16, Freq = 0.8, Glow = 0.05, Scale = 0.6 },
    Tide = { Rate = -0.011, Swing = 0.07, SwingSpeed = 0.042, Bend = 0.055, BendSpeed = 0.13, Freq = 0.6, Glow = 0.04, Scale = 0.65 },
    Aurora = { Rate = 0.01, Swing = 0.09, SwingSpeed = 0.06, Bend = 0.06, BendSpeed = 0.2, Freq = 0.9, Glow = 0.06, Scale = 0.55 },
    Ember = { Rate = 0.014, Swing = 0.05, SwingSpeed = 0.07, Bend = 0.04, BendSpeed = 0.24, Freq = 1.0, Glow = 0.06, Scale = 0.5, Beat = 0.025, BeatSpeed = 0.9 },
    Pulse = { Rate = 0.01, Swing = 0.05, SwingSpeed = 0.05, Bend = 0.035, BendSpeed = 0.14, Freq = 0.6, Glow = 0.05, Scale = 0.6, Beat = 0.045, BeatSpeed = 0.55 },
    Slow = { Rate = 0.011, Swing = 0.06, SwingSpeed = 0.04, Bend = 0.045, BendSpeed = 0.12, Freq = 0.5, Glow = 0.04, Scale = 0.7 },
    Neon = { Rate = 0.016, Swing = 0.05, SwingSpeed = 0.07, Bend = 0.035, BendSpeed = 0.22, Freq = 1.1, Glow = 0.05, Scale = 0.55 },
    Swell = { Rate = -0.01, Swing = 0.09, SwingSpeed = 0.045, Bend = 0.04, BendSpeed = 0.15, Freq = 0.7, Glow = 0.05, Scale = 0.65 },
    Storm = { Rate = 0.009, Swing = 0.08, SwingSpeed = 0.05, Bend = 0.06, BendSpeed = 0.17, Freq = 0.7, Glow = 0.03, Scale = 0.7 },
    Breathe = { Rate = 0.008, Swing = 0.05, SwingSpeed = 0.04, Bend = 0.03, BendSpeed = 0.1, Freq = 0.6, Glow = 0.04, Scale = 0.6, Beat = 0.06, BeatSpeed = 0.42 },
    Breeze = { Rate = 0.005, Swing = 0.17, SwingSpeed = 0.085, Bend = 0.05, BendSpeed = 0.18, Freq = 0.7, Glow = 0.04, Scale = 0.6 },
    Haze = { Rate = -0.009, Swing = 0.08, SwingSpeed = 0.035, Bend = 0.07, BendSpeed = 0.1, Freq = 0.45, Glow = 0.05, Scale = 0.75 },
    Spectrum = { Rate = 0.017, Swing = 0.02, SwingSpeed = 0.05, Bend = 0.025, BendSpeed = 0.12, Freq = 0.5, Glow = 0.03, Scale = 0.5 },
    Orbit = { Rate = 0.009, Swing = 0.06, SwingSpeed = 0.05, Bend = 0.04, BendSpeed = 0.15, Freq = 0.8, Glow = 0.05, Scale = 0.5 },
    Ripple = { Rate = -0.012, Swing = 0.05, SwingSpeed = 0.06, Bend = 0.045, BendSpeed = 0.3, Freq = 1.3, Glow = 0.04, Scale = 0.55 },
    Steam = { Rate = -0.013, Swing = 0.05, SwingSpeed = 0.05, Bend = 0.05, BendSpeed = 0.2, Freq = 0.9, Glow = 0.05, Scale = 0.6 },
}

local ORDER_ANIMATED: { string } = {}

local function sky(spec: { [string]: any })
    local main: Color3 = spec.Main
    local accent: Color3 = spec.Accent
    local white = Color3.new(1, 1, 1)
    local text = mix(white, accent, spec.TextTint or 0.1)
    local cycle: { Color3 } = spec.Cycle
    local rim: { Color3 } = spec.Rim
    local motion = MOTIONS[spec.Motion]
    local pace: number = spec.Pace or 1
    local spread: number = spec.Spread or 1
    if pace ~= 1 or spread ~= 1 then
        motion = table.clone(motion)
        for _, key in { "Rate", "SwingSpeed", "BendSpeed" } do
            if motion[key] then
                motion[key] *= pace
            end
        end
        motion.Scale *= spread
        motion.Bend *= spread
    end
    local preset: Preset = {
        Name = spec.Name,
        Main = main,
        Panel = mix(mix(main, accent, spec.PanelMix or 0.12), white, 0.03),
        Off = mix(mix(main, accent, 0.26), white, 0.04),
        Text = text,
        Sub = mix(text, main, 0.38),
        Accent = accent,
        Disabled = mix(main, text, 0.28),
        Sky = cycle[1],
        Cycle = cycle,
        Glass = spec.Glass,
        Buttons = spec.Buttons,
        Motion = motion,
        Rim = rim,
        Fx = spec.Fx,
        Grad = spec.Grad,
    }
    Theme.Presets[spec.Name] = preset
    table.insert(ORDER_ANIMATED, spec.Name)
end

sky({
    Name = "Midnight Steel",
    Main = rgb(15, 17, 24),
    Accent = rgb(125, 175, 255),
    TextTint = 0.05,
    PanelMix = 0.14,
    Cycle = { rgb(14, 17, 27), rgb(26, 33, 52), rgb(40, 50, 78), rgb(18, 23, 37), rgb(32, 42, 66), rgb(14, 17, 27) },
    Rim = { rgb(125, 175, 255), rgb(205, 228, 255) },
    Pace = 1,
    Motion = "Aurora",
    Grad = "cross",
    Fx = "orbs",
    Glass = 0.5,
    Buttons = 0.8,
})

sky({
    Name = "Deep Ocean",
    Main = rgb(8, 18, 34),
    Accent = rgb(70, 190, 255),
    Cycle = { rgb(10, 60, 120), rgb(20, 100, 170), rgb(30, 140, 190), rgb(15, 80, 140), rgb(40, 120, 200), rgb(10, 50, 110) },
    Rim = { rgb(90, 200, 255), rgb(160, 235, 255) },
    Pace = 1.9,
    Motion = "Tide",
    Grad = "cols",
    Glass = 0.5,
    Buttons = 0.7,
})
sky({
    Name = "Midnight Galaxy",
    Main = rgb(12, 10, 34),
    Accent = rgb(150, 130, 255),
    Cycle = { rgb(40, 30, 120), rgb(80, 50, 170), rgb(30, 60, 150), rgb(110, 60, 180), rgb(50, 40, 140), rgb(70, 30, 130) },
    Rim = { rgb(160, 140, 255), rgb(110, 200, 255) },
    Pace = 1.7,
    Motion = "Pulse",
    Grad = "rows",
    Fx = "stars",
    Glass = 0.45,
    Buttons = 0.65,
})
sky({
    Name = "Arctic Ice",
    Main = rgb(16, 26, 36),
    Accent = rgb(150, 225, 255),
    Cycle = { rgb(50, 110, 150), rgb(80, 150, 190), rgb(110, 180, 210), rgb(60, 120, 170), rgb(90, 160, 200), rgb(40, 100, 140) },
    Rim = { rgb(170, 235, 255), rgb(235, 250, 255) },
    Pace = 2,
    Motion = "Slow",
    Grad = "cols",
    Fx = "snow",
    Glass = 0.5,
    Buttons = 0.68,
})
sky({
    Name = "Lavender Haze",
    Main = rgb(28, 22, 42),
    Accent = rgb(200, 170, 255),
    Cycle = { rgb(130, 100, 190), rgb(170, 130, 220), rgb(110, 90, 170), rgb(190, 150, 230), rgb(150, 110, 200), rgb(100, 80, 160) },
    Rim = { rgb(210, 180, 255), rgb(240, 225, 255) },
    Pace = 1.6,
    Motion = "Pulse",
    Grad = "rows",
    Fx = "motes",
    Glass = 0.5,
    Buttons = 0.7,
})
sky({
    Name = "Black Hole",
    Main = rgb(4, 3, 8),
    Accent = rgb(255, 150, 60),
    TextTint = 0.08,
    Cycle = { rgb(6, 4, 14), rgb(70, 28, 8), rgb(10, 6, 24), rgb(120, 54, 12), rgb(4, 3, 10), rgb(60, 20, 70) },
    Rim = { rgb(255, 170, 70), rgb(150, 80, 255) },
    Pace = 1.4,
    Motion = "Pulse",
    Grad = "cross",
    Fx = "stars",
    Glass = 0.5,
    Buttons = 0.7,
})

sky({
    Name = "Ink Wash",
    Main = rgb(14, 14, 18),
    Accent = rgb(220, 210, 190),
    TextTint = 0.06,
    Cycle = { rgb(40, 42, 56), rgb(70, 72, 90), rgb(30, 30, 40), rgb(100, 100, 116), rgb(50, 54, 74), rgb(24, 24, 32) },
    Rim = { rgb(230, 220, 200), rgb(150, 160, 200) },
    Pace = 3,
    Motion = "Tide",
    Grad = "rows",
    Fx = "dust",
    Glass = 0.58,
    Buttons = 0.78,
})

local ORDER_BRANDS: { string } = {}
local function brand(name: string, main: Color3, panel: Color3, off: Color3, text: Color3, sub: Color3, accent: Color3, disabled: Color3, rim: { Color3 })
    Theme.Presets[name] = {
        Name = name,
        Main = main,
        Panel = panel,
        Off = off,
        Text = text,
        Sub = sub,
        Accent = accent,
        Disabled = disabled,
        Rim = rim,
    }
    table.insert(ORDER_BRANDS, name)
end

brand("Default", rgb(16, 16, 18), rgb(26, 26, 29), rgb(44, 44, 49), rgb(244, 244, 247), rgb(150, 150, 160), rgb(244, 244, 247), rgb(96, 96, 104), { rgb(244, 244, 247), rgb(150, 150, 160) })
table.insert(ORDER_BRANDS, 1, table.remove(ORDER_BRANDS) :: string)
;(Theme.Presets.Default :: any).Pure = true
brand("Google Dark", rgb(32, 33, 36), rgb(48, 49, 52), rgb(60, 64, 67), rgb(232, 234, 237), rgb(154, 160, 166), rgb(138, 180, 248), rgb(95, 99, 104), { rgb(138, 180, 248), rgb(129, 201, 149) })
brand("GitHub Dark", rgb(13, 17, 23), rgb(22, 27, 34), rgb(48, 54, 61), rgb(230, 237, 243), rgb(125, 133, 144), rgb(88, 166, 255), rgb(72, 79, 88), { rgb(88, 166, 255), rgb(63, 185, 80) })
brand("Catppuccin Mocha", rgb(30, 30, 46), rgb(49, 50, 68), rgb(69, 71, 90), rgb(205, 214, 244), rgb(166, 173, 200), rgb(203, 166, 247), rgb(88, 91, 112), { rgb(245, 194, 231), rgb(137, 180, 250) })

Theme.CustomMain = Color3.fromRGB(18, 18, 18)
Theme.CustomAccent = Color3.fromRGB(255, 255, 255)

local season: string? = nil
Theme.Season = season
Theme.Default = Theme.Presets[season or "Default"]

Theme.PresetOrder = {}
for _, name in ORDER_BRANDS do
    if name == "Default" then
        table.insert(Theme.PresetOrder, name)
    end
end
for _, name in ORDER_ANIMATED do
    table.insert(Theme.PresetOrder, name)
end
for _, name in ORDER_BRANDS do
    if name ~= "Default" then
        table.insert(Theme.PresetOrder, name)
    end
end

local MAIN_TOLERANCE = 0.3
local ACCENT_TOLERANCE = 0.5

local function away(first: Color3, second: Color3): number
    return math.abs(first.R - second.R) + math.abs(first.G - second.G) + math.abs(first.B - second.B)
end

function Theme.presetFor(main: Color3, accent: Color3?): string?
    for _, name in Theme.PresetOrder do
        local preset = Theme.Presets[name]
        local accentAway = if accent then away(accent, preset.Accent) else 0
        if away(main, preset.Main) < MAIN_TOLERANCE and accentAway < ACCENT_TOLERANCE then
            return name
        end
    end
    return nil
end

function Theme.isPreset(preset: Preset, main: Color3, accent: Color3): boolean
    return away(main, preset.Main) < 0.01 and away(accent, preset.Accent) < 0.01
end

return Theme
end
modules["core/util"] = function(...)

local Util = {}

function Util.finite(value: any, fallback: number?): number
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return fallback or 0
    end
    return value
end

function Util.lerp(from: number, to: number, alpha: number): number
    return from + (to - from) * alpha
end

function Util.lerpVector2(from: Vector2, to: Vector2, alpha: number): Vector2
    return Vector2.new(from.X + (to.X - from.X) * alpha, from.Y + (to.Y - from.Y) * alpha)
end

function Util.roundVector2(vector: Vector2): Vector2
    return Vector2.new(math.floor(vector.X + 0.5), math.floor(vector.Y + 0.5))
end

function Util.contains(point: Vector2, position: Vector2, size: Vector2): boolean
    return point.X >= position.X and point.X <= position.X + size.X
        and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

function Util.distanceSquared(first: Vector3?, second: Vector3?): number
    if not first or not second then
        return math.huge
    end
    local x = first.X - second.X
    local y = first.Y - second.Y
    local z = first.Z - second.Z
    return x * x + y * y + z * z
end

function Util.sameSize(first: Vector3?, second: Vector3?, epsilon: number?): boolean
    if not first or not second then
        return false
    end
    local limit = epsilon or 0.01
    return math.abs(first.X - second.X) <= limit
        and math.abs(first.Y - second.Y) <= limit
        and math.abs(first.Z - second.Z) <= limit
end

local function index(object: any, key: string): any
    return object[key]
end

local function assign(object: any, key: string, value: any)
    if object[key] ~= value then
        object[key] = value
    end
end

function Util.read(object: any, key: string): any
    local ok, value = pcall(index, object, key)
    if ok then
        return value
    end
    return nil
end

function Util.write(object: any, key: string, value: any): boolean
    return (pcall(assign, object, key, value))
end

local function findChild(object: any, name: string): any
    return object:FindFirstChild(name)
end

function Util.child(object: any, name: string): any
    local ok, found = pcall(findChild, object, name)
    if ok then
        return found
    end
    return nil
end

local function listChildren(object: any): { any }
    return object:GetChildren()
end

function Util.children(object: any): { any }
    local ok, list = pcall(listChildren, object)
    if ok and type(list) == "table" then
        return list
    end
    return {}
end

local function listDescendants(object: any): { any }
    return object:GetDescendants()
end

function Util.descendants(object: any): { any }
    local ok, list = pcall(listDescendants, object)
    if ok and type(list) == "table" then
        return list
    end
    return {}
end

function Util.className(object: any): string
    return tostring(Util.read(object, "ClassName") or "")
end

function Util.removeValue(list: { any }, value: any): boolean
    for index = #list, 1, -1 do
        if list[index] == value then
            table.remove(list, index)
            return true
        end
    end
    return false
end

function Util.truncate(text: string, limit: number, suffix: string?): string
    if #text <= limit then
        return text
    end
    local ending = suffix or ".."
    return string.sub(text, 1, limit - #ending) .. ending
end

function Util.trim(text: string): string
    local trimmed = string.gsub(text, "^%s+", "")
    trimmed = string.gsub(trimmed, "%s+$", "")
    return trimmed
end

function Util.isColor(value: any): boolean
    if type(value) ~= "userdata" and type(value) ~= "table" then
        return false
    end
    local ok, red = pcall(function()
        return value.R
    end)
    return ok and type(red) == "number"
end

function Util.newWeakKeyed(): { [any]: any }
    return setmetatable({}, { __mode = "k" }) :: any
end

return Util
end
modules["input/chat"] = function(...)

local Chat = {}

local userInput: any = nil

function Chat.isTyping(): boolean
    if not userInput then
        userInput = game:GetService("UserInputService")
    end
    local ok, box = pcall(function()
        return userInput:GetFocusedTextBox()
    end)
    return ok and box ~= nil
end

return Chat
end
modules["input/keys"] = function(...)

local Keys = {}

local userInput: any = nil

local function service(): any
    if not userInput then
        userInput = game:GetService("UserInputService")
    end
    return userInput
end

export type KeySet = { [string]: boolean? }

local MODIFIER_ORDER = { "RightAlt", "LeftAlt", "RightCtrl", "LeftCtrl", "RightShift", "LeftShift" }

local ALIASES: { [string]: string } = {
    MouseButton1 = "LeftMouse",
    Mouse1 = "LeftMouse",
    LButton = "LeftMouse",
    LeftButton = "LeftMouse",
    LeftMouseButton = "LeftMouse",
    MouseButton2 = "RightMouse",
    Mouse2 = "RightMouse",
    RButton = "RightMouse",
    RightButton = "RightMouse",
    RightMouseButton = "RightMouse",
    LShift = "LeftShift",
    RShift = "RightShift",
    LCtrl = "LeftCtrl",
    RCtrl = "RightCtrl",
    LeftControl = "LeftCtrl",
    RightControl = "RightCtrl",
    LControl = "LeftCtrl",
    RControl = "RightCtrl",
    Control = "Ctrl",
    LAlt = "LeftAlt",
    RAlt = "RightAlt",
    LeftMenu = "LeftAlt",
    RightMenu = "RightAlt",
    Return = "Enter",
    Zero = "0",
    One = "1",
    Two = "2",
    Three = "3",
    Four = "4",
    Five = "5",
    Six = "6",
    Seven = "7",
    Eight = "8",
    Nine = "9",
}

local normalized: { [string]: string } = {}
local normalizedCount = 0

function Keys.normalize(key: any): string
    local raw = tostring(key or "")
    local known = normalized[raw]
    if known then
        return known
    end
    local name = string.gsub(raw, "^Enum%.KeyCode%.", "")
    name = string.gsub(name, "^KeyCode%.", "")
    local result = ALIASES[name] or name
    if normalizedCount >= 512 then
        normalized, normalizedCount = {}, 0
    end
    normalized[raw] = result
    normalizedCount += 1
    return result
end

local function dropGenericModifiers(keys: KeySet)
    if keys.LeftShift or keys.RightShift then
        keys.Shift = nil
    end
    if keys.LeftCtrl or keys.RightCtrl then
        keys.Ctrl = nil
        keys.Control = nil
    end
    if keys.LeftAlt or keys.RightAlt then
        keys.Alt = nil
    end
end

local function readKeyboard(): KeySet
    local keys: KeySet = {}
    local ok, pressed = pcall(function()
        return service():GetKeysPressed()
    end)
    if ok and type(pressed) == "table" then
        for index = 1, #pressed do
            local key = Keys.normalize(pressed[index].KeyCode.Name)
            if key ~= "" and key ~= "Unknown" then
                keys[key] = true
            end
        end
    end
    dropGenericModifiers(keys)
    return keys
end

local function readButton(read: () -> boolean): boolean
    local ok, down = pcall(read)
    return ok and down == true
end

function Keys.pressed(includeMouse: boolean): KeySet
    local keys = readKeyboard()
    if includeMouse then
        if readButton(function()
            return service():IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        end) then
            keys.LeftMouse = true
        end
        if readButton(function()
            return service():IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        end) then
            keys.RightMouse = true
        end
    end
    return keys
end

function Keys.findNew(keys: KeySet, previous: KeySet): string?
    for index = 1, #MODIFIER_ORDER do
        local key = MODIFIER_ORDER[index]
        if keys[key] and not previous[key] then
            return key
        end
    end
    for key in keys do
        if not previous[key] then
            return key
        end
    end
    return nil
end

return Keys
end
modules["input/window"] = function(...)

local import: (string) -> any = ...
local Draw: typeof(require("../render/draw")) = import("render/draw")

local Window = {}

local ACTION = "OkloUIBlockWheel"
local MOVEMENT_KEYS = { "W", "A", "S", "D", "Up", "Down", "Left", "Right", "Space" }

local blocked: boolean? = nil
local wheelBound = false
local function bindWheel(state: boolean)
    if state and string.find(tostring(getgenv().OkloUISkip), "wheel", 1, true) ~= nil then
        state = false
    end
    if state == wheelBound then
        return
    end
    wheelBound = state
    pcall(function()
        local actions = game:GetService("ContextActionService")
        if state then
            actions:BindActionAtPriority(ACTION, function()
                return Enum.ContextActionResult.Sink
            end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseWheel)
        else
            actions:UnbindAction(ACTION)
        end
    end)
end

function Window.playerIsPlaying(keys: { [string]: boolean? }): boolean
    if keys.RightMouse then
        return true
    end
    for _, name in MOVEMENT_KEYS do
        if keys[name] then
            return true
        end
    end
    return false
end

function Window.setBlocked(state: boolean, position: Vector2?, size: Vector2?, wheel: boolean?)
    local at = position or Vector2.new(0, 0)
    local extent = size or Vector2.new(0, 0)
    if state then
        Draw.blocker(at.X, at.Y, extent.X, extent.Y, true)
    elseif blocked ~= false then
        Draw.blocker(0, 0, 0, 0, false)
    end
    blocked = state
    bindWheel(if wheel == nil then state else wheel)
end

return Window
end
modules["lib"] = function(...)

local import: (string) -> any = ...
local Builder: typeof(require("./ui/builder")) = import("ui/builder")
local Canvas: typeof(require("./render/canvas")) = import("render/canvas")
local Color: typeof(require("./core/color")) = import("core/color")
local Draw: typeof(require("./render/draw")) = import("render/draw")
local Hits: typeof(require("./ui/hits")) = import("ui/hits")
local Keys: typeof(require("./input/keys")) = import("input/keys")
local Fonts: typeof(require("./ui/fonts")) = import("ui/fonts")
local Pages: typeof(require("./ui/pages")) = import("ui/pages")
local Panels: typeof(require("./ui/panels")) = import("ui/panels")
local Painter: typeof(require("./ui/painter")) = import("ui/painter")
local Runner: typeof(require("./ui/runner")) = import("ui/runner")
local Storage: typeof(require("./core/storage")) = import("core/storage")
local UpdatesPage: typeof(require("./ui/updatespage")) = import("ui/updatespage")
local Util: typeof(require("./core/util")) = import("core/util")
local Window: typeof(require("./ui/window")) = import("ui/window")
local WindowBlock: typeof(require("./input/window")) = import("input/window")

local OkloUI = {}

local Library = {}
Library.__index = Library

type Map = { [string]: any }

local UNLOAD_DELAY = 0.3
local RELOAD_FADE = 0.55
local RELOAD_DELAY = 0.1
local REGISTRY = "OkloUIInstances"

local function registry(): Map
    local environment = getgenv()
    local instances = environment[REGISTRY]
    if type(instances) ~= "table" then
        instances = {}
        environment[REGISTRY] = instances
    end
    return instances
end

function OkloUI.new(options: Map)
    local instance: Map = setmetatable({ Started = false, Destroyed = false, User = options }, Library) :: any
    local windowOptions = table.clone(options)
    windowOptions.OnUnload = function()
        task.spawn(function()
            instance:teardown()
            task.wait(UNLOAD_DELAY)
            instance:destroy()
        end)
    end
    if options.OnReload then
        windowOptions.OnReload = function()
            task.spawn(function()
                instance:teardown()
                task.wait(RELOAD_FADE)
                instance:destroy()
                task.wait(RELOAD_DELAY)
                options.OnReload()
            end)
        end
    end
    instance.Window = Window.new(windowOptions)
    local id: string = instance.Window.Options.Id
    local previous = registry()[id]
    if previous then
        pcall(previous.destroy, previous)
    end
    registry()[id] = instance
    return instance
end

function Library.teardown(self: Map)
    local hook = self.User.OnUnload
    if hook then
        pcall(hook)
    end
end

function Library.tab(self: Map, name: string, options: Map?): Map
    return Builder.newTab(self.Window, name, options)
end

function Library.updates(self: Map, spec: Map): Map
    return UpdatesPage.build(self.Window, spec)
end

function Library.flag(self: Map, flag: string, default: any, save: boolean?)
    self.Window:register(flag, default, save ~= false)
end

function Library.get(self: Map, flag: string): any
    return self.Window:get(flag)
end

function Library.set(self: Map, flag: string, value: any)
    self.Window:set(flag, value)
end

function Library.onFrame(self: Map, callback: (Map) -> ())
    self.Window:onFrame(callback)
end

function Library.sidebar(self: Map, definition: Map)
    self.Window:setSidebar(definition)
end

function Library.setWidth(self: Map, width: number, instant: boolean?)
    self.Window:setWidth(width, instant)
end

function Library.info(self: Map, title: string, lines: { string }, width: number?)
    self.Window:openPopup("info", { Title = title, Lines = lines, Width = width })
end

function Library.panel(self: Map, options: Map): Map
    return Panels.add(self.Window, options)
end

function Library.popup(self: Map, name: string, definition: Map)
    local width, height = definition.Width or 300, definition.Height or 200
    self.Window:addPopup(name, {
        size = function(app: Map, arg: any)
            if definition.Size then
                return definition.Size(app, arg)
            end
            return width, height
        end,
        title = function(app: Map, arg: any)
            local title = definition.Title
            if type(title) == "function" then
                return title(app, arg)
            end
            return title or ""
        end,
        locked = definition.Locked == true,
        render = function(app: Map, kit: Map, arg: any)
            definition.Render(kit, app, arg)
        end,
    })
end

local function rowNamed(row: Map, name: string): boolean
    if row.kind == "pair" then
        return row.left.text == name or row.right.text == name
    end
    return row.text == name
end

local function mergeSections(window: Map, tabName: string, merge: Map)
    local tab = window.TabByName[tabName]
    if not tab then
        return
    end
    local from, into
    for _, section in tab.sections do
        if section.title == merge.From then
            from = section
        elseif section.title == merge.Into then
            into = section
        end
    end
    if not from or not into then
        return
    end
    local at = #into.rows + 1
    if merge.Before then
        for index, row in into.rows do
            if rowNamed(row, merge.Before) then
                at = index
                break
            end
        end
    end
    for _, row in from.rows do
        table.insert(into.rows, at, row)
        at += 1
    end
    table.remove(tab.sections, table.find(tab.sections, from) :: number)
end

local function applyPageEdits(window: Map, edits: Map)
    for tabName, edit in edits do
        for _, merge in edit.Merge or {} do
            mergeSections(window, tabName, merge)
        end
        local tab = window.TabByName[tabName]
        for old, new in edit.Rename or {} do
            for _, section in if tab then tab.sections else {} do
                if section.title == old then
                    section.title = new
                end
            end
        end
    end
end

function Library.editPages(self: Map, edits: Map)
    self.PageEdits = edits
end

function Library.openPopup(self: Map, name: string, arg: any?)
    self.Window:openPopup(name, arg)
end

function Library.closePopup(self: Map)
    self.Window:closePopup()
end

function Library.unload(self: Map)
    self.Window:unload()
end

function Library.setVisible(self: Map, visible: boolean)
    self.Window.State.Visible = visible
end

function Library.isVisible(self: Map): boolean
    return self.Window.State.Visible == true
end

function Library.start(self: Map)
    if self.Started then
        return
    end
    self.Started = true
    local window = self.Window
    if not self.User.NoSettings then
        Pages.install(window)
    end
    if self.PageEdits then
        applyPageEdits(window, self.PageEdits)
    end
    window:finalize()
    self.Stop = Runner.start(window)
end

function Library.destroy(self: Map)
    if self.Destroyed then
        return
    end
    self.Destroyed = true
    if self.Stop then
        self.Stop()
    end
    Canvas.destroy()
    Draw.destroyAll()
    Painter.reset()
    Hits.cancel()
    WindowBlock.setBlocked(false)
    local instances = registry()
    if instances[self.Window.Options.Id] == self then
        instances[self.Window.Options.Id] = nil
    end
end

OkloUI.Canvas = Canvas
OkloUI.Color = Color
OkloUI.Util = Util
OkloUI.Keys = Keys
OkloUI.Fonts = Fonts
OkloUI.Storage = Storage
OkloUI.Version = "1.0.0"
OkloUI.UpdateNoticeLog = true

return OkloUI
end
modules["render/canvas"] = function(...)

local Canvas = {}

type Pool = { items: { any }, used: number, shown: number }
type Scope = { pools: { [string]: Pool }, stamp: number }
type Map = { [string]: any }

local KINDS = { "Line", "Square", "Circle", "Quad", "Triangle", "Text" }

local function newScope(): Scope
    local pools: { [string]: Pool } = {}
    for _, kind in KINDS do
        pools[kind] = { items = {}, used = 0, shown = 0 }
    end
    return { pools = pools, stamp = 0 }
end

local fallback: Scope = newScope()
local scopes: { [string]: Scope } = {}
local current: Scope = fallback
local touched: { Scope } = { fallback }
local lastTouched: { Scope } = {}
local frameStamp = 0

local camera: any = nil
local order = 0

local FONT = 0
local BLACK = Color3.new(0, 0, 0)

function Canvas.setCamera(value: any)
    camera = value
end

local function acquire(kind: string): (any, Map)
    local pool = current.pools[kind]
    local index = pool.used + 1
    pool.used = index
    local item = pool.items[index]
    if not item then
        local object = Drawing.new(kind)
        item = { object = object, shadow = {} }
        pool.items[index] = item
    end
    order += 1
    return item.object, item.shadow
end

local function set(object: any, shadow: Map, key: string, value: any)
    if shadow[key] ~= value then
        shadow[key] = value
        object[key] = value
    end
end

local function style(object: any, shadow: Map, color: Color3, alpha: number)
    set(object, shadow, "Color", color)
    set(object, shadow, "Transparency", math.clamp(alpha, 0, 1))
    set(object, shadow, "ZIndex", order)
    set(object, shadow, "Visible", true)
end

local function restart(scope: Scope)
    for _, pool in scope.pools do
        pool.used = 0
    end
end

local function trim(scope: Scope)
    for _, pool in scope.pools do
        for index = pool.used + 1, pool.shown do
            local item = pool.items[index]
            if item then
                set(item.object, item.shadow, "Visible", false)
            end
        end
        pool.shown = pool.used
    end
end

function Canvas.begin()
    order = 0
    frameStamp += 1
    lastTouched, touched = touched, { fallback }
    fallback.stamp = frameStamp
    restart(fallback)
    current = fallback
end

function Canvas.scope(key: any?)
    if key == nil then
        current = fallback
        return
    end
    local name = tostring(key)
    local scope = scopes[name]
    if not scope then
        scope = newScope()
        scopes[name] = scope
    end
    if scope.stamp ~= frameStamp then
        scope.stamp = frameStamp
        restart(scope)
        touched[#touched + 1] = scope
    end
    current = scope
end

function Canvas.skip(kind: string)
    local pool = current.pools[kind]
    local index = pool.used + 1
    pool.used = index
    local item = pool.items[index]
    if item then
        set(item.object, item.shadow, "Visible", false)
    end
end

function Canvas.finish()
    for _, scope in touched do
        trim(scope)
    end
    for _, scope in lastTouched do
        if scope.stamp ~= frameStamp then
            restart(scope)
            trim(scope)
        end
    end
    current = fallback
end

function Canvas.clear()
    Canvas.begin()
    Canvas.finish()
end

function Canvas.line(from: Vector2, to: Vector2, color: Color3, alpha: number, thickness: number)
    local object, shadow = acquire("Line")
    set(object, shadow, "From", from)
    set(object, shadow, "To", to)
    set(object, shadow, "Thickness", thickness)
    style(object, shadow, color, alpha)
end

function Canvas.circle(center: Vector2, radius: number, color: Color3, alpha: number, thickness: number)
    local object, shadow = acquire("Circle")
    set(object, shadow, "Filled", false)
    set(object, shadow, "Position", center)
    set(object, shadow, "Radius", radius)
    set(object, shadow, "NumSides", math.clamp(math.ceil(radius * 1.5), 12, 64))
    set(object, shadow, "Thickness", thickness)
    style(object, shadow, color, alpha)
end

function Canvas.filledCircle(center: Vector2, radius: number, color: Color3, alpha: number)
    local object, shadow = acquire("Circle")
    set(object, shadow, "Filled", true)
    set(object, shadow, "Position", center)
    set(object, shadow, "Radius", radius)
    set(object, shadow, "NumSides", math.clamp(math.ceil(radius * 1.5), 8, 48))
    style(object, shadow, color, alpha)
end

function Canvas.rect(position: Vector2, size: Vector2, color: Color3, alpha: number, thickness: number)
    local object, shadow = acquire("Square")
    set(object, shadow, "Filled", false)
    set(object, shadow, "Position", position)
    set(object, shadow, "Size", size)
    set(object, shadow, "Thickness", thickness)
    style(object, shadow, color, alpha)
end

function Canvas.filledRect(position: Vector2, size: Vector2, color: Color3, alpha: number)
    local object, shadow = acquire("Square")
    set(object, shadow, "Filled", true)
    set(object, shadow, "Position", position)
    set(object, shadow, "Size", size)
    style(object, shadow, color, alpha)
end

local function quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color3, alpha: number, filled: boolean, thickness: number)
    local object, shadow = acquire("Quad")
    set(object, shadow, "Filled", filled)
    set(object, shadow, "PointA", a)
    set(object, shadow, "PointB", b)
    set(object, shadow, "PointC", c)
    set(object, shadow, "PointD", d)
    set(object, shadow, "Thickness", thickness)
    style(object, shadow, color, alpha)
end

function Canvas.quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color3, alpha: number, thickness: number)
    quad(a, b, c, d, color, alpha, false, thickness)
end

function Canvas.filledQuad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color3, alpha: number)
    quad(a, b, c, d, color, alpha, true, 1)
end

function Canvas.filledTriangle(a: Vector2, b: Vector2, c: Vector2, color: Color3, alpha: number)
    local object, shadow = acquire("Triangle")
    set(object, shadow, "Filled", true)
    set(object, shadow, "PointA", a)
    set(object, shadow, "PointB", b)
    set(object, shadow, "PointC", c)
    set(object, shadow, "Thickness", 1)
    style(object, shadow, color, alpha)
end

local probe: any = nil

local measured: { [string]: Vector2 } = {}
local measuredCount = 0

function Canvas.measure(text: string, size: number): Vector2
    local key = size .. "|" .. text
    local known = measured[key]
    if known then
        return known
    end
    local bounds, exact = Canvas.measureNow(text, size)
    if exact then
        if measuredCount >= 600 then
            measured, measuredCount = {}, 0
        end
        measured[key] = bounds
        measuredCount += 1
    end
    return bounds
end

function Canvas.measureNow(text: string, size: number): (Vector2, boolean)
    if not probe then
        local ok, object = pcall(Drawing.new, "Text")
        if not ok then
            return Vector2.new(#text * size * 0.5, size), false
        end
        probe = object
        probe.Visible = false
    end
    probe.Text = text
    probe.Size = size
    probe.Font = FONT
    local ok, bounds = pcall(function()
        return probe.TextBounds
    end)
    if ok and bounds and bounds.X > 0 then
        return bounds, true
    end
    return Vector2.new(#text * size * 0.5, size), false
end

function Canvas.label(center: Vector2, size: number, textColor: Color3, text: string, background: Color3, backgroundAlpha: number)
    local bounds = Canvas.measure(text, size)
    local padX, padY = 7, 3
    local width, height = bounds.X + padX * 2, bounds.Y + padY * 2
    local corner = Vector2.new(center.X - width * 0.5, center.Y - height * 0.5)
    if backgroundAlpha > 0 then
        Canvas.filledRect(corner, Vector2.new(width, height), background, backgroundAlpha)
    end
    Canvas.text(Vector2.new(center.X, center.Y - bounds.Y * 0.5), size, textColor, 1, text, true, nil)
end

function Canvas.glowLabel(center: Vector2, size: number, text: string, fill: Color3, from: Color3, to: Color3, now: number)
    local bounds = Canvas.measure(text, size)
    local width, height = bounds.X + 14, bounds.Y + 6
    local corner = Vector2.new(center.X - width * 0.5, center.Y - height * 0.5)
    Canvas.filledRect(corner, Vector2.new(width, height), fill, 0.9)
    local wave = 0.5 + 0.5 * math.sin(now * 3)
    Canvas.rect(corner, Vector2.new(width, height), from:Lerp(to, wave), 1, 1.5)
    Canvas.text(Vector2.new(center.X, center.Y - bounds.Y * 0.5), size, Color3.new(1, 1, 1), 1, text, true, nil)
end

function Canvas.text(position: Vector2, size: number, color: Color3, alpha: number, text: string, center: boolean, font: any)
    local object, shadow = acquire("Text")
    local used = if type(font) == "number" and font >= 0 and font <= 3 then font else FONT
    set(object, shadow, "Text", text)
    set(object, shadow, "Size", size)
    set(object, shadow, "Font", used)
    set(object, shadow, "Center", center)
    set(object, shadow, "Outline", true)
    set(object, shadow, "OutlineColor", BLACK)
    set(object, shadow, "Position", position)
    style(object, shadow, color, alpha)
end

local function screenOf(point: Vector3): (number, number, boolean)
    local cam = camera
    if not cam then
        return 0, 0, false
    end
    local ok, screen = pcall(cam.WorldToViewportPoint, cam, point)
    if not ok or not screen or screen.Z <= 0 or screen.X ~= screen.X or screen.Y ~= screen.Y then
        return 0, 0, false
    end
    return screen.X, screen.Y, true
end

local FACES = { { 1, 2, 3, 4 }, { 5, 6, 7, 8 }, { 1, 2, 6, 5 }, { 2, 3, 7, 6 }, { 3, 4, 8, 7 }, { 4, 1, 5, 8 } }

local function drawHealth(health: number, left: number, top: number, bottom: number)
    local fraction = math.clamp(health, 0, 1)
    local height = bottom - top
    Canvas.filledRect(Vector2.new(left - 8, top - 1), Vector2.new(5, height + 2), BLACK, 0.55)
    Canvas.filledRect(Vector2.new(left - 7, top + height * (1 - fraction)), Vector2.new(3, height * fraction), Color3.new(1 - fraction, fraction, 0.15), 0.95)
end

function Canvas.screenBox(flat: boolean, corners: { Vector3 }, lineColor: Color3, lineAlpha: number, fillColor: Color3, fillAlpha: number, health: number?, thickness: number?)
    local points: { Vector2 } = {}
    local visible: { boolean } = {}
    local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
    local all = true
    for index = 1, 8 do
        local x, y, ok = screenOf(corners[index])
        points[index], visible[index] = Vector2.new(x, y), ok
        if ok then
            left, top, right, bottom = math.min(left, x), math.min(top, y), math.max(right, x), math.max(bottom, y)
        else
            all = false
        end
    end
    if flat then
        if all and right > left then
            Canvas.filledRect(Vector2.new(left, top), Vector2.new(right - left, bottom - top), fillColor, fillAlpha)
            Canvas.rect(Vector2.new(left, top), Vector2.new(right - left, bottom - top), lineColor, lineAlpha, thickness or 1)
        end
    else
        for _, face in FACES do
            local a, b, c, d = face[1], face[2], face[3], face[4]
            if visible[a] and visible[b] and visible[c] and visible[d] then
                Canvas.filledQuad(points[a], points[b], points[c], points[d], fillColor, fillAlpha)
                Canvas.quad(points[a], points[b], points[c], points[d], lineColor, lineAlpha, thickness or 1)
            end
        end
    end
    if health and right > left then
        drawHealth(health, left, top, bottom)
    end
end

function Canvas.worldBox(flat: boolean, corners: { Vector3 }, lineColor: Color3, lineAlpha: number, fillColor: Color3, fillAlpha: number, health: number?, _velocity: Vector3?, thickness: number?)
    Canvas.screenBox(flat, corners, lineColor, lineAlpha, fillColor, fillAlpha, health, thickness)
end

function Canvas.worldPath(points: { Vector3 }, color: Color3, alpha: number, thickness: number)
    local previous: Vector2? = nil
    for _, point in points do
        local x, y, visible = screenOf(point)
        local current: Vector2? = if visible then Vector2.new(x, y) else nil
        if previous and current then
            Canvas.line(previous, current, color, alpha, thickness)
        end
        previous = current
    end
end

function Canvas.worldText(point: Vector3, size: number, color: Color3, alpha: number, text: string, font: any, _velocity: Vector3?)
    local x, y, visible = screenOf(point)
    if visible then
        Canvas.text(Vector2.new(x, y), size, color, alpha, text, true, font)
    end
end

function Canvas.project(point: Vector3): (Vector2?, number)
    local cam = camera
    if not cam then
        return nil, 0
    end
    local ok, screen = pcall(cam.WorldToViewportPoint, cam, point)
    if not ok or not screen then
        return nil, 0
    end
    return Vector2.new(screen.X, screen.Y), screen.Z
end

local function destroyScope(scope: Scope)
    for _, pool in scope.pools do
        for _, item in pool.items do
            pcall(function()
                item.object:Destroy()
            end)
        end
        pool.items, pool.used, pool.shown = {}, 0, 0
    end
end

function Canvas.destroy()
    destroyScope(fallback)
    for _, scope in scopes do
        destroyScope(scope)
    end
    scopes = {}
    current = fallback
    touched, lastTouched = { fallback }, {}
    if probe then
        pcall(function()
            probe:Destroy()
        end)
        probe = nil
    end
end

return Canvas
end
modules["render/draw"] = function(...)

local import: (string) -> any = ...
local Fonts: typeof(require("../ui/fonts")) = import("ui/fonts")

local Draw = {}

export type Node = {
    kind: string,
    object: any,
    shown: boolean,
    shadow: { [string]: any },
    show: (self: Node, visible: boolean) -> (),
    paint: (self: Node, colors: { Color3 }, rotation: number) -> (),
    fade: (self: Node, from: number, to: number, rotation: number) -> (),
    unpaint: (self: Node) -> (),
    remove: (self: Node) -> (),
}

type Map = { [string]: any }

local root: any = nil
local nodes: { Node } = {}
local sink: any = nil
local widths: { [string]: number } = {}
local widthCount = 0

local MAX_CACHED_WIDTHS = 512
local ROOT_NAME = "OkloUI"

local function container(): any
    local ok, found = pcall(function()
        return gethui()
    end)
    if ok and found then
        return found
    end
    return game:GetService("CoreGui")
end

local function ensureRoot(): any
    if root and root.Parent then
        return root
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = ROOT_NAME
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    local env = getgenv()
    local order = math.min((tonumber(env.__OkloUIOrder) or 2147483000) + 1, 2147483640)
    env.__OkloUIOrder = order
    gui.DisplayOrder = order
    gui.Parent = container()
    root = gui
    return gui
end

function Draw.root(): any
    return ensureRoot()
end

function Draw.setEnabled(state: boolean)
    local gui = ensureRoot()
    if gui.Enabled ~= state then
        gui.Enabled = state
    end
end

local function track(node: Node): Node
    nodes[#nodes + 1] = node
    return node
end

local function show(self: Node, visible: boolean)
    if self.shown ~= visible then
        self.shown = visible
        self.object.Visible = visible
    end
end

local function remove(self: Node)
    self.shown = false
    pcall(function()
        self.object:Destroy()
    end)
end

local fine = false

local function rounded(object: any, shadow: Map, rawRadius: number, half: number?)
    local radius = math.floor(rawRadius + 0.5)
    if fine and half and rawRadius > 0 and rawRadius >= half - 0.01 then
        radius = -1
    end
    if shadow.radius == radius then
        return
    end
    shadow.radius = radius
    local corner = shadow.corner
    if not corner then
        if radius == 0 then
            return
        end
        corner = Instance.new("UICorner")
        corner.Parent = object
        shadow.corner = corner
    end
    corner.CornerRadius = if radius < 0 then UDim.new(0.5, 0) else UDim.new(0, radius)
end

function Draw.fine(state: boolean)
    fine = state
end

local clipFrames: { any } = {}
local clipKeys: { [string]: any } = {}
local clipCount = 0
local clipShown = 0
local clipFrame: any = nil
local clipX, clipY = 0, 0
local clipW, clipH = 0, 0

function Draw.setClip(x: number, y: number, width: number, height: number)
    local left, top = math.floor(x + 0.5), math.floor(y + 0.5)
    local wide, tall = math.max(0, math.floor(width + 0.5)), math.max(0, math.floor(height + 0.5))
    local key = left .. ":" .. top .. ":" .. wide .. ":" .. tall
    local frame = clipKeys[key]
    if not frame then
        clipCount += 1
        frame = clipFrames[clipCount]
        if not frame then
            frame = Instance.new("Frame")
            frame.BackgroundTransparency = 1
            frame.BorderSizePixel = 0
            frame.ClipsDescendants = true
            frame.Parent = ensureRoot()
            clipFrames[clipCount] = frame
        end
        frame.Position = UDim2.fromOffset(left, top)
        frame.Size = UDim2.fromOffset(wide, tall)
        frame.Visible = true
        clipKeys[key] = frame
    end
    clipFrame, clipX, clipY, clipW, clipH = frame, left, top, wide, tall
end

function Draw.clipBox(): (number?, number?, number?, number?)
    if not clipFrame then
        return nil, nil, nil, nil
    end
    return clipX, clipY, clipW, clipH
end

function Draw.clearClip()
    clipFrame = nil
end

function Draw.beginFrame()
    clipCount = 0
    clipFrame = nil
    table.clear(clipKeys)
end

function Draw.endFrame()
    for index = clipCount + 1, clipShown do
        local frame = clipFrames[index]
        if frame then
            frame.Visible = false
        end
    end
    clipShown = clipCount
    clipFrame = nil
end

local function place(object: any, shadow: Map, rawX: number, rawY: number, rawWidth: number, rawHeight: number)
    local target = clipFrame
    if shadow.holder ~= target then
        shadow.holder = target
        shadow.x, shadow.y = nil, nil
        object.Parent = target or ensureRoot()
    end
    if target then
        rawX -= clipX
        rawY -= clipY
    end
    local x, y, width, height
    if fine then
        x, y, width, height = math.floor(rawX * 8 + 0.5) / 8, math.floor(rawY * 8 + 0.5) / 8, rawWidth, rawHeight
    else
        x, y = math.floor(rawX + 0.5), math.floor(rawY + 0.5)
        width, height = math.floor(rawWidth + 0.5), math.floor(rawHeight + 0.5)
    end
    if shadow.x ~= x or shadow.y ~= y then
        shadow.x, shadow.y = x, y
        object.Position = UDim2.fromOffset(x, y)
    end
    if shadow.w ~= width or shadow.h ~= height then
        shadow.w, shadow.h = width, height
        object.Size = UDim2.fromOffset(width, height)
    end
end

local function layer(object: any, shadow: Map, z: number)
    if shadow.z ~= z then
        shadow.z = z
        object.ZIndex = z
    end
end

function Draw.rect(): Node
    local object = Instance.new("Frame")
    object.BorderSizePixel = 0
    object.Visible = false
    object.Parent = ensureRoot()
    local node: any = { kind = "rect", object = object, shown = false, shadow = {} }
    node.show, node.remove = show, remove
    function node.update(self: Node, x: number, y: number, width: number, height: number, color: Color3, alpha: number, z: number, radius: number, rotation: number?)
        local shadow = self.shadow
        place(object, shadow, x, y, width, height)
        local turn = rotation or 0
        if shadow.rotation ~= turn then
            shadow.rotation = turn
            object.Rotation = turn
        end
        if shadow.color ~= color then
            shadow.color = color
            object.BackgroundColor3 = color
        end
        local transparency = math.floor((1 - alpha) * 500 + 0.5) / 500
        if shadow.alpha ~= transparency then
            shadow.alpha = transparency
            object.BackgroundTransparency = transparency
        end
        layer(object, shadow, z)
        rounded(object, shadow, radius, math.min(width, height) * 0.5)
    end
    function node.paint(self: Node, colors: { Color3 }, rotation: number)
        local shadow = self.shadow
        local gradient = shadow.gradient
        if not gradient then
            gradient = Instance.new("UIGradient")
            gradient.Parent = object
            shadow.gradient = gradient
        end
        if shadow.fading then
            shadow.fading = false
            gradient.Transparency = NumberSequence.new(0)
        end
        local count = #colors
        local previous: { Color3 }? = shadow.stops
        local changed = previous == nil or #previous ~= count
        if not changed and previous then
            for index, color in colors do
                local old = previous[index]
                if old.R ~= color.R or old.G ~= color.G or old.B ~= color.B then
                    changed = true
                    break
                end
            end
        end
        if changed then
            local keys = table.create(count)
            for index, color in colors do
                keys[index] = ColorSequenceKeypoint.new((index - 1) / (count - 1), color)
            end
            gradient.Color = ColorSequence.new(keys)
            shadow.stops = table.clone(colors)
        end
        if shadow.gradientRotation ~= rotation then
            shadow.gradientRotation = rotation
            gradient.Rotation = rotation
        end
        if not shadow.gradientOn then
            shadow.gradientOn = true
            gradient.Enabled = true
        end
    end
    function node.fade(self: Node, from: number, to: number, rotation: number)
        local shadow = self.shadow
        local gradient = shadow.gradient
        if not gradient then
            gradient = Instance.new("UIGradient")
            gradient.Parent = object
            shadow.gradient = gradient
        end
        if shadow.stops ~= nil then
            shadow.stops = nil
            gradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
        end
        if shadow.fadeFrom ~= from or shadow.fadeTo ~= to or not shadow.fading then
            shadow.fadeFrom, shadow.fadeTo, shadow.fading = from, to, true
            gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - from), NumberSequenceKeypoint.new(1, 1 - to) })
        end
        if shadow.gradientRotation ~= rotation then
            shadow.gradientRotation = rotation
            gradient.Rotation = rotation
        end
        if not shadow.gradientOn then
            shadow.gradientOn = true
            gradient.Enabled = true
        end
    end
    function node.unpaint(self: Node)
        local shadow = self.shadow
        if shadow.gradientOn then
            shadow.gradientOn = false
            shadow.gradient.Enabled = false
        end
    end
    return track(node)
end

local sequences: { [string]: any } = {}

local function trailSequences(color: Color3, light: Color3, weight: number): (any, any)
    local key = (if weight >= 1 then "t" elseif weight <= 0 then "f" else "w" .. weight) .. tostring(color) .. tostring(light)
    local cached = sequences[key]
    if cached then
        return cached[1], cached[2]
    end
    local colors, alphas
    if weight > 0 and weight < 1 then
        local function mix(flat: number, trailed: number): number
            return flat + (trailed - flat) * weight
        end
        colors = ColorSequence.new({
            ColorSequenceKeypoint.new(0, color),
            ColorSequenceKeypoint.new(0.45, color),
            ColorSequenceKeypoint.new(1, color:Lerp(light, weight)),
        })
        alphas = NumberSequence.new({
            NumberSequenceKeypoint.new(0, mix(0.72, 0.84)),
            NumberSequenceKeypoint.new(0.4, mix(0.72, 0.8)),
            NumberSequenceKeypoint.new(0.78, mix(0.72, 0.35)),
            NumberSequenceKeypoint.new(1, mix(0.72, 0)),
        })
    elseif weight >= 1 then
        colors = ColorSequence.new({
            ColorSequenceKeypoint.new(0, color),
            ColorSequenceKeypoint.new(0.45, color),
            ColorSequenceKeypoint.new(1, light),
        })
        alphas = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.84),
            NumberSequenceKeypoint.new(0.4, 0.8),
            NumberSequenceKeypoint.new(0.78, 0.35),
            NumberSequenceKeypoint.new(1, 0),
        })
    else
        colors = ColorSequence.new(color)
        alphas = NumberSequence.new(0.72)
    end
    sequences[key] = { colors, alphas }
    return colors, alphas
end

function Draw.outline(): Node
    local object = Instance.new("Frame")
    object.BackgroundTransparency = 1
    object.BorderSizePixel = 0
    object.Visible = false
    object.Parent = ensureRoot()
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Parent = object
    local gradient = Instance.new("UIGradient")
    gradient.Parent = stroke
    local node: any = { kind = "outline", object = object, shown = false, shadow = {} }
    node.show, node.remove = show, remove
    function node.update(self: Node, x: number, y: number, width: number, height: number, color: Color3, light: Color3, alpha: number, z: number, radius: number, thickness: number, rotation: number, trail: boolean | number, solid: boolean?)
        local shadow = self.shadow
        place(object, shadow, x, y, width, height)
        layer(object, shadow, z)
        rounded(object, shadow, radius)
        if shadow.thickness ~= thickness then
            shadow.thickness = thickness
            stroke.Thickness = thickness
        end
        local transparency = math.floor((1 - alpha) * 500 + 0.5) / 500
        if shadow.alpha ~= transparency then
            shadow.alpha = transparency
            stroke.Transparency = transparency
        end
        local flat = solid == true
        if shadow.solid ~= flat then
            shadow.solid = flat
            shadow.color, shadow.paint = nil, nil
            gradient.Enabled = not flat
            if not flat then
                stroke.Color = Color3.new(1, 1, 1)
            end
        end
        if flat then
            if shadow.paint ~= color then
                shadow.paint = color
                stroke.Color = color
            end
            return
        end
        local weight = if trail == true then 1 elseif type(trail) == "number" then math.clamp(math.round(trail * 50) / 50, 0, 1) else 0
        if shadow.color ~= color or shadow.light ~= light or shadow.trail ~= weight then
            shadow.color, shadow.light, shadow.trail = color, light, weight
            local colors, alphas = trailSequences(color, light, weight)
            gradient.Color = colors
            gradient.Transparency = alphas
        end
        local turn = if weight > 0 then rotation else 0
        if shadow.rotation ~= turn then
            shadow.rotation = turn
            gradient.Rotation = turn
        end
    end
    return track(node)
end

function Draw.text(): Node
    local object = Instance.new("TextLabel")
    object.BackgroundTransparency = 1
    object.BorderSizePixel = 0
    object.TextXAlignment = Enum.TextXAlignment.Left
    object.TextYAlignment = Enum.TextYAlignment.Center
    object.TextWrapped = false
    object.RichText = false
    object.Text = ""
    object.Visible = false
    object.Parent = ensureRoot()
    local node: any = { kind = "text", object = object, shown = false, shadow = {} }
    node.show, node.remove = show, remove
    function node.update(self: Node, text: string, x: number, y: number, width: number, height: number, size: number, color: Color3, alpha: number, z: number, font: number)
        local shadow = self.shadow
        if shadow.text ~= text then
            shadow.text = text
            object.Text = text
        end
        if shadow.size ~= size then
            shadow.size = size
            object.TextSize = size
        end
        if shadow.font ~= font then
            shadow.font = font
            object.Font = Fonts.enum(font)
        end
        if shadow.color ~= color then
            shadow.color = color
            object.TextColor3 = color
        end
        local transparency = math.floor((1 - alpha) * 500 + 0.5) / 500
        if shadow.alpha ~= transparency then
            shadow.alpha = transparency
            object.TextTransparency = transparency
        end
        place(object, shadow, x, y, width, height)
        layer(object, shadow, z)
    end
    return track(node)
end

function Draw.image(): Node
    local object = Instance.new("ImageLabel")
    object.BackgroundTransparency = 1
    object.BorderSizePixel = 0
    object.ScaleType = Enum.ScaleType.Crop
    object.Visible = false
    object.Parent = ensureRoot()
    local node: any = { kind = "image", object = object, shown = false, shadow = {} }
    node.show, node.remove = show, remove
    function node.update(self: Node, source: string, x: number, y: number, width: number, height: number, alpha: number, z: number, radius: number, tint: Color3?, rotation: number?)
        local shadow = self.shadow
        local turn = rotation or 0
        if shadow.rotation ~= turn then
            shadow.rotation = turn
            object.Rotation = turn
        end
        local color = tint or Color3.new(1, 1, 1)
        if shadow.tint ~= color then
            shadow.tint = color
            object.ImageColor3 = color
        end
        if shadow.source ~= source then
            shadow.source = source
            object.Image = source
        end
        local transparency = math.floor((1 - alpha) * 500 + 0.5) / 500
        if shadow.alpha ~= transparency then
            shadow.alpha = transparency
            object.ImageTransparency = transparency
        end
        place(object, shadow, x, y, width, height)
        layer(object, shadow, z)
        rounded(object, shadow, radius)
    end
    return track(node)
end

function Draw.measure(text: string, size: number, font: number): number
    local key = tostring(font) .. ":" .. tostring(size) .. ":" .. text
    local cached = widths[key]
    if cached then
        return cached
    end
    local ok, bounds = pcall(function()
        return game:GetService("TextService"):GetTextSize(text, size, Fonts.enum(font), Vector2.new(100000, 100000))
    end)
    local width = if ok and bounds then bounds.X else #text * size * 0.5
    if widthCount >= MAX_CACHED_WIDTHS then
        widths = {}
        widthCount = 0
    end
    widths[key] = width
    widthCount += 1
    return width
end

function Draw.blocker(x: number, y: number, width: number, height: number, active: boolean)
    if string.find(tostring(getgenv().OkloUISkip), "blocker", 1, true) ~= nil then
        return
    end
    if not sink then
        if not active then
            return
        end
        local button = Instance.new("TextButton")
        button.Text = ""
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.ZIndex = 1
        button.Parent = ensureRoot()
        sink = button
    end
    sink.Active = active
    sink.Visible = active
    if active then
        sink.Position = UDim2.fromOffset(x, y)
        sink.Size = UDim2.fromOffset(width, height)
    end
end

function Draw.destroyAll()
    for _, node in nodes do
        node:remove()
    end
    table.clear(nodes)
    if sink then
        pcall(function()
            sink:Destroy()
        end)
        sink = nil
    end
    if root then
        pcall(function()
            root:Destroy()
        end)
        root = nil
    end
    table.clear(widths)
    widthCount = 0
    table.clear(clipFrames)
    table.clear(clipKeys)
    clipCount, clipShown, clipFrame = 0, 0, nil
end

return Draw
end
modules["state/config"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")
local Settings: typeof(require("./settings")) = import("state/settings")
local Storage: typeof(require("../core/storage")) = import("core/storage")
local Util: typeof(require("../core/util")) = import("core/util")

local Config = {}
Config.__index = Config

type Map = { [string]: any }

export type Options = {
    Folder: string,
    Directory: string?,
    ShareId: string,
    PlaceId: number,
}

export type Loaded = {
    Colors: { [string]: Color3 },
}

function Config.new(options: Options)
    local folder = options.Folder
    return setmetatable({
        Folder = folder,
        Directory = if options.Directory and options.Directory ~= "" then folder .. "/" .. options.Directory else folder,
        ShareId = options.ShareId .. ":",
        ImportFile = folder .. "/import.txt",
        GlobalDefault = folder .. "/default_global.json",
        GameDefault = folder .. "/default_game_" .. tostring(options.PlaceId) .. ".json",
    }, Config)
end

type Self = typeof(Config.new({ Folder = "", Directory = nil, ShareId = "", PlaceId = 0 }))

function Config.path(self: Self, name: string): string
    return self.Directory .. "/" .. name .. ".json"
end

function Config.list(self: Self): { string }
    Storage.ensureFolder(self.Directory)
    local names = {}
    for _, path in Storage.list(self.Directory) do
        local name = string.match(path, "([^/\\]+)%.json$")
        if name and not string.match(name, "^default_") then
            table.insert(names, name)
        end
    end
    if #names == 0 then
        table.insert(names, "None")
    end
    return names
end

function Config.migrate(self: Self)
    if self.Directory == self.Folder then
        return
    end
    Storage.ensureFolder(self.Directory)
    for _, path in Storage.list(self.Folder) do
        local name = string.match(path, "([^/\]+)%.json$")
        if name and not string.match(name, "^default_") then
            local data = Storage.readJson(path)
            if type(data) == "table" and type(data.Flags) == "table" and not Storage.isFile(self:path(name)) then
                if Storage.writeJson(self:path(name), data) then
                    Storage.delete(path)
                end
            end
        end
    end
end

function Config.listWithNone(self: Self): { string }
    local options = self:list()
    if options[1] ~= "None" then
        table.insert(options, 1, "None")
    end
    return options
end

function Config.exists(self: Self, name: string): boolean
    return Storage.isFile(self:path(name))
end

local function encodeValue(value: any, isColor: boolean): any
    if isColor then
        return Color.toHex(value)
    elseif type(value) == "number" then
        return tostring(value)
    elseif type(value) == "boolean" then
        return if value then "true" else "false"
    end
    return value
end

local function collect(state: Map, flags: Map, definitions: { [string]: Map }): Map
    local data: Map = {}
    for _, key in Settings.PERSISTED_KEYS do
        local value = state[key]
        if value ~= nil then
            data[key] = encodeValue(value, Settings.COLOR_KEYS[key] == true)
        end
    end
    local saved: Map = {}
    for flag, definition in definitions do
        local value = flags[flag]
        if definition.save and value ~= nil then
            saved[flag] = encodeValue(value, Util.isColor(value))
        end
    end
    data.Flags = saved
    return data
end

function Config.save(self: Self, name: string, state: Map, flags: Map, definitions: { [string]: Map }): boolean
    Storage.ensureFolder(self.Directory)
    return Storage.writeJson(self:path(name), collect(state, flags, definitions))
end

function Config.share(self: Self, state: Map, flags: Map, definitions: { [string]: Map }): string
    local json = Storage.encode(collect(state, flags, definitions))
    local ok, encoded = pcall(function()
        return base64encode(json)
    end)
    if json == "" or not ok or type(encoded) ~= "string" then
        return ""
    end
    return self.ShareId .. encoded
end

local function decodeValue(value: any, current: any): any
    if Util.isColor(current) then
        if type(value) == "string" then
            return Color.fromHex(value) or current
        elseif type(value) == "table" and value.R then
            return Color3.new(value.R, value.G, value.B)
        end
        return current
    elseif type(current) == "number" then
        return tonumber(value) or current
    elseif type(current) == "boolean" then
        return value == true or value == "true"
    end
    return value
end

local function apply(data: any, state: Map, flags: Map, definitions: { [string]: Map }): Loaded?
    if type(data) ~= "table" then
        return nil
    end
    local colors: { [string]: Color3 } = {}
    for _, key in Settings.PERSISTED_KEYS do
        local value = data[key]
        if value ~= nil then
            local decoded = decodeValue(value, state[key])
            state[key] = decoded
            if Settings.COLOR_KEYS[key] then
                colors[key] = decoded
            end
        end
    end
    local saved = data.Flags
    if type(saved) == "table" then
        for flag, definition in definitions do
            local value = saved[flag]
            if definition.save and value ~= nil then
                flags[flag] = decodeValue(value, if flags[flag] ~= nil then flags[flag] else definition.default)
            end
        end
    end
    return { Colors = colors }
end

function Config.load(self: Self, name: string, state: Map, flags: Map, definitions: { [string]: Map }): Loaded?
    return apply(Storage.readJson(self:path(name)), state, flags, definitions)
end

function Config.loadCode(self: Self, text: string, state: Map, flags: Map, definitions: { [string]: Map }): Loaded?
    local code = string.match(text, "^%s*(.-)%s*$") or ""
    local prefix = self.ShareId
    if string.sub(code, 1, #prefix) ~= prefix then
        return nil
    end
    local ok, json = pcall(function()
        return base64decode(string.sub(code, #prefix + 1))
    end)
    if not ok or type(json) ~= "string" then
        return nil
    end
    return apply(Storage.decode(json), state, flags, definitions)
end

function Config.delete(self: Self, name: string, defaultName: string): boolean
    Storage.delete(self:path(name))
    if defaultName == name then
        Storage.delete(self.GlobalDefault)
        Storage.delete(self.GameDefault)
        return true
    end
    return false
end

function Config.setDefault(self: Self, name: string, scope: string)
    local onlyThisGame = scope == "This Game"
    if name == "None" or name == "" then
        Storage.delete(self.GameDefault)
        if not onlyThisGame then
            Storage.delete(self.GlobalDefault)
        end
        return
    end
    if onlyThisGame then
        Storage.writeJson(self.GameDefault, { Config = name })
    elseif Storage.writeJson(self.GlobalDefault, { Config = name }) then
        Storage.delete(self.GameDefault)
    end
end

function Config.defaultScope(self: Self): string
    return if Storage.isFile(self.GameDefault) then "This Game" else "All Games"
end

local function configNameIn(path: string): string?
    local data = Storage.readJson(path)
    if type(data) == "table" and data.Config then
        return tostring(data.Config)
    end
    return nil
end

function Config.defaultName(self: Self): string?
    if Storage.isFile(self.GameDefault) then
        return configNameIn(self.GameDefault)
    elseif Storage.isFile(self.GlobalDefault) then
        return configNameIn(self.GlobalDefault)
    end
    return nil
end

function Config.clearMissingDefault(self: Self)
    Storage.delete(self.GameDefault)
    Storage.delete(self.GlobalDefault)
end

return Config
end
modules["state/settings"] = function(...)

local import: (string) -> any = ...
local Theme: typeof(require("../core/theme")) = import("core/theme")

local Settings = {}

export type State = { [string]: any }

Settings.LAYOUT_VERSION = 1
Settings.DEFAULT_ROUNDNESS = 0.46
Settings.DEFAULT_SCALE = 0.86
Settings.BASE_WIDTH = 760
Settings.BASE_HEIGHT = 460

Settings.PERSISTED_KEYS = {
    "Keybind", "OptionKeybinds",    "UITrans", "ButtonTrans", "Transparent", "LightMode", "AccentCol", "MainCol",
    "BackgroundEffect", "SnowCol", "SnowSize", "SnowSpeed", "SnowAmount", "SnowTrans",
    "UIScale", "UILayoutVersion", "HighPerformanceMode", "UIFont", "AnimationsEnabled",
    "PremiumEffects", "AnimationIntensity", "NavSide", "Roundness", "ToggleRoundness",
} :: { string }

Settings.UI_KEYS = {
    "WatermarkEnabled", "RememberTab", "LastTab", "LockPosition", "ClickSound", "ToggleNotifications", "StartHidden", "FasterLoader",
} :: { string }

Settings.COLOR_KEYS = {
    AccentCol = true,
    MainCol = true,
    SnowCol = true,
} :: { [string]: boolean }

Settings.APPEARANCE_KEYS = {
    "NavSide", "Roundness", "ToggleRoundness", "UITrans", "ButtonTrans", "Transparent", "LightMode",
    "BackgroundEffect", "SnowSize", "SnowSpeed", "SnowAmount", "SnowTrans", "UIFont",
    "PremiumEffects", "AnimationsEnabled", "AnimationIntensity", "UIScale",
} :: { string }

Settings.APPEARANCE_COLOR_KEYS = { "AccentCol", "MainCol", "SnowCol" } :: { string }

function Settings.defaultScale(): number
    return math.max(0.10, tonumber(getgenv().OkloUIScale) or Settings.DEFAULT_SCALE)
end

function Settings.create(): State
    return {
        Keybind = "RightShift",
        OptionKeybinds = {},

        UITrans = 1,
        ButtonTrans = 1,
        Transparent = false,
        LightMode = false,
        UIScale = Settings.defaultScale(),
        UILayoutVersion = Settings.LAYOUT_VERSION,
        AccentCol = Theme.Accent,
        MainCol = Theme.BgBase,

        BackgroundEffect = "Random",
        SnowCol = Color3.new(1, 1, 1),
        SnowSize = 2,
        SnowSpeed = 20,
        SnowAmount = 40,
        SnowTrans = 0.4,

        UIFont = "1",
        HighPerformanceMode = false,
        AnimationsEnabled = true,
        PremiumEffects = true,
        AnimationIntensity = 1.0,
        NavSide = "Left",
        Roundness = Settings.DEFAULT_ROUNDNESS,
        ToggleRoundness = 0.55,

        WatermarkEnabled = true,
        RememberTab = false,
        LastTab = "",
        LockPosition = false,
        ClickSound = false,
        ToggleNotifications = true,
        StartHidden = false,
        FasterLoader = false,

        ConfigName = "",
        SelectedConfig = "None",
        DefaultConfigName = "None",
        AutoLoadScope = "All Games",
        ShareNote = "",
    }
end

return Settings
end
modules["ui/birdsheet"] = function(...)

local import: (string) -> any = ...
local Painter: typeof(require("./painter")) = import("ui/painter")
local Storage: typeof(require("../core/storage")) = import("core/storage")

local BirdSheet = {}

local COLS, ROWS = 4, 4
local PER_SHEET = COLS * ROWS
local FPS = 30
local DRAW_FRAMES = 58
local FOLDER = "oklo scripts/loaders/standard"
local BASE = "https://raw.githubusercontent.com/okdude42/main-scripts/main/loader/loader-assets/standard/"
local NEEDED = math.ceil(DRAW_FRAMES / PER_SHEET)

local urls: { [number]: string } = {}
local started = false
local failed = false

BirdSheet.FRAMES = DRAW_FRAMES

local function fetch(url: string): string?
    local ok, response = pcall(function()
        return request({ Url = url, Method = "GET" })
    end)
    if not ok or type(response) ~= "table" then
        return nil
    end
    local status = tonumber(response.StatusCode) or 0
    if status ~= 0 and (status < 200 or status >= 400) then
        return nil
    end
    local body = response.Body
    if type(body) == "string" and string.sub(body, 2, 4) == "PNG" then
        return body
    end
    return nil
end

function BirdSheet.start()
    if started or type(getcustomasset) ~= "function" or type(request) ~= "function" then
        return
    end
    started = true
    task.spawn(function()
        for _, path in { "oklo scripts", "oklo scripts/loaders", FOLDER } do
            if not Storage.ensureFolder(path) then
                failed = true
                return
            end
        end
        for number = 1, NEEDED do
            local path = FOLDER .. "/loader-bird-" .. number .. ".png"
            if not Storage.isFile(path) then
                local body: string? = nil
                for attempt = 1, 4 do
                    body = fetch(BASE .. "loader-bird-" .. number .. ".png")
                    if body then
                        break
                    end
                    task.wait(attempt)
                end
                if not body or not Storage.write(path, body) then
                    failed = true
                    return
                end
            end
            local ok, asset = pcall(getcustomasset, path)
            if not ok or type(asset) ~= "string" or asset == "" then
                failed = true
                return
            end
            pcall(function()
                game:GetService("ContentProvider"):PreloadAsync({ asset })
            end)
            urls[number] = asset
        end
    end)
end

function BirdSheet.ready(): boolean
    return not failed and #urls >= NEEDED
end

function BirdSheet.draw(frame: number, position: Vector2, side: number, alpha: number, zIndex: number, tint: Color3?)
    local index = math.clamp(math.floor(frame), 0, DRAW_FRAMES - 1)
    local sheet = index // PER_SHEET + 1
    local url = urls[sheet]
    if not url or side < 2 then
        return
    end
    local slot = index % PER_SHEET
    local outerAt, outerSize
    local ox, oy, ow, oh = Painter.clipBox()
    if ox and oy and ow and oh then
        outerAt, outerSize = Vector2.new(ox, oy), Vector2.new(ow, oh)
    end
    local inner = Painter.active()
    Painter.scope("bird:sheet:" .. sheet)
    local left, top = position.X, position.Y
    local right, bottom = left + side, top + side
    if outerAt and outerSize then
        left, top = math.max(left, outerAt.X), math.max(top, outerAt.Y)
        right, bottom = math.min(right, outerAt.X + outerSize.X), math.min(bottom, outerAt.Y + outerSize.Y)
    end
    if right > left and bottom > top then
        Painter.clip(Vector2.new(left, top), Vector2.new(right - left, bottom - top))
        Painter.image(url, position - Vector2.new((slot % COLS) * side, (slot // COLS) * side), Vector2.new(side * COLS, side * ROWS), alpha, zIndex, 0, tint)
    end
    if outerAt and outerSize then
        Painter.clip(outerAt, outerSize)
    else
        Painter.unclip()
    end
    Painter.scope(inner)
end

return BirdSheet
end
modules["ui/builder"] = function(...)

local import: (string) -> any = ...
local Controls: typeof(require("./controls")) = import("ui/controls")

local Builder = {}

type Map = { [string]: any }

local Section = {}
Section.__index = Section

local Tab = {}
Tab.__index = Tab

local CONTROL_TYPES = { "Toggle", "Slider", "Button", "Dropdown", "Color", "Input", "BindRow", "Custom" }

local function describe(kind: string, options: Map): Map
    local descriptor = table.clone(options)
    descriptor.Type = kind
    return descriptor
end

function Section.add(self: Map, descriptor: Map): Map
    local spec = Controls.compile(self.Window, descriptor, self.TabSpec)
    table.insert(self.Spec.rows, spec)
    return self
end

function Section.pair(self: Map, left: Map, right: Map): Map
    local row = {
        kind = "pair",
        left = Controls.compile(self.Window, left, self.TabSpec),
        right = Controls.compile(self.Window, right, self.TabSpec),
        bottom = left.Bottom or right.Bottom,
        noStack = left.NoStack == true or right.NoStack == true,
    }
    table.insert(self.Spec.rows, row)
    return self
end

function Section.label(self: Map, text: any): Map
    local descriptor = if type(text) == "table" then describe("Label", text) else { Type = "Label", Text = text }
    return self:add(descriptor)
end

for _, kind in CONTROL_TYPES do
    Section[string.lower(kind)] = function(self: Map, options: Map): Map
        return self:add(describe(kind, options))
    end
end

function Tab.section(self: Map, title: string): Map
    local spec = { title = title, rows = {} }
    table.insert(self.Spec.sections, spec)
    return setmetatable({ Window = self.Window, TabSpec = self.Spec, Spec = spec }, Section) :: any
end

function Tab.main(self: Map): Map
    if not self.Default then
        self.Default = self:section(string.upper(self.Spec.label))
    end
    return self.Default
end

function Tab.add(self: Map, descriptor: Map): Map
    self:main():add(descriptor)
    return self
end

function Tab.pair(self: Map, left: Map, right: Map): Map
    self:main():pair(left, right)
    return self
end

function Tab.label(self: Map, text: any): Map
    self:main():label(text)
    return self
end

for _, kind in CONTROL_TYPES do
    Tab[string.lower(kind)] = function(self: Map, options: Map): Map
        self:main():add(describe(kind, options))
        return self
    end
end

function Builder.newTab(window: Map, name: string, options: Map?): Map
    local settings: Map = options or {}
    local label = tostring(settings.Label or name)
    local group = tostring(settings.Group or "Main")
    local spec = window:addTab(name, label, group)
    spec.gate = settings.Gate
    spec.meteors = settings.Meteors == true
    spec.late = settings.Late == true
    spec.ownSearch = settings.OwnSearch == true
    spec.noun = settings.Noun
    return setmetatable({ Window = window, Spec = spec }, Tab) :: any
end

return Builder
end
modules["ui/chrome"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")
local Discord: typeof(require("./discord")) = import("ui/discord")
local Effects: typeof(require("./effects")) = import("ui/effects")
local Farm: typeof(require("./farm")) = import("ui/farm")
local Fonts: typeof(require("./fonts")) = import("ui/fonts")
local Hits: typeof(require("./hits")) = import("ui/hits")
local Layout: typeof(require("./layout")) = import("ui/layout")
local Logo: typeof(require("./logo")) = import("ui/logo")
local Motion: typeof(require("./motion")) = import("ui/motion")
local Kit: typeof(require("./popups/kit")) = import("ui/popups/kit")
local Painter: typeof(require("./painter")) = import("ui/painter")
local Press: typeof(require("./press")) = import("ui/press")
local Sky: typeof(require("./sky")) = import("ui/sky")
local Skyfx: typeof(require("./skyfx")) = import("ui/skyfx")

local Chrome = {}

type App = { [string]: any }

local SHADOW_LAYERS = 12
local Z_FRAME, Z_CARD, Z_NAV, Z_NAV_TEXT = 1, 2, 4, 6
local MARGIN = 8
local BADGE_COMPACT = 46

local WINDOW_ROUNDING, CARD_ROUNDING, PANEL_ROUNDING = 36, 36, 34
local CHIP_HEIGHT = 24
local FOOTER_HEIGHT = 34
local PANEL_PAD = 8
local CHIPS_Y = 52
local PANEL_GLIDE = 11

local SPACE_XS, SPACE_S, SPACE_M, SPACE_L = 4, 8, 12, 16
local ROW_HEIGHT = 28
local ROW_GAP = 2
local ROW_ROUND = 6
local HEADER_HEIGHT = 24
local NAV_TOP = 60
local TOOLBAR_Y, TOOLBAR_BUTTON = 14, 26
local CHEVRON_WIDTH = 24
local TITLE_SHIFT = CHEVRON_WIDTH * 2 + SPACE_XS + SPACE_M
local SEARCH_KEY = "head:search"
local SEARCH_WIDTH = 176
local SEARCH_GLYPH = 4.6
local FROST_GLOWS = 3
local WELL_SEEN = 0.85
local SIDE_SEEN = 0.5

export type Metrics = {
    Width: number,
    Height: number,
    SidebarWidth: number,
    NoSidebar: boolean,
}

function Chrome.metrics(options: { [string]: any }?): Metrics
    local given: { [string]: any } = options or {}
    local function pick(value: any, default: number, low: number, high: number): number
        return math.clamp(tonumber(value) or default, low, high)
    end
    local width = pick(given.Width, 760, 360, 1400)
    local height = pick(given.Height, 460, 300, 900)
    local none = given.NoSidebar == true
    local sidebar = if none then 0 else pick(given.SidebarWidth, 176, 110, math.min(300, width / 2.5))
    return { Width = width, Height = height, SidebarWidth = sidebar, NoSidebar = none }
end

local function ease(app: App, key: string, goal: number, speed: number): number
    local value = Motion.ease(app.State, app.NavAnim[key] or goal, goal, app.Dt, speed)
    app.NavAnim[key] = value
    return value
end

local function fitBrand(text: string, size: number, limit: number): (string, number)
    if #text * size * 0.6 <= limit then
        return text, size
    end
    local width = Painter.textWidth(text, size)
    if width <= limit then
        return text, size
    end
    local smaller = math.max(math.ceil(size * 0.6), math.floor(size * limit / width))
    if Painter.textWidth(text, smaller) <= limit then
        return text, smaller
    end
    local cut = #text
    while cut > 1 and Painter.textWidth(string.sub(text, 1, cut) .. "..", smaller) > limit do
        cut -= 1
    end
    return string.sub(text, 1, cut) .. "..", smaller
end

local function cutFooter(text: string?, size: number, limit: number): string
    local value = text or ""
    if limit <= 0 or #value * size * 0.3 <= limit or Painter.textWidth(value, size) <= limit then
        return value
    end
    local cut = #value
    while cut > 1 and Painter.textWidth(string.sub(value, 1, cut) .. "..", size) > limit do
        cut -= 1
    end
    return string.sub(value, 1, cut) .. ".."
end

local function geometry(app: App): (number, number, number, number)
    local m: Metrics = app.M
    local width = m.SidebarWidth
    local right = app.NavAnim["navside"]
    if type(right) ~= "number" then
        right = if app.State.NavSide == "Right" then 1 else 0
    end
    local sidebar = MARGIN + (m.Width - width - MARGIN) * right
    local content = (width + MARGIN) + (MARGIN - width - MARGIN) * right
    return sidebar, width - MARGIN, content, m.Width - width - MARGIN * 2
end

local function drawShadows(app: App, position: Vector2, size: Vector2)
    local shown: number = app.Alpha.UI
    if app.State.HighPerformanceMode or shown <= 0.01 then
        return
    end
    local rounding = math.max(12, math.round(WINDOW_ROUNDING * app.Scale))
    local pick = app.Pal.Pick
    for layer = 1, SHADOW_LAYERS do
        local spread = layer * (1.5 + 1.5 * pick)
        local alpha = (0.08 - 0.08 * pick) * (1 - layer / SHADOW_LAYERS) * shown
        Painter.rect(
            position - app:size(spread, spread) + app:size(0, 3 + 7 * pick),
            size + app:size(spread * 2, spread * 2),
            Color3.new(0, 0, 0),
            alpha,
            0,
            rounding + spread * 2
        )
    end
end

local function spring(app: App, key: string, goal: number, response: number, ratio: number): number
    return Motion.spring(app.State, app.Springs, key, goal, app.Dt, response, ratio)
end

local function slidingPill(app: App, name: string, x: number, y: number, w: number, h: number, alpha: number, offset: number, lead: number)
    if alpha <= 0.01 then
        return
    end
    local pal = app.Pal
    local py, speed = y, math.abs(lead) * 13
    local stretch = 1 + math.min(speed / 3200, 0.22)
    local ph = h * stretch
    local pos = app:pos(x, py - (ph - h) / 2 - offset)
    local size = app:size(w, ph)
    local outer = Painter.active()
    Painter.scope("pill:" .. name)
    Painter.rect(pos, size, Color.lerp(pal.Panel, pal.Accent, math.max(0.20, pal.Pick)), app.Alpha.Btn * alpha, Z_NAV, 18 - 5 * pal.Pick)
    Painter.scope(outer)
end

local function boldFace(): number?
    return if Painter.font() == Fonts.DEFAULT then Fonts.find("Gotham Bold") else nil
end

local function strip(app: App): (number, number)
    local right = app.NavAnim["navside"]
    if type(right) ~= "number" then
        right = if app.State.NavSide == "Right" then 1 else 0
    end
    return (app.M.Width - app.M.SidebarWidth) * right, app.M.SidebarWidth
end

local function halo(app: App, key: string, position: Vector2, size: Vector2, rounding: number, level: number)
    local pal = app.Pal
    local pulse = ease(app, key .. ":halo", 0, 3.2 * Motion.speed(app.State))
    local unit = app.Unit
    local alpha = app.Alpha.Btn * 0.5 * (0.4 + 0.6 * pal.Pick)
    local spill = Vector2.new(SPACE_M * unit, SPACE_M * unit)
    Painter.image(Skyfx.glow() or "", position - spill + Vector2.new(0, 3 * unit), size + spill * 2, alpha * level * (1 - pal.Pick), Z_NAV - 1, 0, pal.Accent)
    Painter.border(position, size, rounding * Painter.corner(), pal.Accent, alpha * pulse * 0, Z_NAV + 2, 1.5)
end

local function haloKick(app: App, key: string)
    app.NavAnim[key .. ":halo"] = 1
end

local function arrowHead(tip: Vector2, upper: Vector2, lower: Vector2, color: Color3, alpha: number, thickness: number)
    local half = Vector2.new(thickness / 2, thickness / 2)
    local size = Vector2.new(thickness, thickness)
    for _, far in { upper, lower } do
        local delta = far - tip
        local steps = math.max(2, math.ceil(delta.Magnitude / (thickness * 0.3)))
        for step = 0, steps do
            Painter.rect(tip + delta * (step / steps) - half, size, color, alpha, Z_NAV_TEXT, thickness / 2, true)
        end
    end
end

local function arrowIcon(app: App, middle: Vector2, pixels: number, degrees: number, color: Color3, alpha: number): boolean
    local asset, size = Logo.icon(app, "chevron", pixels)
    if not asset then
        return false
    end
    local corner = Vector2.new(math.floor(middle.X - size / 2 + 0.5), math.floor(middle.Y - size / 2 + 0.5))
    Painter.image(asset, corner, Vector2.new(size, size), alpha, Z_NAV_TEXT, 0, color, degrees)
    return true
end

local function folderGlyph(app: App, left: number, middle: number, color: Color3, alpha: number)
    local unit = app.Unit
    local width, height = math.floor(15 * unit + 0.5), math.floor(11 * unit + 0.5)
    local x = math.floor(left + 0.5)
    local y = math.floor(middle - height / 2 + unit + 0.5)
    Painter.border(Vector2.new(x, y), Vector2.new(width, height), 2.5 * unit, color, alpha, Z_NAV_TEXT, 1.2)
    Painter.rect(Vector2.new(x, y - math.floor(2 * unit + 0.5)), Vector2.new(math.floor(6 * unit + 0.5), math.floor(3 * unit + 0.5)), color, alpha, Z_NAV_TEXT, 1.5 * unit, true)
end

local function slidersGlyph(app: App, left: number, middle: number, color: Color3, alpha: number)
    local unit = app.Unit
    local width = math.floor(15 * unit + 0.5)
    local x = math.floor(left + 0.5)
    local line = math.max(1, math.floor(1.4 * unit + 0.5))
    local knob = math.floor(4 * unit + 0.5)
    for index, at in { 0.28, 0.72 } do
        local y = math.floor(middle - 5.5 * unit + at * 11 * unit + 0.5) - math.max(1, math.floor(unit + 0.5))
        Painter.rect(Vector2.new(x, y - math.floor(line / 2)), Vector2.new(width, line), color, alpha * 0.85, Z_NAV_TEXT, 0, true)
        local kx = x + math.floor((if index == 1 then 0.62 else 0.28) * (width - knob) + 0.5)
        Painter.rect(Vector2.new(kx, y - math.floor(knob / 2)), Vector2.new(knob, knob), color, alpha, Z_NAV_TEXT, knob / 2, true)
    end
end

local function fileGlyph(app: App, left: number, middle: number, color: Color3, alpha: number)
    local unit = app.Unit
    local width, height = math.floor(11 * unit + 0.5), math.floor(14 * unit + 0.5)
    local x = math.floor(left + 2 * unit + 0.5)
    local y = math.floor(middle - height / 2 + 0.5)
    Painter.border(Vector2.new(x, y), Vector2.new(width, height), 2.5 * unit, color, alpha, Z_NAV_TEXT, 1.2)
    for line = 1, 2 do
        Painter.rect(Vector2.new(x + math.floor(2.5 * unit + 0.5), y + math.floor((4 + line * 3) * unit + 0.5)), Vector2.new(math.floor(6 * unit + 0.5), math.max(1, math.floor(unit + 0.5))), color, alpha * 0.8, Z_NAV_TEXT, 0, true)
    end
end

local function finderRow(app: App, key: string, x: number, y: number, w: number, label: string, active: boolean, alpha: number, onClick: (() -> ())?, style: string?, open: number?)
    local pal = app.Pal
    local outer = Painter.active()
    Painter.scope(key)
    local hovered = app.HoverKey == key and not app.Modal and onClick ~= nil
    local hover = ease(app, key, if hovered then 1 else 0, 14 * Motion.speed(app.State))
    local lit = ease(app, key .. ":lit", if active then 1 else 0, 12 * Motion.speed(app.State))
    local pillAt = app.NavAnim.pillScreenY
    if style ~= "folder" and pillAt then
        lit = math.clamp(1 - math.abs(y - pillAt) / (ROW_HEIGHT * 0.85), 0, 1) * (app.NavAnim.pillAlpha or 1)
    end
    local scale = Press.scale(app, app.Springs, key .. ":press", key, hovered)
    local full = app:size(w, ROW_HEIGHT)
    local boxSize = full * scale
    local position = app:pos(x, y) + (full - boxSize) / 2
    halo(app, key, position, boxSize, ROW_ROUND * app.Unit, alpha * (0.14 * hover * (1 - lit)))
    Painter.rect(position, boxSize, pal.Text, app.Alpha.Btn * alpha * hover * (1 - lit) * 0.07, Z_NAV, ROW_ROUND * app.Unit, true)
    local iconColor = Color.lerp(Color.lerp(pal.Sub, pal.Text, hover), pal.AccentText, lit)
    local unfold = math.clamp(open or 0, 0, 1)
    if style == "folder" then
        iconColor = Color.lerp(Color.lerp(pal.Sub, pal.Text, hover), pal.Text, unfold)
    end
    local lift = 0
    local lead = 0
    if style == "folder" or style == "root" then
        lead = 14
    end
    if style == "folder" then
        local turn = math.rad(90 * math.clamp(open or 0, 0, 1))
        local dir = Vector2.new(math.cos(turn), math.sin(turn))
        local side = Vector2.new(-dir.Y, dir.X)
        local unit = app.Unit * scale
        local thickness = math.max(2, 2.2 * unit)
        local reachX, reachY = 3.8 * unit, 4.6 * unit
        local middle = Vector2.new(position.X + (SPACE_S + 1) * unit, position.Y + boxSize.Y / 2)
        local tip = middle + dir * reachX * 0.5
        local upper, lower = tip - dir * reachX - side * reachY, tip - dir * reachX + side * reachY
        local shown = app.Alpha.Text * alpha * 0.9
        if not arrowIcon(app, middle, math.floor(13 * unit + 0.5), 90 * math.clamp(open or 0, 0, 1), iconColor, shown) then
            arrowHead(tip, upper, lower, iconColor, shown, thickness)
        end
    end
    if style == "file" then
        fileGlyph(app, position.X + SPACE_S * app.Unit * scale, position.Y + boxSize.Y / 2 - lift, iconColor, app.Alpha.Text * alpha)
    elseif label == "Settings" and style == "folder" then
        slidersGlyph(app, position.X + (SPACE_S + lead) * app.Unit * scale, position.Y + boxSize.Y / 2 - lift, iconColor, app.Alpha.Text * alpha)
    else
        folderGlyph(app, position.X + (SPACE_S + lead) * app.Unit * scale, position.Y + boxSize.Y / 2 - lift, iconColor, app.Alpha.Text * alpha)
    end
    local indent = SPACE_S + 15 + SPACE_S + lead
    local shown, size = fitBrand(label, 12.5 * app.TextScale, (w - indent - SPACE_S) * app.Unit)
    Painter.text(shown, position + Vector2.new(indent * app.Unit * scale, boxSize.Y / 2), size, if style == "folder" then Color.lerp(Color.lerp(pal.Sub, pal.Text, 0.6), pal.Text, math.max(unfold, hover)) else Color.lerp(pal.Text, pal.AccentText, lit), app.Alpha.Text * alpha, Z_NAV_TEXT, false, true)
    Painter.scope(outer)
    if onClick and not app.Modal and alpha > 0.5 then
        Hits.add({ key = key, position = app:pos(x, y), size = full, click = function()
            haloKick(app, key)
            onClick()
        end })
    end
end

local function finderHeader(app: App, key: string, x: number, y: number, w: number, label: string, alpha: number, onClick: (() -> ())?)
    local pal = app.Pal
    local outer = Painter.active()
    Painter.scope(key)
    local hovered = app.HoverKey == key and not app.Modal and onClick ~= nil
    local hover = ease(app, key, if hovered then 1 else 0, 14 * Motion.speed(app.State))
    Painter.text(label, app:pos(x + SPACE_S, y + HEADER_HEIGHT - 9), 10.5 * app.TextScale, Color.lerp(pal.Sub, pal.Text, hover), app.Alpha.Text * alpha * 0.85, Z_NAV_TEXT, false, true, boldFace())
    Painter.scope(outer)
    if onClick and not app.Modal and alpha > 0.5 then
        Hits.add({ key = key, position = app:pos(x, y), size = app:size(w, HEADER_HEIGHT), click = onClick })
    end
end

local function finderNav(app: App, _sx: number, _sw: number, reveal: number, side: number): number
    local m: Metrics = app.M
    local state = app.State
    local pal = app.Pal
    local current = state.NextTab or state.CurrentTab
    local activeGroup: string = app.TabGroup[current]
    local left, width = strip(app)
    local x, w = left + SPACE_M, width - SPACE_M * 2
    local bottom = m.Height - MARGIN - 48 - (if Farm.available(app) then 32 else 0)
    local needed = NAV_TOP
    for _, group in app.NavGroups do
        if #group.Tabs > 1 then
            needed += ROW_HEIGHT + ROW_GAP + (if group.Name == activeGroup or group.Name == "Settings" then #group.Tabs * (ROW_HEIGHT + ROW_GAP) else 0) + SPACE_XS
        else
            needed += ROW_HEIGHT + ROW_GAP
        end
    end
    local reach = math.max(0, needed - bottom + SPACE_XS)
    local overflow = ease(app, "nav:overflow", reach, 9 * Motion.speed(state))
    local nav = app.NavScroll
    if not nav then
        nav = { Pos = 0, Target = 0 }
        app.NavScroll = nav
    end
    nav.Target = math.clamp(nav.Target, 0, reach)
    nav.Pos = math.clamp(Motion.ease(state, nav.Pos, nav.Target, app.Dt, 14), 0, math.max(overflow, nav.Target))
    if reach > 0 and not app.Modal then
        Hits.add({
            key = "nav:scroll",
            position = app:pos(x, NAV_TOP),
            size = app:size(w, bottom - NAV_TOP),
            wheel = function(delta: number)
                nav.Target = math.clamp(nav.Target - delta * 36, 0, reach)
            end,
        })
    end
    local function edge(at: number, height: number): number
        local top = if nav.Pos > 0.5 then at + height * 0.3 - NAV_TOP else math.huge
        return math.clamp(math.min(top, bottom - at - height * 0.7) / (height * 0.6), 0, 1)
    end
    local y = NAV_TOP - nav.Pos
    local pillY: number? = nil
    local pillIndent = 0
    for index, group in app.NavGroups do
        local entry = math.clamp(reveal * 1.5 - (index - 1) * 0.12, 0, 1)
        local shift = (1 - entry) * 14 * side
        if #group.Tabs > 1 then
            local active = group.Name == activeGroup
            local open = spring(app, "finder:group:" .. group.Name, if active or group.Name == "Settings" then 1 else 0, 0.46, 0.84)
            local first = group.Tabs[1]
            local groupTop = y
            finderRow(app, "nav:head:" .. group.Name, x + shift, y, w, group.Name, false, entry * edge(y, ROW_HEIGHT), if edge(y, ROW_HEIGHT) > 0.6 then function()
                if not active then
                    app:switchTab(first)
                end
            end else nil, "folder", open)
            y += ROW_HEIGHT + ROW_GAP
            if open > 0.01 then
                local fade = math.clamp(open, 0, 1)
                fade = fade * fade * fade
                local tree = 14
                local span = #group.Tabs * (ROW_HEIGHT + ROW_GAP) * open
                local hair = math.max(1, math.floor(app.Unit + 0.5))
                local spine = app:pos(x + shift + SPACE_S + 2, y - ROW_GAP - 2)
                local spineX = math.floor(spine.X + 0.5)
                local spineFrom = math.floor(spine.Y + 0.5)
                for number, name in group.Tabs do
                    local ty = y + (number - 1) * (ROW_HEIGHT + ROW_GAP) * open
                    local tabActive = current == name
                    local shown = fade * entry * edge(ty, ROW_HEIGHT)
                    local branch = app:pos(x + shift + SPACE_S + 2, ty + ROW_HEIGHT / 2)
                    local branchY = math.floor(branch.Y + 0.5)
                    Painter.rect(Vector2.new(spineX, spineFrom), Vector2.new(hair, math.max(0, branchY - spineFrom)), pal.Sub, app.Alpha.Btn * shown * 0.4, Z_NAV, 0, true)
                    spineFrom = branchY
                    Painter.rect(Vector2.new(math.floor(branch.X + 0.5), branchY), Vector2.new(math.max(hair, math.floor(app:size(tree - 6, 1).X + 0.5)), hair), pal.Sub, app.Alpha.Btn * shown * 0.4, Z_NAV, 0, true)
                    finderRow(app, "nav:tab:" .. name, x + shift + tree, ty, w - tree, app.TabByName[name].label, tabActive, shown, if open > 0.9 and edge(ty, ROW_HEIGHT) > 0.6 then function()
                        app:switchTab(name)
                    end else nil, "file")
                    if tabActive then
                        pillY = ty
                        pillIndent = tree
                    end
                end
                y += span
            end
            if group.Name == "Settings" then
                local shown = entry * math.min(edge(groupTop, ROW_HEIGHT), edge(y - ROW_HEIGHT, ROW_HEIGHT))
                Painter.scope("nav:settings:panel")
                Painter.rect(app:pos(x + shift - 3, groupTop - 3), app:size(w + 6, math.max(0, y - groupTop - ROW_GAP + 6)), pal.Text, app.Alpha.Btn * shown * 0.06, Z_CARD + 1, ROW_ROUND * app.Unit + 3, true)
                Painter.scope(nil)
            end
            y += SPACE_XS
        else
            local name = group.Tabs[1]
            local tabActive = current == name
            finderRow(app, "nav:tab:" .. name, x + shift, y, w, app.TabByName[name].label, tabActive, entry * edge(y, ROW_HEIGHT), if edge(y, ROW_HEIGHT) > 0.6 then function()
                app:switchTab(name)
            end else nil, "root")
            if tabActive then
                pillY = y
            end
            y += ROW_HEIGHT + ROW_GAP
        end
    end
    local pillShown = spring(app, "pill:finder:alpha", if pillY then edge(pillY, ROW_HEIGHT) else 0, 0.30, 1)
    local current2 = current
    if pillY then
        local target = pillY + nav.Pos
        if app.NavAnim.pillTab ~= current2 and app.NavAnim.pillLast then
            app.NavAnim.pillOff = app.NavAnim.pillLast - target
        end
        app.NavAnim.pillTab = current2
        app.NavAnim.finderTarget = target
    end
    if app.NavAnim.finderTarget then
        local off = (app.NavAnim.pillOff or 0) * math.exp(-app.Dt * 11 * Motion.speed(state))
        if math.abs(off) < 0.05 then
            off = 0
        end
        app.NavAnim.pillOff = off
        app.NavAnim.pillLast = app.NavAnim.finderTarget + off
        app.NavAnim.pillScreenY = app.NavAnim.pillLast - nav.Pos
        app.NavAnim.pillAlpha = math.clamp(pillShown, 0, 1)
        local indent = ease(app, "nav:pillIndent", if pillY then pillIndent else (app.NavAnim.finderIndent or 0), 14)
        app.NavAnim.finderIndent = if pillY then pillIndent else app.NavAnim.finderIndent
        slidingPill(app, "finder", x + indent, app.NavAnim.pillLast, w - indent, ROW_HEIGHT, math.clamp(pillShown, 0, 1) * reveal, nav.Pos, off)
    end
    local moving = if overflow > 0.5 and math.abs(nav.Target - nav.Pos) > 0.5 then 1 else 0
    local bar = ease(app, "nav:bar", moving, if moving == 1 then 20 else 3)
    if overflow > 0.5 then
        local track = bottom - NAV_TOP
        local thumb = math.max(24, track * track / (track + overflow))
        local at = NAV_TOP + (track - thumb) * math.clamp(nav.Pos / overflow, 0, 1)
        Painter.scope("nav:bar")
        Painter.rect(app:pos(x + w + SPACE_M - 5, at), app:size(3, thumb), pal.Sub, app.Alpha.Btn * reveal * (0.22 + 0.4 * bar), Z_NAV + 3, 2, true)
        Painter.scope(nil)
    end
    return y
end

local function drawFrost(app: App, now: number, size: Vector2, rounding: number)
    local pal = app.Pal
    local alpha = app.Alpha.UI * pal.Pick
    local m: Metrics = app.M
    local left, width = strip(app)
    local right = if m.NoSidebar then 0 else left / math.max(1, m.Width - width)
    local sideWidth = if m.NoSidebar then 0 else width
    local contentX = sideWidth * (1 - right)
    local contentW = m.Width - sideWidth
    local radius = rounding
    local sky = app.SkyFrame
    local seen = if sky and (sky.Sky ~= nil or sky.Cycle ~= nil) then math.max(sky.Flow, sky.Clear) else 0
    Painter.scope("finder:frost")
    local white = Color.lerp(pal.Main, Color3.new(1, 1, 1), if pal.Main.R < 0.5 then 0.1 else 1)
    local glow = Skyfx.glow()
    Painter.clip(app:pos(left, 0), app:size(width, m.Height))
    Painter.gradient(app:pos(left - SPACE_L * right, 0), app:size(width + SPACE_L, m.Height), { Color.lerp(pal.Main, white, 0.9), Color.lerp(pal.Main, white, 0.4) }, 90, alpha * 0.72 * (1 - SIDE_SEEN * seen) * (if m.NoSidebar then 0 else 1), Z_CARD, radius)
    Painter.fine(true)
    for index = 1, FROST_GLOWS do
        local drift = now * (0.05 + index * 0.013) + index * 2.1
        local cx = left + width * (0.5 + 0.32 * math.sin(drift) * (if index == 2 then -1 else 1))
        local cy = m.Height * (0.18 + 0.32 * (index - 1) + 0.06 * math.cos(drift * 1.3))
        local reach = width * (1.15 - 0.15 * index)
        local tint = if index == 1 then white elseif index == 2 then Color.lerp(pal.Main, pal.Accent, 0.12) else Color.lerp(white, pal.Main, 0.4)
        local strength = if index == 2 then 0.10 else 0.42
        Painter.image(glow or "", app:pos(cx - reach, cy - reach), app:size(reach * 2, reach * 2), alpha * strength * (if m.NoSidebar then 0 else 1) * 0, Z_CARD, 0, tint)
    end
    Painter.fine(app.State.UIScaleAnim < 0.999)
    Painter.unclip()
    Painter.rect(app:pos(left + width * (1 - right) - right * 1, 0), Vector2.new(math.max(1, app.Scale * 0.8), size.Y), Color.lerp(pal.Off, pal.Sub, 0.18), alpha * 0.9 * (if m.NoSidebar then 0 else 1), Z_CARD + 1, 0)
    local fill = alpha * (1 - WELL_SEEN * seen)
    local reach = if m.NoSidebar then 0 else SPACE_L * 2
    Painter.clip(app:pos(contentX, 0), app:size(contentW, m.Height))
    Painter.rect(app:pos(contentX - reach * (1 - right), 0), app:size(contentW + reach, m.Height), pal.Well, fill, Z_CARD, radius)
    Painter.unclip()
    Painter.scope(nil)
end

local function drawSidebar(app: App, now: number)
    local m: Metrics = app.M
    local state = app.State
    local pal = app.Pal
    local drop = 0
    local text = app.Alpha.Text
    local scale = math.max(app.Scale, 0.95)
    local sx, sw = geometry(app)
    local reveal = Motion.glide(if state.AnimationsEnabled then math.clamp(state.NavReveal, 0, 1) else 1)
    local side = 2 * (app.NavAnim["navside"] or (if state.NavSide == "Right" then 1 else 0)) - 1

    Painter.scope("sidebar:brand")
    local sky = app.SkyFrame
    local cover = if sky then Sky.left(1 - sky.Clear * (1 - sky.Glass), sky.Veil) else 1
    Painter.rect(app:pos(sx, MARGIN), app:size(sw, m.Height - MARGIN * 2), pal.Well, app.Alpha.UI * cover * (1 - pal.Pick), Z_CARD, CARD_ROUNDING)

    local brand = math.clamp(reveal * 1.6, 0, 1)
    local drift = Vector2.new((1 - brand) * 10 * side * app.Unit, 0)
    local options = app.Options
    local logoShown = ease(app, "logo", if app.LogoAsset then 1 else 0, 7)
    local textX = if options.Logo ~= nil then 50 else 46
    local logoSize = 36
    Painter.text(string.lower(string.sub(options.Title, 1, 1)), app:pos(sx + 26, 36 + drop) + drift, 27 * scale, pal.Text, text * brand * (1 - logoShown), 5, true, true)
    if app.LogoAsset then
        local emblem = options.Logo ~= nil and options.Logo.Emblem == true
        local logoAt = app:pos(sx + 8, 18 + drop) + drift
        if emblem then
            Painter.image(app.LogoAsset, logoAt, app:size(logoSize, logoSize), text * brand * logoShown, 6, 0, pal.Accent)
        else
            Painter.image(app.LogoAsset, logoAt, app:size(logoSize, logoSize), text * brand * logoShown, 5, 10 * app.Unit)
        end
    end
    local limit = (sw - textX - 8) * app.Unit
    local title, titleSize = fitBrand(options.Title, 18 * app.TextScale, limit)
    app.BrandTitleSize = titleSize
    local subtitle, subtitleSize = fitBrand(options.Subtitle, 11 * app.TextScale, limit)
    local boldTitle: number? = if options.BoldTitles then Fonts.find("Gotham Bold") else nil
    Painter.text(title, app:pos(sx + textX, 28 + drop) + drift, titleSize, pal.Text, text * brand, 4, false, true, boldTitle)
    Painter.text(subtitle, app:pos(sx + textX, 45 + drop) + drift, subtitleSize, pal.Sub, text * brand, 4, false, true)
    Painter.rect(app:pos(sx + 14, 62 + drop), app:size((sw - 28) * brand, 1), pal.Off, app.Alpha.UI * 0.8 * (1 - pal.Pick), Z_NAV, 0)
    Painter.scope(nil)

    local y = finderNav(app, sx, sw, reveal, side)

    local panel = app.SidebarPanel
    if panel then
        local top = y + 6
        local bottom = m.Height - MARGIN - 48
        local height = bottom - top
        if height >= (panel.MinHeight or 56) then
            local width = sw - 28
            local fade = math.clamp(reveal * 1.4 - 0.3, 0, 1)
            Painter.scope("sidebar:panel")
            local kit = Kit.new(app, width, height, app:pos(sx + 14, top), app:size(width, height), app.Alpha.Text * fade)
            kit.ZControl, kit.ZText = 5, Z_NAV_TEXT
            if app.Modal then
                Hits.suspend(true)
            end
            pcall(panel.Render, kit, app)
            Painter.scope(nil)
            Hits.suspend(false)
        end
    end

    local invite = app.Options.Discord
    local inset, bh = 14 - 4 * pal.Pick, 26 + 2 * pal.Pick
    local rowY = m.Height - MARGIN * (1 - pal.Pick) - 40
    if Farm.available(app) then
        local fade = math.clamp(reveal * 1.4 - 0.3, 0, 1)
        local key = "farm:enter"
        local hovered = app.HoverKey == key and not app.Modal
        local hover = ease(app, key, if hovered then 1 else 0, 14)
        local at = app:pos(sx + inset, rowY - 32) + drift
        local boxSize = app:size(sw - inset * 2, bh)
        local base = pal.Well
        Painter.scope(key)
        Painter.border(at, boxSize, 20 * Painter.corner(), Color.lerp(pal.Off, pal.Accent, 0.35 * hover), app.Alpha.UI * fade * 0.9, Z_NAV, 1.2)
        Painter.rect(at, boxSize, base, app.Alpha.UI * fade, Z_NAV, 20)
        Painter.rect(at, boxSize, Color.lerp(base, pal.Accent, 0.12 + 0.22 * hover), app.Alpha.Btn * fade, Z_NAV, 20)
        local label = "Farm Mode"
        local labelSize = 11.5 * scale
        local cell = math.max(2, math.floor(4 * app.Unit + 0.5))
        local iconSide = cell * 2 + 1
        local gap = math.floor(6 * app.Unit + 0.5)
        local labelPixels = Painter.textWidth(label, labelSize)
        local boxX, boxY = math.floor(at.X + 0.5), math.floor(at.Y + 0.5)
        local boxW, boxH = math.floor(boxSize.X + 0.5), math.floor(boxSize.Y + 0.5)
        local left = boxX + math.floor((boxW - (iconSide + gap + labelPixels)) / 2)
        local top = boxY + math.floor((boxH - iconSide) / 2)
        local iconColor = Color.lerp(pal.Accent, Color.lighten(pal.Accent, 0.35), hover)
        for column = 0, 1 do
            for row = 0, 1 do
                Painter.rect(Vector2.new(left + column * (cell + 1), top + row * (cell + 1)), Vector2.new(cell, cell), iconColor, text * fade, 6, 1, true)
            end
        end
        local labelHeight = math.max(1, math.floor(labelSize + 0.5))
        Painter.text(label, Vector2.new(left + iconSide + gap, boxY + math.floor((boxH - labelHeight) / 2) + labelHeight / 2), labelSize, Color.lerp(pal.Sub, pal.Text, hover), text * fade, 6, false, true)
        Painter.scope(nil)
        if not app.Modal then
            Hits.add({
                key = key,
                position = app:pos(sx + inset, rowY - 32),
                size = app:size(sw - inset * 2, bh),
                click = function()
                    Farm.enter(app)
                end,
            })
        end
    end
    local badgeWidth = if invite then BADGE_COMPACT else sw - inset * 2
    local badgeSize = app:size(badgeWidth, bh)
    local badgePos = app:pos(sx + inset + (sw - inset * 2 - badgeWidth), rowY)
    if invite then
        local fade = math.clamp(reveal * 1.4 - 0.3, 0, 1)
        local key = "discord:join"
        local hovered = app.HoverKey == key and not app.Modal
        local hover = ease(app, key, if hovered then 1 else 0, 14)
        local width = sw - inset * 2 - BADGE_COMPACT - 6
        local full = app:size(width, bh)
        local shrunk = full
        local at = app:pos(sx + inset, rowY) + drift + (full - shrunk) / 2
        Painter.scope(key)
        Painter.border(at, shrunk, 20 * Painter.corner(), Color.lerp(pal.Off, pal.Accent, 0.35 * hover), app.Alpha.UI * fade * 0.9, Z_NAV, 1.2)
        Painter.rect(at, shrunk, pal.Well, app.Alpha.UI * fade, Z_NAV, 20)
        Painter.rect(at, shrunk, Color.lerp(pal.Well, pal.Accent, 0.10 + 0.20 * hover), app.Alpha.Btn * fade, Z_NAV, 20)
        local label = "Join Server"
        local iconSize = 14
        local labelSize = 11.5 * scale
        local labelWidth = Painter.textWidth(label, labelSize) / app.Unit
        local room = width - 16 - iconSize - 7
        if labelWidth > room then
            labelSize = math.max(8, labelSize * room / labelWidth)
            labelWidth = Painter.textWidth(label, labelSize) / app.Unit
        end
        local color = Color.lerp(pal.Sub, pal.Text, hover)
        local boxX, boxY = math.floor(at.X + 0.5), math.floor(at.Y + 0.5)
        local boxW, boxH = math.floor(shrunk.X + 0.5), math.floor(shrunk.Y + 0.5)
        local wantedIcon = math.floor(iconSize * app.Unit + 0.5)
        if (boxH - wantedIcon) % 2 ~= 0 then
            wantedIcon -= 1
        end
        local iconAsset, iconPixels = Logo.icon(app, "discord", wantedIcon)
        local gap = math.floor(7 * app.Unit + 0.5)
        local labelPixels = Painter.textWidth(label, labelSize)
        local left = boxX + math.floor((boxW - (iconPixels + gap + labelPixels)) / 2 + 1 * app.Unit * pal.Pick)
        if iconAsset then
            Painter.image(iconAsset, Vector2.new(left, boxY + math.floor((boxH - iconPixels) / 2) + math.max(1, math.round(app.Unit * 0.7))), Vector2.new(iconPixels, iconPixels), text * fade, 6, 0, Color.lerp(pal.Accent, Color.lighten(pal.Accent, 0.35), hover))
        end
        local labelHeight = math.max(1, math.floor(labelSize + 0.5))
        Painter.text(label, Vector2.new(left + iconPixels + gap, boxY + math.floor((boxH - labelHeight) / 2) + labelHeight / 2 - math.max(1, math.round(app.Unit * 1.2))), labelSize, color, text * fade, 6, false, true)
        Painter.scope(nil)
        if not app.Modal then
            Hits.add({
                key = key,
                position = app:pos(sx + inset, rowY),
                size = full,
                click = function()
                    app:rememberClick(app:pos(sx + inset, rowY), full, key)
                    Discord.join(invite)
                    app:openPopup("discord")
                end,
            })
        end
    end

    local pulse = 0.5 + 0.5 * math.sin(now * 1.8 * Motion.intensity(state))
    local badgeAlpha = math.clamp(reveal * 1.4 - 0.3, 0, 1)
    Painter.scope("sidebar:badge")
    Painter.rect(badgePos, badgeSize, Color.lerp(pal.Panel, pal.Accent, 0.12 + pulse * 0.04), app.Alpha.Btn * badgeAlpha, Z_NAV, math.max(3, 5 * app.Scale) + math.max(1, math.round(app.Scale)))
    Effects.badge(state, now, badgePos, badgeSize, app.Scale, text * badgeAlpha)
    local tagX, tagY = math.floor(badgePos.X + 0.5), math.floor(badgePos.Y + 0.5)
    local tagCenter = Vector2.new(tagX + math.floor(badgeSize.X + 0.5) / 2, tagY + math.floor(badgeSize.Y + 0.5) / 2)
    Painter.text("V" .. options.Version, tagCenter, 12 * scale, Color.lerp(pal.AccentText, pal.Text, pal.Pick), text * badgeAlpha, 5, true, true)
    Painter.scope(nil)
end

local function drawChips(app: App, tab: { [string]: any }, index: number, x: number, width: number, alpha: number): number
    local sections = tab.sections
    if #sections <= 1 then
        return CHIPS_Y + PANEL_PAD
    end
    local pal = app.Pal
    local cursor = x
    local places: { { number } } = {}
    for number, section in sections do
        local chipWidth = Painter.textWidth(string.upper(section.title), 11 * app.TextScale) / app.Unit + 26
        if cursor + chipWidth > x + width then
            break
        end
        places[number] = { cursor, chipWidth }
        cursor += chipWidth + 6
    end
    local outer = Painter.active()
    local active = places[index]
    Painter.scope("chip:track")
    Painter.rect(app:pos(x - 3, CHIPS_Y - 3), app:size(math.max(0, cursor - 6 - x) + 6, CHIP_HEIGHT + 6), pal.Off, app.Alpha.Btn * alpha * pal.Pick * 0.55, Z_NAV - 1, 11)
    Painter.scope(outer)
    if active then
        local px = spring(app, "chip:x", active[1], 0.36, 0.8)
        local pw = spring(app, "chip:w", active[2], 0.36, 0.8)
        local position, size = app:pos(px, CHIPS_Y), app:size(pw, CHIP_HEIGHT)
        Painter.scope("chip:active")
        Painter.rect(position, size, Color.lerp(Color.lerp(pal.Panel, pal.Accent, math.max(0.22, pal.Pick)), pal.Panel, pal.Pick), app.Alpha.Btn * alpha, Z_NAV + 1, 16 - 8 * pal.Pick)
        Painter.border(position, size, (16 - 8 * pal.Pick) * Painter.corner(), pal.Off, app.Alpha.Btn * alpha * pal.Pick, Z_NAV + 1, 1)
        Painter.scope(outer)
    end
    for number, section in sections do
        local place = places[number]
        if place then
            local label = string.upper(section.title)
            local key = "chip:" .. tab.name .. ":" .. number
            local isActive = number == index
            local position, size = app:pos(place[1], CHIPS_Y), app:size(place[2], CHIP_HEIGHT)
            local hovered = app.HoverKey == key and not app.Modal
            local hover = ease(app, key, if hovered then 1 else 0, 14 * Motion.speed(app.State))
            local lit = ease(app, key .. ":lit", if isActive then 1 else 0, 12 * Motion.speed(app.State))
            local pressed = Press.scale(app, app.Springs, key .. ":press", key, hovered)
            local chipPosition, chipSize = Press.box(position, size, pressed)
            Painter.scope(key)
            halo(app, key, chipPosition, chipSize, 14, alpha * 0.14 * hover * (1 - lit))
            Painter.rect(chipPosition, chipSize, Color.lerp(pal.Panel, pal.Accent, 0.10), app.Alpha.Btn * alpha * hover * (1 - lit), Z_NAV, 16)
            local textColor = Color.lerp(Color.lerp(pal.Sub, pal.Text, hover), Color.lerp(pal.AccentText, pal.Text, pal.Pick), lit)
            Painter.text(label, chipPosition + chipSize / 2, 11 * app.TextScale, textColor, app.Alpha.Text * alpha, Z_NAV_TEXT, true, true)
            Painter.scope(outer)
            if not app.Modal then
                Hits.add({
                    key = key,
                    position = position,
                    size = size,
                    click = function()
                        haloKick(app, key)
                        app.State.TabSlideDirection = if number >= index then 1 else -1
                        Layout.setSection(app, tab, number)
                    end,
                })
            end
        end
    end
    return CHIPS_Y + CHIP_HEIGHT + PANEL_PAD * 2
end

local function drawHeaderButtons(app: App, right: number, alpha: number)
    local pal = app.Pal
    local buttons = {}
    if app.Options.OnUnload then
        table.insert(buttons, { Key = "head:unload", Label = "U", Icon = "power", Click = function()
            app:togglePopup("confirmUnload")
        end })
    end
    if app.Options.OnReload then
        table.insert(buttons, { Key = "head:reload", Label = "R", Icon = "restart", Click = function()
            app:togglePopup("confirmReload")
        end })
    end
    local size = 26
    for index, button in buttons do
        local x = right - index * size - (index - 1) * 6
        local position, boxSize = app:pos(x, 14), app:size(size, size)
        local hovered = app.HoverKey == button.Key and not app.Modal
        local hover = ease(app, button.Key, if hovered then 1 else 0, 14 * Motion.speed(app.State))
        local shrunk = boxSize
        local moved = position
        Painter.scope(button.Key)
        Painter.rect(moved, shrunk, Color.lerp(pal.Panel, pal.Accent, math.max(0.12 + 0.22 * hover, pal.Pick * hover)), app.Alpha.Btn * alpha, Z_NAV, 12)
        local asset, pixels = nil, 0
        local cornerX, cornerY = math.floor(position.X + 0.5), math.floor(position.Y + 0.5)
        local boxPixels = math.floor(boxSize.X + 0.5)
        if button.Icon then
            local wantedGlyph = math.floor(boxPixels * 0.54 + 0.5)
            if (boxPixels - wantedGlyph) % 2 ~= 0 then
                wantedGlyph -= 1
            end
            asset, pixels = Logo.icon(app, button.Icon, wantedGlyph)
        end
        if asset then
            local offset = math.floor((boxPixels - pixels) / 2)
            Painter.image(asset, Vector2.new(cornerX + offset, cornerY + offset), Vector2.new(pixels, pixels), app.Alpha.Text * alpha, Z_NAV_TEXT, 0, Color.lerp(pal.Accent, Color.lighten(pal.Accent, 0.35), hover))
        else
            Painter.text(button.Label, moved + shrunk / 2, 12 * app.TextScale, Color.lerp(pal.Text, pal.AccentText, hover), app.Alpha.Text * alpha, Z_NAV_TEXT, true, true)
        end
        Painter.scope(nil)
        if not app.Modal then
            Hits.add({
                key = button.Key,
                position = position,
                size = boxSize,
                click = function()
                    app:rememberClick(position, boxSize, button.Key)
                    button.Click()
                end,
            })
        end
    end
end

local function trackHistory(app: App)
    local current = app.State.NextTab or app.State.CurrentTab
    local history: { string } = app.NavHistory
    if not history then
        app.NavHistory = { current }
        app.NavIndex = 1
        return
    end
    if history[app.NavIndex] == current then
        return
    end
    for index = #history, app.NavIndex + 1, -1 do
        table.remove(history, index)
    end
    table.insert(history, current)
    if #history > 32 then
        table.remove(history, 1)
    end
    app.NavIndex = #history
end

local function stepHistory(app: App, step: number)
    local target = app.NavIndex + step
    local name = app.NavHistory[target]
    if name and app.TabByName[name] then
        app.NavIndex = target
        app:switchTab(name)
    end
end

local function chevron(app: App, key: string, x: number, direction: number, enabled: boolean, alpha: number, onClick: () -> ())
    local pal = app.Pal
    local hovered = app.HoverKey == key and not app.Modal and enabled
    local hover = ease(app, key, if hovered then 1 else 0, 14 * Motion.speed(app.State))
    local ready = ease(app, key .. ":ready", if enabled then 1 else 0, 10 * Motion.speed(app.State))
    local lean = spring(app, key .. ":lean", if hovered then 1 else 0, 0.34, 0.5)
    local scale = Press.scale(app, app.Springs, key .. ":press", key, hovered)
    local full = app:size(CHEVRON_WIDTH, TOOLBAR_BUTTON)
    local boxSize = full * scale
    local position = app:pos(x, TOOLBAR_Y) + (full - boxSize) / 2
    Painter.scope(key)
    halo(app, key, position, boxSize, ROW_ROUND * app.Unit, alpha * 0.14 * hover)
    Painter.rect(position, boxSize, pal.Text, app.Alpha.Btn * alpha * hover * 0.07, Z_NAV, ROW_ROUND * app.Unit, true)
    local unit = app.Unit * scale
    local tip = position + boxSize / 2 + Vector2.new(direction * 1.5 * lean * unit, 0)
    local color = Color.lerp(pal.Sub, pal.Text, hover)
    local shown = app.Alpha.Text * alpha * (0.3 + 0.7 * ready)
    local thickness = math.max(2, 2.4 * unit)
    local reachX, reachY = 4.6 * unit, 5.6 * unit
    tip = tip + Vector2.new(direction * reachX * 0.5, 0)
    local upper, lower = tip + Vector2.new(-direction * reachX, -reachY), tip + Vector2.new(-direction * reachX, reachY)
    if not arrowIcon(app, tip - Vector2.new(direction * reachX * 0.5, 0), math.floor(17 * unit + 0.5), if direction < 0 then 180 else 0, color, shown) then
        arrowHead(tip, upper, lower, color, shown, thickness)
    end
    Painter.scope(nil)
    if enabled and not app.Modal and alpha > 0.5 then
        Hits.add({ key = key, position = app:pos(x, TOOLBAR_Y), size = full, click = function()
            haloKick(app, key)
            onClick()
        end })
    end
end

local function searchQuery(app: App): string
    if app.Focus == SEARCH_KEY then
        return app.Buffers[SEARCH_KEY] or ""
    end
    return app.SearchQuery or ""
end

function Chrome.query(app: App): string
    if app.Pal.Pick <= 0.5 then
        return ""
    end
    return string.lower(searchQuery(app))
end

function Chrome.clearSearch(app: App)
    app.SearchQuery = ""
    app.Buffers[SEARCH_KEY] = ""
    if app.Focus == SEARCH_KEY then
        app.Focus = nil
    end
end

local function focusSearch(app: App, text: string)
    app:beginInput(SEARCH_KEY, text, {
        maxLength = 40,
        commit = function(value: string)
            app.SearchQuery = value
        end,
    })
end

local function drawSearch(app: App, right: number, alpha: number)
    local pal = app.Pal
    local state = app.State
    local focused = app.Focus == SEARCH_KEY
    local query = searchQuery(app)
    if focused then
        app.SearchQuery = query
    end
    if focused and not app.SearchFocused and os.clock() - (app.SearchBlurAt or 0) > 0.2 then
        app.NavAnim["search:pulse"] = 1
    end
    if app.SearchFocused and not focused then
        app.SearchBlurAt = os.clock()
    end
    app.SearchFocused = focused
    if #query ~= (app.SearchLength or 0) then
        app.NavAnim["search:tick"] = 1
        app.SearchLength = #query
    end
    local speed = Motion.speed(state)
    local pulse = ease(app, "search:pulse", 0, 3.2 * speed)
    local tick = ease(app, "search:tick", 0, 9 * speed)
    local key = SEARCH_KEY
    local hovered = app.HoverKey == key and not app.Modal
    local hover = ease(app, key, if hovered then 1 else 0, 14 * speed)
    local wobble = spring(app, "search:wobble", if hovered and not focused and query == "" then 1 else 0, 0.36, 0.42)
    local open = spring(app, "search:open", if focused or query ~= "" then 1 else 0, 0.5, 0.66)
    local ring = math.clamp(spring(app, "search:ring", if focused then 1 else 0, 0.3, 0.8), 0, 1)
    local grown = math.clamp(open, 0, 1)
    local width = math.max(TOOLBAR_BUTTON - SPACE_XS, TOOLBAR_BUTTON + (SEARCH_WIDTH - TOOLBAR_BUTTON) * open)
    local press = Press.scale(app, app.Springs, key .. ":press", key, hovered and not focused)
    local unit = app.Unit
    local full = app:size(width, TOOLBAR_BUTTON)
    local boxSize = full * press
    local position = app:pos(right - width, TOOLBAR_Y) + (full - boxSize) / 2
    local corner = 12 * Painter.corner()
    Painter.scope(key)
    local glow = Skyfx.glow()
    local spill = app:size(SPACE_L, SPACE_L)
    Painter.image(glow or "", position - spill + app:size(0, 3), boxSize + spill * 2, app.Alpha.Btn * alpha * (0.08 * grown + 0.12 * ring), Z_NAV - 1, 0, pal.Accent)
    local reach = (1 - pulse) * SPACE_M * unit
    Painter.border(position - Vector2.new(reach, reach), boxSize + Vector2.new(reach * 2, reach * 2), corner + reach, pal.Accent, app.Alpha.Btn * alpha * 0.4 * pulse * pulse, Z_NAV, 1.5)
    local pad = 1.5 * unit
    Painter.border(position - Vector2.new(pad, pad), boxSize + Vector2.new(pad * 2, pad * 2), corner + pad, pal.Accent, app.Alpha.Btn * alpha * 0.2 * ring, Z_NAV + 1, 2.5)
    Painter.rect(position, boxSize, Color.lerp(pal.Panel, pal.Accent, 0.12 + 0.22 * hover * (1 - grown) - 0.06 * grown), app.Alpha.Btn * alpha, Z_NAV, 12)
    Painter.fade(position, Vector2.new(boxSize.X, boxSize.Y * 0.6), Color3.new(1, 1, 1), 0.55, 0, 90, app.Alpha.Btn * alpha * grown * (1 - pal.Pick), Z_NAV, 12)

    local roll = -(width - TOOLBAR_BUTTON) / (SEARCH_WIDTH - TOOLBAR_BUTTON) * math.pi * 2
    local tilt = math.rad(45 - 18 * wobble) + roll
    local direction = Vector2.new(math.cos(tilt), math.sin(tilt))
    local middle = position + Vector2.new(TOOLBAR_BUTTON / 2 * unit * press, boxSize.Y / 2)
    local radius = SEARCH_GLYPH * unit * (1 + 0.08 * hover * (1 - grown) + 0.16 * tick)
    local center = middle - direction * 1.6 * unit
    local thickness = math.max(1.5, 1.6 * unit)
    local glyphColor = Color.lerp(pal.Sub, pal.Text, math.max(hover, ring))
    Painter.border(center - Vector2.new(radius, radius), Vector2.new(radius * 2, radius * 2), radius, glyphColor, app.Alpha.Text * alpha, Z_NAV_TEXT, thickness)
    local from = center + direction * (radius + thickness * 0.6)
    Painter.line(from, from + direction * (3.8 + 1.2 * wobble + tick) * unit, glyphColor, app.Alpha.Text * alpha, Z_NAV_TEXT, thickness * 1.15)

    local size = 12 * app.TextScale
    local textLeft = position.X + (TOOLBAR_BUTTON - 2) * unit
    local textY = position.Y + boxSize.Y / 2
    local reveal = math.clamp((open - 0.45) / 0.55, 0, 1)
    local hint = ease(app, "search:hint", if query == "" then 1 else 0, 18 * speed)
    local clearing = spring(app, "search:clear", if query ~= "" and open > 0.6 then 1 else 0, 0.3, 0.62)
    local clearShown = math.clamp(clearing, 0, 1)
    local limit = boxSize.X - (TOOLBAR_BUTTON + SPACE_L + SPACE_S * clearShown) * unit
    local shownQuery = query
    while #shownQuery > 0 and Painter.textWidth(shownQuery, size) > limit do
        shownQuery = string.sub(shownQuery, 2)
    end
    Painter.clip(position, boxSize)
    Painter.text("Search", Vector2.new(textLeft + (1 - reveal) * SPACE_S * unit + 4 * unit * ring, textY), size, pal.Sub, app.Alpha.Text * alpha * reveal * hint, Z_NAV_TEXT, false, true)
    Painter.text(shownQuery, Vector2.new(textLeft, textY), size, pal.Text, app.Alpha.Text * alpha * reveal, Z_NAV_TEXT, false, true)
    local breathe = math.clamp(0.5 + 0.9 * math.cos(os.clock() * math.pi * 2 / 1.1), 0, 1)
    local caretX = textLeft + (if shownQuery == "" then 0 else Painter.textWidth(shownQuery, size) + unit)
    Painter.rect(Vector2.new(caretX, textY - 6 * unit), Vector2.new(math.max(1, 1.5 * unit), 12 * unit), pal.Text, app.Alpha.Text * alpha * ring * reveal * breathe, Z_NAV_TEXT, unit, true)
    local clearKey = key .. ":clear"
    local clearHover = ease(app, clearKey, if app.HoverKey == clearKey then 1 else 0, 16 * speed)
    local dot = 14 * unit * math.max(0, clearing)
    local clearCenter = Vector2.new(position.X + boxSize.X - 13 * unit, textY)
    Painter.rect(clearCenter - Vector2.new(dot / 2, dot / 2), Vector2.new(dot, dot), Color.lerp(pal.Sub, pal.Text, clearHover), app.Alpha.Btn * alpha * 0.6 * clearShown, Z_NAV_TEXT, dot / 2, true)
    local spin = math.rad(45 + 90 * (1 - clearing))
    local arm = 3 * unit * math.max(clearShown, 0.3)
    for turn = 0, 1 do
        local angle = spin + turn * math.pi / 2
        local leg = Vector2.new(math.cos(angle), math.sin(angle)) * arm
        Painter.line(clearCenter - leg, clearCenter + leg, pal.Panel, app.Alpha.Text * alpha * clearShown, Z_NAV_TEXT + 1, math.max(1.2, 1.4 * unit))
    end
    Painter.unclip()
    Painter.scope(nil)
    if not app.Modal and alpha > 0.5 then
        Hits.add({
            key = key,
            position = app:pos(right - width, TOOLBAR_Y),
            size = full,
            click = function()
                if app.Focus ~= SEARCH_KEY then
                    focusSearch(app, app.SearchQuery or "")
                end
            end,
        })
        if clearing > 0.5 then
            Hits.add({
                key = clearKey,
                position = clearCenter - app:size(10, 10),
                size = app:size(20, 20),
                click = function()
                    app.SearchQuery = ""
                    app.Buffers[SEARCH_KEY] = ""
                    focusSearch(app, "")
                end,
            })
        end
    end
end

local function headerSteady(app: App, key: string, text: string, upcoming: string?): boolean
    local state = app.State
    local last: { [string]: string } = app.HeaderText
    if not last then
        last = {}
        app.HeaderText = last
    end
    local fading: { [string]: boolean } = app.HeaderFading
    if not fading then
        fading = {}
        app.HeaderFading = fading
    end
    if upcoming then
        fading[key] = upcoming ~= text
    elseif not state.TabFading then
        fading[key] = nil
    end
    local same = if upcoming then upcoming == text else last[key] == text and not fading[key]
    if not state.NextTab and (state.TabReveal or 1) >= 1 then
        last[key] = text
    end
    return same
end

local function drawContent(app: App, tab: { [string]: any }, section: { [string]: any }, index: number): (number, number, number, number)
    local m: Metrics = app.M
    local state = app.State
    local pal = app.Pal
    local text, ui = app.Alpha.Text, app.Alpha.UI
    local _, _, cx, cw = geometry(app)
    local reveal = Motion.glide(if state.AnimationsEnabled then math.clamp(state.TabReveal, 0, 1) else 1)
    local alpha = state.TabAlpha * math.min(1, reveal * 1.4)
    local direction = state.TabSlideDirection or 1
    local offset = Vector2.new((1 - reveal) * 8 * direction * app.Scale, 0)
    local pick = pal.Pick
    app.SearchText = if pick > 0.5 then string.lower(searchQuery(app)) else ""
    trackHistory(app)

    local title: string = tab.label
    local description: string = app.Options.Subtitle
    local upcoming = if state.NextTab then app.TabByName[state.NextTab] else nil
    local upcomingTitle: string? = nil
    if upcoming then
        upcomingTitle = upcoming.label
    end
    local upcomingDescription: string? = if upcoming then description else nil
    local steadyTitle = headerSteady(app, "title", title, upcomingTitle)
    local steadyDescription = headerSteady(app, "description", description, upcomingDescription)
    local still = Vector2.new(0, 0)
    local lead = 0
    if app.Options.HeaderLogo == true and app.LogoAsset then
        lead = (TOOLBAR_BUTTON + SPACE_S) * pick
        local emblem = app.Options.Logo ~= nil and app.Options.Logo.Emblem == true
        Painter.scope("content:logo")
        if emblem then
            Painter.image(app.LogoAsset, app:pos(cx + 4, TOOLBAR_Y), app:size(TOOLBAR_BUTTON, TOOLBAR_BUTTON), text * pick, Z_NAV, 0, pal.Accent)
        else
            Painter.image(app.LogoAsset, app:pos(cx + 4, TOOLBAR_Y), app:size(TOOLBAR_BUTTON, TOOLBAR_BUTTON), text * pick, Z_NAV, 7 * app.Unit)
        end
        Painter.scope(nil)
    end
    Painter.scope("content:header")
    Painter.text(
        title,
        app:pos(cx + 4 + TITLE_SHIFT * pick + lead, 18.5 + 8.5 * pick) + (if steadyTitle then still else offset),
        math.min((app.BrandTitleSize or 16 * app.TextScale) + 2, 18 * app.TextScale) * (1 - pick) + 16 * app.TextScale * pick,
        pal.Text,
        text * (if steadyTitle then 1 else alpha),
        4,
        false,
        true,
        if app.Options.BoldTitles then Fonts.find("Gotham Bold") elseif pick > 0.5 then boldFace() else nil
    )
    Painter.text(description, app:pos(cx + 4, 35.5) + (if steadyDescription then still else offset * 0.82), 11 * app.TextScale, pal.Sub, text * (if steadyDescription then 1 else alpha) * (1 - pick), 4, false, true)
    Painter.scope(nil)

    local chipAlpha = if state.TabFading then state.TabAlpha elseif state.SectionSwap then 1 else math.min(1, reveal * 1.4)
    local chipsY = drawChips(app, tab, state.NextSection or index, cx + 4, cw - 8, chipAlpha)
    local rowsY = if state.AnimationsEnabled then ease(app, "panel:top", chipsY, PANEL_GLIDE) else chipsY
    if math.abs(rowsY - chipsY) < 0.25 then
        rowsY = chipsY
        app.NavAnim["panel:top"] = chipsY
    end

    local panelTop = rowsY - PANEL_PAD
    local panelHeight = m.Height - FOOTER_HEIGHT - panelTop

    local panelPos, panelSize = app:pos(cx, panelTop), app:size(cw, panelHeight)
    local sky = app.SkyFrame
    local clear = if sky then sky.Clear else 0
    local card = pal.Well
    local skyOn = sky ~= nil and (sky.Sky ~= nil or sky.Cycle ~= nil)
    Painter.scope("content:panel")
    local rim = if clear > 0 then Color.lerp(pal.Off, pal.Text, clear) else pal.Off
    Painter.border(panelPos, panelSize, PANEL_ROUNDING * Painter.corner(), rim, ui * (0.5 - 0.42 * clear) * (1 - pick), 2, 1.2)
    if skyOn and sky then
        local dark = ui * (1 - pal.Light) * (1 - clear)
        Sky.paint(panelPos, panelSize, card, Color.lerp(card, sky.Sky or card, 0.5), dark, dark, 3, PANEL_ROUNDING, if clear > 0 then nil else sky.Cycle, sky.Flow, 0.5)
    end
    local cover = if skyOn and sky then Sky.left(pal.Light + clear * sky.Glass, sky.Veil) elseif sky then Sky.left(1 - clear * (1 - sky.Glass), sky.Veil) else 1
    Painter.rect(panelPos, panelSize, card, ui * cover * (1 - pick), 3, PANEL_ROUNDING)
    Painter.scope(nil)

    local query = app.SearchText or ""
    local empty = ease(app, "search:empty", if query ~= "" and not tab.ownSearch and Layout.sectionHeight(app, section) <= 0 then 1 else 0, 10 * Motion.speed(state))
    if query ~= "" then
        app.SearchShownQuery = query
    end
    Painter.scope("search:empty")
    local middle = panelPos + panelSize / 2 + Vector2.new(0, (1 - empty) * 6 * app.Unit)
    Painter.text("No Results", middle - Vector2.new(0, 9 * app.Unit), 14 * app.TextScale, pal.Sub, text * empty * pick, 6, true, true, boldFace())
    Painter.text('Nothing here matches "' .. tostring(app.SearchShownQuery or "") .. '"', middle + Vector2.new(0, 10 * app.Unit), 11.5 * app.TextScale, pal.Sub, text * empty * pick * 0.8, 6, true, true)
    Painter.scope(nil)

    local footerY = m.Height - FOOTER_HEIGHT / 2 - MARGIN + 6 + SPACE_XS * pick
    local footerX = cx + 4 + 21 * pick
    Painter.scope("content:pathbar")
    Painter.rect(app:pos(cx - MARGIN, m.Height - FOOTER_HEIGHT + SPACE_XS), Vector2.new(app:size(cw + MARGIN * 2, 0).X, math.max(1, app.Scale * 0.8)), pal.Off, text * pick * 0.9, 5, 0)
    local driveAt = app:pos(cx + 5, footerY)
    folderGlyph(app, driveAt.X, driveAt.Y, pal.Sub, text * pick)
    Painter.scope(nil)

    local status: string? = nil
    local notice = app.Notice
    if notice and os.clock() < notice.Expires then
        status = notice.Text
    elseif app.Options.Status then
        status = app.Options.Status()
    end
    local statusShown = ease(app, "footer:status", if status then 1 else 0, 7 * Motion.speed(app.State))
    app.FooterStatus = status or app.FooterStatus
    if app.FooterStatus ~= app.FooterTarget then
        app.FooterOld = if app.FooterTarget ~= nil and app.FooterStatus ~= nil then app.FooterTarget else nil
        app.FooterTarget = app.FooterStatus
        app.NavAnim["footer:swap"] = if app.FooterOld ~= nil then 0 else 1
    end
    local swap = ease(app, "footer:swap", 1, 4.5 * Motion.speed(app.State))
    local countText = if tab.ownSearch then tostring(app.OwnCount or 0) .. " " .. tostring(tab.noun or "items") else tostring(Layout.countOptions(app, section)) .. " options"
    local countWidth = Painter.textWidth(countText, 11 * app.TextScale)
    local footerLimit = (cw - 8 - 18 * pick) * app.Scale - countWidth - 14 * app.Scale
    Painter.scope("content:footer")
    local footerColor = if clear > 0 then Color.lerp(pal.Sub, pal.Text, 0.5 * clear) else pal.Sub
    Painter.text(cutFooter(app.Options.Footer, 11 * app.TextScale, footerLimit), app:pos(footerX, footerY), 11 * app.TextScale, footerColor, text * (1 - statusShown), 5, false, true)
    if app.FooterOld ~= nil and swap < 0.995 then
        local rise = Vector2.new(0, -6 * swap * app.Scale)
        Painter.text(cutFooter(app.FooterOld, 11 * app.TextScale, footerLimit), app:pos(footerX, footerY) + rise, 11 * app.TextScale, pal.Accent, text * statusShown * (1 - swap) * (1 - swap), 5, false, true)
    end
    if app.FooterStatus then
        local settle = Vector2.new(0, 6 * (1 - swap) * app.Scale)
        Painter.text(cutFooter(app.FooterStatus, 11 * app.TextScale, footerLimit), app:pos(footerX, footerY) + settle, 11 * app.TextScale, pal.Accent, text * statusShown * (if app.FooterOld ~= nil then swap * swap else 1), 5, false, true)
    end
    Painter.scope("content:count")
    Painter.text(countText, app:pos(cx + cw - 4, footerY) - Vector2.new(countWidth / 2, 0), 11 * app.TextScale, footerColor, text * alpha, 5, true, true)
    Painter.scope(nil)

    app.ContentBox = { panelPos.X, panelPos.Y, panelPos.X + panelSize.X, panelPos.Y + panelSize.Y }
    drawHeaderButtons(app, cx + cw - 4, text)
    if pick > 0.01 then
        local count = (if app.Options.OnUnload then 1 else 0) + (if app.Options.OnReload then 1 else 0)
        local searchRight = cx + cw - 4 - count * TOOLBAR_BUTTON - math.max(0, count - 1) * 6 - (if count > 0 then SPACE_S else 0)
        drawSearch(app, searchRight, text * pick)
        local history: { string } = app.NavHistory
        Painter.scope("head:navbg")
        Painter.rect(app:pos(cx + 4 + lead, TOOLBAR_Y), app:size(CHEVRON_WIDTH * 2 + SPACE_XS, TOOLBAR_BUTTON), Color.lerp(pal.Panel, pal.Accent, 0.12), app.Alpha.Btn * text * pick, Z_NAV, 12)
        Painter.scope(nil)
        chevron(app, "head:back", cx + 4 + lead, -1, app.NavIndex > 1, text * pick, function()
            stepHistory(app, -1)
        end)
        chevron(app, "head:forward", cx + 4 + lead + CHEVRON_WIDTH + SPACE_XS, 1, app.NavIndex < #history, text * pick, function()
            stepHistory(app, 1)
        end)
    end
    return cx + 1, rowsY, cw - 7, m.Height - FOOTER_HEIGHT - PANEL_PAD
end

function Chrome.draw(app: App, now: number, tab: { [string]: any }, section: { [string]: any }, sectionIndex: number): (number, number, number, number)
    ease(app, "navside", if app.State.NavSide == "Right" then 1 else 0, 7 * Motion.speed(app.State))
    local position, size = app.WindowPos, app.WindowSize
    local rounding = math.max(12, math.round(WINDOW_ROUNDING * app.Scale))
    local frame = app.Alpha.Frame
    local card = app.HandoffCard
    if card then
        local settle: number = card.Settle or 0
        local corner = Painter.corner()
        local cardRadius = tonumber(card.Radius)
        if cardRadius and corner > 0.001 then
            rounding = (cardRadius + (rounding * corner - cardRadius) * settle) / corner
        end
        frame = frame + (1 - frame) * (1 - settle)
    end

    Painter.scope("frame:shadows")
    drawShadows(app, position, size)
    Sky.surface(app, position, size, rounding, frame)
    local quiet = if app.State.PremiumEffects == true then 0 else app.Pal.Pick * (if card then card.Settle or 0 else 1)
    Painter.scope("frame:body")
    Effects.outline(app.State, now, position, size, app.Scale, frame * (1 - quiet), "main", rounding * Painter.corner(), nil, card)
    Painter.scope(nil)
    drawFrost(app, now, size, rounding)

    local soft = Effects.ambient(app.State)
    if soft and app.Popup.Name == "None" and not app.Boot then
        local main = app.State.MainCol
        local light = 0.299 * main.R + 0.587 * main.G + 0.114 * main.B > 0.5
        Painter.scope("frame:ambient")
        Skyfx.ambient(soft, position + Vector2.new(1, 1) * rounding * 0.3 * app.Pal.Pick, size - Vector2.new(2, 2) * rounding * 0.3 * app.Pal.Pick, app.Scale, app.Alpha.UI * app.State.IntroAlpha, Z_FRAME, os.clock(), if light then app.Pal.Accent else Color.lighten(app.Pal.Accent, 0.4), light)
        Painter.scope(nil)
    end
    if app.Popup.Name == "None" and not app.Boot then
        Effects.background(
            app.State, app.Particles, now, app.Dt, position, size, app.Scale, app.Alpha.UI, app.Pal.Light, app.State.IntroAlpha, rounding * Painter.corner()
        )
    end

    if not app.M.NoSidebar then
        drawSidebar(app, now)
    end
    return drawContent(app, tab, section, sectionIndex)
end

return Chrome
end
modules["ui/controls"] = function(...)

local Controls = {}

type Map = { [string]: any }
type Window = { [string]: any }

local BUILDERS: { [string]: (Window, Map, Map) -> Map } = {}

local function fail(message: string)
    error("OkloUI: " .. message, 0)
end

local function accessors(window: Window, descriptor: Map): (() -> any, (any) -> (), string)
    local callback = descriptor.Callback
    local key = descriptor.StateKey
    if key then
        local state = window.State
        local function set(value: any)
            if state[key] ~= value then
                state[key] = value
                if callback then
                    callback(value)
                end
            end
        end
        return function()
            return state[key]
        end, set, key
    end
    local flag = descriptor.Flag
    if type(flag) ~= "string" or flag == "" then
        fail("a control needs a Flag: " .. tostring(descriptor.Name))
    end
    window:register(flag, descriptor.Default, descriptor.Save ~= false)
    local flags = window.Flags
    local function set(value: any)
        if flags[flag] ~= value then
            flags[flag] = value
            if callback then
                callback(value)
            end
        end
    end
    window.Setters[flag] = set
    return function()
        return flags[flag]
    end, set, flag
end

local function announced(window: Window, descriptor: Map, get: () -> any, set: (any) -> (), describe: (any) -> string): (any) -> ()
    return function(value: any)
        local before = get()
        set(value)
        if before ~= get() and window.State.ToggleNotifications and type(descriptor.Name) == "string" then
            window:announce(describe(value))
        end
    end
end

local function common(descriptor: Map, spec: Map): Map
    spec.show = descriptor.Show
    spec.disabled = descriptor.Disabled
    spec.exempt = descriptor.Exempt
    spec.bottom = descriptor.Bottom
    return spec
end

local function infoSide(window: Window, info: Map): Map
    return {
        label = "?",
        onClick = function()
            window:openPopup("info", info)
        end,
    }
end

local function sideOf(window: Window, descriptor: Map): Map?
    if descriptor.Info then
        return infoSide(window, descriptor.Info)
    end
    local side = descriptor.Side
    if side then
        return { label = side.Label, width = side.Width, small = side.Small, onClick = side.OnClick }
    end
    return nil
end

BUILDERS.Toggle = function(window: Window, descriptor: Map, _tab: Map): Map
    local get, set, key = accessors(window, descriptor)
    local bindable = descriptor.Bindable
    if bindable == nil then
        bindable = descriptor.StateKey == nil
    end
    local spec = common(descriptor, {
        kind = "toggle",
        text = descriptor.Name,
        get = get,
        set = announced(window, descriptor, get, set, function(value: any): string
            return descriptor.Name .. (if value then " enabled" else " disabled")
        end),
        flag = key,
        bindable = bindable,
        side = sideOf(window, descriptor),
    })
    if bindable then
        window:defineBindable(spec, descriptor.Key)
    end
    return spec
end

BUILDERS.Slider = function(window: Window, descriptor: Map, _tab: Map): Map
    local get, set = accessors(window, descriptor)
    local minimum, maximum = descriptor.Min, descriptor.Max
    if type(minimum) ~= "number" or type(maximum) ~= "number" or maximum <= minimum then
        fail("a slider needs Min and Max: " .. tostring(descriptor.Name))
    end
    local function shown(value: any): string
        local format = descriptor.Format
        if type(format) == "function" then
            local ok, text = pcall(format, value)
            if ok then
                return descriptor.Name .. ": " .. tostring(text)
            end
        end
        return descriptor.Name .. ": " .. tostring(if type(value) == "number" then math.floor(value * 100 + 0.5) / 100 else value)
    end
    return common(descriptor, {
        kind = "slider",
        text = descriptor.Name,
        get = get,
        set = if descriptor.StateKey then set else announced(window, descriptor, get, set, shown),
        min = minimum,
        max = maximum,
        float = descriptor.Float == true,
        step = descriptor.Step,
        format = descriptor.Format,
        label = descriptor.Label,
        unclamped = descriptor.Unclamped == true,
    })
end

BUILDERS.Button = function(window: Window, descriptor: Map, _tab: Map): Map
    local callback = descriptor.Callback
    local spec = common(descriptor, {
        kind = "button",
        text = descriptor.Name,
        label = descriptor.Label,
        align = descriptor.Align,
        active = descriptor.Active,
        fold = descriptor.Fold,
        side = sideOf(window, descriptor),
        onClick = function(app: Window)
            if callback then
                callback(app)
            end
        end,
    })
    if descriptor.Bind then
        spec.flag = "bind:" .. tostring(descriptor.Bind)
        spec.bindable = true
        window:defineBindable(spec, descriptor.Key)
    end
    return spec
end

BUILDERS.Dropdown = function(window: Window, descriptor: Map, _tab: Map): Map
    local get, set = accessors(window, descriptor)
    if descriptor.Values == nil then
        fail("a dropdown needs Values: " .. tostring(descriptor.Name))
    end
    return common(descriptor, {
        kind = "dropdown",
        text = descriptor.Name,
        get = get,
        set = if descriptor.StateKey then set else announced(window, descriptor, get, set, function(value: any): string
            return descriptor.Name .. ": " .. tostring(value)
        end),
        values = descriptor.Values,
        side = sideOf(window, descriptor),
    })
end

BUILDERS.Color = function(window: Window, descriptor: Map, _tab: Map): Map
    local get, set, key = accessors(window, descriptor)
    local state = window.State
    local default: Color3 = descriptor.Default or Color3.new(1, 1, 1)
    local target = {
        Key = key,
        Get = function()
            return state["Target_" .. key] or get()
        end,
        Set = function(color: Color3)
            if descriptor.StateKey then
                state["Target_" .. key] = color
            end
            set(color)
            if key == "MainCol" or key == "AccentCol" then
                window:colorEdited()
            end
        end,
        Default = default,
    }
    return common(descriptor, {
        kind = "button",
        text = descriptor.Name,
        onClick = function()
            window:openColor(target)
        end,
    })
end

BUILDERS.Input = function(window: Window, descriptor: Map, _tab: Map): Map
    local get, set, key = accessors(window, descriptor)
    local placeholder = descriptor.Name
    return common(descriptor, {
        kind = "button",
        text = placeholder,
        align = "center",
        input = "input:" .. key,
        numeric = descriptor.Numeric == true,
        maxLength = descriptor.MaxLength,
        display = function()
            local value = get()
            local text = if value == nil then "" else tostring(value)
            return if text == "" then placeholder else text
        end,
        commit = function(text: string)
            if descriptor.Numeric then
                local number = tonumber(text)
                if number then
                    set(number)
                end
            else
                set(text)
            end
        end,
    })
end

BUILDERS.BindRow = function(_window: Window, descriptor: Map, _tab: Map): Map
    return common(descriptor, { kind = "bindrow", index = descriptor.Index })
end

BUILDERS.Label = function(_window: Window, descriptor: Map, _tab: Map): Map
    local label = descriptor.Label
    return common(descriptor, {
        kind = "text",
        text = descriptor.Text or "",
        label = label,
        size = descriptor.Size,
        accent = descriptor.Accent,
        color = descriptor.Color,
        center = descriptor.Center,
        height = descriptor.Height,
        bold = descriptor.Bold == true,
        boxed = descriptor.Boxed == true,
    })
end

BUILDERS.Custom = function(_window: Window, descriptor: Map, _tab: Map): Map
    return common(descriptor, {
        kind = "custom",
        height = descriptor.Height or 100,
        bare = descriptor.Bare == true,
        ownSearch = descriptor.OwnSearch == true,
        render = descriptor.Render,
    })
end

function Controls.compile(window: Window, descriptor: Map, tab: Map): Map
    local build = BUILDERS[descriptor.Type]
    if not build then
        fail("unknown control type: " .. tostring(descriptor.Type))
    end
    local spec = build(window, descriptor, tab)
    local gate = tab.gate
    if gate and spec.flag ~= gate and not spec.exempt then
        spec.gated = gate
    end
    return spec
end

return Controls
end
modules["ui/discord"] = function(...)

local Discord = {}

local FIRST_PORT, LAST_PORT = 6463, 6472

function Discord.code(invite: string): string?
    return string.match(invite, "discord%.gg/([%w%-_]+)") or string.match(invite, "discord%.com/invite/([%w%-_]+)")
end

function Discord.join(invite: string)
    pcall(function()
        setclipboard(invite)
    end)
    local code = Discord.code(invite)
    if not code then
        return
    end
    task.spawn(function()
        local http = game:GetService("HttpService")
        local body = http:JSONEncode({ cmd = "INVITE_BROWSER", args = { code = code }, nonce = http:GenerateGUID(false) })
        for port = FIRST_PORT, LAST_PORT do
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

return Discord
end
modules["ui/effects"] = function(...)

local import: (string) -> any = ...
local Canvas: typeof(require("../render/canvas")) = import("render/canvas")
local Color: typeof(require("../core/color")) = import("core/color")
local Geometry: typeof(require("./geometry")) = import("ui/geometry")
local Motion: typeof(require("./motion")) = import("ui/motion")
local Painter: typeof(require("./painter")) = import("ui/painter")

local Effects = {}

type State = { [string]: any }

local SPIN_SPEED = 34
local MAX_PHASE_STEP = 0.10

local function snapBox(position: Vector2, size: Vector2): (Vector2, Vector2)
    local left, top = math.floor(position.X + 0.5), math.floor(position.Y + 0.5)
    local right, bottom = math.floor(position.X + size.X + 0.5), math.floor(position.Y + size.Y + 0.5)
    return Vector2.new(left, top), Vector2.new(right - left, bottom - top)
end

local function advancePhase(state: State, name: string, now: number, perimeter: number, speed: number, offset: number): number
    if type(state.OutlinePhases) ~= "table" then
        state.OutlinePhases = {}
    end
    local intensity = Motion.intensity(state)
    local phase = state.OutlinePhases[name]
    if not phase then
        phase = { Phase = ((now * speed * intensity / math.max(perimeter, 1)) + offset) % 1, Last = now }
        state.OutlinePhases[name] = phase
    end
    local step = math.clamp(now - phase.Last, 0, MAX_PHASE_STEP)
    phase.Phase = (phase.Phase + step * speed * intensity / math.max(perimeter, 1)) % 1
    phase.Last = now
    return phase.Phase * perimeter
end

local function cardPhase(state: State, name: string, now: number, card: { [string]: any }): number
    advancePhase(state, name, now, 360, SPIN_SPEED, 0)
    local phase = state.OutlinePhases[name]
    local cardRate: number = tonumber(card.Spin) or 110
    local settle: number = card.Settle or 0
    if settle <= 0 then
        phase.Phase = ((os.clock() * cardRate) % 360) / 360
    else
        local step = math.clamp(now - (card.Last or now), 0, MAX_PHASE_STEP)
        phase.Phase = (phase.Phase + step * (cardRate - SPIN_SPEED * Motion.intensity(state)) * (1 - settle) / 360) % 1
    end
    card.Last = now
    return phase.Phase * 360
end

function Effects.outline(state: State, now: number, position: Vector2, size: Vector2, scale: number, alpha: number, name: string, windowRadius: number?, zIndex: number?, card: { [string]: any }?)
    if size.X <= 4 or size.Y <= 4 then
        return
    end
    local accent: Color3 = state.AccentCol
    local trail: boolean | number = state.PremiumEffects == true and not state.HighPerformanceMode
    local rotation
    if card then
        local settle: number = card.Settle or 0
        rotation = cardPhase(state, name, now, card)
        if typeof(card.Accent) == "Color3" then
            accent = Color.lerp(card.Accent, accent, settle)
        end
        if trail ~= true then
            trail = 1 - settle
        end
    else
        rotation = advancePhase(state, name, now, 360, if state.PremiumEffects == true then SPIN_SPEED else 0, 0)
    end
    local radius = windowRadius or 6 * scale
    local snapPos, snapSize = snapBox(position, size)
    Painter.outline(snapPos, snapSize, radius, accent, Color.lighten(accent, 0.9), alpha, zIndex or 1, math.max(1.5, 1.7 * scale), rotation, trail)
end

function Effects.badge(state: State, now: number, position: Vector2, size: Vector2, scale: number, alpha: number)
    if alpha <= 0.001 or size.X <= 4 or size.Y <= 4 then
        return
    end
    local inset = math.max(1, math.round(scale))
    local accent: Color3 = state.AccentCol
    local trail = not state.HighPerformanceMode
    local rotation = advancePhase(state, "badge", now, 360, SPIN_SPEED * 1.6, 0.17)
    local snapPos, snapSize = snapBox(position + Vector2.new(inset, inset), size - Vector2.new(inset * 2, inset * 2))
    Painter.outline(snapPos, snapSize, math.max(3, 5 * scale), accent, Color.lighten(accent, 0.9), alpha, 7, math.max(1, 1.2 * scale), rotation, trail)
end

local function clippedLine(from: Vector2, to: Vector2, color: Color3, alpha: number, thickness: number, area: { number }, scale: number)
    if alpha <= 0.0001 or thickness <= 0 then
        Canvas.skip("Line")
        return
    end
    local inset = math.max(1, thickness * 0.5 + 1)
    local left, top, right, bottom = area[1] + inset, area[2] + inset, area[3] - inset, area[4] - inset
    if right <= left or bottom <= top then
        Canvas.skip("Line")
        return
    end
    local a, b = Geometry.clipLine(from.X, from.Y, to.X, to.Y, left, top, right, bottom)
    if not a or not b then
        Canvas.skip("Line")
        return
    end
    local radius = math.max(0, area[5] - inset)

    if math.max(a.Y, b.Y) <= bottom - radius then
        Canvas.line(a, b, color, alpha, thickness)
        return
    end
    local pieces = math.clamp(math.ceil(math.sqrt((b.X - a.X) ^ 2 + (b.Y - a.Y) ^ 2) / math.max(2, 3 * scale)), 1, 12)
    local previous = a
    for index = 1, pieces do
        local current = a + (b - a) * (index / pieces)
        if Geometry.insideArea(previous.X, previous.Y, left, top, right, bottom, radius)
            and Geometry.insideArea(current.X, current.Y, left, top, right, bottom, radius) then
            Canvas.line(previous, current, color, alpha, thickness)
        else
            Canvas.skip("Line")
        end
        previous = current
    end
end

Effects.clippedLine = clippedLine

export type Particle = { [string]: any }

function Effects.createParticles(amount: number): { Particle }
    local list = {}
    for index = 1, amount do
        list[index] = {
            X = math.random(0, 100),
            Y = math.random(0, 100),
            SpeedMult = 0.78 + math.random() * 0.42,
            Sine = math.random() * math.pi * 2,
            TrailLength = 150 + math.random() * 150,
            Twinkle = 0.55 + math.random() * 0.65,
            Seed = math.random() * 1000,
            Depth = math.random(),
        }
    end
    return list
end

local function smooth(value: number): number
    local t = math.clamp(value, 0, 1)
    return t * t * (3 - 2 * t)
end

local function updateSnow(particle: Particle, state: State, now: number, dt: number)
    local depth = particle.Depth
    local fall = state.SnowSpeed * particle.SpeedMult * (0.35 + 0.9 * depth)
    particle.Y += fall * dt
    particle.X += (math.sin(now * (0.5 + 0.4 * depth) + particle.Sine) * 5 + 1.2) * dt * (0.4 + depth)
    if particle.Y > 102 then
        particle.Y = -2
        particle.X = math.random(0, 100)
    end
    if particle.X > 102 then
        particle.X = -2
    elseif particle.X < -2 then
        particle.X = 102
    end
end

local function drawSnow(state: State, particle: Particle, now: number, scale: number, base: Color3, alpha: number, x: number, y: number)
    local depth = particle.Depth
    local arm = math.max(1.2, math.max(1, state.SnowSize) * scale * (0.7 + 0.9 * depth))
    local twinkle = 0.85 + 0.15 * math.sin(now * 1.3 + particle.Sine * 3)
    local color = Color.lighten(base, 0.45)
    local strength = alpha * (0.45 + 0.5 * depth) * twinkle
    local thickness = math.max(1, scale * 0.8)
    local turn = now * 0.25 * (if particle.Sine > math.pi then 1 else -1) + particle.Sine
    local center = Vector2.new(x, y)
    for index = 0, 2 do
        local angle = turn + index * math.pi / 3
        local offset = Vector2.new(math.cos(angle), math.sin(angle)) * arm
        Canvas.line(center - offset, center + offset, color, strength, thickness)
    end
end

local RAIN_SLANT = 0.2

local function updateRain(particle: Particle, state: State, dt: number)
    local depth = particle.Depth
    local fall = state.SnowSpeed * particle.SpeedMult * (1.4 + 2.2 * depth)
    particle.Y += fall * dt
    particle.X += fall * dt * RAIN_SLANT * 0.6
    if particle.Y > 102 then
        particle.Y = -4
        particle.X = math.random(0, 100)
    end
    if particle.X > 102 then
        particle.X = -2
    end
end

local function drawRain(state: State, particle: Particle, scale: number, base: Color3, alpha: number, x: number, y: number, area: { number })
    local depth = particle.Depth
    local length = (8 + 16 * depth) * scale * math.max(1, state.SnowSize) / 2
    local head = Vector2.new(x, y)
    local tail = Vector2.new(x - RAIN_SLANT * length, y - length)
    local thickness = math.max(1, scale * (0.6 + 0.5 * depth))
    clippedLine(tail, head, Color.lighten(base, 0.2), alpha * (0.22 + 0.4 * depth), thickness, area, scale)
end

local function updateFirefly(particle: Particle, state: State, now: number, dt: number)
    local pace = 0.4 + state.SnowSpeed / 40
    local seed = particle.Seed
    particle.X += (math.cos(now * 0.31 + particle.Sine) + math.sin(now * 0.17 * particle.Twinkle + seed)) * dt * 3 * pace
    particle.Y += (math.sin(now * 0.27 + particle.Sine * 1.7) + math.cos(now * 0.13 * particle.Twinkle + seed)) * dt * 2.2 * pace
    if particle.X > 100 then
        particle.X -= 100
    elseif particle.X < 0 then
        particle.X += 100
    end
    if particle.Y > 100 then
        particle.Y -= 100
    elseif particle.Y < 0 then
        particle.Y += 100
    end
end

local function drawFirefly(state: State, particle: Particle, now: number, scale: number, base: Color3, alpha: number, x: number, y: number)
    local size = math.max(1, state.SnowSize) * scale
    local blink = math.sin(now * (0.55 + particle.Twinkle * 0.4) + particle.Sine * 5)
    local lit = smooth(blink * 0.8 + 0.55)
    if lit <= 0.01 then
        return
    end
    local glow = Color.lerp(base, state.AccentCol, 0.5)
    local center = Vector2.new(x, y)
    Canvas.filledCircle(center, size * 5, glow, alpha * 0.05 * lit)
    Canvas.filledCircle(center, size * 2.4, glow, alpha * 0.14 * lit)
    Canvas.filledCircle(center, size * 0.9, Color.lighten(glow, 0.55), alpha * 0.95 * lit)
end

local RANDOM_EFFECTS = { "Bokeh", "Dust", "Silk" }

local function chosen(state: State): string?
    local preset = state.ThemePreset
    if state.ThemeName ~= "Custom" and type(preset) == "table" and type(preset.Cycle) == "table" and #preset.Cycle >= 2 then
        return nil
    end
    local effect: string = if state.ThemeName == "Default" then "Random" else (state.BackgroundEffect or "Random")
    if effect == "Random" then
        if not state.RandomEffect then
            state.RandomEffect = RANDOM_EFFECTS[math.random(1, #RANDOM_EFFECTS)]
        end
        effect = state.RandomEffect
    end
    if state.HighPerformanceMode or effect == "None" then
        return nil
    end
    return effect
end

function Effects.ambient(state: State): string?
    local effect = chosen(state)
    if effect == "Bokeh" or effect == "Dust" or effect == "Silk" then
        return effect
    end
    return nil
end

function Effects.background(state: State, particles: { Particle }, now: number, dt: number, windowPos: Vector2, windowSize: Vector2, scale: number, panelAlpha: number, lightMix: number, intro: number, radius: number)
    local preset = state.ThemePreset
    local forced: string? = if state.ThemeName == "Default" then "Random" else nil
    if state.ThemeName ~= "Custom" and type(preset) == "table" and type(preset.Cycle) == "table" and #preset.Cycle >= 2 then
        forced = "None"
    end
    if forced then
        if state.BackgroundEffect ~= forced then
            if state.EffectMemo == nil then
                state.EffectMemo = state.BackgroundEffect
            end
            state.BackgroundEffect = forced
        end
        if forced == "None" then
            return
        end
    elseif state.EffectMemo ~= nil then
        state.BackgroundEffect = state.EffectMemo
        state.EffectMemo = nil
    end
    local effect = chosen(state)
    if not (effect == "Snowfall" or effect == "Rain" or effect == "Fireflies") then
        return
    end
    local area = {
        windowPos.X + 2,
        windowPos.Y + 30 * intro * scale,
        windowPos.X + windowSize.X - 2,
        windowPos.Y + windowSize.Y - 2,
        math.max(0, radius - 2),
    }
    local accent: Color3 = state.AccentCol
    local tint = Color.lerp(accent, state.SnowCol, 0.20)
    local main: Color3 = state.MainCol
    local onLight = lightMix > 0.5 or 0.299 * main.R + 0.587 * main.G + 0.114 * main.B > 0.5
    local base = Color.lerp(tint, Color3.new(0, 0, 0), if onLight then math.max(lightMix, 0.8) else lightMix)
    local strong = if onLight then 2.6 else 1
    local fireflies = math.max(6, math.floor(#particles * 0.6))
    local fade = math.max(24, 40 * scale)
    local margin = 2 * scale

    for index, particle in particles do
        local visible = true
        if effect == "Rain" then
            updateRain(particle, state, dt)
        elseif effect == "Fireflies" then
            updateFirefly(particle, state, now, dt)
            visible = index <= fireflies
        else
            updateSnow(particle, state, now, dt)
        end

        local drawX = windowPos.X + particle.X / 100 * windowSize.X
        local drawY = windowPos.Y + particle.Y / 100 * windowSize.Y
        Canvas.scope("particle:" .. index)
        if visible then
            if Geometry.insideArea(drawX, drawY, area[1] + margin, area[2] + margin, area[3] - margin, area[4] - margin, math.max(0, area[5] - margin)) then
                local edge = smooth((drawX - area[1]) / fade) * smooth((area[3] - drawX) / fade) * smooth((drawY - area[2]) / fade) * smooth((area[4] - drawY) / fade)
                local alpha = math.min(1, panelAlpha * state.SnowTrans * strong) * edge
                if effect == "Rain" then
                    drawRain(state, particle, scale, base, alpha, drawX, drawY, area)
                elseif effect == "Fireflies" then
                    drawFirefly(state, particle, now, scale, base, alpha, drawX, drawY)
                else
                    drawSnow(state, particle, now, scale, base, alpha, drawX, drawY)
                end
            end
        end
    end
    Canvas.scope(nil)
end

function Effects.meteors(state: State, now: number, area: { number }, scale: number, alpha: number, textColor: Color3)
    local left, top, right, bottom = area[1], area[2], area[3], area[4]
    local width, height = right - left, bottom - top
    if width <= 0 or height <= 0 then
        return
    end
    local accent: Color3 = state.AccentCol
    local trailColor = Color.lighten(accent, 0.10)
    local headColor = Color.lighten(accent, 0.76)
    local glowColor = Color.lerp(accent, textColor, 0.16)
    local clip = { left, top, right, bottom, 0 }
    local cycle = 9.6

    for seed = 1, 10 do
        local a = (seed * 0.61803398875) % 1
        local b = (seed * 0.41421356237) % 1
        local c = (seed * 0.73205080757) % 1
        local d = (seed * 0.27182818284) % 1
        local flight = 4.05 + b * 1.10
        local phase = (now + (seed - 1) * cycle / 10 + (d - 0.5) * 0.24) % cycle
        Canvas.scope("meteor:" .. seed)
        if phase < flight then
            local progress = phase / flight
            local trail = math.min(width * (0.22 + c * 0.12), (92 + b * 82) * scale)
            local padding = math.max(9 * scale, trail * 0.18)
            local rightward = seed % 2 == 1
            local startX = if rightward then left - padding else right + padding
            local endX = if rightward then right + padding else left - padding
            local travelX = endX - startX
            local margin = math.max(11 * scale, 7)
            local travelY = (if (seed + math.floor(a * 10)) % 4 < 2 then 1 else -1) * height * (0.055 + a * 0.155)
            local lane = (((seed - 1) * 7) % 10 + 0.5) / 10
            local low, high
            if travelY >= 0 then
                low, high = top + margin, bottom - margin - travelY
            else
                low, high = top + margin - travelY, bottom - margin
            end
            if high < low then
                travelY = 0
                low, high = top + margin, bottom - margin
            end
            local startY = math.clamp(low + (high - low) * lane + (d - 0.5) * math.min(12 * scale, height * 0.045), low, high)

            local fade = math.min(math.clamp(progress / 0.025, 0, 1), math.clamp((1 - progress) / 0.032, 0, 1))
            fade = fade * fade * (3 - 2 * fade)
            local strength = alpha * fade * (0.30 + c * 0.20)
            local magnitude = math.max(0.001, math.sqrt(travelX * travelX + travelY * travelY))
            local dirX, dirY = travelX / magnitude, travelY / magnitude
            local headX = startX + travelX * progress - dirY * math.max(0.5, 0.92 * scale)
            local headY = startY + travelY * progress + dirX * math.max(0.5, 0.92 * scale)

            local previous = Vector2.new(headX - dirX * trail, headY - dirY * trail)
            for index = 1, 24 do
                local t = index / 24
                local current = Vector2.new(headX - dirX * trail * (1 - t), headY - dirY * trail * (1 - t))
                local taper = t * t
                clippedLine(previous, current, glowColor, strength * 0.026 * taper, math.max(1, (0.70 + 0.96 * taper) * scale), clip, scale)
                clippedLine(previous, current, trailColor, strength * 0.78 * taper ^ 1.58, math.max(1, (0.38 + 0.48 * taper) * scale), clip, scale)
                previous = current
            end
            local radius = math.max(0.9, (0.90 + b * 0.38) * scale)
            if headX > left + radius and headX < right - radius and headY > top + radius and headY < bottom - radius then
                Canvas.filledCircle(Vector2.new(headX, headY), radius, headColor, strength * 0.90)
            end
        end
    end
    Canvas.scope(nil)
end

return Effects
end
modules["ui/emblem"] = function(...)

local Emblem = {}

Emblem.PNG = "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"

return Emblem
end
modules["ui/farm"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")
local Hits: typeof(require("./hits")) = import("ui/hits")
local Motion: typeof(require("./motion")) = import("ui/motion")
local Painter: typeof(require("./painter")) = import("ui/painter")

local Farm = {}

type App = { [string]: any }

local Z_SCRIM, Z_PANEL, Z_CARD, Z_TEXT, Z_BUTTON = 30, 31, 32, 34, 36
local WIDTH = 640
local PAD = 20
local HEADER = 64
local STATUS_HEIGHT = 30
local TILE_HEIGHT = 78
local TILE_GAP = 10
local CARD_GAP = 10
local ROW_HEIGHT = 20
local CARD_HEAD = 34
local REFRESH = 0.4
local MIN_FONT = 11
local TOP = 52
local WIDGET_MIN = 190
local WIDGET_MAX = 440
local WIDGET_ROW = 900
local WIDGET_LIMIT = 8
local WIDGET_GAP = 10
local WIDGET_LINE = 18
local WIDGET_TOP = 14
local NO_DATA = { Tiles = {}, Cards = {}, Status = "" }

local function ease(app: App, key: string, goal: number, speed: number): number
    local value = Motion.ease(app.State, app.NavAnim[key] or goal, goal, app.Dt, speed)
    app.NavAnim[key] = value
    return value
end

function Farm.available(app: App): boolean
    return type(app.Options.FarmMode) == "function"
end

function Farm.enter(app: App)
    if Farm.available(app) then
        app.FarmOn = true
        app.FarmStart = os.clock()
        app.LastClick = nil
    end
end

function Farm.leave(app: App)
    app.FarmOn = false
end

function Farm.shown(app: App): boolean
    return app.FarmOn == true or (app.NavAnim["farm"] or 0) > 0.02
end

local function fit(text: string, size: number, limit: number): string
    if limit <= 0 or Painter.textWidth(text, size) <= limit then
        return text
    end
    local cut = #text
    while cut > 1 and Painter.textWidth(string.sub(text, 1, cut) .. "..", size) > limit do
        cut -= 1
    end
    return string.sub(text, 1, cut) .. ".."
end

local function data(app: App, now: number): any
    local cached = app.FarmData
    if cached ~= nil and now - (app.FarmDataAt or 0) < REFRESH then
        return cached
    end
    app.FarmDataAt = now
    local ok, result = pcall(app.Options.FarmMode)
    if ok and type(result) == "table" then
        app.FarmData = result
    elseif cached == nil then
        app.FarmData = NO_DATA
    end
    return app.FarmData
end

local function widgetWidth(app: App, widget: any, fit: number): number
    local scale = app.FarmTextScale
    local function measure(value: any, size: number): number
        return Painter.textWidth(tostring(value), math.max(MIN_FONT, math.ceil(size * scale * fit - 0.001))) / (app.Scale * fit)
    end
    local content = measure(string.upper(widget.Title), 11)
    if widget.Sub ~= nil then
        content = math.max(content, measure(widget.Sub, 11))
    end
    for _, row in widget.Rows do
        content = math.max(content, measure(row.Label, 12) + 18 + measure(row.Value, 12))
    end
    if widget.Total ~= nil then
        content = math.max(content, measure(widget.TotalLabel or "Total", 11) + 18 + measure(widget.Total, 11))
    end
    return math.clamp(math.ceil(content) + 36, WIDGET_MIN, WIDGET_MAX)
end

local function widgetHeight(widget: any): number
    local head = if widget.Sub ~= nil then 47 else 31
    return head + 8 + #widget.Rows * WIDGET_LINE + (if widget.Total ~= nil then 22 else 0) + 10
end

local function cardHeight(card: any): number
    return CARD_HEAD + #card.Rows * ROW_HEIGHT + 12
end

local function arrange(cards: { any }, width: number): ({ { card: any, x: number, y: number, w: number, h: number } }, number)
    local columnWidth = (width - CARD_GAP) / 2
    local heights = { 0, 0 }
    local placed = {}
    for _, card in cards do
        local column = if heights[2] < heights[1] then 2 else 1
        local height = cardHeight(card)
        table.insert(placed, {
            card = card,
            x = (column - 1) * (columnWidth + CARD_GAP),
            y = heights[column],
            w = columnWidth,
            h = height,
        })
        heights[column] += height + CARD_GAP
    end
    return placed, math.max(0, math.max(heights[1], heights[2]) - CARD_GAP)
end

function Farm.draw(app: App, now: number)
    local state = app.State
    local pal = app.Pal
    local on = app.FarmOn == true
    local motion = math.min(app.Dt, 1 / 30)
    local shown = Motion.ease(state, app.NavAnim["farm"] or 0, if on then 1 else 0, motion, if on then 12 else 18)
    app.NavAnim["farm"] = shown
    local open = math.clamp(Motion.spring(state, app.Springs, "farm", if on then 1 else 0, motion, if on then 0.45 else 0.25, 1), 0, 1)
    if shown < 0.01 then
        return
    end
    local info = data(app, now)
    local tiles = info.Tiles or {}
    local cards = info.Cards or {}
    local viewport: Vector2 = app.Viewport
    local full = math.clamp(shown, 0, 1)
    local started = math.clamp((now - (app.FarmStart or 0) - 0.05) / 0.5, 0, 1)
    local reveal = Motion.out(if state.AnimationsEnabled then started else 1)
    local lift = 0
    local function entry(order: number): number
        return math.clamp(reveal * 1.8 - order * 0.07, 0, 1)
    end

    local inner = WIDTH - PAD * 2
    local placed, gridHeight = arrange(cards, inner)
    local hasStatus = info.Status ~= nil and info.Status ~= ""
    local height = HEADER + PAD
    if hasStatus then
        height += STATUS_HEIGHT + 10
    end
    if #tiles > 0 then
        height += TILE_HEIGHT + 10
    end
    if #placed > 0 then
        height += gridHeight
    end
    height += PAD + 14

    local listed = {}
    for _, widget in info.Widgets or {} do
        if #listed < WIDGET_LIMIT and (widget.Fade or 1) > 0.004 then
            table.insert(listed, widget)
        end
    end
    local function layout(fit: number): ({ any }, number, number)
        local items = {}
        local rows: { { any } } = {}
        local rowWidth = 0
        for _, widget in listed do
            local item = { Data = widget, W = widgetWidth(app, widget, fit), H = widgetHeight(widget), X = 0, Y = 0 }
            table.insert(items, item)
            local last = rows[#rows]
            if last == nil or rowWidth + WIDGET_GAP + item.W > WIDGET_ROW then
                last = {}
                table.insert(rows, last)
                rowWidth = 0
            end
            rowWidth += (if #last > 0 then WIDGET_GAP else 0) + item.W
            table.insert(last, item)
        end
        local widest, top = 0, 0
        for _, row in rows do
            local width, tall = 0, 0
            for _, item in row do
                width += (if width > 0 then WIDGET_GAP else 0) + item.W
                tall = math.max(tall, item.H)
            end
            widest = math.max(widest, width)
            local left = 0
            for _, item in row do
                item.X, item.Y = left - width / 2, top
                left += item.W + WIDGET_GAP
            end
            top += tall + WIDGET_GAP
        end
        return items, widest, math.max(0, top - WIDGET_GAP)
    end
    local widgets, widgetsWidth, rawHeight = layout(1)
    local guess = 1
    for _ = 1, 4 do
        local span = TOP + height + (if rawHeight > 0 then WIDGET_TOP + rawHeight else 0) + 8
        local fits = math.min(1, (viewport.X - 32) / (math.max(WIDTH, widgetsWidth) * app.Scale), (viewport.Y - 24) / (span * app.Scale))
        if fits >= guess - 0.002 then
            break
        end
        guess = fits
        widgets, widgetsWidth, rawHeight = layout(guess)
    end
    local widgetsShown = ease(app, "farm:widgets", rawHeight, 10)
    local extra = if widgetsShown > 0.05 then WIDGET_TOP * math.clamp(widgetsShown / 14, 0, 1) + widgetsShown else 0
    local span = TOP + height + extra + 8

    local fitScale = math.min(1, (viewport.X - 32) / (math.max(WIDTH, widgetsWidth) * app.Scale), (viewport.Y - 24) / (span * app.Scale))
    local unit = app.Scale * (0.86 + 0.14 * open) * fitScale
    local baseText = app.FarmAlpha.Text * full
    local baseBack = app.FarmAlpha.UI * full
    local text, back = baseText, baseBack
    local function stage(order: number)
        local f = entry(order)
        lift = (1 - f) * 8 * unit
        text, back = baseText * f, baseBack * f
    end
    local size = Vector2.new(WIDTH, height) * unit
    local origin = Vector2.new(math.floor(viewport.X / 2 - size.X / 2 + 0.5), math.floor(viewport.Y / 2 - span * unit / 2 + TOP * unit + 0.5))
    local function at(x: number, y: number): Vector2
        return origin + Vector2.new(math.floor(x * unit + 0.5), math.floor(y * unit + 0.5 + lift))
    end
    local function px(value: number): Vector2
        return Vector2.new(value, value) * unit
    end
    local function font(value: number): number
        return math.max(MIN_FONT, math.ceil(value * app.FarmTextScale * fitScale - 0.001))
    end

    app.FarmBox = { origin, size }
    local card = Color.lerp(pal.Panel, pal.Main, 0.35)
    local line = Color.lerp(pal.Off, pal.Accent, 0.25)
    local dim = pal.Sub

    Painter.scope("farm")
    Painter.rect(Vector2.new(0, 0), viewport, Color3.new(0, 0, 0), full, Z_SCRIM, 0, true)
    Hits.add({ key = "farm:scrim", position = Vector2.new(0, 0), size = viewport, shield = true })
    Painter.border(origin, size, 36 * Painter.corner(), pal.Accent, back * 0.28, Z_PANEL, 1.2)
    Painter.rect(origin, size, pal.Main, back, Z_PANEL, 36)

    stage(0)
    Painter.text("FARM MODE", at(PAD, 27), font(17), pal.Text, text, Z_TEXT, false, true)
    Painter.text(app.Options.Title, at(PAD, 46), font(11), dim, text, Z_TEXT, false, true)

    Hits.add({ key = "farm:panel", position = origin, size = size, shield = true })
    local label = "Return To Normal Mode"
    local labelSize = font(12)
    local buttonWidth = Painter.textWidth(label, labelSize) / unit + 32
    local buttonX, buttonY, buttonHeight = WIDTH - PAD - buttonWidth, 17, 30
    local key = "farm:return"
    local hovered = app.HoverKey == key
    local hover = ease(app, key, if hovered then 1 else 0, 14 * Motion.speed(state))
    local buttonPos, buttonSize = at(buttonX, buttonY), Vector2.new(math.floor(buttonWidth * unit + 0.5), math.floor(buttonHeight * unit + 0.5))
    Painter.border(buttonPos, buttonSize, 20 * Painter.corner(), Color.lerp(pal.Off, pal.Accent, 0.35 * hover), back * 0.9, Z_BUTTON, 1.2)
    Painter.rect(buttonPos, buttonSize, card, back, Z_BUTTON, 20)
    Painter.rect(buttonPos, buttonSize, Color.lerp(card, pal.Accent, 0.12 + 0.22 * hover), app.FarmAlpha.Btn * full, Z_BUTTON, 20)
    Painter.text(label, buttonPos + buttonSize / 2, labelSize, Color.lerp(pal.Sub, pal.Text, hover), text, Z_BUTTON + 1, true, true)
    Hits.add({
        key = key,
        position = buttonPos,
        size = buttonSize,
        click = function()
            Farm.leave(app)
        end,
    })

    Painter.rect(at(PAD, HEADER - 1), Vector2.new(math.floor(inner * unit), 1), pal.Off, back * 0.8, Z_CARD, 0, true)

    local y = HEADER + PAD - 4
    if hasStatus then
        stage(1)
        local statusPos, statusSize = at(PAD, y), Vector2.new(math.floor(inner * unit), math.floor(STATUS_HEIGHT * unit))
        Painter.rect(statusPos, statusSize, Color.lerp(card, pal.Accent, 0.08), back, Z_CARD, 22)
        local room = (inner - 28) * unit
        Painter.text(fit(info.Status, font(12), room), statusPos + Vector2.new(math.floor(14 * unit), statusSize.Y / 2), font(12), pal.Accent, text, Z_TEXT, false, true)
        y += STATUS_HEIGHT + 10
    end

    if #tiles > 0 then
        local count = math.min(#tiles, 4)
        local tileWidth = (inner - TILE_GAP * (count - 1)) / count
        for index = 1, count do
            local tile = tiles[index]
            stage(1 + index)
            local x = PAD + (index - 1) * (tileWidth + TILE_GAP)
            local tilePos, tileSize = at(x, y), Vector2.new(math.floor(tileWidth * unit), math.floor(TILE_HEIGHT * unit))
            Painter.border(tilePos, tileSize, 18 * Painter.corner(), line, back * 0.5, Z_CARD, 1)
            Painter.rect(tilePos, tileSize, card, back, Z_CARD, 18)
            local room = (tileWidth - 24) * unit
            Painter.text(fit(string.upper(tile.Label), font(10), room), at(x + 14, y + 17), font(11), dim, text, Z_TEXT, false, true)
            Painter.text(fit(tostring(tile.Value), font(24), room), at(x + 14, y + 42), font(24), tile.Color or pal.Text, text, Z_TEXT, false, true)
            if tile.Sub ~= nil then
                Painter.text(fit(tostring(tile.Sub), font(11), room), at(x + 14, y + 63), font(11), dim, text, Z_TEXT, false, true)
            end
        end
        y += TILE_HEIGHT + 10
    end

    for order, place in placed do
        stage(2 + math.ceil(order / 2))
        local boxPos, boxSize = at(PAD + place.x, y + place.y), Vector2.new(math.floor(place.w * unit), math.floor(place.h * unit))
        Painter.border(boxPos, boxSize, 18 * Painter.corner(), line, back * 0.5, Z_CARD, 1)
        Painter.rect(boxPos, boxSize, card, back, Z_CARD, 18)
        local x = PAD + place.x
        Painter.text(string.upper(place.card.Title), at(x + 14, y + place.y + 17), font(11), pal.Accent, text, Z_TEXT, false, true)
        Painter.rect(at(x + 14, y + place.y + CARD_HEAD - 7), Vector2.new(math.floor((place.w - 28) * unit), 1), pal.Off, back * 0.7, Z_CARD, 0, true)
        for index, row in place.card.Rows do
            local rowY = y + place.y + CARD_HEAD + (index - 1) * ROW_HEIGHT + ROW_HEIGHT / 2 + 2
            local valueText = tostring(row.Value)
            local valueSize = font(12)
            local valueWidth = Painter.textWidth(valueText, valueSize)
            local room = (place.w - 28) * unit
            local labelRoom = math.max(0, room - valueWidth - 10 * unit)
            Painter.text(fit(row.Label, font(12), labelRoom), at(x + 14, rowY), font(12), dim, text, Z_TEXT, false, true)
            Painter.text(fit(valueText, valueSize, room), at(x + place.w - 14, rowY) - Vector2.new(math.min(valueWidth, room), 0), valueSize, row.Color or pal.Text, text, Z_TEXT, false, true)
        end
    end

    local seen: { [string]: number } = {}
    for index, item in widgets do
        local widget = item.Data
        local fade = entry(6 + index) * (widget.Fade or 1)
        local title = tostring(widget.Title)
        seen[title] = (seen[title] or 0) + 1
        local key = "farm:w:" .. title .. ":" .. seen[title]
        local slideX = ease(app, key .. ":x", item.X, 12)
        local slideY = ease(app, key .. ":y", item.Y, 12)
        local width, tall = item.W, item.H
        local left = math.floor(viewport.X / 2 + slideX * unit + 0.5)
        local topY = origin.Y + math.floor((height + WIDGET_TOP + slideY) * unit + 0.5 + (1 - fade) * 8 * unit)
        local boxPos = Vector2.new(left, topY)
        local boxSize = Vector2.new(math.floor(width * unit), math.floor(tall * unit))
        local b, t = baseBack * fade, baseText * fade
        Painter.border(boxPos, boxSize, 18 * Painter.corner(), line, b * 0.5, Z_CARD, 1)
        Painter.rect(boxPos, boxSize, card, b, Z_CARD, 18)
        local function put(value: string, x: number, y: number, size: number, color: Color3, rightAlign: boolean?)
            local pos = Vector2.new(boxPos.X + math.floor(x * unit), boxPos.Y + math.floor(y * unit))
            if rightAlign then
                pos -= Vector2.new(Painter.textWidth(value, size), 0)
            end
            Painter.text(value, pos, size, color, t, Z_TEXT, false, true)
        end
        local room = (width - 28) * unit
        put(string.upper(widget.Title), 14, 17, font(11), pal.Accent)
        local head = 31
        if widget.Sub ~= nil then
            put(fit(widget.Sub, font(11), room), 14, 35, font(11), dim)
            head = 47
        end
        Painter.rect(boxPos + Vector2.new(math.floor(14 * unit), math.floor((head - 7) * unit)), Vector2.new(math.floor((width - 28) * unit), 1), pal.Off, b * 0.7, Z_CARD, 0, true)
        local rowY = head + 8
        for _, row in widget.Rows do
            put(row.Label, 14, rowY + WIDGET_LINE / 2, font(12), dim)
            put(tostring(row.Value), width - 14, rowY + WIDGET_LINE / 2, font(12), row.Color or pal.Text, true)
            rowY += WIDGET_LINE
        end
        if widget.Total ~= nil then
            Painter.rect(boxPos + Vector2.new(math.floor(14 * unit), math.floor((rowY + 3) * unit)), Vector2.new(math.floor((width - 28) * unit), 1), pal.Off, b * 0.5, Z_CARD, 0, true)
            put(widget.TotalLabel or "Total", 14, rowY + 14, font(11), dim)
            put(tostring(widget.Total), width - 14, rowY + 14, font(11), pal.Text, true)
        end
    end

    stage(0)
    local clock = os.date("%H:%M:%S")
    Painter.text(clock, at(WIDTH - PAD, height - 16) - Vector2.new(Painter.textWidth(clock, font(10)), 0), font(10), dim, text * 0.8, Z_TEXT, false, true)
    Painter.text(app.Options.Footer, at(PAD, height - 16), font(10), dim, text * 0.8, Z_TEXT, false, true)
    Painter.scope(nil)
end

return Farm
end
modules["ui/fonts"] = function(...)

local Fonts = {}

Fonts.NAMES = {
    [0] = "Gotham", "Gotham Medium", "Gotham Bold", "Gotham Black", "Source Sans", "Source Sans Bold", "Source Sans Light", "Arial",
    "Roboto", "Roboto Condensed", "Roboto Mono", "Ubuntu", "Nunito", "Oswald", "Titillium", "Jura",
    "Code", "Highway", "Sci Fi", "Arcade", "Fantasy", "Cartoon", "Bodoni", "Garamond",
    "Josefin Sans", "Michroma", "Sarpanch", "Merriweather", "Indie Flower", "Patrick Hand", "Fredoka", "Special Elite",
    "Legacy", "Arial Bold", "Source Sans Semibold", "Source Sans Italic", "Gotham Semibold", "Antique", "Amatic SC", "Bangers",
    "Creepster", "Denk One", "Fondamento", "Grenze Gotisch", "Inconsolata", "Kalam", "Luckiest Guy", "Permanent Marker",
    "Builder Sans", "Builder Sans Medium", "Builder Sans Bold", "Builder Sans ExtraBold", "Builder Mono",
} :: { [number]: string }

local ENUMS: { [number]: string } = {
    [0] = "Gotham", "GothamMedium", "GothamBold", "GothamBlack", "SourceSans", "SourceSansBold", "SourceSansLight", "Arial",
    "Roboto", "RobotoCondensed", "RobotoMono", "Ubuntu", "Nunito", "Oswald", "TitilliumWeb", "Jura",
    "Code", "Highway", "SciFi", "Arcade", "Fantasy", "Cartoon", "Bodoni", "Garamond",
    "JosefinSans", "Michroma", "Sarpanch", "Merriweather", "IndieFlower", "PatrickHand", "FredokaOne", "SpecialElite",
    "Legacy", "ArialBold", "SourceSansSemibold", "SourceSansItalic", "GothamSemibold", "Antique", "AmaticSC", "Bangers",
    "Creepster", "DenkOne", "Fondamento", "GrenzeGotisch", "Inconsolata", "Kalam", "LuckiestGuy", "PermanentMarker",
    "BuilderSans", "BuilderSansMedium", "BuilderSansBold", "BuilderSansExtraBold", "BuilderMono",
}

Fonts.COUNT = 53
Fonts.DEFAULT = 1

local SCALES: { [number]: number } = {
    [0] = 1, 1, 0.98, 0.95, 1.1, 1.08, 1.12, 1,
    1.02, 1.12, 0.95, 1.02, 1.04, 1.06, 1.04, 0.96,
    0.96, 1.04, 0.92, 0.92, 0.94, 0.94, 0.98, 1.04,
    1.04, 0.9, 0.96, 0.98, 1.02, 1.06, 0.94, 1.02,
    1, 1, 1.1, 1.1, 0.98, 1, 1.1, 0.9,
    0.9, 0.9, 0.98, 0.94, 1.04, 1.08, 0.88, 0.92,
    1, 1, 1, 1, 0.96,
}

local resolved: { [number]: any } = {}

function Fonts.find(name: string): number
    for index = 0, Fonts.COUNT - 1 do
        if Fonts.NAMES[index] == name then
            return index
        end
    end
    return Fonts.DEFAULT
end

function Fonts.scale(index: number): number
    return SCALES[index] or 1
end

function Fonts.enum(index: number): any
    local cached = resolved[index]
    if cached then
        return cached
    end
    local name = ENUMS[index] or ENUMS[Fonts.DEFAULT]
    local font = Enum.Font.Ubuntu
    pcall(function()
        local found = (Enum.Font :: any)[name]
        if found ~= nil then
            font = found
        end
    end)
    resolved[index] = font
    return font
end

return Fonts
end
modules["ui/geometry"] = function(...)

local Geometry = {}

local HALF_PI = math.pi * 0.5

function Geometry.outlineMetrics(width: number, height: number, radius: number): (number, number, number, number, number)
    local r = math.clamp(radius, 0, math.min(width, height) * 0.5)
    local straightW = math.max(0, width - r * 2)
    local straightH = math.max(0, height - r * 2)
    local arc = math.pi * r * 0.5
    local perimeter = (straightW + straightH) * 2 + arc * 4
    return r, straightW, straightH, arc, math.max(1, perimeter)
end

function Geometry.outlinePoint(distance: number, width: number, height: number, radius: number): Vector2
    local r, straightW, straightH, arc, perimeter = Geometry.outlineMetrics(width, height, radius)
    local d = distance % perimeter
    local arcSafe = math.max(0.001, arc)

    if d <= straightW then
        return Vector2.new(r + d, 0)
    end
    d -= straightW
    if d <= arc then
        local angle = -HALF_PI + (d / arcSafe) * HALF_PI
        return Vector2.new(width - r + math.cos(angle) * r, r + math.sin(angle) * r)
    end
    d -= arc
    if d <= straightH then
        return Vector2.new(width, r + d)
    end
    d -= straightH
    if d <= arc then
        local angle = (d / arcSafe) * HALF_PI
        return Vector2.new(width - r + math.cos(angle) * r, height - r + math.sin(angle) * r)
    end
    d -= arc
    if d <= straightW then
        return Vector2.new(width - r - d, height)
    end
    d -= straightW
    if d <= arc then
        local angle = HALF_PI + (d / arcSafe) * HALF_PI
        return Vector2.new(r + math.cos(angle) * r, height - r + math.sin(angle) * r)
    end
    d -= arc
    if d <= straightH then
        return Vector2.new(0, height - r - d)
    end
    d -= straightH
    local angle = math.pi + (d / arcSafe) * HALF_PI
    return Vector2.new(r + math.cos(angle) * r, r + math.sin(angle) * r)
end

function Geometry.clipLine(x0: number, y0: number, x1: number, y1: number, left: number, top: number, right: number, bottom: number): (Vector2?, Vector2?)
    local dx = x1 - x0
    local dy = y1 - y0
    local t0, t1 = 0, 1

    local function clip(p: number, q: number): boolean
        if math.abs(p) < 0.000001 then
            return q >= 0
        end
        local r = q / p
        if p < 0 then
            if r > t1 then
                return false
            end
            if r > t0 then
                t0 = r
            end
        else
            if r < t0 then
                return false
            end
            if r < t1 then
                t1 = r
            end
        end
        return true
    end

    if clip(-dx, x0 - left) and clip(dx, right - x0) and clip(-dy, y0 - top) and clip(dy, bottom - y0) then
        return Vector2.new(x0 + dx * t0, y0 + dy * t0), Vector2.new(x0 + dx * t1, y0 + dy * t1)
    end
    return nil, nil
end

function Geometry.insideArea(x: number, y: number, left: number, top: number, right: number, bottom: number, bottomRadius: number): boolean
    if x < left or x > right or y < top or y > bottom then
        return false
    end
    local radius = math.clamp(bottomRadius, 0, math.min((right - left) * 0.5, bottom - top))
    if radius <= 0 or y <= bottom - radius then
        return true
    end
    local dy = y - (bottom - radius)
    if x < left + radius then
        local dx = x - (left + radius)
        return dx * dx + dy * dy <= radius * radius
    elseif x > right - radius then
        local dx = x - (right - radius)
        return dx * dx + dy * dy <= radius * radius
    end
    return true
end

function Geometry.rowInset(y: number, width: number, height: number, radius: number): number
    local r = math.clamp(radius, 0, math.min(width, height) * 0.5)
    if r <= 0 then
        return 0
    end
    local dy
    if y < r then
        dy = r - y
    elseif y > height - r then
        dy = y - (height - r)
    else
        return 0
    end
    return r - math.sqrt(math.max(0, r * r - dy * dy))
end

function Geometry.columnInset(x: number, width: number, height: number, radius: number): number
    return Geometry.rowInset(x, height, width, radius)
end

return Geometry
end
modules["ui/hits"] = function(...)

local import: (string) -> any = ...
local Util: typeof(require("../core/util")) = import("core/util")

local Hits = {}

export type Region = {
    key: any,
    position: Vector2,
    size: Vector2,

    click: (() -> ())?,

    drag: ((mouse: Vector2) -> ())?,

    press: ((mouse: Vector2) -> ())?,

    shield: boolean?,

    wheel: ((delta: number) -> ())?,

    rightClick: (() -> ())?,
}

local regions: { Region } = {}
local previous: { Region } = {}
local pending: Region? = nil
local dragging: Region? = nil
local CLICK_SLACK = 4
local suspended = false
local clipPosition: Vector2? = nil
local clipSize: Vector2? = nil

function Hits.suspend(state: boolean)
    suspended = state
end

function Hits.isSuspended(): boolean
    return suspended
end

function Hits.begin()
    previous, regions = regions, previous
    table.clear(regions)
end

function Hits.setClip(position: Vector2?, size: Vector2?)
    clipPosition, clipSize = position, size
end

function Hits.getClip(): (Vector2?, Vector2?)
    return clipPosition, clipSize
end

function Hits.add(region: Region)
    if suspended then
        return
    end
    if clipPosition and clipSize then
        local left = math.max(region.position.X, clipPosition.X)
        local top = math.max(region.position.Y, clipPosition.Y)
        local right = math.min(region.position.X + region.size.X, clipPosition.X + clipSize.X)
        local bottom = math.min(region.position.Y + region.size.Y, clipPosition.Y + clipSize.Y)
        if right <= left or bottom <= top then
            return
        end
        region.position, region.size = Vector2.new(left, top), Vector2.new(right - left, bottom - top)
    end
    regions[#regions + 1] = region
end

function Hits.at(point: Vector2): Region?
    for index = #previous, 1, -1 do
        local region = previous[index]
        if Util.contains(point, region.position, region.size) then
            return region
        end
    end
    return nil
end

function Hits.wheel(point: Vector2, delta: number): boolean
    for index = #previous, 1, -1 do
        local region = previous[index]
        if region.wheel and Util.contains(point, region.position, region.size) then
            pcall(region.wheel, delta)
            return true
        end
        if region.shield and Util.contains(point, region.position, region.size) then
            return false
        end
    end
    return false
end

function Hits.rightClick(point: Vector2): boolean
    local region = Hits.at(point)
    if region and region.rightClick then
        pcall(region.rightClick)
        return true
    end
    return false
end

function Hits.hover(point: Vector2): any
    local region = Hits.at(point)
    return region and region.key or nil
end

function Hits.isPressed(key: any): boolean
    return pending ~= nil and pending.key == key
end

function Hits.isDragging(key: any): boolean
    return dragging ~= nil and dragging.key == key
end

function Hits.busy(): boolean
    return pending ~= nil or dragging ~= nil
end

function Hits.heldKey(): any
    if dragging then
        return dragging.key
    end
    return pending and pending.key or nil
end

function Hits.press(point: Vector2): boolean
    local region = Hits.at(point)
    if not region or region.shield then
        return region ~= nil
    end
    if region.drag then
        dragging = region
        if region.press then
            pcall(region.press, point)
        end
        pcall(region.drag, point)
    elseif region.click then
        pending = region
    end
    return true
end

function Hits.hold(point: Vector2)
    if dragging and dragging.drag then
        pcall(dragging.drag, point)
    end
end

function Hits.release(point: Vector2)
    local region = pending
    pending = nil
    dragging = nil
    if region and region.click then
        local position, size = region.position, region.size
        if point.X >= position.X - CLICK_SLACK and point.X <= position.X + size.X + CLICK_SLACK
            and point.Y >= position.Y - CLICK_SLACK and point.Y <= position.Y + size.Y + CLICK_SLACK then
            pcall(region.click)
        end
    end
end

function Hits.cancel()
    pending = nil
    dragging = nil
end

return Hits
end
modules["ui/icons"] = function(...)

local Icons = {}

Icons.MIN, Icons.MAX = 8, 32

Icons.SETS = {
    power = {
        [8] = "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAiUlEQVR4ASzKXQpBYRSF4dPpFOVwx517+ckIfJEMzgAYjGIGRsAEFFEorr7zvrUvnvbaq1XmnCu00UMKZruqLIqixgJDDII5kbsOpoQNPvDXm7zGxMflgcfBn6sv1y456PA88cM5mF/k2sGVMEcLt2C2uzg4Us6wQj8suXYnBw+eHUbYhjF3j3sDAAD//2aFwtsAAAAGSURBVAMAZVYylb++DecAAAAASUVORK5CYII=",
        [9] = "iVBORw0KGgoAAAANSUhEUgAAAAkAAAAJCAYAAADgkQYQAAAAqElEQVR4ASzLwQoBYRSG4TFMmpQki0kJSyvKmnI5VqzkDtyCW+BSjNUIO+5hSmMh433L4uk73/nPH5ZlWUENETpYwbS7r4RBEMToY4Q6pjDtPebYo4Rhgybs0T9b5BaJyxnDE3d88IV5Jd3PPRpSbnijwAOm3f3AI0uDB+cXuYNpd184nFgu0EYVfjLt7lOPMh60JsfoYgL7hcw8yhmOOGOJPcyUPCD/AQAA//8O8Mk1AAAABklEQVQDAJX8PdqMzIM4AAAAAElFTkSuQmCC",
        [10] = "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAxklEQVR4ATSPywnCUBQFxQ8KfkgLKgrZKVnq0iJ0684WLMECrMBSguCnAgtINgq6yEJF4ozEkOHOO/eE8MolnjzPy1CBJswKdLNfx0KNbhsG0IBegW7W5sOa7YDFEhbgR1Wm6HPcXWAx5DCFHbzh/+pmE4LQYoQc4ApPeBXoN/wIkcUWcocPWNozRTd7cG5ZTBEvUGe6uDBFN+tyTi3GiLcbMztgJrrZkCw2SJAtrMBbjpiim7lLLGYszrCBPqwL/KXZiXP2BQAA///ybJBsAAAABklEQVQDAJvWRwNzFswxAAAAAElFTkSuQmCC",
        [11] = "iVBORw0KGgoAAAANSUhEUgAAAAsAAAALCAYAAACprHcmAAAA9ElEQVR4ASyQPWoCURSF5w2RiFoEYhIbV5C0MV36kCKbiKViZ60uQXAdLsEdCAp2WlkLWqiDP+P3yRveN+fecw/vzZs0iU+e5yHygnZBvXsxkqSYUsKowiMU4QdU+yqZEqTuXGbQgBE8wwMYUu31v/DKht8o2jCGHeTgUu31Wxivhj8pDjCBPRi6RrXXd94wXGewhGMI4YI6WKuxP1KvoG74TOE3BtS15dUEFUn0CxQnwwuKd3jixgV2y2AHmb0+fMDC8IzCY/7RGoEKFKFiD57ifG54gzGEGvThD75BHaD+LecbwxmGF+qhU/iFDqj2buA8uwEAAP//qytsAQAAAAZJREFUAwBnJGUsBYW56QAAAABJRU5ErkJggg==",
        [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAABGklEQVR4AVyQq04DURRFZyZpEygDaXiltr4JAhQJaCzwD4AGD0j4A3DgSPgDgsEiqqsqWtWHaF2nj9u1mhnTyazcs/c55z5OEq19IYQKXORU1tLRqoFkGVLYoKAERzklvE0wV8aLEoRBDfEIp2CDnhjrPeHXrPWEKuIG9qEFCyh+Yz1zt5hVG+oE5/AOfZhD8Rv3EG9wBnUbGgQdaMME3NVVithcl1zDhpRgDLM4jgNrBn85We7N0CNIbRgSHICTUtvwj5aMh+o5gEO8gaJJsAMn4NwDu04F7Yl65rbRTRu8/xfCKZjYZdctwduDY7gDa7o2eP9vjF9w3vesV3AND/AMP2DNOOHo4kEfmC/gECy+JPY6r6yfMLJ2CQAA//9zgzLpAAAABklEQVQDACHSb1c3i/FUAAAAAElFTkSuQmCC",
        [13] = "iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAYAAABy6+R8AAABQklEQVR4AWSRu0oDQRSGZ3cTUQIpEtMI7gNYKNhpbWcllhaCVl4aiY+gj+DlNey0FG+VnXamsxGMIBICajL5vrBFSMJ8+c/5zzmzs7NpGPvFGFOYgyaoEz1Dg2IGM8IeJZiFDVBL+gUZXnBXgyqJTZvoFDg4Xai5vlQZznxSheIaHEIXIowu8w7GHthXcahBsgvXcAt/MLp+Se7gBnag4dASQQ2u4Bt64PIJap8/fet14kWH5gm+4BP+weYfVE8117fexs8dcic1wXDZ9E6wDao5YbDupfVtfsPxeD6xnCRJBC/kQwWHyvRYt6/l0CuGg1tonSv1ukPRHIrcd7HeoufFIc95SbIM+5DTWAO/iTvneAdg/QJtO+RRnklOYRXO4Ai8XvWceAVOwL5uyjG8CD/ePeYxPMECrIP6iDbhATr2DwAAAP//vK75gQAAAAZJREFUAwCWeXyO/OMeFAAAAABJRU5ErkJggg==",
        [14] = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAABYklEQVR4AWySMS9DURiGz73atNomFSQk3VjQxB9AiNFuYPcfJISJMBDsYvYbJHYzM1FJJZZqDFTiXs/T3A5t2tyn33ve837nnHvaOAz5pGlagY2MypBI6DYSiCAPRRghmIP1jJweOGcmwg8xhqLIoA5bMAo2W6Wnt/EXwAUidywwmIUTWAaDlL5HbwXnFGagYOMYYgfycA7fMPj8YJyBGbNVG2sYS3ALjSiKfql9D14H4xXMeKqajZ7by3hgordbgjYsaobBOTNm6zZWcZ38pP6Bjw33CFEjg3NmzHaP2sJ1gUmql0AJvtMdQtTI4NwEwmzLrycGrurZy/48vFMCnYxEj0wZvFkXerSxieHKm9Q5KBHUR4aQ6RKDeTBj9t1AG+MaPuAY1mCahnFBT8EqHIGZG2o75jhev7vuYTTAwBV1N+OSqvdG3YemPe6IDja/IA7BP4GnWETLF/UCDuAZvI/wDwAA//+/D1gvAAAABklEQVQDADh2ha6kG00jAAAAAElFTkSuQmCC",
        [15] = "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAABkklEQVR4AWySvUpDQRBG9yYGQVIkEEiTgAYL9S20EPUFLARrC0ELtfABfADR1j9UbNRWxJfQQhCMP2idGCWVmus51xASiMxxZr6Z2bvZ3VTo8xfHcRrKsAz6dJ+20BmmKQUZsFF9hIEF0FtzQevWkMP/MAMDZAWYhhy4wCB+CPTmeWLrBfozxCFZkcDCBn4ThiGCbjNXt75OIccCabeQJZmDGTiDKrSg28wfEU5hFuzPOuw25xHu4By+IIZuM1e/RLwF+/MOV0hKcA2NKIp+8ZoDHd/WGwj22V9xuIygPfHvGzS3+UnwAXpzwmD92QBKDnsYxD3m1+9RlkBvTthrDr+1pVF8cgVs0S03yR+g2c4Jg3X7jN8d9nRfyTzF5AqIgwPQAhcKXg26h+utvBBXHa4THMMYLELnERAnxqBf9BFZn0A8gbrDbu+G5AJ8jj6CcQaK4EJFdBdew1u3z/5mim15GF7BLsV9mIQD2IYt0B/ip2APdiC5Ur/s7/tBqIFNK/gr8E37BvTmq2hHUOOD9oc/AAAA//9l4hIcAAAABklEQVQDAKSSk8/bS49aAAAAAElFTkSuQmCC",
        [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABu0lEQVR4AXSSuy5EURSGzxniHoS4dCgISjUqEg+AjiegdYsaLS0NFd4BhUutQULi0kskbjOTGOP7jj0TJpnJ/uZf+z9rrb3PPjsVlfnl8/kGmAg0lEmLig1IjCEFcUiuQqcDxpHP4G/ObwNNEl2lD21nXolWgJ5UBK8drxfqmSeLF7rVYY7BNkyCDQo7YRoZ6/lsB2Mc6mgS26WaiSuvoG9wDDkoHXpHmO+wDNZU26CRyQz4nhvoI3xB6dB7wlyDGpiFRhu0EIzAOdxAJo7jPPpvBC+Dac4ZOgytNughqIVLSIdEwsgtZwnEOArPbGKuNd02aCLJ8cJfkog6LPQ8xFhPzDHXuMkGHoqTZv78dEgy0vzvB4wJk2FNYdE3J/fYbmsIrfXToG43x5Z9JXHV5CLxzK2ba82DDZ4xT8FDGURrCk2IiyN4nr45ozyw5tkGr0z24BO8CwOoN634OhQb1+P3wyp8wC682sADumWyDh2wCVPQRWGnGIO3cAttA+/CHZpN8Z5+c1f3tBcwjdUDYq+t1/uQeBFceQk9gU9r3YEH9o3h17hA58CVrlFvp1f9itidzaPmvFNsTfQDAAD//5N9zaoAAAAGSURBVAMAcQul640cMCoAAAAASUVORK5CYII=",
        [17] = "iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAB5UlEQVR4AXSUO0scURTH7+z6SISwiWwghEQSSPpAIKQIsdZGKwvRTmx9YGujhR9Av4BWouCz0G8gdtoroiKI4BME3+vvN97xgbvD/c0595z/OXtm5mouVLhKpVIeGqALtPkK0lCxCQVV8Au6Qese9/V6bMKv1UB9pBppAm/hHWgTctWQaWqJpyttQqKG3XcYhWFIi7DPl03fEBgCdd9iXcjhOGY9iUH4DetwC+XWHUHz6tQ7VZWT1JFohj8wBTNwAeWW8VkS06C+CVtnkwJOCxzBBJwkSVJ2khg/QTMOx9AKBZsUcX7CKhwhvMG6St7ghY15f1D9D/JFm3zC8aXtYK8hWz7/GZtT0LrHTZe6bby03lt2iJ6LyAcnWsEZAK173MeVPXLeJvuEHfkL1vOBCYGxbeoEjn0W9yFe6hrwrdu3yQGbLfgL7+Mnxw1pI4pvwIbBK+Y/4Ku37sAmPvMiwY/QDgWE2SOyfVox7tdU5wex7tQm58gWYA06oQ2KFNSCLzxowWNuofkONOqtO88xqi/skKDHeRPbDx79RuxXij9r4T8Y78OqU39ovZMQC1fcNqAXluAf+Pcxh50ET+kY1vgytgfUW/fwr4BuvuVLEn77EazNHHUX3zOxh50H4+Y9U5exLtwDAAD//03zb54AAAAGSURBVAMAbqa1/wTef/wAAAAASUVORK5CYII=",
        [18] = "iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAAB+klEQVR4AYSUSy+cURyHzzuqo8VUyrrSLtqmaXdtN9Y+ArYuK0R8BDuxIHFbImJH2FsKibC1IewsJBKXxIg743kmxyuCMfk/Ob/zv73nnPfMmwklfoVCoQoaI1UlUkPJRhRWQFdEjXzZ0kY8tQxcwSfG9zH9HWNNRB2MgTnmlhErWrERAR0WtOIdgVp8CeMTi75anMPQBjX4rA0ZhAWVOFugFz7DW1ZHQg9YU2kPV5TF8RM64QD64DhJkgLjE4u+Y5zmHDJa84Mxa6NqRBN8hDHYgUt4zYxtExwHa5oZqx8aNTDZgxU4i09GPrcYOyOyDNZYW2zkfj3ATQI2uWN8MPUVE1EjQ6CZ2mZbIQRr61xRjokH7t5NYJraBWopokamZq411uZsdE7Ig/Xm6mSamk/13ESdBhDm+raR4dxG+6g8fIcKXqU+ZHALN2zjNHIT4i/mfGDqG7N23yLFOs5v8A9K/hWIa+b8RXyFNcjb6AQxCx6oF7KeJ2bBpeN+NH3gvfuC1wtpjbUnNvJebBCYgXoYgF+Qo6gckki5PjBmjquxxtrLDPv39N3eJElz8BvU3Yz/weai9kswge8PzMMU5O3hijzUWxxHMAT9cA3tMA2LEXUH2kN3RYPoQ5pY+/g9wmGC92KBBAtGGVdhN6L2y2DM1fh/tIZwCPcAAAD//14IF1UAAAAGSURBVAMAn8C/ElIKz+MAAAAASUVORK5CYII=",
        [19] = "iVBORw0KGgoAAAANSUhEUgAAABMAAAATCAYAAAByUDbMAAACM0lEQVR4AYyUuU9UURhHvzcsBkTJFIZoFO3cY7TRykQ7NbFW8Q+wsLJQCyOx1MZWKzWx0MRWCEsFhJ4OKIAGKCCEbcLOcA7z5gXCywRyD79vv3fevDuFqPFXLpfroR06QK2vUR41h9Fo8330Daj6mPkrG8bOCZyAFlATWurgNLSCWkcur450VE5mAV4T3IZOuAoOQo4s45eJfgTrm9L+yjCCjXAdvsIjOA/ZqbEPrgSnHR6D9ddQ+6PAVHcqEngP5+A3DMM25K0dguatO4ttX9E57t5M4AF45AH0FywlSbKLHllpfImEdYPoHXgIzQ5rwfCjIfEzIhZocHfM/JXmF8haj8QT/p1y2EmMWzADo7AJx1nWWT9L8Q3YP5nPy4EGN9m1TKK6POEyjh9L1ceNSOscOB0R9hc9meBH3gPfItEHn0DVxzy0qn0FBy2S2oAz4PXxq8cMd/ck8xHRDfOcRh8zgm/POm9EGwH7Fx1WwhmDS3ABGiBbDoAtyAalSet8Hy/ij0PJYSsY/eD79gJtZVfjmPkrzXvFOqiwrxddscmT/ceZgqfga+JAi3APLwYZd5B11k9S0QWlAsf3Ac7hfIZ1+ADPoY1GL30D6gVvRH0nfUbPyFu3hn6BOed4MuxwiFfEy2vBW4Lf4SXcg5twF/S/oe/Auk7UPvsrF52pXp1VEj3wCobgCjj0B/oPVH1/UcxbZ/1q2l8ZRqGvQXXgCL47v0b/gP5Eqn9R4+aNZ4OIxx4AAAD//48nQeUAAAAGSURBVAMABJfM+4x84ZoAAAAASUVORK5CYII=",
        [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAACXElEQVR4AYyUO08UURSAZxYBcTcWoBS+oj/BR6cNWmhMtNBG4+sHaKelj0YbTSwsNFppo5WNj1gYO0ujkfAIlJBAQkMgLMsjMHwfc3bIJkwWcj7Ouec1c++cu5WkzV+WZTUYCGpt0pO2DWnQA48CbcxyaWnIW3TAbuiCNMq60PsD7cQYmGNuB7FCioYkdOLth1twErqhKTaX5tqYOTdx9EctZpJvGYdP6cPzBO7DFdgFZWLsKsEHYM2+6JFUMFKcHvYd9EWYgY+wAmVi7BNBc61xV3681C271aMEdS6iH8MYrEKZGBsl6Mey5ja2PTpt6NtdxrEXPsN/aKRpmqG3lYg1CA6CNdZewq7ZsIpxGtbhG9SjALNcIqdOxnew9gy6akNn6xiLWZgEt4MqxGR9ol0EMPRNoK21R0+zofM1T2AtnoxZyBLW70AbM5fIXWNlrT02G/rFdDpbfnHiLbLA6mGgjdki1lhrjxXf0MOdJsXb0MsYOWMsc+EtVmEucIt5gP+R24tp7RS6YUMP9g8Lx+cc2jNF7Uj2kGWNtfao29BtfCHg02+gj/BkzwOzXCLnMBnWWPsVe8GGyxjO0w/0AXBYD1Hgxfd8cG0J/hQ8s4N4zbXGWnssVzgbR8Gv9IqEEXCeXqKPQx/FVegOnFnv/Ali5pg7jG3tvL18wwTDV3aevOz/SPCX5D36KVyDATgL1+EZfIBT8BesmYge+a8NTsWte4fvsngD3tELaEfG9euwz6ONub6HPQ7WopKthjwhAwOO0FuiXvjn6F8wBG7tJ/oF+Dv4Dj1tDRT3fgMAAP//sGRbSAAAAAZJREFUAwDsV9oBT+iw2AAAAABJRU5ErkJggg==",
        [21] = "iVBORw0KGgoAAAANSUhEUgAAABUAAAAVCAYAAACpF6WWAAACdElEQVR4AZSUOWtUURiG7x0nmuiEJIpio/4DNxTETrBxAZdCG0vtREXQxqXUwrVSUREUBLVxKVWwELSysREbbVQiSUhIyEaWm+eZ+TLDzXKHhO/Je863vDkz99yUkiY/WZa1wAY4CmpLk5GkqSkGmhxEr4DqnuXikTPlJCmUgzTGyugaWA2q+4SehXppSRonpck/0E52Z9CGFoX1HTTY3x7zbMOURMquAgfgEVwHh5BFo5WKfQ9R5yrhUz/pCgrb4Sp0wgeYgKKYpPgRusA55/VJSrgvI6nRebQDXsJjGIGisG6f/c4536mf36MfYzfTW+AX3IO+NE09CcuFI+p9VO3/jTqvT6umfpd7SXriN2hPDLAsjujroes1OK9PRVMfyGaS0/AVRmEpYf8XBpzXp01T7916klPwF+Z+bPND5AdBdc+yHvb/Y2den7KmXiePblKo52Kc3Vu4A6p7lrlwTvRJNXUzQMty8CmaY1kP63/YPQfVPct62O+c8/1kp0yMsfgBnngbWr1raDV4GBlMwjioWbXQ+GX/VrbO/0THNB1m8RmMQ/zq4K6ZZ1kc0ecpD0enPsMOe4l9g/5T2AX7IPcus58XYej/iv0UnetG38NIiY/k62jiPgmvxUV0D3hiv3iW+cDQvCe07wJV5x6g3fp5UtaJd80n6yvny3CD5CnYhEEXrIKVoPqub6R2Em6C/S/Qd6BP7R8K7j5Rb8AtCk/Au3sWtfkSegKOgHoZfQXnwBPbf5t1f/jUTEkkJLzEvazvwhn4BuvgOGh8LfQYuhas22d/b8yTThqm7qLgiT+xPx08RX0Nv4c+Q2dr9g3EHOlazAAAAP//760NcAAAAAZJREFUAwAfStsAodk4ZQAAAABJRU5ErkJggg==",
        [22] = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAACtElEQVR4AYyUzYuNURzHz3MzbnNnBrMao5FSysvGhtKwkLKTrViwYssCkRTlJS8LNmKH/8DSS7GgRPKSbKwoikQz7lwzI4/P57nnOc0zr3f6feZ3zu/l+5x7nvOcWujgL8/zXhiO9HbQEjoSRqgPrkYcM5zfZgizqgxqkNkafTfjFZHuGAt6SLXkkyVhChSskxmEtdAwhtd8yFQKURINsHaQ2jpYQyhUtmIxkTVwE+7ABkgPZjzdzFljrT32qlHUmfTpi5gNwDnYDH9gBBYya6y15zzFA6xarVDuTw/BA2DBF/wx+AT/YC4zZ81RCr7CJlCjB/HMFXcRWAl7wOJL+HfQyrIsx89qMdciae1FvL1qqNWlsC9gB4ml8AIeQzM2MpzbYs0YFU/gJSyDndAohbcwyeARjNLg0xkubLH2N5X24oLbWQh7xFYT8Wd/wE/AdPNBfwmKY4YVG2dmrxpq1V2x+DUZ/EVBpZEVGR8l/iriLzLGNJk9P5kZX4KvKeqkXKXn0C0hVzGP1UEi4phhxezxEBh09bnCk8w8YiZXMS7OIT4Zq56AH5FyESnPwB571VBrUmGPzBuSBofxUz9lpvObZ5YKT9ZWvBqv8S2Fmwwegiv3qLj5bgmhjsxae+xVQ62mwu6JK36GjGfZr85Ps9wzwrMbq7XGq+A4FfY+xb+F8Rr75hv1hVwj8A22wSkYojFdkcyTEfcm9CodInga7PmOvw4jarpixsEX8p7BWfAhu/E3YDssR6gf+iL9xLxazVmzi7k9Z/BqqNW+NnmCR869vk/SrfiM3wi34DacAI/aIfxJMGbOGmu9iOxNV0G54oC4W+KH8IDG/XAXXMl6/D44AodhL6wDc97F1trjh6MGqdBecTHiXxT3UvnI9DIocgF/D55HHHv3+rArxKwdi71M2/YfAAD//+BGU2MAAAAGSURBVAMAKkv5/QNQkkAAAAAASUVORK5CYII=",
        [23] = "iVBORw0KGgoAAAANSUhEUgAAABcAAAAXCAYAAADgKtSgAAAC2klEQVR4AYyVO2sUURiGZzZuDCHEJChR4i9QQbRQrBQrsdXCSgVR8FZYCaKFpZaijYo2WigKinaKgiKYpEuaXEiTVLlAIIFNNrfN88ye3WRCMjvhe/Oe7/aeM2fOnC1EOf4qlUoR9IBzQC7maItyiSPUDC6Bp0DWZ5htecVdaQ9Se4GszzDbUuI8chNoB/tAG2gK7TG8FZF5YJ319tXqKY82toUiE11Eb4Fv4DxotELz1n2n1r6uoIMbxAnEeO3gKrgL9oM9wDiUafZ1U2HfFdgnSHYk+UegBZwAN8Eu8AF8AUsgy5ZJfgUfgX2u/iTj3SAqsGoncPY7BOS/8DMwG8fxKryjhfwsBdb/ge2/LaursKs+TuAYKAELZ2hcYdzQQt00hc+B/eqIFsVbCZ4Gvpz/8BBotB2UpMx6+3qJqnMGblXclR/GqQCTC6zGMW7dav5WTgpCvat2cdYcIpGs3Jl82wbHCW63He79PLka9HFTZt8EEXU8bUVX7nHzTROPLDDpeDPKOJ6I14H1GabMPk+PQfVixV3FHBEn8SPyY8JNmU0jRF4AWZ9hyuzrJKKOequKu4qxEDwCJ2cUrpt7CpZACciusp4PAy8z+xVXr6y4L6KPAht8y52cUR+LUD4L9T61/Wt0eTBKii/g/AIzwBvvIuxl5AoYZhvC1rVRdQEcBOr8hksFHtP9m8R5D5z1OnwKOIGTM9zeEDavsPU3qLJfnUl0V0wSi9yadwzcng7YH4WzsFvUjIirw62aPnCPfYHWPSFjXz+suHrVK9dZCE6BR2AQeE69Bh4wPgq6EfM67ZD1gXHz1h3At+8hPBX0quIEND9hj5lX508CflyX4U/gDXgM7gP5LWzcvHXWe/ENE1cHijbEmc3TskjUCe7BrmIA9vx6sfmive9lLybj5q2zfpTactBhuElczwRwZm+5z8SuAe/ol/AP8A/Ir2Dj5q2btg+4QFJVWwcAAP//ofhaCgAAAAZJREFUAwBJCf39PbFWBwAAAABJRU5ErkJggg==",
        [24] = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAC+ElEQVR4AZSVSWxNYRTH732vqqMImhpCNIaNFYoVYW1LDAn27FhamBI2RCIxRkiwIPZWrEhMCRtDJLYNmhraprTV9vb3u/1eX7407X2vOf+e4Tvnf+43vlJSw1+WZSloB90B2mkNpUlNDSCSrAN9NUDbGO7cUk+DRVCtCNCuvwHTdyma0AtBGyhDqEgm/CChLRJzgLnWWJvHLRImq010oAVnK7gGjoBmUCTmmHudxG2glYZyYSbRHjQR2QSugF1gB2gARWKOuTtJtFYOuXBDAzqatIzIObAKfANu6DC6SMwx15qVJJ8BywNnUsJICbSCw2AD6AcnwTswAorEHHOtsVaOQxTJmS+RX7+UwF5gs/vo12AoTdMMPaeEnCGSrHmAdl/3oDv5+AYdN2k7gSXgN3gMBkMhZrGE3EEyHwE5vCfuS3OlwWYGtN+gv4MxUJfQ5D8FP8BbIJecLRqNBFYDl+MLepRkbcxp0RfjRIS2wI1kFO8zcEzORht4mRYQVH7xTwJUJBb0EvkaoG0MNxJrXSKDcpZtYGJlSeYx4kajqsKMJvAk9XSI3hAjHIm1chiUM7OBhmvnoOfYU2VCBAg97z0Ee4KNOUOslUMuOcds8I+0j0DJN4bjZVw/AsSZiILBCTU+Nd0h9Ak9LJENXuB4Ydajt4D5oF6xxlo55HoOwV8b6HzA8TaadAw7vyTomoSvd907ST4KPJVyyTlSYspu4AADN4CXZSP6OOgIhZizS8jxkp4gy4dOjpvYA3I7A+zEWbzCuAvc9P3oU6ALAn8ePcq4VSFeBu1EusBpsA9Yewf9EsiZv0WJnQhUZuF19zz7ntwj7iO4BjKXbTFauBxrw5g55lrzkNj012NPNdCgid1/Yp8Hl4AXZh3ar3uC9ssuooUzNeaYOV7Qy4xdAH2BCzOpNtBjwPekD/s28FfKh89GbfiekN1o4VH0Of6Db465t7Ajcvy4gQGaOFXf9ff4fuFB9Fng9J+inwGX0R+WA9jmmNsfaglVZRIAAP//jdTC9wAAAAZJREFUAwB42A8Hgo8O+QAAAABJRU5ErkJggg==",
        [25] = "iVBORw0KGgoAAAANSUhEUgAAABkAAAAZCAYAAADE6YVjAAADNklEQVR4AZyVyY8MYRjGq1rP0rMmZLbThMR24yKWxB0nJ+JCiIMt/gIXBLGF2C4SEnFwQuKAcCERFyIRF+FgmQmGAzOTjmGm/H49X013qzHdo/M+/X7v9rzfVlW5qM5fkiQNoA+sBeqGOkujuptA2Ay2gwtArc2wtsymiTNfCGUPUGszrC2ZJmxFHrQG5CsoYsbmp9DGFUXk/qumFLegNPCP5EZ0L9gPdoI2fFNk2BkJ8TYC5lvXi69qlVNNCDjrbpKPgL1gB+gDMzYJcSdmvnXW9wQ+wtHkweOwWSeefWAdcCb30Z9AAmYS459JeACss16ezsA72YRgE1gJtoA54CY4BYbjOJaE4fQS4sNET4DbwHp55JM3yoVu7QRdrnv7mvFJMATBb3RNCXlDJB4H1ssjX7v8bpOHvYTgCiDpFfQghb/QdUvIH6TAennkW4zdaJMCgzXAh8vZuLdF7P8R6x5S+BXIJ2/BJhquJCbwEvxgVuPo6SQ9n1RX5YS67zjlkW8p42abpFcXO/rIn0tFZcTGI3hTaGNmxHp5DPhI5G1iR6+es/Mc1Cb8DbfiOs4bQK3NMCPWj+FVyxvbZAKHV9BmHYz1oTJi4TO8h4Bam2FGrPeZk0/eCR0mvwupi9BNXDsTGJaF/U7ATzAC1M60nMAo1PlsyIMnes/fmE1c9gsM99iDms/YZaJmLdZZ70WS7zkMxbTJEwyvXQt6M+hgVsYY1ich34d6ExXyyPeUcTHH0r0NXzBuAc9nI9pXQguFmW0jlpGQJ/Eqgta7Cl9NvtPG09mOErwG3gBncxC9HPhdSXMws0ID461ElgEvhZfnLWP5RllEYkLEwKvrIR0m+A0sAOfBBtAFUQGUcrFLog18W3ThWA/8LHse1tvsQ+CNKgu9AI9IPgB8vfSjz4DTQJJ+SP0gdavxGddv/GywrbP+MbZ8qKjchK6eh/f6DhE/Pt44X9sSXcR3F/gQXg76HvoSMG6e+XuwrfcTIR9mRROtikauaBu+Y+AV8CDnod331UHPRXtpjB9lbL4rqGqAv7wSDUEjHzqXOoDta3srejc4B7yBfjG9Odq78Bm/ih6gtggyD+kfAAAA///wUTa9AAAABklEQVQDAInjHAkSPBnfAAAAAElFTkSuQmCC",
        [26] = "iVBORw0KGgoAAAANSUhEUgAAABoAAAAaCAYAAACpSkzOAAADa0lEQVR4AZyWy29NURTGz72tPkSRtkSLSggxMGDAEAn+AO9XYiTxSBhIhEQwkmDOyEAYCCMMCGHChCDBwCseHYgR1aatPlSv32/b93FyxbnarO/utdf+1rfOfp3TfFLjX6FQyIEWsCRCP1djelJzIQTlzqG9EKFvjG621UxESu5c2nkR+sboZlsVkWXJgwbQBOoqJFwm+ZUwFihygTmNtHJCvPiTCkRCC4OrwU7QRqyyGKFqi5w2Rswx1/1LaZc6kPWnQt4AzoMjYA2oB1kmR6455yCvB6liihML1szvKnAczAQ/wHswDrJMjtxBiOaeoF0JmkCwUIjZ+ESdRI6CdvAFHAavwRjIMjlynZG5ahwjaXbULh3vyQS3gUVgCJwFj8FgLpcr0P7TIsfZPIJ4BqixkHY7UDvxhLnZrQQ2AWf2gPYWGIgCuNkWuQMwbwM11NqI38qs6lw613EFgVlgBFwDfSS67ri1W8zpI0MNtdRcTr/JQh6CpXQawDfwBEiimZCZ+5RMtdRcht9sITtddLSP/AzFJ8NNmXvlLCthLEWKuZ7YD3FA7QYLCe+P8e/8/AJ/Mwt8ZqASxghVmRq9MTqNNm8R2qSY4MEovVYcqICcbvq7IvSN0a0yNdRywKLheHsHvhoBHaCeUyIRt2wsicvksX1LVLjExuiWLeZ64tRyQO0xZ+TmvSPi082n9WYXn4Zu2SwGxiOqikSmuTPw1VJT7REL+ZRezmEGp4C1IFwy2omYuetIVEtNtYcsNErwDXgBfBpvcwdLMIn+f1nMccl2kKjWS1q1R/MuA51+cBl4LBfQHgDeaNcaN9soItc3zEHYLptal/D7reGM8BOneB/nDtC28LMftCPgR7DqcDAWjHH/l/Au+iLdR3Az0O7yo6ba4dQlViToufeF+BzfRJNO4S8G0xFMfTnp+55sdAzIkevDmes2nCbeG7X/FCJgMffqE/4h4CvEpfCleJW+r3+/VV0U6BTEvPF+c/y0yJFrzjPG1OimiJp0k3Kh0EsSj7rfFWdzhZhvYzd3L77rfY/2eoS++7qHvt8yuebIfUUsLBltsOIehQ5PUAASvPUnCe4GN0EPkOtm+50R+sYcu8G4XHOcyTA6qXsmEU7aIP0kosBDWpdmK60iF2kVFfp+sh2TI7cn5kJL228AAAD//1W65eIAAAAGSURBVAMAywst/xZTWOoAAAAASUVORK5CYII=",
        [27] = "iVBORw0KGgoAAAANSUhEUgAAABsAAAAbCAYAAACN1PRVAAADjUlEQVR4AZyWS2yMURTH52tNO6qvBapBPTZeEULjuRN7sSIReywkFiQWlgiCRIKISIj3Rlh4bcRjyRKRYElUq4um1Qc6fr9v7gzT+Zj52pz/nHvOPed/7j33zp3WZVL85fP5LOgA3UCdTZGeSVUM4hzYBS4DtTbD2iRtsUZoV4HZQK3NsDZJLEaL6oEtmzivXQ91EdqYBSGnDpjnfMH51+fE4IhgW9NFzGZQ87mQ5/l1kGNeF3YORNglKSuG17YsQV8AZ8BuoA9VVVzkHqLMM38x47LcUjFW4crmEnAcrAUt4AeoVfIEjgHzzD/B2B3KyzBTuI0Usmgbnn1gNfgF7oFLYATUIsYZf5dg8+XZy7gt8BeK4WgArmYLegp4Do6A3iiKfqKrSojrJfAoeAHk2YpeB+J2ensiDLe+M+hvaFvQA0GaNmZCfA/5HoU8Rd5mdhfZPns6h4D1QHnAxzswCiYj5pl/n2TPUd55jLMW8xatwZgG7Ptj9BCrNJBhOgl5Q2Q9AhaWt5txzmL2cxGGOxxAvwbeKtQ/pdpCzH9LtnyenfyNFrPITCY8O/s9zOrGsZPEyzLIhCtXa2OWS8gfxvsVyDsDHbdRw9uInXFF/1u1BFcJfAjU2gwTRR7b6KT88QVxF65UZzMf7haVKCY/Ycbvo1obM1Hkkc9J+cd1uJvPeCzq29bONU18SG0PsM0DQZtDarmE/Ha8s4Axn9BjFvMGFi9FE05vpjeU4aTFfB+JqTC4mTfoEYvZilcYfgm9mb4iLazOOdzpJOS1kiWPfPK+xB6tox3eqD4MD903bQPjTaCJRC8Pw9okxNsd8/0yy+cj0Wed4uo9wOtQfgF+CQ+gl4KK3yR8iRIK2b5lBOwH8sgn73fs0kPsG/gex1lg4YXok2AlsKWJF4a5WCjkvO+g8adwmi+PfB+w5S8UY4t+J5y8zcRN4DmuQF8E20AnhK2gAcTdUANtz6eTmO3A+OVo8+WRr/T0xYlM+mLb337Gx4BfWLc+n7E/Ndr+N7URewFF/JF1zvPVfw3/YaDPRV9hLE8/G5EXM1PYWTzigwkvS/E36RCuj8AW+ZAeZOxqn6LFM/QtoN8fSuOMN89CFb+FpZ2RFEso6A4lsjWnmfBR9WnyHfVspuNTa+t33rMy3ta5IxdO2B+pKOYUBd26D60rPYdvB/CfGQlvML4D1Nr+U+T8eXzGD4Z8zHL5DQAA//9xgluuAAAABklEQVQDANx2M/WzIBoOAAAAAElFTkSuQmCC",
        [28] = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAADvUlEQVR4AaSWTYhNYRjHz72Xe2WmGTOZKRMKCWFtRZSF2FgoS8pXKF8rxQILsRBlZ4OiyIINNpQSKx8lWRCFKDM1aprBjBnX73fue+6dM2fkXKbnP+/zPh//57zP+5733GLUxF+1Wi2AVrAwQL3QBEXUVEGIS2A+uBygro1pPmm24BRol4AFAeramOaTSQvSLltXdJxAY/tckXlCXVs9zBwwWW4cY1KsJP8I9onbmS8C3czLjLkkxHYTvBi0M5cLtSGpgiGgE/cBcAucAa0grxhrzk0SDoLOwIlak3pBHOqubA+u3WAWmAe0M+QSY80xV469ZLlS7ahR6pROx7IO7AQ+6SfGk+AbyCvGmmNuC0k7gJxyo4aCrM5e92Cxla6yH/0IeAh+gLxirDnmyiGXre0JNeor9Ak2wepxH2G8BB6AwUKh8Isxl4TYQYLNvcgol++q3NaIPL72tw3nRlABH8EVMBAIUPNLyBkg4yqQS06521hl0WIaluGcA0bBHdBLojpq8xJyv5B5G8gjtzUqScHlOKaBYfAIfAf/K3I8hkROuesFfbFn4/Dg2PM36I4MGalicU8dRaJjzshPLK+BXHLPRS+7Qq8nT1MBg081REskYpqRMSwfQG+AujamaQkcviZyyu05KVnQyKRAPGdzDdA+Ee7HC4zbA9S1MU3LOI6YE681qk5M+BoM9roDXTtDWnhq2ziE9UmA3dDGNCNyeE3KaTHfyzGNbupbwu25J3YpuvvKkBWLgtGAPxUzUQ655JT7HcZhC3o7PGdir3WuQW8Z1xKmzUnI9WpbTaacclsjLphUf4nTvVvL6O0wlfFfxVw55HJRryByhSNFWmNbvI5uYPRUzWT0i+GnxRPMNL+wOnPcO78Ucrnn12HwmowPDXpkW++ieBhc5Qb0LaAjEKD+XUKsh87c9WTI9ZRRbmvULm9W6bvkKTqN8zPwovXL4afKr34FMpNxZUUfcK/82u8iwlw55DrFvD/UqBXEoHha3djjTPqAL+ohxrNgBeiC1J+FZcZSgLrfzi78xpxj9HNkrpfDMeZyyo0aNQryBMleenkfxvseeLRtrzf/eeZbwSrg3evduBJdmz5jbKMr9QaSw1bGe0dcLJ6gWPEfRX1B/bR4y3ub3MfuprsvFj7BXGIfSjJ1bfpm4DP2HuM2YEzmE5cqSFAUinpqnzH3d8k+Rh/ANnsruWrfMeFqtOmzwH5izTHXlbkATA3JFNRF0SrwVCVE7uVmfEfBBXAtQF2bPmMs2mcucIsIS8tvAAAA//8iiojRAAAABklEQVQDAL4GSO9HVxSRAAAAAElFTkSuQmCC",
        [29] = "iVBORw0KGgoAAAANSUhEUgAAAB0AAAAdCAYAAABWk2cPAAAD5klEQVR4AaSWOWgVURSG52UPCQaNEQJuEBViobiiqIWCiJWdigvYiLggWlhoY+MCFoo7KqgIgitYaSEqLpWVGy6tEgyoMQvRxBif3/fezIthxjAvCefPOfcs/5m7zNxXEhT5l81my0EDaAbq8iIpgqKb0qAa7AC3gNoxZnoZTtMq6JeCiUDtGDO9DKdpKfRl/8Axw/QSa8o+ZUA1GAvGgMoEukzoi3Q4DALzgXXWyxPLGdSUZBNqYFgMroPzoBF/qtmEeY3UXADWy1OLX15ceSk0DQMeioWEjoP5YDaYAgYVMf6fmNdEcBawXp4F2INmXGhKwKNvwSHsSeA3eAxegz8gjZj3hkTrrJdHPnnlJxTkXxlmafNReHaBacCCe+j9oC2TyUiGObSEeW1kWXcXLY98u7Hrwj75pjgqgMuxEu0TvUcfAK0Q9aFTS5jfSoH1H9DyrUDPA/YJSuieYeDhWYN2tt3os+AjBL/QRUtY94nC00A+eVdj19jPZfVkjsOxCGj7dA+wf4CRiPUPIZDP99qT3MC41Ka+hzMY+DTOzMROnjbVPlKXKGF9J8FHQF75Z2JXRk2nMnC9Db7E7gVDSTYMRjocxpQ8L/DKK799ck2dusvr0nraWkhSoxLFmEsXwXFiIk5jEZ/89ilzph4kT5jaJ/fp1NQkis2uEHkG1I4xE0WeiE/+XB+bGuihxD004EnWjytRzL1NZBNQO8ZMFHnkk1d+c7M6fQ99r/op80m8stQM48IB6Qfd4DtQWxdPzHvcuojPPPv02dTp+zFwsz3Jc8lXo0Ys3rVzYJFPfvv0Rk1fEfgKfLJlaK8mNx5zeMJHwPrRVMsn7xds+/SWsEROux3HfeBSuxyrsGNXEr5UQkP3sJZkefzoy+sHp91+zpRY4KfqJsY34JJsRk8HVSEBZlEiRzMVW4DXpbw3sO1T+OD7JG9xXgOesAnog8ArKXVjHxDYxDrrx8PxE8grv33yTZmyr00XQX8pPEd7vD1QJ7A9CF5L7gvDZKGZ8TqiXvwn0d4q8sh3jnFX2CffFEeAw6/HZ+x9wE8hKvC6u4SxDTRBXA/c60p0BVA7rjcOzLuMtiEqkGcvhlek/JjBQNPcKAh8fd5h7wRPgGOXaA/2HXAYbATLwRKg3oD214Fx88y37il+eXKvCXZBooOUczBbl9k9df234zwF/HZm0JPBOuBeXURfBWobrsc2Lp/51jlreXpCXlLyYlLeCv+bAHxSi4/h9nI/g5bAq8oH88bwwKgd6zfupW2+dS3yAOOUD0isaRQi2T3oYOwPraNoybaijwD3zROpdqx/LX7zzO8I63HF5S8AAAD//29ZLW4AAAAGSURBVAMAkYlS4+z0QbQAAAAASUVORK5CYII=",
        [30] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAeCAYAAAA7MK6iAAAEDUlEQVR4AaSWOWhUURSG34zGmIWYxSaJoJULFjYqWmingguiFjYqKFioKJYqggo2KrigYqGooI0ouBQu4FLYuFUuYGHjRopEkpAYTUwyft/MnSTDvJA3yXD+ueeee87/33fvfUs6KvGXyWRSoBrMDNBPlUgTlSyMwGQwG9wM0DdGN7mNR7gM+sVgToC+MbrJbTzC1ijkVQp9Y8lVyYwtYO/KQA2oBeUg8R6aC6yxVg4nhlShFQlTNIWUJnAYnAbzQGwx8Tgzdy4DZ4AczYGT7rAVCJNgUSPDp8AOsAqsBi4pTSIzdw2ZK4EcJ2ibAjduzoaEGZhEqA4cBCtAFegCb8AASGrmviPZWjmcwAH6dUEDNyq4nSqIrAcbwFTQAg4Bhf/RJjVzX5HsBcghl5xyq8FQEGYmLo/7uotoDXC2J2mfg+5UKjVIm8hCbjfJL4BbJpeccrvkag1dsTNZR+Is4FIpeA+/KxDhJrdQo+Bdqp4BOeVWQ60ozdWmGHAv1tIatOAqfgcEFuCWbqG2g8prQE65PXRVanq4PMnOxkcfOdF7/j6AXjBRk0MuIZcaapUpXE5kPrD1YHiYephxhtiELHD0QPIayO1By2op7BU3M+Cm99F+ASbRxJoT8rDZirwfm0xQLjnlVmMGsSkKe/9Oo6MvSTu+LU2s9RP9Cn4F6BujG2ty5TnV8ISndcx25rbCw2Y7GryClwzuD9A3RndUG8mZ1VLYk+vpc2ZefQPltjTFxr6Z5yl9yqgY65aTazq5ttaqNaCwa/+NAWftfvuetSUUb4qDvgDJ4hNzUbk8zb581PhOuE9hj/wnOn+Bg0tovdccwx2/cb/KUQnDUuAE1PDW6nXAg/GDgY/A2ftKW4jv7UUzIZNjEQyuotxq/KTfn2a53GyfrQ8IeM9V0+4EDczYfcEt3UKt50UuOeW+D5PP/oxXjB+5BA9xPgNPoEuzDd+viHwO3WQWRGvJlkMuOeV+REytKEvKVXuy2wieA546n9178H2d+R71xqc7tiFqrqKbyJZDLjnlbgtaOWEStD/8+Vbyoe7S19M/BnaDRggrQXai9IvMMeBB8gvGmiMkySHXdXy51cCNhoWZiZvfSfQCuAV+A/fIB8UVfF9pfj/VI+BHfAWt0FfAx65vuMvkWmOtHHfonwedQQN3hLA9BjzhLvlx+peAj0VfZ8vwLZbkKP52sDFA35VxzEkvJ26NtXI45hLLzVDOipYOcW/yVobPgr3gLXDmnswF+H7ASeaeCX3FHTPHXN9w1srRGjgpHbYiYYdIdHY+2B/T3wL8WHtC6zeUtwVu5CES+sYcM8fcrQStbQ9cdAstVtgUCgZBnvA2sX1gM/Aj7iLtjQB9Y455lea2WAs8N6QV238AAAD//yqFU/wAAAAGSURBVAMAH3Bj3Vxb0voAAAAASUVORK5CYII=",
        [31] = "iVBORw0KGgoAAAANSUhEUgAAAB8AAAAfCAYAAAAfrhY5AAAEMElEQVR4AayWSWyNURiG762pVW3TqmhCUkVYEARBSIiwYCMhMSyEYIGFBDvzEOPCsBHCQiLEEERiYUokbCzszENYGGpOaWmq2l7Pc3vubZsO+t+6+d583znn+973/Oec/9w/K5bBL5FI9ADFYBDQ98iAJpaROEK9wRpwFehtE0azTMVzkJkLhgC9bcJolql4N2R6gZ5Ab5swmrUpzj5mgWzQB/QC8Si05gPrrJenTZ1WnRT5FAWIzQYbwVjg0+E6beaPI3sTmAUKAi9hk7UQJ8F2PsOLwCGwHKwDUffU/LXULQOHwUKQH/gJG02xZMSAS5tLI/XEJcS+Qp/wDSCKmf+RAuvlSa1AbtBhKNbiVfPwDKfXpS7G/wbXwQFQDaKY+QcpuAHkkc8JyK8O3UE8zMbl9p0tZcSZ38NvA+XxePwPvtMW8ssp2ALkkU9e+V3+OP3pJ3c2o+mYCYxd6t3E7yCqxUe2UPeewl3gM5BXfnWM0+LeUPNI8OldpgvEj4ExLmOzXp7zMBjLr456Md9nD52v1jQSfEV+4C+BKmafwGdsof4nBJeBvPJPJXbpsxR2CYbRUQTcm4f4t6AO/A+T5w1Ej4D8ffHJg5cSH0qHk/BgmVQTZk131yzw1MDiQ8mvTlJP8e4M+Cp4szlLT2k9fR2Z475Okupt/ytfXvnVUa+74sK98Pi7xxK6PB2RKXiahAdAb5uwXZNPXvnVUS+55w54ElMDXo1OqF0mBn6BE2AO0NsmbNfkk1dhddRrsNOl+EKZS+cWDCTW49o29rEeVIKvQG9t28mNvfININSbq16d4l4iLxnQexePJPbv0FkSds3C7ekyj4JJfnVeENemxG14qymo+GAGTcR12eSRbwRM6vnUyYfNYtnc8yoG7gBnlYefD/LCrAkzs1Cf5oPFvb6L9wJL7jlxzNN6heA7cIm8AscQZ4OumPXe5fLJK/9FCNVL3+0+sZfANQacXT+8f4GlzN4imtEs1PlP5j+bfPLK7yWmXqM4S+/xr4T+CHgN3Pvx+P2gDKIcYB/Njs084GtVRuZe4OeUta+I5fftUK9RnE7Nq8+EHTQ8fF6D04mPgsmgCNKeQCKaLc1+YI3/EeYfI2MGsM+vmp3E8qtDGGsSD0/vXtxmxI+ID3hP6kT8SWDfJHwJIoXAfya/TvWF9gPHt+LNn4C3Xp7txPJWBx2azcRtMZA6+R4+Pxyf0u8l1B/vx+BZ/Bkg2Sq8H5ir8bbtP0dsn/nWPaO9HsiXPOHEafO9SzcMmk3gFu2lQFK3wX3yD2EKfSuA33pu0QZi2/b7d2me+dYtYewmaCVMX9Oy20ghTMAteE7fZrAYeIc/wX8Dzf8kFLNtv18t5plvnfUutStKWUtr9eSpYSaQAL4SFfTdB/vAArAS7AGKnMIfB7bt9/vcPPMrrAdOjpTW9hcAAP//Pbtl5QAAAAZJREFUAwDjo27OLjTPHwAAAABJRU5ErkJggg==",
        [32] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAEgElEQVR4AayX24tNURzH9xmMW7mNmQnFlOSSW/EPIERRHvDkklsRJeKFci8eFN7IPSUevJA7/4JbHiiKosYwZkbDNGOMz2eftc05nTOXfcz0+571W2v/ft/fb/32WmuvKYtK+Ovo6MiAoWBcgHqmBKqopAQINABMA1cD1B2jm05KTaCcMPPBzAB1x+imk1IT0G8QoQwq1B1jKJ0UdeK9+o770w4C5aDY+80dy9XjDPQB+sohV4GNhgUJ4KShM5qIwVowBwwGaUUffeWQy0TkzuPJSyAn+HSszoFD4DSoCs9Qe5ZgW4XlGSDHWdoZoCCJvAQwcCWb7Ul0sx9JOwT0A2lFbqsgx1yc5ZTbGHSzolGskbVBKujsB7NBf/AZHAO1mUymg7ZXEmy/YKyvHHLNor8PVIRYqFHeOeBMVzC6ALgG6mkPgHvgJ0gr+ugrxzecBwK5jWEsuiGBkFElI5vAMKDzZdq7oIkZ/aFNJcGnCSc5rtD+AnIbozLE/FcBZ7wEg/FAecvPRdAYiFDTS/BtxPMSkJMmmsDPUuD6iMrIJENnKFgEbJ39DXTf+2/a/xKSkKMWEjmtguV3skOM7SJMFp+LxMVixg9x0JimT8RJPYJJbneB23w0/X4m4FE6lY4l8V1bqjr67aCvRC53xRsI1X3lk9HLTcCMxtBx9pbrHXorpetu2/nMZG1FouNaKIGrlSfvgTGMNRZ9gAn4CobTUTe77+gS0nQpknzkqVtVqDvGUJcip7bGSGLGryDxcDGqOyPb7uBsbmNwMEDdMbq9ljheMmv3q5nZ9+i07ZKJkmrbgMHNgIYwRrdLkTPhTvzbHWzD5ROwhK4Hz2s/o3GGjBcVA4KWAAmL2jnodqN1scttDGN5RLeZgKVzdbrt7E/BuBr4nmj6ROTypJXbGMYyZqsds/9KmJfAzDwuF6J7YND0ici1GCa5jfEC3ZjtZZTQRdfMwAPggaHxanTPa7cLaulC+eXwbiCn3MbyoGs2thWQvYWf+8DtRBNN4mcjGA5BYkM3nQRft/gGPOWkiYzhZI0ZxeRk4mvwpDqPhTvCTNej+9EYFojo9l6CjyWXYx2ecsptDL8zxswmwEPF8t9CeQLMbhTtYbAMjITQUqL2LMHWLbccazm86Mj5lL4xjIUadSYQquDF4ShPXCQuFo/oE/R3gxqIrUbRGy7Pkpu0s67BXp/jtHLI9Rz9CKgPsVBzEoh7UeSZ4LdA52eMuUX9am1Dvw62AD9c1QQcBUYEWC23rv8hbcZGW330lUOuXYzLbQzUrMRrIKtGEZm5IyzVqyiKtgKvVH5C/Xr5X5B3ujuMe1vyvrcXfQ+wao55JHun1FYffb0RyfUaOw8uY6BmJS8Bh3KS8LO8kzHPe51/oEvqV2we+hqwHewA3v0d85k22uqjrxxyFQTHr3MN2ElgEsDSuTP8B3QVz7xcukA9tv0O+NyV7FdO3TGfPQ62+uhbJxfImzk2sRRUIB4NPzi1A2fj3r3GsKVcSWvpT9FeAG4rdccM6rvX9oO+wCQxKy5/AQAA///T/Y+jAAAABklEQVQDAJU3hMTePtILAAAAAElFTkSuQmCC",
    },
    restart = {
        [8] = "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAo0lEQVR4ASzOoQrCQADG8bvTJgwNGgSTxTAwWHwCs8J8DrGK0S4Gg89gMPgERotBg48guLAtbG27/T9Y+O37GB9357z3LQSYIGqE5BgLZ4zpYI4NeuhjjwNWGgwpSxxxxR0xpmhrEFJe+CNDCg235EUD0nh9rLXKgv7EA28NPpQZBjyqSwbQW6TS4MePG3RkRK6xwwhOg5yiI0+k7k/IM74oawAAAP//1YSaOwAAAAZJREFUAwAOJDkRDc1fKQAAAABJRU5ErkJggg==",
        [9] = "iVBORw0KGgoAAAANSUhEUgAAAAkAAAAJCAYAAADgkQYQAAAAwUlEQVR4ARTOrQoCQRiF4Z0VdIugCMuKoGAW7GJRsO8FGKwGo8k/0GjQYLGbvACDl2AwiMViNFgU1OCCzr4nPHyH3TMzn2utNfAQoIYQmkVmCXXXcZwU8uijjQo6mGCIUKUMoYcTZlhjgQAtpFUqEzzscccDWVyww0Eln3BDZIz5Mf84YooBtirptHZKsmSCokoRPz944a3SlfCF3vcp5si6vcEswFXpSVihihG6GKMJHbYqKWinOR83OENzydQFNgYAAP//0hAzPwAAAAZJREFUAwA750j+X0DI/QAAAABJRU5ErkJggg==",
        [10] = "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAA3UlEQVR4AVTPIUtDURQH8L0xhYEwERGxCGZNBqtVFA2i2Q9gECwqWtUigharZqsIfgytFrHM4DbGGBvbuPud8Rb2eL97zrnvfy+8YsGTUioxywqbuegX9EusFy0l2Rm2ueMod68ecMFe3DgObdm45Zwrnjhhn/kIzmkOeeCTKv9sMKBJI4LLmjq/dLIsS2qPuHFX3eExgurkKxzBP7vfuWoEfwwV4uayn8uCeZoyUw6mCNYMrxyzxmJuVT2jEgcj2DK88U58uFZvuOSL9uhGS98wDp/qX3gm+g+1S2EIAAD//0WHVoAAAAAGSURBVAMAkMRT6zvKgTEAAAAASUVORK5CYII=",
        [11] = "iVBORw0KGgoAAAANSUhEUgAAAAsAAAALCAYAAACprHcmAAABBklEQVR4ASzQTStEYRQH8Htv3iZl0C2zsBMLNspC+RCy8A1QwsJKkRLZsGGBhcTCF7D3BVjaelmShbxFZoxcvzOZ5vecc6Z/z71zssSnKIqUEhWGGCNqzGV9D4OZI5Uv0c8Se6yxzzIjrDAeN7dp+tjkiQWmWaTOCZPkES5rprjkiGvueaCdFn6pRbhbM8wZL2maxm3apNVxxS47nEe4U1PjnR/iWzgeOeWAQy4i/KqJR3WoTSRuL6jzaf5QQzXCz36Ix02oXbbTTKwyalyQm+OyJMJvQseMMsMAvUSdVTeI92+Eq4ZbVsmJPcdWYs+V//lbTTLvE3/my3DDFvOsM8c2dzTCfwAAAP//GI8+pwAAAAZJREFUAwBIKmbNC2qqpgAAAABJRU5ErkJggg==",
        [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAABKklEQVR4AWTRu0oDQRSA4Zk1QULwBmKXRkGwUawsfACFFIKIdqIPYKG9naUo+AJ2FkGxUbDRV1DUxlYEQQXvWHhZ/38ZQiDLfnvODufs7MxkIV15npfQgxpGEvNe8ioGMFQ0kJTo68MstrGbmM+RD2Id9ayleI2BBZxgJTklLmMPM+h3hipJHePwKw3iBa5xhic4Q4UYbegmsWGfeIP3GOM38Q8T6MQlrnBrgzPUeHHwi+Kc3PuHxyEW4dr83YYNkYG2m8ZfONsD8R6PeLXhg+o7jKLCJjQ/YI4OuOXWBh9vFB7D7RsmdlFQljlc8BixjKLhk+QI59jAPNwxmW/yPgk/HjL+y8U9M7AFt3SKuJNME1245+DOhaKrpemAAg9wieiBrRJteEk14R8AAP//ke8kuAAAAAZJREFUAwDA5XKyV2Be9wAAAABJRU5ErkJggg==",
        [13] = "iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAYAAABy6+R8AAABXklEQVR4AVTRPUiVURgH8PveG9iH0SCBQ5EQNAQNjUFLEETQVATVErRVS0XR1hz4gYMoOAhuDuogIiqCCK4OLoKLg+IgOPj9hXr9/V8ugpfzu8/znHue95x73mql8anX6wXXuUsbD0lMnfkb6uT3yiZF4i39j/lFL4P0kfqJ2MY/Xlc1FJKbvKCb+4zSQeIDsZ8e3tCSHZokj/jDDH8ZYooR8qCa+Jzb1NKU5L1ilQE2iqLY41B+yidy9C0xdtOUiacm5ti2OAul5Ug+Jsspvos/mUxTtm5WbJJFwuU4ks0zwTjTrKTpTLJDC9e4HHY954SjhmPxNE37Vi2S27vjNq80qmvkPTWJWV/J166GYXLVX8RWPzaTl5ljt5r7yDPKB6bpWLFMOy/5zwdekZg6N1hXl6PqjCkOVLP8YI23/OYd6+TdLYjlRWWnisZzE/lvS2IX3/jMVzrJ/H5jXeUCAAD//7r+N4sAAAAGSURBVAMANUqGnwHz2vMAAAAASUVORK5CYII=",
        [14] = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAABeklEQVR4AYTSzStEURjH8efMlfeXwkxN0rCxpNiRlJdSir+CslIsvBQLFizEjoU/QhQrKRvZSHayQlkw8hIjTcz1/d1Ougs10/3M85xzz3Ofe8+9CYv9wjAMUIM0Mp5yzZUwLkMDkn+FDEq5RhJjWMG2t0wcRRrNWMJQVOiLMkysYhoFHHvKZ8g3sY4RNCYoCkjqsYAWzGERO566b5D3Yhi1CNSxkmQQ7VDHU+Kjc+6N+I5vDEAN1D1PnldhNUkfznGJnHMuJOrQ+VaSDxxiFwe40gltShODa3zFihiaOlyQaEP07FPkszhTIfH/g4sUoIu9EJ+8V2JOhbrne0rbUM5mOWLRQ4W6/xNWdqEDVfFi5ahAHRRVY/r7ZPERtDHzxG6kWKSF2voU4x5soROqsQT3+8PgGXoVN8Q16N2NEyegL0dzanDHONrxqJpiPectk+qol63n7GcsWqOvRh/FA2vVyDTJeTMmVJw1sz1o+yeJonyfPOvXkJr9AgAA//9B8ykbAAAABklEQVQDAFN2kpX8tFCTAAAAAElFTkSuQmCC",
        [15] = "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAABq0lEQVR4AVySSyhtYRTH93bvdd/3drhXQgZMhLGBgUw9SsrAwEgSkhkTiZKRISGviYFkwsTIxNTYIyVDhRCSIrbfb9sHx+n7nf9a69trre+VFbz7RVEUwlfIgUIoBlXfeHo+RTz1mozziTq/oRK6YRwmQe1BKyAXimAEauLkJPEvgVaYgWa4hyN4gCaYhQ6wWD36L4vEEOMntEAfbEM7DMAo9EMX7IN2HfoHPts5G6MUOmELxmA/DMNTOMe+hGswwSbfsM2L/DPQQCACl3xGkkvFjccX/tvABmfoMZzClcnfMcphD04+JBIKLDSH4Xk0ou7XLW6a7Cn/IujyHtGMkRSzm8V3mJQD9MJkE25wUmAhJHNQ4CnhERX9eM93fOpJuvR8Tt89EsocxH0g6duJJ+18i7UBDk/8Px9mg1doLMC2YA6ODX7gx3Mm+xgOmZiHWhiEMrBILh/mYesPo1NQAC/J7MErsvsqwQmoggXwJQ0luohWwxKcgDmBnQMKeGhXBJfB17SOutSSRNdQt7SC3vL9WzKBdAFP3atweT7FXubUaXQXbki0EWYQPAMAAP//am8dIAAAAAZJREFUAwCNOqOM4YlF7wAAAABJRU5ErkJggg==",
        [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAB1ElEQVR4AYzTzYtOURwH8Hufx5hhzIsibxvJimxYKBuxwMpWNpRsFCuJshPlJW8RCsmO/wDFUqwHOySRt5Ixw7w03fl8b8/MPE1NzXQ+z+93zj33d8+950yjmPVXVVWTbpazuiV5xpqZbqyLfvqmC+iUdJqwjF2c5BIXSb5HTKEecQ1n2FIXcGOps4hN3OAcO+mjnx2c5SbbSeEUXFEXMLCQDVxmPXfYx+GW/eJd8oAH4m56aTY8Pe+1VCfLzPJOyR/yoSzLbyH/zHO+kxUtFrPqIivo0tnGRlL9tTjoxgmx8IBM7JYfZS1DDDLMaAqkWgr8N/CEITdXYnvLxx0wcI/rXOUWAynQIVnFV/66uX6yvL390LnPNa603BY/poA4d1OwYpxh8mpT0q9fYdztX8je9njnfFTd+bWs4J+pr8jHzN4uUSQfztBMyxgddDL9kBQYMe0lbznEVnrbJ7Xy7Ptm1/aSQycURcN75aP91rtAtue8eIB1blwZyTlITmkO1QJ53bKCJGN+3nGc9xzhETl92brH8ox9EnPMs2qpFeTXKrLvOQfZ6xyY08ZfkBX9EZNn7Jj8DaPUbWoFRYqQC79ceUb+C0+Ikdd7Kv+ZOeSBukUxCQAA//8McA3rAAAABklEQVQDAGaDroMPaSWVAAAAAElFTkSuQmCC",
        [17] = "iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAACAElEQVR4AYzUS4iNYRzH8fOeOdMYcxGho8xCKLKzsFSUFHLZyC0rKUkuK5eSlCILG0lhR1YiZSFlYWlhIUVhN9HErMZpyMyc+fzead65rGZ6vvO/nOf5nf/zf//vqdfm/bXb7QKd6MdKNLECiZMvckTchSXomyMi0WFDH9bjKC7jBq7gCJKP2GL+alzDxkqEQKfEcpzAE5zHTmxG7AX2MU5iE25jF5qlCIFUsEziEk7hJ65jH/ZiPxL/Ys/iKXYgVTfqBHLHHolj2I23OI3n+I5BfMMr5Gpj7BrkTFlE/jUkcr/0IJtviQeLomhhHG1xvqifPYOlSG6CLYlIt2ArepFeDDn4nz975brbJNKzVPeJH76wQxHp4mzAON7jL+avXOGZ5CHsQRoaDvI/RiTfkgaNSoyqImLcmZUcRpAqf7DT/Oa3IpJ7/XFkEbo1OqLcha+IpPzPjqTBW9iIMQtfEck13jnSQqYyo57BE85dqmygFz2oKo5ImpZZyDRmrC86OmBTtZHfgcxFRuGcz4+jqriuMXnmqSKPNwO13Ya7OIC1Dg+w65D4HnsYmW5maqWSGqE8kWGpm7iPVbiKF3iJ2MRN/iM8wD+UqxSJRygDlncjGzK9d+Tf4ANeI3FejYf8YfvTBm6tVokk8kEqGuF/Ra6XdyU/A7GJk8+8ZJ8tU2sSAAD//1fW7bYAAAAGSURBVAMARXm5c72DpckAAAAASUVORK5CYII=",
        [18] = "iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAACGklEQVR4AZSTS0iVQRiG5z9piqekhZXQqqBNm4iiC1GLahMton2LbgRBF2pRUUS1iKhWEVER6tqFiCsRBEEQ75eNbly4dKGIeL//Ps9xPIgcRA/znPf9vn/m+2fmn8mEAr80TTNQCofgcERvLj+GfAmUQzaftB6JBErxFXABHsDryEP0IlTYR/DH4B0czxfigf4AyXPwC/7DE7gd0Zv7TXwJTsIP8HmlgwNFEhJZuA52tFgb/hPch3vwEcydRf/BX7gB5VCUK4QpgdPwGcy9R99CPXRBN+g/oD/hKLh0V2D/4KZqrPqchz74gjbCWJIkc7AsxCvg/jmLYvw+cCwSgmY/7hScgVZogWkGr6Fbm7N+RcK+0+h4ZBKdt5Bvcd3EoZm/QkVIB2dUh3HZL9EXkTfokIWcZiVBCiOwDIXaIkln3IC6X5s0EU9YCA2JfzvhUmEJ5rexSLxqIWcwShH9CdQZIntrDl5gSB+4NM/RQc6VeVK7bw5Yovsg9MNVuAYFi/kCyMIR8I4V0TfXMqzPzzxF5LWYQb07N1EvaxkDiiNl5uAW1MJdyG+DMyIOfpEBjFfCwh7Kr8R34HxE/w1v3gM8jLcvEnIHMjAr92eWjOfoKdoDV8ArU4OKL7mM7wXPUAfqh0JiIR3FrO7SvFfPyD2GP+C5Ef0j4s0XzcQxpLYUMuJBCn5Fj387uSr4HqlGO2HcPuAqCDfaOgAAAP//5csmRQAAAAZJREFUAwBqkshrxS31AQAAAABJRU5ErkJggg==",
        [19] = "iVBORw0KGgoAAAANSUhEUgAAABMAAAATCAYAAAByUDbMAAACTklEQVR4AZTUW2iOcRwH8PedzTIz2ogcSnHrcEO4QSJ3LijldEOJuHHK+YJIThEl5YokxYVIuHJHUkLKjaLVWo05TTZs8/lu72YzLvb2fN7f//97/v/f83/+z/u8ZYX/fDo7O4dQxShqSUx/SN8p8pWMoGpAMckUqTFhEkvZwFbWs4SJxtRQTmX67GJcv2JODk2SjdzgJJtYx2ZOc5Ocz8WmaJ9gOX+KlQpNljzFFoZzj+PsIzH95HP+vNxZFpE7Ke9amULZhzGSh5jHU9ZygKvcIvGgmNt9Lc4vqRaLFLqKaeRqq8S5PGEHL2kuFostfKdF/yufybxsSUWpLRQKZaVV1eqt5BvHaDC5jU7trsO4FBits5fp/KS15If4KwPyRGbqpOBD8S05KfQ7MnaCTFaYcXe173Cb7GVjBmS5UyWyiudia98V6fccHRov2E0eQJ5ujz1yDSkW2TP9QvajPY2/uUAHudBHsamP99qfaE2hXDF7lfkjfeXJCoM/Uiz788bUIjPI65G25uCOFGsz5RkfWEh+uNlHzX8febJU0O8uytxr9qjZtOtUkc0cb+CAFcoVydMfa9xi6vR7C2ZlcoXs2TWNx8wm79s0Mf8W1SYMI7/0Ornkz4hHWUD/YqXVNTmxn0fM4gqHWc0y1pDXLfk52q/I25I70yz0vk4FBfMg3sluIy9xVpu/oPy9HJHbSfrJ53zyeVMGFjOwp2Cj9kVWkMIXxMskbheTz/nG0gKkuo+ePevu+TagnS+a9TzgEudIvC/W5zy9K5LrOn4DAAD//zJQYioAAAAGSURBVAMAFU3ZXnXO0PUAAAAASUVORK5CYII=",
        [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAACgklEQVR4AZyUS4jNURzHz/+aa4YZM7qDIo+FlLKwlI1EKUWiEEkWIkVKYkFWFmw8orw3NkKxoEhZS8pjIzaKGq+YzLgW5vWfz+fc//33n5k7i5npfOb3OOd87++c8z+nFMb5S9M0gTK0QkeGfhN+Up+mD83QBi1jBEkq1MyECiyFjbA7YwPWXIVxijh/KrkFcBgqJrC1xqApeO2wAs7DAzgDRzLOYh/COXDMLOxiMN6BnZ0LZmIdJHfCdVgDvfAEbsINeArm1mKND2AvwGqwkHIURMw9aSO5HY5BE1yGbXASLoHxCay5a1jHH8WuglaIWvEfgfuwHOs+DGKd6KTPSZL8hl4h3w3fwUq10/Dd77pOKBWq20unv+rynuH3IDKALTYrn0fiFCyBXAjflprwIOYSrYQfcB/+IjaEHd3KJPaAB+FeWuU3YvmFrSpoycsIHPwK+wex0ZWRjs38VbxdsBk2FfCUuxR0GXPoSOEL9EPDxg/10dEF7+BNgdf4H+Gfgti8edp50MhBdAgGYaCAsfm4hy7jJ5MVm4916ZjJNSv8z9T34FL9+mdy8m4DqYk3Bf3uvjL1BbiXW7HtiNqHO7bZBy0wHUasqMQ+eBhVpt0Crd/jOvyGlSJg9V5Rr6YXwYci//G64+m9ReQiOOE0dh8sQqATrFg6yS2E/eDj4TX0Q3f/SYUQBQtV3iXr6+JBHcS/B4ofwoq+H759ruwK+U+QX4IoSCIg6l724N8Bq3uO9QVZj3UbRH8GsX2OsYAqcxUnnVUYPf7RoahX6iWhb6C34Ti+7534Em0hts8xPhrOIVVreYW1MFhpirCfki/LhxDCI7id8RhrrtsxkFdGPrZhAAAA//+o7EqeAAAABklEQVQDACrq503EyilEAAAAAElFTkSuQmCC",
        [21] = "iVBORw0KGgoAAAANSUhEUgAAABUAAAAVCAYAAACpF6WWAAACqElEQVR4AZyUy29NURSH973VVh/aJtV4RFEkEhHCxMBjYiSEeARTxGtkggQhXpF4JN7Ee0xESCT8AWIkGGCAaARpmpJGtYq2ru87p+e4V64ObrO+/tZae+911zl775MNQ/zlcrkMVEA11IJqnMlfRj6ZV4NfWbQoA2VQy8JRMBuWwCpQZ6GjHQfn+QMV5CbAJqgrKMokf3E4A2NgA9yCm3ACDoKa5NYTj4U6mAQnYR00pEUtSKIKpsMl2AGT4TM8ggegGpvfSey8hegpWAD1UJ4WJaiEaXAWfORW1MLL0W2wG1Rj8++J58A1mA81ENWL/tFlGYmRcAAmwmPYCPfgYyaT6YAv0EH8CR7CIRgAu/MJo1rEIXFMriAxE97CHmilSA/8xs+3YQRuoF3bnRtF6q9l6dLkCFIrQf88+oFiP9ECG5xrZ3sZmAF98G2QLrQHftmpv9xM4JFoQ330XvR/lmPgCdyAC3Auj4v4nRYtx/E96r/G76XLfx+ZdAjkLdgZQrgMx+FoHsfwr0KXhaSaQPNRihZ0UCjcD93wtQjuQZ8FLfLdBeBBNodbulnAl+2Z89GmUqqKDTGPW5q5uJ+lFvWwe1TmEXvEkNIsy3uxw26W3wH9rWgz3XrDcIsb436t6tEGcLPTiXZq4BGy6HOCKXAYWpjspyyZQyoEcp5tD30LCU+AHxnPOWFs0QK69br5odhP+h3MhSuwDMZRqAkaockYloLji9Hx4DVHYouKxm7wBr3C9/o9RZNO7uKfgSNwGoztzs/dM+Jd4FFEYkuL0q3v09fwgqHN4GF+gzaCnS9C3URjvw+ObyH3EmwIiS0tamhh+IHvdb2OroXVsB32gWq8Bt/xNueDDZGKraBonApexwEmeiLaQwi+ivvobVCN2x0H94J0of0BAAD//56bac4AAAAGSURBVAMAuNLzQkfqfocAAAAASUVORK5CYII=",
        [22] = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAACyklEQVR4AayUuWsVURSHZ56azZhENCgmIjZaiJ02Cgru2imCS6UiCGphowgujYKFIiK4gKJWKiLaqajoH6CdiEtrIglJeFnISpLJ982b98hk8giEPO73zrnnnPnNnbvlghl+URTloAKqE/Qzz5ELwVyNNlPge0hYVIldTL8JNsJO2AX6TebAmpCYrYK/lXAUajPCFM8jUQ8b4Bq8g5dwH+6BvjFz1tTzzELiq+EOnIK6lDAF8wkuhdPwDA7CEuiFvwl9WGPmnuKfgfVwG7ZAAywoCSPqSH3gIomz4Cg+YU/CXvATZQ++sc/YRXAOXoCitdh4amJhRO1YdILEIRiG63AevkBLGIZtog/GLmEfQQ2sAq06uEEQC+M58euwCmOCm/w5lx2IDcE4/bglfkTH0W3C+qUhVjCFVhT2bUcIOWpH8wa/B5ExbKrxda5DM8Eb4OLZ98WTifeo4gpupdCk89U9nSh5myPcjON6tGBd1D9Y+Y39Bf2K+kb3n6vZTfAHjEC5NkriLRyA3eD+LuI+dzrzCjsCt5hz1EbhCKN15LjZRm4M+qAdWqfwn34XDCmcfXoOIgq7QJ1oudLLsJ5347izbwo4Z/+Q6AHvBk+R24/u7FuO+XA+PaZfkfFFh7ENbCvnHrd8o8bLytvP9UkVKmRggD8PhC/Yjr8fvFzKiiNqzm26ltoV9FNfWRR2e/2k4AnYLvDn0W7kgSoo1gX6UEW+Ebw73PfedNX0Sy1+gOlw4Rytwq/IVsJl8Gj7Bc2ILRdinrpt2FtwFTworpFTSrfQYmFdxN0dXfge1btYp8eN70Xzgf7zhPfYx7AD+sF7WgbxS60kbARxd4hb7yH94/AafJlzuQZf6rDGzB3DfwCdybO4hZYSNkSBI3frfaN/BfaBO8ULXfSNmftObtrLKiNMYYB4BMOQp98KvuQjVvQ9ynny1rg+pNJtAgAA///hJ8+AAAAABklEQVQDAAxc/z1SXrJhAAAAAElFTkSuQmCC",
        [23] = "iVBORw0KGgoAAAANSUhEUgAAABcAAAAXCAYAAADgKtSgAAADCElEQVR4AaSVW4jMURjAZ2Z39m5ZKVta1yRKuYQk5RJvUnhDKRSRB+UWhQfiRURSiMKD64Py4p7ygFzelETZl1Vrs8zu2mFn/H7/mf/fjBkbdvt++33n+875zjnfOf8zidhf/GWz2QQkoQrUZccRi4PxGnXZTs5HsALqYBjtFpgGc0Ddoh+MF+aoJj4SlkJ9YYB2LMYAZ6+hMRxWwHG4DTfgEqjvoE/AcmhmTK1gj4WjsAkai5LTwXYDgRlwGg7BQmiEDPSAehB6ARyGMzAbJsERmAuDIWkydG7FGPXgoFPoWdANF2EtzId5oLZ9AbsLZoITOMaymSPIG/wjqFivKRgHwZK8Qq+BA3AP3sXj8VY12LbfBuy3MAKmQpQYOxYkz5ejCcdOMPFL9BZ4Dh0k7QXLEVNDL3531YHuA/NUoOMQiU4bHqC1deWfceyH9yTpgSx2kbCYKhyjwdVPRpsYVSxh8jrcSyAJN+E1fIM/iSXcSnACuAt38Ak7pBM77cfhBNbKmrnFuwRS5VaMP5QfGJdhH2yHbb+hv9PEbqmZoBM46A32d+hPXO0jOlwFJynkCj5jKZN7CJZF7aDo8OhUVthVBtLgmXSjC9FnLGNyD8yTV1tL3wX9ZRP/i9Mk1rmNQSmohPHgwaIGJgm25P31S/NuW/9FpGzgulkmzP8XV+5oy3ILwwP1Sk7E9u6j+hcWUQnV4FNbtKAwuXfaT9rVDyHdXhjDAF+7ogH4AyHm61lLYxSsgpJyBsnzpfFD8JX7SEfv/DH0dGgikSsL+mL7bXjwQ4kZP4n22ViN9stF5SQYkDNjXkNXvot2OMF57D3g0zCOxP5o+Gbb3o3/HDiBT/FDbMuKykmUnNV7FT3YB4Q2wlPw/rvls9j3wQTGbev3w3uC3x+Hx+g0RBIl18ME3hyvpInX4XO7Jv2KbV9rrP5CW/8O9Hp4Bl358Zg5sWPOyv+nQxY8YEtzDfdmWAzLYCWobeu/TrvN/uDOaf6SkuRhiM594Gfdju8DvAC3rm4l1g7G3S2hUvkJAAD//+bfsxEAAAAGSURBVAMASdcZQ6xt5l4AAAAASUVORK5CYII=",
        [24] = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAADHklEQVR4AbSVS2xNURRA7+1HtXhaoiYoYkIMxD8GIsQEU58BA/EZEAx8EomBBIm/ECY+Awx8YyLEJxKJkQkTIRIRFRraUh7VKvqsdd339Oq7ItE2Z3XvffY+e59z7jnnlQT/+JfL5UIojQnThuE3rgxZAWWpBXAaWI4cALUkrIPxMXX2gT5jooLYygpiRsJsqCpagMAynBkYCxvgLNyBazHq9q3HHgeZeIzJx2AfBsdluhUgsA/OobAOLoFJJiL7Q2mM+iR0k1xEGjsC6YQOIWdANZQnCsTJ3YqDOB00GPkajsMaWBizFnkCXoExxh5Dl+nIfhDljv5hBCR3W4ag74Q58ANOwWLYB9fhfoxbtQd9CZwBx7rnk9FN7rdADYKoAMlDLB3LkbOgA3bDfngehuEHaINvMW30f4QGuAJNYJFyZAiFFhXA0jkKuQzcZz/gOfT3JPyOLNb8oJ6W7TiHQSIxdtTyBfpiLYAaeAknoYXkbhNqsrFix3kQduGZANqu+it6Hu1OHfQFlfybCdo3kE0kT5s57sDZekreYdyD23CzC7fQPcqtJczG4Co6PL/O+AG6s0Cktk48T2EjrIZVf2DfAfqyzlgGYnj+HfgG/W+zD1hdDtrBbXS1jehdacbOQofJydd7zQLO2iPntmj78TxVPVK1hGXkyPQFnoEFfBY8gpj/30xoFi+Op8Fi8+io5eP3yCryBdpJehVaYDisgBqKeOlQ05sxUAW+qP4GeCoLA/IFPDUv6PVd8ah6o31nBjEwdSWxz8u5iLF7wdc0ER8ViL9DKwGn4S54ZLciPeejSVQNleCPi6h70XxeNhG3A+bCFEisOipAp2fbVTSibwNvoYEr0c/DZpgPU2EaqG9BXgBjnJAvrTfaPHT/aoUCmqzE96Me3ZkfQTaDD5k307f+MrY/QureXn0+F8Y6iQZypBdgsCuxiLf5KLZ76+CH6J/B7yPqPin6jDH2LckdS9jvllhBvptAZ5HFfgL+vi5F+iPk1oi6B0HfY3w+C45BTbaiBQyhiO+NPzCf0P02bt0jfFJvH+gzxvuDq3v7CQAA//9jTYJUAAAABklEQVQDACKdHTyZkTfjAAAAAElFTkSuQmCC",
        [25] = "iVBORw0KGgoAAAANSUhEUgAAABkAAAAZCAYAAADE6YVjAAADRklEQVR4AayV24tNURjAz5l7M4PRmCGjELk/CBFyK/4A5RoPHoS8KJFLURQhEnlxKU/K5cGLNx6QJBQvkkRkJqNBc+8MY7bf71z2Oce5SMfp+51vf5f9fXutvfZaZZF//AVBEP3bLeZABVRCedEmJJRBDTTAGBhHg4lqGA36jYd18PkQ1eSNhwVQGwYxQjERanA0wyo4CrfgAdyHh6B9BG28yXywng2m4D8Pu2GYTnRaSCzHGg6L4RJchE0wA0ZALRifid4Mxs0zvwl7GpyFhTASqrKaJBtYaANBb16CroDXcBkOwi5Qa+s3vhSfjXaiL8B8qAOnLhI2oYGOegJr4RCMgo+wHzbCCbgGt0Gt7cPsw24Fp3YPeh6EDbhON8FwLk3Yy7XNXqC3gnPfFo1GO6EP+kHdSewz3IFj8AucSutEuQ4lPhJGoXaanIpGoh/AZq/QvRQdQmcJ91ioEudY2AEWR+WKxfVW8ec8OpKfXJ+DNxCjQYDOJzaYROAMzIVCTYJUE5frymTiW/Q9cEoKNSAc8YWv58Jvpwf9Bdr/oAN7ILPJHBxOwSN0DyPImSL8meKIXWFbcK4DF0wmPoCLoivVxKG3kGjhd2gLoAoLD2FOGxnP4UkenuHz3cbcNnx634nDxx/p46/YNBFOCI2GYLAIxoMyEiz4g9sGQcla4zpKJTVdDt0PSnsyRR0Z6v+IRa0U4+8lOKpF6Hq+g1QMszRJFbLJXUoNgDuoy7mORr4vXKVJqonv5CmlXCmuNL/8qdieFUUb+SBQDY3QDDn3xJvw8l26XRT1S/+OngCnwe284NRR0Pvd52aRexVugO9UP5cJyTScKkdyilAvzIYrsAZaKOgp6BTWcq1uwO++Zdw8jwVtz5qs0YdNGI0v3eLuup6EXyniEXoSfR0OgIfX6qTW1m/ckX/D7+jdVN2RMRMSNtGkkUGnzWFvw+cW4/fjaee2fxyfU6rWno5t3OPY/JvY7to+MJcJyWqiK9mom+vHYKHtaA8pn9AH6MdWa+s3bgPzu5P3k5KWnCaGSAzAZe0u6tI+jN9NcDl6BSwDbf3GO8yHrBGQE5e8TeIR/rjJvcczxVOxHfsT7vfoVtDWb9zVSSi//AYAAP//wxyGhgAAAAZJREFUAwDn2DJA5fxjhgAAAABJRU5ErkJggg==",
        [26] = "iVBORw0KGgoAAAANSUhEUgAAABoAAAAaCAYAAACpSkzOAAADXklEQVR4AbSWS2xMYRSA77RVrYZGKxRh0yDeK0TYaNh7LbwWLAhB4rUkkRCxIAjiFSyIkCASW/GIYGHnlUh0Q1QrUVSbFq3xfdN7Z+Z2OjObafN/c8495/z/+d9/y4Ih+ksmkwkohwooK5qIIINrkHXQABNC1LXpK8/uL/4E38NhMsyC6ryJCLYnowhqhA1wHG7DgxB1bfoaia8F60RJphJ3GvbByJxEBDvkKpwTYTvcgcOwAuzdeKTMRC4HfXeRxlqnFn0anICFUAeVsUQmwWgSGzmPvgccfh/yNdyAU3AS1F8h9U1C7oYLsAyMmY8cAY4wiCXC6LxOR54Be4MIHvKzCdbAfrCnJjqAvhY2wiOwwUXIS7AAaiDdflphNBU4xoJTYbIe9LOwA2yoJZFItMPPkHbsX+AJ7AWnzzacOmfFxJj7SzoRnw7ThZ2H/hecOhO10XAPJLENVrS7aZzu7PZisSkHo3F7NuBZB5XwFJyC7yToRc9XnOopOI/BHBgGg5ZUIjwOtQk5DrrhInwrlITOOTWO5CCxM+AfdMKvAdheb5TInrmAzvF7At1Nv5HFilP8gqBr4AzYwWy03cTXGSVyupwCbMEbfgqtCe4gYLSujb13LY8EQeAmGshR7PehK0qk9GBhC77y49lAFC4k64VO+JEHd2g3vj4TFG6tRN4okQvpuXCBPUvuwhKl6G8mSvSHzw9gmc1PVbirUEtTokTuMHePu8hbdy7NuxMRpSnZiR7TZBtUwxaoZ1Rud9Tihdgy8JkQlyBWKZWIXeHpb8Xjjew0LkbfDKOtjCxYwhjvOOv5lNjZWJ1UotDShbwOL8GrZCvSN8aX1DXLjsUVBCSI3i5vlJ0YL8M5GKMPmS7pyuGoPENe/++I8Foyka9kE98m9On2JRXPnQ/gEnw+KyaqR/fKca1RMyWdKDS5KUxipWehzSRX0L1KDiF3hajfQr8KxiCC5/z4dHsZe3Pw2V9iiRiVTt+ht7i3gY/cR6Tnytt5PXqUSN2joO8TdmOtY0ftMKZMiSXSbDIwWQvfTskqpC/rPaT3oI+dqGvTtxKfsZ+tC3YYU6bkJIpcBHuPdfDdDG4S/39Yjb40RF2bvmbiO8Ddizu35E0UhVK5D7rAZ7wV6ZMu6tr0Fb2E/wMAAP//9+5S4QAAAAZJREFUAwCE6TVEoermEgAAAABJRU5ErkJggg==",
        [27] = "iVBORw0KGgoAAAANSUhEUgAAABsAAAAbCAYAAACN1PRVAAADqUlEQVR4AbSWS4iNURzA751hZsw0HvNIxivKsyjySoSyEcojLGxkQZ5RZGfBgrDwTBYeCwuUsiDWlDyKkjxKRJMZzYxmGsYYxvX73ft9d+517zdTXNP5zf91zv//nfOde85XFPuPf4lEIg5FUAxFfRajkwNKkJVQDUNhGCi19RuPZz43ce1SfCNhLJRGFrMzlNGpBmbCDjgF1+AGXAXt7UjjNfYHH85Cjp1A7Azsgcq8xRhQTHAQzIXTYGIHLEOfBpNgOmjvRV6Bk2D/wcgKsNBx5ByohpKcYhTqR8DZbEFegCVQCZ3wEm7DdbgDL+A7DISlcB62gg9iIWdcjp2sk/yHkWwUckY+xT4cu0C9DXkJ1sEqcNmc5Tb01aDfuP18SGOX8YeFXFLMWCxdjEJxPM5gI3I9DIBXsAkOwEP4GI/Hm6AFmrThARwE32k90hwjkM7InKipli6G6c5x+pvR7fga6SzuIj+TvAsS6OkW2D9wdEAjKBGxrCI6JFksY1bOoopAK+yH59ARJEXNbsE4d904IofATZHMiZ7TwkB/IuNhHvj0boBH6JGFiNl8x6NRjsEMcOkRMXNk8gtnIizmEs7H4fJ9RVqsPWpGxMPm+CkYbneX8R362z/Q9wZfp52RsRL+TQW3/XukA3wXqL22bqL+FJYjF8HCPCzGdxjaw2IWGY7D9oF/OZsBX05j5t3wBRqhPoIG/K3QFRZT+qJN6I5yjdULikVMaPJvKuB7C/2YhWthUte+IUjr7so5xYPYP4mwmOfbMzL9hFEwBvw5IArXMovdI63b3hN7Dbr3VN6TgNhftbCY29zj6T5ZLLASOQvKg1MCtfdmP3D5K5BlEOZOD0w62Jb+2tvxnoMWGAIevv5g+yxIYh/QjTWZcZ76/t7C3Y0r1ZLFUmrM9/YE3YJuf885b+IF+KpI6FObFDPV8HkreyB4ntrPsR7ku+kRXSxjdhfp6H3kT2Eiugk8lF3WOgrUgt8etcTqYDYYt58zcwJeR242Qj3NQNqioD8Bl/EITm9adT8PNmD77eGZ6WeCB69SW79x+9n/BH2NuTqoPS2rmG4K+kTN6GfBi9Szz/fpsvjkfiZ4Qyu1PcSN3wr6O87L1Ty4elpOMUMUdIZe8+5OL1Cv/qPETOh79VvkKfZNcJbGd6Lbvy0Yj5nd8hazCwMS4EeOs3yMz6Xx6jfxCuy1YAE3kfFm+4M7m1BuiywWdnUweAt4v5nwE7YnuVJbv/HIImGu3wAAAP//CimeAgAAAAZJREFUAwCFDkdGRvw9CgAAAABJRU5ErkJggg==",
        [28] = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAADzUlEQVR4AbSWWYiOURiAv98y9uyKmSHUiCuyXUjJha2UrLlSZN+iaLIlJFGyZlckZI8iN1JyYSkupNxYZ1LDYIxZzOp5/r7vn+X/5x9pTO8z73ve857zfuc95zvf3yr4z3+1tbUxaBUS+6uEYXB7dFfoBX1CtPXZlzQXMTHW0w4yQ9olBdGREAa0hi44HDANvREOw7kQ7Q3YUyHTWGiDHaBN1h57GJyAddA5ZUKDoQMBWbAYrsMxWAXTYXyItr7jtG/AUugXjnX8UNoHYTT0hoykhATr60ynQWfQm8CntDSl2B/hRYh2GbZ9xuRin4VxMAJMpu6I7bxB/B+NuJDMMnSiMQFc0Vh0W3gH+2EOTIa5Idr6DtB+C8Y65jS2ZYySOS+uoGFCPNbcoD3YA6AcrsB88GmfovNisdhn0QZ9JjTmJu1ayAbL6cpi2AlJrJDVtcZrnbeh+4OlOoXeCm9IUAQV4IS4gkAbKoIgKIJPcAF+gkmcW02zTnRGLZ/G8gzHUQO34BB8ZdJKdErhQZ3UygwmYDv0AH2oZIknZJC6O93zwNPlYbCEhSSrwpdOMugcApbVhzU5zSSJV8ZE9jhoJIb75mquYbtX2phpxRO6lgi3wT3/jv2tEfqK8VVGCR00CofavXuA7SuAalZ8qPNE7YTN4GvUmC34T0JJlNDjPBCHt4RP8x7biVDNym8iHsMl8NCk4jJ9r6A8Sqh2D/EFhfyrYu/iNcdOK8TVgKe3FF3SBGX4K6HGRGknbOnOKKGvwY9wco91G05uk0c7jPsnFSV0v7y+qpnFhJ5W95Vmy0qU0I1/xtQea9/DidhqVMtKlNDr6TlTfwBP6mx0NmX1/cRsOYkn9PQwpXvo8XWVltSXuSdJfQC6mxdi4x9sdA/oBPH564+s7/BF94Z5SYD+GejV0JuBza40jPHyX8kY38Up6KRrzonxBwGr9MB8CYJgB3iXuodLsL1BcpiwG2RA4vRqg75uxOXALlgP3lqT0EnVSSSkU7Gcfs1zabifXnV+QS7StsRj0Fkk6SvaoM8+bxpjfdAC/P7k8Gxg1kmDhKzS26WE7oewAp6Ar8wgtD+CrqLvgx9l0dZnnzHGOsayet2lT8hEltZL4Be2X/JF6N3wGnx1fHq/Cv4qEG199hnjL4WFxDrWa865aNZJgxVGblcKfjXy8PnVn4VeDkfgDjwKuY0+CstgJvg7Jt+xYLVwNZSUCaMQBlWD37F8fHdhH3hyF6BlDXov3AMTFRPv4aOZWtImjIYwiV+EcrS/a/zJUYAt2vrsSypfNL6+/gMAAP//EjHAmAAAAAZJREFUAwDN1VlIqnmF0QAAAABJRU5ErkJggg==",
        [29] = "iVBORw0KGgoAAAANSUhEUgAAAB0AAAAdCAYAAABWk2cPAAAEAklEQVR4AbyWWYjNURzH77WMpbHOZOcN2UohHoQSHkhJ8WB9IWsoWyhRRGTLmjzYEiWllJI1D5a8eKBJebDMjGl2YzYzc30+t///zp3mP7d5uLmdb99zfsv5nvP7n/s//y6x//RLJBJxoVynRA0G3UBv0A/kgXwgO+5FX3/cSdOBXbGe2AYD43MyigYJPQgeCMaC5WA/OA0uAnkfrF3/AHJ6gKR4wApOIOYa2ApyOxQloRsB/cF0cBw8BCfABrAULALyRli7fuOM709+d+yh4Dn608BQEL1TEnJwDgHbwXWwDJjgQuroV4BSIDtWQL87Nn4HvlFgMjgL5N6wFYi322kgOJKAk2Az8Fk0wu+BO1kBzwUzgez4GP0PwDjjzTvP2EegYC/6CkKxWBtRBN3JIDxHwAJg8A/4EFgJLoBX4Av4DmTHTq74YWyFwF25oIn0nSMOp1pKFEEdffCsB/OAJS6AN4EboDAej1eDRtACEkB2XK0f3AOnQBOw5G7CeRm2tpQoJkUmwauAq/sJ7wZvgGLNcGQLFqyIj2U1Qfah6JYUDZJyCTEhD64FPhOf4x92lGAc2YLc8JSeIciFuwG60S0piqsr8PTNgS3JZ/gBqMkkiN9m+cw9ymAccK6/sIcqHQ3YtDeHopZjCsZ+wMBHcBWCHZYUf3rzBVKMwUfxHH4WgZfY9NeHopZjPEaTXZHHv55xZ5ql/0rgNrAWrOkA67DfB7WhqCW1RGFpvuH0BEKZG9XwFDfAFaAkA0rxeT6aQlGfi4dBbkHGt4w7oJv9FooqYDllbf5lXED2FZlRAShmKT0IHhwPlf83S64v6whFPcqfmN1D5GGaSt9yQ9lvoah/E18EVUh4khfCXs4eLLrZbaGoZbW8L5jevn/yJfRzgzcO3c43c0AXEHkukqIcZQ9QDdPeBGXAW2ILbJn9RIlMxt+mKQLM9Uz4JeGikxrpgekGS/wRp5ewf5nh9L1TZ8B9mSxjqQN/X2KNvwN748yHfVxQa0uJBrv9jesqeAI8XGPgS8CLYBgTK54DJ0sXsGPFXKRvoyvEe3Hnw+64XZVSogTEEPavU0L/AHgM/O+OgA+C28AvgtnwaOCE8iz63rn6jVPcPN/BXhounpDW1kZUM8KW2dfgTsZ+KbgIS+Tz3YPtFngKXgNZsb30vTD8j/+ib553cRHzuRFMra2dqC4CFfY0+4lpaX0+RfhctW+rAfQtn+xYu58pd7Ebb15xMA+mti1S1BASXGEl/bfAHS6Gd4HLwNvC6092rF2/ce/wVwb5dNu3DkUNJTF5g9AvB34vuRM/2vzE9HtXdqy9gPhy4I3jX5CU6JZRNExhIsWb4Drg5V4Ge1XJjrX7UglTMvI/AAAA//8k40YuAAAABklEQVQDAN6ebErYJbwbAAAAAElFTkSuQmCC",
        [30] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAeCAYAAAA7MK6iAAAELklEQVR4AcSXSYxNQRRA/0O3oQ2JeSYWiNkCIcTWECIRIsQUEYQFFoh5SAiJKaaFKYaQGFYSdhaIIRaGiKVIJGaSbj3Q03fOy3v9+/f/v/svWnTq/HvfvbfqVtWrV1XdIvGf/vJOnEwmAyiAIugEnSPUtekLso2DOOu2QXYF4wuaTExgSyiiwR4wDpbCNjgQsRWpbTyyB7HtoSV6WNDtTBsehsNFWAlFORNbAdoS1BuWwBW4CftgNSyKWIPUdgNpjLF9rAu2Hyc9jt+O90UW6kCmFyrY445Yp4C93IucDJ2hFfyB0gh1bfqM2YP9AkyF7jASTDoW2Q7MGfiDnipR0k5Y5sMZmAhOdQnyMRyBtbAwQv0ouj5jjLWOdddhPwljwNlz2lETibTEJA2wtoe5sBuc5irkMzDBYuQxuAOPItRNrM8YY63TC/9GGA1pSXlOT4zB9zEBuQWcunLkdVgBd+FzEATFQRBUQGWEerE+uAeO8j7SQZiwMNIRqVI3Ykbre+2KazP0BN9dvJg+kKQcarHnKkkc0gE5EOraRs8o9Z2OdiYRo8DevkAegm8kdOpQsxc6bbz1hxFxGIaAA0FkL2HiqKI99d36jn8RfgKc2kaTEmMp4Gcw+K4zFhL2+sVZSYaJsfo5DELaY0TiDT9P4TfkU6w/i8Bu4Mr+ivySBe3fsVfFiV0A9tTpqsTxEMqY4sbeKSF1xVnxe3dXcmOJP7WG0h3uLLXK4sT2eAAGp8zEb9GViKYLHTTxJyKfgJ3OhbP4lfjKOLELwU3D5xoqOx1K1PwKjdVCNVQ1gv5wFk2UX8vNHBUndnRuAvbG0fs9K5s5Xaq5OHE1pvfgu3KhDUVXIv5NiRO7kF6Rws/HhJ4sHu6xH1fzlrhhR/yOpl3NiMQIfjxh/LxQm7+EiVmF7ibuVrdI4TnrLuZm35NdzU8Mc/6FOi2gdUSYo2Ht+kan2RPoNUF2xIN7E3o3Gsg7eRTbhXpzYBp0wFY/D6ZE6lhk1K5sv18PBre71kTMg53Qn8rtIKMBfGHRB94w+mHwFuJhcRDd607GF9KwIUft7uJF7geVbGgB8hzMAKfeW2JbkhRGqLv5eJROJ+Y8uFU6amfKLwVTeklLzKidYt/xbcLstduglb0cnMLmZW4DcjZ4vxIPh/U86zuNNNY61nUAL7G5eBGpkpZYM8mdcjcTb43eIN1/y/B5+ZuENLH3qGvoYoe84ugzxlhnbRV+LxKltOmAeEyVjMS6CDS5x9sDnpfDDvCO9RNp733/ntuirk2fMbuIWQbqJVFbPKaXrIkNoUISKtA/gtPoZc7Ftp1nb5BXkaJux/QZcxn7R+tCxkjxhSVn4tDLD5VrwOlzpT/HZMP7kf4HIeqXeNb3hVin1hnDlLs0mTiuSoPOgEeeFwRvmj+xibo2fTlHGLcTy78AAAD//3GPG1UAAAAGSURBVAMAxYB4TI5IkJ8AAAAASUVORK5CYII=",
        [31] = "iVBORw0KGgoAAAANSUhEUgAAAB8AAAAfCAYAAAAfrhY5AAAEZ0lEQVR4AcSWWYjNURjA72UMxh6h7B7sWx7slAeKwpO9kEKWpBDZZYlQlhDK9mDJo1KSCJEHkZTlQdaybzODGTNz/X7T/V/3uv9754rJdH7zfec73znf+c7/nHtOjch//Puj4LFYrAbkQz1oBI1BaV17xvHwi0IdsE99ZF5G52BBcLKTAzfG1hqGw0xYAitBaV17a/wdXP8obZUFm3pdKj3hGEyGgqzB6ZSHk0H7IFfDWTgK62EhzAGlde22r8Kmv5PIY4wgcA/su6AfdID80OB2gDo4mKmZnUKfBV2gCdSCcvgBSuvabZ+NTX/7tUF38gbeid4bCqAmRNOCE9SZGrgrDvthLrQCfd8jr8BecCWWIteAde2266e//Q7SNgr2gIFdesenGonoWKkk/auNbgZ2GILuTD8iz8AUmA5bwG93GulyW9c+lbp++ttvMHUT6IVMCUw9NThZ+41b0rAZnKn1J+iLYRncgFfRaPQTFEExKD9ph+uwHFbAWzCRhkhXMopMKYnMCWxjA1r9tv2RfsenyEXgRnpHoBKIUU8rcXspDcXwGAoha0kEx8tgnZAeg3pIs9mANJtCBq9Az1jik3dpu+HkyrVDmhAivCQH9xuNx60ZuIvPIS+AyxqaLW3JxSXujiHY1U6k6uDM2kn4bUbQ2UG+II/D56oyxico9VHWQkfw+Ln8Rei/o/079nKDIiNuLI9WcypmeQ/5EPyGiJyKvhfx9Ix7Ao6gh+EpOU/btyB48L3N2iW/bSNZOxHUnMpXvDzX65CuQCbcD7fwKQmCm3kLDP7yGPwZehnkXJhoGXj0PIYf0TPxhTZPTUUQ3I0RnEWzNYusuzvnWWVxDIIb0E2gdCLu/KAtS/e/awoCuMSvGcpd6ifwQlBiqr4SBPc7u7tLCJUPfaEuR9BVQK2eEgQ38weEeAMG9ArsjO5EENVTKoOz+9xc/rD4i2b2/uBMI6RPpEof9H9ekgd2h3sdviOK5340ciT43nI1UHMrfi7wvdYQ6fvOI5zWOTm43/0RHifBn0BfID6JBlFvwCDJvpjCS9zP23EAHtvA911oAokBWXqPmdfgITrcBCfjzeRFMZZ6MwauDaGroB38hfRiGof/PpgA86EtpPVLBKcxwgTceK/QfQzcRVpvj9wOW2EgtCSIj0OzKUBXuko+QmzXz4y9YDyuL+nzAUwO8aukBI+b3XDu/AXUr4F7wceh1+0J6t52vlZ8Nk2krrTuhWG7fvrb7yrtvoLek1jVweNO/trdp6OPQN9gzt4T0RTbUHApfWi4Isp52IaB7fq9QHfZtZuICWFKLWGZu/wxJuEEHMQAk+jmjeVAPg69Pt3Bngqln0e77fr5GtpBnxeOA2lZ05b6gNSQDJ0c1OfUHewbwY03A+l16ev2APpusO7yj0HXT39vN/tjCi+hmSe7MgFXoRTpJJ7Tdgl8JLipNqG7MoeRl8FMDap/aLb4JEqVwROeKEygAhzYe9snloGU1rX7vfHMrfwEAAD//6uGDa0AAAAGSURBVAMAKV6PTiAFYHMAAAAASUVORK5CYII=",
        [32] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAEa0lEQVR4AcSXWaiNURSAzzHdax4zPfBgLAovylAylKEokRfEA0WIhEIhipLMY4gyvMj8IFEovCi8CVGmUO51rztf997j+07/fzp/Z7j3Ppxof9Y6a6+91/r3v/+9120T+8//Wp1AIpFoA0XQGboGqGvLOx++cSiG7uCYtnkHhIuDs0E7IftgGwozYTmsg7Wgrm2oPqBvZG5scfw6whg4B3OgOOKEIdIYZGAH9adjPhyHe3AWdsNm2ALq2uzTR9/+jO8IzpEe/Cj+E2EEFOVMgIFtcegOU+EiHIR5MAh6QDHoI+ra7NNHX8dMw0d7V6RPfhg5GjpDO4hnTYDgdrrcq3E6DZOhJ/yFn/AMLoNPK5fQtdnXgK6vY06i+4omII+AwV1RV4SfsVhGAgT3iXrRuwk2QD9ogk9gsIXIxbAV9gdsQ2pbgDwB+jrGV7eR3xcgIzi2aAIEN6FudKyAZeArqEY+hCVwAF7Cj3g8XgplAaXa4BWY1FLkY3A1nMNEIk9OX7IZMKkE/xUhXa5VSAca/Aa6K/EaacB6gibQI00b1GMsh7fgpqxB2uL+l41UAsHT++7W4+j7930/Qd8D35i8DjIC05dqzGEgN+RIjNvBzYbI3VIJ4OJAd/xYdDfhd+Q++E5gk0HN3YLgLnO420fh7Yoicrf0BDrhNhf8ZFy6a+jvwGVFNNvcvEPwcp9k3XD0hc2VdJMmkgmQvdKdPx6P9lABt6GSp9cZtdnm8g/Gywf5hfwKX3LwDftHqDcwMmZQ35vvzMzeY/wM7mJEi1ojXu782UjPgEnIXEyn7xbUhgn4zj3FlAZNLn0rnj6GbxO4Yn6iX9DzoY++DWECSr9/pU9SQnZKRGGbAQsboZnZwwR873/wVbqbe6MrEYVtYQK+93DTuQ+GE7YDX4c7G7VwLUzAg+YNYSpB2zBkuClRC9cMltzBhPgNL8BkPIy817sUehWSCRDU5sVzF8VDyCN1EXryVSAL1tITqCXKI/DWc08MQPfOH8AqeFDxs+XNMdAD+oFFqHsrY4JUAhwcfgG+Bms2j1KDTmHEDhjIJFa9zW5K/Kx8vYQGMm4XPABvWE9Z1GhLJRCY65DP4RR4r3uuW2BaTnlL+kRZv44gcAfGWQPq64NY1HhBuZ/sozvaIgkEq+B5cB43i8owiRn8tga0Ch6HbsXbm6AmJJ4bVj32WSXr63nvA/hlWS1nvVUjCTCxX4RHsCWW16rV7Q/s+nnTrUG/DldgLxhM1K/y2+pJH30d49hD2I9BFWQ0nTKMrISb0PvgDJ1Wxk+R7g/3hUWqt5w1ohWvqFvr98XPzaavYxzrHCXBnHRHW9YEdGGAK+Er8MvwLx+r2zv0eWKWIf1q9BF1bfbpo69jHFsezMWQzJYzAV0Z6BVrdeRS3sTm03rfr0TfCVbA4peibRY2ffT1yq1xDmw5W94EwlFOAtXg5/kB+32w1vfvBHHDavugD+jrZ41b/taiBNKnYPJGsEKuQlYEqGvLCJo+Npv+DwAA//+guWVyAAAABklEQVQDAMVtkFCt1PbHAAAAAElFTkSuQmCC",
    },
    chevron = {
        [8] = "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAASUlEQVR4nGP4//8/AxQLILHhGMbg+f///+v///8n4FIAwhr///+//v////7///+zYFMAs2b3////t////5+DZAV4rSDKkVi9CQCiZMhHKuGxMwAAAABJRU5ErkJggg==",
        [9] = "iVBORw0KGgoAAAANSUhEUgAAAAkAAAAJCAYAAADgkQYQAAAASUlEQVR4nGP4//8/AyGMzDn9////9v///7PgU6Tx////6////9/8//9/HlyKQFjg////u6GKVXApAmEOqKLjZJtElJuI8h1ODABKKf1oZSSdoQAAAABJRU5ErkJggg==",
        [10] = "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAVElEQVR4nKXQMQ2AQBBE0SsoKZBAiQxEIAgPyEACMiiQgIgrHrmOatmE4heT/GQyU1AyvMOKHf2XOOHCiTESGwMO3JgjsdFhQ8XyW0xVp8ek7wl5AB7IOOZi6WK+AAAAAElFTkSuQmCC",
        [11] = "iVBORw0KGgoAAAANSUhEUgAAAAsAAAALCAYAAACprHcmAAAAXklEQVR4nGP4//8/A7EYmWPz////7f///5chRrHC////b/////85VCNexSAs8P///93//////f///wRCikGY5f///5P/Q0A/lI9TMQyvh2oIoIrJRLuZpNAgKZwJYgC6MXqbYoVGQQAAAABJRU5ErkJggg==",
        [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAAAZUlEQVR4nK3RrQ2EQBBA4RUIBJJirpwT9EIJlEABSAo5cYUgEB8hLAkKdhImeWKSeZm/hBThmtQY8SkVGvyx4Fsi7LSYHdGjehJSLhqyNOXOt8JJhxW/q/SKEBoptHT4rOHHFbEBTKvCkiBy0eQAAAAASUVORK5CYII=",
        [13] = "iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAYAAABy6+R8AAAAaElEQVR4nGP4//8/A6kYXSDn////IaRqOv4fAppJ0STy////3VCNm////89DjCYQZvn///90qMbL////VyBGEwxn/P////f///+f////34ZYTSBcAbXxOk1sItlPZIUeWfFEVoogCgMAg0oQxDtZPuQAAAAASUVORK5CYII=",
        [14] = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAaUlEQVR4nGP4//8/AzkYXcDg////KeRonP4fAtb///+fhxSNIv///98P1Xz+////MsRqBGEWJJuf////34ZYjTCc8f///99QnECKRhB2+P///2uo7QU010iyU8kKHLKjg+wEQHaSIxoDAPPJZUFO1DnBAAAAAElFTkSuQmCC",
        [15] = "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAd0lEQVR4nGP4//8/A7kYXYDn////EVCaZM0x/yHg9P///2XIsXk/1IDn////tyBFMwiz/P//fzrUgO////9PIEUzDGf8////N9SQdqihRGsGYZf///+/hhqwGT0giYkSj/8IkEAXm8nyM9mhTVE8U5zCyE7bJGEAWXa/7paxzOYAAAAASUVORK5CYII=",
        [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAf0lEQVR4nGP4//8/AyUYm6DB////Rcg1QOU/BDz///+/CTkGcPz//38/1JDv////jyHHCyz///+f/R8Bmkk1AIYz/v///xtqyOb////zkGoACLv8////NdSQy////1cg1QBYwF5HClwRuhpAkRfIDkSKopHihERxUmagNDORjAGnLiESpAne/AAAAABJRU5ErkJggg==",
        [17] = "iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAAiUlEQVR4nMXToQ0CQRAF0BNIJAKBpAzkFYGgAMqgD4pAUAgScQUgTyAQiEc2GQICczubsMk3K15md2Y6dNn8upxjkUUG3LHNIGefc6hFZjh+Qad44iTknT2eAV2wqkFKeowB3bCpQUrWuAZUKtvVICVLPAIa/1JJ+k9S3WkyJ00mtsnuNNniyXkBfTCITHogIN4AAAAASUVORK5CYII=",
        [18] = "iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAAAiUlEQVR4nGP4//8/AzUwLgkWahjU/P///99AdgOlBk3+jwDL////z0OuQSBvzUYy7PT///9lyA0jEM6BehEEnv///9+CXINA2OX////voYZ9////fwK5BoGwyv///68jebUdW6wSGyugAN+OZFj/gBpEFa9RJbApjn6qJUiqZRGqZVoGahUjZGEAphn1utkzIcoAAAAASUVORK5CYII=",
        [19] = "iVBORw0KGgoAAAANSUhEUgAAABMAAAATCAYAAAByUDbMAAAAk0lEQVR4nMXUoQ3CcBDF4QpEBQMwAgMwAmN0BEQlnjEqGALBEMgKRqhEViA+QtKk/xAQcJdwycn75eXeu6tQZXUa6BNsgwFH1FFYa64LVhHYAl0BHCa1oZ3tcJ+AI5qoAVvcCpWHqJtrXAvgCctINJ7D5wLYvzPmmxzVLwr3f1eWtrM0N1NylnoBqbeZ+jV+7lTYA+MEaZdJUqdrAAAAAElFTkSuQmCC",
        [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAkklEQVR4nMXUoQ0CQRAF0BMIBAKJRFIAAoGkCMqgBDq4AigCgaAMJAUgkAjkiUdQjAC1P2GTtS87M3+nQ5e8UewXOMYRJ8wS4Mrn3LBMlHwo6BPbRA93GAq8Twxlg0dB372dtE55gWtBL5i3xmaKc0HvWLfmcIS+oMO3l/4NjJYcHUo0NtFgR79efDnE11fTjYMvsGLjnZpwWq0AAAAASUVORK5CYII=",
        [21] = "iVBORw0KGgoAAAANSUhEUgAAABUAAAAVCAYAAACpF6WWAAAAm0lEQVR4nM3UoQ0CURCE4RNIBAVQABJJCUhKQCIpgQSJoAwkAkERFEAJSAQCgfgIISSPE5iblzDJ2D+Tnd1t0KQdB/6CLnDAOAl9eOuGWQq68a1VaqbLIvFLO/QTRU1xLcAnDBPtj3AuwBdMEis1wLEA3zHvCn25h22rwHVX6Mf7VuL/Shqfabz9+J7GL6rK7Vf5UlX+aSdXgT4Bhstj60/YdDgAAAAASUVORK5CYII=",
        [22] = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAAAn0lEQVR4nM3UoQ0CURCE4RMIBAJJCRRACQiKQFIABSBIKIACkFcCAkEJFEAJSCQC8ZEThMcTmNtN2GTsL2Zmp0GToRToL/AUB8yjwSef20SCt76vxTDK4zWeBfyCSVR4C9wL+A2zqFZ0QV4L+APLqLqNca5830WAOw2wr+BHjPqC31pVobZ/C06xIiW8lLqlPEjKS6eNUNpspg19b6WBX5Bs6mxEanBFAAAAAElFTkSuQmCC",
        [23] = "iVBORw0KGgoAAAANSUhEUgAAABcAAAAXCAYAAADgKtSgAAAArklEQVR4nM2VIQ7CQBBFKxAIBBKJrED2EByhopIDICt7A47AETgAB6hEcgBED1BZ8ciITdoVpOL/hEl+sur9zczf2QIoXLKBf8E3wBVoHPAAp7oDWyW8YVk9cFD2PG4/zQw+QKUc6BkYZwZxrpVpKYF31qZOBQ/tgWdm8AB2CniK5y0zeAFHBTzpkg16AE4qeKhdM4O/ubmt57a02HJue6G23WLditZ9bv2JJLLCv2OndzuWR2TIAAAAAElFTkSuQmCC",
        [24] = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAAsklEQVR4nNWVIRICMQxFK5CIlQgOgFixEolEIpEIJIfYO+wh9hBIJAdAIjkAAoF4TIcwU2ow/wv+zDcVeW2SJglITluD/wIsgS0wcQAWwJO3TsBMDej41jXOpCk6FK/IugMbdZHXEbhUr+6iXI9LBRmBqQqQ3QDHCnIG5ipAinYdKsgt2lkC+HhfFf8B7JSA7FXcvlT7NwBbiqxFtrap9aNZR4V12NnHtX3hJPfKlNkOeAHCHQoutKa+WwAAAABJRU5ErkJggg==",
        [25] = "iVBORw0KGgoAAAANSUhEUgAAABkAAAAZCAYAAADE6YVjAAAAs0lEQVR4nNXVoQ0CQRCF4RUI5ElKQCCvgJMISkAiKQF3JVwJCIqgBCQSgUScPIFA/OTCbiATEsy8SXjJZOWXzc7sJCCpSw78QiqgyacMOfPKFViokAfvDMBKgWwNNGanePhlvsVn9sDUu7vmwMVAJ2DmiZROOxroBtSeyFgToDPQHVh7IqU2Xxqi9UZSHtLeQAdvpEA2/3UT6ZvIu0s+J/KJl/9dIb9wyD4J2YwhO96tQpAnqLOjedY9JyIAAAAASUVORK5CYII=",
        [26] = "iVBORw0KGgoAAAANSUhEUgAAABoAAAAaCAYAAACpSkzOAAAAvUlEQVR4nNXWIQ7CQBCF4RUIBAKJRCIqOQASwQE4AIdA9hbIHgGJ4AAIBAKJRCKRiJ9M2IRmSRpCZl7CJE9/6fZ1pwlIikiQb6AKGEZDNa+5A4tI6Mh7HsA6ClploD0N0I94R/N8dO05ACNvyDIBLgV2BabeUMrN2xeYPenSG7L0gA2fU3tDXSXZAgNvyDIDbgV26irJr5BlDJwLbPe3kOTowssgqbfkg5VcQZJLVbYmZItPtsqT6ufENTLoCf2wQ0lAAn13AAAAAElFTkSuQmCC",
        [27] = "iVBORw0KGgoAAAANSUhEUgAAABsAAAAbCAYAAACN1PRVAAAAzUlEQVR4nNXWIQ4CMRCF4QoEAoFAIJAIJAKBRCI5BAfYI+wNEAgkkkMgOQACiUQgViAQKxA/maQkUFYgOi9hkqe/Np1OG4Cgigz6BWsDXQU2AW7AAyi8sTWftQVaXtg87uq9DkDf68wMvCfgBRh7YJYRcE5AW8DCA7P0gD3fVXpgITbHpgHcAZ3c2CvLhsY5AgMPzDIDqgS8AlMPzDIETglYx4Vkx0K8c3UCrv56Z7Izk3Sj7J7JJohsNsqmvvQ9k77U0j9IUP6uskeKPQECkOkpH6VPRAAAAABJRU5ErkJggg==",
        [28] = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAAx0lEQVR4nN2WoQ0CQRBFVyAQSAQFIBBICkAgkUgKoAgcJSAogBIo4AqgAAQCiUCeQCAe2WRI4FjJ/yE3yTdjXnbmz8wmIDllhf0dsAscgAewBTpq4ILPqIC+EjiO173HJfKyHs6BugGtIy8zzQg48x1rFTBF76oCdB/m+jkwhUt3BegRGCiAL60KZroCExUwawrcGtA7sFQBs4bAqVDijQqY1Ytt1IxZK4DWklpNYxsL6+BbV5t1eVvPk/0A278Y9k+URO0HPgGhhJVKBAJ+WwAAAABJRU5ErkJggg==",
        [29] = "iVBORw0KGgoAAAANSUhEUgAAAB0AAAAdCAYAAABWk2cPAAAA0klEQVR4nOWWLQ4CQQxGKxAIBALBARAIJEdA7gE4wh4ByS2QewAEggOsRCIRSCQSiXibSbohTIpsB0KTT4yZl858/RFAohUO/FpoDVyAPTCJgI6BJ6+4AnNv6Ah48B7pXHk/b2WAU/YbbyMt9GnzaIChF1TURK0BPgFTL2jSANgZ4Buw9IL2qjNX9wZbe0KTVsDdyHrrCU2aaePI46Dl5gIVvfxogFtPqGjZnA3wR1f/XKbhfxru3tA6De9I4b03fMqEz9Mim0ORHUlKbINu+h9oB/6TR58PzV4QAAAAAElFTkSuQmCC",
        [30] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAeCAYAAAA7MK6iAAAAzklEQVR4nOXWoRJBQRTG8Q2iKAiicIMgeABBED2G6BE0DyGIoigKoiAKonCDKAp/szO7Y9w59exnODNf/s3unt09AQiKSNCvhitgl1KVhA+86wFMS8FnPusJLErA47TSZm2AlndzDYCrgR+Bricc02mcd64bMPSEQ9ratYHHo5h5wjnz1GTNWnrDMRPgbuBboO0Jx/SBi4HHK9jzhENa3d7Aa2DkCeemWxn46SdhyVZLmktynYo/IJInU/JJSL5F2SAgG31kw55svHXL/8EvsfAAShMUND8AAAAASUVORK5CYII=",
        [31] = "iVBORw0KGgoAAAANSUhEUgAAAB8AAAAfCAYAAAAfrhY5AAAA4ElEQVR4nOWWIQ4CMRBFK5BIBAdAIjkAAolEcgAEEonnCIgVCARHQHIADoBEIhEIBOKRJrMhWQYByewnMMlXFe+3/dNOApJKMvDXwxvAHCiAft3wGY+6AdM64Uueq7ATCYf3gItjYAe0o+FZXeDoGDjaWig8q2W7rVY+lWE0PNk9F44BrCNC4aUmlvxqrYFmNDxrAJwdA/t3gvhxWIAOcHAMnKxLQuHJjnnrGLgC42h4GcTFiyCOouGlNg589bM7l925LO2yPpe8cLK3Xfaryf5z6SQjneGk06t0bg/V/8Lv1jW/DYj+AHcAAAAASUVORK5CYII=",
        [32] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAA6klEQVR4nO2XrxJBQRTGNwiCKAiiIIiCBxAFUbwP4AHE2z2AIHgADyAIokcQBMEDCKLwY2fujhl2Ke75hnFmvtm4vzn7nT/rAKeU9PKvAejdzhwYKgDawIV7zICKJUDGc6yBuhVAEzhHIPZFdkw80AEOEQgPNrAAcEXKNxEI74+JBYArzDePQPhYANWyAYLGD5URYgs0LAC8+sApAnEEuhYAXi1glzDnyALAqwasEr7ILQCCOacJiOW7zvkJgKAsYc6XM+QnAKRPIDWhtAyljUjWiqXDSDqOpQuJfCWTL6XytdypPyal6w9wBYePhBHotM9GAAAAAElFTkSuQmCC",
    },
    discord = {
        [8] = "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAlklEQVR4ASzOOw6CQBSF4ZFEwwawMrHyUbAYMeoWdAk+KmNhqbuwEagggR7WwBpgDTD8J5lkvpkzN6e4nrXWR4AlFo6yZr5njJnjjhRvJ+G9IVDhQDhihZ2z5j1hr0JEmKFEiw4FpohUCAkWPzSOsmahCgNDnSfXFhu8MEGvwpVQ4wMtq+W+5AoPFbTxmU+MDDn+uCAZAQAA//9xmRxVAAAABklEQVQDADeJNIUTgg8hAAAAAElFTkSuQmCC",
        [9] = "iVBORw0KGgoAAAANSUhEUgAAAAkAAAAJCAYAAADgkQYQAAAAq0lEQVR4ASzOMQ7BAByF8aJWEoMYuiJGVukFMBEJwRWcgQ2xkDiAM3CP2p2AySTCUN+XdPjl9f/60jSfpmmIEmqZapbe9mE+CIIyBjhihSXWOMC+7KjN4cseOYejGdmHfcfRlKOCb6ZA/uBtP3EUU+SwxxYv7DJEEDuKeApRRxN+qUGqSEaOnjx80EIXb5je9g9H/uyZFxeMMMYQV9gvHCUcG5xwxw2mt33yBwAA///PMtOmAAAABklEQVQDACAwO2PaMv4aAAAAAElFTkSuQmCC",
        [10] = "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAA0UlEQVR4ASzQO2oCURiG4ZnJhUhIJJDOLuly2UeIoOACxAVYWGittWKtO9BSFyBW2tlpLQpqoYIrcHxfOMXDf/l+huEkaZrqifqGd2QDe3dmSRJFUQZfqKGJUmDvzizjYY6ggyrK6Ab27sxyHhYIfvGMB7wE9u7Mih7+EzxihR5OOKOPJcz+PPxmuMMcY2yCEXUGsx8Pswz38Mt16ic+0EAeZq8eLhguOOKKdWDvzmzhYYWghQl8jiJV9lN6n6niof80YOEz7OM4Poh5hzaG2N4AAAD//8qX7Q0AAAAGSURBVAMA1UxIUfqk8g4AAAAASUVORK5CYII=",
        [11] = "iVBORw0KGgoAAAANSUhEUgAAAAsAAAALCAYAAACprHcmAAAA+ElEQVR4ASzQu26BcRyHcX96SEt6Ukm3Hu7AKL2Dpk3qBjp0aZp0bZoauAUJNkxOC4vFPdjEZhGDQcJgsr2eJyE+vr9TXiIe4xVFUQIpXCGJU5j2zhOcxeIMTyhu8YI/PCMH85d0nvHOJ6cZFFDGF1rowvwmnbtPe5xlkEcGl/Bb7g5p7/ydPuuxxQXNDjNsYG3aW7vPe+zvO+Zgik/UsUUT9hPSfc7jh0NzRqZwA+fXZBLnOMK9w0Dh+5GPBt7g8pX06U+kN8HjDs0Sc/QxxAjmgHTuvu1xkcEHeqjiHz8wK6R/o/uSxysGY3i4IDchhLUJ+xrpfrUHAAD//9Ln+w0AAAAGSURBVAMAeStQN5ZL1SIAAAAASUVORK5CYII=",
        [12] = "iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMCAYAAABWdVznAAABHUlEQVR4ASyRPUoDURSF8yYE1CRioU1ABRsbXUWsoo2VbkAtXIMKNtoJioKliqAJgWQHyRZSZAMpkjLkr0lg8n3hDXzcc889d+bNTJLhStM0QA7ysAbZyDpVz1kgmkkwsogCHMIFnMBepEy9BGcFsz6hiHEOdXiGT2hBG9RPVGdmii6UMG5hH3bA3ifsRq3nzEzJhQqDA1BPqbKgilqcmakoPOcGgRl8wBtMIu9UcWam7MIRZg40/6k1GIFLVaqozRy74Bn9UnmGN3ANW7AJ6iuqH8bMtgveeY6p9n3O0PZyirZ3Zj9VPGB2oA9f8AgvEfU3egBm7l34ofGHuej5/+hfI2q9O3ozv0kIYUjTgwZ0YYy3Au3L6jXRPfzhEgAA///hdF4WAAAABklEQVQDANphZCsbs8RnAAAAAElFTkSuQmCC",
        [13] = "iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAYAAABy6+R8AAABRUlEQVR4AVyRuUoDYRSF/cdtcGkCAU1lakHsImppI8HOSrvYqoWCb+BSuryAC2hhIYjY2QlpXEpfQAURRQQZiZjJ98EkRUK+Ofeee+7MP0nUkX3SNI2gB2Lo1FbBXr+VNRgcEMrDBJShgDekgn0JzeN5g+B2jDEKR3AKu3AC53AMe3AGh2AudilHswyTUMiYQr37NDoM+nor1DmXxihmoA/qGfrd1GrTc25uXHOO4SD8wwvcwjf8gWr/TO3cXNklj+F7JQx2YBWu4AeuwX4bdd6LllwqUnSBX3s1eIF2NVc05CNVn7ZOcB/8mfvRWTiADXBubsCL7+FRUgbv4JM9yhe1OoLqOzf36lIF8wJcfkPnYQn8G1R7l5ybq7hUJbAGi7AFT3ADl6Dab1IvgLlqFELwCJ8YD3APCV4NfqFmD3fwCB94SQMAAP//lPcj4QAAAAZJREFUAwBdXW8e8wtL+QAAAABJRU5ErkJggg==",
        [14] = "iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAABc0lEQVR4AVyRuy5EURSGz9wICRPJSIxbjURBh2Ya49JJNBQSIy6PwBOgQ0UjQisaUXsA41IIHc1IlDIRg8H4PjmS4SRf1r/+86+99zk7GlQ9lUolCgmI/dpq0PuT/Wl4EYck4XYYhA76FDSjO2EA9JJ4cXTgDooUzTKcwD5swSZsgPqAegwr4IIJd2ykmYIcdIG7jlAnQrJUvW7qLExDg4NpxAw0gbvr1aDrQtR6vjNjtlVjmIAr+kNe0U/wDJ8har0SvZk2atbBDMLVP6iXsAB78BLi982jL6AMZjMO9tJ4HM1T9BkcwRu8wyHkwXcubrbHwRZMj+A3eBX+hDE8AzKO1huimjGbdtAGL7D2IXbBo9VTPdYcVa+faoYSxBz0aH68x7rBPYfHf/h9t3hmzOYddMV1zGuohVXw7kap4p2uoT22GXXOwTvMbZiERbiCB3AHKaD920tUMzvU+2gkEilDkcaAQyX6r2p459U4XMAvQvkbAAD//0e+nkkAAAAGSURBVAMAnpJ8GxyFbnEAAAAASUVORK5CYII=",
        [15] = "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAABnElEQVR4AWSRTStEYRiGzxnkI/nKxkrMVla+YsFKihJKfoDYyEeE1Wz9An7DlJ2PCElZKVHW2DJTszIyJmZc1zhKTHOd+3nu53ne877viQV/fsViMYQYhJZUMP/XWzKiYg3azEArtEEDeT3aCO3QSt4M9pXmflaspTgKO3AM27AC66Ca61u3r5ZFYq5QTUM3bMEYxGEIHFpAl2EQfLt1++yvdthtzVFsARcqRyvB3dRFaq5v3b55/EaHOwgGoAoKkI8wJgzU3559/RQ6HR4h8C3ebpb4DE7gBT5Bz/w0ipHA/mGH3b/b+sC9g1VYg2t4hxsw178ldkH7exz2giow/b/xcBFxsEiu54AYYwX2xx1uIlPL0C7YBD9RH+obVHPpxbPP/gYfvsFL8cxexjgNU+DNIoHeJMEEGNtnf97hJOYzvMI97MIhXIFnVM31H/Dssz/pcALD77yPetZLdANmwF2o5hfk1vfQWUg4nCI4h0WYhgNIh2GYgiewnsY7AutLqAulYhQLkMPIwCNkyT0T4fc/yv3ebjtDnoPCFwAAAP//kfBGAwAAAAZJREFUAwAw6Y8VMbwYjwAAAABJRU5ErkJggg==",
        [16] = "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABvUlEQVR4AYySOy9EURRG7514jneEMNPRiGehRrS03qVoVbQKkUgkFB6NSDQ0SETwUyQiwR+YZMwMhcfEtdbkikbE5K7Z++zz7e+ec+5JBP/8RVEU/iYtGTgJ5VAPrZAC8yRR6mluJ3fOutqSYcmAyUrogkU4giuYhNmYKeI1HIMatfYECVzLKaZgD5ZgBHpgCzZiNondMAxq1KbprXAFLm+OiT5oBJ2lgbw5xtyaqOmnbk+dBm0MJqAWSvsi/vWoqUFgT0qDUQZuoYxYhBxk4AU+Y8ytOfdBTa09oxq4r2qKOj8T12AMLuE1xgMcJ18FzQhBFX9DGvSSVEAEWbDxIY5vRLF2T66RKyEN7OnRIM3IJbkCD2uAcQsMgl9IzK35sibqPvakNUgyspkQ1PG3DX7vBaLLlHly78cO0a+mXpIafB+MW/AQfWMHQufeiWLeSe5nVKPW+pMTHtotkxoViOewAvtwAqdgbu2C3INWa8+aBi5tmglvnsVH8jNYh2Xw5plbu2N8A97MGeKxBrp56rsULB4Qc2EY5sMwzMbkrcEheAO9yvbkEggiKEIBMmCz+0T781BX45watY6jLwAAAP//0Ucu0wAAAAZJREFUAwDEbJUhTt9OegAAAABJRU5ErkJggg==",
        [17] = "iVBORw0KGgoAAAANSUhEUgAAABEAAAARCAYAAAA7bUf6AAAB30lEQVR4AayTyytEcRTH7wzjLSZiq1jJkhSi2LDkD5BEKHbCyisrsiBWWCpKlsjCTjZea5bKAguPvDXj85nGlJ2F6X46r+859/zuvRMO/uGXGhKPx8OQBVEognzIhAhojc1bV5fqTTiIIixUDG0wDZvQCXXQCNourHnrrfgOtC/w7g4qIDkBy6DYphn8DVgHrc3mratTX8ACYQfkILLYji2BPMiGQjAuTVpj89bNdZCvhxyHRHFcXVEa/l8udertizqkkq5ayIQ4fMILvEEMvLTvOOatq1NvX5VDWii6or6CS+JFOACbbNAam78g/wHqc7HNOjU4TsUEiudxFI9hr+ALrmEUFmAO1GEC+6odUkGUeFVY177HepRnrGACrY3mraszb1+5Q/w+fFAmffo9OE3QDeVgrQxrbL4XXx0msFbskHSjJE72ta0QD0E+qNEO4q9CA2TAzxVR4Lld1RU9/xlV1/ZtPOG7vtb4lfgc1Km378ohrrdD4QYU+fF5pH7iKZiFSegD826rTr19vQ45oujqNm3jH8IJKHD9Jfw12IVTOIYtGACPeBQOhUKudEtiH4bB/8QD+Td4hifQesQH6uMwAntwR+3FTQKcGLzCPTyCHx2a35d58AbqvInPJfgGAAD//+0YmOUAAAAGSURBVAMAi+ypI/FgBUIAAAAASUVORK5CYII=",
        [18] = "iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAACAElEQVR4AayTOS9tURiG9z7Ivde9xzUUIjHE0Aj/AL+AxBwkSoVWFGgNBRpRiF+hMzdoTNGTmBMFlQiFcXseOVscNdmP713vN1h7rS0R/NBP2qAoijLhL+RCElyHRFHrmbMm8+sePgZRmAFJElXQC1MwDOXf0JvEs6bKHshgHSQQISIb2mEBJqAH+mENNlKo9cxZY20buWxnuKMsFiUwAJVQAP8gH8rAnKj13Lk11g6m8lkOymHRBRY6FPn5uNt48VXrWVuK6IYcBxUiWsDXi4sj1kJIe/RE01p7mlkUOqgBUQTegkUP6Eu4APUbUdT6otazx94GB9VR+Af8C0/EffDgPchttN4zcRf0ZAetZ4+99Q6qxfR9CYFN64hTOINVsEHfW9MTtR7pwN5aB3kjblHTb6IC8R9ywZvRE78pfYl9SgJ7ix3krRk1f/GrFcZhFDpAT9R6Y3i+uh4ysDfpLw/NQ9YUCxoRnkUe0d2IO9RrwvsN8WPvq4M83FvcF3gFv+RN4hXcfEPP3Ba+tfbYe+CgPswZOIE7qIFlcFe+jnnpTHkrxGqw9phob5+DvKFZDJumiUuwCOewB96ct+T1+22Zc5j/vPbYe5oIw9DrdfohTXMwAjf4LymeiI/g2tpr8kMwD0dwR+7ZHQWICCy8J5qIvxHq0h/yDrbGWns87OAdAAD//84ZZkEAAAAGSURBVAMA2xGyJcckhMwAAAAASUVORK5CYII=",
        [19] = "iVBORw0KGgoAAAANSUhEUgAAABMAAAATCAYAAAByUDbMAAACXUlEQVR4AayUy0tVURSH97mV3UzjNjATegwSclKD7DWIMugPKAiKoFENekyCatKDhCj6CyrwMVJ8gCA6UsGpThTFkc4UwedIvSo+7vH7Dh5QRw68nO+utX7rcbZ7b28mHOFn37A4jiMoghIohRN732UM6uati/bmk2EUOCRLogzuwFv4CVfIVaQQV4K6eevKyGUhGZoMo6AIrkE9tMIXeAmN0A6doDVWN9+CVgfXwf6QYeoxghx8hho4D8ZnsbfAFdzA3oWboG6+Av8hfIKcc1zZKYJ7cB9OgxomuPTjOO6bNkUdOVhnvX0PEIoVfNMLgjNgjDn0Y719z+nIGVTh3IaT4LPN1yoswTrE4KM1Vjdvnbp99lc5zCW6XH0blqnwEL5iB2ANfBw0iPMNmsG6AtY++2t03Fyno4ctvkbgN9jwHWsTJmh/4DTBHxgC6zHB06x22FUiNxkTXNkijn/GClZ/A6uuncfPg3lz6oTB/kqHnSPyemCC1usglxGeQil4gtpn+JegGrwynjBu0lfuMG++xanoPfMydiF8hBLwcV8+4HRDA3jPfDluco2yDnPJ6cm4oS7du3eRKgelDVoHXkAvBuusxw325x3WRuReeFqKo8T/oQOGYQqmQWusbn4MzXpP2/52h9Uivod+WACX74o8ySfE/os92rWPseruXzm+9fa9w6912CxOD7wCfw28Ev/w56IomsFOwgRMElvrKv4SW/cG+xp6YTZDQQHSpSr+IjEOmxDIxSnG4BUxb10f8Tz5NSi4MuJgk0PXEfOwAW5wOPhRB/PWWZ8eQtgBAAD///tVMSUAAAAGSURBVAMAy77AJ7Yes1YAAAAASUVORK5CYII=",
        [20] = "iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAACdUlEQVR4AayTO08VQRSAZ6/Xq0IUVK7R+IqFNtJZSWyMsbLQaKLRaLQxMWploo3xGR/RTm0s7LTTRjoCHQF+A++GAgKECxS8Wb5vc2dzAzQkbObbc+a85uzsTCFs87OhYJqmBdgFdVCCPEYdok+Z+2JfuYHAIjTgOAqX4TFcgDL2JlEHbU+QxhzD3gBF5tnIClYNZSzP4D/8ghfwEb7Ad/gB6h+Qz8EYY81x0ayon5fgrIf78Aia4RA0wTm4CdfgKqhr02fMWWzmPEDW01hihyUmJ0HjAeROcBFR38O8Fm36RN0cmzlFXMmCe1FuwWHI2kZuZZhzhAS732dB9+4KhjqIYxVlGVZg/Yg+ZfSZa42yBVuwuoIroYYlXhPQBcMwB2kVdW36jDEWV9jByy9siQXdI/fExFmcr8B9uYvsBbuVAfR7oO8l0lhzzLXGeQv6V/0x+LMxzrsdRmAQOsFOLKhuUX0d2EfBgohgjWYLHmdmy4hseIQOoindG4+HcXahbifa/bv+UO2EB7fshIH7mcWCOp2/xea584xdQnd1uYjuDdL3Bt2i5qAGazX68ixpiOxGMfEb8ik0gnHi1fTaeXNcyFjc+SgaNMnUPXIvZIZ5BRyu7t7pF3XtYkz8KeYtYpy0oHfTP6nThAUcf+E1eF/bkD1V1LX5uf+wzYMLmduH/smCf1DuwE8YAoueRrbCe3gI3gJR16bvDHZjzTH3NvPfFrR1O/yM4Qa8g68wkSTJFIzDWBX1KXweLWOMvc7cXDusFAhMwbancVjYjv1EPwfTpkNfNx5j+8mvwBKkdog9BCewDPOwCLV3NdQ++sAYY/3s3L0GAAD//ysHJNMAAAAGSURBVAMABgjKKe69wqIAAAAASUVORK5CYII=",
        [21] = "iVBORw0KGgoAAAANSUhEUgAAABUAAAAVCAYAAACpF6WWAAACn0lEQVR4AbSUOWtUURhA78xoYmKMowlqOoURa7dCQQVxAbURtFQUQY2CO4oL2qogLqitdlYKCtoILoX5AaKWCsEUWUhCloGsL+dc3pskME0CCffcb/9yt3n5sAB/VZsmSVKAWqiBWTnaYEwK1dZUKSAxD3XQTGIJDsIBaMLXCMuhURv0H0KW8DWDdZVeUcGpbCBpPzyBj/ASHsBZuAo34Rpo30e+APPMt64h7RNsRizUMm2DR3AY1sIqWAfX4RKcg4ugrd+4eeZbt52YfYJb9lyKOCxoQdaDvhxyMbgDt70MXamt37h55lt3gXiR1RZcqc5dODbDEpjPsM763RTX29RVHsVwJf531DkP66w/QmXRpt70Vox4HsgERqA/RV0fZlBqV4tZv4Wkkk13oHhO6qhhlOkPXAEv6CdSHyLGfqFcTvmNzGLWL8XeqbIRpQayUUZ5Bu/hA3izw0iH8jFKFvM5mY8rDvtssukGTG8TEcc4838wWTrQ9SHCBNPMmHoWIxTss96ma7AWQTa8yb0Yq1P2IPUh4nvOYr5T9Sxm3D4tNvU8vT2dUsd0Cp6CW/XR++wwg/IMits2fhrdfEQc9olPKlozJgMeuKvw999EzBUggnIlir/9fUjzzEedHq60HdOzm0T6ZNS/oHfBQMoQ0ktS6hvENm6e+dZZr95uUz8Qn0nqAd+gh+0P4hb2eXgIr+ANvAZtj+QO+gow3zrr7dNq0zYCreAX6DuyG3wavsdP6M/hHtyAu6Ct37h55n/D75fMPm35XC7nkt3KWwIn4Djchn9QJj4IfdALSrduzV/i5h1DnoR30EVO2ZUGlEkwsZPAD/gKNvSsUGcPcvV7xp6pO+3EZ77nWvmexioCCYylxIQYqDKR40KyXP9JJWsKAAD//9gZ6ysAAAAGSURBVAMARgvTKwLh7PIAAAAASUVORK5CYII=",
        [22] = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAAC5UlEQVR4AbSUSYxMQRjH681mzEYYE2sH4WRwkIjYLiTiQKyJ7YJkbDdrHAlxIyEulhMHDjjgQLggkUjGdnBiDAlBImYYoWfGtN+vvO50dF9IplO/93311ff9q7qq3qsIg/QrK5zL5RKogmooyTEGjlVik3JrKxSZAIo1ktgC02ApNBOvh7qUemOwBMxpId4I1hYmKQiTNASmwk64CNfhJGyH1bApRX8H/im4ARfAnClYNTAhRGFmq6Y3Ac7CAVgA42Ec7IUTcCxFfw++47IQ/yBYm0m1QgVOQrABtkIrDAdnNl6F79aMwBZjzDFzzLVmOjlqNKjpimsITII14P6ZjPtPzRpr1XBLahR2dvdtFFKuAvNfzdpmKldBk8IKevpDCeRbDqcPeuEX/N2MOWaOufnxOhy1Rio8i85YcEZMGODxHZ7AFeiEn5BvWRxjV7GPoQeswYRKHmNgtsJzcVyt+4QbXMUjnM2wG7bBR3CVCnzC3wWObcE+BFePCWrU4sxR2JvgAdKPzaRbeO9BwRdYV69wP/5TeA4f4B3cBmswsanVqnCGbn4bcOOsTTjGxDtu39WIh23MMXFMHUpiM5Yx4ElqY5SH99JrMx/fa7gOOxPcP4tm4G+EyTAP1oI1mNjUiodn0JXEKA+LJ2LPwV3wrRqGtcA8V7if/h04D05gDW5s5tSa7P4UXxn3UjzQ0aQqWlyob8wxr5e5QmpsamUVbqfbDR4MJpjkVbpJ5yV4gJ+xX1L0jTlmzjXi1mCCGl047Qq34fil8m5+w3fGxdhXsALcTz9Eh/APwz4wthL7GhaBNV+xapzGtimsgF+sDQTOQAc4633sW9Bexrqf7vslfGNvsPfAXGusXU//OHRUJEniC+FWPCNwBJaD39sH2Kzj8AN6UvSt8Q10AnOXkXsUvN/d5PW54oCTg15wdv+eogr5ppFf2sh1zNfZ3E76XaCG2/LnQ19cxuAA9IOFxUMlvjlQNvc3AAAA//+JUNItAAAABklEQVQDAPbY4i2/YouGAAAAAElFTkSuQmCC",
        [23] = "iVBORw0KGgoAAAANSUhEUgAAABcAAAAXCAYAAADgKtSgAAADAklEQVR4AbSUS2wNURyHz9y6bSlalYZalIXHQiwqYkPEK8EGiVewEInHTkSwQtgg2BIbEZFY0GDFChuPlWCBpXirShRJS7kd33c6c3O76E2apjfnu//zf/3mzMw5Uwij+BtSPE3TBAoZSeUaiA2Zq6wbJE6TYnXYJopaYR5Mh3piRaiFoj4YN99KrAnsG6RXdkja1EzTUjgGN+EWHIF2WAzLQDsfexTMW+fcvuZMh1QIUZyA1tUeJ3oJdoECbdgtcBuuwRXQKrqZuXnrdjO3z37vQr0BcRL1sAI2wFSYAN5JDbYBWsD4lMzqGzdvnfXmN5JfCeoFn7EFkwjsBa0+02EP+7z7PXT6eGpc/jic5TAXamEkw3511GtQvBG1tTAeEhjJsF+d9Yg0Kj6DyUKog3yUmPyCr/Ad+iAFh1bfuPmfBP9BPtRZgNOm+CImXs0502CzDRdx1sE+eAO5gPYt/n7wji9gXUg/1qGOL3uJE7eSz8qE2PyCyXl4BnfhMvSCQ6t/B+c5uIinWPswcajXrvgcXLcTJg5X8J5Zb5Ikf7C/wZXmzT6yd8TyfA/zD2AfJg71ZinuMR8TQwN/bimPdQuHy5ft9vKduBorbNT3sJh3z1tvn3lRb5riFmgNikUzmZyF7XAAtsFYcGi3MjkI5s9gZ4OCmDjUm+hfZdCM28m973fkJAEPxWSsF8UErd8gj/wpAp5sX6B9uOVRVNyd4XPMo859aT5vL+xRVjDPa+1zyxm3zvdinzlx/sOiDrwusMBt6It5iH8OroM74iP2C3SCVt8ddQPfukdY++xXx/3fobhfMvfyEwq+gQfEF7aK+Wlwr6/G+tx3ZnYN1j1u3pyHxj77H5NT74TirsY9u4PgYXgAXtlVfWYur7Hezb3MvsIa/4T1zq2/z/wQqOPZ6Cywl0vgXrXQx+C3fBNFV6GHXAr98Bf6QKvvI7DPb7z19sUFUWNfyZWjEQKB/CKu4mUIodtYqPLL8t2UWN+FH0Xx4yiLR48/CvKVujIi1Ue1+v8AAAD//446HLsAAAAGSURBVAMAern1L7p1xqgAAAAASUVORK5CYII=",
        [24] = "iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAADJUlEQVR4AbSV2YtOYRjAz5mxzEwfMmMdfMYaRUTJje1CSvb9Ahf8B0IKcUEm+QNcUJYpKdyRK0vKLTdIrmYYaWZqFrKM5fj93s45fb5pvikyvb/ved5nPeddzlRF//lvyAZJksSDPUMlX5YzoAFJ1VAHDTCZwCKyBuIyalJfI3ZjzanG9sfIGxBk4QLeJtgDF+AetMBcmAazU4rIeXAD7oKxu5FN1ClA3ig0wOAy1BGwHe7AedgFC2AJaHuMfJCifgt9ERhjrDm3mW8D38aaUWiAYTjMhCPgkzUgbTgMWQv6piOnpvgG2vQZY+w4fPPhKMwCa0ZV6dO7NAcxmjgCWTp8kozMns2VmU1prjUOMHGpYt9Ao2u7AaNPgvinYY2NVJgDI20wCmUTuCz55jD/22GNepI3Q8EGTtYzcT0R+fiJ9iXlB7J8aBvMb611JNTbYDFKI7hZiDC+8/sersNVaId+yIa6/msYRF0b0zCsNQVtqQ2Wo3hpsg1LmPfBaTgFymNIbfrkI/PjkPlPomvThxpZy5rLbOA5dqN1iEEdKJ55ZSf6U3gL+uQd+hPQZ4z3wrfQhzkMay60wQymvhIiDLt7ht0sdTHOhBDAj3qp33xtuPKhrWjieEwGI8KwoJfGz4Xr6P54w5X6ZBKRO0G/qE9krg8RhjUn2MAdL3Xo9eIdQrkMl8A98DgbJ+reen1ymBhz9KGGoV5rA5VgSX9cR+2jma+ENeBR9pVRw1Afi7YaVsEYMMdc1HyEm9zFtPSIGaStDbsn4yvSM/8LmQ11bd8wGNOKNMdc1DCs2WnXZqZvwEAvF2r0mR8/xSeQLtND5Guwqag/Yu7yeERvonvpEJE1rGXNZhv4vd+Hxwvl8fuE7mdjB9KgM8j9sBZWgMumbo4+YzwELqOFPc5XiNsLLTboRnkJXhr/aVxEd+4/kufo3XEcd0A7tEErqHv+zTXmPnEvwFxPn5fzFfOeKoITcL0MfobxHGwBZR8+15vpwJH6evGcha1gjjV8qH78iW+APYqcgMYe5AfoAr9JUaW/NMZYc3qZWyPf7LxBpSJD+SiaFyyP/Q0AAP//2z9yfAAAAAZJREFUAwDuRfExqurCiAAAAABJRU5ErkJggg==",
        [25] = "iVBORw0KGgoAAAANSUhEUgAAABkAAAAZCAYAAADE6YVjAAADV0lEQVR4AcSVSWxNURiA76vW47VabRHjDiWGimlRIhamGGKLCLFDQxASw04isUKMaysL85wQVjQhJGJvDkmrrWrqUVXP9x3v3rxKWUhDc777z/9/h3Nei6J/8Pd/huRyuRSUQBkMgaGQgR43pA36jZtnvnWpX19OUkiBzdMkVMM02AQn4SosgBHkDIcgtWExXIETsBGsqyYnDcmwZAgJDqhFHoMLsBdWwBQ4AKfhIjjUuPZ+7Klg3j6k/qNI+9gPNYrCEKb2w6qE3bAMRsJgGAADYSLMg5lgg1lIbf3GxXzrlhPbA5X5vj+H4LDZUuRcKIUwHOlKcfEmSpDFBWjrN447LOusn4NlP4dHRflpVTjXQzmYiPjrZb19NtChiv7FOjIY82EC9Ie+WPYZTyP7ZhxSgeGHK0MWPjpmWLlw/f2lt7h97LeSsnKHjEKZDcluQLfwC7IJXkErdEHh0v6Aw7h55luHKyz7zUAb45A6FKeqo4b1letTWAsLwV3XiOwGl/I9itvc+Br0J2AdIiz72bdOZToupyKSlUXzID5AvgAPnHSiu5TXUS7BS3gInq9PyMJl31qH1OB1OyKS5at4htWZSqW8a1+Fzb7hc+lz+Gfi+hyqbZ3xGPvWOMQD5H6PA0p3xyQUf5vU3fsePM8J7kipXcoWNe4O1VY3HmPf0Q7xpCvjgNKiLShLwGHrkP4S+Piokc383fIsTMaxCLaBN4NIln0rvFjglksiKD7mWORxuAl+eA+sd4YZKbV3YdyAU+C5sA41WfZNO8T3m3hR3Iaxz5M7DJ9nyVeEmixt/cbNM2Cd9eoxXQ55jeVu+o6Ml/v/MsZzaIaPYI4f2G2q1NZv3Dx3Xxt58bKfOW8cshnvXfDA2cA7GYTt/5WDSOOHkefgDtwD5XnkEagH88z3XGBG3kQLinn1DmnA8B+OB+sRukG35Th0X8ltpEN2IP3QHjzlduxDcAv8rn5D63yyx/j8/2LfhiL2uY/kaT5DYDX4MX1079gD10FOO7RAEzSCUrud/A64BvfBV7wTuQrsZ17WJ4ko6gaT3xI8C25fX0Mzfj8mrt5XPu5PjK91K1m+1nf4vblQG4YQCIuAw7LIVmgDv1GI/eliHphvnfWheVzTY0js7Gv5AwAA//+zvshMAAAABklEQVQDAOpeAELxUOk0AAAAAElFTkSuQmCC",
        [26] = "iVBORw0KGgoAAAANSUhEUgAAABoAAAAaCAYAAACpSkzOAAADf0lEQVR4AcSWSWxNYRSA76tW0SGqs1iIkEiwEcRGIoghIjbCwhwbNQsJElMkJMQUMSyIaUXCigUhJCwkYlizqAUbrVRbWtri+b6/9930Na8W8kJzvnfOf/5zzj/c/7+3BdE/+vu/A6XT6QIohnIYAWVQ2H/x+sA+Y4w1J+fks5wkFUI5BethNuyAC7ARaumrhKqYSn2wGYzZiZ4F9fQ7eNbEkoHotKOGwAa4DZdhGywEfXvRJ+F8jLa+9bSN2Yo25xZ6A9TENTGjKAyEI0WrFNbBdpgMDurqSrBHwmpYAotitPW5emOMraXPXGtYqzSu3TsQnUUwHtaAW2LbwWkGcbVDsYbBkBhtffbhCmLOYCxrrEVb03bkQ7ezDKezcxV9E3H/lVijmsxkVW6dI47FuQCcISovYq25VBoHxQ7katz3ChyDIF9ireEUWwylDmRjHg1ngErkF9Z3aIcO+An9RZ99X+gw1hzMRKw5h1aFA03EGAXuKyqICV+xHsMh8Ng2oX9ARrSbaVwFYx6hzTEXM4g1rT3Jgabj8iR5KDCD9PD7HLwbl9BH4DQ4e1QQ7TNYh+EiGPsM3Q0Zsaa1pzrQBLweCFQiXVj3oSmVSrWhP8EdsDgqyDd+70JzqjfGFd+jbS4qEWuHFY3B5RJRWeIk+jpsO8O+PtuS8eWKsfZoO7w7npBMsLqYn/lQx832sHgnPD1eUtxBfND6quOYOrxeEXMxE7F2nQN5vNVJD4bLnYI+C7639qO3gK8aVBDtTVgHwXehz2satm8VVCLWLvHHERNvbLgdFppBezesgipwG1BBtH3VLKe1B2aC70trYmZJkU7PfzrLHUUe3U58ardIck1In31ibCaH1ESs3eFAL3F5sgzEDOIRvYLl5+IN+iO0gJfXuyLa+ux7S5+x3jdzaQaxprVfOZDfEz9c7+mygLfdffYz4HFehn8F+O3xmTkBOYdvH6wEY1zNUmxzrWGtD7T9fjU4UCON42DCTbSdJrktattP8V+HY3Ag5ij6GjwBJ2ms9ZycOTfw+/xOoBsLuGwutZXGC9gFzuoU+gH4Vug0BjqgDT7HaOsz38vr2+EhOeZaw0PkY2klvtsZRBhp8Ea756/jYP9PeIftPqP+KL6yjPUq+KqyRos1wcOQfGFDFZ3QA+3gjLvQITAEDPBjDBhrjrnWyMoLKxogP6/u3wAAAP//JcsuqwAAAAZJREFUAwD5uwxEWQPpNwAAAABJRU5ErkJggg==",
        [27] = "iVBORw0KGgoAAAANSUhEUgAAABsAAAAbCAYAAACN1PRVAAADqklEQVR4AcyWyW9NYRTA76uipZO2kpKGVERiQWIKK6xYiDERxLCSmCWGGEIMJUEsJCR2EkJMiy4MK3+BIDHGCgktGjFUVZW2z+/35fa272krkRLN+b1zvnPOd77x3tuc6B/+/R+DpdPpfpAPxVAE/bvbBP1QCOaZ36+7PH0ZK6NDDuRBKcFRMB92w2GowO+gFi3BVhfph0OwC+ZBFbFSsE5G/aRBULuA5JlwDK7DSVgHS2AbbISdsAfUm9DbYRmsh1NwA+w/A10Q18WMIgcIBj95MB1Og51Ho4eCsy9DrwYH2IBeA+odaP3GzTPffva3jvWsS1o8GKO7z3bYincYDAZ9qCDa+iwohXjVMgjbOCqItrnDabkb5XH9ZGX5BDyf8eiB0BdinXEUWgBOKPJC5NJwVSvQzjiF7guxjvWWU8wLk+uZuSr31tvX7fUm+U/Fetb1suQ7mPs+h2reRGeDmUgaqx3aQBv1i+g3R7S7JljP85uLs9jBKjCmgHuMSqQV6xM8hkegrQ8zEdv6jZunrS9JwLDuRHSFg03DcHXamEGc4WesE+ABL0QfAYu5AsxI3YBxHIybp63PGO4g1rX+VA1v4IDg7vz5gfkQzsFLeAWX4DYYQ0Wu4C7GBTBHtO/RNoZKxNVNcLCxuLIHc2bP8H9NpVJtgt0ML8DzQ0Xq5xi95RAO4kUZ42CVNL3+qET0j6AVXqzxQ+mbYCQ+H1pUpK7C6C2HcBBzKy1aTlONSsTBPdSleJyMLML2fJ0lZmTOZIzFYFy0vWzGcCfiYGUO4n56RZMIhv5itG/yq+jLsB9KwBgqvH1s76VxJUbbfh05uINYP0+nRvBk/Ti7IfgmgbP1s9OxKlxBOnJcoZivLwSzflIO5lX1sLvGbHvNxYvhhekaz7aNm2d+j/UcrIae76AFfL5Q4abdwjgAXvn76Ndg3nv0B1Db1m/crTbffk6WlMh61jWvxsEO4vXTcgf9Eb6D/tnolXARvBx+FdZie477Ym1bv3EHW4V/FtjfOtaz7hZ81TrrMfwq+9b38+5D6cxNfkPsKTj7B+ib4OBnY21bv/En+N6CD739feCraVvXr3d9jg8sNOGshTPgvwCb0efhKDQQb4dWaAEf4qZY29bvmXlW5tvPfxd8bKxXS675ba6MelGEwzdFYxRFdXANvOqu0j2n+Vv5RoZb5ha7U3XU/AId5xeeFXI6haCraEY3gjP3kDsTerDITYP59rO/q83ITlaW4f1LjZ8AAAD//3uoKyAAAAAGSURBVAMAeWYrRgXAKiYAAAAASUVORK5CYII=",
        [28] = "iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAD8klEQVR4AcyWSWxNURiA76tq6WxoYggqLEQpEZFYmhZEjIkpgh3CgkiQkIghgoqtGBNDDYkNYoqNBFs2EhIWKuZ0EKLV8fm+++677XsVGyWa/3v/f/7zn/+/59xzzm1O8I///p+CyWQyAblQAEWQB4nsBdEH9hljrGN6xKXH9Zghgx1QREA5TIAVsB0mQTppIXFSoA8mgzHGVmKX029sLnaGZBQkqB+9o2AdnIEbcATWw1aYC8tgTcRytD77NmAbexN9FtbCyCgnZkrignT0xVUB52EvzIbhMAgGw0I4DkfhQEQ1Wt8CtHHimFm0zWGuiig3riAIC+JI0CoGZ+IyDsB2tmE/ttrlG4htUrWkbfuMoTvM6Vj7J+LYCCVRjbCTdpDHTxUshULwAVB/JOYw12KyWNgaQU5U2dn5XnyqPgT0lpjLnL7PYmu5DFYeSwXfmUuB2atiTt+pNfIt6BGYR4lS8IlQvSrmNPd8shZZsAxjDvSHbGnD8RUa4Tt0QLbos88YYx2THWPumThLLTgOw7OXfUhb8b+Bw7AJzoFJLYAZivYXrIuwGQ7Ba3AsKhZze+QqLTgNt+vsrsIMJcnvN9gPJ8AL4CD6EjRDWn5gXAPP5XX0SdgDztQcmKGY2xpTLOhV5MYJe6Ifgz9iP4DGRCLhktVj34XuBbVv4auPYlyBx7TfgTlQsVijyoJjcDllVIa008oepA93huhLx6nFpVZ3D7RGhQWH4LWBisUlGEZrKnh+XA532gza2qhQ8vl1M5RxxvSX0PaSH4E2NyoWawzVaSJ13INhQQf7Prx9puPz2vNSd8fRDEV7NZbXlzHeKvtoO9YcmLHYLraQl3bs7Wa45u5gL+ur+LeBnyyfFDMUbS/2LbSMOYYeD45FZYgFw4PfmeFONVx//R5az6mFfGoLpCK6fvXZZ4yxth1rjq6olNXmDD9jZ58bB7jTXtBXBx4RY/TTzBB99hlj7HN6HasfMxZj6izoR/MVbge4uzBD8ShcwNoJp+EReKjfoz0yoq3PvlP4d4BntQmdFnOa+yWOagvWYPiluIw2iYVcjtG0/Yr7bfS2WUXbHemHeCW2LEJ7Mdvng/s+3VzeKuYw1wdifAi/GDUW9LA+w7kL3IVX0G/Bp3KJ7mA3cLA/ob3qnqI93PIEuzbqa8C+DY5xrDnMZc7d+K3RmENwElxfb5KHdLgsS9D+iyAW8XAHxBnbgW6L0HYmhAfG1GJ4LBznETGXy+1N1MqYpDMkJkgnawmCwCf1afxH6D7tJgPRv5Uoxnd3j0DHmsOVaYn6cAfxvxhhwx87wRk0ow3O3m2G/RLiO8Exjm3HTs8+jo9nGHv+svETAAD//46nJm0AAAAGSURBVAMAlesxSCcRi6kAAAAASUVORK5CYII=",
        [29] = "iVBORw0KGgoAAAANSUhEUgAAAB0AAAAdCAYAAABWk2cPAAAEIklEQVR4AcyWSWxNURiA76sWNY9tUQlCkJBIDUGCxBBTIoIYYsPKbGmKxLQgiFghMcQQC8HCkFgSCxaISAhhobSkQgytqlbb5/tu323ebV+qkSY0//f+c/7zD+ece+65zQr+wd//VzSZTCYgB3KhA2ScpHZwXD/9Ey1tYLMkBFuoPbo7gf1gPKyAGdAZezY4HpGtHWaBfuPQBfh0B32aTSBWFKccAnrBRNgKV+Ay7Ic9MAqcxDS0RdT2R9PfCwfAGNlC2zy9UnnpNkhjUQZs98Rs8EX0BnDWrrYvbQteR1+FC3AG1Pav0R4JfUB/J7KRtnl2oXuk8tMMAguFDX46wXxYAgZ2Q7vyBFo6oqOk+bTzQK2vdsf1E+OMd2wpfvMgF0IJizILn4tJ1mHtAe2gLcQ87t56kuWl6jSu1FksZmAoOEtUm4n5hpFtEVgnyEpV743BbeiMdntQbSbmM+8yMnqost1eq0/FMAicFarNxbyDyeppz7WoD3wuBmfjrGjGpI5eDdRCEjKJdsf107+pj3nNP4eBbhb1BE6g0wHSxUQ/MLyBW/AIvkHTpPa1P2ZMv2K0ccbTbJT2tKyTb9GxdLqCbVSjOOsn9FaCp9rb5hTt7xAlVNs/i205rAX9HqKrIV08ye5qkYWKGGm6SkxBJT8n4CmUQQnYd+X1tBV1KY1j8BY+wHM4Dq4WFRPrjLHocMw+aFRMftF7AdWJRCIJPjNX9RqbW4oKLOp2VjgOrtwVvmTQnULFxDojLDoQs5cDKiba+mPRMeDVcnucaQE241CBB8Qz4RfGcW3GDaChRsVEW6HBXmFRQLqH1+IqDIUU9CPgjbWAvi965K8egs0XPz/lV0jfOONpxsR6ff3pgtkZo2LiqqZjOQ1+MQ6id4KHLvJXezi2YT8E+p1EzwTvYlRMrNfJH2drcGyUjmNOyGPuF8Nr0l0Jt5vxSNwybzRXq98kBpyY8TSbSY4DPnAPQPqofQ/ST4xOyK3y5nKCmJqJdlemn/7GGW+edGf7VRb19Hm8PYmRg4Pv6VwCX4GPaC+AKrSnWF991Pa1O66f/sb5mulDSCj66ldi0U2Y7sAXiFbtbN1KD5DP0k/TUcZvgDfTK7Tvq9q+dsf1O8yY2y3msbB5P2O/DZsteo/GGtgNz+AruDUepMm0Z8NdOAL+N7EQ7f9LU1LavnbH9dPf5+q1Zx4X4wVjfm+s+1m80N48bsU5kvh524d+AG6Vs9Puy1+O7ycog3dQCmr72suJqQCvROOMN4/5/KydZ0zfSlcaEFwHBvh8vV8tvhqnHZDpHsWcUbyNLLSdUePN4ytXbH4Ib7KwKA6hYKwFi7ty999n5Sp9LqFPSz/E6mf8TfyMd2XGe9gwNUisaIMpcOX1JKhJ4akLWvtHzB9jMxZtbYG/9fsNAAD//0ZpxUgAAAAGSURBVAMAbyk/Sixsc+YAAAAASUVORK5CYII=",
        [30] = "iVBORw0KGgoAAAANSUhEUgAAAB4AAAAeCAYAAAA7MK6iAAAEL0lEQVR4AcyWR2iUQRSAd2M3dj2IHbFjASsoiIgoVtSDBbsHsYAeLViPFixHBb0oCmIvoKLYQTyIJ72oNytqjImmGdfvm+y/7L9sSJAEDe/Le/Pem3nzzz8z/xYk/tHf/1s4lUoloRk0h1onagzMMTdZ10LmHYgBCqAVdGKAHjABZkJbfMacTDaO0474LBgPPcjrBI5hDFdcYk4Sm0AbUiw2D70PrsNpOABToCf0gYFptPVNo70fzsA1sO9ctJNow7ixWpkGAZenkMT5cB4OwyIYDF2hO1j8Bvo+3E6jrW8vbSds7hBs+x5BnwMfojBdg2YikSlMqzkMgm0wDLqAE2mKToLxXugBYAEnItr6fOpmxMy1j30dYzi+reAKGcdM1BRmJk7Ad7QOr4O1QCchW2ybJ9pRTFufaEd+tW3HclLrcbSjlr6awjh8mtHoqdAaGloc0z0wioGdSCLsUBptYQl0AGeOalBxTMdexqhutKQOZ9APx0RoCY0ljm0Na7WwsMdnBtXag21Uo4hjW8P7oNCGm2oypVpBrvzG8RM+p/mBroZc0WcsO8++uXk+9SSc7S3cH8NLwCOAmRE7ltC6DKvA93MWrc8YZhBtfZ795XhWwEX4DsZQGfE49aXVz8JjMJxJ2ObYkVRhPIXtcAe8KPag70EFRFKJ8Qh2gbG76J3wGIyhMmINa4208FDcHidUTMppeSN9TiaTZUL7K9yE7MLat/B9MUe0QZ8xzJhYa4SFfXSXIBalkQKLqzGDuHT5fGVE68ojJYi1+li4G80mkCvObCxOz50fD3M8AePwGUMF8Tjmy/MVZueFZP45TncLe7DV+GLigNPxuKl6o72nF6D94vieMIOYNwdrIZhj7mLs2WAMFRNrhV3tMbIRi9JwZn6Pt2D7mZPd2J3BGCqItnluLj+h5u0gkpuHK0jYYPkKhmj6n0fMFfHL4perI37fESom+qI8c7XtG0vKaoQr04PvpsnyB9Pj5Pk07gXhTCUE8/wzJubax76OkZtqrRKf+BmRYrADKiPeWAdpnYKX8BGKoBTcxR4V0dZnzJwXxE/CITCGysgvLC+W5xb2G3wMx1uwmDPCTPjuV2M4+Br0UvACOYG+CtEvEG19xsxZS8wn9baLNqFjOvY7Ykdhg4VfY/j7yKvuCvYHcKncNG4Qv9Pv8Xk7HUe7wTagnZRo6zNmjv09SvZ1DMfS59VrDWu9KeCm8VpzmZ4w2EZYCf5ge4O2gwN+Ja8CSqEIvM0+oUVbnzFX5wv97GNfx/CHogU34bfGN/pV+sQJjBR4I/l1eUDCZvAcmnwJO/dd4apVXNILRH0If+56HB/SdoLl1Ak3XCiMM4hO8Mm8k1/h9F4uxpe78Qjll3Sum9W7+jXtaLVCwahXrHDkVNOhGqrAjaGr3tgH7FvrhGstXO8qf5n4BwAA//9SaFz/AAAABklEQVQDAFnVRkxSbDmlAAAAAElFTkSuQmCC",
        [31] = "iVBORw0KGgoAAAANSUhEUgAAAB8AAAAfCAYAAAAfrhY5AAAEiUlEQVR4AcyWWYiNYRjHvzODsa/DZFcuyBJS1nKHG0qWyF4uZMkal2Qpay5sN5YIUcqSkFwpubLlBilElslg9olZjt/vc85pvjPfjLkYMT3/ed5nf973vO9zTk7wD//+/+LJZDIHtAKNNostAfTLlTfnQGOTEWwii3Vk3ZNEA8BE0Ae5NTyOWqHsByaAAfjlA+PNk0DXgCLFcbZoHl7dwQiwAhwHd8BZsBrYQAG+vYFreQH6vmANOA/0N8744cjd8c0DkSYixXGy8Cj4AXAVbAczwGDQHywDR8BFcB3cAvJL8MNgCXD3+s9kbfw1+H4wEpgf9psyxekqF1U+MGAO3GLd4G2BNo/VHU5HngzGAE9Hrqy+Fzr99DfOePPMRb8N9EjVYRkEmeJI7YFO4+GdgAlgEVLXBo1IF5F7D9RpxxwhdR3RTALmtw7LVHG6MUFvNMtBZ5AALUlu0rzm945YL7Nzu5lNtYEgNMBbmsw7iKR+pNYLfJcqvd3zMHQALb1rUoZkXvNbvBunnetxtMM0BfiWbYTlXyPze7rWa29xL9c0ynkUdscyQnVIP0AVqAZJEEfqteunv3HZfua3zlQMnSzeg8U4EHmDyFIN/76Bu+AMeATKQHZiZfWPsel3G/4V2AwsQtbxReVbfCymLsAnAcuQOylB2gNWAd+pQ8ShUYlcn9ztTRTa9VvLejcoBTYGy5B1uiKNtvhoFnYDi5BdP0NzGXxKJBJF8HfgKDCpzbEM5MpOuHcpv88YroCHwNODRch6oyw+BLVDAhahWqSXoJKErlkGNvSJRSGwKCwsbmMfEH6CIOXvabxCjituvaEWb+yWa/M+tOZZeFHIE84Fx6YDI62TO8F8NR5pkPL3ZvuEzWNsfWjrr8F5HAbVt7LWwa9H53cXEnpLbWYWNrlFWQZyZ7hDytmtn80Nw+jMd5csI2S9Aov71OQRK4IOfpcfYu23mc9xA+uNwGEBy5A7X4e0CfgFsxRunF9E5kGMkPU6+M8vBLuPWFOCF8M7sQP5JPAWe1LZu/GUbNRXcQK/XcCdG88ylvIs7mVKX544L5vzKXrUnpKF4vzUa9dPf+Pi/NK6aosXI9kALELe7C9oHBYOEOWmmsQ1vPn66W+c8XG3XV2xxX2PPhVHYv3kNuRA2ULWc8Dp9RGurw1bIA1l9dr1038rvjeAhWAhmd86+l63uJ/nZkxPgUnsXCePcT66leA+cO2N9tLtQ3bYeA+OsVZeD/cbS78HrI3zx4N5zGde8z/B5sXcZXEHhr/DFqI8CF6A78Cd+3b9afUW2eHirjypdMGd6PcCZX/zOfv10984481jvuf4+dtwEdwTKcxxGoEKFOnRabcmdbfqLmCzoWr8akAVKAMloBjIldV7xO7QQv7IfE/sPeDpmtcmHcEVxNW6c2xBgGBiZ/TrIAhOgcVgATDA5B4dYtNEHv3M469c450Rp4l6g60U2CBiEI7LcJH+pxGUI/tx+PkUIWcC0P+RUv7edOMLkctBgxyZnWdnxDkJ6kS2rTmycaAWeBKxIY0Wj/VuYeUvAAAA//+F+glKAAAABklEQVQDAFV9WE71ntQ2AAAAAElFTkSuQmCC",
        [32] = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAEyUlEQVR4AdSWV4hUVxjH72x0E82uSTYaJRuSaEIgggV9UOwVG1geFMSKDyqKYAHFgoqobyIqir6oWEBQUAQ7ouKD5UHEgg82EKyrLtjWPv5+d+8M987suAuyiMP3n+87Xz/nnnvOLQq+8u/baSCdTqcyKLRoGbu8kE+uvuAKmAQUgybgNwL/BC1BMShE32NoBf4yBhhrjhS6GimvAYIagBK8W4DuYA7YCo6BdaAcexloCppFUC7TBjaAo2ALmAW6ghb4lYDvkBOUaACHBlibg0lgJ9gOZoI+wJmZbAnycrAGbIywFr4CaOsE17cv3AbMI8zZPKqBqZqyDWBwmZqgngYWgC7AVVDn0tq9KzMK/XgwAgyOMBw+DowE+uhrzE+MzWEuc05lXBrVQgyCbAOMDGgPHwuaAscpeJxM/AOKH0EjoCyU1SnrgylL5jDXr2hs3BqOGQbVDdCRjThTO7R4bpLQ+Qv/fLzNyDEFuDmtWd0ACjvqDHfTOQvEeiFz9yCz+8SaQRGzT6HwuY2GuwphZ8j1QeZ2X1jLtyKlwvf6X6p1A3YIq1eyhrX+oUqxDTj7AQxKgWNYvZI1XOmBVCnJDHozcCfDEpRm9BY8BfdBBXgFPoJcUqdNn3sYjTHWHAwTZC33QqkN/I3J5WgIz6V3KG4CT0Ob9Aw4xPgliCdWVucJqI8HlwfYdfxsApYga/2HpqUNdETwubgZEbNk0ueMVoK9wEbOwheBa8DmYCG9599iC+H63IDvB8uAOcyFmCVrWbO9DbRB7UaEJcigB2hOg+epVOo9eI38EJwA8Zkpn0T3QB/wAdnCZ+B3gI8HliBrtrWBQstvAy8IcXbKiCGZTH2uzoLaQif+tNuI+4JhHvkYWtnA75g8pWAJ0vYHmnJgtwFnhrrGjF01EyCGpKyuMT6ZU1SdF5t7zLjQMfanX7kGz2h5zBaKPqefkWYD73ePaC+WIYx7gbApuKTsKeql5NWrr98P3obmMJd+cdhAmYWdUU0OOvu6eON5nXoFr0fptfsL3FhYSMoWWsrI7wF9dyAPA+aH5ZE1GxloJw7yPFBo96Bqh+xNNgju7FxexASpczU91PTtgLW2w62hBdzBbhj8E6TODehGco+4Gl4gxiQcYwNt+uhrjLHmMFfMLRTVVRnga2UToTb2Z7Dv/kV0j8AzoJ+BiDWSNn30NeYCXreBuWAJ8hypsIFVqC3kqxV/jVAHnm5+D7oRN6HwTPC99nx4zPhJBGUnok0ffd2A27CbF5Yla6jz4FptA26WCZj3AJNUwXXS1hp5PvBb0G/AMcj9gHwGfG4EZb+k+jPWpm9PZGP/h7vPzGlua+xGNxHstEglwiVgssnwg0AnDxDtPsvz6Co54dTfQnaW++C7IiifQr4Z+ZjzHGNjzeFKumoH0FljHvwyqCwiIA18bi7ncZR+lLqLXforjL18DsPfgADfj+AdeA1eRVBW5yx109eJHGFwFWwGrvJ0uDWeEPcWpO0OXZBJ7BJ5nTrDxUEQ+B57wTj7mjYSLvlEYn1dBb+Eh+Lh+WDOCmxVINNo9psQn2rC6Iq8gZvgLtr7yK4QYt0pivG74C6yEzCnb0kiSXYFEtpoQKDN5AVF5lpZXeI/20CtFergUJvLJwAAAP//snv1DQAAAAZJREFUAwDL1mVQ7cuF/QAAAABJRU5ErkJggg==",
    },
}

return Icons
end
modules["ui/layout"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")
local Hits: typeof(require("./hits")) = import("ui/hits")
local Motion: typeof(require("./motion")) = import("ui/motion")
local Painter: typeof(require("./painter")) = import("ui/painter")
local Widgets: typeof(require("./widgets")) = import("ui/widgets")

local Layout = {}

type App = { [string]: any }
type Spec = { [string]: any }

local COUNTED_KINDS = { toggle = true, slider = true, dropdown = true, button = true }

local function matches(app: App, spec: Spec): boolean
    local query: string? = app.SearchText
    if query == nil or query == "" then
        return true
    end
    if spec.kind == "custom" and spec.ownSearch then
        return true
    end
    local text = spec.text
    return type(text) == "string" and string.find(string.lower(text), query, 1, true) ~= nil
end

local function visible(app: App, spec: Spec): boolean
    local rule = spec.show
    return (rule == nil or rule(app) == true) and matches(app, spec)
end

local function rowVisible(app: App, row: Spec): boolean
    if row.kind == "pair" then
        return visible(app, row.left) or visible(app, row.right)
    end
    return visible(app, row)
end

function Layout.activeIndex(app: App, tab: Spec): number
    local saved = app.State.SectionByTab[tab.name]
    return math.clamp(saved or 1, 1, math.max(1, #tab.sections))
end

function Layout.setSection(app: App, tab: Spec, index: number)
    local state = app.State
    local target = math.clamp(index, 1, #tab.sections)
    if not state.AnimationsEnabled then
        state.SectionByTab[tab.name] = target
        state.NextSection = nil
        return
    end
    if target == Layout.activeIndex(app, tab) then
        state.NextSection = nil
        return
    end
    state.NextSection = target
end

local RESULT_KINDS = { toggle = true, slider = true, dropdown = true, button = true, bindrow = true }

function Layout.results(app: App, query: string, clear: (App) -> ()): Spec
    local found = app.ResultPage
    if found and found.Query == query then
        return found
    end
    local cache: { [string]: Spec } = app.ResultSpecs or {}
    app.ResultSpecs = cache
    local rows: { Spec } = {}
    local function consider(tab: Spec, sectionIndex: number, section: Spec, entry: Spec, number: number)
        local text = entry.text
        if type(text) ~= "string" or not RESULT_KINDS[entry.kind] or string.find(string.lower(text), query, 1, true) == nil then
            return
        end
        if entry.show and entry.show(app) ~= true then
            return
        end
        local id = "result:" .. tab.name .. ":" .. sectionIndex .. ":" .. number
        local row = cache[id]
        if not row then
            row = { kind = "button", id = id }
            cache[id] = row
        end
        row.text = text
        row.label = function()
            return text .. "   ·   " .. tab.label .. (if #tab.sections > 1 then " › " .. section.title else "")
        end
        row.onClick = function()
            clear(app)
            app:switchTab(tab.name)
            Layout.setSection(app, tab, sectionIndex)
        end
        table.insert(rows, row)
    end
    for _, tab in app.Tabs do
        for sectionIndex, section in tab.sections do
            local number = 0
            for _, row in section.rows do
                if row.kind == "pair" then
                    consider(tab, sectionIndex, section, row.left, number + 1)
                    consider(tab, sectionIndex, section, row.right, number + 2)
                    number += 2
                else
                    number += 1
                    consider(tab, sectionIndex, section, row, number)
                end
            end
        end
    end
    local page = { Query = query, rows = rows, title = "Results" }
    app.ResultPage = page
    return page
end

function Layout.countOptions(app: App, section: Spec): number
    local count = 0
    local function add(spec: Spec)
        if COUNTED_KINDS[spec.kind] then
            count += 1
        end
    end
    for _, row in section.rows do
        if rowVisible(app, row) then
            if row.kind == "pair" then
                add(row.left)
                add(row.right)
            else
                add(row)
            end
        end
    end
    return count
end

local STACK_BELOW = 340
local stacked = false

local function sideHeight(side: Spec): number
    if side.kind == "text" then
        return Widgets.heightOf(side)
    end
    return Widgets.heightOf(side) + Widgets.GAP
end

local function rowHeight(app: App, row: Spec): number
    if row.kind == "pair" then
        if stacked and not row.noStack then
            local total = 0
            for _, side in { row.left, row.right } do
                if visible(app, side) then
                    total += sideHeight(side)
                end
            end
            return total
        end
        return math.max(Widgets.heightOf(row.left), Widgets.heightOf(row.right)) + Widgets.GAP
    end
    if row.kind == "text" or row.bare then
        return Widgets.heightOf(row)
    end
    return Widgets.heightOf(row) + Widgets.GAP
end

function Layout.sectionHeight(app: App, section: Spec): number
    local total = 0
    for _, row in section.rows do
        if rowVisible(app, row) then
            total += rowHeight(app, row)
        end
    end
    return total
end

local WHEEL_STEP = 64
local EDGE_SLACK = 6
local SCROLL_RATE = 8
local BAR_KEY = "page:bar"
local Z_BAR = 9

local function scrollCell(app: App, section: Spec): { [string]: number }
    local store: { [any]: { [string]: number } } = app.PageScroll
    if not store then
        store = {}
        app.PageScroll = store
    end
    local cell = store[section]
    if not cell then
        cell = { Target = 0, Pos = 0, Bar = 0 }
        store[section] = cell
    end
    return cell
end

local function drawScrollbar(app: App, cell: { [string]: number }, x: number, y: number, width: number, viewport: number, content: number, maxScroll: number, shown: number)
    local pal = app.Pal
    local dragging = Hits.isDragging(BAR_KEY)
    local hovered = app.HoverKey == BAR_KEY or dragging
    cell.Bar = Motion.ease(app.State, cell.Bar, if hovered then 1 else 0, app.Dt, 14)
    local thumbHeight = math.max(26, viewport * viewport / content)
    local travel = viewport - thumbHeight
    local thumbY = y + travel * (cell.Pos / maxScroll)
    local thickness = 3 + 2 * cell.Bar
    local right = x + width + 6
    local alpha = (0.30 + 0.60 * cell.Bar) * app.Alpha.Text * shown
    local trackAlpha = 0.14 * cell.Bar * app.Alpha.Text * shown
    local round = thickness * app.Unit * 0.5
    local outer = Painter.active()
    Painter.scope(BAR_KEY)
    Painter.rect(app:pos(right - thickness, y), app:size(thickness, viewport), pal.Sub, trackAlpha, Z_BAR, round, true)
    Painter.rect(app:pos(right - thickness, thumbY), app:size(thickness, thumbHeight), Color.lerp(pal.Sub, pal.Accent, cell.Bar), alpha, Z_BAR + 1, round, true)
    Painter.scope(outer)
    local top = app:pos(0, y).Y
    local thumbScreen = app:size(0, thumbHeight).Y
    local trackScreen = app:size(0, viewport).Y
    local grab = thumbScreen / 2
    Hits.add({
        key = BAR_KEY,
        position = app:pos(right - 11, y),
        size = app:size(14, viewport),
        press = function(mouse: Vector2)
            local current = top + (trackScreen - thumbScreen) * (cell.Pos / maxScroll)
            if mouse.Y >= current and mouse.Y <= current + thumbScreen then
                grab = mouse.Y - current
            else
                grab = thumbScreen / 2
            end
        end,
        drag = function(mouse: Vector2)
            local fraction = (mouse.Y - top - grab) / math.max(1, trackScreen - thumbScreen)
            cell.Target = math.clamp(fraction, 0, 1) * maxScroll
        end,
    })
end

function Layout.draw(app: App, section: Spec, x: number, y: number, width: number, bottom: number)
    local state = app.State
    local animated = state.AnimationsEnabled
    local direction: number = state.TabSlideDirection or 1
    local perRow = if state.HighPerformanceMode then 0.010 else 0.055
    local lift = if state.HighPerformanceMode then 3 else 14
    local slide = if state.HighPerformanceMode then 12 else 16
    stacked = width < STACK_BELOW
    local cursor = y
    local index = 0
    local lower = 0
    for _, row in section.rows do
        if row.bottom and rowVisible(app, row) then
            lower += rowHeight(app, row)
        end
    end
    local lowerCursor = bottom - lower
    local run: { Top: number, Bottom: number, Alpha: number, X: number, Lines: { number }, Splits: { { number } } }? = nil
    local groups = 0
    local function flush(clipped: boolean, clipAt: Vector2, clipSize: Vector2)
        local current = run
        run = nil
        if not current or app.Pal.Pick < 0.01 then
            return
        end
        groups += 1
        local pal = app.Pal
        local outer = Painter.active()
        Painter.scope("group:" .. groups)
        if clipped then
            Painter.clip(clipAt, clipSize)
        else
            Painter.unclip()
        end
        Painter.rect(Vector2.new(app:pos(current.X, 0).X, current.Top), Vector2.new(app:size(width, 0).X, current.Bottom - current.Top), pal.Panel, app.Alpha.Btn * current.Alpha * pal.Pick, 3, 14 * app.Unit)
        for number, at in current.Lines do
            Painter.scope("group:" .. groups .. ":line:" .. number)
            Painter.rect(Vector2.new(app:pos(current.X + 14, 0).X, at), Vector2.new(app:size(width - 28, 0).X, math.max(1, app.Scale * 0.8)), pal.Off, app.Alpha.Btn * current.Alpha * pal.Pick * 0.9, 3, 0)
        end
        for number, split in current.Splits do
            Painter.scope("group:" .. groups .. ":split:" .. number)
            Painter.rect(Vector2.new(split[1], split[2]), Vector2.new(math.max(1, app.Scale * 0.8), split[3] - split[2]), pal.Off, app.Alpha.Btn * current.Alpha * pal.Pick * 0.9, 3, 0)
        end
        Painter.unclip()
        Painter.scope(outer)
    end

    local viewBottom = bottom - lower
    local viewport = math.max(1, viewBottom - y)
    local content = math.max(1, Layout.sectionHeight(app, section) - lower - Widgets.GAP)
    local maxScroll = math.max(0, content - viewport)
    local cell = scrollCell(app, section)
    cell.Target = math.clamp(cell.Target, 0, maxScroll)
    if Hits.isDragging(BAR_KEY) then
        cell.Pos = cell.Target
    else
        cell.Pos = Motion.ease(state, cell.Pos, cell.Target, app.Dt, SCROLL_RATE)
        if math.abs(cell.Pos - cell.Target) < 0.05 then
            cell.Pos = cell.Target
        end
    end
    cell.Pos = math.clamp(cell.Pos, 0, maxScroll)
    local offset = cell.Pos
    local held = maxScroll > 0 or section.Query ~= nil
    if maxScroll > 0 then
        Hits.add({
            key = "page:wheel",
            position = app:pos(x - 10, y),
            size = app:size(width + 20, viewport),
            wheel = function(delta: number)
                cell.Target = math.clamp(cell.Target - delta * WHEEL_STEP, 0, maxScroll)
            end,
        })
    end

    for _, row in section.rows do
        if rowVisible(app, row) then
            local height = rowHeight(app, row)
            local target = if row.bottom then lowerCursor - bottom else cursor - y
            if not animated or row.Settled == nil or not row.Shown and (row.show or row.Filtered) then
                row.Settled = target
            else
                row.Settled = Motion.ease(state, row.Settled, target, app.Dt, 13)
                if math.abs(row.Settled - target) < 0.05 then
                    row.Settled = target
                end
            end
            local place = (if row.bottom then bottom else y - offset) + row.Settled
            local inside = row.bottom or maxScroll <= 0 or (place + height > y and place < viewBottom)
            local alpha, scale, dx, dy = state.TabAlpha, 1, 0, 0
            if animated then
                local delay = math.min(index * perRow, 0.5)
                local reveal = math.clamp(((state.TabReveal or 0) - delay) / math.max(0.01, 1 - delay), 0, 1)
                local settle = Motion.glide(reveal)
                alpha *= math.min(1, settle * 1.4)
                scale = 0.97 + 0.03 * settle
                dy = (1 - settle) * lift
                dx = (1 - settle) * slide * direction - (1 - state.TabAlpha) * 10 * direction
            end
            if row.show or row.Filtered then
                if not row.Shown then
                    row.Shown = true
                    row.Appear = if animated and state.TabReveal >= 1 then 0 else 1
                end
                row.Appear = Motion.ease(state, row.Appear, 1, app.Dt, 11)
                local entry = Motion.out(row.Appear)
                alpha *= entry
                dy += (1 - entry) * 8
            end
            local grouped = inside and not row.bottom and row.kind ~= "text" and not row.bare
            if inside then
                local fx = { Alpha = alpha, Scale = scale }
                local clipped = held and not row.bottom
                local clipAt, clipSize = app:pos(x - EDGE_SLACK, y), app:size(width + EDGE_SLACK * 2, viewport)
                if grouped then
                    local top = app:pos(0, place + dy).Y
                    local bottomEdge = app:pos(0, place + dy + height - Widgets.GAP).Y
                    if run then
                        table.insert(run.Lines, app:pos(0, place + dy - Widgets.GAP / 2).Y)
                        run.Bottom = bottomEdge
                        run.Alpha = math.min(run.Alpha, alpha)
                    else
                        run = { Top = top, Bottom = bottomEdge, Alpha = alpha, X = x + dx, Lines = {}, Splits = {} }
                    end
                    if row.kind == "pair" and not (stacked and not row.noStack) and run then
                        table.insert(run.Splits, { app:pos(x + dx + width / 2, 0).X, top + app:size(0, 6).Y, bottomEdge - app:size(0, 6).Y })
                    end
                else
                    flush(clipped, clipAt, clipSize)
                end
                if held and not row.bottom then
                    local clipAt, clipSize = app:pos(x - EDGE_SLACK, y), app:size(width + EDGE_SLACK * 2, viewport)
                    Painter.clip(clipAt, clipSize)
                    Hits.setClip(clipAt, clipSize)
                else
                    Painter.unclip()
                    Hits.setClip(nil, nil)
                end
                if row.kind == "pair" and stacked and not row.noStack then
                    local at = place + dy
                    for _, side in { row.left, row.right } do
                        if visible(app, side) then
                            Widgets.draw(app, side, x + dx, at, width, fx)
                            at += sideHeight(side)
                        end
                    end
                elseif row.kind == "pair" then
                    local half = math.floor((width - Widgets.GAP) / 2)
                    Widgets.draw(app, row.left, x + dx, place + dy, half, fx)
                    Widgets.draw(app, row.right, x + width - half + dx, place + dy, half, fx)
                else
                    Widgets.draw(app, row, x + dx, place + dy, width, fx)
                end
                Painter.unclip()
                Hits.setClip(nil, nil)
            end
            if row.bottom or row.kind == "text" or row.bare then
                flush(false, Vector2.zero, Vector2.zero)
            end
            if row.bottom then
                lowerCursor += height
            else
                cursor += height
            end
            index += 1
        elseif row.show or app.SearchText ~= nil and app.SearchText ~= "" then
            row.Shown = false
            row.Filtered = row.Filtered or row.show == nil
        end
    end

    flush(held, app:pos(x - EDGE_SLACK, y), app:size(width + EDGE_SLACK * 2, viewport))
    cell.Need = Motion.ease(state, cell.Need or 0, if maxScroll > 0 then 1 else 0, app.Dt, 12)
    if maxScroll > 0 then
        cell.Need = if animated then cell.Need else 1
        cell.Content, cell.Max = content, maxScroll
    elseif not animated or cell.Need < 0.01 then
        cell.Need = 0
    end
    if cell.Need > 0 and cell.Max then
        local shown = state.TabAlpha * cell.Need
        if animated then
            shown *= math.min(1, Motion.out(math.clamp(state.TabReveal or 0, 0, 1)) * 1.5)
        end
        drawScrollbar(app, cell, x, y, width, viewport, cell.Content, cell.Max, shown)
    end
end

return Layout
end
modules["ui/logo"] = function(...)

local import: (string) -> any = ...
local Icons: typeof(require("./icons")) = import("ui/icons")
local Emblem: typeof(require("./emblem")) = import("ui/emblem")
local Storage: typeof(require("../core/storage")) = import("core/storage")

local Logo = {}

type Map = { [string]: any }

local EXTENSIONS = { "png", "jpg" }

local function hash(text: string): string
    local value = 5381
    for index = 1, #text do
        value = (value * 33 + string.byte(text, index)) % 4294967296
    end
    return string.format("%08x", value)
end

local function extensionOf(body: string): string?
    if string.sub(body, 1, 8) == "\137PNG\r\n\26\n" then
        return "png"
    end
    if string.sub(body, 1, 3) == "\255\216\255" then
        return "jpg"
    end
    return nil
end

local function fetch(url: string): string?
    local ok, response = pcall(function()
        return request({ Url = url, Method = "GET" })
    end)
    if not ok or type(response) ~= "table" then
        return nil
    end
    local status = tonumber(response.StatusCode) or 0
    if status ~= 0 and (status < 200 or status >= 400) then
        return nil
    end
    return if type(response.Body) == "string" then response.Body else nil
end

local function asset(path: string): string?
    local ok, value = pcall(getcustomasset, path)
    if ok and type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function gameIconUrl(): string?
    local universe = game.GameId
    if type(universe) ~= "number" or universe <= 0 then
        return nil
    end
    local body = fetch("https://thumbnails.roblox.com/v1/games/icons?universeIds=" .. tostring(universe) .. "&returnPolicy=PlaceHolder&size=256x256&format=Png&isCircular=false")
    local data = if body then Storage.decode(body) else nil
    local first = if type(data) == "table" and type(data.data) == "table" then data.data[1] else nil
    if type(first) == "table" and type(first.imageUrl) == "string" and first.imageUrl ~= "" then
        return first.imageUrl
    end
    return nil
end

local function stored(folder: string, name: string, encoded: string): string?
    local path = folder .. "/" .. name
    if not Storage.isFile(path) then
        local ok, bytes = pcall(base64decode, encoded)
        if not ok or type(bytes) ~= "string" or not Storage.write(path, bytes) then
            return nil
        end
    end
    return asset(path)
end

local function emblem(folder: string): string?
    return stored(folder, "emblem.png", Emblem.PNG)
end

local function load(folder: string, source: Map): string?
    if source.Emblem == true then
        return emblem(folder)
    end
    local key = hash(tostring(source.Url or "gameicon"))
    for _, extension in EXTENSIONS do
        local path = folder .. "/" .. key .. "." .. extension
        if Storage.isFile(path) then
            local found = asset(path)
            if found then
                return found
            end
        end
    end
    local candidates: { string } = {}
    if type(source.Url) == "string" then
        table.insert(candidates, (string.gsub(source.Url, "/Webp/", "/Png/")))
    end
    local body: string? = nil
    for _, url in candidates do
        body = fetch(url)
        if body and extensionOf(body) then
            break
        end
        body = nil
    end
    if not body and source.GameIcon == true then
        local url = gameIconUrl()
        local downloaded = if url then fetch(url) else nil
        if downloaded and extensionOf(downloaded) then
            body = downloaded
        end
    end
    local extension = if body then extensionOf(body) else nil
    if not body or not extension then
        return nil
    end
    if not Storage.write(folder .. "/" .. key .. "." .. extension, body) then
        return nil
    end
    return asset(folder .. "/" .. key .. "." .. extension)
end

function Logo.startIcons(app: Map)
    task.spawn(function()
        local folder = tostring(app.Options.Folder) .. "/logo"
        if Storage.ensureFolder(folder) and not app.Destroyed then
            app.IconFolder = folder
        end
    end)
end

function Logo.icon(app: Map, name: string, wanted: number): (string?, number)
    local pixels = math.clamp(math.floor(wanted + 0.5), Icons.MIN, Icons.MAX)
    local folder = app.IconFolder
    if not folder then
        return nil, pixels
    end
    local cache: { [string]: string | boolean } = app.IconCache
    if not cache then
        cache = {}
        app.IconCache = cache
    end
    local key = name .. pixels
    local found = cache[key]
    if type(found) == "string" then
        return found, pixels
    end
    if found == nil then
        cache[key] = false
        task.spawn(function()
            local ok, result = pcall(stored, folder, name .. "-" .. pixels .. "s.png", Icons.SETS[name][pixels])
            if ok and result and not app.Destroyed then
                cache[key] = result
            end
        end)
    end
    return nil, pixels
end

function Logo.start(app: Map)
    local source: Map? = app.Options.Logo
    if not source then
        return
    end
    task.spawn(function()
        local folder = tostring(app.Options.Folder) .. "/logo"
        if not Storage.ensureFolder(folder) then
            return
        end
        local ok, found = pcall(load, folder, source)
        if ok and found and not app.Destroyed then
            app.LogoAsset = found
        end
    end)
end

return Logo
end
modules["ui/motion"] = function(...)

local import: (string) -> any = ...
local Util: typeof(require("../core/util")) = import("core/util")

local Motion = {}

type State = { [string]: any }

local PRESS_SPEED = 28

local SMOOTHING = 0.75

function Motion.ease(state: State, from: number, to: number, dt: number, speed: number): number
    if state.HighPerformanceMode then
        return to
    end
    local start = Util.finite(from, 0)
    local goal = Util.finite(to, 0)
    local step = Util.finite(dt, 0.01)
    return start + (goal - start) * (1 - math.exp(-speed * SMOOTHING * step))
end

function Motion.spring(state: State, bag: { [string]: any }, key: string, goal: number, dt: number, response: number, ratio: number): number
    local target = Util.finite(goal, 0)
    local cell = bag[key]
    if not cell then
        cell = { x = target, v = 0 }
        bag[key] = cell
        return target
    end
    if state.HighPerformanceMode then
        cell.x, cell.v = target, 0
        return target
    end
    local total = math.clamp(Util.finite(dt, 0.016), 0, 0.05)
    local steps = math.max(1, math.ceil(total * 150))
    local h = total / steps
    local omega = 2 * math.pi * Motion.intensity(state) / math.max(0.05, response)
    local stiffness, damping = omega * omega, 2 * ratio * omega
    local x, v = cell.x, cell.v
    for _ = 1, steps do
        v += (stiffness * (target - x) - damping * v) * h
        x += v * h
    end
    if math.abs(x - target) < 0.0004 and math.abs(v) < 0.004 then
        x, v = target, 0
    end
    cell.x, cell.v = Util.finite(x, target), Util.finite(v, 0)
    return cell.x
end

function Motion.out(t: number): number
    local u = 1 - math.clamp(t, 0, 1)
    return 1 - u * u * u
end

function Motion.glide(t: number): number
    local u = 1 - math.clamp(t, 0, 1)
    return 1 - u * u * u * u * u
end

function Motion.back(t: number): number
    local u = math.clamp(t, 0, 1) - 1
    return 1 + 2.25 * u * u * u + 1.25 * u * u
end

function Motion.velocity(bag: { [string]: any }, key: string): number
    local cell = bag[key]
    return if cell then cell.v else 0
end

function Motion.speed(state: State): number
    if state.AnimationsEnabled and not state.HighPerformanceMode then
        return math.clamp(tonumber(state.AnimationIntensity) or 1, 0.25, 1.50)
    end
    return 0.25
end

function Motion.intensity(state: State): number
    return math.clamp(tonumber(state.AnimationIntensity) or 1, 0.25, 1.50)
end

local function finiteVector(vector: Vector2, fallback: Vector2): Vector2
    return Vector2.new(Util.finite(vector.X, fallback.X), Util.finite(vector.Y, fallback.Y))
end

function Motion.press(
    state: State,
    interaction: { [string]: any },
    leftDown: boolean,
    position: Vector2,
    size: Vector2,
    hot: boolean,
    anim: number?,
    dt: number,
    shrink: number?
): (Vector2, Vector2, number, number)
    local pressed = false
    if hot and leftDown and interaction.Active and interaction.Mode == "PendingClick" and interaction.Bounds then
        local center = position + size / 2
        pressed = Util.contains(center, interaction.Bounds[1], interaction.Bounds[2])
    end
    local nextAnim = Util.finite(Motion.ease(state, anim or 0, if pressed then 1 else 0, dt, PRESS_SPEED))
    local scale = Util.finite(1 - (shrink or 0.05) * nextAnim, 1)
    local shrunk = finiteVector(size * scale, size)
    local moved = finiteVector(position + (size - shrunk) / 2, position)
    return moved, shrunk, nextAnim, scale
end

return Motion
end
modules["ui/overlay"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")
local Motion: typeof(require("./motion")) = import("ui/motion")
local Painter: typeof(require("./painter")) = import("ui/painter")
local Discord: typeof(require("./discord")) = import("ui/discord")
local Effects: typeof(require("./effects")) = import("ui/effects")
local Logo: typeof(require("./logo")) = import("ui/logo")

local Overlay = {}

type App = { [string]: any }

local Z_BODY, Z_TEXT = 40, 41
local CLICK_SOUND = "rbxasset://sounds/switch.wav"
local SEPARATOR = "  |  "

local function stateOf(app: App): App
    local overlay: App? = app.OverlayState
    if not overlay then
        overlay = { Fps = 60, Shown = 60, Last = 0, Mark = 0, Ping = 0, PingAt = -10, Clock = "", Hover = 0, Width = 0, ToastWidth = 0, Toast = 0, ToastText = "", PrevText = "", Swap = 1, Sound = nil }
        app.OverlayState = overlay
    end
    return overlay :: App
end

local function pill(state: App, name: string, position: Vector2, size: Vector2, pal: any, alpha: number, unit: number)
    local radius = math.min(14 * unit * Painter.corner(), size.Y / 2)
    Painter.rect(position, size, pal.Main, alpha * 0.92, Z_BODY, radius, true)
    Effects.outline(state, os.clock(), position, size, unit, alpha, name, radius, Z_BODY + 1)
end

local function ping(): number
    local ok, value = pcall(function()
        return game:GetService("Players").LocalPlayer:GetNetworkPing()
    end)
    return if ok and type(value) == "number" then math.floor(value * 1000 + 0.5) else 0
end

local function watermark(app: App, overlay: App, rawDt: number)
    local state = app.State
    local want = state.WatermarkEnabled == true and app.Welcome == nil and app.Boot == nil
    overlay.Mark = Motion.ease(state, overlay.Mark, if want then 1 else 0, app.Dt, 8)
    local alpha: number = math.clamp(overlay.Mark, 0, 1)
    if alpha < 0.01 then
        return
    end
    local live = 1 / math.max(rawDt, 0.001)
    overlay.Fps += (math.min(live, 999) - overlay.Fps) * (1 - math.exp(-3 * app.Dt))
    local goal = overlay.Fps
    if app.FarmOn == true and overlay.Real ~= nil then
        goal = overlay.Real
        overlay.Fps = goal
    end
    overlay.Shown += (goal - overlay.Shown) * (1 - math.exp(-4 * app.Dt))
    local now = os.clock()
    if now - overlay.PingAt > 1 then
        overlay.PingAt = now
        overlay.Ping = ping()
        overlay.Clock = os.date("%H:%M")
    end

    local pal = app.Pal
    local unit = math.max(0.6, app.Scale)
    local size = 14 * app.FarmTextScale
    local title = tostring(app.Options.Title)
    local version = "V" .. tostring(app.Options.Version)
    local invite: string? = app.Options.Discord
    local fps = tostring(math.floor(overlay.Shown + 0.5))
    local ms = tostring(overlay.Ping)
    local pad = 14 * unit
    local gap = 10 * unit
    local height = 34 * unit
    local logo: string? = app.LogoAsset
    local button = height - 10 * unit
    local inset = (height - button) / 2
    local logoSize = button
    local logoSpace = if logo then logoSize + gap else 0
    local padLeft = if logo then inset else pad
    local padRight = if invite then inset else pad
    local slotFps, slotMs = Painter.textWidth("000", size), Painter.textWidth("000", size)
    local unitFps, unitMs = Painter.textWidth(" FPS", size), Painter.textWidth(" ms", size)
    local titleWidth = Painter.textWidth(title, size)
    local versionWidth = Painter.textWidth(version, size)
    local clockWidth = Painter.textWidth("00:00", size)
    local buttonSpace = if invite then gap + button else 0
    local divider = gap * 2 + 1
    local goal = padLeft + padRight + logoSpace + titleWidth + divider + versionWidth + divider + slotFps + unitFps + divider + slotMs + unitMs + divider + clockWidth + buttonSpace
    overlay.Width = if overlay.Width < 1 then goal else Motion.ease(state, overlay.Width, goal, app.Dt, 10)

    local viewport: Vector2 = app.Viewport
    local home = Vector2.new(16 * unit, 16 * unit)
    local place: Vector2 = overlay.Place or home
    local mouse: Vector2 = app.Mouse
    local down = game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    local box = Vector2.new(overlay.Width, height)
    local buttonAt = Vector2.new(place.X + box.X - padRight - button, place.Y + (height - button) / 2)
    local overButton = invite ~= nil and mouse.X >= buttonAt.X and mouse.X <= buttonAt.X + button and mouse.Y >= buttonAt.Y and mouse.Y <= buttonAt.Y + button
    if down and not overlay.Down and mouse.X >= place.X and mouse.X <= place.X + box.X and mouse.Y >= place.Y and mouse.Y <= place.Y + box.Y then
        if overButton and invite then
            Discord.join(invite)
            app:openPopup("discord")
            Overlay.click(app)
        else
            overlay.Grab = place - mouse
        end
    end
    if not down then
        overlay.Grab = nil
    end
    overlay.Down = down
    if overlay.Grab then
        place = mouse + overlay.Grab
    end
    place = Vector2.new(math.clamp(place.X, 0, math.max(0, viewport.X - box.X)), math.clamp(place.Y, 0, math.max(0, viewport.Y - box.Y)))
    overlay.Place = place
    overlay.FarmMix = Motion.ease(state, overlay.FarmMix or 0, if app.FarmOn == true and app.FarmBox ~= nil then 1 else 0, app.Dt, 7)
    local farm = app.FarmBox
    if farm ~= nil and overlay.FarmMix > 0.002 then
        local goal = Vector2.new(farm[1].X + farm[2].X / 2 - box.X / 2, math.max(6 * unit, farm[1].Y - height - 10 * unit))
        local ramp = math.clamp(overlay.FarmMix, 0, 1)
        local mix = ramp * ramp * (3 - 2 * ramp)
        place = place:Lerp(goal, mix)
    end
    overlay.Hover = Motion.ease(state, overlay.Hover, if overButton then 1 else 0, app.Dt, 14)
    local at = Vector2.new(place.X, place.Y - 6 * (1 - alpha) * unit)

    Painter.scope("overlay:watermark")
    pill(state, "watermark", at, box, pal, alpha, unit)
    local mid = at.Y + height / 2
    local x = at.X + padLeft
    local function line(from: number)
        Painter.rect(Vector2.new(from, mid - height * 0.24), Vector2.new(1, height * 0.48), pal.Sub, alpha * 0.35, Z_TEXT, 0)
    end
    local function text(value: string, left: number, color: Color3)
        Painter.text(value, Vector2.new(left, mid + unit), size, color, alpha, Z_TEXT, false, true)
    end
    if logo then
        local emblem = app.Options.Logo ~= nil and app.Options.Logo.Emblem == true
        local logoAt = Vector2.new(x, mid - logoSize / 2)
        if emblem then
            Painter.image(logo, logoAt, Vector2.new(logoSize, logoSize), alpha, Z_TEXT, 0, pal.Accent)
        else
            Painter.image(logo, logoAt, Vector2.new(logoSize, logoSize), alpha, Z_TEXT, 4 * unit)
        end
        x += logoSpace
    end
    text(title, x, pal.Text)
    x += titleWidth + gap
    line(x)
    x += gap + 1
    text(version, x, pal.Accent)
    x += versionWidth + gap
    line(x)
    x += gap + 1
    text(fps, x, pal.Accent)
    text(" FPS", x + slotFps, pal.Sub)
    x += slotFps + unitFps + gap
    line(x)
    x += gap + 1
    text(ms, x, pal.Accent)
    text(" ms", x + slotMs, pal.Sub)
    x += slotMs + unitMs + gap
    line(x)
    x += gap + 1
    text(overlay.Clock, x, pal.Sub)
    if invite then
        local hover: number = overlay.Hover
        local round = math.min(10 * unit * Painter.corner(), button / 2)
        Painter.rect(Vector2.new(at.X + box.X - padRight - button, mid - button / 2), Vector2.new(button, button), Color.lerp(pal.Off, pal.Accent, math.max(0.25 + 0.4 * hover, pal.Pick * hover)), alpha, Z_BODY, round, true)
        local pixels = math.floor(button * 0.62 + 0.5)
        local icon = Logo.icon(app, "discord", pixels)
        if icon then
            local left = math.floor(at.X + box.X - padRight - button + (button - pixels) / 2 + 0.5)
            local top = math.floor(mid - pixels / 2 + 0.5)
            Painter.image(icon, Vector2.new(left, top), Vector2.new(pixels, pixels), alpha, Z_TEXT, 0, Color.lerp(pal.Text, pal.AccentText, hover))
        end
    end
    Painter.scope(nil)
end

local function toast(app: App, overlay: App)
    local state = app.State
    local notice: App? = app.Notice
    local live = notice ~= nil and os.clock() < notice.Expires and state.ToggleNotifications == true
    if live and notice and notice.Text ~= overlay.ToastText then
        if overlay.Toast < 0.05 then
            overlay.PrevText = ""
            overlay.Swap = 1
            overlay.ToastWidth = 0
        else
            overlay.PrevText = overlay.ToastText
            overlay.Swap = 0
        end
        overlay.ToastText = notice.Text
    end
    overlay.Toast = Motion.ease(state, overlay.Toast, if live then 1 else 0, app.Dt, 9)
    overlay.Swap = Motion.ease(state, overlay.Swap, 1, app.Dt, 10)
    local alpha: number = math.clamp(overlay.Toast, 0, 1)
    if alpha < 0.01 then
        return
    end
    local pal = app.Pal
    local unit = math.max(0.6, app.Scale)
    local size = 15 * app.FarmTextScale
    local text: string = overlay.ToastText
    local goal = Painter.textWidth(text, size) + 40 * unit
    overlay.ToastWidth = if overlay.ToastWidth < 1 then goal else Motion.ease(state, overlay.ToastWidth, goal, app.Dt, 8)
    local height = 36 * unit
    local viewport: Vector2 = app.Viewport
    local at = Vector2.new(viewport.X / 2 - overlay.ToastWidth / 2, (22 - 10 * (1 - alpha)) * unit)
    Painter.scope("overlay:toast")
    pill(state, "toast", at, Vector2.new(overlay.ToastWidth, height), pal, alpha, unit)
    local color = Color.lerp(pal.Text, pal.Accent, 0.35)
    local swap = math.clamp(overlay.Swap, 0, 1)
    local center = at.Y + height / 2
    local rise = 8 * unit
    if swap < 0.98 and overlay.PrevText ~= "" then
        Painter.text(overlay.PrevText, Vector2.new(viewport.X / 2, center - rise * swap), size, color, alpha * (1 - swap), Z_TEXT, true, true)
    end
    Painter.text(text, Vector2.new(viewport.X / 2, center + rise * (1 - swap)), size, color, alpha * swap, Z_TEXT, true, true)
    Painter.scope(nil)
end

function Overlay.draw(app: App, now: number)
    local overlay = stateOf(app)
    local rawDt = if overlay.Last > 0 then now - overlay.Last else 1 / 60
    overlay.Last = now
    overlay.Frames = (overlay.Frames or 0) + 1
    local since = now - (overlay.Counted or now)
    if overlay.Counted == nil then
        overlay.Counted = now
    elseif since >= 0.5 then
        overlay.Real = math.min(overlay.Frames / since, 999)
        overlay.Frames, overlay.Counted = 0, now
    end
    watermark(app, overlay, rawDt)
    toast(app, overlay)
end

function Overlay.click(app: App)
    local overlay = stateOf(app)
    pcall(function()
        local sound: any = overlay.Sound
        if not sound then
            sound = Instance.new("Sound")
            sound.Name = "OkloClick"
            sound.SoundId = tostring(getgenv().OkloUIClickSound or CLICK_SOUND)
            sound.Volume = 0.45
            sound.Parent = game:GetService("SoundService")
            overlay.Sound = sound
        end
        sound.TimePosition = 0
        sound:Play()
    end)
end

function Overlay.destroy(app: App)
    local overlay: App? = app.OverlayState
    if overlay and overlay.Sound then
        pcall(function()
            overlay.Sound:Destroy()
        end)
        overlay.Sound = nil
    end
end

return Overlay
end
modules["ui/overlays"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")
local Effects: typeof(require("./effects")) = import("ui/effects")
local Hits: typeof(require("./hits")) = import("ui/hits")
local Kit: typeof(require("./popups/kit")) = import("ui/popups/kit")
local Motion: typeof(require("./motion")) = import("ui/motion")
local Painter: typeof(require("./painter")) = import("ui/painter")
local Press: typeof(require("./press")) = import("ui/press")
local Util: typeof(require("../core/util")) = import("core/util")

local Overlays = {}

type App = { [string]: any }

local ITEM_HEIGHT = 26
local Z_DROPDOWN, Z_DROPDOWN_ITEM, Z_DROPDOWN_TEXT = 15, 16, 17
local Z_DIM, Z_POPUP = 20, 21

local function clamp01(value: number): number
    return math.clamp(value, 0, 1)
end

local function fullScreen(): (Vector2, Vector2)
    return Vector2.new(-10, -10), Vector2.new(100000, 100000)
end

function Overlays.drawDropdown(app: App)
    local state = app.State
    local spec = app.OpenDropdown
    local box = app.DropdownBox
    app.DropdownBox = nil
    if spec and not box then
        app.OpenDropdown = nil
        spec = nil
    end
    state.DropAlpha = Motion.ease(state, state.DropAlpha or 0, if spec then 1 else 0, app.Dt, 18)
    local swing = Motion.spring(state, app.Springs, "dropdown", if spec then 1 else 0, app.Dt, if spec then 0.36 else 0.24, if spec then 0.74 else 1)
    if spec then
        app.ShownDropdown = spec
        app.ShownBox = box
    elseif state.DropAlpha < 0.01 then
        app.ShownDropdown = nil
        return
    end
    local shown = app.ShownDropdown
    local shownBox = app.ShownBox
    if not shown or not shownBox then
        return
    end

    local pal = app.Pal
    local values: { any } = app.DropdownValues
    local alpha: number = state.DropAlpha
    local unit = app.Unit
    local itemHeight = ITEM_HEIGHT * unit
    local pad = 4 * unit
    local fullHeight = #values * itemHeight + pad * 2
    local height = math.floor(fullHeight * math.max(0, swing))
    local width = shownBox.Size.X
    local grow = clamp01(swing)
    local position = shownBox.Position + Vector2.new(0, shownBox.Size.Y + 4 * unit - (1 - grow) * 6 * unit)
    Painter.scope("dropdown:card")
    Painter.rect(position, Vector2.new(width, height), pal.Panel, alpha * state.UITrans, Z_DROPDOWN, 12 * unit)
    Painter.border(position, Vector2.new(width, height), 12 * unit, pal.Off, alpha * 0.95, Z_DROPDOWN_ITEM + 2, 1.2)
    Painter.scope(nil)

    if spec then
        local outside, size = fullScreen()
        Hits.add({
            key = "dropdown:outside",
            position = outside,
            size = size,
            click = function()
                app.OpenDropdown = nil
            end,
        })
    end
    local lit, litAt = 0, nil
    for index = 1, #values do
        if spec and app.HoverKey == "dropdown:item:" .. index then
            lit, litAt = 1, pad + (index - 1) * itemHeight
        end
    end
    local slide = app.NavAnim["dropdown:slide"]
    if type(slide) ~= "number" or not spec then
        slide = litAt or slide or pad
    end
    if litAt then
        slide = Motion.ease(state, slide, litAt, app.Dt, 22)
    end
    app.NavAnim["dropdown:slide"] = slide
    local glow = Motion.ease(state, app.NavAnim["dropdown:glow"] or 0, lit, app.Dt, 16)
    app.NavAnim["dropdown:glow"] = glow
    Painter.scope("dropdown:highlight")
    Painter.rect(position + Vector2.new(pad, slide), Vector2.new(width - pad * 2, itemHeight), pal.Accent, alpha * glow * state.ButtonTrans, Z_DROPDOWN_ITEM, 8 * unit)
    Painter.scope(nil)
    for index, value in values do
        local y = pad + (index - 1) * itemHeight
        local lag = clamp01(alpha * 1.7 - (index - 1) * 0.1) * clamp01((height - y - itemHeight * 0.4) / (itemHeight * 0.6))
        local key = "dropdown:item:" .. index
        local itemPos = position + Vector2.new(pad + (1 - lag) * 8 * unit, y)
        local itemSize = Vector2.new(width - pad * 2, itemHeight)
        local hover = Motion.ease(state, app.NavAnim[key] or 0, if app.HoverKey == key and spec then 1 else 0, app.Dt, Press.HOVER_SPEED)
        app.NavAnim[key] = hover
        local selected = tostring(value) == tostring(shown.get())
        local textColor = Color.lerp(pal.Text, pal.AccentText, hover)
        Painter.scope(key)
        if selected then
            local tick = itemPos + Vector2.new(11 * unit, itemSize.Y / 2)
            local weight = math.max(1.5, 1.7 * unit)
            local mark = Color.lerp(pal.Accent, pal.AccentText, hover)
            Painter.line(tick + Vector2.new(-3.2 * unit, 0.2 * unit), tick + Vector2.new(-0.8 * unit, 2.6 * unit), mark, alpha * lag, Z_DROPDOWN_TEXT, weight)
            Painter.line(tick + Vector2.new(-0.8 * unit, 2.6 * unit), tick + Vector2.new(3.4 * unit, -2.8 * unit), mark, alpha * lag, Z_DROPDOWN_TEXT, weight)
        end
        Painter.text(tostring(value), itemPos + Vector2.new(24 * unit, itemSize.Y / 2), 13 * app.TextScale, textColor, alpha * lag, Z_DROPDOWN_TEXT, false, true)
        Painter.scope(nil)
        if spec and y + itemHeight < height + 2 * unit then
            Hits.add({
                key = key,
                position = itemPos,
                size = itemSize,
                click = function()
                    app:selectDropdown(shown, value)
                end,
            })
        end
    end
end

local SWAP_TIME = 0.5
local SWAP_OUT, SWAP_IN = 0.3, 0.65

local function seg(value: number, from: number, to: number): number
    return clamp01((value - from) / (to - from))
end

local function smoother(value: number): number
    local t = clamp01(value)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

function Overlays.isDefault(app: App): boolean
    local preset = app.State.ThemePreset
    return type(preset) == "table" and preset.Name == "Default" and app.State.ThemeName ~= "Custom"
end

local function popupColor(app: App): Color3
    if Overlays.isDefault(app) then
        return Color.lerp(Color.lerp(app.Pal.Main, Color3.new(0, 0, 0), 0.62), app.Pal.Accent, 0.02)
    end
    return Color.lerp(app.Pal.Main, app.Pal.Accent, 0.07)
end

function Overlays.drawPopup(app: App, now: number)
    local popup = app.Popup
    local state = app.State
    popup.Alpha = Motion.ease(state, popup.Alpha, if popup.Open then 1 else 0, app.Dt, 14)
    if popup.Name == "None" then
        return
    end
    if not popup.Open and popup.Alpha <= 0.01 then
        popup.Name = "None"
        popup.Alpha = 0
        popup.From, popup.Shown = nil, nil
        return
    end
    local definition = app.PopupDefs[popup.Name]
    if not definition then
        popup.Name = "None"
        popup.From, popup.Shown = nil, nil
        return
    end

    local width, height = definition.size(app, popup.Arg)
    local from = popup.From
    local previous = if from then app.PopupDefs[from.Name] else nil
    local swap = 1
    if from then
        popup.Swap = if state.HighPerformanceMode then 1 else math.min(1, popup.Swap + app.Dt / SWAP_TIME)
        swap = popup.Swap
        if swap >= 1 or not previous then
            popup.From, from, previous, swap = nil, nil, nil, 1
        end
    end
    local resize = if from then smoother(seg(swap, SWAP_OUT, SWAP_IN)) else 1
    local boxWidth = if from then from.Width + (width - from.Width) * resize else width
    local boxHeight = if from then from.Height + (height - from.Height) * resize else height
    popup.Shown = Vector2.new(boxWidth, boxHeight)
    local m = app.M
    local morph = clamp01(popup.Alpha)
    local grow = Motion.spring(state, app.Springs, "popup", if popup.Open then 1 else 0, app.Dt, if popup.Open then 0.46 else 0.3, if popup.Open then 0.7 else 1)
    local finalPos = Vector2.new((m.Width - boxWidth) / 2, (m.Height - boxHeight) / 2)
    if popup.Open and math.abs(grow - 1) <= 0.002 then
        grow = 1
    end
    local settling = morph < 0.999 or grow ~= 1 or from ~= nil
    Painter.fine(settling)
    local designPos = Util.lerpVector2(popup.SourcePos, finalPos, grow)
    local designSize = Util.lerpVector2(popup.SourceSize, Vector2.new(boxWidth, boxHeight), grow)
    local position, size = app:pos(designPos.X, designPos.Y), app:size(designSize.X, designSize.Y)

    local intro = state.IntroAlpha
    Painter.rect(app.WindowPos, app.WindowSize, Color.lerp(Color3.new(0, 0, 0), app.Pal.Main, 0.18), popup.Alpha * 0.45 * intro, Z_DIM, math.max(12, math.round(36 * app.Scale)))
    Painter.rect(position, size, popupColor(app), morph * intro, Z_POPUP, 32)
    Effects.outline(state, now, position, size, app.Scale, morph * intro, "popup", 32 * Painter.corner(), Z_POPUP + 1)

    if popup.Open then
        local outside, outsideSize = fullScreen()
        Hits.add({
            key = "popup:outside",
            position = outside,
            size = outsideSize,
            click = function()
                if not definition.locked then
                    app:closePopup()
                end
            end,
        })
    end

    local shown, shownArg, shownWidth, shownHeight, fade = definition, popup.Arg, width, height, seg(swap, SWAP_IN, 1)
    popup.Leaving = from ~= nil and previous ~= nil and swap < SWAP_OUT
    if popup.Leaving and from and previous then
        shown, shownArg, shownWidth, shownHeight, fade = previous, from.Arg, from.Width, from.Height, 1 - seg(swap, 0, SWAP_OUT)
    end
    local textAlpha = math.clamp((popup.Alpha - 0.2) * 1.25, 0, 1) * app.Alpha.Text * fade
    local kit = Kit.new(app, shownWidth, shownHeight, position, size, textAlpha)
    if popup.Open then
        kit:shield()
    end
    if textAlpha > 0.01 then
        local title = shown.title(app, shownArg)
        Hits.suspend(not popup.Open or shown ~= definition)
        if title ~= "" then
            kit:title(title)
            if shown.closable ~= false then
                kit:closeX(function()
                    app:closePopup()
                end)
            end
        end
        pcall(shown.render, app, kit, shownArg)
        Hits.suspend(false)
    end
    Painter.fine(false)
end

return Overlays
end
modules["ui/pages"] = function(...)

local import: (string) -> any = ...
local Builder: typeof(require("./builder")) = import("ui/builder")

local Pages = {}

type Map = { [string]: any }
type Window = { [string]: any }

local CUSTOM_GROUP = "UI"
local SETTINGS_GROUP = "Settings"
local BACKGROUND_EFFECTS = { "Random", "Bokeh", "Dust", "Silk", "Snowfall", "Fireflies", "Rain", "None" }

local function performanceOff(window: Window): boolean
    return window.State.HighPerformanceMode == true
end

local function animatedTheme(window: Window): boolean
    local state = window.State
    local preset = state.ThemePreset
    return state.ThemeName ~= "Custom" and type(preset) == "table" and type(preset.Cycle) == "table" and #preset.Cycle >= 2
end

local function transparencyLocked(window: Window): boolean
    return performanceOff(window) or not window.State.Transparent
end

local function themeLabel(window: Window): string
    local state = window.State
    return "Themes: " .. tostring(state.ThemeName)
end

local function category(section: any, text: string)
    section:label({ Text = text, Size = 15, Bold = true, Height = 30 })
end

local function customization(window: Window)
    local tab = Builder.newTab(window, "Customization", { Group = SETTINGS_GROUP })
    local compact = window.M.Height < 460
    local look = tab:section("CUSTOMIZATION")
    category(look, "Size & Motion")
    look:slider({ Name = "UI Scale", StateKey = "UIScale", Min = 0.50, Max = 1.50, Float = true })
    look:slider({ Name = "Animation Speed", StateKey = "AnimationIntensity", Min = 0.25, Max = 1.50, Float = true })
    category(look, "Shape")
    look:slider({ Name = "Corner Roundness", StateKey = "Roundness", Min = 0, Max = 0.6, Float = true })
    look:slider({ Name = "Toggle Roundness", StateKey = "ToggleRoundness", Min = 0, Max = 1, Float = true })
    category(look, "Animation")
    look:pair(
        { Type = "Toggle", Name = "Smooth Pages", StateKey = "AnimationsEnabled", NoStack = compact },
        { Type = "Toggle", Name = "Outline Anim", StateKey = "PremiumEffects" }
    )

    local colors = tab:section("COLORS")
    category(colors, "Transparency")
    colors:pair(
        { Type = "Slider", Name = "UI Transparency", StateKey = "UITrans", Min = 0, Max = 1, Float = true, Disabled = transparencyLocked },
        { Type = "Slider", Name = "Btn Transparency", StateKey = "ButtonTrans", Min = 0, Max = 1, Float = true, Disabled = transparencyLocked }
    )
    category(colors, "Colors")
    colors:pair(
        { Type = "Toggle", Name = "Light Mode", StateKey = "LightMode", NoStack = compact },
        { Type = "Toggle", Name = "Transparent", StateKey = "Transparent", Disabled = performanceOff }
    )
    colors:pair(
        { Type = "Color", Name = "Edit Accent Color", StateKey = "AccentCol", Default = window.DefaultAccent, NoStack = compact },
        { Type = "Color", Name = "Edit Main Color", StateKey = "MainCol", Default = window.DefaultMain }
    )
    local extras = colors
    category(extras, "Theme")
    extras:pair({
        Type = "Dropdown",
        Name = "Background Effect",
        StateKey = "BackgroundEffect",
        Values = BACKGROUND_EFFECTS,
        Disabled = function(window: Window): boolean
            return performanceOff(window) or animatedTheme(window) or window.State.ThemeName == "Default"
        end,
        Callback = function()
            window:regenerateParticles()
        end,
    }, {
        Type = "Button",
        Name = "Themes",
        Label = themeLabel,
        Callback = function()
            window:togglePopup("themes")
        end,
    })
    category(colors, "Reset")
    colors:button({
        Name = "Reset Settings",
        Callback = function()
            window:resetAppearance()
        end,
    })
end

local function keybindLabel(window: Window): string
    if window.Focus == window.CAPTURE_PREFIX .. "Keybind" then
        return "Press Any..."
    end
    return "UI Keybind: " .. tostring(window.State.Keybind)
end

local MAX_LISTED = 8

local function bindCell(window: Window, index: number): Map
    return {
        Type = "BindRow",
        Index = index,
        Show = function()
            return #window:boundOptions() >= index
        end,
    }
end

local function keybinds(window: Window)
    local tab = Builder.newTab(window, "General", { Group = SETTINGS_GROUP })
    local compact = window.M.Height < 460
    local behavior = tab:section("GENERAL")
    category(behavior, "Window")
    behavior:pair(
        { Type = "Toggle", Name = "Watermark", StateKey = "WatermarkEnabled", NoStack = compact },
        { Type = "Toggle", Name = "Click Sound", StateKey = "ClickSound" }
    )
    behavior:pair(
        { Type = "Toggle", Name = "Lock Position", StateKey = "LockPosition", NoStack = compact },
        { Type = "Toggle", Name = "Remember Tab", StateKey = "RememberTab" }
    )
    category(behavior, "Behavior")
    behavior:pair(
        { Type = "Toggle", Name = "Notifications", StateKey = "ToggleNotifications", NoStack = compact },
        { Type = "Toggle", Name = "Start Hidden", StateKey = "StartHidden" }
    )
    behavior:add({ Type = "Toggle", Name = "Faster Loader", StateKey = "FasterLoader" })
    behavior:button({
        Name = "Reset Window Position/Size",
        Callback = function()
            window:resetWindow()
        end,
    })

    local section = behavior
    category(section, "Keybinds")
    section:button({
        Name = "UI Keybind",
        Label = keybindLabel,
        Callback = function()
            window:beginCapture(window.CAPTURE_PREFIX .. "Keybind", function(key: string)
                window.State.Keybind = key
            end)
        end,
    })
    local clear = {
        Type = "Button",
        Name = "Clear Option Binds",
        Callback = function()
            window:clearBinds()
        end,
    }
    section:button(clear)
    section:label({
        Text = "No option has a keybind yet",
        Height = 19,
        Show = function()
            return #window:boundOptions() == 0
        end,
    })
    for first = 1, MAX_LISTED, 2 do
        section:pair(bindCell(window, first), bindCell(window, first + 1))
    end
    section:label({
        Height = 19,
        Show = function()
            return #window:boundOptions() > MAX_LISTED
        end,
        Label = function()
            return "+" .. tostring(#window:boundOptions() - MAX_LISTED) .. " more with a keybind"
        end,
    })
end


local function setDefault(window: Window)
    window.Config:setDefault(tostring(window.State.DefaultConfigName), tostring(window.State.AutoLoadScope))
end

local function config(window: Window)
    local tab = Builder.newTab(window, "Config", { Group = SETTINGS_GROUP })
    local section = tab:section("CONFIG")
    local files = window.Config
    category(section, "Save")
    section:input({ Name = "Config Name...", StateKey = "ConfigName", MaxLength = 32 })
    section:button({
        Name = "Save Config",
        Callback = function()
            window:saveConfig(window.State.ConfigName)
        end,
    })
    category(section, "Load")
    section:dropdown({
        Name = "Select Config",
        StateKey = "SelectedConfig",
        Values = function()
            return files:list()
        end,
    })
    local load = {
        Type = "Button",
        Name = "Load Config",
        Callback = function()
            window:loadConfig(window.State.SelectedConfig, false)
        end,
    }
    local delete = {
        Type = "Button",
        Name = "Delete Config",
        Callback = function()
            if window.State.SelectedConfig ~= "None" then
                window:togglePopup("deleteConfig")
            end
        end,
    }
    local compact = window.M.Height < 460
    if compact then
        load.NoStack, delete.NoStack = true, true
        section:pair(load, delete)
    else
        section:add(load)
        section:add(delete)
    end
    category(section, "Auto Load")
    section:dropdown({
        Name = "Auto Load",
        StateKey = "DefaultConfigName",
        Values = function()
            return files:listWithNone()
        end,
        Callback = function()
            setDefault(window)
        end,
    })
    section:dropdown({
        Name = "Auto Load For",
        StateKey = "AutoLoadScope",
        Values = { "All Games", "This Game" },
        Callback = function()
            setDefault(window)
        end,
    })
    category(section, "Share")
    section:pair({
        Type = "Button",
        Name = "Copy Config Code",
        NoStack = compact,
        Callback = function()
            window:copyConfigCode()
        end,
    }, {
        Type = "Button",
        Name = "Import Config Code",
        Callback = function()
            window:importConfigCode()
        end,
    })
    section:label({
        Size = 11,
        Height = 19,
        Label = function()
            local note: string = window.State.ShareNote
            return if note ~= "" then note else "Copy or paste a config code with the buttons above"
        end,
    })
end

function Pages.install(window: Window)
    customization(window)
    keybinds(window)
    config(window)
end

return Pages
end
modules["ui/painter"] = function(...)

local import: (string) -> any = ...
local Draw: typeof(require("../render/draw")) = import("render/draw")
local Fonts: typeof(require("./fonts")) = import("ui/fonts")

local Painter = {}

type Scope = {
    rects: { any },
    texts: { any },
    images: { any },
    outlines: { any },
    rectCount: number,
    textCount: number,
    imageCount: number,
    outlineCount: number,
    shownRects: number,
    shownTexts: number,
    shownImages: number,
    shownOutlines: number,
    stamp: number,
}

local function newScope(): Scope
    return {
        rects = {},
        texts = {},
        images = {},
        outlines = {},
        rectCount = 0,
        textCount = 0,
        imageCount = 0,
        outlineCount = 0,
        shownRects = 0,
        shownTexts = 0,
        shownImages = 0,
        shownOutlines = 0,
        stamp = 0,
    }
end

local fallback: Scope = newScope()
local scopes: { [string]: Scope } = {}
local current: Scope = fallback
local currentKey: string? = nil
local touched: { Scope } = { fallback }
local lastTouched: { Scope } = {}
local frameStamp = 0

local corner = 0.46
local font = Fonts.DEFAULT
local imagesReady, imagesLoading = 0, 0

local Z_SLOT = 100000
local order = 0
local warming = false

function Painter.warm(state: boolean)
    warming = state
end

local function lift(alpha: number): number
    return if warming and alpha <= 0.004 then 0.005 else alpha
end

local function depth(zIndex: number): number
    order += 1
    return zIndex * Z_SLOT + math.min(order, Z_SLOT - 1)
end

function Painter.setCorner(value: number)
    corner = math.clamp(value, 0, 0.6)
end

function Painter.corner(): number
    return corner
end

function Painter.setFont(index: number)
    font = index
end

function Painter.font(): number
    return font
end

function Painter.begin()
    order = 0
    Draw.beginFrame()
    frameStamp += 1
    lastTouched, touched = touched, { fallback }
    fallback.stamp = frameStamp
    fallback.rectCount, fallback.textCount, fallback.imageCount, fallback.outlineCount = 0, 0, 0, 0
    current = fallback
    currentKey = nil
    imagesReady, imagesLoading = 0, 0
end

function Painter.active(): string?
    return currentKey
end

function Painter.scope(key: any?)
    if key == nil then
        current = fallback
        currentKey = nil
        return
    end
    local name = tostring(key)
    currentKey = name
    local scope = scopes[name]
    if not scope then
        scope = newScope()
        scopes[name] = scope
    end
    if scope.stamp ~= frameStamp then
        scope.stamp = frameStamp
        scope.rectCount, scope.textCount, scope.imageCount, scope.outlineCount = 0, 0, 0, 0
        touched[#touched + 1] = scope
    end
    current = scope
end

local function trim(scope: Scope)
    for index = scope.rectCount + 1, scope.shownRects do
        scope.rects[index]:show(false)
    end
    for index = scope.textCount + 1, scope.shownTexts do
        scope.texts[index]:show(false)
    end
    for index = scope.imageCount + 1, scope.shownImages do
        scope.images[index]:show(false)
    end
    for index = scope.outlineCount + 1, scope.shownOutlines do
        scope.outlines[index]:show(false)
    end
    scope.shownRects, scope.shownTexts, scope.shownImages, scope.shownOutlines = scope.rectCount, scope.textCount, scope.imageCount, scope.outlineCount
end

function Painter.finish()
    Draw.endFrame()
    for _, scope in touched do
        trim(scope)
    end
    for _, scope in lastTouched do
        if scope.stamp ~= frameStamp then
            scope.rectCount, scope.textCount, scope.imageCount, scope.outlineCount = 0, 0, 0, 0
            trim(scope)
        end
    end
end

function Painter.hideAll()
    fallback.rectCount, fallback.textCount, fallback.imageCount, fallback.outlineCount = 0, 0, 0, 0
    trim(fallback)
    for _, scope in scopes do
        scope.rectCount, scope.textCount, scope.imageCount, scope.outlineCount = 0, 0, 0, 0
        trim(scope)
    end
    Painter.finish()
end

function Painter.clip(position: Vector2, size: Vector2)
    Draw.setClip(position.X, position.Y, size.X, size.Y)
end

function Painter.unclip()
    Draw.clearClip()
end

function Painter.clipBox(): (number?, number?, number?, number?)
    return Draw.clipBox()
end

function Painter.fine(state: boolean)
    Draw.fine(state)
end

function Painter.rect(position: Vector2, size: Vector2, color: Color3, alpha: number, zIndex: number, rounding: number?, absolute: boolean?, rotation: number?)
    local z = depth(zIndex)
    alpha = lift(alpha)
    local index = current.rectCount + 1
    current.rectCount = index
    local node = current.rects[index]
    if not node then
        node = Draw.rect()
        current.rects[index] = node
    end
    if alpha <= 0.004 or size.X < 1 or size.Y < 1 then
        node:show(false)
        return
    end
    local radius = if absolute then math.min(rounding or 0, math.min(size.X, size.Y) * 0.5) else (rounding or 0) * corner
    node:update(position.X, position.Y, size.X, size.Y, color, math.clamp(alpha, 0, 1), z, radius, rotation)
    node:unpaint()
    node:show(true)
end

function Painter.gradient(position: Vector2, size: Vector2, colors: { Color3 }, angle: number, alpha: number, zIndex: number, rounding: number?)
    local z = depth(zIndex)
    alpha = lift(alpha)
    local index = current.rectCount + 1
    current.rectCount = index
    local node = current.rects[index]
    if not node then
        node = Draw.rect()
        current.rects[index] = node
    end
    if alpha <= 0.004 or size.X < 1 or size.Y < 1 or #colors < 2 then
        node:show(false)
        return
    end
    node:update(position.X, position.Y, size.X, size.Y, Color3.new(1, 1, 1), math.clamp(alpha, 0, 1), z, (rounding or 0) * corner, 0)
    node:paint(colors, angle)
    node:show(true)
end

function Painter.fade(position: Vector2, size: Vector2, color: Color3, from: number, to: number, angle: number, alpha: number, zIndex: number, rounding: number?)
    local z = depth(zIndex)
    alpha = lift(alpha)
    local index = current.rectCount + 1
    current.rectCount = index
    local node = current.rects[index]
    if not node then
        node = Draw.rect()
        current.rects[index] = node
    end
    if alpha <= 0.004 or size.X < 1 or size.Y < 1 then
        node:show(false)
        return
    end
    node:update(position.X, position.Y, size.X, size.Y, color, math.clamp(alpha, 0, 1), z, (rounding or 0) * corner, 0)
    node:fade(from, to, angle)
    node:show(true)
end

function Painter.border(position: Vector2, size: Vector2, radius: number, color: Color3, alpha: number, zIndex: number, thickness: number)
    local z = depth(zIndex)
    alpha = lift(alpha)
    local index = current.outlineCount + 1
    current.outlineCount = index
    local node = current.outlines[index]
    if not node then
        node = Draw.outline()
        current.outlines[index] = node
    end
    if alpha <= 0.004 or size.X < 4 or size.Y < 4 then
        node:show(false)
        return
    end
    local line = if thickness < 1.5 then 1 else thickness
    local half = math.floor(math.min(size.X, size.Y) + 0.5) * 0.5
    node:update(position.X, position.Y, size.X, size.Y, color, color, math.clamp(alpha, 0, 1), z, math.min(radius, half), line, 0, false, true)
    node:show(true)
end

function Painter.outline(position: Vector2, size: Vector2, radius: number, color: Color3, light: Color3, alpha: number, zIndex: number, thickness: number, rotation: number, trail: boolean | number)
    local z = depth(zIndex)
    alpha = lift(alpha)
    local index = current.outlineCount + 1
    current.outlineCount = index
    local node = current.outlines[index]
    if not node then
        node = Draw.outline()
        current.outlines[index] = node
    end
    if string.find(tostring(getgenv().OkloUISkip), "outline", 1, true) ~= nil or alpha <= 0.004 or size.X < 4 or size.Y < 4 then
        node:show(false)
        return
    end
    node:update(position.X, position.Y, size.X, size.Y, color, light, math.clamp(alpha, 0, 1), z, math.min(radius, math.min(size.X, size.Y) * 0.5), thickness, rotation, trail)
    node:show(true)
end

function Painter.line(from: Vector2, to: Vector2, color: Color3, alpha: number, zIndex: number, thickness: number)
    local delta = to - from
    local length = delta.Magnitude
    if length < 0.5 then
        return
    end
    local middle = (from + to) / 2
    local angle = math.deg(math.atan2(delta.Y, delta.X))
    Painter.rect(middle - Vector2.new(length / 2, thickness / 2), Vector2.new(length, thickness), color, alpha, zIndex, thickness / 2, true, angle)
end

function Painter.image(url: string, position: Vector2, size: Vector2, alpha: number, zIndex: number, rounding: number?, tint: Color3?, rotation: number?): boolean
    local z = depth(zIndex)
    alpha = lift(alpha)
    local index = current.imageCount + 1
    current.imageCount = index
    local node = current.images[index]
    if not node then
        node = Draw.image()
        current.images[index] = node
    end
    if url == "" or alpha <= 0.004 or size.X < 1 or size.Y < 1 then
        node:show(false)
        return false
    end
    local radius = math.min(rounding or 0, math.min(size.X, size.Y) * 0.5)
    node:update(url, position.X, position.Y, size.X, size.Y, math.clamp(alpha, 0, 1), z, radius, tint, rotation)
    node:show(true)
    imagesReady += 1
    return true
end

function Painter.preload(_url: string, _position: Vector2, _size: Vector2, _rounding: number?) end

function Painter.imageStats(): (number, number, number, number)
    return imagesReady, imagesLoading, 0, 1
end

function Painter.textWidth(text: string, size: number): number
    return Draw.measure(text, math.max(1, math.ceil(size)), font)
end

function Painter.text(
    text: string,
    position: Vector2,
    size: number,
    color: Color3,
    alpha: number,
    zIndex: number,
    center: boolean?,
    middle: boolean?,
    fontIndex: number?
)
    local z = depth(zIndex)
    alpha = lift(alpha)
    local index = current.textCount + 1
    current.textCount = index
    local node = current.texts[index]
    if not node then
        node = Draw.text()
        current.texts[index] = node
    end
    if alpha <= 0.004 or text == "" then
        node:show(false)
        return
    end
    local face = fontIndex or font
    local drawSize = math.max(1, math.ceil(size))
    local width = Draw.measure(text, drawSize, face) + 2
    local x = if center then position.X - (width - 2) * 0.5 else position.X
    local y = if middle then position.Y - drawSize * 0.5 else position.Y
    node:update(text, x, y, width, drawSize, drawSize, color, math.clamp(alpha, 0, 1), z, face)
    node:show(true)
end

function Painter.reset()
    fallback = newScope()
    scopes = {}
    current = fallback
    currentKey = nil
    touched = { fallback }
    lastTouched = {}
end

return Painter
end
modules["ui/palette"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")
local Theme: typeof(require("../core/theme")) = import("core/theme")
local Motion: typeof(require("./motion")) = import("ui/motion")

local Palette = {}

export type Colors = {
    Main: Color3,
    Panel: Color3,
    Off: Color3,
    Text: Color3,
    Sub: Color3,
    Disabled: Color3,
    AccentText: Color3,
    Accent: Color3,
    Light: number,
    Pick: number,
    Well: Color3,
}


local WHITE = Color3.new(1, 1, 1)
local SOFTEN_TEXT = 0.14
local SOFTEN_SUB = 0.08
local BLACK = Color3.new(0, 0, 0)

local function lightSet(state: { [string]: any }, main: Color3): { [string]: Color3 }
    local preset = state.ThemePreset or Theme.Default
    if state.ThemeName ~= "Custom" then
        if preset.Light then
            return preset.Light
        end
    end
    return {
        Main = Color.lerp(WHITE, main, 0.10),
        Panel = Color.lerp(WHITE, main, 0.19),
        Off = Color.lerp(WHITE, main, 0.31),
        Text = Color.lerp(BLACK, main, 0.55),
        Sub = Color.lerp(WHITE, main, 0.58),
    }
end

function Palette.glide(state: { [string]: any }, colorKeys: { [string]: boolean }, dt: number)
    local factor = 1 - math.exp(-4.5 * dt)
    for key in colorKeys do
        local target = state["Target_" .. key]
        if not target then
            state["Target_" .. key] = state[key]
        elseif state[key] ~= target then
            state[key] = Color.lerp(state[key], target, factor)
        end
    end
end

function Palette.compute(state: { [string]: any }, dt: number): Colors
    state.LightAlpha = Motion.ease(state, state.LightAlpha or (if state.LightMode then 1 else 0), if state.LightMode then 1 else 0, dt, 4.5)
    local light: number = state.LightAlpha

    local main: Color3 = state.MainCol
    local r, g, b = main.R, main.G, main.B
    local bright = 0.299 * r + 0.587 * g + 0.114 * b > 0.5
    local accent: Color3 = state.AccentCol
    local panel, off, text, sub, disabled

    if state.ThemeName == "Custom" then
        if bright then
            panel = Color3.new(math.clamp(r - 0.04, 0, 1), math.clamp(g - 0.04, 0, 1), math.clamp(b - 0.04, 0, 1))
            off = Color3.new(math.clamp(r - 0.10, 0, 1), math.clamp(g - 0.10, 0, 1), math.clamp(b - 0.10, 0, 1))
            text = Color.lerp(Color3.new(0.1, 0.1, 0.1), Color.lerp(accent, Color3.new(0, 0, 0), 0.65), 0.12)
            sub = Color.lerp(Color3.new(0.25, 0.25, 0.25), Color.lerp(accent, Color3.new(0, 0, 0), 0.5), 0.2)
        else
            panel = Color.lerp(main, Color3.new(1, 1, 1), 0.075)
            off = Color.lerp(main, Color3.new(1, 1, 1), 0.17)
            text = Color.lerp(Color3.new(0.93, 0.93, 0.93), Color.lighten(accent, 0.85), 0.12)
            sub = Color.lerp(Color3.new(0.66, 0.66, 0.66), Color.lighten(accent, 0.45), 0.2)
        end
        disabled = Color.lerp(sub, main, 0.5)
    else
        local base = state.ThemePreset or Theme.Default
        local function shifted(color: Color3): Color3
            return Color3.new(
                math.clamp(color.R + r - base.Main.R, 0, 1),
                math.clamp(color.G + g - base.Main.G, 0, 1),
                math.clamp(color.B + b - base.Main.B, 0, 1)
            )
        end
        panel, off = shifted(base.Panel), shifted(base.Off)
        text, sub = base.Text, base.Sub
        local away = math.abs(accent.R - base.Accent.R) + math.abs(accent.G - base.Accent.G) + math.abs(accent.B - base.Accent.B)
        local tint = math.clamp(away * 1.5, 0, 1) * 0.7
        if bright then
            if (base :: any).Pure ~= true then
                panel = Color3.new(math.clamp(r - 0.04, 0, 1), math.clamp(g - 0.04, 0, 1), math.clamp(b - 0.04, 0, 1))
                off = Color3.new(math.clamp(r - 0.10, 0, 1), math.clamp(g - 0.10, 0, 1), math.clamp(b - 0.10, 0, 1))
            end
            text, sub = Color3.new(0.1, 0.1, 0.1), Color3.new(0.25, 0.25, 0.25)
            text, sub = Color.lerp(text, Color.lerp(accent, Color3.new(0, 0, 0), 0.65), tint), Color.lerp(sub, Color.lerp(accent, Color3.new(0, 0, 0), 0.5), tint)
        else
            text, sub = Color.lerp(text, Color.lighten(accent, 0.85), tint), Color.lerp(sub, Color.lighten(accent, 0.45), tint)
        end
        disabled = base.Disabled or Theme.Disabled
    end

    local dark = math.max(light, if bright then 1 else 0)
    local accentText = Color.lerp(Color.lighten(accent, 0.55), Color.lerp(accent, Color3.new(0, 0, 0), 0.4), dark)
    local presetOf = state.ThemePreset or Theme.Default
    local pure = true
    local pick = 0
    if pure then
        pick = 1
        accentText = if bright then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
    end

    local set = lightSet(state, main)
    local target: Colors = {
        Main = Color.lerp(main, set.Main, light),
        Panel = Color.lerp(panel, set.Panel, light),
        Off = Color.lerp(off, set.Off, light),
        Text = Color.lerp(Color.lerp(text, main, if pure then 0 else SOFTEN_TEXT), set.Text, light),
        Sub = Color.lerp(Color.lerp(sub, main, if pure then 0 else SOFTEN_SUB), set.Sub, light),
        Disabled = Color.lerp(disabled, Color.lerp(set.Sub, set.Main, 0.5), light),
        AccentText = accentText,
        Accent = state.AccentCol,
        Light = light,
        Pick = pick,
        Well = Color.lerp(Color.lerp(panel, main, if pure then 1 else 0.35), set.Main, light),
    }

    local shown: Colors? = state.PaletteShown
    if not shown then
        state.PaletteShown = target
        return target
    end
    local factor = 1 - math.exp(-9 * math.clamp(dt, 0, 0.05))
    shown.Main = Color.lerp(shown.Main, target.Main, factor)
    shown.Panel = Color.lerp(shown.Panel, target.Panel, factor)
    shown.Off = Color.lerp(shown.Off, target.Off, factor)
    shown.Text = Color.lerp(shown.Text, target.Text, factor)
    shown.Sub = Color.lerp(shown.Sub, target.Sub, factor)
    shown.Disabled = Color.lerp(shown.Disabled, target.Disabled, factor)
    shown.AccentText = Color.lerp(shown.AccentText, target.AccentText, factor)
    shown.Accent = target.Accent
    shown.Light = light
    shown.Well = Color.lerp(shown.Well, target.Well, factor)
    shown.Pick = Color.lerp(Color3.new(shown.Pick, 0, 0), Color3.new(target.Pick, 0, 0), factor).R
    return shown
end

return Palette
end
modules["ui/panels"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")
local Hits: typeof(require("./hits")) = import("ui/hits")
local Kit: typeof(require("./popups/kit")) = import("ui/popups/kit")
local Motion: typeof(require("./motion")) = import("ui/motion")
local Painter: typeof(require("./painter")) = import("ui/painter")
local Press: typeof(require("./press")) = import("ui/press")
local Util: typeof(require("../core/util")) = import("core/util")

local Panels = {}

type App = { [string]: any }
type Panel = { [string]: any }

local Z_BODY, Z_BAR, Z_CONTENT, Z_TEXT = 12, 13, 14, 15
local TITLE_HEIGHT = 34
local PADDING = 10
local CONTENT_TOP = 40
local CONTENT_BOTTOM = 10
local GRIP = 20
local SHOW_THRESHOLD = 0.01

local function unitOf(app: App): number
    return math.max(0.2, app.Scale or 1)
end

local function viewport(app: App): Vector2
    return app.Viewport
end

function Panels.add(app: App, options: { [string]: any }): { [string]: any }
    local list: { Panel } = app.Panels
    if not list then
        list = {}
        app.Panels = list
    end
    local panel: Panel = {
        Id = tostring(options.Id or ("panel" .. (#list + 1))),
        Title = options.Title or "",
        Width = options.Width or 420,
        Height = options.Height or 300,
        MinWidth = options.MinWidth or 240,
        MinHeight = options.MinHeight or 160,
        Render = options.Render,
        Persistent = options.Persistent == true,
        Locked = options.Locked == true,
        Resizable = options.Resizable ~= false,
        LockAnim = if options.Locked == true then 1 else 0,
        Warm = options.Warm == true,
        Open = false,
        Anim = 0,
        Pos = nil,
    }
    table.insert(list, panel)
    local handle: { [string]: any } = {}
    function handle.open()
        panel.Open = true
    end
    function handle.close()
        panel.Open = false
    end
    function handle.setLocked(locked: boolean)
        panel.Locked = locked == true
    end
    function handle.toggle()
        panel.Open = not panel.Open
    end
    function handle.isOpen(): boolean
        return panel.Open
    end
    function handle.setSize(width: number, height: number)
        panel.Width, panel.Height = width, height
    end
    function handle.setPosition(position: Vector2)
        panel.Pos = position
    end
    return handle
end

function Panels.anyOpen(app: App): boolean
    local list: { Panel }? = app.Panels
    if not list then
        return false
    end
    for _, panel in list do
        if panel.Anim > SHOW_THRESHOLD then
            return true
        end
    end
    return false
end

function Panels.at(app: App, point: Vector2): (Vector2?, Vector2?)
    local list: { Panel }? = app.Panels
    if not list then
        return nil, nil
    end
    local unit = unitOf(app)
    for _, panel in list do
        local size = Vector2.new(panel.Width * unit, panel.Height * unit)
        if panel.Pos and panel.Anim > SHOW_THRESHOLD and Util.contains(point, panel.Pos, size) then
            return panel.Pos, size
        end
    end
    return nil, nil
end

function Panels.contains(app: App, point: Vector2): boolean
    local position = Panels.at(app, point)
    return position ~= nil
end

local function place(app: App, panel: Panel, unit: number)
    local screen = viewport(app)
    local width = panel.Width * unit
    local x = app.WindowPos.X + app.WindowSize.X + 12 * unit
    if x + width > screen.X - 10 then
        x = math.max(10, screen.X - width - 20)
    end
    panel.Pos = Vector2.new(x, math.max(10, app.WindowPos.Y))
end

local function clampPosition(app: App, panel: Panel, unit: number)
    local screen = viewport(app)
    local size = Vector2.new(panel.Width * unit, panel.Height * unit)
    local pos: Vector2 = panel.Pos
    panel.Pos = Vector2.new(math.clamp(pos.X, 60 - size.X, screen.X - 60), math.clamp(pos.Y, 0, screen.Y - 40))
end

local function drawPanel(app: App, panel: Panel)
    local pal = app.Pal
    local unit = unitOf(app)
    if not panel.Pos then
        place(app, panel, unit)
    end
    local alpha: number = math.clamp(panel.Anim, 0, 1)
    local full = Vector2.new(panel.Width * unit, panel.Height * unit)
    local pop = 0.9 + 0.1 * alpha
    local size = full * pop
    local pos: Vector2 = panel.Pos + (full - size) / 2
    local id: string = panel.Id
    local modal = app.Popup.Name ~= "None" or app.OpenDropdown ~= nil

    Painter.border(pos, size, 18 * Painter.corner(), pal.Accent, alpha * 0.30, Z_BODY, 1.2)
    Painter.rect(pos, size, pal.Main, alpha, Z_BODY, 18)
    local barHeight = TITLE_HEIGHT * unit
    Painter.rect(pos, Vector2.new(size.X, barHeight), Color.lerp(pal.Main, pal.Panel, 0.8), alpha, Z_BAR, 18)
    Painter.text(tostring(panel.Title), pos + Vector2.new(14 * unit, barHeight / 2), 15 * app.TextScale, pal.Text, alpha, Z_TEXT, false, true)

    local closeKey = "panel:" .. id .. ":close"
    local closeSize = Vector2.new(24 * unit, 24 * unit)
    local closePos = pos + Vector2.new(size.X - closeSize.X - (barHeight - closeSize.Y) / 2, (barHeight - closeSize.Y) / 2)
    panel.LockAnim = Motion.ease(app.State, panel.LockAnim, if panel.Locked then 1 else 0, app.Dt, 10)
    local dim = 1 - 0.65 * panel.LockAnim
    local hovered = app.HoverKey == closeKey and not modal and not panel.Locked
    local hover = Motion.ease(app.State, app.NavAnim[closeKey] or 0, if hovered then 1 else 0, app.Dt, Press.HOVER_SPEED)
    app.NavAnim[closeKey] = hover
    Painter.rect(closePos, closeSize, Color.lerp(pal.Panel, pal.Accent, 0.12 + 0.33 * hover), alpha * dim, Z_CONTENT, 12)
    local middle = closePos + closeSize / 2
    local reach = Vector2.new(4.5, 4.5) * unit
    local flip = Vector2.new(reach.X, -reach.Y)
    Painter.line(middle - reach, middle + reach, pal.Text, alpha * dim, Z_TEXT, 1.8 * unit)
    Painter.line(middle - flip, middle + flip, pal.Text, alpha * dim, Z_TEXT, 1.8 * unit)

    local grip = GRIP * unit
    local gripPos = pos + size - Vector2.new(grip, grip)
    local dotColor = Color.lerp(pal.Sub, pal.Accent, if app.HoverKey == "panel:" .. id .. ":resize" then 0.6 else 0)
    for row = 0, if panel.Resizable then 2 else -1 do
        for column = 0, 2 - row do
            local dot = Vector2.new(2.2 * unit, 2.2 * unit)
            local offset = Vector2.new(grip - (column + 1) * 5 * unit - 3 * unit, grip - (row + 1) * 5 * unit - 3 * unit)
            Painter.rect(gripPos + offset, dot, dotColor, alpha * 0.9, Z_CONTENT, 1, true)
        end
    end

    if modal then
        Hits.suspend(true)
    end
    Hits.add({ key = "panel:" .. id .. ":body", position = pos, size = size, shield = true })
    Hits.add({
        key = "panel:" .. id .. ":drag",
        position = pos,
        size = Vector2.new(size.X - closeSize.X - 12 * unit, barHeight),
        press = function(mouse: Vector2)
            panel.DragOffset = panel.Pos - mouse
        end,
        drag = function(mouse: Vector2)
            panel.Pos = mouse + panel.DragOffset
            clampPosition(app, panel, unit)
        end,
    })
    Hits.add({
        key = "panel:" .. id .. ":resize",
        position = gripPos,
        size = Vector2.new(grip, grip),
        drag = if not panel.Resizable then nil else function(mouse: Vector2)
            local screen = viewport(app)
            panel.Width = math.clamp((mouse.X - panel.Pos.X) / unit, panel.MinWidth, math.max(panel.MinWidth, (screen.X - panel.Pos.X) / unit))
            panel.Height = math.clamp((mouse.Y - panel.Pos.Y) / unit, panel.MinHeight, math.max(panel.MinHeight, (screen.Y - panel.Pos.Y) / unit))
        end,
    })
    Hits.add({
        key = closeKey,
        position = closePos,
        size = closeSize,
        click = if panel.Locked then nil else function()
            panel.Open = false
        end,
    })

    local contentWidth = panel.Width - PADDING * 2
    local contentHeight = panel.Height - CONTENT_TOP - CONTENT_BOTTOM
    if contentWidth > 20 and contentHeight > 20 and type(panel.Render) == "function" then
        local kit = Kit.new(app, contentWidth, contentHeight, pos + Vector2.new(PADDING * unit, CONTENT_TOP * unit) * pop, Vector2.new(contentWidth * unit, contentHeight * unit) * pop, alpha)
        kit.ZControl, kit.ZText = Z_CONTENT, Z_TEXT
        pcall(panel.Render, kit, app)
    end
    Hits.suspend(false)
end

function Panels.draw(app: App)
    local list: { Panel }? = app.Panels
    if not list then
        return
    end
    for index, panel in list do
        local shown = panel.Open and (panel.Persistent or app.State.Visible ~= false)
        if shown and panel.Warm and not panel.Warmed then
            panel.Warmed = true
            Painter.scope("panel:" .. index)
            drawPanel(app, panel)
            Painter.scope(nil)
            continue
        end
        panel.Anim = Motion.ease(app.State, panel.Anim, if shown then 1 else 0, app.Dt, 14)
        if panel.Anim > SHOW_THRESHOLD then
            Painter.scope("panel:" .. index)
            drawPanel(app, panel)
            Painter.scope(nil)
        end
    end
end

return Panels
end
modules["ui/picker"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")

local Picker = {}
Picker.__index = Picker

type App = { [string]: any }

export type Target = {
    Key: string,
    Get: () -> Color3,
    Set: (Color3) -> (),
    Default: Color3,
}

function Picker.new(app: App)
    return setmetatable({
        App = app,
        Target = nil :: Target?,
        Color = Color3.new(1, 1, 1),
        H = 0,
        S = 0,
        V = 1,
        Memory = {} :: { [string]: { [string]: any } },
    }, Picker)
end

type Self = typeof(Picker.new(nil :: any))

local function sameColor(first: Color3, second: Color3): boolean
    return math.abs(first.R - second.R) < 0.000001
        and math.abs(first.G - second.G) < 0.000001
        and math.abs(first.B - second.B) < 0.000001
end

function Picker.syncInputs(self: Self)
    local buffers = self.App.Buffers
    local color = self.Color
    local hex = string.gsub(Color.toHex(color), "#", "")
    buffers.Hex = string.upper(hex)
    buffers.Red = tostring(Color.channel(color.R))
    buffers.Green = tostring(Color.channel(color.G))
    buffers.Blue = tostring(Color.channel(color.B))
end

local function remember(self: Self)
    local target = self.Target
    if target then
        self.Memory[target.Key] = { Color = self.Color, H = self.H, S = self.S, V = self.V }
    end
end

function Picker.commit(self: Self)
    local target = self.Target
    if not target then
        return
    end
    target.Set(self.Color)
    remember(self)
end

function Picker.setColor(self: Self, color: Color3)
    self.Color = color
    self.H, self.S, self.V = color:ToHSV()
    self:syncInputs()
    self:commit()
end

function Picker.setHSV(self: Self, h: number?, s: number?, v: number?)
    self.H = h or self.H
    self.S = s or self.S
    self.V = v or self.V
    self.Color = Color.fromHSV(self.H, self.S, self.V)
    self:syncInputs()
    self:commit()
end

function Picker.open(self: Self, target: Target)
    self.Target = target
    local source = target.Get()
    self.Color = source
    local memory = self.Memory[target.Key]
    if memory and sameColor(memory.Color, source) then
        self.H, self.S, self.V = memory.H, memory.S, memory.V
    else
        self.H, self.S, self.V = source:ToHSV()
        remember(self)
    end
    self:syncInputs()
end

function Picker.reset(self: Self)
    local target = self.Target
    if target then
        self:setColor(target.Default)
    end
end

function Picker.applyField(self: Self, field: string)
    local buffers = self.App.Buffers
    if field == "Hex" then
        local color = Color.fromHex(buffers.Hex)
        if color then
            self:setColor(color)
        else
            self:syncInputs()
        end
        return
    end
    local value = tonumber(buffers[field])
    if not value then
        self:syncInputs()
        return
    end
    value = math.clamp(math.floor(value + 0.5), 0, 255)
    local r, g, b = Color.channel(self.Color.R), Color.channel(self.Color.G), Color.channel(self.Color.B)
    if field == "Red" then
        r = value
    elseif field == "Green" then
        g = value
    elseif field == "Blue" then
        b = value
    end
    self:setColor(Color3.fromRGB(r, g, b))
end

return Picker
end
modules["ui/popups/builtin"] = function(...)

local import: (string) -> any = ...
local ColorPopup: typeof(require("./color")) = import("ui/popups/color")
local Color: typeof(require("../../core/color")) = import("core/color")

local Discord: typeof(require("../discord")) = import("ui/discord")
local Fonts: typeof(require("../fonts")) = import("ui/fonts")
local Hits: typeof(require("../hits")) = import("ui/hits")
local Kit: typeof(require("./kit")) = import("ui/popups/kit")
local Logo: typeof(require("../logo")) = import("ui/logo")
local Motion: typeof(require("../motion")) = import("ui/motion")
local Painter: typeof(require("../painter")) = import("ui/painter")
local Theme: typeof(require("../../core/theme")) = import("core/theme")

type App = { [string]: any }

local Builtin = {}

local NOTICE_MIN_WIDTH = 220

local FONTS_PER_PAGE = 16
local FONT_PAGES = math.ceil(Fonts.COUNT / FONTS_PER_PAGE)

local function themeList(app: App): { any }
    local list: { any } = {}
    local known = false
    for _, name in Theme.PresetOrder do
        local preset = Theme.Presets[name]
        known = known or preset.Name == app.Preset.Name
        table.insert(list, preset)
    end
    if not known then
        table.insert(list, 1, app.Preset)
    end
    return list
end

local function closer(app: App): () -> ()
    return function()
        app:closePopup()
    end
end

local EDGE, GAP, SECTION, BUTTON, TOP = Kit.EDGE, Kit.GAP, Kit.SECTION, Kit.BUTTON, Kit.TOP
local LINE = 18
local TEXT_SIZE = 13
local TITLE_SIZE = 15

local function widest(app: App, lines: { string }, size: number): number
    local width = 0
    for _, line in lines do
        width = math.max(width, Painter.textWidth(line, size * app.TextScale) / app.Unit)
    end
    return width
end

local function fitWidth(app: App, title: string, lines: { string }, minimum: number): number
    local head = widest(app, { title }, TITLE_SIZE) + EDGE + GAP + Kit.CLOSE + EDGE
    return math.ceil(math.max(minimum, head, widest(app, lines, TEXT_SIZE) + EDGE * 2))
end

local function fitHeight(lines: number, buttons: boolean): number
    return TOP + lines * LINE + (if buttons then SECTION + BUTTON else 0) + EDGE
end

local function bodyLines(kit: any, lines: { string })
    kit:lines(lines, TOP + LINE / 2, LINE, TEXT_SIZE)
end

local function confirmRow(app: App, kit: any, onConfirm: () -> (), yes: string?, no: string?)
    local width = (kit.Width - EDGE * 2 - GAP) / 2
    local y = kit.Height - EDGE - BUTTON
    kit:button("confirm:yes", EDGE, y, width, BUTTON, onConfirm, { label = yes or "Confirm" })
    kit:button("confirm:no", EDGE + width + GAP, y, width, BUTTON, closer(app), { label = no or "Cancel" })
end

local FONT_CELL = 24
local FONT_GAP = 4
local FONT_ROWS = FONTS_PER_PAGE // 2

Builtin.fonts = {
    size = function()
        return 320, TOP + FONT_ROWS * (FONT_CELL + FONT_GAP) - FONT_GAP + SECTION + BUTTON + EDGE
    end,
    title = function()
        return "Select Font"
    end,
    render = function(app: App, kit: any)
        local state = app.State
        local page: number = state.PopFontPage
        local cell = (kit.Width - EDGE * 2 - FONT_GAP) / 2
        for slot = 1, FONTS_PER_PAGE do
            local font = (page - 1) * FONTS_PER_PAGE + slot - 1
            if font >= Fonts.COUNT then
                break
            end
            local column = (slot - 1) % 2
            local row = (slot - 1) // 2
            kit:button("font:" .. slot, EDGE + column * (cell + FONT_GAP), TOP + row * (FONT_CELL + FONT_GAP), cell, FONT_CELL, function()
                state.UIFont = tostring(font)
            end, {
                label = Fonts.NAMES[font],
                font = font,
                active = tostring(font) == state.UIFont,
                hoverMix = 1,
            })
        end
        kit:pager("fonts:page", EDGE, kit.Height - EDGE - BUTTON, kit.Width - EDGE * 2, page, FONT_PAGES, function(target)
            state.PopFontPage = target
        end)
    end,
}

local function deleteLines(app: App): { string }
    return { "Are you sure you want to delete", "'" .. tostring(app.State.SelectedConfig) .. "'?" }
end

Builtin.deleteConfig = {
    closable = false,
    size = function(app: App)
        return fitWidth(app, "Confirm", deleteLines(app), 280), fitHeight(2, true)
    end,
    title = function()
        return "Confirm"
    end,
    render = function(app: App, kit: any)
        bodyLines(kit, deleteLines(app))
        confirmRow(app, kit, function()
            app:deleteConfig(app.State.SelectedConfig)
            app:closePopup()
        end)
    end,
}

local function sureAbout(question: string, action: (app: App) -> ())
    return {
        closable = false,
        size = function(app: App)
            return fitWidth(app, "Confirm", { question }, 280), fitHeight(1, true)
        end,
        title = function()
            return "Confirm"
        end,
        render = function(app: App, kit: any)
            bodyLines(kit, { question })
            confirmRow(app, kit, function()
                app:closePopup()
                action(app)
            end, "Yes", "No")
        end,
    }
end

Builtin.confirmReload = sureAbout("Are you sure you want to reload?", function(app: App)
    app:reload()
end)

Builtin.confirmUnload = sureAbout("Are you sure you want to unload?", function(app: App)
    app:unload()
end)

local PERFORMANCE_LINES = {
    "If you continue, the menu switches to a low end",
    "mode which has no animations and some",
    "customization features removed to improve",
    "performance, this is only recommended if you have",
    "a low end device or low performance.",
}

Builtin.performance = {
    closable = false,
    size = function(app: App)
        return fitWidth(app, "Warning", PERFORMANCE_LINES, 340), fitHeight(#PERFORMANCE_LINES, true)
    end,
    title = function()
        return "Warning"
    end,
    render = function(app: App, kit: any)
        bodyLines(kit, PERFORMANCE_LINES)
        confirmRow(app, kit, function()
            app.State.HighPerformanceMode = true
            app.State.BackgroundEffect = "None"
            app:closePopup()
        end)
    end,
}

Builtin.info = {
    size = function(app: App, arg: { [string]: any })
        local lines: { string } = arg.Lines
        return fitWidth(app, tostring(arg.Title or ""), lines, arg.Width or 260), fitHeight(#lines, false)
    end,
    title = function(_app: App, arg: { [string]: any })
        return arg.Title
    end,
    render = function(_app: App, kit: any, arg: { [string]: any })
        bodyLines(kit, arg.Lines)
    end,
}

local DISCORD_LINES = { "Opened Discord and copied", "invite link to clipboard!" }

Builtin.discord = {
    size = function(app: App)
        return fitWidth(app, "Discord", DISCORD_LINES, 260), fitHeight(#DISCORD_LINES, false)
    end,
    title = function()
        return "Discord"
    end,
    render = function(_app: App, kit: any)
        bodyLines(kit, DISCORD_LINES)
    end,
}

local THEME_ROWS = 4
local THEME_COLUMNS = 2
local THEME_WIDTH = 460
local THEME_CARD = 62
local THEME_GAP = GAP

local function themeEntries(app: App): { { [string]: any } }
    local state = app.State
    local white = Color3.new(1, 1, 1)
    local entries: { { [string]: any } } = {}
    local seen: { [string]: boolean } = {}
    for _, preset in themeList(app) do
        if not seen[preset.Name] and preset.Name ~= "Custom" then
            seen[preset.Name] = true
            local animated = type(preset.Cycle) == "table" and #preset.Cycle >= 2
            table.insert(entries, { Name = preset.Name, Main = preset.Main, Panel = preset.Panel, Accent = preset.Accent, Sky = preset.Sky, Tag = if animated then "Animated" else "Still", Live = animated })
        end
    end
    table.insert(entries, {
        Name = "Custom",
        Main = state.CustomMainCol,
        Panel = Color.lerp(state.CustomMainCol, white, 0.075),
        Accent = state.CustomAccentCol,
        Sky = nil,
        Tag = "Yours",
        Live = false,
    })
    return entries
end

local function themeRows(app: App): number
    return math.ceil(#themeEntries(app) / THEME_COLUMNS)
end

local function themeCard(app: App, kit: any, entry: { [string]: any }, x: number, y: number, width: number)
    local pal = app.Pal
    local name: string = entry.Name
    local key = "themes:" .. name
    local selected = app.State.ThemeName == name
    local hover = kit:ease(key .. ":hover", if kit:hovered(key) then 1 else 0, 16)
    local lit = kit:ease(key .. ":active", if selected then 1 else 0, 14)
    local height = THEME_CARD
    local body = Color.lerp(Color.lerp(pal.Main, pal.Panel, 0.30), pal.Accent, 0.13 * hover)
    kit:rect(x, y, width, height, body, 1, 14)
    kit:border(x + 1.5, y + 1.5, width - 3, height - 3, 12.5, pal.Accent, lit, 1.5)

    local preview = height - 18
    local px, py = x + 9, y + 9
    local accent: Color3 = entry.Accent
    local sky: Color3? = entry.Sky
    kit:rect(px, py, preview, preview, if sky then Color.lerp(entry.Main, sky, 0.7) else entry.Main, 1, 10)
    kit:rect(px + 5, py + preview * 0.42, preview - 10, preview * 0.58 - 5, entry.Panel, 1, 6)
    kit:rect(px + 5, py + 6, math.floor(preview * 0.42), 5, accent, 1, 2.5)

    local textX = px + preview + 12
    kit:text(name, textX, y + 22, 14, pal.Text, false, true)
    local tag: string = entry.Tag
    local live: boolean = entry.Live
    local chipWidth = kit:measure(tag, 11) + 18
    local chipColor = if live then Color.lerp(body, accent, 0.42) else Color.lerp(body, pal.Off, 0.9)
    kit:rect(textX, y + 35, chipWidth, 19, chipColor, 1, 9)
    kit:text(tag, textX + chipWidth / 2, y + 44.5, 11, if live then Color.lighten(accent, 0.7) else pal.Text, true, true)
    if lit > 0.01 then
        local label = "Selected"
        local labelWidth = kit:measure(label, 9) + 8
        kit:rect(x + width - labelWidth - 10, y + 38, labelWidth, 13, pal.Accent, lit, 6.5)
        kit:text(label, x + width - labelWidth / 2 - 10, y + 44.5, 9, Color.lerp(body, pal.AccentText, lit), true, true)
    end
    kit:hit(key, x, y, width, height, function()
        app:applyTheme(name)
    end)
end

Builtin.themes = {
    size = function(app: App)
        return THEME_WIDTH, TOP + math.min(themeRows(app), THEME_ROWS) * (THEME_CARD + THEME_GAP) - THEME_GAP + EDGE
    end,
    title = function()
        return ""
    end,
    render = function(app: App, kit: any)
        local top = kit:header("Themes", "Colors of the whole menu", closer(app))
        local entries = themeEntries(app)
        local rows = math.ceil(#entries / THEME_COLUMNS)
        kit:scroll("themes:list", EDGE, top, kit.Width - EDGE * 2, kit.Height - top - EDGE + THEME_GAP, THEME_CARD + THEME_GAP, rows, function(index: number, x: number, y: number, width: number)
            local cardWidth = (width - THEME_GAP * (THEME_COLUMNS - 1)) / THEME_COLUMNS
            for column = 1, THEME_COLUMNS do
                local entry = entries[(index - 1) * THEME_COLUMNS + column]
                if entry then
                    themeCard(app, kit, entry, x + (column - 1) * (cardWidth + THEME_GAP), y, cardWidth)
                end
            end
        end, 4, true)
    end,
}

local LOG_ITEM = 12
local LOG_STEP = 24
local LOG_MARK = 18
local LOG_INSET = 10
local LOG_ROWS = 9
local LOG_WIDTH = 340
local LOG_KIND = 58
local LOG_SPEED = 7
local LOG_WHEEL = 44
local LOG_SCROLL_SPEED = 10

local logOpen: string? = nil
local logSeen = false
local logLast = 0
local logGrow: { [string]: number } = {}
local logHover: { [string]: number } = {}
local logWrapped: { [string]: { string } } = {}
local logScroll = { Target = 0, Pos = 0, Max = 0 }

local function logKey(group: any, index: number): string
    return group .. ":" .. index
end

local function logWrap(app: App, text: string, limit: number): { string }
    local key = limit .. "|" .. text
    local cached = logWrapped[key]
    if cached then
        return cached
    end
    local rows: { string } = {}
    local current = ""
    for word in string.gmatch(text, "%S+") do
        local candidate = if current == "" then word else current .. " " .. word
        if current ~= "" and Painter.textWidth(candidate, LOG_ITEM * app.TextScale) / app.Unit > limit then
            table.insert(rows, current)
            current = word
        else
            current = candidate
        end
    end
    table.insert(rows, current)
    logWrapped[key] = rows
    return rows
end

local function logStep(app: App, notice: { [string]: any })
    local now = os.clock()
    if not logSeen or now - logLast > 0.5 then
        logSeen = true
        local first = if notice.Groups then notice.Groups[1] else nil
        logOpen = notice.Open or (if first then tostring(first.Name) else nil)
        table.clear(logGrow)
        if logOpen then
            logGrow[logOpen] = 1
        end
    end
    logLast = now
    for _, group in notice.Groups or {} do
        local name = tostring(group.Name)
        local goal = if logOpen == name then 1 else 0
        local grow = Motion.ease(app.State, logGrow[name] or 0, goal, app.Dt, LOG_SPEED)
        logGrow[name] = if goal == 0 and grow < 0.004 then 0 else grow
    end
end

local function logRows(app: App, notice: { [string]: any }): ({ { [string]: any } }, number)
    local rows: { { [string]: any } } = {}
    local at = 0
    local limit = LOG_WIDTH - EDGE * 2 - LOG_INSET * 2 - LOG_MARK - LOG_KIND
    local groups: { any }? = notice.Groups
    if groups then
        for _, group in groups do
            local name = tostring(group.Name)
            local grow = logGrow[name] or 0
            table.insert(rows, { Head = true, Text = name, Name = name, Count = #(group.Items or {}), Offset = at, Key = "head:" .. name })
            at += LOG_STEP
            if grow > 0.002 then
                local lines: { { [string]: any } } = {}
                for _, item in group.Items or {} do
                    local kind, body = string.match(item, "^(%a+): (.*)$")
                    for index, line in logWrap(app, body or item, limit) do
                        table.insert(lines, { Text = line, Kind = if index == 1 then kind else nil, Group = name })
                    end
                end
                local reach = at + #lines * LOG_STEP * grow
                for index, line in lines do
                    line.Offset = at + (index - 1) * LOG_STEP
                    line.Limit = reach
                    line.Key = logKey(line.Group, index)
                    table.insert(rows, line)
                end
                at = reach
            end
        end
    else
        for _, item in notice.Items or {} do
            table.insert(rows, { Text = item, Mark = true, Offset = at, Key = "item:" .. #rows })
            at += LOG_STEP
        end
    end
    return rows, at
end

local function logTitleX(app: App): number
    return if app.LogoAsset then EDGE + Kit.ROW + GAP else EDGE
end

local SHEET_WIDTH = 340
local SHEET_LOGO = 40
local SHEET_LINE = 16
local SHEET_PAD = 8
local SHEET_HEAD_ROW = 28
local SHEET_GAP = 6
local SHEET_VIEW = 236
local SHEET_INDENT = 6
local SHEET_TEXT = 32
local SHEET_GLYPH = { Added = "+", Changed = "~", Removed = "-", Fixed = "•" }
local sheetClosed: { [string]: boolean } = {}
local sheetGrow: { [string]: number } = {}
local sheetHover: { [string]: number } = {}
local sheetSeen = false
local sheetLast = 0

local function sheetHead(app: App): number
    return if app.LogoAsset then 76 else 58
end

local function sheetStep(app: App, notice: { [string]: any })
    local now = os.clock()
    local groups: { any } = notice.Groups
    if not sheetSeen or now - sheetLast > 0.5 then
        sheetSeen = true
        table.clear(sheetClosed)
        table.clear(sheetGrow)
        for index, group in groups do
            local name = tostring(group.Name)
            sheetClosed[name] = index > 1
            sheetGrow[name] = if index > 1 then 0 else 1
        end
    end
    sheetLast = now
    for _, group in groups do
        local name = tostring(group.Name)
        local grow = Motion.ease(app.State, sheetGrow[name] or 0, if sheetClosed[name] then 0 else 1, app.Dt, LOG_SPEED)
        sheetGrow[name] = if sheetClosed[name] and grow < 0.004 then 0 else grow
    end
end

local function sheetRows(app: App, notice: { [string]: any }): ({ { [string]: any } }, number, number)
    local rows: { { [string]: any } } = {}
    local at, count = 0, 0
    local limit = SHEET_WIDTH - EDGE * 2 - SHEET_TEXT - SHEET_INDENT
    local groups: { any } = notice.Groups
    local folded = #groups > 1
    for _, group in groups do
        local name = tostring(group.Name)
        local grow = if folded then sheetGrow[name] or 0 else 1
        local items = group.Items or {}
        if folded then
            table.insert(rows, { Head = true, Name = name, Count = #items, Offset = at, Height = SHEET_HEAD_ROW, Key = "h:" .. name })
            at += SHEET_HEAD_ROW + 4
        end
        local lines: { { [string]: any } } = {}
        local used = 0
        for _, item in items do
            local kind, body = string.match(item, "^(%a+): (.*)$")
            count += 1
            local wrapped = logWrap(app, body or item, limit)
            for index, line in wrapped do
                table.insert(lines, { Text = line, Kind = if index == 1 then kind or "Added" else nil, Offset = used + (index - 1) * SHEET_LINE, Height = SHEET_LINE, Pad = SHEET_PAD, Group = name })
            end
            used += #wrapped * SHEET_LINE + SHEET_PAD
        end
        if grow > 0.002 or not folded then
            local reach = at + used * grow
            for index, line in lines do
                line.Offset += at
                line.Limit = reach
                line.Grow = grow
                line.Key = "i:" .. name .. ":" .. index
                table.insert(rows, line)
            end
            at = reach + (if folded then SHEET_GAP * grow else 0)
        end
    end
    return rows, at, count
end

local function sheetSize(app: App, notice: { [string]: any }): (number, number)
    sheetStep(app, notice)
    local _, content = sheetRows(app, notice)
    local visible = math.min(content, SHEET_VIEW)
    local height = sheetHead(app) + visible + EDGE
    if notice.Footer then
        height += SECTION + BUTTON
    end
    return SHEET_WIDTH, math.ceil(height)
end

local function sheetRender(app: App, kit: any, notice: { [string]: any })
    local pal = app.Pal
    local rows, content, count = sheetRows(app, notice)
    local logo: string? = app.LogoAsset
    local left = EDGE
    if logo then
        local factor = kit.ScreenSize.X / kit.Width
        local emblem = app.Options.Logo ~= nil and app.Options.Logo.Emblem == true
        Painter.image(logo, kit:p(EDGE, 18), Vector2.new(SHEET_LOGO * factor, SHEET_LOGO * factor), kit.Alpha, kit.ZText, if emblem then 0 else 10 * factor, if emblem then pal.Accent else nil)
        left = EDGE + SHEET_LOGO + 12
    end
    local room = kit.Width - left - Kit.CLOSE - EDGE * 2
    local title = tostring(notice.Title)
    local titleSize = 17
    while titleSize > 10 and kit:measure(title, titleSize) > room do
        titleSize -= 1
    end
    local top = if logo then 18 else 14
    local tall = if logo then SHEET_LOGO else 30
    kit:text(title, left, top + tall / 2 - 8, titleSize, pal.Text, false, true)
    kit:text(count .. (if count == 1 then " change" else " changes"), left, top + tall / 2 + 10, 11, pal.Sub, false, true)

    local first = sheetHead(app)
    local visible = math.min(content, SHEET_VIEW)
    local scroll = logScroll
    scroll.Max = math.max(0, content - visible)
    scroll.Target = math.clamp(scroll.Target, 0, scroll.Max)
    scroll.Pos = math.clamp(Motion.ease(app.State, scroll.Pos, scroll.Target, app.Dt, LOG_SCROLL_SPEED), 0, scroll.Max)
    if scroll.Max > 0 then
        Hits.add({
            key = "notice:scroll",
            position = kit:p(EDGE, first),
            size = kit:s(kit.Width - EDGE * 2, visible),
            wheel = function(delta: number)
                scroll.Target = math.clamp(scroll.Target - delta * LOG_WHEEL, 0, scroll.Max)
            end,
        })
    end
    local base = kit.Alpha
    local outer = Painter.active()
    local span = kit.Width - EDGE * 2
    for _, row in rows do
        local y = first + row.Offset - scroll.Pos
        local height = row.Height
        local edge = math.max(first - y, y + height - (first + visible), 0)
        local fade = math.clamp(1 - edge / height, 0, 1)
        if row.Limit then
            fade *= math.clamp((row.Limit - row.Offset) / height, 0, 1) * math.clamp(row.Grow * 4, 0, 1)
        end
        if fade > 0.01 then
            kit.Alpha = base * fade
            local wasSuspended = Hits.isSuspended()
            if fade < 0.7 then
                Hits.suspend(true)
            end
            Painter.scope("sheet:" .. row.Key)
            local center = y + height / 2
            if row.Head then
                local name = row.Name
                local key = "notice:group:" .. name
                local grow = sheetGrow[name] or 0
                local hover = Motion.ease(app.State, sheetHover[name] or 0, if kit:hovered(key) then 1 else 0, app.Dt, 14)
                sheetHover[name] = hover
                kit:rect(EDGE, y, span, height, Color.lerp(pal.Panel, pal.Off, 0.25 + 0.5 * hover), 1, 12)
                kit:hit(key, EDGE, y, span, height, function()
                    sheetClosed[name] = not sheetClosed[name]
                end)
                local angle = math.rad(90 * grow)
                local tipX = EDGE + 16 + math.cos(angle) * 2.2
                local tipY = center + math.sin(angle) * 2.2
                local color = Color.lerp(pal.Sub, pal.Text, 0.4 + 0.6 * grow)
                for _, side in { -1, 1 } do
                    local wing = angle + math.rad(180 + 45 * side)
                    kit:line(tipX, tipY, tipX + math.cos(wing) * 5.4, tipY + math.sin(wing) * 5.4, color, 1.6, 1)
                end
                kit:text(name, EDGE + 30, center, 13, Color.lerp(pal.Sub, pal.Text, 0.75 + 0.25 * grow), false, true)
                local badge = tostring(row.Count)
                local badgeWidth = math.max(18, kit:measure(badge, 10) + 12)
                local badgeX = EDGE + span - 10 - badgeWidth
                kit:rect(badgeX, center - 7, badgeWidth, 14, pal.Main, 0.7, 7)
                kit:text(badge, badgeX + badgeWidth / 2, center, 10, pal.Sub, true, true)
            else
                if row.Kind then
                    kit:rect(EDGE + SHEET_INDENT, center - 9 + row.Pad / 2 - 4, 18, 18, pal.Panel, 1, 6)
                    kit:text(SHEET_GLYPH[row.Kind] or "+", EDGE + SHEET_INDENT + 9, center + row.Pad / 2 - 4, 12, Color.lerp(pal.Sub, pal.Text, 0.7), true, true)
                end
                kit:text(row.Text, EDGE + SHEET_TEXT, center + row.Pad / 2 - 4, LOG_ITEM, Color.lerp(pal.Sub, pal.Text, 0.75), false, true)
            end
            Painter.scope(outer)
            Hits.suspend(wasSuspended)
        end
    end
    kit.Alpha = base
    kit:closeX(function()
        app:acknowledgeUpdate()
        app:closePopup()
    end)
    local footer = notice.Footer
    local invite = app.Options.Discord
    if not footer then
        return
    end
    local barY = kit.Height - EDGE - BUTTON
    local barWidth = kit.Width - EDGE * 2
    if invite then
        kit:button("notice:join", EDGE, barY, barWidth, BUTTON, function()
            Discord.join(invite)
            app:acknowledgeUpdate()
            app:openPopup("discord")
        end, { hoverColor = pal.Off, base = pal.Panel, rounding = 12 })
        local label = tostring(footer)
        local iconSide, gap = 14, 6
        local group = iconSide + gap + kit:measure(label, TEXT_SIZE)
        local startX = EDGE + barWidth / 2 - group / 2
        local origin = kit:p(startX, barY + (BUTTON - iconSide) / 2)
        local pixels = math.floor(kit:s(iconSide, iconSide).X + 0.5)
        local icon = Logo.icon(app, "discord", pixels)
        if icon then
            Painter.image(icon, Vector2.new(math.floor(origin.X + 0.5), math.floor(origin.Y + 0.5)), Vector2.new(pixels, pixels), kit.Alpha, kit.ZText, 0, pal.Text)
        end
        kit:text(label, startX + iconSide + gap, barY + BUTTON / 2, TEXT_SIZE, pal.Text, false, true)
    else
        kit:text(tostring(footer), kit.Width / 2, barY + BUTTON / 2, 12, pal.Sub, true, true)
    end
end

local function logSize(app: App, notice: { [string]: any }): (number, number)
    if notice.Groups then
        return sheetSize(app, notice)
    end
    logStep(app, notice)
    local _, content = logRows(app, notice)
    local visible = math.min(content, LOG_ROWS * LOG_STEP)
    local head = logTitleX(app) + widest(app, { tostring(notice.Title) }, TITLE_SIZE) + GAP + Kit.CLOSE + EDGE
    local width = math.max(LOG_WIDTH, head)
    if not notice.Groups then
        local items = widest(app, notice.Items or {}, LOG_ITEM)
        width = math.max(NOTICE_MIN_WIDTH, head, items + LOG_MARK + LOG_INSET * 2 + EDGE * 2)
    end
    width = math.ceil(width)
    if not notice.Footer then
        return width, TOP + visible + EDGE
    end
    return width, TOP + visible + SECTION + BUTTON + EDGE
end

local function logRender(app: App, kit: any, notice: { [string]: any })
    if notice.Groups then
        sheetRender(app, kit, notice)
        return
    end
    local pal = app.Pal
    kit:title(tostring(notice.Title), logTitleX(app))
    local logo: string? = app.LogoAsset
    if logo then
        local factor = kit.ScreenSize.X / kit.Width
        local emblem = app.Options.Logo ~= nil and app.Options.Logo.Emblem == true
        Painter.image(logo, kit:p(EDGE, EDGE), Vector2.new(Kit.ROW * factor, Kit.ROW * factor), kit.Alpha, kit.ZText, if emblem then 0 else 6 * factor, if emblem then pal.Accent else nil)
    end
    local rows, content = logRows(app, notice)
    local first = TOP
    local visible = math.min(content, LOG_ROWS * LOG_STEP)
    local left, span = EDGE, kit.Width - EDGE * 2

    local scroll = logScroll
    scroll.Max = math.max(0, content - visible)
    scroll.Target = math.clamp(scroll.Target, 0, scroll.Max)
    scroll.Pos = math.clamp(Motion.ease(app.State, scroll.Pos, scroll.Target, app.Dt, LOG_SCROLL_SPEED), 0, scroll.Max)
    if scroll.Max > 0 then
        Hits.add({
            key = "notice:scroll",
            position = kit:p(left, first),
            size = kit:s(span, visible),
            wheel = function(delta: number)
                scroll.Target = math.clamp(scroll.Target - delta * LOG_WHEEL, 0, scroll.Max)
            end,
        })
    end

    local base = kit.Alpha
    local outer = Painter.active()
    for _, row in rows do
        local top = first + row.Offset - scroll.Pos
        local edge = math.max(first - top, top + LOG_STEP - (first + visible), 0)
        local fade = math.clamp((1 - edge / LOG_STEP) * 1.6 - 0.3, 0, 1)
        if row.Limit then
            fade *= math.clamp((row.Limit - row.Offset) / LOG_STEP, 0, 1) * math.clamp((logGrow[row.Group] or 0) * 4, 0, 1)
        end
        if fade > 0.01 then
            kit.Alpha = base * fade
            local wasSuspended = Hits.isSuspended()
            if fade < 0.7 then
                Hits.suspend(true)
            end
            Painter.scope("notice:" .. row.Key)
            local center = top + LOG_STEP / 2
            local x = left
            if row.Head then
                local name = row.Name
                local key = "notice:group:" .. name
                local grow = logGrow[name] or 0
                local hover = Motion.ease(app.State, logHover[name] or 0, if kit:hovered(key) then 1 else 0, app.Dt, 14)
                logHover[name] = hover
                kit:rect(x, top + 1, span, LOG_STEP - 2, Color.lerp(pal.Panel, pal.Off, 0.25 + 0.5 * hover), 1, 12)
                kit:hit(key, x, top, span, LOG_STEP, function()
                    logOpen = if logOpen == name then nil else name
                end)
                local angle = math.rad(90 * grow)
                local tipX = x + LOG_INSET + 3 + math.cos(angle) * 2.2
                local tipY = center + math.sin(angle) * 2.2
                local chevron = Color.lerp(pal.Sub, pal.Text, 0.4 + 0.6 * grow)
                for _, side in { -1, 1 } do
                    local wing = angle + math.rad(180 + 45 * side)
                    kit:line(tipX, tipY, tipX + math.cos(wing) * 5.4, tipY + math.sin(wing) * 5.4, chevron, 1.6, 1)
                end
                kit:text(row.Text, x + LOG_INSET + LOG_MARK - 2, center, LOG_ITEM + 1, Color.lerp(pal.Sub, pal.Text, 0.75 + 0.25 * grow), false, true)
                local badge = tostring(row.Count)
                local badgeWidth = math.max(16, kit:measure(badge, 10) + 10)
                local badgeX = x + span - LOG_INSET + 2 - badgeWidth
                kit:rect(badgeX, center - 7, badgeWidth, 14, pal.Main, 0.7, 7)
                kit:text(badge, badgeX + badgeWidth / 2, center, 10, pal.Sub, true, true)
            else
                local grow = if row.Group then logGrow[row.Group] or 0 else 1
                local slide = (1 - grow) * 14
                if row.Mark then
                    kit:text("+", x + LOG_INSET, center, LOG_ITEM, pal.Sub, false, true)
                end
                if row.Kind then
                    local chip = math.min(LOG_KIND - 8, kit:measure(row.Kind, 10) + 10)
                    local chipX = x + LOG_INSET + LOG_MARK + slide
                    kit:rect(chipX, center - 7, chip, 14, pal.Panel, 1, 7)
                    kit:text(row.Kind, chipX + chip / 2, center, 10, Color.lerp(pal.Sub, pal.Text, 0.5), true, true)
                end
                if row.Group then
                    kit:rect(x + LOG_INSET + 3, top - 2, 1, LOG_STEP + 4, pal.Off, 0.9 * grow, 0)
                end
                local column = if row.Group then LOG_KIND else 0
                kit:text(row.Text, x + LOG_INSET + LOG_MARK + column + slide, center, LOG_ITEM, Color.lerp(pal.Sub, pal.Text, 0.4), false, true)
            end
            Painter.scope(outer)
            Hits.suspend(wasSuspended)
        end
    end
    kit.Alpha = base
    kit:closeX(function()
        app:acknowledgeUpdate()
        app:closePopup()
    end)
    if not notice.Footer then
        return
    end
    local barY = kit.Height - EDGE - BUTTON
    local barWidth = kit.Width - EDGE * 2
    local invite = app.Options.Discord
    local footer = notice.Footer
    if invite and footer then
        kit:button("notice:join", EDGE, barY, barWidth, BUTTON, function()
            Discord.join(invite)
            app:acknowledgeUpdate()
            app:openPopup("discord")
        end, { hoverColor = pal.Off, base = pal.Panel, rounding = 12 })
        local label = tostring(footer)
        local iconSide = 14
        local gap = 6
        local group = iconSide + gap + kit:measure(label, TEXT_SIZE)
        local startX = EDGE + barWidth / 2 - group / 2
        local origin = kit:p(startX, barY + (BUTTON - iconSide) / 2)
        local pixels = math.floor(kit:s(iconSide, iconSide).X + 0.5)
        local icon = Logo.icon(app, "discord", pixels)
        if icon then
            Painter.image(icon, Vector2.new(math.floor(origin.X + 0.5), math.floor(origin.Y + 0.5)), Vector2.new(pixels, pixels), kit.Alpha, kit.ZText, 0, pal.Text)
        end
        kit:text(label, startX + iconSide + gap, barY + BUTTON / 2, TEXT_SIZE, pal.Text, false, true)
    elseif footer then
        kit:text(tostring(footer), EDGE, barY + BUTTON / 2, 12, pal.Sub, false, true)
    end
end

Builtin.updateNotice = {
    size = function(app: App)
        local notice: any = app.Options.UpdateNotice
        if type(notice) == "table" and notice.Title ~= nil then
            return logSize(app, notice)
        end
        local lines: { string } = app.Options.UpdateNotice
        local rest = { table.unpack(lines, 2) }
        local height = if #rest > 0 then fitHeight(#rest, false) else Kit.HEAD + EDGE
        return fitWidth(app, tostring(lines[1] or ""), rest, NOTICE_MIN_WIDTH), height
    end,
    title = function()
        return ""
    end,
    locked = true,
    render = function(app: App, kit: any)
        local notice: any = app.Options.UpdateNotice
        if type(notice) == "table" and notice.Title ~= nil then
            logRender(app, kit, notice)
            return
        end
        local lines: { string } = app.Options.UpdateNotice
        kit:title(tostring(lines[1] or ""))
        bodyLines(kit, { table.unpack(lines, 2) })
        kit:closeX(function()
            app:acknowledgeUpdate()
            app:closePopup()
        end)
    end,
}

local THANKS_TITLE = "Thank you for using my scripts :)"
local THANKS_LINES = { "Join the discord server if you need help", "or want to suggest/report stuff" }

Builtin.thanks = {
    size = function(app: App)
        return fitWidth(app, THANKS_TITLE, THANKS_LINES, 340), fitHeight(#THANKS_LINES + 1, app.Options.Discord ~= nil)
    end,
    title = function()
        return ""
    end,
    locked = true,
    render = function(app: App, kit: any)
        local invite = app.Options.Discord
        local function close()
            app:acknowledgeThanks()
            app:closePopup()
        end
        kit:title(THANKS_TITLE)
        kit:closeX(close)
        bodyLines(kit, THANKS_LINES)
        kit:text("this will show only once", EDGE, TOP + #THANKS_LINES * LINE + LINE / 2, 11, app.Pal.Disabled, false, true, 35)
        if invite then
            kit:button("thanks:join", EDGE, kit.Height - EDGE - BUTTON, kit.Width - EDGE * 2, BUTTON, function()
                Discord.join(invite)
                app:acknowledgeThanks()
                app:openPopup("discord")
            end, { label = "Join Server" })
        end
    end,
}

local previewText: string? = nil
local previewLimit = 0
local previewResult = ""

local function preview(kit: any, text: string, limit: number): string
    if text == "" then
        return ""
    end
    if text == previewText and limit == previewLimit then
        return previewResult
    end
    local result = text
    if #text > 80 or kit:measure(text, 12) > limit then
        local suffix = ".. (" .. #text .. " characters)"
        local cut = math.min(#text, 80)
        while cut > 8 and kit:measure(string.sub(text, 1, cut) .. suffix, 12) > limit do
            cut -= 1
        end
        result = string.sub(text, 1, cut) .. suffix
    end
    previewText, previewLimit, previewResult = text, limit, result
    return result
end

local CODE_BOX = 78

Builtin.configCode = {
    size = function()
        return 440, TOP + CODE_BOX + GAP + LINE + SECTION + BUTTON + EDGE
    end,
    title = function()
        return ""
    end,
    render = function(app: App, kit: any)
        local pal = app.Pal
        local state = app.State
        local importing = state.CodeMode == "import"
        local top = kit:header("Config Code", if importing then "Paste a code to import your settings" else "Your settings as a code you can share", closer(app))
        local boxKey = "config:code"
        local focused = app.Focus == boxKey
        local code: string = if focused then (app.Buffers[boxKey] or "") else tostring(state.CodeBuffer or "")
        local boxWidth = kit.Width - EDGE * 2
        local shown = preview(kit, code, boxWidth - 28)
        kit:rect(EDGE, top, boxWidth, CODE_BOX, if focused then pal.Off else Color.lerp(pal.Main, pal.Panel, 0.34), 1, 12)
        if shown == "" then
            kit:text("Click here and press Ctrl+V to paste a code", kit.Width / 2, top + CODE_BOX / 2, 12, pal.Sub, true, true)
        else
            kit:text(shown .. (if focused then "|" else ""), kit.Width / 2, top + CODE_BOX / 2, 12, pal.Text, true, true)
        end
        if importing then
            kit:hit(boxKey, EDGE, top, boxWidth, CODE_BOX, function()
                app:beginInput(boxKey, tostring(state.CodeBuffer or ""), {
                    maxLength = 6000,
                    commit = function(text: string)
                        state.CodeBuffer = text
                    end,
                })
            end)
        end
        kit:swapText("config:note", state.CodeNote or "", EDGE, top + CODE_BOX + GAP + LINE / 2, 11, pal.Accent, false, true)
        local width = if importing then (kit.Width - EDGE * 2 - GAP * 2) / 3 else kit.Width - EDGE * 2
        local y = kit.Height - EDGE - BUTTON
        local hasCode = tostring(state.CodeBuffer or "") ~= ""
        kit:button("config:copy", EDGE, y, width, BUTTON, function()
            app:copyCodeBuffer()
        end, { label = "Copy", disabled = not hasCode, active = not importing and hasCode })
        if not importing then
            return
        end
        kit:button("config:paste", EDGE + width + GAP, y, width, BUTTON, function()
            app:pasteCodeBuffer()
        end, { label = "Paste" })
        kit:button("config:apply", EDGE + (width + GAP) * 2, y, width, BUTTON, function()
            if app:applyCodeBuffer() then
                app:closePopup()
            end
        end, { label = "Apply", active = hasCode, disabled = not hasCode })
    end,
}

Builtin.color = ColorPopup.color

return Builtin
end
modules["ui/popups/color"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../../core/color")) = import("core/color")
local Geometry: typeof(require("../geometry")) = import("ui/geometry")
local Hits: typeof(require("../hits")) = import("ui/hits")
local Kit: typeof(require("./kit")) = import("ui/popups/kit")
local Motion: typeof(require("../motion")) = import("ui/motion")
local Painter: typeof(require("../painter")) = import("ui/painter")

type App = { [string]: any }

local ColorPopup = {}

local Z_OUTLINE, Z_BASE, Z_WHITE, Z_BLACK, Z_EDGE, Z_DOT = 28, 25, 26, 27, 29, 31
local BAND = 2

local EDGE, GAP, SECTION, BUTTON = Kit.EDGE, Kit.GAP, Kit.SECTION, Kit.BUTTON
local WIDTH = 394
local SPAN = WIDTH - EDGE * 2
local BOARD_Y, BOARD_H = Kit.TOP, 142
local HUE_Y, HUE_H = BOARD_Y + BOARD_H + GAP, 22
local LABEL = 14
local HEX_Y = HUE_Y + HUE_H + SECTION
local RGB_Y = HEX_Y + LABEL + BUTTON + GAP
local ACTION_Y = RGB_Y + LABEL + BUTTON + SECTION
local SWATCH = 54

type Rect = { x: number, y: number, w: number, h: number }
type Band = { x: number, y: number, w: number, h: number, t: number }

type Layout = {
    key: string,
    outline: { Rect },
    base: { Rect },
    white: { Band },
    black: { Band },
    hue: { Band },
    innerW: number,
    innerH: number,
    border: number,
    radius: number,
    topEdge: Rect?,
}

local function mergeRows(spans: { { number }? }, rows: number): { Rect }
    local result: { Rect } = {}
    for y = 0, rows - 1 do
        local span = spans[y + 1]
        if span then
            local last = result[#result]
            if last and last.x == span[1] and last.w == span[2] - span[1] and last.y + last.h == y then
                last.h += 1
            else
                result[#result + 1] = { x = span[1], y = y, w = span[2] - span[1], h = 1 }
            end
        end
    end
    return result
end

local function appendAll(target: { Rect }, source: { Rect })
    for _, item in source do
        target[#target + 1] = item
    end
end

local function buildOutline(width: number, height: number, radius: number, border: number, innerW: number, innerH: number, innerRadius: number): { Rect }
    local full: { { number }? } = {}
    local left: { { number }? } = {}
    local right: { { number }? } = {}
    for y = 0, height - 1 do
        local outerInset = math.ceil(Geometry.rowInset(y + 0.5, width, height, radius) + 0.001)
        local outerX0 = math.clamp(outerInset, 0, width)
        local outerX1 = math.clamp(width - outerInset, 0, width)
        local innerY = y - border
        if outerX1 > outerX0 then
            if innerY < 0 or innerY >= innerH then
                full[y + 1] = { outerX0, outerX1 }
            else
                local innerInset = math.ceil(Geometry.rowInset(innerY + 0.5, innerW, innerH, innerRadius) + 0.001)
                local innerX0 = math.clamp(border + innerInset, outerX0, outerX1)
                local innerX1 = math.clamp(border + innerW - innerInset, outerX0, outerX1)
                if innerX0 > outerX0 then
                    left[y + 1] = { outerX0, innerX0 }
                end
                if outerX1 > innerX1 then
                    right[y + 1] = { innerX1, outerX1 }
                end
            end
        end
    end
    local result = mergeRows(full, height)
    appendAll(result, mergeRows(left, height))
    appendAll(result, mergeRows(right, height))
    return result
end

local layouts: { [string]: Layout } = {}

local function buildLayout(kind: string, width: number, height: number, scale: number, baseRadius: number): Layout
    local key = kind .. ":" .. width .. "x" .. height
    local cached = layouts[key]
    if cached then
        return cached
    end
    table.clear(layouts)
    local radius = math.clamp(math.floor(baseRadius * scale + 0.5), 0, math.floor(math.min(width, height) * 0.5))
    local border = math.max(1, math.floor(scale + 0.5))
    local innerW = math.max(1, width - border * 2)
    local innerH = math.max(1, height - border * 2)
    local innerRadius = math.clamp(radius - border, 0, math.floor(math.min(innerW, innerH) * 0.5))
    local layout: Layout = {
        key = key,
        outline = buildOutline(width, height, radius, border, innerW, innerH, innerRadius),
        base = {},
        white = {},
        black = {},
        hue = {},
        innerW = innerW,
        innerH = innerH,
        border = border,
        radius = radius,
        topEdge = nil,
    }

    local rowSpans: { { number }? } = {}
    for y = 0, innerH - 1 do
        local inset = math.ceil(Geometry.rowInset(y + 0.5, innerW, innerH, innerRadius) + 0.001)
        local x0, x1 = math.clamp(inset, 0, innerW), math.clamp(innerW - inset, 0, innerW)
        rowSpans[y + 1] = if x1 > x0 then { x0, x1 } else nil
    end
    if kind == "sv" then
        layout.base = mergeRows(rowSpans, innerH)
        for y = 0, innerH - 1, BAND do
            local bandH = math.min(BAND, innerH - y)
            local span = rowSpans[y + 1]
            if span then
                layout.black[#layout.black + 1] = { x = span[1], y = y, w = span[2] - span[1], h = bandH, t = math.clamp((y + bandH * 0.5) / innerH, 0, 1) }
            end
        end
    end
    local feather = math.max(3, math.floor(4 * scale + 0.5))
    for x = 0, innerW - 1, BAND do
        local bandW = math.min(BAND, innerW - x)
        local center = x + bandW * 0.5
        local inset = math.ceil(Geometry.columnInset(center, innerW, innerH, innerRadius) + 0.001)
        local y0, y1 = math.clamp(inset, 0, innerH), math.clamp(innerH - inset, 0, innerH)
        if y1 > y0 then
            local band: Band = {
                x = x, y = y0, w = bandW, h = y1 - y0,
                t = if kind == "sv" then 1 - math.clamp((center + feather) / innerW, 0, 1) else math.clamp(center / innerW, 0, 1),
            }
            if kind == "sv" then
                layout.white[#layout.white + 1] = band
            else
                layout.hue[#layout.hue + 1] = band
            end
        end
    end
    if kind == "sv" then
        local span = rowSpans[1]
        if span then
            layout.topEdge = { x = span[1], y = 0, w = span[2] - span[1], h = border }
        end
    end
    layouts[key] = layout
    return layout
end

local Z_SHADOW, Z_RING, Z_FILL = 30, 31, 32
local HANDLE_SPEED, GROW_SPEED = 26, 16

local glide: { [string]: number } = {}
local grow: { [string]: number } = {}

local function follow(app: App, key: string, goal: number, dragging: boolean): number
    local shown = glide[key]
    if shown == nil or dragging then
        shown = goal
    else
        shown = Motion.ease(app.State, shown, goal, app.Dt, HANDLE_SPEED)
        if math.abs(shown - goal) < 0.0005 then
            shown = goal
        end
    end
    glide[key] = shown
    return shown
end

local function handle(app: App, kit: any, key: string, center: Vector2, width: number, height: number, fill: Color3, active: number)
    local pal = app.Pal
    local alpha = kit.Alpha
    local amount = Motion.ease(app.State, grow[key] or 0, active, app.Dt, GROW_SPEED)
    grow[key] = amount
    local lift = 1 + 0.18 * amount
    local w, h = width * lift, height * lift
    local shadow = kit:s(w + 6, h + 6)
    Painter.rect(center - shadow / 2 + kit:s(0, 1), shadow, Color3.new(0, 0, 0), alpha * (0.2 + 0.1 * amount), Z_SHADOW, 1000)
    local body = kit:s(w, h)
    Painter.rect(center - body / 2, body, fill, alpha, Z_RING, 1000)
    local scale = kit.ScreenSize.X / kit.Width
    Painter.border(center - body / 2, body, math.min(body.X, body.Y) / 2, Color.lerp(pal.Text, app.State.AccentCol, 0.3 * amount), alpha, Z_FILL, (2 + amount * 0.5) * scale)
end

local function drawRects(origin: Vector2, rects: { Rect }, color: Color3, alpha: number, z: number)
    for _, rect in rects do
        Painter.rect(origin + Vector2.new(rect.x, rect.y), Vector2.new(rect.w, rect.h), color, alpha, z, 0)
    end
end

local function drawBoard(app: App, kit: any, picker: any, outlineColor: Color3)
    local pal = app.Pal
    local position, size = kit:p(EDGE, BOARD_Y), kit:s(SPAN, BOARD_H)
    local scale = math.max(0.01, kit.ScreenSize.X / kit.Width)
    local radius = 10
    local stroke = math.max(1, scale * 1.5)
    local origin = Vector2.new(position.X, position.Y)
    local inner = origin
    local innerW, innerH = size.X, size.Y
    local alpha = kit.Alpha
    local outer = Painter.active()

    Painter.scope("color:sv:fill")
    Painter.gradient(origin, size, { Color3.new(1, 1, 1), Color.fromHSV(picker.H, 1, 1) }, 0, alpha, Z_BASE, radius)
    Painter.scope("color:sv:shade")
    Painter.fade(origin, size, Color3.new(0, 0, 0), 0, 1, 90, alpha, Z_BLACK, radius)
    Painter.scope("color:sv:outline")
    Painter.border(origin, size, radius * Painter.corner(), outlineColor, alpha, Z_EDGE, stroke)
    Painter.scope("color:sv:dot")
    local half = kit:s(8, 8)
    local dragging = Hits.isDragging("color:board")
    local sx = follow(app, "sv:x", picker.S, dragging)
    local sy = follow(app, "sv:y", picker.V, dragging)
    local center = Vector2.new(
        inner.X + math.clamp(sx * innerW, half.X, math.max(half.X, innerW - half.X)),
        inner.Y + math.clamp((1 - sy) * innerH, half.Y, math.max(half.Y, innerH - half.Y))
    )
    handle(app, kit, "sv", center, 16, 16, picker.Color, if dragging then 1 else 0)
    Painter.scope(outer)

    Hits.add({
        key = "color:board",
        position = inner,
        size = Vector2.new(innerW, innerH),
        drag = function(mouse: Vector2)
            picker:setHSV(nil, math.clamp((mouse.X - inner.X) / math.max(0.001, innerW), 0, 1), 1 - math.clamp((mouse.Y - inner.Y) / math.max(0.001, innerH), 0, 1))
        end,
    })
end

local function drawHue(app: App, kit: any, picker: any, outlineColor: Color3)
    local pal = app.Pal
    local position, size = kit:p(EDGE, HUE_Y), kit:s(SPAN, HUE_H)
    local scale = math.max(0.01, kit.ScreenSize.X / kit.Width)
    local radius = size.Y / 2 / math.max(0.01, kit.ScreenSize.X / kit.Width)
    local stroke = math.max(1, scale * 1.5)
    local origin = Vector2.new(position.X, position.Y)
    local inner = origin
    local innerW, innerH = size.X, size.Y
    local alpha = kit.Alpha
    local outer = Painter.active()
    local stops: { Color3 } = {}
    for index = 0, 6 do
        stops[index + 1] = Color.fromHSV(index / 6, 1, 1)
    end

    Painter.scope("color:hue:bands")
    Painter.gradient(origin, size, stops, 0, alpha, Z_BASE, radius)
    Painter.scope("color:hue:outline")
    Painter.border(origin, size, radius * Painter.corner(), outlineColor, alpha, Z_EDGE, stroke)
    Painter.scope("color:hue:dot")
    local half = kit:s(8, 8)
    local dragging = Hits.isDragging("color:hue")
    local hx = follow(app, "hue:x", picker.H, dragging)
    local center = Vector2.new(
        inner.X + math.clamp(hx * innerW, half.X, math.max(half.X, innerW - half.X)),
        inner.Y + innerH * 0.5
    )
    handle(app, kit, "hue", center, 16, 16, Color.fromHSV(picker.H, 1, 1), if dragging then 1 else 0)
    Painter.scope(outer)

    Hits.add({
        key = "color:hue",
        position = inner,
        size = Vector2.new(innerW, innerH),
        drag = function(mouse: Vector2)
            picker:setHSV(math.clamp((mouse.X - inner.X) / math.max(0.001, innerW), 0, 1), nil, nil)
        end,
    })
end

local shownColor: Color3? = nil

local function label(kit: any, pal: any, text: string, x: number, y: number)
    local alpha = kit.Alpha
    kit.Alpha = alpha * 0.8
    kit:text(text, x, y, 10, pal.Sub, false, false)
    kit.Alpha = alpha
end

ColorPopup.color = {
    size = function()
        return WIDTH, ACTION_Y + BUTTON + EDGE
    end,
    title = function()
        return "Color Mixer"
    end,
    render = function(app: App, kit: any)
        local picker = app.Picker
        local pal = app.Pal
        local outlineColor = Color.lerp(pal.Panel, app.State.AccentCol, 0.36)

        drawBoard(app, kit, picker, outlineColor)
        drawHue(app, kit, picker, outlineColor)

        local previous = shownColor or picker.Color
        shownColor = Color.lerp(previous, picker.Color, math.clamp(Motion.ease(app.State, 0, 1, app.Dt, 24), 0, 1))
        label(kit, pal, "COLOR", EDGE + 2, HEX_Y)
        kit:rect(EDGE, HEX_Y + LABEL, SWATCH, BUTTON, shownColor, 1, Kit.ROUND)
        kit:border(EDGE, HEX_Y + LABEL, SWATCH, BUTTON, Kit.ROUND, outlineColor, 1, 1.5)

        local hexX = EDGE + SWATCH + GAP
        label(kit, pal, "HEX", hexX + 2, HEX_Y)
        kit:input("Hex", hexX, HEX_Y + LABEL, WIDTH - EDGE - hexX, BUTTON, "#" .. (app.Buffers.Hex or ""), function()
            app:beginInput("Hex", app.Buffers.Hex or "", {
                filter = "[0-9A-Fa-f#]",
                upper = true,
                maxLength = 7,
                commit = function()
                    picker:applyField("Hex")
                end,
            })
        end)

        local fields: { { key: string, label: string } } = {
            { key = "Red", label = "RED" },
            { key = "Green", label = "GREEN" },
            { key = "Blue", label = "BLUE" },
        }
        local fieldWidth = (SPAN - GAP * 2) / 3
        for index, field in fields do
            local key = field.key
            local x = EDGE + (index - 1) * (fieldWidth + GAP)
            label(kit, pal, field.label, x + 2, RGB_Y)
            kit:input(key, x, RGB_Y + LABEL, fieldWidth, BUTTON, app.Buffers[key] or "0", function()
                app:beginInput(key, app.Buffers[key] or "0", {
                    filter = "%d",
                    maxLength = 3,
                    commit = function()
                        picker:applyField(key)
                    end,
                })
            end)
        end

        local half = (SPAN - GAP) / 2
        kit:button("color:reset", EDGE, ACTION_Y, half, BUTTON, function()
            picker:reset()
        end, { label = "Reset", hoverColor = Color3.fromRGB(200, 70, 70), hoverMix = 0.75, hoverText = pal.Text })
        kit:button("color:apply", EDGE + half + GAP, ACTION_Y, half, BUTTON, function()
            app:finishColor()
        end, { label = "Apply" })
    end,
}

return ColorPopup
end
modules["ui/popups/kit"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../../core/color")) = import("core/color")
local Hits: typeof(require("../hits")) = import("ui/hits")
local Motion: typeof(require("../motion")) = import("ui/motion")
local Painter: typeof(require("../painter")) = import("ui/painter")
local Fonts: typeof(require("../fonts")) = import("ui/fonts")
local Press: typeof(require("../press")) = import("ui/press")

local Kit = {}
Kit.__index = Kit

type App = { [string]: any }

local Z_BODY, Z_CONTROL, Z_TEXT = 22, 24, 26
Kit.Z_BODY, Kit.Z_CONTROL, Kit.Z_TEXT = Z_BODY, Z_CONTROL, Z_TEXT

local EDGE, GAP, SECTION = 16, 8, 14
local BUTTON, ROUND, CLOSE, ROW = 28, 16, 62, 24
local TITLE_Y = EDGE + ROW / 2 - 0.4
local HEAD = EDGE + ROW
local TOP = HEAD + SECTION
Kit.EDGE, Kit.GAP, Kit.SECTION, Kit.BUTTON, Kit.ROUND, Kit.CLOSE, Kit.ROW, Kit.HEAD, Kit.TOP = EDGE, GAP, SECTION, BUTTON, ROUND, CLOSE, ROW, HEAD, TOP

function Kit.new(app: App, width: number, height: number, position: Vector2, size: Vector2, alpha: number)
    local self = {
        App = app,
        Width = width,
        Height = height,
        Position = position,
        ScreenSize = size,
        Alpha = alpha,
        ZControl = Z_CONTROL,
        ZText = Z_TEXT,
        Owner = Painter.active(),
    }
    return setmetatable(self, Kit)
end

type Self = typeof(Kit.new(nil :: any, 0, 0, Vector2.new(0, 0), Vector2.new(0, 0), 0))

function Kit.p(self: Self, x: number, y: number): Vector2
    return self.Position + Vector2.new(x / self.Width * self.ScreenSize.X, y / self.Height * self.ScreenSize.Y)
end

function Kit.s(self: Self, w: number, h: number): Vector2
    return Vector2.new(w / self.Width * self.ScreenSize.X, h / self.Height * self.ScreenSize.Y)
end

function Kit.rect(self: Self, x: number, y: number, w: number, h: number, color: Color3, alpha: number?, rounding: number?)
    Painter.rect(self:p(x, y), self:s(w, h), color, self.Alpha * (alpha or 1), self.ZControl, rounding or 10)
end

function Kit.image(self: Self, url: string, x: number, y: number, w: number, h: number, radius: number?, alpha: number?, tint: Color3?): boolean
    local factor = self.ScreenSize.X / self.Width
    return Painter.image(url, self:p(x, y), self:s(w, h), self.Alpha * (alpha or 1), self.ZText, (radius or 0) * factor, tint)
end

function Kit.preload(self: Self, url: string, x: number, y: number, w: number, h: number, radius: number?)
    local factor = self.ScreenSize.X / self.Width
    Painter.preload(url, self:p(x, y), self:s(w, h), (radius or 0) * factor)
end

function Kit.imageStats(_self: Self): (number, number, number, number)
    return Painter.imageStats()
end

function Kit.solid(self: Self, x: number, y: number, w: number, h: number, color: Color3, radius: number, alpha: number?)
    local factor = self.ScreenSize.X / self.Width
    Painter.rect(self:p(x, y), self:s(w, h), color, self.Alpha * (alpha or 1), self.ZControl, radius * factor, true)
end

function Kit.text(self: Self, text: string, x: number, y: number, size: number, color: Color3, center: boolean?, middle: boolean?, font: number?)
    local scaled = size * self.App.TextScale
    if font then
        scaled = scaled * Fonts.scale(font) / Fonts.scale(Painter.font())
    end
    Painter.text(text, self:p(x, y), scaled, color, self.Alpha, self.ZText, center, middle, font)
end

function Kit.boldFace(_self: Self): number?
    return Fonts.find("Gotham Bold")
end

local function easeKey(app: App, key: string, goal: number, speed: number): number
    local store = app.PopAnim
    local value = Motion.ease(app.State, store[key] or 0, goal, app.Dt, speed)
    store[key] = value
    return value
end

function Kit.swapText(self: Self, key: string, text: string, x: number, y: number, size: number, color: Color3, center: boolean?, middle: boolean?, font: number?)
    local app = self.App
    local store = app.PopText
    if not store then
        store = {}
        app.PopText = store
    end
    local shown: string = store[key] or ""
    local fade = easeKey(app, key .. ":swap", if shown == text then 1 else 0, 18)
    if shown ~= text and (shown == "" or fade < 0.03) then
        shown, fade = text, 0
        store[key] = text
        app.PopAnim[key .. ":swap"] = 0
    end
    if shown == "" then
        return
    end
    local scaled = size * app.TextScale
    if font then
        scaled = scaled * Fonts.scale(font) / Fonts.scale(Painter.font())
    end
    Painter.text(shown, self:p(x, y), scaled, color, self.Alpha * fade, self.ZText, center, middle, font)
end

local function pressOf(app: App, key: string, enabled: boolean?): number
    return Press.scale(app, app.Springs, key .. ":press", key, enabled)
end

local function drawSwitch(self: Self, key: string, x: number, y: number, width: number, height: number, knob: number, on: boolean, hover: number, off: Color3)
    local app = self.App
    local pal = app.Pal
    local value = Motion.spring(app.State, app.Springs, key .. ":on", if on then 1 else 0, app.Dt, 0.34, 0.6)
    local shown = math.clamp(value, 0, 1)
    local held = Motion.spring(app.State, app.Springs, key .. ":held", if Hits.isPressed(key) and app.HoverKey == key then 1 else 0, app.Dt, 0.22, 0.8)
    local round = math.clamp(tonumber(app.State.ToggleRoundness) or 0.55, 0, 1)
    self:solid(x, y, width, height, Color.lerp(off, Color.lighten(pal.Accent, 0.25 * hover), shown), height * 0.5 * round)
    local travel = math.abs(Motion.velocity(app.Springs, key .. ":on"))
    local knobW = knob * (1 + math.min(travel * 0.07, 0.35) + 0.18 * math.clamp(held, 0, 1))
    local pad = (height - knob) / 2
    local room = width - knob - pad * 2
    self:solid(x + pad + room * value - (knobW - knob) * value, y + pad, knobW, knob, Color.lerp(pal.Sub, pal.Main, shown), knob * 0.5 * round)
end

function Kit.dim(self: Self, key: string, on: boolean, strength: number)
    local value = easeKey(self.App, "dim:" .. key, if on then 1 else 0, 9)
    if value > 0.01 then
        Painter.rect(self.Position, self.ScreenSize, self.App.Pal.Main, self.Alpha * strength * value, self.ZText + 1, 14)
    end
    if on then
        Hits.add({ key = "kit:dim:" .. key, position = self.Position, size = self.ScreenSize, shield = true })
    end
end

function Kit.button(self: Self, key: string, x: number, y: number, w: number, h: number, onClick: () -> (), options: { [string]: any }?): (number, number)
    local app = self.App
    local pal = app.Pal
    local opts: { [string]: any } = options or {}
    local position, size = self:p(x, y), self:s(w, h)
    local live = opts.disabled ~= true
    local hovered = app.HoverKey == key and live
    local hover = easeKey(app, key .. ":hover", if hovered then 1 else 0, Press.HOVER_SPEED)
    local scale = if opts.still == true then 1 else pressOf(app, key, live)
    local moved, shrunk = Press.box(position, size, scale)

    local active = opts.active == true
    local preset = app.State.ThemePreset
    local darker = type(preset) == "table" and preset.Name == "Default" and (preset :: any).Pure ~= true and app.State.ThemeName ~= "Custom"
    local base = opts.base or (if darker then Color.lerp(pal.Panel, Color3.new(0, 0, 0), 0.22) else pal.Panel)
    local fill = if active then pal.Accent else Color.lerp(base, opts.hoverColor or pal.Accent, (opts.hoverMix or 1) * hover)
    Painter.rect(moved, shrunk, fill, self.Alpha, self.ZControl, opts.rounding or ROUND)
    local textColor
    if active then
        textColor = pal.Panel
    else
        textColor = Color.lerp(opts.textColor or pal.Text, opts.hoverText or Color3.new(0, 0, 0), hover * (opts.hoverMix or 1))
    end
    if opts.label then
        local labelSize = (opts.size or 13) * app.TextScale
        if opts.font then
            labelSize = labelSize * Fonts.scale(opts.font) / Fonts.scale(Painter.font())
        end
        if opts.align ~= "left" then
            Painter.text(opts.label, moved + shrunk / 2, labelSize, textColor, self.Alpha, self.ZText, true, true, opts.font)
        else
            Painter.text(opts.label, moved + Vector2.new(self:s(12, 0).X * scale, shrunk.Y / 2), labelSize, textColor, self.Alpha, self.ZText, false, true, opts.font)
        end
    end
    Hits.add({ key = key, position = position, size = size, click = onClick })
    return hover, scale
end

function Kit.pager(self: Self, key: string, x: number, y: number, w: number, page: number, maxPage: number, onPage: (number) -> ())
    local pal = self.App.Pal
    local canPrev, canNext = page > 1, page < maxPage
    local function arrow(suffix: string, label: string, ax: number, enabled: boolean, target: number)
        local hover = self:button(key .. suffix, ax, y, BUTTON, BUTTON, function()
            if enabled then
                onPage(target)
            end
        end, {
            label = label,
            textColor = if enabled then pal.Text else pal.Disabled,
            base = if enabled then pal.Panel else Color.lerp(pal.Panel, pal.Main, 0.5),
            hoverMix = if enabled then 1 else 0,
            disabled = not enabled,
        })
        return hover
    end
    arrow(":prev", "<", x, canPrev, page - 1)
    arrow(":next", ">", x + w - BUTTON, canNext, page + 1)
    self:text(tostring(page) .. "/" .. tostring(maxPage), x + w / 2, y + BUTTON / 2, 13, pal.Sub, true, true)
end

function Kit.lines(self: Self, lines: { string }, y: number, step: number, size: number?)
    local color = self.App.Pal.Sub
    local base = size or 13
    local limit = self.Width - EDGE * 2
    local scale = 1
    for _, line in lines do
        local width = self:measure(line, base)
        if width > limit then
            scale = math.min(scale, limit / width)
        end
    end
    for index, line in lines do
        self:text(line, EDGE, y + (index - 1) * step, base * scale, color, false, true)
    end
end

function Kit.switchRow(self: Self, key: string, x: number, y: number, w: number, h: number, label: string, on: boolean, onClick: () -> ())
    local app = self.App
    local pal = app.Pal
    local hovered = app.HoverKey == key
    local hover = easeKey(app, key .. ":hover", if hovered then 1 else 0, Press.HOVER_SPEED)
    local scale = pressOf(app, key)
    local bx, by, bw, bh = Press.area(x, y, w, h, scale)
    self:rect(bx, by, bw, bh, Color.lerp(Color.lerp(pal.Panel, pal.Main, 0.10), pal.Accent, 0.08 * hover), 1, 16)
    self:text(label, bx + 12 * scale, by + bh / 2, 13, pal.Text, false, true)
    local trackW, trackH = 42 * scale, 22 * scale
    drawSwitch(self, key, bx + bw - (42 + 12) * scale, by + (bh - trackH) / 2, trackW, trackH, 16 * scale, on, hover, pal.Off)
    Hits.add({ key = key, position = self:p(x, y), size = self:s(w, h), click = onClick })
end

function Kit.slider(self: Self, key: string, x: number, y: number, w: number, h: number, label: string, fraction: number, shown: string, onDrag: (number) -> ())
    local app = self.App
    local pal = app.Pal
    local hover = easeKey(app, key .. ":hover", if app.HoverKey == key then 1 else 0, 16)
    self:rect(x, y, w, h, Color.lerp(Color.lerp(pal.Panel, pal.Main, 0.10), pal.Accent, 0.06 * hover), 1, 16)
    self:text(label, x + 12, y + 15, 13, pal.Text, false, true)
    local barX, barY, barW, barH = x + 12, y + h - 12, w - 65, 5
    self:rect(barX, barY, barW, barH, pal.Main, 1, 8)
    self:rect(barX, barY, math.max(1, barW * math.clamp(fraction, 0, 1)), barH, Color.lighten(pal.Accent, 0.25 * hover), 1, 8)
    self:rect(x + w - 47, y + 6, 35, 18, pal.Main, 1, 12)
    self:text(shown, x + w - 29.5, y + 15, 13, pal.Text, true, true)
    local barPos, barSize = self:p(barX, barY), self:s(barW, barH)
    Hits.add({
        key = key,
        position = self:p(x, y),
        size = self:s(w, h),
        drag = function(mouse: Vector2)
            onDrag(math.clamp((mouse.X - barPos.X) / math.max(0.001, barSize.X), 0, 1))
        end,
    })
end

function Kit.input(self: Self, key: string, x: number, y: number, w: number, h: number, shown: string, onFocus: () -> (), base: Color3?)
    local app = self.App
    local pal = app.Pal
    local focused = app.Focus == key
    local hover = easeKey(app, key .. ":hover", if app.HoverKey == key then 1 else 0, Press.HOVER_SPEED)
    local scale = pressOf(app, key)
    local bx, by, bw, bh = Press.area(x, y, w, h, scale)
    self:rect(bx, by, bw, bh, if focused then pal.Off else Color.lerp(base or pal.Panel, pal.Accent, 0.22 * hover), 1, ROUND)
    self:text(if focused then (app.Buffers[key] or "") .. "|" else shown, bx + bw / 2, by + bh / 2, 13, pal.Text, true, true)
    Hits.add({ key = key, position = self:p(x, y), size = self:s(w, h), click = onFocus })
end

function Kit.closeX(self: Self, onClose: () -> ())
    self:button("pop:close", self.Width - EDGE - CLOSE, EDGE, CLOSE, ROW, onClose, { label = "Close" })
end

function Kit.title(self: Self, title: string, x: number?)
    local pal = self.App.Pal
    local left = x or EDGE
    self:text(title, left, TITLE_Y, 15, pal.Accent, false, true)
end

function Kit.header(self: Self, title: string, subtitle: string?, onClose: () -> (), onBack: (() -> ())?): number
    local pal = self.App.Pal
    local left = EDGE
    if onBack then
        self:button("pop:back", EDGE, EDGE, ROW, ROW, onBack, { label = "<", size = 14 })
        left = EDGE + ROW + GAP
    end
    self:text(title, left, if subtitle then TITLE_Y - 2 else TITLE_Y + 3.5, 15, pal.Text, false, true)
    if subtitle then
        self:text(subtitle, left, TITLE_Y + 11, 10, pal.Sub, false, true)
    end
    self:closeX(onClose)
    self:rect(EDGE, HEAD + SECTION / 2, self.Width - EDGE * 2, 1, pal.Off, 0.8, 0)
    return TOP
end

function Kit.listRow(self: Self, key: string, x: number, y: number, w: number, h: number, options: { [string]: any })
    local app = self.App
    local pal = app.Pal
    local clickable = options.onClick ~= nil
    local hover = easeKey(app, key .. ":hover", if clickable and app.HoverKey == key then 1 else 0, Press.HOVER_SPEED)
    local scale = pressOf(app, key, clickable)
    local bx, by, bw, bh = Press.area(x, y, w, h, scale)
    self:rect(bx, by, bw, bh, Color.lerp(Color.lerp(pal.Main, pal.Panel, 0.30), pal.Accent, 0.13 * hover), 1, 12)
    local badgeColor: Color3 = options.badgeColor or pal.Sub
    local size = (h - 12) * scale
    self:rect(bx + 8 * scale, by + 6 * scale, size, size, Color.lerp(pal.Main, badgeColor, 0.80), 1, 9)
    self:text(options.badge or "?", bx + 8 * scale + size / 2, by + bh / 2, 12, Color.lighten(badgeColor, 0.75), true, true)
    local textX = bx + 16 * scale + size
    local middle = by + bh / 2
    local sub: string? = options.sub
    if sub and sub ~= "" then
        self:text(options.title, textX, middle - 6 * scale, 12, pal.Text, false, true)
        self:text(sub, textX, middle + 7 * scale, 9, pal.Sub, false, true)
    else
        self:text(options.title, textX, middle, 12, pal.Text, false, true)
    end
    if options.arrow then
        self:text(">", bx + bw - (14 - hover * 2) * scale, middle, 13, Color.lerp(pal.Sub, pal.Accent, hover), true, true)
    end
    if clickable then
        Hits.add({ key = key, position = self:p(x, y), size = self:s(w, h), click = options.onClick, rightClick = options.onRightClick })
    end
end

function Kit.miniSwitch(self: Self, key: string, x: number, y: number, on: boolean, onClick: () -> ())
    local app = self.App
    local pal = app.Pal
    local width, height, knob = 36, 20, 14
    local hover = easeKey(app, key .. ":hover", if app.HoverKey == key then 1 else 0, Press.HOVER_SPEED)
    drawSwitch(self, key, x, y, width, height, knob, on, hover, Color.lerp(pal.Off, pal.Main, 0.2))
    Hits.add({ key = key, position = self:p(x - 4, y - 4), size = self:s(width + 8, height + 8), click = onClick })
end

function Kit.segment(self: Self, key: string, x: number, y: number, w: number, h: number, labels: { string }, selected: number, onSelect: (number) -> ())
    local app = self.App
    local pal = app.Pal
    local count = #labels
    local cell = w / count
    self:rect(x, y, w, h, Color.lerp(pal.Main, pal.Panel, 0.42), 1, 12)
    local slide = Motion.spring(app.State, app.Springs, key .. ":slide", selected - 1, app.Dt, 0.34, 0.82)
    self:rect(x + 2 + slide * cell, y + 2, cell - 4, h - 4, Color.lerp(pal.Panel, pal.Accent, math.max(0.30, pal.Pick)), 1, 10)
    for index, label in labels do
        local cellKey = key .. ":" .. index
        local hover = easeKey(app, cellKey .. ":hover", if app.HoverKey == cellKey then 1 else 0, Press.HOVER_SPEED)
        local lit = easeKey(app, cellKey .. ":lit", if index == selected then 1 else 0, 14)
        local color = Color.lerp(Color.lerp(pal.Sub, pal.Text, hover), pal.AccentText, lit)
        self:text(label, x + (index - 0.5) * cell, y + h / 2, 11, color, true, true)
        Hits.add({
            key = cellKey,
            position = self:p(x + (index - 1) * cell, y),
            size = self:s(cell, h),
            click = function()
                onSelect(index)
            end,
        })
    end
end

function Kit.scope(self: Self, key: any?)
    Painter.scope(if key == nil then self.Owner else key)
end

function Kit.nest(_self: Self, key: any, draw: () -> ())
    local outer = Painter.active()
    Painter.scope(key)
    draw()
    Painter.scope(outer)
end

function Kit.ease(self: Self, key: string, goal: number, speed: number): number
    local store = self.App.PopAnim
    if store[key] == nil then
        store[key] = goal
    end
    return easeKey(self.App, key, goal, speed)
end

local WHEEL_STEP = 56
local SCROLL_RATE = 8

local EDGE_FADE = 24

local function smooth(value: number): number
    local t = math.clamp(value, 0, 1)
    return t * t * (3 - 2 * t)
end

function Kit.scroll(self: Self, key: string, x: number, y: number, w: number, h: number, rowHeight: number, count: number, draw: (index: number, rx: number, ry: number, rw: number) -> (), _topEdge: number?, contained: boolean?): number
    local app = self.App
    local pal = app.Pal
    local store = app.Scrolls
    if not store then
        store = {}
        app.Scrolls = store
    end
    local cell = store[key]
    if not cell then
        cell = { Target = 0, Pos = 0, Bar = 0 }
        store[key] = cell
    end
    local content = rowHeight * count
    local maxScroll = math.max(0, content - h)
    if contained then
        maxScroll = math.ceil(maxScroll / rowHeight - 0.001) * rowHeight
    end
    cell.Target = math.clamp(cell.Target, 0, maxScroll)
    if contained then
        cell.Target = math.clamp(math.floor(cell.Target / rowHeight + 0.5) * rowHeight, 0, maxScroll)
    end
    local barKey = "scroll:" .. key .. ":bar"
    if Hits.isDragging(barKey) and not contained then
        cell.Pos = cell.Target
    else
        cell.Pos = Motion.ease(app.State, cell.Pos, cell.Target, app.Dt, SCROLL_RATE)
        if math.abs(cell.Pos - cell.Target) < 0.05 then
            cell.Pos = cell.Target
        end
    end
    cell.Pos = math.clamp(cell.Pos, 0, maxScroll)
    local barWidth = if maxScroll > 0 then 10 else 0
    if maxScroll > 0 then
        Hits.add({
            key = "scroll:" .. key,
            position = self:p(x, y),
            size = self:s(w, h),
            wheel = function(delta: number)
                cell.Target = math.clamp(cell.Target - delta * WHEEL_STEP, 0, maxScroll)
            end,
        })
    end
    local outer = Painter.active()
    local first = math.max(1, math.floor(cell.Pos / rowHeight) + 1)
    local last = math.min(count, math.ceil((cell.Pos + h) / rowHeight))
    local room = if contained then 4 else 0
    local clipAt, clipSize = self:p(x - 4, y - room), self:s(w + 8, h + room)
    local pageAt, pageSize = Hits.getClip()
    if pageAt and pageSize then
        local left, top = math.max(clipAt.X, pageAt.X), math.max(clipAt.Y, pageAt.Y)
        local right = math.min(clipAt.X + clipSize.X, pageAt.X + pageSize.X)
        local bottom = math.min(clipAt.Y + clipSize.Y, pageAt.Y + pageSize.Y)
        clipAt, clipSize = Vector2.new(left, top), Vector2.new(math.max(0, right - left), math.max(0, bottom - top))
    end
    Painter.clip(clipAt, clipSize)
    Hits.setClip(clipAt, clipSize)
    for index = first, last do
        local top = y + (index - 1) * rowHeight - cell.Pos
        Painter.scope(key .. ":" .. index)
        draw(index, x, top, w - barWidth)
        Painter.scope(outer)
    end
    if pageAt and pageSize then
        Painter.clip(pageAt, pageSize)
        Hits.setClip(pageAt, pageSize)
    else
        Painter.unclip()
        Hits.setClip(nil, nil)
    end
    if maxScroll > 0 then
        local dragging = Hits.isDragging(barKey)
        local hovered = app.HoverKey == barKey or dragging
        cell.Bar = Motion.ease(app.State, cell.Bar, if hovered then 1 else 0, app.Dt, 14)
        local thumb = math.max(24, h * h / content)
        local travel = h - thumb
        local thumbY = y + travel * (cell.Pos / maxScroll)
        local thickness = 3 + 2 * cell.Bar
        local trackX = x + w - thickness - 1
        local alpha = 0.30 + 0.60 * cell.Bar
        self:solid(trackX, y, thickness, h, pal.Sub, thickness * 0.5, 0.14 * cell.Bar)
        self:solid(trackX, thumbY, thickness, thumb, Color.lerp(pal.Sub, pal.Accent, cell.Bar), thickness * 0.5, alpha)
        local trackPosition, trackSize = self:p(x + w - 12, y), self:s(12, h)
        local thumbScreen = thumb / h * trackSize.Y
        local grab = thumbScreen / 2
        Hits.add({
            key = barKey,
            position = trackPosition,
            size = trackSize,
            press = function(mouse: Vector2)
                local current = trackPosition.Y + (trackSize.Y - thumbScreen) * (cell.Pos / maxScroll)
                if mouse.Y >= current and mouse.Y <= current + thumbScreen then
                    grab = mouse.Y - current
                else
                    grab = thumbScreen / 2
                end
            end,
            drag = function(mouse: Vector2)
                local fraction = (mouse.Y - trackPosition.Y - grab) / math.max(1, trackSize.Y - thumbScreen)
                cell.Target = math.clamp(fraction, 0, 1) * maxScroll
            end,
        })
    end
    return cell.Pos
end

function Kit.measure(self: Self, text: string, size: number): number
    local factor = self.ScreenSize.X / self.Width
    return Painter.textWidth(text, size * self.App.TextScale) / factor
end

function Kit.hit(self: Self, key: string, x: number, y: number, w: number, h: number, onClick: () -> ())
    Hits.add({ key = key, position = self:p(x, y), size = self:s(w, h), click = onClick })
end

function Kit.border(self: Self, x: number, y: number, w: number, h: number, radius: number, color: Color3, alpha: number?, thickness: number?)
    local factor = self.ScreenSize.X / self.Width
    Painter.border(self:p(x, y), self:s(w, h), radius * factor, color, self.Alpha * (alpha or 1), self.ZControl, thickness or 1.5)
end

function Kit.line(self: Self, x1: number, y1: number, x2: number, y2: number, color: Color3, thickness: number, alpha: number?)
    local factor = self.ScreenSize.X / self.Width
    Painter.line(self:p(x1, y1), self:p(x2, y2), color, self.Alpha * (alpha or 1), self.ZControl, thickness * factor)
end

function Kit.region(self: Self, key: string, x: number, y: number, w: number, h: number, onClick: (() -> ())?, onRightClick: (() -> ())?)
    Hits.add({ key = key, position = self:p(x, y), size = self:s(w, h), click = onClick, rightClick = onRightClick })
end

function Kit.hovered(self: Self, key: string): boolean
    return self.App.HoverKey == key
end

function Kit.shield(self: Self)
    Hits.add({ key = "pop:body", position = self.Position, size = self.ScreenSize, shield = true })
end

return Kit
end
modules["ui/press"] = function(...)

local import: (string) -> any = ...
local Hits: typeof(require("./hits")) = import("ui/hits")
local Motion: typeof(require("./motion")) = import("ui/motion")

local Press = {}

type App = { [string]: any }

Press.SHRINK = 0.04
Press.HOVER_SPEED = 16

local RESPONSE, RATIO = 0.26, 0.5

function Press.scale(app: App, bag: { [string]: any }, name: string, key: any, enabled: boolean?): number
    local goal = if enabled ~= false and Hits.isPressed(key) and app.HoverKey == key then 1 else 0
    local value = Motion.spring(app.State, bag, name, goal, app.Dt, RESPONSE, RATIO)
    return 1 - Press.SHRINK * math.clamp(value, -0.6, 1.2)
end

function Press.box(position: Vector2, size: Vector2, scale: number): (Vector2, Vector2)
    local smaller = size * scale
    return position + (size - smaller) / 2, smaller
end

function Press.area(x: number, y: number, w: number, h: number, scale: number): (number, number, number, number)
    return x + w * (1 - scale) / 2, y + h * (1 - scale) / 2, w * scale, h * scale
end

return Press
end
modules["ui/runner"] = function(...)

local import: (string) -> any = ...
local Canvas: typeof(require("../render/canvas")) = import("render/canvas")
local Chat: typeof(require("../input/chat")) = import("input/chat")
local Draw: typeof(require("../render/draw")) = import("render/draw")
local Logo: typeof(require("./logo")) = import("ui/logo")
local Chrome: typeof(require("./chrome")) = import("ui/chrome")
local Effects: typeof(require("./effects")) = import("ui/effects")
local Farm: typeof(require("./farm")) = import("ui/farm")
local Fonts: typeof(require("./fonts")) = import("ui/fonts")
local Hits: typeof(require("./hits")) = import("ui/hits")
local Keys: typeof(require("../input/keys")) = import("input/keys")
local Layout: typeof(require("./layout")) = import("ui/layout")
local Motion: typeof(require("./motion")) = import("ui/motion")
local Overlays: typeof(require("./overlays")) = import("ui/overlays")
local Overlay: typeof(require("./overlay")) = import("ui/overlay")
local Painter: typeof(require("./painter")) = import("ui/painter")
local Palette: typeof(require("./palette")) = import("ui/palette")
local Panels: typeof(require("./panels")) = import("ui/panels")
local Settings: typeof(require("../state/settings")) = import("state/settings")
local Skyfx: typeof(require("./skyfx")) = import("ui/skyfx")
local Util: typeof(require("../core/util")) = import("core/util")
local Welcome: typeof(require("./welcome")) = import("ui/welcome")
local WindowBlock: typeof(require("../input/window")) = import("input/window")

local Runner = {}

type App = { [string]: any }

local MENU_TOGGLE_DELAY = 0.35
local TYPING_INTERVAL = 0.1
local CAMERA_INTERVAL = 0.5
local STARTUP_DELAY = 0.1
local UI_SAVE_INTERVAL = 0.5
local LEAN_EVERY = 3
local MOTION_DT = 1 / 30
local HALO_ALPHA = 0.23
local PRELOAD_LIMIT = 30
local HOLD_ANSWER = 1
local HOLD_LIMIT = 4

local function clamp01(value: number): number
    return math.clamp(value, 0, 1)
end

local userInput: any = nil

local function input(): any
    if not userInput then
        userInput = game:GetService("UserInputService")
    end
    return userInput
end

local function liveMouse(app: App): Vector2
    local ok, position = pcall(function()
        return input():GetMouseLocation()
    end)
    if ok and position then
        return position
    end
    return app.Mouse
end

local function leftDown(): boolean
    local ok, down = pcall(function()
        return input():IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    end)
    return ok and down == true
end

local function rightDown(): boolean
    local ok, down = pcall(function()
        return input():IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end)
    return ok and down == true
end

local function refreshCamera(app: App, now: number)
    if now < app.NextCamera then
        return
    end
    app.NextCamera = now + CAMERA_INTERVAL
    local camera = Util.read(workspace, "CurrentCamera")
    if camera then
        app.Camera = camera
        local size = Util.read(camera, "ViewportSize")
        if size then
            app.Viewport = size
        end
    end
end

local FAREWELL_HOLD = 1.35

local function updateGeometry(app: App, now: number, dt: number)
    local state = app.State
    local m = app.M
    Painter.setCorner(tonumber(state.Roundness) or Settings.DEFAULT_ROUNDNESS)
    local scaleGoal: number? = app.ScaleGoal
    if scaleGoal and app.Recentering and app.Viewport.X > 0 then
        local viewport = app.Viewport
        local goal = math.max(0.10, math.min(scaleGoal, (viewport.X - 36) / app.M.Width, (viewport.Y - 36) / app.M.Height))
        local eased = Motion.ease(state, tonumber(state.UIScale) or goal, goal, math.min(dt, MOTION_DT), 9)
        state.UIScale = if math.abs(eased - goal) < 0.002 then goal else eased
        app.ScaleReached = state.UIScale == goal
    end
    local requested = math.max(0.10, tonumber(state.UIScale) or Settings.defaultScale())
    state.UIScale = requested
    local widthGoal: number? = app.WidthGoal
    if widthGoal and m.Width ~= widthGoal then
        local before = m.Width
        local eased = Motion.ease(state, before, widthGoal, math.min(dt, MOTION_DT), 9)
        m.Width = if math.abs(eased - widthGoal) < 0.5 then widthGoal else eased
        local shift = (m.Width - before) * requested / 2
        app.MenuPos -= Vector2.new(shift, 0)
        app.TargetPos -= Vector2.new(shift, 0)
    end
    local menuSize = Vector2.new(m.Width, m.Height) * requested
    app.MenuSize = menuSize
    app.Scale = menuSize.X / m.Width

    if not app.Centered and app.Viewport.X > 0 then
        local viewport = app.Viewport
        local fit = math.min((viewport.X - 36) / m.Width, (viewport.Y - 36) / m.Height)
        state.UIScale = math.max(0.10, math.min(state.UIScale, fit))
        menuSize = Vector2.new(m.Width, m.Height) * state.UIScale
        app.MenuSize = menuSize
        app.Scale = menuSize.X / m.Width
        app.MenuPos = Vector2.new(math.floor(viewport.X / 2 - menuSize.X / 2), math.floor(viewport.Y / 2 - menuSize.Y / 2))
        app.TargetPos = app.MenuPos
        app.Centered = true
    end

    if app.Recentering and app.Centered and app.Viewport.X > 0 then
        local viewport = app.Viewport
        app.TargetPos = Vector2.new(math.floor(viewport.X / 2 - menuSize.X / 2), math.floor(viewport.Y / 2 - menuSize.Y / 2))
        local scaleDone = app.ScaleGoal == nil or app.ScaleReached == true
        if scaleDone and (app.MenuPos - app.TargetPos).Magnitude < 1 then
            app.Recentering, app.ScaleGoal = nil, nil
        end
    end

    local motion = math.min(dt, MOTION_DT)
    if app.RevealStart then
        if not app.RevealHold then
            app.RevealTime = (app.RevealTime or 0) + motion * (app.RevealSpeed or 1)
        end
        local elapsed = app.RevealTime
        state.VisibilityAnim = 1
        state.IntroAlpha = 1
        state.NavReveal = math.clamp((elapsed - 0.06) / 0.72, 0, 1)
        state.TabReveal = math.clamp((elapsed - 0.12) / 0.66, 0, 1)
        local visual = math.clamp((elapsed - 0.08) / 0.72, 0, 1)
        app.WelcomeVisual = visual * visual * (3 - 2 * visual)
        local card = app.HandoffCard
        if card then
            local settle = math.clamp((elapsed - 0.08) / 0.9, 0, 1)
            card.Settle = settle * settle * (3 - 2 * settle)
        end
        if elapsed >= 2.22 then
            app.RevealStart, app.RevealSpeed, app.RevealTime = nil, nil, nil
            app.WelcomeVisual = 1
            app.HandoffCard = nil
        end
    else
        local shownWindow = state.Visible and app.FarmOn ~= true
        state.VisibilityAnim = Motion.ease(state, state.VisibilityAnim, if shownWindow then 1 else 0, motion, if shownWindow then 12 else 18)
        state.IntroAlpha = clamp01(state.VisibilityAnim)
    end

    local opening = state.Visible == true and app.FarmOn ~= true
    local open = clamp01(Motion.spring(state, app.Springs, "open", if opening then 1 else 0, motion, if opening then 0.45 else 0.25, 1))
    state.UIScaleAnim = 0.86 + 0.14 * open

    local previous = app.MenuPos
    local follow = 1 - math.exp(-22 * dt)
    app.MenuPos = Util.lerpVector2(app.MenuPos, app.TargetPos, follow)
    if (app.TargetPos - app.MenuPos).Magnitude < 0.45 then
        app.MenuPos = app.TargetPos
    end
    local velocity = app.MenuPos - previous
    app.Moving = Hits.heldKey() == "window:drag" or math.abs(velocity.X) + math.abs(velocity.Y) > 0.25

    local animated = state.UIScaleAnim
    local current = app.MenuSize * animated
    local origin = app.MenuPos + app.MenuSize / 2 - current / 2
    origin = Vector2.new(math.floor(origin.X + 0.5), math.floor(origin.Y + 0.5))
    current = Vector2.new(math.floor(current.X + 0.5), math.floor(current.Y + 0.5))
    app.WindowPos = origin
    app.WindowSize = current
    app.Unit = app.Scale * animated

    local farewell = app.Farewell
    if farewell and not farewell.Done then
        if farewell.Start == 0 then
            farewell.Start = now
            if farewell.Kind == "reload" then
                local requestedScale = tonumber(app.Options.Scale)
                app.ScaleGoal = if requestedScale then math.max(0.10, requestedScale) else Settings.defaultScale()
                app.Recentering = true
            end
        end
        local elapsed = now - farewell.Start
        local fade = clamp01((elapsed - 0.05) / 0.40)
        app.WelcomeVisual = 1 - fade * fade * (3 - 2 * fade)
        if farewell.Kind == "unload" then
            if elapsed >= FAREWELL_HOLD then
                app:finishFarewell()
            end
        else
            if not farewell.ReadyAt and ((not app.Recentering and elapsed >= 0.9) or elapsed >= 3) then
                farewell.ReadyAt = now
            end
            if farewell.ReadyAt and now - farewell.ReadyAt >= 0.45 then
                app:finishFarewell()
            end
        end
    end
    local intro = state.IntroAlpha
    local visual = app.WelcomeVisual
    app.Alpha.Frame = math.clamp((if state.Transparent then state.UITrans else 1) * intro, 0, 1)
    app.Alpha.UI = app.Alpha.Frame * visual
    local clear = if app.NavAnim then app.NavAnim["sky:glass"] else nil
    local glassBtn = if type(clear) == "number" and clear > 0.004 then 1 - clear * (1 - (state.LightAlpha or 0)) * (1 - (app.SkyButtons or math.clamp((app.SkyGlass or 1) + 0.2, 0, 1))) else 1
    app.Alpha.Btn = math.clamp((if state.Transparent then state.ButtonTrans else 1) * intro * visual * glassBtn, 0, 1)
    app.Alpha.Text = math.clamp((intro - 0.35) * 1.54, 0, 1) * visual
    app.FarmAlpha = {
        UI = math.clamp(if state.Transparent then state.UITrans else 1, 0, 1) * visual,
        Btn = math.clamp(if state.Transparent then state.ButtonTrans else 1, 0, 1) * visual,
        Text = visual,
    }
    app.Pal = Palette.compute(state, dt)

    local font = tonumber(state.UIFont) or Fonts.DEFAULT
    Painter.setFont(font)
    app.TextScale = Util.finite(math.max(app.Scale, 0.95) * animated * Fonts.scale(font), 1)
    app.FarmTextScale = Util.finite(math.max(app.Scale, 0.95) * Fonts.scale(font), 1)
end

local function updateTabs(app: App, dt: number)
    local state = app.State
    if state.AnimationsEnabled then
        local speed = 14 * Motion.speed(state)
        if state.NextTab or state.NextSection then
            state.TabFading = state.TabFading or state.NextTab ~= nil
            state.TabAlpha = Motion.ease(state, state.TabAlpha, 0, dt, speed * 2.2)
            if state.TabAlpha < 0.03 then
                if state.NextSection then
                    state.SectionByTab[state.CurrentTab] = state.NextSection
                    state.NextSection = nil
                end
                state.SectionSwap = state.NextTab == nil
                if state.NextTab then
                    state.CurrentTab = state.NextTab
                    state.NextTab = nil
                end
                state.TabReveal = 0
                state.TabAlpha = 1
                state.TabFading = false
            end
        elseif state.TabAlpha < 1 then
            state.TabAlpha = Motion.ease(state, state.TabAlpha, 1, dt, speed * 2.2)
            if state.TabAlpha > 0.997 then
                state.TabAlpha = 1
                state.TabFading = false
            end
        end
        if not app.RevealStart then
            local step = if state.HighPerformanceMode then 1 else dt * Motion.intensity(state) / 0.62
            state.TabReveal = math.min(1, (state.TabReveal or 0) + step)
            state.NavReveal = math.min(1, (state.NavReveal or 0) + step)
        end
        if state.SectionSwap and state.TabReveal >= 1 then
            state.SectionSwap = false
        end
    else
        if state.NextSection then
            state.SectionByTab[state.CurrentTab] = state.NextSection
            state.NextSection = nil
        end
        if state.NextTab then
            state.CurrentTab = state.NextTab
            state.NextTab = nil
        end
        state.SectionSwap, state.TabFading = false, false
        state.TabAlpha, state.TabReveal, state.NavReveal = 1, 1, 1
    end
    state.TogglePulse = Motion.ease(state, state.TogglePulse, 0, dt, 7 * Motion.speed(state))
end

local function handleKeys(app: App, now: number)
    local state = app.State
    local down = Keys.pressed(true)
    local fresh: { [string]: boolean } = {}
    for key in down do
        if not app.PreviousKeys[key] then
            fresh[key] = true
        end
    end
    local captured = Keys.findNew(down, app.PreviousKeys)
    app.PreviousKeys = down
    if next(fresh) == nil then
        return
    end

    if state.Visible and app:isCapturing() and captured then
        local clear = captured == "Escape" or captured == "Backspace" or captured == "Delete"
        app:finishCapture(if clear then "None" else captured)
        return
    end
    local blocked = app.Focus ~= nil or Hits.busy() or app.Popup.Name ~= "None" or app.OpenDropdown ~= nil
        or app.ChatTyping
    if blocked then
        return
    end
    local menuKey = Keys.normalize(state.Keybind)
    if menuKey ~= "" and menuKey ~= "None" and fresh[menuKey] then
        if now - app.LastToggle > MENU_TOGGLE_DELAY then
            app.LastToggle = now
            state.Visible = not state.Visible
            if not state.Visible then
                app.Focus = nil
                Hits.cancel()
                WindowBlock.setBlocked(false)
            end
        end
        return
    end
    local fired: { [string]: boolean } = {}
    for flag, keyName in state.OptionKeybinds do
        local key = Keys.normalize(keyName)
        if key ~= "" and key ~= "None" and fresh[key] and not fired[flag] then
            fired[flag] = true
            app:triggerBind(flag)
        end
    end
end

local function updateSlow(app: App, now: number)
    if now >= app.NextTyping then
        app.NextTyping = now + TYPING_INTERVAL
        local isTyping = app.Options.IsTyping or Chat.isTyping
        app.ChatTyping = app.Focus == nil and isTyping() == true
    end
end

local function runFrameHooks(app: App)
    if #app.FrameHooks == 0 or app.FarmOn == true then
        return
    end
    local frame = {
        Camera = app.Camera,
        Mouse = app.Mouse,
        Viewport = app.Viewport,
        Delta = app.Dt,
        Now = app.Now,
        Visible = app.State.Visible,
        Canvas = Canvas,
    }
    for _, hook in app.FrameHooks do
        pcall(hook, frame)
    end
end

local function updateWindowBlock(app: App)
    local state = app.State
    local mouse = app.Mouse
    local panelsOpen = Panels.anyOpen(app)
    local blockAt, blockSize = app.WindowPos, app.WindowSize
    if Farm.shown(app) and app.FarmBox then
        blockAt, blockSize = app.FarmBox[1], app.FarmBox[2]
    end
    local over = Util.contains(mouse, blockAt, blockSize)
    if not over then
        local panelAt, panelSize = Panels.at(app, mouse)
        if panelAt and panelSize then
            over, blockAt, blockSize = true, panelAt, panelSize
        end
    end
    local menuShown = state.Visible and state.VisibilityAnim > 0.05
    local enabled = (menuShown or panelsOpen) and not app.Suspended
    local block = false
    if enabled then
        if Hits.busy() then
            block = true
        elseif over then
            local steering = app.Focus == nil and WindowBlock.playerIsPlaying(app.PreviousKeys)
            block = not steering
        end
    end
    WindowBlock.setBlocked(block, blockAt, blockSize, enabled and (over or Hits.busy()))
end

local function drawFarewellLogo(app: App, now: number)
    local farewell = app.Farewell
    if not farewell or farewell.Start == 0 then
        return
    end
    local elapsed = now - farewell.Start
    local mix = clamp01((elapsed - 0.20) / 0.50)
    mix = mix * mix * (3 - 2 * mix)
    local alpha = mix * app.Alpha.Frame
    if farewell.ReadyAt then
        local gone = clamp01((now - farewell.ReadyAt) / 0.35)
        alpha = alpha * (1 - gone * gone * (3 - 2 * gone))
    end
    if alpha <= 0.002 then
        return
    end
    local size: Vector2 = app.WindowSize
    local middle = app.WindowPos + size / 2
    local breathe = (0.82 + 0.18 * mix) * (1 + 0.02 * math.sin(elapsed * 3))
    local halo = Skyfx.halo()
    if halo then
        local swell = clamp01((elapsed - 0.25) / 0.8)
        swell = swell * swell * (3 - 2 * swell)
        local pulse = 1 + 0.035 * math.sin(elapsed * 2.4)
        local side = math.min(size.X, size.Y) * 0.34 * 1.71 * breathe * (0.9 + 0.1 * swell) * pulse
        local strength = HALO_ALPHA * swell * (0.92 + 0.08 * math.sin(elapsed * 2.4 + 0.6))
        Painter.fine(true)
        Painter.image(halo, middle - Vector2.new(side, side) / 2, Vector2.new(side, side), alpha * strength, 30)
        Painter.fine(false)
    end
    local logo: string? = app.LogoAsset
    if logo then
        local side = math.min(size.X, size.Y) * 0.34 * breathe
        local box = Vector2.new(side, side)
        local emblem = app.Options.Logo ~= nil and app.Options.Logo.Emblem == true
        if emblem then
            Painter.image(logo, middle - box / 2, box, alpha, 30, 0, app.Pal.Accent)
        else
            Painter.image(logo, middle - box / 2, box, alpha, 30, side * 0.22)
        end
    else
        Painter.text(string.lower(string.sub(app.Options.Title, 1, 1)), middle, 80 * app.Unit * breathe, app.Pal.Text, alpha, 30, true, true)
    end
end

local function drawWindow(app: App, now: number)
    local state = app.State
    local m = app.M
    app.Modal = app.Popup.Name ~= "None" or app.OpenDropdown ~= nil

    Hits.add({
        key = "window:drag",
        position = app.WindowPos,
        size = app:size(m.Width, 54),
        press = function(mouse: Vector2)
            app.DragOffset = app.MenuPos - mouse
            app.Recentering, app.ScaleGoal = nil, nil
        end,
        drag = function(mouse: Vector2)
            if state.LockPosition then
                return
            end
            app.TargetPos = mouse + app.DragOffset
        end,
    })

    local tab = app:currentTab()
    local index = Layout.activeIndex(app, tab)
    local section = tab.sections[index]
    local typed = Chrome.query(app)
    if typed ~= "" and not tab.ownSearch then
        section = Layout.results(app, typed, Chrome.clearSearch)
    end
    local baseText = app.Alpha.Text
    local behind = 1 - 0.92 * clamp01(app.Popup.Alpha)
    app.Alpha.Text = baseText * behind
    Painter.fine(state.UIScaleAnim < 0.999)
    local x, y, width, bottom = Chrome.draw(app, now, tab, section, index)
    Layout.draw(app, section, x, y, width, bottom)
    Painter.fine(false)
    drawFarewellLogo(app, now)

    if tab.meteors and not app.Boot then
        local reveal = Motion.out(if state.AnimationsEnabled then math.clamp(state.TabReveal, 0, 1) else 1)
        Effects.meteors(state, now, app.ContentBox, app.Scale, app.Alpha.Text * state.TabAlpha * math.min(1, reveal * 1.4), app.Pal.Text)
    end
    app.Alpha.Text = baseText
    Painter.scope("overlay:dropdown")
    Overlays.drawDropdown(app)
    Painter.scope("overlay:popup")
    Overlays.drawPopup(app, now)
    Painter.scope(nil)
end

local function processInput(app: App)
    local state = app.State
    local mouse = app.Mouse
    local active = not app.Suspended
    local down = active and leftDown()
    local pressed = down and not app.WasDown
    local released = app.WasDown and not down
    app.WasDown = down
    app.LeftDown = down
    local wheel: number = app.WheelPending or 0
    app.WheelPending = 0
    if app.Welcome or app.Farewell or not state.Visible and state.VisibilityAnim < 0.5 and not Panels.anyOpen(app) then
        return
    end
    if wheel ~= 0 and active then
        Hits.wheel(mouse, wheel)
    end
    local right = active and rightDown()
    if right and not app.WasRight then
        Hits.rightClick(mouse)
    end
    app.WasRight = right
    if pressed then
        if state.ClickSound and app.HoverKey ~= nil and app.HoverKey ~= "window:drag" then
            Overlay.click(app)
        end
        local onSearch = app.Focus == "head:search" and type(app.HoverKey) == "string" and string.sub(app.HoverKey, 1, 11) == "head:search"
        if app.Focus and not app:isCapturing() and not onSearch then
            app.Typing:apply()
        end
        Hits.press(mouse)
    elseif down then
        Hits.hold(mouse)
    end
    if released then
        Hits.release(mouse)
    end
end

local BOOT_SECONDS = 0.5
local BOOT_LIMIT = 2.5

local function bootDone(app: App, now: number): boolean
    local boot = app.Boot
    if not boot or now - boot.Start < BOOT_SECONDS then
        return false
    end
    return boot.Loaded or now - boot.Start >= BOOT_LIMIT
end

local function snapColors(app: App)
    local state = app.State
    for key in Settings.COLOR_KEYS do
        local target = state["Target_" .. key]
        if target then
            state[key] = target
        end
    end
    state.LightAlpha = if state.LightMode then 1 else 0
    state.PaletteShown = nil
end

local function finishBoot(app: App)
    local state = app.State
    state.VisibilityAnim, state.IntroAlpha = 0, 0
    state.NavReveal, state.TabReveal = 0, 0
    app.Springs.open = { x = 0, v = 0 }
    snapColors(app)
    local welcome = app.Welcome
    if welcome then
        welcome.Start, welcome.Fade, welcome.Hover = 0, 0, 0
    end
    app.Boot = nil
end

local function present(revealing: boolean)
    Painter.finish()
    Canvas.finish()
    if revealing then
        Draw.setEnabled(true)
    end
end

local function leanStep(app: App, now: number)
    app.Dt, app.Now = math.min(now - app.LastNow, 0.05), now
    Canvas.begin()
    refreshCamera(app, now)
    Canvas.setCamera(app.Camera)
    runFrameHooks(app)
    Canvas.finish()
end

function Runner.step(app: App, now: number)
    local state = app.State
    if app.Unfocused and not app.Boot and not app.Welcome then
        app.LeanTick = (app.LeanTick + 1) % LEAN_EVERY
        if app.LeanTick ~= 0 then
            leanStep(app, now)
            return
        end
    end
    local dt = math.min(now - app.LastNow, 0.05)
    app.LastNow = now
    app.Dt, app.Now = dt, now

    Hits.begin()
    Painter.begin()
    Canvas.begin()

    local revealing = bootDone(app, now)
    if revealing then
        finishBoot(app)
    end
    app.Mouse = liveMouse(app)
    app.HoverKey = Hits.hover(app.Mouse)
    refreshCamera(app, now)
    Canvas.setCamera(app.Camera)
    Palette.glide(state, Settings.COLOR_KEYS, dt)
    app:flushTheme()
    if app.Handoff and app.Viewport then
        app.Handoff = nil
        snapColors(app)
        local cardScale = if type(app.CardLook) == "table" then tonumber(app.CardLook.Scale) else nil
        local savedScale = state.UIScale
        Welcome.handoff(app, cardScale)
        if cardScale and math.abs((tonumber(savedScale) or cardScale) - cardScale) > 0.002 then
            app.PendingScale = savedScale
        end
        app.RevealStart = now
        app.RevealTime = 0
        app.RevealSpeed = 0.7
        app.RevealHold = { Since = now, Frames = 0, Signaled = nil }
        local look = app.CardLook
        app.CardLook = nil
        app.HandoffCard = {
            Main = if type(look) == "table" then look.Main else nil,
            Accent = if type(look) == "table" then look.Accent else nil,
            Spin = if type(look) == "table" then look.Spin else nil,
            Radius = if type(look) == "table" then look.Radius else nil,
            Settle = 0,
        }
        Painter.warm(true)
    end
    local waiting = app.PreloadWait ~= nil
    if waiting and (getgenv().__OkloReveal == true or now - app.PreloadWait > PRELOAD_LIMIT) then
        getgenv().__OkloReveal = nil
        app.PreloadWait, waiting = nil, false
        snapColors(app)
        app.PreviousKeys = Keys.pressed(true)
        Draw.setEnabled(true)
    end
    local hold = app.RevealHold
    if hold then
        local answer = getgenv().__OkloDrawn
        if waiting then
            hold.Since = now
        elseif answer == "gone" or (hold.Signaled and now - hold.Signaled > HOLD_ANSWER) or now - hold.Since > HOLD_LIMIT then
            app.RevealHold = nil
            Painter.warm(false)
            if app.PendingScale then
                app.ScaleGoal, app.Recentering, app.PendingScale = app.PendingScale, true, nil
            end
            if answer ~= nil then
                getgenv().__OkloDrawn = nil
            end
        end
    end
    local booting = app.Boot ~= nil or waiting
    if not booting then
        processInput(app)
    end
    updateGeometry(app, now, dt)
    updateTabs(app, dt)

    if app.Welcome then
        Painter.scope("welcome")
        local covered = Welcome.render(app, now)
        Painter.scope(nil)
        if covered then
            present(revealing)
            return
        end
        updateGeometry(app, now, 0)
    end

    if not app.Welcome and not waiting and state.Visible and state.UpdateNoticePending and not state.UpdateNoticeOpened and app.Popup.Name == "None" then
        state.UpdateNoticeOpened = true
        app.LastClick = nil
        app:openPopup("updateNotice")
    end

    if not app.Welcome and not waiting and state.Visible and state.ThanksPending and not state.ThanksOpened and not state.UpdateNoticePending and app.Popup.Name == "None" then
        state.ThanksOpened = true
        app.LastClick = nil
        app:openPopup("thanks")
    end

    updateSlow(app, now)
    if not booting then
        handleKeys(app, now)
    end
    runFrameHooks(app)
    app.Typing:step(now)

    if state.IntroAlpha > 0.001 then
        drawWindow(app, now)
    end
    if Farm.shown(app) then
        Farm.draw(app, now)
    end
    Panels.draw(app)
    if not booting then
        Overlay.draw(app, now)
        updateWindowBlock(app)
        if now >= app.NextUiSave then
            app.NextUiSave = now + UI_SAVE_INTERVAL
            app:flushUi()
        end
    end
    present(revealing)
    local drawn = app.RevealHold
    if drawn and not waiting and not drawn.Signaled then
        drawn.Frames += 1
        if drawn.Frames >= 2 then
            drawn.Signaled = now
            getgenv().__OkloDrawn = true
        end
    end
end

local function watchFocus(app: App): { any }
    local connections: { any } = {}
    local function released()
        app.Unfocused = true
        Hits.cancel()
        app.Focus = nil
        app.WasDown = false
        WindowBlock.setBlocked(false)
    end
    local function regained()
        app.Unfocused = false
        app.PreviousKeys = Keys.pressed(true)
        app.Typing:reset()
    end
    pcall(function()
        local service = game:GetService("UserInputService")
        connections[#connections + 1] = service.WindowFocusReleased:Connect(released)
        connections[#connections + 1] = service.WindowFocused:Connect(regained)
    end)
    return connections
end

function Runner.start(app: App): () -> ()
    local running = true
    app.Springs.open = { x = 0, v = 0 }
    app.LastNow = os.clock()
    app.NextCamera, app.NextTyping = 0, 0
    app.LastToggle = 0
    app.NextUiSave, app.LeanTick, app.Unfocused = 0, 0, false
    app.ChatTyping = false
    app.PreviousKeys = Keys.pressed(true)
    app.WasDown = false
    app.DragOffset = Vector2.new(0, 0)
    app.WelcomeVisual = 1
    app.Handoff = getgenv().__OkloHandoff == true
    getgenv().__OkloHandoff = nil
    getgenv().__OkloDrawn = nil
    if not app.Handoff and getgenv().__OkloPreload == true then
        getgenv().__OkloPreload = "built"
        app.Handoff = true
        app.PreloadWait = os.clock()
    end
    local cardLook = getgenv().__OkloCard
    getgenv().__OkloCard = nil
    app.CardLook = if app.Handoff and type(cardLook) == "table" then cardLook else nil
    if not app.Handoff and Welcome.pending(app) then
        app.Welcome = Welcome.new()
        app.WelcomeVisual = 1
    end
    app:applyFont()
    if not app.Handoff then
        app.Boot = { Start = os.clock(), Loaded = false }
    end
    Draw.setEnabled(app.Handoff == true and not app.PreloadWait)
    task.spawn(function()
        task.wait(BOOT_SECONDS * 0.6)
        pcall(function()
            game:GetService("ContentProvider"):PreloadAsync({ Draw.root() })
        end)
        local boot = app.Boot
        if boot then
            boot.Loaded = true
        end
    end)
    Logo.start(app)
    Logo.startIcons(app)

    local connection = nil
    pcall(function()
        connection = game:GetService("RunService").RenderStepped:Connect(function()
            if not running or app.Suspended then
                return
            end
            local ok, problem = pcall(Runner.step :: any, app, os.clock())
            if not ok then
                if problem ~= app.LastProblem then
                    app.LastProblem = problem
                    warn("[OkloUI] frame error: " .. tostring(problem))
                end
                Painter.finish()
                Canvas.finish()
            end
        end)
    end)
    local focusConnections = watchFocus(app)
    pcall(function()
        focusConnections[#focusConnections + 1] = game:GetService("UserInputService").InputChanged:Connect(function(change: any)
            if change.UserInputType == Enum.UserInputType.MouseWheel then
                app.WheelPending = (app.WheelPending or 0) + change.Position.Z
            end
        end)
    end)

    task.delay(STARTUP_DELAY, function()
        if running then
            pcall(app.loadStartupConfig, app)
        end
    end)

    return function()
        running = false
        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end
        for _, link in focusConnections do
            pcall(function()
                link:Disconnect()
            end)
        end
        app.Typing:destroy()
        pcall(app.flushUi, app)
        Overlay.destroy(app)
        Canvas.clear()
        Painter.hideAll()
        WindowBlock.setBlocked(false)
    end
end

return Runner
end
modules["ui/sky"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")
local Motion: typeof(require("./motion")) = import("ui/motion")
local Painter: typeof(require("./painter")) = import("ui/painter")
local Skyfx: typeof(require("./skyfx")) = import("ui/skyfx")

local Sky = {}

type App = { [string]: any }

local Z_FRAME = 1
local SKY_FADE_SPEED = 2.4
local SKY_LEAVE_SPEED = 6
local GLASS_VEIL = 0.85
local STOPS = 20

local skyFx: string? = nil

local skyNow = 0
local skyCycle: { Color3 }? = nil
local skyFlow = 0
local skyReach = 1
local skyDrift = 0
local skySwell = 1
local skyRate, skySwing, skySwingSpeed = 0.03, 0.3, 0.11
local skyBend, skyBendSpeed, skyFreq = 0.1, 0.47, 1
local skyGlow, skyScale = 0.07, 0.85
local skyBeat, skyBeatSpeed, skyPulse = 0, 0, 0
local skyShade = 1
local skyPhase, skyFlip, skyWay = 0, false, 1
local skyAngle = 0
local skyBaseR, skyBaseG, skyBaseB = 0, 0, 0
local skyTopR, skyTopG, skyTopB = 0, 0, 0

local ringPoints: { [{ Color3 }]: { number } } = setmetatable({}, { __mode = "k" }) :: any

local function ringControls(cycle: { Color3 }): { number }
    local known = ringPoints[cycle]
    if known then
        return known
    end
    local count = #cycle
    local points: { number } = table.create(count * 3, 0)
    for index, color in cycle do
        points[index * 3 - 2], points[index * 3 - 1], points[index * 3] = color.R, color.G, color.B
    end
    for _ = 1, 40 do
        for index, color in cycle do
            local before, after = (index - 2) % count + 1, index % count + 1
            points[index * 3 - 2] = (6 * color.R - points[before * 3 - 2] - points[after * 3 - 2]) / 4
            points[index * 3 - 1] = (6 * color.G - points[before * 3 - 1] - points[after * 3 - 1]) / 4
            points[index * 3] = (6 * color.B - points[before * 3] - points[after * 3]) / 4
        end
    end
    ringPoints[cycle] = points
    return points
end

local function ringAt(cycle: { Color3 }, position: number): (number, number, number)
    local points = ringControls(cycle)
    local count = #cycle
    local wrapped = position % count
    local index = math.floor(wrapped)
    local t = wrapped - index
    local i0, i1 = (index - 1) % count * 3, index * 3
    local i2, i3 = (index + 1) % count * 3, (index + 2) % count * 3
    local t2 = t * t
    local t3 = t2 * t
    local u = 1 - t
    local a = u * u * u / 6
    local b = (3 * t3 - 6 * t2 + 4) / 6
    local c = (-3 * t3 + 3 * t2 + 3 * t + 1) / 6
    local d = t3 / 6
    return math.clamp(a * points[i0 + 1] + b * points[i1 + 1] + c * points[i2 + 1] + d * points[i3 + 1], 0, 1),
        math.clamp(a * points[i0 + 2] + b * points[i1 + 2] + c * points[i2 + 2] + d * points[i3 + 2], 0, 1),
        math.clamp(a * points[i0 + 3] + b * points[i1 + 3] + c * points[i2 + 3] + d * points[i3 + 3], 0, 1)
end

local function skyPrepare(now: number)
    skyNow = now
    skyDrift = skyWay * skyRate * now + skySwing * math.sin(now * skySwingSpeed) + skySwing * 0.3 * math.sin(now * skySwingSpeed * 2.45 + 1.7) + skySwing * 0.13 * math.sin(now * skySwingSpeed * 4.8 + 0.4)
    skySwell = 0.75 + 0.25 * math.sin(now * 0.05 + 0.6)
    skyPulse = skyBeat * math.sin(now * skyBeatSpeed)
end

local function skyColor(level: number, shift: number?, tone: number?): Color3
    level = math.clamp(level, 0, 1)
    local mixed = tone or level
    local shaded = mixed * skyShade
    local r = skyBaseR + (skyTopR - skyBaseR) * shaded
    local g = skyBaseG + (skyTopG - skyBaseG) * shaded
    local b = skyBaseB + (skyTopB - skyBaseB) * shaded
    local cycle = skyCycle
    if cycle and skyFlow > 0 then
        local now = skyNow
        local wave = if skyFlip then 1 - level else level
        local bend = skySwell * (skyBend * math.sin(wave * 5.2 * skyFreq + now * skyBendSpeed) + skyBend * 0.45 * math.sin(wave * 11.3 * skyFreq - now * skyBendSpeed * 1.72 + 2.1))
        local fr, fg, fb = ringAt(cycle, (wave * skyScale + skyDrift + bend + skyPhase + (shift or 0)) * #cycle)
        local glow = 3 * (skyGlow * math.sin(wave * 3.1 - now * 0.11 + 0.8) + skyGlow * 0.43 * math.sin(wave * 7.3 + now * 0.17) + skyPulse)
        fr, fg, fb = fr + glow * fr * (1 - fr), fg + glow * fg * (1 - fg), fb + glow * fb * (1 - fb)
        local mix = (0.62 + 0.06 * mixed) * skyReach
        fr, fg, fb = skyBaseR + (fr - skyBaseR) * mix, skyBaseG + (fg - skyBaseG) * mix, skyBaseB + (fb - skyBaseB) * mix
        r, g, b = r + (fr - r) * skyFlow, g + (fg - g) * skyFlow, b + (fb - b) * skyFlow
    end
    return Color3.new(r, g, b)
end

local stops: { Color3 } = {}

local function skyGradient(position: Vector2, size: Vector2, base: Color3, top: Color3, alpha: number, baseAlpha: number, z: number, rounding: number, cycle: { Color3 }?, flow: number, reach: number)
    if alpha <= 0.004 and baseAlpha <= 0.004 then
        return
    end
    Painter.rect(position, size, base, baseAlpha, z, rounding)
    if alpha <= 0.004 then
        return
    end
    skyCycle, skyFlow, skyReach = cycle, if cycle then flow else 0, reach
    skyBaseR, skyBaseG, skyBaseB = base.R, base.G, base.B
    skyTopR, skyTopG, skyTopB = top.R, top.G, top.B
    local angle = if skyFlow > 0 then skyAngle else math.pi * 0.5
    local peak = 0
    for index = 1, STOPS do
        local level = (index - 1) / (STOPS - 1)
        local color = skyColor(if skyFlow > 0 then level else 1 - level)
        stops[index] = color
        peak = math.max(peak, color.R, color.G, color.B)
    end
    local lift = math.clamp(math.ceil(peak * 50) / 50, 0.04, 1)
    if lift < 1 then
        for index = 1, STOPS do
            local color = stops[index]
            stops[index] = Color3.new(math.min(color.R / lift, 1), math.min(color.G / lift, 1), math.min(color.B / lift, 1))
        end
        local faint = alpha * lift
        Painter.rect(position, size, Color3.new(0, 0, 0), (alpha - faint) / (1 - faint), z, rounding)
        Painter.gradient(position, size, stops, math.deg(angle), faint, z, rounding)
        return
    end
    Painter.gradient(position, size, stops, math.deg(angle), alpha, z, rounding)
end

local function ease(app: App, key: string, goal: number, speed: number): number
    local value = Motion.ease(app.State, app.NavAnim[key] or goal, goal, app.Dt, speed)
    app.NavAnim[key] = value
    return value
end

type Sky = { Sky: Color3?, Cycle: { Color3 }?, Flow: number, Glass: number, Clear: number, Veil: number }

local function rollSky(): { [string]: any }
    pcall(math.randomseed, math.floor(os.clock() * 100000) + os.time())
    return {
        Phase = math.random(),
        Flip = math.random() < 0.5,
        Way = if math.random() < 0.5 then 1 else -1,
        Angle = math.random() * math.pi * 2,
    }
end

local function skyOf(app: App): Sky
    local state = app.State
    local preset = state.ThemePreset
    local sky: Color3?, live: { Color3 }?, glass: number? = nil, nil, nil
    if state.ThemeName ~= "Custom" and type(preset) == "table" then
        sky = preset.Sky
        local cycle = preset.Cycle
        if type(cycle) == "table" and #cycle >= 2 then
            if state.HighPerformanceMode then
                if sky then
                    sky = Color.lerp(preset.Main, sky, 0.4)
                end
            else
                live = cycle
            end
        end
        if type(preset.Glass) == "number" then
            glass = math.clamp(preset.Glass, 0.05, 1)
            local buttons = preset.Buttons
            app.SkyButtons = if type(buttons) == "number" then math.clamp(buttons, 0.2, 1) else math.clamp(glass + 0.2, 0, 1)
        end
    end
    local shown = app.SkyShown
    local leaving = shown ~= nil and shown ~= preset and (app.NavAnim["sky:flow"] or 0) > 0.02
    if live and not leaving then
        if app.SkyShown ~= preset or app.SkyRoll == nil then
            app.SkyRoll = rollSky()
        end
        shown = preset
        app.SkyShown = preset
    end
    skyFx = nil
    local rolled = app.SkyRoll
    if rolled then
        skyPhase, skyFlip, skyWay, skyAngle = rolled.Phase, rolled.Flip, rolled.Way, rolled.Angle
    end
    if type(shown) == "table" then
        local motion = shown.Motion
        if type(motion) == "table" then
            skyRate, skySwing, skySwingSpeed = motion.Rate or 0.03, motion.Swing or 0.3, motion.SwingSpeed or 0.11
            skyBend, skyBendSpeed, skyFreq = motion.Bend or 0.1, motion.BendSpeed or 0.47, motion.Freq or 1
            skyGlow, skyScale = motion.Glow or 0.07, motion.Scale or 0.85
            skyBeat, skyBeatSpeed = motion.Beat or 0, motion.BeatSpeed or 0
        end
        if type(shown.Fx) == "string" then
            skyFx = shown.Fx
        end
    end
    if glass then
        app.SkyGlass = glass
    end
    local fading = app.NavAnim["sky:shade"] or 0
    local flowGoal = if live and not leaving and fading <= 0.02 then 1 else 0
    local flow = ease(app, "sky:flow", flowGoal, if flowGoal == 0 then SKY_LEAVE_SPEED else SKY_FADE_SPEED)
    local shadeGoal = if live or sky == nil or flow > 0.004 then 0 else 1
    local shade = ease(app, "sky:shade", shadeGoal, if shadeGoal == 0 then SKY_LEAVE_SPEED else SKY_FADE_SPEED)
    skyShade = if shade > 0.999 then 1 elseif shade < 0.001 then 0 else shade
    if app.SkyTop == nil or shade <= 0.02 or (shadeGoal == 1 and shade >= 0.999) then
        app.SkyTop = sky
    end
    local clear = ease(app, "sky:glass", if glass then 1 else 0, SKY_FADE_SPEED)
    local result: Sky = app.SkyFrame or { Sky = nil, Cycle = nil, Flow = 0, Glass = 1, Clear = 0, Veil = 0 }
    app.SkyFrame = result
    result.Sky = app.SkyTop
    result.Cycle = if flow > 0.004 and type(shown) == "table" then shown.Cycle else nil
    result.Flow = if result.Cycle then flow else 0
    result.Glass = app.SkyGlass or 1
    result.Clear = if clear > 0.004 then clear * (1 - app.Pal.Light) else 0
    result.Veil = if result.Sky ~= nil or result.Cycle ~= nil then result.Clear * result.Glass * GLASS_VEIL else 0
    return result
end

local function glassLeft(cover: number, veil: number): number
    if veil <= 0.004 then
        return cover
    end
    return math.clamp((cover - veil) / (1 - veil), 0, 1)
end

function Sky.cover(sky: Sky): number
    return glassLeft(1 - sky.Clear * (1 - sky.Glass), sky.Veil)
end

function Sky.of(app: App): Sky
    return skyOf(app)
end

function Sky.prepare(now: number)
    skyPrepare(now)
end

function Sky.color(level: number): Color3
    return skyColor(level)
end

function Sky.effect(): string?
    return skyFx
end

function Sky.time(): number
    return skyNow
end

function Sky.paint(position: Vector2, size: Vector2, base: Color3, top: Color3, alpha: number, baseAlpha: number, z: number, rounding: number, cycle: { Color3 }?, flow: number, reach: number)
    skyGradient(position, size, base, top, alpha, baseAlpha, z, rounding, cycle, flow, reach)
end

function Sky.left(cover: number, veil: number): number
    return glassLeft(cover, veil)
end

local function skipping(name: string): boolean
    return string.find(tostring(getgenv().OkloUISkip), name, 1, true) ~= nil
end

function Sky.surface(app: App, position: Vector2, size: Vector2, rounding: number, ui: number): Sky
    local card = app.HandoffCard
    local settle: number = if card then card.Settle or 0 else 1
    Painter.scope("frame:rim")
    Painter.border(position, size, rounding * Painter.corner(), app.Pal.Off, ui * 0.8 * settle, Z_FRAME, 1.5)
    Painter.scope("frame:sky")
    local pal = app.Pal
    local sky = skyOf(app)
    local skyOn = sky.Sky ~= nil or sky.Cycle ~= nil
    if skyOn then
        skyPrepare(os.clock())
        local dark = ui * (1 - pal.Light)
        local effect = if sky.Cycle then skyFx else nil
        local fxIn = app.WelcomeVisual or 1
        fxIn = fxIn * fxIn * (3 - 2 * fxIn)
        if not skipping("skygradient") then
            skyGradient(position, size, pal.Main, sky.Sky or pal.Main, dark, dark * (1 - sky.Clear), Z_FRAME, rounding, sky.Cycle, sky.Flow, 1)
        end
        local palette = app.SkyShown
        local rim = if type(palette) == "table" then palette.Rim else nil
        local first: Color3 = if type(rim) == "table" and #rim >= 2 then rim[1] else pal.Accent
        local second: Color3 = if type(rim) == "table" and #rim >= 2 then rim[2] else pal.Accent
        if effect and not skipping("skyfx") then
            Skyfx.draw(effect, position, size, rounding * Painter.corner(), app.Scale, dark * sky.Flow * fxIn, Z_FRAME, skyNow, first, second)
        end
        if sky.Veil > 0.004 and not skipping("skyveil") then
            Painter.rect(position, size, Color.lerp(pal.Panel, pal.Main, 0.35), ui * sky.Veil, Z_FRAME, rounding)
        end
        if effect and not skipping("skystrike") then
            Skyfx.strike(effect, position, size, rounding * Painter.corner(), app.Scale, dark * sky.Flow * fxIn, Z_FRAME, skyNow, first, second)
        end
    end
    local tint = app.State.OutlineTint
    local preset = app.State.ThemePreset
    local rim = if app.State.ThemeName ~= "Custom" and type(preset) == "table" then preset.Rim else nil
    if type(rim) == "table" and #rim >= 2 then
        if not tint then
            tint = { Accent = pal.Accent, Light = pal.Accent }
            app.State.OutlineTint = tint
        end
        local live = if sky.Cycle then sky.Flow * 0.35 else 0
        local first, second = rim[1], rim[2]
        if live > 0.004 then
            first = Color.lerp(first, Color.lighten(skyColor(0.8), 0.32), live)
            second = Color.lerp(second, Color.lighten(skyColor(0.2), 0.78), live)
        end
        tint.Accent, tint.Light = first, second
    elseif sky.Cycle and sky.Flow > 0.004 then
        if not tint then
            tint = { Accent = pal.Accent, Light = pal.Accent }
            app.State.OutlineTint = tint
        end
        tint.Accent = Color.lerp(app.State.AccentCol, Color.lighten(skyColor(0.8), 0.32), sky.Flow)
        tint.Light = Color.lerp(Color.lighten(app.State.AccentCol, 0.9), Color.lighten(skyColor(0.2), 0.78), sky.Flow)
    elseif tint then
        app.State.OutlineTint = nil
    end
    Painter.rect(position, size, pal.Main, ui * (if skyOn then pal.Light else 1), Z_FRAME, rounding)
    local cardMain: Color3 = if card and typeof(card.Main) == "Color3" then card.Main else pal.Main
    Painter.rect(position, size, cardMain, ui * (1 - settle), Z_FRAME, rounding)
    Painter.scope(nil)
    return sky
end


return Sky
end
modules["ui/skyfx"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")
local Painter: typeof(require("./painter")) = import("ui/painter")

local Skyfx = {}

type Field = {
    N: number,
    Dir: number,
    Speed: { number },
    Sway: number,
    SwayFreq: number,
    Size: { number },
    Aspect: number,
    Alpha: number,
    Twinkle: number,
    Sharp: number,
    Flow: number?,
}

local FIELDS: { [string]: Field } = {
    rain = { N = 26, Dir = 1, Speed = { 0.1, 0.16 }, Sway = 0, SwayFreq = 0, Size = { 1.3, 2 }, Aspect = 9, Alpha = 0.5, Twinkle = 0, Sharp = 1 },
    petals = { N = 16, Dir = 1, Speed = { 0.022, 0.04 }, Sway = 0.05, SwayFreq = 0.35, Size = { 5, 8 }, Aspect = 0.62, Alpha = 0.55, Twinkle = 0, Sharp = 1, Flow = 0.006 },
    snow = { N = 36, Dir = 1, Speed = { 0.016, 0.034 }, Sway = 0.015, SwayFreq = 0.3, Size = { 2, 3.6 }, Aspect = 1, Alpha = 0.6, Twinkle = 0, Sharp = 1 },
    embers = { N = 24, Dir = -1, Speed = { 0.022, 0.048 }, Sway = 0.02, SwayFreq = 0.4, Size = { 2, 4 }, Aspect = 1, Alpha = 0.8, Twinkle = 0.7, Sharp = 1 },
    bubbles = { N = 14, Dir = -1, Speed = { 0.02, 0.042 }, Sway = 0.018, SwayFreq = 0.35, Size = { 7, 15 }, Aspect = 1, Alpha = 0.2, Twinkle = 0, Sharp = 1 },
    fizz = { N = 30, Dir = -1, Speed = { 0.03, 0.06 }, Sway = 0.01, SwayFreq = 0.5, Size = { 2.5, 5 }, Aspect = 1, Alpha = 0.35, Twinkle = 0, Sharp = 1 },
    motes = { N = 40, Dir = 0, Speed = { 0.12, 0.26 }, Sway = 0.05, SwayFreq = 0.5, Size = { 1.6, 3 }, Aspect = 1, Alpha = 0.5, Twinkle = 0.6, Sharp = 1, Flow = 0.004 },
    fireflies = { N = 16, Dir = 0, Speed = { 0.14, 0.3 }, Sway = 0.07, SwayFreq = 0.6, Size = { 3, 5 }, Aspect = 1, Alpha = 0.85, Twinkle = 0.8, Sharp = 2 },
    stars = { N = 44, Dir = 0, Speed = { 0.05, 0.1 }, Sway = 0.006, SwayFreq = 0, Size = { 1.6, 3.2 }, Aspect = 1, Alpha = 0.8, Twinkle = 0.9, Sharp = 1.5, Flow = -0.007 },
    glints = { N = 18, Dir = 0, Speed = { 0.06, 0.12 }, Sway = 0.02, SwayFreq = 0, Size = { 2, 4.5 }, Aspect = 1, Alpha = 0.95, Twinkle = 0.9, Sharp = 4, Flow = 0.005 },
    sparkle = { N = 26, Dir = -1, Speed = { 0.014, 0.028 }, Sway = 0.02, SwayFreq = 0.4, Size = { 1.4, 2.8 }, Aspect = 1, Alpha = 0.9, Twinkle = 1.3, Sharp = 3 },
    leaves = { N = 14, Dir = 1, Speed = { 0.022, 0.042 }, Sway = 0.07, SwayFreq = 0.5, Size = { 4, 7 }, Aspect = 0.55, Alpha = 0.62, Twinkle = 0, Sharp = 1, Flow = 0.01 },
    flurry = { N = 34, Dir = 1, Speed = { 0.016, 0.03 }, Sway = 0.03, SwayFreq = 0.25, Size = { 1.4, 2.6 }, Aspect = 1, Alpha = 0.55, Twinkle = 0, Sharp = 1, Flow = -0.012 },
    pollen = { N = 30, Dir = 0, Speed = { 0.1, 0.22 }, Sway = 0.035, SwayFreq = 0.6, Size = { 1.5, 3 }, Aspect = 1, Alpha = 0.7, Twinkle = 0.5, Sharp = 1, Flow = 0.011 },
    steam = { N = 18, Dir = -1, Speed = { 0.016, 0.03 }, Sway = 0.03, SwayFreq = 0.3, Size = { 4, 8 }, Aspect = 1, Alpha = 0.2, Twinkle = 0, Sharp = 1 },
    drizzle = { N = 22, Dir = 1, Speed = { 0.07, 0.11 }, Sway = 0, SwayFreq = 0, Size = { 1, 1.6 }, Aspect = 6, Alpha = 0.35, Twinkle = 0, Sharp = 1, Flow = 0.01 },
    dust = { N = 36, Dir = 0, Speed = { 0.08, 0.18 }, Sway = 0.02, SwayFreq = 0.3, Size = { 1.2, 2.4 }, Aspect = 1, Alpha = 0.45, Twinkle = 0.4, Sharp = 1, Flow = -0.009 },
    koi = { N = 7, Dir = 0, Speed = { 0.012, 0.022 }, Sway = 0.07, SwayFreq = 0.3, Size = { 9, 13 }, Aspect = 0.3, Alpha = 0.7, Twinkle = 0, Sharp = 1 },
    lightning = { N = 16, Dir = 1, Speed = { 0.11, 0.16 }, Sway = 0, SwayFreq = 0, Size = { 1, 1.5 }, Aspect = 8, Alpha = 0.26, Twinkle = 0, Sharp = 1, Flow = -0.006 },
}

local BOLT_RECTS = 40
local BOLT_SLOT = 5.5
local BOLT_LIFE = 1.15
local BOLT_STEPS = 8
local BRANCH_STEPS = 2

local function hash(index: number, salt: number): number
    local value = math.sin(index * 127.1 + salt * 311.7) * 43758.5453
    return value - math.floor(value)
end

local function smooth(t: number): number
    t = math.clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function toggle(index: number, first: Color3, second: Color3): Color3
    return if index % 2 == 0 then first else second
end

local function field(kind: string, left: number, top: number, width: number, height: number, scale: number, alpha: number, z: number, now: number, first: Color3, second: Color3)
    local spec = FIELDS[kind]
    local flow = spec.Flow or 0
    Painter.fine(true)
    for index = 1, spec.N do
        local grade = hash(index, 5)
        local size = (spec.Size[1] + (spec.Size[2] - spec.Size[1]) * grade) * scale
        local home = hash(index, 1)
        local row = hash(index, 2)
        local phase = hash(index, 4) * 6.2832
        local speed = spec.Speed[1] + (spec.Speed[2] - spec.Speed[1]) * hash(index, 3)
        local x, y, env = 0, 0, 1
        if kind == "koi" then
            local heading = if index % 2 == 0 then 1 else -1
            local swim = (home + heading * now * speed) % 1
            env = smooth(math.min(swim, 1 - swim) * 7)
            x = swim
            y = 0.15 + 0.7 * row + spec.Sway * math.sin(now * spec.SwayFreq + phase)
        elseif spec.Dir ~= 0 then
            local fall = (row + spec.Dir * now * speed) % 1
            local edge = math.min(fall, 1 - fall)
            env = smooth(edge * 6)
            x = home + spec.Sway * math.sin(now * spec.SwayFreq + phase)
            y = fall
        else
            x = home + spec.Sway * math.sin(now * speed + phase)
            y = row + spec.Sway * math.cos(now * speed * 0.8 + phase * 1.3)
        end
        if flow ~= 0 then
            x = (x + now * flow * (0.45 + 0.55 * grade)) % 1
            env *= smooth(math.min(x, 1 - x) * 10)
        end
        local shine = alpha * spec.Alpha * env
        if spec.Twinkle > 0 then
            local pulse = 0.5 + 0.5 * math.sin(now * spec.Twinkle * (0.6 + hash(index, 6)) + phase)
            shine *= pulse ^ spec.Sharp
        end
        local w = size
        local h = size * spec.Aspect
        local px = left + (width - w) * math.clamp(x, 0, 1)
        local py = top + (height - h) * math.clamp(y, 0, 1)
        Painter.rect(Vector2.new(px, py), Vector2.new(w, h), Color.lighten(toggle(index, first, second), 0.25), if shine > 0.004 then shine else 0, z, math.min(w, h) * 0.5, true)
    end
    Painter.fine(false)
end

local function piece(x: number, y: number, w: number, h: number, color: Color3, alpha: number, z: number)
    if w >= 1 and h >= 1 then
        Painter.rect(Vector2.new(x, y), Vector2.new(w, h), color, alpha, z, 0)
    else
        Painter.rect(Vector2.new(0, 0), Vector2.new(1, 1), color, 0, z, 0)
    end
end

local function jog(x: number, goal: number, y: number, core: number, glow: number, coreColor: Color3, glowColor: Color3, coreAlpha: number, glowAlpha: number, z: number)
    if goal > x then
        piece(x + core + glow, y - glow, goal - x, core + glow * 2, glowColor, glowAlpha, z)
        piece(x + core, y, goal - x, core, coreColor, coreAlpha, z)
    else
        piece(goal - glow, y - glow, x - goal, core + glow * 2, glowColor, glowAlpha, z)
        piece(goal, y, x - goal, core, coreColor, coreAlpha, z)
    end
end

local function branch(slot: number, x: number, y: number, side: number, reach: number, core: number, glow: number, low: number, high: number, coreColor: Color3, glowColor: Color3, coreAlpha: number, glowAlpha: number, z: number)
    local thin, soft = math.max(core - 1, 1), glow
    local goal = math.clamp(x + side * math.floor(reach * (0.9 + 0.6 * hash(slot, 70))), low, high)
    if math.abs(goal - x) <= core + soft then
        return
    end
    local start = if side > 0 then x + core - thin else x
    jog(start, goal, y, thin, soft, coreColor, glowColor, coreAlpha, glowAlpha, z)
    x = goal
    local top, glowTop = y + thin, y + thin + soft
    for step = 1, BRANCH_STEPS do
        local nextY = math.floor(y + reach * 0.9 * step)
        local last = step == BRANCH_STEPS
        local fade = 1 - (step - 1) * 0.22
        local bottom = if last then nextY else nextY + thin
        local glowBottom = if last then nextY + soft else nextY + thin + soft
        piece(x - soft, glowTop, thin + soft * 2, glowBottom - glowTop, glowColor, glowAlpha * fade, z)
        piece(x, top, thin, bottom - top, coreColor, coreAlpha * fade, z)
        if not last then
            local nextX = math.clamp(x + side * (thin + 2 + math.floor(hash(slot, 71 + step) * reach * 0.7)), low, high)
            if math.abs(nextX - x) > thin then
                jog(x, nextX, nextY, thin, soft, coreColor, glowColor, coreAlpha * fade, glowAlpha * fade, z)
                x = nextX
            end
            top, glowTop = nextY + thin, nextY + thin + soft
        end
    end
end

local function bolt(left: number, top: number, width: number, height: number, scale: number, alpha: number, z: number, now: number, first: Color3, second: Color3, position: Vector2, size: Vector2, radius: number)
    local slot = math.floor(now / BOLT_SLOT)
    if hash(slot, 31) > 0.82 then
        return
    end
    local age = now - (slot * BOLT_SLOT + 0.3 + hash(slot, 32) * (BOLT_SLOT - BOLT_LIFE - 0.4))
    if age < 0 or age > BOLT_LIFE then
        return
    end
    local light = smooth(age / 0.035) * math.exp(-age * 5.5)
    local again = 0.13 + 0.12 * hash(slot, 34)
    if hash(slot, 33) < 0.65 and age > again then
        light += 0.8 * smooth((age - again) / 0.03) * math.exp(-(age - again) * 7)
    end
    local shine = alpha * math.min(light, 1)
    if shine <= 0.004 then
        return
    end
    Painter.rect(position, size, Color.lighten(first, 0.55), shine * 0.14, z, radius, true)
    local core = math.max(2, math.floor(2 * scale + 0.5))
    local glow = math.max(2, math.floor(3 * scale + 0.5))
    local coreColor, glowColor = Color.lighten(second, 0.85), Color.lighten(first, 0.2)
    local coreAlpha, glowAlpha = shine, shine * 0.32
    local low, high = math.floor(left) + glow * 2, math.floor(left + width) - core - glow * 2
    local x = math.floor(left + width * (0.2 + 0.6 * hash(slot, 35)))
    local y = math.floor(top)
    local glowTop = y
    local stepHeight = height * (0.55 + 0.38 * hash(slot, 36)) / BOLT_STEPS
    local lean = if hash(slot, 37) < 0.5 then -1 else 1
    local fork = if hash(slot, 38) < 0.75 then 2 + math.floor(hash(slot, 39) * 4) else 0
    for step = 1, BOLT_STEPS do
        local nextY = math.floor(top + stepHeight * (step + if step < BOLT_STEPS then (hash(slot, 60 + step) - 0.5) * 0.6 else 0))
        local last = step == BOLT_STEPS
        local bottom = if last then nextY else nextY + core
        local glowBottom = if last then nextY + glow else nextY + core + glow
        piece(x - glow, glowTop, core + glow * 2, glowBottom - glowTop, glowColor, glowAlpha, z)
        piece(x, y, core, bottom - y, coreColor, coreAlpha, z)
        if step == fork then
            branch(slot, x, math.floor((y + nextY) * 0.5), -lean, stepHeight, core, glow, low, high, coreColor, glowColor, coreAlpha * 0.7, glowAlpha * 0.7, z)
        end
        if not last then
            local reach = core + 2 + math.floor(hash(slot, 40 + step) ^ 1.5 * stepHeight * 0.75)
            local side = if (fork == 0 or step < fork) and hash(slot, 50 + step) < 0.38 then -lean else lean
            local nextX = x + side * reach
            if nextX < low or nextX > high then
                nextX = x - side * reach
            end
            nextX = math.clamp(nextX, low, high)
            if math.abs(nextX - x) > core then
                jog(x, nextX, nextY, core, glow, coreColor, glowColor, coreAlpha, glowAlpha, z)
                x = nextX
            end
            y, glowTop = nextY + core, nextY + core + glow
        end
    end
end

local ORBS = {
    { Tone = 0, Size = 0.46, AX = 0.34, AY = 0.30, WX = 0.113, WY = 0.083, Phase = 0.0, Breath = 0.17, Power = 1.0 },
    { Tone = 1, Size = 0.34, AX = 0.40, AY = 0.34, WX = 0.071, WY = 0.131, Phase = 1.9, Breath = 0.11, Power = 0.85 },
    { Tone = 0, Size = 0.30, AX = 0.30, AY = 0.38, WX = 0.157, WY = 0.059, Phase = 3.4, Breath = 0.2, Power = 0.8 },
    { Tone = 1, Size = 0.40, AX = 0.36, AY = 0.26, WX = 0.047, WY = 0.097, Phase = 4.6, Breath = 0.14, Power = 0.7 },
}
local ORB_LAYERS = 72

local function bat(x: number, y: number, unit: number, now: number, phase: number, _dir: number, color: Color3, alpha: number, z: number)
    local beat = math.sin(now * 7.5 + phase)
    local flap = beat + 0.28 * math.sin(now * 15 + phase * 2)
    local fill = math.max(1.8, 2.5 * unit)
    local arm = math.max(1.3, 1.7 * unit)
    for side = -1, 1, 2 do
        local shoulder = Vector2.new(x + side * 1.8 * unit, y - 1 * unit)
        local lean = -0.45 - 0.7 * flap
        local wrist = shoulder + Vector2.new(side * math.cos(lean) * 9 * unit, math.sin(lean) * 9 * unit)
        local hip = Vector2.new(x + side * 1.6 * unit, y + 4.5 * unit)
        local tips = {}
        local reaches = { 13.5, 12.5, 9.5 }
        local drops = { 0.1, 0.62, 1.2 }
        for index = 1, 3 do
            local angle = lean * 0.45 + drops[index] + 0.1 * flap
            tips[index] = wrist + Vector2.new(side * math.cos(angle) * reaches[index] * unit, math.sin(angle) * reaches[index] * unit)
        end
        local edge = { tips[1] }
        for index = 1, 2 do
            local middle = (tips[index] + tips[index + 1]) / 2
            table.insert(edge, middle + (wrist - middle) * 0.2 + Vector2.new(0, 0.8 * unit))
            table.insert(edge, tips[index + 1])
        end
        table.insert(edge, (tips[3] + hip) / 2 + Vector2.new(0, 0.8 * unit))
        table.insert(edge, hip)
        for index = 1, #edge - 1 do
            for step = 0, 2 do
                local point = edge[index] + (edge[index + 1] - edge[index]) * (step / 3)
                Painter.line(wrist, point, color, alpha, z, fill)
            end
        end
        Painter.line(shoulder, hip, color, alpha, z, fill)
        Painter.line(shoulder, wrist, color, alpha, z, arm * 1.3)
        for index = 1, 3 do
            Painter.line(wrist, tips[index], color, alpha, z, arm)
        end
    end
    Painter.rect(Vector2.new(x - 2.6 * unit, y - 2 * unit), Vector2.new(5.2 * unit, 9 * unit), color, alpha, z, 2.6 * unit, true)
    Painter.rect(Vector2.new(x - 2.4 * unit, y - 5 * unit), Vector2.new(4.8 * unit, 4.8 * unit), color, alpha, z, 2.4 * unit, true)
    for side = -1, 1, 2 do
        Painter.line(Vector2.new(x + side * 1.3 * unit, y - 4.2 * unit), Vector2.new(x + side * 2.1 * unit, y - 7.4 * unit), color, alpha, z, math.max(1.3, 1.6 * unit))
    end
end

local function web(cornerX: number, cornerY: number, sx: number, sy: number, length: number, color: Color3, alpha: number, z: number, thick: number)
    local spokes = 6
    local rings = { 0.26, 0.48, 0.70, 0.94 }
    for index = 0, spokes - 1 do
        local angle = index / (spokes - 1) * math.pi * 0.5
        local reach = Vector2.new(sx * math.cos(angle), sy * math.sin(angle)) * length
        Painter.line(Vector2.new(cornerX, cornerY), Vector2.new(cornerX, cornerY) + reach, color, alpha, z, thick)
    end
    for _, fraction in rings do
        for index = 0, spokes - 2 do
            local a0 = index / (spokes - 1) * math.pi * 0.5
            local a1 = (index + 1) / (spokes - 1) * math.pi * 0.5
            local sag = 0.9
            local p0 = Vector2.new(cornerX + sx * math.cos(a0) * length * fraction, cornerY + sy * math.sin(a0) * length * fraction)
            local p1 = Vector2.new(cornerX + sx * math.cos(a1) * length * fraction, cornerY + sy * math.sin(a1) * length * fraction)
            local mid = (p0 + p1) / 2
            local pull = Vector2.new(cornerX, cornerY) + (mid - Vector2.new(cornerX, cornerY)) * sag
            Painter.line(p0, pull, color, alpha, z, thick)
            Painter.line(pull, p1, color, alpha, z, thick)
        end
    end
end

local function knee(hip: Vector2, foot: Vector2, first: number, second: number): (Vector2, Vector2)
    local delta = foot - hip
    local distance = math.clamp(delta.Magnitude, 0.001, first + second - 0.01)
    local direction = delta.Unit
    local along = (first * first - second * second + distance * distance) / (2 * distance)
    local height = math.sqrt(math.max(first * first - along * along, 0))
    local perpendicular = Vector2.new(-direction.Y, direction.X)
    if perpendicular.Y > 0 then
        perpendicular = -perpendicular
    end
    return hip + direction * along + perpendicular * height, hip + direction * distance
end

local function limb(from: Vector2, joint: Vector2, to: Vector2, color: Color3, alpha: number, z: number, thick: number)
    Painter.line(from, joint, color, alpha, z, thick)
    Painter.line(joint, to, color, alpha, z, thick)
end

local function spider(x: number, top: number, drop: number, unit: number, color: Color3, alpha: number, z: number, now: number, seed: number)
    local thick = math.max(1, 1.05 * unit)
    local swing = 0.16 * math.sin(now * 0.75 + seed) + 0.05 * math.sin(now * 1.9 + seed * 2.1)
    local anchor = Vector2.new(x, top)
    local length = drop + 6 * unit
    local center = anchor + Vector2.new(math.sin(swing), math.cos(swing)) * length
    local cosine, sine = math.cos(swing), math.sin(swing)
    local function turn(offset: Vector2): Vector2
        return center + Vector2.new(offset.X * cosine - offset.Y * sine, offset.X * sine + offset.Y * cosine)
    end
    Painter.line(anchor, turn(Vector2.new(0, -5.5 * unit)), Color3.new(0.82, 0.82, 0.88), alpha * 0.4, z, math.max(1, 0.8 * unit))
    for side = -1, 1, 2 do
        for leg = 1, 4 do
            local twitch = 0.14 * math.sin(now * (1.1 + leg * 0.37) + leg * 1.7 + side * 2.3 + seed)
            local reach = (-0.95 + (leg - 1) * 0.62 + twitch)
            local hip = turn(Vector2.new(side * 1.8 * unit, (leg - 2.5) * 2.1 * unit))
            local joint = turn(Vector2.new(side * math.cos(reach) * 6.5 * unit + side * 1.8 * unit, (leg - 2.5) * 2.1 * unit + math.sin(reach) * 6.5 * unit))
            local tip = turn(Vector2.new(side * (7.8 + leg * 0.9) * unit, (leg - 2.5) * 2.1 * unit + (6.2 + leg * 0.8 + twitch * 8) * unit))
            limb(hip, joint, tip, color, alpha, z, thick)
        end
    end
    local tilt = math.deg(swing)
    Painter.rect(center + Vector2.new(-4.2 * unit, -1.5 * unit), Vector2.new(8.4 * unit, 10.5 * unit), color, alpha, z, 4.2 * unit, true, tilt)
    Painter.rect(center + Vector2.new(-2.8 * unit, -5.6 * unit), Vector2.new(5.6 * unit, 5.6 * unit), color, alpha, z, 2.8 * unit, true, tilt)
end

local function crawler(position: Vector2, size: Vector2, unit: number, color: Color3, alpha: number, z: number, now: number)
    local pace = 15 * unit
    local span = size.X - 110 * unit
    local run = (now * pace) % (span * 2)
    local forward = if run < span then 1 else -1
    local travelled = if forward == 1 then run else span * 2 - run
    local x = position.X + 55 * unit + travelled
    local stride = 12 * unit
    local duty = 0.6
    local cycle = run / (stride / duty)
    local floor = position.Y + size.Y - 6 * unit
    local lift = 5 * unit
    local body = Vector2.new(x, floor - 10.5 * unit + 0.5 * unit * math.sin(cycle * math.pi * 4))
    local thick = math.max(1.2, 1.15 * unit)
    local rests = { 16, 8, -3, -13 }
    for side = -1, 1, 2 do
        local near = side == 1
        for leg = 1, 4 do
            local group = (leg + (if near then 0 else 1)) % 2
            local phase = (cycle + group * 0.5) % 1
            local reach: number
            local height = 0
            if phase < duty then
                reach = 1 - phase / duty * 2
            else
                local swing = (phase - duty) / (1 - duty)
                reach = -1 + swing * 2
                height = math.sin(swing * math.pi) * lift
            end
            local hip = body + Vector2.new(forward * (7 - leg * 1.5) * unit, 1.5 * unit)
            local foot = Vector2.new(body.X + forward * ((rests[leg] + (if near then 0 else 2.5)) * unit + reach * stride * 0.5), floor - height)
            local joint, tip = knee(hip, foot, 11 * unit, 14 * unit)
            limb(hip, joint, tip, color, alpha * (if near then 1 else 0.5), z, thick * (if near then 1 else 0.85))
        end
        if not near then
            Painter.rect(body + Vector2.new(-9 * unit - forward * 6 * unit, -6.2 * unit), Vector2.new(18 * unit, 13 * unit), color, alpha, z, 6.5 * unit, true)
            Painter.rect(body + Vector2.new(-4.8 * unit + forward * 8.5 * unit, -3.6 * unit), Vector2.new(9.6 * unit, 8 * unit), color, alpha, z, 4 * unit, true)
            local eyes = Color3.fromRGB(255, 190, 90)
            for eye = 0, 1 do
                Painter.rect(body + Vector2.new(forward * (11.5 + eye * 2.2) * unit - 0.9 * unit, (-1.4 - eye * 1.6) * unit), Vector2.new(1.8 * unit, 1.8 * unit), eyes, alpha, z, 0.9 * unit, true)
            end
        end
    end
end

local function haunt(position: Vector2, size: Vector2, radius: number, scale: number, alpha: number, z: number, now: number)
    local unit = math.max(0.7, scale)
    local silk = Color3.fromRGB(205, 200, 195)
    local reach = math.min(size.X, size.Y) * 0.34
    local inset = radius * 0.42 + 3 * unit
    local thick = math.max(1, 0.9 * unit)
    web(position.X + inset, position.Y + inset, 1, 1, reach, silk, alpha * 0.2, z, thick)
    web(position.X + size.X - inset, position.Y + inset, -1, 1, reach * 0.85, silk, alpha * 0.17, z, thick)
    web(position.X + size.X - inset, position.Y + size.Y - inset, -1, -1, reach * 0.6, silk, alpha * 0.12, z, thick)
    local body = Color3.fromRGB(150, 80, 30)
    for index, route in { { 0.047, 0.17, 0.0 }, { 0.031, 0.31, 2.1 }, { 0.039, 0.24, 4.4 } } do
        local along = (now * route[1] + route[3] * 0.17) % 1
        local x = position.X + size.X * (-0.08 + 1.16 * along)
        local y = position.Y + size.Y * (route[2] + 0.07 * math.sin(now * 0.8 + route[3]) + 0.03 * math.sin(now * 2.3 + index))
        local fade = math.clamp(math.min(along, 1 - along) * 8, 0, 1)
        bat(x, y, unit * (1.1 - index * 0.12), now, route[3], 1, body, alpha * 0.75 * fade, z)
    end
    local legs = Color3.fromRGB(170, 100, 40)
    for index, hang in { { 0.64, 0.10, 0.07 }, { 0.93, 0.17, 0.05 } } do
        local drop = size.Y * (hang[2] + hang[3] * math.sin(now * 0.42 + index * 2.3))
        spider(position.X + size.X * hang[1], position.Y + 4 * unit, drop, unit * 1.7, legs, alpha * 0.85, z, now, index * 1.9)
    end
end

local GLOW_PNG = "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"
local HALO_PNG = "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"
local pictures: { [string]: string | false } = {}

local tidied = false

local function tidy()
    if tidied then
        return
    end
    tidied = true
    pcall(function()
        local exists, remove = isfile, delfile
        if type(exists) ~= "function" or type(remove) ~= "function" then
            return
        end
        for _, name in { "orbglow", "oklohalo", "oklobubble", "oklomote", "oklobeam", "fibredot", "fibrefine", "fibreglow", "fibrepatch", "fibrestroke" } do
            local old = "oklo scripts/" .. name .. ".png"
            if exists(old) then
                pcall(remove, old)
            end
        end
    end)
end

local function picture(name: string, data: string, raw: boolean?): string?
    local known = pictures[name]
    if known ~= nil then
        return if known then known else nil
    end
    pictures[name] = false
    pcall(function()
        local write, asset, folder = writefile, getcustomasset, makefolder
        if type(write) ~= "function" or type(asset) ~= "function" then
            return
        end
        if type(folder) == "function" then
            pcall(folder, "oklo scripts")
            pcall(folder, "oklo scripts/loaders")
        end
        tidy()
        local file = data
        if not raw then
            local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
            local value: { [number]: number } = {}
            for index = 1, 64 do
                value[string.byte(letters, index)] = index - 1
            end
            local bytes: { string } = {}
            local bits, count = 0, 0
            for index = 1, #data do
                local code = value[string.byte(data, index)]
                if code then
                    bits = bits * 64 + code
                    count += 6
                    if count >= 8 then
                        count -= 8
                        local divisor = 2 ^ count
                        local byte = math.floor(bits / divisor)
                        bits -= byte * divisor
                        table.insert(bytes, string.char(byte))
                    end
                end
            end
            file = table.concat(bytes)
        end
        local path = "oklo scripts/loaders/" .. name .. ".png"
        write(path, file)
        local made = asset(path)
        if type(made) == "string" and made ~= "" then
            pictures[name] = made
        end
    end)
    local made = pictures[name]
    return if made then made else nil
end

local function glowImage(): string?
    return picture("orbglow", GLOW_PNG)
end

function Skyfx.glow(): string?
    return glowImage()
end

local function orbs(position: Vector2, size: Vector2, radius: number, scale: number, alpha: number, z: number, now: number, first: Color3, second: Color3, spooky: boolean)
    local reach = math.min(size.X, size.Y)
    Painter.clip(position, size)
    Painter.fine(true)
    for index, orb in ORBS do
        local cx = position.X + size.X * (0.5 + orb.AX * math.sin(now * orb.WX + orb.Phase) * math.cos(now * orb.WY * 0.6 + orb.Phase * 0.7))
        local cy = position.Y + size.Y * (0.5 + orb.AY * math.sin(now * orb.WY + orb.Phase * 1.3))
        local orbRadius = reach * orb.Size * (1 + orb.Breath * math.sin(now * (0.21 + index * 0.037) + orb.Phase))
        local color = if orb.Tone == 0 then first else second
        local each = 0.0075 * alpha * orb.Power
        local glow = glowImage()
        if glow then
            Painter.image(glow, Vector2.new(cx - orbRadius, cy - orbRadius), Vector2.new(orbRadius * 2, orbRadius * 2), each * ORB_LAYERS, z, 0, color)
            continue
        end
        for layer = 1, ORB_LAYERS do
            local r = orbRadius * (1 - (layer - 1) / ORB_LAYERS) ^ 0.85
            Painter.rect(Vector2.new(cx - r, cy - r), Vector2.new(r * 2, r * 2), color, each, z, r, true)
        end
    end
    Painter.fine(false)
    if spooky then
        haunt(position, size, radius, scale, alpha, z, now)
    end
    Painter.unclip()
end

function Skyfx.halo(): string?
    return picture("oklohalo", HALO_PNG)
end

local BEAM_PNG = "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"
local MOTE_PNG = "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAACQElEQVR42u2Za27CMBCEgZYWQnkEFYKIUAGh0J+chFtwL67CVXKRqSLNqisrzgtQsUuk/YGzseZbj01itwC0XI7WE+AJ8HgA7ZJ4SIB2w/hTgDxBnYpxM5hbidfiXkqiCOTuADbhIu7ViC7DbDdhGoM0FZ8nXMS+lYSGKgK5KYBNvCn8ndFj9BnyW+7ngTSCaCLerPqbEp2JDQAMLBEoIA1ijkZliDoApnhTeCbwA8AQwMgSQ+YMckBsEFcB2Gwj4qXiInwMYAIgBDA1IuS9sQKRETEhOlUh6lrHFC9VH1FcJvQTwAzA3IgZ702ZOzJGIw+i1Ep1rCOe1+Kl6iHFZUIXAJYAYiOWvDdnbqhGQ0N0LRBXA8iE7SnbjFnRrLoRRa4AfAFYA9gw1mxbMSfiM1P2IXbqqYl9FUBZ9cU2IYUsWOVM5BbADkACYM9I2LZlTsxnZuxD7FR7FJpUX6wzoRUiJX5HwQcARwAnxpFte+YIRMQ+JspKtUahCEBWgrzqi3XmtISI/6bYM4AUv1fKtiNzBGLJPrSVzFHQK1IlgKKVJzCqv6Cvt6xuJvAC+3Vhzp7PrNiHHoWgZEVqDCD20d7X1T+wymXXmbl6FPRc0Da6G4DYJ+YKk7CyaQWAlLkJn42Vje4CIBO4bwHY0BInVL9OfGZjAehXncj/AsB5C3kziZ1ZRp3/I/PmVcLplznnX6e9+qBx9pPS+Y96L7ZVvNjYcn5r0YvNXS+217044PDmiMmLQz6vjlmfJ/VPAFfjB0B8b0Kp4MYmAAAAAElFTkSuQmCC"
local BUBBLE_PNG = "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAT2ElEQVR42u2d+XcUVRbHZQuQrbN0CCSBBGSRNUhAESSAYgRR0CEYCBhxA0SQRVGRAC6jCIwBBtkiu4R9x2EJYpQEFBCXwZFx+1vuVJ3zeZ5nWVVd1d0kzdA/vJOkU1X96vu993vvu+/VqztE5I5bpDWzac1pdv+7Je4rloE2gW0hIi1FpJWIJIhIGxFpKyKJIpIkIsm0JD5ryzEJnNOSazSPVWJiCXQFeCtANIFNF5F2IpIrIp1FpLuI9BKRfiJyt4gMoPXns14cU8A5WSKSxrXacG2dkNuaAAW6aaWtASkD4LoD7HAReVREJonI8yIyR0QWishiEVlmXONt2jI+W8gxz4lImYiMFZFiyOrGtTPwmNZ8d5OS0VTAt0AmTCCCWKxpxQ8A3Gzj2LdEZJ2IfGL875iI1IrIlyJySUSuGMR8IyLX+HlVRC6LyEWDtDoROSMih43r7jC8aK2ILBWRWSIy0bjGSBEpFJF84/qZ9CGBPjX7fyZAAW9aXgBr7Csio0SkQkTeNCRjPcDVAex/DOv/r4j8zE/z73+LyHeAf1Vr5vHfisj3HPOjiFzn2K9F5JyI7Dc84J8i8oaITIXwPvQlQN8alYjGBL4Nmm5a+z0GOBNE5FVAPwFIP4nIrwB+HUv/QkROG1Z7VET2isguEdkqIptFZKMRIzbQzN+rRWSbiOwWkYMi8qkhQZ+LyFeQ8wM/L0C06R3zjc+fEJFBeEVaYxLRGBrfmpsygb/PAHgKur1HROqx6t+w8GtY/3FDs2sMy/wYGfrQyHBWGEH0PQOYdznflJVKPGeRiLwuIq8RB17DypcYOv93w7pXi8gWw9oPichnyNV3eM1nSNUSYs1giAggTTc1RtxM8FsSWHOxrsmAdxDL/gVr/x4rPwoQGwDsH4Y+r7JpKyFjOYS8QxCuBHTTq+YRR14UkZm02fzvLWRoL+BfwSu+hHTzWk8a3jOQvidzL81uBQKU1bchuPY2bm4cGco+bvZXwL+KtNQgJyYoa5CFj5CUzXiBakp21nO8Isok5H3IWIpXLISIl0TkBRF5hlhTQZY0B7A34nGX8EDTGHbiUY+S2mbiyc1jmQDd6jsa1nU/lmfqcoNm8Sbw/0LLNyIx6zluO1nPHloNx22HgA0AX4UnLEdiVCq6BLKVJOneMAMSppJpTeTnMxy3mrhwkT7WYggmeUMMCcsjY4qqN0QT/FZofQ+s3gTlJBr/O5p7BoA3AWY11rYXfT6MRO3l82oIWgXQS5GZV0RkrkVmZljaTEubzlhiGnHIJOBxw+ofM/o23jCQcshag0d8TfA+iLyNZXySxr02ixUCVKANMuCpANyLBNcbuPV+AN1IFlMD4Mdph7H6LVj5cm58ASA/A0g6cCYoYwywRtPM3x9BOsaR3ZSi6ZM5fwo/y8jEHuPcEs6dhEdsJnW9gjes5txC7jUhGpIUDfBNvW9PhjMbEH/A6r/FC7Zj9Vv4/1FSRLMdIW3chKyYEvIygD8JQA8xKr6PgK6XH/pqrR+fDyCI3muAOJRzHzQs+mFIGweJ47n+GMYjIzh2NIZkxpQDxIcLpLgzuW429968qQhoTvErl06/jiXfQOsbNKuvBmQT+FME32N4wQaymVeRiIkAUsx4oZBAaJYSupDOdiLO5PH9ufyex+f51I7utNSPBgDe/YA9Cssv0QgYSip6P+S8TP/rIGIfXjnM+DwnUhKiAf4DBL+zAG8ScB6t34z1HyTwnsXq92Px7zEQehqrHImF9wHwAkDtgMVl4f5BMpNMajsZ2t+Z/D+Lc9rTz06Q0g1CCvGSwYA+jDYE4k2yiiClgjh0mrhwBIMbESkJkchODuAvI5/+jeH/aUCv1uo4Z2lH+d9KLP5p9HoY8aOHVslUgCuQ0wmAaQyS3Jo6Lp2mSGkHmXl8T1fDGHpq3jEQAyhCyvrQ7iGeLON+LvFzESR0CJeEcLKd1ljVcCxfgX8d695KyriXv89Byn7SuiWkdo8jM/2xyk5cN8sCuA5sahhNJyWda+tkdNQ8oyeAq9iiytvd+Gw0WdghkoxjeMIwDCbBb3YUTqoZJBi+hlUr8E8SZLcA9mnA/xRPWIXcTCYgFnFzCvigDeipN6HZkZGN1+UTZ7rRt+7EkQL+1wOvf4XgfBEy5hNbgn5TVL+DrDSkYjYB91dk51MN/APk++c4ZisliJlkHUMYIRc4AO9mxX6aHzIybCQqXwO+I5LbAYKGQ8Ihko09jD0KuWbLaBPQnBFuDwLSHoLtDSxdyY4Cvxa934zkTCMFLNImRpTUOAEfiHLz6hWZENEewBXw7bQg3wkS3sDI6jG+crwmyWs88Gr9bbCCcaSNP1Ba+IzcuJr07DTgH2HAtUiruxeite25CTvgQwVVvy1SIoJa5qWMJYVjOzE+eQcprqNEMhYPau1FirxKT5C8+G1073dcbxfpZA1pprL8DVjHZCylD67czsXqvYKeHqJ5JcNPrFDnJ2uLAgLI0XjKF2reYjEym+mlbuRVenqj4ScJutew+I3UbE5gBccgZBHgF5NJdMSS0sMAPj3C5oeIFK1ZP0/WVl4oEtK5vwpK6Q3g8jwZVXIoKfKScuYiPdUE3J8AXJUWjqD7J/i7kprJ8BDguwHvBGaGx+aFDC8kpFjA1wloi9ZnMXZYQDy4QEl9LPHDNTV1I6AFnRtEfb0e668j6G6C7VNkQTuQqKfR/N4ewXcDPiNKzS8RVvCTtLVHVhJS0PwSBph1YLKQpCMAlr4IUIG3ACnZS9D9lgxoPYAfR/v3MCkynY70I0iFC74diJk+WygivJKQHIKERK5xF1K0GynaRl0r3y0gu1l/OgOudynJ/gyzaqbqAJZ/EJebS/GqiGynnUfw3YB3Ajfo0LySYUdEJCQkcb9DkOBaxkGVDNDSnLzATfsLyGsPYv2XCbjr+HmcoPsxElUGYV1JNTMiAN8r4KGaGxHRIEGXolSyolIkugGcyty8wE3772EC+worFk5Sy9mE9R/H3d5njvUBgm6uluf7Bd8L8Fkhmh8i3EhIdSDBTYqCxMw3yArPkZYO5DrNQxHQjKidy2xRDdJzmSrmWn4ewTPWUQcZRzUxX1uPGfAAfoZLOdkP6F7JCOUNTiR49YIU5LeUGNBAZvg4GdFf6kR2eX8SlcBXSal+JtCuwwP2MH24HQ+ZyiCtWwjpCQd8K6DtPDY3IqJJgpMXDGb++jxxcy5Z4V9KFFYC1Kh3FJnOj2Q+uxhmVyM/exn9zWEetR8pZ9BBerzITjSAD4cIP3LkNRZ0JSPaR/pexWRTpjUYOwXfCgZWv8DiR0xK76DUvBXrn8JsUldKuuk+rT8U+FZAsz02NyK8kBCJFyShBA8CfD1ElCPRfxqY2ZUdCslqvmLUe5ClgWqlco2Wdo7l+I4ugTcc8MMF3isRkZIQygvSwWWBVh1eiFL8SYas2U8G2YySn6sEkZXk/7sJLu8y4i2m/NreYv0Bm5mo9BCabwe+FdD2HpsbEVkOc8tOJLh5gVNGpILxJAxWydAIrt/CSoCa7cplKcghgu9nWPtK9H8XcrSQOdIi3CoYofWHAt8O5A6WFooILySE6wV2wTgbGVoDAZ+QWaps6C8EtMGaX2JJ9w3SzRWsv9yC9a+kMvoQkT0nROYTTfA7eGzRJsGrF1hlqAg5P884agbZYhsVB6z6P4DgepVVyztZOlIFAZtYGTDVJfhGav1egc+xNK9ERMMLvATjVGYQpzNo/ZxBWX+9TG2t/QxnWeB1gvAG9H4NErSW8YFf+fELfrYD+Dkemx0J2WGSEK4MJVOQLCV21qMkw7jenwhoSYceRefV4qoPmXJbQxBegUSNZrCWG2X58QN+rqX5ISFaMuSWDSXynSUkNQ0Y8Ri+s6VOgArAk5hSvIFmLdcIWMfvzzKo6OGS/bjJT6Tg54Zo0SDBTYa8xgE1Kjal+gOqCnsoUf8RiPX6T2eKamfJ/w8A+NsMwlYTUMq56J3cgNfsJ1zrdwI+z9KciIjEC7zGgVCBuJIYcJQVIgVqQGbNgOYwuXydtGkpQflDbTlhKZXSAq3wFq7+ewU/xwV4JyJyfJLgNw54CcQBFiQsYDB2iqX2f2RCioC2lJIXsurhO7Ie9UD0KsrOL2uVz050OBz9D9f68yyroPXmRoIfL4gkDthlQnfxjLJaNTKfCfu2OgGJDJMXU3r+hqCrnjT8ACl6USu+5dFRPwQEo0RAR4cWDQKCUSQghVT9eVLR86wl7ctxfxCQRH66jAmYK9qIdzFjAbWotkR7uDnjJhDgFfxOluaHhMYkoAu6f0QbCxRyfDN9DmAAVn6V56PWsv5xEZ8vIgMaFcEI+HYjIBkCKrQdACoxdlcCviL1nM8q6KX8fFqbeowTECUC7CToawiYSwR/E294ijFAzzgB0ZMgPQireYDLSNAcSHgdb5jaCATclkFYpaGvUrO4ShCeTenhFVLQKRDQK8IqaDwNtaShaiA2Gze5RuVTPWGuHoouh4DeHrKg+EDMx0AsgZHtsxz0PbV/tfvULE4sZ5Khj4dxQLwU4bEUoRfjypgN+4HC0Twynxeoa5eThuqrIAIO6+rjxTiPxThVjs5ikn0HBBxjIPYUrD3HQt0SMqZ8m1pQvBwdZjm6BV9STPp5Dc1aQuYzBU+YrD3r1dmmGhqfkAlzQkZNSd7NoOsSjH2AB5RBQhkM3qMtwo10LVB8SlLLhLoRcGtJRTcQmCewWmIixbjBXNwuFY1PyocxKa8vS5nISq7vWIL4EnPAZvsbBAxlLJBnMyccX5YSxrIUfWHWSEbB3/DU3yKAV3vwPIKO9dWefEzzsEVAfGGWy8IsvShXyHD5CyZnVnGh0drmSGqPhy4OK6LjSxPDWJqoFufmk/kcIhvaSS3jYcYAavMk9dR7js2ALL44N4zFuUqGMik5r6UyepqZsbG40AgkaCB1jo4O44H48nSfy9N1GepD0aiW6uhaUtBiAvBQHsXpxbA620GG4g9o+HxAQ39E6QmegrmKHM3GM+6lFUFUF7KQTEueHC0SbqtHlKwPaFcSjC+wKm484KtN83rjbrkWGbI+7h9/SM/jQ3rWYDyJYfQV9Gwm+l+o7SjVlTigngt22nMh/piqx8dU9drQvWhZHXsrr2As0J9JBbWjVEdLHEiJAgm37YPaVi94kgrpZS0WDCUDulPb2dBKgOq0FxLiWxW4xIIiVkSc4cLrcLN+lm0lszQJSra0FA+Buak360gNA/ybtlmHnhHlMAZYx8j4NAWmkeh/jradl7L+JK15ISEWt6vxAv5N3a5GL1P3ZDS8n3FBDbNkRdrWBAHLvjrhkBArGzZZwXeSnpu6YZO+ZVkmAWYxUlTPqolStC+obefV1iMJKTG0ZVlKGOA3ypZlekDOw62q+LJzbCn/MLEg1eKeiTZEhCIhtQk27UvxIDt2KWejbNpnLVF0Z2ZM5bknGHQU86UpPkgIh4hobltpB7wX8FXQLW6sbSv1ifsAg7AZzPA3kJouIDXNtSEhlCSFIiJcQpyuEwp4p4CrwM/lXhc05sat1q2L76VYd0gLPPPoWB43muiThGSXAVykLcUFeC/gJ3KdPO5xHvfc0FhbF1tT02xKEq+z2KhB21e/GH0MuJDglwg/pLid6wV4uz4HuKdi7lGBf7QxN++2bl/fgbmBRRoJh9DFh8gQ0rm5th6JsCMjFCF+AE+2+b5EF8lJ4h66cE9vaF5/tCm2r7d7h8AIrEB17DiZwXhy5CzASIwCEZE0P8An0ucs7mE893RcM7Qme4GDnScMQwfV2/HOkhtXMErMIy208wYrEXZk+CXF6fzEEMArq0+jz4O4hzXcUz33OJ977tBUrzCxkpBNEJpBOlbHWGEHmlnCgK2dQ4B2IsKNDK8t0SPwKtC2o68l9H0H91LHvc2IlZf46CQkkAEUkgtXMSpUkrQSSxqCngZdZMmNjEia2/ek0Kcu9LGCPivJOc09lcfaa6ysKWqAgchY7fWFF7Ce3dTHS3HtztxIqos0hUuKl2sl8d1B+jKIvlXS1zr6vo97US9yC8Tai9ysdaMk9HMIRam1lGcbmKjYSjZRyuS1vsY0xQeA4TRl7el8Z1f6UEqfttLHBvq8lnuI+VcZ2r1ZL5OK4Fhq49uoHzUQ0LYx21bBGhr1godsy7xCYpikqPOSuVY61+7Mdz3Idy+lL2fp2zn+Xkjfe94qL/N0erFnDmXribj3To2I87h4FQFvkvaCnx42L/hxWp2sD9ICHBvk3E5cq4hrT+K7qvju8xrwO+njRI7PudVeZ2v3atsEQMkneyhDU7fg5vW0M8wzrGHCZzrSUMLwXy2DuQvp6GJpXflfH44dyrmlXOtNrl2jldTr6YPaF6OMPt7yL3R2epd8Gjc3kLUyczVLrNVAOa/tTb2e5xTUiz1naW9FVe8HnsZnszimknPWcw31iKi6fq3meXPpy8D/t1eauxGRinv3ZmqzHM2tYhn3SR5oqEceLvB3LY97HufB58O0I9q7DGo59gLn1vP3Sa5dxXfpT3zm0KdGA74pCLBKUyuyikwsrx9D+wkMdhbzSE+19gbWUwB8HlDraJ/zmXoU9CjnVHONxVxzAt/Rj+/MpA+tbrbUxBIBViJaoLVJTKjnsOq6P8P9MQTFaTwqO586zGKkppLf1dP8L3KseivrMO11ieqJniS+s0VTAR8LBDiR0YohfjJ6nAVwBdr7HvuSSvanqZV6PbW3sOZoyyWTuWarWAA9FglwIqQ5KWArLLaNluPb1XzackwC57TUrtMsFu81VglwIsVPuyXu63+GjeFcvKsQPgAAAABJRU5ErkJggg=="
local AMBIENT_BOKEH = 26
local AMBIENT_DUST = 64
local AMBIENT_LIGHTS = 6
local AMBIENT_SILK = 9
local AMBIENT_INTRO = 2
local ambientBuilt = false
local ambientStart, ambientLast = 0, -10
local ambientSet: { { [string]: number } } = {}

local function ambientBuild()
    ambientBuilt = true
    for index = 1, 80 do
        ambientSet[index] = {
            A = hash(index, 101), B = hash(index, 102), C = hash(index, 103), D = hash(index, 104), E = hash(index, 105), F = hash(index, 106),
        }
    end
end

local function edgeFade(x: number, y: number, left: number, top: number, right: number, bottom: number, reach: number): number
    return smooth(math.min(x - left, right - x, y - top, bottom - y) / reach)
end

local function ambient(name: string, position: Vector2, size: Vector2, scale: number, alpha: number, z: number, now: number, color: Color3, light: boolean)
    if not ambientBuilt then
        ambientBuild()
    end
    if now - ambientLast > 0.75 then
        ambientStart = now
    end
    ambientLast = now
    alpha *= smooth(math.clamp((now - ambientStart) / AMBIENT_INTRO, 0, 1))
    alpha *= if light then 1.7 else 1
    local width, height = size.X, size.Y
    local left, top = position.X, position.Y
    local right, bottom = left + width, top + height
    local unit = math.clamp(width / 520, 0.8, 2)
    local glow = glowImage()
    if not glow then
        return
    end
    Painter.clip(position, size)
    Painter.fine(true)
    if name == "Bokeh" then
        local ring = picture("oklobubble", BUBBLE_PNG)
        for index = 1, AMBIENT_BOKEH do
            local item = ambientSet[index]
            local radius = (14 + 54 * item.A * item.A) * unit
            local span = height + radius * 4
            local rise = (4 + 14 * item.B) * unit
            local travel = (item.C * span + now * rise) % span
            local y = bottom + radius * 2 - travel
            local x = left + item.D * width + math.sin(now * (0.08 + 0.1 * item.E) + item.F * 6.28) * 22 * unit
            local breath = 0.75 + 0.25 * math.sin(now * (0.3 + 0.4 * item.E) + item.F * 12)
            local fade = edgeFade(x, y, left, top, right, bottom, radius * 1.4)
            local reach = radius * (0.95 + 0.1 * breath)
            local shown = fade * breath * alpha
            Painter.image(glow, Vector2.new(x - reach, y - reach), Vector2.new(reach * 2, reach * 2), 0.16 * shown, z, 0, color, 0)
            if ring and index % 2 == 0 then
                Painter.image(ring, Vector2.new(x - reach * 0.8, y - reach * 0.8), Vector2.new(reach * 1.6, reach * 1.6), 0.5 * shown, z, 0, color, 0)
            elseif ring then
                local small = reach * 0.35
                Painter.image(ring, Vector2.new(x + reach * 0.9 - small, y - reach * 0.6 - small), Vector2.new(small * 2, small * 2), 0.45 * shown, z, 0, color, 0)
            end
        end
    else
        local dot = picture("oklomote", MOTE_PNG)
        local strip = picture("oklobeam", BEAM_PNG)
        if name == "Silk" and strip then
            local long = math.max(width, height) * 1.9
            local centerX, centerY = left + width / 2, top + height / 2
            for index = 1, AMBIENT_SILK do
                local item = ambientSet[index]
                local sway = math.sin(now * (0.035 + 0.02 * item.B) + item.C * 6.28)
                local x = centerX + (item.A - 0.5) * width * 1.5 + sway * 60 * unit
                local pulse = 0.5 + 0.5 * math.sin(now * (0.12 + 0.14 * item.D) + item.E * 6.28)
                local wide = (70 + 150 * item.F) * unit
                Painter.image(strip, Vector2.new(x - wide / 2, centerY - long / 2), Vector2.new(wide, long), (0.09 + 0.14 * pulse) * alpha, z, 0, color, 24 + sway * 6 + (item.B - 0.5) * 10)
                if index % 3 == 0 then
                    Painter.image(strip, Vector2.new(x - 5 * unit, centerY - long * 0.4), Vector2.new(10 * unit, long * 0.8), (0.12 + 0.16 * pulse) * alpha, z, 0, color, 24 + sway * 6 + (item.B - 0.5) * 10)
                end
            end
        else
            for index = 1, AMBIENT_LIGHTS do
                local item = ambientSet[index + 40]
                local x = left + width * (0.1 + 0.8 * item.A) + math.sin(now * (0.03 + 0.03 * item.B) + item.C * 6.28) * 50 * unit
                local y = top + height * (0.15 + 0.7 * item.D) + math.cos(now * (0.025 + 0.03 * item.E) + item.F * 6.28) * 30 * unit
                local breath = 0.5 + 0.5 * math.sin(now * (0.18 + 0.2 * item.B) + item.C * 12)
                local reach = (36 + 40 * item.F) * unit * (0.92 + 0.16 * breath)
                Painter.image(glow, Vector2.new(x - reach, y - reach), Vector2.new(reach * 2, reach * 2), (0.025 + 0.035 * breath) * alpha, z, 0, color, 0)
            end
        end
        for index = 1, (if name == "Silk" then 14 else AMBIENT_DUST) do
            local item = ambientSet[index]
            local depth = item.C
            local x = left + (item.A * width + now * (2 + 10 * depth) * unit) % width
            local y = top + (item.B * height - now * (1 + 5 * depth) * unit) % height
            local twinkle = (0.5 + 0.5 * math.sin(now * (0.5 + 1.3 * item.D) + item.E * 40)) ^ 2
            local reach = (1.3 + 3 * depth) * unit * 1.7
            local shown = (0.25 + 0.7 * twinkle) * edgeFade(x, y, left, top, right, bottom, 22 * unit) * alpha
            if dot then
                Painter.image(dot, Vector2.new(x - reach, y - reach), Vector2.new(reach * 2, reach * 2), shown, z, 0, color, 0)
            else
                Painter.image(glow, Vector2.new(x - reach, y - reach), Vector2.new(reach * 2, reach * 2), shown * 0.8, z, 0, color, 0)
            end
        end
    end
    Painter.fine(false)
    Painter.unclip()
end

function Skyfx.ambient(name: string, position: Vector2, size: Vector2, scale: number, alpha: number, z: number, now: number, color: Color3, light: boolean)
    if alpha > 0.004 and size.X >= 80 and size.Y >= 80 then
        ambient(name, position, size, scale, alpha, z, now, color, light)
    end
end

function Skyfx.count(name: string?): number
    local spec = if name then FIELDS[name] else nil
    if not spec then
        return 0
    end
    return if name == "lightning" then spec.N + BOLT_RECTS else spec.N
end

function Skyfx.draw(name: string, position: Vector2, size: Vector2, radius: number, scale: number, alpha: number, z: number, now: number, first: Color3, second: Color3, pointer: Vector2?)
    if name == "orbs" or name == "orbshaunted" then
        if alpha > 0.004 and size.X >= 40 and size.Y >= 40 then
            orbs(position, size, radius, scale, alpha, z, now, first, second, name == "orbshaunted")
        end
        return
    end
    if alpha <= 0.004 or not FIELDS[name] then
        return
    end
    local left = position.X + 4
    local top = position.Y + radius * 0.55
    local width = size.X - 8
    local height = size.Y - radius * 1.1
    if width < 40 or height < 40 then
        return
    end
    field(name, left, top, width, height, scale, alpha, z, now, first, second)
end

function Skyfx.strike(name: string, position: Vector2, size: Vector2, radius: number, scale: number, alpha: number, z: number, now: number, first: Color3, second: Color3)
    if name ~= "lightning" or alpha <= 0.004 or size.X < 48 or size.Y < 40 + radius * 1.1 then
        return
    end
    bolt(position.X + 4, position.Y + radius * 0.55, size.X - 8, size.Y - radius * 1.1, scale, alpha, z, now, first, second, position, size, radius)
end

local PULSE_PERIOD = 8

function Skyfx.popup(position: Vector2, size: Vector2, rounding: number, alpha: number, z: number, now: number)
    local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
    local turn = now * 5
    local breath = math.sin(now * math.pi / PULSE_PERIOD) ^ 2
    Painter.fade(position, size, white, 0, 1, turn % 360, alpha * 0.05, z, rounding)
    Painter.fade(position, size, black, 0, 1, (turn + 180 + 40 * math.sin(now * 0.21)) % 360, alpha * 0.26, z, rounding)
    Painter.fade(position, size, white, 0, 1, (90 - now * 3) % 360, alpha * (0.02 + 0.03 * breath), z, rounding)
end

return Skyfx
end
modules["ui/spec"] = function(...)

local Spec = {}

type Map = { [string]: any }

function Spec.section(title: string): Map
    return { title = title, rows = {} }
end

function Spec.tab(name: string, label: string, group: string): Map
    return { name = name, label = label, group = group, sections = {} }
end

local function eachControl(tab: Map, visit: (Map) -> ())
    for _, section in tab.sections do
        for _, row in section.rows do
            if row.kind == "pair" then
                visit(row.left)
                visit(row.right)
            else
                visit(row)
            end
        end
    end
end

function Spec.eachControl(tab: Map, visit: (Map) -> ())
    eachControl(tab, visit)
end

function Spec.assignIds(tab: Map)
    local count = 0
    eachControl(tab, function(spec: Map)
        count += 1
        spec.id = tab.name .. "/" .. tostring(count)
    end)
end

return Spec
end
modules["ui/typing"] = function(...)

local import: (string) -> any = ...
local Draw: typeof(require("../render/draw")) = import("render/draw")

local Typing = {}
Typing.__index = Typing

type App = { [string]: any }

local NUMERIC_PATTERN = "[%d%.%-]"

function Typing.new(app: App)
    return setmetatable({ App = app, Box = nil :: any, Bound = nil :: string?, Lost = nil :: any }, Typing)
end

type Self = typeof(Typing.new(nil :: any))

local function accepts(options: { [string]: any }, char: string, length: number): boolean
    local limit = options.maxLength
    if limit and length >= limit then
        return false
    end
    local pattern = options.filter or (if options.numeric then NUMERIC_PATTERN else nil)
    return pattern == nil or string.match(char, "^" .. pattern .. "$") ~= nil
end

local function clean(options: { [string]: any }, text: string): string
    local kept: { string } = {}
    for index = 1, #text do
        local char = string.sub(text, index, index)
        if accepts(options, char, #kept) then
            kept[#kept + 1] = if options.upper then string.upper(char) else char
        end
    end
    return table.concat(kept)
end

local function createBox(self: Self): any
    local box = Instance.new("TextBox")
    box.BackgroundTransparency = 1
    box.TextTransparency = 1
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.MultiLine = false
    box.Text = ""
    box.Position = UDim2.fromOffset(0, 0)
    box.Size = UDim2.fromOffset(2, 2)
    box.ZIndex = 1
    box.Parent = Draw.root()
    self.Lost = box.FocusLost:Connect(function(enterPressed: boolean?)
        local app = self.App
        local hover = app.HoverKey
        if not enterPressed and self.Bound == "head:search" and app.Focus == self.Bound and type(hover) == "string" and string.sub(hover, 1, 11) == "head:search" then
            task.defer(function()
                if self.Bound == "head:search" and self.Box then
                    pcall(function()
                        self.Box:CaptureFocus()
                    end)
                end
            end)
            return
        end
        if self.Bound ~= nil and app.Focus == self.Bound then
            self:apply()
        end
    end)
    return box
end

local function release(self: Self)
    local box = self.Box
    self.Bound = nil
    if box then
        pcall(function()
            box:ReleaseFocus()
        end)
    end
end

function Typing.apply(self: Self)
    local app = self.App
    local focus: string? = app.Focus
    local options = app.InputOptions
    app.Focus = nil
    app.InputOptions = nil
    local box = self.Box
    local text = if focus then app.Buffers[focus] or "" else ""
    if box and focus and self.Bound == focus then
        text = clean(options or {}, box.Text)
        app.Buffers[focus] = text
    end
    release(self)
    if focus and options and options.commit then
        pcall(options.commit, text)
    end
end

function Typing.step(self: Self, _now: number)
    local app = self.App
    local focus: string? = app.Focus
    if not focus or app:isCapturing() then
        if self.Bound then
            release(self)
        end
        return
    end
    local box = self.Box
    if not box or not box.Parent then
        box = createBox(self)
        self.Box = box
    end
    local options = app.InputOptions or {}
    if self.Bound ~= focus then
        self.Bound = focus
        box.Text = app.Buffers[focus] or ""
        task.defer(function()
            if self.Bound == focus and self.Box then
                pcall(function()
                    self.Box:CaptureFocus()
                end)
            end
        end)
        return
    end
    local text = box.Text
    local cleaned = clean(options, text)
    if cleaned ~= text then
        box.Text = cleaned
    end
    app.Buffers[focus] = cleaned
end

function Typing.reset(self: Self)
    release(self)
end

function Typing.destroy(self: Self)
    release(self)
    if self.Lost then
        pcall(function()
            self.Lost:Disconnect()
        end)
        self.Lost = nil
    end
    if self.Box then
        pcall(function()
            self.Box:Destroy()
        end)
        self.Box = nil
    end
end

return Typing
end
modules["ui/updatespage"] = function(...)

local import: (string) -> any = ...
local Builder: typeof(require("./builder")) = import("ui/builder")
local BirdSheet: typeof(require("./birdsheet")) = import("ui/birdsheet")
local Color: typeof(require("../core/color")) = import("core/color")
local Fonts: typeof(require("./fonts")) = import("ui/fonts")
local Logo: typeof(require("./logo")) = import("ui/logo")
local Motion: typeof(require("./motion")) = import("ui/motion")
local Painter: typeof(require("./painter")) = import("ui/painter")
local Press: typeof(require("./press")) = import("ui/press")
local Skyfx: typeof(require("./skyfx")) = import("ui/skyfx")

local UpdatesPage = {}

type Map = { [string]: any }
type Entry = { Kind: string, Rows: { string }, Top: number }

local KINDS = { "Added", "Changed", "Removed", "Fixed" }

local HEAD = 92
local HEAD_PLAIN = 92
local INTRO = 28
local TITLE_X = 82
local LOGO = 64
local PILL = 30
local PILL_GAP = 6
local ROW = 17
local ENTRY_GAP = 5
local BODY_TOP = 7
local BODY_BOTTOM = 8
local MARK_X = 16
local TEXT_X = 32
local TEXT_SIZE = 12
local NAME_SIZE = 12.5
local CLOSING = 40
local RESPONSE, RATIO = 0.42, 1
local FADE_IN = 0.3
local FADE_OUT = 0.16
local RISE = 8

local wrapped: { [string]: { string } } = {}

local function wrap(kit: Map, text: string, limit: number): { string }
    local key = math.floor(limit) .. "|" .. tostring(kit.App.TextScale) .. "|" .. Painter.font() .. "|" .. text
    local cached = wrapped[key]
    if cached then
        return cached
    end
    local rows: { string } = {}
    local current = ""
    for word in string.gmatch(text, "%S+") do
        local candidate = if current == "" then word else current .. " " .. word
        if kit:measure(candidate, TEXT_SIZE) <= limit then
            current = candidate
        else
            if current ~= "" then
                table.insert(rows, current)
            end
            current = word
            while #current > 1 and kit:measure(current, TEXT_SIZE) > limit do
                local cut = #current - 1
                while cut > 1 and kit:measure(string.sub(current, 1, cut), TEXT_SIZE) > limit do
                    cut -= 1
                end
                table.insert(rows, string.sub(current, 1, cut))
                current = string.sub(current, cut + 1)
            end
        end
    end
    if current ~= "" or #rows == 0 then
        table.insert(rows, current)
    end
    wrapped[key] = rows
    return rows
end

local function entries(kit: Map, group: Map, width: number): ({ Entry }, number)
    local list: { Entry } = {}
    local at = BODY_TOP
    local limit = width - TEXT_X - 10
    for _, kind in KINDS do
        for _, text in group[kind] or {} do
            local rows = wrap(kit, tostring(text), limit)
            table.insert(list, { Kind = kind, Rows = rows, Top = at })
            at += #rows * ROW + ENTRY_GAP
        end
    end
    if #list == 0 then
        return list, 0
    end
    return list, at - ENTRY_GAP + BODY_BOTTOM
end

local function factor(kit: Map): number
    return kit.ScreenSize.X / kit.Width
end

local function mark(kit: Map, _kind: string, cx: number, cy: number, color: Color3)
    kit:solid(cx - 2, cy - 2, 4, 4, color, 2)
end

local function chevron(kit: Map, cx: number, cy: number, turn: number, color: Color3)
    local asset, pixels = Logo.icon(kit.App, "chevron", 11 * factor(kit))
    if asset then
        local middle = kit:p(cx, cy)
        local corner = Vector2.new(math.floor(middle.X - pixels / 2 + 0.5), math.floor(middle.Y - pixels / 2 + 0.5))
        Painter.image(asset, corner, Vector2.new(pixels, pixels), kit.Alpha, kit.ZText, 0, color, 90 * turn)
        return
    end
    local angle = math.rad(90 * turn)
    local tipX, tipY = cx + math.cos(angle) * 1.6, cy + math.sin(angle) * 1.6
    for _, side in { -1, 1 } do
        local wing = angle + math.rad(180 + 45 * side)
        kit:line(tipX, tipY, tipX + math.cos(wing) * 4.5, tipY + math.sin(wing) * 4.5, color, 1.6, 1)
    end
end

local function emblem(kit: Map, cx: number, cy: number, shown: number)
    local app = kit.App
    local logo: string? = app.LogoAsset
    local bird = BirdSheet.ready()
    if not (logo or bird) or shown <= 0 then
        return
    end
    local scale = factor(kit)
    local now = tonumber(app.Now) or os.clock()
    local moving = app.State.AnimationsEnabled and not app.State.HighPerformanceMode
    local breathe = if moving then 1 + 0.025 * math.sin(now * 2.1) else 1
    local float = if moving then math.sin(now * 1.3) * 2 else 0
    local middle = kit:p(cx, cy + float)
    Painter.fine(true)
    local halo = Skyfx.halo()
    if halo then
        local side = LOGO * 1.5 * scale * (1 + 0.04 * (if moving then math.sin(now * 2.1 + 0.6) else 0))
        Painter.image(halo, middle - Vector2.new(side, side) / 2, Vector2.new(side, side), kit.Alpha * shown * 0.5, kit.ZControl)
    end
    if bird then
        local play = app.BirdPlay
        if not play or now - play.Last > 0.4 then
            play = { Start = now, Last = now }
            app.BirdPlay = play
        end
        play.Last = now
        local draw = BirdSheet.FRAMES / 30
        local cycle = draw + 3.2
        local time = (now - play.Start) % cycle
        local frame = if app.State.AnimationsEnabled then time * 30 else BirdSheet.FRAMES
        local fade = if app.State.AnimationsEnabled then math.clamp((cycle - time) / 0.5, 0, 1) else 1
        local birdSide = math.floor(LOGO * 1.3 * scale + 0.5)
        local still = kit:p(cx, cy)
        BirdSheet.draw(frame, Vector2.new(math.floor(still.X - birdSide / 2 + 0.5), math.floor(still.Y - birdSide / 2 + 0.5)), birdSide, kit.Alpha * shown * fade, kit.ZText)
        Painter.fine(false)
        return
    end
    local side = LOGO * scale * breathe * (0.92 + 0.08 * shown)
    local box = Vector2.new(side, side)
    local tinted = app.Options.Logo ~= nil and app.Options.Logo.Emblem == true
    Painter.image(logo, middle - box / 2, box, kit.Alpha * shown, kit.ZText, if tinted then 0 else side * 0.22, if tinted then app.Pal.Accent else nil)
    Painter.fine(false)
end

local function body(kit: Map, scope: string, list: { Entry }, top: number, edge: number, full: number, snap: (number) -> number, appear: { number }, opening: boolean)
    local app = kit.App
    local pal = app.Pal
    local state = app.State
    local still = not state.AnimationsEnabled or state.HighPerformanceMode
    local step = math.clamp(tonumber(app.Dt) or 0, 0, 0.05) * Motion.speed(state)
    local base = kit.Alpha
    local moving, lit = edge < full - 1, false
    for index, entry in list do
        local goal = if opening and edge >= entry.Top + 2 then 1 else 0
        local value = appear[index] or goal
        if still then
            value = goal
        elseif value < goal then
            value = math.min(goal, value + step / FADE_IN)
        elseif value > goal then
            value = math.max(goal, value - step / FADE_OUT)
        end
        appear[index] = value
        moving = moving or value ~= goal
        lit = lit or value > 0
    end
    if not lit then
        return
    end
    local fromX, fromY, wide, tall = Painter.clipBox()
    if moving then
        local corner, far = kit:p(-4, top), kit:p(kit.Width + 4, top + math.max(0, edge))
        local left, upper, right, lower = corner.X, corner.Y, far.X, far.Y
        if fromX and fromY and wide and tall then
            left, upper = math.max(left, fromX), math.max(upper, fromY)
            right, lower = math.min(right, fromX + wide), math.min(lower, fromY + tall)
        end
        Painter.clip(Vector2.new(left, upper), Vector2.new(math.max(0, right - left), math.max(0, lower - upper)))
    end
    for index, entry in list do
        local value = appear[index]
        kit:nest(scope .. ":" .. index, function()
            local seen = Motion.out(value)
            local y = snap(top + entry.Top + (1 - seen) * RISE)
            kit.Alpha = base * seen
            mark(kit, entry.Kind, MARK_X, y + ROW / 2, Color.lerp(pal.Sub, pal.Text, 0.55))
            for row, text in entry.Rows do
                kit:text(text, TEXT_X, y + (row - 1) * ROW + ROW / 2, TEXT_SIZE, Color.lerp(pal.Sub, pal.Text, 0.8), false, true)
            end
            kit.Alpha = base
        end)
    end
    if fromX and fromY and wide and tall then
        Painter.clip(Vector2.new(fromX, fromY), Vector2.new(wide, tall))
    else
        Painter.unclip()
    end
end

local function chipWidth(kit: Map, group: Map, count: number): number
    local badge = math.max(22, math.ceil(kit:measure(tostring(count), 10.5)) + 12)
    return math.ceil(TEXT_X + kit:measure(tostring(group.Mode), NAME_SIZE) + 10 + badge + 8)
end

local function pill(kit: Map, key: string, group: Map, count: number, top: number, height: number, open: number, hover: number)
    local app = kit.App
    local pal = app.Pal
    local width = chipWidth(kit, group, count)
    local grown = math.clamp(open, 0, 1)
    local press = Press.scale(app, app.Springs, key .. ":press", key)
    local fill = math.min(1, app.Alpha.Btn / math.max(0.01, app.Alpha.Text))
    local full = kit:s(width, height)
    local size = full * press
    local position = kit:p(0, top) + (full - size) / 2
    Painter.rect(position, size, Color.lerp(pal.Panel, pal.Accent, 0.12 + 0.22 * hover * (1 - grown) - 0.06 * grown), kit.Alpha * fill, kit.ZControl, 12)
    local middle = top + height / 2
    kit:nest(key .. ":arrow", function()
        chevron(kit, MARK_X, middle, grown, Color.lerp(pal.Sub, pal.Text, math.max(hover, grown)))
    end)
    kit:text(tostring(group.Mode), TEXT_X, middle, NAME_SIZE, Color.lerp(Color.lerp(pal.Sub, pal.Text, 0.8), pal.Text, math.max(hover, grown)), false, true)
    local label = tostring(count)
    local badge = math.max(22, math.ceil(kit:measure(label, 10.5)) + 12)
    local badgeX = width - 6 - badge
    kit:solid(badgeX, middle - 9, badge, 18, Color.lerp(pal.Main, pal.Accent, 0.12 * grown), 9, 0.65 * fill)
    kit:text(label, badgeX + badge / 2, middle, 10.5, Color.lerp(pal.Sub, pal.Text, grown), true, true)
end

local function block(section: Map, version: string, date: string?, groups: { Map }?, lines: { string }?, closing: string?, openFirst: boolean)
    local holder = { Value = HEAD }
    local goal: { [number]: number } = {}
    local springs: { [string]: any } = {}
    local hover: { [number]: number } = {}
    local appear: { [number]: { number } } = {}
    local plainAppear: { number } = {}
    local logoShown = 0
    for index in groups or {} do
        goal[index] = if openFirst and index == 1 then 1 else 0
        hover[index] = 0
        appear[index] = {}
    end
    local plain: Map = { Fixed = lines or {} }
    section:add({
        Type = "Custom",
        Bare = true,
        Height = holder,
        Render = function(kit: Map, app: Map)
            local pal = app.Pal
            local state = app.State
            local width = kit.Width
            local still = not state.AnimationsEnabled or state.HighPerformanceMode
            local dt = math.clamp(tonumber(app.Dt) or 0, 0, 0.05)
            local owner = tostring(kit.Owner)
            local unit = kit.ScreenSize.Y / kit.Height
            local origin = kit.Position.Y
            local function snap(value: number): number
                return (math.floor(origin + value * unit + 0.5) - origin) / unit
            end
            local pillHeight = math.max(2, 2 * math.floor(PILL * unit / 2 + 0.5)) / unit
            local dated = date ~= nil and date ~= ""
            local head = if dated then HEAD else HEAD_PLAIN
            logoShown = if still then (if app.LogoAsset then 1 else 0) else Motion.ease(state, logoShown, if app.LogoAsset then 1 else 0, dt, 7)
            local left = if app.LogoAsset or BirdSheet.ready() then TITLE_X else 2
            kit:nest(owner .. ":head", function()
                kit:text("V" .. version, left, 22, 24, pal.Text, false, true, Fonts.find("Gotham Bold"))
                kit:text(tostring(app.Options.Title or ""), left, 47, 14, pal.Text, false, true)
                kit:text(if dated then "Released " .. tostring(date) else "", left, 67, 12, pal.Sub, false, true)
            end)
            kit:nest(owner .. ":logo", function()
                emblem(kit, 2 + LOGO / 2, head / 2 - 4, logoShown)
            end)
            kit:nest(owner .. ":intro", function()
                kit:text(if (groups and #groups > 0) or #plain.Fixed > 0 then "This update contains the following changes:" else "", 3, head + INTRO / 2 - 2, 12, pal.Sub, false, true)
            end)
            local y = head + INTRO
            for index, group in groups or {} do
                local scope = owner .. ":mode" .. index
                local list, used = entries(kit, group, width)
                local open = if still then goal[index] else Motion.spring(state, springs, tostring(index), goal[index], app.Dt, RESPONSE, RATIO)
                if still then
                    springs[tostring(index)] = nil
                end
                local shown = math.clamp(open, 0, 1)
                local key = scope .. ":pill"
                hover[index] = Motion.ease(state, hover[index], if kit:hovered(key) then 1 else 0, dt, 14)
                local top = snap(y)
                local edge = snap(top + pillHeight + used * shown) - top - pillHeight
                kit:nest(scope, function()
                    pill(kit, key, group, #list, top, pillHeight, shown, hover[index])
                end)
                body(kit, scope, list, top + pillHeight, edge, used, snap, appear[index], goal[index] == 1)
                kit:hit(key, 0, top, chipWidth(kit, group, #list), pillHeight, function()
                    goal[index] = 1 - goal[index]
                end)
                y = top + pillHeight + edge + PILL_GAP
            end
            if #plain.Fixed > 0 then
                local list, used = entries(kit, plain, width)
                body(kit, owner .. ":plain", list, snap(y), used, used, snap, plainAppear, true)
                y += used + PILL_GAP
            end
            kit:nest(owner .. ":closing", function()
                kit:text(closing or "", 3, y - PILL_GAP + CLOSING / 2, 11.5, pal.Sub, false, true)
            end)
            y += if closing and closing ~= "" then CLOSING - PILL_GAP else 0
            holder.Value = math.max(head + INTRO, math.ceil(y))
        end,
    })
end

function UpdatesPage.build(window: Map, spec: Map): Map
    BirdSheet.start()
    local tab = Builder.newTab(window, spec.Name or "Updates", { Group = spec.Group or "Settings", Late = true })
    block(tab:section("V" .. tostring(spec.Version)), tostring(spec.Version), spec.Date, spec.Groups, spec.Lines, spec.Closing, true)
    for _, entry in spec.History or {} do
        block(tab:section("V" .. tostring(entry.Version)), tostring(entry.Version), entry.Date, entry.Groups, entry.Lines, spec.Closing, false)
    end
    return tab
end

return UpdatesPage
end
modules["ui/welcome"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")
local Effects: typeof(require("./effects")) = import("ui/effects")
local Motion: typeof(require("./motion")) = import("ui/motion")
local Painter: typeof(require("./painter")) = import("ui/painter")
local Storage: typeof(require("../core/storage")) = import("core/storage")
local Util: typeof(require("../core/util")) = import("core/util")

local Welcome = {}

type App = { [string]: any }

local DEFAULT_WIDTH = 400
local Z_CARD, Z_TEXT = 30, 32
local MARGIN = 9
local EDGE, SECTION = 16, 14
local TITLE_Y = EDGE
local HEADING_Y = TITLE_Y + 26
local RULE_Y = HEADING_Y + 20
local ROWS_Y = RULE_Y + SECTION
local ROW_GAP, ROW_PAD, ROW_LINE, ROW_TEXT = 4, 5, 17, 12
local BUTTON_WIDTH, BUTTON_HEIGHT = 84, 28

local function reveal(elapsed: number, delay: number, duration: number): number
    local t = math.clamp((elapsed - delay) / math.max(0.01, duration), 0, 1)
    return t
end

local function smoother(t: number): number
    return t * t * t * (t * (t * 6 - 15) + 10)
end

function Welcome.new(): { [string]: any }
    return { Start = 0, Closing = false, ClosingStart = 0, Fade = 0, Hover = 0, WasDown = false }
end

function Welcome.marker(app: App): string
    return app.Folder .. "/welcome_seen.txt"
end

function Welcome.pending(app: App): boolean
    return app.Options.Welcome ~= nil and not Storage.isFile(Welcome.marker(app))
end

local function wrapped(label: string, size: number, limit: number): { string }
    local rows: { string } = {}
    local current = ""
    for word in string.gmatch(label, "%S+") do
        local candidate = if current == "" then word else current .. " " .. word
        if current ~= "" and Painter.textWidth(candidate, size) > limit then
            table.insert(rows, current)
            current = word
        else
            current = candidate
        end
    end
    if current ~= "" then
        table.insert(rows, current)
    end
    return rows
end

local function text(app: App, label: string, position: Vector2, size: number, color: Color3, alpha: number, center: boolean?)
    Painter.text(label, position, size, color, alpha, Z_TEXT, center, false)
end

function Welcome.render(app: App, now: number): boolean
    local session = app.Welcome
    local copy: { [string]: any } = app.Options.Welcome
    local state = app.State
    local pal = app.Pal
    if session.Start == 0 then
        session.Start = now
    end

    local viewport: Vector2 = app.Viewport
    local popupWidth = math.clamp(tonumber(copy.Width) or DEFAULT_WIDTH, 300, 700)
    local wrapScale = math.max(0.10, math.min(state.UIScale, (viewport.X - 42) / popupWidth, 1.10))
    local textLimit = (popupWidth - MARGIN * 2 - EDGE * 2 - ROW_TEXT * 2) * wrapScale
    local blocks: { { string } } = {}
    local contentHeight = ROWS_Y
    for index, label in copy.Lines do
        blocks[index] = wrapped(label, 13 * wrapScale, textLimit)
        contentHeight += ROW_PAD * 2 + #blocks[index] * ROW_LINE + ROW_GAP
    end
    if #blocks > 0 then
        contentHeight -= ROW_GAP
    end
    contentHeight += SECTION + BUTTON_HEIGHT + EDGE
    local POPUP_SIZE = Vector2.new(popupWidth, math.clamp(tonumber(copy.Height) or contentHeight + MARGIN * 2, 200, 700))
    local baseWidth, baseHeight = app.M.Width, app.M.Height
    local fitX = (viewport.X - 36) / baseWidth
    local fitY = (viewport.Y - 36) / baseHeight
    local fullScale = math.max(0.10, math.min(state.UIScale, fitX, fitY))
    local fullSize = Util.roundVector2(Vector2.new(baseWidth, baseHeight) * fullScale)
    local fullPos = Util.roundVector2(Vector2.new(viewport.X * 0.5 - fullSize.X * 0.5, viewport.Y * 0.5 - fullSize.Y * 0.5))

    local popupFitX = (viewport.X - 42) / POPUP_SIZE.X
    local popupFitY = (viewport.Y - 42) / POPUP_SIZE.Y
    local popupScale = math.max(0.10, math.min(state.UIScale, popupFitX, popupFitY, 1.10))
    local popupSize = Util.roundVector2(POPUP_SIZE * popupScale)
    local popupPos = Util.roundVector2(Vector2.new(viewport.X * 0.5 - popupSize.X * 0.5, viewport.Y * 0.5 - popupSize.Y * 0.5))

    local elapsed = now - session.Start
    session.Fade = Motion.ease(state, session.Fade, 1, app.Dt, 10)
    local fade = math.clamp(session.Fade, 0, 1)

    local raw, closing = 0, 0
    if session.Closing then
        closing = now - session.ClosingStart
        raw = math.clamp((closing - 0.20) / 1.38, 0, 1)
    end
    local expand = smoother(raw)
    local position = Util.roundVector2(popupPos + (fullPos - popupPos) * expand)
    local size = Util.roundVector2(popupSize + (fullSize - popupSize) * expand)
    local scale = popupScale + (fullScale - popupScale) * expand
    local contentFade = if session.Closing then math.clamp(1 - closing / 0.30, 0, 1) else 1
    local merge = math.clamp((raw - 0.12) / 0.68, 0, 1)
    local rounding = math.max(6, math.round((16 - expand) * scale))

    Painter.rect(position, size, pal.Main, fade, 1, rounding)
    Effects.outline(state, now, position, size, scale, fade, "main")

    local margin = MARGIN * popupScale * (1 - merge)
    local cardPos = Util.roundVector2(position + Vector2.new(margin, margin))
    local cardSize = Util.roundVector2(size - Vector2.new(margin * 2, margin * 2))
    Painter.rect(cardPos, cardSize, Color.lerp(pal.Panel, pal.Main, 0.35), fade * (1 - merge) * 0.96, Z_CARD, math.max(8, math.round(16 * scale)))

    local content = fade * contentFade
    local unit = popupScale
    local width = cardSize.X / unit
    local function line(label: string, x: number, y: number, delay: number, duration: number, color: Color3, center: boolean, size: number)
        local shown = reveal(elapsed, delay, duration) * content
        local at = cardPos + Vector2.new(x * unit, (y + (1 - shown) * 8 - raw * 7) * unit)
        text(app, label, Util.roundVector2(at), size * unit, color, shown, center)
    end
    line(copy.Title, EDGE, TITLE_Y, 0.15, 0.55, pal.Text, false, 20)
    line(copy.Heading, EDGE, HEADING_Y, 0.35, 0.55, pal.Sub, false, 12)
    local ruleShown = reveal(elapsed, 0.30, 0.50)
    Painter.rect(
        Util.roundVector2(cardPos + Vector2.new(EDGE * unit, RULE_Y * unit)),
        Util.roundVector2(Vector2.new((width - EDGE * 2) * unit * ruleShown, math.max(1, unit))),
        pal.Off, content * 0.8, Z_CARD + 1, 0
    )

    local cursor = ROWS_Y
    for index, rows in blocks do
        local rowHeight = ROW_PAD * 2 + #rows * ROW_LINE
        local delay = 0.55 + (index - 1) * 0.12
        local shown = reveal(elapsed, delay, 0.45) * content
        local rowPosition = Util.roundVector2(cardPos + Vector2.new((EDGE + (1 - shown) * 10) * unit, (cursor - raw * 7) * unit))
        local rowSize = Util.roundVector2(Vector2.new((width - EDGE * 2) * unit, rowHeight * unit))
        Painter.rect(rowPosition, rowSize, pal.Panel, shown * (1 - merge) * 0.95, Z_CARD + 1, 16)
        for rowIndex, row in rows do
            line(row, EDGE + ROW_TEXT, cursor + ROW_PAD + (ROW_LINE - 13) / 2 + (rowIndex - 1) * ROW_LINE, delay, 0.45, pal.Text, false, 13)
        end
        cursor += rowHeight + ROW_GAP
    end

    local barY = cardSize.Y / unit - EDGE - BUTTON_HEIGHT
    line(copy.Footer, EDGE, barY + BUTTON_HEIGHT / 2 - 6, 1.70, 0.50, pal.Sub, false, 12)
    local buttonReveal = reveal(elapsed, 1.90, 0.50) * content
    local buttonSize = Util.roundVector2(Vector2.new(BUTTON_WIDTH * unit, BUTTON_HEIGHT * unit))
    local buttonPos = Util.roundVector2(Vector2.new(cardPos.X + cardSize.X - buttonSize.X - EDGE * unit, cardPos.Y + barY * unit))
    local hovered = buttonReveal > 0.80 and not session.Closing and Util.contains(app.Mouse, buttonPos, buttonSize)
    session.Hover = Motion.ease(state, session.Hover, if hovered then 1 else 0, app.Dt, 18)
    Painter.rect(buttonPos, buttonSize, Color.lerp(pal.Panel, pal.Accent, 0.15 + 0.85 * session.Hover), buttonReveal, Z_CARD + 1, 16)
    Painter.text(
        "Close",
        buttonPos + buttonSize / 2,
        13 * unit,
        Color.lerp(pal.Text, Color3.new(0.07, 0.08, 0.08), session.Hover),
        buttonReveal,
        Z_TEXT,
        true,
        true
    )

    local pressed = app.LeftDown and not session.WasDown
    session.WasDown = app.LeftDown
    if pressed and hovered then
        session.Closing = true
        session.ClosingStart = now
        Storage.ensureFolder(app.Folder)
        Storage.write(Welcome.marker(app), "seen")
    end

    if session.Closing and raw >= 0.995 then
        app:finishWelcome(fullPos, fullScale)
        return false
    end
    return true
end

function Welcome.handoff(app: App, scale: number?)
    local state = app.State
    local viewport: Vector2 = app.Viewport
    local fullScale = math.max(0.10, math.min(scale or state.UIScale, (viewport.X - 36) / app.M.Width, (viewport.Y - 36) / app.M.Height))
    local fullSize = Util.roundVector2(Vector2.new(app.M.Width, app.M.Height) * fullScale)
    local fullPos = Util.roundVector2(Vector2.new(viewport.X * 0.5 - fullSize.X * 0.5, viewport.Y * 0.5 - fullSize.Y * 0.5))
    app:finishWelcome(fullPos, fullScale)
end

return Welcome
end
modules["ui/widgets"] = function(...)

local import: (string) -> any = ...
local Color: typeof(require("../core/color")) = import("core/color")
local Fonts: typeof(require("./fonts")) = import("ui/fonts")
local Hits: typeof(require("./hits")) = import("ui/hits")
local Kit: typeof(require("./popups/kit")) = import("ui/popups/kit")
local Motion: typeof(require("./motion")) = import("ui/motion")
local Painter: typeof(require("./painter")) = import("ui/painter")
local Press: typeof(require("./press")) = import("ui/press")
local Skyfx: typeof(require("./skyfx")) = import("ui/skyfx")

local Widgets = {}

export type Fx = {
    Alpha: number,
    Scale: number,
}

type App = { [string]: any }
type Spec = { [string]: any }

Widgets.HEIGHTS = { toggle = 40, slider = 50, button = 36, dropdown = 36, bindrow = 30 }
Widgets.GAP = 4

local Z_BG, Z_TEXT, Z_CONTROL, Z_CONTROL_TEXT = 5, 6, 7, 8
local BIND_WIDTH, BIND_HEIGHT = 58, 22
local SWITCH_WIDTH, SWITCH_HEIGHT = 42, 22
local KNOB = 16
local INSET = 12
local TOGGLE_BIND_INSET = INSET + SWITCH_WIDTH + 8 + BIND_WIDTH
local BUTTON_BIND_INSET = INSET + BIND_WIDTH
local VALUE_WIDTH, VALUE_HEIGHT, VALUE_GAP = 46, 22, 16

local function anim(spec: Spec, name: string): number
    local values = spec.Anim
    if not values then
        values = {}
        spec.Anim = values
    end
    return values[name] or 0
end

local function easeTo(app: App, spec: Spec, name: string, goal: number, speed: number): number
    local value = Motion.ease(app.State, anim(spec, name), goal, app.Dt, speed)
    spec.Anim[name] = value
    return value
end

local function clamp01(value: number): number
    return math.clamp(value, 0, 1)
end

local function kick(spec: Spec, name: string)
    anim(spec, name)
    spec.Anim[name] = 1
end

local function aura(app: App, spec: Spec, name: string, position: Vector2, size: Vector2, rounding: number, level: number, ringLevel: number, fx: Fx, spread: number)
    local pal = app.Pal
    local tone = 0.5 * (0.4 + 0.6 * pal.Pick)
    local pulse = easeTo(app, spec, name .. "Pulse", 0, 3.2 * Motion.speed(app.State))
    local unit = app.Unit
    local alpha = app.Alpha.Btn * fx.Alpha * tone
    local spill = Vector2.new(spread * unit, spread * unit)
    Painter.image(Skyfx.glow() or "", position - spill + Vector2.new(0, 3 * unit), size + spill * 2, alpha * level * (1 - pal.Pick), Z_BG, 0, pal.Accent)
    Painter.border(position, size, rounding, pal.Accent, alpha * pulse * 0, Z_CONTROL_TEXT + 1, 1.5)
    local pad = 1.5 * unit
    Painter.border(position - Vector2.new(pad, pad), size + Vector2.new(pad * 2, pad * 2), rounding + pad, pal.Accent, alpha * 0.22 * ringLevel * (1 - pal.Pick), Z_CONTROL_TEXT + 1, 2.5)
end

local function rowShow(app: App, hover: number): number
    return 1 - app.Pal.Pick * (1 - clamp01(hover))
end

local function disabledMix(app: App, color: Color3, disabled: number): Color3
    return Color.lerp(color, app.Pal.Main, disabled)
end

local function springTo(app: App, spec: Spec, name: string, goal: number, response: number, ratio: number): number
    local bag = spec.Spr
    if not bag then
        bag = {}
        spec.Spr = bag
    end
    return Motion.spring(app.State, bag, name, goal, app.Dt, response, ratio)
end

local function pressScale(app: App, spec: Spec, name: string, key: any, enabled: boolean?): number
    local bag = spec.Spr
    if not bag then
        bag = {}
        spec.Spr = bag
    end
    local shrink = Press.scale(app, bag, name, key, enabled)
    return if name == "press" then 1 + (shrink - 1) * (1 - app.Pal.Pick) else shrink
end

local shrinkBox = Press.box

local function fitted(text: string, size: number, limit: number): (string, number)
    if limit <= 0 or #text * size * 0.6 <= limit or Painter.textWidth(text, size) <= limit then
        return text, size
    end
    local smaller = math.max(size * 0.76, size * limit / Painter.textWidth(text, size))
    if Painter.textWidth(text, smaller) <= limit then
        return text, smaller
    end
    local cut = #text
    while cut > 1 and Painter.textWidth(string.sub(text, 1, cut) .. "..", smaller) > limit do
        cut -= 1
    end
    return string.sub(text, 1, cut) .. "..", smaller
end

local function region(app: App, key: any, position: Vector2, size: Vector2, click: (() -> ())?, drag: ((Vector2) -> ())?)
    if app.Modal then
        return
    end
    Hits.add({ key = key, position = position, size = size, click = click, drag = drag })
end

local function isDisabled(app: App, spec: Spec): boolean
    if spec.gated and app:get(spec.gated) ~= true then
        return true
    end
    local rule = spec.disabled
    return rule ~= nil and rule(app) == true
end

local function drawSwitch(app: App, spec: Spec, boxPos: Vector2, boxSize: Vector2, scale: number, fx: Fx, disabled: number, hover: number)
    local pal = app.Pal
    local on = spec.get() == true
    local value = springTo(app, spec, "on", if on then 1 else 0, 0.34, 0.6)
    local shown = clamp01(value)
    local raw = app:size(SWITCH_WIDTH, SWITCH_HEIGHT) * scale
    local size = Vector2.new(math.round(raw.X), math.round(raw.Y))
    local rawPosition = boxPos + Vector2.new(boxSize.X - (SWITCH_WIDTH + INSET) * scale * app.Unit, (boxSize.Y - size.Y) / 2)
    local position = Vector2.new(math.round(rawPosition.X), math.round(rawPosition.Y))
    local held = springTo(app, spec, "held", if Hits.isPressed(spec.id) and app.HoverKey == spec.id then 1 else 0, 0.2, 0.62)
    local grip = clamp01(held)
    local track = Color.lerp(Color.lerp(pal.Off, pal.Sub, 0.14 * grip * (1 - shown)), Color.lighten(pal.Accent, 0.25 * clamp01(hover)), shown)
    local round = math.clamp(tonumber(app.State.ToggleRoundness) or 0.55, 0, 1)
    aura(app, spec, "switch", position, size, size.Y * 0.5 * round, (0.55 * shown + 0.25 * clamp01(hover)) * (1 - disabled), 0, fx, 10)
    Painter.rect(position, size, disabledMix(app, track, disabled), app.Alpha.Btn * fx.Alpha, Z_CONTROL, size.Y * 0.5 * round, true)

    local bounce = easeTo(app, spec, "bounce", 0, 13 * Motion.intensity(app.State))
    local travel = math.abs(Motion.velocity(spec.Spr, "on"))
    local base = math.round(KNOB * scale * app.Unit)
    if (size.Y - base) % 2 ~= 0 then
        base -= 1
    end
    local knobHeight = base * (1 + bounce * 0.22)
    local knobWidth = knobHeight * (1 + math.min(travel * 0.07, 0.35) + 0.2 * held + 0.06 * grip)
    local pad = (size.Y - base) / 2
    local room = size.X - knobHeight - pad * 2
    local knobX = position.X + pad + room * value - (knobWidth - knobHeight) * value
    local knobColor = Color.lerp(Color.lerp(pal.Sub, pal.Main, shown), pal.Disabled, disabled)
    Painter.rect(Vector2.new(knobX, position.Y + (size.Y - knobHeight) / 2), Vector2.new(knobWidth, knobHeight), knobColor, app.Alpha.Text * fx.Alpha, Z_CONTROL_TEXT, knobHeight * 0.5 * round, true)

end

local function drawBind(app: App, spec: Spec, boxPos: Vector2, boxSize: Vector2, scale: number, fx: Fx, disabled: number, inset: number)
    local pal = app.Pal
    local key = spec.id .. ":bind"
    local size = app:size(BIND_WIDTH, BIND_HEIGHT) * scale
    local position = boxPos + Vector2.new(boxSize.X - inset * scale * app.Unit, (boxSize.Y - size.Y) / 2)
    local hovered = app.HoverKey == key
    local hover = easeTo(app, spec, "bindHover", if hovered then 1 else 0, 16)
    local press = pressScale(app, spec, "bindPress", key)
    local pressedPos, pressedSize = shrinkBox(position, size, press)
    local capture = app.Focus == app.CAPTURE_PREFIX .. spec.flag
    local fill = Color.lerp(Color.lerp(pal.Main, pal.Accent, (0.18 - 0.12 * pal.Pick) * clamp01(hover)), Color.lerp(pal.Main, pal.Disabled, 0.4), disabled)
    Painter.rect(pressedPos, pressedSize, fill, app.Alpha.Btn * fx.Alpha, Z_CONTROL, 10)
    local label = if capture then "press..." else app:shortKey(app.State.OptionKeybinds[spec.flag])
    local textColor = if capture then pal.Accent else Color.lerp(pal.Sub, pal.Accent, 0.35 * clamp01(hover))
    Painter.text(label, pressedPos + pressedSize / 2, 11 * app.TextScale, textColor, app.Alpha.Text * fx.Alpha, Z_CONTROL_TEXT, true, true)
    region(app, key, position, size, function()
        app:beginBindCapture(spec.flag)
    end, nil)
end

local function drawSideButton(app: App, spec: Spec, boxPos: Vector2, width: number, height: number, fx: Fx, disabled: number)
    local pal = app.Pal
    local side = spec.side
    local sideKey = spec.id .. ":side"
    local position = boxPos + Vector2.new((width - (side.width or height)) * app.Unit, 0)
    local size = app:size(side.width or height, height)
    local hovered = app.HoverKey == sideKey
    local hover = easeTo(app, spec, "sideHover", if hovered then 1 else 0, 16)
    local p, s = position, size
    local fade = app:sourceFade(sideKey)
    Painter.rect(p, s, Color.lerp(pal.Panel, pal.Accent, (0.15 - 0.10 * pal.Pick) * clamp01(hover)), app.Alpha.Btn * fx.Alpha * fade, Z_CONTROL, 10)
    local sideColor = Color.lerp(pal.Text, pal.Disabled, disabled)
    local labelAlpha = app.Alpha.Text * fx.Alpha * fade
    if side.label == "?" then
        local unit = app.Unit
        local center = p + s / 2
        local stemWidth = math.max(2, math.floor(2 * unit + 0.5))
        local diameter = math.floor(17 * unit + 0.5)
        if (diameter - stemWidth) % 2 ~= 0 then
            diameter += 1
        end
        local left = math.floor(center.X - diameter / 2 + 0.5)
        local top = math.floor(center.Y - diameter / 2 + 0.5)
        local gap = math.max(1, math.floor(1.5 * unit + 0.5))
        local stemHeight = math.max(3, math.floor(5.5 * unit + 0.5))
        local glyphTop = top + math.floor((diameter - (stemWidth + gap + stemHeight)) / 2)
        local glyphLeft = left + (diameter - stemWidth) / 2
        Painter.rect(Vector2.new(left, top), Vector2.new(diameter, diameter), sideColor, labelAlpha * 0.22, Z_CONTROL, 1000, true)
        Painter.rect(Vector2.new(glyphLeft, glyphTop), Vector2.new(stemWidth, stemWidth), sideColor, labelAlpha, Z_CONTROL_TEXT, stemWidth * 0.5, true)
        Painter.rect(Vector2.new(glyphLeft, glyphTop + stemWidth + gap), Vector2.new(stemWidth, stemHeight), sideColor, labelAlpha, Z_CONTROL_TEXT, stemWidth * 0.5, true)
    else
        Painter.text(side.label, p + s / 2, (if side.small then 11 else 14) * app.TextScale, sideColor, labelAlpha, Z_CONTROL_TEXT, true, true)
    end
    region(app, sideKey, position, size, function()
        app:rememberClick(position, size, sideKey)
        side.onClick(app)
    end, nil)
end

local function mainWidth(spec: Spec, width: number, height: number): number
    if spec.side then
        return width - ((spec.side.width or height) + Widgets.GAP)
    end
    return width
end

local function rowEdge(app: App, position: Vector2, size: Vector2, alpha: number)
    local pal = app.Pal
    Painter.rect(position + app:size(14, 0) + Vector2.new(0, size.Y + 1.5 * app.Scale), Vector2.new(size.X - app:size(28, 0).X, math.max(1, app.Scale * 0.8)), pal.Off, alpha * pal.Pick * 0, Z_BG, 0)
end

function Widgets.toggle(app: App, spec: Spec, x: number, y: number, width: number, fx: Fx)
    local pal = app.Pal
    local height = Widgets.HEIGHTS.toggle
    local disabledGoal = if isDisabled(app, spec) then 1 else 0
    local disabled = easeTo(app, spec, "disabled", disabledGoal, 12)
    local mainW = mainWidth(spec, width, height)
    local key = spec.id
    local position = app:pos(x, y)
    local size = app:size(mainW, height)
    local hovered = app.HoverKey == key and disabledGoal == 0
    local hover = easeTo(app, spec, "hover", if hovered then 1 else 0, 16)
    local press = pressScale(app, spec, "press", key, disabledGoal == 0) * fx.Scale
    local p, s = shrinkBox(position, size, press)

    local fade = app:sourceFade(key)
    aura(app, spec, "row", p, s, 10, 0.16 * clamp01(hover) * (1 - disabled), 0, fx, 14)
    local bg = Color.lerp(Color.lerp(pal.Panel, pal.Accent, (0.15 - 0.10 * pal.Pick) * clamp01(hover)), Color.lerp(pal.Main, pal.Panel, pal.Pick), disabled)
    Painter.rect(p, s, bg, app.Alpha.Btn * fx.Alpha * fade * rowShow(app, hover), Z_BG, 16 - 6 * app.Pal.Pick)
    rowEdge(app, p, s, app.Alpha.Btn * fx.Alpha * fade)
    local title, titleSize = fitted(spec.text, 14 * app.TextScale, s.X - (12 + (if spec.bindable then 126 else 58)) * app.Unit)
    Painter.text(title, p + Vector2.new(12 * app.Unit * press, s.Y / 2), titleSize, Color.lerp(pal.Text, pal.Disabled, disabled), app.Alpha.Text * fx.Alpha * fade, Z_TEXT, false, true)
    drawSwitch(app, spec, p, s, press, fx, disabled, hover)
    if disabledGoal == 0 then
        region(app, key, position, size, function()
            app:rememberClick(position, size, key)
            kick(spec, "switchPulse")
            kick(spec, "rowPulse")
            app:toggle(spec)
        end, nil)
    end
    if spec.bindable then
        drawBind(app, spec, p, s, press, fx, disabled, TOGGLE_BIND_INSET)
    end
    if spec.side then
        drawSideButton(app, spec, app:pos(x, y), width, height, fx, disabled)
    end
end

local function sliderValue(spec: Spec, trackPos: Vector2, trackSize: Vector2, mouse: Vector2): number
    local fraction = math.clamp((mouse.X - trackPos.X) / math.max(0.001, trackSize.X), 0, 1)
    local value = spec.min + (spec.max - spec.min) * fraction
    local step: number? = spec.step
    if step and step > 0 then
        local snapped = spec.min + math.floor((value - spec.min) / step + 0.5) * step
        return math.clamp(math.floor(snapped * 1000 + 0.5) / 1000, spec.min, spec.max)
    end
    if spec.float then
        return math.floor(value * 100) / 100
    end
    return math.floor(value)
end

local function sliderText(spec: Spec, value: number): string
    if spec.format then
        return spec.format(value)
    end
    local step: number? = spec.step
    if step and step > 0 then
        local decimals = if step >= 1 then 0 elseif step >= 0.1 then 1 else 2
        return string.format("%." .. decimals .. "f", value)
    end
    if spec.float then
        return string.format("%.2f", value)
    end
    return tostring(value)
end

local function valueWidth(spec: Spec, value: number): number
    local widest = 0
    for _, sample in { spec.min, spec.max, value } do
        widest = math.max(widest, Painter.textWidth(sliderText(spec, sample), 14))
    end
    if spec.ValueWidthKey ~= widest then
        spec.ValueWidthKey = widest
        spec.ValueWidth = math.clamp(math.ceil(widest) + 20, VALUE_WIDTH, 120)
    end
    return spec.ValueWidth
end

function Widgets.slider(app: App, spec: Spec, x: number, y: number, width: number, fx: Fx)
    local pal = app.Pal
    local height = Widgets.HEIGHTS.slider
    local disabledGoal = if isDisabled(app, spec) then 1 else 0
    local disabled = easeTo(app, spec, "disabled", disabledGoal, 12)
    local key = spec.id
    local position = app:pos(x, y)
    local size = app:size(width, height)
    local hovered = app.HoverKey == key and disabledGoal == 0
    local hover = easeTo(app, spec, "hover", if hovered then 1 else 0, 16)
    local held = Hits.isDragging(key)
    local scale = fx.Scale
    local p, s = shrinkBox(position, size, scale)
    local unit = app.Unit

    Painter.rect(p, s, Color.lerp(pal.Panel, Color.lerp(pal.Main, pal.Panel, pal.Pick), disabled), app.Alpha.Btn * fx.Alpha * rowShow(app, hover), Z_BG, 16 - 6 * app.Pal.Pick)
    rowEdge(app, p, s, app.Alpha.Btn * fx.Alpha)
    local label = spec.text
    if spec.label then
        label = spec.label(app)
    end
    local value: number = spec.get()
    local VALUE_WIDTH = valueWidth(spec, value)
    local textColor = Color.lerp(pal.Text, pal.Disabled, disabled)
    local shownLabel, labelSize = fitted(label, 14 * app.TextScale * scale, s.X - (INSET * 2 + VALUE_WIDTH + VALUE_GAP) * unit)
    Painter.text(shownLabel, p + Vector2.new(INSET * unit * scale, 7 * unit * scale), labelSize, textColor, app.Alpha.Text * fx.Alpha, Z_TEXT)

    local fraction = springTo(app, spec, "fill", math.clamp((value - spec.min) / math.max(0.0001, spec.max - spec.min), 0, 1), if held then 0.12 else 0.30, if held then 1 else 0.78)
    local trackWidth = width - INSET * 2 - VALUE_WIDTH - VALUE_GAP
    local trackPos = p + Vector2.new(INSET * unit * scale, 36 * unit * scale)
    local trackSize = Vector2.new(trackWidth * unit * scale, 5 * unit * scale)
    Painter.rect(trackPos, trackSize, pal.Main, app.Alpha.Text * fx.Alpha, Z_CONTROL, 8)
    local fillColor = Color.lerp(Color.lighten(pal.Accent, 0.25 * clamp01(hover)), pal.Disabled, disabled)
    Painter.rect(trackPos, Vector2.new(math.max(1, trackSize.X * clamp01(fraction)), trackSize.Y), fillColor, app.Alpha.Text * fx.Alpha, Z_CONTROL_TEXT, 8)

    local near = springTo(app, spec, "near", if hovered or held then 1 else 0, 0.28, 0.7)
    local grab = springTo(app, spec, "grab", if held then 1 else 0, 0.22, 0.6)
    local tip = trackPos + Vector2.new(trackSize.X * clamp01(fraction), trackSize.Y / 2)
    local thumb = math.floor((7 + 3 * near + 3 * grab) * unit * scale / 2) * 2 + 1
    if held and not spec.WasHeld then
        kick(spec, "thumbPulse")
    end
    spec.WasHeld = held
    aura(app, spec, "thumb", tip - Vector2.new(thumb / 2, thumb / 2), Vector2.new(thumb, thumb), thumb / 2, (0.35 * near + 0.5 * grab) * (1 - disabled), 0, fx, 12)
    Painter.rect(tip - Vector2.new(thumb / 2, thumb / 2), Vector2.new(thumb, thumb), Color.lerp(Color.lighten(pal.Accent, 0.55), pal.Disabled, disabled), app.Alpha.Text * fx.Alpha, Z_CONTROL_TEXT, 16)

    local boxKey = key .. ":value"
    local boxPos = p + Vector2.new((width - INSET - VALUE_WIDTH) * unit * scale, (height - VALUE_HEIGHT) / 2 * unit * scale)
    local boxSize = app:size(VALUE_WIDTH, VALUE_HEIGHT)
    local boxHover = easeTo(app, spec, "valueHover", if app.HoverKey == boxKey and disabledGoal == 0 then 1 else 0, 16)
    local boxPress = pressScale(app, spec, "valuePress", boxKey, disabledGoal == 0)
    local bp, bs = shrinkBox(boxPos, boxSize * scale, boxPress)
    local boxFocus = springTo(app, spec, "boxFocus", if app.Focus == boxKey then 1 else 0, 0.3, 0.8)
    aura(app, spec, "box", bp, bs, 12, 0.5 * clamp01(boxFocus) + 0.12 * clamp01(boxHover), clamp01(boxFocus), fx, 10)
    Painter.rect(bp, bs, Color.lerp(Color.lerp(pal.Main, pal.Accent, (0.15 - 0.10 * pal.Pick) * clamp01(boxHover)), Color.lerp(pal.Main, pal.Panel, pal.Pick), disabled), app.Alpha.Btn * fx.Alpha, Z_CONTROL, 12)
    local shown = if app.Focus == boxKey then (app.Buffers[boxKey] or "") .. "|" else sliderText(spec, value)
    local boxText, boxTextSize = fitted(shown, 14 * app.TextScale, bs.X - 10 * unit)
    Painter.text(boxText, bp + bs / 2, boxTextSize, textColor, app.Alpha.Text * fx.Alpha, Z_CONTROL_TEXT, true, true)

    if disabledGoal == 0 then
        region(app, boxKey, boxPos, boxSize, function()
            app:rememberClick(boxPos, boxSize, boxKey)
            kick(spec, "boxPulse")
            app:beginInput(boxKey, sliderText(spec, value), {
                numeric = true,
                commit = function(text: string)
                    local typed = tonumber(text)
                    if typed then
                        app:setSlider(spec, typed)
                    end
                end,
            })
        end, nil)
        local fixedTrack = position + Vector2.new(INSET * unit * fx.Scale, 36 * unit * fx.Scale)
        local fixedSize = Vector2.new(trackWidth * unit * fx.Scale, 5 * unit * fx.Scale)
        local grabPos = fixedTrack - Vector2.new(10 * unit, 15 * unit)
        local grabSize = fixedSize + Vector2.new(20 * unit, 30 * unit)
        region(app, key, grabPos, grabSize, nil, function(mouse)
            app:setSlider(spec, sliderValue(spec, fixedTrack, fixedSize, mouse))
        end)
    end
end

function Widgets.button(app: App, spec: Spec, x: number, y: number, width: number, fx: Fx)
    local pal = app.Pal
    local height = Widgets.HEIGHTS.button
    local disabledGoal = if isDisabled(app, spec) then 1 else 0
    local disabled = easeTo(app, spec, "disabled", disabledGoal, 12)
    local mainW = mainWidth(spec, width, height)
    local key = spec.id
    local position = app:pos(x, y)
    local size = app:size(mainW, height)
    local hovered = app.HoverKey == key and disabledGoal == 0
    local hover = easeTo(app, spec, "hover", if hovered then 1 else 0, 16)
    local press = pressScale(app, spec, "press", key, disabledGoal == 0) * fx.Scale
    local p, s = shrinkBox(position, size, press)
    local fade = app:sourceFade(key)

    local lit = easeTo(app, spec, "active", if spec.active and spec.active(app) == true then 1 else 0, 12)
    local base = Color.lerp(Color.lerp(pal.Panel, pal.Accent, (0.25 - 0.19 * pal.Pick) * clamp01(hover)), Color.lerp(pal.Panel, pal.Accent, math.max(0.22, pal.Pick)), lit)
    local textColor = Color.lerp(Color.lerp(pal.Text, pal.AccentText, lit), pal.Disabled, disabled)
    local inputKey = spec.input
    local label = spec.text
    if inputKey then
        if app.Focus == inputKey then
            base = pal.Off
            label = (app.Buffers[inputKey] or "") .. "|"
        elseif spec.display then
            label = spec.display(app)
        end
    elseif spec.label then
        label = spec.label(app)
    end
    local typing = springTo(app, spec, "typing", if inputKey and app.Focus == inputKey then 1 else 0, 0.3, 0.8)
    aura(app, spec, "row", p, s, 10, (0.16 * clamp01(hover) + 0.14 * lit + 0.4 * clamp01(typing)) * (1 - disabled), clamp01(typing), fx, 14)
    Painter.rect(p, s, Color.lerp(base, Color.lerp(pal.Main, pal.Panel, pal.Pick), disabled), app.Alpha.Btn * fx.Alpha * fade * rowShow(app, hover), Z_BG, 16 - 6 * app.Pal.Pick)
    rowEdge(app, p, s, app.Alpha.Btn * fx.Alpha * fade)
    if spec.align == "center" and not spec.bindable then
        local shown, shownSize = fitted(label, 14 * app.TextScale, s.X - 20 * app.Unit)
        Painter.text(shown, p + s / 2, shownSize, textColor, app.Alpha.Text * fx.Alpha * fade, Z_TEXT, true, true)
    else
        local indent = if spec.fold then 22 else 0
        local shown, shownSize = fitted(label, 14 * app.TextScale, s.X - (12 + indent + (if spec.bindable then 74 else 14)) * app.Unit)
        Painter.text(shown, p + Vector2.new((12 + indent) * app.Unit * press, s.Y / 2), shownSize, textColor, app.Alpha.Text * fx.Alpha * fade, Z_TEXT, false, true)
        if spec.fold then
            local turn = easeTo(app, spec, "fold", if spec.fold(app) == true then 1 else 0, 14)
            local angle = math.rad(90 * turn)
            local center = p + Vector2.new(17 * app.Unit * press, s.Y / 2)
            local arm = 3.6 * app.Unit * press
            local tip = center + Vector2.new(math.cos(angle), math.sin(angle)) * arm * 0.6
            local weight = math.max(1.5, 1.7 * app.Unit)
            local color = Color.lerp(Color.lerp(pal.Sub, pal.Accent, clamp01(turn)), pal.Disabled, disabled)
            for _, side in { -1, 1 } do
                local wing = angle + math.rad(180 + 45 * side)
                Painter.line(tip, tip + Vector2.new(math.cos(wing), math.sin(wing)) * arm * 1.5, color, app.Alpha.Text * fx.Alpha * fade, Z_CONTROL_TEXT, weight)
            end
        end
    end
    if disabledGoal == 0 then
        region(app, key, position, size, function()
            app:rememberClick(position, size, key)
            kick(spec, "rowPulse")
            if inputKey then
                app:beginInput(inputKey, "", { numeric = spec.numeric, commit = spec.commit, maxLength = spec.maxLength })
            end
            if spec.onClick then
                spec.onClick(app, position, size)
            end
        end, nil)
    end
    if spec.bindable then
        drawBind(app, spec, p, s, press, fx, disabled, BUTTON_BIND_INSET)
    end
    if spec.side then
        drawSideButton(app, spec, app:pos(x, y), width, height, fx, disabled)
    end
end

function Widgets.dropdown(app: App, spec: Spec, x: number, y: number, width: number, fx: Fx)
    local pal = app.Pal
    local height = Widgets.HEIGHTS.dropdown
    local disabledGoal = if isDisabled(app, spec) then 1 else 0
    local disabled = easeTo(app, spec, "disabled", disabledGoal, 12)
    local key = spec.id
    local position = app:pos(x, y)
    local size = app:size(mainWidth(spec, width, height), height)
    local hovered = app.HoverKey == key and disabledGoal == 0
    local hover = easeTo(app, spec, "hover", if hovered then 1 else 0, 16)
    local press = pressScale(app, spec, "press", key, disabledGoal == 0) * fx.Scale
    local p, s = shrinkBox(position, size, press)
    local unit = app.Unit
    local textColor = Color.lerp(pal.Text, pal.Disabled, disabled)

    local opened = springTo(app, spec, "opened", if app.OpenDropdown == spec then 1 else 0, 0.3, 0.8)
    aura(app, spec, "row", p, s, 10, (0.16 * clamp01(hover) + 0.3 * clamp01(opened)) * (1 - disabled), clamp01(opened), fx, 14)
    Painter.rect(p, s, Color.lerp(pal.Panel, pal.Accent, (0.15 - 0.10 * pal.Pick) * clamp01(hover)), app.Alpha.Btn * fx.Alpha * rowShow(app, hover), Z_BG, 16 - 6 * app.Pal.Pick)
    rowEdge(app, p, s, app.Alpha.Btn * fx.Alpha)
    local shown, shownSize = fitted(spec.text .. ": " .. tostring(spec.get()), 14 * app.TextScale, s.X - 44 * unit)
    Painter.text(shown, p + Vector2.new(12 * unit * press, s.Y / 2), shownSize, textColor, app.Alpha.Text * fx.Alpha, Z_TEXT, false, true)
    local arrowColor = Color.lerp(pal.Sub, pal.Disabled, disabled)
    local arrowAlpha = if app.Modal then 0 else app.Alpha.Text * fx.Alpha
    local arrowCenter = p + Vector2.new(s.X - 16 * unit * press, s.Y / 2)
    local arm = 4 * unit * press
    do
        local weight = math.max(1.5, 1.6 * unit)
        local flip = 1 - 2 * clamp01(opened)
        Painter.line(arrowCenter + Vector2.new(-arm, -arm * 0.5 * flip), arrowCenter + Vector2.new(0, arm * 0.5 * flip), arrowColor, arrowAlpha, Z_CONTROL_TEXT, weight)
        Painter.line(arrowCenter + Vector2.new(0, arm * 0.5 * flip), arrowCenter + Vector2.new(arm, -arm * 0.5 * flip), arrowColor, arrowAlpha, Z_CONTROL_TEXT, weight)
    end

    if app.OpenDropdown == spec then
        app.DropdownBox = { Position = position, Size = size }
    end
    if disabledGoal == 0 then
        region(app, key, position, size, function()
            app:rememberClick(position, size, key)
            kick(spec, "rowPulse")
            app:toggleDropdown(spec)
        end, nil)
    end
    if spec.side then
        drawSideButton(app, spec, app:pos(x, y), width, height, fx, disabled)
    end
end

function Widgets.text(app: App, spec: Spec, x: number, y: number, width: number, fx: Fx)
    local pal = app.Pal
    local size = spec.size or 13
    local color = if typeof(spec.color) == "Color3" then spec.color elseif spec.accent then pal.Accent else pal.Sub
    local label = spec.text
    if spec.label then
        label = spec.label(app)
    end
    local limit = (width - INSET * 2) * app.Unit
    local font: number? = if spec.bold then Fonts.find("Gotham Bold") else nil
    local scaled = size * app.TextScale * fx.Scale
    if font then
        scaled = scaled * Fonts.scale(font) / Fonts.scale(Painter.font())
    end
    local shown, shownSize = fitted(label, scaled, limit)
    if spec.boxed then
        local box = pal.Panel
        Painter.rect(app:pos(x, y), app:size(width, spec.height or 23), box, app.Alpha.Btn * fx.Alpha * rowShow(app, 0), Z_BG, 16 - 6 * app.Pal.Pick)
        rowEdge(app, app:pos(x, y), app:size(width, spec.height or 23), app.Alpha.Btn * fx.Alpha)
    end
    if spec.center then
        local center = app:pos(x + width / 2, y + (spec.height or 23) / 2)
        Painter.text(shown, center, shownSize, color, app.Alpha.Text * fx.Alpha, Z_TEXT, true, true, font)
    else
        Painter.text(shown, app:pos(x + INSET, y + (spec.height or 23) / 2), shownSize, color, app.Alpha.Text * fx.Alpha, Z_TEXT, false, true, font)
    end
end

local function fitText(text: string, size: number, limit: number): string
    if Painter.textWidth(text, size) <= limit then
        return text
    end
    local cut = #text
    while cut > 1 and Painter.textWidth(string.sub(text, 1, cut) .. "..", size) > limit do
        cut -= 1
    end
    return string.sub(text, 1, cut) .. ".."
end

function Widgets.bindrow(app: App, spec: Spec, x: number, y: number, width: number, fx: Fx)
    local entry = app:boundOptions()[spec.index]
    if not entry then
        return
    end
    local pal = app.Pal
    local unit = app.Unit
    local height = Widgets.HEIGHTS.bindrow
    local position = app:pos(x, y)
    local size = app:size(width, height)
    local chipKey = spec.id .. ":bind"
    local chipSize = app:size(BIND_WIDTH, BIND_HEIGHT)
    local chipPosition = position + Vector2.new(size.X - chipSize.X - INSET * unit, (size.Y - chipSize.Y) / 2)
    local hovered = app.HoverKey == chipKey
    local hover = easeTo(app, spec, "bindHover", if hovered then 1 else 0, 16)
    local press = pressScale(app, spec, "bindPress", chipKey)
    local pressedPosition, pressedSize = shrinkBox(chipPosition, chipSize, press)
    local capture = app.Focus == app.CAPTURE_PREFIX .. entry.Flag
    Painter.rect(position, size, Color.lerp(pal.Panel, pal.Accent, 0.06), app.Alpha.Btn * fx.Alpha * rowShow(app, 0), Z_BG, 16 - 6 * app.Pal.Pick)
    rowEdge(app, position, size, app.Alpha.Btn * fx.Alpha)
    local name = fitText(tostring(entry.Name), 13 * app.TextScale, size.X - chipSize.X - (INSET * 2 + 8) * unit)
    Painter.text(name, position + Vector2.new(INSET * unit, size.Y / 2), 13 * app.TextScale, pal.Text, app.Alpha.Text * fx.Alpha, Z_TEXT, false, true)
    Painter.rect(pressedPosition, pressedSize, Color.lerp(pal.Main, pal.Accent, (0.18 - 0.12 * pal.Pick) * clamp01(hover)), app.Alpha.Btn * fx.Alpha, Z_CONTROL, 10)
    local label = if capture then "press..." else app:shortKey(entry.Key)
    local textColor = if capture then pal.Accent else Color.lerp(pal.Sub, pal.Accent, 0.35 * clamp01(hover))
    Painter.text(label, pressedPosition + pressedSize / 2, 11 * app.TextScale, textColor, app.Alpha.Text * fx.Alpha, Z_CONTROL_TEXT, true, true)
    region(app, chipKey, chipPosition, chipSize, function()
        app:beginBindCapture(entry.Flag)
    end, nil)
end

function Widgets.custom(app: App, spec: Spec, x: number, y: number, width: number, fx: Fx)
    local height = Widgets.heightOf(spec)
    local kit = Kit.new(app, width, height, app:pos(x, y), app:size(width, height), app.Alpha.Text * fx.Alpha)
    kit.ZControl, kit.ZText = Z_CONTROL, Z_CONTROL_TEXT
    if type(spec.render) == "function" then
        pcall(spec.render, kit, app)
    end
end

function Widgets.heightOf(spec: Spec): number
    if spec.kind == "text" then
        return spec.height or 23
    elseif spec.kind == "custom" then
        local height: any = spec.height
        return if type(height) == "table" then height.Value else height
    end
    return Widgets.HEIGHTS[spec.kind] or 36
end

function Widgets.draw(app: App, spec: Spec, x: number, y: number, width: number, fx: Fx)
    local kind = spec.kind
    local outer = Painter.active()
    Painter.scope(spec.id)
    if kind == "toggle" then
        Widgets.toggle(app, spec, x, y, width, fx)
    elseif kind == "slider" then
        Widgets.slider(app, spec, x, y, width, fx)
    elseif kind == "button" then
        Widgets.button(app, spec, x, y, width, fx)
    elseif kind == "dropdown" then
        Widgets.dropdown(app, spec, x, y, width, fx)
    elseif kind == "text" then
        Widgets.text(app, spec, x, y, width, fx)
    elseif kind == "bindrow" then
        Widgets.bindrow(app, spec, x, y, width, fx)
    elseif kind == "custom" then
        Widgets.custom(app, spec, x, y, width, fx)
    end
    Painter.scope(outer)
end

return Widgets
end
modules["ui/window"] = function(...)

local import: (string) -> any = ...
local Builtin: typeof(require("./popups/builtin")) = import("ui/popups/builtin")
local Chrome: typeof(require("./chrome")) = import("ui/chrome")
local Color: typeof(require("../core/color")) = import("core/color")
local Config: typeof(require("../state/config")) = import("state/config")
local Discord: typeof(require("./discord")) = import("ui/discord")
local Effects: typeof(require("./effects")) = import("ui/effects")
local Fonts: typeof(require("./fonts")) = import("ui/fonts")
local Keys: typeof(require("../input/keys")) = import("input/keys")
local Painter: typeof(require("./painter")) = import("ui/painter")
local Picker: typeof(require("./picker")) = import("ui/picker")
local Settings: typeof(require("../state/settings")) = import("state/settings")
local Spec: typeof(require("./spec")) = import("ui/spec")
local Storage: typeof(require("../core/storage")) = import("core/storage")
local Theme: typeof(require("../core/theme")) = import("core/theme")
local Typing: typeof(require("./typing")) = import("ui/typing")
local Util: typeof(require("../core/util")) = import("core/util")

local Window = {}
Window.__index = Window

type Map = { [string]: any }

Window.CAPTURE_PREFIX = "capture:"

local KEY_ALIASES: { [string]: string } = {
    RightShift = "rshift", LeftShift = "lshift", RightControl = "rctrl", LeftControl = "lctrl",
    RightCtrl = "rctrl", LeftCtrl = "lctrl", RightAlt = "ralt", LeftAlt = "lalt",
    Backspace = "bksp", CapsLock = "caps", PageUp = "pgup", PageDown = "pgdn",
    MouseButton1 = "m1", MouseButton2 = "m2", MouseButton3 = "m3", LeftMouse = "m1", RightMouse = "m2",
    KeypadPlus = "num+", KeypadMinus = "num-", KeypadMultiply = "num*", KeypadDivide = "num/",
}

export type Options = {
    Id: string,
    Title: string,
    Subtitle: string,
    Version: string,
    Folder: string,
    ConfigFolder: string?,
    Footer: string,
    Keybind: string?,
    Status: (() -> string?)?,
    IsTyping: (() -> boolean)?,
    OnReload: (() -> ())?,
    OnUnload: (() -> ())?,
    Welcome: Map?,
    UpdateNotice: { string }?,
    ShareId: string?,
    Width: number?,
    Height: number?,
    SidebarWidth: number?,
    NoSidebar: boolean?,
    MainColor: Color3?,
    AccentColor: Color3?,
    Font: number?,
    Scale: number?,
    Theme: any,
    ForceTheme: string?,
    Logo: Map?,
    Announce: boolean,
    Watermark: boolean,
    Thanks: boolean,
    Discord: string?,
    FirstRunInvite: boolean,
    FarmMode: (() -> any)?,
}

local CHANGE_KINDS = { "Added", "Changed", "Removed", "Fixed" }

local function noticeFrom(options: Map): any
    local data: any = options.Changelog
    if options.UpdateNotice ~= nil or type(data) ~= "table" then
        return options.UpdateNotice
    end
    local lines, sections = {}, {}
    for _, group in data.GROUPS do
        local items = {}
        for _, kind in CHANGE_KINDS do
            for _, text in group[kind] or {} do
                table.insert(lines, string.format("%s | %s: %s", group.Mode, kind, text))
                table.insert(items, kind .. ": " .. text)
            end
        end
        table.insert(sections, { Name = group.Mode, Items = items })
    end
    return { Title = "Updated to V" .. data.VERSION, Open = data.OPEN, Items = lines, Groups = sections, Footer = data.CLOSING }
end

local function normalizeOptions(options: Map): Options
    local title = tostring(options.Title or "Menu")
    return {
        Id = tostring(options.Id or title),
        Title = title,
        Subtitle = tostring(options.Subtitle or ""),
        Version = tostring(options.Version or "1.0.0"),
        Folder = tostring(options.Folder or (string.lower((string.gsub(title, "%s+", ""))) .. "confs")),
        ConfigFolder = if options.ConfigFolder ~= nil then tostring(options.ConfigFolder) else nil,
        Footer = tostring(options.Footer or ""),
        Keybind = options.Keybind,
        Status = options.Status,
        IsTyping = options.IsTyping,
        OnReload = options.OnReload,
        OnUnload = options.OnUnload,
        Welcome = options.Welcome,
        UpdateNotice = noticeFrom(options),
        ShareId = tostring(options.ShareId or string.upper((string.gsub(title, "%s+", "")))),
        Width = options.Width,
        Height = options.Height,
        SidebarWidth = options.SidebarWidth,
        MainColor = options.MainColor,
        AccentColor = options.AccentColor,
        Font = options.Font,
        Scale = options.Scale,
        Theme = options.Theme,
        Announce = options.Announce ~= false,
        Watermark = options.Watermark ~= false,
        Thanks = options.Thanks == true,
        BoldTitles = options.BoldTitles == true,
        FarmMode = if type(options.FarmMode) == "function" then options.FarmMode else nil,
        Discord = if type(options.Discord) == "string" and options.Discord ~= "" then options.Discord else nil,
        FirstRunInvite = options.FirstRunInvite == true,
        Logo = if type(options.Logo) == "string" then { Url = options.Logo } else options.Logo,
        ForceTheme = if type(options.ForceTheme) == "string" then options.ForceTheme else nil,
    }
end

function Window.new(rawOptions: Map)
    local options = normalizeOptions(rawOptions)
    local state = Settings.create()
    if options.Keybind then
        state.Keybind = options.Keybind
    end
    if tonumber(options.Scale) then
        state.UIScale = math.max(0.10, options.Scale :: number)
    end
    if tonumber(options.Font) then
        state.UIFont = tostring(options.Font)
    end
    local self: Map = {
        Options = options,
        Folder = options.Folder,
        State = state,
        Flags = {},
        FlagDefs = {},
        Setters = {},
        BindSpecs = {},
        BindOrder = {},
        M = Chrome.metrics(rawOptions),
        Config = Config.new({ Folder = options.Folder, Directory = options.ConfigFolder, ShareId = options.ShareId :: string, PlaceId = game.PlaceId }),
        Tabs = {},
        TabByName = {},
        TabGroup = {},
        TabOrder = {},
        NavGroups = {},
        PopupDefs = {},
        FrameHooks = {},
        Buffers = {},
        Focus = nil,
        InputOptions = nil,
        CaptureHandler = nil,
        NavAnim = {},
        Springs = {},
        PopAnim = {},
        Popup = { Name = "None", Arg = nil, Open = false, Alpha = 0, SourcePos = Vector2.new(0, 0), SourceSize = Vector2.new(0, 0), SourceKey = nil, Return = nil, From = nil, Swap = 1, Shown = nil, Leaving = false },
        LastClick = nil,
        OpenDropdown = nil,
        DropdownValues = {},
        Welcome = nil,
        Particles = {},
        Pal = nil,
        Alpha = { Frame = 0, UI = 0, Btn = 0, Text = 0 },
        Scale = 1,
        Unit = 1,
        TextScale = 1,
        Dt = 0.016,
        Now = 0,
        Mouse = Vector2.new(0, 0),
        LeftDown = false,
        HoverKey = nil,
        Modal = false,
        Moving = false,
        Viewport = Vector2.new(1920, 1080),
        WindowPos = Vector2.new(0, 0),
        WindowSize = Vector2.new(0, 0),
        MenuPos = Vector2.new(0, 0),
        TargetPos = Vector2.new(0, 0),
        Centered = false,
        Suspended = false,
        Destroyed = false,
    }
    local window: Map = setmetatable(self, Window) :: any
    window.Config:migrate()
    window.Picker = Picker.new(window)
    window.Typing = Typing.new(window)
    Window.prepareState(window)
    state.ToggleNotifications = options.Announce
    state.WatermarkEnabled = options.Watermark
    window:loadUiSettings()
    window:loadTheme()
    for name, definition in Builtin do
        window.PopupDefs[name] = definition
    end
    window.Particles = Effects.createParticles(state.SnowAmount)
    return window
end

type Self = Map

function Window.prepareState(self: Self)
    local state = self.State
    local runtime: Map = {
        Visible = true, CurrentTab = "", NextTab = nil, NextSection = nil, SectionSwap = false, TabFading = false, TabAlpha = 1, TabReveal = 1, NavReveal = 1,
        TabSlideDirection = 1, SectionByTab = {}, VisibilityAnim = 0, IntroAlpha = 0,
        DropAlpha = 0, TogglePulse = 0, LightAlpha = if state.LightMode then 1 else 0, PopFontPage = 1,
        OutlinePhases = {}, UIScaleAnim = 0.945, IsReloading = false,
        MenuSizeX = self.M.Width * state.UIScale, MenuSizeY = self.M.Height * state.UIScale,
        UpdateNoticePending = self.Options.UpdateNotice ~= nil, UpdateNoticeOpened = false,
        ThanksPending = self.Options.Thanks and not Storage.isFile(self.Folder .. "/thanks_seen.txt"), ThanksOpened = false,
    }
    for key, value in runtime do
        if state[key] == nil then
            state[key] = value
        end
    end
    for key in Settings.COLOR_KEYS do
        state["Target_" .. key] = state[key]
    end
    local invite = self.Options.Discord
    local opened = self.Folder .. "/discord_opened.txt"
    if invite and self.Options.FirstRunInvite and not Storage.isFile(opened) then
        Storage.ensureFolder(self.Folder)
        if Storage.write(opened, "true") then
            Discord.join(invite)
        end
    end
    local marker = self:updateMarker()
    if state.UpdateNoticePending and Storage.isFile(marker) then
        local seen = Storage.read(marker)
        if seen and Util.trim(seen) == self.Options.Version then
            state.UpdateNoticePending = false
        end
    end
end

function Window.uiPath(self: Self): string
    return self.Folder .. "/ui_settings.json"
end

function Window.loadUiSettings(self: Self)
    local state = self.State
    local data: any = Storage.readJson(self:uiPath())
    if type(data) == "table" then
        for _, key in Settings.UI_KEYS do
            local value = data[key]
            if value ~= nil and type(value) == type(state[key]) then
                state[key] = value
            end
        end
    end
    local saved: Map = {}
    for _, key in Settings.UI_KEYS do
        saved[key] = state[key]
    end
    self.UiSaved = saved
    local menuKey = tostring(state.Keybind)
    if state.StartHidden and menuKey ~= "" and menuKey ~= "None" then
        state.Visible = false
    end
end

function Window.flushUi(self: Self)
    local state = self.State
    if state.RememberTab and state.CurrentTab ~= "" and self.TabByName[state.CurrentTab] then
        state.LastTab = state.CurrentTab
    end
    local saved: Map = self.UiSaved
    local changed = false
    for _, key in Settings.UI_KEYS do
        if saved[key] ~= state[key] then
            changed = true
            break
        end
    end
    if not changed then
        return
    end
    local data: Map = {}
    for _, key in Settings.UI_KEYS do
        data[key] = state[key]
        saved[key] = state[key]
    end
    Storage.ensureFolder(self.Folder)
    Storage.writeJson(self:uiPath(), data)
end

function Window.resetWindow(self: Self)
    local state = self.State
    self.ScaleGoal = if tonumber(self.Options.Scale) then math.max(0.10, self.Options.Scale :: number) else Settings.defaultScale()
    self.Recentering = true
end

function Window.updateMarker(self: Self): string
    return self.Folder .. "/update_version.txt"
end

function Window.register(self: Self, flag: string, default: any, save: boolean)
    if self.FlagDefs[flag] then
        error("flag is used twice: " .. flag)
    end
    self.FlagDefs[flag] = { default = default, save = save }
    self.Flags[flag] = default
end

function Window.get(self: Self, flag: string): any
    return self.Flags[flag]
end

function Window.set(self: Self, flag: string, value: any)
    local setter = self.Setters[flag]
    if setter then
        setter(value)
    else
        self.Flags[flag] = value
    end
end

function Window.addTab(self: Self, name: string, label: string, group: string): Map
    if self.TabByName[name] then
        error("tab is used twice: " .. name)
    end
    local tab = Spec.tab(name, label, group)
    self.Tabs[#self.Tabs + 1] = tab
    self.TabByName[name] = tab
    return tab
end

function Window.defineBindable(self: Self, spec: Map, key: string?)
    self.BindSpecs[spec.flag] = spec
    table.insert(self.BindOrder, spec)
    local binds = self.State.OptionKeybinds
    if binds[spec.flag] == nil then
        binds[spec.flag] = key or "None"
    end
end

function Window.addPopup(self: Self, name: string, definition: Map)
    self.PopupDefs[name] = definition
end

function Window.setWidth(self: Self, width: number, instant: boolean?)
    local goal = math.clamp(width, 360, 1400)
    self.WidthGoal = goal
    if instant then
        self.M.Width = goal
    end
end

function Window.setSidebar(self: Self, definition: Map)
    self.SidebarPanel = definition
end

function Window.onFrame(self: Self, callback: (Map) -> ())
    table.insert(self.FrameHooks, callback)
end

function Window.finalize(self: Self)
    local early: { Map } = {}
    local late: { Map } = {}
    for _, tab in self.Tabs do
        table.insert(if tab.late then late else early, tab)
    end
    for _, tab in late do
        table.insert(early, tab)
    end
    self.Tabs = early
    local order = 0
    for _, tab in self.Tabs do
        if #tab.sections == 0 then
            table.insert(tab.sections, { title = string.upper(tab.label), rows = {} })
        end
        Spec.assignIds(tab)
        local groupName: string = tab.group
        local group = nil
        for _, candidate in self.NavGroups do
            if candidate.Name == groupName then
                group = candidate
            end
        end
        if not group then
            group = { Name = groupName, Tabs = {} }
            self.NavGroups[#self.NavGroups + 1] = group
        end
        table.insert(group.Tabs, tab.name)
        order += 1
        self.TabGroup[tab.name] = groupName
        self.TabOrder[tab.name] = order
    end
    local state = self.State
    if state.RememberTab and state.LastTab ~= "" and self.TabByName[state.LastTab] then
        state.CurrentTab = state.LastTab
    end
    if self.State.CurrentTab == "" or not self.TabByName[self.State.CurrentTab] then
        self.State.CurrentTab = self.Tabs[1].name
    end
end

function Window.pos(self: Self, x: number, y: number): Vector2
    return self.WindowPos + Vector2.new(x, y) * self.Unit
end

function Window.size(self: Self, w: number, h: number): Vector2
    return Vector2.new(w, h) * self.Unit
end

function Window.currentTab(self: Self): Map
    return self.TabByName[self.State.CurrentTab] or self.Tabs[1]
end

function Window.switchTab(self: Self, name: string)
    local state = self.State
    local target = state.NextTab or state.CurrentTab
    if target == name then
        return
    end
    local from = self.TabOrder[target] or self.TabOrder[state.CurrentTab] or 1
    local to = self.TabOrder[name] or from
    state.TabSlideDirection = if to >= from then 1 else -1
    if state.NextTab and name == state.CurrentTab then
        state.NextTab = nil
        self.Focus = nil
        self.OpenDropdown = nil
        return
    end
    state.NextTab = name
    self.Focus = nil
    self.OpenDropdown = nil
end

local NOTICE_SECONDS = 2.2

function Window.announce(self: Self, text: string)
    self.Notice = { Text = text, Expires = os.clock() + NOTICE_SECONDS }
end

function Window.toggle(self: Self, spec: Map)
    local value = not spec.get()
    spec.set(value)
    if spec.Anim then
        spec.Anim.bounce = 1
    end
    self.State.TogglePulse = 1
end

function Window.triggerBind(self: Self, flag: string)
    local spec = self.BindSpecs[flag]
    if not spec then
        return
    end
    if spec.kind == "toggle" then
        self:toggle(spec)
    elseif spec.onClick then
        spec.onClick(self)
    end
end

function Window.setSlider(self: Self, spec: Map, value: number)
    local number = value
    if not spec.unclamped then
        number = math.clamp(number, spec.min, spec.max)
    end
    spec.set(number)
end

function Window.isCapturing(self: Self): boolean
    return self.Focus ~= nil and self.CaptureHandler ~= nil
end

function Window.beginInput(self: Self, key: string, text: string, options: Map?)
    self.Focus = key
    self.Buffers[key] = text
    self.InputOptions = options or {}
    self.CaptureHandler = nil
end

function Window.beginCapture(self: Self, key: string, handler: (string) -> ())
    self.Focus = key
    self.InputOptions = nil
    self.CaptureHandler = handler
end

function Window.beginBindCapture(self: Self, flag: string)
    local focus = Window.CAPTURE_PREFIX .. flag
    if self.Focus == focus then
        self.Focus = nil
        self.CaptureHandler = nil
        return
    end
    self:beginCapture(focus, function(key: string)
        self.State.OptionKeybinds[flag] = key
    end)
end

function Window.finishCapture(self: Self, key: string)
    local handler = self.CaptureHandler
    self.Focus = nil
    self.CaptureHandler = nil
    if handler and key ~= "Unknown" then
        handler(key)
    end
end

function Window.shortKey(self: Self, key: any): string
    local name = Keys.normalize(key)
    if name == "" or name == "None" then
        return "none"
    end
    return Util.truncate(KEY_ALIASES[name] or string.lower(name), 7, "")
end

function Window.countBinds(self: Self): number
    local count = 0
    for _, key in self.State.OptionKeybinds do
        local name = Keys.normalize(key)
        if name ~= "" and name ~= "None" then
            count += 1
        end
    end
    return count
end

function Window.boundOptions(self: Self): { Map }
    if self.BoundList and self.BoundAt == self.Now then
        return self.BoundList
    end
    local list: { Map } = {}
    local binds = self.State.OptionKeybinds
    for _, spec in self.BindOrder do
        local key = binds[spec.flag]
        local name = Keys.normalize(key)
        if name ~= "" and name ~= "None" then
            table.insert(list, { Name = spec.text, Key = key, Flag = spec.flag })
        end
    end
    self.BoundList, self.BoundAt = list, self.Now
    return list
end

function Window.clearBinds(self: Self)
    local binds = self.State.OptionKeybinds
    for key in binds do
        binds[key] = "None"
    end
end

function Window.toggleDropdown(self: Self, spec: Map)
    if self.OpenDropdown == spec then
        self.OpenDropdown = nil
        return
    end
    self.Focus = nil
    self.OpenDropdown = spec
    local values = spec.values
    self.DropdownValues = if type(values) == "function" then values() else values
end

function Window.selectDropdown(self: Self, spec: Map, value: any)
    spec.set(value)
    self.OpenDropdown = nil
end

function Window.rememberClick(self: Self, position: Vector2, size: Vector2, key: any)
    local unit = self.Unit
    self.LastClick = {
        Pos = (position - self.WindowPos) / unit,
        Size = size / unit,
        Key = key,
    }
end

function Window.sourceFade(self: Self, key: any): number
    local popup = self.Popup
    if popup.Name ~= "None" and popup.SourceKey == key then
        return 1 - math.clamp(popup.Alpha, 0, 1)
    end
    return 1
end

function Window.openPopup(self: Self, name: string, arg: any?)
    local popup = self.Popup
    local click = self.LastClick
    if popup.Open and popup.Name ~= "None" and popup.Alpha > 0.5 and popup.Shown then
        if not (popup.From and popup.Leaving) then
            popup.From = { Name = popup.Name, Arg = popup.Arg, Width = popup.Shown.X, Height = popup.Shown.Y }
            popup.Swap = 0
        end
        popup.Name, popup.Arg = name, arg
        self.LastClick = nil
        self.OpenDropdown = nil
        return
    end
    popup.From = nil
    if self.PopText then
        table.clear(self.PopText)
    end
    if click and popup.Name == "None" then
        popup.SourcePos, popup.SourceSize, popup.SourceKey = click.Pos, click.Size, click.Key
    else
        popup.SourcePos = Vector2.new(self.M.Width / 2, self.M.Height / 2)
        popup.SourceSize = Vector2.new(1, 1)
        popup.SourceKey = nil
    end
    self.LastClick = nil
    popup.Name, popup.Arg, popup.Open, popup.Alpha = name, arg, true, 0
    self.Springs.popup = { x = 0, v = 0 }
    self.OpenDropdown = nil
end

function Window.closePopup(self: Self)
    local popup = self.Popup
    local back = popup.Return
    popup.Return = nil
    if self.Focus and not self:isCapturing() then
        self.Typing:apply()
    end
    if back then
        self:openPopup(back.Name, back.Arg)
    else
        popup.Open = false
    end
end

function Window.togglePopup(self: Self, name: string, arg: any?)
    local popup = self.Popup
    if popup.Open and popup.Name == name and popup.Arg == arg then
        self:closePopup()
    else
        self:openPopup(name, arg)
    end
end

function Window.setPopupReturn(self: Self, name: string, arg: any?)
    self.Popup.Return = { Name = name, Arg = arg }
end

function Window.openColor(self: Self, target: Map)
    local popup = self.Popup
    if popup.Open and popup.Name == "color" and self.Picker.Target and self.Picker.Target.Key == target.Key then
        self:closePopup()
        return
    end
    self.Picker:open(target)
    self:openPopup("color")
end

function Window.finishColor(self: Self)
    if self.Focus then
        self.Typing:apply()
    end
    self.Picker:commit()
    self:closePopup()
end

function Window.regenerateParticles(self: Self)
    self.Particles = Effects.createParticles(self.State.SnowAmount)
end

local THEME_VERSION = 2

function Window.themePath(self: Self): string
    return self.Folder .. "/default_theme.json"
end

function Window.loadTheme(self: Self)
    local state = self.State
    local options = self.Options
    local given: any = options.Theme
    if type(given) == "string" then
        given = Theme.Presets[given]
    end
    local forced = options.ForceTheme or Theme.Season or "Default"
    local forcePreset: Map? = if forced then Theme.Presets[forced] else nil
    local saved: any = Storage.readJson(self:themePath())
    local applyForce = forcePreset ~= nil and (type(saved) ~= "table" or saved.Forced ~= forced)
    if applyForce then
        given = forcePreset
    end
    local preset: Map = Theme.Default
    if given and given.Main and given.Panel and given.Off and given.Text and given.Sub and given.Accent then
        preset = table.clone(given)
        preset.Name = tostring(given.Name or "Theme")
    end
    self.Preset = preset
    state.ThemePreset = preset
    self.DefaultMain = options.MainColor or preset.Main
    self.DefaultAccent = options.AccentColor or preset.Accent
    state.MainCol, state.AccentCol = self.DefaultMain, self.DefaultAccent
    state.Target_MainCol, state.Target_AccentCol = self.DefaultMain, self.DefaultAccent
    state.ThemeName = preset.Name
    state.CustomMainCol, state.CustomAccentCol = Theme.CustomMain, Theme.CustomAccent
    if not Theme.isPreset(preset, self.DefaultMain, self.DefaultAccent) then
        state.ThemeName = "Custom"
        state.CustomMainCol, state.CustomAccentCol = self.DefaultMain, self.DefaultAccent
    end
    if applyForce then
        self:saveTheme()
        return
    end
    local data = saved
    if type(data) ~= "table" or data.Version ~= THEME_VERSION or type(data.Main) ~= "string" or type(data.Accent) ~= "string" then
        return
    end
    local main, accent = Color.fromHex(data.Main), Color.fromHex(data.Accent)
    if not main or not accent then
        return
    end
    state.CustomMainCol, state.CustomAccentCol = main, accent
    local savedName: any = data.Theme
    local saved: Map? = if type(savedName) == "string" then Theme.Presets[savedName] else nil
    if saved and savedName ~= preset.Name then
        state.ThemePreset = saved
        state.ThemeName = saved.Name
        state.MainCol, state.AccentCol = saved.Main, saved.Accent
        state.Target_MainCol, state.Target_AccentCol = saved.Main, saved.Accent
    elseif data.Theme == "Custom" then
        state.ThemeName = "Custom"
        state.MainCol, state.AccentCol = main, accent
        state.Target_MainCol, state.Target_AccentCol = main, accent
    end
    if data.ShownMain ~= Color.toHex(state.Target_MainCol or state.MainCol) or data.ShownAccent ~= Color.toHex(state.Target_AccentCol or state.AccentCol) then
        self:saveTheme()
    end
end

function Window.saveTheme(self: Self)
    local state = self.State
    Storage.ensureFolder(self.Folder)
    Storage.writeJson(self:themePath(), {
        Version = THEME_VERSION,
        Forced = self.Options.ForceTheme or Theme.Season or "Default",
        Theme = state.ThemeName,
        Main = Color.toHex(state.CustomMainCol),
        Accent = Color.toHex(state.CustomAccentCol),
        ShownMain = Color.toHex(state.Target_MainCol or state.MainCol),
        ShownAccent = Color.toHex(state.Target_AccentCol or state.AccentCol),
    })
    self.ThemeDirty = nil
end

function Window.colorEdited(self: Self)
    local state = self.State
    state.ThemeName = "Custom"
    state.CustomMainCol = state.Target_MainCol or state.MainCol
    state.CustomAccentCol = state.Target_AccentCol or state.AccentCol
    self.ThemeDirty = os.clock()
end

function Window.flushTheme(self: Self, force: boolean?)
    local changed: number? = self.ThemeDirty
    if changed and (force or os.clock() - changed > 0.5) then
        self:saveTheme()
    end
end

function Window.themeFromColors(self: Self)
    local state = self.State
    local main: Color3 = state.Target_MainCol or state.MainCol
    local accent: Color3 = state.Target_AccentCol or state.AccentCol
    local current: Map = state.ThemePreset or self.Preset
    local near = Theme.presetFor(main, accent)
    if Theme.isPreset(current, main, accent) then
        state.ThemeName = current.Name
    elseif near and Theme.Presets[near] then
        local preset = Theme.Presets[near]
        state.ThemePreset = preset
        state.ThemeName = preset.Name
        state.Target_MainCol, state.Target_AccentCol = preset.Main, preset.Accent
    else
        state.ThemeName = "Custom"
        state.CustomMainCol, state.CustomAccentCol = main, accent
    end
    self:saveTheme()
end

function Window.applyTheme(self: Self, name: string)
    local state = self.State
    if name == "Custom" then
        state.Target_MainCol, state.Target_AccentCol = state.CustomMainCol, state.CustomAccentCol
    else
        local preset: Map? = if name == self.Preset.Name then self.Preset else Theme.Presets[name]
        if not preset then
            return
        end
        state.ThemePreset = preset
        state.Target_MainCol, state.Target_AccentCol = preset.Main, preset.Accent
    end
    state.ThemeName = name
    self:saveTheme()
end

function Window.resetAppearance(self: Self)
    local state = self.State
    local defaults = Settings.create()
    for _, key in Settings.APPEARANCE_KEYS do
        state[key] = defaults[key]
    end
    for _, key in Settings.APPEARANCE_COLOR_KEYS do
        state["Target_" .. key] = defaults[key]
    end
    state.Target_MainCol, state.Target_AccentCol = self.DefaultMain, self.DefaultAccent
    state.ThemePreset = self.Preset
    state.CustomMainCol, state.CustomAccentCol = Theme.CustomMain, Theme.CustomAccent
    if Theme.isPreset(self.Preset, self.DefaultMain, self.DefaultAccent) then
        state.ThemeName = self.Preset.Name
    else
        state.ThemeName = "Custom"
        state.CustomMainCol, state.CustomAccentCol = self.DefaultMain, self.DefaultAccent
    end
    state.UIFont = if tonumber(self.Options.Font) then tostring(self.Options.Font) else state.UIFont
    if tonumber(self.Options.Scale) then
        state.UIScale = math.max(0.10, self.Options.Scale :: number)
    end
    self:saveTheme()
    self:regenerateParticles()
end

function Window.saveConfig(self: Self, name: string?)
    if not name or name == "" then
        return
    end
    local state = self.State
    if self.Config:save(name, state, self.Flags, self.FlagDefs) then
        state.SelectedConfig = name
    end
end

function Window.finishLoad(self: Self, loaded: Map)
    local state = self.State
    for key, color in loaded.Colors do
        state["Target_" .. key] = color
    end
    if loaded.Colors.MainCol or loaded.Colors.AccentCol then
        self:themeFromColors()
    end
    state.UIScale = math.max(0.10, tonumber(state.UIScale) or Settings.defaultScale())
    state.MenuSizeX, state.MenuSizeY = self.M.Width * state.UIScale, self.M.Height * state.UIScale
    self:regenerateParticles()
end

function Window.loadConfig(self: Self, name: string, auto: boolean)
    local loaded = self.Config:load(name, self.State, self.Flags, self.FlagDefs)
    if not loaded then
        return
    end
    self:finishLoad(loaded)
    if not auto then
        self.State.SelectedConfig = name
    end
end

function Window.copyConfigCode(self: Self)
    local state = self.State
    state.CodeBuffer = self.Config:share(state, self.Flags, self.FlagDefs)
    state.CodeNote = "Press Copy to put your code on the clipboard"
    state.CodeMode = "copy"
    self:openPopup("configCode")
end

function Window.importConfigCode(self: Self)
    local state = self.State
    state.CodeBuffer = ""
    state.CodeNote = "Paste a code, then press Apply"
    state.CodeMode = "import"
    self:openPopup("configCode")
end

function Window.copyCodeBuffer(self: Self)
    local state = self.State
    local code = tostring(state.CodeBuffer or "")
    local copied = code ~= "" and type(setclipboard) == "function" and pcall(setclipboard, code)
    state.CodeNote = if copied then "Copied to the clipboard" else "Could not copy the code"
end

function Window.pasteCodeBuffer(self: Self)
    local state = self.State
    local ok, text = false, nil
    if type(getclipboard) == "function" then
        ok, text = pcall(getclipboard)
    end
    if ok and type(text) == "string" and text ~= "" then
        state.CodeBuffer = text
        state.CodeNote = "Pasted, press Apply"
    else
        state.CodeNote = "This executor cannot paste for you, click the box and press Ctrl+V"
    end
end

function Window.applyCodeBuffer(self: Self): boolean
    local state = self.State
    local text = tostring(state.CodeBuffer or "")
    local loaded = if text ~= "" then self.Config:loadCode(text, state, self.Flags, self.FlagDefs) else nil
    if loaded then
        self:finishLoad(loaded)
        state.ShareNote = "Config code imported"
        return true
    end
    state.CodeNote = "That is not a valid config code"
    return false
end

function Window.deleteConfig(self: Self, name: string)
    if self.Config:delete(name, self.State.DefaultConfigName) then
        self.State.DefaultConfigName = "None"
    end
    self.State.SelectedConfig = "None"
end

function Window.loadStartupConfig(self: Self)
    local config = self.Config
    local name = config:defaultName()
    if not name then
        return
    end
    if config:exists(name) then
        self:loadConfig(name, true)
        self.State.DefaultConfigName = name
        self.State.AutoLoadScope = config:defaultScope()
        self.State.SelectedConfig = "None"
    else
        config:clearMissingDefault()
        self.State.DefaultConfigName = "None"
    end
end

function Window.acknowledgeThanks(self: Self)
    self.State.ThanksPending = false
    Storage.ensureFolder(self.Folder)
    Storage.write(self.Folder .. "/thanks_seen.txt", "1")
end

function Window.acknowledgeUpdate(self: Self)
    self.State.UpdateNoticePending = false
    Storage.ensureFolder(self.Folder)
    Storage.write(self:updateMarker(), self.Options.Version)
end

local function startFarewell(self: Self, kind: string)
    local state = self.State
    if state.IsReloading then
        return
    end
    state.IsReloading = true
    self:flushTheme(true)
    if kind == "reload" and state.DefaultConfigName and state.DefaultConfigName ~= "None" then
        self:saveConfig(state.DefaultConfigName)
    end
    self.Popup.Open = false
    self.OpenDropdown = nil
    self.Focus = nil
    self.Farewell = { Kind = kind, Start = 0, Done = false }
    if not state.Visible or self.FarmOn == true then
        self:finishFarewell()
    end
end

function Window.reload(self: Self)
    startFarewell(self, "reload")
end

function Window.unload(self: Self)
    startFarewell(self, "unload")
end

function Window.finishFarewell(self: Self)
    local farewell = self.Farewell
    if not farewell or farewell.Done then
        return
    end
    farewell.Done = true
    self.State.Visible = false
    if farewell.Kind == "reload" then
        self.Options.OnReload()
    else
        self.Options.OnUnload()
    end
end

function Window.finishWelcome(self: Self, position: Vector2, scale: number)
    local state = self.State
    state.Visible = true
    state.VisibilityAnim = 1
    state.IntroAlpha = 1
    state.UIScaleAnim = 1
    self.Springs.open = { x = 1, v = 0 }
    state.NavReveal, state.TabReveal, state.TabAlpha = 0, 0, 1
    state.UIScale = scale
    state.MenuSizeX, state.MenuSizeY = self.M.Width * scale, self.M.Height * scale
    self.MenuPos, self.TargetPos = position, position
    self.Centered = true
    self.Welcome = nil
    self.RevealStart = self.Now
end

function Window.fontScale(_self: Self, font: number): number
    return Fonts.scale(font)
end

function Window.applyFont(self: Self)
    Painter.setFont(tonumber(self.State.UIFont) or Fonts.DEFAULT)
end

return Window
end
return import("lib")
