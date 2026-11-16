--[[
    PrismUI v1.4 - executor single-file build
    Load from a hosted raw file:
    local Prism = loadstring(game:HttpGet("RAW_GITHUB_URL"))()
    local Window = Prism:CreateWindow({
        Title = "My UI", Tags = { "BETA" },
        Subtitle = "auto",            -- or a custom string; "auto" shows @player
        Font = "BuilderSans",         -- BuilderSans | Gotham | Montserrat | Code
        Mobile = nil,                 -- nil = auto-detect touch, true/false to force
        MobileButton = nil,           -- floating open/close bubble (default: on for touch)
        TextScale = 1,                -- 0.8 - 1.3
        Scale = nil,                  -- UI scale 0.5 - 1.5 (default: auto-fit to the screen)
        Density = "comfortable",      -- "comfortable" | "compact"
        Glass = 0,                    -- 0 = opaque, 1 = fully frosted
        Pattern = "none",             -- "none" | "dots" | "grid"
        Blob = false,                 -- accent blob fading in a page corner
        Glow = false,                 -- accent glow behind the window
        AnimatedBorder = false,       -- slowly rotating accent gradient border
        Rainbow = false,              -- slow hue-cycling accent
        Profile = true,               -- player card at the bottom of the sidebar
    })

    What's new in v1.4
      * Minimal look: flat header with a brand dot, borderless sidebar, plain icon
        buttons, solid accent controls (no gradients), slimmer sliders and switches.
      * Mobile: the window resizes to fit the screen (and re-fits on rotation), the
        sidebar turns into a horizontal tab strip on narrow screens, controls get
        larger touch targets, a draggable floating bubble opens/closes the UI, the
        window drags from the header only (so pages scroll normally), sliders lock
        page scrolling while dragged, and hover/tooltips are skipped on touch.
        On touch the X button hides the window (reopen with the bubble).

    What's new in v1.3
      * Sidebar search: filters every widget in every tab (Window:Search("text")).
      * Smooth theme / accent cross-fades, auto-fit + adjustable UI scale (Window:SetScale).
      * Cards get a hairline border that lights up on hover.
      * Window:Dialog({ Title, Message, Buttons = { { Text, Primary, Style, Callback } } })
      * Window:SetWatermark("Name", { Stats = true })  -- pill with FPS / ping
      * Window:LoadAutoload()  -- applies the profile marked "autoload" in the config tab
      * Slider values are editable (click the number and type).
      * Dropdowns get a search field when they have more than 7 entries.
      * Toggle: Keybind = Enum.KeyCode.X adds an inline rebindable hotkey; :SetDisabled(bool)
      * Button: Style = "primary" | "danger", ButtonText = "Run"; :SetTitle() :SetDisabled()
      * Tab:AddSegmented({ Values = {...}, Default = ..., Callback })
      * Tab:AddCallout({ Title, Message, Type = "info"|"success"|"warning"|"error" })
      * Tab:AddConsole({ Height = 150 })  :Log(text, "info"|"success"|"warning"|"error"|"debug")  :Clear()
      * Tab:AddKeyValue({ Rows = { {"Ping", "32 ms"} } })  :Set(key, value)  :SetRows(rows)
      * Tab:AddDivider("optional label")
      * Lazy-built background patterns (much cheaper than before).

    Elements from earlier versions:
      Tab:AddLineGraph({ Values = {...}, Height = 120 })   :Set({ ... })
      Tab:AddStatCard({ Title = "FPS", Value = 60, Delta = 4, Values = {...} })
      Tab:AddGauge({ Title = "Load", Default = 0.7, Suffix = "%" })  :Set(0..1)
      Tab:AddSkeleton({ Title = "Loading..." })            :Destroy()
      Tab:AddSection("Name") returns a section object with :Toggle() / :Set(open)
      local cols = Tab:AddColumns(2)  -- side-by-side columns; add widgets per column:
        cols[1]:AddToggle({ Title = "Left" })  cols[2]:AddSlider({ Title = "Right" })
    Widget cfg extras: Tooltip = "text", Badge = "NEW" (tabs + cards),
    Notify({ Title, Message (or Content), Type = "info"|"success"|"warning"|"error",
             Duration (0 = stays until dismissed), Color = Color3,
             Icon = "!" or "rbxassetid://..." }) returns { Dismiss }.
    Toasts stack with smooth reflow, pause on hover / touch-hold, dismiss by
    swipe right on touch or the close button, and adapt their width on mobile.
    Window:SetNotificationPosition("bottomright"|"bottomleft"|"topright"|"topleft"),
    or cfg.NotificationPosition at creation. The window is draggable from any
    non-interactive part of it (buttons, sliders and text boxes still work).
]]

local Prism = (function()
    local TweenService     = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local Players          = game:GetService("Players")
    local CoreGui          = game:GetService("CoreGui")
    local HttpService      = game:GetService("HttpService")
    local TextService      = game:GetService("TextService")
    local RunService       = game:GetService("RunService")
    local GuiService       = game:GetService("GuiService")

    local function touchOnly() return UserInputService.TouchEnabled and not UserInputService.MouseEnabled end

    local Library = {}
    local Window, Tab = {}, {}
    Window.__index, Tab.__index = Window, Tab
    local ActiveWindow = nil -- only one PrismUI window may exist at a time
    local CONFIG_FOLDER = "PrismConfigs"

    local FONT_MAP = {
        Gotham      = { Normal = Enum.Font.Gotham,           Medium = Enum.Font.GothamMedium,           Bold = Enum.Font.GothamBold },
        BuilderSans = { Normal = Enum.Font.BuilderSans,      Medium = Enum.Font.BuilderSansMedium,      Bold = Enum.Font.BuilderSansBold },
        Montserrat  = { Normal = Enum.Font.Montserrat,       Medium = Enum.Font.MontserratMedium,       Bold = Enum.Font.MontserratBold },
        Code        = { Normal = Enum.Font.Code,             Medium = Enum.Font.Code,                   Bold = Enum.Font.Code },
    }

    local TI     = TweenInfo.new(0.18, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
    local TI_POP = TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local SHADOW_IMAGE = "rbxassetid://6014261993"
    local SHADOW_SLICE = Rect.new(49, 49, 450, 450)
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

    -- Derive a full palette from a single accent colour (auto-theme).
    function Library.ThemeFromAccent(accent)
        local h, s, v = Color3.toHSV(accent)
        local function shade(sv, vv) return Color3.fromHSV(h, sv, vv) end
        return {
            Background = shade(math.min(s * 0.55, 0.5), math.max(0.055, v * 0.09)),
            Surface    = shade(math.min(s * 0.60, 0.5), math.max(0.085, v * 0.14)),
            Elevated   = shade(math.min(s * 0.65, 0.5), math.max(0.125, v * 0.20)),
            Stroke     = shade(math.min(s * 0.70, 0.5), math.max(0.175, v * 0.28)),
            Text       = Color3.new(1, 1, 1):Lerp(shade(s, 1), 0.88),
            SubText    = shade(math.min(s * 0.35, 0.35), 0.62),
            Accent     = accent,
        }
    end

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

    local function shiftHue(c, deg)
        local h, s, v = Color3.toHSV(c)
        return Color3.fromHSV((h + deg / 360) % 1, s, v)
    end

    local function keyName(k)
        return (k == nil or k == Enum.KeyCode.Unknown) and "None" or k.Name
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

    -- Accent -> hue-shifted accent gradient (multiplies the instance colour,
    -- so the instance should be white for exact colours).
    function Window:_gradient(inst, shift, rotation, fromKey, toKey)
        local g = New("UIGradient", { Parent = inst, Rotation = rotation or 0 })
        self:_onTheme(inst, function()
            local a = type(fromKey) == "string" and self.Theme[fromKey] or fromKey or self.Theme.Accent
            local b = type(toKey) == "string" and self.Theme[toKey] or toKey or shiftHue(a, shift or 25)
            g.Color = ColorSequence.new(a, b)
        end)
        return g
    end

    -- Glass: keeps a background at a theme-driven transparency.
    function Window:_glassify(inst, maxT)
        self:_onTheme(inst, function() inst.BackgroundTransparency = (self._glass or 0) * maxT end)
    end

    function Window:_refresh()
        for i = #self._painters, 1, -1 do
            local p = self._painters[i]
            if p.inst.Parent == nil then table.remove(self._painters, i) else pcall(p.fn) end
        end
        for i = #self._textRegs, 1, -1 do
            local r = self._textRegs[i]
            if r.inst.Parent == nil then table.remove(self._textRegs, i) end
        end
    end

    -- Cross-fades from the current theme to whatever `apply` sets up.
    function Window:_transition(apply)
        local old = self.Theme
        apply()
        self:_buildTheme()
        local target = self.Theme
        self._themeToken = (self._themeToken or 0) + 1
        local token = self._themeToken
        if self._themeConn then self._themeConn:Disconnect(); self._themeConn = nil end
        if not old or self._rainbow or not self._animateTheme then self:_refresh() return end
        local t0, dur = os.clock(), 0.28
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if token ~= self._themeToken or not self.Gui.Parent then conn:Disconnect() return end
            local a = math.clamp((os.clock() - t0) / dur, 0, 1)
            if a >= 1 then
                conn:Disconnect()
                if self._themeConn == conn then self._themeConn = nil end
                self.Theme = target
                self:_refresh()
                return
            end
            local e = 1 - (1 - a) ^ 3
            local mix = {}
            for k, v in pairs(target) do
                mix[k] = (typeof(v) == "Color3" and old[k]) and old[k]:Lerp(v, e) or v
            end
            self.Theme = mix
            self:_refresh()
        end)
        self._themeConn = conn
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
            Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, self:_ts(size) + 2),
            AutomaticSize = Enum.AutomaticSize.Y, Text = text or "", TextSize = self:_ts(size), Font = font,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        })
        self:_styleLabel(l, font == FONT_MAP[self._fontName].Bold and "Bold" or (font == FONT_MAP[self._fontName].Medium and "Medium" or "Normal"), size)
        self:_bind(l, "TextColor3", key)
        return l
    end

    -- Registers a label so font + text scale can be changed live.
    function Window:_styleLabel(inst, weight, size)
        table.insert(self._textRegs, { inst = inst, weight = weight or "Normal", size = size or 13 })
        return inst
    end

    function Window:_ts(n) return math.floor((n or 13) * (self.TextScale or 1) + 0.5) end
    function Window:_font(weight) return (FONT_MAP[self._fontName] or FONT_MAP.Gotham)[weight or "Normal"] end

    -- Hover tooltip.
    function Window:_tooltip(inst, text)
        if not text or text == "" or self._touch then return end
        local tip
        local function kill() if tip then tip:Destroy(); tip = nil end end
        inst.MouseEnter:Connect(function()
            kill()
            local m = UserInputService:GetMouseLocation()
            tip = New("TextLabel", {
                Parent = self.Gui, Text = text, Font = self:_font("Medium"), TextSize = self:_ts(12),
                TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = rgb(20, 20, 26), BackgroundTransparency = 0.08,
                AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromOffset(m.X + 14, m.Y - 10),
                AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 100,
                BorderSizePixel = 0, TextWrapped = true,
            })
            self:_corner(tip, 0.4)
            pad(tip, 6, 9)
            local st = New("UIStroke", { Parent = tip, Thickness = 1 })
            st.Color = self.Theme.Stroke
            tip.Destroying:Connect(kill)
        end)
        inst.MouseLeave:Connect(kill)
        inst.Destroying:Connect(kill)
    end

    function Window:_connect(signal, fn) table.insert(self._conns, signal:Connect(fn)) end

    ------------------------------------------------------------------ public window API
    function Window:SetTheme(theme)
        self:_transition(function() self._themeName = theme end)
    end
    function Window:SetAccent(color)
        self:_transition(function() self._accent = color; self._baseAccent = color end)
    end
    function Window:GetTheme() return self.Theme end

    function Window:SetFont(name)
        self._fontName = FONT_MAP[name] and name or "Gotham"
        for _, r in ipairs(self._textRegs) do
            r.inst.Font = self:_font(r.weight)
            r.inst.TextSize = self:_ts(r.size)
        end
    end

    function Window:SetTextScale(scale)
        self.TextScale = math.clamp(tonumber(scale) or 1, 0.8, 1.3)
        for _, r in ipairs(self._textRegs) do r.inst.TextSize = self:_ts(r.size) end
    end

    function Window:SetScale(scale)
        self._userScale = math.clamp(tonumber(scale) or 1, 0.5, 1.5)
        if self._scale and self.Holder.Visible then tween(self._scale, { Scale = self._userScale }, TI) end
    end

    function Window:SetDensity(mode)
        self.Density = mode == "compact" and "compact" or "comfortable"
        local c = self.Density == "compact"
        local t = self._touch
        self._d = { cardPad = c and 8 or (t and 13 or 11), gap = c and 5 or 6, rowH = c and 24 or 28, headerH = c and 20 or (t and 28 or 24) }
        -- Live-update paddings/gaps made density-aware.
        for _, e in ipairs(self._densityRegs) do e.fn(self._d) end
    end

    function Window:SetGlass(t)
        self._glass = math.clamp(tonumber(t) or 0, 0, 1)
        self:_refresh()
    end

    -- Patterns are built lazily the first time they are shown.
    function Window:SetPattern(mode)
        self._pattern = mode
        for _, kind in ipairs({ "dots", "grid" }) do
            if mode == kind and not self._patterns[kind] and self._buildPattern then
                self._patterns[kind] = self._buildPattern(kind)
            end
            if self._patterns[kind] then self._patterns[kind].Visible = mode == kind end
        end
    end

    function Window:SetBlob(on)
        if self._blob then self._blob.Visible = on == true end
    end

    function Window:SetGlow(on)
        self._glow = on == true
        if self._glowImage then self._glowImage.Visible = self._glow end
    end

    local NOTIF_POSITIONS = {
        bottomright = { anchor = Vector2.new(1, 1), pos = UDim2.new(1, -20, 1, -20), align = Enum.VerticalAlignment.Bottom },
        bottomleft  = { anchor = Vector2.new(0, 1), pos = UDim2.new(0, 20, 1, -20),  align = Enum.VerticalAlignment.Bottom },
        topright    = { anchor = Vector2.new(1, 0), pos = UDim2.new(1, -20, 0, 20),  align = Enum.VerticalAlignment.Top },
        topleft     = { anchor = Vector2.new(0, 0), pos = UDim2.new(0, 20, 0, 20),   align = Enum.VerticalAlignment.Top },
    }

    function Window:SetAnimatedBorder(on)
        self._animBorder = on == true
        if not self._borderStroke then return end
        if on then
            if not self._borderGrad then
                -- UIGradient multiplies the stroke colour, so force the stroke
                -- to white and let the gradient supply the accent colours.
                self._borderGrad = New("UIGradient", { Parent = self._borderStroke, Rotation = 0 })
                self:_onTheme(self._borderStroke, function()
                    local a = self.Theme.Accent
                    self._borderGrad.Color = ColorSequence.new(a, shiftHue(a, -60))
                    self._borderStroke.Color = Color3.new(1, 1, 1)
                    self._borderStroke.Thickness = 1.6
                end)
            end
            if not self._borderConn then
                self._borderConn = RunService.RenderStepped:Connect(function()
                    if self._borderGrad and self._borderGrad.Parent then
                        self._borderGrad.Rotation = (os.clock() * 60) % 360
                    end
                end)
                table.insert(self._conns, self._borderConn)
            end
        else
            if self._borderConn then self._borderConn:Disconnect(); self._borderConn = nil end
            if self._borderGrad then self._borderGrad:Destroy(); self._borderGrad = nil end
            self._borderStroke.Thickness = 1
            self:_refresh() -- restores the bound Stroke colour
        end
    end

    function Window:SetRainbow(on)
        self._rainbow = on == true
        if on then
            if not self._rainbowConn then
                self._rainbowConn = RunService.Heartbeat:Connect(function()
                    if os.clock() - (self._lastHue or 0) < 1 / 30 then return end
                    self._lastHue = os.clock()
                    self._accent = Color3.fromHSV((os.clock() * 0.06) % 1, 0.6, 1)
                    self:_buildTheme(); self:_refresh()
                end)
                table.insert(self._conns, self._rainbowConn)
            end
        else
            if self._rainbowConn then self._rainbowConn:Disconnect(); self._rainbowConn = nil end
            self:_transition(function() self._accent = self._baseAccent end)
        end
    end

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
            self._scale.Scale = 0.94 * self._userScale
            tween(self._scale, { Scale = self._userScale }, TI_POP)
        else
            tween(self._scale, { Scale = 0.94 * self._userScale }, TI)
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
            self._preMinimizePos = self.Holder.Position
            tween(self.Holder, { Size = UDim2.fromOffset(math.min(300, self._size.X), self._headerH + 2) }, TI_POP)
            task.delay(0.28, function()
                if token == self._minimizeToken and self._minimized then
                    self._body.Visible = false
                end
            end)
        else
            self._minimizeToken = (self._minimizeToken or 0) + 1
            self._body.Visible = true
            tween(self.Holder, { Size = UDim2.fromOffset(self._size.X, self._size.Y) }, TI_POP)
            -- re-center the expanded window so it is always fully on screen
            tween(self.Holder, { Position = UDim2.fromScale(0.5, 0.5) }, TI_POP)
        end
    end

    function Window:SetToggleKey(key) self.ToggleKey = key end
    function Window:GetToggleKey() return self.ToggleKey end

    -- Small pill in the top-left corner. opts.Stats = true appends FPS + ping.
    function Window:SetWatermark(text, opts)
        if self._watermark then self._watermark:Destroy(); self._watermark = nil end
        if self._wmConn then self._wmConn:Disconnect(); self._wmConn = nil end
        if not text then return end
        opts = opts or {}
        local pill = New("Frame", {
            Parent = self.Gui, Position = UDim2.new(0, 14, 0, 12), Size = UDim2.fromOffset(0, 26),
            AutomaticSize = Enum.AutomaticSize.X, BorderSizePixel = 0, BackgroundTransparency = 0.08,
        })
        self:_corner(pill, "pill")
        self:_bind(pill, "BackgroundColor3", "Surface")
        local st = self:_stroke(pill, "Stroke"); st.Transparency = 0.3
        pad(pill, 0, 12, 0, 10)
        New("UIListLayout", {
            Parent = pill, FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
        })
        local dot = New("Frame", { Parent = pill, Size = UDim2.fromOffset(7, 7), BorderSizePixel = 0, LayoutOrder = 1 })
        self:_corner(dot, "pill")
        self:_bind(dot, "BackgroundColor3", "Accent")
        local label = New("TextLabel", {
            Parent = pill, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26),
            Text = tostring(text), Font = self:_font("Medium"), TextSize = self:_ts(12), LayoutOrder = 2,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        self:_styleLabel(label, "Medium", 12)
        self:_bind(label, "TextColor3", "Text")
        if opts.Stats then
            local acc, frames = 0, 0
            self._wmConn = RunService.Heartbeat:Connect(function(dt)
                frames += 1; acc += dt
                if acc < 0.5 then return end
                local fps = math.floor(frames / acc + 0.5)
                local ping = 0
                pcall(function() ping = math.floor(Players.LocalPlayer:GetNetworkPing() * 1000 + 0.5) end)
                label.Text = string.format("%s  |  %d FPS  |  %d ms", tostring(text), fps, ping)
                acc, frames = 0, 0
            end)
            table.insert(self._conns, self._wmConn)
        end
        self._watermark = pill
    end

    function Window:Destroy()
        if ActiveWindow == self then ActiveWindow = nil end
        for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
        self.Gui:Destroy()
    end

    -- Sidebar on wide windows, horizontal tab strip on narrow ones (phones).
    function Window:_layout()
        if not self._sidebar then return end
        local strip = self._size.X < 560
        self._layoutMode = strip and "top" or "side"
        local sb, line, list, lay, tp, pages = self._sidebar, self._sideLine, self._tabList, self._tabLayout, self._tabPad, self._pages
        if strip then
            local TB = self._touch and 46 or 40
            sb.Size = UDim2.new(1, 0, 0, TB)
            line.Position = UDim2.fromOffset(0, TB); line.Size = UDim2.new(1, 0, 0, 1)
            self._searchBox.Visible = false
            if self._footer then self._footer.Visible = false end
            list.Position = UDim2.new(); list.Size = UDim2.fromScale(1, 1)
            list.ScrollingDirection = Enum.ScrollingDirection.X
            list.AutomaticCanvasSize = Enum.AutomaticSize.X
            lay.FillDirection = Enum.FillDirection.Horizontal
            lay.VerticalAlignment = Enum.VerticalAlignment.Center
            tp.PaddingTop, tp.PaddingBottom = UDim.new(0, 0), UDim.new(0, 0)
            tp.PaddingLeft, tp.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
            pages.Position = UDim2.fromOffset(0, TB + 1); pages.Size = UDim2.new(1, 0, 1, -(TB + 1))
        else
            local SW = self._size.X < 700 and 136 or 164
            local listTop = self._searchH + 18
            local footerH = self._footer and 54 or 0
            sb.Size = UDim2.new(0, SW, 1, 0)
            line.Position = UDim2.fromOffset(SW, 0); line.Size = UDim2.new(0, 1, 1, 0)
            self._searchBox.Visible = true
            if self._footer then self._footer.Visible = true end
            list.Position = UDim2.fromOffset(0, listTop); list.Size = UDim2.new(1, 0, 1, -(listTop + footerH))
            list.ScrollingDirection = Enum.ScrollingDirection.Y
            list.AutomaticCanvasSize = Enum.AutomaticSize.Y
            lay.FillDirection = Enum.FillDirection.Vertical
            lay.VerticalAlignment = Enum.VerticalAlignment.Top
            tp.PaddingTop, tp.PaddingBottom = UDim.new(0, 0), UDim.new(0, 8)
            tp.PaddingLeft, tp.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
            pages.Position = UDim2.fromOffset(SW + 1, 0); pages.Size = UDim2.new(1, -(SW + 1), 1, 0)
        end
        list.CanvasSize = UDim2.new()
        for _, t in ipairs(self.Tabs) do if t._setMode then t._setMode(strip) end end
        for _, g in ipairs(self._groupLabels) do if g.Parent then g.Visible = not strip end end
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

    -- Filters every widget in every tab by title/description.
    function Window:Search(query)
        if self._searchBox then self._searchBox.Text = tostring(query or "") else self:_applySearch(query) end
    end

    function Window:_applySearch(query)
        query = (tostring(query or ""):lower():match("^%s*(.-)%s*$"))
        local counts = {}
        for i = #self._searchIndex, 1, -1 do
            local it = self._searchIndex[i]
            if it.card.Parent == nil then
                table.remove(self._searchIndex, i)
            else
                local hit = query == "" or it.text:find(query, 1, true) ~= nil
                it.card.Visible = hit
                if hit then counts[it.tab] = (counts[it.tab] or 0) + 1 end
            end
        end
        for _, t in ipairs(self.Tabs) do
            if t._btn then t._btn.Visible = query == "" or (counts[t] or 0) > 0 end
        end
        if query ~= "" and self.ActiveTab and (counts[self.ActiveTab] or 0) == 0 then
            for _, t in ipairs(self.Tabs) do
                if (counts[t] or 0) > 0 then self:SelectTab(t) break end
            end
        end
    end

    -- Modal dialog. cfg: { Title, Message, Buttons = { { Text, Primary, Style, Callback, Close } }, Dismissible }
    function Window:Dialog(cfg)
        cfg = cfg or {}
        if self._dialog then pcall(self._dialog.Close) end
        local overlay = New("Frame", {
            Name = "Dialog", Parent = self.Holder, Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50,
        })
        self:_corner(overlay, 1)
        local backdrop = New("TextButton", {
            Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 50,
        })
        local card = New("Frame", {
            Parent = overlay, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(math.min(330, math.max(self._size.X - 60, 200)), 0), AutomaticSize = Enum.AutomaticSize.Y,
            BorderSizePixel = 0, ZIndex = 51, Active = true,
        })
        local cardScale = New("UIScale", { Parent = card, Scale = 0.9 })
        self:_bind(card, "BackgroundColor3", "Surface")
        self:_corner(card, 0.6)
        self:_stroke(card, "Stroke")
        pad(card, 16)
        New("UIListLayout", { Parent = card, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
        self:_text(card, cfg.Title or "Confirm", 16, self:_font("Bold"), "Text").LayoutOrder = 1
        local msg = cfg.Message or cfg.Content
        if msg and msg ~= "" then self:_text(card, tostring(msg), 13, self:_font("Normal"), "SubText").LayoutOrder = 2 end
        local row = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 3 })
        New("UIListLayout", {
            Parent = row, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
        })

        local dlg = { closed = false }
        function dlg.Close()
            if dlg.closed then return end
            dlg.closed = true
            if self._dialog == dlg then self._dialog = nil end
            tween(overlay, { BackgroundTransparency = 1 }, TI)
            tween(cardScale, { Scale = 0.92 }, TI)
            task.delay(0.2, function() overlay:Destroy() end)
        end
        local buttons = cfg.Buttons or { { Text = "OK", Primary = true } }
        for i, b in ipairs(buttons) do
            local style = b.Style and string.lower(tostring(b.Style)) or (b.Primary and "primary" or nil)
            local btn = New("TextButton", {
                Parent = row, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), Text = tostring(b.Text or "OK"),
                Font = self:_font("Bold"), TextSize = self:_ts(12), AutoButtonColor = false, BorderSizePixel = 0,
                LayoutOrder = i, BackgroundColor3 = Color3.new(1, 1, 1),
            })
            self:_styleLabel(btn, "Bold", 12)
            self:_corner(btn, 0.45)
            pad(btn, 0, 14, 0, 14)
            if style == "primary" then
                self:_bind(btn, "BackgroundColor3", "Accent")
                self:_bind(btn, "TextColor3", "AccentText")
            elseif style == "danger" then
                btn.BackgroundColor3 = rgb(210, 62, 76)
                btn.TextColor3 = Color3.new(1, 1, 1)
            else
                self:_bind(btn, "BackgroundColor3", "Elevated")
                self:_bind(btn, "TextColor3", "Text")
            end
            btn.Activated:Connect(function()
                if b.Close ~= false then dlg.Close() end
                safe(b.Callback)
            end)
        end
        backdrop.Activated:Connect(function()
            if cfg.Dismissible ~= false then dlg.Close(); safe(cfg.OnDismiss) end
        end)
        tween(overlay, { BackgroundTransparency = 0.45 }, TI)
        tween(cardScale, { Scale = 1 }, TI_POP)
        self._dialog = dlg
        return dlg
    end

    -- Toast notifications: manual stack with smooth reflow, hover/hold to
    -- pause, swipe right to dismiss, sticky toasts (Duration = 0), responsive
    -- width for mobile, and big tap targets. Themed from the active theme.
    local NOTIF_TYPES = {
        info    = { color = rgb(56, 132, 255), glyph = "i" },
        success = { color = rgb(34, 170, 96),  glyph = "check" },
        warning = { color = rgb(232, 160, 32), glyph = "!" },
        error   = { color = rgb(232, 72, 66),  glyph = "×" },
    }

    local function drawCheck(parent, color)
        for _, s in ipairs({
            { x = 10, y = 15, len = 5,  rot = -45 },
            { x = 15, y = 13, len = 11, rot = 45  },
        }) do
            local bar = New("Frame", {
                Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(s.x, s.y), Size = UDim2.fromOffset(2, s.len),
                Rotation = s.rot, BackgroundColor3 = color, BorderSizePixel = 0,
            })
            New("UICorner", { CornerRadius = UDim.new(0, 1), Parent = bar })
        end
    end

    function Window:_notifReflow()
        if not self._activeNotifs then return end
        local dir = (self._notifPos == "bottomright" or self._notifPos == "bottomleft") and -1 or 1
        local y = 0
        for _, n in ipairs(self._activeNotifs) do
            if n.card.Parent then
                tween(n.card, { Position = UDim2.fromOffset(0, dir * y) },
                    TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
            end
            y += n.height + 10
        end
    end

    function Window:_dismissNotif(n)
        if n.dismissed then return end
        n.dismissed = true
        for i, v in ipairs(self._activeNotifs) do
            if v == n then table.remove(self._activeNotifs, i) break end
        end
        self:_notifReflow()
        if n.barTween then n.barTween:Cancel() end
        local out = TweenService:Create(n.card,
            TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
            { Position = UDim2.fromOffset((self._notifWidth or 340) + 60, n.card.Position.Y.Offset) })
        out:Play()
        out.Completed:Once(function() n.card:Destroy() end)
    end

    function Window:SetNotificationPosition(pos)
        self._notifPos = NOTIF_POSITIONS[pos] and pos or "bottomright"
        local p = NOTIF_POSITIONS[self._notifPos]
        if self._notifs then
            self._notifs.AnchorPoint = p.anchor
            self._notifs.Position = p.pos
            self:_notifReflow()
        end
    end

    -- cfg: { Title, Message / Content, Type = "info"|"success"|"warning"|"error",
    --        Duration (0 = stays until dismissed), Color = Color3,
    --        Icon = "!" or "rbxassetid://..." } or a plain string.
    -- Returns { Dismiss = function() end }.
    function Window:Notify(cfg)
        if type(cfg) == "string" then cfg = { Content = cfg } end
        cfg = cfg or {}
        self._notifId += 1
        local theme = NOTIF_TYPES[string.lower(tostring(cfg.Type or "info"))] or NOTIF_TYPES.info
        local color = cfg.Color or theme.color
        local title = cfg.Title or "Notification"
        local message = cfg.Message or cfg.Content or ""
        local duration = tonumber(cfg.Duration)
        duration = (duration == nil or duration < 0) and 5 or duration
        local hasMsg = message ~= ""

        -- responsive metrics (mobile friendly)
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local compact = vp.X < 620
        local width = math.floor(math.min(340, vp.X * 0.92))
        self._notifWidth = width
        if self._notifs then self._notifs.Size = UDim2.fromOffset(width, 100) end
        local titleSize, bodySize = compact and 14 or 15, compact and 13 or 14
        local textX = 54
        local textW = width - textX - (compact and 44 or 40)

        -- measure the message
        local msgH = 0
        if hasMsg then
            local ok, size = pcall(function()
                return TextService:GetTextSize(message, bodySize, Enum.Font.Gotham, Vector2.new(textW, 1000))
            end)
            msgH = (ok and size and size.Y or 16) + 2
            msgH = math.max(msgH, 16)
        end
        local height = hasMsg and (14 + 18 + 4 + msgH + 22) or 58

        -- cap the stack
        self._activeNotifs = self._activeNotifs or {}
        while #self._activeNotifs >= 4 do
            self:_dismissNotif(self._activeNotifs[1])
        end

        local th = self.Theme
        -- UIGradient multiplies BackgroundColor3, so the card stays white and
        -- the gradient supplies the elevated surface tones.
        local card = New("Frame", {
            Parent = self._notifs, Size = UDim2.fromOffset(width, height),
            Position = UDim2.fromOffset(width + 60, 0),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        })
        New("UICorner", { CornerRadius = UDim.new(0, 14), Parent = card })
        local grad = New("UIGradient", { Parent = card, Rotation = 90 })
        self:_onTheme(card, function()
            grad.Color = ColorSequence.new(self.Theme.Elevated:Lerp(Color3.new(1, 1, 1), 0.10), self.Theme.Surface:Lerp(Color3.new(1, 1, 1), 0.07))
        end)
        local stroke = New("UIStroke", { Parent = card, Thickness = 1, Transparency = 0.35 })
        self:_bind(stroke, "Color", "Stroke")

        -- tinted icon badge
        local badge = New("Frame", {
            Parent = card, Position = UDim2.fromOffset(16, hasMsg and 14 or (height / 2 - 13)),
            Size = UDim2.fromOffset(26, 26), BackgroundColor3 = color,
            BackgroundTransparency = 0.85, BorderSizePixel = 0,
        })
        New("UICorner", { CornerRadius = UDim.new(0, 13), Parent = badge })

        local iconText = cfg.Icon or theme.glyph
        local iconAsset = type(iconText) == "string" and iconText:match("^rbxassetid://") or nil
        if iconAsset then
            New("ImageLabel", {
                Parent = badge, BackgroundTransparency = 1, Image = iconAsset,
                Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5), ImageColor3 = color,
            })
        elseif iconText == "check" or theme.glyph == "check" then
            drawCheck(badge, color)
        else
            New("TextLabel", {
                Parent = badge, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Text = tostring(iconText), Font = self:_font("Bold"), TextSize = 16,
                TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
            })
        end

        New("TextLabel", {
            Parent = card, Position = UDim2.fromOffset(textX, hasMsg and 14 or (height / 2 - 9)),
            Size = UDim2.fromOffset(textW, 18), BackgroundTransparency = 1,
            Text = title, Font = self:_font("Bold"), TextSize = titleSize,
            TextColor3 = th.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        })
        if hasMsg then
            New("TextLabel", {
                Parent = card, Position = UDim2.fromOffset(textX, 36),
                Size = UDim2.fromOffset(textW, msgH), BackgroundTransparency = 1,
                Text = message, Font = self:_font("Normal"), TextSize = bodySize,
                TextColor3 = th.SubText, TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
            })
        end

        local n = { card = card, height = height, dismissed = false }

        -- close button: 40x40 tap target
        local close = New("TextButton", {
            Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4),
            Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Text = "×",
            Font = self:_font("Bold"), TextSize = 20, TextColor3 = th.SubText, AutoButtonColor = false,
        })
        close.MouseEnter:Connect(function() tween(close, { TextColor3 = th.Text }, TweenInfo.new(0.15)) end)
        close.MouseLeave:Connect(function() tween(close, { TextColor3 = th.SubText }, TweenInfo.new(0.15)) end)
        close.Activated:Connect(function() self:_dismissNotif(n) end)

        -- countdown bar
        local track = New("Frame", {
            Parent = card, Position = UDim2.new(0, 16, 1, -12), Size = UDim2.new(1, -32, 0, 3),
            BackgroundColor3 = th.Background, BorderSizePixel = 0,
        })
        New("UICorner", { CornerRadius = UDim.new(0, 2), Parent = track })
        local fill = New("Frame", {
            Parent = track, Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0,
        })
        New("UICorner", { CornerRadius = UDim.new(0, 2), Parent = fill })

        local function setPaused(paused)
            if n.dismissed or not n.barTween then return end
            if paused then n.barTween:Pause() else n.barTween:Play() end
        end

        if duration > 0 then
            n.barTween = TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
            n.barTween.Completed:Connect(function(state)
                if state == Enum.PlaybackState.Completed then self:_dismissNotif(n) end
            end)
            n.barTween:Play()
        else
            track.Visible = false
        end

        -- desktop: hover pauses the countdown
        card.MouseEnter:Connect(function() setPaused(true) end)
        card.MouseLeave:Connect(function() setPaused(false) end)

        -- touch: hold to pause, swipe right to dismiss
        local touchStart, swiped = nil, false
        card.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                touchStart, swiped = input.Position, false
                setPaused(true)
            end
        end)
        card.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                touchStart = nil
                if not swiped then setPaused(false) end
            end
        end)
        self:_connect(UserInputService.InputChanged, function(input)
            if n.dismissed or not touchStart then return end
            if input.UserInputType == Enum.UserInputType.Touch then
                local dx = input.Position.X - touchStart.X
                local dy = math.abs(input.Position.Y - touchStart.Y)
                if dx > 55 and dy < 40 then
                    swiped = true
                    self:_dismissNotif(n)
                end
            end
        end)

        table.insert(self._activeNotifs, n)
        self:_notifReflow()

        return { Dismiss = function() self:_dismissNotif(n) end }
    end

    function Window:AddTab(cfg)
        if type(cfg) == "string" then cfg = { Title = cfg } end
        local tab = setmetatable({ Window = self, Title = cfg.Title, _order = 0, _sectionStack = {} }, Tab)

        self._navOrder = (self._navOrder or 0) + 1
        local BH = self._touch and 38 or 32
        local btn = New("TextButton", { Parent = self._tabList, Size = UDim2.new(1, 0, 0, BH), Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundTransparency = 1, LayoutOrder = self._navOrder, ClipsDescendants = true })
        tab._btn = btn
        self:_corner(btn, 0.6)
        local btnPad = New("UIPadding", { Parent = btn })
        local iconImage = resolveIcon(cfg.Icon)
        local textX = iconImage and 34 or 12
        local label = New("TextLabel", {
            Parent = btn, BackgroundTransparency = 1, Position = UDim2.fromOffset(textX, 0), Size = UDim2.new(1, -(textX + 6), 1, 0),
            Text = cfg.Title or "Tab", Font = self:_font("Medium"), TextSize = self:_ts(13), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        })
        self:_styleLabel(label, "Medium", 13)
        local icon
        if iconImage then
            icon = New("ImageLabel", {
                Parent = btn, BackgroundTransparency = 1, Image = iconImage,
                Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 10, 0.5, 0),
            })
        end

        -- tab badge (text like "NEW" or a count)
        local badge
        if cfg.Badge ~= nil and cfg.Badge ~= "" then
            badge = New("Frame", {
                Parent = btn, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
                AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 15), BorderSizePixel = 0,
            })
            self:_corner(badge, "pill")
            self:_bind(badge, "BackgroundColor3", "Accent")
            pad(badge, 0, 5, 0, 5)
            local bl = New("TextLabel", {
                Parent = badge, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
                Size = UDim2.fromOffset(0, 15), Text = type(cfg.Badge) == "number" and tostring(cfg.Badge) or string.upper(tostring(cfg.Badge)),
                Font = self:_font("Bold"), TextSize = self:_ts(8),
            })
            self:_styleLabel(bl, "Bold", 8)
            self:_bind(bl, "TextColor3", "AccentText")
        end

        -- vertical row in the sidebar, or an auto-width pill in the mobile tab strip
        tab._setMode = function(horizontal)
            if horizontal then
                btn.AutomaticSize = Enum.AutomaticSize.X
                btn.Size = UDim2.fromOffset(0, BH - 6)
                label.AutomaticSize = Enum.AutomaticSize.X
                label.Size = UDim2.new(0, 0, 1, 0)
                btnPad.PaddingRight = UDim.new(0, 12)
                if badge then badge.Visible = false end
            else
                btn.AutomaticSize = Enum.AutomaticSize.None
                btn.Size = UDim2.new(1, 0, 0, BH)
                label.AutomaticSize = Enum.AutomaticSize.None
                label.Size = UDim2.new(1, -(textX + (badge and 36 or 6)), 1, 0)
                btnPad.PaddingRight = UDim.new(0, 0)
                if badge then badge.Visible = true end
            end
        end
        tab._setMode(self._layoutMode == "top")

        tab._paint = function()
            local active = self.ActiveTab == tab
            local th = self.Theme
            tween(btn, { BackgroundColor3 = th.Elevated, BackgroundTransparency = active and 0 or 1 }, TI)
            tween(label, { TextColor3 = active and th.Text or th.SubText }, TI)
            if icon then tween(icon, { ImageColor3 = active and th.Accent or th.SubText }, TI) end
        end
        self:_onTheme(btn, tab._paint)

        btn.MouseEnter:Connect(function()
            if self._touch or self.ActiveTab == tab then return end
            tween(btn, { BackgroundTransparency = 0.6 })
            tween(label, { TextColor3 = self.Theme.Text })
        end)
        btn.MouseLeave:Connect(function()
            if self._touch or self.ActiveTab == tab then return end
            tween(btn, { BackgroundTransparency = 1 })
            tween(label, { TextColor3 = self.Theme.SubText })
        end)
        btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
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
        local label = self:_text(self._tabList, string.upper(tostring(title or "GROUP")), 9, self:_font("Bold"), "SubText")
        label.Size = UDim2.new(1, 0, 0, 16)
        label.LayoutOrder = self._navOrder
        pad(label, 8, 0, 0, 8)
        table.insert(self._groupLabels, label)
        label.Visible = self._layoutMode ~= "top"
        self._navOrder += 1
        return label
    end

    function Window:AddAppearanceTab(title)
        local tab = self:AddTab({ Title = title or "Appearance", Icon = "settings" })
        local names = {}
        for n in pairs(Library.Themes) do table.insert(names, n) end
        table.sort(names)
        local swatches = {}
        for _, n in ipairs(names) do swatches[n] = Library.Themes[n].Accent end

        local accents = {
            ["Theme default"] = false, Violet = rgb(129,102,255), Rose = rgb(251,86,140), Sky = rgb(56,189,248),
            Emerald = rgb(52,211,153), Amber = rgb(251,176,52), Crimson = rgb(239,68,68), Candy = rgb(255,110,220),
        }
        local accentNames = {}
        for n in pairs(accents) do table.insert(accentNames, n) end
        table.sort(accentNames)

        tab:AddSection("Theme")
        tab:AddDropdown({ ConfigKey = "Theme", Title = "Theme", Values = names, Swatch = swatches, Default = type(self._themeName) == "string" and self._themeName or "Midnight", Callback = function(v) self:SetTheme(v) end })
        tab:AddDropdown({ ConfigKey = "Accent colour", Title = "Accent colour", Values = accentNames, Default = "Theme default", Callback = function(v) self:SetAccent(accents[v] or nil) end })
        tab:AddColorPicker({ ConfigKey = "Custom accent", Title = "Custom accent", Default = self.Theme.Accent, Callback = function(c) self:SetAccent(c) end })
        tab:AddToggle({ ConfigKey = "Rainbow accent", Title = "Rainbow accent", Description = "Slowly cycles the accent hue.", Default = self._rainbow == true, Callback = function(on) self:SetRainbow(on) end })
        tab:AddSection("Typography")
        tab:AddDropdown({ ConfigKey = "Font", Title = "Font", Values = { "Gotham", "BuilderSans", "Montserrat", "Code" }, Default = self._fontName, Callback = function(v) self:SetFont(v) end })
        tab:AddSlider({ ConfigKey = "Text scale", Title = "Text size scale", Min = 0.8, Max = 1.3, Increment = 0.05, Default = self.TextScale, Callback = function(v) self:SetTextScale(v) end })
        tab:AddDropdown({ ConfigKey = "Density", Title = "Layout density", Values = { "Comfortable", "Compact" }, Default = self.Density == "compact" and "Compact" or "Comfortable", Callback = function(v) self:SetDensity(v == "Compact" and "compact" or "comfortable") end })
        tab:AddSection("Shape")
        tab:AddSlider({ ConfigKey = "Corner radius", Title = "Corner radius", Description = "0 = sharp - 28 = very round", Min = 0, Max = 28, Default = self.CornerRadius, Suffix = "px", Callback = function(v) self:SetCornerRadius(v) end })
        tab:AddSlider({ ConfigKey = "UI scale", Title = "UI scale", Description = "Resize the whole window.", Min = 0.6, Max = 1.4, Increment = 0.05, Default = math.floor(self._userScale * 20 + 0.5) / 20, Callback = function(v) self:SetScale(v) end })
        tab:AddSection("Effects")
        tab:AddSlider({ ConfigKey = "Glass", Title = "Glass transparency", Description = "Let the game show through.", Min = 0, Max = 1, Increment = 0.05, Default = self._glass, Callback = function(v) self:SetGlass(v) end })
        tab:AddDropdown({ ConfigKey = "Pattern", Title = "Background pattern", Values = { "None", "Dots", "Grid" }, Default = (self._pattern == "grid" and "Grid") or (self._pattern == "dots" and "Dots") or "None", Callback = function(v) self:SetPattern(string.lower(v)) end })
        tab:AddToggle({ ConfigKey = "Accent blob", Title = "Accent blob", Description = "Soft accent glow fading in the page corner.", Default = self._blobOn == true, Callback = function(on) self:SetBlob(on) end })
        tab:AddToggle({ ConfigKey = "Window glow", Title = "Accent window glow", Default = self._glow == true, Callback = function(on) self:SetGlow(on) end })
        tab:AddToggle({ ConfigKey = "Animated border", Title = "Animated gradient border", Default = self._animBorder == true, Callback = function(on) self:SetAnimatedBorder(on) end })
        tab:AddSection("Notifications")
        tab:AddDropdown({ ConfigKey = "Notification position", Title = "Notification position", Values = { "Bottom right", "Bottom left", "Top right", "Top left" }, Default = "Bottom right", Callback = function(v) self:SetNotificationPosition((string.lower(v):gsub(" ", ""))) end })
        tab:AddSection("Window")
        if not self._touch then
            tab:AddKeybind({ ConfigKey = "Toggle key", Title = "Toggle key", Default = self.ToggleKey, Changed = function(k) self.ToggleKey = k end })
        end
        tab:AddToggle({ ConfigKey = "Start minimized", Title = "Start minimized", Default = false, Callback = function(on) self:SetMinimized(on) end })
        tab:AddButton({ Title = "Recenter window", Callback = function() self:Center() end })
        return tab
    end

    ------------------------------------------------------------------ elements
    function Tab:_next() self._order += 1; return self._order end

    function Tab:_host()
        local stack = self._sectionStack or {}
        return #stack > 0 and stack[#stack].body or self.Page
    end

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
        self._sectionStack = {}
    end

    function Tab:AddColumns(n, gap)
        n = math.max(1, math.floor(tonumber(n) or 1))
        gap = math.max(0, tonumber(gap) or 10)
        local frame = New("Frame", { Parent = self:_host(), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self:_next() })
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
        parent = parent or self:_host()
        local card = New(class or "Frame", { Parent = parent, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = self:_next() })
        if class == "TextButton" then card.Text = ""; card.AutoButtonColor = false end
        w:_bind(card, "BackgroundColor3", "Surface")
        w:_glassify(card, 0.35)
        w:_corner(card, 0.7)
        pad(card, w._d.cardPad, 14)
        local layout = New("UIListLayout", { Parent = card, Padding = UDim.new(0, w._d.gap), SortOrder = Enum.SortOrder.LayoutOrder })
        table.insert(w._densityRegs, { fn = function(d) layout.Padding = UDim.new(0, d.gap) end })

        local header = New("Frame", { Name = "Header", Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, w._d.headerH), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 })
        local texts = New("Frame", { Parent = header, BackgroundTransparency = 1, Size = UDim2.new(1, ctrlW > 0 and -(ctrlW + 10) or 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
        New("UIListLayout", { Parent = texts, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
        local hasDesc = cfg.Description and cfg.Description ~= ""
        if not hasDesc then pad(texts, 3, 0, 0, 0) end
        w:_text(texts, cfg.Title or cfg.Text or "", 14, w:_font("Medium"), "Text").LayoutOrder = 1
        if hasDesc then w:_text(texts, cfg.Description, 12, w:_font("Normal"), "SubText").LayoutOrder = 2 end
        if cfg.Badge ~= nil and cfg.Badge ~= "" then
            local pill = New("Frame", { Parent = texts, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 15), BorderSizePixel = 0, LayoutOrder = 3 })
            w:_corner(pill, "pill")
            w:_bind(pill, "BackgroundColor3", "Accent")
            pad(pill, 0, 6, 0, 6)
            local bl = New("TextLabel", {
                Parent = pill, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 15),
                Text = type(cfg.Badge) == "number" and tostring(cfg.Badge) or string.upper(tostring(cfg.Badge)),
                Font = w:_font("Bold"), TextSize = w:_ts(8),
            })
            w:_styleLabel(bl, "Bold", 8)
            w:_bind(bl, "TextColor3", "AccentText")
        end
        w:_tooltip(card, cfg.Tooltip)
        -- register for sidebar search
        table.insert(w._searchIndex, {
            card = card, tab = self,
            text = (tostring(cfg.Title or cfg.Text or "") .. " " .. tostring(cfg.Description or "")):lower(),
        })
        return card, header, texts
    end

    function Tab:_hover(card)
        local w = self.Window
        local hovered = false
        local st = card:FindFirstChildOfClass("UIStroke")
        card.MouseEnter:Connect(function()
            if w._touch then return end
            hovered = true
            tween(card, { BackgroundColor3 = w.Theme.Elevated }, TI)
            if st then tween(st, { Color = w.Theme.Accent, Transparency = 0.45 }, TI) end
        end)
        card.MouseLeave:Connect(function()
            hovered = false
            tween(card, { BackgroundColor3 = w.Theme.Surface }, TI)
            if st then tween(st, { Color = w.Theme.Stroke, Transparency = 0.65 }, TI) end
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

    -- Returns fn(on?) -> bool. Passing a boolean dims the card's text and sets the state.
    function Tab:_disabler(card)
        local state = false
        return function(on)
            if on ~= nil then
                state = on == true
                for _, d in ipairs(card:GetDescendants()) do
                    if d:IsA("TextLabel") or d:IsA("TextButton") then d.TextTransparency = state and 0.6 or 0 end
                end
            end
            return state
        end
    end

    -- Collapsible section. Returns { Toggle(), Set(open), Get(), SetTitle(text) }.
    function Tab:AddSection(name)
        local w = self.Window
        self._sectionStack = {}

        local wrap = New("Frame", { Parent = self.Page, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = self:_next() })
        local header = New("TextButton", { Parent = wrap, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1 })
        local label = New("TextLabel", {
            Parent = header, BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -30, 1, 0),
            Text = string.upper(tostring(name)), Font = w:_font("Bold"), TextSize = w:_ts(10),
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        w:_styleLabel(label, "Bold", 10)
        w:_bind(label, "TextColor3", "SubText")
        local chev = New("TextLabel", {
            Parent = header, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(14, 16),
            Text = "›", Font = w:_font("Bold"), TextSize = w:_ts(16), Rotation = 90,
            TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
        })
        w:_styleLabel(chev, "Bold", 16)
        w:_bind(chev, "TextColor3", "SubText")

        -- Plain Frame: CanvasGroup does not reliably support AutomaticSize.
        local body = New("Frame", { Parent = wrap, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
        local bodyLayout = New("UIListLayout", { Parent = body, Padding = UDim.new(0, w._d.gap), SortOrder = Enum.SortOrder.LayoutOrder })
        table.insert(w._densityRegs, { fn = function(d) bodyLayout.Padding = UDim.new(0, d.gap) end })

        local sec = { open = true, body = body }
        function sec:Set(open)
            sec.open = open == true
            tween(chev, { Rotation = sec.open and 90 or 0 }, TI)
            body.Visible = sec.open
        end
        function sec:Toggle() sec:Set(not sec.open) end
        function sec:Get() return sec.open end
        function sec:SetTitle(text) label.Text = string.upper(tostring(text)) end
        header.MouseButton1Click:Connect(function() sec:Toggle() end)
        header.MouseEnter:Connect(function() tween(label, { TextColor3 = w.Theme.Text }, TI) end)
        header.MouseLeave:Connect(function() tween(label, { TextColor3 = w.Theme.SubText }, TI) end)

        table.insert(self._sectionStack, sec)
        return sec
    end

    -- Optional label renders a divider with centred text: AddDivider("Advanced")
    function Tab:AddDivider(text)
        local w = self.Window
        if text and text ~= "" then
            local row = New("Frame", { Parent = self:_host(), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = self:_next() })
            local label = New("TextLabel", {
                Parent = row, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16),
                AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
                Text = string.upper(tostring(text)), Font = w:_font("Bold"), TextSize = w:_ts(9), ZIndex = 2,
            })
            w:_styleLabel(label, "Bold", 9)
            w:_bind(label, "TextColor3", "SubText")
            pad(label, 0, 8, 0, 8)
            local line = New("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, ZIndex = 1 })
            w:_bind(line, "BackgroundColor3", "Stroke")
            -- label paints over the line with the page colour
            w:_bind(label, "BackgroundColor3", "Background")
            label.BackgroundTransparency = 0
            return row
        end
        local f = New("Frame", { Parent = self:_host(), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, LayoutOrder = self:_next() })
        w:_bind(f, "BackgroundColor3", "Stroke")
        return f
    end

    function Tab:AddSpacer(px)
        local f = New("Frame", { Parent = self:_host(), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, px or 8), LayoutOrder = self:_next() })
        return f
    end

    function Tab:AddLabel(text) self:_card({ Title = text }, 0) end

    function Tab:AddParagraph(cfg)
        local card, _, texts = self:_card(cfg, 0)
        local description, title
        for _, child in ipairs(texts:GetChildren()) do
            if child:IsA("TextLabel") then
                if child.LayoutOrder == 2 then description = child elseif child.LayoutOrder == 1 then title = child end
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

    -- cfg: Title, Description, Callback, Style = "primary"|"danger", ButtonText = "Run"
    function Tab:AddButton(cfg)
        local w = self.Window
        local style = cfg.Style and string.lower(tostring(cfg.Style)) or nil
        local pillMode = style == "primary" or style == "danger" or cfg.ButtonText ~= nil
        local card, header, texts = self:_card(cfg, pillMode and 84 or 20, "TextButton")
        self:_hover(card)
        local chev, pill, pillText
        if pillMode then
            pill = New("Frame", rightAnchored({ Parent = header, Size = UDim2.fromOffset(74, 24), BackgroundColor3 = Color3.new(1, 1, 1) }))
            w:_corner(pill, "pill")
            pillText = New("TextLabel", {
                Parent = pill, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = tostring(cfg.ButtonText or "Run"),
                Font = w:_font("Bold"), TextSize = w:_ts(11), TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
            })
            w:_styleLabel(pillText, "Bold", 11)
            if style == "danger" then
                pill.BackgroundColor3 = rgb(210, 62, 76)
                pillText.TextColor3 = Color3.new(1, 1, 1)
            elseif style == "primary" then
                w:_bind(pill, "BackgroundColor3", "Accent")
                w:_bind(pillText, "TextColor3", "AccentText")
            else
                w:_bind(pill, "BackgroundColor3", "Elevated")
                w:_bind(pillText, "TextColor3", "Accent")
            end
        else
            chev = New("TextLabel", rightAnchored({ Parent = header, Size = UDim2.fromOffset(16, 20), BackgroundTransparency = 1, Text = "›", Font = w:_font("Bold"), TextSize = w:_ts(22) }))
            w:_styleLabel(chev, "Bold", 22)
            w:_bind(chev, "TextColor3", "Accent")
        end
        local titleLabel
        for _, c in ipairs(texts:GetChildren()) do
            if c:IsA("TextLabel") and c.LayoutOrder == 1 then titleLabel = c end
        end
        local isDisabled = self:_disabler(card)
        card.MouseButton1Click:Connect(function()
            if isDisabled() then return end
            if chev then
                tween(chev, { Position = UDim2.new(1, 4, 0.5, 0) }, TweenInfo.new(0.08))
                task.delay(0.1, function() tween(chev, { Position = UDim2.new(1, 0, 0.5, 0) }) end)
            elseif pill then
                tween(pill, { Size = UDim2.fromOffset(68, 22) }, TweenInfo.new(0.07))
                task.delay(0.09, function() tween(pill, { Size = UDim2.fromOffset(74, 24) }, TI_POP) end)
            end
            safe(cfg.Callback)
        end)
        return {
            Fire = function() if not isDisabled() then safe(cfg.Callback) end end,
            SetTitle = function(_, t) if titleLabel then titleLabel.Text = tostring(t) end end,
            SetButtonText = function(_, t) if pillText then pillText.Text = tostring(t) end end,
            SetDisabled = function(_, on) isDisabled(on == true) end,
            IsDisabled = function() return isDisabled() end,
        }
    end

    -- cfg: Title, Description, Default, Callback, Keybind = Enum.KeyCode (inline hotkey)
    function Tab:AddToggle(cfg)
        local w = self.Window
        local showBind = cfg.Keybind ~= nil and not w._touch
        local tw, tth, tk = w._touch and 44 or 36, w._touch and 24 or 20, w._touch and 18 or 14
        local card, header = self:_card(cfg, showBind and (tw + 64) or (tw + 4), "TextButton")
        self:_hover(card)
        local track = New("Frame", rightAnchored({ Parent = header, Size = UDim2.fromOffset(tw, tth) }))
        w:_corner(track, "pill")
        local thumb = New("Frame", { Parent = track, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(tk, tk), BorderSizePixel = 0 })
        w:_corner(thumb, "pill")

        local obj = { Value = cfg.Default == true }
        local function paint(animate)
            local th, on = w.Theme, obj.Value
            local inset = (tth - tk) / 2
            local goals = {
                { track, { BackgroundColor3 = on and th.Accent or th.Stroke } },
                { thumb, { BackgroundColor3 = on and th.AccentText or Color3.new(1, 1, 1), Position = on and UDim2.new(1, -(tk + inset), 0.5, 0) or UDim2.new(0, inset, 0.5, 0) } },
            }
            for _, g in ipairs(goals) do
                if animate then tween(g[1], g[2]) else for k, v in pairs(g[2]) do g[1][k] = v end end
            end
        end
        w:_onTheme(track, function() paint(false) end)

        function obj:Set(v, silent) obj.Value = v and true or false; paint(true); if not silent then safe(cfg.Callback, obj.Value) end end
        function obj:Get() return obj.Value end
        function obj:Toggle() obj:Set(not obj.Value) end

        local isDisabled = self:_disabler(card)
        function obj:SetDisabled(on) isDisabled(on == true) end
        function obj:IsDisabled() return isDisabled() end

        if showBind then
            local bindKey, listening = cfg.Keybind, false
            local bind = New("TextButton", {
                Parent = header, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(tw + 8), 0.5, 0),
                Size = UDim2.fromOffset(52, 20), Text = keyName(bindKey), Font = w:_font("Medium"), TextSize = w:_ts(10),
                AutoButtonColor = false, BorderSizePixel = 0, TextTruncate = Enum.TextTruncate.AtEnd,
            })
            w:_styleLabel(bind, "Medium", 10)
            w:_corner(bind, 0.4)
            w:_bind(bind, "BackgroundColor3", "Elevated")
            w:_bind(bind, "TextColor3", "Accent")
            bind.MouseButton1Click:Connect(function() listening = true; w._rebinding = true; bind.Text = "..." end)
            w:_connect(UserInputService.InputBegan, function(input, gpe)
                if listening then
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        listening = false
                        task.defer(function() w._rebinding = false end)
                        bindKey = input.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or input.KeyCode
                        bind.Text = keyName(bindKey)
                    end
                elseif not gpe and not w._rebinding and bindKey ~= Enum.KeyCode.Unknown and input.KeyCode == bindKey and not isDisabled() then
                    obj:Toggle()
                end
            end)
            function obj:SetKeybind(k) bindKey = k or Enum.KeyCode.Unknown; bind.Text = keyName(bindKey) end
            function obj:GetKeybind() return bindKey end
        else
            function obj:SetKeybind() end
            function obj:GetKeybind() return cfg.Keybind end
        end

        card.MouseButton1Click:Connect(function()
            if isDisabled() then return end
            -- thumb stretch while pressed
            tween(thumb, { Size = UDim2.fromOffset(tk + 4, tk - 2) }, TweenInfo.new(0.07))
            task.delay(0.09, function() tween(thumb, { Size = UDim2.fromOffset(tk, tk) }) end)
            obj:Set(not obj.Value)
        end)
        if cfg.CallOnInit then safe(cfg.Callback, obj.Value) end
        return self:_registerState(cfg, obj)
    end

    function Tab:AddSlider(cfg)
        local w = self.Window
        local min, max, inc = cfg.Min or 0, cfg.Max or 100, cfg.Increment or 1
        local card, header = self:_card(cfg, 64)
        -- value is a text box: click it and type an exact number
        local valueLabel = New("TextBox", rightAnchored({ Parent = header, Size = UDim2.fromOffset(64, 20), BackgroundTransparency = 1, Font = w:_font("Medium"), TextSize = w:_ts(13), TextXAlignment = Enum.TextXAlignment.Right, ClearTextOnFocus = true }))
        w:_styleLabel(valueLabel, "Medium", 13)
        w:_bind(valueLabel, "TextColor3", "Accent")

        local ks = w._touch and 20 or 14
        local hit = New("TextButton", { Parent = card, Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, w._touch and 30 or 16), LayoutOrder = 2 })
        local bar  = New("Frame", { Parent = hit, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 4), BorderSizePixel = 0 })
        w:_corner(bar, "pill"); w:_bind(bar, "BackgroundColor3", "Elevated")
        local fill = New("Frame", { Parent = bar, Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) })
        w:_corner(fill, "pill")
        w:_bind(fill, "BackgroundColor3", "Accent")
        local knob = New("Frame", { Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(ks, ks), Position = UDim2.new(0, 0, 0.5, 0), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) })
        w:_corner(knob, "pill")
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
        hit.InputBegan:Connect(function(i)
            if isPress(i) then
                dragging = true; fromX(i.Position.X)
                self.Page.ScrollingEnabled = false -- keep the page still while dragging on touch
                tween(knob, { Size = UDim2.fromOffset(ks + 4, ks + 4) }, TweenInfo.new(0.1))
            end
        end)
        w:_connect(UserInputService.InputChanged, function(i) if dragging and isMove(i) then fromX(i.Position.X) end end)
        w:_connect(UserInputService.InputEnded, function(i)
            if isPress(i) and dragging then
                dragging = false
                self.Page.ScrollingEnabled = true
                tween(knob, { Size = UDim2.fromOffset(ks, ks) }, TI)
            end
        end)
        valueLabel.FocusLost:Connect(function()
            local n = tonumber(valueLabel.Text:match("-?%d+%.?%d*"))
            set(n or obj.Value)
        end)

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

        local box = New("TextButton", rightAnchored({ Parent = header, Size = UDim2.fromOffset(130, w._touch and 32 or 26), Text = "", AutoButtonColor = false }))
        w:_corner(box, 0.45); w:_bind(box, "BackgroundColor3", "Elevated")
        local boxLabel = New("TextLabel", { Parent = box, BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -26, 1, 0), Font = w:_font("Medium"), TextSize = w:_ts(12), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
        w:_styleLabel(boxLabel, "Medium", 12)
        w:_bind(boxLabel, "TextColor3", "Text")
        local arrow = New("TextLabel", { Parent = box, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(14, 16), Text = "›", Rotation = 90, Font = w:_font("Bold"), TextSize = w:_ts(13), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
        w:_styleLabel(arrow, "Bold", 13)
        w:_bind(arrow, "TextColor3", "SubText")

        -- search field, shown when the list is long
        local searchBox = New("TextBox", {
            Parent = card, Visible = false, Size = UDim2.new(1, 0, 0, 26), Text = "", PlaceholderText = "Search...",
            Font = w:_font("Normal"), TextSize = w:_ts(12), TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false, LayoutOrder = 2, BorderSizePixel = 0, ClipsDescendants = true,
        })
        w:_styleLabel(searchBox, "Normal", 12)
        pad(searchBox, 0, 9, 0, 9)
        w:_corner(searchBox, 0.4)
        w:_bind(searchBox, "BackgroundColor3", "Elevated"); w:_bind(searchBox, "TextColor3", "Text"); w:_bind(searchBox, "PlaceholderColor3", "SubText")

        local list = New("ScrollingFrame", { Parent = card, Visible = false, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, LayoutOrder = 3 })
        w:_bind(list, "ScrollBarImageColor3", "Stroke")
        New("UIListLayout", { Parent = list, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })

        local obj, painters = {}, {}
        local filter = ""
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
        local function listHeight()
            local n = 0
            for _, v in ipairs(values) do
                if filter == "" or tostring(v):lower():find(filter, 1, true) then n += 1 end
            end
            return math.min(math.max(n, 1) * (w._touch and 40 or 32), w._touch and 200 or 160)
        end
        local openToken = 0
        local function setOpen(open)
            openToken += 1
            local token = openToken
            tween(arrow, { Rotation = open and 270 or 90 }, TI)
            if open then
                list.Visible = true
                searchBox.Visible = #values > 7
                tween(list, { Size = UDim2.new(1, 0, 0, listHeight()) }, TI)
            else
                searchBox.Visible = false
                if searchBox.Text ~= "" then searchBox.Text = "" end
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
            filter = ""
            for i, val in ipairs(values) do
                local b = New("TextButton", { Name = tostring(val), Parent = list, Size = UDim2.new(1, -6, 0, w._touch and 36 or 28), Text = "", Font = w:_font("Medium"), TextSize = w:_ts(13), AutoButtonColor = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, ClipsDescendants = true })
                w:_styleLabel(b, "Medium", 13)
                local swatchColor = type(cfg.Swatch) == "table" and cfg.Swatch[val] or nil
                local textPad = 10
                if swatchColor then
                    textPad = 26
                    local dot = New("Frame", { Parent = b, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(10, 10), BorderSizePixel = 0, BackgroundColor3 = swatchColor })
                    w:_corner(dot, "pill")
                end
                local lbl = New("TextLabel", { Parent = b, BackgroundTransparency = 1, Position = UDim2.fromOffset(textPad, 0), Size = UDim2.new(1, -(textPad + 10), 1, 0), Text = tostring(val), Font = w:_font("Medium"), TextSize = w:_ts(13), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
                w:_styleLabel(lbl, "Medium", 13)
                pad(b, 0, 10, 0, 10)
                w:_corner(b, 0.4)
                local function paint()
                    local sel = multi and selected[val] or (not multi and value == val)
                    tween(b, { BackgroundColor3 = sel and w.Theme.Elevated or w.Theme.Surface }, TI)
                    tween(lbl, { TextColor3 = sel and w.Theme.Accent or w.Theme.Text }, TI)
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
                tween(list, { Size = UDim2.new(1, 0, 0, listHeight()) }, TI)
            else
                list.Size = UDim2.new(1, 0, 0, 0)
            end
            display()
        end
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            filter = searchBox.Text:lower()
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then c.Visible = filter == "" or c.Name:lower():find(filter, 1, true) ~= nil end
            end
            if list.Visible then tween(list, { Size = UDim2.new(1, 0, 0, listHeight()) }, TI) end
        end)
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
            Parent = header, Size = UDim2.fromOffset(140, w._touch and 32 or 26), Text = cfg.Default or "", PlaceholderText = cfg.Placeholder or "Type here...",
            Font = w:_font("Normal"), TextSize = w:_ts(12), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = cfg.ClearOnFocus == true, ClipsDescendants = true,
        }))
        w:_styleLabel(box, "Normal", 12)
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
            PlaceholderText = cfg.Placeholder or "Write something...", Font = w:_font("Normal"), TextSize = w:_ts(12),
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            ClearTextOnFocus = false, MultiLine = true, LayoutOrder = 2, ClipsDescendants = true,
        })
        w:_styleLabel(box, "Normal", 12)
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
        local btn = New("TextButton", rightAnchored({ Parent = header, Size = UDim2.fromOffset(80, 26), Text = key.Name, Font = w:_font("Medium"), TextSize = w:_ts(12), AutoButtonColor = false }))
        w:_styleLabel(btn, "Medium", 12)
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
        New("UIListLayout", { Parent = picker, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

        local hexBox = New("TextBox", { Parent = picker, Size = UDim2.new(1, 0, 0, 26), Text = color3ToHex(current), Font = w:_font("Medium"), TextSize = w:_ts(12), ClearTextOnFocus = false, LayoutOrder = 1 })
        w:_styleLabel(hexBox, "Medium", 12)
        pad(hexBox, 0, 9, 0, 9)
        w:_corner(hexBox, 0.4)
        w:_bind(hexBox, "BackgroundColor3", "Elevated")
        w:_bind(hexBox, "TextColor3", "Text")

        local function makeBar(label, init, color)
            local row = New("Frame", { Parent = picker, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = #picker:GetChildren() + 1 })
            local lbl = New("TextLabel", { Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0, 18, 1, 0), Text = label, Font = w:_font("Bold"), TextSize = w:_ts(10), TextXAlignment = Enum.TextXAlignment.Left })
            w:_styleLabel(lbl, "Bold", 10)
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

        -- HSV palette: saturation/value square + hue bar
        local hsvH, hsvS, hsvV = Color3.toHSV(current)
        local svArea = New("Frame", { Parent = picker, Size = UDim2.new(1, 0, 0, 110), BorderSizePixel = 0, LayoutOrder = #picker:GetChildren() + 1, BackgroundColor3 = Color3.fromHSV(hsvH, 1, 1) })
        w:_corner(svArea, 0.3)
        local svWhite = New("UIGradient", { Parent = svArea, Rotation = 0, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hsvH, 1, 1)) })
        local svBlack = New("Frame", { Parent = svArea, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 })
        w:_corner(svBlack, 0.3)
        New("UIGradient", { Parent = svBlack, Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) })
        local svCursor = New("Frame", { Parent = svArea, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3 })
        New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = svCursor })
        New("UIStroke", { Parent = svCursor, Thickness = 1.5, Color = Color3.new(0, 0, 0), Transparency = 0.4 })

        local hueHit = New("TextButton", { Parent = picker, Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = #picker:GetChildren() + 1, AutoButtonColor = false })
        local hueBar = New("Frame", { Parent = hueHit, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 })
        w:_corner(hueBar, "pill")
        New("UIGradient", { Parent = hueBar, Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
        }) })
        local hueCursor = New("Frame", { Parent = hueHit, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 18), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3 })
        New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = hueCursor })
        New("UIStroke", { Parent = hueCursor, Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.4 })

        local function update(v)
            current = v
            fill.BackgroundColor3 = current
            hexBox.Text = color3ToHex(current)
            rFill.Size = UDim2.new(current.R, 0, 1, 0)
            gFill.Size = UDim2.new(current.G, 0, 1, 0)
            bFill.Size = UDim2.new(current.B, 0, 1, 0)
            hsvH, hsvS, hsvV = Color3.toHSV(current)
            svArea.BackgroundColor3 = Color3.fromHSV(hsvH, 1, 1)
            svWhite.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hsvH, 1, 1))
            svCursor.Position = UDim2.new(hsvS, 0, 1 - hsvV, 0)
            hueCursor.Position = UDim2.new(hsvH, 0, 0.5, 0)
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

        -- SV square dragging
        local svDrag = false
        local function svFromInput(i)
            local ap, as = svArea.AbsolutePosition, svArea.AbsoluteSize
            local s = math.clamp((i.Position.X - ap.X) / math.max(as.X, 1), 0, 1)
            local v = 1 - math.clamp((i.Position.Y - ap.Y) / math.max(as.Y, 1), 0, 1)
            return s, v
        end
        svArea.InputBegan:Connect(function(i)
            if isPress(i) then svDrag = true; local s, v = svFromInput(i); update(Color3.fromHSV(hsvH, s, v)) end
        end)
        w:_connect(UserInputService.InputChanged, function(i)
            if svDrag and isMove(i) then local s, v = svFromInput(i); update(Color3.fromHSV(hsvH, s, v)) end
        end)
        w:_connect(UserInputService.InputEnded, function(i)
            if isPress(i) then if svDrag then push() end; svDrag = false end
        end)

        -- hue bar dragging
        local hueDrag = false
        local function hueFromInput(i)
            return math.clamp((i.Position.X - hueHit.AbsolutePosition.X) / math.max(hueHit.AbsoluteSize.X, 1), 0, 1)
        end
        hueHit.InputBegan:Connect(function(i)
            if isPress(i) then hueDrag = true; update(Color3.fromHSV(hueFromInput(i), hsvS, hsvV)) end
        end)
        w:_connect(UserInputService.InputChanged, function(i)
            if hueDrag and isMove(i) then update(Color3.fromHSV(hueFromInput(i), hsvS, hsvV)) end
        end)
        w:_connect(UserInputService.InputEnded, function(i)
            if isPress(i) then if hueDrag then push() end; hueDrag = false end
        end)

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
        local pct = New("TextLabel", rightAnchored({ Parent = header, Size = UDim2.fromOffset(60, 20), BackgroundTransparency = 1, Font = w:_font("Medium"), TextSize = w:_ts(13), TextXAlignment = Enum.TextXAlignment.Right }))
        w:_styleLabel(pct, "Medium", 13)
        w:_bind(pct, "TextColor3", "Accent")
        local bar = New("Frame", { Parent = card, Size = UDim2.new(1, 0, 0, 8), BorderSizePixel = 0, LayoutOrder = 2 })
        w:_corner(bar, "pill"); w:_bind(bar, "BackgroundColor3", "Elevated")
        local fill = New("Frame", { Parent = bar, Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) })
        w:_corner(fill, "pill")
        w:_bind(fill, "BackgroundColor3", "Accent")
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
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description, Tooltip = cfg.Tooltip }, 0)
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
            local label = New("TextLabel", { Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), Text = tostring(value), Font = w:_font("Medium"), TextSize = w:_ts(13), TextXAlignment = Enum.TextXAlignment.Left })
            w:_styleLabel(label, "Medium", 13)
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
        local minus = New("TextButton", { Parent = row, Size = UDim2.fromOffset(26, 26), Text = "−", Font = w:_font("Bold"), TextSize = w:_ts(16), AutoButtonColor = false })
        w:_styleLabel(minus, "Bold", 16)
        w:_corner(minus, 0.4); w:_bind(minus, "BackgroundColor3", "Elevated"); w:_bind(minus, "TextColor3", "Text")
        local box = New("TextBox", { Parent = row, Position = UDim2.fromOffset(30, 0), Size = UDim2.fromOffset(60, 26), Text = tostring(value), Font = w:_font("Medium"), TextSize = w:_ts(13), ClearTextOnFocus = false })
        w:_styleLabel(box, "Medium", 13)
        w:_corner(box, 0.4); w:_bind(box, "BackgroundColor3", "Elevated"); w:_bind(box, "TextColor3", "Text")
        local plus = New("TextButton", { Parent = row, Position = UDim2.fromOffset(94, 0), Size = UDim2.fromOffset(26, 26), Text = "+", Font = w:_font("Bold"), TextSize = w:_ts(16), AutoButtonColor = false })
        w:_styleLabel(plus, "Bold", 16)
        w:_corner(plus, 0.4); w:_bind(plus, "BackgroundColor3", "Elevated"); w:_bind(plus, "TextColor3", "Text")

        local function apply(v, silent)
            v = math.clamp(v, min, max)
            v = min + math.floor((v - min) / inc + 0.5) * inc
            value = v
            box.Text = tostring(v)
            if not silent then safe(cfg.Callback, v) end
        end
        box.FocusLost:Connect(function() apply(tonumber(box.Text) or value) end)
        minus.MouseButton1Click:Connect(function() apply(value - inc) end)
        plus.MouseButton1Click:Connect(function() apply(value + inc) end)
        apply(value, true)
        return self:_registerState(cfg, { Get = function() return value end, Set = function(_, v) apply(v) end })
    end

    function Tab:AddMultiInput(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description, Tooltip = cfg.Tooltip }, 0)
        local fields = cfg.Fields or {}
        local values, inputBoxes = {}, {}
        local container = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
        New("UIListLayout", { Parent = container, Padding = UDim.new(0, 6) })
        for _, spec in ipairs(fields) do
            local row = New("Frame", { Parent = container, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26) })
            local lbl = New("TextLabel", { Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0.4, -6, 1, 0), Text = spec.Name, Font = w:_font("Medium"), TextSize = w:_ts(12), TextXAlignment = Enum.TextXAlignment.Left })
            w:_styleLabel(lbl, "Medium", 12)
            w:_bind(lbl, "TextColor3", "SubText")
            local box = New("TextBox", { Parent = row, Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, 0, 1, 0), Text = spec.Default or "", PlaceholderText = spec.Placeholder or "", Font = w:_font("Normal"), TextSize = w:_ts(12), ClearTextOnFocus = false })
            w:_styleLabel(box, "Normal", 12)
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
        local card = self:_card({ Title = cfg.Title or "Search", Description = cfg.Description, Tooltip = cfg.Tooltip }, 0)
        local box = New("TextBox", { Parent = card, Size = UDim2.new(1, 0, 0, 28), Text = "", PlaceholderText = cfg.Placeholder or "Search...", Font = w:_font("Normal"), TextSize = w:_ts(12), ClearTextOnFocus = false, LayoutOrder = 2 })
        w:_styleLabel(box, "Normal", 12)
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
                    local l = New("TextLabel", { Parent = results, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Text = tostring(v), Font = w:_font("Medium"), TextSize = w:_ts(13), TextXAlignment = Enum.TextXAlignment.Left })
                    w:_styleLabel(l, "Medium", 13)
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
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description, Tooltip = cfg.Tooltip }, 0)
        local state = {}
        for _, v in ipairs(cfg.Default or {}) do state[v] = true end
        local rows = {}
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
            local tick = New("TextLabel", { Parent = box, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "✓", Font = w:_font("Bold"), TextSize = w:_ts(12), TextColor3 = Color3.new(1,1,1), Visible = false })
            w:_styleLabel(tick, "Bold", 12)
            local label = New("TextLabel", { Parent = row, BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), Text = tostring(value), Font = w:_font("Medium"), TextSize = w:_ts(13), TextXAlignment = Enum.TextXAlignment.Left })
            w:_styleLabel(label, "Medium", 13)
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
        local card = self:_card({ Title = cfg.Title or "Code", Description = cfg.Description, Tooltip = cfg.Tooltip }, 0)
        local box = New("TextBox", { Parent = card, Size = UDim2.new(1, 0, 0, cfg.Height or 110), Text = cfg.Default or "", Font = Enum.Font.Code, TextSize = w:_ts(12), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, MultiLine = true, ClearTextOnFocus = false, LayoutOrder = 2 })
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

    ------------------------------------------------------------------ new in 1.3: segmented / callout / console / key-value
    -- Pill selector with a sliding accent indicator.
    function Tab:AddSegmented(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description, Tooltip = cfg.Tooltip, Badge = cfg.Badge }, 0)
        local values = cfg.Values or {}
        local n = math.max(#values, 1)
        local selected = cfg.Default
        if selected == nil then selected = values[1] end

        local track = New("Frame", { Parent = card, Size = UDim2.new(1, 0, 0, w._touch and 36 or 30), BorderSizePixel = 0, LayoutOrder = 2 })
        w:_corner(track, "pill")
        w:_bind(track, "BackgroundColor3", "Elevated")
        local indicator = New("Frame", {
            Parent = track, Size = UDim2.new(1 / n, -6, 1, -6), Position = UDim2.new(0, 3, 0, 3),
            BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
        })
        w:_corner(indicator, "pill")
        w:_bind(indicator, "BackgroundColor3", "Accent")

        local labels = {}
        local function indexOf(v)
            for i, x in ipairs(values) do if x == v then return i end end
            return 1
        end
        local function paint(animate)
            local idx = indexOf(selected)
            local pos = UDim2.new((idx - 1) / n, 3, 0, 3)
            if animate then tween(indicator, { Position = pos }, TI_POP) else indicator.Position = pos end
            for i, l in ipairs(labels) do
                local goal = i == idx and w.Theme.AccentText or w.Theme.SubText
                if animate then tween(l, { TextColor3 = goal }, TI) else l.TextColor3 = goal end
            end
        end
        local obj = {}
        for i, val in ipairs(values) do
            local b = New("TextButton", {
                Parent = track, BackgroundTransparency = 1, AutoButtonColor = false,
                Size = UDim2.new(1 / n, 0, 1, 0), Position = UDim2.new((i - 1) / n, 0, 0, 0),
                Text = tostring(val), Font = w:_font("Bold"), TextSize = w:_ts(11), TextTruncate = Enum.TextTruncate.AtEnd,
            })
            w:_styleLabel(b, "Bold", 11)
            labels[i] = b
            b.MouseButton1Click:Connect(function()
                if selected == val then return end
                selected = val; paint(true); safe(cfg.Callback, val)
            end)
        end
        w:_onTheme(track, function() paint(false) end)
        function obj:Get() return selected end
        function obj:Set(v) selected = v; paint(true); safe(cfg.Callback, v) end
        return self:_registerState(cfg, obj)
    end

    -- Tinted alert box. cfg: Title, Message, Type = info|success|warning|error, Color
    function Tab:AddCallout(cfg)
        local w = self.Window
        local kind = NOTIF_TYPES[string.lower(tostring(cfg.Type or "info"))] or NOTIF_TYPES.info
        local color = cfg.Color or kind.color
        local outer = New("Frame", {
            Parent = self:_host(), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = color, BackgroundTransparency = 0.88, BorderSizePixel = 0, LayoutOrder = self:_next(),
        })
        w:_corner(outer, 0.35)
        New("UIStroke", { Parent = outer, Color = color, Thickness = 1, Transparency = 0.7 })
        local bar = New("Frame", { Parent = outer, Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = color, BorderSizePixel = 0 })
        w:_corner(bar, "pill")
        local inner = New("Frame", { Parent = outer, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
        pad(inner, 10, 12, 10, 22)
        New("UIListLayout", { Parent = inner, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
        local title = w:_text(inner, cfg.Title or "", 13, w:_font("Bold"), "Text")
        title.TextColor3 = color
        title.LayoutOrder = 1
        -- colour is fixed, so drop the theme binding the helper created
        for i = #w._painters, 1, -1 do
            if w._painters[i].inst == title then table.remove(w._painters, i) end
        end
        local body = w:_text(inner, cfg.Message or cfg.Description or "", 12, w:_font("Normal"), "SubText")
        body.LayoutOrder = 2
        title.Visible = (cfg.Title or "") ~= ""
        body.Visible = (cfg.Message or cfg.Description or "") ~= ""
        return {
            Set = function(_, t, m)
                if t ~= nil then title.Text = tostring(t); title.Visible = tostring(t) ~= "" end
                if m ~= nil then body.Text = tostring(m); body.Visible = tostring(m) ~= "" end
            end,
            Destroy = function() outer:Destroy() end,
        }
    end

    -- Scrolling log. :Log(text, level)  :Clear()  :Get()
    function Tab:AddConsole(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title or "Console", Description = cfg.Description, Tooltip = cfg.Tooltip }, 0)
        local view = New("ScrollingFrame", {
            Parent = card, Size = UDim2.new(1, 0, 0, cfg.Height or 150), BorderSizePixel = 0, ScrollBarThickness = 3,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 2,
        })
        w:_corner(view, 0.3)
        w:_bind(view, "BackgroundColor3", "Elevated")
        w:_bind(view, "ScrollBarImageColor3", "Stroke")
        pad(view, 6, 8, 6, 8)
        New("UIListLayout", { Parent = view, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
        local lines, count, maxLines = {}, 0, cfg.MaxLines or 200
        local obj = {}
        function obj:Log(text, level)
            level = string.lower(tostring(level or "info"))
            count += 1
            local stamp = cfg.Timestamps ~= false and ("[" .. os.date("%H:%M:%S") .. "] ") or ""
            local l = New("TextLabel", {
                Parent = view, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = count, Text = stamp .. tostring(text), Font = Enum.Font.Code, TextSize = w:_ts(11),
                TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            })
            if NOTIF_TYPES[level] then
                l.TextColor3 = NOTIF_TYPES[level].color
            elseif level == "debug" then
                w:_bind(l, "TextColor3", "SubText")
            else
                w:_bind(l, "TextColor3", "Text")
            end
            table.insert(lines, l)
            if #lines > maxLines then table.remove(lines, 1):Destroy() end
            task.defer(function()
                if view.Parent then view.CanvasPosition = Vector2.new(0, 1e6) end
            end)
        end
        function obj:Clear()
            for _, l in ipairs(lines) do l:Destroy() end
            lines = {}
        end
        function obj:Get()
            local t = {}
            for _, l in ipairs(lines) do table.insert(t, l.Text) end
            return table.concat(t, "\n")
        end
        return obj
    end

    -- Read-only rows of "name .... value". :Set(key, value)  :SetRows(rows)
    function Tab:AddKeyValue(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description, Tooltip = cfg.Tooltip }, 0)
        local holder = New("Frame", { Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
        New("UIListLayout", { Parent = holder, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
        local valueLabels, obj = {}, {}
        local function build(rows)
            for _, c in ipairs(holder:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
            valueLabels = {}
            for i, r in ipairs(rows or {}) do
                local row = New("Frame", { Parent = holder, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = i })
                local k = New("TextLabel", { Parent = row, BackgroundTransparency = 1, Size = UDim2.new(0.5, 0, 1, 0), Text = tostring(r[1]), Font = w:_font("Normal"), TextSize = w:_ts(12), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
                w:_styleLabel(k, "Normal", 12); w:_bind(k, "TextColor3", "SubText")
                local v = New("TextLabel", { Parent = row, BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.5, 0, 1, 0), Text = tostring(r[2]), Font = w:_font("Medium"), TextSize = w:_ts(12), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd })
                w:_styleLabel(v, "Medium", 12); w:_bind(v, "TextColor3", "Text")
                valueLabels[tostring(r[1])] = v
            end
        end
        build(cfg.Rows)
        function obj:Set(key, value)
            local l = valueLabels[tostring(key)]
            if l then l.Text = tostring(value) end
        end
        function obj:SetRows(rows) build(rows) end
        function obj:Destroy() card:Destroy() end
        return obj
    end

    ------------------------------------------------------------------ graphs & data widgets
    -- Shared rotated-segment line renderer. points = array of Vector2 (px).
    local function drawLine(w, plot, points, thickness, withFill, withDots)
        for _, c in ipairs(plot:GetChildren()) do c:Destroy() end
        local n = #points
        if n < 2 then return end
        -- gradient fill under the line
        if withFill then
            for i = 1, n - 1 do
                local p1, p2 = points[i], points[i + 1]
                local x = p1.X
                local width = math.max(p2.X - p1.X, 1) + 1
                local top = math.min(p1.Y, p2.Y)
                local bar = New("Frame", {
                    Parent = plot, Position = UDim2.fromOffset(x, top),
                    Size = UDim2.fromOffset(width, math.max(plot.AbsoluteSize.Y - top, 0)),
                    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1,
                })
                local g = New("UIGradient", { Parent = bar, Rotation = 90 })
                g.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.55),
                    NumberSequenceKeypoint.new(1, 1),
                })
                w:_onTheme(bar, function()
                    local a = w.Theme.Accent
                    g.Color = ColorSequence.new(a, a)
                end)
            end
        end
        -- line segments (rotated frames)
        for i = 1, n - 1 do
            local p1, p2 = points[i], points[i + 1]
            local dx, dy = p2.X - p1.X, p2.Y - p1.Y
            local len = math.sqrt(dx * dx + dy * dy)
            local seg = New("Frame", {
                Parent = plot, AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(p1.X + dx / 2, p1.Y + dy / 2),
                Size = UDim2.fromOffset(len, thickness or 2),
                Rotation = math.deg(math.atan2(dy, dx)),
                BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3,
            })
            w:_bind(seg, "BackgroundColor3", "Accent")
        end
        if withDots ~= false then
            for _, p in ipairs(points) do
                local dot = New("Frame", {
                    Parent = plot, AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(6, 6),
                    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4,
                })
                w:_corner(dot, "pill")
                w:_bind(dot, "BackgroundColor3", "Accent")
            end
        end
    end

    function Tab:AddLineGraph(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description, Tooltip = cfg.Tooltip }, 0)
        local plot = New("Frame", {
            Parent = card, Size = UDim2.new(1, 0, 0, cfg.Height or 120),
            BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = 2, BorderSizePixel = 0,
        })
        local obj = { values = cfg.Values or {} }
        local function redraw()
            local vals = obj.values
            local W, H = plot.AbsoluteSize.X, plot.AbsoluteSize.Y
            if W < 20 or H < 20 or #vals < 2 then return end
            local min, max = math.min(table.unpack(vals)), math.max(table.unpack(vals))
            if max == min then max = min + 1 end
            local points = {}
            for i, v in ipairs(vals) do
                local x = (i - 1) / (#vals - 1) * (W - 8) + 4
                local y = H - 6 - ((v - min) / (max - min)) * (H - 12)
                table.insert(points, Vector2.new(x, y))
            end
            drawLine(w, plot, points, cfg.Thickness or 2, cfg.Fill ~= false, cfg.Dots ~= false)
        end
        plot:GetPropertyChangedSignal("AbsoluteSize"):Connect(redraw)
        task.defer(redraw)
        function obj:Set(values) obj.values = values; redraw() end
        function obj:Get() return obj.values end
        return obj
    end

    function Tab:AddStatCard(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description, Tooltip = cfg.Tooltip, Badge = cfg.Badge }, 0)
        local valueLabel = New("TextLabel", {
            Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30),
            Text = tostring(cfg.Value or 0), Font = w:_font("Bold"), TextSize = w:_ts(26),
            TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2,
        })
        w:_styleLabel(valueLabel, "Bold", 26)
        w:_bind(valueLabel, "TextColor3", "Text")
        local trend = New("TextLabel", {
            Parent = card, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
            Text = "", Font = w:_font("Bold"), TextSize = w:_ts(12),
            TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 3,
        })
        w:_styleLabel(trend, "Bold", 12)
        local spark = New("Frame", {
            Parent = card, Size = UDim2.new(1, 0, 0, cfg.SparkHeight or 34),
            BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = 4, BorderSizePixel = 0,
        })
        local obj = { values = cfg.Values or {} }
        local function redrawSpark()
            local vals = obj.values
            local W, H = spark.AbsoluteSize.X, spark.AbsoluteSize.Y
            if W < 10 or H < 10 or #vals < 2 then return end
            local min, max = math.min(table.unpack(vals)), math.max(table.unpack(vals))
            if max == min then max = min + 1 end
            local points = {}
            for i, v in ipairs(vals) do
                table.insert(points, Vector2.new((i - 1) / (#vals - 1) * (W - 4) + 2, H - 2 - ((v - min) / (max - min)) * (H - 4)))
            end
            drawLine(w, spark, points, 2, false, false)
        end
        spark:GetPropertyChangedSignal("AbsoluteSize"):Connect(redrawSpark)
        local function paintTrend(delta)
            local num = tonumber(delta)
            if num == nil then trend.Text = tostring(delta or ""); trend.TextColor3 = w.Theme.SubText; return end
            local arrow = num > 0 and "▲" or (num < 0 and "▼" or "■")
            trend.Text = arrow .. " " .. formatNumber(math.abs(num))
            trend.TextColor3 = num > 0 and rgb(52, 199, 89) or (num < 0 and rgb(239, 68, 68) or w.Theme.SubText)
        end
        paintTrend(cfg.Delta)
        task.defer(redrawSpark)
        function obj:Set(value, delta, values)
            if value ~= nil then valueLabel.Text = tostring(value) end
            if delta ~= nil then paintTrend(delta) end
            if values ~= nil then obj.values = values; redrawSpark() end
        end
        function obj:Get() return { value = valueLabel.Text, values = obj.values } end
        return obj
    end

    function Tab:AddGauge(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title, Description = cfg.Description, Tooltip = cfg.Tooltip }, 0)
        local size = cfg.Size or 120
        local holder = New("Frame", {
            Parent = card, Size = UDim2.new(1, 0, 0, size), BackgroundTransparency = 1,
            LayoutOrder = 2, BorderSizePixel = 0,
        })
        local cx, cy, r = size / 2, size / 2, size / 2 - 6
        local N = 48
        local segs = {}
        local arcLen = (2 * math.pi * r) / N + 1.5
        for i = 1, N do
            local a = (i / N) * math.pi * 2 - math.pi / 2
            local seg = New("Frame", {
                Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(cx + math.cos(a) * r, cy + math.sin(a) * r),
                Size = UDim2.fromOffset(arcLen, 5), Rotation = math.deg(a) + 90,
                BorderSizePixel = 0,
            })
            w:_corner(seg, "pill")
            segs[i] = seg
        end
        local valueLabel = New("TextLabel", {
            Parent = holder, BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0.5, -12),
            Size = UDim2.new(1, 0, 0, 24), Text = "", Font = w:_font("Bold"), TextSize = w:_ts(20),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        w:_styleLabel(valueLabel, "Bold", 20)
        w:_bind(valueLabel, "TextColor3", "Text")

        local obj = { Value = math.clamp(cfg.Default or 0, 0, 1) }
        local function paint()
            local th = w.Theme
            local v = obj.Value
            for i = 1, N do
                local on = (i / N) <= v + 1e-6
                segs[i].BackgroundColor3 = on and th.Accent or th.Elevated
            end
            local shown = cfg.Max or 1
            valueLabel.Text = formatNumber(v * shown) .. (cfg.Suffix or "")
        end
        w:_onTheme(holder, paint)
        function obj:Set(v) obj.Value = math.clamp(tonumber(v) or 0, 0, 1); paint(); end
        function obj:Get() return obj.Value end
        paint()
        return self:_registerState(cfg, obj)
    end

    -- Skeleton shimmer placeholder for loading data.
    function Tab:AddSkeleton(cfg)
        local w = self.Window
        local card = self:_card({ Title = cfg.Title or "", Description = cfg.Description, Tooltip = cfg.Tooltip }, 0)
        local rows = cfg.Rows or 3
        for i = 1, rows do
            local bar = New("Frame", {
                Parent = card, Size = UDim2.new(1, 0, 0, i == 1 and 18 or 12),
                BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, LayoutOrder = i + 1,
            })
            w:_corner(bar, 0.3)
            local g = New("UIGradient", { Parent = bar, Offset = Vector2.new(-1, 0) })
            w:_onTheme(bar, function()
                g.Color = ColorSequence.new(w.Theme.Elevated, w.Theme.Text, w.Theme.Elevated)
                g.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.4),
                    NumberSequenceKeypoint.new(0.5, 0.05),
                    NumberSequenceKeypoint.new(1, 0.4),
                })
            end)
            local shimmer = TweenService:Create(g, TweenInfo.new(1.3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false), { Offset = Vector2.new(1, 0) })
            shimmer:Play()
        end
        return { Destroy = function() card:Destroy() end }
    end

    -- Config manager: profile save / load / delete via executor file APIs,
    -- plus clipboard export, JSON import and an "autoload" profile.
    function Tab:AddConfigSection(window)
        local w = window or self.Window

        -- status paragraph for feedback
        local status = self:AddParagraph({ Title = "Status", Description = "Ready." })
        self:AddDivider()

        if type(makefolder) == "function" and type(isfolder) == "function" then
            if not isfolder(CONFIG_FOLDER) then pcall(makefolder, CONFIG_FOLDER) end
        end

        -- ==========================================
        -- 1. PROFILE MANAGEMENT
        -- ==========================================
        self:AddSection("Profile Settings")

        local nameInput = self:AddInput({
            Title = "Profile name",
            Placeholder = "e.g. MyConfig",
            Default = "default",
        })

        local function profilePath(name)
            if #name > 48 or not name:match("^[%w_-]+$") then
                error("Use 1-48 letters, numbers, underscores, or hyphens for the profile name.")
            end
            return CONFIG_FOLDER .. "/" .. name .. ".json"
        end

        local function refreshProfiles()
            if type(listfiles) ~= "function" then return {} end
            local ok, files = pcall(listfiles, CONFIG_FOLDER)
            if not ok or not files then return {} end
            local names = {}
            for _, file in ipairs(files) do
                local name = tostring(file):match("([^/\\]+)%.json$")
                if name then table.insert(names, name) end
            end
            table.sort(names)
            return names
        end

        local selectedProfile = ""
        local profileDropdown = self:AddDropdown({
            Title = "Saved profiles",
            Values = (function() local n = refreshProfiles() return #n > 0 and n or { "No configs found" } end)(),
            Default = "",
            Callback = function(value) selectedProfile = value end,
        })

        local function report(action, ok, detail)
            status:Set(ok and (action .. " successfully.") or (action .. " failed: " .. tostring(detail)))
            w:Notify({
                Title = ok and (action .. " complete") or (action .. " failed"),
                Message = ok and ("Profile " .. action:lower() .. " successfully.") or tostring(detail),
                Type = ok and "success" or "error",
                Duration = 3,
            })
        end

        self:AddButton({
            Title = "Save profile",
            Description = "Save the current interface and widget values.",
            Style = "primary", ButtonText = "Save",
            Callback = function()
                local ok, err = pcall(function()
                    local saveName = nameInput:Get()
                    if saveName == "" then saveName = selectedProfile end
                    if saveName == "" or saveName == "No configs found" then
                        error("enter a profile name first")
                    end
                    if type(writefile) ~= "function" then error("executor does not expose writefile") end
                    local path = profilePath(saveName)
                    if type(makefolder) == "function" and type(isfolder) == "function" then
                        local folderOk, exists = pcall(isfolder, CONFIG_FOLDER)
                        if folderOk and not exists then makefolder(CONFIG_FOLDER) end
                    end
                    writefile(path, HttpService:JSONEncode(w:_collectState()))
                    profileDropdown:SetValues(refreshProfiles())
                    profileDropdown:Set(saveName)
                    selectedProfile = saveName
                end)
                report("Save", ok, err)
            end,
        })

        self:AddButton({
            Title = "Load selected profile",
            Callback = function()
                local ok, err = pcall(function()
                    if selectedProfile == "" or selectedProfile == "No configs found" then
                        error("select a profile first")
                    end
                    local path = profilePath(selectedProfile)
                    if type(isfile) ~= "function" or type(readfile) ~= "function" then
                        error("executor does not expose readfile/isfile")
                    end
                    if not isfile(path) then error("file not found: " .. path) end
                    local data = HttpService:JSONDecode(readfile(path))
                    if type(data) ~= "table" then error("invalid config data") end
                    w:_applyState(data)
                    nameInput:Set(selectedProfile)
                end)
                report("Load", ok, err)
            end,
        })

        self:AddButton({
            Title = "Delete selected profile",
            Style = "danger", ButtonText = "Delete",
            Callback = function()
                if selectedProfile == "" or selectedProfile == "No configs found" then
                    report("Delete", false, "select a profile to delete")
                    return
                end
                local target = selectedProfile
                w:Dialog({
                    Title = "Delete profile?",
                    Message = "'" .. target .. "' will be permanently removed.",
                    Buttons = {
                        { Text = "Cancel" },
                        { Text = "Delete", Style = "danger", Callback = function()
                            local ok, err = pcall(function()
                                if type(delfile) ~= "function" then error("executor does not expose delfile") end
                                local okDel, errDel = pcall(delfile, profilePath(target))
                                if not okDel then error(errDel) end
                                selectedProfile = ""
                                profileDropdown:SetValues(refreshProfiles())
                            end)
                            report("Delete", ok, err)
                        end },
                    },
                })
            end,
        })

        self:AddButton({
            Title = "Refresh profiles",
            Callback = function()
                local names = refreshProfiles()
                profileDropdown:SetValues(#names > 0 and names or { "No configs found" })
                status:Set(#names > 0 and ("Found " .. #names .. " profile(s).") or "No configs found.")
            end,
        })

        -- ==========================================
        -- 2. AUTOLOAD
        -- ==========================================
        self:AddSection("Autoload")

        self:AddButton({
            Title = "Use selected profile on startup",
            Description = "It is applied automatically the next time the script runs.",
            Callback = function()
                local ok, err = pcall(function()
                    if selectedProfile == "" or selectedProfile == "No configs found" then error("select a profile first") end
                    if type(writefile) ~= "function" then error("executor does not expose writefile") end
                    profilePath(selectedProfile)
                    writefile(CONFIG_FOLDER .. "/_autoload.txt", selectedProfile)
                end)
                report("Autoload set", ok, err)
            end,
        })

        self:AddButton({
            Title = "Clear autoload",
            Callback = function()
                local ok, err = pcall(function()
                    local f = CONFIG_FOLDER .. "/_autoload.txt"
                    if type(isfile) == "function" and isfile(f) and type(delfile) == "function" then delfile(f) end
                end)
                report("Autoload cleared", ok, err)
            end,
        })

        -- ==========================================
        -- 3. IMPORT / EXPORT
        -- ==========================================
        self:AddSection("Import / Export")

        self:AddButton({
            Title = "Export to clipboard",
            Callback = function()
                local ok, result = pcall(function() return HttpService:JSONEncode(w:_collectState()) end)
                if not ok then
                    status:Set("Export failed: " .. tostring(result))
                    w:Notify({ Title = "Export failed", Message = tostring(result), Type = "error", Duration = 3 })
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

        local importBox = self:AddCodeBox({
            Title = "Import JSON",
            Placeholder = "Paste config JSON here...",
            Height = 110,
        })

        self:AddButton({
            Title = "Apply imported JSON",
            Callback = function()
                local ok, err = pcall(function()
                    local raw = importBox:Get()
                    if raw == "" or not raw:match("%S") then error("paste JSON first") end
                    local data = HttpService:JSONDecode(raw)
                    if type(data) ~= "table" then error("invalid JSON format") end
                    w:_applyState(data)
                end)
                report("Import", ok, err)
            end,
        })

        -- apply the autoload profile once the rest of the UI has been built
        task.delay(1.5, function()
            if w.Gui and w.Gui.Parent then w:LoadAutoload() end
        end)
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
            version = 4,
            theme = type(self._themeName) == "string" and self._themeName or "custom",
            themeData = type(self._themeName) == "table" and encodeConfigValue(self._themeName) or nil,
            accent = self._accent and encodeConfigValue(self._accent) or nil,
            corner = self.CornerRadius,
            size = { X = self._size.X, Y = self._size.Y },
            font = self._fontName,
            textScale = self.TextScale,
            density = self.Density,
            glass = self._glass,
            pattern = self._pattern,
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
        if type(s.font) == "string" then self:SetFont(s.font) end
        if type(s.textScale) == "number" then self:SetTextScale(s.textScale) end
        if type(s.density) == "string" then self:SetDensity(s.density) end
        if type(s.glass) == "number" then self:SetGlass(s.glass) end
        if type(s.pattern) == "string" then self:SetPattern(s.pattern) end
    end

    -- Applies the profile marked as autoload in the config tab (safe to call any time).
    function Window:LoadAutoload()
        pcall(function()
            local f = CONFIG_FOLDER .. "/_autoload.txt"
            if type(isfile) ~= "function" or type(readfile) ~= "function" or not isfile(f) then return end
            local name = (readfile(f):gsub("%s+", ""))
            if not name:match("^[%w_-]+$") then return end
            local path = CONFIG_FOLDER .. "/" .. name .. ".json"
            if not isfile(path) then return end
            self:_applyState(HttpService:JSONDecode(readfile(path)))
            self:Notify({ Title = "Profile loaded", Message = "Autoloaded '" .. name .. "'.", Type = "success", Duration = 3 })
        end)
    end

    function Library:CreateWindow(cfg)
        cfg = cfg or {}
        local self = setmetatable({ Tabs = {}, _painters = {}, _corners = {}, _conns = {}, _notifId = 0, _stateWidgets = {}, _textRegs = {}, _densityRegs = {}, _searchIndex = {}, _patterns = {}, _groupLabels = {} }, Window)
        self._themeName = cfg.Theme or "Midnight"
        self._accent    = cfg.Accent
        self._baseAccent = cfg.Accent
        self.CornerRadius = math.clamp(cfg.CornerRadius or 12, 0, 28)
        self.ToggleKey    = cfg.ToggleKey or Enum.KeyCode.RightShift
        self._size        = cfg.Size or Vector2.new(620, 420)
        self._minimized   = false
        self._fontName    = FONT_MAP[cfg.Font] and cfg.Font or "BuilderSans"
        self.TextScale    = math.clamp(tonumber(cfg.TextScale) or 1, 0.8, 1.3)
        self._glass       = math.clamp(tonumber(cfg.Glass) or 0, 0, 1)
        self._pattern     = cfg.Pattern or "none"
        self._glow        = cfg.Glow == true
        if cfg.Mobile == nil then self._touch = touchOnly() else self._touch = cfg.Mobile == true end
        self:_buildTheme()
        self:SetDensity(cfg.Density == "compact" and "compact" or "comfortable")

        local size = self._size
        local gui = New("ScreenGui", { Name = "PrismUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100, IgnoreGuiInset = true })
        self.Gui = gui

        -- fit the screen by resizing (text stays readable on phones); Scale is optional
        local baseSize = size
        local cam0 = workspace.CurrentCamera
        local inset0 = GuiService:GetGuiInset()
        local function fitSize()
            local vp = cam0 and cam0.ViewportSize or Vector2.new(1280, 720)
            local ax, ay = vp.X - 20, vp.Y - inset0.Y - 20
            return Vector2.new(math.max(math.min(baseSize.X, ax), 300), math.max(math.min(baseSize.Y, ay), 220))
        end
        size = fitSize()
        self._size = size
        self._userScale = math.clamp(tonumber(cfg.Scale) or 1, 0.5, 1.5)

        local holder = New("Frame", { Name = "Window", Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, inset0.Y / 2), Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1 })
        local scale  = New("UIScale", { Parent = holder, Scale = 0.92 * self._userScale })
        self.Holder, self._scale = holder, scale
        tween(scale, { Scale = self._userScale }, TI_POP)

        -- optional accent glow behind the window
        local glow = New("ImageLabel", {
            Parent = holder, BackgroundTransparency = 1, Image = SHADOW_IMAGE,
            ScaleType = Enum.ScaleType.Slice, SliceCenter = SHADOW_SLICE,
            Size = UDim2.new(1, 40, 1, 40), Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = -1, Visible = self._glow,
        })
        self:_onTheme(glow, function()
            glow.ImageColor3 = self.Theme.Accent
            glow.ImageTransparency = 0.65
        end)
        self._glowImage = glow

        local main = New("Frame", { Name = "Main", Parent = holder, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ClipsDescendants = true })
        self:_bind(main, "BackgroundColor3", "Background")
        self:_glassify(main, 0.55)
        self:_corner(main, 1)
        local borderStroke = self:_stroke(main, "Stroke")
        self._borderStroke = borderStroke

        -- header: brand dot, title, subtitle and tags on one line; plain icon buttons on the right
        local HEADER_H = self._touch and 52 or 46
        self._headerH = HEADER_H
        local top = New("Frame", { Name = "Header", Parent = main, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, HEADER_H) })
        self._header = top
        local headerLine = New("Frame", { Parent = main, Position = UDim2.fromOffset(0, HEADER_H), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0 })
        self:_bind(headerLine, "BackgroundColor3", "Stroke")

        local BTN = self._touch and 36 or 28
        local titleRow = New("Frame", {
            Parent = top, BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 0),
            Size = UDim2.new(1, -(BTN * 2 + 44), 1, 0), ClipsDescendants = true,
        })
        New("UIListLayout", {
            Parent = titleRow, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
        })
        local brandDot = New("Frame", { Parent = titleRow, Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, LayoutOrder = 0 })
        self:_corner(brandDot, "pill")
        self:_bind(brandDot, "BackgroundColor3", "Accent")
        local brandTitle = New("TextLabel", {
            Parent = titleRow, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20),
            Text = cfg.Title or "PrismUI", Font = self:_font("Bold"), TextSize = self:_ts(15),
            TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1,
        })
        self:_styleLabel(brandTitle, "Bold", 15)
        self:_bind(brandTitle, "TextColor3", "Text")
        if cfg.Subtitle then
            local subText = cfg.Subtitle == "auto" and ("@" .. tostring(Players.LocalPlayer and Players.LocalPlayer.Name or "player")) or tostring(cfg.Subtitle)
            local sub = New("TextLabel", {
                Parent = titleRow, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20),
                Text = subText, Font = self:_font("Medium"), TextSize = self:_ts(12), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2,
            })
            self:_styleLabel(sub, "Medium", 12)
            self:_bind(sub, "TextColor3", "SubText")
        end
        for index, tag in ipairs(cfg.Tags or {}) do
            local text, color
            if type(tag) == "table" then
                text, color = tostring(tag.Text or tag.Name or ""), tag.Color
                if typeof(color) ~= "Color3" then color = nil end
            else
                text = tostring(tag)
            end
            if text ~= "" then
                local pill = New("TextLabel", {
                    Parent = titleRow, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), BorderSizePixel = 0,
                    Text = string.upper(text), Font = self:_font("Bold"), TextSize = self:_ts(9), LayoutOrder = 2 + index,
                })
                self:_styleLabel(pill, "Bold", 9)
                self:_corner(pill, "pill")
                pad(pill, 0, 7, 0, 7)
                if color then
                    pill.TextColor3 = color
                    self:_onTheme(pill, function() pill.BackgroundColor3 = color:Lerp(self.Theme.Background, 0.85) end)
                else
                    self:_bind(pill, "BackgroundColor3", "Elevated")
                    self:_bind(pill, "TextColor3", "SubText")
                end
            end
        end

        local function topButton(iconName, x, danger)
            local b = New("TextButton", {
                Parent = top, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0),
                Size = UDim2.fromOffset(BTN, BTN), Text = "", AutoButtonColor = false,
                BackgroundTransparency = 1, BorderSizePixel = 0,
            })
            self:_corner(b, 0.6)
            local image = New("ImageLabel", {
                Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Image = resolveIcon(iconName),
            })
            self:_onTheme(b, function()
                b.BackgroundColor3 = danger and rgb(220, 70, 84) or self.Theme.Elevated
                image.ImageColor3 = self.Theme.SubText
            end)
            b.MouseEnter:Connect(function()
                if self._touch then return end
                tween(b, { BackgroundTransparency = 0 }, TI)
                tween(image, { ImageColor3 = danger and Color3.new(1, 1, 1) or self.Theme.Text }, TI)
            end)
            b.MouseLeave:Connect(function()
                tween(b, { BackgroundTransparency = 1 }, TI)
                tween(image, { ImageColor3 = self.Theme.SubText }, TI)
            end)
            return b, image
        end
        local closeBtn = topButton("x", -10, true)
        local minBtn, minIcon = topButton("minimize-2", -(14 + BTN))
        self._minButton, self._minIcon = minBtn, minIcon

        -- body: sidebar (or a horizontal tab strip on narrow screens) + pages
        local body = New("Frame", { Parent = main, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, HEADER_H + 1), Size = UDim2.new(1, 0, 1, -(HEADER_H + 1)) })
        self._body = body
        local sidebar = New("Frame", { Parent = body, BackgroundTransparency = 1, BorderSizePixel = 0 })
        self._sidebar = sidebar
        local sideLine = New("Frame", { Parent = body, BorderSizePixel = 0 })
        self:_bind(sideLine, "BackgroundColor3", "Stroke")
        self._sideLine = sideLine

        -- sidebar search: filters widgets in every tab
        self._searchH = self._touch and 34 or 30
        local searchBox = New("TextBox", {
            Parent = sidebar, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, self._searchH), Text = "",
            PlaceholderText = "Search", Font = self:_font("Normal"), TextSize = self:_ts(12),
            TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, BorderSizePixel = 0, ClipsDescendants = true,
        })
        self:_styleLabel(searchBox, "Normal", 12)
        pad(searchBox, 0, 10, 0, 10)
        self:_corner(searchBox, 0.6)
        self:_bind(searchBox, "BackgroundColor3", "Surface")
        self:_bind(searchBox, "TextColor3", "Text")
        self:_bind(searchBox, "PlaceholderColor3", "SubText")
        local searchStroke = self:_stroke(searchBox, "Accent")
        searchStroke.Transparency = 1
        searchBox.Focused:Connect(function() tween(searchStroke, { Transparency = 0.3 }) end)
        searchBox.FocusLost:Connect(function() tween(searchStroke, { Transparency = 1 }) end)
        searchBox:GetPropertyChangedSignal("Text"):Connect(function() self:_applySearch(searchBox.Text) end)
        self._searchBox = searchBox

        local tabList = New("ScrollingFrame", { Parent = sidebar, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = 0 })
        self._tabPad = New("UIPadding", { Parent = tabList })
        self._tabLayout = New("UIListLayout", { Parent = tabList, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
        self._tabList = tabList

        -- player row at the bottom of the sidebar
        if cfg.Profile ~= false and Players.LocalPlayer ~= nil then
            local lp = Players.LocalPlayer
            local footer = New("Frame", {
                Parent = sidebar, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8),
                Size = UDim2.new(1, -16, 0, 40), BackgroundTransparency = 1, BorderSizePixel = 0,
            })
            local avatar = New("ImageLabel", {
                Parent = footer, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0),
                Size = UDim2.fromOffset(28, 28), BorderSizePixel = 0,
            })
            self:_corner(avatar, "pill")
            self:_bind(avatar, "BackgroundColor3", "Elevated")
            task.spawn(function()
                local ok, img = pcall(function()
                    return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
                end)
                if ok and avatar.Parent then avatar.Image = img end
            end)
            local nameLabel = New("TextLabel", {
                Parent = footer, BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 6), Size = UDim2.new(1, -44, 0, 14),
                Text = lp.DisplayName, Font = self:_font("Medium"), TextSize = self:_ts(12),
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            })
            self:_styleLabel(nameLabel, "Medium", 12)
            self:_bind(nameLabel, "TextColor3", "Text")
            local handle = New("TextLabel", {
                Parent = footer, BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 21), Size = UDim2.new(1, -44, 0, 12),
                Text = "@" .. lp.Name, Font = self:_font("Normal"), TextSize = self:_ts(10),
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            })
            self:_styleLabel(handle, "Normal", 10)
            self:_bind(handle, "TextColor3", "SubText")
            self._footer = footer
        end

        self._pages = New("Frame", { Parent = body, BackgroundTransparency = 1, ClipsDescendants = true })
        pad(self._pages, 10, 12, 10, 12)
        self:_layout()

        -- background pattern (dots or grid) + optional accent blob, behind page content.
        -- Patterns are built lazily (see Window:SetPattern) and share a single painter.
        local patternHost = New("Frame", { Parent = self._pages, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0, BorderSizePixel = 0 })
        self._buildPattern = function(kind)
            local host = New("Frame", { Parent = patternHost, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Visible = false })
            local step = 24
            local maxW, maxH = math.max(self._size.X, 700), math.max(self._size.Y, 500)
            local parts = {}
            if kind == "grid" then
                for x = step, maxW, step do
                    table.insert(parts, New("Frame", { Parent = host, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(0, 1, 1, 0), BorderSizePixel = 0, BackgroundTransparency = 0.8 }))
                end
                for y = step, maxH, step do
                    table.insert(parts, New("Frame", { Parent = host, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, BackgroundTransparency = 0.8 }))
                end
            else
                for x = step, maxW, step do
                    for y = step, maxH, step do
                        table.insert(parts, New("Frame", { Parent = host, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(2, 2), BorderSizePixel = 0, BackgroundTransparency = 0.6 }))
                    end
                end
            end
            self:_onTheme(host, function()
                local c = self.Theme.Stroke
                for _, p in ipairs(parts) do p.BackgroundColor3 = c end
            end)
            return host
        end
        self:SetPattern(self._pattern)

        local blob = New("Frame", {
            Parent = patternHost, AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, 40, 1, 40), Size = UDim2.fromOffset(320, 320),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 0, Visible = cfg.Blob == true,
        })
        self:_corner(blob, "pill")
        local blobGrad = New("UIGradient", { Parent = blob, Rotation = 45 })
        self:_onTheme(blob, function()
            local a = self.Theme.Accent
            blobGrad.Color = ColorSequence.new(a, self.Theme.Background)
            blobGrad.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.85),
                NumberSequenceKeypoint.new(1, 1),
            })
        end)
        self._blob, self._blobOn = blob, cfg.Blob == true

        self._notifs = New("Frame", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.new(0, 340, 0, 100) })
        self._notifPos = "bottomright"
        self._activeNotifs = {}

        -- resize handle
        if cfg.Resizable then
            local handle = New("TextButton", { Parent = holder, Text = "", Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -14, 1, -14), BackgroundTransparency = 1, ZIndex = 5 })
            local resize = false
            handle.InputBegan:Connect(function(i) if isPress(i) and not self._minimized then resize = true end end)
            self:_connect(UserInputService.InputChanged, function(i)
                if resize and isMove(i) then
                    local sx = (i.Position.X - holder.AbsolutePosition.X) / self._userScale
                    local sy = (i.Position.Y - holder.AbsolutePosition.Y) / self._userScale
                    self._size = Vector2.new(math.max(360, sx + 12), math.max(240, sy + 12))
                    holder.Size = UDim2.fromOffset(self._size.X, self._size.Y)
                end
            end)
            self:_connect(UserInputService.InputEnded, function(i) if isPress(i) then resize = false end end)
        end

        -- Drag: with a mouse, from any non-interactive part of the window; with
        -- touch, from the header only so swiping a page scrolls it instead.
        local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
        local function overInteractive(x, y)
            local ok, objs = pcall(function() return gui:GetGuiObjectsAtPosition(x, y) end)
            if not ok or type(objs) ~= "table" then return false end
            for _, o in ipairs(objs) do
                if o:IsA("TextBox") or o:IsA("TextButton") then return true end
            end
            return false
        end
        local function inRect(g, p)
            local ap, as = g.AbsolutePosition, g.AbsoluteSize
            return p.X >= ap.X and p.X <= ap.X + as.X and p.Y >= ap.Y and p.Y <= ap.Y + as.Y
        end
        local function beginDrag(i)
            dragging, dragInput, dragStart, startPos = true, i, Vector2.new(i.Position.X, i.Position.Y), holder.Position
        end
        top.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.Touch then return end
            -- touch positions exclude the top-bar inset; the gui ignores it
            local p = Vector2.new(i.Position.X, i.Position.Y) + GuiService:GetGuiInset()
            if inRect(closeBtn, p) or inRect(minBtn, p) then return end
            beginDrag(i)
        end)
        self:_connect(UserInputService.InputBegan, function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            local m = UserInputService:GetMouseLocation()
            if not inRect(holder, m) then return end
            if overInteractive(m.X, m.Y) then return end
            beginDrag(i)
        end)
        self:_connect(UserInputService.InputChanged, function(i)
            if not dragging then return end
            local isMouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1
            if (isMouse and i.UserInputType == Enum.UserInputType.MouseMovement) or (not isMouse and i == dragInput) then
                local d = Vector2.new(i.Position.X - dragStart.X, i.Position.Y - dragStart.Y)
                holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        self:_connect(UserInputService.InputEnded, function(i)
            if dragging and (i == dragInput or i.UserInputType == Enum.UserInputType.MouseButton1) then dragging = false end
        end)

        minBtn.MouseButton1Click:Connect(function() self:SetMinimized(not self._minimized) end)
        closeBtn.MouseButton1Click:Connect(function()
            -- with the floating bubble present, X hides instead of destroying
            if self._fab then self:Toggle(false) return end
            tween(scale, { Scale = 0.9 * self._userScale }, TI)
            task.delay(0.15, function() self:Destroy() end)
        end)
        self:_connect(UserInputService.InputBegan, function(i, gpe)
            if not gpe and not self._rebinding and i.KeyCode == self.ToggleKey then self:Toggle() end
        end)

        -- floating bubble that opens/closes the window (touch devices have no toggle key)
        if cfg.MobileButton == true or (cfg.MobileButton == nil and self._touch) then
            local fab = New("TextButton", {
                Name = "PrismToggle", Parent = gui, AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(46, 46),
                Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 20,
            })
            New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fab })
            self:_bind(fab, "BackgroundColor3", "Surface")
            local fabStroke = self:_stroke(fab, "Stroke")
            fabStroke.Transparency = 0.2
            local mark = New("TextLabel", {
                Parent = fab, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21,
                Text = string.upper(string.sub(tostring(cfg.Title or "P"), 1, 1)),
                Font = self:_font("Bold"), TextSize = 18,
            })
            self:_bind(mark, "TextColor3", "Accent")
            local fabInput, fabStart, fabPos, moved = nil, nil, nil, false
            fab.InputBegan:Connect(function(i)
                if isPress(i) then fabInput, fabStart, fabPos, moved = i, i.Position, fab.Position, false end
            end)
            self:_connect(UserInputService.InputChanged, function(i)
                if not fabInput then return end
                local isMouse = fabInput.UserInputType == Enum.UserInputType.MouseButton1
                if (isMouse and i.UserInputType == Enum.UserInputType.MouseMovement) or (not isMouse and i == fabInput) then
                    local dx, dy = i.Position.X - fabStart.X, i.Position.Y - fabStart.Y
                    if math.abs(dx) + math.abs(dy) > 8 then moved = true end
                    if moved then
                        fab.Position = UDim2.new(fabPos.X.Scale, fabPos.X.Offset + dx, fabPos.Y.Scale, fabPos.Y.Offset + dy)
                    end
                end
            end)
            self:_connect(UserInputService.InputEnded, function(i)
                if fabInput and (i == fabInput or i.UserInputType == Enum.UserInputType.MouseButton1) then
                    fabInput = nil
                    if not moved then
                        tween(fab, { Size = UDim2.fromOffset(40, 40) }, TweenInfo.new(0.07))
                        task.delay(0.08, function() tween(fab, { Size = UDim2.fromOffset(46, 46) }, TI_POP) end)
                        self:Toggle()
                    end
                end
            end)
            self._fab = fab
        end

        -- re-fit when the screen rotates or resizes
        if cam0 then
            self:_connect(cam0:GetPropertyChangedSignal("ViewportSize"), function()
                self._size = fitSize()
                if not self._minimized then holder.Size = UDim2.fromOffset(self._size.X, self._size.Y) end
                self:_layout()
            end)
        end

        -- optional animated gradient border (off by default)
        if cfg.AnimatedBorder then self:SetAnimatedBorder(true) end
        if cfg.Rainbow then self:SetRainbow(true) end
        if cfg.NotificationPosition then self:SetNotificationPosition(cfg.NotificationPosition) end

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
        -- enforce a single instance: tear down any previously created window
        if ActiveWindow and ActiveWindow ~= self and ActiveWindow.Gui then
            pcall(function() ActiveWindow:Destroy() end)
        end
        ActiveWindow = self
        self._animateTheme = true -- later theme changes cross-fade
        return self
    end

    return Library
end)()
return Prism
