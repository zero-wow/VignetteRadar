local _, addon = ...
if type(addon) ~= "table" then return end

-- A screen-space bearing display. WoW exposes one world-anchored navigation
-- frame, so these markers deliberately form a compass instead of pretending
-- that arbitrary map positions are projected into the 3D scene.
local API = {}
addon.VignetteRadarBeacons = API

local PI, TWO_PI = math.pi, math.pi * 2
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local SURFACE = "Interface\\AddOns\\VignetteRadar\\Media\\beacon-surface.tga"
local BORDER = "Interface\\AddOns\\VignetteRadar\\Media\\beacon-border.tga"
local RARE = "Interface\\AddOns\\VignetteRadar\\Media\\beacon-rare.tga"
local QUEST = "Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond.tga"
local QUEST_HOLLOW = "Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond-hollow.tga"
local WIDTH, HEIGHT, BINS, CARD_W, ROWS = 520, 146, 19, 88, 4
local candidates, frame, cards = {}, nil, {}
local bins, used = {}, {}
local lastX = {}
local lastMapID, lastPlayer
local preview = false
local previewSaved
local paused, slowUpdates = false, 0

local function Pause(reason)
    if paused then return end
    paused = true
    if frame then frame:SetScript("OnUpdate", nil); frame:Hide() end
    local message = "Vignette Radar: Bearing Bar paused for this session (" .. reason
        .. "). /reload retries them."
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    elseif print then print(message) end
end

local function Number(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return nil end
    end
    return type(value) == "number" and value == value and value ~= math.huge
        and value ~= -math.huge and value or nil
end

local function StyleColor(slot)
    local style = addon.VignetteRadarStyle
    if style and type(style.Color) == "function" then
        local ok, r, g, b = pcall(style.Color, slot)
        if ok and Number(r) and Number(g) and Number(b) then return r, g, b end
    end
    return .65, .85, .95
end

local function QuestColor(quest)
    local palette = addon.VignetteRadarQuestColors
    if addon.GetSettings().vignetteRadarQuestColors and palette then
        local color = palette[quest.colorSlot or 1]
        if color then return color[1], color[2], color[3] end
    end
    return StyleColor("quest")
end

local function NavigateToPoint(item)
    local raw = item and item.raw
    local x, y = Number(raw and raw.mapX), Number(raw and raw.mapY)
    if not (x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1
        and UiMapPoint and type(UiMapPoint.CreateFromCoordinates) == "function"
        and C_Map and type(C_Map.SetUserWaypoint) == "function") then return end
    if type(C_Map.CanSetUserWaypointOnMap) == "function" then
        local ok, allowed = pcall(function()
            return C_Map.CanSetUserWaypointOnMap(item.mapID) ~= false
        end)
        if not ok or not allowed then return end
    end
    local ok, point = pcall(UiMapPoint.CreateFromCoordinates, item.mapID, x, y)
    if not ok or not point then return end
    local placed, result = pcall(C_Map.SetUserWaypoint, point)
    local valid, applied = pcall(function() return result ~= false end)
    if placed and valid and applied and C_SuperTrack
        and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
end

local function RefreshTheme()
    if not frame then return end
    local ar, ag, ab = StyleColor("accent")
    local br, bg, bb = StyleColor("background")
    frame.background:SetVertexColor(br, bg, bb, .96)
    frame.border:SetVertexColor(ar, ag, ab, .72)
    frame.heading:SetTextColor(ar, ag, ab, 1)
    frame.center:SetColorTexture(ar, ag, ab, .65)
    frame.axis:SetColorTexture(ar, ag, ab, .16)
end

local function SavePosition()
    if not frame or not UIParent then return end
    local scale = frame:GetScale()
    local left, top = frame:GetLeft(), frame:GetTop()
    if not (Number(scale) and Number(left) and Number(top) and scale > 0) then return end
    addon.GetSettings().vignetteRadarBeaconPosition = {
        x = (left + WIDTH / 2) * scale - UIParent:GetWidth() / 2,
        y = top * scale - UIParent:GetHeight(),
    }
end

local function MakeCard(index)
    local card = CreateFrame("Button", nil, frame)
    card:SetSize(CARD_W, 25)
    card:SetFrameLevel(frame:GetFrameLevel() + 1)
    card.icon = card:CreateTexture(nil, "OVERLAY")
    card.icon:SetSize(18, 18)
    card.icon:SetPoint("LEFT", card, "LEFT", 0, 0)
    card.label = card:CreateFontString(nil, "OVERLAY")
    card.label:SetFont(FONT, 9, "OUTLINE")
    card.label:SetPoint("TOPLEFT", card, "TOPLEFT", 20, -1)
    card.label:SetWidth(67)
    card.label:SetJustifyH("LEFT")
    card.label:SetWordWrap(false)
    card.distance = card:CreateFontString(nil, "OVERLAY")
    card.distance:SetFont(FONT, 8, "OUTLINE")
    card.distance:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 20, 1)
    card.distance:SetTextColor(.73, .78, .81, .9)
    card.count = card:CreateFontString(nil, "OVERLAY")
    card.count:SetFont(FONT, 8, "OUTLINE")
    card.count:SetPoint("TOPRIGHT", card.icon, "TOPRIGHT", 3, 3)
    card.count:SetTextColor(1, 1, 1, 1)
    card:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        for n = 1, math.min(self.groupCount or 0, 8) do
            local item = self.group[n]
            local r, g, b = item.r, item.g, item.b
            GameTooltip:AddLine(item.name .. "  ·  " .. math.floor(item.distance + .5) .. " yd", r, g, b)
        end
        if (self.groupCount or 0) > 8 then
            GameTooltip:AddLine("+" .. (self.groupCount - 8) .. " More Nearby", .7, .8, .83)
        end
        GameTooltip:AddLine(self.group[1].source == "note"
            and "Shift-Click for a Waypoint. Drag the Top Edge to Move."
            or "Click to Focus; Shift-Click to Navigate. Drag the Top Edge to Move.",
            .66, .76, .8)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    card:SetScript("OnClick", function(self, button)
        local item = self.group and self.group[1]
        if not item or preview then return end
        local shift = IsShiftKeyDown and IsShiftKeyDown()
        if item.kind == "quest" then
            if shift then NavigateToPoint(item)
            else
                local exploration = addon.VignetteRadarExploration
                if exploration and exploration.FocusQuest then exploration.FocusQuest(item.raw.questID) end
            end
        elseif item.source == "live" and addon.HandleVignetteClick then
            addon.HandleVignetteClick(item.raw, button)
        elseif item.source == "note" and shift then
            NavigateToPoint(item)
        end
    end)
    card:Hide()
    cards[index] = card
    return card
end

local function EnsureFrame()
    if frame then return frame end
    frame = CreateFrame("Frame", "VignetteRadarBeaconRail", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    local saved = addon.GetSettings().vignetteRadarBeaconPosition
    frame:SetPoint("TOP", UIParent, "TOP",
        type(saved) == "table" and Number(saved.x) or 0,
        type(saved) == "table" and Number(saved.y) or -84)
    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAllPoints()
    frame.background:SetTexture(SURFACE)
    frame.border = frame:CreateTexture(nil, "BORDER")
    frame.border:SetAllPoints()
    frame.border:SetTexture(BORDER)
    frame.heading = frame:CreateFontString(nil, "OVERLAY")
    frame.heading:SetFont(FONT, 10, "OUTLINE")
    frame.heading:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -8)
    frame.heading:SetText("Bearing Bar")
    frame.summary = frame:CreateFontString(nil, "OVERLAY")
    frame.summary:SetFont(FONT, 9, "OUTLINE")
    frame.summary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -9)
    frame.summary:SetTextColor(.73, .78, .81, .95)
    frame.empty = frame:CreateFontString(nil, "OVERLAY")
    frame.empty:SetFont(FONT, 10, "OUTLINE")
    frame.empty:SetPoint("TOP", frame, "TOP", 0, -42)
    frame.empty:SetTextColor(.73, .78, .81, .9)
    frame.empty:Hide()
    frame.axis = frame:CreateTexture(nil, "ARTWORK")
    frame.axis:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -27)
    frame.axis:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -27)
    frame.axis:SetHeight(1)
    frame.center = frame:CreateTexture(nil, "ARTWORK")
    frame.center:SetSize(2, 11)
    frame.center:SetPoint("TOP", frame, "TOP", 0, -23)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition() end)
    frame.update = function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < .2 then return end
        self.elapsed = 0
        local started = type(debugprofilestop) == "function" and debugprofilestop() or nil
        local ok = pcall(API.Render)
        if not ok then Pause("display error"); return end
        if started then
            local elapsedMS = debugprofilestop() - started
            slowUpdates = elapsedMS > 20 and slowUpdates + 1 or 0
            if elapsedMS > 100 or slowUpdates >= 3 then Pause("slow updates") end
        end
    end
    RefreshTheme()
    frame:Hide()
    return frame
end

local function Add(out, kind, source, raw, origin, player, mapID, range)
    if not (source and Number(source.worldX) and Number(source.worldY)
        and Number(source.mapX) and Number(source.mapY)) then return end
    if player.instanceID and source.instanceID and player.instanceID ~= source.instanceID then return end
    local dx, dy = source.worldX - player.worldX, source.worldY - player.worldY
    local distance2 = dx * dx + dy * dy
    if distance2 > range * range then return end
    local r, g, b
    if kind == "quest" then r, g, b = QuestColor(source)
    else r, g, b = StyleColor(source.isWorldBoss and "boss" or "rare") end
    out[#out + 1] = {
        kind = kind, source = origin, raw = raw,
        mapID = source.mapID or mapID, worldX = source.worldX, worldY = source.worldY,
        name = type(source.name) == "string" and source.name or (kind == "quest" and "Quest Point" or "Rare"),
        distance2 = distance2, distance = math.sqrt(distance2),
        r = r, g = g, b = b, completed = source.completed == true,
        priority = source.isWorldBoss and 1 or kind == "rare" and 2 or 3,
    }
end

function API.BuildCandidates(mapID, player, targets, quests, notes, visible, db)
    db = db or addon.GetSettings()
    if not (mapID and player and Number(player.worldX) and Number(player.worldY)) then
        return {}
    end
    local range = math.max(150, math.min(2400, Number(db.vignetteRadarBeaconRange) or 1200))
    local list = {}
    if db.vignetteRadarBeaconRares and type(targets) == "table" then
        for index = 1, math.min(#targets, 128) do
            local target = targets[index]
            if target.category == "rare" and not target.stale
                and (not visible or visible(target)) then
                Add(list, "rare", target, target, "live", player, mapID, range)
            end
        end
    end
    if db.vignetteRadarBeaconQuests and type(quests) == "table" then
        for index = 1, math.min(#quests, 128) do
            Add(list, "quest", quests[index], quests[index], "quest", player, mapID, range)
        end
    end
    if db.vignetteRadarBeaconRares and type(notes) == "table"
        and db.vignetteRadarPOISource ~= "none" and db.vignetteRadarPOITypes.mob ~= false then
        for index = 1, math.min(#notes, 64) do
            local note = notes[index]
            if note.kind == "mob" and Number(note.worldX) and Number(note.worldY)
                and not (addon.VignetteRadarRecent and addon.VignetteRadarRecent.IsHidden
                    and addon.VignetteRadarRecent.IsHidden(note, db)) then
                local duplicate = false
                for j = 1, #list do
                    local live = list[j]
                    if live.kind == "rare" and live.source == "live" then
                        local dx, dy = note.worldX - live.worldX, note.worldY - live.worldY
                        if dx * dx + dy * dy <= 45 * 45 then duplicate = true; break end
                    end
                end
                if not duplicate then Add(list, "rare", note, note, "note", player, mapID, range) end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.distance2 < b.distance2
    end)
    local max = math.max(4, math.min(24, Number(db.vignetteRadarBeaconMax) or 8))
    while #list > max do list[#list] = nil end
    return list
end

function API.Sync(mapID, player, targets, quests, notes, visible)
    if preview or paused then return end
    local db = addon.GetSettings()
    if not (db.vignetteRadarBeaconsEnabled and db.vignetteRadarEnabled) then
        candidates, lastMapID, lastPlayer = {}, nil, nil
        if frame then frame:SetScript("OnUpdate", nil); frame:Hide() end
        return
    end
    if not (mapID and player and Number(player.worldX) and Number(player.worldY)) then
        candidates, lastMapID, lastPlayer = {}, nil, nil
        EnsureFrame():SetHeight(64)
        frame:SetScript("OnUpdate", nil)
        frame:Show()
        local ok = pcall(API.Render)
        if not ok then Pause("display error") end
        return
    end
    local ok, list = pcall(API.BuildCandidates,
        mapID, player, targets, quests, notes, visible, db)
    if not ok then Pause("scan error"); return end
    candidates, lastMapID, lastPlayer = list, mapID, player
    EnsureFrame():SetHeight(#list > 0 and HEIGHT or 64)
    frame:SetScript("OnUpdate", #list > 0 and frame.update or nil)
    frame:Show()
    RefreshTheme()
    local ok = pcall(API.Render)
    if not ok then Pause("display error") end
end

local function Facing()
    if type(GetPlayerFacing) ~= "function" then return nil end
    local ok, result = pcall(GetPlayerFacing)
    return ok and Number(result) or nil
end

function API.Render()
    if not (frame and frame:IsShown()) then return end
    local player = lastPlayer
    local facing = Facing()
    if not (player and lastMapID) then
        frame.summary:SetText("Position Unavailable")
        frame.empty:SetText("Waiting for Map Position")
        frame.empty:Show()
        for _, card in ipairs(cards) do card:Hide() end
        return
    end
    if not facing then
        frame.summary:SetText("Heading Unavailable")
        frame.empty:SetText("Waiting for Player Heading")
        frame.empty:Show()
        for _, card in ipairs(cards) do card:Hide() end
        return
    end
    if #candidates == 0 then
        frame.summary:SetText("0 Points in " .. addon.GetSettings().vignetteRadarBeaconRange .. " yd")
        frame.empty:SetText("No Rare or Quest Points in Range")
        frame.empty:Show()
        for _, card in ipairs(cards) do card:Hide() end
        return
    end
    frame.empty:Hide()
    for index = 1, BINS do
        local bin = bins[index]
        if not bin then bin = {}; bins[index] = bin end
        for j = #bin, 1, -1 do bin[j] = nil end
    end
    local count = 0
    for _, item in ipairs(candidates) do
        local dx, dy = item.worldX - player.worldX, item.worldY - player.worldY
        local angle = (atan2(dy, dx) - facing + PI) % TWO_PI - PI
        local index = math.max(1, math.min(BINS,
            math.floor((angle + PI) / TWO_PI * BINS) + 1))
        local bin = bins[index]
        bin[#bin + 1] = item
        count = count + 1
    end
    frame.summary:SetText(count .. " Point" .. (count == 1 and "" or "s") .. "  ·  Facing")
    for row = 1, ROWS do lastX[row] = -math.huge end
    local shown = 0
    for index = BINS, 1, -1 do
        local bin = bins[index]
        if #bin > 0 then
            local angle = ((index - .5) / BINS * TWO_PI) - PI
            local x = -angle / PI * 209
            local row
            for r = 1, ROWS do
                if x - lastX[r] >= CARD_W + 3 then row = r; break end
            end
            if row then
                lastX[row] = x
                shown = shown + 1
                local card = cards[shown] or MakeCard(shown)
                local item = bin[1]
                card.group, card.groupCount = bin, #bin
                card.icon:SetTexture(item.kind == "quest"
                    and (item.completed and QUEST or QUEST_HOLLOW) or RARE)
                card.icon:SetVertexColor(item.r, item.g, item.b, 1)
                card.label:SetText(item.name)
                card.label:SetTextColor(item.r, item.g, item.b, 1)
                card.distance:SetText(math.floor(item.distance + .5) .. " yd")
                card.count:SetText(#bin > 1 and ("+" .. (#bin - 1)) or "")
                card:ClearAllPoints()
                card:SetPoint("TOP", frame, "TOP", x, -31 - (row - 1) * 28)
                card:Show()
            end
        end
    end
    for index = shown + 1, #cards do cards[index]:Hide() end
end

function API.Preview(value)
    if paused then return end
    if value ~= true then
        preview = false
        if previewSaved then
            candidates, lastMapID, lastPlayer =
                previewSaved.candidates, previewSaved.mapID, previewSaved.player
            previewSaved = nil
        end
        if frame then
            frame:SetHeight(#candidates > 0 and HEIGHT or 64)
            local db = addon.GetSettings()
            frame:SetScript("OnUpdate", #candidates > 0 and db.vignetteRadarBeaconsEnabled
                and db.vignetteRadarEnabled and frame.update or nil)
            frame:SetShown(db.vignetteRadarBeaconsEnabled and db.vignetteRadarEnabled)
            API.Render()
        end
        return
    end
    if not preview then
        previewSaved = { candidates = candidates, mapID = lastMapID, player = lastPlayer }
    end
    preview = true
    local demo = {
        { kind = "rare", name = "Sample Rare", worldX = 100, worldY = 20,
            distance = 102, r = 1, g = .55, b = .35, priority = 2, raw = {} },
        { kind = "quest", name = "Quest Objective", worldX = 120, worldY = -35,
            distance = 125, r = .46, g = .80, b = 1, priority = 3, raw = {} },
    }
    candidates, lastMapID, lastPlayer = demo, 1, { worldX = 0, worldY = 0 }
    EnsureFrame():SetHeight(HEIGHT)
    frame:SetScript("OnUpdate", frame.update)
    frame:Show()
    API.Render()
end

function API.IsAvailable() return type(CreateFrame) == "function" end
