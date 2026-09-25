local _, addon = ...
if type(addon) ~= "table" then return end

local API = {}
addon.VignetteRadarRouteArrow = API

local frame
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local POINTER = "Interface\\AddOns\\VignetteRadar\\Media\\route-crystal-pointer.tga"
local KIND_TITLE = { quest = "Quest", treasure = "Treasure", rare = "Rare",
    boss = "World Boss", guide = "Zygor", zygor = "Zygor",
    exploration = "Map Note", event = "Event" }

local function Number(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function Settings() return addon.GetSettings() end

local function Place(x, y)
    if not (frame and UIParent) then return end
    local scale = frame:GetScale()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not (Number(scale) and scale > 0 and Number(width) and Number(height)) then return end
    local margin = 8
    x = math.max(margin, math.min(width - frame:GetWidth() * scale - margin, x))
    y = math.max(-height + frame:GetHeight() * scale + margin,
        math.min(-margin, y))
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x / scale, y / scale)
end

local function SavePosition()
    if not frame then return end
    local scale = frame:GetScale()
    local left, top = Number(frame:GetLeft()), Number(frame:GetTop())
    if not (Number(scale) and left and top) then return end
    local x, y = left * scale, top * scale - UIParent:GetHeight()
    Place(x, y)
    left, top = Number(frame:GetLeft()), Number(frame:GetTop())
    if left and top then
        Settings().vignetteRadarRouteArrowPosition = {
            x = left * scale, y = top * scale - UIParent:GetHeight(), layout = 2 }
    end
end

local function SetColor(kind)
    local style = addon.VignetteRadarStyle
    local revision = style and style.revision or -1
    if frame.kind == kind and frame.styleRevision == revision then return end
    frame.kind, frame.styleRevision = kind, revision
    local r, g, b = .05, .82, .62
    local slot = (kind == "guide" or kind == "zygor") and "accent" or kind
    if style and style.Color then r, g, b = style.Color(slot or "accent") end
    frame.pointer:SetVertexColor(r, g, b, 1)
    frame.node.mark:SetVertexColor(r, g, b, 1)
    frame.node.meta:SetTextColor(r, g, b, .96)
    local controls = addon.VignetteRadarControls
    if controls and controls.RefreshRoundedStatusSurface then
        controls.RefreshRoundedStatusSurface(frame.node)
        for _, edge in ipairs(frame.node.statusSurface.edge) do
            edge:SetVertexColor(r, g, b, .54)
        end
    end
end

local function DrawBearing(dx, dy, facing)
    local angle = atan2(dy, dx) - facing
    if frame.bearing ~= angle then
        frame.bearing = angle
        frame.pointer:SetRotation(angle)
    end
end

local function Ensure()
    if frame then return frame end
    frame = CreateFrame("Button", "VignetteRadarRouteArrow", UIParent)
    frame:SetSize(160, 52)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("RightButtonUp")
    frame.pointer = frame:CreateTexture(nil, "OVERLAY")
    frame.pointer:SetTexture(POINTER)
    frame.pointer:SetSize(16, 16)
    frame.pointer:SetPoint("TOP", frame, "TOP", 0, -2)
    frame.node = CreateFrame("Frame", nil, frame)
    frame.node:SetSize(160, 30)
    frame.node:SetPoint("TOP", frame, "TOP", 0, -22)
    local controls = addon.VignetteRadarControls
    if controls and controls.RoundedStatusSurface then
        controls.RoundedStatusSurface(frame.node)
    end
    frame.node.mark = frame.node:CreateTexture(nil, "ARTWORK")
    frame.node.mark:SetTexture(CIRCLE)
    frame.node.mark:SetSize(7, 7)
    frame.node.mark:SetPoint("LEFT", frame.node, "LEFT", 8, 0)
    frame.node.name = frame.node:CreateFontString(nil, "OVERLAY")
    frame.node.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    frame.node.name:SetSize(132, 12)
    frame.node.name:SetPoint("TOPLEFT", frame.node, "TOPLEFT", 21, -3)
    frame.node.name:SetJustifyH("LEFT")
    frame.node.name:SetWordWrap(false)
    frame.node.name:SetTextColor(.91, .94, .95, 1)
    frame.node.meta = frame.node:CreateFontString(nil, "OVERLAY")
    frame.node.meta:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    frame.node.meta:SetSize(132, 11)
    frame.node.meta:SetPoint("BOTTOMLEFT", frame.node, "BOTTOMLEFT", 21, 3)
    frame.node.meta:SetJustifyH("LEFT")
    frame:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Auto Route", 1, 1, 1)
        local focus = addon.VignetteRadarWorldFocus
        if focus and focus.Status then GameTooltip:AddLine(focus.Status(), .72, .82, .84, true) end
        GameTooltip:AddLine("Drag to move. Right-click for Auto Route settings.", .6, .7, .72, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    frame:SetScript("OnClick", function(self, button)
        if button == "RightButton" and addon.VignetteRadarQuickConfig
            and addon.VignetteRadarQuickConfig.OpenPage then
            addon.VignetteRadarQuickConfig.OpenPage("Auto Route", self)
        end
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= .2 then
            self.elapsed = 0
            API.Refresh()
        end
    end)
    local position = Settings().vignetteRadarRouteArrowPosition
    if type(position) == "table" and Number(position.x) and Number(position.y) then
        if position.layout ~= 2 then
            -- Keep the pointer near its former location as the label widens.
            position.x, position.y, position.layout = position.x - 51, position.y - 10, 2
        end
        Place(position.x, position.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    end
    frame:Hide()
    return frame
end

function API.Refresh()
    local settings = Settings()
    local focus = addon.VignetteRadarWorldFocus
    local radar = addon.VignetteRadarAPI
    if not (settings.vignetteRadarEnabled == true
        and settings.vignetteRadarRouteArrow == true
        and focus and focus.GetRoutePoint and radar and radar.GetPlayerSnapshot) then
        if frame then frame:Hide() end
        return
    end
    local step, kind, routeName, routeIndex, routeCount = focus.GetRoutePoint()
    if not (step and Number(step.worldX) and Number(step.worldY)) then
        if frame then frame:Hide() end
        return
    end
    local player = radar.GetPlayerSnapshot()
    if not (player and Number(player.worldX) and Number(player.worldY)
        and Number(player.facing))
        or (Number(step.instanceID) and Number(player and player.instanceID)
            and step.instanceID ~= player.instanceID) then
        if frame then frame:Hide() end
        return
    end
    local dx, dy = step.worldX - player.worldX, step.worldY - player.worldY
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 1 then
        if frame then frame:Hide() end
        return
    end
    Ensure()
    SetColor(kind)
    DrawBearing(dx, dy, player.facing)
    local rounded = math.floor(distance + .5)
    local name = type(step.name) == "string" and step.name ~= "" and step.name
        or type(routeName) == "string" and routeName ~= "" and routeName
        or "Route Stop"
    if frame.nodeName ~= name then
        frame.nodeName = name
        frame.node.name:SetText(name)
    end
    local kindTitle = KIND_TITLE[kind] or "Route"
    local progress = Number(routeIndex) and Number(routeCount) and routeCount > 1
        and (" " .. routeIndex .. "/" .. routeCount) or ""
    local yards = rounded < 10000 and (rounded .. " yd")
        or (math.floor(rounded / 1000 + .5) .. "k yd")
    local meta = kindTitle .. progress .. "  ·  " .. yards
    if frame.nodeMeta ~= meta then
        frame.nodeMeta = meta
        frame.node.meta:SetText(meta)
    end
    if not frame:IsShown() then frame:Show() end
end

function API.ResetPosition()
    Settings().vignetteRadarRouteArrowPosition = nil
    if frame then frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, -120) end
end

function API.GetFrame() return frame end
