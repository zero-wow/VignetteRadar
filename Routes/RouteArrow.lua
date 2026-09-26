local _, addon = ...
if type(addon) ~= "table" then return end

local API = {}
addon.VignetteRadarRouteArrow = API

local frame
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local POINTER = "Interface\\AddOns\\VignetteRadar\\Media\\route-nav-chevron.tga"
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
    -- Keep the tiny directional art neutral and let the status surface carry color.
    frame.pointer:SetVertexColor(1, 1, 1, 1)
    frame.node.mark:SetVertexColor(r, g, b, 1)
    frame.node.meta:SetTextColor(.72, .81, .83, 1)
    local controls = addon.VignetteRadarControls
    if controls and controls.RefreshRoundedStatusSurface then
        controls.RefreshRoundedStatusSurface(frame.node)
        for _, edge in ipairs(frame.node.statusSurface.edge) do
            edge:SetVertexColor(r, g, b, .38)
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
    frame:SetSize(160, 86)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame.pointer = frame:CreateTexture(nil, "OVERLAY")
    frame.pointer:SetTexture(POINTER)
    frame.pointer:SetSize(16, 16)
    frame.pointer:SetPoint("TOP", frame, "TOP", 0, -2)
    frame.node = CreateFrame("Frame", nil, frame)
    frame.node:SetSize(160, 30)
    frame.node:SetPoint("TOP", frame, "TOP", 0, -34)
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
    frame.next = frame:CreateFontString(nil, "OVERLAY")
    frame.next:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    frame.next:SetSize(142, 15)
    frame.next:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -68)
    frame.next:SetJustifyH("LEFT")
    frame.next:SetWordWrap(false)
    frame.next:SetTextColor(.70, .79, .81, 1)
    frame.horizon = CreateFrame("Frame", nil, frame)
    frame.horizon:SetSize(160, 102)
    frame.horizon:SetPoint("TOP", frame, "TOP", 0, -88)
    if controls and controls.RoundedStatusSurface then
        controls.RoundedStatusSurface(frame.horizon)
    end
    frame.horizon.title = frame.horizon:CreateFontString(nil, "OVERLAY")
    frame.horizon.title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    frame.horizon.title:SetPoint("TOPLEFT", frame.horizon, "TOPLEFT", 9, -7)
    frame.horizon.title:SetText("Next (Preview)")
    frame.horizon.why = controls.Button(frame.horizon, "Why?", 38, 16)
    frame.horizon.why:SetPoint("TOPRIGHT", frame.horizon, "TOPRIGHT", -7, -4)
    frame.horizon.why:SetScript("OnClick", function()
        local focus = addon.VignetteRadarWorldFocus
        local reason = focus and focus.ExplainActive and focus.ExplainActive()
            or "No active destination"
        if addon.ShowVignetteRadarRouteNote then
            addon.ShowVignetteRadarRouteNote("WHY THIS STOP", reason)
        end
    end)
    frame.horizon.why:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Why This Stop", 1, 1, 1)
        local focus = addon.VignetteRadarWorldFocus
        GameTooltip:AddLine(focus and focus.ExplainActive and focus.ExplainActive()
            or "No active destination", .7, .82, .84, true)
        GameTooltip:Show()
    end)
    frame.horizon.why:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    frame.horizon.rows = {}
    for index = 1, 3 do
        local row = frame.horizon:CreateFontString(nil, "OVERLAY")
        row:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        row:SetPoint("TOPLEFT", frame.horizon, "TOPLEFT", 9, -22 - (index - 1) * 17)
        row:SetSize(142, 13)
        row:SetJustifyH("LEFT")
        row:SetWordWrap(false)
        frame.horizon.rows[index] = row
    end
    frame.horizon.lock = controls.Button(frame.horizon, "Lock Stop", 68, 17)
    frame.horizon.lock:SetPoint("BOTTOMLEFT", frame.horizon, "BOTTOMLEFT", 8, 5)
    frame.horizon.lock:SetScript("OnClick", function()
        local focus = addon.VignetteRadarWorldFocus
        if focus and focus.ToggleRouteLock then focus.ToggleRouteLock() end
        API.Refresh()
    end)
    frame.horizon.skip = controls.Button(frame.horizon, "Skip Stop", 68, 17)
    frame.horizon.skip:SetPoint("BOTTOMRIGHT", frame.horizon, "BOTTOMRIGHT", -8, 5)
    frame.horizon.skip:SetScript("OnClick", function()
        local focus = addon.VignetteRadarWorldFocus
        if focus and focus.SkipRouteStop then focus.SkipRouteStop() end
        API.Refresh()
    end)
    frame.horizon:Hide()
    frame:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Auto Route", 1, 1, 1)
        local focus = addon.VignetteRadarWorldFocus
        if focus and focus.Status then GameTooltip:AddLine(focus.Status(), .72, .82, .84, true) end
        if focus and focus.ExplainActive then
            GameTooltip:AddLine(focus.ExplainActive(), .67, .83, .79, true)
        end
        GameTooltip:AddLine("Click for upcoming stops. Drag to move; right-click for Auto Route settings.", .6, .7, .72, true)
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
        elseif button == "LeftButton" then
            Settings().vignetteRadarRouteHorizonExpanded =
                Settings().vignetteRadarRouteHorizonExpanded ~= true
            API.Refresh()
        end
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        self.bearingElapsed = (self.bearingElapsed or 0) + elapsed
        if self.bearingElapsed >= .033 then
            self.bearingElapsed = 0
            if Number(self.routeDX) and Number(self.routeDY)
                and type(GetPlayerFacing) == "function" then
                local ok, facing = pcall(GetPlayerFacing)
                if ok and Number(facing) then DrawBearing(self.routeDX, self.routeDY, facing) end
            end
        end
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
    frame.routeDX, frame.routeDY = dx, dy
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
    if kind == "quest" and step.availableStart then kindTitle = "Quest Start" end
    if kind == "treasure" and Number(routeCount) and routeCount > 1 then
        kindTitle = routeIndex == 1 and "Entrance"
            or routeIndex < routeCount and "Approach" or "Treasure"
    end
    local progress = Number(routeIndex) and Number(routeCount) and routeCount > 1
        and (" " .. routeIndex .. "/" .. routeCount) or ""
    local yards = rounded < 10000 and (rounded .. " yd")
        or (math.floor(rounded / 1000 + .5) .. "k yd")
    local cueText
    if settings.vignetteRadarSoundCompassEnabled then
        local runtime = addon.VignetteRadarFeatureRuntime
        local compass = runtime and runtime.GetSoundCompass and runtime.GetSoundCompass()
        if compass then
            local angle = atan2(dy, dx) - player.facing
            angle = atan2(math.sin(angle), math.cos(angle)) * 180 / math.pi
            local inCombat = type(InCombatLockdown) == "function" and InCombatLockdown() == true
            local inInstance = type(IsInInstance) == "function" and IsInInstance() == true
            local cueState = compass:Update({ id = tostring(step.key or step.questID or name),
                name = name, relativeDegrees = angle, distance = distance,
                inCombat = inCombat, inInstance = inInstance },
                type(GetTime) == "function" and GetTime() or 0, function(cue)
                    if cue.mode ~= "tone" or type(PlaySound) ~= "function" or not SOUNDKIT then
                        return false
                    end
                    local sound = cue.kind == "left" and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
                        or cue.kind == "right" and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
                        or SOUNDKIT.TELL_MESSAGE
                    if not sound then return false end
                    local ok = pcall(PlaySound, sound, "SFX")
                    return ok
                end)
            cueText = cueState and cueState.directionText
        end
    end
    local meta = "Now · " .. (cueText and (cueText .. " · ") or "")
        .. kindTitle .. progress .. " · " .. yards
    if frame.nodeMeta ~= meta then
        frame.nodeMeta = meta
        frame.node.meta:SetText(meta)
    end
    local expanded = settings.vignetteRadarRouteHorizonExpanded == true
    local wantedHeight = expanded and 192 or 86
    if frame:GetHeight() ~= wantedHeight then
        frame:SetHeight(wantedHeight)
        local scale = frame:GetScale()
        local left, top = Number(frame:GetLeft()), Number(frame:GetTop())
        if left and top and Number(scale) then
            Place(left * scale, top * scale - UIParent:GetHeight())
        end
    end
    frame.horizon:SetShown(expanded)
    local upcoming = focus.GetHorizon and focus.GetHorizon() or {}
    frame.next:SetText(upcoming[2] and ("Next  " .. (upcoming[2].name or "Route Stop"))
        or "Next  —")
    if expanded then
        local controls = addon.VignetteRadarControls
        if controls and controls.RefreshRoundedStatusSurface then
            controls.RefreshRoundedStatusSurface(frame.horizon)
        end
        local focus = addon.VignetteRadarWorldFocus
        frame.horizon.title:SetTextColor(.88, .94, .95, 1)
        for index, row in ipairs(frame.horizon.rows) do
            local stop = upcoming[index]
            row:SetText(stop and ((index == 1 and "NOW  " or index == 2 and "NEXT  " or "THEN  ")
                .. (stop.name or stop.kind or "Point")) or "")
            row:SetTextColor(index == 1 and .96 or .7, index == 1 and .98 or .8,
                index == 1 and 1 or .83, 1)
        end
        frame.horizon.lock:SetText(focus and focus.IsRouteLocked and focus.IsRouteLocked()
            and "Unlock" or "Lock Stop")
    end
    if not frame:IsShown() then frame:Show() end
end

function API.ResetPosition()
    Settings().vignetteRadarRouteArrowPosition = nil
    if frame then frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, -120) end
end

function API.GetFrame() return frame end
