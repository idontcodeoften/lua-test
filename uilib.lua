--[[
    PrismUI v2.1 - executor single-file build (lean + minimal)

    local Prism  = loadstring(game:HttpGet("RAW_GITHUB_URL"))()
    local Window = Prism:CreateWindow({ Title = "My UI", Tags = { "BETA" } })
    local Main   = Window:AddTab({ Title = "Main", Icon = "house" })
    Main:AddButton({ Title = "Hello", Callback = function() Window:Notify("Hello!") end })

    Same API as v1.x. New in 2.0:
      * AddColumns() returns tab-like columns (you can call :AddToggle etc. on them)
      * Window:ExportConfig() / Window:ImportConfig(json)
      * ColorPicker is HSV with gradient bars (cfg.Live = true to fire while dragging)
      * Widgets accept cfg.NoSave = true to be excluded from config profiles
      * Dropdown:Set(v, silent), Slider:Set(v, silent), Toggle:Set(v, silent)
      * Library:AddTheme(name, theme), Library:AddIcon(name, assetId)

    New in 2.1 (animations + graphs):
      * Tab:AddLineGraph  - multi-series, filled, hover tooltip, realtime mode (MaxPoints + :Push)
      * Tab:AddBarGraph   - animated bars, hover highlight
      * Tab:AddDistribution - segmented proportion bar with legend
      * Graphs replay their intro animation whenever their tab is opened (Animate = false to disable)
      * Sliding tab indicator, page fade, notification timer bar, slider knob grow
      * progress:SetIndeterminate(true) / AddProgressBar({ Indeterminate = true })
      * Window:SetAnimations(bool), Window:SetAnimationSpeed(0.25-4)  (global), also CreateWindow
        options Animations / AnimationSpeed, and controls in AddAppearanceTab
]]

local Prism = (function()
    local TweenService     = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local Players          = game:GetService("Players")
    local CoreGui          = game:GetService("CoreGui")
    local HttpService      = game:GetService("HttpService")

    local Library = { Version = "2.1" }
    local Window, Tab = {}, {}
    Window.__index, Tab.__index = Window, Tab

    local FONT, FONT_MED, FONT_BOLD = Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold
    local AUTO_X, AUTO_Y = Enum.AutomaticSize.X, Enum.AutomaticSize.Y
    local LEFT, RIGHT = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right
    local TI      = TweenInfo.new(0.14, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
    local TI_POP  = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local TOP_H, SIDEBAR_W = 44, 148

    Library.Icons = {
        ["code"]             = "rbxassetid://107380207681249",
        ["file-cog"]         = "rbxassetid://101385347151368",
        ["house"]            = "rbxassetid://98755624629571",
        ["info"]             = "rbxassetid://124560466474914",
        ["layout-dashboard"] = "rbxassetid://139929981863901",
        ["maximize-2"]       = "rbxassetid://73085922906397",
        ["minimize-2"]       = "rbxassetid://116269596042539",
        ["settings"]         = "rbxassetid://80758916183665",
        ["x"]                = "rbxassetid://110786993356448",
    }

    ------------------------------------------------------------------ themes
    local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
    local function theme(bg, surface, elevated, stroke, text, sub, accent)
        return { Background = bg, Surface = surface, Elevated = elevated, Stroke = stroke, Text = text, SubText = sub, Accent = accent }
    end

    Library.Themes = {
        Midnight = theme(rgb(15,17,23),  rgb(21,24,32),   rgb(30,34,44),  rgb(42,47,60),  rgb(238,241,247), rgb(145,153,168), rgb(129,102,255)),
        Light    = theme(rgb(244,245,249), rgb(255,255,255), rgb(236,238,245), rgb(214,218,232), rgb(24,26,36), rgb(110,115,135), rgb(99,102,241)),
        Rose     = theme(rgb(20,12,16),  rgb(30,19,25),   rgb(44,28,36),  rgb(66,42,54),  rgb(250,238,243), rgb(178,140,155), rgb(251,86,140)),
        Ocean    = theme(rgb(9,17,26),   rgb(15,27,40),   rgb(23,40,58),  rgb(34,57,80),  rgb(232,243,252), rgb(128,158,184), rgb(56,189,248)),
        Emerald  = theme(rgb(10,18,15),  rgb(16,28,23),   rgb(24,43,35),  rgb(36,62,50),  rgb(234,248,241), rgb(130,170,150), rgb(52,211,153)),
        Amber    = theme(rgb(20,16,10),  rgb(31,25,15),   rgb(45,37,22),  rgb(68,56,34),  rgb(252,245,232), rgb(184,166,132), rgb(251,176,52)),
        Nebula   = theme(rgb(10,8,22),   rgb(18,14,36),   rgb(30,22,58),  rgb(50,38,88),  rgb(240,234,255), rgb(160,148,200), rgb(186,104,255)),
        Mono     = theme(rgb(16,16,16),  rgb(24,24,24),   rgb(38,38,38),  rgb(58,58,58),  rgb(238,238,238), rgb(150,150,150), rgb(210,210,210)),
        Sunset   = theme(rgb(24,12,10),  rgb(38,18,14),   rgb(56,26,18),  rgb(84,40,26),  rgb(255,238,228), rgb(200,150,130), rgb(255,122,74)),
        Forest   = theme(rgb(10,18,12),  rgb(16,28,18),   rgb(24,42,26),  rgb(40,66,42),  rgb(234,248,236), rgb(140,180,144), rgb(96,200,110)),
        Blood    = theme(rgb(18,6,8),    rgb(30,10,14),   rgb(46,16,22),  rgb(72,24,32),  rgb(255,236,238), rgb(190,120,130), rgb(230,48,64)),
        Candy    = theme(rgb(24,10,22),  rgb(38,16,36),   rgb(56,24,52),  rgb(86,40,80),  rgb(255,238,252), rgb(200,150,196), rgb(255,110,220)),
    }

    function Library:AddTheme(name, t) self.Themes[name] = t end
    function Library:AddIcon(name, id)
        self.Icons[string.lower(name)] = type(id) == "number" and ("rbxassetid://" .. id) or id
    end

    ------------------------------------------------------------------ helpers
    local DEFAULTS = {
        Frame          = { BorderSizePixel = 0 },
        TextLabel      = { BorderSizePixel = 0, BackgroundTransparency = 1, Font = FONT_MED, TextSize = 13, Text = "" },
        TextButton     = { BorderSizePixel = 0, AutoButtonColor = false, Font = FONT_MED, TextSize = 13, Text = "" },
        TextBox        = { BorderSizePixel = 0, ClearTextOnFocus = false, Font = FONT, TextSize = 12, Text = "" },
        ImageLabel     = { BorderSizePixel = 0, BackgroundTransparency = 1 },
        ScrollingFrame = { BorderSizePixel = 0, BackgroundTransparency = 1, CanvasSize = UDim2.new(), AutomaticCanvasSize = AUTO_Y, ScrollBarThickness = 2 },
    }

    local function New(class, props)
        local inst = Instance.new(class)
        local d = DEFAULTS[class]
        if d then for k, v in pairs(d) do inst[k] = v end end
        local parent
        for k, v in pairs(props) do
            if k == "Parent" then parent = v else inst[k] = v end
        end
        inst.Parent = parent -- parent last: one replication/layout pass
        return inst
    end

    -- global animation settings (shared by every window): Window:SetAnimations / SetAnimationSpeed
    local ANIM = { on = true, speed = 1 }
    local function T(t) return ANIM.on and t / ANIM.speed or 0 end -- scale a delay to the current speed

    local function tween(inst, goal, info)
        if not ANIM.on then
            for k, v in pairs(goal) do inst[k] = v end
            return
        end
        info = info or TI
        if ANIM.speed ~= 1 then
            info = TweenInfo.new(info.Time / ANIM.speed, info.EasingStyle, info.EasingDirection, info.RepeatCount, info.Reverses, info.DelayTime)
        end
        TweenService:Create(inst, info, goal):Play()
    end

    local function apply(inst, goal, animate)
        if animate then tween(inst, goal) else for k, v in pairs(goal) do inst[k] = v end end
    end

    local function safe(fn, ...)
        if type(fn) ~= "function" then return end
        local ok, err = pcall(fn, ...)
        if not ok then warn("[PrismUI] callback error: " .. tostring(err)) end
    end

    local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
    local function isMove(i)  return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch end

    -- Temporary drag listeners: only connected while the pointer is actually held down.
    local function beginDrag(onMove, onEnd)
        local c1, c2
        c1 = UserInputService.InputChanged:Connect(function(i)
            if isMove(i) then onMove(Vector2.new(i.Position.X, i.Position.Y)) end
        end)
        c2 = UserInputService.InputEnded:Connect(function(i)
            if isPress(i) then
                c1:Disconnect(); c2:Disconnect()
                if onEnd then onEnd() end
            end
        end)
    end

    local function pad(parent, t, r, b, l)
        return New("UIPadding", {
            Parent = parent,
            PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r or t),
            PaddingBottom = UDim.new(0, b or t), PaddingLeft = UDim.new(0, l or r or t),
        })
    end

    local function layout(parent, gap, horizontal)
        return New("UIListLayout", {
            Parent = parent, Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder,
            FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        })
    end

    local function rightAnchored(props)
        props.AnchorPoint = Vector2.new(1, 0.5)
        props.Position = UDim2.new(1, 0, 0.5, 0)
        return props
    end

    local function formatNumber(v)
        if type(v) ~= "number" then return tostring(v) end
        if v == math.floor(v) then return tostring(math.floor(v)) end
        return string.format("%.2f", v)
    end

    local function resolveIcon(icon)
        if type(icon) == "number" then return "rbxassetid://" .. icon end
        if type(icon) ~= "string" then return nil end
        if icon:match("^rbxassetid://%d+$") then return icon end
        if icon:match("^%d+$") then return "rbxassetid://" .. icon end
        return Library.Icons[icon:lower()]
    end

    local function hexToColor3(hex)
        local h = tostring(hex):match("^%s*#?(%x%x%x%x%x%x)%s*$")
        if not h then return nil end
        return Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
    end

    local function color3ToHex(c)
        return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
    end

    ------------------------------------------------------------------ window internals
    function Window:_buildTheme()
        local src = type(self._themeName) == "table" and self._themeName or Library.Themes[self._themeName] or Library.Themes.Midnight
        local t = table.clone(src)
        for k, v in pairs(Library.Themes.Midnight) do if t[k] == nil then t[k] = v end end
        if self._accent then t.Accent = self._accent end
        local a = t.Accent
        t.AccentText = (0.299 * a.R + 0.587 * a.G + 0.114 * a.B) > 0.62 and rgb(15, 15, 20) or Color3.new(1, 1, 1)
        self.Theme = t
    end

    -- painters: { inst, prop = , key = } for simple bindings, { inst, fn = } for custom ones
    function Window:_bind(inst, prop, key)
        inst[prop] = self.Theme[key]
        table.insert(self._painters, { inst, prop = prop, key = key })
    end

    function Window:_onTheme(inst, fn)
        table.insert(self._painters, { inst, fn = fn })
        fn()
    end

    function Window:_refresh()
        local list, th = self._painters, self.Theme
        for i = #list, 1, -1 do
            local p = list[i]
            if not p[1].Parent then
                list[i] = list[#list]; list[#list] = nil
            elseif p.fn then
                pcall(p.fn)
            else
                p[1][p.prop] = th[p.key]
            end
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

    function Window:_prune()
        local c, n = self._corners, 0
        for i = 1, #c do
            local e = c[i]
            if e.corner.Parent then n += 1; c[n] = e end
        end
        for i = #c, n + 1, -1 do c[i] = nil end
        self._cornerLimit = n * 2 + 64
    end

    function Window:_corner(parent, scale)
        local c = New("UICorner", { Parent = parent })
        local e = { corner = c, scale = scale }
        local list = self._corners
        list[#list + 1] = e
        self:_applyCorner(e)
        if #list > self._cornerLimit then self:_prune() end
        return c
    end

    function Window:_stroke(parent, key, thickness)
        local s = New("UIStroke", { Parent = parent, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
        self:_bind(s, "Color", key or "Stroke")
        return s
    end

    function Window:_text(parent, text, size, font, key)
        local l = New("TextLabel", {
            Parent = parent, Size = UDim2.new(1, 0, 0, size + 2), AutomaticSize = AUTO_Y,
            Text = text or "", TextSize = size, Font = font, TextWrapped = true,
            TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Top,
        })
        self:_bind(l, "TextColor3", key)
        return l
    end

    function Window:_connect(signal, fn) table.insert(self._conns, signal:Connect(fn)) end

    ------------------------------------------------------------------ public window API
    function Window:SetTheme(t) self._themeName = t; self:_buildTheme(); self:_refresh() end
    function Window:SetAccent(c) self._accent = c; self:_buildTheme(); self:_refresh() end
    function Window:GetTheme() return self.Theme end

    function Window:SetCornerRadius(r)
        self.CornerRadius = math.clamp(r, 0, 28)
        self:_prune()
        for _, e in ipairs(self._corners) do self:_applyCorner(e) end
    end

    function Window:Toggle(state)
        if state == nil then state = not self._visible end
        self._visible = state
        self._visToken += 1
        local token = self._visToken
        if state then
            self.Holder.Visible = true
            self._scale.Scale = 0.95
            tween(self._scale, { Scale = 1 }, TI_POP)
        else
            tween(self._scale, { Scale = 0.95 }, TI)
            task.delay(T(0.15), function()
                if self._visToken == token and self.Holder.Parent then self.Holder.Visible = false end
            end)
        end
    end

    function Window:Center() tween(self.Holder, { Position = UDim2.fromScale(0.5, 0.5) }, TI_POP) end

    function Window:SetSize(size)
        self._size = size
        if not self._minimized then tween(self.Holder, { Size = UDim2.fromOffset(size.X, size.Y) }, TI_POP) end
    end

    function Window:SetMinimized(state)
        if state == nil then state = not self._minimized end
        if state == self._minimized then return end
        self._minimized = state
        self._minToken += 1
        local token = self._minToken
        self._minIcon.Image = resolveIcon(state and "maximize-2" or "minimize-2")
        if state then
            tween(self.Holder, { Size = UDim2.fromOffset(math.min(self._size.X, 300), TOP_H) }, TI_POP)
            task.delay(T(0.26), function()
                if token == self._minToken and self._minimized then self._body.Visible = false end
            end)
        else
            self._body.Visible = true
            tween(self.Holder, { Size = UDim2.fromOffset(self._size.X, self._size.Y) }, TI_POP)
        end
    end

    function Window:SetToggleKey(key) self.ToggleKey = key end
    function Window:GetToggleKey() return self.ToggleKey end

    function Window:SetAnimations(on) ANIM.on = on ~= false end
    function Window:SetAnimationSpeed(s) ANIM.speed = math.clamp(tonumber(s) or 1, 0.25, 4) end
    function Window:GetAnimations() return ANIM.on, ANIM.speed end
    function Window:Tween(inst, goal, info) tween(inst, goal, info or TI_POP) end

    function Window:SetWatermark(text)
        if self._watermark then self._watermark:Destroy(); self._watermark = nil end
        if not text then return end
        local w = New("TextLabel", {
            Parent = self.Gui, Text = text, TextSize = 12, Position = UDim2.fromOffset(16, 12),
            Size = UDim2.fromOffset(0, 20), AutomaticSize = AUTO_X, TextXAlignment = LEFT,
            TextStrokeTransparency = 0.6,
        })
        self:_bind(w, "TextColor3", "SubText")
        self:_bind(w, "TextStrokeColor3", "Background")
        self._watermark = w
    end

    function Window:Destroy()
        if self._destroyed then return end
        self._destroyed = true
        for _, c in ipairs(self._conns) do c:Disconnect() end
        self.Gui:Destroy()
    end

    function Window:_moveIndicator(tab, animate)
        local btn, ind, side = tab._btn, self._indicator, self._sidebar
        local function go(anim)
            if not btn.Parent or self.ActiveTab ~= tab then return end
            local sc = self._scale.Scale
            local goal = {
                Position = UDim2.fromOffset(8, (btn.AbsolutePosition.Y - side.AbsolutePosition.Y) / sc),
                Size = UDim2.new(1, -16, 0, btn.AbsoluteSize.Y / sc),
            }
            ind.Visible = true
            if anim then tween(ind, goal, TI_POP) else for k, v in pairs(goal) do ind[k] = v end end
        end
        if btn.AbsoluteSize.Y > 0 then go(animate) else task.delay(0.05, function() go(false) end) end
    end

    function Window:SelectTab(tab)
        local prev = self.ActiveTab
        if prev == tab then return end
        self.ActiveTab = tab
        if prev then prev.Page.Visible = false; prev._paint(true) end
        tab.Page.Position = UDim2.fromOffset(10, 0)
        tab.Page.Visible = true
        tween(tab.Page, { Position = UDim2.fromOffset(0, 0) }, TI_POP)
        local curtain = self._curtain
        if ANIM.on then
            curtain.BackgroundTransparency = 0.25
            tween(curtain, { BackgroundTransparency = 1 }, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
        end
        tab._paint(true)
        self:_moveIndicator(tab, prev ~= nil)
        for _, f in ipairs(tab._onShow) do safe(f) end
    end

    function Window:Notify(cfg)
        if type(cfg) == "string" then cfg = { Content = cfg } end
        cfg = cfg or {}
        self._notifId += 1
        local wrap = New("Frame", { Parent = self._notifs, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = self._notifId })
        local card = New("Frame", { Parent = wrap, Position = UDim2.fromOffset(300, 0), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y })
        self:_bind(card, "BackgroundColor3", "Surface")
        self:_corner(card, 0.4)
        self:_stroke(card, "Stroke")
        local content = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y })
        pad(content, 10, 12)
        layout(content, 3)
        local title = self:_text(content, cfg.Title or "Notice", 13, FONT_BOLD, "Text")
        title.LayoutOrder = 1
        pad(title, 0, 0, 0, 10)
        local stripe = New("Frame", { Parent = title, Position = UDim2.fromOffset(-10, 1), Size = UDim2.fromOffset(3, 14) })
        self:_corner(stripe, "pill")
        self:_bind(stripe, "BackgroundColor3", "Accent")
        if cfg.Content then
            self:_text(content, tostring(cfg.Content), 12, FONT, "SubText").LayoutOrder = 2
        end
        local duration = math.max(0.5, tonumber(cfg.Duration) or 4)
        local timer = New("Frame", { Parent = card, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 0.5 })
        self:_bind(timer, "BackgroundColor3", "Accent")
        if ANIM.on then
            TweenService:Create(timer, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
        end
        tween(card, { Position = UDim2.fromOffset(0, 0) }, TI_POP)
        task.delay(duration, function()
            if card.Parent then
                tween(card, { Position = UDim2.fromOffset(300, 0) }, TI)
                task.wait(T(0.16))
            end
            if wrap.Parent then wrap:Destroy() end
        end)
    end

    function Window:AddTab(cfg)
        if type(cfg) == "string" then cfg = { Title = cfg } end
        cfg = cfg or {}
        local tab = setmetatable({ Window = self, Title = cfg.Title or "Tab", _order = 0, _keys = {}, _onShow = {} }, Tab)
        tab._root = tab

        self._navOrder += 1
        local btn = New("TextButton", { Parent = self._tabList, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = self._navOrder })
        self:_corner(btn, 0.5)
        local iconImage = resolveIcon(cfg.Icon)
        local textX = iconImage and 34 or 12
        local label = New("TextLabel", {
            Parent = btn, Position = UDim2.fromOffset(textX, 0), Size = UDim2.new(1, -(textX + 6), 1, 0),
            Text = tab.Title, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd,
        })
        local icon
        if iconImage then
            icon = New("ImageLabel", { Parent = btn, Image = iconImage, Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 11, 0.5, 0) })
        end

        tab._btn = btn
        tab._paint = function(animate)
            local active, th = self.ActiveTab == tab, self.Theme
            btn.BackgroundColor3 = th.Elevated -- the sliding indicator draws the active fill
            btn.BackgroundTransparency = 1
            apply(label, { TextColor3 = active and th.Text or th.SubText }, animate)
            if icon then apply(icon, { ImageColor3 = active and th.Accent or th.SubText }, animate) end
        end
        self:_onTheme(btn, function() tab._paint(false) end)

        btn.MouseEnter:Connect(function()
            if self.ActiveTab ~= tab then btn.BackgroundColor3 = self.Theme.Elevated; tween(btn, { BackgroundTransparency = 0.55 }) end
        end)
        btn.MouseLeave:Connect(function()
            if self.ActiveTab ~= tab then tween(btn, { BackgroundTransparency = 1 }) end
        end)
        btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)

        local page = New("ScrollingFrame", { Parent = self._pages, Visible = false, Size = UDim2.fromScale(1, 1), ScrollingDirection = Enum.ScrollingDirection.Y })
        self:_bind(page, "ScrollBarImageColor3", "Stroke")
        pad(page, 10, 12, 10, 12)
        layout(page, 6)
        tab.Page = page

        table.insert(self.Tabs, tab)
        if #self.Tabs == 1 then self:SelectTab(tab) end
        return tab
    end

    function Window:AddTabGroup(title)
        self._navOrder += 1
        local label = self:_text(self._tabList, string.upper(tostring(title or "GROUP")), 9, FONT_BOLD, "SubText")
        label.LayoutOrder = self._navOrder
        pad(label, 10, 0, 2, 10)
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
        tab:AddSlider({ Title = "Corner radius", Description = "0 = sharp, 28 = very round", Min = 0, Max = 28, Default = self.CornerRadius, Suffix = "px", Callback = function(v) self:SetCornerRadius(v) end })
        tab:AddSection("Animations")
        tab:AddToggle({ Title = "Animations", Default = ANIM.on, Callback = function(v) self:SetAnimations(v) end })
        tab:AddSlider({ Title = "Animation speed", Min = 0.5, Max = 2, Increment = 0.1, Default = ANIM.speed, Suffix = "x", Callback = function(v) self:SetAnimationSpeed(v) end })
        tab:AddSection("Window")
        tab:AddKeybind({ Title = "Toggle key", Default = self.ToggleKey, Changed = function(k) self.ToggleKey = k end })
        tab:AddToggle({ Title = "Start minimized", Default = false, Callback = function(on) self:SetMinimized(on) end })
        tab:AddButton({ Title = "Recenter window", Callback = function() self:Center() end })
        return tab
    end

    ------------------------------------------------------------------ elements: shared
    function Tab:_next() self._order += 1; return self._order end

    function Tab:_registerState(cfg, widget)
        if cfg.NoSave or type(widget) ~= "table" or type(widget.Get) ~= "function" or type(widget.Set) ~= "function" then
            return widget
        end
        local states = self.Window._stateWidgets
        local baseKey = tostring(self.Title or "Tab") .. "/" .. tostring(cfg.ConfigKey or cfg.Title or cfg.Text or "Setting")
        local key, n = baseKey, 2
        while states[key] do key = baseKey .. " (" .. n .. ")"; n += 1 end
        states[key] = widget
        table.insert(self._root._keys, key)
        return widget
    end

    function Tab:Clear()
        for _, c in ipairs(self.Page:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
        end
        self._order = 0
        local root = self._root
        if root == self then
            for _, k in ipairs(root._keys) do self.Window._stateWidgets[k] = nil end
            root._keys = {}
        end
    end

    -- Returns tab-like column objects: every Add* method works on them.
    function Tab:AddColumns(n, gap)
        n = math.max(1, math.floor(tonumber(n) or 1))
        gap = math.max(0, tonumber(gap) or 8)
        local row = New("Frame", { Parent = self.Page, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = self:_next() })
        layout(row, gap, true)
        local cols = {}
        for i = 1, n do
            local col = New("Frame", { Parent = row, BackgroundTransparency = 1, Size = UDim2.new(1 / n, -(gap * (n - 1) / n), 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = i })
            layout(col, 6)
            cols[i] = setmetatable({ Window = self.Window, Title = self.Title, Page = col, Frame = col, _order = 0, _root = self._root }, Tab)
        end
        return cols
    end

    function Tab:_card(cfg, ctrlW, class)
        local w = self.Window
        local card = New(class or "Frame", { Parent = self.Page, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = self:_next() })
        w:_bind(card, "BackgroundColor3", "Surface")
        w:_corner(card, 0.35)
        pad(card, 10, 12)
        layout(card, 6)

        local header = New("Frame", { Name = "Header", Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), AutomaticSize = AUTO_Y, LayoutOrder = 1 })
        local texts = New("Frame", { Parent = header, BackgroundTransparency = 1, Size = UDim2.new(1, ctrlW > 0 and -(ctrlW + 10) or 0, 0, 0), AutomaticSize = AUTO_Y })
        layout(texts, 2)
        local hasDesc = cfg.Description and cfg.Description ~= ""
        pad(texts, hasDesc and 1 or 4, 0, hasDesc and 1 or 4, 0)
        local titleLabel = w:_text(texts, cfg.Title or cfg.Text or "", 13, FONT_MED, "Text")
        titleLabel.LayoutOrder = 1
        if hasDesc and titleLabel.Text == "" then titleLabel.Visible = false end
        local descLabel
        if hasDesc then
            descLabel = w:_text(texts, cfg.Description, 11, FONT, "SubText")
            descLabel.LayoutOrder = 2
        end
        return card, header, titleLabel, descLabel
    end

    function Tab:_hover(card)
        local w = self.Window
        local hovered = false
        card.MouseEnter:Connect(function() hovered = true; tween(card, { BackgroundColor3 = w.Theme.Elevated }) end)
        card.MouseLeave:Connect(function() hovered = false; tween(card, { BackgroundColor3 = w.Theme.Surface }) end)
        card.MouseButton1Down:Connect(function() tween(card, { BackgroundColor3 = w.Theme.Stroke }, TweenInfo.new(0.06)) end)
        card.MouseButton1Up:Connect(function() tween(card, { BackgroundColor3 = hovered and w.Theme.Elevated or w.Theme.Surface }) end)
    end

    -- Styled text box: elevated fill, accent outline on focus.
    local function styleBox(w, box, padV, padH, radius)
        pad(box, padV, padH, padV, padH)
        w:_corner(box, radius or 0.45)
        w:_bind(box, "BackgroundColor3", "Elevated")
        w:_bind(box, "TextColor3", "Text")
        w:_bind(box, "PlaceholderColor3", "SubText")
        local st = w:_stroke(box, "Accent")
        st.Transparency = 1
        box.Focused:Connect(function() tween(st, { Transparency = 0 }) end)
        box.FocusLost:Connect(function() tween(st, { Transparency = 1 }) end)
    end

    local function textObj(box, cfg)
        return {
            Get = function() return box.Text end,
            Set = function(_, t) box.Text = tostring(t or ""); safe(cfg.Callback, box.Text, false) end,
        }
    end

    ------------------------------------------------------------------ elements
    function Tab:AddSection(name)
        local l = self.Window:_text(self.Page, string.upper(tostring(name)), 10, FONT_BOLD, "SubText")
        l.LayoutOrder = self:_next()
        pad(l, 8, 0, 0, 4)
        return l
    end

    function Tab:AddDivider()
        local f = New("Frame", { Parent = self.Page, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = self:_next() })
        self.Window:_bind(f, "BackgroundColor3", "Stroke")
        return f
    end

    function Tab:AddSpacer(px)
        return New("Frame", { Parent = self.Page, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, px or 8), LayoutOrder = self:_next() })
    end

    function Tab:AddLabel(text)
        local card, _, title = self:_card({ Title = text }, 0)
        return {
            Set = function(_, t) title.Text = tostring(t) end,
            Get = function() return title.Text end,
            Destroy = function() card:Destroy() end,
        }
    end

    function Tab:AddParagraph(cfg)
        if type(cfg) == "string" then cfg = { Description = cfg } end
        local card, _, title, desc = self:_card(cfg, 0)
        return {
            Set = function(_, t) local l = desc or title; l.Text = tostring(t) end,
            Get = function() return (desc or title).Text end,
            Destroy = function() card:Destroy() end,
        }
    end

    function Tab:AddButton(cfg)
        local card, header = self:_card(cfg, 20, "TextButton")
        self:_hover(card)
        local chev = New("TextLabel", rightAnchored({ Parent = header, Size = UDim2.fromOffset(16, 20), Text = "›", Font = FONT_BOLD, TextSize = 20 }))
        self.Window:_bind(chev, "TextColor3", "Accent")
        card.MouseButton1Click:Connect(function()
            tween(chev, { Position = UDim2.new(1, 4, 0.5, 0) }, TweenInfo.new(0.07))
            task.delay(0.09, function() if chev.Parent then tween(chev, { Position = UDim2.new(1, 0, 0.5, 0) }) end end)
            safe(cfg.Callback)
        end)
        return { Fire = function() safe(cfg.Callback) end }
    end

    function Tab:AddToggle(cfg)
        local w = self.Window
        local card, header = self:_card(cfg, 46, "TextButton")
        self:_hover(card)
        local track = New("Frame", rightAnchored({ Parent = header, Size = UDim2.fromOffset(36, 20) }))
        w:_corner(track, "pill")
        local thumb = New("Frame", { Parent = track, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(14, 14) })
        w:_corner(thumb, "pill")

        local obj = { Value = cfg.Default == true }
        local function paint(animate)
            local th, on = w.Theme, obj.Value
            apply(track, { BackgroundColor3 = on and th.Accent or th.Stroke }, animate)
            apply(thumb, { BackgroundColor3 = on and th.AccentText or th.SubText, Position = UDim2.new(0, on and 19 or 3, 0.5, 0) }, animate)
        end
        w:_onTheme(track, function() paint(false) end)

        function obj:Set(v, silent)
            obj.Value = v and true or false
            paint(true)
            if not silent then safe(cfg.Callback, obj.Value) end
        end
        function obj:Get() return obj.Value end
        function obj:Toggle() obj:Set(not obj.Value) end
        card.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
        if cfg.CallOnInit then safe(cfg.Callback, obj.Value) end
        return self:_registerState(cfg, obj)
    end

    function Tab:AddSlider(cfg)
        local w = self.Window
        local min, max, inc = cfg.Min or 0, cfg.Max or 100, cfg.Increment or 1
        local card, header = self:_card(cfg, 70)
        local valueLabel = New("TextLabel", rightAnchored({ Parent = header, Size = UDim2.fromOffset(64, 20), TextXAlignment = RIGHT }))
        w:_bind(valueLabel, "TextColor3", "Accent")

        local hit = New("TextButton", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 })
        local bar = New("Frame", { Parent = hit, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 4) })
        w:_corner(bar, "pill"); w:_bind(bar, "BackgroundColor3", "Stroke")
        local fill = New("Frame", { Parent = bar, Size = UDim2.fromScale(0, 1) })
        w:_corner(fill, "pill"); w:_bind(fill, "BackgroundColor3", "Accent")
        local knob = New("Frame", { Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), Position = UDim2.fromScale(0, 0.5) })
        w:_corner(knob, "pill"); w:_bind(knob, "BackgroundColor3", "Text")

        local obj = { Value = min }
        local function set(v, silent, force)
            v = math.clamp(min + math.floor((v - min) / inc + 0.5) * inc, min, max)
            v = tonumber(string.format("%.4f", v))
            local changed = v ~= obj.Value
            obj.Value = v
            local a = max == min and 0 or (v - min) / (max - min)
            fill.Size = UDim2.fromScale(a, 1)
            knob.Position = UDim2.fromScale(a, 0.5)
            valueLabel.Text = formatNumber(v) .. (cfg.Suffix or "")
            if not silent and (changed or force) then safe(cfg.Callback, v) end
        end
        local function fromX(x)
            set(min + (max - min) * math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1))
        end
        hit.InputBegan:Connect(function(i)
            if isPress(i) then
                fromX(i.Position.X)
                tween(knob, { Size = UDim2.fromOffset(16, 16) }, TI)
                beginDrag(function(p) fromX(p.X) end, function() tween(knob, { Size = UDim2.fromOffset(12, 12) }, TI) end)
            end
        end)

        obj.Value = nil
        set(cfg.Default or min, not cfg.CallOnInit, true)
        function obj:Set(v, silent) set(v, silent, true) end
        function obj:Get() return obj.Value end
        return self:_registerState(cfg, obj)
    end

    function Tab:AddDropdown(cfg)
        local w = self.Window
        local card, header = self:_card(cfg, 140)
        local multi, values = cfg.Multi == true, cfg.Values or {}
        local selected, value = {}, nil
        if multi then for _, v in ipairs(cfg.Default or {}) do selected[v] = true end else value = cfg.Default end

        local box = New("TextButton", rightAnchored({ Parent = header, Size = UDim2.fromOffset(130, 26) }))
        w:_corner(box, 0.45); w:_bind(box, "BackgroundColor3", "Elevated")
        local boxLabel = New("TextLabel", { Parent = box, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -28, 1, 0), TextSize = 12, TextXAlignment = LEFT, TextTruncate = Enum.TextTruncate.AtEnd })
        w:_bind(boxLabel, "TextColor3", "Text")
        local arrow = New("TextLabel", { Parent = box, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(14, 16), Text = "›", Font = FONT_BOLD, TextSize = 16, Rotation = 90 })
        w:_bind(arrow, "TextColor3", "SubText")

        local listFrame = New("ScrollingFrame", { Parent = card, Visible = false, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2 })
        w:_bind(listFrame, "ScrollBarImageColor3", "Stroke")
        layout(listFrame, 4)

        local obj, entries, dirty, isOpen, token = {}, {}, true, false, 0

        local function isSel(v) if multi then return selected[v] == true end return value == v end
        local function display()
            if multi then
                local t = {}
                for _, v in ipairs(values) do if selected[v] then t[#t + 1] = tostring(v) end end
                boxLabel.Text = #t == 0 and "None" or table.concat(t, ", ")
            else
                boxLabel.Text = value ~= nil and tostring(value) or "Select"
            end
        end
        local function paintOne(v, b)
            local s = isSel(v)
            b.BackgroundColor3 = w.Theme.Elevated
            b.BackgroundTransparency = s and 0 or 1
            b.TextColor3 = s and w.Theme.Accent or w.Theme.Text
        end
        local function repaint() for _, e in ipairs(entries) do paintOne(e[1], e[2]) end end
        local function targetHeight() return math.min(#values * 32, 140) end

        local setOpen
        local function choose(v)
            if multi then selected[v] = not selected[v] or nil else value = v; setOpen(false) end
            display(); repaint()
            safe(cfg.Callback, obj:Get())
        end
        local function build() -- options are only created when the list is first opened
            for _, e in ipairs(entries) do e[2]:Destroy() end
            entries = {}
            for i, v in ipairs(values) do
                local b = New("TextButton", { Parent = listFrame, Size = UDim2.new(1, -6, 0, 28), Text = tostring(v), TextXAlignment = LEFT, LayoutOrder = i })
                pad(b, 0, 10, 0, 10)
                w:_corner(b, 0.4)
                entries[i] = { v, b }
                b.MouseEnter:Connect(function()
                    if not isSel(v) then b.BackgroundColor3 = w.Theme.Elevated; b.BackgroundTransparency = 0.5 end
                end)
                b.MouseLeave:Connect(function() paintOne(v, b) end)
                b.MouseButton1Click:Connect(function() choose(v) end)
            end
            dirty = false
            repaint()
        end
        setOpen = function(open)
            if open and dirty then build() end
            isOpen = open
            token += 1
            local t = token
            tween(arrow, { Rotation = open and -90 or 90 })
            if open then
                listFrame.Visible = true
                tween(listFrame, { Size = UDim2.new(1, 0, 0, targetHeight()) })
            else
                tween(listFrame, { Size = UDim2.new(1, 0, 0, 0) })
                task.delay(T(0.16), function() if t == token and listFrame.Parent then listFrame.Visible = false end end)
            end
        end

        function obj:Get()
            if not multi then return value end
            local t = {}
            for _, v in ipairs(values) do if selected[v] then t[#t + 1] = v end end
            return t
        end
        function obj:SetValues(v)
            values = v; dirty = true
            if isOpen then build(); tween(listFrame, { Size = UDim2.new(1, 0, 0, targetHeight()) }) end
            display()
        end
        function obj:Set(v, silent)
            if multi then
                selected = {}
                if type(v) == "table" then for _, x in ipairs(v) do selected[x] = true end end
            else
                value = v
            end
            display(); repaint()
            if not silent then safe(cfg.Callback, obj:Get()) end
        end

        box.MouseButton1Click:Connect(function() setOpen(not isOpen) end)
        w:_onTheme(listFrame, repaint)
        display()
        return self:_registerState(cfg, obj)
    end

    function Tab:AddInput(cfg)
        local w = self.Window
        local _, header = self:_card(cfg, 150)
        local box = New("TextBox", rightAnchored({
            Parent = header, Size = UDim2.fromOffset(140, 26), Text = cfg.Default or "",
            PlaceholderText = cfg.Placeholder or "Type here...", ClearTextOnFocus = cfg.ClearOnFocus == true, ClipsDescendants = true,
            TextXAlignment = LEFT,
        }))
        styleBox(w, box, 0, 9)
        box.FocusLost:Connect(function(enter) safe(cfg.Callback, box.Text, enter) end)
        return self:_registerState(cfg, textObj(box, cfg))
    end

    function Tab:AddTextArea(cfg)
        local w = self.Window
        local card = self:_card(cfg, 0)
        local box = New("TextBox", {
            Parent = card, Size = UDim2.new(1, 0, 0, cfg.Height or 90), Text = cfg.Default or "",
            PlaceholderText = cfg.Placeholder or "Write something...", TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Top,
            MultiLine = true, LayoutOrder = 2, ClipsDescendants = true,
        })
        styleBox(w, box, 8, 10, 0.35)
        box.FocusLost:Connect(function(enter) safe(cfg.Callback, box.Text, enter) end)
        return self:_registerState(cfg, textObj(box, cfg))
    end

    function Tab:AddCodeBox(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title or "Code", Description = cfg.Description }, 0)
        local box = New("TextBox", {
            Parent = card, Size = UDim2.new(1, 0, 0, cfg.Height or 110), Text = cfg.Default or "", Font = Enum.Font.Code,
            PlaceholderText = cfg.Placeholder or "-- code here", TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Top,
            MultiLine = true, LayoutOrder = 2, ClipsDescendants = true,
        })
        styleBox(w, box, 8, 10, 0.35)
        box.FocusLost:Connect(function(enter) safe(cfg.Callback, box.Text, enter) end)
        return self:_registerState(cfg, textObj(box, cfg))
    end

    function Tab:AddKeybind(cfg)
        local w = self.Window
        local _, header = self:_card(cfg, 90)
        local key, listening = cfg.Default or Enum.KeyCode.Unknown, false
        local btn = New("TextButton", rightAnchored({ Parent = header, Size = UDim2.fromOffset(80, 26), Text = key.Name, TextSize = 12 }))
        w:_corner(btn, 0.45)
        w:_bind(btn, "BackgroundColor3", "Elevated")
        w:_bind(btn, "TextColor3", "Accent")
        btn.MouseButton1Click:Connect(function() listening = true; w._rebinding = true; btn.Text = "..." end)
        table.insert(w._inputs, function(input, gpe)
            if not btn.Parent then return true end -- widget was destroyed: drop this handler
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
            Set = function(_, k) key = k; btn.Text = k.Name; safe(cfg.Changed, k) end,
        })
    end

    function Tab:AddColorPicker(cfg)
        local w = self.Window
        local card, header = self:_card(cfg, 44)
        local current = cfg.Default or Color3.fromRGB(129, 102, 255)
        local h, s, v = current:ToHSV()

        local swatch = New("TextButton", rightAnchored({ Parent = header, Size = UDim2.fromOffset(40, 22) }))
        w:_corner(swatch, 0.4)
        w:_stroke(swatch, "Stroke")

        local panel = New("Frame", { Parent = card, BackgroundTransparency = 1, Visible = false, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = 2 })
        layout(panel, 8)

        local hexBox = New("TextBox", { Parent = panel, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 1 })
        styleBox(w, hexBox, 0, 9, 0.4)

        local function makeBar(order, letter)
            local row = New("Frame", { Parent = panel, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = order })
            local lbl = New("TextLabel", { Parent = row, Size = UDim2.new(0, 14, 1, 0), Text = letter, Font = FONT_BOLD, TextSize = 10, TextXAlignment = LEFT })
            w:_bind(lbl, "TextColor3", "SubText")
            local hit = New("TextButton", { Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -18, 1, 0) })
            local bar = New("Frame", { Parent = hit, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Color3.new(1, 1, 1) })
            w:_corner(bar, "pill")
            local grad = New("UIGradient", { Parent = bar })
            local knob = New("Frame", { Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1) })
            w:_corner(knob, "pill")
            w:_stroke(knob, "Surface", 2)
            return hit, bar, grad, knob
        end

        local hHit, hBar, hGrad, hKnob = makeBar(2, "H")
        local sHit, sBar, sGrad, sKnob = makeBar(3, "S")
        local vHit, vBar, vGrad, vKnob = makeBar(4, "V")

        local rainbow = {}
        for i = 0, 6 do rainbow[#rainbow + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)) end
        hGrad.Color = ColorSequence.new(rainbow)

        local function render()
            swatch.BackgroundColor3 = current
            hexBox.Text = color3ToHex(current)
            sGrad.Color = ColorSequence.new(Color3.fromHSV(h, 0, v), Color3.fromHSV(h, 1, v))
            vGrad.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(h, s, 1))
            hKnob.Position = UDim2.fromScale(h, 0.5)
            sKnob.Position = UDim2.fromScale(s, 0.5)
            vKnob.Position = UDim2.fromScale(v, 0.5)
        end
        local function setColor(c)
            current = c
            local nh, ns, nv = c:ToHSV()
            if ns > 0 and nv > 0 then h = nh end -- keep hue when colour is grey/black
            s, v = ns, nv
            render()
        end
        local function push() safe(cfg.Callback, current) end

        local function bindBar(hit, bar, which)
            local function at(px)
                local a = math.clamp((px - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
                if which == "h" then h = a elseif which == "s" then s = a else v = a end
                current = Color3.fromHSV(h, s, v)
                render()
                if cfg.Live then push() end
            end
            hit.InputBegan:Connect(function(i)
                if isPress(i) then
                    at(i.Position.X)
                    beginDrag(function(p) at(p.X) end, function() if not cfg.Live then push() end end)
                end
            end)
        end
        bindBar(hHit, hBar, "h"); bindBar(sHit, sBar, "s"); bindBar(vHit, vBar, "v")

        hexBox.FocusLost:Connect(function()
            local c = hexToColor3(hexBox.Text)
            if c then setColor(c); push() else render() end
        end)
        swatch.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)

        render()
        return self:_registerState(cfg, {
            Get = function() return current end,
            Set = function(_, c, silent) setColor(c); if not silent then push() end end,
        })
    end

    function Tab:AddProgressBar(cfg)
        local w = self.Window
        local card, header = self:_card(cfg, 60)
        local val = cfg.Default or 0
        local pct = New("TextLabel", rightAnchored({ Parent = header, Size = UDim2.fromOffset(60, 20), TextXAlignment = RIGHT }))
        w:_bind(pct, "TextColor3", "Accent")
        local bar = New("Frame", { Parent = card, Size = UDim2.new(1, 0, 0, 6), LayoutOrder = 2, ClipsDescendants = true })
        w:_corner(bar, "pill"); w:_bind(bar, "BackgroundColor3", "Stroke")
        local fill = New("Frame", { Parent = bar, Size = UDim2.fromScale(0, 1) })
        w:_corner(fill, "pill"); w:_bind(fill, "BackgroundColor3", "Accent")
        local loop
        local function setVal(x, animate)
            val = math.clamp(x, 0, 1)
            apply(fill, { Size = UDim2.fromScale(val, 1) }, animate)
            pct.Text = string.format("%d%%", math.floor(val * 100 + 0.5))
        end
        local obj = {}
        function obj:Set(x) if not loop then setVal(x, true) else val = math.clamp(x, 0, 1) end end
        function obj:Get() return val end
        function obj:SetIndeterminate(on)
            if loop then loop:Cancel(); loop = nil end
            if on then
                fill.Size = UDim2.fromScale(0.35, 1)
                fill.Position = UDim2.fromScale(-0.35, 0)
                pct.Text = ""
                loop = TweenService:Create(fill, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), { Position = UDim2.fromScale(1, 0) })
                loop:Play()
            else
                fill.Position = UDim2.fromScale(0, 0)
                setVal(val, false)
            end
        end
        setVal(val, false)
        if cfg.Indeterminate then obj:SetIndeterminate(true) end
        return self:_registerState(cfg, obj)
    end

    function Tab:AddRadioGroup(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description }, 0)
        local selected, rows = cfg.Default, {}
        local list = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = 2 })
        layout(list, 2)
        local function repaint()
            for _, r in ipairs(rows) do
                local sel = r.value == selected
                r.dot.BackgroundColor3 = sel and w.Theme.Accent or w.Theme.Stroke
                r.inner.Visible = sel
                r.inner.BackgroundColor3 = w.Theme.AccentText
                r.label.TextColor3 = sel and w.Theme.Text or w.Theme.SubText
            end
        end
        for i, value in ipairs(cfg.Values or {}) do
            local row = New("TextButton", { Parent = list, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i })
            local dot = New("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14) })
            w:_corner(dot, "pill")
            local inner = New("Frame", { Parent = dot, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), Visible = false })
            w:_corner(inner, "pill")
            local label = New("TextLabel", { Parent = row, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), Text = tostring(value), TextXAlignment = LEFT })
            rows[i] = { value = value, dot = dot, inner = inner, label = label }
            row.MouseButton1Click:Connect(function() selected = value; repaint(); safe(cfg.Callback, value) end)
        end
        w:_onTheme(list, repaint)
        return self:_registerState(cfg, {
            Get = function() return selected end,
            Set = function(_, x, silent) selected = x; repaint(); if not silent then safe(cfg.Callback, x) end end,
        })
    end

    function Tab:AddCheckboxGroup(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description }, 0)
        local values, state, rows = cfg.Values or {}, {}, {}
        for _, x in ipairs(cfg.Default or {}) do state[x] = true end
        local list = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = 2 })
        layout(list, 2)
        local function collect()
            local out = {}
            for _, x in ipairs(values) do if state[x] then out[#out + 1] = x end end
            return out
        end
        local function repaint()
            for _, r in ipairs(rows) do
                local on = state[r.value] == true
                r.box.BackgroundColor3 = on and w.Theme.Accent or w.Theme.Stroke
                r.tick.Visible = on
                r.tick.TextColor3 = w.Theme.AccentText
                r.label.TextColor3 = on and w.Theme.Text or w.Theme.SubText
            end
        end
        for i, value in ipairs(values) do
            local row = New("TextButton", { Parent = list, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = i })
            local box = New("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14) })
            w:_corner(box, 0.3)
            local tick = New("TextLabel", { Parent = box, Size = UDim2.fromScale(1, 1), Text = "✓", Font = FONT_BOLD, TextSize = 11, Visible = false })
            local label = New("TextLabel", { Parent = row, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), Text = tostring(value), TextXAlignment = LEFT })
            rows[i] = { value = value, box = box, tick = tick, label = label }
            row.MouseButton1Click:Connect(function()
                state[value] = not state[value] or nil
                repaint()
                safe(cfg.Callback, collect())
            end)
        end
        w:_onTheme(list, repaint)
        return self:_registerState(cfg, {
            Get = collect,
            Set = function(_, vals, silent)
                state = {}
                if type(vals) == "table" then for _, x in ipairs(vals) do state[x] = true end end
                repaint()
                if not silent then safe(cfg.Callback, collect()) end
            end,
        })
    end

    function Tab:AddNumberStepper(cfg)
        local w = self.Window
        local _, header = self:_card(cfg, 130)
        local min, max, inc = cfg.Min or 0, cfg.Max or 999, cfg.Increment or 1
        local value = cfg.Default or min
        local row = New("Frame", rightAnchored({ Parent = header, Size = UDim2.fromOffset(120, 26), BackgroundTransparency = 1 }))
        layout(row, 4, true)
        local function mk(order, props, class)
            props.Parent = row; props.LayoutOrder = order
            local o = New(class or "TextButton", props)
            w:_corner(o, 0.4); w:_bind(o, "BackgroundColor3", "Elevated"); w:_bind(o, "TextColor3", "Text")
            return o
        end
        local minus = mk(1, { Size = UDim2.fromOffset(26, 26), Text = "−", Font = FONT_BOLD, TextSize = 16 })
        local box   = mk(2, { Size = UDim2.fromOffset(60, 26) }, "TextBox")
        local plus  = mk(3, { Size = UDim2.fromOffset(26, 26), Text = "+", Font = FONT_BOLD, TextSize = 16 })

        local function setVal(x, silent)
            x = math.clamp(x, min, max)
            x = tonumber(string.format("%.4f", min + math.floor((x - min) / inc + 0.5) * inc))
            value = x
            box.Text = formatNumber(x)
            if not silent then safe(cfg.Callback, x) end
        end
        minus.MouseButton1Click:Connect(function() setVal(value - inc) end)
        plus.MouseButton1Click:Connect(function() setVal(value + inc) end)
        box.FocusLost:Connect(function() setVal(tonumber(box.Text) or value) end)
        setVal(value, true)
        return self:_registerState(cfg, {
            Get = function() return value end,
            Set = function(_, x, silent) setVal(x, silent) end,
        })
    end

    function Tab:AddMultiInput(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description }, 0)
        local boxes, order = {}, {}
        local container = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = 2 })
        layout(container, 6)
        local function collect()
            local t = {}
            for _, k in ipairs(order) do t[k] = boxes[k].Text end
            return t
        end
        for i, spec in ipairs(cfg.Fields or {}) do
            local k = spec.Key or spec.Name
            local row = New("Frame", { Parent = container, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = i })
            local lbl = New("TextLabel", { Parent = row, Size = UDim2.new(0.4, -6, 1, 0), Text = spec.Name, TextSize = 12, TextXAlignment = LEFT })
            w:_bind(lbl, "TextColor3", "SubText")
            local box = New("TextBox", { Parent = row, Position = UDim2.fromScale(0.4, 0), Size = UDim2.fromScale(0.6, 1), Text = spec.Default or "", PlaceholderText = spec.Placeholder or "", TextXAlignment = LEFT, ClipsDescendants = true })
            styleBox(w, box, 0, 8, 0.4)
            boxes[k] = box
            order[#order + 1] = k
            box.FocusLost:Connect(function(enter) safe(cfg.Callback, collect(), enter) end)
        end
        return self:_registerState(cfg, {
            Get = collect,
            Set = function(_, t)
                if type(t) ~= "table" then error("expected a table of input values") end
                for k, box in pairs(boxes) do if t[k] ~= nil then box.Text = tostring(t[k]) end end
                safe(cfg.Callback, collect(), false)
            end,
        })
    end

    function Tab:AddSearchBox(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title or "Search", Description = cfg.Description }, 0)
        local box = New("TextBox", { Parent = card, Size = UDim2.new(1, 0, 0, 28), PlaceholderText = cfg.Placeholder or "Search...", LayoutOrder = 2, TextXAlignment = LEFT, ClipsDescendants = true })
        styleBox(w, box, 0, 10, 0.4)
        local results = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = 3 })
        layout(results, 2)

        local values, maxResults, rows = cfg.Values or {}, cfg.MaxResults or 8, {}
        for i = 1, maxResults do -- pooled rows: never destroyed/recreated while typing
            local b = New("TextButton", { Parent = results, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), TextXAlignment = LEFT, LayoutOrder = i, Visible = false })
            w:_bind(b, "TextColor3", "SubText")
            b.MouseButton1Click:Connect(function() box.Text = b.Text; safe(cfg.OnSelect, b.Text) end)
            rows[i] = b
        end
        local function rebuild()
            local q, n = box.Text:lower(), 0
            for _, val in ipairs(values) do
                if n >= maxResults then break end
                local str = tostring(val)
                if q == "" or str:lower():find(q, 1, true) then
                    n += 1
                    rows[n].Text = str
                    rows[n].Visible = true
                end
            end
            for i = n + 1, maxResults do rows[i].Visible = false end
        end
        box:GetPropertyChangedSignal("Text"):Connect(function() rebuild(); safe(cfg.Callback, box.Text) end)
        rebuild()
        return {
            Get = function() return box.Text end,
            Set = function(_, t) box.Text = tostring(t or "") end,
            SetValues = function(_, v) values = v; rebuild() end,
        }
    end

    ------------------------------------------------------------------ graphs
    local PALETTE = { rgb(56,189,248), rgb(52,211,153), rgb(251,176,52), rgb(251,86,140), rgb(186,104,255), rgb(255,122,74) }

    local function pickColor(w, i, c)
        if c then return c end
        if i == 1 then return w.Theme.Accent end
        return PALETTE[(i - 2) % #PALETTE + 1]
    end

    local function shortNumber(v)
        local a = math.abs(v)
        if a >= 1e9 then return string.format("%.1fB", v / 1e9) end
        if a >= 1e6 then return string.format("%.1fM", v / 1e6) end
        if a >= 1e4 then return string.format("%.1fK", v / 1e3) end
        if v == math.floor(v) or a >= 100 then return string.format("%d", math.floor(v + 0.5)) end
        return string.format("%.1f", v)
    end

    local function fmtValue(cfg, v)
        if cfg.Format then return tostring(cfg.Format(v)) end
        return formatNumber(v) .. (cfg.Suffix or "")
    end

    local function esc(s) -- RichText escape
        s = tostring(s):gsub("&", "&amp;")
        s = s:gsub("<", "&lt;")
        return (s:gsub(">", "&gt;"))
    end

    --[[
        AddLineGraph({
            Title, Description, Height = 140,
            Values = {..}                      -- one series, or
            Series = { { Name, Color, Values } },
            Labels = {..}                      -- optional x labels (tooltip)
            MaxPoints = 60                     -- realtime mode: newest point enters from the right
            Min, Max                           -- fixed y range (otherwise auto)
            Fill = true | false | "all", Dots = true, Thickness = 2,
            Suffix, Format = function(v), AxisFormat = function(v),
            ShowLatest = true, Legend = true, Animate = true,
        })
        graph:SetData(valuesOrSeries)  graph:Push(value, seriesIndex)  graph:Clear()  graph:Replay()
    ]]
    function Tab:AddLineGraph(cfg)
        local w, root = self.Window, self._root
        local H, GUTTER, INSET = cfg.Height or 140, 36, 3
        local realtime = cfg.MaxPoints ~= nil
        local maxPts = cfg.MaxPoints or 120
        local thick = cfg.Thickness or 2
        local axisFmt = cfg.AxisFormat or shortNumber
        local showLatest = cfg.ShowLatest ~= false

        local card, header = self:_card(cfg, showLatest and 84 or 0)
        local latest
        if showLatest then
            latest = New("TextLabel", rightAnchored({ Parent = header, Size = UDim2.fromOffset(84, 20), TextXAlignment = RIGHT }))
            w:_bind(latest, "TextColor3", "Accent")
        end

        local area = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, H), LayoutOrder = 2 })
        local axisLabels = {}
        for k, ys in ipairs({ 0, 0.5, 1 }) do
            local l = New("TextLabel", {
                Parent = area, AnchorPoint = Vector2.new(0, 0.5), TextSize = 10, TextXAlignment = RIGHT,
                Position = UDim2.new(0, 0, ys, ys == 0 and 4 or (ys == 1 and -4 or 0)), Size = UDim2.fromOffset(GUTTER - 6, 12),
            })
            w:_bind(l, "TextColor3", "SubText")
            axisLabels[k] = l
        end

        local plot = New("Frame", { Parent = area, BackgroundTransparency = 1, Position = UDim2.fromOffset(GUTTER, 4), Size = UDim2.new(1, -GUTTER, 1, -8) })
        for _, ys in ipairs({ 0, 0.5, 1 }) do
            local g = New("Frame", { Parent = plot, AnchorPoint = Vector2.new(0, ys), Position = UDim2.fromScale(0, ys), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.5 })
            w:_bind(g, "BackgroundColor3", "Stroke")
        end
        local clip = New("Frame", { Parent = plot, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true })

        -- hover widgets
        local hoverLine = New("Frame", { Parent = plot, Visible = false, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundTransparency = 0.5, ZIndex = 5 })
        w:_bind(hoverLine, "BackgroundColor3", "SubText")
        local tip = New("Frame", { Parent = plot, Visible = false, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 10 })
        w:_bind(tip, "BackgroundColor3", "Elevated")
        w:_corner(tip, 0.4)
        w:_stroke(tip, "Stroke")
        pad(tip, 5, 8)
        local tipText = New("TextLabel", { Parent = tip, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), RichText = true, TextSize = 11, TextXAlignment = LEFT })
        w:_bind(tipText, "TextColor3", "Text")
        local hoverDots = {}

        local legend = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = 3, Visible = false })
        layout(legend, 12, true).Wraps = true

        local series, pools, legendItems = {}, {}, {}
        local layoutInfo = { W = 0, step = 1, maxN = 0, pts = {} }
        local dirty, scheduled, hoverX = false, false, nil

        local function normalize(d)
            local out = {}
            if type(d) == "table" and type(d[1]) == "table" then
                for i, s in ipairs(d) do
                    out[i] = { Name = s.Name or ("Series " .. i), Color = s.Color, Values = table.clone(s.Values or {}) }
                end
            else
                out[1] = { Name = cfg.SeriesName or cfg.Title or "Value", Color = cfg.Color, Values = type(d) == "table" and table.clone(d) or {} }
            end
            return out
        end

        local function updateLatest()
            if not latest then return end
            local s = series[1]
            local v = s and s.Values[#s.Values]
            latest.Text = v ~= nil and fmtValue(cfg, v) or "-"
        end

        local function rebuildLegend()
            for _, l in ipairs(legendItems) do l:Destroy() end
            legendItems = {}
            legend.Visible = #series > 1 and cfg.Legend ~= false
            for i, s in ipairs(series) do
                local l = New("TextLabel", {
                    Parent = legend, AutomaticSize = AUTO_X, Size = UDim2.fromOffset(0, 14), RichText = true, TextSize = 11, LayoutOrder = i,
                    Text = string.format('<font color="%s">●</font> %s', color3ToHex(pickColor(w, i, s.Color)), esc(s.Name)),
                })
                w:_bind(l, "TextColor3", "SubText")
                legendItems[i] = l
            end
        end

        local function hideHover()
            hoverX = nil
            hoverLine.Visible, tip.Visible = false, false
            for _, d in ipairs(hoverDots) do d.Visible = false end
        end

        local function showHover(screenX)
            if layoutInfo.maxN == 0 then hideHover(); return end
            hoverX = screenX
            local sc = w._scale.Scale
            local x = (screenX - plot.AbsolutePosition.X) / sc
            local W, step = layoutInfo.W, layoutInfo.step
            local lines, lineX, used = {}, nil, 0
            for si, s in ipairs(series) do
                local n = #s.Values
                local pts = layoutInfo.pts[si]
                if n > 0 and pts then
                    local idx
                    if realtime then idx = n - math.floor(((W - INSET) - x) / step + 0.5)
                    else idx = math.floor((x - INSET) / step + 0.5) + 1 end
                    idx = math.clamp(idx, 1, n)
                    local p = pts[idx]
                    if p then
                        used += 1
                        lineX = lineX or p.X
                        local color = pickColor(w, si, s.Color)
                        local dot = hoverDots[used]
                        if not dot then
                            dot = New("Frame", { Parent = plot, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(9, 9), ZIndex = 6 })
                            New("UICorner", { Parent = dot, CornerRadius = UDim.new(1, 0) })
                            w:_stroke(dot, "Surface", 2)
                            hoverDots[used] = dot
                        end
                        dot.Visible = true
                        dot.BackgroundColor3 = color
                        dot.Position = UDim2.fromOffset(p.X, p.Y)
                        local head = (#lines == 0 and cfg.Labels and cfg.Labels[idx]) and (esc(cfg.Labels[idx]) .. "\n") or ""
                        if #series == 1 then
                            lines[#lines + 1] = head .. "<b>" .. esc(fmtValue(cfg, s.Values[idx])) .. "</b>"
                        else
                            lines[#lines + 1] = head .. string.format('<font color="%s">●</font> %s  <b>%s</b>', color3ToHex(color), esc(s.Name), esc(fmtValue(cfg, s.Values[idx])))
                        end
                    end
                end
            end
            for i = used + 1, #hoverDots do hoverDots[i].Visible = false end
            if not lineX then hideHover(); return end
            hoverLine.Visible = true
            hoverLine.Position = UDim2.fromOffset(lineX, 0)
            local right = lineX > W / 2
            tip.AnchorPoint = Vector2.new(right and 1 or 0, 0)
            tip.Position = UDim2.fromOffset(lineX + (right and -10 or 10), 4)
            tipText.Text = table.concat(lines, "\n")
            tip.Visible = true
        end

        local function render()
            scheduled = false
            if w._destroyed then return end
            if w.ActiveTab ~= root then dirty = true; return end
            local sc = w._scale.Scale
            local W, Hp = plot.AbsoluteSize.X / sc, plot.AbsoluteSize.Y / sc
            if W < 12 or Hp < 12 then dirty = true; return end
            dirty = false

            local lo, hi = cfg.Min, cfg.Max
            if lo == nil or hi == nil then
                local mn, mx = math.huge, -math.huge
                for _, s in ipairs(series) do
                    for _, x in ipairs(s.Values) do
                        if x < mn then mn = x end
                        if x > mx then mx = x end
                    end
                end
                if mn == math.huge then mn, mx = 0, 1 end
                if mx == mn then mx = mn + 1 end
                local p = (mx - mn) * 0.08
                if lo == nil then lo = (mn >= 0 and mn - p < 0) and 0 or mn - p end
                if hi == nil then hi = mx + p end
            end
            if hi <= lo then hi = lo + 1 end
            local range = hi - lo
            axisLabels[1].Text, axisLabels[2].Text, axisLabels[3].Text = axisFmt(hi), axisFmt(lo + range / 2), axisFmt(lo)

            local maxN = 0
            for _, s in ipairs(series) do if #s.Values > maxN then maxN = #s.Values end end
            local span = math.max(realtime and maxPts or maxN, 2)
            local step = (W - INSET * 2) / (span - 1)
            layoutInfo.W, layoutInfo.step, layoutInfo.maxN = W, step, maxN
            local yRange = Hp - INSET * 2

            for si, s in ipairs(series) do
                local pool = pools[si]
                if not pool then pool = { segs = {}, dots = {}, fills = {} }; pools[si] = pool end
                local color = pickColor(w, si, s.Color)
                local vals, n = s.Values, #s.Values
                local pts = {}
                for i = 1, n do
                    local x = realtime and (W - INSET - (n - i) * step) or (INSET + (i - 1) * step)
                    local y = INSET + (1 - (vals[i] - lo) / range) * yRange
                    pts[i] = Vector2.new(x, math.clamp(y, 0, Hp))
                end
                layoutInfo.pts[si] = pts

                local showDots = cfg.Dots ~= false and n <= (cfg.DotsMax or 24)
                local doFill = cfg.Fill ~= false and (si == 1 or cfg.Fill == "all")
                for i = 1, n - 1 do
                    local a, b = pts[i], pts[i + 1]
                    local d = b - a
                    local seg = pool.segs[i]
                    if not seg then
                        seg = New("Frame", { Parent = clip, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
                        pool.segs[i] = seg
                    end
                    seg.Visible = true
                    seg.BackgroundColor3 = color
                    seg.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
                    seg.Size = UDim2.fromOffset(d.Magnitude + 1.2, thick)
                    seg.Rotation = math.deg(math.atan2(d.Y, d.X))
                    if doFill then
                        local f = pool.fills[i]
                        if not f then
                            f = New("Frame", { Parent = clip, BackgroundTransparency = 0.88, ZIndex = 1 })
                            pool.fills[i] = f
                        end
                        local top = (a.Y + b.Y) / 2
                        f.Visible = true
                        f.BackgroundColor3 = color
                        f.Position = UDim2.fromOffset(a.X, top)
                        f.Size = UDim2.fromOffset(d.X + 1, math.max(Hp - top, 0))
                    end
                end
                for i = math.max(n, 1), #pool.segs do pool.segs[i].Visible = false end
                for i = doFill and math.max(n, 1) or 1, #pool.fills do pool.fills[i].Visible = false end
                if showDots then
                    for i = 1, n do
                        local dt = pool.dots[i]
                        if not dt then
                            dt = New("Frame", { Parent = clip, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), ZIndex = 4 })
                            New("UICorner", { Parent = dt, CornerRadius = UDim.new(1, 0) })
                            pool.dots[i] = dt
                        end
                        dt.Visible = true
                        dt.BackgroundColor3 = color
                        dt.Position = UDim2.fromOffset(pts[i].X, pts[i].Y)
                    end
                end
                for i = showDots and n + 1 or 1, #pool.dots do pool.dots[i].Visible = false end
            end
            for si = #series + 1, #pools do -- series that were removed
                local pool = pools[si]
                for _, list in pairs(pool) do for _, f in ipairs(list) do f.Visible = false end end
                layoutInfo.pts[si] = nil
            end
            if hoverX then showHover(hoverX) end
        end

        local function schedule()
            if scheduled then return end
            scheduled = true
            task.defer(render)
        end

        local function reveal()
            if cfg.Animate == false then return end
            clip.Size = UDim2.new(0, 0, 1, 0)
            tween(clip, { Size = UDim2.fromScale(1, 1) }, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
        end

        plot.InputChanged:Connect(function(i) if isMove(i) then showHover(i.Position.X) end end)
        plot.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then showHover(i.Position.X) end end)
        plot.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then hideHover() end end)
        plot.MouseLeave:Connect(hideHover)
        plot:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule)
        table.insert(root._onShow, function()
            if dirty then render() end
            reveal()
        end)

        local obj = {}
        function obj:SetData(d, noReveal)
            series = normalize(d)
            rebuildLegend(); updateLatest(); schedule()
            if not noReveal then reveal() end
        end
        function obj:Push(v, si)
            local s = series[si or 1]
            if not s then return end
            s.Values[#s.Values + 1] = v
            if #s.Values > maxPts then table.remove(s.Values, 1) end
            updateLatest(); schedule()
        end
        function obj:Clear()
            for _, s in ipairs(series) do s.Values = {} end
            updateLatest(); schedule()
        end
        function obj:Get() return series end
        function obj:Replay() reveal() end

        series = normalize(cfg.Series or cfg.Values or cfg.Data)
        w:_onTheme(plot, function() rebuildLegend(); schedule() end)
        updateLatest()
        reveal()
        return obj
    end

    --[[
        AddBarGraph({
            Title, Description, Height = 140, Gap = 6,
            Data = { { Label = "Mon", Value = 3, Color = Color3? }, ... }   -- or Values = {..}, Labels = {..}
            Max (otherwise auto), ShowValues = true, Suffix, Format, Animate = true,
        })
        graph:SetData(data)  graph:SetValue(index, value)  graph:Replay()
    ]]
    function Tab:AddBarGraph(cfg)
        local w, root = self.Window, self._root
        local H, GAP, BAR_W = cfg.Height or 140, cfg.Gap or 6, 0.7
        local card = self:_card(cfg, 0)
        local area = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, H + 18), LayoutOrder = 2 })
        layout(area, GAP, true)
        local items, cols = {}, {}

        local function normalize(d)
            local out = {}
            if type(d) ~= "table" then return out end
            if d.Values then
                for i, v in ipairs(d.Values) do out[i] = { Label = d.Labels and d.Labels[i] or tostring(i), Value = v } end
            elseif type(d[1]) == "table" then
                for i, it in ipairs(d) do out[i] = { Label = it.Label or it.Name or tostring(i), Value = it.Value or 0, Color = it.Color } end
            else
                for i, v in ipairs(d) do out[i] = { Label = tostring(i), Value = v } end
            end
            return out
        end

        local function build()
            for _, c in ipairs(cols) do c.col:Destroy() end
            cols = {}
            local n = #items
            for i = 1, n do
                local col = New("TextButton", { Parent = area, BackgroundTransparency = 1, Size = UDim2.new(1 / n, -(GAP * (n - 1) / n), 1, 0), LayoutOrder = i })
                local plotA = New("Frame", { Parent = col, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -18) })
                local bar = New("Frame", { Parent = plotA, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(BAR_W, 0), BackgroundTransparency = 0.1 })
                w:_corner(bar, 0.3)
                w:_onTheme(bar, function()
                    local it = items[i]
                    bar.BackgroundColor3 = (it and it.Color) or w.Theme.Accent
                end)
                local val = New("TextLabel", { Parent = bar, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -3), Size = UDim2.fromOffset(0, 12), AutomaticSize = AUTO_X, TextSize = 10, Visible = cfg.ShowValues ~= false })
                w:_bind(val, "TextColor3", "Text")
                local lbl = New("TextLabel", { Parent = col, Position = UDim2.new(0, 0, 1, -14), Size = UDim2.new(1, 0, 0, 14), TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd })
                w:_bind(lbl, "TextColor3", "SubText")
                col.MouseEnter:Connect(function() tween(bar, { BackgroundTransparency = 0 }); val.Visible = true end)
                col.MouseLeave:Connect(function() tween(bar, { BackgroundTransparency = 0.1 }); val.Visible = cfg.ShowValues ~= false end)
                cols[i] = { col = col, bar = bar, val = val, lbl = lbl, h = 0 }
            end
        end

        local function update(animate)
            local mx = cfg.Max
            if not mx then
                mx = 0
                for _, it in ipairs(items) do if it.Value > mx then mx = it.Value end end
                mx = mx * 1.15
            end
            if mx <= 0 then mx = 1 end
            for i, it in ipairs(items) do
                local c = cols[i]
                c.h = math.clamp(it.Value / mx, 0, 1)
                c.val.Text = fmtValue(cfg, it.Value)
                c.lbl.Text = tostring(it.Label)
                local goal = { Size = UDim2.fromScale(BAR_W, c.h) }
                if animate then tween(c.bar, goal, TI_POP) else c.bar.Size = goal.Size end
            end
        end

        local function replay()
            if cfg.Animate == false or not ANIM.on then return end
            for i, c in ipairs(cols) do
                c.bar.Size = UDim2.fromScale(BAR_W, 0)
                task.delay(T(i * 0.035), function()
                    if c.bar.Parent then tween(c.bar, { Size = UDim2.fromScale(BAR_W, c.h) }, TI_POP) end
                end)
            end
        end
        table.insert(root._onShow, replay)

        local obj = {}
        function obj:SetData(d)
            local old = #items
            items = normalize(d)
            if #items ~= old then build() end
            update(true)
        end
        function obj:SetValue(i, v)
            if items[i] then items[i].Value = v; update(true) end
        end
        function obj:Get() return items end
        function obj:Replay() replay() end

        items = normalize(cfg.Data or { Values = cfg.Values, Labels = cfg.Labels })
        build()
        update(false)
        replay()
        return obj
    end

    --[[
        AddDistribution({ Title, Description, Data = { { Label, Value, Color }, ... }, ShowValue = false, BarHeight = 10 })
        A segmented proportion bar with a legend (the minimal alternative to a pie chart).
        dist:SetData(data)
    ]]
    function Tab:AddDistribution(cfg)
        local w, root = self.Window, self._root
        local GAP = 2
        local card = self:_card(cfg, 0)
        local row = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, cfg.BarHeight or 10), LayoutOrder = 2 })
        layout(row, GAP, true)
        local legend = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = 3 })
        layout(legend, 12, true).Wraps = true
        local items, segs, labels = {}, {}, {}

        local function normalize(d)
            local out = {}
            for i, it in ipairs(type(d) == "table" and d or {}) do
                out[i] = { Label = it.Label or it.Name or tostring(i), Value = tonumber(it.Value) or 0, Color = it.Color }
            end
            return out
        end

        local function total()
            local t = 0
            for _, it in ipairs(items) do t += math.max(it.Value, 0) end
            return t
        end

        local function paint()
            local t = total()
            for i, it in ipairs(items) do
                local color = pickColor(w, i, it.Color)
                segs[i].BackgroundColor3 = color
                local pct = t > 0 and math.floor(it.Value / t * 100 + 0.5) or 0
                local tail = cfg.ShowValue and string.format("%s · %d%%", formatNumber(it.Value), pct) or string.format("%d%%", pct)
                labels[i].Text = string.format('<font color="%s">●</font>  %s  <font color="%s">%s</font>',
                    color3ToHex(color), esc(it.Label), color3ToHex(w.Theme.SubText), tail)
            end
        end

        local function build()
            for _, s in ipairs(segs) do s:Destroy() end
            for _, l in ipairs(labels) do l:Destroy() end
            segs, labels = {}, {}
            for i = 1, #items do
                local seg = New("Frame", { Parent = row, Size = UDim2.fromScale(0, 1), LayoutOrder = i })
                w:_corner(seg, "pill")
                segs[i] = seg
                local l = New("TextLabel", { Parent = legend, AutomaticSize = AUTO_X, Size = UDim2.fromOffset(0, 14), RichText = true, TextSize = 11, LayoutOrder = i })
                w:_bind(l, "TextColor3", "Text")
                labels[i] = l
            end
        end

        local function update(animate)
            local t, n = total(), #items
            for i, it in ipairs(items) do
                local f = t > 0 and math.max(it.Value, 0) / t or 0
                local goal = { Size = UDim2.new(f, -GAP * (n - 1) * f, 1, 0) }
                if animate then tween(segs[i], goal, TI_POP) else segs[i].Size = goal.Size end
            end
            paint()
        end

        local function replay()
            if cfg.Animate == false or not ANIM.on then return end
            for _, s in ipairs(segs) do s.Size = UDim2.fromScale(0, 1) end
            update(true)
        end
        table.insert(root._onShow, replay)

        local obj = {}
        function obj:SetData(d)
            items = normalize(d)
            build(); update(true)
        end
        function obj:Get() return items end
        function obj:Replay() replay() end

        items = normalize(cfg.Data)
        build()
        update(false)
        w:_onTheme(row, paint)
        replay()
        return obj
    end

    ------------------------------------------------------------------ config profiles
    function Tab:AddConfigSection()
        local w = self.Window
        local FOLDER, NONE = "PrismConfigs", "No profiles found"
        self:AddSection("Config")
        local nameInput = self:AddInput({ Title = "Profile name", Placeholder = "MyConfig", Default = "default", NoSave = true })
        local selected = NONE
        local profileDropdown = self:AddDropdown({
            Title = "Select profile", Values = { NONE }, Default = NONE, NoSave = true,
            Callback = function(v) selected = v end,
        })
        local status = self:AddParagraph({ Title = "Status", Description = "Ready." })

        local function profilePath(name)
            if #name > 48 or not name:match("^[%w_-]+$") then
                error("Use 1-48 letters, numbers, underscores, or hyphens for the profile name.")
            end
            return FOLDER .. "/" .. name .. ".json"
        end

        local function refresh()
            if type(listfiles) ~= "function" then
                status:Set("Profile list unavailable: executor does not expose listfiles.")
                return
            end
            local ok, files = pcall(listfiles, FOLDER)
            if not ok then
                if type(isfolder) == "function" and isfolder(FOLDER) then
                    status:Set("Could not list profiles: " .. tostring(files))
                    return
                end
                files = {}
            end
            local names = {}
            for _, f in ipairs(files) do
                local n = tostring(f):match("([^/\\]+)%.json$")
                if n and n:match("^[%w_-]+$") then names[#names + 1] = n end
            end
            table.sort(names)
            if #names == 0 then names = { NONE } end
            selected = table.find(names, selected) and selected or names[1]
            profileDropdown:SetValues(names)
            profileDropdown:Set(selected, true)
        end

        local function save()
            local name = nameInput:Get()
            if name == "" then name = "default" end
            local path = profilePath(name)
            if type(writefile) ~= "function" then error("executor does not expose writefile") end
            if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder(FOLDER) then makefolder(FOLDER) end
            writefile(path, w:ExportConfig())
            selected = name
            refresh()
        end

        local function load()
            if selected == "" or selected == NONE then error("select a saved profile first") end
            local path = profilePath(selected)
            if type(readfile) ~= "function" or type(isfile) ~= "function" then error("executor does not expose readfile/isfile") end
            if not isfile(path) then error("profile file not found: " .. path) end
            w:ImportConfig(readfile(path))
            nameInput:Set(selected)
        end

        local function delete()
            if selected == "" or selected == NONE then error("select a saved profile first") end
            if type(delfile) ~= "function" or type(isfile) ~= "function" then error("executor does not expose delfile/isfile") end
            local path = profilePath(selected)
            if not isfile(path) then error("profile file not found: " .. path) end
            delfile(path)
            refresh()
        end

        local function run(action, fn)
            local ok, err = pcall(fn)
            status:Set(ok and (action .. " successful.") or (action .. " failed: " .. tostring(err)))
            w:Notify({
                Title = ok and (action .. " complete") or (action .. " failed"),
                Content = ok and ("Profile " .. action:lower() .. " successful.") or tostring(err),
                Duration = 3,
            })
        end

        self:AddButton({ Title = "Save profile", Description = "Save the current interface and widget values.", Callback = function() run("Save", save) end })
        self:AddButton({ Title = "Load selected profile", Callback = function() run("Load", load) end })
        self:AddButton({ Title = "Delete selected profile", Callback = function() run("Delete", delete) end })
        self:AddButton({ Title = "Refresh profiles", Callback = refresh })
        self:AddButton({
            Title = "Export profile JSON",
            Callback = function()
                local ok, result = pcall(function() return w:ExportConfig() end)
                if not ok then
                    status:Set("Export failed: " .. tostring(result))
                    w:Notify({ Title = "Export failed", Content = tostring(result), Duration = 3 })
                elseif type(setclipboard) == "function" then
                    setclipboard(result)
                    status:Set("Config JSON copied to clipboard.")
                else
                    status:Set("Clipboard unavailable; JSON printed to output.")
                    print(result)
                end
            end,
        })
        refresh()
    end

    local function enumName(et) return (tostring(et):gsub("^Enum%.", "")) end

    local function encodeValue(value)
        local t = typeof(value)
        if t == "EnumItem" then
            return { __prismType = "EnumItem", enum = enumName(value.EnumType), name = value.Name }
        elseif t == "Color3" then
            return { __prismType = "Color3", r = value.R, g = value.G, b = value.B }
        elseif value == nil then
            return { __prismType = "nil" }
        elseif t == "table" then
            local r = {}
            for k, x in pairs(value) do r[k] = encodeValue(x) end
            return r
        elseif t == "string" or t == "number" or t == "boolean" then
            return value
        end
        error("unsupported config value type: " .. t)
    end

    -- v1.x configs stored enums as bare names plus an `enumTypes` map
    local function legacyEnum(value, typeName)
        local ok, et = pcall(function() return Enum[typeName] end)
        if not ok or not et then error("unknown enum type '" .. tostring(typeName) .. "'") end
        if type(value) == "string" then
            local ok2, item = pcall(function() return et[value] end)
            if not ok2 or not item then error("invalid saved enum value '" .. value .. "'") end
            return item
        elseif type(value) == "table" then
            local r = {}
            for k, x in pairs(value) do r[k] = legacyEnum(x, typeName) end
            return r
        end
        return value
    end

    local function decodeValue(value, legacyType)
        if type(value) ~= "table" then
            if legacyType and type(value) == "string" then return legacyEnum(value, legacyType) end
            return value
        end
        local kind = value.__prismType
        if kind == "nil" then return nil end
        if kind == "Color3" then
            if type(value.r) ~= "number" or type(value.g) ~= "number" or type(value.b) ~= "number" then error("invalid saved Color3 value") end
            return Color3.new(value.r, value.g, value.b)
        end
        if kind == "EnumItem" then
            local ok, item = pcall(function() return Enum[value.enum][value.name] end)
            if not ok or not item then error("invalid saved enum '" .. tostring(value.enum) .. "." .. tostring(value.name) .. "'") end
            return item
        end
        if legacyType and kind == nil then return legacyEnum(value, legacyType) end
        local r = {}
        for k, x in pairs(value) do r[k] = decodeValue(x, legacyType) end
        return r
    end

    function Window:_collectState()
        local widgets = {}
        for key, widget in pairs(self._stateWidgets) do
            local ok, value = pcall(widget.Get, widget)
            if not ok then error("could not read setting '" .. key .. "': " .. tostring(value)) end
            widgets[key] = encodeValue(value)
        end
        return {
            version = 4,
            theme = type(self._themeName) == "string" and self._themeName or "custom",
            themeData = type(self._themeName) == "table" and encodeValue(self._themeName) or nil,
            accent = self._accent and encodeValue(self._accent) or nil,
            corner = self.CornerRadius,
            animations = ANIM.on,
            animSpeed = ANIM.speed,
            size = { X = self._size.X, Y = self._size.Y },
            widgets = widgets,
        }
    end

    function Window:_applyState(s)
        if type(s) ~= "table" then error("invalid config data") end
        local jobs = {}
        if type(s.widgets) == "table" then
            for key, stored in pairs(s.widgets) do
                local widget = self._stateWidgets[key]
                if widget then
                    local legacy = type(s.enumTypes) == "table" and s.enumTypes[key] or nil
                    local ok, decoded = pcall(decodeValue, stored, legacy)
                    if not ok then error("could not decode setting '" .. key .. "': " .. tostring(decoded)) end
                    jobs[#jobs + 1] = { key, widget, decoded }
                end
            end
        end
        for _, j in ipairs(jobs) do -- decode everything first, then apply
            local ok, err = pcall(j[2].Set, j[2], j[3])
            if not ok then error("could not apply setting '" .. j[1] .. "': " .. tostring(err)) end
        end
        if s.themeData then self:SetTheme(decodeValue(s.themeData)) elseif s.theme and s.theme ~= "custom" then self:SetTheme(s.theme) end
        self:SetAccent(s.accent and decodeValue(s.accent) or nil)
        if type(s.corner) == "number" then self:SetCornerRadius(s.corner) end
        if type(s.animations) == "boolean" then self:SetAnimations(s.animations) end
        if type(s.animSpeed) == "number" then self:SetAnimationSpeed(s.animSpeed) end
        if type(s.size) == "table" and type(s.size.X) == "number" and type(s.size.Y) == "number" then
            self:SetSize(Vector2.new(s.size.X, s.size.Y))
        end
    end

    function Window:ExportConfig() return HttpService:JSONEncode(self:_collectState()) end
    function Window:ImportConfig(json) self:_applyState(HttpService:JSONDecode(json)) end

    ------------------------------------------------------------------ window creation
    function Library:CreateWindow(cfg)
        cfg = cfg or {}
        local self = setmetatable({
            Tabs = {}, _painters = {}, _corners = {}, _cornerLimit = 64, _conns = {}, _inputs = {},
            _notifId = 0, _navOrder = 0, _stateWidgets = {}, _visible = true, _visToken = 0, _minToken = 0, _minimized = false,
        }, Window)
        self._themeName   = cfg.Theme or "Midnight"
        self._accent      = cfg.Accent
        self.CornerRadius = math.clamp(cfg.CornerRadius or 10, 0, 28)
        self.ToggleKey    = cfg.ToggleKey or Enum.KeyCode.RightShift
        self._size        = cfg.Size or Vector2.new(600, 400)
        self:_buildTheme()
        if cfg.Animations ~= nil then ANIM.on = cfg.Animations ~= false end
        if cfg.AnimationSpeed then ANIM.speed = math.clamp(tonumber(cfg.AnimationSpeed) or 1, 0.25, 4) end

        local size = self._size
        local gui = New("ScreenGui", { Name = "PrismUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100, IgnoreGuiInset = true })
        self.Gui = gui

        local holder = New("Frame", { Name = "Window", Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1 })
        local scale = New("UIScale", { Parent = holder, Scale = 0.94 })
        self.Holder, self._scale = holder, scale
        tween(scale, { Scale = 1 }, TI_POP)

        local main = New("Frame", { Name = "Main", Parent = holder, Size = UDim2.fromScale(1, 1), ClipsDescendants = true })
        self:_bind(main, "BackgroundColor3", "Background")
        self:_corner(main, 1)
        self:_stroke(main, "Stroke")

        ---------------- top bar
        local top = New("Frame", { Parent = main, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TOP_H) })
        local hairline = New("Frame", { Parent = main, Position = UDim2.fromOffset(0, TOP_H), Size = UDim2.new(1, 0, 0, 1) })
        self:_bind(hairline, "BackgroundColor3", "Stroke")

        local titleRow = New("Frame", { Parent = top, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -96, 1, 0), ClipsDescendants = true })
        layout(titleRow, 8, true).VerticalAlignment = Enum.VerticalAlignment.Center
        local brand = New("TextLabel", { Parent = titleRow, Size = UDim2.fromOffset(0, 20), AutomaticSize = AUTO_X, Text = cfg.Title or "PrismUI", Font = FONT_BOLD, TextSize = 15, LayoutOrder = 1 })
        self:_bind(brand, "TextColor3", "Text")

        for index, tag in ipairs(cfg.Tags or {}) do
            local text, color
            if type(tag) == "table" then
                text = tostring(tag.Text or tag.Name or "")
                color = typeof(tag.Color) == "Color3" and tag.Color or nil
            else
                text = tostring(tag)
            end
            if text ~= "" then
                local pill = New("Frame", { Parent = titleRow, Size = UDim2.fromOffset(0, 16), AutomaticSize = AUTO_X, LayoutOrder = index + 1 })
                self:_corner(pill, "pill")
                pad(pill, 0, 7, 0, 7)
                local lbl = New("TextLabel", { Parent = pill, Size = UDim2.fromOffset(0, 16), AutomaticSize = AUTO_X, Text = string.upper(text), Font = FONT_BOLD, TextSize = 9 })
                if color then
                    lbl.TextColor3 = color
                    self:_onTheme(pill, function() pill.BackgroundColor3 = color:Lerp(self.Theme.Background, 0.85) end)
                else
                    self:_bind(pill, "BackgroundColor3", "Elevated")
                    self:_bind(lbl, "TextColor3", "Accent")
                end
            end
        end

        local RED = rgb(210, 60, 75)
        local function topButton(iconName, x, danger)
            local b = New("TextButton", { Parent = top, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1 })
            self:_corner(b, 0.6)
            local img = New("ImageLabel", { Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14), Image = resolveIcon(iconName) or "" })
            self:_onTheme(b, function()
                b.BackgroundColor3 = danger and RED or self.Theme.Elevated
                img.ImageColor3 = self.Theme.SubText
            end)
            b.MouseEnter:Connect(function()
                tween(b, { BackgroundTransparency = 0 })
                tween(img, { ImageColor3 = danger and Color3.new(1, 1, 1) or self.Theme.Text })
            end)
            b.MouseLeave:Connect(function()
                tween(b, { BackgroundTransparency = 1 })
                tween(img, { ImageColor3 = self.Theme.SubText })
            end)
            return b, img
        end
        local closeBtn = topButton("x", -10, true)
        local minBtn, minIcon = topButton("minimize-2", -42)
        self._minIcon = minIcon

        ---------------- body
        local body = New("Frame", { Parent = main, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, TOP_H + 1), Size = UDim2.new(1, 0, 1, -(TOP_H + 1)) })
        self._body = body

        local sidebar = New("Frame", { Parent = body, BackgroundTransparency = 1, Size = UDim2.new(0, SIDEBAR_W, 1, 0), ClipsDescendants = true })
        local indicator = New("Frame", { Parent = sidebar, Visible = false, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 30) })
        self:_corner(indicator, 0.5)
        self:_bind(indicator, "BackgroundColor3", "Elevated")
        local tabList = New("ScrollingFrame", { Parent = sidebar, Size = UDim2.fromScale(1, 1), ScrollBarThickness = 0 })
        pad(tabList, 8, 8, 8, 8)
        layout(tabList, 2)
        self._tabList, self._sidebar, self._indicator = tabList, sidebar, indicator
        tabList:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
            if self.ActiveTab then self:_moveIndicator(self.ActiveTab, false) end
        end)

        local divider = New("Frame", { Parent = body, Position = UDim2.fromOffset(SIDEBAR_W, 0), Size = UDim2.new(0, 1, 1, 0) })
        self:_bind(divider, "BackgroundColor3", "Stroke")

        self._pages = New("Frame", { Parent = body, BackgroundTransparency = 1, Position = UDim2.fromOffset(SIDEBAR_W + 1, 0), Size = UDim2.new(1, -(SIDEBAR_W + 1), 1, 0), ClipsDescendants = true })
        self._curtain = New("Frame", { Parent = self._pages, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 })
        self:_bind(self._curtain, "BackgroundColor3", "Background")

        self._notifs = New("Frame", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.new(0, 280, 1, -40) })
        layout(self._notifs, 8).VerticalAlignment = Enum.VerticalAlignment.Bottom

        ---------------- resize
        if cfg.Resizable then
            local handle = New("TextButton", { Parent = holder, BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -18, 1, -18), ZIndex = 5 })
            handle.InputBegan:Connect(function(i)
                if not isPress(i) or self._minimized then return end
                local m0 = Vector2.new(i.Position.X, i.Position.Y)
                local s0, p0 = self._size, holder.Position
                beginDrag(function(p)
                    local ns = Vector2.new(math.max(380, s0.X + (p.X - m0.X)), math.max(260, s0.Y + (p.Y - m0.Y)))
                    local d = ns - s0
                    self._size = ns
                    holder.Size = UDim2.fromOffset(ns.X, ns.Y)
                    holder.Position = UDim2.new(p0.X.Scale, p0.X.Offset + d.X / 2, p0.Y.Scale, p0.Y.Offset + d.Y / 2)
                end)
            end)
        end

        ---------------- dragging (listeners exist only while dragging)
        top.InputBegan:Connect(function(i)
            if not isPress(i) then return end
            local m0 = Vector2.new(i.Position.X, i.Position.Y)
            local p0 = holder.Position
            beginDrag(function(p)
                local d = p - m0
                holder.Position = UDim2.new(p0.X.Scale, p0.X.Offset + d.X, p0.Y.Scale, p0.Y.Offset + d.Y)
            end)
        end)

        minBtn.MouseButton1Click:Connect(function() self:SetMinimized() end)
        closeBtn.MouseButton1Click:Connect(function()
            tween(scale, { Scale = 0.92 }, TI)
            task.delay(T(0.12), function() safe(cfg.OnClose); self:Destroy() end)
        end)

        -- one shared InputBegan for the toggle key + every keybind widget
        self:_connect(UserInputService.InputBegan, function(input, gpe)
            local h = self._inputs
            for i = #h, 1, -1 do
                if h[i](input, gpe) then table.remove(h, i) end
            end
            if not gpe and not self._rebinding and self.ToggleKey ~= Enum.KeyCode.Unknown and input.KeyCode == self.ToggleKey then
                self:Toggle()
            end
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
