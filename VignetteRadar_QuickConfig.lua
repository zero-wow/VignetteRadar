local _, addon = ...
if type(addon) ~= "table" then return end

local WIDTH, HEIGHT = 288, 432
local THEME_COLUMNS, THEME_ROW, THEME_VIEW_HEIGHT = 4, 24, 46
local THEME_VIEW_WIDTH = 244
local ACCENT = { 0.05, 0.82, 0.62 }
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local quick, anchor, guide
local checks, groups, steppers, swatches, sections = {}, {}, {}, {}, {}
local searchEntries = {}
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

local function RegisterSearch(page, key, title)
    local name = page and page.searchPage
    if name and title and title ~= "" then
        searchEntries[#searchEntries + 1] = { page = name, key = key, title = title,
            match = (name .. " " .. title .. " " .. (key or "")):lower() }
    end
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
    elseif key == "vignetteRadarBreadcrumbs" then
        addon.SetVignetteRadarTrailEnabled(value)
    elseif key == "vignetteRadarTrailStyle" then
        addon.SetVignetteRadarTrailStyle(value)
    elseif key == "vignetteRadarPOIIcons" then
        db[key] = value == true
        addon.VignetteRadarAPI.Refresh(false)
    elseif key == "vignetteRadarFollowZygor" and addon.VignetteRadarZygor then
        local ready, reason = true, nil
        if value then ready, reason = addon.VignetteRadarAPI.BindZygorGuide() end
        if ready then
            if quick then quick.zygorError = nil end
            addon.VignetteRadarZygor.SetFollow(value)
        else
            db[key] = false
            if quick then quick.zygorError = reason or "Zygor is unavailable" end
        end
    elseif key == "vignetteRadarZygorMode" and addon.VignetteRadarZygor then
        addon.VignetteRadarZygor.SetMode(value)
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
    if key == "vignetteRadarIndependentViews" and value == true then
        addon.VignetteRadarViewProfiles.Record(db)
    elseif key == "vignetteRadarHoverTools" or key == "vignetteRadarControlsVisible" then
        addon.VignetteRadarViewProfiles.Record(db)
    end
    if addon.RefreshVignetteRadarOptions then addon.RefreshVignetteRadarOptions() end
    API.Refresh()
end

local function Check(page, key, title, x, y, subkey, labelWidth)
    title = addon.VignetteRadarControls.TitleCase(title)
    local box = addon.VignetteRadarControls.Checkbox(page)
    box:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
    local hit = CreateFrame("Button", nil, page)
    hit:SetPoint("TOPLEFT", page, "TOPLEFT", x + 31, y)
    hit:SetSize(labelWidth or WIDTH - x - 43, 26)
    box.label = Label(hit, title, 0, -7, 10, hit:GetWidth())
    box.optionKey, box.subkey = key, subkey
    if key == "vignetteRadarNorthUp" then box:SetGlyph("N")
    elseif key == "vignetteRadarKeepVisibleCombat" then box:SetGlyph("eye") end
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
    RegisterSearch(page, key, title)
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
    title = addon.VignetteRadarControls.TitleCase(title)
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
    RegisterSearch(page, key, title)
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
    Label(page, addon.VignetteRadarControls.TitleCase(style.labels[slot]),
        x + 24, y - 3, 9, x < 100 and 99 or 101)
    swatches[slot] = button
end

Button = function(page, title, x, y, width, action, searchKey)
    local controls = addon.VignetteRadarControls
    local button = (title == "+" or title == "-" or title == "−")
        and controls.IconButton(page, title, width, 21)
        or controls.Button(page, controls.TitleCase(title), width, 21)
    button:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
    button:SetScript("OnClick", action)
    if title ~= "+" and title ~= "-" and title ~= "−" then
        RegisterSearch(page, searchKey, title)
    end
    return button
end

local function Choice(page, key, value, title, x, y, width)
    local button = Button(page, title, x, y, width, function() Changed(key, value) end, key)
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

local function RefreshPOISources()
    if not quick or not quick.poiRows then return end
    local poi = addon.VignetteRadarPOIs
    local radar = addon.VignetteRadarAPI
    local mapID = radar and radar.GetCurrentMapID and radar.GetCurrentMapID()
    local sources = poi and poi.ZoneSources(mapID) or {}
    local entries = { { id = "none", enabled = true }, { id = "auto", enabled = true } }
    for _, source in ipairs(sources) do entries[#entries + 1] = source end
    quick.poiEntries = entries
    if quick.poiMapID ~= mapID then quick.poiOffset, quick.poiMapID = 0, mapID end
    local maxOffset = math.max(0, #entries - #quick.poiRows)
    quick.poiOffset = math.min(maxOffset, quick.poiOffset or 0)
    local selected = Settings().vignetteRadarPOISource
    local zoneChoice = poi and poi.ZoneChoice and poi.ZoneChoice(mapID)
    local selectedEntry
    for _, entry in ipairs(entries) do
        if entry.id == selected then selectedEntry = entry; break end
    end
    for index, row in ipairs(quick.poiRows) do
        local entry = entries[index + quick.poiOffset]
        row.sourceID = entry and entry.id
        row:SetShown(entry ~= nil)
        if entry then
            row:SetText(entry.id == "none" and "Off" or entry.id == "auto" and "Auto · current zone"
                or entry.id:gsub("(%l)(%u)", "%1 %2"):gsub("_", " "))
            row:SetEnabled(entry.enabled)
            if entry.id == (selected == "auto" and zoneChoice or selected) then
                row:LockHighlight()
            else row:UnlockHighlight() end
        end
    end
    local track = 85
    quick.poiThumb:SetHeight(math.max(16, track * math.min(1, #quick.poiRows / #entries)))
    quick.poiThumb:ClearAllPoints()
    quick.poiThumb:SetPoint("TOP", quick.poiTrack, "TOP", 0,
        maxOffset > 0 and -((track - quick.poiThumb:GetHeight()) * quick.poiOffset / maxOffset) or 0)
    quick.poiTrack:SetShown(maxOffset > 0)
    if selected == "none" then
        quick.poiStatus:SetText("Map notes are off. Choose Auto or a pack above.")
    elseif selected == "auto" then
        local chosen = poi and poi.ResolveSource(mapID, selected)
        quick.poiStatus:SetText(zoneChoice == "none" and "Map notes are off in this zone."
            or zoneChoice and chosen == zoneChoice and ("Pinned here: " .. zoneChoice)
            or zoneChoice and ("Pinned pack unavailable; using " .. tostring(chosen or "none"))
            or chosen and ("Auto: " .. chosen .. " · right-click to pin")
            or "No enabled HandyNotes pack has notes here.")
    elseif not selectedEntry then
        quick.poiStatus:SetText("This pack has no notes here. Choose Auto.")
    else
        quick.poiStatus:SetText(Settings().vignetteRadarPOIIcons
            and "Pack icons · dots where unavailable." or "One pack here · hollow dots are saved notes.")
    end
end

function API.Refresh()
    if not quick then return end
    local db = Settings()
    if quick.pages["World Focus"] and quick.pages["World Focus"].status then
        local focus = addon.VignetteRadarWorldFocus
        quick.pages["World Focus"].status:SetText(focus and focus.Status() or "Waypoint data unavailable")
        if quick.pages["Auto Route"] and quick.pages["Auto Route"].status then
            quick.pages["Auto Route"].status:SetText(focus and focus.Status() or "Waypoint data unavailable")
        end
    end
    if quick.pages.Zygor and quick.pages.Zygor.status and addon.VignetteRadarZygor then
        quick.pages.Zygor.status:SetText(quick.zygorError
            or addon.VignetteRadarZygor.GuideLabel()
                .. "\n" .. addon.VignetteRadarZygor.Status())
        if quick.pages.Zygor.followButton then
            quick.pages.Zygor.followButton:SetText(addon.VignetteRadarZygor.IsPaused()
                and "Resume Follow" or addon.VignetteRadarZygor.IsFollowing()
                    and "Pause Follow" or "Start Follow")
        end
    end
    if quick.pages.Performance and quick.pages.Performance.workload then
        local budget = addon.VignetteRadarBudget
        local recent = budget and budget.recent or {}
        local total = (recent.radar or 0) + (recent.launcher or 0)
            + (recent.background or 0)
        quick.pages.Performance.workload:SetText(budget and next(budget.paused)
            and string.format("Recent update work: %.1f ms/sec · retrying automatically", total)
            or budget and budget.softThrottle
                and string.format("Recent update work: %.1f ms/sec · temporarily slowed", total)
                or string.format("Recent update work: %.1f ms/sec", total))
        local layerBudget = addon.VignetteRadarLayerBudget
        if quick.pages.Performance.layers and layerBudget then
            quick.pages.Performance.layers:SetText(layerBudget.StatusLine())
        end
    end
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
        quick.headerLine:SetColorTexture(ar, ag, ab, .18)
        quick.bead:SetColorTexture(ar, ag, ab, 1)
        if quick.poiThumb then quick.poiThumb:SetColorTexture(ar, ag, ab, .7) end
        if quick.themeThumb then quick.themeThumb:SetColorTexture(ar, ag, ab, .95) end
        for _, label in ipairs(sections) do label:SetTextColor(ar, ag, ab, .88) end
        if anchor and anchor.settingsDot then
            anchor.settingsDot.rim:SetVertexColor(ar, ag, ab, quick:IsShown() and .68 or .20)
        end
        local br, bg, bb = style.Color("background")
        quick:SetBackdropColor(math.min(.14, br * 2.7), math.min(.14, bg * 2.7),
            math.min(.14, bb * 2.7), .99)
        addon.VignetteRadarControls.RefreshPopupSurface(quick)
        for slot, button in pairs(swatches) do
            button:SetBackdropColor(style.Color(slot))
        end
        quick.customLabel:SetText(style.IsCustomized() and "CUSTOM COLORS" or "THEME COLORS")
        addon.VignetteRadarControls.RefreshTheme()
    end
    RefreshPOISources()
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
    if name == "Status" and API.RefreshStatus then API.RefreshStatus() end
    API.Refresh()
end

function API.RefreshStatus()
    if not (quick and quick.pages.Status and quick.pages.Status.diagnosticLines) then return end
    local lines = addon.GetVignetteRadarDiagnostics and addon.GetVignetteRadarDiagnostics() or {}
    for index, label in ipairs(quick.pages.Status.diagnosticLines) do
        label:SetText(lines[index] or "")
    end
end

local function RefreshSearch()
    if not (quick and quick.searchRows and quick.searchInput) then return end
    local query = (quick.searchInput:GetText() or ""):lower():match("^%s*(.-)%s*$")
    local matches = {}
    if query ~= "" then
        for _, result in ipairs(searchEntries) do
            if result.match:find(query, 1, true) then
                local title = result.title:lower()
                local score = title == query and 0 or title:find(query, 1, true) == 1 and 1
                    or result.page:lower():find(query, 1, true) and 2 or 3
                matches[#matches + 1] = { result = result, score = score }
            end
        end
        table.sort(matches, function(a, b)
            if a.score ~= b.score then return a.score < b.score end
            if a.result.page ~= b.result.page then return a.result.page < b.result.page end
            return a.result.title < b.result.title
        end)
    end
    local shown = math.min(#matches, #quick.searchRows)
    for index = 1, shown do
        local row, result = quick.searchRows[index], matches[index].result
        row.result = result
        row:SetText(result.page .. "  ·  " .. result.title)
        row:Show()
    end
    for index = shown + 1, #quick.searchRows do
        quick.searchRows[index]:Hide()
    end
    quick.searchHint:SetText(query == "" and "Type an option or button name."
        or shown == 0 and "No matching setting."
        or #matches > shown and ("Showing " .. shown .. " of " .. #matches .. " matches.")
        or "Choose a result to open its page.")
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
    addon.VignetteRadarControls.PopupSurface(quick)
    quick.pages, quick.tabs = {}, {}
    quick.bead = quick:CreateTexture(nil, "OVERLAY")
    quick.bead:SetSize(5, 5)
    quick.bead:SetPoint("TOPLEFT", 12, -13)
    quick.title = Label(quick, "RADAR SETTINGS", 23, -9, 11, 180)
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
    local find = addon.VignetteRadarControls.Button(quick, "Find", 44, 20)
    find:SetPoint("TOPRIGHT", quick, "TOPRIGHT", -34, -7)
    find:SetScript("OnClick", function()
        SelectPage("Search")
        if quick.searchInput and quick.searchInput.SetFocus then quick.searchInput:SetFocus() end
    end)
    quick.find = find

    local order = { "Radar", "Layout", "Explore", "Alerts", "Markers", "Guides", "Themes", "Behavior", "Quests", "Wayfinding", "Map Data", "Status" }
    for index, name in ipairs(order) do
        local row, column = math.floor((index - 1) / 3), (index - 1) % 3
        local tab = addon.VignetteRadarControls.Button(quick, name, 84, 20)
        tab:SetPoint("TOPLEFT", quick, "TOPLEFT", 12 + column * 89, -40 - row * 23)
        tab:SetScript("OnClick", function() SelectPage(name) end)
        quick.tabs[name] = tab
        local page = CreateFrame("Frame", nil, quick)
        page:SetSize(WIDTH, HEIGHT - 137)
        page:SetPoint("TOPLEFT", quick, "TOPLEFT", 0, -137)
        page.searchPage = name
        page:Hide()
        quick.pages[name] = page
    end

    local radar = quick.pages.Radar
    Check(radar, "vignetteRadarEnabled", "Enable radar", 14, -3)
    Check(radar, "vignetteRadarHideWhenEmpty", "Hide when empty", 14, -31)
    Check(radar, "vignetteRadarLauncherVisible", "Show launcher", 14, -59)
    Check(radar, "vignetteRadarWorldMap", "Include world-map detections", 14, -87)
    Check(radar, "vignetteRadarEmptyHelp", "Explain an empty radar", 14, -109)
    Section(radar, "RANGE", -137)
    quick.rangeMinus = Button(radar, "−", 14, -154, 45, function() StepRange(-1) end)
    quick.rangeMinus.optionKey = "vignetteRadarRange"
    quick.rangeValue = Label(radar, "450 yd", 78, -157, 11, 126)
    quick.rangeValue:SetJustifyH("CENTER")
    quick.rangePlus = Button(radar, "+", 228, -154, 45, function() StepRange(1) end)
    quick.rangePlus.optionKey = "vignetteRadarRange"
    Button(radar, "Preview", 14, -190, 124, function()
        addon.ToggleVignetteRadarPreview()
        API.Reanchor()
    end)
    Button(radar, "Reset positions", 150, -190, 124, function()
        addon.ResetVignetteRadarPositions()
        API.Reanchor()
    end)
    Button(radar, "Explore tools", 14, -224, 260, function()
        if addon.VignetteRadarExploration then addon.VignetteRadarExploration.TogglePanel() end
    end)
    Button(radar, "How to read the radar", 14, -253, 260, function()
        if API.ShowGuide then API.ShowGuide(anchor) end
    end)

    local layout = quick.pages.Layout
    Section(layout, "RADAR LAYOUT", -5)
    Check(layout, "vignetteRadarNorthUp", "Keep North At The Top", 14, -30)
    Check(layout, "vignetteRadarHoverTools", "Show Controls On Hover", 14, -65)
    Label(layout, "Drag the radar edges to change its size.", 14, -97, 10)
    Section(layout, "RADAR SIZE", -126)
    Stepper(layout, "vignetteRadarScale", "Radar Scale", -151,
        { .8, .9, 1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8 },
        function(value) return math.floor(value * 100 + .5) .. "%" end)
    Check(layout, "vignetteRadarActiveCue", "Pulse Active Destination", 14, -191)
    Check(layout, "vignetteRadarRouteHorizonExpanded", "Show Upcoming Route Stops", 14, -221)
    Check(layout, "vignetteRadarSourceBadges", "Show Marker Source Badges", 14, -251)

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
    Button(markers, "Bearing Bar...", 14, -251, 124, function()
        SelectPage("Beacons")
    end)
    Button(markers, "World Focus...", 150, -251, 124, function()
        SelectPage("World Focus")
    end)

    local focus = CreateFrame("Frame", nil, quick)
    focus:SetSize(WIDTH, HEIGHT - 137)
    focus:SetPoint("TOPLEFT", quick, "TOPLEFT", 0, -137)
    focus.searchPage = "World Focus"
    focus:Hide()
    quick.pages["World Focus"] = focus
    Section(focus, "SINGLE WORLD WAYPOINT", -3)
    Check(focus, "vignetteRadarWorldFocusEnabled", "Click Markers to Focus a Waypoint", 14, -21)
    Check(focus, "vignetteRadarWorldFocusAutoAdvance", "Advance When You Arrive", 14, -49)
    Check(focus, "vignetteRadarWorldFocusRoutes", "Follow Pack Entrance + Path Steps", 14, -77)
    Check(focus, "vignetteRadarWorldFocusSavedNotes", "Include Saved Treasure + Rare Notes", 14, -105)
    Check(focus, "vignetteRadarWorldFocusZygor", "Show Zygor Step", 14, -133, nil, 145)
    focus.pinZygor = Button(focus, "Zygor...", 202, -135, 72, function()
        SelectPage("Zygor")
    end)
    Section(focus, "RARE FOCUS ARRIVAL DISTANCE", -166)
    Choice(focus, "vignetteRadarWorldFocusArrivalRadius", 10, "10 yd", 14, -184, 80)
    Choice(focus, "vignetteRadarWorldFocusArrivalRadius", 20, "20 yd", 104, -184, 80)
    Choice(focus, "vignetteRadarWorldFocusArrivalRadius", 40, "40 yd", 194, -184, 80)
    Button(focus, "Previous", 14, -218, 80, function()
        if addon.VignetteRadarWorldFocus then addon.VignetteRadarWorldFocus.Cycle(-1) end
        API.Refresh()
    end)
    Button(focus, "Next", 104, -218, 80, function()
        if addon.VignetteRadarWorldFocus then addon.VignetteRadarWorldFocus.Cycle(1) end
        API.Refresh()
    end)
    Button(focus, "Back", 194, -218, 80, function() SelectPage("Markers") end)
    Button(focus, "Next Route Step", 14, -246, 124, function()
        if addon.VignetteRadarWorldFocus then addon.VignetteRadarWorldFocus.Advance() end
        API.Refresh()
    end)
    Button(focus, "Auto Route...", 150, -246, 124, function() SelectPage("Auto Route") end)
    focus.status = Label(focus, "", 14, -277, 9, 260)

    local zygor = CreateFrame("Frame", nil, quick)
    zygor:SetSize(WIDTH, HEIGHT - 137)
    zygor:SetPoint("TOPLEFT", quick, "TOPLEFT", 0, -137)
    zygor.searchPage = "Zygor"
    zygor:Hide()
    quick.pages.Zygor = zygor
    Section(zygor, "ZYGOR GUIDE", -3)
    Check(zygor, "vignetteRadarWorldFocusZygor", "Show Guide Point on Radar", 14, -21)
    Check(zygor, "vignetteRadarFollowZygor", "Follow Active Guide Automatically", 14, -49)
    Section(zygor, "FOLLOW DESTINATION", -81)
    Choice(zygor, "vignetteRadarZygorMode", "objective", "Objective", 14, -99, 124)
    Choice(zygor, "vignetteRadarZygorMode", "travel", "Travel Stop", 150, -99, 124)
    zygor.pinObjective = Button(zygor, "Pin Objective", 14, -133, 124, function()
        local bridge = addon.VignetteRadarZygor
        local ok, reason = addon.VignetteRadarAPI.BindZygorGuide()
        if ok and bridge then ok, reason = bridge.Pin("objective") end
        API.Refresh()
        if not ok and reason then zygor.status:SetText(reason) end
    end)
    zygor.pinTravel = Button(zygor, "Pin Travel Stop", 150, -133, 124, function()
        local bridge = addon.VignetteRadarZygor
        local ok, reason = addon.VignetteRadarAPI.BindZygorGuide()
        if ok and bridge then ok, reason = bridge.Pin("travel") end
        API.Refresh()
        if not ok and reason then zygor.status:SetText(reason) end
    end)
    zygor.status = Label(zygor, "", 14, -170, 9, 260)
    zygor.status:SetHeight(43)
    zygor.status:SetWordWrap(true)
    zygor.followButton = Button(zygor, "Start Follow", 14, -221, 124, function()
        local ok, reason = addon.VignetteRadarAPI.BindZygorGuide()
        if ok then ok, reason = addon.VignetteRadarZygor.ToggleFollow() end
        API.Refresh()
        if not ok and reason then zygor.status:SetText(reason) end
    end)
    Button(zygor, "Back to World Focus", 150, -221, 124, function()
        SelectPage("World Focus")
    end)
    Label(zygor, "Manual waypoints pause Follow until you resume it.", 14, -258, 9, 260)

    local autoRoute = CreateFrame("Frame", nil, quick)
    autoRoute:SetSize(WIDTH, HEIGHT - 137)
    autoRoute:SetPoint("TOPLEFT", quick, "TOPLEFT", 0, -137)
    autoRoute.searchPage = "Auto Route"
    autoRoute:Hide()
    quick.pages["Auto Route"] = autoRoute
    Section(autoRoute, "AUTO ROUTE", -3)
    Check(autoRoute, "vignetteRadarAutoRouteOnSelect", "Start When I Click a Point", 14, -21)
    Check(autoRoute, "vignetteRadarAutoRouteMapNotes", "Include Current Map Data Pack", 14, -49)
    Check(autoRoute, "vignetteRadarRouteArrow", "Mini Route Arrow", 14, -77, nil, 94)
    Check(autoRoute, "vignetteRadarWorldFocusThemedWaypoint", "Color World Pin", 150, -77, nil, 92)
    Section(autoRoute, "TRAVEL MODE", -111)
    Choice(autoRoute, "vignetteRadarAutoRouteTravel", "auto", "Auto", 14, -129, 80)
    Choice(autoRoute, "vignetteRadarAutoRouteTravel", "ground", "Ground", 104, -129, 80)
    Choice(autoRoute, "vignetteRadarAutoRouteTravel", "flying", "Flying", 194, -129, 80)
    Section(autoRoute, "RARE ARRIVAL DISTANCE", -161)
    Choice(autoRoute, "vignetteRadarAutoRouteArrivalRadius", 10, "10 yd", 14, -179, 80)
    Choice(autoRoute, "vignetteRadarAutoRouteArrivalRadius", 20, "20 yd", 104, -179, 80)
    Choice(autoRoute, "vignetteRadarAutoRouteArrivalRadius", 40, "40 yd", 194, -179, 80)
    Button(autoRoute, "Start/Pause", 14, -207, 80, function()
        local focusAPI = addon.VignetteRadarWorldFocus
        if focusAPI then focusAPI.ToggleRoute() end
        if addon.VignetteRadarRouteArrow then addon.VignetteRadarRouteArrow.Refresh() end
        API.Refresh()
    end)
    Button(autoRoute, "Skip Stop", 104, -207, 80, function()
        local focusAPI = addon.VignetteRadarWorldFocus
        if focusAPI then focusAPI.SkipRouteStop() end
        API.Refresh()
    end)
    Button(autoRoute, "Skip Quest", 194, -207, 80, function()
        local focusAPI = addon.VignetteRadarWorldFocus
        if focusAPI then focusAPI.SkipQuest() end
        API.Refresh()
    end)
    Button(autoRoute, "Back to World Focus", 14, -235, 260, function()
        SelectPage("World Focus")
    end)
    autoRoute.status = Label(autoRoute, "", 14, -265, 9, 260)
    autoRoute.status:SetHeight(18)
    autoRoute.status:SetWordWrap(true)

    local beacons = CreateFrame("Frame", nil, quick)
    beacons:SetSize(WIDTH, HEIGHT - 137)
    beacons:SetPoint("TOPLEFT", quick, "TOPLEFT", 0, -137)
    beacons.searchPage = "Beacons"
    beacons:Hide()
    quick.pages.Beacons = beacons
    Section(beacons, "Bearing Bar", -3)
    Check(beacons, "vignetteRadarBeaconsEnabled", "Show Multi-Point Bearing Display", 14, -22)
    Check(beacons, "vignetteRadarBeaconRares", "Rares", 14, -50, nil, 55)
    Check(beacons, "vignetteRadarBeaconTreasures", "Loot/Caves", 104, -50, nil, 55)
    Check(beacons, "vignetteRadarBeaconQuests", "Quests", 194, -50, nil, 52)
    Section(beacons, "Show Within", -88)
    Choice(beacons, "vignetteRadarBeaconRange", 150, "150 yd", 14, -106, 60)
    Choice(beacons, "vignetteRadarBeaconRange", 450, "450 yd", 80, -106, 60)
    Choice(beacons, "vignetteRadarBeaconRange", 1200, "1200 yd", 146, -106, 60)
    Choice(beacons, "vignetteRadarBeaconRange", 2400, "2400 yd", 212, -106, 62)
    Section(beacons, "Most Important Points", -149)
    for index, limit in ipairs({ 4, 8, 12, 16, 24 }) do
        Choice(beacons, "vignetteRadarBeaconMax", limit, tostring(limit),
            14 + (index - 1) * 52, -167, 48)
    end
    Button(beacons, "Preview", 14, -211, 124, function()
        if addon.VignetteRadarBeacons then addon.VignetteRadarBeacons.Preview(true) end
    end)
    Button(beacons, "Back to Markers", 150, -211, 124, function()
        if addon.VignetteRadarBeacons then addon.VignetteRadarBeacons.Preview(false) end
        SelectPage("Markers")
    end)
    Label(beacons, "Drag the Display's Top Edge to Move It.", 14, -245, 9)
    Label(beacons, "Click a Marker to Focus It on the Radar.", 14, -260, 9)

    local guides = quick.pages.Guides
    Section(guides, "RADAR GUIDES & FACING", -3)
    local percent = function(value) return math.floor(value * 100 + .5) .. "%" end
    Stepper(guides, "vignetteRadarRingOpacity", "Ring visibility", -25,
        { 0, .25, .5, .75, 1, 1.25, 1.5, 1.75, 2 }, percent)
    Stepper(guides, "vignetteRadarRangeLabelOpacity", "Yard text visibility", -61,
        { 0, .25, .5, .75, 1, 1.5, 2, 3, 4, 6, 8, 12, 16 }, percent)
    Stepper(guides, "vignetteRadarChevronOpacity", "Chevron opacity", -97,
        { 0, .1, .2, .3, .4, .5, .6, .72, .8, .9, 1 }, percent)
    Stepper(guides, "vignetteRadarHeadingOpacity", "Facing line opacity", -133,
        { 0, .1, .2, .3, .4, .46, .5, .6, .7, .8, .9, 1 }, percent)
    Stepper(guides, "vignetteRadarChevronDistance", "Chevron gap", -169,
        { 2, 3, 4, 5, 6, 7, 8, 9 }, function(value) return value .. " px" end)
    Stepper(guides, "vignetteRadarHeadingLength", "Facing line length", -205,
        { .12, .16, .2, .25, .3, .35, .4, .5, .6, .7, .8 }, percent)
    Check(guides, "vignetteRadarFullSweep", "Animated Sweep On Radar", 14, -247)

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
    themeContent.searchPage = "Themes"
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
    Stepper(themes, "vignetteRadarBorderOpacity", "Radar Border Visibility", -259,
        { 0, .25, .5, .75, 1, 1.25, 1.5, 2, 2.5, 3, 4 }, percent)

    local behavior = quick.pages.Behavior
    Check(behavior, "vignetteRadarLastSeen", "Keep last-seen markers", 14, -3)
    Section(behavior, "KEEP FOR", -40)
    Choice(behavior, "vignetteRadarLastSeenSeconds", 5, "5 sec", 14, -57, 80)
    Choice(behavior, "vignetteRadarLastSeenSeconds", 10, "10 sec", 104, -57, 80)
    Choice(behavior, "vignetteRadarLastSeenSeconds", 15, "15 sec", 194, -57, 80)
    Check(behavior, "vignetteRadarQuietCombat", "Mute combat alerts", 14, -91)
    Check(behavior, "vignetteRadarKeepVisibleCombat", "Stay fully visible", 14, -124)
    Check(behavior, "vignetteRadarQuietInstances", "Fade + mute in instances", 14, -157)
    Check(behavior, "vignetteRadarHideCleared", "Hide cleared rares + treasures", 14, -185)
    Button(behavior, "Clear ignored vignettes", 14, -239, 260, function()
        if addon.VignetteRadarFeatures and addon.VignetteRadarFeatures.ClearIgnored then
            addon.VignetteRadarFeatures.ClearIgnored()
            addon.VignetteRadarAPI.Refresh(true)
            API.Refresh()
        end
    end)

    local quests = quick.pages.Quests
    Check(quests, "vignetteRadarQuestDots", "Show quest diamonds", 14, -3)
    Check(quests, "vignetteRadarQuestAreas", "Shade Blizzard quest areas", 14, -31)
    Check(quests, "vignetteRadarQuestHalos", "Approximate quest circles", 14, -59)
    Check(quests, "vignetteRadarFollowTrackedQuest", "Outline Blizzard's tracked quest", 14, -87)
    Check(quests, "vignetteRadarNorthUp", "Keep north at the top", 14, -115)
    Check(quests, "vignetteRadarEdgeCues", "Show nearby off-screen cues", 14, -143)
    Check(quests, "vignetteRadarQuestColors", "Color quest diamonds", 14, -171)
    Check(quests, "vignetteRadarQuestAreaColors", "Color estimated quest circles", 14, -199)
    Stepper(quests, "vignetteRadarQuestHaloRadius", "Circle radius", -230,
        { 10, 20, 40, 80 }, function(value) return value .. " yd" end)
    Button(quests, "Quest key", 14, -258, 124, function()
        if addon.VignetteRadarAPI and addon.VignetteRadarAPI.ToggleQuestKey then
            addon.VignetteRadarAPI.ToggleQuestKey()
        end
    end)
    Check(quests, "vignetteRadarQuestKeyProgress", "Progress", 147, -257, nil, 95)

    local wayfinding = quick.pages.Wayfinding
    Check(wayfinding, "vignetteRadarNextQuestStep", "Use Blizzard's next quest step", 14, -3)
    Check(wayfinding, "vignetteRadarQuestStartBadges", "Show available quest-line starts", 14, -31)
    Check(wayfinding, "vignetteRadarQuestNumbers", "Number quest color diamonds", 14, -59)
    Check(wayfinding, "vignetteRadarDataStatus", "Explain missing map data", 14, -87)
    Check(wayfinding, "vignetteRadarLensEnabled", "Enable hold-to-filter key", 14, -115)
    Section(wayfinding, "HOLD KEY SHOWS", -149)
    Choice(wayfinding, "vignetteRadarLensCategory", "quest", "Quests", 14, -169, 80)
    Choice(wayfinding, "vignetteRadarLensCategory", "rare", "Rares", 104, -169, 80)
    Choice(wayfinding, "vignetteRadarLensCategory", "treasure", "Treasure", 194, -169, 80)
    Label(wayfinding, "Assign the key in WoW's AddOns key bindings.", 14, -194, 9)
    Button(wayfinding, "Data status", 14, -211, 124, function(self)
        if addon.ToggleVignetteRadarStatus then addon.ToggleVignetteRadarStatus(self) end
    end)
    Button(wayfinding, "Draft route", 150, -211, 124, function()
        if addon.VignetteRadarExploration and addon.VignetteRadarExploration.OpenRouteDraft then
            addon.VignetteRadarExploration.OpenRouteDraft()
        end
    end)
    Check(wayfinding, "vignetteRadarRouteAutoAdvance", "Advance route on arrival", 14, -236)
    Choice(wayfinding, "vignetteRadarRouteArrivalRadius", 10, "10 yd", 14, -263, 80)
    Choice(wayfinding, "vignetteRadarRouteArrivalRadius", 20, "20 yd", 104, -263, 80)
    Choice(wayfinding, "vignetteRadarRouteArrivalRadius", 40, "40 yd", 194, -263, 80)

    local mapData = quick.pages["Map Data"]
    Section(mapData, "CHOOSE ONE MAP-DATA PACK", -3)
    mapData:EnableMouseWheel(true)
    local function ScrollPOI(_, delta)
        local maxOffset = math.max(0, #(quick.poiEntries or {}) - #quick.poiRows)
        quick.poiOffset = math.max(0, math.min(maxOffset, (quick.poiOffset or 0) - delta))
        RefreshPOISources()
    end
    mapData:SetScript("OnMouseWheel", ScrollPOI)
    quick.poiRows = {}
    for index = 1, 4 do
        local row = Button(mapData, "", 14, -23 - (index - 1) * 27, 244, function(self, mouseButton)
            if not self.sourceID then return end
            if mouseButton == "RightButton" then
                local poi = addon.VignetteRadarPOIs
                local mapID = addon.VignetteRadarAPI.GetCurrentMapID()
                if poi and poi.SetZoneChoice and poi.SetZoneChoice(mapID, self.sourceID) then
                    Changed("vignetteRadarPOISource", "auto")
                end
            else Changed("vignetteRadarPOISource", self.sourceID) end
        end)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.optionKey = "vignetteRadarPOISource"
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", ScrollPOI)
        row:HookScript("OnEnter", function(self)
            if not (GameTooltip and self.sourceID) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.sourceID == "none" and "Hide map notes"
                or self.sourceID == "auto" and "Auto: current zone" or self.sourceID, 1, 1, 1)
            GameTooltip:AddLine(self.sourceID == "auto"
                and "Automatically pick a pack for each map."
                or "Left-click: use everywhere. Right-click: use only in this zone.", .65, .78, .75, true)
            GameTooltip:Show()
        end)
        row:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        quick.poiRows[index] = row
    end
    quick.poiTrack = mapData:CreateTexture(nil, "ARTWORK")
    quick.poiTrack:SetSize(3, 85)
    quick.poiTrack:SetPoint("TOPLEFT", mapData, "TOPLEFT", 267, -24)
    quick.poiTrack:SetColorTexture(1, 1, 1, .1)
    quick.poiThumb = mapData:CreateTexture(nil, "OVERLAY")
    quick.poiThumb:SetWidth(3)
    quick.poiThumb:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], .7)
    Section(mapData, "SHOW THESE NOTE TYPES", -137)
    Check(mapData, "vignetteRadarPOITypes", "Treasures", 14, -156, "treasure", 91)
    Check(mapData, "vignetteRadarPOITypes", "Mobs", 147, -156, "mob", 91)
    Check(mapData, "vignetteRadarPOITypes", "Items", 14, -185, "item", 91)
    Check(mapData, "vignetteRadarPOITypes", "Other notes", 147, -185, "note", 91)
    Check(mapData, "vignetteRadarPOITypes", "Entrances", 14, -214, "entrance", 91)
    Check(mapData, "vignetteRadarPOIIcons", "Pack icons", 147, -214, nil, 91)
    quick.poiStatus = Label(mapData, "", 14, -243, 9, 260)
    Button(mapData, "Clear zone choice", 14, -259, 124, function()
        local poi = addon.VignetteRadarPOIs
        local mapID = addon.VignetteRadarAPI.GetCurrentMapID()
        if poi and poi.SetZoneChoice and poi.SetZoneChoice(mapID, nil) then
            addon.VignetteRadarAPI.Refresh(true)
            RefreshPOISources()
        end
    end)
    Check(mapData, "vignetteRadarHideCleared", "Hide cleared", 147, -259, nil, 91)

    local status = quick.pages.Status
    Section(status, "LIVE DIAGNOSTICS", -3)
    status.diagnosticLines = {}
    for index = 1, 9 do
        status.diagnosticLines[index] = Label(status, "", 14, -22 - (index - 1) * 25, 9, 260)
    end

    local search = CreateFrame("Frame", nil, quick)
    search:SetSize(WIDTH, HEIGHT - 137)
    search:SetPoint("TOPLEFT", quick, "TOPLEFT", 0, -137)
    search:Hide()
    quick.pages.Search = search
    Section(search, "FIND A SETTING", -3)
    quick.searchInput = CreateFrame("EditBox", nil, search, "BackdropTemplate")
    quick.searchInput:SetSize(260, 25)
    quick.searchInput:SetPoint("TOPLEFT", 14, -24)
    quick.searchInput:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    quick.searchInput:SetBackdropColor(.03, .045, .05, 1)
    quick.searchInput:SetBackdropBorderColor(.45, .60, .60, .45)
    quick.searchInput:SetFont(FONT, 11, "")
    quick.searchInput:SetTextInsets(7, 7, 0, 0)
    quick.searchInput:SetAutoFocus(false)
    quick.searchInput:SetMaxLetters(50)
    quick.searchInput:SetScript("OnTextChanged", RefreshSearch)
    quick.searchInput:SetScript("OnEscapePressed", function(self) self:ClearFocus(); SelectPage("Radar") end)
    quick.searchInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    quick.searchRows = {}
    for index = 1, 8 do
        local row = addon.VignetteRadarControls.Button(search, "", 260, 23)
        row:SetPoint("TOPLEFT", search, "TOPLEFT", 14, -57 - (index - 1) * 27)
        row:SetScript("OnClick", function(self)
            if self.result then SelectPage(self.result.page) end
        end)
        row:Hide()
        quick.searchRows[index] = row
    end
    quick.searchHint = Label(search, "Type an option or button name.", 14, -275, 9, 260)
    Button(status, "Rescan Now", 14, -255, 124, function()
        if addon.VignetteRadarAPI and addon.VignetteRadarAPI.RefreshMapData then
            addon.VignetteRadarAPI.RefreshMapData()
        end
        if API.RefreshStatus then API.RefreshStatus() end
    end)
    Button(status, "Performance...", 150, -255, 124, function()
        SelectPage("Performance")
    end)

    local performance = CreateFrame("Frame", nil, quick)
    performance:SetSize(WIDTH, HEIGHT - 137)
    performance:SetPoint("TOPLEFT", quick, "TOPLEFT", 0, -137)
    performance.searchPage = "Performance"
    performance:Hide()
    quick.pages.Performance = performance
    Section(performance, "RADAR UPDATE RATE", -3)
    Choice(performance, "vignetteRadarPerformance", "standard", "Standard", 14, -25, 80)
    Choice(performance, "vignetteRadarPerformance", "balanced", "Balanced", 104, -25, 80)
    Choice(performance, "vignetteRadarPerformance", "low", "Low CPU", 194, -25, 80)
    Label(performance, "Standard: 10 redraws/sec, scans each second.", 14, -61, 9)
    Label(performance, "Balanced: about 7 redraws/sec.", 14, -79, 9)
    Label(performance, "Low CPU: 4 redraws/sec and slower scans.", 14, -97, 9)
    Section(performance, "AUTOMATIC PROTECTION", -132)
    Label(performance, "Sustained high load slows updates automatically.", 14, -152, 9)
    Label(performance, "Extreme spikes pause briefly, then retry at Low CPU.", 14, -170, 9)
    performance.workload = Label(performance, "Measuring update work...", 14, -191, 9, 260)
    performance.workload:SetHeight(23)
    performance.workload:SetWordWrap(true)
    performance.layers = Label(performance, "Measuring drawing layers...", 14, -219, 9, 260)
    performance.layers:SetHeight(28)
    performance.layers:SetWordWrap(true)
    Button(performance, "Back to Status", 14, -255, 260, function()
        SelectPage("Status")
    end)

    local explore = quick.pages.Explore
    Check(explore, "vignetteRadarSmartZoom", "Smart zoom while moving", 14, -3)
    Check(explore, "vignetteRadarUntangle", "Spread overlapping markers", 14, -31)
    Check(explore, "vignetteRadarBreadcrumbs", "Travel trail", 14, -59, nil, 91)
    local trailPickerButton = Button(explore, "Styles & flow", 142, -61, 132, function(self)
        addon.ToggleVignetteRadarTrailPicker(self)
    end)
    trailPickerButton.optionKey = "vignetteRadarTrailStyle"
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
    quick:SetScript("OnHide", function()
        if addon.VignetteRadarBeacons then addon.VignetteRadarBeacons.Preview(false) end
        API.Refresh()
    end)
    quick:Hide()
    return quick
end

function API.ShowGuide(anchorFrame)
    if not guide then
        guide = CreateFrame("Frame", "VignetteRadarGuidePanel", UIParent, "BackdropTemplate")
        guide:SetSize(238, 211)
        guide:SetFrameStrata("DIALOG")
        guide:SetClampedToScreen(true)
        guide:EnableMouse(true)
        guide:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        addon.VignetteRadarControls.PopupSurface(guide)
        if type(UISpecialFrames) == "table" then
            UISpecialFrames[#UISpecialFrames + 1] = "VignetteRadarGuidePanel"
        end
        local title = Label(guide, "READING YOUR RADAR", 14, -12, 11, 194)
        guide.title = title
        title:SetTextColor(addon.VignetteRadarStyle.Color("accent"))
        local items = {
            { "boss", "World boss", "boss" },
            { "rare", "Rare", "rare" },
            { "treasure", "Treasure or chest", "treasure" },
            { "quest", "Quest (solid when complete)", "quest" },
            { "note", "Saved map note", "other" },
            { "area", "Shaded area: quest search zone", "quest" },
        }
        guide.symbols = {}
        for index, item in ipairs(items) do
            local symbol = CreateFrame("Frame", nil, guide)
            symbol:SetSize(21, 21)
            symbol:SetPoint("TOPLEFT", guide, "TOPLEFT", 15, -36 - (index - 1) * 23)
            symbol:Show()
            local parts = {}
            local function AddTexture(path, size, dx, dy, opacity)
                local texture = symbol:CreateTexture(nil, "ARTWORK")
                texture:SetSize(size, size)
                texture:SetPoint("CENTER", symbol, "CENTER", dx or 0, dy or 0)
                texture:SetTexture(path)
                parts[#parts + 1] = { texture = texture, opacity = opacity or 1 }
                return texture
            end
            if item[1] == "boss" or item[1] == "rare" then
                AddTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
                    item[1] == "boss" and 18 or 15)
            elseif item[1] == "treasure" then
                local icon = AddTexture("Interface\\Icons\\INV_Misc_Chest_01", 15)
                if icon.SetAtlas then pcall(icon.SetAtlas, icon, "VignetteLoot") end
            elseif item[1] == "quest" then
                AddTexture("Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond-hollow.tga", 14)
            elseif item[1] == "note" then
                AddTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", 11)
                local core = symbol:CreateTexture(nil, "OVERLAY")
                core:SetSize(4, 4)
                core:SetPoint("CENTER")
                core:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
                core:SetVertexColor(.02, .03, .035, 1)
            else
                AddTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", 16, -2, 1, .22)
                AddTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", 12, 3, -2, .18)
            end
            guide.symbols[index] = { frame = symbol, slot = item[3], parts = parts }
            Label(guide, item[2], 43, -39 - (index - 1) * 23, 10, 184)
        end
        Label(guide, "Click a marker to focus. Show All clears it.", 15, -184, 9, 211)
        local close = addon.VignetteRadarControls.Button(guide, "×", 20, 20)
        close:SetPoint("TOPRIGHT", -8, -7)
        close:SetScript("OnClick", function() guide:Hide() end)
        guide:Hide()
    end
    addon.VignetteRadarControls.RefreshPopupSurface(guide)
    guide.title:SetTextColor(addon.VignetteRadarStyle.Color("accent"))
    for _, symbol in ipairs(guide.symbols) do
        local red, green, blue = addon.VignetteRadarStyle.Color(symbol.slot)
        for _, part in ipairs(symbol.parts) do
            part.texture:SetVertexColor(red, green, blue, part.opacity)
        end
    end
    guide:ClearAllPoints()
    if anchorFrame then guide:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 8, 0)
    else guide:SetPoint("CENTER", UIParent, "CENTER") end
    guide:Show()
end

function API.ShowFirstRunGuide(anchorFrame)
    local db = Settings()
    if db.vignetteRadarGuideSeen then return end
    db.vignetteRadarGuideSeen = true
    API.ShowGuide(anchorFrame)
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
    local sourceScale = source:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if left then left = left * sourceScale end
    if right then right = right * sourceScale end
    if top then top = top * sourceScale end
    if bottom then bottom = bottom * sourceScale end
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

function API.OpenPage(name, anchorFrame)
    local frame = Build()
    PositionAt(anchorFrame)
    SelectPage(name or "Radar")
    frame:Show()
    API.Refresh()
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
