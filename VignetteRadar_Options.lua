local _, addon = ...
if type(addon) ~= "table" then return end

local panel, category, closeButton
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
end

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

local function AddCheckbox(parent, key, title, x, y, subkey, labelWidth)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox:SetSize(26, 26)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    label:SetWidth(labelWidth or (496 - x - 31))
    label:SetWordWrap(false)
    label:SetText(title)
    checkbox.label, checkbox.optionKey, checkbox.subkey = label, key, subkey
    checkbox:SetScript("OnClick", function(self)
        local enabled = Checked(self:GetChecked())
        if key == "vignetteRadarEnabled" then
            addon.SetVignetteRadarEnabled(enabled)
        elseif subkey then
            local db = addon.GetSettings()
            if type(db[key]) ~= "table" then db[key] = {} end
            db[key][subkey] = enabled
        else
            addon.GetSettings()[key] = enabled
        end
        Changed()
    end)
    checkboxes[#checkboxes + 1] = checkbox
    return checkbox
end

local function AddButton(parent, title, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(title)
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

    closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    closeButton:SetScript("OnClick", function() panel:Hide() end)
    closeButton:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -22)
    title:SetText("Vignette Radar")

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -11)
    description:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    description:SetJustifyH("LEFT")
    description:SetText("Heading-up positions for active Blizzard minimap vignettes. Hidden locations are never revealed.")

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
        local button = AddButton(panel, name, 24 + (index - 1) * 156, -77, 144, function()
            SelectPage(name)
        end)
        panel.pageButtons[name] = button
        return page
    end

    local radar = AddPage("Radar", 1)
    AddCheckbox(radar, "vignetteRadarEnabled", "Enable radar", 18, -118)
    AddCheckbox(radar, "vignetteRadarHideWhenEmpty", "Hide full radar when there are no detections", 18, -153)
    AddCheckbox(radar, "vignetteRadarLauncherVisible", "Show draggable 150-yard launcher", 18, -188)
    AddLabel(radar, "Full radar range", 24, -236)
    for index, range in ipairs({ 150, 300, 450, 600 }) do
        AddChoice(radar, "vignetteRadarRange", range, range .. " yd", 169 + (index - 1) * 82, -227, 74)
    end
    AddButton(radar, "Preview layout", 24, -281, 133, function()
        addon.ToggleVignetteRadarPreview()
    end)
    AddButton(radar, "Reset positions", 169, -281, 133, function()
        addon.ResetVignetteRadarPositions()
    end)
    AddFooter(radar, "/vr toggles the full panel. Right-click the launcher for a layout preview.")

    local alerts = AddPage("Alerts", 2)
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

    local behavior = AddPage("Behavior", 3)
    AddCheckbox(behavior, "vignetteRadarLastSeen", "Keep last-seen markers", 18, -118, nil, 185)
    AddLabel(behavior, "Keep for", 24, -157)
    AddChoice(behavior, "vignetteRadarLastSeenSeconds", 5, "5 sec", 24, -178, 62)
    AddChoice(behavior, "vignetteRadarLastSeenSeconds", 10, "10 sec", 98, -178, 62)
    AddChoice(behavior, "vignetteRadarLastSeenSeconds", 15, "15 sec", 172, -178, 62)
    AddCheckbox(behavior, "vignetteRadarQuietCombat", "Fade in combat", 18, -224, nil, 185)
    AddCheckbox(behavior, "vignetteRadarQuietInstances", "Fade in instances", 18, -258, nil, 185)

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
    AddFooter(behavior, "Combat and instance fading also mutes alerts. Clear ignores above.")

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
