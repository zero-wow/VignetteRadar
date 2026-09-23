local _, addon = ...
if type(addon) ~= "table" then return end

local PANEL_W, PANEL_H = 220, 278
local ZOOM_FOOTER_H = 26
local HEADER_H, FIELD_SIZE = 34, 200
local FIELD_RADIUS = (FIELD_SIZE / 2) - 9
local PLOT_RADIUS = FIELD_RADIUS - 15
local LAYOUTS = {
    classic = { width = 220, height = 278, field = 200, footer = 26, focus = 46 },
    squat = { width = 374, height = 230, field = 184 },
    compact = { width = 184, height = 260, field = 164, footer = 50, focus = 64 },
}
local LAUNCHER_SIZE, LAUNCHER_RADIUS, LAUNCHER_RANGE = 44, 13, 150
local UPDATE_SECONDS, RESCAN_SECONDS = 0.05, 1
local MAX_BLIPS = 64
local ACCENT = { 0.05, 0.82, 0.62 }
local RED = { 1, 0.18, 0.14 }
local CIRCLE_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SKULL_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local LAUNCHER_BEZEL = "Interface\\AddOns\\VignetteRadar\\Media\\vignette-radar-bezel.tga"
local LAUNCHER_CLOSED = "Interface\\AddOns\\VignetteRadar\\Media\\vignette-radar-closed.tga"
local TWO_PI = math.pi * 2
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local Unpack = unpack or table.unpack

local panel, launcher
local preview = false
local manualPanelState
local activeTargets = {}
local activeMapID
local activeWorldMapMode
local pulseUntil = 0
local RefreshRadar, ScanVignettes, Render, UpdateLauncher, EnsureLauncher
local PREVIEW_TARGETS = {
    { key = "preview-rare", x = 28, y = 52, launcherX = 3, launcherY = 6,
        distanceFactor = 0.34, name = "Sample rare", category = "rare", sample = true },
    { key = "preview-treasure", x = -58, y = -14, launcherX = -6, launcherY = -2,
        distanceFactor = 0.58, name = "Sample treasure", category = "treasure", atlasName = "VignetteLoot", sample = true },
    { key = "preview-event", x = 49, y = -45, launcherX = 5, launcherY = -5,
        distanceFactor = 0.52, name = "Sample event", category = "event", sample = true },
    { key = "preview-boss", x = -18, y = -50, launcherX = -4, launcherY = -6,
        distanceFactor = 0.70, name = "Sample world boss", category = "rare", isWorldBoss = true, sample = true },
}

local function Settings()
    return addon.GetSettings()
end

local function ViewFacing(facing)
    return Settings().vignetteRadarNorthUp == true and 0 or facing
end

local function PreviewPosition(x, y)
    local angle = Settings().vignetteRadarNorthUp == true and 0.65 or 0
    return x * math.cos(angle) - y * math.sin(angle), x * math.sin(angle) + y * math.cos(angle)
end

local function DrawPlayerHeading(line, frame, facing, innerRadius, outerRadius)
    local angle = facing - ViewFacing(facing)
    local x, y = -math.sin(angle), math.cos(angle)
    line:SetStartPoint("CENTER", frame, "CENTER", x * innerRadius, y * innerRadius)
    line:SetEndPoint("CENTER", frame, "CENTER", x * outerRadius, y * outerRadius)
end

local function Ranges()
    return addon.VignetteRadarRanges or { 150, 300, 450, 600, 1200, 2400, 4800 }
end

local function StepRange(step)
    local ranges, current = Ranges(), Settings().vignetteRadarRange
    for index, value in ipairs(ranges) do
        if current == value then
            local nextIndex = math.max(1, math.min(#ranges, index + step))
            addon.SetVignetteRadarRange(ranges[nextIndex])
            return
        end
    end
end

local function OnZoomWheel(_, delta)
    if delta > 0 then StepRange(-1) elseif delta < 0 then StepRange(1) end
end

local function Features()
    return addon.VignetteRadarFeatures
end

local function Now()
    return GetTime and GetTime() or 0
end

local function Quiet()
    return not preview and Features() and Features().IsQuiet() or false
end

local function Ignored(target)
    return Features() and Features().IsIgnored(target) or false
end

local function Favorite(target)
    if target.favorite ~= nil then return target.favorite == true end
    return Features() and Features().IsFavorite(target) or false
end

local function TargetAlpha(target)
    if not target.stale then return 1 end
    local duration = math.max(1, (target.expiresAt or 0) - (target.lastSeenAt or 0))
    return math.max(0, math.min(0.65, ((target.expiresAt or 0) - Now()) / duration * 0.65))
end

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) or false
end

local function SafeField(object, key)
    if object == nil or IsSecret(object) then return nil end
    local ok, value = pcall(function() return object[key] end)
    if not ok or IsSecret(value) then return nil end
    return value
end

local function SafeNumber(value)
    if IsSecret(value) or type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function SafeString(value)
    if IsSecret(value) or type(value) ~= "string" or value == "" then return nil end
    return value
end

local function SafeBoolean(value)
    if IsSecret(value) or type(value) ~= "boolean" then return nil end
    return value
end

local function Call(func, ...)
    if type(func) ~= "function" then return nil end
    local results = { pcall(func, ...) }
    if not results[1] then return nil end
    return Unpack(results, 2)
end

local function ReadXY(vector)
    if vector == nil or IsSecret(vector) then return nil end
    local x, y = SafeNumber(SafeField(vector, "x")), SafeNumber(SafeField(vector, "y"))
    if x and y then return x, y end
    local getXY = SafeField(vector, "GetXY")
    if type(getXY) ~= "function" then return nil end
    local ok, vx, vy = pcall(getXY, vector)
    if not ok then return nil end
    return SafeNumber(vx), SafeNumber(vy)
end

local function MapToWorld(mapID, mapPosition)
    if not (C_Map and C_Map.GetWorldPosFromMapPos) then return nil end
    local instanceID, worldPosition = Call(C_Map.GetWorldPosFromMapPos, mapID, mapPosition)
    local worldX, worldY = ReadXY(worldPosition)
    if not worldX or not worldY then return nil end
    return worldX, worldY, SafeNumber(instanceID)
end

local function CurrentMapID()
    return C_Map and C_Map.GetBestMapForUnit
        and SafeNumber(Call(C_Map.GetBestMapForUnit, "player")) or nil
end

local function PlayerSnapshot(mapID)
    if not (mapID and C_Map and C_Map.GetPlayerMapPosition) then return nil end
    local mapPosition = Call(C_Map.GetPlayerMapPosition, mapID, "player")
    local mapX, mapY = ReadXY(mapPosition)
    if not mapX or not mapY then return nil end
    local worldX, worldY, instanceID = MapToWorld(mapID, mapPosition)
    if not worldX or not worldY then return nil end
    local facing = GetPlayerFacing and SafeNumber(Call(GetPlayerFacing)) or nil
    return {
        mapID = mapID,
        mapX = mapX,
        mapY = mapY,
        worldX = worldX,
        worldY = worldY,
        instanceID = instanceID,
        facing = facing or 0,
        headingAvailable = facing ~= nil,
    }
end

local function DisplayableVignetteInfo(info, includeWorldMap)
    if info == nil or SafeBoolean(SafeField(info, "isDead")) == true then return false end
    if SafeBoolean(SafeField(info, "onMinimap")) == true then return true end
    return includeWorldMap == true and SafeBoolean(SafeField(info, "onWorldMap")) == true
        and SafeBoolean(SafeField(info, "inFogOfWar")) == false
end

local function ClassifyVignette(info)
    local vignetteType = SafeField(info, "type")
    local vignetteTypes = Enum and Enum.VignetteType
    if vignetteTypes then
        if vignetteTypes.Treasure ~= nil and vignetteType == vignetteTypes.Treasure then return "treasure" end
        if vignetteTypes.Rare ~= nil and vignetteType == vignetteTypes.Rare then return "rare" end
        if vignetteTypes.Event ~= nil and vignetteType == vignetteTypes.Event then return "event" end
    end

    local atlasName = (SafeString(SafeField(info, "atlasName")) or ""):lower()
    if atlasName:find("treasure", 1, true) or atlasName:find("chest", 1, true)
        or atlasName:find("container", 1, true) or atlasName:find("loot", 1, true) then
        return "treasure"
    end
    if atlasName:find("rare", 1, true) or atlasName:find("vignettekill", 1, true)
        or atlasName:find("skull", 1, true) then
        return "rare"
    end
    if atlasName:find("event", 1, true) or atlasName:find("horn", 1, true) then
        return "event"
    end
    return "other"
end

local function CollectVignettes(mapID)
    local targets = {}
    if not (mapID and C_VignetteInfo and C_VignetteInfo.GetVignettes
        and C_VignetteInfo.GetVignetteInfo and C_VignetteInfo.GetVignettePosition) then
        return targets
    end
    local vignetteGUIDs = Call(C_VignetteInfo.GetVignettes)
    if IsSecret(vignetteGUIDs) or type(vignetteGUIDs) ~= "table" then return targets end
    local includeWorldMap = Settings().vignetteRadarWorldMap ~= false
    -- Honor maps where Blizzard explicitly suppresses world-map vignette pins.
    if includeWorldMap and C_Map.GetMapInfo and FlagsUtil and FlagsUtil.IsSet and Enum and Enum.UIMapFlag then
        local flags = SafeNumber(SafeField(Call(C_Map.GetMapInfo, mapID), "flags"))
        local hiddenFlag = SafeNumber(Enum.UIMapFlag.HideVignettes)
        if flags and hiddenFlag and Call(FlagsUtil.IsSet, flags, hiddenFlag) == true then includeWorldMap = false end
    end
    for index = 1, math.min(#vignetteGUIDs, 512) do
        local guid = vignetteGUIDs[index]
        if guid ~= nil and not IsSecret(guid) then
            local info = Call(C_VignetteInfo.GetVignetteInfo, guid)
            if DisplayableVignetteInfo(info, includeWorldMap) then
                local mapPosition = Call(C_VignetteInfo.GetVignettePosition, guid, mapID)
                local mapX, mapY = ReadXY(mapPosition)
                local worldX, worldY, instanceID = MapToWorld(mapID, mapPosition)
                if mapX and mapY and worldX and worldY then
                    local worldBoss = Features() and Features().IsWorldBoss(info) or false
                    targets[#targets + 1] = {
                        key = tostring(guid),
                        vignetteID = SafeNumber(SafeField(info, "vignetteID")),
                        mapID = mapID,
                        mapX = mapX,
                        mapY = mapY,
                        name = SafeString(SafeField(info, "name")) or "Detected vignette",
                        category = worldBoss and "rare" or ClassifyVignette(info),
                        isWorldBoss = worldBoss,
                        source = SafeBoolean(SafeField(info, "onMinimap")) == true and "minimap" or "worldMap",
                        vignetteType = SafeField(info, "type"),
                        atlasName = SafeString(SafeField(info, "atlasName")),
                        worldX = worldX,
                        worldY = worldY,
                        instanceID = instanceID,
                    }
                    -- Collect beyond the visible pool so ignored entries cannot starve useful ones.
                end
            end
        end
    end
    -- Nearby entries get first claim on the bounded state pool in crowded zones.
    local player = PlayerSnapshot(mapID)
    for _, target in ipairs(targets) do
        target.favorite = Features() and Features().IsFavorite(target) or false
        if player and (not player.instanceID or not target.instanceID or player.instanceID == target.instanceID) then
            local dx, dy = target.worldX - player.worldX, target.worldY - player.worldY
            target.distance = math.sqrt(dx * dx + dy * dy)
        end
    end
    table.sort(targets, function(left, right)
        if left.favorite ~= right.favorite then return left.favorite end
        if left.source ~= right.source then return left.source == "minimap" end
        if left.isWorldBoss ~= right.isWorldBoss then return left.isWorldBoss end
        if left.distance ~= right.distance then return (left.distance or math.huge) < (right.distance or math.huge) end
        return left.key < right.key
    end)
    return targets
end

local function NormalizeAngle(angle)
    angle = angle % TWO_PI
    if angle > math.pi then angle = angle - TWO_PI end
    return angle
end

local function Project(dx, dy, distance, facing, pixelRadius, rangeYards)
    if not (SafeNumber(dx) and SafeNumber(dy) and SafeNumber(distance)
        and SafeNumber(facing) and SafeNumber(pixelRadius) and SafeNumber(rangeYards))
        or rangeYards <= 0 then return nil end
    local relative = NormalizeAngle(atan2(dy, dx) - facing)
    local radius = (distance / rangeYards) * pixelRadius
    return -math.sin(relative) * radius, math.cos(relative) * radius
end

addon.VignetteRadarTesting = {
    ClassifyVignette = ClassifyVignette,
    CollectVignettes = CollectVignettes,
    DisplayableVignetteInfo = DisplayableVignetteInfo,
    NormalizeAngle = NormalizeAngle,
    Project = Project,
}

local function Text(parent, size, value, accent)
    local label = parent:CreateFontString(nil, "OVERLAY")
    local font = EllesmereUI and (EllesmereUI.EXPRESSWAY or EllesmereUI._font)
        or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    label:SetFont(font or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
    label:SetTextColor(accent and ACCENT[1] or 0.88, accent and ACCENT[2] or 0.90,
        accent and ACCENT[3] or 0.92, 1)
    label:SetText(value or "")
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    return label
end

local function Surface(frame, alpha)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.045, 0.052, 0.06, alpha or 0.96)
    frame:SetBackdropBorderColor(1, 1, 1, 0.15)
end

local function AddRing(field, radius, alpha)
    local lines = {}
    for index = 1, 64 do
        local line = field:CreateLine(nil, "BORDER")
        local first = ((index - 1) / 64) * TWO_PI
        local last = (index / 64) * TWO_PI
        line:SetThickness(1)
        line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], alpha)
        line:SetStartPoint("CENTER", field, "CENTER", math.cos(first) * radius, math.sin(first) * radius)
        line:SetEndPoint("CENTER", field, "CENTER", math.cos(last) * radius, math.sin(last) * radius)
        lines[index] = line
    end
    return lines
end

local function ResizeRing(lines, field, radius)
    for index, line in ipairs(lines) do
        local first, last = ((index - 1) / #lines) * TWO_PI, (index / #lines) * TWO_PI
        line:SetStartPoint("CENTER", field, "CENTER", math.cos(first) * radius, math.sin(first) * radius)
        line:SetEndPoint("CENTER", field, "CENTER", math.cos(last) * radius, math.sin(last) * radius)
    end
end

local function LegendAPI()
    return type(addon.VignetteRadarLegend) == "table" and addon.VignetteRadarLegend or nil
end

local function TargetPickerAPI()
    return type(addon.VignetteRadarTargetPicker) == "table" and addon.VignetteRadarTargetPicker or nil
end

local function CategoryEnabled(category)
    local legend = LegendAPI()
    if not (legend and type(legend.IsCategoryEnabled) == "function") then return true end
    local ok, enabled = pcall(legend.IsCategoryEnabled, category or "other")
    return not ok or enabled ~= false
end

local function CategoryColor(category)
    local legend = LegendAPI()
    if legend and type(legend.ColorFor) == "function" then
        local ok, r, g, b = pcall(legend.ColorFor, category or "other")
        if ok and SafeNumber(r) and SafeNumber(g) and SafeNumber(b) then return r, g, b end
    end
    return RED[1], RED[2], RED[3]
end

local function TargetColor(target)
    if target.isWorldBoss then return 1, 0.18, 0.12 end
    return CategoryColor(target.category)
end

local function TargetKind(target)
    if target.isWorldBoss then return "World boss" end
    if target.category == "rare" then return "Rare enemy" end
    if target.category == "treasure" then return "Treasure" end
    if target.category == "event" then return "Event" end
    return "Other detection"
end

local function HighlightCategory()
    local legend = LegendAPI()
    if not (legend and type(legend.GetHighlight) == "function") then return nil end
    local ok, category = pcall(legend.GetHighlight)
    return ok and SafeString(category) or nil
end

local function CategoryOpacity(category)
    local legend = LegendAPI()
    if legend and type(legend.OpacityFor) == "function" then
        local ok, alpha = pcall(legend.OpacityFor, category or "other")
        if ok and SafeNumber(alpha) then return alpha end
    end
    local highlight = HighlightCategory()
    return highlight and highlight ~= (category or "other") and 0.18 or 1
end

local function FocusedTargetKey()
    local picker = TargetPickerAPI()
    if not (picker and type(picker.GetFocus) == "function") then return nil end
    local ok, key = pcall(picker.GetFocus)
    return ok and SafeString(key) or nil
end

local function TargetVisible(target)
    if not (target and CategoryEnabled(target.category)) or Ignored(target) or TargetAlpha(target) <= 0 then return false end
    local focusedKey = FocusedTargetKey()
    return not focusedKey or focusedKey == target.key
end

local function SelectableTargets()
    local output = {}
    local player = not preview and PlayerSnapshot(CurrentMapID()) or nil
    local source = preview and PREVIEW_TARGETS or activeTargets
    local previewRange = tonumber(Settings().vignetteRadarRange) or 450
    for _, target in ipairs(source) do
        if CategoryEnabled(target.category) and not Ignored(target) and TargetAlpha(target) > 0 then
            if preview then
                target.distance = previewRange * target.distanceFactor
            elseif player and not (player.instanceID and target.instanceID and player.instanceID ~= target.instanceID) then
                local dx, dy = target.worldX - player.worldX, target.worldY - player.worldY
                target.distance = math.sqrt((dx * dx) + (dy * dy))
            else
                target.distance = nil
            end
            target.red, target.green, target.blue = TargetColor(target)
            output[#output + 1] = target
        end
    end
    table.sort(output, function(left, right)
        if Favorite(left) ~= Favorite(right) then return Favorite(left) end
        if (left.stale == true) ~= (right.stale == true) then return not left.stale end
        if (left.isWorldBoss == true) ~= (right.isWorldBoss == true) then return left.isWorldBoss == true end
        if type(left.distance) == "number" and type(right.distance) == "number" and left.distance ~= right.distance then
            return left.distance < right.distance
        end
        return (left.name or left.key or "") < (right.name or right.key or "")
    end)
    return output
end

-- The same explicit gestures work on the radar and in the target list.
function addon.HandleVignetteClick(target, button)
    if not target then return false end
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    local alt = IsAltKeyDown and IsAltKeyDown()
    local features = Features()
    if button == "RightButton" then
        if not features then return false end
        if not target.sample then features.Ignore(target, shift == true) end
    elseif shift and features then
        local ok, reason = features.Navigate(target)
        if not ok and reason then
            local messages = {
                ["not-live"] = "Navigation needs a current live detection.",
                ["no-map-position"] = "This detection has no usable map position.",
                ["waypoint-unavailable"] = "Navigation is unavailable on this map.",
                ["waypoint-failed"] = "The game could not set a waypoint for this detection.",
            }
            reason = messages[reason] or "This detection cannot be tracked right now."
            if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(reason, 1, 0.65, 0.25)
            elseif DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("Vignette Radar: " .. reason) end
        end
        return ok, reason
    elseif alt and features then
        if not target.sample then features.ToggleFavorite(target) end
    else
        local picker = TargetPickerAPI()
        if picker then
            if picker.GetFocus() == target.key then picker.ClearFocus()
            else picker.SetFocus(target.key, target.name) end
        end
        return true
    end
    RefreshRadar(true)
    return true
end

local function ReconcileFocusedTarget()
    local picker = TargetPickerAPI()
    if picker and type(picker.ValidateTargets) == "function" then
        pcall(picker.ValidateTargets, SelectableTargets())
    end
end

local function UpdateTargetButton()
    if not (panel and panel.target) then return end
    local focusedKey = FocusedTargetKey()
    local red, green, blue = ACCENT[1], ACCENT[2], ACCENT[3]
    if focusedKey then
        for _, target in ipairs(SelectableTargets()) do
            if target.key == focusedKey then
                red, green, blue = TargetColor(target)
                break
            end
        end
    end
    panel.target.dot:SetVertexColor(red, green, blue, 1)
    panel.target.glow:SetVertexColor(red, green, blue, focusedKey and 0.20 or 0.05)
    panel.target:SetAlpha(focusedKey and 1 or 0.68)
end

local function Tooltip(owner)
    local target = owner.target
    if not (target and GameTooltip) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(target.name or "Detected vignette", 1, 1, 1)
    local r, g, b = TargetColor(target)
    GameTooltip:AddLine(TargetKind(target), r, g, b)
    if target.distance then
        GameTooltip:AddLine(math.floor(target.distance + 0.5) .. " yd from you", 0.72, 0.76, 0.78)
    end
    if FocusedTargetKey() == target.key then
        GameTooltip:AddLine("Specific vignette focus is active.", ACCENT[1], ACCENT[2], ACCENT[3])
    end
    if Favorite(target) then GameTooltip:AddLine("Favorite", 1, 0.82, 0.30) end
    if target.stale then
        GameTooltip:AddLine("Last seen " .. math.floor(math.max(0, Now() - target.lastSeenAt)) .. " seconds ago; not a live detection.", 0.75, 0.75, 0.75, true)
    end
    if target.sample then
        GameTooltip:AddLine("Layout preview; this is not a live detection.", 0.55, 0.86, 0.76, true)
    elseif not target.stale then
        GameTooltip:AddLine(target.source == "worldMap" and "Shown on Blizzard's world map; availability follows the game."
            or "Shown from Blizzard's active minimap vignette data.", 0.55, 0.86, 0.76, true)
    end
    GameTooltip:AddLine("Click: focus; click again to show all.", 0.65, 0.80, 0.77, true)
    if not target.sample then
        if not target.stale then GameTooltip:AddLine("Shift-click: navigate.", 0.65, 0.80, 0.77, true) end
        GameTooltip:AddLine("Alt-click: favorite. Right-click: ignore this session.", 0.65, 0.80, 0.77, true)
        GameTooltip:AddLine("Shift-right-click: remember ignore.", 0.65, 0.80, 0.77, true)
    end
    GameTooltip:Show()
end

local SHAPES = {
    treasure = { { 0, 0.62 }, { 0.62, 0 }, { 0, -0.62 }, { -0.62, 0 } },
    event = { { -0.5, 0.5 }, { 0.5, 0.5 }, { 0.5, -0.5 }, { -0.5, -0.5 } },
}

-- Use familiar game imagery first, with vector fallbacks for missing client art.
local function StyleMarker(owner, dot, target, size, r, g, b)
    owner.shapeLines = owner.shapeLines or {}
    local icons = Settings().vignetteRadarShapes ~= false
    local points = icons and SHAPES[target.category] or nil
    dot:SetTexture(CIRCLE_TEXTURE)
    local iconSize, nativeIcon = size, false
    if icons and target.category == "rare" then
        dot:SetTexture(SKULL_TEXTURE)
        iconSize = size + (owner.isMini and 2 or 5) + (target.isWorldBoss and 2 or 0)
        nativeIcon, points = true, nil
    elseif icons and not owner.isMini and target.atlasName and dot.SetAtlas then
        local atlas = C_Texture and C_Texture.GetAtlasInfo and Call(C_Texture.GetAtlasInfo, target.atlasName)
        if atlas and pcall(dot.SetAtlas, dot, target.atlasName) then
            iconSize, nativeIcon, points = size + 5, true, nil
        end
    end
    if target.stale and not points then
        points = { { 0, 0.6 }, { 0.6, 0 }, { 0, -0.6 }, { -0.6, 0 } }
    end
    for index = 1, 4 do
        local line = owner.shapeLines[index]
        if points and points[index] then
            if not line then
                line = owner:CreateLine(nil, "OVERLAY")
                owner.shapeLines[index] = line
            end
            local first, last = points[index], points[index % #points + 1]
            line:SetThickness(size < 5 and 1 or 1.3)
            line:SetColorTexture(r, g, b, 1)
            line:SetStartPoint("CENTER", owner, "CENTER", first[1] * size, first[2] * size)
            line:SetEndPoint("CENTER", owner, "CENTER", last[1] * size, last[2] * size)
            line:Show()
        elseif line then line:Hide() end
    end
    dot:SetSize(points and math.max(2, size * 0.35) or iconSize, points and math.max(2, size * 0.35) or iconSize)
    -- Skull silhouettes take category color; other native icons retain their own familiar colors.
    if nativeIcon and target.category ~= "rare" then dot:SetVertexColor(1, 1, 1, 1)
    else dot:SetVertexColor(r, g, b, 1) end
    dot:SetShown(not target.stale)
end

local function DrawArrow(frame, x, y, r, g, b)
    local length = math.sqrt(x * x + y * y)
    if length < 0.001 then x, y, length = 0, 1, 1 end
    local ux, uy = x / length, y / length
    frame.lines = frame.lines or {}
    for index = 1, 2 do
        local line = frame.lines[index]
        if not line then line = frame:CreateLine(nil, "OVERLAY"); frame.lines[index] = line end
        local side = index == 1 and -1 or 1
        line:SetThickness(2)
        line:SetColorTexture(r, g, b, 1)
        line:SetStartPoint("CENTER", frame, "CENTER", ux * 5, uy * 5)
        line:SetEndPoint("CENTER", frame, "CENTER", -ux * 4 - uy * side * 4, -uy * 4 + ux * side * 4)
    end
end

local function AcquireBlip()
    local blip = table.remove(panel.freeBlips)
    if not blip then
        if #panel.blips >= MAX_BLIPS then return nil end
        blip = CreateFrame("Button", nil, panel.field)
        blip:SetSize(11, 11)
        blip:SetFrameLevel(panel.field:GetFrameLevel() + 4)
        blip.glow = blip:CreateTexture(nil, "BACKGROUND")
        blip.glow:SetAllPoints()
        blip.glow:SetTexture(CIRCLE_TEXTURE)
        blip.glow:SetVertexColor(RED[1], RED[2], RED[3], 0.28)
        blip.dot = blip:CreateTexture(nil, "ARTWORK")
        blip.dot:SetSize(6, 6)
        blip.dot:SetPoint("CENTER")
        blip.dot:SetTexture(CIRCLE_TEXTURE)
        blip.dot:SetVertexColor(RED[1], RED[2], RED[3], 1)
        blip:SetScript("OnEnter", Tooltip)
        blip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        blip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        blip:EnableMouseWheel(true)
        blip:SetScript("OnMouseWheel", OnZoomWheel)
        blip:SetScript("OnClick", function(self, button) addon.HandleVignetteClick(self.target, button) end)
        blip.favorite = Text(blip, 9, "*")
        blip.favorite:SetPoint("BOTTOMLEFT", blip, "TOPRIGHT", -3, -3)
        blip.favorite:SetTextColor(1, 0.82, 0.30, 1)
        panel.blips[#panel.blips + 1] = blip
    end
    blip:Show()
    return blip
end

local function ReleaseBlip(key, blip)
    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == blip then GameTooltip:Hide() end
    panel.blipByKey[key] = nil
    blip.target = nil
    blip._seen = nil
    blip:Hide()
    blip:ClearAllPoints()
    panel.freeBlips[#panel.freeBlips + 1] = blip
end

local function BeginBlips()
    if not panel then return end
    for _, blip in pairs(panel.blipByKey) do blip._seen = false end
end

local function EndBlips()
    if not panel then return end
    local stale = {}
    for key, blip in pairs(panel.blipByKey) do
        if not blip._seen then stale[#stale + 1] = { key, blip } end
    end
    for _, entry in ipairs(stale) do ReleaseBlip(entry[1], entry[2]) end
end

local function ReleaseAllBlips()
    if not panel then return end
    local assigned = {}
    for key, blip in pairs(panel.blipByKey) do assigned[#assigned + 1] = { key, blip } end
    for _, entry in ipairs(assigned) do ReleaseBlip(entry[1], entry[2]) end
end

local function PlaceBlip(key, screenX, screenY, target)
    local blip = panel.blipByKey[key]
    if not blip then
        blip = AcquireBlip()
        if not blip then return end
        panel.blipByKey[key] = blip
    end
    blip._seen = true
    blip.target = target
    local r, g, b = TargetColor(target)
    local size = tonumber(Settings().vignetteRadarMarkerSize) or 7
    local hitSize = math.max(14, size + (target.isWorldBoss and 11 or 8))
    blip:SetSize(hitSize, hitSize)
    StyleMarker(blip, blip.dot, target, size, r, g, b)
    blip.favorite:SetShown(Favorite(target))
    local flashing = not Quiet() and target.newUntil and target.newUntil > Now()
    blip.glow:SetVertexColor(r, g, b, flashing and (0.4 + 0.3 * math.sin(Now() * 9)) or 0.18)
    blip.glow:SetShown(not target.stale)
    blip:SetAlpha(CategoryOpacity(target.category) * TargetAlpha(target))
    blip:ClearAllPoints()
    blip:SetPoint("CENTER", panel.field, "CENTER", screenX, screenY)
end

local CARDINALS = {
    { text = "N", angle = 0 },
    { text = "W", angle = math.pi / 2 },
    { text = "S", angle = math.pi },
    { text = "E", angle = -math.pi / 2 },
}

local function RenderCardinals(facing)
    for index, definition in ipairs(CARDINALS) do
        local relative = NormalizeAngle(definition.angle - facing)
        local label = panel.cardinals[index]
        label:ClearAllPoints()
        label:SetPoint("CENTER", panel.field, "CENTER",
            -math.sin(relative) * (panel.fieldRadius - 5), math.cos(relative) * (panel.fieldRadius - 5))
    end
end

local function UpdateRingLabels(range)
    panel.innerLabel:SetText(math.floor(range / 3) .. "y")
    panel.outerLabel:SetText(math.floor((range * 2) / 3) .. "y")
end

local function ApplyPanelLayout(focused)
    local name = Settings().vignetteRadarLayout or "classic"
    if not LAYOUTS[name] then name = "classic" end
    if panel.layout == name and panel.layoutFocused == focused then return end
    local changed = panel.layout ~= name
    local layout = LAYOUTS[name]
    local left, top = SafeNumber(panel:GetLeft()), SafeNumber(panel:GetTop())
    panel.layout, panel.layoutFocused = name, focused
    panel.fieldRadius = layout.field / 2 - 9
    panel.plotRadius = panel.fieldRadius - 15
    panel:SetSize(layout.width, layout.height + (focused and layout.focus or 0))
    -- Resizing a dragged or bottom-adjacent panel must leave the entire new view on screen.
    if left and top and UIParent and UIParent.GetWidth and UIParent.GetHeight then
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        left = math.max(4, math.min(left, width - panel:GetWidth() - 4))
        top = math.max(panel:GetHeight() + 4, math.min(top, height - 4))
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, top - height)
    end
    panel.field:SetSize(layout.field, layout.field)
    panel.field.halo:SetSize(layout.field + 4, layout.field + 4)
    ResizeRing(panel.outerRing, panel.field, panel.fieldRadius)
    ResizeRing(panel.rangeRing, panel.field, panel.plotRadius)
    ResizeRing(panel.middleRing, panel.field, panel.plotRadius * 2 / 3)
    ResizeRing(panel.innerRing, panel.field, panel.plotRadius / 3)
    local function Place(region, point, x, y, width, height)
        region:ClearAllPoints()
        region:SetPoint(point, x, y)
        if width then region:SetWidth(width) end
        if height then region:SetHeight(height) end
    end
    Place(panel.innerLabel, "CENTER", 0, -panel.plotRadius / 3)
    Place(panel.outerLabel, "CENTER", 0, -panel.plotRadius * 2 / 3)
    panel.layoutHint:SetShown(name == "squat" and not focused)
    if name == "squat" then
        -- A circular plotting area beside the readout keeps this view short even while focused.
        Place(panel.field, "BOTTOMLEFT", 10, 38)
        Place(panel.title, "TOPLEFT", 214, -16, 148, 13)
        Place(panel.summary, "TOPLEFT", 214, -35, 148, 10)
        Place(panel.drag, "TOPLEFT", 208, -8, 158, 47)
        Place(panel.focusDivider, "BOTTOMLEFT", 202, 42, 1, 174)
        Place(panel.focusReadout, "TOPLEFT", 214, -76, 148, 50)
        Place(panel.zoomOut, "BOTTOMLEFT", 12, 8)
        Place(panel.zoomLabel, "BOTTOMLEFT", 42, 12, 110, 12)
        Place(panel.zoomIn, "BOTTOMLEFT", 160, 8)
        Place(panel.compass, "BOTTOMLEFT", 214, 8)
        Place(panel.target, "BOTTOMRIGHT", -74, 8)
        Place(panel.legend, "BOTTOMRIGHT", -42, 8)
        Place(panel.close, "BOTTOMRIGHT", -10, 8)
    else
        local compact = name == "compact"
        local footer = layout.footer
        Place(panel.field, "BOTTOM", 0, footer + (focused and layout.focus or 0) + 9)
        Place(panel.title, "TOPLEFT", 12, -6, compact and 160 or 120, 13)
        Place(panel.summary, "TOPLEFT", 12, -21, compact and 160 or 120, 10)
        Place(panel.drag, "TOPLEFT", 4, -3, compact and 176 or 128, 28)
        Place(panel.focusDivider, "BOTTOM", 0, footer + layout.focus, layout.width - 24, 1)
        Place(panel.focusReadout, "BOTTOMLEFT", 12, footer + 8, layout.width - 24, compact and 50 or 32)
        if compact then
            Place(panel.zoomLabel, "BOTTOM", 0, 38, 92, 12)
        else
            Place(panel.zoomLabel, "BOTTOMLEFT", 76, 10, 96, 12)
        end
        -- Compact puts its range above a single, evenly spaced row of controls.
        panel.zoomOut:ClearAllPoints()
        panel.zoomOut:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, compact and 8 or 6)
        panel.zoomIn:ClearAllPoints()
        if compact then
            panel.zoomIn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 38, 8)
            Place(panel.target, "BOTTOMLEFT", 64, 6)
            Place(panel.legend, "BOTTOMLEFT", 92, 6)
            Place(panel.compass, "BOTTOMLEFT", 120, 8)
            Place(panel.close, "BOTTOMLEFT", 148, 6)
        else
            panel.zoomIn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 6)
            Place(panel.compass, "BOTTOMLEFT", 42, 6)
            Place(panel.target, "TOPRIGHT", -57, -5)
            Place(panel.legend, "TOPRIGHT", -31, -5)
            Place(panel.close, "TOPRIGHT", -5, -5)
        end
    end
    local textWidth = panel.focusReadout:GetWidth() - 24
    panel.focusName:SetWidth(textWidth)
    panel.focusMeta:SetSize(textWidth, name == "classic" and 12 or 28)
    if changed then
        -- Close pop-outs; opening them again chooses the side that fits the resized panel.
        local legend, picker = LegendAPI(), TargetPickerAPI()
        if legend and legend.Hide then legend.Hide() end
        if picker and picker.Hide then picker.Hide() end
        panel.legend:SetAlpha(0.68)
        UpdateTargetButton()
    else
        local legend, picker = LegendAPI(), TargetPickerAPI()
        if legend and legend.Reanchor then legend.Reanchor(panel) end
        if picker and picker.Reanchor then picker.Reanchor(panel) end
    end
end

local function UpdateFocusReadout(target, player)
    local focused = target ~= nil
    ApplyPanelLayout(focused)
    panel.focusReadout:SetShown(focused)
    panel.focusDivider:SetShown(focused or panel.layout == "squat")
    panel.edgeArrow:Hide()
    if not focused then return end
    panel.focusReadout.target = target
    panel.focusName:SetText((Favorite(target) and "* " or "") .. (target.name or "Detected vignette"))
    local age = target.stale and math.floor(math.max(0, Now() - target.lastSeenAt)) or nil
    local detail = target.isWorldBoss and "BOSS | " or (target.category == "rare" and "RARE | " or "")
    detail = detail .. (target.distance and (math.floor(target.distance + 0.5) .. " yd") or "Distance unavailable")
    local separator = panel.layout == "classic" and " | " or "\n"
    if age then detail = detail .. separator .. "seen " .. age .. "s ago"
    elseif target.sample then detail = detail .. separator .. "preview"
    elseif Features() then
        if not target._healthAt or Now() - target._healthAt >= 1 then
            target._healthAt, target._health = Now(), Features().GetHealth(target)
        end
        if Settings().vignetteRadarShowHealth ~= false and target._health then
            detail = detail .. separator .. math.floor(target._health + 0.5) .. "% HP"
        end
    end
    panel.focusMeta:SetText(detail)
    local r, g, b = TargetColor(target)
    local x, y
    if target.sample then x, y = PreviewPosition(target.x, target.y)
    elseif player and (player.headingAvailable or Settings().vignetteRadarNorthUp == true) then
        x, y = Project(target.worldX - player.worldX, target.worldY - player.worldY,
            target.distance or 0, ViewFacing(player.facing), 1, math.max(1, target.distance or 1))
    end
    panel.focusArrow:SetShown(x ~= nil and y ~= nil)
    if x and y then
        DrawArrow(panel.focusArrow, x, y, r, g, b)
        local range = tonumber(Settings().vignetteRadarRange) or 450
        if not target.stale and target.distance and target.distance > range then
            local magnitude = math.sqrt(x * x + y * y)
            if magnitude > 0 then
                panel.edgeArrow:ClearAllPoints()
                panel.edgeArrow:SetPoint("CENTER", panel.field, "CENTER",
                    x / magnitude * panel.plotRadius, y / magnitude * panel.plotRadius)
                panel.edgeArrow.target = target
                DrawArrow(panel.edgeArrow, x, y, r, g, b)
                panel.edgeArrow:Show()
            end
        end
    end
end

Render = function()
    if not panel or not panel:IsShown() then return end
    BeginBlips()
    local range = tonumber(Settings().vignetteRadarRange) or 450
    UpdateRingLabels(range)
    panel.zoomLabel:SetText(range .. " yd")
    local ranges = Ranges()
    panel.zoomIn:SetEnabled(range ~= ranges[1])
    panel.zoomOut:SetEnabled(range ~= ranges[#ranges])
    local northUp = Settings().vignetteRadarNorthUp == true
    if panel.compass._northUp ~= northUp then
        panel.compass._northUp = northUp
        if northUp then panel.compass:LockHighlight() else panel.compass:UnlockHighlight() end
    end
    panel:SetAlpha(Quiet() and 0.35 or 1)
    local mapID = CurrentMapID()
    if not preview and mapID ~= activeMapID then ScanVignettes(mapID) end
    local targets = SelectableTargets()
    local focusedTarget
    for _, target in ipairs(targets) do
        if target.key == FocusedTargetKey() then focusedTarget = target; break end
    end
    local player = not preview and PlayerSnapshot(CurrentMapID()) or nil
    UpdateFocusReadout(focusedTarget, player)

    if preview then
        panel.summary:SetText(FocusedTargetKey() and "PREVIEW FOCUS" or "PREVIEW")
        RenderCardinals(ViewFacing(0.65))
        DrawPlayerHeading(panel.direction, panel.field, 0.65, 3, 21)
        panel.direction:Show()
        for _, target in ipairs(PREVIEW_TARGETS) do
            target.distance = range * target.distanceFactor
            local scale = panel.plotRadius / PLOT_RADIUS
            local x, y = PreviewPosition(target.x, target.y)
            if TargetVisible(target) then PlaceBlip(target.key, x * scale, y * scale, target) end
        end
        EndBlips()
        return
    end

    player = PlayerSnapshot(mapID)
    if not player then
        panel.summary:SetText("POSITION UNAVAILABLE")
        RenderCardinals(0)
        panel.direction:Hide()
        EndBlips()
        return
    end
    RenderCardinals(ViewFacing(player.facing))
    DrawPlayerHeading(panel.direction, panel.field, player.facing, 3, 21)
    panel.direction:SetShown(player.headingAvailable)
    local shown, staleShown, totalInRange = 0, 0, 0
    for _, target in ipairs(targets) do
        if TargetVisible(target)
            and not (player.instanceID and target.instanceID and player.instanceID ~= target.instanceID) then
            local dx, dy = target.worldX - player.worldX, target.worldY - player.worldY
            local distance = math.sqrt((dx * dx) + (dy * dy))
            if distance <= range then
                totalInRange = totalInRange + 1
                local screenX, screenY = Project(dx, dy, distance, ViewFacing(player.facing), panel.plotRadius, range)
                if screenX and screenY and shown < MAX_BLIPS then
                    target.distance = distance
                    PlaceBlip(target.key, screenX, screenY, target)
                    shown = shown + 1
                    if target.stale then staleShown = staleShown + 1 end
                end
            end
        end
    end
    if FocusedTargetKey() then
        panel.summary:SetText(focusedTarget and focusedTarget.stale and "LAST SEEN"
            or (shown > 0 and "TARGET FOCUS" or "OUT OF RANGE"))
    else
        panel.summary:SetText(totalInRange > shown and (shown .. " OF " .. totalInRange .. " SHOWN")
            or staleShown > 0 and ((shown - staleShown) .. " LIVE / " .. staleShown .. " SEEN")
            or (shown == 1 and "1 IN RANGE" or shown .. " IN RANGE"))
    end
    EndBlips()
end

local function SavePosition()
    if not panel then return end
    local left, top = panel:GetLeft(), panel:GetTop()
    if SafeNumber(left) and SafeNumber(top) and UIParent and UIParent.GetHeight then
        Settings().vignetteRadarPosition = { x = left, y = top - UIParent:GetHeight() }
    end
end

local function SaveLauncherPosition()
    if not launcher then return end
    local left, top = launcher:GetLeft(), launcher:GetTop()
    if SafeNumber(left) and SafeNumber(top) and UIParent and UIParent.GetHeight then
        Settings().vignetteRadarLauncherPosition = { x = left, y = top - UIParent:GetHeight() }
    end
end

local function LauncherTooltip(owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("Vignette Radar", 1, 1, 1)
    GameTooltip:AddLine("The hollow center mirrors live detections within 150 yards.", 0.55, 0.86, 0.76, true)
    if (owner.bosses or 0) > 0 then GameTooltip:AddLine(owner.bosses .. " world boss nearby", 1, 0.18, 0.12) end
    if (owner.rares or 0) > 0 then GameTooltip:AddLine(owner.rares .. " rare enemy nearby", 0.78, 0.88, 1) end
    GameTooltip:AddLine("Silver skull: rare enemy. Larger red skull: world boss.", 0.78, 0.88, 1, true)
    GameTooltip:AddLine("Left-click to show or tuck away the radar.", 0.65, 0.80, 0.77, true)
    GameTooltip:AddLine("Right-click to preview its live layout. Drag to move this launcher.", 0.65, 0.80, 0.77, true)
    GameTooltip:Show()
end

local function PlayLauncherSound()
    if Quiet() then return end
    if type(PlaySound) ~= "function" then return end
    local sound = SOUNDKIT and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION)
    if sound then pcall(PlaySound, sound) end
end

local function ToggleRadarPanel()
    if panel and panel:IsShown() then
        manualPanelState = false
        preview = false
        panel:Hide()
        local legend = LegendAPI()
        if legend and type(legend.Hide) == "function" then pcall(legend.Hide) end
    else
        Settings().vignetteRadarEnabled = true
        manualPanelState = true
        RefreshRadar(true)
    end
    if UpdateLauncher then UpdateLauncher(0, true) end
end

local function CreateLauncherRing(parent, radius, alpha)
    local ring = {}
    for index = 1, 24 do
        local line = parent:CreateLine(nil, "ARTWORK")
        local first = ((index - 1) / 24) * TWO_PI
        local last = (index / 24) * TWO_PI
        line:SetThickness(1)
        line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], alpha)
        line:SetStartPoint("CENTER", parent, "CENTER", math.cos(first) * radius, math.sin(first) * radius)
        line:SetEndPoint("CENTER", parent, "CENTER", math.cos(last) * radius, math.sin(last) * radius)
        ring[index] = line
    end
    return ring
end

local function UpdateLauncherSweep(frame, elapsed)
    frame:SetAlpha(Quiet() and 0.35 or 1)
    local active = Settings().vignetteRadarEnabled == true or preview
    frame._animationTime = (frame._animationTime or 0) + elapsed
    local speed = frame._hovered and 1.35 or 0.72
    frame._sweepAngle = ((frame._sweepAngle or 0) + elapsed * speed) % TWO_PI
    for index, line in ipairs(frame.sweepLines) do
        local angle = frame._sweepAngle - ((index - 1) * 0.13)
        local alpha = active and (0.30 / index) or (0.08 / index)
        line:SetColorTexture(active and ACCENT[1] or 0.45, active and ACCENT[2] or 0.49,
            active and ACCENT[3] or 0.50, alpha)
        line:SetEndPoint("CENTER", frame, "CENTER", math.sin(angle) * LAUNCHER_RADIUS,
            math.cos(angle) * LAUNCHER_RADIUS)
    end

    local pulse = 0.5 + (0.5 * math.sin(frame._animationTime * 2.0))
    frame.bezel:SetShown(active)
    frame.closed:SetShown(not active)
    local stateTexture = active and frame.bezel or frame.closed
    local stateAlpha = 0.92
    if frame._pressed then
        stateAlpha = 0.78
    elseif frame._hovered then
        stateAlpha = 1
    elseif (frame.detected or 0) > 0 then
        stateAlpha = 0.93 + (pulse * 0.02)
    end
    stateTexture:SetAlpha(stateAlpha)
    stateTexture:SetVertexColor(1, 1, 1, 1)
    if active and pulseUntil > Now() and not Quiet() then
        stateTexture:SetVertexColor(0.60 + 0.40 * math.abs(math.sin(Now() * 6)), 1, 0.72, 1)
    end
    frame.face:SetVertexColor(frame._pressed and 0.01 or 0.012, frame._pressed and 0.035 or 0.046,
        frame._pressed and 0.038 or 0.052, 0.98)

    if frame._shock then
        frame._shock = frame._shock + elapsed / 0.24
        if frame._shock >= 1 then
            frame._shock = nil
            frame.shock:Hide()
        else
            local size = 28 + (frame._shock * 16)
            frame.shock:SetSize(size, size)
            frame.shock:SetAlpha((1 - frame._shock) * 0.22)
            frame.shock:Show()
        end
    end
end

UpdateLauncher = function(elapsed, updateTargets)
    if not launcher then return end
    UpdateLauncherSweep(launcher, elapsed or 0)
    if not updateTargets then return end

    local range = LAUNCHER_RANGE
    local shown, rares, bosses = 0, 0, 0
    local highlight = HighlightCategory()
    local player = not preview and Settings().vignetteRadarEnabled == true and PlayerSnapshot(CurrentMapID()) or nil
    launcher.direction:SetShown(Settings().vignetteRadarNorthUp == true
        and (preview or (player and player.headingAvailable) == true))
    if preview or player then
        DrawPlayerHeading(launcher.direction, launcher, preview and 0.65 or player.facing, 2, 9)
    end
    local function ShowDot(target, x, y)
        shown = shown + 1
        local dot = launcher.miniBlips[shown]
        if not dot then shown = shown - 1; return false end
        local red, green, blue = TargetColor(target)
        if not target.stale then
            if target.isWorldBoss then bosses = bosses + 1
            elseif target.category == "rare" then rares = rares + 1 end
        end
        local size = (tonumber(Settings().vignetteRadarMarkerSize) or 7) * 0.5
        if highlight == (target.category or "other") or Favorite(target) then size = size + 1 end
        StyleMarker(dot, dot.dot, target, size, red, green, blue)
        dot:SetAlpha(CategoryOpacity(target.category) * TargetAlpha(target))
        dot:SetSize(size + 2, size + 2)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", launcher, "CENTER", x, y)
        dot:Show()
        return shown < #launcher.miniBlips
    end

    if preview then
        for _, target in ipairs(PREVIEW_TARGETS) do
            local x, y = PreviewPosition(target.launcherX, target.launcherY)
            if TargetVisible(target) then ShowDot(target, x, y) end
        end
    elseif player then
        for _, target in ipairs(SelectableTargets()) do
            if TargetVisible(target)
                and not (player.instanceID and target.instanceID and player.instanceID ~= target.instanceID) then
                local dx, dy = target.worldX - player.worldX, target.worldY - player.worldY
                local distance = math.sqrt((dx * dx) + (dy * dy))
                if distance <= range then
                    local x, y = Project(dx, dy, distance, ViewFacing(player.facing), LAUNCHER_RADIUS - 5, range)
                    if x and y and not ShowDot(target, x, y) then break end
                end
            end
        end
    end
    for index = shown + 1, #launcher.miniBlips do launcher.miniBlips[index]:Hide() end
    launcher.detected = shown
    launcher.rares, launcher.bosses = rares, bosses
    launcher.rangeLabel:SetText(bosses > 0 and "BOSS" or (rares > 0 and "RARE" or "150"))
    if bosses > 0 then launcher.rangeLabel:SetTextColor(1, 0.25, 0.18, 1)
    elseif rares > 0 then launcher.rangeLabel:SetTextColor(0.78, 0.88, 1, 1)
    else launcher.rangeLabel:SetTextColor(0.56, 0.78, 0.74, 0.68) end
end

EnsureLauncher = function()
    if launcher then return launcher end
    launcher = CreateFrame("Button", "VignetteRadarLauncher", UIParent)
    launcher:SetSize(LAUNCHER_SIZE, LAUNCHER_SIZE)
    launcher:SetFrameStrata("MEDIUM")
    launcher:SetClampedToScreen(true)
    launcher:SetMovable(true)
    launcher:EnableMouse(true)
    launcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    launcher:RegisterForDrag("LeftButton")
    local position = Settings().vignetteRadarLauncherPosition
    launcher:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
        type(position) == "table" and tonumber(position.x) or 30,
        type(position) == "table" and tonumber(position.y) or -170)

    launcher.face = launcher:CreateTexture(nil, "BORDER")
    launcher.face:SetSize(29, 29)
    launcher.face:SetPoint("CENTER")
    launcher.face:SetTexture(CIRCLE_TEXTURE)
    launcher.face:SetVertexColor(0.012, 0.046, 0.052, 0.98)
    launcher.ring = CreateLauncherRing(launcher, 9, 0.18)

    launcher.horizontal = launcher:CreateTexture(nil, "ARTWORK")
    launcher.horizontal:SetSize(25, 1)
    launcher.horizontal:SetPoint("CENTER")
    launcher.horizontal:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.12)
    launcher.vertical = launcher:CreateTexture(nil, "ARTWORK")
    launcher.vertical:SetSize(1, 25)
    launcher.vertical:SetPoint("CENTER")
    launcher.vertical:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.12)

    launcher.sweepLines = {}
    for index = 1, 2 do
        local line = launcher:CreateLine(nil, "OVERLAY")
        line:SetThickness(index == 1 and 1.2 or 1)
        line:SetStartPoint("CENTER", launcher, "CENTER", 0, 0)
        launcher.sweepLines[index] = line
    end
    launcher.centerGlow = launcher:CreateTexture(nil, "OVERLAY")
    launcher.centerGlow:SetSize(7, 7)
    launcher.centerGlow:SetPoint("CENTER")
    launcher.centerGlow:SetTexture(CIRCLE_TEXTURE)
    launcher.centerGlow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.22)
    launcher.center = launcher:CreateTexture(nil, "OVERLAY", nil, 1)
    launcher.center:SetSize(3, 3)
    launcher.center:SetPoint("CENTER")
    launcher.center:SetTexture(CIRCLE_TEXTURE)
    launcher.center:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    launcher.direction = launcher:CreateLine(nil, "OVERLAY")
    launcher.direction:SetThickness(1.5)
    launcher.direction:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.95)
    launcher.direction:Hide()
    launcher.miniBlips = {}
    for index = 1, 5 do
        local dot = CreateFrame("Frame", nil, launcher)
        dot.isMini = true
        dot:SetFrameLevel(launcher:GetFrameLevel() + 1)
        dot:SetSize(3, 3)
        dot.dot = dot:CreateTexture(nil, "OVERLAY")
        dot.dot:SetPoint("CENTER")
        dot.dot:SetTexture(CIRCLE_TEXTURE)
        dot:Hide()
        launcher.miniBlips[index] = dot
    end
    launcher.rangeLabel = Text(launcher, 7, "150")
    launcher.rangeLabel:SetPoint("BOTTOM", launcher, "BOTTOM", 0, 8)
    launcher.rangeLabel:SetJustifyH("CENTER")
    launcher.rangeLabel:SetTextColor(0.56, 0.78, 0.74, 0.68)
    launcher.bezel = launcher:CreateTexture(nil, "OVERLAY", nil, 3)
    launcher.bezel:SetAllPoints()
    launcher.bezel:SetTexture(LAUNCHER_BEZEL)
    launcher.bezel:SetAlpha(0.92)
    launcher.closed = launcher:CreateTexture(nil, "OVERLAY", nil, 3)
    launcher.closed:SetAllPoints()
    launcher.closed:SetTexture(LAUNCHER_CLOSED)
    launcher.closed:SetAlpha(0.92)
    launcher.closed:Hide()
    launcher.shock = launcher:CreateTexture(nil, "OVERLAY", nil, 4)
    launcher.shock:SetPoint("CENTER")
    launcher.shock:SetTexture(CIRCLE_TEXTURE)
    launcher.shock:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    launcher.shock:Hide()

    launcher:SetScript("OnEnter", function(self)
        self._hovered = true
        LauncherTooltip(self)
    end)
    launcher:SetScript("OnLeave", function(self)
        self._hovered = false
        self._pressed = false
        if GameTooltip then GameTooltip:Hide() end
    end)
    launcher:SetScript("OnMouseDown", function(self) self._pressed = true end)
    launcher:SetScript("OnMouseUp", function(self) self._pressed = false end)
    launcher:SetScript("OnDragStart", function(self)
        self._dragging = true
        self._suppressClick = true
        self:StartMoving()
        if GameTooltip then GameTooltip:Hide() end
    end)
    launcher:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self._dragging = false
        SaveLauncherPosition()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() self._suppressClick = false end)
        else
            self._suppressClick = false
        end
    end)
    launcher:SetScript("OnClick", function(self, button)
        if self._suppressClick or self._dragging then return end
        self._shock = 0.001
        PlayLauncherSound()
        if button == "RightButton" then
            preview = not preview
            manualPanelState = preview and true or nil
            RefreshRadar(true)
        else
            ToggleRadarPanel()
        end
    end)
    launcher:SetScript("OnUpdate", function(self, elapsed)
        self._sweepElapsed = (self._sweepElapsed or 0) + elapsed
        self._targetElapsed = (self._targetElapsed or 0) + elapsed
        self._scanElapsed = (self._scanElapsed or 0) + elapsed
        if self._sweepElapsed >= (1 / 30) then
            UpdateLauncherSweep(self, self._sweepElapsed)
            self._sweepElapsed = 0
        end
        if self._targetElapsed >= 0.15 then
            self._targetElapsed = 0
            UpdateLauncher(0, true)
        end
        if self._scanElapsed >= RESCAN_SECONDS and (not panel or not panel:IsShown()) then
            self._scanElapsed = 0
            RefreshRadar(true)
        end
    end)
    UpdateLauncher(0, true)
    return launcher
end

local function EnsurePanel()
    if panel then return panel end
    panel = CreateFrame("Frame", "VignetteRadarPanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", OnZoomWheel)
    Surface(panel)
    local position = Settings().vignetteRadarPosition
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
        type(position) == "table" and tonumber(position.x) or 30,
        type(position) == "table" and tonumber(position.y) or -520)

    panel.title = Text(panel, 11, "VIGNETTE RADAR", true)
    panel.title:SetPoint("TOPLEFT", 12, -6)
    panel.title:SetWidth(120)
    panel.summary = Text(panel, 8, "0 IN RANGE")
    panel.summary:SetPoint("TOPLEFT", 12, -21)
    panel.summary:SetJustifyH("LEFT")
    panel.summary:SetWidth(120)

    panel.layoutHint = Text(panel, 10, "Click a marker to focus.\nScroll to zoom.")
    panel.layoutHint:SetPoint("TOPLEFT", 214, -76)
    panel.layoutHint:SetSize(148, 40)
    panel.layoutHint:SetTextColor(0.65, 0.69, 0.71, 1)
    panel.layoutHint:Hide()

    panel.drag = CreateFrame("Frame", nil, panel)
    panel.drag:SetPoint("TOPLEFT", 4, -3)
    panel.drag:SetSize(PANEL_W - 92, HEADER_H - 6)
    panel.drag:EnableMouse(true)
    panel.drag:RegisterForDrag("LeftButton")
    panel.drag:SetScript("OnDragStart", function() panel:StartMoving() end)
    panel.drag:SetScript("OnDragStop", function() panel:StopMovingOrSizing(); SavePosition() end)

    panel.target = CreateFrame("Button", nil, panel)
    panel.target:SetSize(24, 24)
    panel.target:SetPoint("TOPRIGHT", -57, -5)
    panel.target:SetAlpha(0.68)
    panel.target:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    panel.target:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    panel.target:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.07)
    panel.target.glow = panel.target:CreateTexture(nil, "BACKGROUND")
    panel.target.glow:SetSize(18, 18)
    panel.target.glow:SetPoint("CENTER")
    panel.target.glow:SetTexture(CIRCLE_TEXTURE)
    panel.target.glow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.05)
    panel.target.crossH = panel.target:CreateTexture(nil, "ARTWORK")
    panel.target.crossH:SetSize(16, 1)
    panel.target.crossH:SetPoint("CENTER")
    panel.target.crossH:SetColorTexture(0.61, 0.67, 0.68, 0.80)
    panel.target.crossV = panel.target:CreateTexture(nil, "ARTWORK")
    panel.target.crossV:SetSize(1, 16)
    panel.target.crossV:SetPoint("CENTER")
    panel.target.crossV:SetColorTexture(0.61, 0.67, 0.68, 0.80)
    panel.target.dot = panel.target:CreateTexture(nil, "OVERLAY")
    panel.target.dot:SetSize(6, 6)
    panel.target.dot:SetPoint("CENTER")
    panel.target.dot:SetTexture(CIRCLE_TEXTURE)
    panel.target.dot:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    panel.target:SetScript("OnClick", function(self, button)
        local picker = TargetPickerAPI()
        if not picker then return end
        local legend = LegendAPI()
        if legend and type(legend.Hide) == "function" then pcall(legend.Hide) end
        panel.legend:SetAlpha(0.68)
        if button == "RightButton" then
            if type(picker.ClearFocus) == "function" then pcall(picker.ClearFocus) end
        elseif type(picker.Toggle) == "function" then
            pcall(picker.Toggle, panel)
        end
        UpdateTargetButton()
    end)
    panel.target:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Focus a specific vignette", 1, 1, 1)
        GameTooltip:AddLine("Choose one current detection to isolate on the full radar and the 150-yard launcher view.",
            0.65, 0.80, 0.77, true)
        GameTooltip:AddLine("Right-click to show all again.", 0.55, 0.86, 0.76, true)
        GameTooltip:Show()
    end)
    panel.target:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    panel.legend = CreateFrame("Button", nil, panel)
    panel.legend:SetSize(24, 24)
    panel.legend:SetPoint("TOPRIGHT", -31, -5)
    panel.legend:SetAlpha(0.68)
    panel.legend:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    panel.legend:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.07)
    local legendColors = {
        { 0.78, 0.88, 1.00 },
        { 1.00, 0.68, 0.16 },
        { 0.67, 0.42, 1.00 },
    }
    panel.legend.dots = {}
    for index, color in ipairs(legendColors) do
        local dot = panel.legend:CreateTexture(nil, "ARTWORK")
        dot:SetSize(4, 4)
        dot:SetPoint("LEFT", 4, 12 - (index * 6))
        dot:SetTexture(CIRCLE_TEXTURE)
        dot:SetVertexColor(color[1], color[2], color[3], 1)
        panel.legend.dots[index] = dot
        local line = panel.legend:CreateTexture(nil, "ARTWORK")
        line:SetSize(9, 1)
        line:SetPoint("LEFT", 11, 12 - (index * 6))
        line:SetColorTexture(0.68, 0.72, 0.74, 0.72)
    end
    panel.legend:SetScript("OnClick", function(self)
        local legend = LegendAPI()
        if not (legend and type(legend.Toggle) == "function") then return end
        local picker = TargetPickerAPI()
        if picker and type(picker.Hide) == "function" then pcall(picker.Hide) end
        local ok, shown = pcall(legend.Toggle, panel)
        if ok then self:SetAlpha(shown and 1 or 0.68) end
    end)
    panel.legend:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Radar legend and spotlight", 1, 1, 1)
        GameTooltip:AddLine("Filter vignette types or spotlight one category while keeping the others as dim context.",
            0.65, 0.80, 0.77, true)
        GameTooltip:Show()
    end)
    panel.legend:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    panel.close = CreateFrame("Button", nil, panel)
    panel.close:SetSize(24, 24)
    panel.close:SetPoint("TOPRIGHT", -5, -5)
    panel.close.label = Text(panel.close, 16, "×")
    panel.close.label:SetAllPoints()
    panel.close.label:SetJustifyH("CENTER")
    panel.close:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    panel.close:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.07)
    panel.close:SetScript("OnClick", function()
        manualPanelState = false
        preview = false
        panel:Hide()
        local legend = LegendAPI()
        if legend and type(legend.Hide) == "function" then pcall(legend.Hide) end
        local picker = TargetPickerAPI()
        if picker and type(picker.Hide) == "function" then pcall(picker.Hide) end
        if UpdateLauncher then UpdateLauncher(0, true) end
    end)
    panel.close:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Tuck away radar", 1, 1, 1)
        GameTooltip:AddLine("The launcher stays ready so you can bring the radar back without disabling detection.",
            0.72, 0.76, 0.78, true)
        GameTooltip:Show()
    end)
    panel.close:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    panel.field = CreateFrame("Frame", nil, panel)
    panel.field:SetSize(FIELD_SIZE, FIELD_SIZE)
    panel.field:SetPoint("BOTTOM", 0, 9 + ZOOM_FOOTER_H)
    panel.field:EnableMouseWheel(true)
    panel.field:SetScript("OnMouseWheel", OnZoomWheel)
    panel.field:SetFrameLevel(panel:GetFrameLevel() + 1)
    panel.field.background = panel.field:CreateTexture(nil, "BACKGROUND")
    panel.field.background:SetAllPoints()
    panel.field.background:SetTexture(CIRCLE_TEXTURE)
    panel.field.background:SetVertexColor(0.015, 0.022, 0.028, 0.94)
    panel.field.halo = panel.field:CreateTexture(nil, "BACKGROUND", nil, -1)
    panel.field.halo:SetPoint("CENTER")
    panel.field.halo:SetSize(FIELD_SIZE + 4, FIELD_SIZE + 4)
    panel.field.halo:SetTexture(CIRCLE_TEXTURE)
    panel.field.halo:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.18)
    panel.outerRing = AddRing(panel.field, FIELD_RADIUS, 0.44)
    panel.rangeRing = AddRing(panel.field, PLOT_RADIUS, 0.23)
    panel.middleRing = AddRing(panel.field, PLOT_RADIUS * (2 / 3), 0.23)
    panel.innerRing = AddRing(panel.field, PLOT_RADIUS / 3, 0.18)

    panel.innerLabel = Text(panel.field, 8, "150y")
    panel.innerLabel:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.55)
    panel.innerLabel:SetPoint("CENTER", 0, -(PLOT_RADIUS / 3))
    panel.outerLabel = Text(panel.field, 8, "300y")
    panel.outerLabel:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.55)
    panel.outerLabel:SetPoint("CENTER", 0, -(PLOT_RADIUS * 2 / 3))

    panel.cardinals = {}
    for index, definition in ipairs(CARDINALS) do
        local label = Text(panel.field, 9, definition.text)
        label:SetTextColor(0.65, 0.69, 0.71, 0.82)
        label:SetJustifyH("CENTER")
        panel.cardinals[index] = label
    end
    panel.direction = panel.field:CreateLine(nil, "ARTWORK")
    panel.direction:SetThickness(2)
    DrawPlayerHeading(panel.direction, panel.field, 0, 3, 21)
    panel.direction:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
    panel.playerGlow = panel.field:CreateTexture(nil, "OVERLAY")
    panel.playerGlow:SetSize(14, 14)
    panel.playerGlow:SetPoint("CENTER")
    panel.playerGlow:SetTexture(CIRCLE_TEXTURE)
    panel.playerGlow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.25)
    panel.player = panel.field:CreateTexture(nil, "OVERLAY", nil, 1)
    panel.player:SetSize(7, 7)
    panel.player:SetPoint("CENTER")
    panel.player:SetTexture(CIRCLE_TEXTURE)
    panel.player:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    panel.blips, panel.freeBlips, panel.blipByKey = {}, {}, {}

    panel.focusDivider = panel:CreateTexture(nil, "ARTWORK")
    panel.focusDivider:SetSize(PANEL_W - 24, 1)
    panel.focusDivider:SetPoint("BOTTOM", 0, 46 + ZOOM_FOOTER_H)
    panel.focusDivider:SetColorTexture(1, 1, 1, 0.12)
    panel.focusDivider:Hide()
    panel.focusReadout = CreateFrame("Button", nil, panel)
    panel.focusReadout:SetSize(PANEL_W - 24, 32)
    panel.focusReadout:SetPoint("BOTTOMLEFT", 12, 8 + ZOOM_FOOTER_H)
    panel.focusReadout:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    panel.focusReadout:SetScript("OnEnter", Tooltip)
    panel.focusReadout:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    panel.focusReadout:SetScript("OnClick", function(self, button) addon.HandleVignetteClick(self.target, button) end)
    panel.focusArrow = CreateFrame("Frame", nil, panel.focusReadout)
    panel.focusArrow:SetSize(16, 16)
    panel.focusArrow:SetPoint("LEFT", 0, 0)
    panel.focusName = Text(panel.focusReadout, 10, "")
    panel.focusName:SetPoint("TOPLEFT", 24, -1)
    panel.focusName:SetSize(172, 13)
    panel.focusMeta = Text(panel.focusReadout, 9, "")
    panel.focusMeta:SetPoint("BOTTOMLEFT", 24, 1)
    panel.focusMeta:SetSize(172, 12)
    panel.focusReadout:Hide()
    panel.edgeArrow = CreateFrame("Button", nil, panel.field)
    panel.edgeArrow:SetSize(14, 14)
    panel.edgeArrow:SetFrameLevel(panel.field:GetFrameLevel() + 5)
    panel.edgeArrow:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    panel.edgeArrow:SetScript("OnEnter", Tooltip)
    panel.edgeArrow:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    panel.edgeArrow:SetScript("OnClick", function(self, button) addon.HandleVignetteClick(self.target, button) end)
    panel.edgeArrow:Hide()

    panel.zoomLabel = Text(panel, 10, "450 yd")
    panel.zoomLabel:SetPoint("BOTTOM", 0, 10)
    panel.zoomLabel:SetSize(110, 12)
    panel.zoomLabel:SetJustifyH("CENTER")
    local function ZoomButton(label, right, step, title)
        local button = addon.VignetteRadarControls.Button(panel, label, 22, 20)
        button:SetPoint(right and "BOTTOMRIGHT" or "BOTTOMLEFT", panel, right and "BOTTOMRIGHT" or "BOTTOMLEFT", right and -12 or 12, 6)
        button:SetScript("OnClick", function() StepRange(step) end)
        button:HookScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(title, 1, 1, 1)
            GameTooltip:AddLine("Range is the distance from you to the outer range ring. You can also use the mouse wheel.", 0.7, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        return button
    end
    panel.zoomOut = ZoomButton("-", false, 1, "Zoom out: show a wider area")
    panel.zoomIn = ZoomButton("+", true, -1, "Zoom in: show nearby detail")
    panel.compass = addon.VignetteRadarControls.Button(panel, "N", 24, 20)
    panel.compass:SetScript("OnClick", function()
        addon.SetVignetteRadarNorthUp(Settings().vignetteRadarNorthUp ~= true)
    end)
    panel.compass:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        local northUp = Settings().vignetteRadarNorthUp == true
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(northUp and "North up" or "Facing up", 1, 1, 1)
        GameTooltip:AddLine(northUp and "North stays at the top. Your direction line turns as you turn."
            or "The radar turns with you. Your direction line points up.", 0.7, 0.8, 0.8, true)
        GameTooltip:AddLine(northUp and "Click to follow your facing." or "Click to keep north at the top.",
            0.55, 0.86, 0.76, true)
        GameTooltip:Show()
    end)
    panel.compass:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    panel:SetScript("OnUpdate", function(self, elapsed)
        self._renderElapsed = (self._renderElapsed or 0) + elapsed
        self._scanElapsed = (self._scanElapsed or 0) + elapsed
        if self._scanElapsed >= RESCAN_SECONDS then
            self._scanElapsed = 0
            RefreshRadar(true)
            if not self:IsShown() then return end
        end
        if self._renderElapsed >= UPDATE_SECONDS then
            self._renderElapsed = 0
            Render()
        end
    end)
    panel:SetScript("OnHide", function()
        ReleaseAllBlips()
        panel.legend:SetAlpha(0.68)
        UpdateTargetButton()
        local legend = LegendAPI()
        if legend and type(legend.Hide) == "function" then pcall(legend.Hide) end
        local picker = TargetPickerAPI()
        if picker and type(picker.Hide) == "function" then pcall(picker.Hide) end
    end)
    ApplyPanelLayout(false)
    RenderCardinals(0)
    UpdateTargetButton()
    return panel
end

ScanVignettes = function(mapID)
    if activeMapID ~= mapID or preview or Settings().vignetteRadarEnabled ~= true then pulseUntil = 0 end
    activeMapID = mapID
    activeTargets = CollectVignettes(mapID)
    if Features() then
        local worldMapMode = Settings().vignetteRadarWorldMap ~= false
        if activeWorldMapMode ~= nil and worldMapMode ~= activeWorldMapMode then
            Features().Update({}, mapID, Now(), { enabled = false })
            pulseUntil = 0
        end
        activeWorldMapMode = worldMapMode
        local alerts
        activeTargets, alerts = Features().Update(activeTargets, mapID, Now(), {
            enabled = Settings().vignetteRadarEnabled == true, preview = preview,
        })
        if alerts and #alerts > 0 then
            local favorite = false
            for _, target in ipairs(alerts) do
                pulseUntil = math.max(pulseUntil, target.newUntil or 0)
                favorite = favorite or Favorite(target)
            end
            if Settings().vignetteRadarAlertSound == true and not Quiet() and PlaySound and SOUNDKIT then
                local sound = favorite and SOUNDKIT.RAID_WARNING or SOUNDKIT.TELL_MESSAGE
                    or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
                if sound then pcall(PlaySound, sound, "SFX") end
            end
        end
    end
end

RefreshRadar = function(rescan)
    local settings = Settings()
    if settings.vignetteRadarLauncherVisible ~= false then
        EnsureLauncher():Show()
    elseif launcher then
        launcher:Hide()
    end
    if rescan then ScanVignettes(CurrentMapID()) end
    ReconcileFocusedTarget()
    local picker = TargetPickerAPI()
    if picker and type(picker.Refresh) == "function" then pcall(picker.Refresh) end
    if settings.vignetteRadarEnabled ~= true and not preview then
        if panel then panel:Hide() end
        if launcher then UpdateLauncher(0, true) end
        return
    end
    if manualPanelState == false then
        if panel then panel:Hide() end
    elseif manualPanelState == true or preview or settings.vignetteRadarHideWhenEmpty == false or #SelectableTargets() > 0 then
        EnsurePanel():Show()
        Render()
    elseif panel then
        panel:Hide()
    end
    if launcher then UpdateLauncher(0, true) end
    UpdateTargetButton()
end

addon.RefreshVignetteRadar = function(rescan) RefreshRadar(rescan ~= false) end
addon.VignetteRadarAPI = {
    GetTargets = function() return activeTargets end,
    GetSelectableTargets = SelectableTargets,
    GetPanel = function() return panel end,
    GetLauncher = function() return launcher end,
    IsPreviewing = function() return preview end,
    Refresh = function(rescan) RefreshRadar(rescan == true) end,
    RefreshPresentation = function()
        if panel and panel:IsShown() then Render() end
        if launcher then UpdateLauncher(0, true) end
    end,
}

do
    local legend = LegendAPI()
    if legend and type(legend.ApplyDefaults) == "function" then pcall(legend.ApplyDefaults, Settings()) end
    if legend and type(legend.SetChangeCallback) == "function" then
        legend.SetChangeCallback(function()
            ReconcileFocusedTarget()
            local picker = TargetPickerAPI()
            if picker and type(picker.Refresh) == "function" then pcall(picker.Refresh) end
            if panel and panel:IsShown() then Render() end
            if launcher then UpdateLauncher(0, true) end
            UpdateTargetButton()
        end)
    end
    local picker = TargetPickerAPI()
    if picker and type(picker.SetProvider) == "function" then pcall(picker.SetProvider, SelectableTargets) end
    if picker and type(picker.SetChangeCallback) == "function" then
        picker.SetChangeCallback(function()
            if panel and panel:IsShown() then Render() end
            if launcher then UpdateLauncher(0, true) end
            UpdateTargetButton()
        end)
    end
end

function addon.ResetVignetteRadarPositions()
    Settings().vignetteRadarPosition = nil
    Settings().vignetteRadarLauncherPosition = nil
    if panel then panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -520) end
    if launcher then launcher:ClearAllPoints(); launcher:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -170) end
end

function addon.SetVignetteRadarRange(range)
    for _, supported in ipairs(Ranges()) do
        if range == supported then
            Settings().vignetteRadarRange = supported
            RefreshRadar(false)
            if addon.RefreshVignetteRadarOptions then addon.RefreshVignetteRadarOptions() end
            return true
        end
    end
    return false
end

function addon.SetVignetteRadarEnabled(enabled)
    Settings().vignetteRadarEnabled = enabled == true
    preview = false
    manualPanelState = nil
    RefreshRadar(true)
end

function addon.SetVignetteRadarLayout(layout)
    if not LAYOUTS[layout] then return false end
    Settings().vignetteRadarLayout = layout
    RefreshRadar(false)
    if addon.RefreshVignetteRadarOptions then addon.RefreshVignetteRadarOptions() end
    return true
end

function addon.SetVignetteRadarNorthUp(enabled)
    Settings().vignetteRadarNorthUp = enabled == true
    RefreshRadar(false)
    if addon.RefreshVignetteRadarOptions then addon.RefreshVignetteRadarOptions() end
end

function addon.ToggleVignetteRadarPreview()
    preview = not preview
    manualPanelState = preview and true or nil
    RefreshRadar(true)
end

SLASH_VIGNETTERADAR1 = "/vr"
SLASH_VIGNETTERADAR2 = "/vradar"
SLASH_VIGNETTERADAR3 = "/vignetteradar"
SLASH_VIGNETTERADAR4 = "/whradar"
SlashCmdList.VIGNETTERADAR = function(message)
    message = (message or ""):lower():match("^%s*(.-)%s*$")
    if message == "config" or message == "options" then
        if addon.OpenOptions then addon.OpenOptions() end
        return
    elseif message == "layout" or message:match("^layout%s+") then
        local layout = message:match("^layout%s+(%S+)$")
        if not layout and message == "layout" then
            local nextLayout = { classic = "squat", squat = "compact", compact = "classic" }
            layout = nextLayout[Settings().vignetteRadarLayout or "classic"]
        end
        if not addon.SetVignetteRadarLayout(layout) and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("Vignette Radar: /vr layout [classic, squat, compact]")
        end
        return
    elseif message == "preview" then
        addon.ToggleVignetteRadarPreview()
        return
    elseif message == "off" then
        addon.SetVignetteRadarEnabled(false)
        return
    elseif message == "on" then
        Settings().vignetteRadarEnabled = true
        preview = false
        manualPanelState = true
    else
        ToggleRadarPanel()
        return
    end
    RefreshRadar(true)
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "VIGNETTES_UPDATED", "VIGNETTE_MINIMAP_UPDATED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    RefreshRadar(true)
    if event == "PLAYER_LOGIN" and C_Timer and C_Timer.After then
        C_Timer.After(0.5, function() RefreshRadar(true) end)
    end
end)
-- Detection and expiry continue when the user hides both visual surfaces.
events:SetScript("OnUpdate", function(self, elapsed)
    if Settings().vignetteRadarEnabled ~= true or preview
        or (panel and panel:IsShown()) or (launcher and launcher:IsShown()) then
        self._idleElapsed = 0
        return
    end
    self._idleElapsed = (self._idleElapsed or 0) + elapsed
    if self._idleElapsed >= RESCAN_SECONDS then
        self._idleElapsed = 0
        RefreshRadar(true)
    end
end)
