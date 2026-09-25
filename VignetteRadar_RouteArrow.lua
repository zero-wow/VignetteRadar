local _, addon = ...
if type(addon) ~= "table" then return end

local API = {}
addon.VignetteRadarRouteArrow = API

local frame
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

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
            x = left * scale, y = top * scale - UIParent:GetHeight() }
    end
end

local function SetColor(kind)
    local style = addon.VignetteRadarStyle
    local revision = style and style.revision or -1
    if frame.kind == kind and frame.styleRevision == revision then return end
    frame.kind, frame.styleRevision = kind, revision
    local r, g, b = .05, .82, .62
    if style and style.Color then r, g, b = style.Color(kind or "accent") end
    frame.outer:SetVertexColor(r, g, b, .17)
    frame.rim:SetVertexColor(r, g, b, .62)
    frame.inner:SetVertexColor(r, g, b, .18)
    frame.distance:SetTextColor(r, g, b, .95)
    for _, line in ipairs(frame.arrow) do
        line:SetColorTexture(r, g, b, 1)
    end
end

local function PointLine(line, firstX, firstY, lastX, lastY)
    line:SetStartPoint("CENTER", frame, firstX, firstY + 5)
    line:SetEndPoint("CENTER", frame, lastX, lastY + 5)
end

local function DrawBearing(dx, dy, facing)
    local angle = atan2(dy, dx) - facing
    local forwardX, forwardY = -math.sin(angle), math.cos(angle)
    local rightX, rightY = -forwardY, forwardX
    PointLine(frame.arrow[1], -forwardX * 12, -forwardY * 12,
        forwardX * 6, forwardY * 6)
    PointLine(frame.arrow[2], -forwardX * 2 + rightX * 9,
        -forwardY * 2 + rightY * 9, forwardX * 13, forwardY * 13)
    PointLine(frame.arrow[3], -forwardX * 2 - rightX * 9,
        -forwardY * 2 - rightY * 9, forwardX * 13, forwardY * 13)
end

local function Ensure()
    if frame then return frame end
    frame = CreateFrame("Button", "VignetteRadarRouteArrow", UIParent)
    frame:SetSize(58, 58)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("RightButtonUp")
    frame.outer = frame:CreateTexture(nil, "BACKGROUND")
    frame.outer:SetSize(58, 58)
    frame.outer:SetPoint("CENTER")
    frame.outer:SetTexture(CIRCLE)
    frame.rim = frame:CreateTexture(nil, "BORDER")
    frame.rim:SetSize(52, 52)
    frame.rim:SetPoint("CENTER")
    frame.rim:SetTexture(CIRCLE)
    frame.face = frame:CreateTexture(nil, "ARTWORK")
    frame.face:SetSize(49, 49)
    frame.face:SetPoint("CENTER")
    frame.face:SetTexture(CIRCLE)
    frame.face:SetVertexColor(.025, .033, .04, .94)
    frame.inner = frame:CreateTexture(nil, "ARTWORK")
    frame.inner:SetSize(37, 37)
    frame.inner:SetPoint("CENTER", 0, 4)
    frame.inner:SetTexture(CIRCLE)
    frame.arrow = {}
    for index = 1, 3 do
        local line = frame:CreateLine(nil, "OVERLAY")
        line:SetThickness(index == 1 and 2.2 or 2.5)
        frame.arrow[index] = line
    end
    frame.distance = frame:CreateFontString(nil, "OVERLAY")
    frame.distance:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    frame.distance:SetSize(48, 12)
    frame.distance:SetPoint("BOTTOM", 0, 4)
    frame.distance:SetJustifyH("CENTER")
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
    local step, kind = focus.GetRoutePoint()
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
    if frame.lastDistance ~= rounded then
        frame.lastDistance = rounded
        frame.distance:SetText(rounded < 10000 and (rounded .. " yd")
            or (math.floor(rounded / 1000 + .5) .. "k yd"))
    end
    if not frame:IsShown() then frame:Show() end
end

function API.ResetPosition()
    Settings().vignetteRadarRouteArrowPosition = nil
    if frame then frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, -120) end
end

function API.GetFrame() return frame end
