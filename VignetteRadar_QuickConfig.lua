local _, addon = ...
if type(addon) ~= "table" then return end

local WIDTH, HEIGHT = 288, 389
local THEME_COLUMNS, THEME_ROW, THEME_VIEW_HEIGHT = 4, 24, 46
local THEME_VIEW_WIDTH = 244
local ACCENT = { 0.05, 0.82, 0.62 }
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local quick, anchor
local checks, groups, steppers, swatches, sections = {}, {}, {}, {}, {}
local API = {}
addon.VignetteRadarQuickConfig = API

local function Settings()
    return addon.GetSettings()
end

local function Label(parent, value, x, y, size, width)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, size or 10, "")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width or WIDTH - x - 12)
    label:SetTextColor(0.81, 0.87, 0.86, 1)
    label:SetWordWrap(false)
    label:SetText(value)
    return label
end

local function Section(page, value, y)
    local label = Label(page, value, 14, y, 9)
    sections[#sections + 1] = label
    local line = page:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", page, "TOPLEFT", 14, y - 14)
    line:SetPoint("TOPRIGHT", page, "TOPRIGHT", -14, y - 14)
    line:SetHeight(1)
    line:SetColorTexture(1, 1, 1, .09)
    return label
end

local function Changed(key, value, subkey)
    local db = Settings()
    local legend = addon.VignetteRadarLegend
    if key == "vignetteRadarEnabled" then
        addon.SetVignetteRadarEnabled(value)
    elseif key == "vignetteRadarRange" then
        addon.SetVignetteRadarRange(value)
    elseif key == "vignetteRadarLayout" then
        addon.SetVignetteRadarLayout(value)
    elseif key == "vignetteRadarCircleOnly" then
        addon.SetVignetteRadarCircleOnly(value)
    elseif key == "vignetteRadarNorthUp" then
        addon.SetVignetteRadarNorthUp(value)
    elseif key == "vignetteRadarScale" then
        addon.SetVignetteRadarScale(value)
    elseif key == "vignetteRadarQuietCombat" then
        addon.SetVignetteRadarQuietCombat(value)
    elseif key == "vignetteRadarKeepVisibleCombat" then
        addon.SetVignetteRadarKeepVisibleCombat(value)
    elseif key == "vignetteRadarCategories" and legend then
        legend.SetCategoryEnabled(subkey, value)
    elseif key == "vignetteRadarHighlight" and legend then
        legend.SetHighlight(value)
    elseif key == "vignetteRadarTheme" then
        addon.VignetteRadarStyle.SetTheme(value)
        addon.VignetteRadarAPI.Refresh(false)
    else
        if subkey then
            if type(db[key]) ~= "table" then db[key] = {} end
            db[key][subkey] = value
        else
            db[key] = value
        end
        addon.VignetteRadarAPI.Refresh(true)
    end
    if addon.RefreshVignetteRadarOptions then addon.RefreshVignetteRadarOptions() end
    API.Refresh()
end

local function Check(page, key, title, x, y, subkey, labelWidth)
    local box = addon.VignetteRadarControls.Checkbox(page)
    box:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
    local hit = CreateFrame("Button", nil, page)
    hit:SetPoint("TOPLEFT", page, "TOPLEFT", x + 31, y)
    hit:SetSize(labelWidth or WIDTH - x - 43, 26)
    box.label = Label(hit, title, 0, -7, 10, hit:GetWidth())
    box.optionKey, box.subkey = key, subkey
    box:SetScript("OnClick", function(self)
        Changed(key, self:GetChecked() == true or self:GetChecked() == 1, subkey)
    end)
    hit:SetScript("OnClick", function()
        box:SetChecked(not (box:GetChecked() == true or box:GetChecked() == 1))
        Changed(key, box:GetChecked() == true or box:GetChecked() == 1, subkey)
    end)
    hit:SetScript("OnEnter", function() box._hovered = true; box:RefreshAppearance() end)
    hit:SetScript("OnLeave", function() box._hovered = false; box:RefreshAppearance() end)
    checks[#checks + 1] = box
    return box
end

local Button
local function StepValue(values, current, direction)
    if direction > 0 then
        for _, value in ipairs(values) do
            if value > current + .001 then return value end
        end
    else
        for index = #values, 1, -1 do
            if values[index] < current - .001 then return values[index] end
        end
    end
end
local function Stepper(page, key, title, y, values, format)
    local row = { key = key, values = values }
    Label(page, title, 14, y, 10, 145)
    row.minus = Button(page, "−", 162, y + 3, 27, function()
        local value = StepValue(values, Settings()[key], -1)
        if value then Changed(key, value) end
    end)
    row.value = Label(page, "", 191, y, 10, 53)
    row.value:SetJustifyH("CENTER")
    row.plus = Button(page, "+", 247, y + 3, 27, function()
        local value = StepValue(values, Settings()[key], 1)
        if value then Changed(key, value) end
    end)
    row.format = format
    row.minus.optionKey, row.plus.optionKey = key, key
    steppers[#steppers + 1] = row
    return row
end

local function ColorSwatch(page, slot, x, y)
    local style = addon.VignetteRadarStyle
    local button = CreateFrame("Button", nil, page, "BackdropTemplate")
    button:SetSize(18, 18)
    button:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    button:SetBackdropBorderColor(.85, .9, .9, .48)
    button.colorSlot = slot
    button:SetScript("OnClick", function()
        if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then return end
        local db = Settings()
        local previous = db.vignetteRadarColors and db.vignetteRadarColors[slot]
        local r, g, b = style.Color(slot)
        ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function()
                local red, green, blue = ColorPickerFrame:GetColorRGB()
                if style.SetColor(slot, red, green, blue) then
                    addon.VignetteRadarAPI.Refresh(false)
                    API.Refresh()
                end
            end,
            cancelFunc = function()
                if previous then style.SetColor(slot, previous[1], previous[2], previous[3])
                else style.ClearColor(slot) end
                addon.VignetteRadarAPI.Refresh(false)
                API.Refresh()
            end,
        })
    end)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 1, 1, 1)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(style.labels[slot], 1, 1, 1)
            GameTooltip:AddLine("Click to choose a custom color. Choosing a preset clears custom colors.",
                .7, .8, .8, true)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(.85, .9, .9, .48)
        if GameTooltip then GameTooltip:Hide() end
    end)
    Label(page, style.labels[slot], x + 24, y - 3, 9, x < 100 and 99 or 101)
    swatches[slot] = button
end

Button = function(page, title, x, y, width, action)
    local button = addon.VignetteRadarControls.Button(page, title, width, 21)
    button:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
    button:SetScript("OnClick", action)
    return button
end

local function Choice(page, key, value, title, x, y, width)
    local button = Button(page, title, x, y, width, function() Changed(key, value) end)
    button.optionKey, button.optionValue = key, value
    if not groups[key] then groups[key] = {} end
    groups[key][value] = button
    return button
end

local function StepRange(step)
    local ranges, current = addon.VignetteRadarRanges, Settings().vignetteRadarRange
    for index, range in ipairs(ranges) do
        if range == current then
            if ranges[index + step] then Changed("vignetteRadarRange", ranges[index + step]) end
            return
        end
    end
end

function API.Refresh()
    if not quick then return end
    local db = Settings()
    for _, box in ipairs(checks) do
        local value = db[box.optionKey]
        if box.subkey then value = type(value) == "table" and value[box.subkey] end
        box:SetChecked(value == true or value == 1)
    end
    for key, values in pairs(groups) do
        local selected = key == "vignetteRadarHighlight" and (db[key] or "all") or db[key]
        for value, button in pairs(values) do
            if value == selected then button:LockHighlight() else button:UnlockHighlight() end
        end
    end
    quick.rangeValue:SetText(db.vignetteRadarRange .. " yd")
    local ranges = addon.VignetteRadarRanges
    quick.rangeMinus:SetEnabled(db.vignetteRadarRange ~= ranges[1])
    quick.rangePlus:SetEnabled(db.vignetteRadarRange ~= ranges[#ranges])
    for _, row in ipairs(steppers) do
        local value = db[row.key]
        row.value:SetText(row.format(value))
        row.minus:SetEnabled(value > row.values[1] + .001)
        row.plus:SetEnabled(value < row.values[#row.values] - .001)
    end
    local style = addon.VignetteRadarStyle
    if style then
        local ar, ag, ab = style.Color("accent")
        quick.title:SetTextColor(ar, ag, ab, 1)
        quick.rail:SetColorTexture(ar, ag, ab, .75)
        quick.headerLine:SetColorTexture(ar, ag, ab, .18)
        quick.bead:SetColorTexture(ar, ag, ab, 1)
        if quick.themeThumb then quick.themeThumb:SetColorTexture(ar, ag, ab, .95) end
        for _, label in ipairs(sections) do label:SetTextColor(ar, ag, ab, .88) end
        if anchor and anchor.settingsDot then
            anchor.settingsDot.rim:SetVertexColor(ar, ag, ab, quick:IsShown() and .68 or .20)
        end
        local br, bg, bb = style.Color("background")
        quick:SetBackdropColor(math.min(.14, br * 2.7), math.min(.14, bg * 2.7),
            math.min(.14, bb * 2.7), .99)
        for slot, button in pairs(swatches) do
            button:SetBackdropColor(style.Color(slot))
        end
        quick.customLabel:SetText(style.IsCustomized() and "CUSTOM COLORS" or "THEME COLORS")
        addon.VignetteRadarControls.RefreshTheme()
    end
end

local function SelectPage(name)
    if not quick then return end
    quick.selectedPage = name
    for pageName, page in pairs(quick.pages) do page:SetShown(pageName == name) end
    for pageName, tab in pairs(quick.tabs) do
        if pageName == name then tab:LockHighlight() else tab:UnlockHighlight() end
    end
    if name == "Themes" and quick.SetThemeScroll then
        local selected = Settings().vignetteRadarTheme
        for index, key in ipairs(addon.VignetteRadarStyle.order) do
            if key == selected then
                local row = math.floor((index - 1) / THEME_COLUMNS)
                local first = math.floor((quick.themeOffset or 0) / THEME_ROW)
                if row < first then quick.SetThemeScroll(row * THEME_ROW)
                elseif row > first + 1 then quick.SetThemeScroll((row - 1) * THEME_ROW) end
                break
            end
        end
    end
    API.Refresh()
end

local function Build()
    if quick then return quick end
    quick = CreateFrame("Frame", "VignetteRadarQuickConfigPanel", UIParent, "BackdropTemplate")
    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "VignetteRadarQuickConfigPanel"
    end
    quick:SetSize(WIDTH, HEIGHT)
    quick:SetFrameStrata("DIALOG")
    quick:SetClampedToScreen(true)
    quick:EnableMouse(true)
    quick:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    quick:SetBackdropColor(0.035, 0.043, 0.049, 0.98)
    quick:SetBackdropBorderColor(1, 1, 1, 0.22)
    quick.pages, quick.tabs = {}, {}
    quick.rail = quick:CreateTexture(nil, "ARTWORK")
    quick.rail:SetPoint("TOPLEFT", 1, -1)
    quick.rail:SetPoint("BOTTOMLEFT", 1, 1)
    quick.rail:SetWidth(2)
    quick.bead = quick:CreateTexture(nil, "OVERLAY")
    quick.bead:SetSize(5, 5)
    quick.bead:SetPoint("TOPLEFT", 12, -13)
    quick.title = Label(quick, "RADAR SETTINGS", 23, -9, 11, 190)
    quick.title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    quick.headerLine = quick:CreateTexture(nil, "ARTWORK")
    quick.headerLine:SetPoint("TOPLEFT", 12, -34)
    quick.headerLine:SetPoint("TOPRIGHT", -12, -34)
    quick.headerLine:SetHeight(1)
    quick.headerLine:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], .18)
    local close = addon.VignetteRadarControls.Button(quick, "×", 20, 20)
    close:SetPoint("TOPRIGHT", quick, "TOPRIGHT", -8, -7)
    close:SetScript("OnClick", function() quick:Hide() end)
    quick.close = close

    local order = { "Radar", "Layout", "Explore", "Alerts", "Markers", "Guides", "Themes", "Behavior", "Quests" }
    for index, name in ipairs(order) do
        local row, column = math.floor((index - 1) / 3), (index - 1) % 3
        local tab = addon.VignetteRadarControls.Button(quick, name, 84, 20)
        tab:SetPoint("TOPLEFT", quick, "TOPLEFT", 12 + column * 89, -40 - row * 23)
        tab:SetScript("OnClick", function() SelectPage(name) end)
        quick.tabs[name] = tab
        local page = CreateFrame("Frame", nil, quick)
        page:SetSize(WIDTH, HEIGHT - 114)
        page:SetPoint("TOPLEFT", quick, "TOPLEFT", 0, -114)
        page:Hide()
        quick.pages[name] = page
    end

    local radar = quick.pages.Radar
    Check(radar, "vignetteRadarEnabled", "Enable radar", 14, -3)
    Check(radar, "vignetteRadarHideWhenEmpty", "Hide when empty", 14, -31)
    Check(radar, "vignetteRadarLauncherVisible", "Show launcher", 14, -59)
    Check(radar, "vignetteRadarWorldMap", "Include world-map detections", 14, -87)
    Section(radar, "RANGE", -121)
    quick.rangeMinus = Button(radar, "−", 14, -138, 45, function() StepRange(-1) end)
    quick.rangeMinus.optionKey = "vignetteRadarRange"
    quick.rangeValue = Label(radar, "450 yd", 78, -141, 11, 126)
    quick.rangeValue:SetJustifyH("CENTER")
    quick.rangePlus = Button(radar, "+", 228, -138, 45, function() StepRange(1) end)
    quick.rangePlus.optionKey = "vignetteRadarRange"
    Button(radar, "Preview", 14, -181, 124, function()
        addon.ToggleVignetteRadarPreview()
        API.Reanchor()
    end)
    Button(radar, "Reset positions", 150, -181, 124, function()
        addon.ResetVignetteRadarPositions()
        API.Reanchor()
    end)
    Button(radar, "Explore tools", 14, -221, 260, function()
        if addon.VignetteRadarExploration then addon.VignetteRadarExploration.TogglePanel() end
    end)

    local layout = quick.pages.Layout
    Section(layout, "PANEL STYLE", -5)
    Choice(layout, "vignetteRadarLayout", "classic", "Classic", 14, -23, 80)
    Choice(layout, "vignetteRadarLayout", "squat", "Squat", 104, -23, 80)
    Choice(layout, "vignetteRadarLayout", "compact", "Compact", 194, -23, 80)
    Check(layout, "vignetteRadarNorthUp", "Keep north at the top", 14, -64)
    Check(layout, "vignetteRadarCircleOnly", "Show only the radar", 14, -94)
    Label(layout, "Drag the radar edges to change its size.", 14, -137, 10)
    Label(layout, "Your view, position and size are saved.", 14, -156, 10)
    Section(layout, "PANEL SIZE", -184)
    Stepper(layout, "vignetteRadarScale", "Frame scale", -207,
        { .8, .9, 1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8 },
        function(value) return math.floor(value * 100 + .5) .. "%" end)

    local alerts = quick.pages.Alerts
    Check(alerts, "vignetteRadarAlerts", "Pulse for new detections", 14, -3)
    Check(alerts, "vignetteRadarAlertSound", "Play alert sound", 14, -31)
    Section(alerts, "ALERT FOR", -68)
    Check(alerts, "vignetteRadarAlertCategories", "Rares / bosses", 14, -85, "rare", 95)
    Check(alerts, "vignetteRadarAlertCategories", "Treasures", 147, -85, "treasure", 95)
    Check(alerts, "vignetteRadarAlertCategories", "Events", 14, -114, "event", 95)
    Check(alerts, "vignetteRadarAlertCategories", "Other", 147, -114, "other", 95)
    Section(alerts, "REPEAT AFTER", -154)
    Choice(alerts, "vignetteRadarAlertCooldown", 30, "30 sec", 14, -172, 80)
    Choice(alerts, "vignetteRadarAlertCooldown", 60, "60 sec", 104, -172, 80)
    Choice(alerts, "vignetteRadarAlertCooldown", 120, "120 sec", 194, -172, 80)

    local markers = quick.pages.Markers
    Section(markers, "SHOW MARKERS", -3)
    Check(markers, "vignetteRadarCategories", "Rares / bosses", 14, -19, "rare", 95)
    Check(markers, "vignetteRadarCategories", "Treasures", 147, -19, "treasure", 95)
    Check(markers, "vignetteRadarCategories", "Events", 14, -48, "event", 95)
    Check(markers, "vignetteRadarCategories", "Other", 147, -48, "other", 95)
    Section(markers, "SPOTLIGHT", -83)
    Choice(markers, "vignetteRadarHighlight", "all", "All", 14, -101, 48)
    Choice(markers, "vignetteRadarHighlight", "rare", "Rares", 68, -101, 48)
    Choice(markers, "vignetteRadarHighlight", "treasure", "Loot", 122, -101, 48)
    Choice(markers, "vignetteRadarHighlight", "event", "Events", 176, -101, 48)
    Choice(markers, "vignetteRadarHighlight", "other", "Other", 230, -101, 48)
    Section(markers, "MARKER SIZE", -137)
    Choice(markers, "vignetteRadarMarkerSize", 5, "Small", 14, -154, 80)
    Choice(markers, "vignetteRadarMarkerSize", 7, "Medium", 104, -154, 80)
    Choice(markers, "vignetteRadarMarkerSize", 9, "Large", 194, -154, 80)
    Check(markers, "vignetteRadarShapes", "Recognizable icons", 14, -190)
    Check(markers, "vignetteRadarShowHealth", "Focused rare health", 14, -218)

    local guides = quick.pages.Guides
    Section(guides, "RADAR GUIDES & FACING", -3)
    local percent = function(value) return math.floor(value * 100 + .5) .. "%" end
    Stepper(guides, "vignetteRadarRingOpacity", "Ring visibility", -25,
        { 0, .25, .5, .75, 1, 1.25, 1.5, 1.75, 2 }, percent)
    Stepper(guides, "vignetteRadarChevronOpacity", "Chevron opacity", -66,
        { 0, .1, .2, .3, .4, .5, .6, .72, .8, .9, 1 }, percent)
    Stepper(guides, "vignetteRadarHeadingOpacity", "Facing line opacity", -107,
        { 0, .1, .2, .3, .4, .46, .5, .6, .7, .8, .9, 1 }, percent)
    Stepper(guides, "vignetteRadarChevronDistance", "Chevron gap", -148,
        { 2, 3, 4, 5, 6, 7, 8, 9 }, function(value) return value .. " px" end)
    Stepper(guides, "vignetteRadarHeadingLength", "Facing line length", -189,
        { .12, .16, .2, .25, .3, .35, .4, .5, .6, .7, .8 }, percent)
    Check(guides, "vignetteRadarFullSweep", "Animated sweep on full radar", 14, -231)

    local themes = quick.pages.Themes
    Section(themes, "COLOR THEMES", -3)
    local style = addon.VignetteRadarStyle
    local themeRows = math.ceil(#style.order / THEME_COLUMNS)
    local maxThemeScroll = math.max(0, (themeRows - 2) * THEME_ROW)
    local themeScroll = CreateFrame("ScrollFrame", nil, themes)
    themeScroll:SetSize(THEME_VIEW_WIDTH, THEME_VIEW_HEIGHT)
    themeScroll:SetPoint("TOPLEFT", themes, "TOPLEFT", 14, -18)
    themeScroll:SetClipsChildren(true)
    themeScroll:EnableMouseWheel(true)
    local themeContent = CreateFrame("Frame", nil, themeScroll)
    themeContent:SetSize(THEME_VIEW_WIDTH, themeRows * THEME_ROW)
    themeScroll:SetScrollChild(themeContent)
    quick.themeScroll, quick.themeContent = themeScroll, themeContent

    local track = CreateFrame("Button", nil, themes, "BackdropTemplate")
    track:SetSize(8, THEME_VIEW_HEIGHT)
    track:SetPoint("TOPLEFT", themes, "TOPLEFT", 267, -18)
    track:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    track:SetBackdropColor(.018, .030, .034, 1)
    track:SetBackdropBorderColor(1, 1, 1, .18)
    track:EnableMouse(true)
    track:RegisterForDrag("LeftButton")
    local thumb = track:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(6, 13)
    thumb:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], .95)
    quick.themeTrack, quick.themeThumb = track, thumb

    local function SetThemeScroll(value)
        local row = math.max(0, math.min(themeRows - 2, math.floor(value / THEME_ROW + .5)))
        local offset = row * THEME_ROW
        quick.themeOffset = offset
        themeScroll:SetVerticalScroll(offset)
        thumb:ClearAllPoints()
        local travel = THEME_VIEW_HEIGHT - thumb:GetHeight() - 2
        local position = maxThemeScroll > 0 and (offset / maxThemeScroll) * travel or 0
        thumb:SetPoint("TOP", track, "TOP", 0, -1 - position)
    end
    quick.SetThemeScroll = SetThemeScroll
    local function WheelThemes(_, delta)
        SetThemeScroll((quick.themeOffset or 0) + (delta > 0 and -THEME_ROW or THEME_ROW))
    end
    themeScroll:SetScript("OnMouseWheel", WheelThemes)
    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", WheelThemes)
    local function CursorScroll()
        if not GetCursorPosition then return end
        local _, cursorY = GetCursorPosition()
        local scale = track:GetEffectiveScale()
        local top = track:GetTop()
        if not (cursorY and scale and scale > 0 and top) then return end
        local travel = THEME_VIEW_HEIGHT - thumb:GetHeight() - 2
        local distance = math.max(0, math.min(travel, top - cursorY / scale - thumb:GetHeight() / 2))
        SetThemeScroll(travel > 0 and distance / travel * maxThemeScroll or 0)
    end
    track:SetScript("OnMouseDown", function(self)
        self.dragging = true
        CursorScroll()
        self:SetScript("OnUpdate", function(active) if active.dragging then CursorScroll() end end)
    end)
    local function StopScrollDrag(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
    end
    track:SetScript("OnMouseUp", StopScrollDrag)
    track:SetScript("OnDragStop", StopScrollDrag)
    track:SetScript("OnHide", StopScrollDrag)
    track:SetScript("OnDragStart", function(self) self.dragging = true end)

    quick.themeChoices = {}
    for index, name in ipairs(style.order) do
        local row, column = math.floor((index - 1) / THEME_COLUMNS), (index - 1) % THEME_COLUMNS
        local choice = Choice(themeContent, "vignetteRadarTheme", name, style.names[name],
            column * 61, -row * THEME_ROW - 1, 56)
        choice:EnableMouseWheel(true)
        choice:SetScript("OnMouseWheel", WheelThemes)
        quick.themeChoices[name] = choice
        local stripe = choice:CreateTexture(nil, "OVERLAY")
        stripe:SetPoint("TOPLEFT", 2, -1)
        stripe:SetPoint("TOPRIGHT", -2, -1)
        stripe:SetHeight(2)
        stripe:SetColorTexture(style.PresetColor(name, "accent"))
    end
    SetThemeScroll(0)
    Check(themes, "vignetteRadarShapes", "Use icons (off = colored dots)", 14, -78)
    quick.customLabel = Section(themes, "THEME COLORS", -116)
    local slots = style.slots
    for index, slot in ipairs(slots) do
        local row, column = math.floor((index - 1) / 2), (index - 1) % 2
        ColorSwatch(themes, slot, 14 + column * 135, -133 - row * 25)
    end

    local behavior = quick.pages.Behavior
    Check(behavior, "vignetteRadarLastSeen", "Keep last-seen markers", 14, -3)
    Section(behavior, "KEEP FOR", -40)
    Choice(behavior, "vignetteRadarLastSeenSeconds", 5, "5 sec", 14, -57, 80)
    Choice(behavior, "vignetteRadarLastSeenSeconds", 10, "10 sec", 104, -57, 80)
    Choice(behavior, "vignetteRadarLastSeenSeconds", 15, "15 sec", 194, -57, 80)
    Check(behavior, "vignetteRadarQuietCombat", "Mute combat alerts", 14, -91)
    Check(behavior, "vignetteRadarKeepVisibleCombat", "Stay fully visible", 14, -124)
    Check(behavior, "vignetteRadarQuietInstances", "Fade + mute in instances", 14, -157)
    Button(behavior, "Clear ignored vignettes", 14, -200, 260, function()
        if addon.VignetteRadarFeatures and addon.VignetteRadarFeatures.ClearIgnored then
            addon.VignetteRadarFeatures.ClearIgnored()
            addon.VignetteRadarAPI.Refresh(true)
            API.Refresh()
        end
    end)

    local quests = quick.pages.Quests
    Check(quests, "vignetteRadarQuestDots", "Show gold quest dots", 14, -3)
    Check(quests, "vignetteRadarQuestAreas", "Shade Blizzard quest areas", 14, -31)
    Label(quests, "Quest areas switch the radar to a square.", 14, -75, 10)
    Label(quests, "The exact area shape needs north-up mode.", 14, -98, 10)
    Check(quests, "vignetteRadarNorthUp", "Keep north at the top", 14, -130)
    Label(quests, "Quest dots follow either radar orientation.", 14, -174, 10)

    local explore = quick.pages.Explore
    Check(explore, "vignetteRadarSmartZoom", "Smart zoom while moving", 14, -3)
    Check(explore, "vignetteRadarUntangle", "Spread overlapping markers", 14, -31)
    Check(explore, "vignetteRadarBreadcrumbs", "Show dotted travel trail", 14, -59)
    Check(explore, "vignetteRadarApproachAlerts", "Alert near watched targets", 14, -87)
    Check(explore, "vignetteRadarJournalEnabled", "Save sighting history", 14, -115)
    Stepper(explore, "vignetteRadarApproachDistance", "Approach distance", -148,
        { 25, 50, 75, 100, 150, 200, 300, 400, 600 }, function(value) return value .. " yd" end)
    Section(explore, "HUNTING PRESETS", -170)
    for index, name in ipairs({ "Treasure", "Rare", "Questing", "Exploring" }) do
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        Button(explore, name, 14 + column * 136, -188 - row * 26, 124, function()
            addon.VignetteRadarExploration.ApplyPreset(name)
            API.Refresh()
        end)
    end
    Button(explore, "Saved presets, pins & journal", 14, -244, 260, function()
        addon.VignetteRadarExploration.TogglePanel()
    end)

    SelectPage("Radar")
    quick:SetScript("OnShow", API.Refresh)
    quick:SetScript("OnHide", API.Refresh)
    quick:Hide()
    return quick
end

local function PositionAt(anchorFrame)
    if not quick then return end
    local source = anchorFrame or anchor
    quick:ClearAllPoints()
    quick:SetScale(1)
    if not source then
        quick:SetPoint("CENTER", UIParent, "CENTER")
        return
    end
    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local left, right, top, bottom = source:GetLeft(), source:GetRight(), source:GetTop(), source:GetBottom()
    local rightSpace = right and screenWidth - right - 12 or 0
    local leftSpace = left and left - 12 or 0
    if rightSpace >= WIDTH + 8 then
        quick:SetPoint("TOPLEFT", source, "TOPRIGHT", 8, 0)
    elseif leftSpace >= WIDTH + 8 then
        quick:SetPoint("TOPRIGHT", source, "TOPLEFT", -8, 0)
    elseif bottom and bottom >= HEIGHT + 12 then
        quick:SetPoint("TOP", source, "BOTTOM", 0, -8)
    elseif top and screenHeight - top >= HEIGHT + 12 then
        quick:SetPoint("BOTTOM", source, "TOP", 0, 8)
    elseif rightSpace >= WIDTH * .65 + 8 then
        quick:SetScale(math.min(1, (rightSpace - 8) / WIDTH))
        quick:SetPoint("TOPLEFT", source, "TOPRIGHT", 8, 0)
    elseif leftSpace >= WIDTH * .65 + 8 then
        quick:SetScale(math.min(1, (leftSpace - 8) / WIDTH))
        quick:SetPoint("TOPRIGHT", source, "TOPLEFT", -8, 0)
    else
        quick:SetScale(math.min(1, (screenWidth - 24) / WIDTH, (screenHeight - 24) / HEIGHT))
        quick:SetPoint("CENTER", UIParent, "CENTER")
    end
    anchor = source
end

function API.Toggle(anchorFrame)
    local frame = Build()
    if frame:IsShown() then frame:Hide(); return false end
    PositionAt(anchorFrame)
    API.Refresh()
    frame:Show()
    API.Refresh()
    return true
end

function API.Reanchor(anchorFrame)
    if quick and quick:IsShown() then PositionAt(anchorFrame) end
end

function API.Hide()
    if quick then quick:Hide() end
end

function API.IsShown()
    return quick and quick:IsShown() or false
end

function API.GetPanel()
    return quick
end
