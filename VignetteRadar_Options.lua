local _, addon = ...
if type(addon) ~= "table" then return end

local panel, category, closeButton, rangeValue, previousRange, nextRange
local checkboxes, choiceGroups = {}, {}

local function Checked(value)
    return value == true or value == 1
end

local function Refresh()
    if not panel then return end
    local db = addon.GetSettings()
    for _, checkbox in ipairs(checkboxes) do
        local value = db[checkbox.optionKey]
        if checkbox.subkey then
            value = type(value) == "table" and value[checkbox.subkey]
        end
        checkbox:SetChecked(Checked(value))
    end
    for key, buttons in pairs(choiceGroups) do
        for value, button in pairs(buttons) do
            if db[key] == value then button:LockHighlight() else button:UnlockHighlight() end
        end
    end
    if rangeValue then
        rangeValue:SetText(db.vignetteRadarRange .. " yd")
        local ranges = addon.VignetteRadarRanges
        previousRange:SetEnabled(db.vignetteRadarRange ~= ranges[1])
        nextRange:SetEnabled(db.vignetteRadarRange ~= ranges[#ranges])
    end
    local style = addon.VignetteRadarStyle
    if style then
        local ar, ag, ab = style.Color("accent")
        local br, bg, bb = style.Color("background")
        panel:SetBackdropColor(math.min(.14, br * 2.7), math.min(.14, bg * 2.7),
            math.min(.14, bb * 2.7), .99)
        addon.VignetteRadarControls.RefreshPopupSurface(panel)
        panel.headerLine:SetColorTexture(ar, ag, ab, .24)
        panel.tabLine:SetColorTexture(ar, ag, ab, .16)
        panel.title:SetTextColor(ar, ag, ab, 1)
        addon.VignetteRadarControls.RefreshTheme()
    end
end

addon.RefreshVignetteRadarOptions = Refresh

local function Changed()
    addon.VignetteRadarAPI.Refresh(true)
    Refresh()
end

local function AddLabel(parent, title, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
    label:SetTextColor(.68, .87, .81, 1)
    label:SetText(title)
    return label
end

local function AddDescription(parent, title, x, y, width)
    local label = AddLabel(parent, title, x, y)
    label:SetWidth(width)
    label:SetWordWrap(true)
    label:SetTextColor(.65, .73, .73, 1)
    return label
end

local function AddCheckbox(parent, key, title, x, y, subkey, labelWidth, presentationOnly)
    local checkbox = addon.VignetteRadarControls.Checkbox(parent)
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    label:SetWidth(labelWidth or (496 - x - 31))
    label:SetWordWrap(false)
    label:SetText(title)
    checkbox.label, checkbox.optionKey, checkbox.subkey = label, key, subkey
    if key == "vignetteRadarNorthUp" then checkbox:SetGlyph("N")
    elseif key == "vignetteRadarKeepVisibleCombat" then checkbox:SetGlyph("eye") end
    checkbox:RefreshAppearance()
    checkbox:SetScript("OnClick", function(self)
        local enabled = Checked(self:GetChecked())
        if key == "vignetteRadarEnabled" then
            addon.SetVignetteRadarEnabled(enabled)
        elseif key == "vignetteRadarCircleOnly" then
            addon.SetVignetteRadarCircleOnly(enabled)
        elseif key == "vignetteRadarKeepVisibleCombat" then
            addon.SetVignetteRadarKeepVisibleCombat(enabled)
        elseif key == "vignetteRadarBreadcrumbs" and type(addon.SetVignetteRadarTrailEnabled) == "function" then
            addon.SetVignetteRadarTrailEnabled(enabled)
        elseif subkey then
            local db = addon.GetSettings()
            if type(db[key]) ~= "table" then db[key] = {} end
            db[key][subkey] = enabled
        else
            addon.GetSettings()[key] = enabled
        end
        if addon.VignetteRadarViewProfiles and ((key == "vignetteRadarIndependentViews" and enabled)
            or key == "vignetteRadarHoverTools" or key == "vignetteRadarControlsVisible") then
            addon.VignetteRadarViewProfiles.Record(addon.GetSettings())
        end
        if presentationOnly and type(addon.RefreshVignetteRadar) == "function" then
            addon.RefreshVignetteRadar(false)
            Refresh()
        else
            Changed()
        end
    end)
    checkboxes[#checkboxes + 1] = checkbox
    return checkbox
end

local function AddButton(parent, title, x, y, width, callback)
    local controls = addon.VignetteRadarControls
    local button = (title == "+" or title == "-" or title == "−")
        and controls.IconButton(parent, title, width, 24) or controls.Button(parent, title, width, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetScript("OnClick", callback)
    return button
end

local function AddChoice(parent, key, value, title, x, y, width)
    local button = AddButton(parent, title, x, y, width, function()
        if key == "vignetteRadarTrailStyle" and type(addon.SetVignetteRadarTrailStyle) == "function" then
            addon.SetVignetteRadarTrailStyle(value)
        else
            addon.GetSettings()[key] = value
            Changed()
        end
    end)
    if not choiceGroups[key] then choiceGroups[key] = {} end
    choiceGroups[key][value] = button
    return button
end

local function AddLayoutChoice(parent, value, title, x, y, width)
    local button = AddButton(parent, title, x, y, width, function()
        addon.GetSettings().vignetteRadarLayout = value
        if type(addon.RefreshVignetteRadar) == "function" then
            addon.RefreshVignetteRadar(false)
            Refresh()
        else
            Changed()
        end
    end)
    if not choiceGroups.vignetteRadarLayout then choiceGroups.vignetteRadarLayout = {} end
    choiceGroups.vignetteRadarLayout[value] = button
    return button
end

local function StepRange(direction)
    local db = addon.GetSettings()
    local ranges = addon.VignetteRadarRanges
    for index, range in ipairs(ranges) do
        if db.vignetteRadarRange == range then
            local nextRangeValue = ranges[index + direction]
            if nextRangeValue then
                db.vignetteRadarRange = nextRangeValue
                if addon.VignetteRadarViewProfiles then addon.VignetteRadarViewProfiles.Record(db) end
                Changed()
            end
            return
        end
    end
end

local function AddFooter(parent, title)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -326)
    label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "")
    label:SetTextColor(.51, .63, .62, 1)
    label:SetText(title)
    return label
end

local function BuildPanel()
    if panel then return panel end
    panel = CreateFrame("Frame", "VignetteRadarOptionsPanel", UIParent, "BackdropTemplate")
    panel.name = "Vignette Radar"
    panel:SetSize(520, 365)
    panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    addon.VignetteRadarControls.PopupSurface(panel)
    panel:SetBackdropColor(.035, .043, .049, .99)
    panel:SetBackdropBorderColor(1, 1, 1, .22)
    panel:Hide()
    panel.pages, panel.pageButtons = {}, {}

    panel.headerLine = panel:CreateTexture(nil, "ARTWORK")
    panel.headerLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -65)
    panel.headerLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -65)
    panel.headerLine:SetHeight(1)
    panel.tabLine = panel:CreateTexture(nil, "ARTWORK")
    panel.tabLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -105)
    panel.tabLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -105)
    panel.tabLine:SetHeight(1)

    closeButton = addon.VignetteRadarControls.Button(panel, "×", 24, 24)
    closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    closeButton:SetScript("OnClick", function() panel:Hide() end)
    closeButton:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -22)
    title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
    title:SetText("VIGNETTE RADAR")
    panel.title = title

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -11)
    description:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    description:SetJustifyH("LEFT")
    description:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "")
    description:SetTextColor(.68, .77, .76, 1)
    description:SetText("Heading-up positions for Blizzard vignette detections. Hidden locations are never revealed.")

    local function SelectPage(name)
        for pageName, otherPage in pairs(panel.pages) do
            if pageName == name then otherPage:Show() else otherPage:Hide() end
        end
        panel.selectedPage = name
        for pageName, otherButton in pairs(panel.pageButtons) do
            if pageName == name then otherButton:LockHighlight() else otherButton:UnlockHighlight() end
        end
        Refresh()
    end

    local function AddPage(name, index)
        local page = CreateFrame("Frame", nil, panel)
        page:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
        page:SetSize(520, 365)
        page:Hide()
        panel.pages[name] = page
        local button = AddButton(panel, name, 10 + (index - 1) * 84, -77, 80, function()
            SelectPage(name)
        end)
        panel.pageButtons[name] = button
        return page
    end

    local radar = AddPage("Radar", 1)
    AddCheckbox(radar, "vignetteRadarEnabled", "Enable radar", 18, -114, nil, 185)
    AddCheckbox(radar, "vignetteRadarHideCleared", "Hide cleared targets", 258, -114, nil, 205)
    AddCheckbox(radar, "vignetteRadarHideWhenEmpty", "Hide full radar when there are no detections", 18, -146)
    AddCheckbox(radar, "vignetteRadarLauncherVisible", "Show draggable 150-yard launcher", 18, -178)
    AddCheckbox(radar, "vignetteRadarWorldMap", "Include world-map detections", 18, -210)
    AddCheckbox(radar, "vignetteRadarEmptyHelp", "Explain an empty radar", 258, -210, nil, 205)
    AddLabel(radar, "Full radar range", 24, -251)
    previousRange = AddButton(radar, "-", 169, -247, 48, function() StepRange(-1) end)
    rangeValue = radar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rangeValue:SetPoint("TOPLEFT", radar, "TOPLEFT", 229, -251)
    rangeValue:SetWidth(118)
    rangeValue:SetJustifyH("CENTER")
    nextRange = AddButton(radar, "+", 359, -247, 48, function() StepRange(1) end)
    AddButton(radar, "Preview", 24, -283, 109, function()
        addon.ToggleVignetteRadarPreview()
    end)
    AddButton(radar, "Reset", 145, -283, 109, function()
        addon.ResetVignetteRadarPositions()
    end)
    AddButton(radar, "Explore", 266, -283, 109, function()
        if addon.VignetteRadarExploration then addon.VignetteRadarExploration.TogglePanel() end
    end)
    AddButton(radar, "Map data", 387, -283, 109, function()
        local quick = addon.VignetteRadarQuickConfig
        if quick and quick.OpenPage then quick.OpenPage("Map Data") end
    end)
    AddFooter(radar, "Stay fully visible (Behavior) overrides auto-hide.")

    local layout = AddPage("Layout", 2)
    AddLabel(layout, "Choose the panel arrangement that fits your screen.", 24, -118)
    AddLayoutChoice(layout, "classic", "Classic", 24, -148, 144)
    AddLayoutChoice(layout, "squat", "Squat", 188, -148, 144)
    AddLayoutChoice(layout, "compact", "Compact", 352, -148, 144)
    AddDescription(layout, "Current portrait radar with details below.", 24, -181, 144)
    AddDescription(layout, "Wide and short: radar left, details right, buttons below.", 188, -181, 144)
    AddDescription(layout, "Smaller radar with range and controls below.", 352, -181, 144)
    AddCheckbox(layout, "vignetteRadarNorthUp", "Keep north at the top", 18, -229, nil, nil, true)
    AddCheckbox(layout, "vignetteRadarHoverTools", "Hover tools in square view", 258, -229, nil, 205)
    AddCheckbox(layout, "vignetteRadarCircleOnly", "Radar-only view", 18, -264, nil, 185, true)
    AddCheckbox(layout, "vignetteRadarPeekEnabled", "Hold-key full radar peek", 258, -264, nil, 205)
    AddCheckbox(layout, "vignetteRadarIndependentViews", "Save zoom and size per view", 18, -296, nil, 250)
    AddCheckbox(layout, "vignetteRadarControlsVisible", "Show full-view buttons", 258, -296, nil, 205)
    local layoutFooter = AddFooter(layout, "Drag the radar's edges or corners to resize it.")
    layoutFooter:ClearAllPoints()
    layoutFooter:SetPoint("TOPLEFT", layout, "TOPLEFT", 24, -339)

    local alerts = AddPage("Alerts", 3)
    AddCheckbox(alerts, "vignetteRadarAlerts", "Pulse for newly seen vignettes", 18, -118)
    AddCheckbox(alerts, "vignetteRadarAlertSound", "Play an alert sound", 18, -153)
    AddLabel(alerts, "Alert categories", 24, -193)
    AddCheckbox(alerts, "vignetteRadarAlertCategories", "Rares and bosses", 18, -216, "rare", 185)
    AddCheckbox(alerts, "vignetteRadarAlertCategories", "Treasures", 250, -216, "treasure", 210)
    AddCheckbox(alerts, "vignetteRadarAlertCategories", "Events", 18, -249, "event", 185)
    AddCheckbox(alerts, "vignetteRadarAlertCategories", "Other", 250, -249, "other", 210)
    AddLabel(alerts, "Repeat alert after", 24, -286)
    AddChoice(alerts, "vignetteRadarAlertCooldown", 30, "30 sec", 242, -278, 68)
    AddChoice(alerts, "vignetteRadarAlertCooldown", 60, "60 sec", 322, -278, 68)
    AddChoice(alerts, "vignetteRadarAlertCooldown", 120, "120 sec", 402, -278, 68)
    AddFooter(alerts, "Alerts apply to newly detected, enabled categories.")

    local behavior = AddPage("Behavior", 4)
    AddCheckbox(behavior, "vignetteRadarLastSeen", "Keep last-seen markers", 18, -118, nil, 185)
    AddLabel(behavior, "Keep for", 24, -157)
    AddChoice(behavior, "vignetteRadarLastSeenSeconds", 5, "5 sec", 24, -178, 62)
    AddChoice(behavior, "vignetteRadarLastSeenSeconds", 10, "10 sec", 98, -178, 62)
    AddChoice(behavior, "vignetteRadarLastSeenSeconds", 15, "15 sec", 172, -178, 62)
    AddCheckbox(behavior, "vignetteRadarQuietCombat", "Mute alerts in combat", 18, -214, nil, 185)
    AddCheckbox(behavior, "vignetteRadarKeepVisibleCombat", "Stay fully visible", 18, -249, nil, 185, true)
    AddCheckbox(behavior, "vignetteRadarQuietInstances", "Fade + mute in instances", 18, -284, nil, 185)

    AddLabel(behavior, "Marker size", 264, -122)
    AddChoice(behavior, "vignetteRadarMarkerSize", 5, "Small", 264, -145, 68)
    AddChoice(behavior, "vignetteRadarMarkerSize", 7, "Medium", 344, -145, 68)
    AddChoice(behavior, "vignetteRadarMarkerSize", 9, "Large", 424, -145, 68)
    AddCheckbox(behavior, "vignetteRadarShapes", "Recognizable icons", 258, -191, nil, 203)
    AddCheckbox(behavior, "vignetteRadarShowHealth", "Focused rare health", 258, -225, nil, 203)
    AddButton(behavior, "Clear ignored vignettes", 264, -278, 204, function()
        local features = addon.VignetteRadarFeatures
        if features and type(features.ClearIgnored) == "function" then
            features.ClearIgnored()
            Changed()
        end
    end)
    AddFooter(behavior, "Stay fully visible overrides fading; alerts can stay muted.")

    local quests = AddPage("Quests", 5)
    AddLabel(quests, "QUEST LOCATIONS", 24, -119)
    AddCheckbox(quests, "vignetteRadarQuestDots", "Show quest diamonds", 18, -145, nil, 203)
    AddCheckbox(quests, "vignetteRadarFollowTrackedQuest", "Outline tracked quest", 258, -145, nil, 205)
    AddDescription(quests, "Quest diamonds turn with the radar.", 49, -179, 185)
    AddCheckbox(quests, "vignetteRadarQuestColors", "Color quest diamonds", 258, -177, nil, 205)
    AddLabel(quests, "QUEST AREAS", 24, -205)
    AddCheckbox(quests, "vignetteRadarQuestAreas", "Shade Blizzard quest areas", 18, -222, nil, 203)
    AddCheckbox(quests, "vignetteRadarEdgeCues", "Show off-range cues", 258, -222, nil, 205)
    AddCheckbox(quests, "vignetteRadarQuestHalos", "Approximate quest circles", 18, -253, nil, 203)
    AddLabel(quests, "Radius", 264, -251)
    AddChoice(quests, "vignetteRadarQuestHaloRadius", 10, "10", 308, -250, 39)
    AddChoice(quests, "vignetteRadarQuestHaloRadius", 20, "20", 356, -250, 39)
    AddChoice(quests, "vignetteRadarQuestHaloRadius", 40, "40", 404, -250, 39)
    AddChoice(quests, "vignetteRadarQuestHaloRadius", 80, "80", 452, -250, 39)
    AddCheckbox(quests, "vignetteRadarQuestAreaColors", "Match areas to diamond colors", 258, -282, nil, 205)
    AddCheckbox(quests, "vignetteRadarQuestKeyProgress", "Progress in quest key", 18, -282, nil, 203)
    AddButton(quests, "Toggle quest key", 18, -313, 203, function()
        if addon.VignetteRadarAPI and addon.VignetteRadarAPI.ToggleQuestKey then
            addon.VignetteRadarAPI.ToggleQuestKey()
        end
    end)
    AddButton(quests, "Wayfinding options", 258, -313, 203, function()
        if addon.VignetteRadarQuickConfig and addon.VignetteRadarQuickConfig.OpenPage then
            addon.VignetteRadarQuickConfig.OpenPage("Wayfinding")
        end
    end)
    local questFooter = AddFooter(quests, "Exact blobs need north-up; estimated circles stay behind markers.")
    questFooter:ClearAllPoints()
    questFooter:SetPoint("TOPLEFT", quests, "TOPLEFT", 24, -345)

    local explore = AddPage("Explore", 6)
    AddCheckbox(explore, "vignetteRadarSmartZoom", "Smart zoom", 18, -115, nil, 170)
    AddCheckbox(explore, "vignetteRadarUntangle", "Spread overlapping markers", 250, -115, nil, 210)
    AddCheckbox(explore, "vignetteRadarBreadcrumbs", "Travel trail", 18, -148, nil, 170)
    AddCheckbox(explore, "vignetteRadarApproachAlerts", "Approach alerts", 250, -148, nil, 210)
    AddCheckbox(explore, "vignetteRadarJournalEnabled", "Save sighting history", 18, -181, nil, 170)
    AddLabel(explore, "Trail", 250, -183)
    local trailPickerButton = AddButton(explore, "Styles & flow", 320, -177, 176, function(self)
        addon.ToggleVignetteRadarTrailPicker(self)
    end)
    AddLabel(explore, "Approach distance", 24, -218)
    AddChoice(explore, "vignetteRadarApproachDistance", 50, "50 yd", 178, -211, 70)
    AddChoice(explore, "vignetteRadarApproachDistance", 100, "100 yd", 258, -211, 70)
    AddChoice(explore, "vignetteRadarApproachDistance", 200, "200 yd", 338, -211, 70)
    AddChoice(explore, "vignetteRadarApproachDistance", 400, "400 yd", 418, -211, 70)
    AddLabel(explore, "Hunting presets", 24, -257)
    for index, name in ipairs({ "Treasure", "Rare", "Questing", "Exploring" }) do
        AddButton(explore, name, 147 + (index - 1) * 87, -252, 80, function()
            addon.VignetteRadarExploration.ApplyPreset(name)
            Refresh()
        end)
    end
    AddButton(explore, "Saved presets, pins & journal", 24, -286, 230, function()
        addon.VignetteRadarExploration.TogglePanel()
    end)
    AddButton(explore, "World beacons", 266, -286, 230, function()
        local quick = addon.VignetteRadarQuickConfig
        if quick and quick.OpenPage then quick.OpenPage("Beacons") end
    end)
    AddFooter(explore, "Ctrl-click a detection for a route stop; Ctrl-Alt-click to watch it.")

    SelectPage("Radar")
    panel:SetScript("OnShow", Refresh)
    return panel
end

function addon.OpenOptions()
    if not panel then BuildPanel() end
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    else
        closeButton:Show()
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER")
        panel:SetFrameStrata("DIALOG")
        panel:Show()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    BuildPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, registered = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
        if ok and registered then
            category = registered
            Settings.RegisterAddOnCategory(category)
        end
    end
end)
