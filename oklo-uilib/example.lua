
local OkloUI = loadstring(request({ Url = "https://raw.githubusercontent.com/okdude42/main-scripts/main/oklo-uilib/OkloUI.luau", Method = "GET" }).Body)()

local function run()
    local ui = OkloUI.new({
        Title = "oklo ui lib by ok0f",
        Subtitle = "example script",
        Version = "1.0.0",
        Keybind = "RightShift",
        Folder = "whateverUrScriptsNameIs",

        Width = 760,
        Height = 460,
        SidebarWidth = 176,
        Theme = "GTA VI",
        Font = 1,

        Welcome = {
            Title = "Welcome to My Script",
            Heading = "here is what is new",
            Lines = { "first thing", "second thing", "third thing" },
            Footer = "lmk about issues in the discord",
            Width = 400,
            Height = 404,
        },
        UpdateNotice = { "V1.0.0", "fixed a bug", "added a feature" },

        OnUnload = function() end,
        OnReload = run,
    })

    local tabMain = ui:tab("Main", { Group = "Main" })
    local tabOther = ui:tab("Other", { Group = "Main" })

    local section = tabMain:section("SETTINGS (of whatever)")

    section:toggle({
        Name = "toggletest1",
        Flag = "Test1",
        Default = false,
        Callback = function(state) print("test1:", state) end,
    })

    section:label("more testing")

    section:pair({
        Type = "Toggle",
        Name = "toggletest2",
        Flag = "Test2",
        Default = false,
        Callback = function(state) print("test2:", state) end,
    }, {
        Type = "Toggle",
        Name = "toggletest3",
        Flag = "Test3",
        Default = true,
        Callback = function(state) print("test3:", state) end,
    })

    section:slider({
        Name = "slidertest1",
        Flag = "Test4",
        Min = 0, Max = 100, Default = 50,
        Callback = function(value) print("slider value:", value) end,
    })

    section:dropdown({
        Name = "dropdowntest1",
        Flag = "Test5",
        Values = { "Option 1", "Option 2", "Option 3" },
        Default = "Option 1",
        Callback = function(value) print("dropdown:", value) end,
    })

    section:color({
        Name = "custom color",
        Flag = "Test6",
        Default = Color3.new(1, 0, 0),
        Callback = function(color) print("color:", color) end,
    })

    ui:popup("popuptest1", {
        Width = 260,
        Height = 176,
        Title = "popuptest1",
        Render = function(kit, window)
            kit:switchRow("popuptest1:switch", 10, 50, kit.Width - 20, 36, "toggletest1", window:get("Test1"), function()
                window:set("Test1", not window:get("Test1"))
            end)
            kit:button("popuptest1:button", 10, 96, kit.Width - 20, 28, function() print("button works") end, { label = "buttontest1", align = "center" })
            kit:closeButton("Close", function() window:closePopup() end)
        end,
    })

    tabOther:button({
        Name = "buttontest2",
        Callback = function()
            ui:openPopup("popuptest1")
        end,
    })

    ui:start()
end

run()
