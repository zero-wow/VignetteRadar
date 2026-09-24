local _, addon = ...
if type(addon) ~= "table" then return end

local PANEL_W, PANEL_H = 250, 258
local ROWS_PER_PAGE = 5
local ACCENT = { 0.05, 0.82, 0.62 }
local CIRCLE_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SKULL_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local FONT_FALLBACK = "Fonts\\FRIZQT__.TTF"

local panel
local attachedTo
local provider
local changeCallback
local focusKey, focusName
local page = 1

local API = {}
addon.VignetteRadarTargetPicker = API

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

local function Targets()
    if type(provider) ~= "function" then return {} end
    local ok, targets = pcall(provider)
    if not ok or type(targets) ~= "table" then return {} end
    return targets
end

local function IsFavorite(target)
    local features = addon.VignetteRadarFeatures
    if features and type(features.IsFavorite) == "function" then
        local ok, favorite = pcall(features.IsFavorite, target)
        if ok then return favorite == true end
    end
    return target.favorite == true
end

local function LastSeenAge(target)
    if type(target.lastSeenAt) ~= "number" or type(GetTime) ~= "function" then return nil end
    return math.max(0, math.floor(GetTime() - target.lastSeenAt + 0.5))
end

local function AgeLabel(seconds)
    if not seconds then return "LAST SEEN" end
    if seconds < 60 then return seconds .. "S AGO" end
    if seconds < 3600 then return math.floor(seconds / 60) .. "M AGO" end
    return math.floor(seconds / 3600) .. "H AGO"
end

local function Tooltip(owner, target)
    if not (GameTooltip and target) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(target.name or "Detected vignette", 1, 1, 1)
    if target.isWorldBoss == true then
        GameTooltip:AddLine("World boss", 1, 0.18, 0.12)
    elseif target.category == "rare" then
        GameTooltip:AddLine("Rare enemy", 0.78, 0.88, 1)
    end
    if type(target.distance) == "number" then
        GameTooltip:AddLine(math.floor(target.distance + 0.5) .. " yd away", 0.72, 0.76, 0.78)
    end
    if type(target.groupMin) == "number" and target.groupMin > 0 then
        local group = type(target.groupMax) == "number" and target.groupMax > target.groupMin
            and (target.groupMin .. "–" .. target.groupMax) or tostring(target.groupMin)
        GameTooltip:AddLine("Suggested group: " .. group, .85, .76, .53)
    end
    if target.stale then
        local age = LastSeenAge(target)
        GameTooltip:AddLine(age and ("Last seen " .. AgeLabel(age):lower() .. ".") or "Last seen recently.",
            0.72, 0.76, 0.78)
    elseif not target.sample then
        GameTooltip:AddLine(target.source == "worldMap" and "Shown on Blizzard's world map."
            or "Currently visible on the minimap.", 0.72, 0.76, 0.78)
    end
    if IsFavorite(target) then GameTooltip:AddLine("Favorite", 1, 0.82, 0.33) end
    GameTooltip:AddLine("Left-click: focus this vignette; click again to show all.", 0.55, 0.86, 0.76, true)
    if not target.sample then
        if not target.stale then GameTooltip:AddLine("Shift-left-click: navigate to it.", 0.55, 0.86, 0.76, true) end
        GameTooltip:AddLine("Alt-left-click: toggle favorite.", 0.55, 0.86, 0.76, true)
        GameTooltip:AddLine("Right-click: ignore this session.", 0.55, 0.86, 0.76, true)
        GameTooltip:AddLine("Shift-right-click: ignore persistently.", 0.55, 0.86, 0.76, true)
        GameTooltip:AddLine("Ctrl-click: route stop. Ctrl-Alt-click: watch approach.", 0.55, 0.86, 0.76, true)
    end
    GameTooltip:Show()
end

local function NotifyChanged()
    API.Refresh()
    if type(changeCallback) == "function" then pcall(changeCallback) end
end

function API.SetProvider(callback)
    provider = type(callback) == "function" and callback or nil
    API.Refresh()
end

function API.SetChangeCallback(callback)
    changeCallback = type(callback) == "function" and callback or nil
end

function API.GetFocus()
    return focusKey
end

function API.GetFocusName()
    return focusName
end

function API.SetFocus(key, name)
    key = type(key) == "string" and key ~= "" and key or nil
    name = key and type(name) == "string" and name or nil
    if focusKey == key and focusName == name then return false end
    focusKey, focusName = key, name
    NotifyChanged()
    return true
end

function API.ClearFocus()
    return API.SetFocus(nil)
end

function API.ValidateTargets(targets)
    if not focusKey then return false end
    targets = type(targets) == "table" and targets or Targets()
    for _, target in ipairs(targets) do
        if target.key == focusKey then return false end
    end
    focusKey, focusName = nil, nil
    API.Refresh()
    return true
end

local function AddPressState(button)
    button.press = button:CreateTexture(nil, "OVERLAY")
    button.press:SetAllPoints()
    button.press:SetColorTexture(1, 1, 1, 0.05)
    button.press:Hide()
    button:SetScript("OnMouseDown", function(self) self.press:Show() end)
    button:SetScript("OnMouseUp", function(self) self.press:Hide() end)
    button:SetScript("OnHide", function(self) self.press:Hide() end)
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    row:SetSize(PANEL_W - 18, 34)
    row:SetPoint("TOPLEFT", 9, -45 - ((index - 1) * 37))
    Surface(row, 0.06, 0.069, 0.078, 0.98, 0.09)

    row.selection = row:CreateTexture(nil, "BACKGROUND")
    row.selection:SetPoint("TOPLEFT", 1, -1)
    row.selection:SetPoint("BOTTOMRIGHT", -1, 1)
    row.selection:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.10)
    row.selection:Hide()
    row.accent = row:CreateTexture(nil, "OVERLAY")
    row.accent:SetWidth(2)
    row.accent:SetPoint("TOPLEFT", 1, -1)
    row.accent:SetPoint("BOTTOMLEFT", 1, 1)
    row.accent:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
    row.accent:Hide()

    row.reticle = row:CreateTexture(nil, "ARTWORK")
    row.reticle:SetSize(19, 19)
    row.reticle:SetPoint("LEFT", 8, 0)
    row.reticle:SetTexture(CIRCLE_TEXTURE)
    row.reticle:SetVertexColor(0.22, 0.26, 0.28, 0.9)
    row.dot = row:CreateTexture(nil, "OVERLAY")
    row.dot:SetSize(7, 7)
    row.dot:SetPoint("CENTER", row.reticle, "CENTER")
    row.dot:SetTexture(CIRCLE_TEXTURE)

    row.favorite = Text(row, 11, "*")
    row.favorite:SetPoint("TOPLEFT", 34, -5)
    row.favorite:SetWidth(10)
    row.favorite:SetTextColor(1, 0.82, 0.33, 1)
    row.favorite:Hide()
    row.name = Text(row, 10, "")
    row.name:SetPoint("TOPLEFT", 46, -6)
    row.name:SetWidth(121)
    if row.name.SetMaxLines then row.name:SetMaxLines(1) end
    row.meta = Text(row, 8, "")
    row.meta:SetPoint("BOTTOMLEFT", 35, 5)
    row.meta:SetWidth(132)
    if row.meta.SetMaxLines then row.meta:SetMaxLines(1) end
    row.meta:SetTextColor(0.49, 0.58, 0.59, 1)
    row.action = Text(row, 8, "FOCUS")
    row.action:SetPoint("RIGHT", -8, 0)
    row.action:SetWidth(49)
    row.action:SetJustifyH("RIGHT")
    row.action:SetTextColor(0.56, 0.64, 0.65, 1)
    AddPressState(row)

    row:SetScript("OnClick", function(self, button)
        local target = self.target
        if not target then return end
        local handler = addon.HandleVignetteClick
        if type(handler) == "function" then
            handler(target, button or "LeftButton")
            API.Refresh()
            return
        end
        if button and button ~= "LeftButton" then return end
        if focusKey == target.key then API.ClearFocus() else API.SetFocus(target.key, target.name) end
    end)
    row:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.36)
        Tooltip(self, self.target)
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(1, 1, 1, 0.09)
        if GameTooltip then GameTooltip:Hide() end
    end)
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
            local shiftedLeft = math.max(8, screenWidth - PANEL_W - 12 - anchorWidth)
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

    panel = CreateFrame("Frame", "VignetteRadarTargetPickerPanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, PANEL_H)
    if panel.SetFrameStrata then panel:SetFrameStrata("DIALOG") end
    if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
    Surface(panel)

    panel.accent = panel:CreateTexture(nil, "OVERLAY")
    panel.accent:SetPoint("TOPLEFT", 1, -1)
    panel.accent:SetPoint("BOTTOMLEFT", 1, 1)
    panel.accent:SetWidth(2)
    panel.accent:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
    panel.title = Text(panel, 11, "VIGNETTE FOCUS")
    panel.title:SetPoint("TOPLEFT", 10, -9)
    panel.title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    panel.subtitle = Text(panel, 8, "Choose one current detection")
    panel.subtitle:SetPoint("TOPLEFT", 10, -25)
    panel.subtitle:SetWidth(165)
    if panel.subtitle.SetMaxLines then panel.subtitle:SetMaxLines(1) end
    panel.subtitle:SetTextColor(0.48, 0.56, 0.57, 1)

    panel.clear = CreateFrame("Button", nil, panel, "BackdropTemplate")
    panel.clear:SetSize(58, 20)
    panel.clear:SetPoint("TOPRIGHT", -9, -8)
    Surface(panel.clear, 0.03, 0.038, 0.043, 0.96, 0.16)
    panel.clear.label = Text(panel.clear, 8, "SHOW ALL")
    panel.clear.label:SetAllPoints()
    panel.clear.label:SetJustifyH("CENTER")
    AddPressState(panel.clear)
    panel.clear:SetScript("OnClick", function() API.ClearFocus() end)
    panel.clear:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show all vignettes", 1, 1, 1)
        GameTooltip:AddLine("Clear the specific target filter while keeping category filters active.", 0.55, 0.86, 0.76, true)
        GameTooltip:Show()
    end)
    panel.clear:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    panel.rows = {}
    for index = 1, ROWS_PER_PAGE do panel.rows[index] = CreateRow(panel, index) end
    panel.empty = Text(panel, 10, "NO CURRENT DETECTIONS")
    panel.empty:SetPoint("CENTER", 0, -5)
    panel.empty:SetJustifyH("CENTER")
    panel.empty:SetTextColor(0.50, 0.56, 0.57, 1)

    panel.previous = CreateFrame("Button", nil, panel, "BackdropTemplate")
    panel.previous:SetSize(24, 18)
    panel.previous:SetPoint("BOTTOMLEFT", 9, 7)
    Surface(panel.previous, 0.03, 0.038, 0.043, 0.96, 0.14)
    panel.previous.label = Text(panel.previous, 10, "‹")
    panel.previous.label:SetAllPoints()
    panel.previous.label:SetJustifyH("CENTER")
    panel.previous:SetScript("OnClick", function() page = math.max(1, page - 1); API.Refresh() end)
    panel.next = CreateFrame("Button", nil, panel, "BackdropTemplate")
    panel.next:SetSize(24, 18)
    panel.next:SetPoint("BOTTOMRIGHT", -9, 7)
    Surface(panel.next, 0.03, 0.038, 0.043, 0.96, 0.14)
    panel.next.label = Text(panel.next, 10, "›")
    panel.next.label:SetAllPoints()
    panel.next.label:SetJustifyH("CENTER")
    panel.next:SetScript("OnClick", function() page = page + 1; API.Refresh() end)
    panel.page = Text(panel, 8, "1 / 1")
    panel.page:SetPoint("BOTTOM", 0, 11)
    panel.page:SetJustifyH("CENTER")
    panel.page:SetTextColor(0.49, 0.57, 0.58, 1)
    panel:Hide()
    return panel
end

function API.Refresh()
    if not panel then return end
    local targets = Targets()
    local pageCount = math.max(1, math.ceil(#targets / ROWS_PER_PAGE))
    page = math.max(1, math.min(page, pageCount))
    local first = ((page - 1) * ROWS_PER_PAGE) + 1
    for rowIndex, row in ipairs(panel.rows) do
        local target = targets[first + rowIndex - 1]
        row.target = target
        if target then
            local rare = target.category == "rare"
            local boss = target.isWorldBoss == true
            local red = target.red or (boss and 1 or rare and 0.78 or 1)
            local green = target.green or (boss and 0.18 or rare and 0.88 or 0.24)
            local blue = target.blue or (boss and 0.12 or rare and 1 or 0.20)
            row.name:SetText(target.name or "Detected vignette")
            row.favorite:SetShown(IsFavorite(target))
            local category = boss and "WORLD BOSS"
                or type(target.category) == "string" and target.category:upper() or "OTHER"
            local distance = type(target.distance) == "number" and (math.floor(target.distance + 0.5) .. " YD") or "DISTANCE N/A"
            if target.stale then
                row.meta:SetText(boss and ("WORLD BOSS  •  " .. AgeLabel(LastSeenAge(target)))
                    or (distance .. "  •  " .. AgeLabel(LastSeenAge(target))))
                row.meta:SetTextColor(0.64, 0.58, 0.47, 1)
            else
                row.meta:SetText(category .. "  •  " .. distance)
                row.meta:SetTextColor(0.49, 0.58, 0.59, 1)
            end
            row.dot:SetTexture((boss or rare) and SKULL_TEXTURE or CIRCLE_TEXTURE)
            row.dot:SetSize(boss and 14 or rare and 12 or 7, boss and 14 or rare and 12 or 7)
            row.dot:SetVertexColor(red, green, blue, 1)
            local selected = focusKey == target.key
            row.action:SetText(selected and "ACTIVE" or "FOCUS")
            row.action:SetTextColor(selected and ACCENT[1] or 0.56, selected and ACCENT[2] or 0.64,
                selected and ACCENT[3] or 0.65, 1)
            if selected then row.selection:Show(); row.accent:Show() else row.selection:Hide(); row.accent:Hide() end
            row:Show()
        else
            row:Hide()
        end
    end
    panel.empty:SetShown(#targets == 0)
    panel.page:SetText(page .. " / " .. pageCount)
    panel.previous:SetShown(pageCount > 1 and page > 1)
    panel.next:SetShown(pageCount > 1 and page < pageCount)
    panel.clear:SetAlpha(focusKey and 1 or 0.48)
    panel.subtitle:SetText(focusKey and ("Focused: " .. (focusName or "current vignette")) or "Choose one current detection")
end

function API.Toggle(anchor)
    local picker = EnsurePanel()
    if not picker then return false end
    if picker:IsShown() then picker:Hide(); return false end
    Attach(anchor)
    API.Refresh()
    picker:Show()
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

API.Testing = {
    GetPanel = function() return panel end,
    GetTargets = Targets,
    RowsPerPage = ROWS_PER_PAGE,
}
