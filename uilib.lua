--[[
    PrismUI v1.1 - executor single-file build
    Load from a hosted raw file:
    local Prism = loadstring(game:HttpGet("RAW_GITHUB_URL"))()
    local Window = Prism:CreateWindow({ Title = "My UI", Tags = { "BETA" } })
    local Main = Window:AddTab({ Title = "Main", Icon = "house" })
    Main:AddButton({ Title = "Hello", Callback = function() Window:Notify("Hello!") end })
]]

local Prism = (function()
    local TweenService     = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local Players          = game:GetService("Players")
    local CoreGui          = game:GetService("CoreGui")
    local HttpService      = game:GetService("HttpService")
    local RunService       = game:GetService("RunService")

    local Library = {}
    local Window, Tab = {}, {}
    Window.__index, Tab.__index = Window, Tab

    local FONT, FONT_MED, FONT_BOLD = Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold
    local TI     = TweenInfo.new(0.18, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
    local TI_POP = TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local ICONS = {
        ["code"] = "rbxassetid://107380207681249",
        ["file-cog"] = "rbxassetid://101385347151368",
        ["house"] = "rbxassetid://98755624629571",
        ["info"] = "rbxassetid://124560466474914",
        ["layout-dashboard"] = "rbxassetid://139929981863901",
        ["maximize-2"] = "rbxassetid://73085922906397",
        ["minimize-2"] = "rbxassetid://116269596042539",
        ["settings"] = "rbxassetid://80758916183665",
        ["x"] = "rbxassetid://110786993356448",
    }
    Library.Icons = ICONS

    ------------------------------------------------------------------ themes
    local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

    Library.Themes = {
        Midnight = { Background = rgb(15,17,23),  Surface = rgb(21,24,32),  Elevated = rgb(30,34,44),  Stroke = rgb(42,47,60),  Text = rgb(238,241,247), SubText = rgb(145,153,168), Accent = rgb(129,102,255) },
        Light    = { Background = rgb(244,245,249), Surface = rgb(255,255,255), Elevated = rgb(236,238,245), Stroke = rgb(214,218,232), Text = rgb(24,26,36),   SubText = rgb(110,115,135), Accent = rgb(99,102,241) },
        Rose     = { Background = rgb(20,12,16),  Surface = rgb(30,19,25),  Elevated = rgb(44,28,36),  Stroke = rgb(66,42,54),  Text = rgb(250,238,243), SubText = rgb(178,140,155), Accent = rgb(251,86,140) },
        Ocean    = { Background = rgb(9,17,26),   Surface = rgb(15,27,40),  Elevated = rgb(23,40,58),  Stroke = rgb(34,57,80),  Text = rgb(232,243,252), SubText = rgb(128,158,184), Accent = rgb(56,189,248) },
        Emerald  = { Background = rgb(10,18,15),  Surface = rgb(16,28,23),  Elevated = rgb(24,43,35),  Stroke = rgb(36,62,50),  Text = rgb(234,248,241), SubText = rgb(130,170,150), Accent = rgb(52,211,153) },
        Amber    = { Background = rgb(20,16,10),  Surface = rgb(31,25,15),  Elevated = rgb(45,37,22),  Stroke = rgb(68,56,34),  Text = rgb(252,245,232), SubText = rgb(184,166,132), Accent = rgb(251,176,52) },
        Nebula   = { Background = rgb(10,8,22),   Surface = rgb(18,14,36),  Elevated = rgb(30,22,58),  Stroke = rgb(50,38,88),  Text = rgb(240,234,255), SubText = rgb(160,148,200), Accent = rgb(186,104,255) },
        Mono     = { Background = rgb(16,16,16),  Surface = rgb(24,24,24),  Elevated = rgb(38,38,38),  Stroke = rgb(58,58,58),  Text = rgb(238,238,238), SubText = rgb(150,150,150), Accent = rgb(210,210,210) },
        Sunset   = { Background = rgb(24,12,10),  Surface = rgb(38,18,14),  Elevated = rgb(56,26,18),  Stroke = rgb(84,40,26),  Text = rgb(255,238,228), SubText = rgb(200,150,130), Accent = rgb(255,122,74) },
        Forest   = { Background = rgb(10,18,12),  Surface = rgb(16,28,18),  Elevated = rgb(24,42,26),  Stroke = rgb(40,66,42),  Text = rgb(234,248,236), SubText = rgb(140,180,144), Accent = rgb(96,200,110) },
        Blood    = { Background = rgb(18,6,8),    Surface = rgb(30,10,14),  Elevated = rgb(46,16,22),  Stroke = rgb(72,24,32),  Text = rgb(255,236,238), SubText = rgb(190,120,130), Accent = rgb(230,48,64) },
        Candy    = { Background = rgb(24,10,22),  Surface = rgb(38,16,36),  Elevated = rgb(56,24,52),  Stroke = rgb(86,40,80),  Text = rgb(255,238,252), SubText = rgb(200,150,196), Accent = rgb(255,110,220) },
    }

    ------------------------------------------------------------------ helpers
    local function New(class, props, children)
        local inst = Instance.new(class)
        local parent
        for k, v in pairs(props or {}) do
            if k == "Parent" then parent = v else inst[k] = v end
        end
        for _, c in ipairs(children or {}) do c.Parent = inst end
        inst.Parent = parent
        return inst
    end

    local function tween(inst, props, info) TweenService:Create(inst, info or TI, props):Play() end

    local function safe(fn, ...)
        if type(fn) ~= "function" then return end
        local ok, err = pcall(fn, ...)
        if not ok then warn("[PrismUI] callback error: " .. tostring(err)) end
    end

    local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
    local function isMove(i)  return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch end

    local function pad(parent, t, r, b, l)
        return New("UIPadding", {
            Parent = parent,
            PaddingTop    = UDim.new(0, t),
            PaddingRight  = UDim.new(0, r or t),
            PaddingBottom = UDim.new(0, b or t),
            PaddingLeft   = UDim.new(0, l or r or t),
        })
    end

    local function formatNumber(v)
        if type(v) ~= "number" then return tostring(v) end
        if v == math.floor(v) then return tostring(math.floor(v)) end
        return string.format("%.2f", v)
    end

    local function resolveIcon(icon)
        if type(icon) == "number" then return "rbxassetid://" .. tostring(icon) end
        if type(icon) ~= "string" then return nil end
        if icon:match("^rbxassetid://%d+$") then return icon end
        if icon:match("^%d+$") then return "rbxassetid://" .. icon end
        return ICONS[icon:lower()]
    end

    local function hexToColor3(hex)
        hex = hex:gsub("#", "")
        local r = tonumber(hex:sub(1,2), 16) or 0
        local g = tonumber(hex:sub(3,4), 16) or 0
        local b = tonumber(hex:sub(5,6), 16) or 0
        return Color3.fromRGB(r, g, b)
    end

    local function color3ToHex(c)
        return string.format("#%02X%02X%02X", math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5))
    end

    ------------------------------------------------------------------ window internals
    function Window:_buildTheme()
        local t = table.clone(type(self._themeName) == "table" and self._themeName or Library.Themes[self._themeName] or Library.Themes.Midnight)
        for k, v in pairs(Library.Themes.Midnight) do if t[k] == nil then t[k] = v end end
        if self._accent then t.Accent = self._accent end
        local a = t.Accent
        t.AccentText = (0.299 * a.R + 0.587 * a.G + 0.114 * a.B) > 0.62 and rgb(15,15,20) or Color3.new(1,1,1)
        self.Theme = t
    end

    function Window:_onTheme(inst, fn)
        table.insert(self._painters, { inst = inst, fn = fn })
        fn()
    end

    function Window:_bind(inst, prop, key)
        self:_onTheme(inst, function() inst[prop] = self.Theme[key] end)
    end

    function Window:_refresh()
        for i = #self._painters, 1, -1 do
            local p = self._painters[i]
            if p.inst.Parent == nil then table.remove(self._painters, i) else pcall(p.fn) end
        end
    end

    function Window:_applyCorner(e)
        local r = self.CornerRadius
        if e.scale == "pill" then
            e.corner.CornerRadius = r <= 0 and UDim.new(0, 0) or UDim.new(1, 0)
        else
            e.corner.CornerRadius = UDim.new(0, math.floor(r * e.scale + 0.5))
        end
    end

    function Window:_corner(parent, scale)
        local c = New("UICorner", { Parent = parent })
        local e = { corner = c, scale = scale }
        table.insert(self._corners, e)
        self:_applyCorner(e)
        return c
    end

    function Window:_stroke(parent, key, thickness)
        local s = New("UIStroke", { Parent = parent, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
        self:_bind(s, "Color", key or "Stroke")
        return s
    end

    function Window:_text(parent, text, size, font, key)
        local l = New("TextLabel", {
            Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, size + 2),
            AutomaticSize = Enum.AutomaticSize.Y, Text = text or "", TextSize = size, Font = font,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        })
        self:_bind(l, "TextColor3", key)
        return l
    end

    function Window:_connect(signal, fn) table.insert(self._conns, signal:Connect(fn)) end

    ------------------------------------------------------------------ public window API
    function Window:SetTheme(theme) self._themeName = theme; self:_buildTheme(); self:_refresh() end
    function Window:SetAccent(color) self._accent = color; self:_buildTheme(); self:_refresh() end
    function Window:GetTheme() return self.Theme end

    function Window:SetCornerRadius(r)
        self.CornerRadius = math.clamp(r, 0, 28)
        for i = #self._corners, 1, -1 do
            local e = self._corners[i]
            if e.corner.Parent == nil then table.remove(self._corners, i) else self:_applyCorner(e) end
        end
    end

    function Window:Toggle(state)
        if state == nil then state = not self.Holder.Visible end
        self._visibilityToken = (self._visibilityToken or 0) + 1
        local token = self._visibilityToken
        if state then
            self.Holder.Visible = true
            self._scale.Scale = 0.94
            tween(self._scale, { Scale = 1 }, TI_POP)
        else
            tween(self._scale, { Scale = 0.94 }, TI)
            task.delay(0.18, function()
                if self._visibilityToken == token and not state and self.Holder.Parent then
                    self.Holder.Visible = false
                end
            end)
        end
    end

    function Window:Center()
        tween(self.Holder, { Position = UDim2.fromScale(0.5, 0.5) }, TI_POP)
    end

    function Window:SetSize(size)
        self._size = size
        if not self._minimized then
            tween(self.Holder, { Size = UDim2.fromOffset(size.X, size.Y) }, TI_POP)
        end
    end

    function Window:SetMinimized(state)
        if state == nil then state = not self._minimized end
        self._minimized = state
        self._minIcon.Image = resolveIcon(state and "maximize-2" or "minimize-2")
        if state then
            self._minimizeToken = (self._minimizeToken or 0) + 1
            local token = self._minimizeToken
            tween(self.Holder, { Size = UDim2.fromOffset(300, 72) }, TI_POP)
            task.delay(0.28, function()
                if token == self._minimizeToken and self._minimized then
                    self._body.Visible = false
                end
            end)
        else
            self._minimizeToken = (self._minimizeToken or 0) + 1
            self._body.Visible = true
            tween(self.Holder, { Size = UDim2.fromOffset(self._size.X, self._size.Y) }, TI_POP)
        end
    end

    function Window:SetToggleKey(key) self.ToggleKey = key end
    function Window:GetToggleKey() return self.ToggleKey end

    function Window:SetWatermark(text)
        if self._watermark then self._watermark:Destroy(); self._watermark = nil end
        if not text then return end
        local w = New("TextLabel", {
            Parent = self.Gui, Text = text, Font = FONT_MED, TextSize = 13,
            BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 12), Size = UDim2.fromOffset(0, 20),
            AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left,
        })
        self:_bind(w, "TextColor3", "SubText")
        self:_bind(w, "TextStrokeColor3", "Background")
        w.TextStrokeTransparency = 0.6
        self._watermark = w
    end

    function Window:Destroy()
        for _, c in ipairs(self._conns) do c:Disconnect() end
        self.Gui:Destroy()
    end

    function Window:SelectTab(tab)
        if self.ActiveTab == tab then
            tab.Page.Visible = true
            tab.Page.Position = UDim2.new(0, 0, 0, 0)
            tab._paint()
            return
        end
        self.ActiveTab = tab
        for _, t in ipairs(self.Tabs) do
            if t == tab then
                t.Page.Visible = true
                t.Page.Position = UDim2.new(0, 10, 0, 0)
                tween(t.Page, { Position = UDim2.new(0, 0, 0, 0) }, TI_POP)
            else
                t.Page.Visible = false
                t.Page.Position = UDim2.new(0, 0, 0, 0)
            end
            t._paint()
        end
    end

    function Window:Notify(cfg)
        if type(cfg) == "string" then cfg = { Content = cfg } end
        cfg = cfg or {}
        self._notifId += 1
        local wrap = New("Frame", { Parent = self._notifs, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self._notifId })
        local card = New("Frame", { Parent = wrap, Position = UDim2.fromOffset(310, 0), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 })
        self:_bind(card, "BackgroundColor3", "Surface")
        self:_corner(card, 0.35)
        pad(card, 10, 12)
        New("UIListLayout", { Parent = card, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })
        local title = self:_text(card, cfg.Title or "Notice", 13, FONT_BOLD, "Text")
        title.LayoutOrder = 1
        pad(title, 0, 0, 0, 8)
        local stripe = New("Frame", { Parent = title, Position = UDim2.new(0, -8, 0, 1), Size = UDim2.new(0, 3, 0, 14), BorderSizePixel = 0 })
        self:_corner(stripe, "pill")
        self:_bind(stripe, "BackgroundColor3", "Accent")
        if cfg.Content then
            local content = self:_text(card, cfg.Content, 12, FONT, "SubText")
            content.LayoutOrder = 2
        end
        local duration = math.max(0.5, tonumber(cfg.Duration) or 4)
        card.BackgroundTransparency = 1
        tween(card, { Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 0 }, TI_POP)
        task.delay(duration, function()
            if card.Parent then
                tween(card, { Position = UDim2.fromOffset(310, 0), BackgroundTransparency = 1 }, TI)
                task.wait(0.2)
            end
            if wrap.Parent then wrap:Destroy() end
        end)
    end

    function Window:AddTab(cfg)
        if type(cfg) == "string" then cfg = { Title = cfg } end
        local tab = setmetatable({ Window = self, Title = cfg.Title, _order = 0, _columns = nil }, Tab)

        self._navOrder = (self._navOrder or 0) + 1
        local btn = New("TextButton", { Parent = self._tabList, Size = UDim2.new(1, 0, 0, 32), Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = self._navOrder })
        self:_corner(btn, 0.5)
        local iconImage = resolveIcon(cfg.Icon)
        local textX = iconImage and 36 or 16
        local label = New("TextLabel", {
            Parent = btn, BackgroundTransparency = 1, Position = UDim2.fromOffset(textX, 0), Size = UDim2.new(1, -(textX + 6), 1, 0),
            Text = cfg.Title or "Tab", Font = FONT_MED, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        })
        local icon
        if iconImage then
            icon = New("ImageLabel", {
                Parent = btn, BackgroundTransparency = 1, Image = iconImage,
                Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 14, 0.5, 0),
            })
        end
        local bar = New("Frame", { Parent = btn, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(2, 14), BorderSizePixel = 0 })
        self:_corner(bar, "pill")
        self:_bind(bar, "BackgroundColor3", "Accent")

        tab._paint = function()
            local active = self.ActiveTab == tab
            local th = self.Theme
            tween(btn, {
                BackgroundColor3 = active and th.Elevated or th.Surface,
                BackgroundTransparency = active and 0 or 1,
            }, TI)
            tween(label, { TextColor3 = active and th.Text or th.SubText }, TI)
            if icon then tween(icon, { ImageColor3 = active and th.Accent or th.SubText }, TI) end
            bar.Visible = active
        end
        self:_onTheme(btn, tab._paint)

        btn.MouseEnter:Connect(function()
            if self.ActiveTab ~= tab then btn.BackgroundColor3 = self.Theme.Elevated; tween(btn, { BackgroundTransparency = 0.5 }) end
        end)
        btn.MouseLeave:Connect(function()
            if self.ActiveTab ~= tab then tween(btn, { BackgroundTransparency = 1 }) end
        end)
        btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)

        local page = New("ScrollingFrame", {
            Parent = self._pages, Visible = false, Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
        })
        self:_bind(page, "ScrollBarImageColor3", "Stroke")
        pad(page, 2, 6, 2, 2)
        New("UIListLayout", { Parent = page, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
        tab.Page = page

        table.insert(self.Tabs, tab)
        if #self.Tabs == 1 then self:SelectTab(tab) end
        return tab
    end

    function Window:AddTabGroup(title)
        self._navOrder = (self._navOrder or 0) + 1
        local label = self:_text(self._tabList, string.upper(tostring(title or "GROUP")), 9, FONT_BOLD, "SubText")
        label.Size = UDim2.new(1, 0, 0, 16)
        label.LayoutOrder = self._navOrder
        pad(label, 8, 0, 0, 8)
        self._navOrder += 1
        return label
    end

    function Window:AddAppearanceTab(title)
        local tab = self:AddTab({ Title = title or "Appearance", Icon = "settings" })
        local names = {}
        for n in pairs(Library.Themes) do table.insert(names, n) end
        table.sort(names)

        local accents = {
            ["Theme default"] = false, Violet = rgb(129,102,255), Rose = rgb(251,86,140), Sky = rgb(56,189,248),
            Emerald = rgb(52,211,153), Amber = rgb(251,176,52), Crimson = rgb(239,68,68), Candy = rgb(255,110,220),
        }
        local accentNames = {}
        for n in pairs(accents) do table.insert(accentNames, n) end
        table.sort(accentNames)

        tab:AddSection("Theme")
        tab:AddDropdown({ Title = "Theme", Values = names, Default = type(self._themeName) == "string" and self._themeName or "Midnight", Callback = function(v) self:SetTheme(v) end })
        tab:AddDropdown({ Title = "Accent colour", Values = accentNames, Default = "Theme default", Callback = function(v) self:SetAccent(accents[v] or nil) end })
        tab:AddColorPicker({ Title = "Custom accent", Default = self.Theme.Accent, Callback = function(c) self:SetAccent(c) end })
        tab:AddSection("Shape")
        tab:AddSlider({ Title = "Corner radius", Description = "0 = sharp - 28 = very round", Min = 0, Max = 28, Default = self.CornerRadius, Suffix = "px", Callback = function(v) self:SetCornerRadius(v) end })
        tab:AddSection("Window")
        tab:AddKeybind({ Title = "Toggle key", Default = self.ToggleKey, Changed = function(k) self.ToggleKey = k end })
        tab:AddToggle({ Title = "Start minimized", Default = false, Callback = function(on) self:SetMinimized(on) end })
        tab:AddButton({ Title = "Recenter window", Callback = function() self:Center() end })
        return tab
    end

    ------------------------------------------------------------------ elements
    function Tab:_next() self._order += 1; return self._order end

    function Tab:_registerState(cfg, widget)
        if type(widget) ~= "table" or type(widget.Get) ~= "function" or type(widget.Set) ~= "function" then
            return widget
        end
        local enumType
        local function findEnumType(value)
            if typeof(value) == "EnumItem" then return value.EnumType end
            if type(value) == "table" then
                for _, item in pairs(value) do
                    local found = findEnumType(item)
                    if found then return found end
                end
            end
            return nil
        end
        enumType = findEnumType(cfg.Default) or findEnumType(cfg.Values)
        widget._configEnumType = enumType
        local name = cfg.ConfigKey or cfg.Title or cfg.Text or ("Setting" .. tostring(#self.Window._stateWidgets + 1))
        local baseKey = tostring(self.Title or "Tab") .. "/" .. tostring(name)
        local key = baseKey
        local suffix = 2
        while self.Window._stateWidgets[key] do
            key = baseKey .. " (" .. suffix .. ")"
            suffix += 1
        end
        self.Window._stateWidgets[key] = widget
        return widget
    end

    function Tab:Clear()
        for _, c in ipairs(self.Page:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
        end
        self._order = 0
    end

    function Tab:AddColumns(n, gap)
        n = math.max(1, math.floor(tonumber(n) or 1))
        gap = math.max(0, tonumber(gap) or 10)
        local frame = New("Frame", { Parent = self.Page, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self:_next() })
        New("UIListLayout", { Parent = frame, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder })
        local cols = {}
        for i = 1, n do
            local columnOffset = -(gap * (n - 1) / n)
            local col = New("Frame", {
                Parent = frame, BackgroundTransparency = 1,
                Size = UDim2.new(1 / n, columnOffset, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i,
            })
            New("UIListLayout", { Parent = col, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
            table.insert(cols, col)
        end
        return cols
    end

    function Tab:_card(cfg, ctrlW, class, parent)
        local w = self.Window
        parent = parent or self.Page
        local card = New(class or "Frame", { Parent = parent, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = self:_next() })
        if class == "TextButton" then card.Text = ""; card.AutoButtonColor = false end
        w:_bind(card, "BackgroundColor3", "Surface")
        w:_corner(card, 0.35)
        pad(card, 11, 12)
        New("UIListLayout", { Parent = card, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder })

        local header = New("Frame", { Name = "Header", Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 })
        local texts = New("Frame", { Parent = header, BackgroundTransparency = 1, Size = UDim2.new(1, ctrlW > 0 and -(ctrlW + 10) or 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
        New("UIListLayout", { Parent = texts, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
        local hasDesc = cfg.Description and cfg.Description ~= ""
        if not hasDesc then pad(texts, 3, 0, 0, 0) end
        w:_text(texts, cfg.Title or cfg.Text or "", 14, FONT_MED, "Text").LayoutOrder = 1
        if hasDesc then w:_text(texts, cfg.Description, 12, FONT, "SubText").LayoutOrder = 2 end
        return card, header, texts
    end

    function Tab:_hover(card)
        local w = self.Window
        local hovered = false
        card.MouseEnter:Connect(function()
            hovered = true
            tween(card, { BackgroundColor3 = w.Theme.Elevated }, TI)
        end)
        card.MouseLeave:Connect(function()
            hovered = false
            tween(card, { BackgroundColor3 = w.Theme.Surface }, TI)
        end)
        card.InputBegan:Connect(function(input)
            if isPress(input) then
                tween(card, { BackgroundColor3 = w.Theme.Elevated }, TweenInfo.new(0.07))
            end
        end)
        card.InputEnded:Connect(function(input)
            if isPress(input) then
                tween(card, { BackgroundColor3 = hovered and w.Theme.Elevated or w.Theme.Surface }, TI)
            end
        end)
    end

    local function rightAnchored(props)
        props.AnchorPoint = Vector2.new(1, 0.5)
        props.Position = UDim2.new(1, 0, 0.5, 0)
        props.BorderSizePixel = 0
        return props
    end

    function Tab:AddSection(name)
        local l = self.Window:_text(self.Page, string.upper(name), 10, FONT_BOLD, "SubText")
        l.LayoutOrder = self:_next()
        pad(l, 6, 0, 0, 4)
        return l
    end

    function Tab:AddDivider()
        local f = New("Frame", { Parent = self.Page, Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, LayoutOrder = self:_next() })
        self.Window:_bind(f, "BackgroundColor3", "Stroke")
        return f
    end

    function Tab:AddSpacer(px)
        local f = New("Frame", { Parent = self.Page, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, px or 8), LayoutOrder = self:_next() })
        return f
    end

    function Tab:AddLabel(text) self:_card({ Title = text }, 0) end
    function Tab:AddParagraph(cfg)
        local card, _, texts = self:_card(cfg, 0)
        local description
        for _, child in ipairs(texts:GetChildren()) do
            if child:IsA("TextLabel") and child.LayoutOrder == 2 then
                description = child
                break
            end
        end
        local title
        for _, child in ipairs(texts:GetChildren()) do
            if child:IsA("TextLabel") and child.LayoutOrder == 1 then
                title = child
                break
            end
        end
        return {
            Set = function(_, text)
                local label = description or title
                if label then label.Text = tostring(text) end
            end,
            Get = function()
                local label = description or title
                return label and label.Text or ""
            end,
            Destroy = function() card:Destroy() end,
        }
    end

    function Tab:AddButton(cfg)
        local card, header = self:_card(cfg, 20, "TextButton")
        self:_hover(card)
        local chev = New("TextLabel", rightAnchored({ Parent = header, Size = UDim2.fromOffset(16, 20), BackgroundTransparency = 1, Text = "›", Font = FONT_BOLD, TextSize = 22 }))
        self.Window:_bind(chev, "TextColor3", "Accent")
        card.MouseButton1Click:Connect(function()
            tween(chev, { Position = UDim2.new(1, 4, 0.5, 0) }, TweenInfo.new(0.08))
            task.delay(0.1, function() tween(chev, { Position = UDim2.new(1, 0, 0.5, 0) }) end)
            safe(cfg.Callback)
        end)
        return { Fire = function() safe(cfg.Callback) end }
    end

    function Tab:AddToggle(cfg)
        local w = self.Window
        local card, header = self:_card(cfg, 44, "TextButton")
        self:_hover(card)
        local track = New("Frame", rightAnchored({ Parent = header, Size = UDim2.fromOffset(40, 22) }))
        w:_corner(track, "pill")
        local thumb = New("Frame", { Parent = track, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0 })
        w:_corner(thumb, "pill")

        local obj = { Value = cfg.Default == true }
        local function paint(animate)
            local th, on = w.Theme, obj.Value
            local goals = {
                { track, { BackgroundColor3 = on and th.Accent or th.Stroke } },
                { thumb, { BackgroundColor3 = on and th.AccentText or th.SubText, Position = on and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) } },
            }
            for _, g in ipairs(goals) do
                if animate then tween(g[1], g[2]) else for k, v in pairs(g[2]) do g[1][k] = v end end
            end
        end
        w:_onTheme(track, function() paint(false) end)

        function obj:Set(v, silent) obj.Value = v and true or false; paint(true); if not silent then safe(cfg.Callback, obj.Value) end end
        function obj:Get() return obj.Value end
        function obj:Toggle() obj:Set(not obj.Value) end
        card.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
        if cfg.CallOnInit then safe(cfg.Callback, obj.Value) end
        return self:_registerState(cfg, obj)
    end

    function Tab:AddSlider(cfg)
        local w = self.Window
        local min, max, inc = cfg.Min or 0, cfg.Max or 100, cfg.Increment or 1
        local card, header = self:_card(cfg, 64)
        local valueLabel = New("TextLabel", rightAnchored({ Parent = header, Size = UDim2.fromOffset(64, 20), BackgroundTransparency = 1, Font = FONT_MED, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right }))
        w:_bind(valueLabel, "TextColor3", "Accent")

        local hit = New("TextButton", { Parent = card, Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 2 })
        local bar  = New("Frame", { Parent = hit, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 6), BorderSizePixel = 0 })
        w:_corner(bar, "pill"); w:_bind(bar, "BackgroundColor3", "Elevated")
        local fill = New("Frame", { Parent = bar, Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 })
        w:_corner(fill, "pill"); w:_bind(fill, "BackgroundColor3", "Accent")
        local knob = New("Frame", { Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 0, 0.5, 0), BorderSizePixel = 0 })
        w:_corner(knob, "pill"); w:_bind(knob, "BackgroundColor3", "Text")
        w:_stroke(knob, "Accent", 2)

        local obj = { Value = min }
        local function set(v, silent)
            v = math.clamp(min + math.floor((v - min) / inc + 0.5) * inc, min, max)
            v = tonumber(string.format("%.4f", v))
            obj.Value = v
            local a = max == min and 0 or (v - min) / (max - min)
            fill.Size = UDim2.new(a, 0, 1, 0)
            knob.Position = UDim2.new(a, 0, 0.5, 0)
            valueLabel.Text = formatNumber(v) .. (cfg.Suffix or "")
            if not silent then safe(cfg.Callback, v) end
        end
        local function fromX(x) set(min + (max - min) * math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)) end

        local dragging = false
        hit.InputBegan:Connect(function(i) if isPress(i) then dragging = true; fromX(i.Position.X) end end)
        w:_connect(UserInputService.InputChanged, function(i) if dragging and isMove(i) then fromX(i.Position.X) end end)
        w:_connect(UserInputService.InputEnded, function(i) if isPress(i) then dragging = false end end)

        set(cfg.Default or min, not cfg.CallOnInit)
        function obj:Set(v) set(v) end
        function obj:Get() return obj.Value end
        return self:_registerState(cfg, obj)
    end

    function Tab:AddDropdown(cfg)
        local w = self.Window
        local card, header = self:_card(cfg, 140)
        local multi, values = cfg.Multi == true, cfg.Values or {}
        local selected, value = {}, nil
        if multi then for _, v in ipairs(cfg.Default or {}) do selected[v] = true end else value = cfg.Default end

        local box = New("TextButton", rightAnchored({ Parent = header, Size = UDim2.fromOffset(130, 26), Text = "", AutoButtonColor = false }))
        w:_corner(box, 0.45); w:_bind(box, "BackgroundColor3", "Elevated")
        local boxLabel = New("TextLabel", { Parent = box, BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -26, 1, 0), Font = FONT_MED, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
        w:_bind(boxLabel, "TextColor3", "Text")
        local arrow = New("TextLabel", { Parent = box, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(14, 16), Text = "v", Font = FONT_BOLD, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
        w:_bind(arrow, "TextColor3", "SubText")

        local list = New("ScrollingFrame", { Parent = card, Visible = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, LayoutOrder = 2 })
        w:_bind(list, "ScrollBarImageColor3", "Stroke")
        New("UIListLayout", { Parent = list, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })

        local obj, painters = {}, {}
        local function display()
            if multi then
                local t = {}
                for _, v in ipairs(values) do if selected[v] then table.insert(t, tostring(v)) end end
                boxLabel.Text = #t == 0 and "None" or table.concat(t, ", ")
            else
                boxLabel.Text = value ~= nil and tostring(value) or "Select"
            end
        end
        local function repaint() for _, p in ipairs(painters) do p() end end
        function obj:Get()
            if not multi then return value end
            local t = {}
            for _, v in ipairs(values) do if selected[v] then table.insert(t, v) end end
            return t
        end
        local openToken = 0
        local function setOpen(open)
            openToken += 1
            local token = openToken
            tween(arrow, { Rotation = open and 180 or 0 }, TI)
            if open then
                list.Visible = true
                tween(list, { Size = UDim2.new(1, 0, 0, math.min(#values * 32, 140)) }, TI)
            else
                tween(list, { Size = UDim2.new(1, 0, 0, 0) }, TI)
                task.delay(0.18, function()
                    if token == openToken and list.Parent then list.Visible = false end
                end)
            end
        end
        local function choose(val, silent)
            if multi then selected[val] = not selected[val] or nil else value = val; setOpen(false) end
            display(); repaint()
            if not silent then safe(cfg.Callback, obj:Get()) end
        end
        local function rebuild()
            for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            painters = {}
            for i, val in ipairs(values) do
                local b = New("TextButton", { Parent = list, Size = UDim2.new(1, -6, 0, 28), Text = tostring(val), Font = FONT_MED, TextSize = 13, AutoButtonColor = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i })
                pad(b, 0, 10, 0, 10)
                w:_corner(b, 0.4)
                local function paint()
                    local sel = multi and selected[val] or (not multi and value == val)
                    tween(b, { BackgroundColor3 = sel and w.Theme.Elevated or w.Theme.Surface }, TI)
                    tween(b, { TextColor3 = sel and w.Theme.Accent or w.Theme.Text }, TI)
                end
                table.insert(painters, paint)
                w:_onTheme(b, paint)
                b.MouseEnter:Connect(function()
                    if not (multi and selected[val] or (not multi and value == val)) then
                        tween(b, { BackgroundColor3 = w.Theme.Elevated }, TI)
                    end
                end)
                b.MouseLeave:Connect(function() paint() end)
                b.MouseButton1Click:Connect(function() choose(val) end)
            end
            if list.Visible then
                tween(list, { Size = UDim2.new(1, 0, 0, math.min(#values * 32, 140)) }, TI)
            else
                list.Size = UDim2.new(1, 0, 0, 0)
            end
            display()
        end
        function obj:SetValues(v) values = v; rebuild() end
        function obj:Set(v)
            if multi then
                selected = {}
                if type(v) == "table" then
                    for _, x in ipairs(v) do selected[x] = true end
                end
            else
                value = v
            end
            display(); repaint(); safe(cfg.Callback, obj:Get())
        end
        box.MouseButton1Click:Connect(function() setOpen(not list.Visible) end)
        rebuild()
        return self:_registerState(cfg, obj)
    end

    function Tab:AddInput(cfg)
        local w = self.Window
        local _, header = self:_card(cfg, 150)
        local box = New("TextBox", rightAnchored({
            Parent = header, Size = UDim2.fromOffset(140, 26), Text = cfg.Default or "", PlaceholderText = cfg.Placeholder or "Type here...",
            Font = FONT, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = cfg.ClearOnFocus == true, ClipsDescendants = true,
        }))
        pad(box, 0, 9, 0, 9)
        w:_corner(box, 0.45)
        w:_bind(box, "BackgroundColor3", "Elevated")
        w:_bind(box, "TextColor3", "Text")
        w:_bind(box, "PlaceholderColor3", "SubText")
        local st = w:_stroke(box, "Accent"); st.Transparency = 1
        box.Focused:Connect(function() tween(st, { Transparency = 0 }) end)
        box.FocusLost:Connect(function(enter) tween(st, { Transparency = 1 }); safe(cfg.Callback, box.Text, enter) end)
        local obj = {
            Get = function() return box.Text end,
            Set = function(_, t)
                box.Text = tostring(t or "")
                safe(cfg.Callback, box.Text, false)
            end,
        }
        return self:_registerState(cfg, obj)
    end

    function Tab:AddTextArea(cfg)
        local w = self.Window
        local card = self:_card(cfg, 0)
        local box = New("TextBox", {
            Parent = card, Size = UDim2.new(1, 0, 0, cfg.Height or 90), Text = cfg.Default or "",
            PlaceholderText = cfg.Placeholder or "Write something...", Font = FONT, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            ClearTextOnFocus = false, MultiLine = true, LayoutOrder = 2, ClipsDescendants = true,
        })
        pad(box, 8, 10, 8, 10)
        w:_corner(box, 0.35)
        w:_bind(box, "BackgroundColor3", "Elevated")
        w:_bind(box, "TextColor3", "Text")
        w:_bind(box, "PlaceholderColor3", "SubText")
        local st = w:_stroke(box, "Stroke")
        box.Focused:Connect(function() tween(st, { Color = w.Theme.Accent }) end)
        box.FocusLost:Connect(function(enter) tween(st, { Color = w.Theme.Stroke }); safe(cfg.Callback, box.Text, enter) end)
        local obj = {
            Get = function() return box.Text end,
            Set = function(_, t)
                box.Text = tostring(t or "")
                safe(cfg.Callback, box.Text, false)
            end,
        }
        return self:_registerState(cfg, obj)
    end

    function Tab:AddKeybind(cfg)
        local w = self.Window
        local _, header = self:_card(cfg, 90)
        local key, listening = cfg.Default or Enum.KeyCode.Unknown, false
        local btn = New("TextButton", rightAnchored({ Parent = header, Size = UDim2.fromOffset(80, 26), Text = key.Name, Font = FONT_MED, TextSize = 12, AutoButtonColor = false }))
        w:_corner(btn, 0.45)
        w:_bind(btn, "BackgroundColor3", "Elevated")
        w:_bind(btn, "TextColor3", "Accent")
        btn.MouseButton1Click:Connect(function() listening = true; w._rebinding = true; btn.Text = "..." end)
        w:_connect(UserInputService.InputBegan, function(input, gpe)
            if listening then
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    listening = false
                    task.defer(function() w._rebinding = false end)
                    if input.KeyCode ~= Enum.KeyCode.Escape then key = input.KeyCode; safe(cfg.Changed, key) end
                    btn.Text = key.Name
                end
            elseif not gpe and key ~= Enum.KeyCode.Unknown and input.KeyCode == key then
                safe(cfg.Callback, key)
            end
        end)
        return self:_registerState(cfg, {
            Get = function() return key end,
            Set = function(_, k)
                key = k
                btn.Text = k.Name
                safe(cfg.Changed, k)
            end,
        })
    end

    function Tab:AddColorPicker(cfg)
        local w = self.Window
        local card, header = self:_card(cfg, 44)
        local current = cfg.Default or Color3.fromRGB(129, 102, 255)
        local swatch = New("TextButton", rightAnchored({ Parent = header, Size = UDim2.fromOffset(40, 24), Text = "", AutoButtonColor = false }))
        w:_corner(swatch, 0.4)
        w:_bind(swatch, "BackgroundColor3", "Elevated")
        local fill = New("Frame", { Parent = swatch, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 })
        w:_corner(fill, 0.4)
        local swStroke = New("UIStroke", { Parent = swatch, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
        w:_bind(swStroke, "Color", "Stroke")

        local picker = New("Frame", { Parent = card, Visible = false, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, BackgroundTransparency = 1 })
        New("UIListLayout", { Parent = picker, Padding = UDim.new(0, 6) })

        local hexBox = New("TextBox", { Parent = picker, Size = UDim2.new(1, 0, 0, 26), Text = color3ToHex(current), Font = FONT_MED, TextSize = 12, ClearTextOnFocus = false, LayoutOrder = 1 })
        pad(hexBox, 0, 9, 0, 9)
        w:_corner(hexBox, 0.4)
        w:_bind(hexBox, "BackgroundColor3", "Elevated")
        w:_bind(hexBox, "TextColor3", "Text")

        local function makeBar(label, init, color)
            local row = New("Frame", { Parent = picker, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = #picker:GetChildren() + 1 })
            local lbl = New("TextLabel", { Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0, 18, 1, 0), Text = label, Font = FONT_BOLD, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left })
            w:_bind(lbl, "TextColor3", "SubText")

            local hit = New("TextButton", { Parent = row, Text = "", BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 2), Size = UDim2.new(1, -24, 0, 12), AutoButtonColor = false })
            local bar = New("Frame", { Parent = hit, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0) })
            w:_corner(bar, "pill")
            w:_bind(bar, "BackgroundColor3", "Elevated")

            local f = New("Frame", { Parent = bar, BorderSizePixel = 0, Size = UDim2.new(init, 0, 1, 0) })
            w:_corner(f, "pill")
            f.BackgroundColor3 = color or Color3.new(1, 1, 1)

            return f, hit, bar
        end

        local rFill, rHit, rBar = makeBar("R", current.R, Color3.fromRGB(255, 0, 0))
        local gFill, gHit, gBar = makeBar("G", current.G, Color3.fromRGB(0, 255, 0))
        local bFill, bHit, bBar = makeBar("B", current.B, Color3.fromRGB(0, 0, 255))

        local function update(v)
            current = v
            fill.BackgroundColor3 = current
            hexBox.Text = color3ToHex(current)
            rFill.Size = UDim2.new(current.R, 0, 1, 0)
            gFill.Size = UDim2.new(current.G, 0, 1, 0)
            bFill.Size = UDim2.new(current.B, 0, 1, 0)
        end

        local function push()
            safe(cfg.Callback, current)
        end

        local function track(fillF, hitF, barF, chan)
            local drag = false
            hitF.InputBegan:Connect(function(i)
                if isPress(i) then drag = true end
            end)
            w:_connect(UserInputService.InputChanged, function(i)
                if drag and isMove(i) then
                    local a = math.clamp((i.Position.X - barF.AbsolutePosition.X) / math.max(barF.AbsoluteSize.X, 1), 0, 1)
                    fillF.Size = UDim2.new(a, 0, 1, 0)
                    local c = Color3.new(
                        chan == "R" and a or current.R,
                        chan == "G" and a or current.G,
                        chan == "B" and a or current.B
                    )
                    update(c)
                end
            end)
            w:_connect(UserInputService.InputEnded, function(i)
                if isPress(i) then
                    if drag then push() end
                    drag = false
                end
            end)
        end

        track(rFill, rHit, rBar, "R")
        track(gFill, gHit, gBar, "G")
        track(bFill, bHit, bBar, "B")

        hexBox.FocusLost:Connect(function()
            local ok, c = pcall(hexToColor3, hexBox.Text)
            if ok and c then update(c); push() end
        end)

        swatch.MouseButton1Click:Connect(function()
            picker.Visible = not picker.Visible
        end)

        update(current)
        return self:_registerState(cfg, {
            Get = function() return current end,
            Set = function(_, c) update(c); push() end,
        })
    end

    function Tab:AddProgressBar(cfg)
        local w = self.Window
        local card, header = self:_card(cfg, 60)
        local val = cfg.Default or 0
        local pct = New("TextLabel", rightAnchored({ Parent = header, Size = UDim2.fromOffset(60, 20), BackgroundTransparency = 1, Font = FONT_MED, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right }))
        w:_bind(pct, "TextColor3", "Accent")
        local bar = New("Frame", { Parent = card, Size = UDim2.new(1, 0, 0, 8), BorderSizePixel = 0, LayoutOrder = 2 })
        w:_corner(bar, "pill"); w:_bind(bar, "BackgroundColor3", "Elevated")
        local fill = New("Frame", { Parent = bar, Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 })
        w:_corner(fill, "pill"); w:_bind(fill, "BackgroundColor3", "Accent")
        local obj = {}
        local function apply(v, animate)
            v = math.clamp(v, 0, 1)
            val = v
            local goal = { Size = UDim2.new(v, 0, 1, 0) }
            if animate then tween(fill, goal) else fill.Size = goal.Size end
            pct.Text = string.format("%d%%", math.floor(v * 100 + 0.5))
        end
        apply(val, false)
        function obj:Set(v) apply(v, true) end
        function obj:Get() return val end
        return self:_registerState(cfg, obj)
    end

    function Tab:AddRadioGroup(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description }, 0)
        local group = {}
        local selected = cfg.Default
        local buttons = {}
        local list = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
        New("UIListLayout", { Parent = list, Padding = UDim.new(0, 4) })
        local function repaint()
            for value, b in pairs(buttons) do
                local isSel = value == selected
                b.dot.BackgroundColor3 = isSel and w.Theme.Accent or w.Theme.Stroke
                b.dotInner.Visible = isSel
                b.label.TextColor3 = isSel and w.Theme.Text or w.Theme.SubText
            end
        end
        for _, value in ipairs(cfg.Values or {}) do
            local row = New("TextButton", { Parent = list, Size = UDim2.new(1, 0, 0, 24), Text = "", AutoButtonColor = false, BackgroundTransparency = 1 })
            local dot = New("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0 })
            w:_corner(dot, "pill"); w:_bind(dot, "BackgroundColor3", "Stroke")
            local dotInner = New("Frame", { Parent = dot, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0, Visible = false })
            w:_corner(dotInner, "pill"); w:_bind(dotInner, "BackgroundColor3", "AccentText")
            local label = New("TextLabel", { Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), Text = tostring(value), Font = FONT_MED, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left })
            w:_bind(label, "TextColor3", "SubText")
            buttons[value] = { dot = dot, dotInner = dotInner, label = label }
            row.MouseButton1Click:Connect(function()
                selected = value; repaint(); safe(cfg.Callback, value)
            end)
        end
        w:_onTheme(list, repaint)
        repaint()
        return self:_registerState(cfg, {
            Get = function() return selected end,
            Set = function(_, v) selected = v; repaint(); safe(cfg.Callback, v) end,
        })
    end

    function Tab:AddNumberStepper(cfg)
        local w = self.Window
        local _, header = self:_card(cfg, 130)
        local min, max, inc = cfg.Min or 0, cfg.Max or 999, cfg.Increment or 1
        local value = cfg.Default or min
        local row = New("Frame", rightAnchored({ Parent = header, Size = UDim2.fromOffset(120, 26), BackgroundTransparency = 1 }))
        local minus = New("TextButton", { Parent = row, Size = UDim2.fromOffset(26, 26), Text = "−", Font = FONT_BOLD, TextSize = 16, AutoButtonColor = false })
        w:_corner(minus, 0.4); w:_bind(minus, "BackgroundColor3", "Elevated"); w:_bind(minus, "TextColor3", "Text")
        local box = New("TextBox", { Parent = row, Position = UDim2.fromOffset(30, 0), Size = UDim2.fromOffset(60, 26), Text = tostring(value), Font = FONT_MED, TextSize = 13, ClearTextOnFocus = false })
        w:_corner(box, 0.4); w:_bind(box, "BackgroundColor3", "Elevated"); w:_bind(box, "TextColor3", "Text")
        local plus = New("TextButton", { Parent = row, Position = UDim2.fromOffset(94, 0), Size = UDim2.fromOffset(26, 26), Text = "+", Font = FONT_BOLD, TextSize = 16, AutoButtonColor = false })
        w:_corner(plus, 0.4); w:_bind(plus, "BackgroundColor3", "Elevated"); w:_bind(plus, "TextColor3", "Text")

        local function apply(v, silent)
            v = math.clamp(v, min, max)
            v = min + math.floor((v - min) / inc + 0.5) * inc
            value = v
            box.Text = tostring(v)
            if not silent then safe(cfg.Callback, v) end
        end
        minus.MouseButton1Click:Connect(function() apply(value - inc) end)
        plus.MouseButton1Click:Connect(function() apply(value + inc) end)
        box.FocusLost:Connect(function() apply(tonumber(box.Text) or value) end)
        apply(value, true)
        return self:_registerState(cfg, { Get = function() return value end, Set = function(_, v) apply(v) end })
    end

    function Tab:AddMultiInput(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description }, 0)
        local fields = cfg.Fields or {}
        local values, inputBoxes = {}, {}
        local container = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
        New("UIListLayout", { Parent = container, Padding = UDim.new(0, 6) })
        for _, spec in ipairs(fields) do
            local row = New("Frame", { Parent = container, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26) })
            local lbl = New("TextLabel", { Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0.4, -6, 1, 0), Text = spec.Name, Font = FONT_MED, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left })
            w:_bind(lbl, "TextColor3", "SubText")
            local box = New("TextBox", { Parent = row, Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), Text = spec.Default or "", PlaceholderText = spec.Placeholder or "", Font = FONT, TextSize = 12, ClearTextOnFocus = false })
            pad(box, 0, 8, 0, 8)
            w:_corner(box, 0.4)
            w:_bind(box, "BackgroundColor3", "Elevated"); w:_bind(box, "TextColor3", "Text"); w:_bind(box, "PlaceholderColor3", "SubText")
            values[spec.Key or spec.Name] = spec.Default or ""
            inputBoxes[spec.Key or spec.Name] = box
            box:GetPropertyChangedSignal("Text"):Connect(function()
                values[spec.Key or spec.Name] = box.Text
            end)
            box.FocusLost:Connect(function(enter) safe(cfg.Callback, values, enter) end)
        end
        local obj = {
            Get = function() return values end,
            Set = function(_, t)
                if type(t) ~= "table" then error("expected a table of input values") end
                for k, box in pairs(inputBoxes) do
                    if t[k] ~= nil then box.Text = tostring(t[k]) end
                end
                safe(cfg.Callback, values, false)
            end,
        }
        return self:_registerState(cfg, obj)
    end

    function Tab:AddSearchBox(cfg)
        local w = self.Window
        local card, header = self:_card({ Title = cfg.Title or "Search", Description = cfg.Description }, 0)
        local box = New("TextBox", { Parent = card, Size = UDim2.new(1, 0, 0, 28), Text = "", PlaceholderText = cfg.Placeholder or "Search...", Font = FONT, TextSize = 12, ClearTextOnFocus = false, LayoutOrder = 2 })
        pad(box, 0, 10, 0, 10)
        w:_corner(box, 0.4); w:_bind(box, "BackgroundColor3", "Elevated"); w:_bind(box, "TextColor3", "Text"); w:_bind(box, "PlaceholderColor3", "SubText")
        local results = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 })
        New("UIListLayout", { Parent = results, Padding = UDim.new(0, 4) })
        local function rebuild(query)
            for _, c in ipairs(results:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
            if not cfg.Values then return end
            local count = 0
            for _, v in ipairs(cfg.Values) do
                if query == "" or tostring(v):lower():find(query:lower(), 1, true) then
                    count += 1
                    if count > (cfg.MaxResults or 8) then break end
                    local l = New("TextLabel", { Parent = results, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Text = tostring(v), Font = FONT_MED, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left })
                    w:_bind(l, "TextColor3", "SubText")
                end
            end
        end
        box:GetPropertyChangedSignal("Text"):Connect(function() rebuild(box.Text); safe(cfg.Callback, box.Text) end)
        rebuild("")
        return { Get = function() return box.Text end }
    end

    function Tab:AddCheckboxGroup(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description }, 0)
        local state = {}
        for _, v in ipairs(cfg.Default or {}) do state[v] = true end
        local rows, painters = {}, {}
        local list = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
        New("UIListLayout", { Parent = list, Padding = UDim.new(0, 4) })
        local function repaint()
            for value, r in pairs(rows) do
                local on = state[value] == true
                r.box.BackgroundColor3 = on and w.Theme.Accent or w.Theme.Stroke
                r.tick.Visible = on
                r.label.TextColor3 = on and w.Theme.Text or w.Theme.SubText
            end
        end
        for _, value in ipairs(cfg.Values or {}) do
            local row = New("TextButton", { Parent = list, Size = UDim2.new(1, 0, 0, 24), Text = "", AutoButtonColor = false, BackgroundTransparency = 1 })
            local box = New("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0 })
            w:_corner(box, 0.3); w:_bind(box, "BackgroundColor3", "Stroke")
            local tick = New("TextLabel", { Parent = box, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "✓", Font = FONT_BOLD, TextSize = 12, TextColor3 = Color3.new(1,1,1), Visible = false })
            local label = New("TextLabel", { Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), Text = tostring(value), Font = FONT_MED, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left })
            w:_bind(label, "TextColor3", "SubText")
            rows[value] = { box = box, tick = tick, label = label }
            row.MouseButton1Click:Connect(function()
                state[value] = not state[value] or nil
                repaint()
                local out = {}
                for _, v in ipairs(cfg.Values or {}) do if state[v] then table.insert(out, v) end end
                safe(cfg.Callback, out)
            end)
        end
        w:_onTheme(list, repaint)
        repaint()
        local obj
        obj = {
            Get = function()
                local t = {}
                for _, v in ipairs(cfg.Values or {}) do if state[v] then table.insert(t, v) end end
                return t
            end,
            Set = function(_, values)
                state = {}
                if type(values) == "table" then
                    for _, v in ipairs(values) do state[v] = true end
                end
                repaint()
                safe(cfg.Callback, obj:Get())
            end,
        }
        return self:_registerState(cfg, obj)
    end

    function Tab:AddCodeBox(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title or "Code", Description = cfg.Description }, 0)
        local box = New("TextBox", { Parent = card, Size = UDim2.new(1, 0, 0, cfg.Height or 110), Text = cfg.Default or "", Font = Enum.Font.Code, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, MultiLine = true, ClearTextOnFocus = false, LayoutOrder = 2 })
        pad(box, 8, 10, 8, 10)
        w:_corner(box, 0.3)
        w:_bind(box, "BackgroundColor3", "Elevated"); w:_bind(box, "TextColor3", "Text"); w:_bind(box, "PlaceholderColor3", "SubText")
        box.PlaceholderText = cfg.Placeholder or "-- code here"
        local st = w:_stroke(box, "Stroke")
        box.Focused:Connect(function() tween(st, { Color = w.Theme.Accent }) end)
        box.FocusLost:Connect(function(enter) tween(st, { Color = w.Theme.Stroke }); safe(cfg.Callback, box.Text, enter) end)
        local obj = {
            Get = function() return box.Text end,
            Set = function(_, t)
                box.Text = tostring(t or "")
                safe(cfg.Callback, box.Text, false)
            end,
        }
        return self:_registerState(cfg, obj)
    end

    function Tab:AddConfigSection(window)
        local w = window or self.Window
        self:AddSection("Config")
        local nameInput = self:AddInput({ Title = "Profile name", Placeholder = "MyConfig", Default = "default" })
        local selectedProfile = ""
        local profileDropdown
        local status = self:AddParagraph({ Title = "Status", Description = "Ready." })
        local function profilePath(name)
            if #name > 48 or not name:match("^[%w_-]+$") then
                error("Use 1-48 letters, numbers, underscores, or hyphens for the profile name.")
            end
            return "PrismConfigs/" .. name .. ".json"
        end
        local function refreshProfiles()
            if type(listfiles) ~= "function" then
                status:Set("Profile list unavailable: executor does not expose listfiles.")
                return
            end
            local ok, files = pcall(listfiles, "PrismConfigs")
            if not ok then
                if type(isfolder) == "function" then
                    local folderOk, exists = pcall(isfolder, "PrismConfigs")
                    if folderOk and not exists then files = {} else
                        status:Set("Could not list profiles: " .. tostring(files))
                        return
                    end
                else
                    status:Set("Could not list profiles: " .. tostring(files))
                    return
                end
            end
            local names = {}
            for _, file in ipairs(files) do
                local name = tostring(file):match("[^/\\]+%.json$")
                if name then table.insert(names, name:gsub("%.json$", "")) end
            end
            table.sort(names)
            if #names == 0 then names = { "No profiles found" } end
            selectedProfile = names[1]
            if profileDropdown then
                profileDropdown:SetValues(names)
                profileDropdown:Set(selectedProfile)
            else
                profileDropdown = self:AddDropdown({
                    Title = "Select profile",
                    Values = names,
                    Default = selectedProfile,
                    Callback = function(value) selectedProfile = value end,
                })
            end
        end
        local function saveProfile()
            local name = nameInput:Get()
            if name == "" then name = "default" end
            local path = profilePath(name)
            if type(writefile) ~= "function" then error("executor does not expose writefile") end
            if type(makefolder) == "function" and type(isfolder) == "function" then
                local folderOk, exists = pcall(isfolder, "PrismConfigs")
                if not folderOk then error("could not check PrismConfigs folder: " .. tostring(exists)) end
                if not exists then makefolder("PrismConfigs") end
            end
            local json = HttpService:JSONEncode(w:_collectState())
            writefile(path, json)
            selectedProfile = name
            refreshProfiles()
            if profileDropdown then profileDropdown:Set(name) end
        end
        local function loadProfile()
            local name = selectedProfile
            if name == "" or name == "No profiles found" then error("select a saved profile first") end
            local path = profilePath(name)
            if type(readfile) ~= "function" or type(isfile) ~= "function" then
                error("executor does not expose readfile/isfile")
            end
            if not isfile(path) then error("profile file not found: " .. path) end
            local data = HttpService:JSONDecode(readfile(path))
            w:_applyState(data)
            nameInput:Set(name)
        end
        local function report(action, ok, detail)
            status:Set(ok and (action .. " successfully.") or (action .. " failed: " .. tostring(detail)))
            w:Notify({
                Title = ok and (action .. " complete") or (action .. " failed"),
                Content = ok and ("Profile " .. action:lower() .. " successfully.") or tostring(detail),
                Duration = 3,
            })
        end
        self:AddButton({
            Title = "Save profile",
            Description = "Save the current interface and widget values.",
            Callback = function()
                local ok, err = pcall(saveProfile)
                report("Save", ok, err)
            end,
        })
        self:AddButton({
            Title = "Load selected profile",
            Callback = function()
                local ok, err = pcall(loadProfile)
                report("Load", ok, err)
            end,
        })
        self:AddButton({
            Title = "Delete selected profile",
            Callback = function()
                local ok, err = pcall(function()
                    if selectedProfile == "" or selectedProfile == "No profiles found" then
                        error("select a saved profile first")
                    end
                    if type(delfile) ~= "function" or type(isfile) ~= "function" then
                        error("executor does not expose delfile/isfile")
                    end
                    local path = profilePath(selectedProfile)
                    if not isfile(path) then error("profile file not found: " .. path) end
                    delfile(path)
                    refreshProfiles()
                end)
                report("Delete", ok, err)
            end,
        })
        self:AddButton({
            Title = "Refresh profiles",
            Callback = refreshProfiles,
        })
        self:AddButton({
            Title = "Export profile JSON",
            Callback = function()
                local ok, result = pcall(function() return HttpService:JSONEncode(w:_collectState()) end)
                if not ok then
                    status:Set("Export failed: " .. tostring(result))
                    w:Notify({ Title = "Export failed", Content = tostring(result), Duration = 3 })
                    return
                end
                if type(setclipboard) == "function" then
                    setclipboard(result)
                    status:Set("Config JSON copied to clipboard.")
                else
                    status:Set("Clipboard unavailable; JSON printed to output.")
                    print(result)
                end
            end,
        })
        refreshProfiles()
    end

    ------------------------------------------------------------------ window creation
    local function encodeConfigValue(value)
        local valueType = typeof(value)
        if valueType == "EnumItem" then
            return value.Name
        elseif valueType == "Color3" then
            return { __prismType = "Color3", r = value.R, g = value.G, b = value.B }
        elseif value == nil then
            return { __prismType = "nil" }
        elseif type(value) == "table" then
            local result = {}
            for key, item in pairs(value) do result[key] = encodeConfigValue(item) end
            return result
        elseif type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
            return value
        end
        error("unsupported config value type: " .. valueType)
    end

    local function decodeEnumValue(value, expected, enumTypeHint)
        local function normalizeEnumType(enumType)
            if typeof(enumType) == "EnumItem" then enumType = enumType.EnumType end
            local name = tostring(enumType):match("^Enum%.([%w_]+)$") or tostring(enumType):gsub("^Enum%.", "")
            if name == "" or name == "nil" then return nil end
            local ok, result = pcall(function() return Enum[name] end)
            return ok and result or nil
        end
        local expectedType = typeof(expected) == "EnumItem" and expected.EnumType or nil
        local savedTypeName = type(value) == "table" and (value.enumType or value.EnumType or value.enum) or nil
        local savedType = savedTypeName and normalizeEnumType(savedTypeName) or nil
        local hintedType = enumTypeHint and normalizeEnumType(enumTypeHint) or nil
        local enumType = expectedType or savedType or hintedType
        local enumName = value
        if type(value) == "table" then
            enumName = value.name or value.Name or value.value or value.Value
        end
        if type(enumName) ~= "string" then error("saved enum value is not a name") end
        local fullType, fullName = enumName:match("^Enum%.([%w_]+)%.([%w_]+)$")
        if not fullType then
            fullType, fullName = enumName:match("^([%w_]+)%.([%w_]+)$")
            if fullType then
                local ok, result = pcall(function() return Enum[fullType] end)
                if not ok or not result then fullType, fullName = nil, nil end
            end
        end
        if fullType and fullName then
            local fullEnumType = normalizeEnumType(fullType)
            if not fullEnumType then error("unknown saved enum type '" .. fullType .. "'") end
            enumType = enumType or fullEnumType
            enumName = fullName
        end
        if not enumType then
            error("missing enum type for saved value '" .. tostring(enumName) .. "'")
        end
        local expectedTypeName = tostring(enumType):match("^Enum%.([%w_]+)$")
        if fullType and fullType ~= expectedTypeName then
            error("saved enum type does not match the setting")
        end
        if savedType and tostring(savedType) ~= tostring(enumType) then
            error("saved enum type does not match the setting")
        end
        local ok, item = pcall(function()
            return enumType[enumName]
        end)
        if not ok or not item then
            error("invalid saved enum value '" .. tostring(enumName) .. "'")
        end
        return item
    end

    local function decodeConfigValue(value, expected, enumTypeHint)
        if (typeof(expected) == "EnumItem" or enumTypeHint) and
            (type(value) == "string" or (type(value) == "table" and value.__prismType == "EnumItem")) then
            return decodeEnumValue(value, expected, enumTypeHint)
        end
        if type(value) ~= "table" then return value end
        if value.__prismType == "nil" then return nil end
        if value.__prismType == "Color3" then
            if type(value.r) ~= "number" or type(value.g) ~= "number" or type(value.b) ~= "number" then
                error("invalid saved Color3 value")
            end
            return Color3.new(value.r, value.g, value.b)
        end
        if value.__prismType == "EnumItem" then
            return decodeEnumValue(value, expected, enumTypeHint)
        end
        local result = {}
        for key, item in pairs(value) do
            local template = type(expected) == "table" and expected[key] or nil
            result[key] = decodeConfigValue(item, template, enumTypeHint)
        end
        return result
    end

    function Window:_collectState()
        local widgets, enumTypes = {}, {}
        for key, widget in pairs(self._stateWidgets) do
            local ok, value = pcall(widget.Get, widget)
            if not ok then error("could not read setting '" .. key .. "': " .. tostring(value)) end
            widgets[key] = encodeConfigValue(value)
            local enumType = widget._configEnumType
            if not enumType then
                local function findEnumType(item)
                    if typeof(item) == "EnumItem" then return item.EnumType end
                    if type(item) == "table" then
                        for _, nested in pairs(item) do
                            local found = findEnumType(nested)
                            if found then return found end
                        end
                    end
                    return nil
                end
                enumType = findEnumType(value)
            end
            if enumType then
                enumTypes[key] = tostring(enumType):gsub("^Enum%.", "")
            end
        end
        local s = {
            version = 3,
            theme = type(self._themeName) == "string" and self._themeName or "custom",
            themeData = type(self._themeName) == "table" and encodeConfigValue(self._themeName) or nil,
            accent = self._accent and encodeConfigValue(self._accent) or nil,
            corner = self.CornerRadius,
            size = { X = self._size.X, Y = self._size.Y },
            widgets = widgets,
            enumTypes = enumTypes,
        }
        return s
    end
    function Window:_applyState(s)
        if type(s) ~= "table" then error("invalid config data") end
        local decodedSettings = {}
        if type(s.widgets) == "table" then
            for key, storedValue in pairs(s.widgets) do
                local widget = self._stateWidgets[key]
                if widget then
                    local ok, current = pcall(widget.Get, widget)
                    if not ok then error("could not inspect setting '" .. key .. "': " .. tostring(current)) end
                    local decodedOk, decoded = pcall(function()
                        local enumTypeHint = type(s.enumTypes) == "table" and s.enumTypes[key] or widget._configEnumType
                        return decodeConfigValue(storedValue, current, enumTypeHint)
                    end)
                    if not decodedOk then
                        error("could not decode setting '" .. key .. "': " .. tostring(decoded))
                    end
                    decodedSettings[key] = { widget = widget, value = decoded }
                end
            end
        end
        for key, setting in pairs(decodedSettings) do
            local ok, err = pcall(setting.widget.Set, setting.widget, setting.value)
            if not ok then error("could not apply setting '" .. key .. "': " .. tostring(err)) end
        end
        if s.themeData then
            self:SetTheme(decodeConfigValue(s.themeData))
        elseif s.theme then
            self:SetTheme(s.theme)
        end
        self:SetAccent(s.accent and decodeConfigValue(s.accent) or nil)
        if type(s.corner) == "number" then self:SetCornerRadius(s.corner) end
        if type(s.size) == "table" and type(s.size.X) == "number" and type(s.size.Y) == "number" then
            self:SetSize(Vector2.new(s.size.X, s.size.Y))
        end
    end

    function Library:CreateWindow(cfg)
        cfg = cfg or {}
        local self = setmetatable({ Tabs = {}, _painters = {}, _corners = {}, _conns = {}, _notifId = 0, _stateWidgets = {} }, Window)
        self._themeName = cfg.Theme or "Midnight"
        self._accent    = cfg.Accent
        self.CornerRadius = math.clamp(cfg.CornerRadius or 10, 0, 28)
        self.ToggleKey    = cfg.ToggleKey or Enum.KeyCode.RightShift
        self._size        = cfg.Size or Vector2.new(620, 420)
        self._minimized   = false
        self:_buildTheme()

        local size = self._size
        local gui = New("ScreenGui", { Name = "PrismUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100, IgnoreGuiInset = true })
        self.Gui = gui

        local holder = New("Frame", { Name = "Window", Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1 })
        local scale  = New("UIScale", { Parent = holder, Scale = 0.92 })
        self.Holder, self._scale = holder, scale
        tween(scale, { Scale = 1 }, TI_POP)

        local main = New("Frame", { Name = "Main", Parent = holder, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ClipsDescendants = true })
        self:_bind(main, "BackgroundColor3", "Background")
        self:_corner(main, 1)
        self:_stroke(main, "Stroke")
        pad(main, 12)

        local topSurface = New("Frame", { Parent = main, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 52) })
        self:_bind(topSurface, "BackgroundColor3", "Surface")
        self:_corner(topSurface, 0.45)
        local topSurfaceStroke = self:_stroke(topSurface, "Stroke")
        topSurfaceStroke.Transparency = 0.45
        local separator = New("Frame", { Parent = main, Position = UDim2.new(0, 8, 0, 53), Size = UDim2.new(1, -16, 0, 1), BorderSizePixel = 0 })
        self:_bind(separator, "BackgroundColor3", "Stroke")
        local top = New("Frame", { Parent = main, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52) })
        local titleAccent = New("Frame", {
            Parent = top, Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(3, 32),
            BorderSizePixel = 0,
        })
        self:_corner(titleAccent, "pill")
        self:_bind(titleAccent, "BackgroundColor3", "Accent")
        local titleRow = New("Frame", {
            Parent = top, BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 0),
            Size = UDim2.new(1, -132, 1, 0), ClipsDescendants = true,
        })
        local brandTitle = New("TextLabel", {
            Parent = titleRow, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 4),
            Size = UDim2.new(1, 0, 0, 23),
            Text = cfg.Title or "PrismUI", Font = FONT_BOLD, TextSize = 17,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        })
        self:_bind(brandTitle, "TextColor3", "Text")
        local tagList = New("Frame", {
            Parent = titleRow, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 29),
            Size = UDim2.new(1, 0, 0, 20), ClipsDescendants = true,
        })
        New("UIListLayout", {
            Parent = tagList, FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        for index, tag in ipairs(cfg.Tags or {}) do
            local text, color
            if type(tag) == "table" then
                text, color = tostring(tag.Text or tag.Name or ""), tag.Color
                if typeof(color) ~= "Color3" then color = nil end
            else
                text = tostring(tag)
            end
            if text ~= "" then
                local pill = New("Frame", {
                    Parent = tagList, AutomaticSize = Enum.AutomaticSize.X,
                    Size = UDim2.fromOffset(0, 19), BorderSizePixel = 0, LayoutOrder = index,
                })
                self:_corner(pill, "pill")
                pill.BackgroundColor3 = color and color:Lerp(self.Theme.Background, 0.82) or self.Theme.Elevated
                if not color then self:_bind(pill, "BackgroundColor3", "Elevated") end
                local pillStroke = self:_stroke(pill, "Stroke")
                pillStroke.Transparency = 0.55
                pad(pill, 0, 9, 0, 9)
                local pillLayout = New("UIListLayout", {
                    Parent = pill, FillDirection = Enum.FillDirection.Horizontal,
                    VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6),
                })
                pillLayout.SortOrder = Enum.SortOrder.LayoutOrder
                local tagDot = New("Frame", {
                    Parent = pill, Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0, LayoutOrder = 1,
                })
                self:_corner(tagDot, "pill")
                tagDot.BackgroundColor3 = color or self.Theme.Accent
                if not color then self:_bind(tagDot, "BackgroundColor3", "Accent") end
                local tagLabel = New("TextLabel", {
                    Parent = pill, AutomaticSize = Enum.AutomaticSize.X,
                    Size = UDim2.fromOffset(0, 19), BackgroundTransparency = 1,
                    Text = string.upper(text), Font = FONT_BOLD, TextSize = 8,
                    TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2,
                })
                tagLabel.TextColor3 = color or self.Theme.Accent
                if not color then self:_bind(tagLabel, "TextColor3", "Accent") end
            end
        end

        local controls = New("Frame", {
            Parent = top, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(80, 36),
            BorderSizePixel = 0,
        })
        self:_corner(controls, "pill")
        self:_bind(controls, "BackgroundColor3", "Elevated")
        local controlsStroke = self:_stroke(controls, "Stroke")
        controlsStroke.Transparency = 0.35
        local controlDivider = New("Frame", {
            Parent = controls, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 1, 0, 16),
            BorderSizePixel = 0,
        })
        self:_bind(controlDivider, "BackgroundColor3", "Stroke")
        local function topButton(iconName, x, danger)
            local restingTransparency = danger and 0.72 or 1
            local b = New("TextButton", {
                Parent = controls, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0),
                Size = UDim2.fromOffset(32, 32), Text = "", AutoButtonColor = false,
                BackgroundTransparency = restingTransparency, BorderSizePixel = 0,
            })
            self:_corner(b, "pill")
            local image = New("ImageLabel", {
                Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(15, 15), BackgroundTransparency = 1,
                Image = resolveIcon(iconName),
            })
            self:_onTheme(b, function()
                b.BackgroundColor3 = danger and rgb(190, 55, 68) or self.Theme.Elevated
                b.BackgroundTransparency = restingTransparency
                image.ImageColor3 = danger and rgb(239, 135, 145) or self.Theme.SubText
            end)
            b.MouseEnter:Connect(function()
                tween(b, { BackgroundTransparency = 0, BackgroundColor3 = danger and rgb(190, 55, 68) or self.Theme.Stroke }, TI)
                tween(image, { ImageColor3 = danger and rgb(255, 255, 255) or self.Theme.Text }, TI)
            end)
            b.MouseLeave:Connect(function()
                tween(b, { BackgroundTransparency = restingTransparency, BackgroundColor3 = danger and rgb(190, 55, 68) or self.Theme.Elevated }, TI)
                tween(image, { ImageColor3 = danger and rgb(239, 135, 145) or self.Theme.SubText }, TI)
            end)
            b.MouseButton1Down:Connect(function() tween(b, { Size = UDim2.fromOffset(29, 29) }, TweenInfo.new(0.07)) end)
            b.MouseButton1Up:Connect(function() tween(b, { Size = UDim2.fromOffset(32, 32) }, TI) end)
            return b, image
        end
        local closeBtn = topButton("x", 0, true)
        local minBtn, minIcon = topButton("minimize-2", -48)
        self._minButton, self._minIcon = minBtn, minIcon

        local body = New("Frame", { Parent = main, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 1, -60) })
        self._body = body
        local sidebar = New("Frame", { Parent = body, Size = UDim2.new(0, 142, 1, 0), BorderSizePixel = 0 })
        self:_bind(sidebar, "BackgroundColor3", "Surface")
        self:_corner(sidebar, 0.45)
        local tabList = New("ScrollingFrame", { Parent = sidebar, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0 })
        pad(tabList, 8, 6, 8, 6)
        New("UIListLayout", { Parent = tabList, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })
        self._tabList = tabList
        self._pages   = New("Frame", { Parent = body, BackgroundTransparency = 1, Position = UDim2.fromOffset(152, 0), Size = UDim2.new(1, -152, 1, 0), ClipsDescendants = true })

        self._notifs = New("Frame", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.new(0, 280, 1, -40) })
        New("UIListLayout", { Parent = self._notifs, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder })

        -- resize handle
        if cfg.Resizable then
            local handle = New("TextButton", { Parent = holder, Text = "", Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -14, 1, -14), BackgroundTransparency = 1, ZIndex = 5 })
            local resize = false
            handle.InputBegan:Connect(function(i) if isPress(i) then resize = true end end)
            self:_connect(UserInputService.InputChanged, function(i)
                if resize and isMove(i) then
                    local sx = i.Position.X - holder.AbsolutePosition.X
                    local sy = i.Position.Y - holder.AbsolutePosition.Y
                    self._size = Vector2.new(math.max(360, sx + 12), math.max(240, sy + 12))
                    holder.Size = UDim2.fromOffset(self._size.X, self._size.Y)
                end
            end)
            self:_connect(UserInputService.InputEnded, function(i) if isPress(i) then resize = false end end)
        end

        local dragging, dragStart, startPos = false, nil, nil
        top.InputBegan:Connect(function(i) if isPress(i) then dragging, dragStart, startPos = true, i.Position, holder.Position end end)
        self:_connect(UserInputService.InputChanged, function(i)
            if dragging and isMove(i) then
                local d = i.Position - dragStart
                holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        self:_connect(UserInputService.InputEnded, function(i) if isPress(i) then dragging = false end end)

        minBtn.MouseButton1Click:Connect(function() self:SetMinimized(not self._minimized) end)
        closeBtn.MouseButton1Click:Connect(function()
            tween(scale, { Scale = 0.9 }, TI)
            task.delay(0.15, function() self:Destroy() end)
        end)
        self:_connect(UserInputService.InputBegan, function(i, gpe)
            if not gpe and not self._rebinding and i.KeyCode == self.ToggleKey then self:Toggle() end
        end)

        local parent = cfg.Parent
        if not parent and typeof(gethui) == "function" then
            local ok, r = pcall(gethui)
            if ok then parent = r end
        end
        if parent then
            gui.Parent = parent
        else
            local ok = pcall(function() gui.Parent = CoreGui end)
            if not ok or gui.Parent ~= CoreGui then gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
        end
        return self
    end

    return Library
end)()
return Prism
