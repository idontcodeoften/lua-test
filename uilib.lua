--[[
    PrismUI v1.2 - executor single-file build
    Load from a hosted raw file:
    local Prism = loadstring(game:HttpGet("RAW_GITHUB_URL"))()
    local Window = Prism:CreateWindow({
        Title = "My UI", Tags = { "BETA" },
        Subtitle = "auto",            -- or a custom string; "auto" shows @player
        Font = "Gotham",              -- Gotham | BuilderSans | Montserrat | Code
        TextScale = 1,                -- 0.8 - 1.3
        Density = "comfortable",      -- "comfortable" | "compact"
        Glass = 0,                    -- 0 = opaque, 1 = fully frosted
        Pattern = "none",             -- "none" | "dots" | "grid"
        Blob = false,                 -- accent blob fading in a page corner
        Glow = false,                 -- accent glow behind the window
        AnimatedBorder = false,       -- slowly rotating accent gradient border
        Rainbow = false,              -- slow hue-cycling accent
    })

    New element APIs:
      Tab:AddLineGraph({ Values = {...}, Height = 120 })   :Set({ ... })
      Tab:AddStatCard({ Title = "FPS", Value = 60, Delta = 4, Values = {...} })
      Tab:AddGauge({ Title = "Load", Default = 0.7, Suffix = "%" })  :Set(0..1)
      Tab:AddSkeleton({ Title = "Loading..." })            :Destroy()
      Tab:AddSection("Name") returns a section object with :Toggle() / :Set(open)
      local cols = Tab:AddColumns(2)  -- side-by-side columns; add widgets per column:
        cols[1]:AddToggle({ Title = "Left" })  cols[2]:AddSlider({ Title = "Right" })
    Widget cfg extras: Tooltip = "text", Badge = "NEW" (tabs + cards),
    Notify({ Type = "success" | "warning" | "error" | "info" }) + click-to-dismiss.
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
        if not text or text == "" then return end
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

    -- Small "NEW" / count pill.
    function Window:_badge(parent, text, order, layout)
        if text == nil or text == "" then return nil end
        local isCount = type(text) == "number"
        local pill = New("Frame", {
            Parent = parent, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16),
            BorderSizePixel = 0, LayoutOrder = order or 99,
        })
        self:_corner(pill, "pill")
        self:_bind(pill, "BackgroundColor3", "Accent")
        pad(pill, 0, 6, 0, 6)
        local l = New("TextLabel", {
            Parent = pill, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 16), Text = isCount and tostring(text) or string.upper(tostring(text)),
            Font = self:_font("Bold"), TextSize = self:_ts(8), TextXAlignment = Enum.TextXAlignment.Center,
        })
        self:_styleLabel(l, "Bold", 8)
        self:_bind(l, "TextColor3", "AccentText")
        if layout == "horizontal" then
            pill.Parent = parent
        end
        return pill
    end

    function Window:_connect(signal, fn) table.insert(self._conns, signal:Connect(fn)) end

    ------------------------------------------------------------------ public window API
    function Window:SetTheme(theme) self._themeName = theme; self:_buildTheme(); self:_refresh() end
    function Window:SetAccent(color) self._accent = color; self._baseAccent = color or self._baseAccent; self:_buildTheme(); self:_refresh() end
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

    function Window:SetDensity(mode)
        self.Density = mode == "compact" and "compact" or "comfortable"
        local c = self.Density == "compact"
        self._d = { cardPad = c and 8 or 11, gap = c and 5 or 7, rowH = c and 24 or 28, headerH = c and 20 or 24 }
        -- Live-update paddings/gaps made density-aware.
        for _, e in ipairs(self._densityRegs) do e.fn(self._d) end
    end

    function Window:SetGlass(t)
        self._glass = math.clamp(tonumber(t) or 0, 0, 1)
        self:_refresh()
    end

    function Window:SetPattern(mode)
        self._pattern = mode
        if self._patternDots then self._patternDots.Visible = mode == "dots" end
        if self._patternGrid then self._patternGrid.Visible = mode == "grid" end
    end

    function Window:SetBlob(on)
        if self._blob then self._blob.Visible = on == true end
    end

    function Window:SetGlow(on)
        self._glow = on == true
        if self._glowImage then self._glowImage.Visible = self._glow end
    end

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
            self._accent = self._baseAccent
            self:_buildTheme(); self:_refresh()
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
            Parent = self.Gui, Text = text, Font = self:_font("Medium"), TextSize = self:_ts(13),
            BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 12), Size = UDim2.fromOffset(0, 20),
            AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Left,
        })
        self:_styleLabel(w, "Medium", 13)
        self:_bind(w, "TextColor3", "SubText")
        self:_bind(w, "TextStrokeColor3", "Background")
        w.TextStrokeTransparency = 0.6
        self._watermark = w
    end

    function Window:Destroy()
        for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
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

    local NOTIF_TYPES = {
        info    = { glyph = "i" },
        success = { glyph = "✓", color = rgb(64, 200, 100) },
        warning = { glyph = "!", color = rgb(250, 176, 60) },
        error   = { glyph = "✕", color = rgb(240, 80, 80) },
    }

    -- Fully rebuilt notifications: bottom-right toasts with a type icon,
    -- title + message, close button and an edge progress line.
    -- cfg: { Title, Content, Type = "info"|"success"|"warning"|"error", Duration }
    -- or just a plain string for a quick info toast.
    function Window:Notify(cfg)
        if type(cfg) == "string" then cfg = { Content = cfg } end
        cfg = cfg or {}
        self._notifId += 1
        local nType = NOTIF_TYPES[cfg.Type] or NOTIF_TYPES.info
        local accent = nType.color or self.Theme.Accent
        local duration = math.max(0.5, tonumber(cfg.Duration) or 4)

        -- layout slot in the stack
        local wrap = New("Frame", {
            Parent = self._notifs, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = self._notifId,
        })
        local card = New("TextButton", {
            Parent = wrap, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(0, -12),
        })
        self:_bind(card, "BackgroundColor3", "Surface")
        self:_glassify(card, 0.3)
        self:_corner(card, 0.3)
        local cardStroke = self:_stroke(card, "Stroke")
        cardStroke.Transparency = 0.6

        -- icon bubble
        local bubble = New("Frame", {
            Parent = card, AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 12, 0, 12),
            Size = UDim2.fromOffset(26, 26), BorderSizePixel = 0,
        })
        self:_corner(bubble, "pill")
        bubble.BackgroundColor3 = accent
        if not nType.color then self:_bind(bubble, "BackgroundColor3", "Accent") end
        local glyph = New("TextLabel", {
            Parent = bubble, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
            Text = nType.glyph, Font = self:_font("Bold"), TextSize = self:_ts(12),
            TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
        })
        self:_styleLabel(glyph, "Bold", 12)
        if not nType.color then self:_bind(glyph, "TextColor3", "AccentText") end

        -- text column
        local texts = New("Frame", {
            Parent = card, BackgroundTransparency = 1,
            Position = UDim2.new(0, 48, 0, 10), Size = UDim2.new(1, -78, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
        })
        New("UIListLayout", { Parent = texts, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
        local title = self:_text(texts, cfg.Title or "Notice", 13, self:_font("Bold"), "Text")
        title.LayoutOrder = 1
        if cfg.Content then
            local content = self:_text(texts, cfg.Content, 12, self:_font("Normal"), "SubText")
            content.LayoutOrder = 2
        end

        -- close button
        local closeBtn = New("TextButton", {
            Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8),
            Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, BorderSizePixel = 0,
            Text = "×", Font = self:_font("Bold"), TextSize = self:_ts(15),
            TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
        })
        self:_styleLabel(closeBtn, "Bold", 15)
        self:_bind(closeBtn, "TextColor3", "SubText")
        closeBtn.MouseEnter:Connect(function() tween(closeBtn, { TextColor3 = self.Theme.Text }) end)
        closeBtn.MouseLeave:Connect(function() tween(closeBtn, { TextColor3 = self.Theme.SubText }) end)

        -- progress line along the bottom edge
        local bar = New("Frame", {
            Parent = card, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, BackgroundColor3 = accent,
        })
        if not nType.color then self:_bind(bar, "BackgroundColor3", "Accent") end

        -- entrance: fade + rise
        local restingT = (self._glass or 0) * 0.3
        tween(card, { Position = UDim2.fromOffset(0, 0), BackgroundTransparency = restingT }, TI_POP)
        tween(bar, { Size = UDim2.new(0, 0, 0, 2) }, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out))

        local dismissed = false
        local function dismiss()
            if dismissed then return end
            dismissed = true
            tween(card, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, -8) }, TI)
            task.delay(0.18, function() if wrap.Parent then wrap:Destroy() end end)
        end
        closeBtn.MouseButton1Click:Connect(dismiss)
        card.MouseButton1Click:Connect(dismiss)
        task.delay(duration, dismiss)
    end

    function Window:AddTab(cfg)
        if type(cfg) == "string" then cfg = { Title = cfg } end
        local tab = setmetatable({ Window = self, Title = cfg.Title, _order = 0, _sectionStack = {} }, Tab)

        self._navOrder = (self._navOrder or 0) + 1
        local btn = New("TextButton", { Parent = self._tabList, Size = UDim2.new(1, 0, 0, 32), Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = self._navOrder, ClipsDescendants = true })
        self:_corner(btn, 0.5)
        local iconImage = resolveIcon(cfg.Icon)
        local textX = iconImage and 36 or 16
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
                Position = UDim2.new(0, 14, 0.5, 0),
            })
        end
        local bar = New("Frame", { Parent = btn, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(2, 14), BorderSizePixel = 0 })
        self:_corner(bar, "pill")
        self:_bind(bar, "BackgroundColor3", "Accent")

        -- tab badge (text like "NEW" or a count)
        if cfg.Badge ~= nil and cfg.Badge ~= "" then
            local pill = New("Frame", {
                Parent = btn, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
                AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 15), BorderSizePixel = 0,
            })
            self:_corner(pill, "pill")
            self:_bind(pill, "BackgroundColor3", "Accent")
            pad(pill, 0, 5, 0, 5)
            local bl = New("TextLabel", {
                Parent = pill, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
                Size = UDim2.fromOffset(0, 15), Text = type(cfg.Badge) == "number" and tostring(cfg.Badge) or string.upper(tostring(cfg.Badge)),
                Font = self:_font("Bold"), TextSize = self:_ts(8),
            })
            self:_styleLabel(bl, "Bold", 8)
            self:_bind(bl, "TextColor3", "AccentText")
        end

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
        local label = self:_text(self._tabList, string.upper(tostring(title or "GROUP")), 9, self:_font("Bold"), "SubText")
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
        tab:AddSection("Effects")
        tab:AddSlider({ ConfigKey = "Glass", Title = "Glass transparency", Description = "Let the game show through.", Min = 0, Max = 1, Increment = 0.05, Default = self._glass, Callback = function(v) self:SetGlass(v) end })
        tab:AddDropdown({ ConfigKey = "Pattern", Title = "Background pattern", Values = { "None", "Dots", "Grid" }, Default = (self._pattern == "grid" and "Grid") or (self._pattern == "dots" and "Dots") or "None", Callback = function(v) self:SetPattern(string.lower(v)) end })
        tab:AddToggle({ ConfigKey = "Accent blob", Title = "Accent blob", Description = "Soft accent glow fading in the page corner.", Default = self._blobOn == true, Callback = function(on) self:SetBlob(on) end })
        tab:AddToggle({ ConfigKey = "Window glow", Title = "Accent window glow", Default = self._glow == true, Callback = function(on) self:SetGlow(on) end })
        tab:AddToggle({ ConfigKey = "Animated border", Title = "Animated gradient border", Default = self._animBorder == true, Callback = function(on) self:SetAnimatedBorder(on) end })
        tab:AddSection("Window")
        tab:AddKeybind({ ConfigKey = "Toggle key", Title = "Toggle key", Default = self.ToggleKey, Changed = function(k) self.ToggleKey = k end })
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
        w:_corner(card, 0.35)
        pad(card, w._d.cardPad, 12)
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

        -- Plain Frame: CanvasGroup does not reliably support AutomaticSize,
        -- which collapsed section content into an overlapping stack that
        -- blocked clicks on widgets and section headers.
        local body = New("Frame", { Parent = wrap, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 })
        local bodyLayout = New("UIListLayout", { Parent = body, Padding = UDim.new(0, w._d.gap), SortOrder = Enum.SortOrder.LayoutOrder })
        table.insert(w._densityRegs, { fn = function(d) bodyLayout.Padding = UDim.new(0, d.gap) end })

        local sec = { open = true }
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

    function Tab:AddDivider()
        local f = New("Frame", { Parent = self:_host(), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, LayoutOrder = self:_next() })
        self.Window:_bind(f, "BackgroundColor3", "Stroke")
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

    function Tab:AddButton(cfg)
        local card, header = self:_card(cfg, 20, "TextButton")
        self:_hover(card)
        local chev = New("TextLabel", rightAnchored({ Parent = header, Size = UDim2.fromOffset(16, 20), BackgroundTransparency = 1, Text = "›", Font = self.Window:_font("Bold"), TextSize = self.Window:_ts(22) }))
        self.Window:_styleLabel(chev, "Bold", 22)
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
        track.BackgroundColor3 = Color3.new(1, 1, 1) -- gradient supplies the colour
        local trackGrad = w:_gradient(track, 25)
        local thumb = New("Frame", { Parent = track, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0 })
        w:_corner(thumb, "pill")

        local obj = { Value = cfg.Default == true }
        local function paint(animate)
            local th, on = w.Theme, obj.Value
            local trackColor = on and Color3.new(1, 1, 1) or th.Stroke
            local goals = {
                { track, { BackgroundColor3 = trackColor } },
                { thumb, { BackgroundColor3 = on and th.AccentText or th.SubText, Position = on and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) } },
            }
            for _, g in ipairs(goals) do
                if animate then tween(g[1], g[2]) else for k, v in pairs(g[2]) do g[1][k] = v end end
            end
            -- soft accent glow on the track while on
            local stroke = track:FindFirstChildOfClass("UIStroke")
            if not stroke then
                stroke = New("UIStroke", { Parent = track, Thickness = 2 })
            end
            stroke.Color = th.Accent
            tween(stroke, { Transparency = on and 0.55 or 1 })
            trackGrad.Color = ColorSequence.new(th.Accent, shiftHue(th.Accent, 25))
        end
        w:_onTheme(track, function() paint(false) end)

        function obj:Set(v, silent) obj.Value = v and true or false; paint(true); if not silent then safe(cfg.Callback, obj.Value) end end
        function obj:Get() return obj.Value end
        function obj:Toggle() obj:Set(not obj.Value) end
        card.MouseButton1Click:Connect(function()
            -- thumb stretch while pressed
            tween(thumb, { Size = UDim2.fromOffset(20, 14) }, TweenInfo.new(0.07))
            task.delay(0.09, function() tween(thumb, { Size = UDim2.fromOffset(16, 16) }) end)
            obj:Set(not obj.Value)
        end)
        if cfg.CallOnInit then safe(cfg.Callback, obj.Value) end
        return self:_registerState(cfg, obj)
    end

    function Tab:AddSlider(cfg)
        local w = self.Window
        local min, max, inc = cfg.Min or 0, cfg.Max or 100, cfg.Increment or 1
        local card, header = self:_card(cfg, 64)
        local valueLabel = New("TextLabel", rightAnchored({ Parent = header, Size = UDim2.fromOffset(64, 20), BackgroundTransparency = 1, Font = w:_font("Medium"), TextSize = w:_ts(13), TextXAlignment = Enum.TextXAlignment.Right }))
        w:_styleLabel(valueLabel, "Medium", 13)
        w:_bind(valueLabel, "TextColor3", "Accent")

        local hit = New("TextButton", { Parent = card, Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 2 })
        local bar  = New("Frame", { Parent = hit, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 6), BorderSizePixel = 0 })
        w:_corner(bar, "pill"); w:_bind(bar, "BackgroundColor3", "Elevated")
        local fill = New("Frame", { Parent = bar, Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) })
        w:_corner(fill, "pill")
        w:_gradient(fill, 22) -- gradient accent fill
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
        local boxLabel = New("TextLabel", { Parent = box, BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -26, 1, 0), Font = w:_font("Medium"), TextSize = w:_ts(12), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
        w:_styleLabel(boxLabel, "Medium", 12)
        w:_bind(boxLabel, "TextColor3", "Text")
        local arrow = New("TextLabel", { Parent = box, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(14, 16), Text = "v", Font = w:_font("Bold"), TextSize = w:_ts(13), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
        w:_styleLabel(arrow, "Bold", 13)
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
                local b = New("TextButton", { Parent = list, Size = UDim2.new(1, -6, 0, 28), Text = "", Font = w:_font("Medium"), TextSize = w:_ts(13), AutoButtonColor = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, ClipsDescendants = true })
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
        New("UIListLayout", { Parent = picker, Padding = UDim.new(0, 6) })

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
        local pct = New("TextLabel", rightAnchored({ Parent = header, Size = UDim2.fromOffset(60, 20), BackgroundTransparency = 1, Font = w:_font("Medium"), TextSize = w:_ts(13), TextXAlignment = Enum.TextXAlignment.Right }))
        w:_styleLabel(pct, "Medium", 13)
        w:_bind(pct, "TextColor3", "Accent")
        local bar = New("Frame", { Parent = card, Size = UDim2.new(1, 0, 0, 8), BorderSizePixel = 0, LayoutOrder = 2 })
        w:_corner(bar, "pill"); w:_bind(bar, "BackgroundColor3", "Elevated")
        local fill = New("Frame", { Parent = bar, Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) })
        w:_corner(fill, "pill")
        w:_gradient(fill, 22) -- gradient accent fill
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
        local card, header = self:_card({ Title = cfg.Title or "Search", Description = cfg.Description, Tooltip = cfg.Tooltip }, 0)
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
            w:_gradient(seg, 18)
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
            local g = New("UIGradient", { Parent = bar })
            w:_onTheme(bar, function()
                g.Color = ColorSequence.new(w.Theme.Elevated, w.Theme.Text, w.Theme.Elevated)
                g.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.4),
                    NumberSequenceKeypoint.new(0.5, 0.05),
                    NumberSequenceKeypoint.new(1, 0.4),
                })
            end)
            local shimmer = TweenService:Create(g, TweenInfo.new(1.1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false), { Offset = Vector2.new(1, 0) })
            shimmer:Play()
        end
        return { Destroy = function() card:Destroy() end }
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
                Type = ok and "success" or "error",
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
                    w:Notify({ Title = "Export failed", Content = tostring(result), Type = "error", Duration = 3 })
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

    function Library:CreateWindow(cfg)
        cfg = cfg or {}
        local self = setmetatable({ Tabs = {}, _painters = {}, _corners = {}, _conns = {}, _notifId = 0, _stateWidgets = {}, _textRegs = {}, _densityRegs = {} }, Window)
        self._themeName = cfg.Theme or "Midnight"
        self._accent    = cfg.Accent
        self._baseAccent = cfg.Accent
        self.CornerRadius = math.clamp(cfg.CornerRadius or 10, 0, 28)
        self.ToggleKey    = cfg.ToggleKey or Enum.KeyCode.RightShift
        self._size        = cfg.Size or Vector2.new(620, 420)
        self._minimized   = false
        self._fontName    = FONT_MAP[cfg.Font] and cfg.Font or "Gotham"
        self.TextScale    = math.clamp(tonumber(cfg.TextScale) or 1, 0.8, 1.3)
        self._glass       = math.clamp(tonumber(cfg.Glass) or 0, 0, 1)
        self._pattern     = cfg.Pattern or "none"
        self._glow        = cfg.Glow == true
        self:_buildTheme()
        self:SetDensity(cfg.Density == "compact" and "compact" or "comfortable")

        local size = self._size
        local gui = New("ScreenGui", { Name = "PrismUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100, IgnoreGuiInset = true })
        self.Gui = gui

        local holder = New("Frame", { Name = "Window", Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1 })
        local scale  = New("UIScale", { Parent = holder, Scale = 0.92 })
        self.Holder, self._scale = holder, scale
        tween(scale, { Scale = 1 }, TI_POP)

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
        pad(main, 12)

        local topSurface = New("Frame", { Parent = main, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 52) })
        self:_bind(topSurface, "BackgroundColor3", "Surface")
        self:_glassify(topSurface, 0.45)
        self:_corner(topSurface, 0.45)
        local topSurfaceStroke = self:_stroke(topSurface, "Stroke")
        topSurfaceStroke.Transparency = 0.45
        local separator = New("Frame", { Parent = main, Position = UDim2.new(0, 8, 0, 53), Size = UDim2.new(1, -16, 0, 1), BorderSizePixel = 0 })
        self:_bind(separator, "BackgroundColor3", "Stroke")
        local top = New("Frame", { Parent = main, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52) })
        local titleAccent = New("Frame", {
            Parent = top, Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(3, 32),
            BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
        })
        self:_corner(titleAccent, "pill")
        self:_gradient(titleAccent, 30, 115) -- gradient accent bar
        local titleRow = New("Frame", {
            Parent = top, BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 0),
            Size = UDim2.new(1, -132, 1, 0), ClipsDescendants = true,
        })
        local brandTitle = New("TextLabel", {
            Parent = titleRow, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 4),
            Size = UDim2.new(1, 0, 0, 23),
            Text = cfg.Title or "PrismUI", Font = self:_font("Bold"), TextSize = self:_ts(17),
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        })
        self:_styleLabel(brandTitle, "Bold", 17)
        self:_bind(brandTitle, "TextColor3", "Text")

        -- subtitle / player line under the title (shares the tag row)
        local tagList = New("Frame", {
            Parent = titleRow, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 29),
            Size = UDim2.new(1, 0, 0, 20), ClipsDescendants = true,
        })
        New("UIListLayout", {
            Parent = tagList, FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        if cfg.Subtitle then
            local subText = cfg.Subtitle == "auto" and ("@" .. tostring(Players.LocalPlayer and Players.LocalPlayer.Name or "player")) or tostring(cfg.Subtitle)
            local sub = New("TextLabel", {
                Parent = tagList, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
                Size = UDim2.fromOffset(0, 20), Text = subText, Font = self:_font("Medium"), TextSize = self:_ts(11),
                TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, TextTruncate = Enum.TextTruncate.AtEnd,
            })
            self:_styleLabel(sub, "Medium", 11)
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
                    Text = string.upper(text), Font = self:_font("Bold"), TextSize = self:_ts(8),
                    TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2,
                })
                self:_styleLabel(tagLabel, "Bold", 8)
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
        self:_glassify(sidebar, 0.45)
        self:_corner(sidebar, 0.45)
        local tabList = New("ScrollingFrame", { Parent = sidebar, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0 })
        pad(tabList, 8, 6, 8, 6)
        New("UIListLayout", { Parent = tabList, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder })
        self._tabList = tabList
        self._pages   = New("Frame", { Parent = body, BackgroundTransparency = 1, Position = UDim2.fromOffset(152, 0), Size = UDim2.new(1, -152, 1, 0), ClipsDescendants = true })

        -- background pattern (dots or grid) + optional accent blob, behind page content
        local patternHost = New("Frame", { Parent = self._pages, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0, BorderSizePixel = 0 })
        local function buildPattern(kind)
            local host = New("Frame", { Parent = patternHost, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Visible = false })
            local step = 24
            local maxW, maxH = 900, 800
            if kind == "grid" then
                for x = step, maxW, step do
                    local line = New("Frame", { Parent = host, Position = UDim2.fromOffset(x, 0), Size = UDim2.new(0, 1, 1, 0), BorderSizePixel = 0 })
                    self:_bind(line, "BackgroundColor3", "Stroke")
                    line.BackgroundTransparency = 0.8
                end
                for y = step, maxH, step do
                    local line = New("Frame", { Parent = host, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0 })
                    self:_bind(line, "BackgroundColor3", "Stroke")
                    line.BackgroundTransparency = 0.8
                end
            elseif kind == "dots" then
                for x = step, maxW, step do
                    for y = step, maxH, step do
                        local d = New("Frame", { Parent = host, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(2, 2), BorderSizePixel = 0 })
                        self:_corner(d, "pill")
                        self:_bind(d, "BackgroundColor3", "Stroke")
                        d.BackgroundTransparency = 0.6
                    end
                end
            end
            return host
        end
        self._patternDots = buildPattern("dots")
        self._patternGrid = buildPattern("grid")
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

        -- optional animated gradient border (off by default)
        if cfg.AnimatedBorder then self:SetAnimatedBorder(true) end
        if cfg.Rainbow then self:SetRainbow(true) end

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
