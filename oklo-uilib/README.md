# oklo ui lib documentation

a menu lib. sidebar with pages, toggles with hotkeys, sliders, dropdowns, color mixer, popups, floating panels, smooth scrolling, configs, themes and 53 fonts. the menu is real instances in `gethui()`, the game overlays (esp, circles, text) are drawing objects.
`example.lua` shows the basics of the lib, read it first and then come back here when you need something.

## loading it

put `OkloUI.luau` in your workspace folder as `Oklo UI Lib/OkloUI.luau` and load it with

```lua
local OkloUI = loadfile("Oklo UI Lib/OkloUI.luau")()
```

or load it from GitHub

```lua
local OkloUI = loadstring(request({ Url = "https://raw.githubusercontent.com/okdude42/main-scripts/main/oklo-uilib/OkloUI.luau", Method = "GET" }).Body)()
```

## making a window

```lua
local ui = OkloUI.new({
    Title = "my script",
    Subtitle = "universal",
    Version = "1.0.0",
    Folder = "myscriptconfs", -- folder in workspace, your configs save in it
})
```

every option, none of them are needed except Title

| option | what it does |
| --- | --- |
| Title | name at the top of the sidebar. a second window with the same Title (or Id) replaces the first one |
| Id | use this if two scripts have the same Title |
| Subtitle | small text under the title and under every page name |
| Version | shown on the badge in the sidebar. any text works, `"1"` shows V1 |
| ConfigFolder | a sub folder of Folder where the configs are saved, for example `"configs"`. without it the configs sit in Folder itself. config files already in Folder are moved into it on start |
| Folder | the folder in workspace for configs and saved stuff. use a nested path like `"myscripts/mygame"` to keep scripts together |
| Footer | text at the bottom left. it is also the status place: when the player turns a toggle on or off with a click or a hotkey the footer fades to "<name> enabled" or "<name> disabled" for about two seconds and then back to this text |
| Discord | `Discord = "https://discord.gg/xxxx"` adds a "Join Server" button with the Discord icon next to the version badge at the bottom of the sidebar. pressing it copies the invite to the clipboard, asks the Discord app to open the invite (it needs the desktop app running) and shows a popup that says so. leave it out for no button |
| Announce | false turns those enabled and disabled messages off, default true |
| Keybind | key that opens and closes the menu, default RightShift |
| Width, Height | window size, 360 to 1400 and 300 to 900. default 760 and 460 |
| SidebarWidth | how wide the sidebar is, 110 to 300. default 176 |
| NoSidebar | `true` removes the sidebar and the content uses the whole window. pages can not be switched anymore, so use it for a window with one page |
| TopNav | with `NoSidebar`, `true` puts the logo, title and subtitle in the header and turns the sections of the page into a top bar of tabs with the sliding pill, the Join Server button and the version badge on the right |
| Scale | ui scale, default 0.86. only use it if you have a custom scale or 4k res |
| MainColor, AccentColor | the start colors. the player can change them in Customization and Reset goes back to yours |
| BoldTitles | true draws the menu title and the page titles in bold (Gotham Bold). default false |
| Font | start font number, 0 to 52, default 1 (Gotham Medium). `OkloUI.Fonts.NAMES` is the list |
| Logo | an image instead of the first letter of the title, look at logo below |
| Theme | the start theme, the name of a built in theme or your own theme table, look at themes below |
| ForceTheme | the name of a built in theme that is put on every player one time, look at themes below |
| Welcome | the welcome card, look at welcome below |
| UpdateNotice | the update popup, look at welcome below |
| Thanks | true shows a "thank you" popup one time on the first start with a Join Server button for the Discord link, it shows after Welcome and UpdateNotice. needs Discord to have the button |
| Status | a function that returns a text for the footer (or nil), the text fades in at the bottom left |
| IsTyping | a function that returns true while the player types. you do not need this, the typing check is built in |
| OnUnload | runs when the player presses U. turn everything of your script off in here |
| OnReload | runs when the player presses R. the R button only exists when this is set. run your script again in here |
| ShareId | start of the config codes, default is the Title |

for reload to work put your whole script inside a function and give that function to OnReload, like in example.lua

## logo

```lua
Logo = "https://tr.rbxcdn.com/.../256/256/Image/Png/noFilter"
Logo = { Url = "https://...", GameIcon = true }
Logo = { Emblem = true }
```

the image is downloaded once with `request`, saved in `<Folder>/logo` and shown with rounded corners instead of the first letter of Title. it fades in when it is ready. `/Webp/` in a roblox thumbnail link is changed to `/Png/`. `Emblem = true` draws the built in bird logo: a rounded square in the main color of the menu with the logo in the accent color, so it follows every theme. with `GameIcon = true` the icon of the current game is used when there is no Url or the Url fails

## pages (tabs)

```lua
local page = ui:tab("Main", { Group = "Main" })
```

| option | what it does |
| --- | --- |
| Group | pages with the same Group are under one entry of the sidebar. a group with 1 page is just a normal entry |
| Label | the name that is shown, the first argument is only the name you use in your script |
| Gate | a flag name. while that flag is off everything on the page is dimmed, except the control that has that flag |
| Meteors | true shows shooting stars behind the page |
| Late | true puts the page after the built in pages of its group, so your page can sit behind Keybinds and Config in the Settings group |

pages that are taller than the window scroll by themselves: smooth mouse wheel scrolling, a thin scrollbar on the right that gets thicker when you hover it and can be dragged. while the mouse is over the menu the wheel does not reach the game

## sections

a page can have more than one section, then they show as buttons at the top of the page

```lua
local section = page:section("SETTINGS")
local other = page:section("OTHER")
```

you can also add controls straight to the page, they go in one section named after the page

## controls

all of these work on a section and on a page. every control that saves a value needs a Flag, that is its name

options every control has

| option | what it does |
| --- | --- |
| Name | the text on the control |
| Show | a function(window) that returns true or false, false hides the control |
| Disabled | a function(window) that returns true or false, true dims it and it can not be used |
| Exempt | true means the page Gate does not dim this control |
| Save | false keeps the value out of configs |
| Bottom | true stacks the row at the bottom of the page |

toggle

```lua
section:toggle({ Name = "toggle", Flag = "Toggle", Default = false, Callback = function(value) end })
```

Bindable false removes the hotkey button (every toggle has one). Key is the key it starts with. Info = { Title = "", Lines = { "" }, Width = 280 } adds a ? button that opens a popup with those lines. Side = { Label = "...", Width = 28, Small = true, OnClick = function() end } adds your own small button on the right

slider

```lua
section:slider({ Name = "slider", Flag = "Slider", Min = 0, Max = 100, Default = 50 })
```

Float true gives 2 decimals. Step = 0.25 snaps the value to that step and the text shows the right amount of decimals. Format = function(value) return "" end changes the text of the value. Label = function(window) return "" end changes the name while it is shown. Unclamped true lets the player type a number outside Min and Max

dropdown

```lua
section:dropdown({ Name = "mode", Flag = "Mode", Values = { "a", "b" }, Default = "a" })
```

Values can also be a function that returns a list, it runs every time the dropdown opens

color

```lua
section:color({ Name = "my color", Flag = "Color", Default = Color3.new(1, 0, 0) })
```

this is a button that opens the color mixer. Default is also the color the reset button goes back to. Callback gets the color

button

```lua
section:button({ Name = "press", Callback = function(window) end })
```

Label = function(window) return "" end changes the text while it is shown. Active = function(window) return true end highlights the button like a selected page (good for buttons that switch a view). The text sits on the left like on a toggle, Align = "center" centers it. Bind = "name" adds a hotkey button that presses the button, every Bind needs its own name. Key is the key it starts with. Info and Side work like on the toggle

input

```lua
section:input({ Name = "type here", Flag = "Text", Default = "" })
```

Numeric true only lets numbers in. MaxLength is how many characters

label

```lua
section:label("some text")
section:label({ Text = "bigger text", Size = 14, Accent = true, Center = true, Height = 23 })
section:label({ Text = "Category", Size = 15, Bold = true, Height = 28 }) -- Bold draws the text in Gotham Bold, good for headings
section:label({ Label = function() return "status" end, Height = 26, Boxed = true }) -- Boxed puts the text on a thin background like the other rows
```

Label = function(window) return "" end works on labels too

pair, 2 controls in one row, 2 is the max

```lua
section:pair({ Type = "Toggle", Name = "a", Flag = "A" }, { Type = "Button", Name = "b", Callback = function() end })
```

Type can be Toggle, Slider, Button, Dropdown, Color or Input

## reading and changing values

```lua
ui:get("Toggle") -- gives the value
ui:set("Toggle", true) -- changes it and runs the Callback if the value changed
ui:flag("Hidden", 0) -- a value without a control, it saves in configs too. ui:flag(name, default, save)
```

when a config is loaded the values change without running Callbacks, so read the flags in your loop with ui:get instead of keeping your own copy

## popups

```lua
ui:popup("mypopup", {
    Width = 260,
    Height = 160,
    Title = "my popup",
    Render = function(kit, window)
        kit:switchRow("mypopup:row", 14, 50, kit.Width - 28, 36, "option", window:get("Toggle"), function()
            window:set("Toggle", not window:get("Toggle"))
        end)
        kit:closeButton("Close", function() window:closePopup() end)
    end,
})

ui:openPopup("mypopup") -- MUST match the name exactly
ui:closePopup()
ui:info("Title", { "line one", "line two" }) -- a popup with only text, no need to create it
```

Locked = true stops the player from closing the popup by clicking outside of it, only your buttons close it. Title can be a function. Render runs every frame while the popup is open and draws everything in it. the position is in popup units, 0, 0 is the top left of the popup. every key you give (the first argument) must be different, use the popup name in it. `window.Pal` has the menu colors: Main, Panel, Off, Text, Sub, Accent, AccentText, Disabled

what the kit can draw, x and y are the top left, w and h the size

| call | what it does |
| --- | --- |
| kit:text(text, x, y, size, color, center, middle, font) | text. color is a Color3, window.Pal.Text and window.Pal.Sub are the menu colors. font is a font number, leave it out for the menu font |
| kit:lines({ "a", "b" }, y, step, size) | centered lines of text, step is the gap between them |
| kit:button(key, x, y, w, h, onClick, { label = "text" }) | a button. options: label, size, rounding, active, base, textColor, hoverColor, hoverText, hoverMix, font, align. the label sits on the left when w is over 80, else centered, align = "center" or "left" picks it |
| kit:switchRow(key, x, y, w, h, label, on, onClick) | a row with a switch |
| kit:slider(key, x, y, w, h, label, fraction, shown, onDrag) | a slider. fraction is 0 to 1, shown is the text of the value, onDrag gets a fraction |
| kit:input(key, x, y, w, h, shown, onFocus) | a text box. in onFocus call window:beginInput(key, "", { numeric = true, commit = function(text) end }) |
| kit:segment(key, x, y, w, h, labels, selected, onSelect) | buttons next to each other, 1 is selected |
| kit:miniSwitch(key, x, y, on, onClick) | a small switch |
| kit:listRow(key, x, y, w, h, { title, sub, badge, badgeColor, arrow, onClick }) | a row for lists |
| kit:header(title, subtitle, onClose, onBack) | a title with a close button, gives back how far down you can start |
| kit:pager(key, x, y, w, page, maxPage, onPage) | page arrows |
| kit:scroll(key, x, y, w, h, rowHeight, count, draw, topEdge) | a list that scrolls smoothly with the wheel and has a thin draggable scrollbar. draw(index, x, y, width) draws one row. every row keeps its own boxes so nothing flickers. topEdge is optional: rows that scroll past the top fade out within that many pixels so they never cover things drawn above the list |
| kit:rect(x, y, w, h, color, alpha, rounding) | a box |
| kit:solid(x, y, w, h, color, radius, alpha) | a box with an exact corner radius |
| kit:image(url, x, y, w, h, radius, alpha) | an image, url can be a getcustomasset result or an rbxassetid link |
| kit:hit(key, x, y, w, h, onClick) | an invisible click area |
| kit:region(key, x, y, w, h, onClick, onRightClick) | an invisible click area that also reacts to the right mouse button. kit:listRow takes `onRightClick` in its options too |
| kit:line(x1, y1, x2, y2, color, thickness, alpha) | a straight line, handy for chevrons and arrows |
| kit:hovered(key) | true while the mouse is over that key |
| kit:measure(text, size) | the width of a text in popup units |
| kit:scope(key) | gives everything you draw after it its own pool of boxes. use it around things that appear and disappear (like a check mark on a tile) so other things do not flicker. kit:scope(nil) ends it |
| kit:closeButton(label, onClick) | the close button at the bottom |

## floating panels

```lua
local panel = ui:panel({
    Id = "players", Title = "Players",
    Width = 280, Height = 200, MinWidth = 220, MinHeight = 140,
    Render = function(kit, window) end, -- drawn with the same kit as popups
})
panel.toggle() -- panel.open(), panel.close(), panel.isOpen(), panel.setSize(w, h), panel.setPosition(Vector2)
```

a window the player can drag and resize. it hides with the main menu, Persistent = true keeps it on the screen while the main menu is closed

## sidebar panel

```lua
ui:sidebar({
    MinHeight = 62, -- it hides when there is less room than this
    Render = function(kit, window)
        kit:text("PLAYERS", 2, 6, 10, window.Pal.Accent, false, true)
        kit:button("mylist:1", 0, 14, kit.Width, 22, function() end, { label = "a name", size = 11 })
    end,
})
```

draws your own stuff in the sidebar between the pages and the version badge. it takes all the room that is left, so when a group of pages opens or closes it gets smaller or bigger by itself. kit.Height is how much room there is. it uses the same kit as popups and every key must be different

## welcome and update popup

```lua
Welcome = {
    Title = "Welcome to My Script",
    Heading = "here is what is new",
    Lines = { "first thing", "second thing" },
    Footer = "report issues in the discord",
    Width = 400, -- size of the card, 300 to 700 wide and 280 to 700 high, you can leave them out
    Height = 404,
},
UpdateNotice = { "V1.0.1", "fixed a bug", "added a feature" },
-- or a changelog style popup, a bold title, one "+" line for each log on the left and a closing line
UpdateNotice = { Title = "Updated to V1.0.1", Items = { "fixed a bug", "added a feature" }, Footer = "thanks for playing" },
```

put them in the options of OkloUI.new. Welcome shows when the player starts your script the first time, and grows into the menu when they press Close. UpdateNotice is a small popup that shows one time per Version, so change Version when you update. the first line is the title. leave them out and they do not show

for your own warning or first start popup use ui:popup with Locked = true, save a flag or a file when the player pressed Close and call ui:openPopup after ui:start()

## themes

every theme is in the Themes popup, the animated ones have a sky that flows with a random start and angle every time they show, some have particles. the player changes the main and accent color in Customization and it becomes Custom and saves by itself

### default theme

`Theme` is the theme the player starts with. give it the name of a built in theme

```lua
local ui = OkloUI.new({
    Title = "my script",
    Theme = "GTA VI", -- the start theme, the name must be exactly like in the list below
})
```

it is only the start, a player who picks another theme keeps it. an unknown name is ignored and the script starts with Gruvbox

`ForceTheme = "GTA VI"` puts that theme on every player one time and replaces the theme they saved. their own changes after that stay. give it another name in a later version to force again

```lua
ForceTheme = "GTA VI",
```

### all theme names

animated themes, the sky flows and has particles: Default and the ones listed in the themes popup (Midnight Galaxy, Arctic Ice, Aurora Borealis and so on)

Default is the start theme of every script

Custom is the theme of the colors the player picks in Customization, it can not be used as a start theme

### your own theme

`Theme` can also be a table, it becomes the start theme and shows in the Themes popup

```lua
Theme = {
    Name = "Cloud", -- the name in the Themes popup
    Main = Color3.fromRGB(24, 28, 35), -- background of the window
    Panel = Color3.fromRGB(37, 43, 53), -- buttons and rows
    Off = Color3.fromRGB(62, 72, 88), -- switches that are off and lines
    Text = Color3.fromRGB(226, 232, 240),
    Sub = Color3.fromRGB(148, 163, 184), -- the lighter small text
    Accent = Color3.fromRGB(125, 160, 215),
    Disabled = Color3.fromRGB(85, 96, 112), -- dimmed text, you can leave this out
    Sky = Color3.fromRGB(60, 80, 120), -- the window fades from Main to this color at the top, you can leave this out
    Light = { Main = Color3, Panel = Color3, Off = Color3, Text = Color3, Sub = Color3 }, -- the colors of light mode, you can leave this out and they are made from Main
},
```

## changing the built-in pages

call `ui:editPages` before `ui:start()` to reshape the Customization page for your script. Merge moves all rows of one section into another (Before is the name of a row to put them in front of), Rename renames sections

```lua
ui:editPages({
    Customization = {
        Merge = { { From = "EXTRAS", Into = "COLORS", Before = "Reset Settings" } },
        Rename = { COLORS = "MISC" },
    },
})
```

## the loop hook

```lua
ui:onFrame(function(frame) end)
```

runs once per frame. frame has Camera, Mouse, Viewport, Delta, Now, Visible and Canvas. use Canvas to draw in the game, the objects are pooled drawing objects and are reused every frame

| call | what it does |
| --- | --- |
| Canvas.line(from, to, color, alpha, thickness) | a line between 2 screen points (Vector2) |
| Canvas.circle(center, radius, color, alpha, thickness) | a circle outline |
| Canvas.filledCircle(center, radius, color, alpha) | a filled circle |
| Canvas.rect(position, size, color, alpha, thickness) | a box outline |
| Canvas.filledRect(position, size, color, alpha) | a filled box |
| Canvas.quad(a, b, c, d, color, alpha, thickness) | a 4 point outline |
| Canvas.filledQuad(a, b, c, d, color, alpha) | a filled 4 point shape |
| Canvas.filledTriangle(a, b, c, color, alpha) | a filled triangle |
| Canvas.text(position, size, color, alpha, text, center, font) | text with an outline |
| Canvas.label(center, size, textColor, text, background, backgroundAlpha) | text on a box |
| Canvas.glowLabel(center, size, text, fill, from, to, now) | a filled label with an outline that pulses between two colors |
| Canvas.measure(text, size) | gives a Vector2, the size of a text |
| Canvas.project(point) | gives the screen Vector2 (or nil) and the depth of a Vector3 |
| Canvas.worldBox(flat, corners, lineColor, lineAlpha, fillColor, fillAlpha, health, velocity, thickness) | a box around 8 world corners, flat true draws the 2d version |
| Canvas.worldText(point, size, color, alpha, text, font) | text at a world position |
| Canvas.worldPath(points, color, alpha, thickness) | a line through a list of Vector3 |
| Canvas.screenBox(flat, corners, ...) | the same as worldBox |

note: drawing Transparency is the opposite of what you would think in the real executor (1 is solid). the lib handles that for you, the alpha you give is 1 for solid

## other calls

```lua
ui:start() -- call this last, it adds the Customization, Keybinds and Config pages and shows the menu
ui:setVisible(false) -- hide or show the menu
ui:isVisible()
ui:setWidth(880) -- makes the window wider or narrower with a smooth animation, 360 to 1400. ui:setWidth(880, true) jumps there at once
ui:unload() -- the same as the U button
ui:destroy() -- removes the menu and everything it draws
```

## what the player gets by itself

- Customization page: scale, animation speed, corner roundness, toggle roundness, smooth pages, outline animation, transparency, light mode, accent and main color, reset, background effects (snow, rain, stars, fireflies), themes, sidebar side, 53 fonts, performance mode
- Keybinds page: the menu key and every hotkey of your toggles and buttons
- Config page: save, load, delete, auto load, and config codes to share
- typing check: hotkeys stop while the player types in a text box or the chat
- smooth scrolling and thin scrollbars on every page, the wheel never reaches the game while the mouse is over the menu
- clicks on the menu never reach the game
- buttons shrink a little while they are pressed, like toggles
- info popups (`ui:info` and the ? buttons) size themselves to their text
- R and U buttons at the top right

## helpers

the lib also gives you a few of its own modules: OkloUI.Canvas, OkloUI.Util, OkloUI.Keys, OkloUI.Color, OkloUI.Fonts and OkloUI.Storage. Fonts.find("Ubuntu") gives the number of a font by its name and Fonts.NAMES is the list. Storage reads and writes files in the workspace safely: isFile, isFolder, ensureFolder (nested paths work), read, write, delete, readJson, writeJson and list


## credits

the power and restart icons of the U and R buttons are "power-off" and "rotate-right" from Font Awesome Free (CC BY 4.0, https://fontawesome.com), the Discord icon is from simple-icons (CC0)
