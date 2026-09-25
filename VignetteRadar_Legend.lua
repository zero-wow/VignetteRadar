local _, addon = ...
if type(addon) ~= "table" then return end

local PANEL_W, PANEL_H = 232, 370
local QUEST_PANEL_W, QUEST_VISIBLE_ROWS = 224, 8
local QUEST_ROW_H, QUEST_ROW_STEP = 22, 26
local QUEST_DIAMOND_TEXTURE = "Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond.tga"
local QUEST_HOLLOW_DIAMOND_TEXTURE = "Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond-hollow.tga"
local QUEST_HOLLOW_SIZE = 13 * 26 / 30
local ACCENT = { 0.05, 0.82, 0.62 }
local FONT_FALLBACK = "Fonts\\FRIZQT__.TTF"
local SKULL_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local CIRCLE_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local CATEGORY_ORDER = { "rare", "treasure", "event", "other" }
local CATEGORIES = {
    rare = { label = "RARE / BOSS", color = { 0.78, 0.88, 1.00 } },
    treasure = { label = "TREASURE", color = { 1.00, 0.68, 0.16 } },
    event = { label = "EVENTS", color = { 0.67, 0.42, 1.00 } },
    other = { label = "OTHER", color = { 0.66, 0.72, 0.76 } },
}
local MAP_NOTES = {
    { kind = "treasure", label = "Treasure", color = "treasure" },
    { kind = "mob", label = "Mob", color = "rare" },
    { kind = "item", label = "Item", color = "event" },
    { kind = "note", label = "Other note", color = "other" },
}
local TRAIL_STYLES = addon.VignetteRadarTrailStyleByID or {
    dashes = { label="Dashes", segments={{-3.5,0,3.5,0,2.5}} },
    ticks = { label="Ticks", segments={{0,-3.5,0,3.5,2}} },
    dots = { label="Dots", dot=5 },
}

local fallbackSettings = {}
local panel
local attachedTo
local questPanel, questAttachedTo, questEntries = nil, nil, {}
local questOffset = 0
local changeCallback

local API = {}
addon.VignetteRadarLegend = API

local function Settings()
    if type(addon.GetSettings) == "function" then
        local ok, settings = pcall(addon.GetSettings)
        if ok and type(settings) == "table" then return settings end
    end
    return fallbackSettings
end

local function CategoryKey(category)
    if type(category) == "string" then
        category = category:lower()
        if CATEGORIES[category] then return category end
    end
    return "other"
end

function API.ApplyDefaults(settings)
    settings = type(settings) == "table" and settings or Settings()
    if type(settings.vignetteRadarCategories) ~= "table" then
        settings.vignetteRadarCategories = {}
    end
    local enabled = settings.vignetteRadarCategories
    for _, category in ipairs(CATEGORY_ORDER) do
        if type(enabled[category]) ~= "boolean" then enabled[category] = true end
    end
    local highlight = settings.vignetteRadarHighlight
    if type(highlight) ~= "string" then
        settings.vignetteRadarHighlight = nil
    else
        highlight = highlight:lower()
        if not CATEGORIES[highlight] or enabled[highlight] ~= true then
            settings.vignetteRadarHighlight = nil
        else
            settings.vignetteRadarHighlight = highlight
        end
    end
    return settings
end

function API.IsCategoryEnabled(category)
    local settings = API.ApplyDefaults()
    return settings.vignetteRadarCategories[CategoryKey(category)] == true
end

function API.GetHighlight()
    return API.ApplyDefaults().vignetteRadarHighlight
end

function API.ColorFor(category)
    if addon.VignetteRadarStyle then return addon.VignetteRadarStyle.Color(CategoryKey(category)) end
    local color = CATEGORIES[CategoryKey(category)].color
    return color[1], color[2], color[3]
end

-- A disabled category is hidden. Enabled categories outside the spotlight remain
-- visible enough to preserve spatial context without competing with the focus.
function API.OpacityFor(category)
    category = CategoryKey(category)
    if not API.IsCategoryEnabled(category) then return 0 end
    local highlight = API.GetHighlight()
    if highlight and highlight ~= category then return 0.18 end
    return 1
end

function API.DotStyle(category)
    category = CategoryKey(category)
    local red, green, blue = API.ColorFor(category)
    return API.IsCategoryEnabled(category), red, green, blue, API.OpacityFor(category), category
end

local function FontPath()
    return EllesmereUI and (EllesmereUI.EXPRESSWAY or EllesmereUI._font)
        or STANDARD_TEXT_FONT or FONT_FALLBACK
end

local function Text(parent, size, value)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(FontPath(), size, "")
    label:SetText(value or "")
    label:SetTextColor(0.88, 0.90, 0.92, 1)
    label:SetJustifyH("LEFT")
    if label.SetWordWrap then label:SetWordWrap(false) end
    return label
end

local function Surface(frame, red, green, blue, alpha, borderAlpha)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(red or 0.045, green or 0.052, blue or 0.06, alpha or 0.98)
    frame:SetBackdropBorderColor(1, 1, 1, borderAlpha or 0.13)
end

local function Tooltip(owner, title, body)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    GameTooltip:AddLine(body, 0.65, 0.76, 0.74, true)
    GameTooltip:Show()
end

local function AddPressState(button)
    button.press = button:CreateTexture(nil, "OVERLAY")
    button.press:SetAllPoints()
    button.press:SetColorTexture(1, 1, 1, 0.055)
    button.press:Hide()
    button:SetScript("OnMouseDown", function(self) self.press:Show() end)
    button:SetScript("OnMouseUp", function(self) self.press:Hide() end)
    button:SetScript("OnHide", function(self) self.press:Hide() end)
end

local function NotifyChanged()
    API.Refresh()
    if type(changeCallback) == "function" then
        pcall(changeCallback)
    elseif type(addon.RefreshVignetteRadar) == "function" then
        addon.RefreshVignetteRadar()
    end
end

function API.SetChangeCallback(callback)
    changeCallback = type(callback) == "function" and callback or nil
end

function API.SetCategoryEnabled(category, enabled)
    category = CategoryKey(category)
    local settings = API.ApplyDefaults()
    enabled = enabled == true
    if settings.vignetteRadarCategories[category] == enabled then return false end
    settings.vignetteRadarCategories[category] = enabled
    if not enabled and settings.vignetteRadarHighlight == category then
        settings.vignetteRadarHighlight = nil
    end
    NotifyChanged()
    return true
end

function API.SetHighlight(category)
    local settings = API.ApplyDefaults()
    if category == nil or category == "all" then
        category = nil
    else
        category = CategoryKey(category)
        settings.vignetteRadarCategories[category] = true
    end
    if settings.vignetteRadarHighlight == category then return false end
    settings.vignetteRadarHighlight = category
    NotifyChanged()
    return true
end

local function CreateCategoryRow(parent, category, index)
    local definition = CATEGORIES[category]
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(PANEL_W - 18, 23)
    row:SetPoint("TOPLEFT", 9, -39 - ((index - 1) * 27))
    Surface(row, 0.065, 0.073, 0.082, 0.98, 0.10)
    row.category = category

    row.selection = row:CreateTexture(nil, "BACKGROUND")
    row.selection:SetPoint("TOPLEFT", 1, -1)
    row.selection:SetPoint("BOTTOMRIGHT", -1, 1)
    row.selection:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.09)
    row.selection:Hide()

    row.hover = row:CreateTexture(nil, "ARTWORK")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(1, 1, 1, 0.035)
    row.hover:Hide()

    row.swatchGlow = row:CreateTexture(nil, "ARTWORK")
    row.swatchGlow:SetSize(13, 13)
    row.swatchGlow:SetPoint("LEFT", 8, 0)
    row.swatchGlow:SetColorTexture(definition.color[1], definition.color[2], definition.color[3], 0.14)
    row.swatch = row:CreateTexture(nil, "OVERLAY")
    row.swatch:SetSize(7, 7)
    row.swatch:SetPoint("CENTER", row.swatchGlow, "CENTER")
    row.swatch:SetTexture(CIRCLE_TEXTURE)
    row.swatch:SetVertexColor(definition.color[1], definition.color[2], definition.color[3], 1)
    if category == "rare" then
        row.swatch:SetSize(13, 13)
        row.swatch:SetTexture(SKULL_TEXTURE)
        row.swatch:SetVertexColor(definition.color[1], definition.color[2], definition.color[3], 1)
        row.bossSwatch = row:CreateTexture(nil, "OVERLAY")
        row.bossSwatch:SetSize(13, 13)
        row.bossSwatch:SetPoint("LEFT", 21, 0)
        row.bossSwatch:SetTexture(SKULL_TEXTURE)
        row.bossSwatch:SetVertexColor(1, 0.18, 0.12, 1)
    elseif category == "treasure" and row.swatch.SetAtlas then
        row.swatch:SetSize(13, 13)
        row.swatch:SetAtlas("VignetteLoot")
        row.swatch:SetVertexColor(definition.color[1], definition.color[2], definition.color[3], 1)
    end

    row.label = Text(row, 10, definition.label)
    row.label:SetPoint("LEFT", category == "rare" and 39 or 29, 0)
    row.label:SetWidth(category == "rare" and 98 or 108)
    if row.label.SetMaxLines then row.label:SetMaxLines(1) end

    row.toggle = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.toggle:SetSize(42, 17)
    row.toggle:SetPoint("RIGHT", -4, 0)
    Surface(row.toggle, 0.025, 0.03, 0.035, 0.95, 0.14)
    row.toggle.label = Text(row.toggle, 8, "ON")
    row.toggle.label:SetAllPoints()
    row.toggle.label:SetJustifyH("CENTER")
    AddPressState(row)
    AddPressState(row.toggle)

    row:SetScript("OnClick", function()
        if API.GetHighlight() == category then API.SetHighlight(nil) else API.SetHighlight(category) end
    end)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        Tooltip(self, definition.label:sub(1, 1) .. definition.label:sub(2):lower(), category == "rare"
            and "Silver skull: rare enemy. Red skull: world boss. Both use this filter. Click to spotlight."
            or "Click the row to spotlight this type. Other enabled dots stay visible but dim.")
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        if GameTooltip then GameTooltip:Hide() end
    end)
    row.toggle:SetScript("OnClick", function()
        API.SetCategoryEnabled(category, not API.IsCategoryEnabled(category))
    end)
    row.toggle:SetScript("OnEnter", function(self)
        Tooltip(self, "Filter " .. definition.label:sub(1, 1) .. definition.label:sub(2):lower(),
            category == "rare" and "Silver skull: rare enemy. Red skull: world boss. Both use this filter."
            or "Turn this category on or off on the radar.")
    end)
    row.toggle:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return row
end

local function GuideLabel(parent, value, x, y, width, size)
    local label = Text(parent, size or 9, value)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    label:SetSize(width, 16)
    if label.SetMaxLines then label:SetMaxLines(1) end
    return label
end

local function SectionRule(parent, y)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -y)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -y)
    line:SetHeight(1)
    line:SetColorTexture(1, 1, 1, .08)
    return line
end

local function GuideRow(parent, label, x, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(103, 18)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    row.label = GuideLabel(row, label, 20, 1, 82, 9)
    return row
end

local function Circle(parent, size, layer)
    local dot = parent:CreateTexture(nil, layer or "ARTWORK")
    dot:SetSize(size, size)
    dot:SetPoint("LEFT", parent, "LEFT", 7, 0)
    dot:SetTexture(CIRCLE_TEXTURE)
    return dot
end

local function CreateMapNote(parent, definition, index)
    local x = index % 2 == 1 and 10 or 120
    local y = index <= 2 and 172 or 194
    local row = GuideRow(parent, definition.label, x, y)
    row.kind, row.colorSlot = definition.kind, definition.color
    row.rim = Circle(row, 9)
    row.core = row:CreateTexture(nil, "OVERLAY")
    row.core:SetSize(3, 3)
    row.core:SetPoint("CENTER", row.rim, "CENTER")
    row.core:SetTexture(CIRCLE_TEXTURE)
    row.core:SetVertexColor(.02, .03, .035, .95)
    return row
end

local function CreateOtherGuide(parent, label, x, y, symbol)
    local row = GuideRow(parent, label, x, y)
    row.symbol = symbol
    if symbol == "quest" then
        row.rim = Circle(row, 11)
        row.rim:SetTexture("Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond.tga")
        row.rim:SetVertexColor(.04, .04, .03, .9)
        row.halo = row:CreateTexture(nil, "BACKGROUND")
        row.halo:SetSize(16, 16)
        row.halo:SetPoint("CENTER", row.rim, "CENTER")
        row.halo:SetTexture(CIRCLE_TEXTURE)
        row.fill = row:CreateTexture(nil, "OVERLAY")
        row.fill:SetSize(8, 8)
        row.fill:SetPoint("CENTER", row.rim, "CENTER")
        row.fill:SetTexture("Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond.tga")
    elseif symbol == "area" then
        row.fill = row:CreateTexture(nil, "ARTWORK")
        row.fill:SetSize(11, 11)
        row.fill:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.fill:SetTexture(CIRCLE_TEXTURE)
    elseif symbol == "trail" then
        row.dots = {}
        row.marks = {}
        row.extraMarks = {}
        for index = 1, 3 do
            local dot = row:CreateTexture(nil, "ARTWORK")
            dot:SetSize(4, 4)
            dot:SetPoint("LEFT", row, "LEFT", 3 + index * 4, 0)
            dot:SetTexture(CIRCLE_TEXTURE)
            row.dots[index] = dot
            local mark = row:CreateLine(nil, "ARTWORK")
            mark:SetThickness(1.7)
            mark:Hide()
            row.marks[index] = mark
            row.extraMarks[index] = {}
            for part = 1, 3 do
                local extra = row:CreateLine(nil, "ARTWORK")
                extra:Hide()
                row.extraMarks[index][part] = extra
            end
        end
    elseif symbol == "stale" then
        row.lines = {}
        local corners = { { 12, 5 }, { 17, 0 }, { 12, -5 }, { 7, 0 } }
        for index = 1, 4 do
            local line = row:CreateLine(nil, "ARTWORK")
            local first, last = corners[index], corners[index % 4 + 1]
            line:SetThickness(1.2)
            line:SetStartPoint("LEFT", row, first[1], first[2])
            line:SetEndPoint("LEFT", row, last[1], last[2])
            row.lines[index] = line
        end
    elseif symbol == "edge" then
        row.fill = Circle(row, 7)
        row.tip = row:CreateLine(nil, "OVERLAY")
        row.tip:SetThickness(1.3)
        row.tip:SetStartPoint("LEFT", row, 14, 0)
        row.tip:SetEndPoint("LEFT", row, 20, 0)
    else
        row.fill = Circle(row, 10)
        if symbol == "route" then
            row.number = Text(row, 8, "1")
            row.number:SetSize(10, 10)
            row.number:SetPoint("CENTER", row.fill, "CENTER")
            row.number:SetJustifyH("CENTER")
        end
    end
    return row
end

local function FrameValue(frame, method)
    if not (frame and type(frame[method]) == "function") then return nil end
    local value = frame[method](frame)
    return type(value) == "number" and value or nil
end

local function Attach(anchor)
    if not panel then return end
    panel:ClearAllPoints()
    local screenWidth = FrameValue(UIParent, "GetWidth")
    local screenHeight = FrameValue(UIParent, "GetHeight")
    local anchorScale = (FrameValue(anchor, "GetEffectiveScale") or 1)
        / (FrameValue(UIParent, "GetEffectiveScale") or 1)
    local left, right = FrameValue(anchor, "GetLeft"), FrameValue(anchor, "GetRight")
    local top, bottom = FrameValue(anchor, "GetTop"), FrameValue(anchor, "GetBottom")
    if left then left = left * anchorScale end
    if right then right = right * anchorScale end
    if top then top = top * anchorScale end
    if bottom then bottom = bottom * anchorScale end
    if anchor and screenWidth and right and screenWidth - right >= PANEL_W + 12 then
        panel:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
    elseif anchor and left and left >= PANEL_W + 12 then
        panel:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -8, 0)
    elseif anchor and bottom and bottom >= PANEL_H + 12 then
        panel:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
    elseif anchor and top and screenHeight and screenHeight - top >= PANEL_H + 12 then
        panel:SetPoint("BOTTOM", anchor, "TOP", 0, 8)
    else
        local anchorWidth = left and right and right - left
            or ((FrameValue(anchor, "GetWidth") or 0) * anchorScale)
        -- A centered Squat panel can leave no side or vertical space. Move the
        -- whole panel only when it is the anchor, keeping the saved position intact.
        if anchor and anchorWidth and anchorWidth >= 100 and left and top and screenWidth and screenHeight
            and anchorWidth + PANEL_W + 24 <= screenWidth
            and type(anchor.ClearAllPoints) == "function" and type(anchor.SetPoint) == "function" then
            local shiftedLeft = math.max(8, screenWidth - PANEL_W - 16 - anchorWidth)
            anchor:ClearAllPoints()
            anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
                shiftedLeft / anchorScale, (top - screenHeight) / anchorScale)
            panel:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
        elseif anchor then
            panel:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
        else
            panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
    attachedTo = anchor
end

local function EnsurePanel()
    if panel then return panel end
    if type(CreateFrame) ~= "function" or not UIParent then return nil end

    panel = CreateFrame("Frame", "VignetteRadarLegendPanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, PANEL_H)
    if panel.SetFrameStrata then panel:SetFrameStrata("DIALOG") end
    if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
    if panel.EnableMouse then panel:EnableMouse(true) end
    Surface(panel)

    panel.accent = panel:CreateTexture(nil, "OVERLAY")
    panel.accent:SetPoint("TOPLEFT", 1, -1)
    panel.accent:SetPoint("BOTTOMLEFT", 1, 1)
    panel.accent:SetWidth(2)
    panel.accent:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)

    panel.title = Text(panel, 11, "RADAR LEGEND")
    panel.title:SetPoint("TOPLEFT", 10, -10)
    panel.title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)

    panel.divider = panel:CreateTexture(nil, "ARTWORK")
    panel.divider:SetPoint("TOPLEFT", 9, -31)
    panel.divider:SetPoint("TOPRIGHT", -9, -31)
    panel.divider:SetHeight(1)
    panel.divider:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.18)

    panel.all = CreateFrame("Button", nil, panel, "BackdropTemplate")
    panel.all:SetSize(38, 18)
    panel.all:SetPoint("TOPRIGHT", -9, -7)
    Surface(panel.all, 0.03, 0.038, 0.043, 0.96, 0.16)
    panel.all.label = Text(panel.all, 8, "ALL")
    panel.all.label:SetAllPoints()
    panel.all.label:SetJustifyH("CENTER")
    AddPressState(panel.all)
    panel.all:SetScript("OnClick", function() API.SetHighlight(nil) end)
    panel.all:SetScript("OnEnter", function(self)
        Tooltip(self, "Show all enabled", "Clear the spotlight and return enabled categories to equal strength.")
    end)
    panel.all:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    panel.rows = {}
    for index, category in ipairs(CATEGORY_ORDER) do
        panel.rows[category] = CreateCategoryRow(panel, category, index)
    end

    panel.mapRule = SectionRule(panel, 148)
    panel.mapHeading = GuideLabel(panel, "MAP NOTES  /  HOLLOW DOTS", 10, 151, PANEL_W - 20, 9)
    panel.mapHeading:SetTextColor(.68, .75, .77, 1)
    panel.mapNotes = {}
    for index, definition in ipairs(MAP_NOTES) do
        panel.mapNotes[definition.kind] = CreateMapNote(panel, definition, index)
    end
    panel.mapCaption = GuideLabel(panel, "Saved in one pack; not live detections", 10, 216, PANEL_W - 20, 8)
    panel.mapCaption:SetTextColor(.5, .57, .59, 1)

    panel.otherRule = SectionRule(panel, 233)
    panel.otherHeading = GuideLabel(panel, "MORE ON THE RADAR", 10, 238, PANEL_W - 20, 9)
    panel.otherHeading:SetTextColor(.68, .75, .77, 1)
    panel.guides = {
        quest = CreateOtherGuide(panel, "Quest diamond", 10, 256, "quest"),
        area = CreateOtherGuide(panel, "Quest area", 120, 256, "area"),
        pin = CreateOtherGuide(panel, "Saved pin", 10, 278, "pin"),
        route = CreateOtherGuide(panel, "Route stop", 120, 278, "route"),
        trail = CreateOtherGuide(panel, "Travel trail", 10, 300, "trail"),
        stale = CreateOtherGuide(panel, "Last seen", 120, 300, "stale"),
        edge = CreateOtherGuide(panel, "Off-range cue", 10, 322, "edge"),
    }
    panel.footerRule = SectionRule(panel, 346)

    panel.status = Text(panel, 8, "NO SPOTLIGHT")
    panel.status:SetPoint("BOTTOMLEFT", 10, 7)
    panel.status:SetTextColor(0.48, 0.55, 0.56, 1)
    -- WoW creates frames shown by default. Keep the lazy panel closed until the
    -- radar's legend button explicitly opens it.
    panel:Hide()
    return panel
end

local function QuestColor(entry)
    local palette = addon.VignetteRadarQuestColors
    local color = Settings().vignetteRadarQuestColors and palette and palette[entry.colorSlot or 1]
    if color then return color[1], color[2], color[3] end
    if addon.VignetteRadarStyle then return addon.VignetteRadarStyle.Color("quest") end
    return 1, .74, .27
end

local function RestoreQuestShift()
    if not (questPanel and questPanel.shiftedAnchor) then return end
    local saved = questPanel.shiftedAnchor
    questPanel.shiftedAnchor = nil
    local anchor = saved.anchor
    local currentLeft = FrameValue(anchor, "GetLeft")
    if currentLeft and math.abs(currentLeft - saved.shiftedLeft) <= 2 then
        anchor:ClearAllPoints()
        anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", saved.left,
            (saved.top * saved.scale - saved.screenHeight) / saved.scale)
    end
end

local function AttachQuest(anchor, owner)
    if not questPanel then return end
    questPanel:ClearAllPoints()
    local screenWidth, screenHeight = FrameValue(UIParent, "GetWidth"), FrameValue(UIParent, "GetHeight")
    local parentScale = FrameValue(UIParent, "GetEffectiveScale") or 1
    local left, right = FrameValue(anchor, "GetLeft"), FrameValue(anchor, "GetRight")
    local top, bottom = FrameValue(anchor, "GetTop"), FrameValue(anchor, "GetBottom")
    local anchorScale = (FrameValue(anchor, "GetEffectiveScale") or 1) / parentScale
    if left then left = left * anchorScale end
    if right then right = right * anchorScale end
    if top then top = top * anchorScale end
    if bottom then bottom = bottom * anchorScale end
    if anchor and left and left < QUEST_PANEL_W + 12 and owner and screenWidth and screenHeight
        and not questPanel.shiftedAnchor then
        local ownerLeft, ownerRight = FrameValue(owner, "GetLeft"), FrameValue(owner, "GetRight")
        local ownerTop = FrameValue(owner, "GetTop")
        local ownerScale = (FrameValue(owner, "GetEffectiveScale") or 1) / parentScale
        local shift = QUEST_PANEL_W + 16 - left
        if ownerLeft and ownerRight and ownerTop and ownerRight * ownerScale + shift <= screenWidth - 8
            and type(owner.ClearAllPoints) == "function" and type(owner.SetPoint) == "function" then
            questPanel.shiftedAnchor = { anchor = owner, left = ownerLeft, top = ownerTop,
                scale = ownerScale, shiftedLeft = ownerLeft + shift / ownerScale,
                screenHeight = screenHeight }
            owner:ClearAllPoints()
            owner:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
                ownerLeft + shift / ownerScale,
                (ownerTop * ownerScale - screenHeight) / ownerScale)
            left = left + shift
        end
    end
    if anchor and left and left >= QUEST_PANEL_W + 12 then
        questPanel:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -8, 0)
    elseif anchor and right and screenWidth and screenWidth - right >= QUEST_PANEL_W + 12 then
        questPanel:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
    elseif anchor and bottom and bottom >= questPanel:GetHeight() + 12 then
        questPanel:SetPoint("TOP", anchor, "BOTTOM", 0, -8)
    elseif anchor then
        questPanel:SetPoint("BOTTOM", anchor, "TOP", 0, 8)
    else
        questPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    questAttachedTo = anchor
end

local function RefreshQuestRows()
    if not questPanel then return end
    local count = #questEntries
    local visible = math.min(QUEST_VISIBLE_ROWS, count)
    local height = 54 + math.max(1, visible) * QUEST_ROW_STEP
    questPanel:SetHeight(height)
    local style = addon.VignetteRadarStyle
    local red, green, blue = ACCENT[1], ACCENT[2], ACCENT[3]
    if style then red, green, blue = style.Color("accent") end
    questPanel.accent:SetColorTexture(red, green, blue, .8)
    questPanel.title:SetTextColor(red, green, blue, 1)
    questPanel.rule:SetColorTexture(red, green, blue, .18)
    questPanel.count:SetText(count .. " IN RANGE")
    questOffset = math.max(0, math.min(questOffset, count - QUEST_VISIBLE_ROWS))
    local focused = addon.VignetteRadarExploration and addon.VignetteRadarExploration.GetFocusedQuest
        and addon.VignetteRadarExploration.GetFocusedQuest()
    for index, row in ipairs(questPanel.rows) do
        local entry = questEntries[questOffset + index]
        row.entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            local r, g, b = QuestColor(entry)
            row.fill:SetVertexColor(r, g, b, 1)
            if entry.completed then
                row.rim:SetTexture(QUEST_DIAMOND_TEXTURE)
                row.rim:SetSize(13, 13)
                row.rim:SetVertexColor(.04, .05, .06, .98)
                row.fill:Show()
                row.number:SetTextColor(.03, .04, .05, 1)
            else
                row.rim:SetTexture(QUEST_HOLLOW_DIAMOND_TEXTURE)
                row.rim:SetSize(QUEST_HOLLOW_SIZE, QUEST_HOLLOW_SIZE)
                row.rim:SetVertexColor(r, g, b, 1)
                row.fill:Hide()
                row.number:SetTextColor(r, g, b, 1)
            end
            row.number:SetText(addon.GetSettings().vignetteRadarQuestNumbers
                and tostring(entry.colorSlot or 1) or "")
            row.halo:SetVertexColor(r, g, b, .14)
            row.name:SetText(entry.name)
            local selected = focused == entry.questID
            row.focus:SetColorTexture(r, g, b, .85)
            row.focus:SetShown(selected)
            row.name:SetTextColor(selected and r or .82, selected and g or .87,
                selected and b or .88, 1)
            row.hover:SetColorTexture(r, g, b, .10)
        end
    end
    local overflow = count > QUEST_VISIBLE_ROWS
    questPanel.scrollTrack:SetShown(overflow)
    questPanel.scrollThumb:SetShown(overflow)
    if overflow then
        local trackHeight = QUEST_VISIBLE_ROWS * QUEST_ROW_STEP - 4
        local thumbHeight = math.max(18, trackHeight * QUEST_VISIBLE_ROWS / count)
        questPanel.scrollTrack:SetHeight(trackHeight)
        questPanel.scrollThumb:SetHeight(thumbHeight)
        questPanel.scrollThumb:ClearAllPoints()
        questPanel.scrollThumb:SetPoint("TOP", questPanel.scrollTrack, "TOP", 0,
            -(trackHeight - thumbHeight) * questOffset / (count - QUEST_VISIBLE_ROWS))
        questPanel.scrollThumb:SetColorTexture(red, green, blue, .65)
    end
    questPanel.status:SetText(count == 0 and "No mapped quests inside this range"
        or overflow and (questOffset + 1) .. "–" .. (questOffset + visible) .. " of " .. count .. " · scroll"
        or "Click a quest to spotlight it")
end

local function EnsureQuestPanel()
    if questPanel then return questPanel end
    if type(CreateFrame) ~= "function" or not UIParent then return nil end
    questPanel = CreateFrame("Frame", "VignetteRadarQuestLegendPanel", UIParent, "BackdropTemplate")
    questPanel:SetSize(QUEST_PANEL_W, 80)
    if questPanel.SetFrameStrata then questPanel:SetFrameStrata("DIALOG") end
    if questPanel.SetClampedToScreen then questPanel:SetClampedToScreen(true) end
    if questPanel.EnableMouse then questPanel:EnableMouse(true) end
    Surface(questPanel)
    questPanel.accent = questPanel:CreateTexture(nil, "OVERLAY")
    questPanel.accent:SetPoint("TOPRIGHT", -1, -1)
    questPanel.accent:SetPoint("BOTTOMRIGHT", -1, 1)
    questPanel.accent:SetWidth(2)
    questPanel.title = Text(questPanel, 11, "QUEST KEY")
    questPanel.title:SetPoint("TOPLEFT", 12, -10)
    questPanel.count = Text(questPanel, 8, "0 IN RANGE")
    questPanel.count:SetPoint("TOPRIGHT", -31, -11)
    questPanel.count:SetJustifyH("RIGHT")
    questPanel.count:SetWidth(85)
    questPanel.rule = SectionRule(questPanel, 31)
    questPanel.rows = {}
    local function Scroll(_, delta)
        questOffset = math.max(0, math.min(math.max(0, #questEntries - QUEST_VISIBLE_ROWS),
            questOffset - delta))
        RefreshQuestRows()
    end
    if questPanel.EnableMouseWheel then questPanel:EnableMouseWheel(true) end
    questPanel:SetScript("OnMouseWheel", Scroll)
    for index = 1, QUEST_VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, questPanel)
        row:SetSize(204, QUEST_ROW_H)
        row:SetPoint("TOPLEFT", 10, -37 - (index - 1) * QUEST_ROW_STEP)
        if row.EnableMouseWheel then row:EnableMouseWheel(true) end
        row:SetScript("OnMouseWheel", Scroll)
        row.hover = row:CreateTexture(nil, "BACKGROUND")
        row.hover:SetAllPoints()
        row.hover:Hide()
        row.focus = row:CreateTexture(nil, "ARTWORK")
        row.focus:SetSize(2, 16)
        row.focus:SetPoint("LEFT", 0, 0)
        row.halo = row:CreateTexture(nil, "ARTWORK")
        row.halo:SetSize(18, 18)
        row.halo:SetPoint("LEFT", 7, 0)
        row.halo:SetTexture(CIRCLE_TEXTURE)
        row.rim = row:CreateTexture(nil, "OVERLAY")
        row.rim:SetSize(13, 13)
        row.rim:SetPoint("CENTER", row.halo, "CENTER")
        row.rim:SetTexture(QUEST_DIAMOND_TEXTURE)
        row.rim:SetVertexColor(.04, .05, .06, .98)
        row.fill = row:CreateTexture(nil, "OVERLAY")
        row.fill:SetSize(9, 9)
        row.fill:SetPoint("CENTER", row.halo, "CENTER")
        row.fill:SetTexture(QUEST_DIAMOND_TEXTURE)
        row.number = Text(row, 8, "")
        row.number:SetPoint("CENTER", row.halo, "CENTER")
        row.number:SetTextColor(.03, .04, .05, 1)
        row.name = Text(row, 10, "")
        row.name:SetPoint("LEFT", 30, 0)
        row.name:SetWidth(164)
        row:SetScript("OnEnter", function(self)
            self.hover:Show()
            if not (self.entry and GameTooltip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.entry.name, 1, .89, .78)
            GameTooltip:AddLine(self.entry.completed and "Complete · solid diamond"
                or "In progress · hollow diamond", .68, .82, .8)
            if self.entry.distance then
                GameTooltip:AddLine(math.floor(self.entry.distance + .5) .. " yd from you", .72, .76, .78)
            end
            GameTooltip:AddLine("Click to spotlight; click again to clear.", .6, .8, .72, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            self.hover:Hide()
            if GameTooltip then GameTooltip:Hide() end
        end)
        row:SetScript("OnClick", function(self)
            local exploration = addon.VignetteRadarExploration
            if self.entry and exploration and exploration.FocusQuest then
                exploration.FocusQuest(self.entry.questID)
                RefreshQuestRows()
            end
        end)
        row:Hide()
        questPanel.rows[index] = row
    end
    questPanel.scrollTrack = questPanel:CreateTexture(nil, "ARTWORK")
    questPanel.scrollTrack:SetPoint("TOPRIGHT", -5, -38)
    questPanel.scrollTrack:SetWidth(2)
    questPanel.scrollTrack:SetColorTexture(.55, .61, .63, .20)
    questPanel.scrollThumb = questPanel:CreateTexture(nil, "OVERLAY")
    questPanel.scrollThumb:SetWidth(2)
    questPanel.status = Text(questPanel, 8, "No mapped quests inside this range")
    questPanel.status:SetPoint("BOTTOMLEFT", 12, 8)
    questPanel.status:SetTextColor(.53, .62, .63, 1)
    questPanel.close = CreateFrame("Button", nil, questPanel)
    questPanel.close:SetSize(20, 20)
    questPanel.close:SetPoint("TOPRIGHT", -5, -5)
    for _, points in ipairs({ { -4, -4, 4, 4 }, { -4, 4, 4, -4 } }) do
        local line = questPanel.close:CreateLine(nil, "OVERLAY")
        line:SetThickness(1.8)
        line:SetColorTexture(.72, .78, .79, .9)
        line:SetStartPoint("CENTER", questPanel.close, points[1], points[2])
        line:SetEndPoint("CENTER", questPanel.close, points[3], points[4])
    end
    questPanel.close:SetScript("OnClick", function() API.HideQuest() end)
    questPanel:SetScript("OnHide", RestoreQuestShift)
    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "VignetteRadarQuestLegendPanel"
    end
    RefreshQuestRows()
    questPanel:Hide()
    return questPanel
end

function API.Refresh()
    local settings = API.ApplyDefaults()
    if not panel then return end
    local highlight = API.GetHighlight()
    local style = addon.VignetteRadarStyle
    local accentRed, accentGreen, accentBlue = ACCENT[1], ACCENT[2], ACCENT[3]
    if style then
        accentRed, accentGreen, accentBlue = style.Color("accent")
        panel.accent:SetColorTexture(accentRed, accentGreen, accentBlue, .8)
        panel.title:SetTextColor(accentRed, accentGreen, accentBlue, 1)
        panel.divider:SetColorTexture(accentRed, accentGreen, accentBlue, .18)
    end
    for _, category in ipairs(CATEGORY_ORDER) do
        local row = panel.rows[category]
        row.selection:SetColorTexture(accentRed, accentGreen, accentBlue, .09)
        local red, green, blue = API.ColorFor(category)
        row.swatchGlow:SetColorTexture(red, green, blue, .14)
        local icons = settings.vignetteRadarShapes ~= false
        if category == "rare" then
            row.swatch:SetTexture(icons and SKULL_TEXTURE or CIRCLE_TEXTURE)
            row.swatch:SetSize(icons and 13 or 7, icons and 13 or 7)
            row.bossSwatch:SetTexture(icons and SKULL_TEXTURE or CIRCLE_TEXTURE)
            row.bossSwatch:SetSize(icons and 13 or 7, icons and 13 or 7)
            if style then row.bossSwatch:SetVertexColor(style.Color("boss")) end
        elseif category == "treasure" then
            if icons and row.swatch.SetAtlas then row.swatch:SetAtlas("VignetteLoot")
            else row.swatch:SetTexture(CIRCLE_TEXTURE) end
            row.swatch:SetSize(icons and row.swatch.SetAtlas and 13 or 7,
                icons and row.swatch.SetAtlas and 13 or 7)
        else
            row.swatch:SetTexture(CIRCLE_TEXTURE)
        end
        row.swatch:SetVertexColor(red, green, blue, 1)
        local enabled = API.IsCategoryEnabled(category)
        local selected = highlight == category
        if enabled then
            row:SetAlpha((selected or not highlight) and 1 or 0.58)
            row.toggle.label:SetText("ON")
            row.toggle.label:SetTextColor(accentRed, accentGreen, accentBlue, 1)
            row.swatch:SetAlpha(1)
            if row.bossSwatch then row.bossSwatch:SetAlpha(1) end
        else
            row:SetAlpha(0.46)
            row.toggle.label:SetText("OFF")
            row.toggle.label:SetTextColor(0.58, 0.60, 0.62, 1)
            row.swatch:SetAlpha(0.38)
            if row.bossSwatch then row.bossSwatch:SetAlpha(0.38) end
        end
        if selected then row.selection:Show() else row.selection:Hide() end
    end
    local function Color(slot, fallback)
        if style then return style.Color(slot) end
        return fallback[1], fallback[2], fallback[3]
    end
    local mapEnabled = settings.vignetteRadarPOISource ~= "none"
    for _, definition in ipairs(MAP_NOTES) do
        local row = panel.mapNotes[definition.kind]
        row.rim:SetVertexColor(Color(definition.color, CATEGORIES[definition.color].color))
        local enabled = mapEnabled and (type(settings.vignetteRadarPOITypes) ~= "table"
            or settings.vignetteRadarPOITypes[definition.kind] ~= false)
        row:SetAlpha(enabled and 1 or .6)
        row.label:SetText(definition.label .. (enabled and "" or " off"))
    end
    panel.mapCaption:SetText(not mapEnabled and "Map notes off · enable in Map Data"
        or settings.vignetteRadarPOIIcons and "Pack icons vary · saved, not live"
        or "Saved in one pack; not live detections")
    local questRed, questGreen, questBlue = Color("quest", { 1, .74, .27 })
    if settings.vignetteRadarQuestColors and addon.VignetteRadarQuestColors then
        local first = addon.VignetteRadarQuestColors[1]
        questRed, questGreen, questBlue = first[1], first[2], first[3]
    end
    panel.guides.quest.fill:SetVertexColor(questRed, questGreen, questBlue, 1)
    local areaRed, areaGreen, areaBlue = .34, .60, 1
    if settings.vignetteRadarQuestColors and settings.vignetteRadarQuestAreaColors
        and addon.VignetteRadarQuestColors then
        local first = addon.VignetteRadarQuestColors[1]
        areaRed, areaGreen, areaBlue = first[1], first[2], first[3]
    end
    panel.guides.quest.halo:SetVertexColor(areaRed, areaGreen, areaBlue, .16)
    local showQuestHalo = settings.vignetteRadarQuestDots and settings.vignetteRadarQuestAreas
        and settings.vignetteRadarQuestHalos
    panel.guides.quest.halo:SetShown(showQuestHalo == true)
    panel.guides.area.fill:SetVertexColor(areaRed, areaGreen, areaBlue, .3)
    panel.guides.quest:SetAlpha(settings.vignetteRadarQuestDots and 1 or .6)
    panel.guides.quest.label:SetText(not settings.vignetteRadarQuestDots and "Quest off"
        or showQuestHalo and "Quest + halo" or "Quest diamond")
    panel.guides.area:SetAlpha(settings.vignetteRadarQuestAreas and 1 or .6)
    panel.guides.area.label:SetText(settings.vignetteRadarQuestAreas and "Native area" or "Area off")
    panel.guides.pin.fill:SetVertexColor(.92, .71, .34, .9)
    panel.guides.route.fill:SetVertexColor(.16, .7, .54, .9)
    panel.guides.edge.fill:SetVertexColor(questRed, questGreen, questBlue, .9)
    panel.guides.edge.tip:SetColorTexture(questRed, questGreen, questBlue, .7)
    panel.guides.edge:SetAlpha(settings.vignetteRadarEdgeCues and 1 or .6)
    panel.guides.edge.label:SetText(settings.vignetteRadarEdgeCues and "Off-range cue" or "Edge cues off")
    local rareRed, rareGreen, rareBlue = Color("rare", CATEGORIES.rare.color)
    for _, line in ipairs(panel.guides.stale.lines) do
        line:SetColorTexture(rareRed, rareGreen, rareBlue, .4)
    end
    local trailStyle = settings.vignetteRadarTrailStyle or "dashes"
    local trailDefinition = TRAIL_STYLES[trailStyle] or TRAIL_STYLES.dashes
    for index, dot in ipairs(panel.guides.trail.dots) do
        dot:SetVertexColor(accentRed, accentGreen, accentBlue, .85)
        dot:SetTexture(trailDefinition.square and "Interface\\Buttons\\WHITE8X8"
            or "Interface\\CharacterFrame\\TempPortraitAlphaMask")
        local dotSize = trailDefinition.alternating and index % 2 == 0 and 2.5 or 4
        dot:SetSize(dotSize, dotSize)
        dot:SetShown(trailDefinition.dot ~= nil or trailDefinition.square ~= nil)
        local mark = panel.guides.trail.marks[index]
        local x = 2 + index * 5
        for part = 1, 4 do
            local line = part == 1 and mark or panel.guides.trail.extraMarks[index][part - 1]
            local segment = trailDefinition.segments and trailDefinition.segments[part]
            if segment then
                local scale = trailDefinition.alternating and index % 2 == 0 and .22 or .45
                line:SetThickness(segment[5] * .8)
                line:SetStartPoint("LEFT", panel.guides.trail,
                    x + segment[1] * scale, segment[2] * scale)
                line:SetEndPoint("LEFT", panel.guides.trail,
                    x + segment[3] * scale, segment[4] * scale)
                line:SetColorTexture(accentRed, accentGreen, accentBlue, .85)
                line:Show()
            else
                line:Hide()
            end
        end
    end
    panel.guides.trail:SetAlpha(settings.vignetteRadarBreadcrumbs and 1 or .6)
    local trailName = trailStyle == "long" and "Long" or trailDefinition.label
    panel.guides.trail.label:SetText(settings.vignetteRadarBreadcrumbs
        and ("Trail: " .. trailName) or "Trail off")
    if highlight then
        panel.status:SetText("SPOTLIGHT: " .. CATEGORIES[highlight].label)
        panel.all.label:SetTextColor(0.62, 0.66, 0.68, 1)
    else
        panel.status:SetText("NO SPOTLIGHT")
        panel.all.label:SetTextColor(accentRed, accentGreen, accentBlue, 1)
    end
end

function API.Toggle(anchor)
    local legend = EnsurePanel()
    if not legend then return false end
    if legend:IsShown() then
        legend:Hide()
        return false
    end
    Attach(anchor or attachedTo)
    API.Refresh()
    legend:Show()
    return true
end

function API.Reanchor(anchor)
    if not (panel and panel:IsShown()) then return false end
    Attach(anchor or attachedTo)
    return true
end

function API.Hide()
    if panel then panel:Hide() end
end

function API.IsShown()
    return panel ~= nil and panel:IsShown() or false
end

function API.SetQuestEntries(entries)
    questEntries = type(entries) == "table" and entries or {}
    table.sort(questEntries, function(left, right)
        if left.distance ~= right.distance then
            return (left.distance or math.huge) < (right.distance or math.huge)
        end
        return left.questID < right.questID
    end)
    if questPanel and questPanel:IsShown() then RefreshQuestRows() end
end

function API.ToggleQuest(anchor, owner)
    local key = EnsureQuestPanel()
    if not key then return false end
    if key:IsShown() then key:Hide(); return false end
    RefreshQuestRows()
    AttachQuest(anchor or questAttachedTo, owner)
    key:Show()
    return true
end

function API.ReanchorQuest(anchor, owner)
    if not (questPanel and questPanel:IsShown()) then return false end
    AttachQuest(anchor or questAttachedTo, owner)
    return true
end

function API.HideQuest()
    if questPanel then questPanel:Hide() end
end

function API.IsQuestShown()
    return questPanel ~= nil and questPanel:IsShown() or false
end

API.ApplyDefaults()

API.Testing = {
    CategoryKey = CategoryKey,
    CategoryOrder = CATEGORY_ORDER,
    Categories = CATEGORIES,
    GetPanel = function() return panel end,
    GetQuestPanel = function() return questPanel end,
}
