local CONFIG = ...
if type(CONFIG) ~= "table" then
    CONFIG = {
        Name = "Script Hub",
        Id = "script-hub",
        Folder = "oklo scripts/scripthub",
        ScriptUrl = "https://raw.githubusercontent.com/okdude42/main-scripts/main/hub/hub-core.lua",
        UiUrl = "https://raw.githubusercontent.com/okdude42/main-scripts/main/oklo-uilib/OkloUI.luau",
        Discord = "https://discord.gg/oklo",
        Registry = "__ScriptHubStop",
        Width = 700,
        Height = 460,
        Hub = true,
        RegistryUrl = "https://raw.githubusercontent.com/okdude42/main-scripts/main/hub/registry.json",
    }
end

local Intro = (function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local Loader = {}

local FOLDER = "oklo scripts"
local CACHE = FOLDER .. "/loaders"
local COLS, ROWS = 4, 4
local PER_SHEET = COLS * ROWS
local BIRD_SHEETS = 9
local SCENE_SHEETS, SCENE_FRAMES = 3, 48
local FPS = 30
local DRAW_FRAMES, REPLAY_FRAMES = 58, 78
local SLIDE_AT, SLIDE_FOR = 0.83, 0.77
local FROM_X, TO_X = 0.17, 0.81
local LOOP = 3.24
local HOLD_AFTER = 1
local SPIN_SPEED = 110

Loader.Base = "https://raw.githubusercontent.com/okdude42/main-scripts/main/loader/loader-assets"
Loader.Version = "10"

local function rgb(r, g, b)
    return Color3.fromRGB(r, g, b)
end

Loader.Themes = {
    standard = { Main = rgb(8, 8, 10), Accent = rgb(235, 235, 242) },
    halloween = { Main = rgb(7, 5, 10), Accent = rgb(240, 130, 45), Sprites = true, Scene = true, Gate = true, Steady = true },
    christmas = { Main = rgb(6, 10, 18), Accent = rgb(190, 235, 255), Snow = true },
    valentines = { Main = rgb(14, 6, 12), Accent = rgb(255, 160, 200) },
    easter = { Main = rgb(12, 6, 20), Accent = rgb(190, 140, 240), Scene = true, Gate = true, Steady = true, LoopFade = true },
    newyear = { Main = rgb(12, 9, 4), Accent = rgb(255, 190, 70), Scene = true, Steady = true, LoopFade = true },
    stpatricks = { Main = rgb(4, 14, 9), Accent = rgb(110, 230, 110), Scene = true, Gate = true, Steady = true, LoopFade = true },
}

local function try(fn, ...)
    local ok, value = pcall(fn, ...)
    if ok then
        return value
    end
    return nil
end

local function fetch(url)
    local body = try(function()
        return game:HttpGet(url)
    end)
    if type(body) == "string" and #body > 0 then
        return body
    end
    local send = request or http_request
    if send then
        local response = try(send, { Url = url, Method = "GET" })
        if type(response) == "table" and type(response.Body) == "string" and #response.Body > 0 then
            return response.Body
        end
    end
    return nil
end

local function ensureFolders(dir)
    if not (makefolder and isfolder) then
        return false
    end
    for _, path in ipairs({ FOLDER, CACHE, dir }) do
        if not isfolder(path) then
            pcall(makefolder, path)
        end
    end
    return isfolder(dir) == true
end

local function namesFor(info)
    local names = { "loader-text", "loader-halo" }
    for i = 1, BIRD_SHEETS do
        table.insert(names, "loader-bird-" .. i)
    end
    if info.Sprites then
        table.insert(names, "loader-sprites")
    end
    if info.Scene then
        for i = 1, SCENE_SHEETS do
            table.insert(names, "loader-scene-" .. i)
        end
    end
    return names
end

local function prepare(theme, version, names)
    local dir = CACHE .. "/" .. theme
    if not (writefile and readfile and isfile and getcustomasset and ensureFolders(dir)) then
        return nil
    end
    local stamp = dir .. "/version.txt"
    local stale = not (isfile(stamp) and try(readfile, stamp) == version)
    local queue = {}
    for _, name in ipairs(names) do
        local path = ("%s/%s.png"):format(dir, name)
        if stale or not isfile(path) then
            table.insert(queue, name)
        end
    end
    local pending, nextIndex = #queue, 1
    for _ = 1, math.min(3, #queue) do
        task.spawn(function()
            while true do
                local name = queue[nextIndex]
                if not name then
                    break
                end
                nextIndex += 1
                local url = ("%s/%s/%s.png"):format(Loader.Base, theme, name)
                for attempt = 1, 8 do
                    local body = fetch(url)
                    if body and body:sub(2, 4) == "PNG" then
                        pcall(writefile, ("%s/%s.png"):format(dir, name), body)
                        break
                    end
                    task.wait(1 + attempt)
                end
                pending -= 1
            end
        end)
    end
    local deadline = os.clock() + 120
    while pending > 0 and os.clock() < deadline do
        task.wait(0.05)
    end
    local assets = {}
    for _, name in ipairs(names) do
        local path = ("%s/%s.png"):format(dir, name)
        local saved = isfile(path) and try(readfile, path)
        if type(saved) ~= "string" or saved:sub(2, 4) ~= "PNG" then
            return nil
        end
        local asset = try(getcustomasset, path)
        if not asset then
            return nil
        end
        assets[name] = asset
    end
    pcall(writefile, stamp, version)
    return assets
end

local function hostGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "OkloLoader"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local parent = try(function()
        return gethui()
    end) or try(function()
        return game:GetService("CoreGui")
    end) or Players.LocalPlayer:WaitForChild("PlayerGui")
    gui.Parent = parent
    return gui
end

local function noop() end

local function lighten(color, amount)
    return Color3.new(color.R + (1 - color.R) * amount, color.G + (1 - color.G) * amount, color.B + (1 - color.B) * amount)
end

local function seg(x, from, to)
    return math.clamp((x - from) / (to - from), 0, 1)
end

local function smoother(t)
    t = math.clamp(t, 0, 1)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

local function ease(x)
    x = math.clamp(x, 0, 1)
    if x < 0.5 then
        return 4 * x * x * x
    end
    return 1 - (-2 * x + 2) ^ 3 / 2
end

local function round(x)
    return math.floor(x + 0.5)
end

local swaps = setmetatable({}, { __mode = "k" })
local SWAP_OUT, SWAP_RESIZE, SWAP_IN = 0.14, 0.26, 0.22

local function retext(area, label, value)
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")
    local swap = swaps[area]
    if not swap then
        swap = { Token = 0 }
        swaps[area] = swap
    end
    swap.Token += 1
    local token = swap.Token
    if swap.Tween then
        swap.Tween:Cancel()
        swap.Tween = nil
    end
    local height = area.AbsoluteSize.Y
    area.AutomaticSize = Enum.AutomaticSize.None
    area.ClipsDescendants = true
    area.Size = UDim2.new(1, 0, 0, height)
    task.spawn(function()
        if label.Visible and label.Text ~= "" and label.TextTransparency < 1 then
            TweenService:Create(label, TweenInfo.new(SWAP_OUT), { TextTransparency = 1 }):Play()
            task.wait(SWAP_OUT)
            if swap.Token ~= token then
                return
            end
        end
        label.TextTransparency = 1
        label.Text = value
        label.Visible = value ~= ""
        RunService.RenderStepped:Wait()
        RunService.Heartbeat:Wait()
        if swap.Token ~= token then
            return
        end
        local layout = area:FindFirstChildOfClass("UIListLayout")
        local target = if layout then layout.AbsoluteContentSize.Y else height
        local tween = TweenService:Create(area, TweenInfo.new(SWAP_RESIZE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, target) })
        swap.Tween = tween
        tween:Play()
        TweenService:Create(label, TweenInfo.new(SWAP_IN), { TextTransparency = 0 }):Play()
        tween.Completed:Wait()
        if swap.Token ~= token then
            return
        end
        swap.Tween = nil
        area.Size = UDim2.new(1, 0, 0, 0)
        area.AutomaticSize = Enum.AutomaticSize.Y
        area.ClipsDescendants = false
    end)
end
Loader.retext = retext

local EDGE, GAP, SECTION, BUTTON, LINE_GAP, ROW = 16, 8, 14, 28, 4, 24
local BUTTON_MIN = 62

local function fillNotice(card, opts, mainColor, accent, close, unit)
    local TweenService = game:GetService("TweenService")
    local TextService = game:GetService("TextService")
    local FONT = Enum.Font.GothamMedium
    local textUnit = math.max(unit, 0.95)
    local function px(value)
        return round(value * unit)
    end
    local function textSize(size)
        return math.max(8, round(size * textUnit))
    end
    local function measure(text, size)
        return TextService:GetTextSize(text, size, FONT, Vector2.new(1000, 100)).X
    end
    local padding = Instance.new("UIPadding")
    padding.PaddingTop, padding.PaddingBottom = UDim.new(0, px(EDGE)), UDim.new(0, px(EDGE))
    padding.PaddingLeft, padding.PaddingRight = UDim.new(0, px(EDGE)), UDim.new(0, px(EDGE))
    padding.Parent = card
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, px(SECTION))
    list.HorizontalAlignment = Enum.HorizontalAlignment.Left
    list.Parent = card
    local order = 0
    local function label(text, size, color, parent)
        order += 1
        local object = Instance.new("TextLabel")
        object.Size = UDim2.new(1, 0, 0, 0)
        object.AutomaticSize = Enum.AutomaticSize.Y
        object.BackgroundTransparency = 1
        object.RichText = true
        object.Text = text
        object.TextColor3 = color
        object.TextSize = textSize(size)
        object.Font = FONT
        object.TextWrapped = true
        object.TextXAlignment = Enum.TextXAlignment.Left
        object.LayoutOrder = order
        object.Parent = parent
        return object
    end
    local text, sub = Color3.fromRGB(235, 235, 240), Color3.fromRGB(150, 150, 160)
    local dark = Color3.new(0.04, 0.04, 0.05)
    local panel = lighten(mainColor, 0.07)
    local api = {}
    api.close = close
    local function button(spec, parent)
        local idle = if spec.Primary then accent else panel
        local idleText = if spec.Primary then dark else text
        local object = Instance.new("TextButton")
        object.BackgroundColor3 = idle
        object.BorderSizePixel = 0
        object.AutoButtonColor = false
        object.Text = spec.Text
        object.TextSize = textSize(13)
        object.Font = FONT
        object.TextColor3 = idleText
        object.Parent = parent
        local rounding = Instance.new("UICorner")
        rounding.CornerRadius = UDim.new(0, px(8))
        rounding.Parent = object
        object.MouseEnter:Connect(function()
            TweenService:Create(object, TweenInfo.new(0.15), { BackgroundColor3 = accent, TextColor3 = dark }):Play()
        end)
        object.MouseLeave:Connect(function()
            TweenService:Create(object, TweenInfo.new(0.15), { BackgroundColor3 = idle, TextColor3 = idleText }):Play()
        end)
        object.MouseButton1Click:Connect(function()
            local keep = false
            if spec.Click then
                local ok, result = pcall(spec.Click, api)
                keep = ok and result == false
            end
            if not keep then
                close()
            end
        end)
        return object
    end
    order += 1
    local head = Instance.new("Frame")
    head.Size = UDim2.new(1, 0, 0, px(ROW))
    head.BackgroundTransparency = 1
    head.LayoutOrder = order
    head.Parent = card
    local titleSize = textSize(15)
    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(0, -px(0.4))
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = opts.Title or ""
    title.TextColor3 = accent
    title.TextSize = titleSize
    title.Font = FONT
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Parent = head
    local buttons = {}
    local corner
    for _, spec in ipairs(opts.Buttons or {}) do
        if not corner and (spec.Top or (spec.Text == "Close" and not spec.Click)) then
            corner = spec
        else
            table.insert(buttons, spec)
        end
    end
    local need = measure(title.Text, titleSize)
    if corner then
        local width = math.max(px(BUTTON_MIN), measure(corner.Text, textSize(13)) + px(EDGE * 2))
        title.Size = UDim2.new(1, -(width + px(GAP)), 1, 0)
        need += px(GAP) + width
        local top = button(corner, head)
        top.AnchorPoint = Vector2.new(1, 0)
        top.Position = UDim2.fromScale(1, 0)
        top.Size = UDim2.new(0, width, 1, 0)
    end
    need += px(EDGE * 2)
    if card.Size.X.Offset < need then
        card.Size = UDim2.new(card.Size.X.Scale, need, card.Size.Y.Scale, card.Size.Y.Offset)
    end
    order += 1
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.LayoutOrder = order
    body.Parent = card
    local bodyList = Instance.new("UIListLayout")
    bodyList.SortOrder = Enum.SortOrder.LayoutOrder
    bodyList.Padding = UDim.new(0, px(LINE_GAP))
    bodyList.Parent = body
    for index, entry in ipairs(opts.Lines or {}) do
        label(entry, 13, if index == 1 then text else sub, body)
    end
    local status = label("", 12, sub, body)
    status.Visible = false
    function api.note(value)
        retext(body, status, value)
    end
    if #buttons == 0 then
        return api
    end
    order += 1
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, px(BUTTON))
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = card
    local across = Instance.new("UIListLayout")
    across.FillDirection = Enum.FillDirection.Horizontal
    across.SortOrder = Enum.SortOrder.LayoutOrder
    across.Padding = UDim.new(0, px(GAP))
    across.Parent = row
    local count = #buttons
    for index, spec in ipairs(buttons) do
        local object = button(spec, row)
        object.LayoutOrder = index
        object.Size = UDim2.new(1 / count, -px(GAP) * (count - 1) / count, 1, 0)
    end
    return api
end

local function plainNotice(opts, mainColor, accent)
    local TweenService = game:GetService("TweenService")
    local gui = hostGui()
    gui.Name = "OkloLoaderNotice"
    local card = Instance.new("CanvasGroup")
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.fromOffset(344, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = mainColor
    card.BorderSizePixel = 0
    card.GroupTransparency = 1
    card.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = card
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Thickness = 1.7
    stroke.Color = accent
    stroke.Parent = card
    local closed = false
    local function close()
        if closed then
            return
        end
        closed = true
        TweenService:Create(card, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
        task.delay(0.35, function()
            gui:Destroy()
            if opts.OnClose then
                pcall(opts.OnClose)
            end
        end)
    end
    fillNotice(card, opts, mainColor, accent, close, 0.86)
    TweenService:Create(card, TweenInfo.new(0.4), { GroupTransparency = 0 }):Play()
end

function Loader.play(opts)
    opts = opts or {}
    local run = opts.Run or noop
    local done = opts.Done or noop
    local theme = opts.Theme or "halloween"
    local version = opts.Version or Loader.Version
    local info = Loader.Themes[theme] or Loader.Themes.standard
    local mainColor = opts.Main or info.Main
    local accent = opts.Accent or info.Accent
    local early = opts.Preload == true and opts.Done ~= nil
    pcall(function()
        getgenv().__OkloReveal = nil
    end)

    local noticeOpts = opts.Notice
    local runFinished = false
    task.spawn(function()
        local ok, result = pcall(run)
        if not ok then
            warn("[OkloLoader] load failed: " .. tostring(result))
        elseif type(result) == "table" then
            noticeOpts = result
        end
        runFinished = true
    end)

    local assets = if info.Abstract then setmetatable({}, { __index = function() return "" end }) else prepare(theme, version, namesFor(info))
    if not assets and noticeOpts then
        plainNotice(noticeOpts, mainColor, accent)
        return
    end
    if not assets then
        warn("[OkloLoader] could not get the " .. theme .. " files, playing without the animation")
        while not runFinished do
            task.wait(0.05)
        end
        if noticeOpts then
            plainNotice(noticeOpts, mainColor, accent)
            return
        end
        pcall(done)
        return
    end

    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local base = opts.Size or Vector2.new(760, 460)
    local uiScale = opts.Scale or 0.86
    local fullScale = math.max(0.1, math.min(uiScale, (viewport.X - 36) / base.X, (viewport.Y - 36) / base.Y))
    local fullSize = Vector2.new(round(base.X * fullScale), round(base.Y * fullScale))
    local play = opts.PlayScale or 0.5
    local artSize = Vector2.new(round(760 * fullScale), round(460 * fullScale))
    local playW, playH = round(artSize.X * play), round(artSize.Y * play)
    local playSize = Vector2.new(playW, playH)
    local playScale = fullScale * play
    local windowRadius = round(math.max(12, round(36 * fullScale)) * 0.46)
    pcall(function()
        getgenv().__OkloCard = { Main = mainColor, Accent = accent, Spin = SPIN_SPEED, Radius = windowRadius, Scale = fullScale }
    end)

    local gui = hostGui()
    local body = Instance.new("Frame")
    body.Name = "Window"
    body.AnchorPoint = Vector2.new(0.5, 0.5)
    body.Position = UDim2.fromScale(0.5, 0.5)
    body.Size = UDim2.fromOffset(playW, playH)
    body.BackgroundColor3 = mainColor
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.Parent = gui
    local corner = Instance.new("UICorner")
    corner.Parent = body

    local rim = Instance.new("Frame")
    rim.Name = "Outline"
    rim.Size = UDim2.fromScale(1, 1)
    rim.BackgroundTransparency = 1
    rim.BorderSizePixel = 0
    rim.Parent = body
    local rimCorner = Instance.new("UICorner")
    rimCorner.Parent = rim
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Transparency = 1
    stroke.Parent = rim
    local spin = Instance.new("UIGradient")
    spin.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, accent),
        ColorSequenceKeypoint.new(0.45, accent),
        ColorSequenceKeypoint.new(1, lighten(accent, 0.9)),
    })
    spin.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.84),
        NumberSequenceKeypoint.new(0.4, 0.8),
        NumberSequenceKeypoint.new(0.78, 0.35),
        NumberSequenceKeypoint.new(1, 0),
    })
    spin.Parent = stroke

    local content = Instance.new("CanvasGroup")
    content.Name = "Content"
    content.AnchorPoint = Vector2.new(0.5, 0.5)
    content.Position = UDim2.fromScale(0.5, 0.5)
    content.Size = UDim2.fromOffset(playW, playH)
    content.BackgroundTransparency = 1
    content.GroupTransparency = 1
    content.Parent = gui

    local function image(name, asset, parent)
        local label = Instance.new("ImageLabel")
        label.Name = name
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.Size = UDim2.fromOffset(playW, playH)
        label.Image = asset
        label.ScaleType = Enum.ScaleType.Stretch
        label.Parent = parent
        return label
    end

    local function cutter(list, size)
        return { List = list, Size = size, Sheet = 1 }
    end
    local function cut(c, index, transparency)
        local list = c.List
        if not index then
            list[c.Sheet].Visible = false
            return
        end
        local nextSheet = math.floor(index / PER_SHEET) + 1
        if nextSheet ~= c.Sheet then
            list[c.Sheet].Visible = false
            c.Sheet = nextSheet
        end
        local slot = index % PER_SHEET
        local sheet = list[c.Sheet]
        sheet.Visible = true
        sheet.ImageTransparency = transparency
        sheet.Position = UDim2.fromOffset(-(slot % COLS) * c.Size, -math.floor(slot / COLS) * c.Size)
    end

    local preload = {}
    local haloSize = round(1.2 * playH)
    local halo = image("Halo", assets["loader-halo"], content)
    halo.Size = UDim2.fromOffset(haloSize, haloSize)
    table.insert(preload, halo)

    local sceneSheets, sceneWindow = {}, nil
    local sceneSheets2, sceneWindow2 = {}, nil
    local sceneSize = haloSize
    if info.Scene then
        sceneWindow = Instance.new("Frame")
        sceneWindow.Name = "Scene"
        sceneWindow.BackgroundTransparency = 1
        sceneWindow.BorderSizePixel = 0
        sceneWindow.ClipsDescendants = true
        sceneWindow.Size = UDim2.fromOffset(sceneSize, sceneSize)
        sceneWindow.Parent = content
        for i = 1, SCENE_SHEETS do
            local sheet = image("Scene" .. i, assets["loader-scene-" .. i], sceneWindow)
            sheet.Size = UDim2.fromOffset(sceneSize * COLS, sceneSize * ROWS)
            sheet.ImageTransparency = 1
            sheet.Visible = false
            sceneSheets[i] = sheet
            table.insert(preload, sheet)
        end
        sceneWindow2 = Instance.new("Frame")
        sceneWindow2.Name = "SceneBlend"
        sceneWindow2.BackgroundTransparency = 1
        sceneWindow2.BorderSizePixel = 0
        sceneWindow2.ClipsDescendants = true
        sceneWindow2.Size = UDim2.fromOffset(sceneSize, sceneSize)
        sceneWindow2.Parent = content
        for i = 1, SCENE_SHEETS do
            local sheet = image("Scene" .. i, assets["loader-scene-" .. i], sceneWindow2)
            sheet.Size = UDim2.fromOffset(sceneSize * COLS, sceneSize * ROWS)
            sheet.ImageTransparency = 1
            sheet.Visible = false
            sceneSheets2[i] = sheet
        end
    end

    local text = image("Text", assets["loader-text"], content)
    table.insert(preload, text)
    local reveal = Instance.new("UIGradient")
    reveal.Transparency = NumberSequence.new(1)
    reveal.Parent = text

    local birdSize = round(0.56 * playH)
    local window = Instance.new("Frame")
    window.Name = "Bird"
    window.BackgroundTransparency = 1
    window.BorderSizePixel = 0
    window.ClipsDescendants = true
    window.Size = UDim2.fromOffset(birdSize, birdSize)
    window.Parent = content
    local sheets = {}
    for i = 1, BIRD_SHEETS do
        local sheet = image("Sheet" .. i, assets["loader-bird-" .. i], window)
        sheet.Size = UDim2.fromOffset(birdSize * COLS, birdSize * ROWS)
        sheet.Visible = false
        sheets[i] = sheet
        table.insert(preload, sheet)
    end
    local window2 = Instance.new("Frame")
    window2.Name = "BirdBlend"
    window2.BackgroundTransparency = 1
    window2.BorderSizePixel = 0
    window2.ClipsDescendants = true
    window2.Size = UDim2.fromOffset(birdSize, birdSize)
    window2.Parent = content
    local sheets2 = {}
    for i = 1, BIRD_SHEETS do
        local sheet = image("Sheet" .. i, assets["loader-bird-" .. i], window2)
        sheet.Size = UDim2.fromOffset(birdSize * COLS, birdSize * ROWS)
        sheet.ImageTransparency = 1
        sheet.Visible = false
        sheets2[i] = sheet
    end
    local birdBottom, birdTop = cutter(sheets, birdSize), cutter(sheets2, birdSize)
    local sceneBottom = cutter(sceneSheets, sceneSize)
    local sceneTop = cutter(sceneSheets2, sceneSize)
    cut(birdBottom, 0, 0)

    local particles = Instance.new("Folder")
    particles.Name = "Particles"
    particles.Parent = content
    local bats, embers, flakes = {}, {}, {}
    local bh = 0.5 * playH
    if info.Sprites then
        local rng = Random.new(7)
        local rows = { { 0.16, 0.085, 0.0 }, { 0.30, 0.060, 0.35 }, { 0.82, 0.070, 0.55 }, { 0.70, 0.050, 0.8 }, { 0.42, 0.045, 0.2 } }
        for i, row in ipairs(rows) do
            local label = Instance.new("ImageLabel")
            label.Name = "Bat" .. i
            label.BackgroundTransparency = 1
            label.BorderSizePixel = 0
            label.AnchorPoint = Vector2.new(0.5, 0.5)
            label.Image = assets["loader-sprites"]
            label.ImageRectSize = Vector2.new(64, 48)
            label.ImageTransparency = 1
            local width = playH * 1.4 * row[2] * 64 / 48
            label.Size = UDim2.fromOffset(round(width), round(width * 0.75))
            label.Parent = particles
            bats[i] = { Label = label, Row = row }
            table.insert(preload, label)
        end
        for i = 1, 40 do
            local label = Instance.new("ImageLabel")
            label.Name = "Ember" .. i
            label.BackgroundTransparency = 1
            label.BorderSizePixel = 0
            label.AnchorPoint = Vector2.new(0.5, 0.5)
            label.Image = assets["loader-sprites"]
            label.ImageRectOffset = Vector2.new(0, 96)
            label.ImageRectSize = Vector2.new(64, 64)
            label.ImageTransparency = 1
            label.Parent = particles
            embers[i] = { Label = label, Ph = rng:NextNumber(), X = rng:NextNumber(), Sz = rng:NextNumber(), Sw = rng:NextNumber() * 6.28 }
        end
    end
    if info.Snow then
        local rng = Random.new(33)
        for i = 1, 22 do
            local dot = Instance.new("Frame")
            dot.Name = "Flake" .. i
            dot.BorderSizePixel = 0
            dot.BackgroundColor3 = Color3.new(1, 1, 1)
            dot.BackgroundTransparency = 1
            dot.AnchorPoint = Vector2.new(0.5, 0.5)
            local round_ = Instance.new("UICorner")
            round_.CornerRadius = UDim.new(0.5, 0)
            round_.Parent = dot
            dot.Parent = particles
            flakes[i] = { Dot = dot, Ph = rng:NextNumber(), X = rng:NextNumber(), D = rng:NextNumber() ^ 1.6, Sw = rng:NextNumber() * 6.2832 }
        end
    end

    local updateArt
    if info.Abstract then
        local WHITE = Color3.new(1, 1, 1)
        local art = Instance.new("Frame")
        art.Name = "Art"
        art.BackgroundTransparency = 1
        art.BorderSizePixel = 0
        art.ClipsDescendants = true
        art.Size = UDim2.fromOffset(playW, playH)
        art.Parent = content
        local artCorner = Instance.new("UICorner")
        artCorner.Parent = art
        local m = playH
        local mx, my = playW / 2, playH / 2

        local function shape(parent, round_)
            local object = Instance.new("Frame")
            object.BackgroundColor3 = WHITE
            object.BackgroundTransparency = 1
            object.BorderSizePixel = 0
            object.AnchorPoint = Vector2.new(0.5, 0.5)
            if round_ then
                local rounding = Instance.new("UICorner")
                rounding.CornerRadius = UDim.new(0.5, 0)
                rounding.Parent = object
            end
            object.Parent = parent
            return object
        end

        local discs = {}
        for i = 1, 3 do
            discs[i] = shape(art, true)
            discs[i].Size = UDim2.fromOffset(round(m * (0.9 + 0.25 * i)), round(m * (0.9 + 0.25 * i)))
        end

        local rings = {}
        for i = 1, 4 do
            local ring = shape(art, true)
            ring.BackgroundTransparency = 1
            local line = Instance.new("UIStroke")
            line.Color = WHITE
            line.Thickness = 1
            line.Transparency = 1
            line.Parent = ring
            rings[i] = { Frame = ring, Stroke = line }
        end

        local orbits = {}
        local plan = { { 0.58, 0.30, 9, 0.55 }, { 0.42, 0.34, 7, -0.85 }, { 0.27, 0.22, 5, 1.3 } }
        for index, row in ipairs(plan) do
            local dots = {}
            for k = 1, row[3] do
                local dot = shape(art, true)
                local size = math.max(2, round(m * (0.012 + 0.012 * ((k * 7 + index * 3) % 5) / 4)))
                dot.Size = UDim2.fromOffset(size, size)
                dots[k] = dot
            end
            orbits[index] = { Dots = dots, Rx = row[1] * m, Ry = row[2] * m, Speed = row[4], Tilt = (index - 1) * 1.05 }
        end

        local BARS = 40
        local bars = {}
        local barWidth = math.max(1, round(playW / BARS * 0.5))
        for i = 1, BARS do
            local bar = shape(art, false)
            bar.AnchorPoint = Vector2.new(0.5, 1)
            bar.Size = UDim2.fromOffset(barWidth, 1)
            bar.Position = UDim2.fromOffset(round(playW * (i - 0.5) / BARS), playH)
            bars[i] = bar
        end

        local halo = shape(art, true)
        local core = shape(art, true)

        function updateArt(t)
            artCorner.CornerRadius = corner.CornerRadius
            local appear = ease(seg(t, 0, 0.9))
            local clock = t

            for i, disc in ipairs(discs) do
                disc.Position = UDim2.fromOffset(
                    round(mx + math.sin(clock * (0.31 + 0.07 * i) + i * 2) * playW * 0.26),
                    round(my + math.cos(clock * (0.23 + 0.05 * i) + i) * m * 0.2)
                )
                disc.BackgroundTransparency = 1 - 0.05 * appear
            end

            for i, ring in ipairs(rings) do
                local p = (clock * 0.26 + (i - 1) / 4) % 1
                local grow = 1 - (1 - p) ^ 2.2
                local diameter = round(m * (0.14 + 1.55 * grow))
                ring.Frame.Size = UDim2.fromOffset(diameter, diameter)
                ring.Frame.Position = UDim2.fromOffset(round(mx), round(my))
                ring.Stroke.Transparency = 1 - 0.6 * (1 - p) ^ 1.6 * seg(p, 0, 0.08) * appear
            end

            for index, orbit in ipairs(orbits) do
                local tilt = orbit.Tilt + clock * 0.12 * (if index == 2 then -1 else 1)
                local cosT, sinT = math.cos(tilt), math.sin(tilt)
                local count = #orbit.Dots
                for k, dot in ipairs(orbit.Dots) do
                    local phase = clock * orbit.Speed + (k / count) * 6.2832
                    local ex, ey = math.cos(phase) * orbit.Rx, math.sin(phase) * orbit.Ry
                    dot.Position = UDim2.fromOffset(round(mx + ex * cosT - ey * sinT), round(my + ex * sinT + ey * cosT))
                    local front = 0.5 + 0.5 * math.sin(phase)
                    dot.BackgroundTransparency = 1 - (0.25 + 0.7 * front) * appear
                end
            end

            for i, bar in ipairs(bars) do
                local u = (i - 1) / (BARS - 1)
                local wave = 0.6 * math.sin(u * 7.0 + clock * 1.35) + 0.4 * math.sin(u * 13.0 - clock * 2.1)
                local h = math.max(1, round(m * 0.26 * (0.5 + 0.5 * wave) * appear))
                bar.Size = UDim2.fromOffset(barWidth, h)
                bar.BackgroundTransparency = 1 - (0.1 + 0.32 * h / (m * 0.26)) * appear
            end

            local pulse = 1 + 0.12 * math.sin(clock * 3.0)
            local coreSize = round(m * 0.085 * pulse * (0.4 + 0.6 * appear))
            core.Size = UDim2.fromOffset(coreSize, coreSize)
            core.Position = UDim2.fromOffset(round(mx), round(my))
            core.BackgroundTransparency = 1 - appear
            local haloSize2 = round(m * 0.26 * pulse)
            halo.Size = UDim2.fromOffset(haloSize2, haloSize2)
            halo.Position = core.Position
            halo.BackgroundTransparency = 1 - 0.1 * appear
        end
    end

    do
        local cx = round((if opts.Fast == true then 0.5 else FROM_X) * playW)
        halo.Position = UDim2.fromOffset(cx - round(haloSize / 2), round(playH / 2 - haloSize / 2))
        window.Position = UDim2.fromOffset(cx - round(birdSize / 2), round(playH / 2 - birdSize / 2))
        window2.Position = window.Position
        if sceneWindow then
            sceneWindow.Position = UDim2.fromOffset(cx - round(sceneSize / 2), round(playH / 2 - sceneSize / 2))
            sceneWindow2.Position = sceneWindow.Position
        end
    end

    pcall(function()
        ContentProvider:PreloadAsync(preload)
    end)

    local noticeGroup, noticeSize, noticeStart, leaving
    local function arm(message)
        local noticeWidth = math.min(round(330 * fullScale), viewport.X - 40)
        noticeGroup = Instance.new("CanvasGroup")
        noticeGroup.Name = "Notice"
        noticeGroup.AnchorPoint = Vector2.new(0.5, 0.5)
        noticeGroup.Position = UDim2.fromScale(0.5, 0.5)
        noticeGroup.Size = UDim2.fromOffset(noticeWidth, 0)
        noticeGroup.AutomaticSize = Enum.AutomaticSize.Y
        noticeGroup.BackgroundTransparency = 1
        noticeGroup.GroupTransparency = 1
        noticeGroup.Parent = body
        fillNotice(noticeGroup, message, mainColor, accent, function()
            leaving = leaving or os.clock()
        end, fullScale)
        noticeWidth = math.min(noticeGroup.Size.X.Offset, viewport.X - 40)
        noticeGroup.Size = UDim2.fromOffset(noticeWidth, 0)
        task.spawn(function()
            task.wait(0.15)
            noticeSize = Vector2.new(noticeWidth, noticeGroup.AbsoluteSize.Y)
        end)
    end
    local armed = false

    local fast = opts.Fast == true
    local origin = os.clock()
    local from = opts.From
    local started = origin + (if fast then 0.1 else 0.25) + (if from then 1.6 else 0)
    local COVER, MORPH = 0.3, 1.25
    local fromCenter = opts.FromCenter
    local fromMain = opts.FromMain or mainColor
    local fromRadius = tonumber(opts.FromRadius) or windowRadius
    local coverAt, morphStart = nil, nil
    local contentScale
    if fast then
        contentScale = Instance.new("UIScale")
        contentScale.Parent = content
    end

    local birdDone = false
    local replayAt, holdAt = nil, nil
    local closing
    local doneCalled = false
    local doneAt
    local preloaded = false
    local dropped = false
    pcall(function()
        getgenv().__OkloDrawn = nil
    end)
    local shown = false
    local fade = 0
    local last = origin
    local connection
    connection = RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local dt = math.min(now - last, 0.1)
        last = now

        fade = fade + (1 - fade) * math.min(1, dt * 10)
        local morph = 0
        if from then
            fade = smoother((now - origin) / COVER)
            if fade >= 1 and not shown then
                shown = true
                coverAt = now
                pcall(function()
                    getgenv().__OkloCardUp = true
                end)
            end
            if coverAt and not morphStart then
                local waiting = false
                pcall(function()
                    waiting = getgenv().__OkloCardUp == true
                end)
                if not waiting or now - coverAt > 0.25 then
                    morphStart = now
                    started = now + MORPH
                end
            end
            morph = if morphStart then smoother((now - morphStart) / MORPH) else 0
        end
        local raw = 0
        if closing then
            raw = math.clamp((now - closing - (if fast then 0.05 else 0.2)) / (if fast then 0.62 else 1.38), 0, 1)
        end
        local expand = smoother(raw)
        local pop = ease((now - origin) / 0.4)
        local shrink = if from then 1 - morph else 0
        if from then
            pop = smoother(seg(morph, 0.78, 1))
        end
        if noticeOpts and not armed then
            armed = true
            arm(noticeOpts)
        end
        if noticeSize and not noticeStart and now - started > (if opts.Notice then 2.0 else 1.2) then
            noticeStart = now
        end
        if noticeSize then
            noticeSize = Vector2.new(noticeSize.X, noticeGroup.AbsoluteSize.Y)
        end
        local grow = if noticeStart then smoother((now - noticeStart) / 0.7) else 0
        local outT = if leaving then math.clamp((now - leaving) / 0.35, 0, 1) else 0
        local size = playSize + (fullSize - playSize) * expand
        if from then
            size = size + (from - playSize) * shrink
        end
        if noticeSize then
            size = size + (noticeSize - playSize) * grow
        end
        local popScale = (if from then 1 else 0.94 + 0.06 * pop) * (1 - 0.04 * outT)
        local bodyW, bodyH = round(size.X * popScale), round(size.Y * popScale)
        body.Size = UDim2.fromOffset(bodyW, bodyH)
        local screen = gui.AbsoluteSize
        if screen.X < 1 then
            screen = viewport
        end
        local centerX, centerY = screen.X * 0.5, screen.Y * 0.5
        if from and fromCenter then
            centerX = centerX + (fromCenter.X - centerX) * shrink
            centerY = centerY + (fromCenter.Y - centerY) * shrink
        end
        body.Position = UDim2.fromOffset(round(centerX - bodyW * 0.5) + bodyW * 0.5, round(centerY - bodyH * 0.5) + bodyH * 0.5)
        if from then
            content.Position = UDim2.fromOffset(round(centerX - playW * 0.5) + playW * 0.5, round(centerY - playH * 0.5) + playH * 0.5)
            body.BackgroundColor3 = fromMain:Lerp(mainColor, morph)
        end
        local scale = playScale + (fullScale - playScale) * expand
        local radius = math.max(6, round(16 * scale + (windowRadius - 16 * fullScale) * expand))
        if from then
            local start = round(fromRadius)
            radius = round(start + (radius - start) * morph)
        end
        corner.CornerRadius = UDim.new(0, radius)
        rimCorner.CornerRadius = UDim.new(0, radius)
        stroke.Thickness = math.max(1.5, 1.7 * scale)
        local closeFade = outT
        body.BackgroundTransparency = 1 - fade * (1 - closeFade)
        stroke.Transparency = 1 - fade * (1 - closeFade)
        spin.Rotation = (now * SPIN_SPEED) % 360
        local leaveFade = if closing then math.clamp(1 - (now - closing) / (if fast then 0.45 else 0.3), 0, 1) else 1
        if contentScale then
            contentScale.Scale = 1 - 0.1 * ease(1 - leaveFade)
            leaveFade = leaveFade * leaveFade * (3 - 2 * leaveFade)
        end
        content.GroupTransparency = 1 - (closing and leaveFade or math.clamp(fade * pop, 0, 1) * (1 - seg(grow, 0, 0.4)))
        if noticeGroup then
            noticeGroup.GroupTransparency = 1 - seg(grow, 0.55, 1) * (1 - outT)
        end

        if closing and not doneCalled and raw >= 1 and preloaded then
            doneCalled = true
            pcall(function()
                getgenv().__OkloReveal = true
            end)
            doneAt = os.clock()
        elseif closing and not doneCalled and raw >= 1 then
            doneCalled = true
            task.spawn(function()
                pcall(function()
                    getgenv().__OkloHandoff = true
                end)
                local ok, err = pcall(done)
                pcall(function()
                    getgenv().__OkloHandoff = nil
                end)
                doneAt = os.clock()
                if not ok then
                    warn("[OkloLoader] ui failed: " .. tostring(err))
                end
            end)
        end
        if doneCalled and not dropped then
            local drawn = nil
            pcall(function()
                drawn = getgenv().__OkloDrawn
            end)
            if drawn == true then
                dropped = true
                gui.Enabled = false
                pcall(function()
                    getgenv().__OkloDrawn = "gone"
                    getgenv().__OkloCard = nil
                end)
            end
        end

        local t = now - started
        if t < 0 then
            return
        end
        local u = (t / LOOP) % 1
        local first = t < LOOP
        if updateArt then
            updateArt(t)
        end

        local glide = if fast then 0 else ease((t - SLIDE_AT) / SLIDE_FOR)
        local x = if fast then 0.5 else FROM_X + (TO_X - FROM_X) * glide
        local cx = round(x * playW)
        halo.Position = UDim2.fromOffset(cx - round(haloSize / 2), round(playH / 2 - haloSize / 2))
        window.Position = UDim2.fromOffset(cx - round(birdSize / 2), round(playH / 2 - birdSize / 2))
        window2.Position = window.Position
        if not birdDone then
            local edge = if fast then 0 else x - 0.0363 - (1 - glide) * 0.08
            if edge <= 0 then
                reveal.Transparency = NumberSequence.new(1)
            elseif edge >= 1 then
                reveal.Transparency = NumberSequence.new(0)
            else
                local points = { NumberSequenceKeypoint.new(0, 0) }
                if edge - 0.03 > 0.001 then
                    table.insert(points, NumberSequenceKeypoint.new(edge - 0.03, 0))
                end
                table.insert(points, NumberSequenceKeypoint.new(edge, 1))
                table.insert(points, NumberSequenceKeypoint.new(1, 1))
                reveal.Transparency = NumberSequence.new(points)
            end

            local fp
            if fast then
                fp = DRAW_FRAMES + REPLAY_FRAMES
                if runFinished and t >= 0.5 then
                    birdDone = true
                end
            elseif t < DRAW_FRAMES / FPS then
                fp = t * FPS + 1
            else
                replayAt = replayAt or now
                local pos = (now - replayAt) * FPS
                if pos >= REPLAY_FRAMES - 1 then
                    pos = REPLAY_FRAMES - 1
                    if runFinished then
                        holdAt = holdAt or now
                        if now - holdAt >= HOLD_AFTER then
                            birdDone = true
                        end
                    end
                end
                fp = DRAW_FRAMES + pos + 1
            end
            local n = math.floor(fp)
            cut(birdBottom, n - 1, 0)
            cut(birdTop, nil)
        end

        if sceneWindow then
            sceneWindow.Position = UDim2.fromOffset(cx - round(sceneSize / 2), round(playH / 2 - sceneSize / 2))
            local alpha = if info.Gate then seg(t, 1.62, 2.0) else seg(t, 0, 0.3)
            if info.LoopFade then
                alpha = alpha * ease(seg(u, 0, 0.08)) * (1 - ease(seg(u, 0.9, 1)))
            end
            local fs = u * SCENE_FRAMES
            local frame = math.min(SCENE_FRAMES - 1, math.floor(fs))
            local blend = fs - frame
            sceneWindow2.Position = sceneWindow.Position
            cut(sceneBottom, frame, 1 - alpha)
            if blend > 0.02 and not info.Steady then
                cut(sceneTop, (frame + 1) % SCENE_FRAMES, 1 - alpha * blend)
            else
                cut(sceneTop, nil)
            end
        end

        local batK = first and seg(u, 0.2, 0.45) or 1
        for i, bat in ipairs(bats) do
            local row = bat.Row
            local fr = (u + row[3]) % 1
            local flap = math.abs(math.cos(math.pi * 14 * u + i))
            local px = (-0.10 + fr * 1.20) * playW
            local py = playH * row[1] + math.sin((u * 2 + row[3]) * 6.2832) * playH * 0.02
            bat.Label.Position = UDim2.fromOffset(round(px), round(py))
            bat.Label.Rotation = math.cos(fr * 12.566) * 7
            bat.Label.ImageRectOffset = Vector2.new((math.floor(flap * 5 + 0.5) % 3) * 64, math.floor(math.floor(flap * 5 + 0.5) / 3) * 48)
            bat.Label.ImageTransparency = 1 - batK * 0.55
        end
        local emberK = first and seg(u, 0.15, 0.45) or 1
        local unit = bh * 0.0055 * 0.5 * 2
        for _, ember in ipairs(embers) do
            local fr = (u + ember.Ph) % 1
            local ex = playW * ember.X + math.sin(fr * 6.28 + ember.Sw) * unit * 6
            local ey = playH / 2 - 0.6 * bh + 1.2 * bh - fr * 1.2 * bh * 1.05
            local near = math.clamp(1 - math.sqrt(((ex - cx) / (1.1 * bh)) ^ 2 + ((ey - playH / 2) / (0.9 * bh)) ^ 2), 0, 1)
            local a = math.sin(math.pi * fr) ^ 1.4 * (90 + 140 * ember.Sz) / 255 * emberK * (0.1 + 0.9 * near * near * (3 - 2 * near))
            local d = round(6 * unit * (0.8 + 1.1 * ember.Sz) * 1.0)
            ember.Label.Size = UDim2.fromOffset(d, d)
            ember.Label.Position = UDim2.fromOffset(round(ex), round(ey))
            ember.Label.ImageTransparency = 1 - math.clamp(a, 0, 1)
        end
        local flake = playH * 0.0036
        for _, f in ipairs(flakes) do
            local speed = f.D > 0.5 and 2 or 1
            local fr = (u * speed + f.Ph) % 1
            local fx = playW * f.X + math.sin(u * speed * 6.2832 + f.Sw) * flake * (2 + 7 * f.D)
            local fy = playH * (-0.06 + fr * 1.12)
            local a = math.min(1, math.min(fr * 10, (1 - fr) * 10)) * (70 + 170 * f.D) / 255 * (first and seg(u, 0.15, 0.45) or 1)
            local d = math.max(1, round(flake * (0.5 + 2.6 * f.D) * 2))
            f.Dot.Size = UDim2.fromOffset(d, d)
            f.Dot.Position = UDim2.fromOffset(round(fx), round(fy))
            f.Dot.BackgroundTransparency = 1 - math.clamp(a, 0, 1)
        end
    end)

    local built, buildFrom = not early, nil
    while (not birdDone or not runFinished or not built) and not noticeOpts do
        if early and not buildFrom and runFinished and (fast or holdAt) then
            buildFrom = os.clock()
            preloaded = true
            task.spawn(function()
                pcall(function()
                    getgenv().__OkloPreload = true
                end)
                local ok, err = pcall(done)
                if not ok then
                    warn("[OkloLoader] ui failed: " .. tostring(err))
                end
                built = true
            end)
        end
        if buildFrom and not built then
            local answer = nil
            pcall(function()
                answer = getgenv().__OkloPreload
            end)
            built = answer == "built" or os.clock() - buildFrom > 15
        end
        task.wait(0.03)
    end
    if early then
        pcall(function()
            getgenv().__OkloPreload = nil
        end)
    end
    if noticeOpts then
        while not leaving or os.clock() - leaving < 0.4 do
            task.wait(0.03)
        end
        connection:Disconnect()
        gui:Destroy()
        if noticeOpts.OnClose then
            pcall(noticeOpts.OnClose)
        end
        return
    end
    task.wait(if fast then 0.05 else 0.2)
    closing = os.clock()
    while not doneAt and not dropped and os.clock() - closing < 20 do
        task.wait(0.03)
    end
    local since = os.clock()
    while not dropped and os.clock() - since < 1.5 do
        task.wait()
    end
    connection:Disconnect()
    gui:Destroy()
end

function Loader.notice(opts)
    task.spawn(Loader.play, {
        Theme = opts.Theme,
        Main = opts.Main,
        Accent = opts.Accent,
        Size = opts.Size,
        Notice = opts,
    })
end

return Loader
end)()

local Support = (function()
local DEMANDS = {
    { name = "request", hard = true },
    { name = "loadstring", hard = true },
    { name = "getgenv", hard = true },
    { name = "Drawing", hard = true },
    { name = "writefile" },
    { name = "readfile" },
    { name = "isfile" },
    { name = "isfolder" },
    { name = "makefolder" },
    { name = "delfile" },
    { name = "listfiles" },
    { name = "getcustomasset" },
    { name = "getgc" },
    { name = "firetouchinterest" },
    { name = "setclipboard" },
}

local present = {
    request = request,
    loadstring = loadstring,
    getgenv = getgenv,
    Drawing = Drawing,
    writefile = writefile,
    readfile = readfile,
    isfile = isfile,
    isfolder = isfolder,
    makefolder = makefolder,
    delfile = delfile,
    listfiles = listfiles,
    getcustomasset = getcustomasset,
    getgc = getgc,
    firetouchinterest = firetouchinterest,
    setclipboard = setclipboard,
}

local PROBES = {
    loadstring = function()
        local chunk = loadstring("return 7")
        return type(chunk) == "function" and chunk() == 7
    end,
    getgenv = function()
        return type(getgenv()) == "table"
    end,
    Drawing = function()
        local shape = Drawing.new("Square")
        shape:Remove()
        return true
    end,
}

local DEMANDED = {}
for _, demand in ipairs(DEMANDS) do
    DEMANDED[demand.name] = true
end

local function lacking()
    local list = {}
    for _, demand in ipairs(DEMANDS) do
        if present[demand.name] == nil then
            table.insert(list, demand.name)
        elseif PROBES[demand.name] then
            local ok, result = pcall(PROBES[demand.name])
            if not ok or result ~= true then
                table.insert(list, demand.name .. " (not working)")
            end
        end
    end
    return list
end

local function shortReason(reason)
    if reason == nil or reason == "" then
        return "unknown"
    end
    local text = string.gsub(tostring(reason), "%s+", " ")
    text = string.gsub(text, '^%[string "[^"]*"%]:%d+: ', "")
    if #text > 150 then
        text = string.sub(text, 1, 147) .. "..."
    end
    return text
end

local function joinDiscord(discord)
    local copy = setclipboard or toclipboard
    local copied = copy ~= nil and pcall(copy, discord)
    pcall(function()
        game:GetService("GuiService"):OpenBrowserWindow(discord)
    end)
    local code = string.match(discord, "discord%.gg/([%w%-_]+)")
    if code and type(request) == "function" then
        task.spawn(function()
            local http = game:GetService("HttpService")
            local body = http:JSONEncode({ cmd = "INVITE_BROWSER", args = { code = code }, nonce = http:GenerateGUID(false) })
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
    return if copied then "Invite link copied to your clipboard, paste it in Discord if it did not open." else "Open " .. discord .. " to join the server."
end

return function(discord, reason, compileFailure)
    local executor = "unknown"
    local ok, name = pcall(function()
        return identifyexecutor()
    end)
    if ok and type(name) == "string" and name ~= "" then
        executor = name
    end
    local text = tostring(reason or "")
    local list = lacking()
    local named = string.match(text, "%(global '([%w_]+)'%)") or string.match(text, "%(field '([%w_]+)'%)")
    local kind, obfuscated = "obfuscation", nil
    if not compileFailure then
        if named and DEMANDED[named] then
            local listed = false
            for _, entry in ipairs(list) do
                listed = listed or string.gsub(entry, " %(not working%)$", "") == named
            end
            if not listed then
                table.insert(list, 1, named)
            end
        end
        if #list > 0 then
            kind = "missing"
        elseif named and not DEMANDED[named] then
            obfuscated = named
        end
    end
    if kind ~= "missing" then
        list = {}
    end
    local hash = 5381
    local seed = tostring(executor) .. "|" .. kind .. "|" .. shortReason(reason) .. "|" .. table.concat(list, ",")
    for index = 1, #seed do
        hash = (hash * 33 + string.byte(seed, index)) % 16777216
    end
    local info = {
        note = "the script keeps expanding for full compatibility, any reports and suggestions will be highly appreciated!",
        reason = "reason: " .. shortReason(reason),
        report = string.format("report: %s | %06X | loader %s", executor, hash, "1.0"),
    }
    if kind == "missing" then
        info.head = "Your executor (" .. executor .. ") seems to not be able to support this script, please join the discord server and report your issue!"
        info.detail = "missing functions: " .. (if #list > 0 then table.concat(list, ", ") else "none found")
    else
        info.head = "Your executor (" .. executor .. ") cannot run the obfuscation of this script, please join the discord server and report your issue!"
        info.detail = if obfuscated then "the obfuscation needs " .. obfuscated .. ", which your executor does not have" else "everything the script itself needs is supported, so this comes from the obfuscation"
    end
    return {
        Lines = { info.head, "<u>" .. info.note .. "</u>", info.reason, info.detail, info.report },
        Buttons = {
            {
                Text = "Join Discord Server",
                Primary = true,
                Top = true,
                Click = function(api)
                    api.note(joinDiscord(discord))
                    task.delay(1.2, api.close)
                    return false
                end,
            },
        },
    }
end
end)()

local Session = (function()
return function()
    local env = getgenv()
    if env.__OkloSession then
        return
    end
    env.__OkloSession = true
    local players = game:GetService("Players")
    local me = players.LocalPlayer
    local virtualUser = game:GetService("VirtualUser")
    local teleport = game:GetService("TeleportService")
    me.Idled:Connect(function()
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.zero)
    end)
    game:GetService("GuiService").ErrorMessageChanged:Connect(function()
        task.wait(2)
        pcall(function()
            teleport:Teleport(game.PlaceId, me)
        end)
    end)
end
end)()

local Migrate = (function()
return function()
    pcall(function()
        local OLD, NEW = "okdude42scripts", "oklo scripts"
        if not (isfolder and makefolder and listfiles and isfile and readfile and writefile and isfolder(OLD)) then return end
        local clean = true
        local function move(from, to)
            if not isfolder(to) then makefolder(to) end
            for _, path in listfiles(from) do
                local name = string.match(path, "[^/\\]+$")
                if name then
                    if isfolder(path) then move(path, to .. "/" .. name)
                    elseif not isfile(to .. "/" .. name) then
                        local ok, data = pcall(readfile, path)
                        if not (ok and pcall(writefile, to .. "/" .. name, data)) then clean = false end
                    end
                end
            end
        end
        move(OLD, NEW)
        if clean and delfolder then pcall(delfolder, OLD) end
    end)
end
end)()

local Teleport = (function()
return function(url, gameId, enabled)
    if type(queue_on_teleport) ~= "function" then
        return nil
    end
    local queuedAt = 0
    return game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
        if state == Enum.TeleportState.Failed or os.clock() - queuedAt < 5 or (enabled and not enabled()) then
            return
        end
        queuedAt = os.clock()
        pcall(queue_on_teleport, string.format(
            'if game.GameId == %d and os.time() - %d < 180 then getgenv().__OkloFastLoad = true loadstring(game:HttpGet("%s"))() end',
            gameId or game.GameId,
            os.time(),
            url
        ))
    end)
end
end)()

local Counter = (function()
return function(...)
local SCRIPT, STOP = ...
task.spawn(pcall, function()
    local function clean(value, limit)
        return string.sub(string.gsub(tostring(value or "unknown"), "[^%w ._-]", ""), 1, limit)
    end
    local function encode(value)
        return (string.gsub(value, "[^%w]", function(character)
            return string.format("%%%02X", string.byte(character))
        end))
    end
    local function safe(call, fallback)
        local ok, value = pcall(call)
        if ok and value ~= nil then
            return value
        end
        return fallback
    end
    local players = game:GetService("Players")
    local input = game:GetService("UserInputService")
    local id = nil
    pcall(function()
        local folder, path = "oklo scripts", "oklo scripts/anonymous id.txt"
        if isfile(path) then
            local saved = string.lower((string.gsub(readfile(path), "%s", "")))
            if #saved == 24 and string.match(saved, "^%x+$") then
                id = saved
                return
            end
        end
        local generator = Random.new()
        local made = {}
        for index = 1, 24 do
            made[index] = string.format("%x", generator:NextInteger(0, 15))
        end
        local fresh = table.concat(made)
        if not isfolder(folder) then
            makefolder(folder)
        end
        writefile(path, fresh)
        id = fresh
    end)
    local executor = "unknown"
    if identifyexecutor then
        local ok, name = pcall(identifyexecutor)
        if ok and name then
            executor = tostring(name)
        end
    end
    local present = {
        request, writefile, readfile, isfile, makefolder, hookfunction, getgc, setclipboard, getgenv, loadstring,
        Drawing, firesignal, getconnections, getrawmetatable, setreadonly, getcustomasset, queue_on_teleport,
        fireclickdetector, firetouchinterest, getnilinstances,
    }
    local bits = {}
    for index = 1, 20 do
        bits[index] = if present[index] ~= nil then "1" else "0"
    end
    local device = safe(function()
        return input:GetPlatform().Name
    end, nil)
    if device == nil then
        device = if safe(function()
            return input.TouchEnabled and not input.KeyboardEnabled
        end, false) then "Mobile" else "PC"
    end
    local query = table.concat({
        "s=" .. SCRIPT,
        "p=" .. tostring(game.PlaceId),
        "u=" .. tostring(game.GameId),
        "e=" .. encode(clean(executor, 24)),
        "d=" .. encode(clean(device, 16)),
        "c=" .. table.concat(bits),
    }, "&")
    local sessionId = nil
    if id then
        local generator = Random.new()
        local made = {}
        for index = 1, 8 do
            made[index] = string.format("%x", generator:NextInteger(0, 15))
        end
        sessionId = table.concat(made)
        query ..= "&i=" .. id .. "&sid=" .. sessionId
    end
    local base = "https://execution-counter.cheekyboy67.workers.dev/run?"
    local function send(url)
        local options = { Url = url, Method = "GET" }
        local attempts = {
            function()
                return request(options)
            end,
            function()
                return http_request(options)
            end,
            function()
                return syn.request(options)
            end,
            function()
                return http.request(options)
            end,
            function()
                return fluxus.request(options)
            end,
            function()
                return (game :: any):HttpGet(url)
            end,
            function()
                return (game :: any):HttpGetAsync(url)
            end,
            function()
                return game:GetService("HttpService"):GetAsync(url)
            end,
        }
        for _, attempt in attempts do
            if pcall(attempt) then
                break
            end
        end
    end
    send(base .. query)
    if id and sessionId then
        local started = os.time()
        local pause = 1
        local mine = nil
        while true do
            task.wait(pause)
            pause = 300
            if mine == nil then
                mine = getgenv()[STOP]
            end
            local alive = mine ~= nil and getgenv()[STOP] == mine
            send(base .. "s=" .. SCRIPT .. "&hb=1&i=" .. id .. "&sid=" .. sessionId .. "&sec=" .. math.max(0, os.time() - started) .. (if alive then "" else "&end=1"))
            if not alive then
                break
            end
        end
    end
end)
end
end)()

local HUB_SOURCE = nil

local SAVED_REGISTRY = [=====[
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
]=====]


local function fetch(url)
    local ok, response = pcall(request, { Url = url, Method = "GET" })
    if ok and type(response) == "table" and type(response.Body) == "string" and response.Body ~= "" and (tonumber(response.StatusCode) or 200) < 400 then
        return response.Body
    end
    local got, body = pcall(game.HttpGet, game, url)
    return if got and type(body) == "string" and body ~= "" then body else nil
end

local function fetchCached(url, name)
    local folder = "oklo scripts/cache"
    local bodyPath, tagPath = folder .. "/" .. name, folder .. "/" .. name .. ".etag"
    local cached, tag
    pcall(function()
        if isfile(bodyPath) and isfile(tagPath) then
            cached, tag = readfile(bodyPath), readfile(tagPath)
        end
    end)
    if cached == "" then
        cached = nil
    end
    local headers = {}
    if cached and tag and tag ~= "" then
        headers["If-None-Match"] = tag
    end
    local ok, response = pcall(request, { Url = url, Method = "GET", Headers = headers })
    if ok and type(response) == "table" then
        local status = tonumber(response.StatusCode) or 200
        if status == 304 and cached then
            return cached
        end
        if status < 400 and type(response.Body) == "string" and response.Body ~= "" then
            local fresh
            for key, value in response.Headers or {} do
                if string.lower(tostring(key)) == "etag" then
                    fresh = tostring(value)
                end
            end
            if fresh then
                pcall(function()
                    for _, path in { "oklo scripts", folder } do
                        if not isfolder(path) then
                            makefolder(path)
                        end
                    end
                    writefile(bodyPath, response.Body)
                    writefile(tagPath, fresh)
                end)
            end
            return response.Body
        end
        if cached then
            return cached
        end
    end
    return fetch(url) or cached
end

if CONFIG.Hub and CONFIG.RegistryUrl then
    pcall(function()
        local body = fetch(CONFIG.RegistryUrl) or SAVED_REGISTRY
        local data = body and game:GetService("HttpService"):JSONDecode(body)
        if type(data) ~= "table" or type(data.Scripts) ~= "table" then
            return
        end
        if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftShift) then
            return
        end
        for _, entry in data.Scripts do
            local config = type(entry) == "table" and entry.Config
            if type(config) == "table" and entry.Universal ~= true and config.ScriptUrl then
                local here = (config.GameId and config.GameId == game.GameId) or table.find(entry.Places or {}, game.PlaceId) ~= nil
                if here then
                    for key, value in config do
                        CONFIG[key] = value
                    end
                    CONFIG.Hub = nil
                    return
                end
            end
        end
    end)
end

local NAME = CONFIG.Name

local colors = {}
pcall(function()
    local path = CONFIG.Folder .. "/default_theme.json"
    if not isfile(path) then
        return
    end
    local data = game:GetService("HttpService"):JSONDecode(readfile(path))
    local function hex(text)
        local r, g, b = string.match(tostring(text), "^#?(%x%x)(%x%x)(%x%x)$")
        return r and Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
    end
    colors.Main, colors.Accent = hex(data.ShownMain), hex(data.ShownAccent)
    if not (colors.Main and colors.Accent) then
        colors = {}
    end
end)

local function style(card)
    card.Theme, card.Main, card.Accent = "standard", colors.Main, colors.Accent
    card.Size, card.Title = Vector2.new(CONFIG.Width, CONFIG.Height), NAME
    if CONFIG.FromWidth and CONFIG.FromHeight then
        card.From = Vector2.new(CONFIG.FromWidth, CONFIG.FromHeight)
        card.FromCenter = if CONFIG.FromX then Vector2.new(CONFIG.FromX, CONFIG.FromY) else nil
        card.FromRadius, card.FromMain = CONFIG.FromRadius, CONFIG.FromMain
    end
    return card
end

local API = {
    teleport = Teleport,
    config = CONFIG,
    url = CONFIG.LoaderUrl,
    notice = function(card)
        Intro.notice(style(card))
    end,
}

local function fasterLoader()
    local env = getgenv()
    if env.__OkloFastLoad == true then
        env.__OkloFastLoad = nil
        return true
    end
    local ok, value = pcall(function()
        local path = CONFIG.Folder .. "/ui_settings.json"
        return isfile(path) and game:GetService("HttpService"):JSONDecode(readfile(path)).FasterLoader == true
    end)
    return ok and value
end

local function unsupported(reason, compileFailure)
    warn(NAME .. " loader: " .. tostring(reason))
    pcall(function()
        local built = ""
        for part in string.gmatch(CONFIG.Folder, "[^/]+") do
            built = if built == "" then part else built .. "/" .. part
            if not isfolder(built) then
                makefolder(built)
            end
        end
        writefile(CONFIG.Folder .. "/error.txt", tostring(reason))
    end)
    return style(Support(CONFIG.Discord, reason, compileFailure))
end

local function launch()
    local chunk

    local function load()
        local source = if CONFIG.Hub and HUB_SOURCE then HUB_SOURCE else fetch(CONFIG.ScriptUrl)
        if not source then
            return style({
                Lines = { "Could not download the script.", "GitHub has ratelimited you, please try again later or use a VPN." },
                Buttons = { { Text = "Close", Primary = true } },
            })
        end
        local compileError
        chunk, compileError = loadstring(source, NAME)
        if not chunk then
            return unsupported("could not compile: " .. tostring(compileError), true)
        end
        local lib = fetchCached(CONFIG.UiUrl, "OkloUI.luau")
        if lib then
            getgenv().__OkloUiPrefetch = lib
        end
    end

    local function start()
        if not chunk then
            return
        end
        pcall(Migrate)
        pcall(Counter, CONFIG.Id, CONFIG.Registry)
        local ok, failure = xpcall(chunk, debug.traceback, API)
        getgenv().__OkloUiPrefetch = nil
        if ok then
            return
        end
        if string.find(tostring(failure), "could not download", 1, true) then
            warn(NAME .. " loader: " .. tostring(failure))
            return
        end
        local card = unsupported(failure, false)
        if card then
            Intro.notice(card)
        end
    end

    local running = type(getgenv()[CONFIG.Registry]) == "function"
    local faster = fasterLoader() or running
    if not pcall(Intro.play, style({ Run = load, Done = start, Fast = faster })) then
        load()
        start()
    end
end

local function wrongGame()
    if CONFIG.GameId and game.GameId == CONFIG.GameId then
        return false
    end
    for place in string.gmatch(CONFIG.Places or "", "%d+") do
        if tonumber(place) == game.PlaceId then
            return false
        end
    end
    return true
end

local function showWrongGame()
    local service = game:GetService("TeleportService")
    local link = "https://www.roblox.com/games/" .. CONFIG.HomePlace
    local failure
    local joining = false
    Intro.notice(style({
        Lines = { "This script only works for " .. CONFIG.GameName .. "!", "Would you like to join " .. CONFIG.GameName .. "?" },
        Buttons = {
            {
                Text = "Yes",
                Primary = true,
                Click = function(api)
                    if joining then
                        return false
                    end
                    joining = true
                    api.note("Joining " .. CONFIG.GameName .. "...")
                    failure = service.TeleportInitFailed:Connect(function()
                        joining = false
                        local copy = setclipboard or toclipboard
                        if copy and pcall(copy, link) then
                            api.note("Roblox blocked joining from here. The game link was copied, paste it in your browser to join.")
                        else
                            api.note("Roblox blocked joining from here. Open " .. link .. " in your browser to join.")
                        end
                    end)
                    pcall(function()
                        service:Teleport(CONFIG.HomePlace, game:GetService("Players").LocalPlayer)
                    end)
                    return false
                end,
            },
            { Text = "No" },
        },
        OnClose = function()
            if failure then
                failure:Disconnect()
            end
        end,
    }))
end

pcall(function()
    getgenv().__OkloNotice = Intro.notice
end)

if CONFIG.HomePlace and wrongGame() then
    showWrongGame()
    return
end

pcall(Session)

launch()
