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
local HEADING_HALF_WIDTH = 4
local UPDATE_SECONDS, RESCAN_SECONDS = 0.05, 1
local MAX_BLIPS = 64
local MAX_QUEST_DOTS = 64
local MAX_MAP_NOTES = 48
local TRAIL_STYLES = addon.VignetteRadarTrailStyles
local TRAIL_STYLE_BY_ID = addon.VignetteRadarTrailStyleByID
local TRAIL_SETTING_VALUES = addon.VignetteRadarTrailSettingValues or {
    vignetteRadarTrailSpacing = { .5, .65, .75, 1, 1.25, 1.5, 2 },
    vignetteRadarTrailSpeed = { 0, .25, .5, .75, 1, 1.25, 1.5, 2, 3, 4 },
    vignetteRadarTrailSize = { .5, .75, 1, 1.25, 1.5, 2 },
    vignetteRadarTrailTailFade = { 0, .25, .5, .75, 1 },
}
local TRAIL_SPACINGS = TRAIL_SETTING_VALUES.vignetteRadarTrailSpacing
local TRAIL_SPEEDS = TRAIL_SETTING_VALUES.vignetteRadarTrailSpeed
local TRAIL_SIZES = TRAIL_SETTING_VALUES.vignetteRadarTrailSize
local TRAIL_TAIL_FADES = TRAIL_SETTING_VALUES.vignetteRadarTrailTailFade
local TRAIL_LIFETIMES = { 1, 300 }
local ACCENT = { 0.05, 0.82, 0.62 }
local RED = { 1, 0.18, 0.14 }
local CIRCLE_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SQUARE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local ROUNDED_SQUARE_TEXTURE = "Interface\\AddOns\\VignetteRadar\\Media\\radar-rounded-square.tga"
local ROUNDED_BORDER_TEXTURE = "Interface\\AddOns\\VignetteRadar\\Media\\radar-rounded-border.tga"
local QUEST_CLIP_INSET = 4
local SKULL_TEXTURE = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local LAUNCHER_BEZEL = "Interface\\AddOns\\VignetteRadar\\Media\\vignette-radar-bezel.tga"
local LAUNCHER_CLOSED = "Interface\\AddOns\\VignetteRadar\\Media\\vignette-radar-closed.tga"
local TWO_PI = math.pi * 2
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local Unpack = unpack or table.unpack

local panel, launcher
local events
local trailPopup, HideTrailPopup, ToggleTrailPopup, RefreshTrailPopup
local preview = false
local manualPanelState
local activeTargets = {}
local activeQuests = {}
local activeMapNotes = {}
local mapNotesMapID, mapNotesSource, mapNotesUpdatedAt
local questMapBasis
local activeMapID
local activeWorldMapMode
local pulseUntil = 0
local approachPulseKey, approachPulseUntil
local displayedRange
local clusterHoverKey, clusterHoverUntil
local RefreshRadar, ScanVignettes, Render, UpdateLauncher, EnsureLauncher, ApplyAppearance
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

local function DrawTrailGlyph(definition, primary, extras, frame, x, y, ux, uy, r, g, b, alpha, index, sizeScale)
    sizeScale = sizeScale or 1
    if definition.dot or definition.square then
        local size = definition.alternating and (index % 2 == 0 and 3 or 6)
            or definition.dot or definition.square
        primary:SetSize(size * sizeScale, size * sizeScale)
        primary:SetVertexColor(r, g, b, alpha)
        primary:ClearAllPoints()
        primary:SetPoint("CENTER", frame, "CENTER", x, y)
        primary:Show()
        return
    end
    local scale = (definition.alternating and (index % 2 == 0 and .48 or 1) or 1) * sizeScale
    for part, segment in ipairs(definition.segments) do
        local line = part == 1 and primary or extras[part - 1]
        local x1, y1 = segment[1] * scale, segment[2] * scale
        local x2, y2 = segment[3] * scale, segment[4] * scale
        line:SetThickness(segment[5] * sizeScale)
        line:SetColorTexture(r, g, b, alpha)
        line:SetStartPoint("CENTER", frame, x + ux*x1 - uy*y1, y + uy*x1 + ux*y1)
        line:SetEndPoint("CENTER", frame, x + ux*x2 - uy*y2, y + uy*x2 + ux*y2)
        line:Show()
    end
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
    line:SetStartPoint("CENTER", frame, x * innerRadius, y * innerRadius)
    line:SetEndPoint("CENTER", frame, x * outerRadius, y * outerRadius)
end

local function DrawPlayerChevron(lines, frame, facing)
    local angle = facing - ViewFacing(facing)
    local base = Settings().vignetteRadarChevronDistance or 4
    local tip = base + 5
    local forwardX, forwardY = -math.sin(angle), math.cos(angle)
    local rightX, rightY = math.cos(angle), math.sin(angle)
    for index, line in ipairs(lines) do
        local side = index == 1 and -1 or 1
        line:SetStartPoint("CENTER", frame, forwardX * base + rightX * HEADING_HALF_WIDTH * side,
            forwardY * base + rightY * HEADING_HALF_WIDTH * side)
        line:SetEndPoint("CENTER", frame, forwardX * tip, forwardY * tip)
    end
end

local function HeadingGeometry(radius)
    local tip = (Settings().vignetteRadarChevronDistance or 4) + 5
    return tip, math.max(tip + 2, radius * (Settings().vignetteRadarHeadingLength or .30))
end

local function Ranges()
    return addon.VignetteRadarRanges or { 150, 300, 450, 600, 1200, 2400, 4800 }
end

local function StepRange(step)
    local ranges, current = Ranges(), displayedRange or Settings().vignetteRadarRange
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

local function VisuallyQuiet()
    return not preview and Features() and Features().IsVisuallyQuiet() or false
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

local function MapVector(x, y)
    local vector = type(CreateVector2D) == "function" and Call(CreateVector2D, x, y) or nil
    return vector or { x = x, y = y }
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
            if info and SafeBoolean(SafeField(info, "isDead")) == true
                and addon.VignetteRadarRecent then
                local kind = ClassifyVignette(info)
                if kind == "rare" or kind == "treasure"
                    or (Features() and Features().IsWorldBoss(info)) then
                    addon.VignetteRadarRecent.RecordNPCGuid(SafeString(SafeField(info, "objectGUID")))
                end
            end
            if DisplayableVignetteInfo(info, includeWorldMap) then
                local mapPosition = Call(C_VignetteInfo.GetVignettePosition, guid, mapID)
                local mapX, mapY = ReadXY(mapPosition)
                local worldX, worldY, instanceID = MapToWorld(mapID, mapPosition)
                if mapX and mapY and worldX and worldY then
                    local worldBoss = Features() and Features().IsWorldBoss(info) or false
                    local groupMin, groupMax
                    if C_VignetteInfo.GetRecommendedGroupSize then
                        local minimum, maximum = Call(C_VignetteInfo.GetRecommendedGroupSize, guid)
                        groupMin, groupMax = SafeNumber(minimum), SafeNumber(maximum)
                    end
                    targets[#targets + 1] = {
                        key = tostring(guid),
                        vignetteID = SafeNumber(SafeField(info, "vignetteID")),
                        objectGUID = SafeString(SafeField(info, "objectGUID")),
                        rewardQuestID = SafeNumber(SafeField(info, "rewardQuestID")),
                        isDead = SafeBoolean(SafeField(info, "isDead")),
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
                        groupMin = groupMin, groupMax = groupMax,
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

local function CollectQuests(mapID)
    local quests = {}
    if not (mapID and C_QuestLog and C_QuestLog.GetQuestsOnMap
        and (Settings().vignetteRadarQuestDots or Settings().vignetteRadarQuestAreas)) then
        return quests
    end
    local records = Call(C_QuestLog.GetQuestsOnMap, mapID)
    if IsSecret(records) or type(records) ~= "table" then return quests end
    local seen = {}
    for index = 1, math.min(#records, 256) do
        local record = records[index]
        local questID = SafeNumber(SafeField(record, "questID"))
        local x, y = SafeNumber(SafeField(record, "x")), SafeNumber(SafeField(record, "y"))
        if questID and questID > 0 and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1
            and not seen[questID] then
            local worldX, worldY, instanceID = MapToWorld(mapID, MapVector(x, y))
            if worldX and worldY then
                seen[questID] = true
                quests[#quests + 1] = {
                    questID = questID, mapX = x, mapY = y,
                    worldX = worldX, worldY = worldY, instanceID = instanceID,
                    name = SafeString(SafeField(record, "name"))
                        or SafeString(Call(C_QuestLog.GetTitleForQuestID, questID)) or "Quest location",
                }
            end
        end
    end
    return quests
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
    CollectQuests = CollectQuests,
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
        line:SetStartPoint("CENTER", field, math.cos(first) * radius, math.sin(first) * radius)
        line:SetEndPoint("CENTER", field, math.cos(last) * radius, math.sin(last) * radius)
        lines[index] = line
    end
    return lines
end

local function ResizeRing(lines, field, radius)
    for index, line in ipairs(lines) do
        local first, last = ((index - 1) / #lines) * TWO_PI, (index / #lines) * TWO_PI
        line:SetStartPoint("CENTER", field, math.cos(first) * radius, math.sin(first) * radius)
        line:SetEndPoint("CENTER", field, math.cos(last) * radius, math.sin(last) * radius)
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
    if target.isWorldBoss then
        if addon.VignetteRadarStyle then return addon.VignetteRadarStyle.Color("boss") end
        return RED[1], RED[2], RED[3]
    end
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
    local ctrl = IsControlKeyDown and IsControlKeyDown()
    local features = Features()
    if ctrl and button ~= "RightButton" and not target.sample then
        local exploration = addon.VignetteRadarExploration
        if exploration then
            if alt then exploration.Watch(target)
            else
                local ok, reason = exploration.AddRouteStop(target)
                if not ok then exploration.Tell(reason) end
            end
        end
    elseif button == "RightButton" then
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
    panel.target.glow:SetVertexColor(red, green, blue,
        panel.target._hovered and .25 or focusedKey and .20 or .05)
    panel.target:SetAlpha((focusedKey or panel.target._hovered) and 1 or .68)
end

local function Tooltip(owner)
    local target = owner.target
    if not (target and GameTooltip) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(target.name or "Detected vignette", 1, 1, 1)
    if owner.cluster and #owner.cluster > 1 then
        clusterHoverKey, clusterHoverUntil = owner.cluster[1].key, Now() + 2.5
        GameTooltip:AddLine(#owner.cluster .. " detections here; hover to spread them.", .52, .91, .77)
        for index = 2, math.min(#owner.cluster, 6) do
            GameTooltip:AddLine(owner.cluster[index].name or "Detected vignette", .7, .8, .77)
        end
    elseif owner.clusterKey then
        clusterHoverKey, clusterHoverUntil = owner.clusterKey, Now() + 2.5
    end
    local r, g, b = TargetColor(target)
    GameTooltip:AddLine(TargetKind(target), r, g, b)
    if target.distance then
        GameTooltip:AddLine(math.floor(target.distance + 0.5) .. " yd from you", 0.72, 0.76, 0.78)
    end
    if target.groupMin and target.groupMin > 0 then
        local group = target.groupMax and target.groupMax > target.groupMin
            and (target.groupMin .. "–" .. target.groupMax) or tostring(target.groupMin)
        GameTooltip:AddLine("Suggested group: " .. group, 0.85, 0.76, 0.53)
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
        GameTooltip:AddLine("Ctrl-click: route stop. Ctrl-Alt-click: watch approach.", 0.65, 0.80, 0.77, true)
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
            line:SetStartPoint("CENTER", owner, first[1] * size, first[2] * size)
            line:SetEndPoint("CENTER", owner, last[1] * size, last[2] * size)
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
        line:SetStartPoint("CENTER", frame, ux * 5, uy * 5)
        line:SetEndPoint("CENTER", frame, -ux * 4 - uy * side * 4, -uy * 4 + ux * side * 4)
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
        blip.count = Text(blip, 8, "")
        blip.count:SetPoint("BOTTOM", blip, "TOP", 0, -2)
        blip.count:SetTextColor(1, 1, 1, 1)
        blip.count:Hide()
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

local function HideQuestDots()
    if not panel or not panel.questDots then return end
    for _, dot in ipairs(panel.questDots) do dot:Hide() end
end

local function AddQuestTooltipObjectives(questID)
    local exploration = addon.VignetteRadarExploration
    if not (exploration and GameTooltip) then return end
    local lines = exploration.ObjectiveLines and exploration.ObjectiveLines(questID) or {}
    if #lines > 0 then
        GameTooltip:AddLine("Still needed", .58, .83, .73)
        for _, line in ipairs(lines) do GameTooltip:AddLine(line, 1, .86, .52, true) end
    end
    local progress = exploration.ObjectiveProgress and exploration.ObjectiveProgress(questID)
    if progress then GameTooltip:AddLine(progress, .7, .75, .78) end
end

local function HideMapNotes()
    if not panel or not panel.mapNotes then return end
    for _, dot in ipairs(panel.mapNotes) do dot:Hide() end
end

local MAP_NOTE_COLOR = { treasure = "treasure", mob = "rare", item = "event", note = "other" }
local MAP_NOTE_LABEL = { treasure = "Treasure", mob = "Mob", item = "Item", note = "Note" }
local function RenderMapNotes(player, range)
    local settings = Settings()
    if not (player and settings.vignetteRadarPOISource ~= "none") then HideMapNotes(); return 0 end
    local count = 0
    for _, note in ipairs(activeMapNotes) do
        if count >= MAX_MAP_NOTES then break end
        if settings.vignetteRadarPOITypes[note.kind] ~= false
            and not (addon.VignetteRadarRecent and addon.VignetteRadarRecent.IsHidden(note, settings))
            and not (player.instanceID and note.instanceID and player.instanceID ~= note.instanceID) then
            local dx, dy = note.worldX - player.worldX, note.worldY - player.worldY
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance >= 9 and distance <= range then
                local usePackIcon = settings.vignetteRadarPOIIcons == true and note.icon ~= nil
                local x, y = Project(dx, dy, distance, ViewFacing(player.facing),
                    panel.plotRadius - (usePackIcon and 11 or 5), range)
                if x and y then
                    count = count + 1
                    local dot = panel.mapNotes[count]
                    if not dot then
                        dot = CreateFrame("Button", nil, panel.field)
                        dot:SetSize(13, 13)
                        dot:SetFrameLevel(panel.field:GetFrameLevel() + 2)
                        dot.rim = dot:CreateTexture(nil, "ARTWORK")
                        dot.rim:SetSize(8, 8)
                        dot.rim:SetPoint("CENTER")
                        dot.rim:SetTexture(CIRCLE_TEXTURE)
                        dot.core = dot:CreateTexture(nil, "OVERLAY")
                        dot.core:SetSize(3, 3)
                        dot.core:SetPoint("CENTER")
                        dot.core:SetTexture(CIRCLE_TEXTURE)
                        dot.core:SetVertexColor(0.02, 0.03, 0.035, 0.95)
                        dot.icon = dot:CreateTexture(nil, "OVERLAY")
                        dot.icon:SetPoint("CENTER")
                        dot.icon:Hide()
                        dot:EnableMouseWheel(true)
                        dot:SetScript("OnMouseWheel", OnZoomWheel)
                        dot:SetScript("OnEnter", function(self)
                            if not (GameTooltip and self.note) then return end
                            local entry = self.note
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetText(entry.name, 1, 1, 1)
                            GameTooltip:AddLine(MAP_NOTE_LABEL[entry.kind] .. " map note · " .. entry.source,
                                0.72, 0.8, 0.82)
                            GameTooltip:AddLine(math.floor(self.distance + 0.5) .. " yd from you", 0.65, 0.7, 0.73)
                            if entry.note then GameTooltip:AddLine(entry.note, 0.7, 0.76, 0.78, true) end
                            GameTooltip:AddLine("Saved location, not a live detection.", 0.7, 0.78, 0.72, true)
                            if (entry.kind == "mob" or entry.kind == "treasure")
                                and Settings().vignetteRadarHideCleared then
                                GameTooltip:AddLine("Right-click: hide this location for 1 hour.", .58, .83, .73)
                            end
                            GameTooltip:Show()
                        end)
                        dot:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
                        dot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                        dot:SetScript("OnClick", function(self, button)
                            if button == "RightButton" and self.note
                                and (self.note.kind == "mob" or self.note.kind == "treasure")
                                and Settings().vignetteRadarHideCleared and addon.VignetteRadarRecent then
                                addon.VignetteRadarRecent.HideNote(self.note)
                                RefreshRadar(false)
                            end
                        end)
                        panel.mapNotes[count] = dot
                    end
                    local slot = MAP_NOTE_COLOR[note.kind] or "other"
                    local color = addon.VignetteRadarStyle
                    if color then dot.rim:SetVertexColor(color.Color(slot))
                    else dot.rim:SetVertexColor(0.7, 0.75, 0.78, 1) end
                    if usePackIcon then
                        local icon = note.icon
                        if dot._iconNote ~= note then
                            dot.icon:SetTexture(icon.texture)
                            if icon.texCoord then dot.icon:SetTexCoord(Unpack(icon.texCoord))
                            else dot.icon:SetTexCoord(0, 1, 0, 1) end
                            local tint = icon.color
                            dot.icon:SetVertexColor(tint and tint[1] or 1, tint and tint[2] or 1,
                                tint and tint[3] or 1, icon.alpha * (tint and tint[4] or 1))
                            dot.icon:SetSize(math.max(10, math.min(18, 12 * icon.scale)),
                                math.max(10, math.min(18, 12 * icon.scale)))
                            dot._iconNote = note
                        end
                        dot:SetSize(18, 18)
                        dot.rim:Hide()
                        dot.core:Hide()
                        dot.icon:Show()
                    else
                        dot:SetSize(13, 13)
                        dot.icon:Hide()
                        dot.rim:Show()
                        dot.core:Show()
                    end
                    dot.note, dot.distance = note, distance
                    dot:ClearAllPoints()
                    dot:SetPoint("CENTER", panel.field, "CENTER", x, y)
                    dot:Show()
                end
            end
        end
    end
    for index = count + 1, #panel.mapNotes do panel.mapNotes[index]:Hide() end
    return count
end

local function RenderQuestDots(player, range)
    if not (Settings().vignetteRadarQuestDots and player) then HideQuestDots(); return 0 end
    local count = 0
    for _, quest in ipairs(activeQuests) do
        if not (player.instanceID and quest.instanceID and player.instanceID ~= quest.instanceID) then
            local dx, dy = quest.worldX - player.worldX, quest.worldY - player.worldY
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance <= range and count < MAX_QUEST_DOTS then
                local x, y = Project(dx, dy, distance, ViewFacing(player.facing), panel.plotRadius, range)
                if x and y then
                    count = count + 1
                    local dot = panel.questDots[count]
                    if not dot then
                        dot = CreateFrame("Button", nil, panel.field)
                        dot:SetSize(12, 12)
                        dot:SetFrameLevel(panel.field:GetFrameLevel() + 3)
                        dot.rim = dot:CreateTexture(nil, "ARTWORK")
                        dot.rim:SetSize(8, 8)
                        dot.rim:SetPoint("CENTER")
                        dot.rim:SetTexture(CIRCLE_TEXTURE)
                        dot.rim:SetVertexColor(0.04, 0.04, 0.03, 0.9)
                        dot.fill = dot:CreateTexture(nil, "OVERLAY")
                        dot.fill:SetSize(5, 5)
                        dot.fill:SetPoint("CENTER")
                        dot.fill:SetTexture(CIRCLE_TEXTURE)
                        if addon.VignetteRadarStyle then
                            dot.fill:SetVertexColor(addon.VignetteRadarStyle.Color("quest"))
                        else
                            dot.fill:SetVertexColor(1, 0.74, 0.27, 1)
                        end
                        dot:EnableMouseWheel(true)
                        dot:SetScript("OnMouseWheel", OnZoomWheel)
                        dot:SetScript("OnEnter", function(self)
                            if not GameTooltip then return end
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetText(self.quest.name, 1, 0.82, 0.35)
                            GameTooltip:AddLine(math.floor(self.distance + 0.5) .. " yd from you", 0.72, 0.76, 0.78)
                            AddQuestTooltipObjectives(self.quest.questID)
                            GameTooltip:AddLine("Click to spotlight; click again to show all.", .6, .8, .72, true)
                            GameTooltip:Show()
                        end)
                        dot:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
                        dot:SetScript("OnClick", function(self)
                            local exploration = addon.VignetteRadarExploration
                            if exploration and self.quest then exploration.FocusQuest(self.quest.questID) end
                        end)
                        panel.questDots[count] = dot
                    end
                    dot.quest, dot.distance = quest, distance
                    local exploration = addon.VignetteRadarExploration
                    local spotlight = exploration and exploration.GetFocusedQuest()
                    dot:SetAlpha(spotlight and spotlight ~= quest.questID and .24 or 1)
                    dot:ClearAllPoints()
                    dot:SetPoint("CENTER", panel.field, "CENTER", x, y)
                    dot:Show()
                end
            end
        end
    end
    for index = count + 1, #panel.questDots do panel.questDots[index]:Hide() end
    return count
end

local function HideQuestAreas()
    if panel and panel.questBlob then
        if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == panel.questBlob then
            GameTooltip:Hide()
        end
        panel.questBlob.tooltipQuestID = nil
        panel.questBlob:Hide()
        panel.questBlob.drawnKey = nil
        panel.questBlob.nextDrawAt = nil
    end
end

local function UpdateQuestAreaTooltip()
    local blob = panel and panel.questBlob
    if not (blob and blob:IsShown() and GameTooltip and type(blob.UpdateMouseOverTooltip) == "function"
        and type(GetCursorPosition) == "function") then return end
    local owner = GameTooltip.GetOwner and GameTooltip:GetOwner()
    if owner and owner ~= blob and GameTooltip.IsShown and GameTooltip:IsShown() then return end
    local cursorX, cursorY = Call(GetCursorPosition)
    local scale = UIParent and UIParent.GetEffectiveScale and SafeNumber(UIParent:GetEffectiveScale()) or 1
    if not (SafeNumber(cursorX) and SafeNumber(cursorY) and scale and scale > 0) then return end
    cursorX, cursorY = cursorX / scale, cursorY / scale
    local field = panel.field
    local fieldLeft, fieldTop = SafeNumber(field:GetLeft()), SafeNumber(field:GetTop())
    local blobLeft, blobTop = SafeNumber(blob:GetLeft()), SafeNumber(blob:GetTop())
    local width, height = SafeNumber(blob:GetWidth()), SafeNumber(blob:GetHeight())
    local questID
    if fieldLeft and fieldTop and blobLeft and blobTop and width and height and width > 0 and height > 0 then
        local fromCenterX = cursorX - fieldLeft - field:GetWidth() / 2
        local fromCenterY = cursorY - fieldTop + field:GetHeight() / 2
        local inside
        if panel.squarePlot then
            inside = math.abs(fromCenterX) <= panel.fieldRadius - QUEST_CLIP_INSET
                and math.abs(fromCenterY) <= panel.fieldRadius - QUEST_CLIP_INSET
        else
            inside = fromCenterX * fromCenterX + fromCenterY * fromCenterY <= panel.fieldRadius * panel.fieldRadius
        end
        if inside then
            local x, y = (cursorX - blobLeft) / width, (blobTop - cursorY) / height
            if x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                questID = SafeNumber(Call(blob.UpdateMouseOverTooltip, blob, x, y))
            end
        end
    end
    local quest
    if questID then
        for _, candidate in ipairs(activeQuests) do
            if candidate.questID == questID then quest = candidate; break end
        end
    end
    if not quest then
        if owner == blob then GameTooltip:Hide() end
        blob.tooltipQuestID = nil
        return
    end
    if blob.tooltipQuestID == questID and owner == blob and GameTooltip:IsShown() then return end
    blob.tooltipQuestID = questID
    GameTooltip:SetOwner(blob, "ANCHOR_CURSOR_RIGHT", 5, 2)
    GameTooltip:SetText(quest.name, 1, .82, .35)
    GameTooltip:AddLine("Quest area", .72, .76, .78)
    AddQuestTooltipObjectives(quest.questID)
    GameTooltip:AddLine("Click to spotlight; click again to show all.", .6, .8, .72, true)
    GameTooltip:Show()
end

local function RenderQuestAreas(player, mapID, range)
    local blob = panel.questBlob
    if not (blob and player and mapID and Settings().vignetteRadarQuestAreas
        and Settings().vignetteRadarNorthUp and #activeQuests > 0) then
        HideQuestAreas()
        return
    end
    -- Blizzard's quest widget draws in map coordinates. Keep its full-map canvas
    -- aligned with the north-up radar, and clip it to the plotting frame.
    local now = Now()
    if not questMapBasis or questMapBasis.mapID ~= mapID
        or (not questMapBasis.horizontal and now >= questMapBasis.retryAt) then
        local originX, originY, originInstance = MapToWorld(mapID, MapVector(0, 0))
        local rightX, rightY, rightInstance = MapToWorld(mapID, MapVector(1, 0))
        local downX, downY, downInstance = MapToWorld(mapID, MapVector(0, 1))
        -- A zone's map coordinates can be unavailable on the first attempt.
        -- Retry a failed projection instead of caching that failure for the zone.
        questMapBasis = { mapID = mapID, retryAt = now + RESCAN_SECONDS }
        if originX and rightX and downX
            and (not originInstance or not rightInstance or originInstance == rightInstance)
            and (not originInstance or not downInstance or originInstance == downInstance) then
            local horizontal = math.sqrt((rightX - originX)^2 + (rightY - originY)^2)
            local vertical = math.sqrt((downX - originX)^2 + (downY - originY)^2)
            -- Native blobs cannot rotate. Only show them when map axes match the radar.
            if horizontal > 0 and vertical > 0 and math.abs(rightX - originX) <= horizontal * 0.03
                and rightY < originY and math.abs(downY - originY) <= vertical * 0.03 and downX < originX then
                questMapBasis.horizontal, questMapBasis.vertical = horizontal, vertical
            end
        end
    end
    if not questMapBasis.horizontal then HideQuestAreas(); return end
    local pixelsPerYard = panel.plotRadius / range
    local width, height = questMapBasis.horizontal * pixelsPerYard, questMapBasis.vertical * pixelsPerYard
    if width > 8192 or height > 8192 or width < 1 or height < 1 then HideQuestAreas(); return end
    local exploration = addon.VignetteRadarExploration
    local spotlight = exploration and exploration.GetFocusedQuest()
    local key = tostring(mapID) .. ":" .. tostring(width) .. ":" .. tostring(height) .. ":" .. tostring(spotlight)
    for _, quest in ipairs(activeQuests) do key = key .. ":" .. tostring(quest.questID) end
    blob:SetSize(width, height)
    blob:ClearAllPoints()
    blob:SetPoint("CENTER", panel.field, "CENTER", (0.5 - player.mapX) * width, (player.mapY - 0.5) * height)
    if blob.drawnKey ~= key or now >= (blob.nextDrawAt or 0) then
        local ok = true
        if blob.mapContextID ~= mapID then
            ok = pcall(blob.SetMapID, blob, mapID)
            if ok then blob.mapContextID = mapID end
        end
        if ok then ok = pcall(blob.DrawNone, blob) end
        if ok then
            for _, quest in ipairs(activeQuests) do
                if not spotlight or spotlight == quest.questID then
                    if not pcall(blob.DrawBlob, blob, quest.questID, true) then ok = false; break end
                end
            end
        end
        if not ok then HideQuestAreas(); return end
        blob.drawnKey = key
        -- DrawBlob has no readiness result: a successful call can precede its
        -- data. Refresh at the scan interval as well as on quest-data events.
        blob.nextDrawAt = now + RESCAN_SECONDS
    end
    blob:Show()
    return true
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
    blip.cluster, blip.clusterKey = nil, nil
    blip.count:Hide()
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

local function RenderExploration(player, range)
    local exploration = addon.VignetteRadarExploration
    if not exploration or not panel then return end
    panel.exploreLines = panel.exploreLines or {}
    panel.exploreDots = panel.exploreDots or {}
    panel.trailDots = panel.trailDots or {}
    panel.trailMarks = panel.trailMarks or {}
    panel.trailExtraMarks = panel.trailExtraMarks or {}
    for _, line in ipairs(panel.exploreLines) do line:Hide() end
    for _, dot in ipairs(panel.exploreDots) do dot:Hide() end
    for _, dot in ipairs(panel.trailDots) do dot:Hide() end
    for _, mark in ipairs(panel.trailMarks) do mark:Hide() end
    for _, mark in pairs(panel.trailExtraMarks) do mark:Hide() end
    if not player then return end
    local lineCount, dotCount = 0, 0
    local function Position(item, clamp)
        if player.instanceID and item.instanceID and player.instanceID ~= item.instanceID then return nil end
        local worldX = SafeNumber(item.worldX) or SafeNumber(item.x)
        local worldY = SafeNumber(item.worldY) or SafeNumber(item.y)
        if not worldX or not worldY then return nil end
        local dx, dy = worldX - player.worldX, worldY - player.worldY
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance > range and not clamp then return nil end
        local x, y = Project(dx, dy, distance, ViewFacing(player.facing), panel.plotRadius, range)
        if not x then return nil end
        if clamp and distance > range then
            local factor = panel.plotRadius / math.max(1, math.sqrt(x*x + y*y))
            x, y = x * factor, y * factor
        end
        return x, y, distance
    end
    local function Line(x1, y1, x2, y2, r, g, b, a, thick)
        lineCount = lineCount + 1
        local line = panel.exploreLines[lineCount]
        if not line then
            line = panel.field:CreateLine(nil, "ARTWORK")
            panel.exploreLines[lineCount] = line
        end
        line:SetThickness(thick or 1)
        line:SetColorTexture(r, g, b, a)
        line:SetStartPoint("CENTER", panel.field, x1, y1)
        line:SetEndPoint("CENTER", panel.field, x2, y2)
        line:Show()
    end
    local function Dot(item, x, y, label, r, g, b, onClick)
        dotCount = dotCount + 1
        local dot = panel.exploreDots[dotCount]
        if not dot then
            dot = CreateFrame("Button", nil, panel.field)
            dot:SetSize(16, 16)
            dot:SetFrameLevel(panel.field:GetFrameLevel() + 2)
            dot.fill = dot:CreateTexture(nil, "ARTWORK")
            dot.fill:SetSize(10, 10)
            dot.fill:SetPoint("CENTER")
            dot.fill:SetTexture(CIRCLE_TEXTURE)
            dot.text = Text(dot, 8, "")
            dot.text:SetAllPoints()
            dot.text:SetJustifyH("CENTER")
            dot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            dot:SetScript("OnEnter", function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.item.name or "Stop", 1, 1, 1)
                GameTooltip:AddLine(self.hint or "", .65, .8, .75, true)
                GameTooltip:Show()
            end)
            dot:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            dot:SetScript("OnClick", function(self, button)
                if self.onClick then self.onClick(self.item, button) end
            end)
            panel.exploreDots[dotCount] = dot
        end
        dot.item, dot.onClick = item, onClick
        local dx, dy = item.worldX-player.worldX, item.worldY-player.worldY
        local distance = math.floor(math.sqrt(dx*dx+dy*dy)+.5)
        dot.hint = label == "" and (distance .. " yd straight line. Click: route; right-click: remove.")
            or ("Route stop " .. label .. " • " .. distance .. " yd straight line")
        dot.fill:SetVertexColor(r, g, b, .9)
        dot.text:SetText(label)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", panel.field, "CENTER", x, y)
        dot:Show()
    end
    local trail, trailMap = exploration.GetTrail()
    if Settings().vignetteRadarBreadcrumbs and trailMap == player.mapID then
        if not panel.trailLayer then
            local layer = CreateFrame("Frame", nil, panel.field)
            layer:SetAllPoints(panel.field)
            layer:SetFrameLevel(panel.field:GetFrameLevel() + 3)
            layer:EnableMouse(false)
            panel.trailLayer = layer
        end
        local trailDotCount = 0
        local definition = TRAIL_STYLE_BY_ID[Settings().vignetteRadarTrailStyle] or TRAIL_STYLES[1]
        local spacing = definition.spacing * (Settings().vignetteRadarTrailSpacing or 1)
        local sizeScale = Settings().vignetteRadarTrailSize or 1
        local tailFade = Settings().vignetteRadarTrailTailFade or 0
        local limit = definition.segments and #definition.segments > 2 and 48 or 64
        local edge = panel.plotRadius - 7
        local now = Now()
        local nextDot = (now * (Settings().vignetteRadarTrailSpeed or 1) * 8) % spacing
        local lifetime = Settings().vignetteRadarTrailLifetime or 180
        local r, g, b = .25, .91, .7
        if addon.VignetteRadarStyle then r, g, b = addon.VignetteRadarStyle.Color("accent") end
        local extraParts = {}
        local function TrailSegment(x1, y1, x2, y2, alpha, progress)
            local dx, dy = x2 - x1, y2 - y1
            local length = math.sqrt(dx*dx + dy*dy)
            if length < .01 then return end
            if length > edge * 4 then nextDot = 0; return end
            local offset = nextDot
            local steps = 0
            while offset <= length and trailDotCount < limit and steps < 128 do
                steps = steps + 1
                local x, y = x1 + dx * offset / length, y1 + dy * offset / length
                local radiusSquared = x*x + y*y
                if radiusSquared >= 49 and radiusSquared <= edge*edge then
                    trailDotCount = trailDotCount + 1
                    local visibleProgress = math.max(progress + offset / length / #trail,
                        (trailDotCount - 1) / math.max(1, limit - 1))
                    local markAlpha = alpha * (1 - tailFade * math.min(1, visibleProgress))
                    if definition.dot or definition.square then
                        local dot = panel.trailDots[trailDotCount]
                        if not dot then
                            dot = panel.trailLayer:CreateTexture(nil, "BACKGROUND")
                            panel.trailDots[trailDotCount] = dot
                        end
                        local texture = definition.square and SQUARE_TEXTURE or CIRCLE_TEXTURE
                        if dot._trailTexture ~= texture then
                            dot:SetTexture(texture)
                            dot._trailTexture = texture
                        end
                        DrawTrailGlyph(definition, dot, nil, panel.field, x, y,
                            dx / length, dy / length, r, g, b, markAlpha, trailDotCount, sizeScale)
                    else
                        local mark = panel.trailMarks[trailDotCount]
                        if not mark then
                            mark = panel.trailLayer:CreateLine(nil, "BACKGROUND")
                            panel.trailMarks[trailDotCount] = mark
                        end
                        for part = 2, #definition.segments do
                            local slot = (trailDotCount - 1) * 3 + part - 1
                            local extra = panel.trailExtraMarks[slot]
                            if not extra then
                                extra = panel.trailLayer:CreateLine(nil, "BACKGROUND")
                                panel.trailExtraMarks[slot] = extra
                            end
                            extraParts[part - 1] = extra
                        end
                        DrawTrailGlyph(definition, mark, extraParts, panel.field, x, y,
                            dx / length, dy / length, r, g, b, markAlpha, trailDotCount, sizeScale)
                    end
                end
                offset = offset + spacing
            end
            nextDot = steps >= 128 and 0 or offset - length
        end
        local priorX, priorY = 0, 0
        for index = #trail, 1, -1 do
            if trailDotCount >= limit then break end
            local point = trail[index]
            local x, y = Position(point, false)
            if x and priorX and trailDotCount < limit then
                local age = math.max(0, now - point.at)
                local alpha = (.3 + .65 * index / #trail) * math.max(0, 1 - age / lifetime)
                TrailSegment(priorX, priorY, x, y, alpha, (#trail - index) / #trail)
            end
            priorX, priorY = x, y
            if not x then nextDot = 0 end
        end
    end
    for _, pin in ipairs(exploration.GetPins(player.mapID)) do
        local x, y, distance = Position(pin, false)
        if x and distance > 12 then
            Dot(pin, x, y, "", .92, .71, .34, function(item, button)
                if button == "RightButton" then exploration.RemovePin(item.id)
                else exploration.AddRouteStop(item) end
            end)
        end
    end
    local priorX, priorY = 0, 0
    for index, stop in ipairs(exploration.GetRoute(player.mapID)) do
        local x, y, distance = Position(stop, true)
        if x then
            if distance > 12 then
                Line(priorX, priorY, x, y, .3, .88, .71, .55, 1.7)
                Dot(stop, x, y, tostring(index), .16, .7, .54, nil)
            end
            priorX, priorY = x, y
        end
    end
end

local CARDINALS = {
    { text = "N", angle = 0 },
    { text = "W", angle = math.pi / 2 },
    { text = "S", angle = math.pi },
    { text = "E", angle = -math.pi / 2 },
}

local function RenderCardinals(facing)
    local radius = panel.fieldRadius - (panel.squarePlot and 8 or 5)
    for index, definition in ipairs(CARDINALS) do
        local relative = NormalizeAngle(definition.angle - facing)
        local label = panel.cardinals[index]
        label:ClearAllPoints()
        label:SetPoint("CENTER", panel.field, "CENTER",
            -math.sin(relative) * radius, math.cos(relative) * radius)
    end
end

local function UpdateRingLabels(range)
    panel.innerLabel:SetText(math.floor(range / 3) .. "y")
    panel.outerLabel:SetText(math.floor((range * 2) / 3) .. "y")
end

local function PanelScale(value)
    local maximum = 1.8
    if UIParent and UIParent.GetWidth and UIParent.GetHeight then
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        if SafeNumber(width) and SafeNumber(height) and width > 0 and height > 0 then
            maximum = math.min(maximum, (width - 8) / panel:GetWidth(), (height - 8) / panel:GetHeight())
            -- Reserve room for the wider target picker beside the panel on small screens.
            maximum = math.min(maximum, (width - 274) / panel:GetWidth())
        end
    end
    return math.max(0.8, math.min(value, maximum))
end

local function PlacePanel(left, top, scale)
    if not (UIParent and UIParent.GetWidth and UIParent.GetHeight) then return end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not (SafeNumber(width) and SafeNumber(height) and width > 0 and height > 0) then return end
    scale = PanelScale(scale)
    panel:SetScale(scale)
    if Settings().vignetteRadarCircleOnly == true then
        local layoutName = panel.layout or Settings().vignetteRadarLayout
        local layout = LAYOUTS[layoutName] or LAYOUTS.classic
        local fieldLeft = layoutName == "squat" and 10 or (layout.width - layout.field) / 2
        local fieldBottom = layoutName == "squat" and 38
            or (layout.footer or ZOOM_FOOTER_H) + (panel.layoutFocused and (layout.focus or 0) or 0) + 9
        -- The hidden frame may leave the screen. Keep the face and restore chevron visible.
        local lowerLeft = 4 - fieldLeft * scale
        local upperLeft = width - 4 - (fieldLeft + layout.field + 5) * scale
        local lowerTop = 4 + (panel:GetHeight() - fieldBottom) * scale
        local upperTop = height - 4 + (panel:GetHeight() - fieldBottom - layout.field) * scale
        left = math.max(lowerLeft, math.min(left, upperLeft))
        top = math.max(lowerTop, math.min(top, upperTop))
    else
        left = math.max(4, math.min(left, width - panel:GetWidth() * scale - 4))
        top = math.max(panel:GetHeight() * scale + 4, math.min(top, height - 4))
    end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, top - height)
end

local function ApplyPanelLayout(focused)
    local name = Settings().vignetteRadarLayout or "classic"
    local square = Settings().vignetteRadarQuestAreas == true
    if not LAYOUTS[name] then name = "classic" end
    if panel.layout == name and panel.layoutFocused == focused and panel.squarePlot == square then return end
    local changed = panel.layout ~= name
    local layout = LAYOUTS[name]
    local left, top = SafeNumber(panel:GetLeft()), SafeNumber(panel:GetTop())
    panel.layout, panel.layoutFocused, panel.squarePlot = name, focused, square
    panel.fieldRadius = layout.field / 2 - 9
    panel.plotRadius = panel.fieldRadius - 15
    panel:SetSize(layout.width, layout.height + (focused and layout.focus or 0))
    if left and top then PlacePanel(left, top, Settings().vignetteRadarScale or 1) end
    panel.field:SetSize(layout.field, layout.field)
    -- Keep one native rectangular clip, inset far enough that its corners stay
    -- inside the rounded face, including the anti-aliased outline's inner edge.
    local radius = panel.fieldRadius
    panel.field.background:ClearAllPoints()
    if square then
        panel.field.background:SetTexture(ROUNDED_SQUARE_TEXTURE)
        panel.field.background:SetPoint("CENTER", panel.field, "CENTER")
        panel.field.background:SetSize(radius * 2, radius * 2)
    else
        panel.field.background:SetTexture(CIRCLE_TEXTURE)
        panel.field.background:SetAllPoints(panel.field)
    end
    panel.questClip:ClearAllPoints()
    panel.questClip:SetPoint("CENTER", panel.field, "CENTER")
    panel.questClip:SetSize((radius - QUEST_CLIP_INSET) * 2, (radius - QUEST_CLIP_INSET) * 2)
    panel.squareBorder:SetSize(radius * 2, radius * 2)
    panel.squareBorder:SetShown(square)
    panel.field.halo:SetShown(not square)
    for _, line in ipairs(panel.outerRing) do line:SetShown(not square) end
    if panel.frameToggle then
        panel.frameToggle:ClearAllPoints()
        panel.frameToggle:SetPoint("CENTER", panel.field, "CENTER",
            radius + (square and 8 or 5), 0)
        panel.frameToggle:SetWidth(square and 10 or 16)
        panel.frameToggle.glow:SetSize(square and 10 or 16, square and 10 or 16)
    end
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
    panel.layoutHint:SetShown(false)
    panel.sideCaption:SetShown(name == "squat")
    panel.sideGuide:SetShown(name == "squat")
    if name == "squat" then
        -- The plotting area beside the readout keeps this view short even while focused.
        Place(panel.field, "BOTTOMLEFT", 10, 38)
        Place(panel.title, "TOPLEFT", 214, -16, 122, 13)
        Place(panel.summary, "TOPLEFT", 214, -35, 148, 10)
        Place(panel.drag, "TOPLEFT", 208, -8, 130, 47)
        Place(panel.settingsDot, "TOPRIGHT", -10, -12)
        Place(panel.focusDivider, "BOTTOMLEFT", 202, 42, 1, 174)
        Place(panel.sideCaption, "TOPLEFT", 214, -68, 148, 12)
        Place(panel.focusReadout, "TOPLEFT", 214, -91, 148, 68)
        Place(panel.layoutHint, "TOPLEFT", 214, -91, 148, 54)
        Place(panel.sideGuide, "TOPLEFT", 214, -173, 148, 14)
        Place(panel.zoomOut, "BOTTOMLEFT", 12, 8)
        Place(panel.zoomLabel, "BOTTOMLEFT", 42, 12, 110, 12)
        Place(panel.zoomIn, "BOTTOMLEFT", 160, 8)
        Place(panel.combatToggle, "BOTTOMLEFT", 192, 9)
        Place(panel.compass, "BOTTOMLEFT", 214, 8)
        Place(panel.trailToggle, "BOTTOMLEFT", 246, 8)
        Place(panel.target, "BOTTOMRIGHT", -74, 8)
        Place(panel.legend, "BOTTOMRIGHT", -42, 8)
        Place(panel.close, "BOTTOMRIGHT", -10, 8)
    else
        local compact = name == "compact"
        local footer = layout.footer
        Place(panel.field, "BOTTOM", 0, footer + (focused and layout.focus or 0) + 9)
        Place(panel.title, "TOPLEFT", 12, -6, compact and 136 or 100, 13)
        Place(panel.summary, "TOPLEFT", 12, -21, compact and 136 or 100, 10)
        Place(panel.drag, "TOPLEFT", 4, -3, compact and 144 or 106, 28)
        Place(panel.settingsDot, "TOPRIGHT", compact and -10 or -85, -6)
        Place(panel.focusDivider, "BOTTOM", 0, footer + layout.focus, layout.width - 24, 1)
        Place(panel.focusReadout, "BOTTOMLEFT", 12, footer + 8, layout.width - 24, compact and 50 or 32)
        if compact then
            Place(panel.zoomLabel, "BOTTOM", 0, 38, 92, 12)
            Place(panel.combatToggle, "BOTTOMLEFT", 146, 32)
            Place(panel.trailToggle, "BOTTOMLEFT", 18, 30)
        else
            Place(panel.zoomLabel, "BOTTOMLEFT", 118, 10, 62, 12)
            Place(panel.combatToggle, "BOTTOMLEFT", 72, 7)
            Place(panel.trailToggle, "BOTTOMLEFT", 94, 6)
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
    panel.focusName:SetHeight(name == "squat" and 26 or 13)
    panel.focusName:SetWordWrap(name == "squat")
    if panel.resizeGrips then
        panel.resizeGrips.top:SetWidth(layout.width - 20)
        panel.resizeGrips.bottom:SetWidth(layout.width - 20)
        panel.resizeGrips.left:SetHeight(panel:GetHeight() - 20)
        panel.resizeGrips.right:SetHeight(panel:GetHeight() - 20)
    end
    if changed then
        -- Close pop-outs; opening them again chooses the side that fits the resized panel.
        if HideTrailPopup then HideTrailPopup() end
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
    local quick = addon.VignetteRadarQuickConfig
    if quick and quick.Reanchor then quick.Reanchor(panel) end
end

local function UpdateFocusReadout(target, player, selected)
    ApplyPanelLayout(selected and Settings().vignetteRadarCircleOnly ~= true)
    local squat = panel.layout == "squat"
    panel.focusReadout:SetShown(target ~= nil)
    panel.focusDivider:SetShown(selected or squat)
    panel.layoutHint:SetShown(squat and target == nil)
    if squat then
        local outside = target and target.distance and target.distance > (displayedRange or Settings().vignetteRadarRange)
        local questContext = not target and #activeQuests > 0 and (Settings().vignetteRadarQuestDots
            or (Settings().vignetteRadarQuestAreas and Settings().vignetteRadarNorthUp))
        panel.sideCaption:SetText(selected and "TRACKING" or (outside and "OUTSIDE RADAR RANGE"
            or (target and "NEAREST DETECTION" or (questContext and "QUEST LOCATIONS" or "NO DETECTIONS"))))
        panel.sideGuide:SetText(selected and "CLICK AGAIN TO SHOW ALL" or (outside and "ZOOM OUT TO SEE IT"
            or (target and "CLICK TO FOCUS" or (questContext and "ZOOM FOR QUEST DETAIL" or "MOVE OR CHECK THE MAP"))))
        if not target then panel.layoutHint:SetText(questContext and "Your quest locations are on the radar."
            or "Nothing detected here yet.") end
    end
    panel.edgeArrow:Hide()
    if not target then return end
    panel.focusReadout.target = target
    panel.focusName:SetText((Favorite(target) and "* " or "") .. (target.name or "Detected vignette"))
    local age = target.stale and math.floor(math.max(0, Now() - target.lastSeenAt)) or nil
    local kind = target.isWorldBoss and "BOSS" or (target.category or "other"):upper()
    local detail = kind .. " | "
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
    if squat then panel.focusName:SetTextColor(r, g, b, 1)
    else panel.focusName:SetTextColor(0.88, 0.90, 0.92, 1) end
    local x, y
    if target.sample then x, y = PreviewPosition(target.x, target.y)
    elseif player and (player.headingAvailable or Settings().vignetteRadarNorthUp == true) then
        x, y = Project(target.worldX - player.worldX, target.worldY - player.worldY,
            target.distance or 0, ViewFacing(player.facing), 1, math.max(1, target.distance or 1))
    end
    panel.focusArrow:SetShown(x ~= nil and y ~= nil)
    if x and y then
        DrawArrow(panel.focusArrow, x, y, r, g, b)
        local range = displayedRange or tonumber(Settings().vignetteRadarRange) or 450
        if selected and not target.stale and target.distance and target.distance > range then
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

local function UpdatePanelChrome()
    local circleOnly = Settings().vignetteRadarCircleOnly == true
    local style = addon.VignetteRadarStyle
    local br, bg, bb = .02, .025, .03
    if style then br, bg, bb = style.Color("background") end
    panel:SetBackdropColor(math.min(.14, br * 2.7), math.min(.14, bg * 2.7),
        math.min(.14, bb * 2.7), circleOnly and 0 or .98)
    panel:SetBackdropBorderColor(1, 1, 1, circleOnly and 0 or .15)
    panel:EnableMouseWheel(not circleOnly)
    for _, control in ipairs({ panel.title, panel.summary, panel.drag, panel.settingsDot,
        panel.zoomOut, panel.zoomIn, panel.zoomLabel, panel.combatToggle, panel.trailToggle, panel.compass,
        panel.target, panel.legend, panel.close }) do
        control:SetShown(not circleOnly)
    end
    if circleOnly then
        panel.focusReadout:Hide()
        panel.focusDivider:Hide()
        panel.layoutHint:Hide()
        panel.sideCaption:Hide()
        panel.sideGuide:Hide()
    else
        panel.sideCaption:SetShown(panel.layout == "squat")
        panel.sideGuide:SetShown(panel.layout == "squat")
    end
    if panel.resizeGrips then
        for _, grip in pairs(panel.resizeGrips) do grip:SetShown(not circleOnly) end
    end
    local button = panel.frameToggle
    if button then
        if button._circleOnly ~= circleOnly then
            button._circleOnly = circleOnly
            local direction = circleOnly and 1 or -1
            button.chevron[1]:SetStartPoint("CENTER", button, -direction * 2, -4)
            button.chevron[1]:SetEndPoint("CENTER", button, direction * 2, 0)
            button.chevron[2]:SetStartPoint("CENTER", button, direction * 2, 0)
            button.chevron[2]:SetEndPoint("CENTER", button, -direction * 2, 4)
        end
        local opacity = button._hovered and 1 or (circleOnly and .82 or .62)
        for _, line in ipairs(button.chevron) do
            line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], opacity)
        end
        button.glow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], button._hovered and .18 or 0)
    end
end

local appearanceKey, appearancePanel, appearanceLauncher
ApplyAppearance = function()
    local style = addon.VignetteRadarStyle
    if not style then return end
    local db = Settings()
    local key = table.concat({ db.vignetteRadarTheme or "verdant", style.revision or 0,
        db.vignetteRadarRingOpacity or .5, db.vignetteRadarChevronOpacity or .72,
        db.vignetteRadarHeadingOpacity or .46 }, ":")
    if key == appearanceKey and panel == appearancePanel and launcher == appearanceLauncher then return end
    appearanceKey, appearancePanel, appearanceLauncher = key, panel, launcher
    local ar, ag, ab = style.Color("accent")
    local rr, rg, rb = style.Color("rings")
    local hr, hg, hb = style.Color("heading")
    local br, bg, bb = style.Color("background")
    ACCENT[1], ACCENT[2], ACCENT[3] = ar, ag, ab
    RED[1], RED[2], RED[3] = style.Color("boss")
    if panel then
        panel:SetBackdropColor(math.min(.14, br * 2.7), math.min(.14, bg * 2.7),
            math.min(.14, bb * 2.7), .98)
        panel.title:SetTextColor(ar, ag, ab, 1)
        panel.field.background:SetVertexColor(br, bg, bb, .94)
        panel.field.halo:SetVertexColor(rr, rg, rb, .18 * db.vignetteRadarRingOpacity)
        panel.squareBorder:SetVertexColor(rr, rg, rb, .12 * db.vignetteRadarRingOpacity)
        for _, group in ipairs({ { panel.outerRing, .02 }, { panel.rangeRing, .045 },
            { panel.middleRing, .04 }, { panel.innerRing, .03 } }) do
            for _, line in ipairs(group[1]) do
                line:SetColorTexture(rr, rg, rb, group[2] * db.vignetteRadarRingOpacity)
            end
        end
        panel.direction:SetColorTexture(hr, hg, hb, db.vignetteRadarHeadingOpacity)
        for _, line in ipairs(panel.headingChevron) do
            line:SetColorTexture(hr, hg, hb, db.vignetteRadarChevronOpacity)
        end
        panel.player:SetVertexColor(ar, ag, ab, 1)
        panel.playerGlow:SetVertexColor(ar, ag, ab, .25)
        panel.innerLabel:SetTextColor(rr, rg, rb, .55)
        panel.outerLabel:SetTextColor(rr, rg, rb, .55)
        panel.settingsDot.dot:SetVertexColor(ar, ag, ab, 1)
        panel.settingsDot.rim:SetVertexColor(ar, ag, ab, .20)
        panel.settingsDot.inner:SetVertexColor(br, bg, bb, 1)
        panel.legend.glow:SetVertexColor(ar, ag, ab,
            panel.legend._hovered and .18 or panel.legend._open and .12 or 0)
        panel.close.glow:SetVertexColor(ar, ag, ab, panel.close._hovered and .18 or 0)
        for _, button in ipairs({ panel.zoomOut, panel.zoomIn, panel.compass, panel.trailToggle }) do
            if button and button.RefreshAppearance then button:RefreshAppearance() end
        end
        if RefreshTrailPopup then RefreshTrailPopup() end
        if panel.legend and panel.legend.dots then
            for index, slot in ipairs({ "rare", "treasure", "event" }) do
                panel.legend.dots[index]:SetVertexColor(style.Color(slot))
            end
        end
    end
    if launcher then
        launcher.face:SetVertexColor(br, bg, bb, .98)
        launcher.center:SetVertexColor(ar, ag, ab, 1)
        launcher.centerGlow:SetVertexColor(ar, ag, ab, .22)
        launcher.direction:SetColorTexture(hr, hg, hb, db.vignetteRadarHeadingOpacity)
        for _, line in ipairs(launcher.ring) do line:SetColorTexture(rr, rg, rb, .18) end
    end
    if addon.VignetteRadarControls and addon.VignetteRadarControls.RefreshTheme then
        addon.VignetteRadarControls.RefreshTheme()
    end
    local legend = LegendAPI()
    if legend and legend.Refresh then legend.Refresh() end
end

local function UpdateFullSweep(elapsed)
    if not (panel and panel.sweepLines) then return end
    local enabled = Settings().vignetteRadarFullSweep == true and panel:IsShown()
    if not enabled then
        for _, line in ipairs(panel.sweepLines) do line:Hide() end
        return
    end
    panel._sweepAngle = ((panel._sweepAngle or 0) + (elapsed or 0) * .72) % TWO_PI
    for index, line in ipairs(panel.sweepLines) do
        local angle = panel._sweepAngle - ((index - 1) * .13)
        line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], index == 1 and .17 or .07)
        line:SetStartPoint("CENTER", panel.field, 0, 0)
        line:SetEndPoint("CENTER", panel.field, math.sin(angle) * panel.plotRadius,
            math.cos(angle) * panel.plotRadius)
        line:Show()
    end
end

local function UpdateCombatToggle()
    if not (panel and panel.combatToggle) then return end
    local button = panel.combatToggle
    local keepVisible = Settings().vignetteRadarKeepVisibleCombat == true
    local red, green, blue, opacity
    if keepVisible then
        red, green, blue, opacity = ACCENT[1], ACCENT[2], ACCENT[3], 1
    else
        red, green, blue, opacity = .62, .70, .71, button._hovered and .9 or .62
    end
    for _, line in ipairs(button.eye) do
        line:SetColorTexture(red, green, blue, opacity)
    end
    button.pupil:SetVertexColor(red, green, blue, opacity)
    button.glow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3],
        button._hovered and .16 or (keepVisible and .1 or 0))
    button.keepVisible = keepVisible
end

local function UpdateTrailToggle()
    if not (panel and panel.trailToggle) then return end
    local button = panel.trailToggle
    local style = Settings().vignetteRadarTrailStyle or "dashes"
    local selected = Settings().vignetteRadarBreadcrumbs == true
    if button._style ~= style then
        button._style = style
        local definition = TRAIL_STYLE_BY_ID[style] or TRAIL_STYLES[1]
        for index, line in ipairs(button.trailMarks) do
            local x = (index - 2) * 5
            local segments = definition.segments
            for part = 1, 4 do
                local glyphLine = part == 1 and line or button.trailExtras[index][part - 1]
                local segment = segments and segments[part]
                if segment then
                    local scale = definition.alternating and index % 2 == 0 and .3 or .6
                    glyphLine:SetThickness(segment[5] * .8)
                    glyphLine:SetStartPoint("CENTER", button,
                        x + segment[1] * scale, segment[2] * scale)
                    glyphLine:SetEndPoint("CENTER", button,
                        x + segment[3] * scale, segment[4] * scale)
                    glyphLine:Show()
                elseif part == 1 and (definition.dot or definition.square) then
                    local size = definition.alternating and index % 2 == 0 and 2 or 3.2
                    glyphLine:SetThickness(size)
                    glyphLine:SetStartPoint("CENTER", button, x - .1, 0)
                    glyphLine:SetEndPoint("CENTER", button, x + .1, 0)
                    glyphLine:Show()
                else
                    glyphLine:Hide()
                end
            end
        end
        button:RefreshAppearance()
    end
    if button._selected ~= selected then button._selected = selected; button:RefreshAppearance() end
end

HideTrailPopup = function()
    if trailPopup and trailPopup:IsShown() then trailPopup:Hide() end
end

RefreshTrailPopup = function()
    if not trailPopup then return end
    local style = addon.VignetteRadarStyle
    local ar, ag, ab = ACCENT[1], ACCENT[2], ACCENT[3]
    local br, bg, bb = .045, .052, .06
    if style then
        ar, ag, ab = style.Color("accent")
        br, bg, bb = style.Color("background")
    end
    trailPopup:SetBackdropColor(math.min(.14, br * 2.7), math.min(.14, bg * 2.7),
        math.min(.14, bb * 2.7), .98)
    trailPopup.rail:SetColorTexture(ar, ag, ab, .8)
    trailPopup.title:SetTextColor(ar, ag, ab, 1)
    trailPopup.rule:SetColorTexture(ar, ag, ab, .18)
    trailPopup.close.label:SetTextColor(ar, ag, ab, trailPopup.close._hovered and 1 or .7)
    trailPopup.close.glow:SetVertexColor(ar, ag, ab, trailPopup.close._hovered and .18 or 0)
    trailPopup.scrollTrack:SetColorTexture(ar, ag, ab, .13)
    trailPopup.scrollThumb:SetColorTexture(ar, ag, ab, .8)
    for _, row in ipairs(trailPopup.rows) do
        local selected = row.style == Settings().vignetteRadarTrailStyle
        row:SetBackdropColor(ar, ag, ab, selected and .13 or row._hovered and .07 or .025)
        row:SetBackdropBorderColor(ar, ag, ab, selected and .48 or row._hovered and .25 or .10)
        row.rail:SetColorTexture(ar, ag, ab, selected and .9 or 0)
        row.label:SetTextColor(selected and ar or .82, selected and ag or .87,
            selected and ab or .88, 1)
        row.track:SetColorTexture(ar, ag, ab, .12)
        for _, mark in ipairs(row.marks) do
            if row.definition.dot or row.definition.square then mark:SetVertexColor(ar, ag, ab, .9)
            else mark:SetColorTexture(ar, ag, ab, .9) end
        end
        for _, mark in ipairs(row.extraMarks) do mark:SetColorTexture(ar, ag, ab, .9) end
    end
    for _, control in ipairs(trailPopup.controls) do
        control.label:SetTextColor(.72, .82, .81, 1)
        local value = Settings()[control.key]
        if not control.value._editing then control.value:SetText(control.format(value)) end
        control.value:SetTextColor(ar, ag, ab, 1)
        if control.key == "vignetteRadarTrailLifetime" then
            control.value:SetBackdropColor(ar, ag, ab, .055)
            control.value:SetBackdropBorderColor(ar, ag, ab, .3)
        end
        for _, button in ipairs({ control.minus, control.plus }) do
            local nextValue
            if control.key == "vignetteRadarTrailLifetime" then
                nextValue = value + button.direction
                if nextValue < 1 or nextValue > 300 then nextValue = nil end
            else
                for slot, candidate in ipairs(control.values) do
                    if candidate == value then nextValue = control.values[slot + button.direction]; break end
                end
            end
            button:SetEnabled(nextValue ~= nil)
            local opacity = not nextValue and .3 or button._hovered and 1 or .78
            button.glow:SetVertexColor(ar, ag, ab, nextValue and button._hovered and .2 or 0)
            for _, stroke in ipairs(button.strokes) do
                stroke:SetColorTexture(button._hovered and ar or .69,
                    button._hovered and ag or .77, button._hovered and ab or .78, opacity)
            end
        end
    end
    trailPopup:DrawPreviews()
end

local function PositionTrailPopup(anchor)
    if not (trailPopup and anchor) then return end
    trailPopup:ClearAllPoints()
    local screenWidth = UIParent and UIParent:GetWidth()
    if not panel or anchor ~= panel.trailToggle then
        local left, right = anchor:GetLeft(), anchor:GetRight()
        if screenWidth and right and screenWidth - right >= trailPopup:GetWidth() + 16 then
            trailPopup:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 8, 0)
        elseif left and left >= trailPopup:GetWidth() + 16 then
            trailPopup:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -8, 0)
        else
            trailPopup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
        end
        return
    end
    local panelLeft, panelRight = panel:GetLeft(), panel:GetRight()
    if screenWidth and panelRight and screenWidth - panelRight >= trailPopup:GetWidth() + 16 then
        trailPopup:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", 8, 0)
    elseif panelLeft and panelLeft >= trailPopup:GetWidth() + 16 then
        trailPopup:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", -8, 0)
    else
        local buttonLeft, buttonRight = anchor:GetLeft(), anchor:GetRight()
        local screenHeight, buttonTop = UIParent and UIParent:GetHeight(), anchor:GetTop()
        local above = screenHeight and buttonTop and screenHeight - buttonTop >= trailPopup:GetHeight() + 16
        local alignRight = screenWidth and buttonLeft and buttonLeft + trailPopup:GetWidth() > screenWidth - 8
            and buttonRight ~= nil
        trailPopup:SetPoint(above and (alignRight and "BOTTOMRIGHT" or "BOTTOMLEFT")
                or (alignRight and "TOPRIGHT" or "TOPLEFT"), anchor,
            above and (alignRight and "TOPRIGHT" or "TOPLEFT")
                or (alignRight and "BOTTOMRIGHT" or "BOTTOMLEFT"), 0, above and 8 or -8)
    end
end

local function EnsureTrailPopup()
    if trailPopup then return trailPopup end
    trailPopup = CreateFrame("Frame", "VignetteRadarTrailStylePopup", UIParent, "BackdropTemplate")
    trailPopup:SetSize(244, 360)
    trailPopup:SetFrameStrata("DIALOG")
    trailPopup:SetClampedToScreen(true)
    trailPopup:EnableMouse(true)
    Surface(trailPopup)
    trailPopup.rail = trailPopup:CreateTexture(nil, "OVERLAY")
    trailPopup.rail:SetPoint("TOPLEFT", 1, -1)
    trailPopup.rail:SetPoint("BOTTOMLEFT", 1, 1)
    trailPopup.rail:SetWidth(2)
    trailPopup.title = Text(trailPopup, 10, "TRAIL STYLE & FLOW", true)
    trailPopup.title:SetPoint("TOPLEFT", 11, -9)
    trailPopup.rule = trailPopup:CreateTexture(nil, "ARTWORK")
    trailPopup.rule:SetPoint("TOPLEFT", 9, -28)
    trailPopup.rule:SetPoint("TOPRIGHT", -9, -28)
    trailPopup.rule:SetHeight(1)
    trailPopup.close = CreateFrame("Button", nil, trailPopup)
    trailPopup.close:SetSize(18, 18)
    trailPopup.close:SetPoint("TOPRIGHT", -6, -5)
    trailPopup.close.label = Text(trailPopup.close, 15, "×")
    trailPopup.close.label:SetAllPoints()
    trailPopup.close.label:SetJustifyH("CENTER")
    trailPopup.close.glow = trailPopup.close:CreateTexture(nil, "BACKGROUND")
    trailPopup.close.glow:SetSize(18, 18)
    trailPopup.close.glow:SetPoint("CENTER")
    trailPopup.close.glow:SetTexture(CIRCLE_TEXTURE)
    trailPopup.close:SetScript("OnClick", HideTrailPopup)
    trailPopup.close:SetScript("OnEnter", function(self)
        self._hovered = true
        RefreshTrailPopup()
    end)
    trailPopup.close:SetScript("OnLeave", function(self)
        self._hovered = false
        RefreshTrailPopup()
    end)
    trailPopup.scroll = CreateFrame("ScrollFrame", nil, trailPopup)
    trailPopup.scroll:SetSize(208, 135)
    trailPopup.scroll:SetPoint("TOPLEFT", trailPopup, "TOPLEFT", 8, -34)
    trailPopup.scroll:EnableMouseWheel(true)
    trailPopup.content = CreateFrame("Frame", nil, trailPopup.scroll)
    trailPopup.content:SetSize(208, #TRAIL_STYLES * 27)
    trailPopup.scroll:SetScrollChild(trailPopup.content)
    trailPopup.scrollIndex = 0
    trailPopup.scrollTrack = trailPopup:CreateTexture(nil, "ARTWORK")
    trailPopup.scrollTrack:SetSize(3, 99)
    trailPopup.scrollTrack:SetPoint("TOPLEFT", trailPopup, "TOPLEFT", 228, -52)
    trailPopup.scrollThumb = trailPopup:CreateTexture(nil, "OVERLAY")
    trailPopup.scrollThumb:SetSize(3, math.max(24, math.floor(99 * 5 / #TRAIL_STYLES + .5)))
    trailPopup.rows = {}
    for index, definition in ipairs(TRAIL_STYLES) do
        local row = CreateFrame("Button", nil, trailPopup.content, "BackdropTemplate")
        row:SetSize(202, 24)
        row:SetPoint("TOPLEFT", trailPopup.content, "TOPLEFT", 0, -(index - 1) * 27)
        Surface(row)
        row.style, row.definition = definition.id, definition
        row.rail = row:CreateTexture(nil, "ARTWORK")
        row.rail:SetPoint("TOPLEFT", 1, -1)
        row.rail:SetPoint("BOTTOMLEFT", 1, 1)
        row.rail:SetWidth(2)
        row.label = Text(row, 10, definition.label)
        row.label:SetPoint("LEFT", 11, 0)
        row.label:SetWidth(96)
        row.track = row:CreateTexture(nil, "ARTWORK")
        row.track:SetSize(79, 1)
        row.track:SetPoint("RIGHT", -9, 0)
        row.marks, row.extraMarks, row.extraByMark = {}, {}, {}
        -- The shortest style at 25% spacing needs 25 marks in this lane.
        for markIndex = 1, 13 do
            local mark
            if definition.dot or definition.square then
                mark = row:CreateTexture(nil, "OVERLAY")
                mark:SetSize(4, 4)
                mark:SetTexture(definition.square and SQUARE_TEXTURE or CIRCLE_TEXTURE)
            else
                mark = row:CreateLine(nil, "OVERLAY")
                row.extraByMark[markIndex] = {}
                for part = 2, #definition.segments do
                    local extra = row:CreateLine(nil, "OVERLAY")
                    row.extraMarks[#row.extraMarks + 1] = extra
                    row.extraByMark[markIndex][part - 1] = extra
                end
            end
            row.marks[markIndex] = mark
        end
        row:SetScript("OnClick", function(self)
            HideTrailPopup()
            addon.SetVignetteRadarTrailStyle(self.style, true)
        end)
        row:SetScript("OnEnter", function(self)
            self._hovered = true
            RefreshTrailPopup()
        end)
        row:SetScript("OnLeave", function(self)
            self._hovered = false
            RefreshTrailPopup()
        end)
        trailPopup.rows[index] = row
    end
    local function ScrollStyles(direction)
        local maxIndex = #TRAIL_STYLES - 5
        trailPopup.scrollIndex = math.max(0, math.min(maxIndex, trailPopup.scrollIndex + direction))
        trailPopup.scroll:SetVerticalScroll(trailPopup.scrollIndex * 27)
        trailPopup.scrollThumb:ClearAllPoints()
        local travel = trailPopup.scrollTrack:GetHeight() - trailPopup.scrollThumb:GetHeight()
        trailPopup.scrollThumb:SetPoint("TOPLEFT", trailPopup.scrollTrack, "TOPLEFT", 0,
            maxIndex > 0 and -travel * trailPopup.scrollIndex / maxIndex or 0)
        trailPopup:DrawPreviews()
    end
    trailPopup.ScrollStyles = ScrollStyles
    trailPopup.scroll:SetScript("OnMouseWheel", function(_, delta)
        ScrollStyles(delta > 0 and -1 or 1)
    end)
    trailPopup.scrollGrip = CreateFrame("Button", nil, trailPopup)
    trailPopup.scrollGrip:SetSize(16, 99)
    trailPopup.scrollGrip:SetPoint("TOPLEFT", trailPopup, "TOPLEFT", 221, -52)
    trailPopup.scrollGrip:RegisterForDrag("LeftButton")
    local function ScrollAtCursor()
        if type(GetCursorPosition) ~= "function" then return end
        local _, cursorY = GetCursorPosition()
        local top = trailPopup.scrollTrack:GetTop()
        if not (cursorY and top) then return end
        local scale = UIParent:GetEffectiveScale()
        local travel = trailPopup.scrollTrack:GetHeight() - trailPopup.scrollThumb:GetHeight()
        local ratio = (top - cursorY / scale - trailPopup.scrollThumb:GetHeight() / 2) / travel
        local index = math.floor(math.max(0, math.min(1, ratio)) * (#TRAIL_STYLES - 5) + .5)
        ScrollStyles(index - trailPopup.scrollIndex)
    end
    trailPopup.scrollGrip:SetScript("OnMouseDown", ScrollAtCursor)
    trailPopup.scrollGrip:SetScript("OnDragStart", function(self)
        self._dragging = true
        ScrollAtCursor()
    end)
    trailPopup.scrollGrip:SetScript("OnDragStop", function(self) self._dragging = false end)
    trailPopup.scrollGrip:SetScript("OnUpdate", function(self)
        if self._dragging then ScrollAtCursor() end
    end)
    trailPopup.rule2 = trailPopup:CreateTexture(nil, "ARTWORK")
    trailPopup.rule2:SetPoint("TOPLEFT", trailPopup, "TOPLEFT", 9, -177)
    trailPopup.rule2:SetPoint("TOPRIGHT", trailPopup, "TOPRIGHT", -9, -177)
    trailPopup.rule2:SetHeight(1)
    trailPopup.rule2:SetColorTexture(.5, .7, .7, .16)
    trailPopup.controls = {}
    local controlDefinitions = {
        { key="vignetteRadarTrailSpacing", label="Spacing", values=TRAIL_SPACINGS,
            format=function(value) return math.floor(value * 100 + .5) .. "%" end },
        { key="vignetteRadarTrailSpeed", label="Flow", values=TRAIL_SPEEDS,
            format=function(value) return value == 0 and "Still" or value .. "×" end },
        { key="vignetteRadarTrailSize", label="Size", values=TRAIL_SIZES,
            format=function(value) return math.floor(value * 100 + .5) .. "%" end },
        { key="vignetteRadarTrailLifetime", label="Fade (seconds)",
            format=function(value) return tostring(value) end },
        { key="vignetteRadarTrailTailFade", label="Tail fade", values=TRAIL_TAIL_FADES,
            format=function(value) return math.floor(value * 100 + .5) .. "%" end },
    }
    for index, definition in ipairs(controlDefinitions) do
        local y = -186 - (index - 1) * 32
        local control = { key=definition.key, values=definition.values, format=definition.format }
        control.label = Text(trailPopup, 10, definition.label)
        control.label:SetPoint("TOPLEFT", trailPopup, "TOPLEFT", 12, y - 3)
        if control.key == "vignetteRadarTrailLifetime" then
            control.value = CreateFrame("EditBox", nil, trailPopup, "BackdropTemplate")
            Surface(control.value)
            local font = EllesmereUI and (EllesmereUI.EXPRESSWAY or EllesmereUI._font)
                or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
            control.value:SetFont(font, 10, "")
            control.value:SetAutoFocus(false)
            control.value:SetMaxLetters(3)
            control.value:SetTextInsets(2, 2, 0, 0)
            control.value:SetScript("OnEditFocusGained", function(self) self._editing = true end)
            local function CommitFade(self)
                self._editing = false
                local raw = self:GetText() or ""
                local seconds = raw:match("^%s*(%d+)%s*$")
                if seconds then addon.SetVignetteRadarTrailOption(control.key, tonumber(seconds)) end
                RefreshTrailPopup()
            end
            control.value:SetScript("OnEnterPressed", function(self)
                CommitFade(self)
                self:ClearFocus()
            end)
            control.value:SetScript("OnEditFocusLost", CommitFade)
            control.value:SetScript("OnEscapePressed", function(self)
                self:SetText(tostring(Settings()[control.key]))
                self._editing = false
                self:ClearFocus()
            end)
        else
            control.value = Text(trailPopup, 10, "")
        end
        control.value:SetSize(46, 20)
        control.value:SetPoint("TOPLEFT", trailPopup, "TOPLEFT", 156, y)
        control.value:SetJustifyH("CENTER")
        for _, direction in ipairs({ -1, 1 }) do
            local button = CreateFrame("Button", nil, trailPopup)
            button:SetSize(20, 20)
            button:SetPoint("TOPLEFT", trailPopup, "TOPLEFT", direction < 0 and 132 or 208, y)
            button.direction = direction
            button.glow = button:CreateTexture(nil, "BACKGROUND")
            button.glow:SetSize(18, 18)
            button.glow:SetPoint("CENTER")
            button.glow:SetTexture(CIRCLE_TEXTURE)
            button.strokes = {}
            local horizontal = button:CreateLine(nil, "OVERLAY")
            horizontal:SetThickness(2)
            horizontal:SetStartPoint("CENTER", button, -5, 0)
            horizontal:SetEndPoint("CENTER", button, 5, 0)
            button.strokes[1] = horizontal
            if direction > 0 then
                local vertical = button:CreateLine(nil, "OVERLAY")
                vertical:SetThickness(2)
                vertical:SetStartPoint("CENTER", button, 0, -5)
                vertical:SetEndPoint("CENTER", button, 0, 5)
                button.strokes[2] = vertical
            end
            button:SetScript("OnClick", function()
                local current = Settings()[control.key]
                if control.key == "vignetteRadarTrailLifetime" then
                    addon.SetVignetteRadarTrailOption(control.key, current + direction)
                else
                    for slot, value in ipairs(control.values) do
                        if value == current then
                            local nextValue = control.values[slot + direction]
                            if nextValue then addon.SetVignetteRadarTrailOption(control.key, nextValue) end
                            break
                        end
                    end
                end
            end)
            button:SetScript("OnEnter", function(self) self._hovered = true; RefreshTrailPopup() end)
            button:SetScript("OnLeave", function(self) self._hovered = false; RefreshTrailPopup() end)
            if direction < 0 then control.minus = button else control.plus = button end
        end
        trailPopup.controls[index] = control
    end
    trailPopup:SetScript("OnUpdate", function(self, elapsed)
        if not self:IsShown() then return end
        local speed = Settings().vignetteRadarTrailSpeed or 1
        if speed == 0 then self._elapsed = 0; return end
        self._elapsed = (self._elapsed or 0) + elapsed
        if self._elapsed < .05 then return end
        self._phase = ((self._phase or 0) + math.min(self._elapsed, .1) * 42
            * speed)
        self._elapsed = 0
        self:DrawPreviews()
    end)
    function trailPopup:DrawPreviews()
        local r, g, b = ACCENT[1], ACCENT[2], ACCENT[3]
        if addon.VignetteRadarStyle then r, g, b = addon.VignetteRadarStyle.Color("accent") end
        local settings = Settings()
        local spacing = settings.vignetteRadarTrailSpacing or 1
        local sizeScale = settings.vignetteRadarTrailSize or 1
        local tailFade = settings.vignetteRadarTrailTailFade or 0
        local lifetime = settings.vignetteRadarTrailLifetime or 180
        local phase = self._phase or 0
        for rowIndex = self.scrollIndex + 1, self.scrollIndex + 5 do
            local row = self.rows[rowIndex]
            local gap = row.definition.spacing * spacing
            local offset = phase % gap
            local cycle = math.floor(phase / gap)
            for index, mark in ipairs(row.marks) do
                local x = 21 + (index - 1) * gap + offset
                if x <= 77 then
                    -- Treat the left edge as three minutes old so Fade has a
                    -- visible effect without waiting for real trail history.
                    local age = (77 - x) * 180 / 56
                    local alpha = (.12 + .78 * math.max(0, 1 - age / lifetime))
                        * (1 - tailFade * math.max(0, math.min(1, (77 - x) / 56)))
                    DrawTrailGlyph(row.definition, mark, row.extraByMark[index], row, x, 0, 1, 0,
                        r, g, b, alpha, index - cycle, sizeScale)
                else
                    mark:Hide()
                    for _, extra in ipairs(row.extraByMark[index] or {}) do extra:Hide() end
                end
            end
        end
    end
    ScrollStyles(0)
    trailPopup:SetScript("OnHide", function()
        if panel and panel.trailToggle then
            panel.trailToggle._popupOpen = false
            panel.trailToggle:RefreshAppearance()
        end
    end)
    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "VignetteRadarTrailStylePopup"
    end
    trailPopup:Hide()
    return trailPopup
end

ToggleTrailPopup = function(anchor, keepConfig)
    local popup = EnsureTrailPopup()
    if popup:IsShown() then HideTrailPopup(); return false end
    local legend, picker = LegendAPI(), TargetPickerAPI()
    if legend and legend.Hide then legend.Hide() end
    if picker and picker.Hide then picker.Hide() end
    if not keepConfig and addon.VignetteRadarQuickConfig then addon.VignetteRadarQuickConfig.Hide() end
    PositionTrailPopup(anchor)
    local selectedIndex = 1
    for index, definition in ipairs(TRAIL_STYLES) do
        if definition.id == Settings().vignetteRadarTrailStyle then selectedIndex = index; break end
    end
    if selectedIndex <= popup.scrollIndex then
        popup.ScrollStyles(selectedIndex - 1 - popup.scrollIndex)
    elseif selectedIndex > popup.scrollIndex + 5 then
        popup.ScrollStyles(selectedIndex - 5 - popup.scrollIndex)
    end
    popup._phase, popup._elapsed = 0, 0
    popup:DrawPreviews()
    RefreshTrailPopup()
    popup:Show()
    if panel and panel.trailToggle then
        panel.trailToggle._popupOpen = true
        panel.trailToggle:RefreshAppearance()
    end
    return true
end

function addon.ToggleVignetteRadarTrailPicker(anchor)
    return ToggleTrailPopup(anchor, true)
end

Render = function()
    if not panel or not panel:IsShown() then return end
    ApplyAppearance()
    UpdateCombatToggle()
    UpdateTrailToggle()
    UpdateFullSweep(0)
    BeginBlips()
    local mapID = CurrentMapID()
    if not preview and mapID ~= activeMapID then ScanVignettes(mapID) end
    local targets = SelectableTargets()
    local focusedTarget
    for _, target in ipairs(targets) do
        if target.key == FocusedTargetKey() then focusedTarget = target; break end
    end
    local player = not preview and PlayerSnapshot(mapID) or nil
    local exploration = addon.VignetteRadarExploration
    local range = exploration and exploration.Range(player, focusedTarget)
        or tonumber(Settings().vignetteRadarRange) or 450
    displayedRange = range
    UpdateRingLabels(range)
    panel.zoomLabel:SetText(range .. " yd")
    local ranges = Ranges()
    panel.zoomIn:SetEnabled(range ~= ranges[1])
    panel.zoomOut:SetEnabled(range ~= ranges[#ranges])
    local northUp = Settings().vignetteRadarNorthUp == true
    if panel.compass._northUp ~= northUp then
        panel.compass._northUp, panel.compass._selected = northUp, northUp
        panel.compass:RefreshAppearance()
    end
    panel:SetAlpha(VisuallyQuiet() and 0.35 or 1)
    local sidebarTarget = focusedTarget
    if not sidebarTarget and Settings().vignetteRadarLayout == "squat" then
        if preview then
            for _, candidate in ipairs(PREVIEW_TARGETS) do
                if TargetVisible(candidate) then sidebarTarget = candidate; break end
            end
            if sidebarTarget then sidebarTarget.distance = range * sidebarTarget.distanceFactor end
        elseif player then
            local fallback
            for _, candidate in ipairs(targets) do
                if TargetVisible(candidate)
                    and not (player.instanceID and candidate.instanceID and player.instanceID ~= candidate.instanceID) then
                    if candidate.distance and candidate.distance <= range then sidebarTarget = candidate; break end
                    if not fallback then fallback = candidate end
                end
            end
            sidebarTarget = sidebarTarget or fallback
        end
    end
    UpdateFocusReadout(sidebarTarget, player, focusedTarget ~= nil)
    UpdatePanelChrome()

    if preview then
        RenderExploration(nil, range)
        HideQuestDots()
        HideMapNotes()
        HideQuestAreas()
        panel.summary:SetText(FocusedTargetKey() and "PREVIEW FOCUS" or "PREVIEW")
        RenderCardinals(ViewFacing(0.65))
        local tip, outer = HeadingGeometry(panel.plotRadius)
        DrawPlayerHeading(panel.direction, panel.field, 0.65, tip, outer)
        DrawPlayerChevron(panel.headingChevron, panel.field, 0.65)
        panel.direction:Show()
        for _, line in ipairs(panel.headingChevron) do line:Show() end
        for _, target in ipairs(PREVIEW_TARGETS) do
            target.distance = range * target.distanceFactor
            local scale = panel.plotRadius / PLOT_RADIUS
            local x, y = PreviewPosition(target.x, target.y)
            if TargetVisible(target) then PlaceBlip(target.key, x * scale, y * scale, target) end
        end
        EndBlips()
        return
    end

    if not player then
        RenderExploration(nil, range)
        HideQuestDots()
        HideMapNotes()
        HideQuestAreas()
        panel.summary:SetText("POSITION UNAVAILABLE")
        if panel.layout == "squat" then
            panel.sideCaption:SetText("POSITION UNAVAILABLE")
            panel.layoutHint:SetText("Waiting for your map position.")
            panel.sideGuide:SetText("CHECK YOUR CURRENT MAP")
        end
        RenderCardinals(0)
        panel.direction:Hide()
        for _, line in ipairs(panel.headingChevron) do line:Hide() end
        EndBlips()
        return
    end
    RenderCardinals(ViewFacing(player.facing))
    local tip, outer = HeadingGeometry(panel.plotRadius)
    DrawPlayerHeading(panel.direction, panel.field, player.facing, tip, outer)
    DrawPlayerChevron(panel.headingChevron, panel.field, player.facing)
    panel.direction:SetShown(player.headingAvailable)
    for _, line in ipairs(panel.headingChevron) do line:SetShown(player.headingAvailable) end
    local questAreasShown = RenderQuestAreas(player, mapID, range)
    local questsInRange = RenderQuestDots(player, range)
    local notesInRange = RenderMapNotes(player, range)
    RenderExploration(player, range)
    local shown, staleShown, totalInRange = 0, 0, 0
    local groups = {}
    for _, target in ipairs(targets) do
        if TargetVisible(target)
            and not (player.instanceID and target.instanceID and player.instanceID ~= target.instanceID) then
            local dx, dy = target.worldX - player.worldX, target.worldY - player.worldY
            local distance = math.sqrt((dx * dx) + (dy * dy))
            if distance <= range then
                totalInRange = totalInRange + 1
                local screenX, screenY = Project(dx, dy, distance, ViewFacing(player.facing), panel.plotRadius, range)
                if screenX and screenY then
                    target.distance = distance
                    local group
                    if Settings().vignetteRadarUntangle ~= false then
                        for _, candidate in ipairs(groups) do
                            if (candidate.x-screenX)^2 + (candidate.y-screenY)^2 <= 16^2 then
                                group = candidate; break
                            end
                        end
                    end
                    if not group then
                        group = { x=screenX, y=screenY, items={} }
                        groups[#groups+1] = group
                    end
                    group.items[#group.items+1] = { target=target, x=screenX, y=screenY }
                end
            end
        end
    end
    local drawn = 0
    for _, group in ipairs(groups) do
        local items, size = group.items, #group.items
        if drawn < MAX_BLIPS then
            local expanded = size > 1 and clusterHoverKey == items[1].target.key
                and Now() < (clusterHoverUntil or 0)
            local count = expanded and math.min(size, MAX_BLIPS-drawn) or 1
            for index=1,count do
                local entry = items[index]
                local x, y = entry.x, entry.y
                if expanded then
                    local angle = (index-1) * TWO_PI / size
                    local radius = math.min(25, 14 + size*1.5)
                    x, y = group.x + math.sin(angle)*radius, group.y + math.cos(angle)*radius
                    local magnitude = math.sqrt(x*x+y*y)
                    if magnitude > panel.plotRadius-7 then
                        local factor = (panel.plotRadius-7)/magnitude
                        x, y = x*factor, y*factor
                    end
                end
                PlaceBlip(entry.target.key, x, y, entry.target)
                local blip = panel.blipByKey[entry.target.key]
                if blip and size > 1 then
                    blip.clusterKey = items[1].target.key
                    if not expanded then
                        blip.cluster = {}
                        for _, member in ipairs(items) do blip.cluster[#blip.cluster+1] = member.target end
                        blip.count:SetText(size > 9 and "9+" or tostring(size))
                        blip.count:Show()
                    end
                end
                drawn = drawn + 1
            end
            shown = shown + size
            for _, entry in ipairs(items) do if entry.target.stale then staleShown = staleShown + 1 end end
        end
    end
    if FocusedTargetKey() then
        panel.summary:SetText(focusedTarget and focusedTarget.stale and "LAST SEEN"
            or (shown > 0 and "TARGET FOCUS" or "OUT OF RANGE"))
    else
        panel.summary:SetText(totalInRange > shown and (shown .. " OF " .. totalInRange .. " SHOWN")
            or staleShown > 0 and ((shown - staleShown) .. " LIVE / " .. staleShown .. " SEEN")
            or (shown == 0 and questsInRange > 0 and (questsInRange == 1 and "1 QUEST IN RANGE"
                or questsInRange .. " QUESTS IN RANGE"))
            or (shown == 0 and questAreasShown and "QUEST AREAS")
            or (shown == 0 and notesInRange > 0 and (notesInRange == 1 and "1 MAP NOTE"
                or notesInRange .. " MAP NOTES"))
            or (shown == 1 and "1 IN RANGE" or shown .. " IN RANGE"))
    end
    EndBlips()
end

local function SavePosition()
    if not panel then return end
    local left, top = panel:GetLeft(), panel:GetTop()
    if SafeNumber(left) and SafeNumber(top) and UIParent and UIParent.GetHeight then
        local key = Settings().vignetteRadarCircleOnly and "vignetteRadarCirclePosition"
            or "vignetteRadarPosition"
        if Settings().vignetteRadarCircleOnly then
            PlacePanel(left, top, panel:GetScale())
            left, top = panel:GetLeft(), panel:GetTop()
        end
        Settings()[key] = { x = left, y = top - UIParent:GetHeight() }
    end
    local quick = addon.VignetteRadarQuickConfig
    if quick and quick.Reanchor then quick.Reanchor(panel) end
end

local function AddResizeGrips()
    local grips = {}
    panel.resizeGrips = grips
    local definitions = {
        { "top", "TOP", 0, 1, panel:GetWidth() - 20, 5 },
        { "bottom", "BOTTOM", 0, -1, panel:GetWidth() - 20, 5 },
        { "left", "LEFT", -1, 0, 5, panel:GetHeight() - 20 },
        { "right", "RIGHT", 1, 0, 5, panel:GetHeight() - 20 },
        { "topLeft", "TOPLEFT", -1, 1, 10, 10 },
        { "topRight", "TOPRIGHT", 1, 1, 5, 5 },
        { "bottomLeft", "BOTTOMLEFT", -1, -1, 10, 10 },
        { "bottomRight", "BOTTOMRIGHT", 1, -1, 10, 10 },
    }
    for _, definition in ipairs(definitions) do
        local key, point, horizontal, vertical, width, height = Unpack(definition)
        local grip = CreateFrame("Frame", nil, panel)
        grip:SetPoint(point, panel, point, 0, 0)
        grip:SetSize(width, height)
        grip:SetFrameLevel(panel:GetFrameLevel() + 3)
        grip:EnableMouse(true)
        grip:RegisterForDrag("LeftButton")
        local highlight = grip:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.18)
        highlight:SetAlpha(0)
        grip.highlight = highlight
        grip:SetScript("OnEnter", function(self)
            self.highlight:SetAlpha(1)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Drag to resize radar", 1, 1, 1)
                GameTooltip:AddLine("The panel grows or shrinks together, keeping its layout and controls aligned.",
                    0.7, 0.8, 0.8, true)
                GameTooltip:Show()
            end
        end)
        grip:SetScript("OnLeave", function(self)
            self.highlight:SetAlpha(0)
            if GameTooltip then GameTooltip:Hide() end
        end)
        grip:SetScript("OnDragStart", function(self)
            if type(GetCursorPosition) ~= "function" then return end
            local x, y = GetCursorPosition()
            local factor = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
            if not (SafeNumber(x) and SafeNumber(y) and SafeNumber(factor) and factor > 0) then return end
            local left, top = SafeNumber(panel:GetLeft()), SafeNumber(panel:GetTop())
            if not (left and top) then return end
            self.resize = { x = x / factor, y = y / factor, left = left, top = top,
                scale = panel:GetScale(), width = panel:GetWidth(), height = panel:GetHeight(), factor = factor }
            local legend, picker = LegendAPI(), TargetPickerAPI()
            if legend and legend.Hide then legend.Hide() end
            if picker and picker.Hide then picker.Hide() end
            self:SetScript("OnUpdate", function(active)
                local cursorX, cursorY = GetCursorPosition()
                local start = active.resize
                if not (start and SafeNumber(cursorX) and SafeNumber(cursorY)) then return end
                local change, axes = 0, 0
                if horizontal ~= 0 then
                    change, axes = horizontal * ((cursorX / start.factor) - start.x) / start.width, axes + 1
                end
                if vertical ~= 0 then
                    change, axes = change + vertical * ((cursorY / start.factor) - start.y) / start.height, axes + 1
                end
                local scale = PanelScale(start.scale + change / axes)
                local oldWidth, oldHeight = start.width * start.scale, start.height * start.scale
                local newWidth, newHeight = start.width * scale, start.height * scale
                local newLeft = horizontal < 0 and start.left + oldWidth - newWidth
                    or (horizontal > 0 and start.left or start.left + (oldWidth - newWidth) / 2)
                local newTop = vertical > 0 and start.top - oldHeight + newHeight
                    or (vertical < 0 and start.top or start.top + (newHeight - oldHeight) / 2)
                PlacePanel(newLeft, newTop, scale)
            end)
        end)
        grip:SetScript("OnDragStop", function(self)
            self:SetScript("OnUpdate", nil)
            if not self.resize then return end
            self.resize = nil
            Settings().vignetteRadarScale = panel:GetScale()
            SavePosition()
        end)
        grip:SetScript("OnHide", function(self)
            self:SetScript("OnUpdate", nil)
            self.resize = nil
        end)
        if key == "bottomRight" then
            for _, stroke in ipairs({ { -3, -4, 4, 3 }, { 1, -4, 4, -1 } }) do
                local line = grip:CreateLine(nil, "ARTWORK")
                line:SetThickness(1)
                line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
                line:SetStartPoint("CENTER", grip, stroke[1], stroke[2])
                line:SetEndPoint("CENTER", grip, stroke[3], stroke[4])
            end
        end
        grips[key] = grip
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
        line:SetStartPoint("CENTER", parent, math.cos(first) * radius, math.sin(first) * radius)
        line:SetEndPoint("CENTER", parent, math.cos(last) * radius, math.sin(last) * radius)
        ring[index] = line
    end
    return ring
end

local function UpdateLauncherSweep(frame, elapsed)
    ApplyAppearance()
    frame:SetAlpha(VisuallyQuiet() and 0.35 or 1)
    local active = Settings().vignetteRadarEnabled == true or preview
    frame._animationTime = (frame._animationTime or 0) + elapsed
    local speed = frame._hovered and 1.35 or 0.72
    frame._sweepAngle = ((frame._sweepAngle or 0) + elapsed * speed) % TWO_PI
    for index, line in ipairs(frame.sweepLines) do
        local angle = frame._sweepAngle - ((index - 1) * 0.13)
        local alpha = active and (0.30 / index) or (0.08 / index)
        line:SetColorTexture(active and ACCENT[1] or 0.45, active and ACCENT[2] or 0.49,
            active and ACCENT[3] or 0.50, alpha)
        line:SetEndPoint("CENTER", frame, math.sin(angle) * LAUNCHER_RADIUS,
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
        line:SetStartPoint("CENTER", launcher, 0, 0)
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
    panel:SetClampedToScreen(Settings().vignetteRadarCircleOnly ~= true)
    panel:SetMovable(true)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", OnZoomWheel)
    Surface(panel)
    local position = Settings().vignetteRadarCircleOnly
        and (Settings().vignetteRadarCirclePosition or Settings().vignetteRadarPosition)
        or Settings().vignetteRadarPosition
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
        type(position) == "table" and tonumber(position.x) or 30,
        type(position) == "table" and tonumber(position.y) or -520)

    panel.title = Text(panel, 11, "VIGNETTE RADAR", true)
    panel.title:SetPoint("TOPLEFT", 12, -6)
    panel.title:SetWidth(100)
    panel.summary = Text(panel, 8, "0 IN RANGE")
    panel.summary:SetPoint("TOPLEFT", 12, -21)
    panel.summary:SetJustifyH("LEFT")
    panel.summary:SetWidth(100)

    panel.layoutHint = Text(panel, 10, "Nothing detected here yet.")
    panel.layoutHint:SetPoint("TOPLEFT", 214, -76)
    panel.layoutHint:SetSize(148, 40)
    panel.layoutHint:SetTextColor(0.65, 0.69, 0.71, 1)
    panel.layoutHint:Hide()
    panel.sideCaption = Text(panel, 8, "NEAREST DETECTION", true)
    panel.sideCaption:SetSize(148, 12)
    panel.sideCaption:Hide()
    panel.sideGuide = Text(panel, 8, "CLICK TO FOCUS")
    panel.sideGuide:SetSize(148, 14)
    panel.sideGuide:SetTextColor(0.55, 0.70, 0.67, 1)
    panel.sideGuide:Hide()

    panel.drag = CreateFrame("Frame", nil, panel)
    panel.drag:SetPoint("TOPLEFT", 4, -3)
    panel.drag:SetSize(106, HEADER_H - 6)
    panel.drag:EnableMouse(true)
    panel.drag:RegisterForDrag("LeftButton")
    panel.drag:SetScript("OnDragStart", function() panel:StartMoving() end)
    panel.drag:SetScript("OnDragStop", function() panel:StopMovingOrSizing(); SavePosition() end)

    panel.settingsDot = CreateFrame("Button", nil, panel)
    panel.settingsDot:SetSize(20, 20)
    panel.settingsDot:SetPoint("TOPRIGHT", -85, -6)
    panel.settingsDot:SetFrameLevel(panel:GetFrameLevel() + 2)
    panel.settingsDot.rim = panel.settingsDot:CreateTexture(nil, "ARTWORK")
    panel.settingsDot.rim:SetSize(18, 18)
    panel.settingsDot.rim:SetPoint("CENTER")
    panel.settingsDot.rim:SetTexture(CIRCLE_TEXTURE)
    panel.settingsDot.rim:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.20)
    panel.settingsDot.inner = panel.settingsDot:CreateTexture(nil, "ARTWORK")
    panel.settingsDot.inner:SetSize(13, 13)
    panel.settingsDot.inner:SetPoint("CENTER")
    panel.settingsDot.inner:SetTexture(CIRCLE_TEXTURE)
    panel.settingsDot.inner:SetVertexColor(0.018, 0.04, 0.042, 1)
    panel.settingsDot.dot = panel.settingsDot:CreateTexture(nil, "OVERLAY")
    panel.settingsDot.dot:SetSize(6, 6)
    panel.settingsDot.dot:SetPoint("CENTER")
    panel.settingsDot.dot:SetTexture(CIRCLE_TEXTURE)
    panel.settingsDot.dot:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    panel.settingsDot:SetScript("OnClick", function()
        HideTrailPopup()
        local quick = addon.VignetteRadarQuickConfig
        if not (quick and quick.Toggle) then return end
        local legend, picker = LegendAPI(), TargetPickerAPI()
        if legend and legend.Hide then legend.Hide() end
        if picker and picker.Hide then picker.Hide() end
        quick.Toggle(panel)
    end)
    panel.settingsDot:SetScript("OnEnter", function(self)
        self.rim:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.55)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Quick settings", 1, 1, 1)
        GameTooltip:AddLine("Open compact controls for every radar setting.", 0.65, 0.80, 0.77, true)
        GameTooltip:Show()
    end)
    panel.settingsDot:SetScript("OnLeave", function(self)
        local quick = addon.VignetteRadarQuickConfig
        self.rim:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3],
            quick and quick.IsShown and quick.IsShown() and .68 or .20)
        if GameTooltip then GameTooltip:Hide() end
    end)

    panel.target = CreateFrame("Button", nil, panel)
    panel.target:SetSize(24, 24)
    panel.target:SetPoint("TOPRIGHT", -57, -5)
    panel.target:SetAlpha(0.68)
    panel.target:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
        HideTrailPopup()
        if addon.VignetteRadarQuickConfig then addon.VignetteRadarQuickConfig.Hide() end
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
        self._hovered = true
        UpdateTargetButton()
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Focus a specific vignette", 1, 1, 1)
        GameTooltip:AddLine("Choose one current detection to isolate on the full radar and the 150-yard launcher view.",
            0.65, 0.80, 0.77, true)
        GameTooltip:AddLine("Right-click to show all again.", 0.55, 0.86, 0.76, true)
        GameTooltip:Show()
    end)
    panel.target:SetScript("OnLeave", function(self)
        self._hovered = false
        UpdateTargetButton()
        if GameTooltip then GameTooltip:Hide() end
    end)

    panel.legend = CreateFrame("Button", nil, panel)
    panel.legend:SetSize(24, 24)
    panel.legend:SetPoint("TOPRIGHT", -31, -5)
    panel.legend:SetAlpha(0.68)
    panel.legend.glow = panel.legend:CreateTexture(nil, "BACKGROUND")
    panel.legend.glow:SetSize(18, 18)
    panel.legend.glow:SetPoint("CENTER")
    panel.legend.glow:SetTexture(CIRCLE_TEXTURE)
    panel.legend.glow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0)
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
        HideTrailPopup()
        if addon.VignetteRadarQuickConfig then addon.VignetteRadarQuickConfig.Hide() end
        local legend = LegendAPI()
        if not (legend and type(legend.Toggle) == "function") then return end
        local picker = TargetPickerAPI()
        if picker and type(picker.Hide) == "function" then pcall(picker.Hide) end
        local ok, shown = pcall(legend.Toggle, panel)
        if ok then
            self._open = shown
            self:SetAlpha(shown and 1 or 0.68)
            self.glow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3],
                self._hovered and .18 or shown and .12 or 0)
        end
    end)
    panel.legend:SetScript("OnEnter", function(self)
        self._hovered = true
        self.glow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], .18)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Radar legend", 1, 1, 1)
        GameTooltip:AddLine("See live detections, saved map notes, quests, pins, routes, and trail symbols. Filter or spotlight live types here.",
            0.65, 0.80, 0.77, true)
        GameTooltip:Show()
    end)
    panel.legend:SetScript("OnLeave", function(self)
        self._hovered = false
        self.glow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], self._open and .12 or 0)
        if GameTooltip then GameTooltip:Hide() end
    end)

    panel.close = CreateFrame("Button", nil, panel)
    panel.close:SetSize(24, 24)
    panel.close:SetPoint("TOPRIGHT", -5, -5)
    panel.close.label = Text(panel.close, 16, "×")
    panel.close.label:SetAllPoints()
    panel.close.label:SetJustifyH("CENTER")
    panel.close.glow = panel.close:CreateTexture(nil, "BACKGROUND")
    panel.close.glow:SetSize(18, 18)
    panel.close.glow:SetPoint("CENTER")
    panel.close.glow:SetTexture(CIRCLE_TEXTURE)
    panel.close.glow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0)
    panel.close:SetScript("OnClick", function()
        if addon.VignetteRadarQuickConfig then addon.VignetteRadarQuickConfig.Hide() end
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
        self._hovered = true
        self.glow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], .18)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Tuck away radar", 1, 1, 1)
        GameTooltip:AddLine("The launcher stays ready so you can bring the radar back without disabling detection.",
            0.72, 0.76, 0.78, true)
        GameTooltip:Show()
    end)
    panel.close:SetScript("OnLeave", function(self)
        self._hovered = false
        self.glow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0)
        if GameTooltip then GameTooltip:Hide() end
    end)

    panel.field = CreateFrame("Frame", nil, panel)
    panel.field:SetSize(FIELD_SIZE, FIELD_SIZE)
    panel.field:SetPoint("BOTTOM", 0, 9 + ZOOM_FOOTER_H)
    panel.field:EnableMouseWheel(true)
    panel.field:SetScript("OnMouseWheel", OnZoomWheel)
    panel.field:EnableMouse(true)
    panel.field:RegisterForDrag("LeftButton")
    panel.field:SetScript("OnDragStart", function()
        if Settings().vignetteRadarCircleOnly == true then
            panel.field._dragged = true
            panel:StartMoving()
        end
    end)
    panel.field:SetScript("OnDragStop", function() panel:StopMovingOrSizing(); SavePosition() end)
    panel.field:SetScript("OnMouseUp", function(self, button)
        local dragged = self._dragged
        self._dragged = nil
        if button == "LeftButton" and not dragged and panel.questBlob and panel.questBlob.tooltipQuestID then
            local exploration = addon.VignetteRadarExploration
            if exploration then exploration.FocusQuest(panel.questBlob.tooltipQuestID) end
        end
    end)
    panel.field:SetFrameLevel(panel:GetFrameLevel() + 1)
    panel.frameToggle = CreateFrame("Button", nil, panel)
    panel.frameToggle:SetSize(16, 20)
    panel.frameToggle:SetFrameLevel(panel.field:GetFrameLevel() + 6)
    if type(panel.frameToggle.SetIgnoreParentAlpha) == "function" then
        panel.frameToggle:SetIgnoreParentAlpha(true)
    end
    panel.frameToggle.glow = panel.frameToggle:CreateTexture(nil, "BACKGROUND")
    panel.frameToggle.glow:SetSize(16, 16)
    panel.frameToggle.glow:SetPoint("CENTER")
    panel.frameToggle.glow:SetTexture(CIRCLE_TEXTURE)
    panel.frameToggle.chevron = {}
    for index = 1, 2 do
        local line = panel.frameToggle:CreateLine(nil, "OVERLAY")
        line:SetThickness(1.8)
        panel.frameToggle.chevron[index] = line
    end
    panel.frameToggle:Show()
    panel.frameToggle:SetScript("OnClick", function()
        addon.SetVignetteRadarCircleOnly(Settings().vignetteRadarCircleOnly ~= true)
    end)
    panel.frameToggle:SetScript("OnEnter", function(self)
        self._hovered = true
        UpdatePanelChrome()
        if not GameTooltip then return end
        local circleOnly = Settings().vignetteRadarCircleOnly == true
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(circleOnly and "Show full radar frame" or "Show only the radar", 1, 1, 1)
        GameTooltip:AddLine("Click to switch views. Your choice is saved.", .7, .8, .8, true)
        GameTooltip:Show()
    end)
    panel.frameToggle:SetScript("OnLeave", function(self)
        self._hovered = false
        UpdatePanelChrome()
        if GameTooltip then GameTooltip:Hide() end
    end)
    panel.field.background = panel.field:CreateTexture(nil, "BACKGROUND")
    panel.field.background:SetAllPoints()
    panel.field.background:SetTexture(CIRCLE_TEXTURE)
    panel.field.background:SetVertexColor(0.015, 0.022, 0.028, 0.94)
    panel.questDots = {}
    panel.mapNotes = {}
    panel.questClip = CreateFrame("Frame", nil, panel.field)
    panel.questClip:SetAllPoints(panel.field)
    panel.questClip:SetFrameLevel(panel.field:GetFrameLevel() + 1)
    panel.questClip:EnableMouse(false)
    if type(panel.questClip.SetClipsChildren) == "function" then
        panel.questClip:SetClipsChildren(true)
        local ok, blob = pcall(CreateFrame, "QuestPOIFrame", nil, panel.questClip)
        if ok and blob and type(blob.SetMapID) == "function" and type(blob.DrawBlob) == "function"
            and type(blob.DrawNone) == "function" and type(blob.SetFillTexture) == "function"
            and type(blob.SetBorderTexture) == "function" and type(blob.SetFillAlpha) == "function"
            and type(blob.SetBorderAlpha) == "function" then
            panel.questBlob = blob
            blob:SetFrameLevel(panel.field:GetFrameLevel() + 2)
            blob:EnableMouse(false)
            blob:SetFillTexture("Interface\\WorldMap\\UI-QuestBlob-Inside")
            blob:SetBorderTexture("Interface\\WorldMap\\UI-QuestBlob-Outside")
            blob:SetFillAlpha(48)
            blob:SetBorderAlpha(0)
            blob:Hide()
        end
    end
    panel.field.halo = panel.field:CreateTexture(nil, "BACKGROUND", nil, -1)
    panel.field.halo:SetPoint("CENTER")
    panel.field.halo:SetSize(FIELD_SIZE + 4, FIELD_SIZE + 4)
    panel.field.halo:SetTexture(CIRCLE_TEXTURE)
    panel.field.halo:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.18)
    panel.outerRing = AddRing(panel.field, FIELD_RADIUS, 0.02)
    -- One continuous outline avoids tiny native Line segments disappearing at corners.
    panel.squareBorder = panel.field:CreateTexture(nil, "BORDER")
    panel.squareBorder:SetTexture(ROUNDED_BORDER_TEXTURE)
    panel.squareBorder:SetPoint("CENTER", panel.field, "CENTER")
    panel.squareBorder:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], .06)
    panel.squareBorder:Hide()
    panel.rangeRing = AddRing(panel.field, PLOT_RADIUS, 0.045)
    panel.middleRing = AddRing(panel.field, PLOT_RADIUS * (2 / 3), 0.04)
    panel.innerRing = AddRing(panel.field, PLOT_RADIUS / 3, 0.03)
    panel.sweepLines = {}
    for index = 1, 2 do
        local line = panel.field:CreateLine(nil, "BORDER")
        line:SetThickness(index == 1 and 1.5 or 1)
        line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], index == 1 and .17 or .07)
        line:Hide()
        panel.sweepLines[index] = line
    end

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
    panel.direction = panel.field:CreateLine(nil, "OVERLAY")
    panel.direction:SetThickness(2.5)
    local tip, outer = HeadingGeometry(PLOT_RADIUS)
    DrawPlayerHeading(panel.direction, panel.field, 0, tip, outer)
    panel.direction:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.46)
    panel.headingChevron = {}
    for index = 1, 2 do
        local line = panel.field:CreateLine(nil, "OVERLAY")
        line:SetThickness(2.25)
        line:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.72)
        panel.headingChevron[index] = line
    end
    DrawPlayerChevron(panel.headingChevron, panel.field, 0)
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
    local function ToolbarIcon(symbol, width)
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(width, 20)
        -- Keep navigation controls legible when the radar surface is dimmed.
        if type(button.SetIgnoreParentAlpha) == "function" then
            button:SetIgnoreParentAlpha(true)
        end
        button.glow = button:CreateTexture(nil, "BACKGROUND")
        button.glow:SetSize(18, 18)
        button.glow:SetPoint("CENTER")
        button.glow:SetTexture(CIRCLE_TEXTURE)
        button.strokes = {}
        if symbol == "N" then
            button.label = Text(button, 13, "N")
            button.label:SetAllPoints()
            button.label:SetJustifyH("CENTER")
            button:SetFontString(button.label)
            button:SetText("N")
        elseif symbol == "trail" then
            button.trailMarks, button.trailExtras = {}, {}
            for index = 1, 3 do
                local stroke = button:CreateLine(nil, "OVERLAY")
                stroke:SetThickness(1.7)
                stroke:SetStartPoint("CENTER", button, (index - 2) * 5 - 2, 0)
                stroke:SetEndPoint("CENTER", button, (index - 2) * 5 + 2, 0)
                button.strokes[#button.strokes + 1] = stroke
                button.trailMarks[index] = stroke
                button.trailExtras[index] = {}
                for part = 1, 3 do
                    local extra = button:CreateLine(nil, "OVERLAY")
                    extra:Hide()
                    button.trailExtras[index][part] = extra
                    button.strokes[#button.strokes + 1] = extra
                end
            end
        else
            local horizontal = button:CreateLine(nil, "OVERLAY")
            horizontal:SetThickness(2)
            horizontal:SetStartPoint("CENTER", button, -5, 0)
            horizontal:SetEndPoint("CENTER", button, 5, 0)
            button.strokes[1] = horizontal
            if symbol == "+" then
                local vertical = button:CreateLine(nil, "OVERLAY")
                vertical:SetThickness(2)
                vertical:SetStartPoint("CENTER", button, 0, -5)
                vertical:SetEndPoint("CENTER", button, 0, 5)
                button.strokes[2] = vertical
            end
        end
        button._enabled = true
        function button:RefreshAppearance()
            local enabled, hovered = self._enabled, self._hovered
            local selected = self._selected == true or self._popupOpen == true
            local r, g, b = .69, .77, .78
            if selected or hovered then r, g, b = ACCENT[1], ACCENT[2], ACCENT[3] end
            local opacity = not enabled and .32 or (hovered or selected) and 1 or .78
            self.glow:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3],
                not enabled and 0 or hovered and .20 or selected and .12 or 0)
            for _, stroke in ipairs(self.strokes) do stroke:SetColorTexture(r, g, b, opacity) end
            if self.label then self.label:SetTextColor(r, g, b, opacity) end
        end
        local nativeSetEnabled = button.SetEnabled
        button.SetEnabled = function(self, enabled)
            enabled = enabled == true or enabled == 1
            if self._enabled == enabled then return end
            nativeSetEnabled(self, enabled)
            self._enabled = enabled
            if not enabled then self._hovered = false end
            self:RefreshAppearance()
        end
        button:SetScript("OnEnter", function(self) self._hovered = true; self:RefreshAppearance() end)
        button:SetScript("OnLeave", function(self) self._hovered = false; self:RefreshAppearance() end)
        button:SetScript("OnHide", function(self) self._hovered = false; self:RefreshAppearance() end)
        button:RefreshAppearance()
        return button
    end
    local function ZoomButton(symbol, right, step, title)
        local button = ToolbarIcon(symbol, 22)
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
    panel.compass = ToolbarIcon("N", 24)
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

    panel.trailToggle = ToolbarIcon("trail", 22)
    panel.trailToggle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    panel.trailToggle:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if GameTooltip then GameTooltip:Hide() end
            ToggleTrailPopup(panel.trailToggle)
        else
            HideTrailPopup()
            addon.SetVignetteRadarTrailEnabled(Settings().vignetteRadarBreadcrumbs ~= true)
        end
    end)
    panel.trailToggle:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        local style = Settings().vignetteRadarTrailStyle or "dashes"
        local name = (TRAIL_STYLE_BY_ID[style] or TRAIL_STYLES[1]).label
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Travel trail: " .. (Settings().vignetteRadarBreadcrumbs and "ON" or "OFF"), 1, 1, 1)
        GameTooltip:AddLine("Style: " .. name .. ". Left-click to toggle; right-click to choose from moving previews.",
            .7, .8, .8, true)
        GameTooltip:Show()
    end)
    panel.trailToggle:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    UpdateTrailToggle()

    panel.combatToggle = CreateFrame("Button", nil, panel)
    panel.combatToggle:SetSize(18, 18)
    if type(panel.combatToggle.SetIgnoreParentAlpha) == "function" then
        panel.combatToggle:SetIgnoreParentAlpha(true)
    end
    panel.combatToggle.glow = panel.combatToggle:CreateTexture(nil, "BACKGROUND")
    panel.combatToggle.glow:SetSize(18, 18)
    panel.combatToggle.glow:SetPoint("CENTER")
    panel.combatToggle.glow:SetTexture(CIRCLE_TEXTURE)
    panel.combatToggle.eye = {}
    for index, points in ipairs({
        { -6, 0, 0, 3 }, { 0, 3, 6, 0 }, { -6, 0, 0, -3 }, { 0, -3, 6, 0 },
    }) do
        local line = panel.combatToggle:CreateLine(nil, "OVERLAY")
        line:SetThickness(1.5)
        line:SetStartPoint("CENTER", panel.combatToggle, points[1], points[2])
        line:SetEndPoint("CENTER", panel.combatToggle, points[3], points[4])
        panel.combatToggle.eye[index] = line
    end
    panel.combatToggle.pupil = panel.combatToggle:CreateTexture(nil, "OVERLAY")
    panel.combatToggle.pupil:SetSize(3, 3)
    panel.combatToggle.pupil:SetPoint("CENTER")
    panel.combatToggle.pupil:SetTexture(CIRCLE_TEXTURE)
    panel.combatToggle:SetScript("OnClick", function()
        addon.SetVignetteRadarKeepVisibleCombat(Settings().vignetteRadarKeepVisibleCombat ~= true)
    end)
    panel.combatToggle:SetScript("OnEnter", function(self)
        self._hovered = true
        UpdateCombatToggle()
        if not GameTooltip then return end
        local enabled = Settings().vignetteRadarKeepVisibleCombat == true
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(enabled and "Stay fully visible: ON" or "Stay fully visible: OFF", 1, 1, 1)
        GameTooltip:AddLine(enabled and "Click to allow automatic fading and hiding again."
            or "Click to prevent automatic fading and hiding.", .7, .8, .8, true)
        GameTooltip:AddLine("Keeps the radar open when zone data is empty or unavailable.", .7, .8, .8, true)
        GameTooltip:AddLine("Alert muting stays separate.", .55, .7, .68, true)
        GameTooltip:Show()
    end)
    panel.combatToggle:SetScript("OnLeave", function(self)
        self._hovered = false
        UpdateCombatToggle()
        if GameTooltip then GameTooltip:Hide() end
    end)
    UpdateCombatToggle()

    AddResizeGrips()

    panel:SetScript("OnUpdate", function(self, elapsed)
        self._renderElapsed = (self._renderElapsed or 0) + elapsed
        self._scanElapsed = (self._scanElapsed or 0) + elapsed
        local settings = Settings()
        if not preview and settings.vignetteRadarEnabled == true
            and settings.vignetteRadarBreadcrumbs == true
            and settings.vignetteRadarTrailLifetime <= 5 and activeMapID
            and addon.VignetteRadarExploration then
            self._shortTrailElapsed = (self._shortTrailElapsed or 0) + elapsed
            if self._shortTrailElapsed >= .25 then
                self._shortTrailElapsed = 0
                addon.VignetteRadarExploration.UpdateTrail(PlayerSnapshot(activeMapID), activeMapID, Now())
            end
        else
            self._shortTrailElapsed = 0
        end
        self._questTooltipElapsed = (self._questTooltipElapsed or 0) + elapsed
        if self._questTooltipElapsed >= .1 then
            self._questTooltipElapsed = 0
            UpdateQuestAreaTooltip()
        end
        if self._scanElapsed >= RESCAN_SECONDS then
            self._scanElapsed = 0
            RefreshRadar(true)
            if not self:IsShown() then return end
        end
        if self._renderElapsed >= UPDATE_SECONDS then
            local renderElapsed = self._renderElapsed
            self._renderElapsed = 0
            UpdateFullSweep(renderElapsed)
            Render()
        end
    end)
    panel:SetScript("OnHide", function()
        HideTrailPopup()
        ReleaseAllBlips()
        HideQuestDots()
        HideMapNotes()
        HideQuestAreas()
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
    local changedMap = activeMapID ~= mapID
    if changedMap then questMapBasis = nil end
    if activeMapID ~= mapID or preview or Settings().vignetteRadarEnabled ~= true then
        pulseUntil, approachPulseKey, approachPulseUntil = 0, nil, nil
    end
    activeMapID = mapID
    activeTargets = CollectVignettes(mapID)
    activeQuests = CollectQuests(mapID)
    local source = Settings().vignetteRadarPOISource
    local now = Now()
    if source == "none" or not mapID then
        activeMapNotes = {}
        mapNotesMapID, mapNotesSource, mapNotesUpdatedAt = nil, nil, nil
    elseif mapNotesMapID ~= mapID or mapNotesSource ~= source
        or not mapNotesUpdatedAt or now - mapNotesUpdatedAt >= 5 then
        local pois = addon.VignetteRadarPOIs
        local selected, dataMapID
        if pois then selected, dataMapID = pois.ResolveSource(mapID, source) end
        activeMapNotes = selected and pois.Collect(dataMapID, selected, MapToWorld, MapVector) or {}
        mapNotesMapID, mapNotesSource, mapNotesUpdatedAt = mapID, source, now
    end
    if #activeMapNotes > 1 then
        local player = PlayerSnapshot(mapID)
        if player then
            table.sort(activeMapNotes, function(left, right)
                local ldx, ldy = left.worldX - player.worldX, left.worldY - player.worldY
                local rdx, rdy = right.worldX - player.worldX, right.worldY - player.worldY
                return ldx * ldx + ldy * ldy < rdx * rdx + rdy * rdy
            end)
        end
    end
    if addon.VignetteRadarExploration then
        addon.VignetteRadarExploration.ValidateQuestFocus(activeQuests, changedMap)
    end
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
    local exploration = addon.VignetteRadarExploration
    if exploration and not preview and Settings().vignetteRadarEnabled == true then
        local player = PlayerSnapshot(mapID)
        exploration.UpdateTrail(player, mapID, Now())
        exploration.RecordSightings(activeTargets, mapID)
        local approach = exploration.CheckApproach(activeTargets, player, mapID)
        if approach and not Quiet() then
            approach.newUntil = Now() + 3
            approachPulseKey, approachPulseUntil = approach.key, approach.newUntil
            pulseUntil = math.max(pulseUntil, approach.newUntil)
            if Settings().vignetteRadarAlertSound == true and PlaySound and SOUNDKIT then
                pcall(PlaySound, SOUNDKIT.TELL_MESSAGE or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
            end
        end
    end
    if approachPulseKey and approachPulseUntil and Now() < approachPulseUntil then
        for _, target in ipairs(activeTargets) do
            if target.key == approachPulseKey then target.newUntil = approachPulseUntil; break end
        end
    end
end

RefreshRadar = function(rescan)
    local settings = Settings()
    if events and events._killListening ~= settings.vignetteRadarHideCleared then
        events._killListening = settings.vignetteRadarHideCleared
        if events._killListening then events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        else events:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end
    end
    local exploration = addon.VignetteRadarExploration
    local mapID = CurrentMapID()
    local trail, trailMap
    if exploration and settings.vignetteRadarBreadcrumbs then trail, trailMap = exploration.GetTrail() end
    local hasExploration = exploration and mapID and
        (#exploration.GetPins(mapID) > 0 or #exploration.GetRoute(mapID) > 0
            or (settings.vignetteRadarBreadcrumbs and settings.vignetteRadarTrailLifetime <= 5)
            or (trailMap == mapID and #trail > 1))
    if addon.VignetteRadarQuickConfig and addon.VignetteRadarQuickConfig.Refresh then
        addon.VignetteRadarQuickConfig.Refresh()
    end
    if settings.vignetteRadarLauncherVisible ~= false then
        EnsureLauncher():Show()
    elseif launcher then
        launcher:Hide()
    end
    if rescan then ScanVignettes(CurrentMapID()) end
    local hasMapNotes = false
    if #activeMapNotes > 0 and settings.vignetteRadarPOISource ~= "none" then
        local player = PlayerSnapshot(mapID)
        local range = exploration and exploration.Range(player, nil) or settings.vignetteRadarRange
        if player and type(range) == "number" then
            for _, note in ipairs(activeMapNotes) do
                if settings.vignetteRadarPOITypes[note.kind] ~= false
                    and not (addon.VignetteRadarRecent and addon.VignetteRadarRecent.IsHidden(note, settings))
                    and not (player.instanceID and note.instanceID and player.instanceID ~= note.instanceID) then
                    local dx, dy = note.worldX - player.worldX, note.worldY - player.worldY
                    local distance2 = dx * dx + dy * dy
                    if distance2 >= 81 and distance2 <= range * range then
                        hasMapNotes = true
                        break
                    end
                end
            end
        end
    end
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
    elseif manualPanelState == true or preview or settings.vignetteRadarKeepVisibleCombat == true
        or settings.vignetteRadarHideWhenEmpty == false
        or hasExploration or #SelectableTargets() > 0 or hasMapNotes or (#activeQuests > 0 and (settings.vignetteRadarQuestDots
            or (settings.vignetteRadarQuestAreas and settings.vignetteRadarNorthUp))) then
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
    GetCurrentMapID = CurrentMapID,
    GetPlayerSnapshot = function() return PlayerSnapshot(CurrentMapID()) end,
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
    Settings().vignetteRadarCirclePosition = nil
    Settings().vignetteRadarLauncherPosition = nil
    if panel then PlacePanel(30, UIParent:GetHeight() - 520, panel:GetScale()) end
    if launcher then launcher:ClearAllPoints(); launcher:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -170) end
    if addon.VignetteRadarQuickConfig then addon.VignetteRadarQuickConfig.Reanchor(panel) end
end

function addon.SetVignetteRadarRange(range)
    for _, supported in ipairs(Ranges()) do
        if range == supported then
            if addon.VignetteRadarExploration then addon.VignetteRadarExploration.ManualZoom() end
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

function addon.SetVignetteRadarScale(scale)
    if not SafeNumber(scale) then return false end
    if not panel then
        Settings().vignetteRadarScale = math.max(.8, math.min(1.8, scale))
        return true
    end
    PlacePanel(panel:GetLeft(), panel:GetTop(), scale)
    Settings().vignetteRadarScale = panel:GetScale()
    SavePosition()
    return true
end

function addon.SetVignetteRadarNorthUp(enabled)
    Settings().vignetteRadarNorthUp = enabled == true
    RefreshRadar(false)
    if addon.RefreshVignetteRadarOptions then addon.RefreshVignetteRadarOptions() end
end

function addon.SetVignetteRadarTrailEnabled(enabled)
    Settings().vignetteRadarBreadcrumbs = enabled == true
    RefreshRadar(false)
    if addon.RefreshVignetteRadarOptions then addon.RefreshVignetteRadarOptions() end
    local quick = addon.VignetteRadarQuickConfig
    if quick and quick.Refresh then quick.Refresh() end
end

function addon.SetVignetteRadarTrailStyle(style, enable)
    if not TRAIL_STYLE_BY_ID[style] then return false end
    Settings().vignetteRadarTrailStyle = style
    if enable then Settings().vignetteRadarBreadcrumbs = true end
    RefreshRadar(false)
    if RefreshTrailPopup then RefreshTrailPopup() end
    if addon.RefreshVignetteRadarOptions then addon.RefreshVignetteRadarOptions() end
    local quick = addon.VignetteRadarQuickConfig
    if quick and quick.Refresh then quick.Refresh() end
    return true
end

function addon.SetVignetteRadarTrailOption(key, value)
    local allowed = key == "vignetteRadarTrailSpacing" and TRAIL_SPACINGS
        or key == "vignetteRadarTrailSpeed" and TRAIL_SPEEDS
        or key == "vignetteRadarTrailSize" and TRAIL_SIZES
        or key == "vignetteRadarTrailTailFade" and TRAIL_TAIL_FADES
        or key == "vignetteRadarTrailLifetime" and TRAIL_LIFETIMES
    if not allowed then return false end
    local valid = key == "vignetteRadarTrailLifetime" and type(value) == "number"
        and value == math.floor(value) and value >= allowed[1] and value <= allowed[2]
    if not valid and key ~= "vignetteRadarTrailLifetime" then
        for _, candidate in ipairs(allowed) do
            if candidate == value then valid = true; break end
        end
    end
    if not valid then return false end
    Settings()[key] = value
    if panel and panel:IsShown() then Render() end
    if RefreshTrailPopup then RefreshTrailPopup() end
    if addon.RefreshVignetteRadarOptions then addon.RefreshVignetteRadarOptions() end
    local quick = addon.VignetteRadarQuickConfig
    if quick and quick.Refresh then quick.Refresh() end
    return true
end

function addon.SetVignetteRadarQuietCombat(fadeInCombat)
    Settings().vignetteRadarQuietCombat = fadeInCombat == true
    RefreshRadar(false)
    if addon.RefreshVignetteRadarOptions then addon.RefreshVignetteRadarOptions() end
    local quick = addon.VignetteRadarQuickConfig
    if quick and quick.Refresh then quick.Refresh() end
end

function addon.SetVignetteRadarKeepVisibleCombat(enabled)
    Settings().vignetteRadarKeepVisibleCombat = enabled == true
    RefreshRadar(false)
    if addon.RefreshVignetteRadarOptions then addon.RefreshVignetteRadarOptions() end
    local quick = addon.VignetteRadarQuickConfig
    if quick and quick.Refresh then quick.Refresh() end
end

function addon.SetVignetteRadarCircleOnly(enabled)
    local settings = Settings()
    enabled = enabled == true
    if panel and settings.vignetteRadarCircleOnly ~= enabled then SavePosition() end
    settings.vignetteRadarCircleOnly = enabled
    if panel then
        panel:SetClampedToScreen(not enabled)
        local position = enabled and settings.vignetteRadarCirclePosition or settings.vignetteRadarPosition
        local x = type(position) == "table" and SafeNumber(tonumber(position.x))
        local y = type(position) == "table" and SafeNumber(tonumber(position.y))
        local left = x or panel:GetLeft()
        local top = y and UIParent:GetHeight() + y or panel:GetTop()
        if left and top then PlacePanel(left, top, panel:GetScale()); SavePosition() end
    end
    if enabled then
        if HideTrailPopup then HideTrailPopup() end
        local legend, picker = LegendAPI(), TargetPickerAPI()
        if legend and legend.Hide then legend.Hide() end
        if picker and picker.Hide then picker.Hide() end
    end
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
    elseif message == "explore" then
        if addon.VignetteRadarExploration then addon.VignetteRadarExploration.TogglePanel() end
        return
    elseif message == "pin" or message:match("^pin%s+") then
        local exploration = addon.VignetteRadarExploration
        if exploration then
            local name = message:match("^pin%s+(.+)$") or "My pin"
            local ok, result = exploration.AddPin(PlayerSnapshot(CurrentMapID()), name)
            exploration.Tell(ok and ("Pinned " .. result.name) or result)
        end
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

local function RelevantKill(identity, guid)
    for _, target in ipairs(activeTargets) do
        if (target.category == "rare" or target.category == "treasure")
            and target.objectGUID == guid then return true end
    end
    for _, note in ipairs(activeMapNotes) do
        if note.kind == "mob" or note.kind == "treasure" then
            if note.npcID and identity == "npc:" .. note.npcID then return true end
            if note.objectID and identity == "object:" .. note.objectID then return true end
        end
    end
    return false
end

events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    "VIGNETTES_UPDATED", "VIGNETTE_MINIMAP_UPDATED",
    "QUEST_LOG_UPDATE", "QUEST_POI_UPDATE", "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local recent = addon.VignetteRadarRecent
        if recent and recent.RecordCombatLog(RelevantKill) then
            RefreshRadar(true)
        end
        return
    end
    if event == "QUEST_LOG_UPDATE" and addon.VignetteRadarRecent then
        addon.VignetteRadarRecent.InvalidateQuests()
    end
    local mapChanged = event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS"
    if mapChanged then questMapBasis = nil end
    if mapChanged or event == "QUEST_LOG_UPDATE" or event == "QUEST_POI_UPDATE"
        or event == "QUEST_WATCH_LIST_CHANGED" or event == "SUPER_TRACKING_CHANGED" then
        if panel and panel.questBlob then
            panel.questBlob.drawnKey = nil
            if mapChanged then panel.questBlob.mapContextID = nil end
        end
    end
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
