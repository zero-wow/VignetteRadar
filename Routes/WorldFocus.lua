local _, addon = ...
if type(addon) ~= "table" then return end

-- One owned Blizzard waypoint at a time. Route choices are made only on
-- selection, arrival, or quest progress; there is no per-frame route scan.
local API = {}
addon.VignetteRadarWorldFocus = API
local targets, quests, notes, player = {}, {}, {}, nil
local active, candidates = nil, {}
local route, pausedRoute, lastSelected = nil, nil, nil
local horizonCache, horizonCachedAt
local lootSession
local ROUTE_LIMIT, ROUTE_DUPLICATE_YARDS = 192, 60
local QuestComplete

local function Number(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function Call(owner, name, ...)
    if type(owner) ~= "table" or type(owner[name]) ~= "function" then return nil end
    local ok, value = pcall(owner[name], ...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
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
    if kind ~= "rare" and kind ~= "treasure" and kind ~= "quest"
        and kind ~= "guide" then return nil end
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
        r, g, b = style.Color(kind == "rare" and item.isWorldBoss and "boss"
            or kind == "guide" and "accent" or kind)
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
            if named and result and not (issecretvalue and issecretvalue(result)) then
                local stability = addon.VignetteRadarWaypointStability
                local budget = addon.VignetteRadarBudget
                if stability and addon.GetSettings().vignetteRadarWorldFocusSmoothWaypoint
                    and not (budget and budget.paused
                        and (budget.paused.radar or budget.paused.background)) then
                    stability.Enable()
                elseif stability then stability.Disable() end
                return true
            end
        end
    end
    local stability = addon.VignetteRadarWaypointStability
    if stability then stability.Disable() end
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
    if item and item.kind == "guide" then return mapID ~= nil end
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
        return "quest:" .. item.questID .. (item.availableStart and ":start:" or ":objective:")
            .. math.floor(item.mapX * 10000 + .5)
            .. ":" .. math.floor(item.mapY * 10000 + .5)
    end
    return kind .. ":" .. tostring(item.key or item.name or "location")
end

local function QuestRouteItem(quest)
    return { kind = "quest", questID = quest.questID, name = quest.name,
        colorSlot = quest.colorSlot, taskType = quest.taskType, nextStep = quest.nextStep,
        mapID = quest.mapID or player.mapID, mapX = quest.mapX, mapY = quest.mapY,
        worldX = quest.worldX, worldY = quest.worldY, instanceID = quest.instanceID }
end

local function StartRouteItem(start)
    return { kind = "quest", availableStart = true, questID = start.questID,
        questLineID = start.questLineID,
        name = start.questName or start.questLineName or "Available Quest",
        mapID = start.mapID, mapX = start.x, mapY = start.y,
        worldX = start.worldX, worldY = start.worldY,
        instanceID = start.instanceID }
end

local function Distance(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function AttachKnownTreasurePath(item)
    if not (item and item.kind == "treasure" and not item.route
        and addon.GetSettings().vignetteRadarTreasurePlaybooks ~= false
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

local function RouteCost(item, travelMode, directOnly)
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
    if directOnly then return cost end
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
    for _, prior in ipairs(route.visitedPlaces) do
        local limit = kind == "quest" and 8
            or route.kind == "closest"
                and (prior.live ~= (item.live == true) and ROUTE_DUPLICATE_YARDS or 8)
                or ROUTE_DUPLICATE_YARDS
        local dx, dy = prior.x - item.worldX, prior.y - item.worldY
        if prior.kind == kind and prior.mapID == item.mapID
            and (kind ~= "quest" or prior.questID == item.questID)
            and (kind ~= "quest" or prior.availableStart == (item.availableStart == true))
            and dx * dx + dy * dy <= limit * limit then return true end
    end
    return false
end

local function MarkVisited(item)
    if not route or not item then return end
    horizonCache = nil
    local id = RouteID(item)
    if id then route.visited[id] = true end
    if #route.visitedPlaces < ROUTE_LIMIT and Number(item.worldX) and Number(item.worldY) then
        route.visitedPlaces[#route.visitedPlaces + 1] = {
            kind = RouteKind(item), questID = item.questID, mapID = item.mapID,
            availableStart = item.availableStart == true,
            live = item.live == true,
            x = item.worldX, y = item.worldY,
        }
    end
end

local function RememberQuestStep(stack, item)
    if not (stack and item and RouteKind(item) == "quest") then return end
    local id = RouteID(item)
    if not id or (#stack > 0 and RouteID(stack[#stack]) == id) then return end
    if #stack >= 64 then table.remove(stack, 1) end
    stack[#stack + 1] = item
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
            return false -- Objectives may be done, but the quest still needs its turn-in.
        end
    end
    return Done(C_QuestLog.IsQuestFlaggedCompleted) or Done(C_QuestLog.IsComplete)
end

local function HiddenWarbandQuestStart(item, trackingAccountQuests, checked)
    if not (item and item.availableStart and item.questID
        and trackingAccountQuests == false) then return false end
    if checked and checked[item.questID] ~= nil then return checked[item.questID] end
    -- Accepted quests still have real objectives even when completed elsewhere.
    local hidden = Call(C_QuestLog, "IsOnQuest", item.questID) ~= true
        and Call(C_QuestLog, "IsQuestFlaggedCompletedOnAccount", item.questID) == true
    if checked then checked[item.questID] = hidden end
    return hidden
end

local function AvailableQuestStep(saved)
    if not (saved and player and route and route.kind == "quest"
        and saved.mapID == player.mapID and not QuestComplete(saved.questID)
        and not (route.skippedQuests and route.skippedQuests[saved.questID])) then return nil end
    if C_QuestLog and type(C_QuestLog.IsOnQuest) == "function" then
        local ok, onQuest = pcall(C_QuestLog.IsOnQuest, saved.questID)
        if ok and not (issecretvalue and issecretvalue(onQuest)) and onQuest == false then
            return nil
        end
    end
    for _, quest in ipairs(quests) do
        if quest.questID == saved.questID then
            local current = QuestRouteItem(quest)
            if current.mapID == player.mapID and Valid(current)
                and (RouteID(current) == RouteID(saved)
                    or Distance(current.worldX, current.worldY, saved.worldX, saved.worldY) <= 8) then
                return current
            end
        end
    end
end

local function QuestProgress(questID)
    if not (questID and C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function") then return nil end
    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(objectives) ~= "table" or (issecretvalue and issecretvalue(objectives)) then return nil end
    local result, finishedState = {}, {}
    for index = 1, math.min(#objectives, 16) do
        local read, complete, count = pcall(function()
            return objectives[index].finished, objectives[index].numFulfilled
        end)
        if not read or (issecretvalue and (issecretvalue(complete) or issecretvalue(count))) then return nil end
        result[#result + 1] = (complete and "1" or "0") .. ":" .. tostring(Number(count) or 0)
        finishedState[#finishedState + 1] = complete and "1" or "0"
    end
    return table.concat(result, ","), table.concat(finishedState)
end

local function NewlyFinishedObjective(previous, current)
    if type(previous) ~= "string" or type(current) ~= "string" then return false end
    for index = 1, #current do
        if current:sub(index, index) == "1" and previous:sub(index, index) ~= "1" then
            return true
        end
    end
    return false
end

local function NextRouteStop()
    if not (route and player) then return nil end
    local kind = route.kind
    local best, bestCost, bestRank
    local bestWorldQuest, bestWorldQuestCost
    local inspected = 0
    local limit = (kind == "closest" or kind == "quest")
        and ROUTE_LIMIT * 3 or ROUTE_LIMIT
    local travelMode = TravelMode()
    local settings = addon.GetSettings()
    local questDone = {}
    local warbandDone = {}
    local trackingAccountQuests = kind == "closest"
        and Call(C_Minimap, "IsTrackingAccountCompletedQuests")
    local exploration = addon.VignetteRadarExploration
    local focusedQuestID = kind == "quest" and exploration
        and type(exploration.GetFocusedQuest) == "function"
        and exploration.GetFocusedQuest() or nil
    if route.manualQuestID and (Call(C_QuestLog, "IsQuestFlaggedCompleted", route.manualQuestID) == true
        or Call(C_QuestLog, "IsOnQuest", route.manualQuestID) == false) then
        route.manualQuestID = nil
    end
    if focusedQuestID and (Call(C_QuestLog, "IsQuestFlaggedCompleted", focusedQuestID) == true
        or Call(C_QuestLog, "IsOnQuest", focusedQuestID) == false) then
        focusedQuestID = nil
    end
    local selectedQuestID = route.manualQuestID or focusedQuestID
    local function Consider(item)
        if inspected >= limit then return end
        inspected = inspected + 1
        local itemKind = RouteKind(item)
        if not itemKind or (kind ~= "closest" and itemKind ~= kind)
            or not Valid(item)
            or (item.mapID ~= player.mapID and itemKind == "quest"
                and settings.vignetteRadarAutoRouteNearbyZones == false)
            or Visited(item) or (itemKind == "quest" and (
                route.skippedQuests and route.skippedQuests[item.questID]
                or selectedQuestID and item.questID ~= selectedQuestID
                or kind == "quest" and settings.vignetteRadarAutoRouteQuestNearest == false
                    and route.questID and item.questID ~= route.questID)) then return end
        if itemKind == "quest" then
            if kind == "closest" and HiddenWarbandQuestStart(item, trackingAccountQuests,
                warbandDone) then
                return
            end
            local complete = questDone[item.questID]
            if complete == nil then
                complete = QuestComplete(item.questID)
                questDone[item.questID] = complete
            end
            if complete and not item.availableStart then return end
        end
        if itemKind == "quest" and C_QuestLog and type(C_QuestLog.IsOnQuest) == "function" then
            local ok, onQuest = pcall(C_QuestLog.IsOnQuest, item.questID)
            if ok and not (issecretvalue and issecretvalue(onQuest))
                and ((item.availableStart and onQuest == true)
                    or (not item.availableStart and onQuest == false)) then return end
        end
        local recent = addon.VignetteRadarRecent
        if itemKind ~= "quest" and recent and type(recent.IsHidden) == "function"
            and recent.IsHidden(item) then return end
        local cost = RouteCost(item, travelMode, kind == "closest")
        if kind == "quest" and not selectedQuestID
            and settings.vignetteRadarWorldQuestPriority ~= false
            and item.taskType == "world" and item.mapID == player.mapID
            and Number(item.worldX) and Number(item.worldY)
            and Distance(player.worldX, player.worldY, item.worldX, item.worldY)
                <= (Number(settings.vignetteRadarWorldQuestPriorityRange) or 300)
            and (not bestWorldQuest or cost < bestWorldQuestCost) then
            bestWorldQuest, bestWorldQuestCost = item, cost
        end
        local rank = itemKind == "rare" and 1 or itemKind == "treasure" and 2
            or item.availableStart and 3.1 or 3
        local tied = bestCost and math.abs(cost - bestCost) <= (kind == "closest" and .5 or 0)
        if not best or (not tied and cost < bestCost)
            or (tied and (rank < bestRank or (rank == bestRank
                and (cost < bestCost or cost == bestCost
                    and tostring(RouteID(item)) < tostring(RouteID(best)))))) then
            best, bestCost, bestRank = item, cost, rank
        end
    end
    if kind == "quest" or kind == "closest" then
        for _, quest in ipairs(quests) do
            Consider(QuestRouteItem(quest))
        end
        local pool = addon.VignetteRadarRouteQuests
        if pool and type(pool.CurrentQuestWaypoint) == "function"
            and route.waiting and active and active.kind == "quest" and active.item
            and route.questID == active.item.questID
            and Call(C_QuestLog, "IsOnQuest", route.questID) == true then
            Consider(pool.CurrentQuestWaypoint(route.questID))
        end
        if settings.vignetteRadarAutoRouteQuestStarts ~= false then
            for _, start in ipairs(addon.VignetteRadarAvailableStarts or {}) do
                Consider(StartRouteItem(start))
            end
        end
        if pool and settings.vignetteRadarAutoRouteNearbyZones ~= false then
            for _, quest in ipairs(pool.Candidates()) do Consider(quest) end
        end
    end
    if kind ~= "quest" then
        local live = {}
        for _, target in ipairs(targets) do
            if (target.category == kind or kind == "closest"
                and (target.category == "rare" or target.category == "treasure"))
                and not target.stale and not target.sample then
                live[#live + 1] = { key = target.key, kind = target.category, name = target.name,
                    live = true, source = target.source,
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
                if RouteKind(note) == kind or kind == "closest"
                    and (RouteKind(note) == "rare" or RouteKind(note) == "treasure") then
                    local duplicate
                    if Number(note.worldX) and Number(note.worldY) then
                        for _, target in ipairs(live) do
                            if target.mapID == note.mapID
                                and RouteKind(target) == RouteKind(note)
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
    return bestWorldQuest or best
end

local function ArrivalRadius()
    local settings = addon.GetSettings()
    if (route and route.kind == "treasure") or (active and active.kind == "treasure") then
        return 3
    end
    return route and (settings.vignetteRadarAutoRouteArrivalRadius or 10)
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

local function RouteNote(label, message)
    if type(addon.ShowVignetteRadarRouteNote) == "function" then
        addon.ShowVignetteRadarRouteNote(label, message)
    end
end

local function Activate(item)
    lootSession = nil
    horizonCache = nil
    local steps = { item }
    if item.kind == "treasure" and addon.GetSettings().vignetteRadarWorldFocusRoutes
        and addon.GetSettings().vignetteRadarTreasurePlaybooks ~= false
        and type(item.route) == "table" and #item.route > 1 then steps = item.route end
    local ok, reason = Place(steps[1], item)
    if not ok then return false, reason end
    active = { key = item.key or item.questID or item.name, name = item.name or "Location",
        kind = item.kind, questID = item.questID, item = item, steps = steps, index = 1,
        wasOutside = false }
    if route and (route.kind == "closest" or route.kind == "quest") then
        route.questID = item.kind == "quest" and item.questID or nil
        if route.questID and not item.availableStart then
            route.progress, route.finished = QuestProgress(route.questID)
        else route.progress, route.finished = nil, nil end
    end
    ArmArrival()
    local detail = type(item.note) == "string" and item.note ~= "" and item.kind ~= "guide"
        and (" · " .. item.note) or ""
    RouteNote(item.kind == "guide" and "ZYGOR STEP" or route and "AUTO ROUTE" or "WORLD FOCUS",
        active.name .. (#steps > 1 and (" · 1/" .. #steps) or "") .. detail)
    return true
end

local function RecordQuestAdvance()
    if not (route and route.kind == "quest" and active) then return end
    route.previous = route.previous or {}
    RememberQuestStep(route.previous, active.item)
    route.forward = {}
end

local function AdvanceRoute(force)
    if not (route and active) then return false end
    if route.locked and not force then return false, "Current stop is locked" end
    RecordQuestAdvance()
    MarkVisited(active.item)
    local nextItem = NextRouteStop()
    if nextItem then
        route.waiting = false
        local ok, reason = Activate(nextItem)
        if not ok then route = nil end
        return ok, reason
    end
    if route.kind == "closest" then
        route.waiting, route.waitingTicks = true, 0
        RouteNote("AUTO ROUTE", "Closest is waiting for a nearby point")
        return true, "Waiting for a nearby point"
    end
    route.waiting = route.kind == "quest" and (route.questID ~= nil
        or addon.GetSettings().vignetteRadarAutoRouteNearbyZones ~= false
        or addon.GetSettings().vignetteRadarAutoRouteQuestStarts ~= false)
    if route.waiting then
        RouteNote("AUTO ROUTE", active.item.availableStart
            and "Waiting for the accepted quest objective"
            or "Waiting for the next quest location")
    else
        route = nil
        if API.Clear then API.Clear(true) else active = nil end
        RouteNote("AUTO ROUTE", "Route complete")
    end
    return false
end

local function Select(item, directPin)
    if not ((directPin or addon.GetSettings().vignetteRadarWorldFocusEnabled) and Valid(item)) then
        return false, "No usable location"
    end
    AttachKnownTreasurePath(item)
    local ok, reason = Activate(item)
    if not ok then return false, reason end
    if item.kind ~= "guide" and addon.VignetteRadarZygor then
        addon.VignetteRadarZygor.PauseForManual("Manual waypoint selected")
    end
    lastSelected = item
    route, pausedRoute = nil, nil
    local kind = RouteKind(item)
    if kind and addon.GetSettings().vignetteRadarAutoRouteOnSelect then
        local progress, finished
        if kind == "quest" then progress, finished = QuestProgress(item.questID) end
        route = { kind = kind, questID = kind == "quest" and item.questID or nil,
            manualQuestID = kind == "quest" and item.questID or nil,
            visited = {}, visitedPlaces = {}, waiting = false,
            progress = progress, finished = finished }
    end
    ArmArrival()
    return true
end

function API.ToggleRoute()
    if route then
        pausedRoute, route = route, nil
        RouteNote("AUTO ROUTE", "Paused · " .. (active and active.name or "Waypoint kept"))
        return false, "Auto Route paused; waypoint kept"
    end
    if pausedRoute then
        if not (active and active.steps[active.index]
            and SameWaypoint(active.steps[active.index])) then
            pausedRoute = nil
            return false, "Route waypoint changed; choose a point to start again"
        end
        route, pausedRoute = pausedRoute, nil
        ArmArrival()
        RouteNote("AUTO ROUTE", "Resumed · " .. (active and active.name or "Current waypoint"))
        return true, "Auto Route resumed"
    end
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
    local progress, finished
    if kind == "quest" then progress, finished = QuestProgress(item.questID) end
    route = { kind = kind, questID = kind == "quest" and item.questID or nil,
        manualQuestID = kind == "quest" and item.questID or nil,
        visited = {}, visitedPlaces = {}, waiting = false,
        progress = progress, finished = finished }
    ArmArrival()
    RouteNote("AUTO ROUTE", "Started · " .. (active and active.name or item.name or kind))
    return true, "Auto Route: " .. kind
end

function API.IsRouteActive() return route ~= nil end
function API.IsRoutePaused() return pausedRoute ~= nil end
function API.IsRouteLocked() return (route or pausedRoute) and (route or pausedRoute).locked == true or false end
function API.ToggleRouteLock()
    local current = route or pausedRoute
    if not (current and active) then return false, "Start an Auto Route first" end
    current.locked = not current.locked
    RouteNote("AUTO ROUTE", current.locked and "Current stop locked" or "Current stop unlocked")
    return true, current.locked
end
function API.IsQuestRoute() return route and route.kind == "quest" or false end
function API.WantsQuestPool()
    return route and (route.kind == "quest" or route.kind == "closest") or false
end
function API.GetRouteChoice()
    if route then return route.kind, "active" end
    if pausedRoute then return pausedRoute.kind, "paused" end
    if active then
        if active.kind == "guide" then return "zygor", "focus" end
        return RouteKind(active.item), "focus"
    end
end
function API.HasFocus() return active ~= nil end
function API.GetFocusedStep()
    return active and active.steps[active.index] or nil
end

function API.GetRoutePoint()
    if not (route and not route.waiting and active) then return nil end
    return active.steps[active.index], route.kind == "closest"
        and RouteKind(active.item) or route.kind, active.name,
        active.index, #active.steps
end
function API.GetTrackedRouteKind()
    local current = route or pausedRoute
    if not active or current and current.waiting then return nil end
    return active.kind == "guide" and "zygor" or RouteKind(active.item)
end

function API.ExplainActive()
    if not (active and active.item) then return "No active destination" end
    local item = active.item
    local source = item.kind == "quest" and (item.nextStep and "Blizzard next step" or "Blizzard quest point")
        or item.kind == "guide" and "Zygor guide"
        or item.live and (item.source == "worldMap" and "Blizzard world map" or "Live vignette")
        or item.source and ("Saved map note · " .. item.source) or "Selected location"
    local rule = item.availableStart and "advances when the quest is accepted"
        or item.kind == "quest" and "advances on objective progress"
        or item.kind == "treasure" and "advances at 3 yd or on matching loot"
        or item.kind == "rare" and "advances when cleared or skipped"
        or "follows its guide step"
    return source .. " · " .. rule
end

function API.GetHorizon()
    if not (route and active and player) then return {} end
    local now = type(GetTime) == "function" and GetTime() or 0
    if horizonCache and now >= (horizonCachedAt or 0)
        and now - (horizonCachedAt or 0) < 3 then return horizonCache end
    local result = {}
    if not route.waiting then
        result[1] = { name = active.name, kind = RouteKind(active.item) or active.kind,
            item = active.item, current = true }
    end
    local original = route
    local previewRoute = { kind = original.kind, questID = original.questID,
        skippedQuests = original.skippedQuests, visited = {}, visitedPlaces = {} }
    for id, seen in pairs(original.visited or {}) do previewRoute.visited[id] = seen end
    for index, place in ipairs(original.visitedPlaces or {}) do
        previewRoute.visitedPlaces[index] = place
    end
    route = previewRoute
    local ok = pcall(function()
        if not original.waiting then MarkVisited(active.item) end
        for _ = #result + 1, 3 do
            local nextItem = NextRouteStop()
            if not nextItem then break end
            result[#result + 1] = { name = nextItem.name, kind = RouteKind(nextItem),
                item = nextItem, current = false }
            MarkVisited(nextItem)
        end
    end)
    route = original
    if not ok then return result end
    horizonCache, horizonCachedAt = result, now
    return result
end

function API.OwnsGuideWaypoint()
    return active and active.kind == "guide" and active.steps[active.index]
        and SameWaypoint(active.steps[active.index]) or false
end

function API.Clear(silent)
    horizonCache = nil
    if not active then return false, "No focused waypoint" end
    local name = active.name
    local step = active.steps[active.index]
    if step and SameWaypoint(step) then
        if not (C_Map and type(C_Map.ClearUserWaypoint) == "function") then
            return false, "Waypoint removal is unavailable"
        end
        if type(InCombatLockdown) == "function" then
            local checked, locked = pcall(InCombatLockdown)
            if not checked or (issecretvalue and issecretvalue(locked)) or locked then
                return false, "Leave combat to clear the waypoint"
            end
        end
        local cleared = pcall(C_Map.ClearUserWaypoint)
        if not cleared then return false, "Waypoint could not be cleared" end
    end
    if active.kind == "guide" and addon.VignetteRadarZygor then
        addon.VignetteRadarZygor.PauseForManual("Guide waypoint cleared")
    end
    active, route, pausedRoute, lastSelected, lootSession = nil, nil, nil, nil, nil
    if addon.VignetteRadarWaypointStability then
        addon.VignetteRadarWaypointStability.Disable()
    end
    if not silent then RouteNote("WORLD FOCUS", "Cleared · " .. (name or "Waypoint")) end
    return true
end

function API.StartNearest(kind)
    if kind ~= "rare" and kind ~= "treasure" and kind ~= "quest"
        and kind ~= "closest" then
        return false, "Choose Closest, Rare, Treasure, or Quest"
    end
    if kind == "closest" or kind == "quest" or kind == "rare"
        or kind == "treasure" then
        if not addon.GetSettings().vignetteRadarWorldFocusEnabled or not player then
            return false, "World Focus is unavailable"
        end
        if not (Number(player.worldX) and Number(player.worldY)) then
            return false, "Player location is unavailable"
        end
        local pool = addon.VignetteRadarRouteQuests
        if (kind == "closest" or kind == "quest") and pool and pool.Tick then
            pool.Tick(true)
        end
        local previous = route
        route = { kind = kind, visited = {}, visitedPlaces = {}, waiting = false }
        local nearest = NextRouteStop()
        route = previous
        if not nearest then return false,
            kind == "quest" and "No Quest Objective or Available Start Found Yet"
            or kind == "treasure" and "No Eligible Treasure in Live or Selected Map Data"
            or kind == "rare" and "No Eligible Rare in Live or Selected Map Data"
            or "No Rare, Treasure, or Quest Point Found Yet" end
        route = nil
        local ok, reason = Select(nearest)
        if not ok then route = previous; return false, reason end
        route = { kind = kind, visited = {}, visitedPlaces = {}, waiting = false }
        if nearest.kind == "quest" then
            route.questID = nearest.questID
            if not nearest.availableStart then
                route.progress, route.finished = QuestProgress(nearest.questID)
            end
        end
        ArmArrival()
        RouteNote("AUTO ROUTE", (kind == "quest" and "Quest" or kind == "rare" and "Rare"
            or kind == "treasure" and "Treasure" or "Closest")
            .. " · " .. (active and active.name or nearest.name or "Point"))
        return true, nearest
    end
end

function API.SkipRouteStop()
    if not (route and active) then return false, "No active route" end
    return AdvanceRoute(true)
end

function API.SkipQuest()
    if not (route and route.kind == "quest" and route.questID) then
        return false, "No active quest route"
    end
    route.skippedQuests = route.skippedQuests or {}
    route.skippedQuests[route.questID] = true
    route.questID, route.progress, route.finished, route.waiting = nil, nil, nil, false
    local advanced, reason = AdvanceRoute(true)
    return advanced or not route, reason or "Quest skipped"
end

function API.PreviousQuestStep()
    if not (route and route.kind == "quest" and active) then
        return false, "Start a quest Auto Route first"
    end
    route.previous = route.previous or {}
    while #route.previous > 0 do
        local point = AvailableQuestStep(route.previous[#route.previous])
        if point then
            local current = not route.waiting and active.item or nil
            local ok, reason = Activate(point)
            if not ok then return false, reason end
            table.remove(route.previous)
            route.forward = route.forward or {}
            RememberQuestStep(route.forward, current)
            route.questID, route.waiting = point.questID, false
            RouteNote("QUEST ROUTE", "Previous · " .. (point.name or "Quest point"))
            return true, point
        end
        table.remove(route.previous)
    end
    return false, "No previous quest point is still available"
end

function API.NextQuestStep()
    if not (route and route.kind == "quest" and active) then
        return false, "Start a quest Auto Route first"
    end
    route.forward = route.forward or {}
    while #route.forward > 0 do
        local point = AvailableQuestStep(route.forward[#route.forward])
        if point then
            local current = not route.waiting and active.item or nil
            local ok, reason = Activate(point)
            if not ok then return false, reason end
            table.remove(route.forward)
            route.previous = route.previous or {}
            RememberQuestStep(route.previous, current)
            route.questID, route.waiting = point.questID, false
            RouteNote("QUEST ROUTE", "Next · " .. (point.name or "Quest point"))
            return true, point
        end
        table.remove(route.forward)
    end
    if route.waiting then
        local point = NextRouteStop()
        if not point then return false, "Waiting for the next quest point" end
        local ok, reason = Activate(point)
        if ok then route.waiting = false end
        return ok, reason
    end
    local ok, reason = AdvanceRoute(true)
    return ok, reason or (not ok and "Waiting for the next quest point")
end

function API.SelectTarget(target)
    if not target or target.stale or target.sample then return false, "No live target" end
    return Select({ key = target.key, name = target.name, kind = target.category,
        live = true, source = target.source,
        isWorldBoss = target.isWorldBoss, rewardQuestID = target.rewardQuestID,
        npcID = target.npcID, objectGUID = target.objectGUID,
        objectID = target.objectID, isDead = target.isDead,
        mapID = target.mapID, mapX = target.mapX, mapY = target.mapY,
        worldX = target.worldX, worldY = target.worldY, instanceID = target.instanceID })
end

function API.SelectQuest(questID)
    local nearest, nearestDistance, nearestOnMap
    for _, quest in ipairs(quests) do
        if quest.questID == questID and Number(quest.worldX) and Number(quest.worldY) then
            local onMap = player and quest.mapID == player.mapID or false
            local distance = onMap and Number(player.worldX) and Number(player.worldY)
                and Distance(player.worldX, player.worldY, quest.worldX, quest.worldY)
                or math.huge
            if not nearest or (onMap and not nearestOnMap)
                or (onMap == nearestOnMap and distance < nearestDistance) then
                nearest, nearestDistance, nearestOnMap = quest, distance, onMap
            end
        end
    end
    if nearest then
        return Select({ key = "quest:" .. questID, questID = questID,
            name = nearest.name, kind = "quest", colorSlot = nearest.colorSlot,
            nextStep = nearest.nextStep,
            mapID = nearest.mapID, mapX = nearest.mapX, mapY = nearest.mapY,
            worldX = nearest.worldX, worldY = nearest.worldY,
            instanceID = nearest.instanceID })
    end
    return false, "Quest point unavailable"
end

function API.SelectNote(note, directPin)
    if not note then return false, "No map note" end
    if note.kind == "entrance" and note.parentCoord and type(note.source) == "string" then
        for _, candidate in ipairs(notes) do
            if candidate.kind == "treasure" and candidate.mapID == note.mapID
                and candidate.key == note.source .. ":" .. note.mapID .. ":" .. note.parentCoord then
                return Select(candidate, directPin)
            end
        end
    end
    return Select(note, directPin)
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
    if not (player and Number(player.worldX) and Number(player.worldY)) then return end
    local db = addon.GetSettings()
    local function Add(item, priority)
        if #candidates >= 128 or not Valid(item)
            or not (Number(item.worldX) and Number(item.worldY)) then return end
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
            name = quest.name, kind = "quest", mapID = quest.mapID or player.mapID,
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
                    if target.focusPriority == 1 and note.mapID == target.mapID
                        and Number(note.worldX) and Number(note.worldY)
                        and ((note.kind == "mob" and target.kind == "rare")
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
    else
        candidates = {}
        if not (active and active.kind == "guide" and addon.VignetteRadarZygor
            and addon.VignetteRadarZygor.IsFollowing()) then
            active, route, pausedRoute = nil, nil, nil
        end
    end
    if not (active and player) then
        if addon.VignetteRadarWaypointStability then
            addon.VignetteRadarWaypointStability.Disable()
        end
        return
    end
    local step = active.steps[active.index]
    if not step or not SameWaypoint(step) then
        if active.kind == "guide" and addon.VignetteRadarZygor then
            addon.VignetteRadarZygor.PauseForManual("Waypoint changed outside the radar")
        end
        active, route, pausedRoute = nil, nil, nil
        if addon.VignetteRadarWaypointStability then
            addon.VignetteRadarWaypointStability.Disable()
        end
        return
    end
    if route and route.kind == "closest" and active.item
        and HiddenWarbandQuestStart(active.item,
            Call(C_Minimap, "IsTrackingAccountCompletedQuests")) then
        local nextItem = NextRouteStop()
        if nextItem then
            local ok = Activate(nextItem)
            if not ok then API.Clear(true) end
        else API.Clear(true) end
        return
    end
    local stability = addon.VignetteRadarWaypointStability
    if stability then
        local smooth = addon.GetSettings().vignetteRadarWorldFocusSmoothWaypoint
            and addon.GetSettings().vignetteRadarWorldFocusThemedWaypoint
            and _G.WaypointUIAPI and _G.WaypointUIAPI.Navigation
            and not (addon.VignetteRadarBudget and addon.VignetteRadarBudget.paused
                and (addon.VignetteRadarBudget.paused.radar
                    or addon.VignetteRadarBudget.paused.background))
        if smooth and not stability.IsEnabled() then stability.Enable()
        elseif not smooth then stability.Disable() end
    end
    if not (Number(player.worldX) and Number(player.worldY)) then return end
    if route and route.locked then return end
    if route and route.kind == "closest" and route.waiting then
        -- A waiting mixed route stays armed, but retries only on every second
        -- data scan. An empty zone should stay cheap while new points appear.
        route.waitingTicks = (route.waitingTicks or 0) + 1
        if route.waitingTicks >= 2 then
            route.waitingTicks = 0
            local nextItem = NextRouteStop()
            if nextItem then
                local ok = Activate(nextItem)
                if ok then route.waiting = false end
            end
        end
        return
    end
    if route and active.kind ~= "quest" and addon.VignetteRadarRecent
        and addon.VignetteRadarRecent.IsHidden(active.item)
        and (active.kind ~= "rare" or Number(step.worldX) and Number(step.worldY)
            and Distance(player.worldX, player.worldY,
                step.worldX, step.worldY) <= ArrivalRadius()) then
        AdvanceRoute()
        return
    end
    if route and active.kind == "quest"
        and (route.kind == "quest" or route.kind == "closest") then
        if active.item.availableStart then
            local onQuest = Call(C_QuestLog, "IsOnQuest", active.item.questID)
            if onQuest == true and not route.waiting then AdvanceRoute(); return end
            if route.waiting then
                local nextItem = NextRouteStop()
                if nextItem then route.waiting = false; Activate(nextItem) end
            end
            return
        end
        if QuestComplete(route.questID) then
            route.questID, route.progress, route.finished = nil, nil, nil
            AdvanceRoute()
            return
        end
        local progress, finished = QuestProgress(route.questID)
        if NewlyFinishedObjective(route.finished, finished) then
            route.progress, route.finished = progress, finished
            if route.kind == "closest"
                or addon.GetSettings().vignetteRadarAutoRouteQuestNearest ~= false then
                AdvanceRoute(); return
            end
            RecordQuestAdvance()
            MarkVisited(active.item)
            route.waiting = true
            RouteNote("AUTO ROUTE", "Waiting for the next quest objective")
        else
            route.progress = progress or route.progress
            route.finished = finished or route.finished
        end
        if route.waiting then
            local nextItem = NextRouteStop()
            if nextItem then route.waiting = false; Activate(nextItem) end
            return
        end
    end
    -- Zygor follow is driven by guide messages, never by the ordinary scan.
    if active.kind == "guide" then return end
    if not (Number(step.worldX) and Number(step.worldY)
        and Number(player.worldX) and Number(player.worldY)) then return end
    if pausedRoute or (not route and not addon.GetSettings().vignetteRadarWorldFocusAutoAdvance) then return end
    if active.kind == "quest" then return end -- Quest points wait for objective or quest progress.
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
        if ok then
            active.index, active.wasOutside = active.index + 1, false
            RouteNote("NEXT STEP", active.name .. " · " .. active.index .. "/" .. #active.steps)
        end
    elseif route and active.kind == "rare" then
        -- Reaching a rare is not completing it. Keep the current target while
        -- the player fights; a recorded kill/clear or Skip Stop advances it.
        return
    elseif route then AdvanceRoute()
    else
        RouteNote("ARRIVED", active.name)
        active = nil
    end
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
    local step = active and active.steps[active.index]
    local distance = step and player and Number(step.worldX) and Number(step.worldY)
        and Number(player.worldX) and Number(player.worldY)
        and math.floor(Distance(player.worldX, player.worldY,
            step.worldX, step.worldY) + .5)
    local prefix = distance and not (route and route.waiting)
        and distance .. " yd · " or ""
    if route then
        local kind = route.kind == "rare" and "Rare" or route.kind == "treasure"
            and "Treasure" or route.kind == "closest" and "Closest" or "Quest"
        return prefix .. "Auto Route · " .. kind .. (route.locked and " · Locked" or "") .. " · " .. (route.waiting
            and (active and active.item and active.item.availableStart
                and "Waiting for Accepted Quest Objective"
                or route.kind == "closest" and "Waiting for Nearby Points"
                or "Waiting for Next Quest")
            or active and active.name or "Choosing Next Stop")
    end
    if pausedRoute then return prefix .. "Auto Route paused · " .. (active and active.name or "Waypoint kept") end
    if active then return prefix .. active.name .. "  ·  " .. active.index .. "/" .. #active.steps end
    return #candidates .. " possible focus points"
end

-- A read-only snapshot for explicit troubleshooting; no quest or map APIs run here.
function API.Diagnostics()
    local current = route or pausedRoute
    local visited = 0
    for _ in pairs(current and current.visited or {}) do visited = visited + 1 end
    return { mode = current and current.kind or "off",
        state = route and (route.waiting and "waiting" or "active")
            or pausedRoute and "paused" or "off",
        questID = active and active.item and active.item.questID,
        radarPoints = #quests, availableStarts = #(addon.VignetteRadarAvailableStarts or {}),
        visited = visited }
end

function API.Advance()
    if not active or active.index >= #active.steps then return false end
    if not SameWaypoint(active.steps[active.index]) then active, route = nil, nil; return false end
    local nextStep = active.steps[active.index + 1]
    local ok = Place(nextStep, active.item)
    if ok then
        active.index, active.wasOutside = active.index + 1, false
        RouteNote("NEXT STEP", active.name .. " · " .. active.index .. "/" .. #active.steps)
    end
    return ok
end

local function LootLocation()
    local snapshot = player
    local radar = addon.VignetteRadarAPI
    if radar and type(radar.GetPlayerSnapshot) == "function" then
        local ok, current = pcall(radar.GetPlayerSnapshot)
        if ok and type(current) == "table" then snapshot = current end
    end
    if not (snapshot and active and active.item and Number(snapshot.worldX)
        and Number(snapshot.worldY) and Number(active.item.worldX)
        and Number(active.item.worldY)) then return nil end
    if Number(snapshot.instanceID) and Number(active.item.instanceID)
        and snapshot.instanceID ~= active.item.instanceID then return nil end
    return Distance(snapshot.worldX, snapshot.worldY,
        active.item.worldX, active.item.worldY)
end

local function LootSourceMatch(item)
    if type(GetNumLootItems) ~= "function" or type(GetLootSourceInfo) ~= "function" then
        return "unknown"
    end
    local ok, slots = pcall(GetNumLootItems)
    if not ok or not Number(slots) then return "unknown" end
    local gameObject, creature, exact = false, false, false
    for slot = 1, math.min(slots, 32) do
        local read, guid = pcall(GetLootSourceInfo, slot)
        if read and type(guid) == "string"
            and not (issecretvalue and issecretvalue(guid)) then
            if guid:find("^GameObject%-") then
                gameObject = true
                local objectID = tonumber(guid:match(
                    "^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
                if (item.objectGUID and guid == item.objectGUID)
                    or (Number(item.objectID) and objectID == item.objectID) then
                    exact = true
                end
            elseif guid:find("^Creature%-") or guid:find("^Vehicle%-") then
                creature = true
            end
        end
    end
    if exact then return "exact" end
    if gameObject and (item.objectGUID or Number(item.objectID)) then return "wrong-object" end
    if gameObject then return "gameobject" end
    if creature then return "creature" end
    return "unknown"
end

function API.OnLootEvent(event)
    if event == "LOOT_CLOSED" then lootSession = nil; return false end
    if route and route.locked then return false end
    if event == "LOOT_OPENED" then
        lootSession = nil
        if not (route and route.kind == "treasure" and active
            and active.kind == "treasure" and active.item
            and active.steps[active.index]
            and SameWaypoint(active.steps[active.index])) then return false end
        local source = LootSourceMatch(active.item)
        local radius = source == "exact" and 50
            or source == "gameobject" and 18 or source == "unknown" and 8 or 0
        local distance = LootLocation()
        if not (distance and distance <= radius) then return false end
        lootSession = { key = active.key, at = type(GetTime) == "function" and GetTime() or 0,
            radius = radius }
        return false
    end
    if event ~= "LOOT_SLOT_CLEARED" or not lootSession then return false end
    local session = lootSession
    lootSession = nil
    if not (route and route.kind == "treasure" and active and active.key == session.key
        and active.steps[active.index]
        and SameWaypoint(active.steps[active.index])) then return false end
    local now = type(GetTime) == "function" and GetTime() or 0
    local distance = LootLocation()
    if now < session.at or now - session.at > 5
        or not (distance and distance <= session.radius) then return false end
    if addon.VignetteRadarRecent and addon.VignetteRadarRecent.HideNote then
        addon.VignetteRadarRecent.HideNote(active.item)
    end
    AdvanceRoute()
    return true
end

local function ZygorPoint(source, step)
    if type(source) ~= "table" then return nil end
    local pointMapID = Number(source.map) or Number(source.m) or Number(step and step.map)
    local x, y = Number(source.x), Number(source.y)
    if not (pointMapID and x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1) then
        return nil
    end
    return { m = pointMapID, x = x, y = y, title = source.title or source.text }
end

local function ZygorGoalPoint(goal, step, directPin)
    if not goal or goal.force_noway or goal.action == "mapmarker" then return nil end
    local point
    if directPin and type(goal.GetWaypoint) == "function" then
        local ok, native = pcall(goal.GetWaypoint, goal)
        if ok then point = ZygorPoint(native, step) end
    end
    point = point or ZygorPoint(goal, step)
    if not point then return nil end
    if type(goal.IsVisible) == "function" then
        local ok, visible = pcall(goal.IsVisible, goal)
        if not ok or visible == false or (issecretvalue and issecretvalue(visible)) then
            return nil
        end
    end
    if directPin and type(goal.GetText) == "function" then
        local ok, title = pcall(goal.GetText, goal, false, true, false, true)
        if ok and type(title) == "string" and title ~= "" then point.title = title end
    end
    return point
end

local function ZygorGoalComplete(goal)
    if not goal then return false end
    if type(goal.IsComplete) == "function" then
        local ok, done = pcall(goal.IsComplete, goal)
        if ok and type(done) == "boolean" then return done end
    end
    return goal.status == "complete"
end

local function ZygorTravelPoint(step, mapToWorld, mapVector)
    local coords = step and step.waypath and step.waypath.coords
    if type(coords) ~= "table" then return nil end
    local nearest, nearestDistance, count
    count = math.min(#coords, 64)
    for index = 1, count do
        local point = ZygorPoint(coords[index], step)
        if point then
            if not nearest then nearest = index end
            if player and Number(player.worldX) and Number(player.worldY) then
                local ok, x, y, instanceID = pcall(mapToWorld, point.m,
                    mapVector(point.x, point.y))
                if ok and Number(x) and Number(y)
                    and (not Number(instanceID) or not Number(player.instanceID)
                        or instanceID == player.instanceID) then
                    local distance = (x - player.worldX)^2 + (y - player.worldY)^2
                    if not nearestDistance or distance < nearestDistance then
                        nearest, nearestDistance = index, distance
                    end
                end
            end
        end
    end
    if not nearest then return nil end
    if nearestDistance and nearestDistance <= 20^2 then
        for index = nearest + 1, count do
            local nextPoint = ZygorPoint(coords[index], step)
            if nextPoint then return nextPoint, index, count end
        end
    end
    return ZygorPoint(coords[nearest], step), nearest, count
end

function API.ZygorNote(mapID, mapToWorld, mapVector, allowHidden, allowRemote, mode, goalIndex)
    if not allowHidden and addon.GetSettings().vignetteRadarWorldFocusZygor ~= true then return nil end
    local zgv = _G.ZygorGuidesViewer
    if not zgv then return nil, "Zygor is not loaded" end
    local read, step, pointer = pcall(function() return zgv.CurrentStep, zgv.Pointer end)
    if not read or not step then return nil, "Zygor has no active guide step" end

    -- Zygor's arrow can point at a travel hop or a manual POI. Read the
    -- selected objective from the active guide step instead.
    local selected, waypoint
    local goals = type(step.goals) == "table" and step.goals or nil
    if goals and mode ~= "travel" then
        local anyIncomplete = false
        local goalNum = Number(goalIndex) or Number(step.current_waypoint_goal_num)
        if goalNum and goalNum >= 1 and goalNum <= 64 then
            selected = goals[goalNum]
            if goalIndex or not ZygorGoalComplete(selected) then
                waypoint = ZygorGoalPoint(selected, step, allowRemote)
            end
        end
        if goalIndex and not waypoint then return nil, "That Zygor objective has no mapped location" end
        if not waypoint then
            for index = 1, math.min(#goals, 64) do
                local goal = goals[index]
                if goal and not ZygorGoalComplete(goal) then
                    anyIncomplete = true
                    waypoint = ZygorGoalPoint(goal, step, allowRemote)
                    if waypoint then selected = goal; break end
                end
            end
        end
        if not waypoint and not goalIndex and #goals > 0 and not anyIncomplete then
            for index = 1, math.min(#goals, 64) do
                if goals[index] and not ZygorGoalComplete(goals[index]) then
                    anyIncomplete = true
                    break
                end
            end
            if not anyIncomplete then
                return nil, "Waiting for Zygor's next guide step"
            end
        end
    end
    local travelIndex, travelCount
    if not waypoint or mode == "travel" then
        waypoint, travelIndex, travelCount = ZygorTravelPoint(step, mapToWorld, mapVector)
    end
    if mode == "travel" and not waypoint then
        return nil, "Current Zygor step has no mapped travel stop"
    end
    if not waypoint and pointer then
        local possible = { pointer.DestinationWaypoint, pointer.current_waypoint,
            pointer.ArrowFrame and pointer.ArrowFrame.waypoint }
        for index = 1, 3 do
            local candidate = possible[index]
            if candidate and candidate.goal and candidate.goal.parentStep == step then
                waypoint = ZygorPoint(candidate, step)
                if waypoint then selected = candidate.goal; break end
            end
        end
    end
    if not waypoint then return nil, "Current Zygor step has no mapped location" end
    if not allowRemote and waypoint.m ~= mapID then return nil end
    local converted, worldX, worldY, instanceID = pcall(mapToWorld, waypoint.m,
        mapVector(waypoint.x, waypoint.y))
    if not converted or not Number(worldX) or not Number(worldY) then
        if not allowRemote then return nil end
        worldX, worldY, instanceID = nil, nil, nil
    end
    local stepNum = Number(step.num)
    local title = waypoint.title
    if mode == "travel" then
        title = "Travel Stop " .. tostring(travelIndex or 1) .. "/" .. tostring(travelCount or 1)
    end
    if type(title) ~= "string" or title == "" then
        title = "Zygor Step " .. tostring(stepNum or "?")
    end
    return { key = "zygor:" .. tostring(stepNum or 0) .. ":" .. waypoint.m
        .. ":" .. math.floor(waypoint.x * 10000) .. ":" .. math.floor(waypoint.y * 10000),
        kind = "guide", source = "Zygor", name = title, mapID = waypoint.m,
        mapX = waypoint.x, mapY = waypoint.y, worldX = worldX, worldY = worldY,
        instanceID = instanceID, stepNumber = stepNum,
        travelIndex = travelIndex, travelCount = travelCount,
        goalNumber = selected and (Number(selected.num) or Number(goalIndex)
            or Number(step.current_waypoint_goal_num)) or nil,
        goalCount = goals and #goals or 0,
        note = selected and "Selected Zygor guide objective"
            or "Current Zygor guide path" }
end
