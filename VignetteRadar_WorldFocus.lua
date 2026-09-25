local _, addon = ...
if type(addon) ~= "table" then return end

-- One owned Blizzard waypoint at a time. Route choices are made only on
-- selection, arrival, or quest progress; there is no per-frame route scan.
local API = {}
addon.VignetteRadarWorldFocus = API
local targets, quests, notes, player = {}, {}, {}, nil
local active, candidates = nil, {}
local route, lastSelected = nil, nil
local ROUTE_LIMIT, ROUTE_DUPLICATE_YARDS = 192, 60
local QuestComplete

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

local function WaypointColor(item)
    if not item then return nil end
    local kind = item.kind == "mob" and "rare" or item.kind
    if kind ~= "rare" and kind ~= "treasure" and kind ~= "quest" then return nil end
    local r, g, b
    local style = addon.VignetteRadarStyle
    if kind == "quest" then
        if addon.GetSettings().vignetteRadarQuestColors and item.colorSlot
            and addon.VignetteRadarQuestColors then
            local color = addon.VignetteRadarQuestColors[item.colorSlot]
            if color then r, g, b = color[1], color[2], color[3] end
        end
    end
    if not r and style and type(style.Color) == "function" then
        r, g, b = style.Color(kind == "rare" and item.isWorldBoss and "boss" or kind)
    end
    if not (Number(r) and Number(g) and Number(b)) then r, g, b = .55, .88, .82 end
    return r, g, b
end

local function Place(step, item)
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
    local wui = _G.WaypointUIAPI and _G.WaypointUIAPI.Navigation
    if item and addon.GetSettings().vignetteRadarWorldFocusThemedWaypoint
        and wui and type(wui.NewUserNavigation) == "function" then
        local r, g, b = WaypointColor(item)
        if r then
            local named, result = pcall(wui.NewUserNavigation, {
                name = item.name or "World Focus", mapID = mapID, x = x * 100, y = y * 100,
                r = r, g = g, b = b, requestRecolor = true, suppressAudio = true,
            })
            if named and result and not (issecretvalue and issecretvalue(result)) then return true end
        end
    end
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

local function RouteKind(item)
    if not item then return nil end
    if item.kind == "rare" or item.kind == "mob" then return "rare" end
    if item.kind == "treasure" then return "treasure" end
    if item.kind == "quest" and Number(item.questID) then return "quest" end
    return nil
end

local function RouteID(item)
    local kind = RouteKind(item)
    if not kind then return nil end
    if kind == "quest" then
        return "quest:" .. item.questID .. ":" .. math.floor(item.mapX * 10000 + .5)
            .. ":" .. math.floor(item.mapY * 10000 + .5)
    end
    return kind .. ":" .. tostring(item.key or item.name or "location")
end

local function Distance(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function AttachKnownTreasurePath(item)
    if not (item and item.kind == "treasure" and not item.route
        and Number(item.worldX) and Number(item.worldY)) then return end
    for _, note in ipairs(notes) do
        if note.kind == "treasure" and note.mapID == item.mapID
            and type(note.route) == "table" and #note.route > 1
            and Number(note.worldX) and Number(note.worldY)
            and Distance(note.worldX, note.worldY, item.worldX, item.worldY)
                <= ROUTE_DUPLICATE_YARDS then
            item.route = note.route
            return
        end
    end
end

local function TravelMode()
    local mode = addon.GetSettings().vignetteRadarAutoRouteTravel or "auto"
    if mode ~= "auto" then return mode end
    if type(IsFlying) == "function" then
        local ok, flying = pcall(IsFlying)
        if ok and not (issecretvalue and issecretvalue(flying)) and flying == true then
            return "flying"
        end
    end
    return "ground"
end

local function RouteCost(item, travelMode)
    local x, y = player.worldX, player.worldY
    local steps = item.route
    if type(steps) ~= "table" or #steps < 2 then
        return Distance(x, y, item.worldX, item.worldY)
    end
    local first = steps[1]
    if not (Number(first.worldX) and Number(first.worldY)) then
        return Distance(x, y, item.worldX, item.worldY)
    end
    local cost = Distance(x, y, first.worldX, first.worldY)
    local path = 0
    local prior = first
    for index = 2, math.min(#steps, 12) do
        local step = steps[index]
        if Number(step.worldX) and Number(step.worldY) then
            path = path + Distance(prior.worldX, prior.worldY, step.worldX, step.worldY)
            prior = step
        end
    end
    -- Ground travel weighs the pack's approach path fully. In flight the
    -- approach still matters, but its interior steps weigh less for ordering.
    return cost + path * (travelMode == "flying" and .35 or 1)
end

local function Visited(item)
    if not route then return false end
    local id, kind = RouteID(item), RouteKind(item)
    if id and route.visited[id] then return true end
    local limit = kind == "quest" and 8 or ROUTE_DUPLICATE_YARDS
    for _, prior in ipairs(route.visitedPlaces) do
        if prior.kind == kind and (kind ~= "quest" or prior.questID == item.questID)
            and Distance(prior.x, prior.y, item.worldX, item.worldY) <= limit then return true end
    end
    return false
end

local function MarkVisited(item)
    if not route or not item then return end
    local id = RouteID(item)
    if id then route.visited[id] = true end
    if #route.visitedPlaces < ROUTE_LIMIT and Number(item.worldX) and Number(item.worldY) then
        route.visitedPlaces[#route.visitedPlaces + 1] = {
            kind = RouteKind(item), questID = item.questID,
            x = item.worldX, y = item.worldY,
        }
    end
end

QuestComplete = function(questID)
    if not (questID and C_QuestLog) then return false end
    local function Done(callback)
        if type(callback) == "function" then
            local ok, done = pcall(callback, questID)
            if ok and not (issecretvalue and issecretvalue(done)) and done == true then
                return true
            end
        end
        return false
    end
    if type(C_QuestLog.IsOnQuest) == "function" then
        local ok, onQuest = pcall(C_QuestLog.IsOnQuest, questID)
        if ok and not (issecretvalue and issecretvalue(onQuest)) and onQuest == true then
            return Done(C_QuestLog.IsComplete)
        end
    end
    return Done(C_QuestLog.IsComplete) or Done(C_QuestLog.IsQuestFlaggedCompleted)
end

local function QuestProgress(questID)
    if not (questID and C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function") then return nil end
    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(objectives) ~= "table" or (issecretvalue and issecretvalue(objectives)) then return nil end
    local result = {}
    for index = 1, math.min(#objectives, 16) do
        local read, complete, count = pcall(function()
            return objectives[index].finished, objectives[index].numFulfilled
        end)
        if not read or (issecretvalue and (issecretvalue(complete) or issecretvalue(count))) then return nil end
        result[#result + 1] = (complete and "1" or "0") .. ":" .. tostring(Number(count) or 0)
    end
    return table.concat(result, ",")
end

local function NextRouteStop()
    if not (route and player) then return nil end
    local kind = route.kind
    local best, bestCost
    local inspected = 0
    local travelMode = TravelMode()
    local questDone = {}
    local function Consider(item)
        if inspected >= ROUTE_LIMIT then return end
        inspected = inspected + 1
        local complete = false
        if kind == "quest" then
            complete = questDone[item.questID]
            if complete == nil then
                complete = QuestComplete(item.questID)
                questDone[item.questID] = complete
            end
        end
        if RouteKind(item) ~= kind or not Valid(item) or item.mapID ~= player.mapID
            or Visited(item) or (kind == "quest" and (complete
                or route.questID and item.questID ~= route.questID)) then return end
        if kind == "quest" and C_QuestLog and type(C_QuestLog.IsOnQuest) == "function" then
            local ok, onQuest = pcall(C_QuestLog.IsOnQuest, item.questID)
            if ok and not (issecretvalue and issecretvalue(onQuest)) and onQuest == false then return end
        end
        local recent = addon.VignetteRadarRecent
        if kind ~= "quest" and recent and type(recent.IsHidden) == "function"
            and recent.IsHidden(item) then return end
        local cost = RouteCost(item, travelMode)
        if not best or cost < bestCost or (cost == bestCost
            and tostring(RouteID(item)) < tostring(RouteID(best))) then
            best, bestCost = item, cost
        end
    end
    if kind == "quest" then
        for _, quest in ipairs(quests) do
            Consider({ kind = "quest", questID = quest.questID, name = quest.name,
                colorSlot = quest.colorSlot,
                mapID = quest.mapID or player.mapID, mapX = quest.mapX, mapY = quest.mapY,
                worldX = quest.worldX, worldY = quest.worldY, instanceID = quest.instanceID })
        end
    else
        local live = {}
        for _, target in ipairs(targets) do
            if target.category == kind and not target.stale and not target.sample then
                live[#live + 1] = { key = target.key, kind = target.category, name = target.name,
                    isWorldBoss = target.isWorldBoss,
                    mapID = target.mapID, mapX = target.mapX, mapY = target.mapY,
                    worldX = target.worldX, worldY = target.worldY,
                    instanceID = target.instanceID, rewardQuestID = target.rewardQuestID,
                    npcID = target.npcID, objectGUID = target.objectGUID,
                    objectID = target.objectID, isDead = target.isDead }
            end
        end
        local unpairedNotes = {}
        if addon.GetSettings().vignetteRadarAutoRouteMapNotes then
            for _, note in ipairs(notes) do
                if RouteKind(note) == kind then
                    local duplicate
                    if Number(note.worldX) and Number(note.worldY) then
                        for _, target in ipairs(live) do
                            if target.mapID == note.mapID
                                and Number(target.worldX) and Number(target.worldY)
                                and Distance(target.worldX, target.worldY, note.worldX, note.worldY)
                                    <= ROUTE_DUPLICATE_YARDS then
                                duplicate = target
                                break
                            end
                        end
                    end
                    if duplicate then
                        if duplicate.kind == "treasure" and not duplicate.route
                            and type(note.route) == "table" and #note.route > 1 then
                            duplicate.route = note.route
                        end
                    else unpairedNotes[#unpairedNotes + 1] = note end
                end
            end
        end
        for _, item in ipairs(live) do Consider(item) end
        for _, note in ipairs(unpairedNotes) do Consider(note) end
    end
    return best
end

local function ArrivalRadius()
    local settings = addon.GetSettings()
    return route and (settings.vignetteRadarAutoRouteArrivalRadius or 3)
        or (settings.vignetteRadarWorldFocusArrivalRadius or 20)
end

local function ArmArrival()
    if not (active and player) then return end
    local step = active.steps[active.index]
    if not (step and Number(step.worldX) and Number(step.worldY)) then return end
    local radius = ArrivalRadius()
    local margin = route and 0 or 5
    active.wasOutside = Distance(player.worldX, player.worldY,
        step.worldX, step.worldY) > radius + margin
end

local function Activate(item)
    local steps = { item }
    if item.kind == "treasure" and addon.GetSettings().vignetteRadarWorldFocusRoutes
        and type(item.route) == "table" and #item.route > 1 then steps = item.route end
    local ok, reason = Place(steps[1], item)
    if not ok then return false, reason end
    active = { key = item.key or item.questID or item.name, name = item.name or "Location",
        kind = item.kind, questID = item.questID, item = item, steps = steps, index = 1,
        wasOutside = false }
    ArmArrival()
    return true
end

local function AdvanceRoute()
    if not (route and active) then return false end
    MarkVisited(active.item)
    local nextItem = NextRouteStop()
    if nextItem then
        if route.kind == "quest" and not route.questID then route.questID = nextItem.questID end
        route.waiting = false
        local ok, reason = Activate(nextItem)
        if not ok then route = nil end
        return ok, reason
    end
    route.waiting = route.kind == "quest" and route.questID ~= nil
    if not route.waiting then route, active = nil, nil end
    return false
end

local function Select(item)
    if not (addon.GetSettings().vignetteRadarWorldFocusEnabled and Valid(item)) then
        return false, "No usable location"
    end
    AttachKnownTreasurePath(item)
    local ok, reason = Activate(item)
    if not ok then return false, reason end
    lastSelected = item
    route = nil
    local kind = RouteKind(item)
    if kind and addon.GetSettings().vignetteRadarAutoRouteOnSelect then
        route = { kind = kind, questID = kind == "quest" and item.questID or nil,
            visited = {}, visitedPlaces = {}, waiting = false,
            progress = kind == "quest" and QuestProgress(item.questID) or nil }
    end
    ArmArrival()
    return true
end

function API.ToggleRoute()
    if route then route = nil; return false, "Auto Route paused; waypoint kept" end
    local item = active and active.item or lastSelected
    local kind = RouteKind(item)
    if not kind then return false, "Click a rare, treasure, or quest point first" end
    if not addon.GetSettings().vignetteRadarWorldFocusEnabled or not Valid(item)
        or not player or item.mapID ~= player.mapID then
        return false, "This point is not available on the current map"
    end
    if not (active and active.item == item and SameWaypoint(active.steps[active.index])) then
        local ok, reason = Activate(item)
        if not ok then return false, reason end
    end
    route = { kind = kind, questID = kind == "quest" and item.questID or nil,
        visited = {}, visitedPlaces = {}, waiting = false,
        progress = kind == "quest" and QuestProgress(item.questID) or nil }
    ArmArrival()
    return true, "Auto Route: " .. kind
end

function API.IsRouteActive() return route ~= nil end

function API.SkipRouteStop()
    if not (route and active) then return false, "No active route" end
    return AdvanceRoute()
end

function API.SelectTarget(target)
    if not target or target.stale or target.sample then return false, "No live target" end
    return Select({ key = target.key, name = target.name, kind = target.category,
        isWorldBoss = target.isWorldBoss, rewardQuestID = target.rewardQuestID,
        npcID = target.npcID, objectGUID = target.objectGUID,
        objectID = target.objectID, isDead = target.isDead,
        mapID = target.mapID, mapX = target.mapX, mapY = target.mapY,
        worldX = target.worldX, worldY = target.worldY, instanceID = target.instanceID })
end

function API.SelectQuest(questID)
    for _, quest in ipairs(quests) do
        if quest.questID == questID then
            return Select({ key = "quest:" .. questID, questID = questID,
                name = quest.name, kind = "quest",
                colorSlot = quest.colorSlot,
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
                isWorldBoss = target.isWorldBoss,
                mapID = target.mapID, mapX = target.mapX, mapY = target.mapY,
                worldX = target.worldX, worldY = target.worldY, instanceID = target.instanceID }, 1)
        end
    end
    for _, quest in ipairs(quests) do
        Add({ key = "quest:" .. quest.questID .. ":" .. math.floor((quest.mapX or 0) * 10000),
            questID = quest.questID, colorSlot = quest.colorSlot,
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
    else candidates, active, route = {}, nil, nil end
    if not (active and player) then return end
    local step = active.steps[active.index]
    if not step or not SameWaypoint(step) then active, route = nil, nil; return end
    if route and route.kind ~= "quest" and addon.VignetteRadarRecent
        and addon.VignetteRadarRecent.IsHidden(active.item) then
        AdvanceRoute()
        return
    end
    if route and route.kind == "quest" then
        if QuestComplete(route.questID) then
            route.questID, route.progress = nil, nil
            AdvanceRoute()
            return
        end
        local progress = QuestProgress(route.questID)
        if progress and route.progress and progress ~= route.progress then
            route.progress = progress
            for key in pairs(route.visited) do
                if key:find("^quest:" .. route.questID .. ":") then route.visited[key] = nil end
            end
            for index = #route.visitedPlaces, 1, -1 do
                if route.visitedPlaces[index].questID == route.questID then
                    table.remove(route.visitedPlaces, index)
                end
            end
            MarkVisited(active.item)
            route.waiting = true
        else route.progress = progress or route.progress end
        if route.waiting then
            local nextItem = NextRouteStop()
            if nextItem then route.waiting = false; Activate(nextItem) end
            return
        end
    end
    if active.kind == "guide" then
        for _, note in ipairs(notes) do
            if note.kind == "guide" and note.key ~= active.key then
                Select(note)
                return
            end
        end
    end
    if not route and not addon.GetSettings().vignetteRadarWorldFocusAutoAdvance then return end
    if Number(player.instanceID) and Number(step.instanceID)
        and player.instanceID ~= step.instanceID then return end
    local dx, dy = player.worldX - step.worldX, player.worldY - step.worldY
    local distance = math.sqrt(dx * dx + dy * dy)
    local radius = ArrivalRadius()
    if distance > radius + (route and 0 or 5) then active.wasOutside = true end
    if not active.wasOutside or distance > radius then return end
    if active.index < #active.steps then
        local nextStep = active.steps[active.index + 1]
        local ok = Place(nextStep, active.item)
        if ok then active.index, active.wasOutside = active.index + 1, false end
    elseif route then AdvanceRoute()
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
    if route then
        local kind = route.kind == "rare" and "Rare" or route.kind == "treasure" and "Treasure" or "Quest"
        return "Auto Route · " .. kind .. " · " .. (route.waiting and "Waiting for Next Objective"
            or active and active.name or "Choosing Next Stop")
    end
    if active then return active.name .. "  ·  " .. active.index .. "/" .. #active.steps end
    return #candidates .. " possible focus points"
end

function API.Advance()
    if not active or active.index >= #active.steps then return false end
    if not SameWaypoint(active.steps[active.index]) then active, route = nil, nil; return false end
    local nextStep = active.steps[active.index + 1]
    local ok = Place(nextStep, active.item)
    if ok then active.index, active.wasOutside = active.index + 1, false end
    return ok
end

function API.ZygorNote(mapID, mapToWorld, mapVector, allowHidden)
    if not allowHidden and addon.GetSettings().vignetteRadarWorldFocusZygor ~= true then return nil end
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
