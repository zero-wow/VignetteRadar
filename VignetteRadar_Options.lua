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
end

addon.RefreshVignetteRadarOptions = Refresh

local function Changed()
    addon.VignetteRadarAPI.Refresh(true)
    Refresh()
end

local function AddLabel(parent, title, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(title)
    return label
end

local function AddDescription(parent, title, x, y, width)
    local label = AddLabel(parent, title, x, y)
    label:SetWidth(width)
    label:SetWordWrap(true)
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
    checkbox:RefreshAppearance()
    checkbox:SetScript("OnClick", function(self)
        local enabled = Checked(self:GetChecked())
        if key == "vignetteRadarEnabled" then
            addon.SetVignetteRadarEnabled(enabled)
        elseif key == "vignetteRadarCircleOnly" then
            addon.SetVignetteRadarCircleOnly(enabled)
        elseif key == "vignetteRadarKeepVisibleCombat" then
            addon.SetVignetteRadarKeepVisibleCombat(enabled)
        elseif subkey then
            local db = addon.GetSettings()
            if type(db[key]) ~= "table" then db[key] = {} end
            db[key][subkey] = enabled
        else
            addon.GetSettings()[key] = enabled
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
    local button = addon.VignetteRadarControls.Button(parent, title, width, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetScript("OnClick", callback)
    return button
end

local function AddChoice(parent, key, value, title, x, y, width)
    local button = AddButton(parent, title, x, y, width, function()
        addon.GetSettings()[key] = value
        Changed()
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
                Changed()
            end
            return
        end
    end
end

local function AddFooter(parent, title)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -326)
    label:SetText(title)
    return label
end

local function BuildPanel()
    if panel then return panel end
    panel = CreateFrame("Frame", "VignetteRadarOptionsPanel", UIParent)
    panel.name = "Vignette Radar"
    panel:SetSize(520, 365)
    panel:Hide()
    panel.pages, panel.pageButtons = {}, {}

    closeButton = addon.VignetteRadarControls.Button(panel, "×", 24, 24)
    closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    closeButton:SetScript("OnClick", function() panel:Hide() end)
    closeButton:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -22)
    title:SetText("Vignette Radar")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -11)
    description:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    description:SetJustifyH("LEFT")
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
        local button = AddButton(panel, name, 18 + (index - 1) * 96, -77, 90, function()
            SelectPage(name)
        end)
        panel.pageButtons[name] = button
        return page
    end

    local radar = AddPage("Radar", 1)
    AddCheckbox(radar, "vignetteRadarEnabled", "Enable radar", 18, -114)
    AddCheckbox(radar, "vignetteRadarHideWhenEmpty", "Hide full radar when there are no detections", 18, -146)
    AddCheckbox(radar, "vignetteRadarLauncherVisible", "Show draggable 150-yard launcher", 18, -178)
    AddCheckbox(radar, "vignetteRadarWorldMap", "Include world-map detections", 18, -210)
    AddLabel(radar, "Full radar range", 24, -251)
    previousRange = AddButton(radar, "-", 169, -247, 48, function() StepRange(-1) end)
    rangeValue = radar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rangeValue:SetPoint("TOPLEFT", radar, "TOPLEFT", 229, -251)
    rangeValue:SetWidth(118)
    rangeValue:SetJustifyH("CENTER")
    nextRange = AddButton(radar, "+", 359, -247, 48, function() StepRange(1) end)
    AddButton(radar, "Preview layout", 24, -283, 133, function()
        addon.ToggleVignetteRadarPreview()
    end)
    AddButton(radar, "Reset positions", 169, -283, 133, function()
        addon.ResetVignetteRadarPositions()
    end)
    AddFooter(radar, "/vr toggles the full panel. Right-click the launcher for a layout preview.")

    local layout = AddPage("Layout", 2)
    AddLabel(layout, "Choose the panel arrangement that fits your screen.", 24, -118)
    AddLayoutChoice(layout, "classic", "Classic", 24, -148, 144)
    AddLayoutChoice(layout, "squat", "Squat", 188, -148, 144)
    AddLayoutChoice(layout, "compact", "Compact", 352, -148, 144)
    AddDescription(layout, "Current portrait radar with details below.", 24, -181, 144)
    AddDescription(layout, "Wide and short: radar left, details right, buttons below.", 188, -181, 144)
    AddDescription(layout, "Smaller radar with range and controls below.", 352, -181, 144)
    AddCheckbox(layout, "vignetteRadarNorthUp", "Keep north at the top", 18, -229, nil, nil, true)
    AddCheckbox(layout, "vignetteRadarCircleOnly", "Radar-only view", 18, -264, nil, 185, true)
    AddButton(layout, "Preview layout", 264, -264, 144, function()
        addon.ToggleVignetteRadarPreview()
    end)
    AddFooter(layout, "Drag the radar's edges or corners to resize it. Your size is saved.")

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
    AddCheckbox(behavior, "vignetteRadarKeepVisibleCombat", "Stay visible in combat", 18, -249, nil, 185, true)
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
    AddFooter(behavior, "Combat visibility and alert muting are separate. Clear ignores.")

    local quests = AddPage("Quests", 5)
    AddLabel(quests, "QUEST LOCATIONS", 24, -119)
    AddCheckbox(quests, "vignetteRadarQuestDots", "Show quest location dots", 18, -145)
    AddDescription(quests, "Small gold dots mark quest positions supplied by the game. They turn with the radar in facing-up mode.", 49, -176, 435)
    AddLabel(quests, "QUEST AREAS", 24, -236)
    AddCheckbox(quests, "vignetteRadarQuestAreas", "Shade Blizzard quest areas", 18, -262)
    AddDescription(quests, "A square radar contains quest areas behind markers. Exact shapes require north-up.", 49, -292, 435)
    AddFooter(quests, "Quest areas require north-up. Use the N button to switch.")

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
