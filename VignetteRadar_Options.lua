local _, addon = ...
if type(addon) ~= "table" then return end

local panel, category, closeButton
local rangeButtons = {}
local checkboxes = {}

local function Refresh()
    if not panel then return end
    local db = addon.GetSettings()
    for key, checkbox in pairs(checkboxes) do
        checkbox:SetChecked(db[key] == true)
    end
    for range, button in pairs(rangeButtons) do
        if db.vignetteRadarRange == range then button:LockHighlight() else button:UnlockHighlight() end
    end
end

local function AddCheckbox(parent, key, title, y)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y)
    checkbox:SetSize(26, 26)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    label:SetText(title)
    checkbox:SetScript("OnClick", function(self)
        local enabled = self:GetChecked() == true
        if key == "vignetteRadarEnabled" then
            addon.SetVignetteRadarEnabled(enabled)
        else
            addon.GetSettings()[key] = enabled
            addon.VignetteRadarAPI.Refresh(true)
        end
        Refresh()
    end)
    checkboxes[key] = checkbox
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

local function BuildPanel()
    if panel then return panel end
    panel = CreateFrame("Frame", "VignetteRadarOptionsPanel", UIParent)
    panel.name = "Vignette Radar"
    panel:SetSize(520, 365)
    panel:Hide()
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

    AddCheckbox(panel, "vignetteRadarEnabled", "Enable radar", -91)
    AddCheckbox(panel, "vignetteRadarHideWhenEmpty", "Hide full radar when there are no detections", -132)
    AddCheckbox(panel, "vignetteRadarLauncherVisible", "Show draggable 150-yard launcher", -173)

    local rangeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rangeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -225)
    rangeLabel:SetText("Full radar range")
    for index, range in ipairs({ 150, 300, 450, 600 }) do
        rangeButtons[range] = AddButton(panel, range .. " yd", 169 + (index - 1) * 82, -216, 74, function()
            addon.GetSettings().vignetteRadarRange = range
            addon.VignetteRadarAPI.Refresh(true)
            Refresh()
        end)
    end

    AddButton(panel, "Preview layout", 24, -274, 133, function()
        addon.ToggleVignetteRadarPreview()
    end)
    AddButton(panel, "Reset positions", 169, -274, 133, function()
        addon.ResetVignetteRadarPositions()
    end)

    local footer = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -322)
    footer:SetText("/vr toggles the full panel. Right-click the launcher for a layout preview.")

    panel:SetScript("OnShow", Refresh)
    return panel
end

function addon.OpenOptions()
    if not panel then BuildPanel() end
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    else
        closeButton:Show()
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
