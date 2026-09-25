local _, addon = ...
if type(addon) ~= "table" then return end

-- One explicit Blizzard waypoint at a time. No frame updates or guide parsing.
local API = {}
addon.VignetteRadarWorldFocus = API
local targets, quests, notes, player = {}, {}, {}, nil
local active, candidates = nil, {}

local function Number(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function Position(item)
    local mapID, x, y = Number(item and item.mapID), Number(item and item.mapX), Number(item and item.mapY)
    if not (mapID and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1) then return nil end
    return mapID, x, y
end

local function SameWaypoint(step)
    if not (C_Map and type(C_Map.GetUserWaypoint) == "function") then return false end
    if C_SuperTrack and type(C_SuperTrack.IsSuperTrackingUserWaypoint) == "function" then
        local tracked, isUserWaypoint = pcall(C_SuperTrack.IsSuperTrackingUserWaypoint)
        if not tracked or isUserWaypoint == false
            or (issecretvalue and issecretvalue(isUserWaypoint)) then return false end
    end
    local ok, point = pcall(C_Map.GetUserWaypoint)
    if not ok or not point or (issecretvalue and issecretvalue(point)) then return false end
    local read, mapID, x, y = pcall(function()
        return point.uiMapID, point.position.x, point.position.y
    end)
    if not read or not (Number(mapID) and Number(x) and Number(y)) then return false end
    return mapID == step.mapID and math.abs(x - step.mapX) < .0001
        and math.abs(y - step.mapY) < .0001
end

local function Place(step)
    local mapID, x, y = Position(step)
    if not (mapID and UiMapPoint and type(UiMapPoint.CreateFromCoordinates) == "function"
        and C_Map and type(C_Map.SetUserWaypoint) == "function") then return false, "Waypoint unavailable" end
    if type(C_Map.CanSetUserWaypointOnMap) == "function" then
        local ok, allowed = pcall(C_Map.CanSetUserWaypointOnMap, mapID)
        if not ok or allowed == false or (issecretvalue and issecretvalue(allowed)) then
            return false, "Waypoint unavailable on this map"
        end
    end
    local ok, point = pcall(UiMapPoint.CreateFromCoordinates, mapID, x, y)
    if not ok or not point or (issecretvalue and issecretvalue(point)) then return false, "Waypoint unavailable" end
    local placed, result = pcall(C_Map.SetUserWaypoint, point)
    if not placed or result == false or (issecretvalue and issecretvalue(result)) then
        return false, "Waypoint could not be set"
    end
    if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
    return true
end

local function Valid(item)
    local mapID = Position(item)
    return mapID and Number(item.worldX) and Number(item.worldY)
        and (not player or not (Number(player.instanceID) and Number(item.instanceID)
            and player.instanceID ~= item.instanceID))
end

local function Select(item)
    if not (addon.GetSettings().vignetteRadarWorldFocusEnabled and Valid(item)) then
        return false, "No usable location"
    end
    local steps = { item }
    if item.kind == "treasure" and addon.GetSettings().vignetteRadarWorldFocusRoutes
        and type(item.route) == "table" and #item.route > 1 then steps = item.route end
    local ok, reason = Place(steps[1])
    if not ok then return false, reason end
    local radius = addon.GetSettings().vignetteRadarWorldFocusArrivalRadius or 20
    local dx = player and player.worldX - steps[1].worldX or 0
    local dy = player and player.worldY - steps[1].worldY or 0
    active = { key = item.key or item.questID or item.name, name = item.name or "Location",
        kind = item.kind, steps = steps, index = 1,
        wasOutside = player and dx * dx + dy * dy > (radius + 5) * (radius + 5) or false }
    return true
end

function API.SelectTarget(target)
    if not target or target.stale or target.sample then return false, "No live target" end
    return Select({ key = target.key, name = target.name, kind = target.category,
        mapID = target.mapID, mapX = target.mapX, mapY = target.mapY,
        worldX = target.worldX, worldY = target.worldY, instanceID = target.instanceID })
end

function API.SelectQuest(questID)
    for _, quest in ipairs(quests) do
        if quest.questID == questID then
            return Select({ key = "quest:" .. questID, name = quest.name, kind = "quest",
                mapID = player and player.mapID, mapX = quest.mapX, mapY = quest.mapY,
                worldX = quest.worldX, worldY = quest.worldY, instanceID = quest.instanceID })
        end
    end
    return false, "Quest point unavailable"
end

function API.SelectNote(note)
    if not note then return false, "No map note" end
    if note.kind == "entrance" and note.parentCoord then
        for _, candidate in ipairs(notes) do
            if candidate.kind == "treasure" and candidate.mapID == note.mapID
                and candidate.key == note.source .. ":" .. note.mapID .. ":" .. note.parentCoord then
                return Select(candidate)
            end
        end
    end
    return Select(note)
end

function API.SelectPoint(point)
    return Select(point)
end

function API.LoadZygorGuide(note)
    if not (note and note.zygorPoint) then return false end
    local viewer = _G.ZygorGuidesViewer
    local poi = viewer and viewer.Poi
    if not (poi and type(poi.LoadPoint) == "function") then return false end
    local ok = pcall(poi.LoadPoint, poi, note.zygorPoint)
    if ok then addon.GetSettings().vignetteRadarWorldFocusZygor = true end
    return ok
end

local function BuildCandidates()
    candidates = {}
    if not player then return end
    local db = addon.GetSettings()
    local function Add(item, priority)
        if #candidates >= 128 or not Valid(item) then return end
        local dx, dy = item.worldX - player.worldX, item.worldY - player.worldY
        item.focusDistance = math.sqrt(dx * dx + dy * dy)
        item.focusPriority = priority
        candidates[#candidates + 1] = item
    end
    for _, target in ipairs(targets) do
        if not target.stale and not target.sample and (target.category == "rare"
            or target.category == "treasure") then
            Add({ key = target.key, name = target.name, kind = target.category,
                mapID = target.mapID, mapX = target.mapX, mapY = target.mapY,
                worldX = target.worldX, worldY = target.worldY, instanceID = target.instanceID }, 1)
        end
    end
    for _, quest in ipairs(quests) do
        Add({ key = "quest:" .. quest.questID .. ":" .. math.floor((quest.mapX or 0) * 10000),
            name = quest.name, kind = "quest", mapID = player.mapID,
            mapX = quest.mapX, mapY = quest.mapY, worldX = quest.worldX,
            worldY = quest.worldY, instanceID = quest.instanceID }, 2)
    end
    for _, note in ipairs(notes) do
        if note.kind == "guide" and db.vignetteRadarWorldFocusZygor then Add(note, 2) end
        if db.vignetteRadarWorldFocusSavedNotes and (note.kind == "treasure"
            or note.kind == "mob" or note.kind == "entrance") then
            local duplicate = false
            if note.kind ~= "entrance" then
                for _, target in ipairs(candidates) do
                    if target.focusPriority == 1 and ((note.kind == "mob" and target.kind == "rare")
                        or note.kind == target.kind) then
                        local dx, dy = note.worldX - target.worldX, note.worldY - target.worldY
                        if dx * dx + dy * dy <= 3600 then duplicate = true; break end
                    end
                end
            end
            if not duplicate then Add(note, 3) end
        end
    end
    table.sort(candidates, function(a, b)
        if a.focusPriority ~= b.focusPriority then return a.focusPriority < b.focusPriority end
        if a.focusDistance ~= b.focusDistance then return a.focusDistance < b.focusDistance end
        return tostring(a.key) < tostring(b.key)
    end)
end

function API.Sync(mapID, snapshot, liveTargets, questPoints, mapNotes)
    targets, quests, notes, player = liveTargets or {}, questPoints or {}, mapNotes or {}, snapshot
    if player then player.mapID = mapID end
    if addon.GetSettings().vignetteRadarWorldFocusEnabled then BuildCandidates()
    else candidates, active = {}, nil end
    if not (active and player) then return end
    local step = active.steps[active.index]
    if not step or not SameWaypoint(step) then active = nil; return end
    if active.kind == "guide" then
        for _, note in ipairs(notes) do
            if note.kind == "guide" and note.key ~= active.key then
                Select(note)
                return
            end
        end
    end
    if not addon.GetSettings().vignetteRadarWorldFocusAutoAdvance then return end
    if Number(player.instanceID) and Number(step.instanceID)
        and player.instanceID ~= step.instanceID then return end
    local dx, dy = player.worldX - step.worldX, player.worldY - step.worldY
    local distance = math.sqrt(dx * dx + dy * dy)
    local radius = addon.GetSettings().vignetteRadarWorldFocusArrivalRadius or 20
    if distance > radius + 5 then active.wasOutside = true end
    if not active.wasOutside or distance > radius then return end
    if active.index < #active.steps then
        local nextStep = active.steps[active.index + 1]
        local ok = Place(nextStep)
        if ok then active.index, active.wasOutside = active.index + 1, false end
    else active = nil end
end

function API.Cycle(direction)
    if #candidates == 0 then return false, "No nearby focus points" end
    local index = direction and direction < 0 and 1 or 0
    for i, candidate in ipairs(candidates) do
        if active and candidate.key == active.key then index = i; break end
    end
    for offset = 1, #candidates do
        local nextIndex = ((index - 1 + (direction or 1) * offset) % #candidates) + 1
        local candidate = candidates[nextIndex]
        local ok = candidate.source and API.SelectNote(candidate) or Select(candidate)
        if ok then return true, candidates[nextIndex] end
    end
    return false, "No waypoint can be set here"
end

function API.Status()
    if active then return active.name .. "  ·  " .. active.index .. "/" .. #active.steps end
    return #candidates .. " possible focus points"
end

function API.Advance()
    if not active or active.index >= #active.steps then return false end
    if not SameWaypoint(active.steps[active.index]) then active = nil; return false end
    local nextStep = active.steps[active.index + 1]
    local ok = Place(nextStep)
    if ok then active.index, active.wasOutside = active.index + 1, false end
    return ok
end

function API.ZygorNote(mapID, mapToWorld, mapVector)
    if addon.GetSettings().vignetteRadarWorldFocusZygor ~= true then return nil end
    local zgv = _G.ZygorGuidesViewer
    local ok, waypoint, step = pcall(function()
        return zgv and zgv.Pointer and zgv.Pointer.current_waypoint, zgv and zgv.CurrentStep
    end)
    if not ok or not waypoint then return nil end
    local read, pointMapID, x, y, title = pcall(function()
        return waypoint.m, waypoint.x, waypoint.y, waypoint.title
    end)
    if not read or Number(pointMapID) ~= mapID or not Number(x) or not Number(y)
        or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    local converted, worldX, worldY, instanceID = pcall(mapToWorld, mapID, mapVector(x, y))
    if not converted or not Number(worldX) or not Number(worldY) then return nil end
    local name = type(title) == "string" and title ~= "" and title
        or "Zygor current step"
    local gotStep, stepNum = pcall(function() return step and step.num end)
    stepNum = gotStep and Number(stepNum) or nil
    return { key = "zygor:" .. tostring(stepNum or 0) .. ":" .. math.floor(x * 10000)
        .. ":" .. math.floor(y * 10000), kind = "guide", source = "Zygor",
        name = name, mapID = mapID, mapX = x, mapY = y,
        worldX = worldX, worldY = worldY, instanceID = instanceID,
        note = "Current active guide waypoint" }
end
