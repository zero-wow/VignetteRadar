local addon = {}
local settings = {
    vignetteRadarWorldFocusEnabled = true,
    vignetteRadarWorldFocusAutoAdvance = true,
    vignetteRadarWorldFocusRoutes = true,
    vignetteRadarWorldFocusSavedNotes = true,
    vignetteRadarWorldFocusZygor = true,
    vignetteRadarWorldFocusArrivalRadius = 20,
    vignetteRadarAutoRouteArrivalRadius = 10,
    vignetteRadarAutoRouteMapNotes = true,
}
addon.GetSettings = function() return settings end
local routeNotes = {}
addon.ShowVignetteRadarRouteNote = function(label, message)
    routeNotes[#routeNotes + 1] = { label, message }
end
local waypoint, placed = nil, {}
UiMapPoint = { CreateFromCoordinates = function(mapID, x, y)
    return { uiMapID = mapID, position = { x = x, y = y } }
end }
C_Map = {
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function(point)
        waypoint = point
        placed[#placed + 1] = point.position.x
        return true
    end,
    GetUserWaypoint = function() return waypoint end,
    ClearUserWaypoint = function() waypoint = nil end,
}
C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
assert(loadfile("VignetteRadar_WorldFocus.lua"))("VignetteRadar", addon)
local focus = addon.VignetteRadarWorldFocus
local function Step(x)
    return { mapID = 123, mapX = x / 1000, mapY = .5,
        worldX = x, worldY = 500, instanceID = 42 }
end
local treasure = Step(500)
treasure.kind, treasure.name, treasure.key = "treasure", "Hidden cache", "pack:123:50005000"
treasure.route = { Step(400), Step(450), Step(500) }
local entrance = Step(400)
entrance.kind, entrance.parentCoord, entrance.source = "entrance", 50005000, "pack"
local player = { worldX = 300, worldY = 500, instanceID = 42 }
focus.Sync(123, player, {}, {}, { treasure, entrance })
assert(focus.SelectNote(entrance) and placed[1] == .4
    and focus.Status():find("100 yd", 1, true)
    and focus.Status():find("1/3", 1, true),
    "clicking a linked entrance should begin the parent treasure's complete path")
assert(routeNotes[#routeNotes][1] == "WORLD FOCUS"
    and routeNotes[#routeNotes][2]:find("Hidden cache", 1, true),
    "focusing a mapped route should announce its destination")
player.worldX = 396.9
focus.Sync(123, player, {}, {}, { treasure, entrance })
assert(#placed == 1,
    "a linked treasure path must wait until the player is within 3 yards of its stop")
player.worldX = 397.1
focus.Sync(123, player, {}, {}, { treasure, entrance })
assert(placed[2] == .45 and focus.Status():find("2/3", 1, true),
    "entering 3 yards should advance exactly one explicitly supplied treasure-path step")
assert(routeNotes[#routeNotes][1] == "NEXT STEP"
    and routeNotes[#routeNotes][2]:find("2/3", 1, true),
    "route notes should describe automatic step changes")
player.worldX = 410
local routeNoteCount = #routeNotes
focus.Sync(123, player, {}, {}, { treasure, entrance })
assert(#placed == 2 and #routeNotes == routeNoteCount,
    "remaining inside the arrival radius must not skip stops or repeat the note")
player.worldX = 450
focus.Sync(123, player, {}, {}, { treasure, entrance })
assert(placed[3] == .5 and focus.Status():find("3/3", 1, true),
    "the final waypoint must point at the treasure")

focus.SelectNote(treasure)
assert(placed[4] == .4)
waypoint = UiMapPoint.CreateFromCoordinates(123, .9, .9)
player.worldX = 400
focus.Sync(123, player, {}, {}, { treasure, entrance })
assert(#placed == 4 and not focus.Status():find("/3", 1, true),
    "a manually changed waypoint must stop automatic route ownership")

local rareA, rareB, rareNote = Step(600), Step(800), Step(900)
rareA.kind, rareA.key, rareA.name = "rare", "live:600", "First rare"
rareB.kind, rareB.key, rareB.name = "rare", "live:800", "Second rare"
rareA.category, rareB.category = "rare", "rare"
rareNote.kind, rareNote.key, rareNote.name = "mob", "pack:900", "Saved rare"
player.worldX = 300
focus.Sync(123, player, { rareA, rareB }, {}, { rareNote })
assert(focus.SelectTarget({ key = rareA.key, name = rareA.name, category = rareA.kind,
    mapID = rareA.mapID, mapX = rareA.mapX, mapY = rareA.mapY,
    worldX = rareA.worldX, worldY = rareA.worldY, instanceID = rareA.instanceID }))
local focusedKind, focusedState = focus.GetRouteChoice()
assert(focusedKind == "rare" and focusedState == "focus",
    "a manually focused point should identify its category before Auto Route starts")
assert(focus.ToggleRoute() and focus.IsRouteActive(), "route button should use the last clicked rare")
local chosenKind, chosenState = focus.GetRouteChoice()
assert(chosenKind == "rare" and chosenState == "active",
    "the route chooser should identify the active route category")
local routePoint, routeKind = focus.GetRoutePoint()
assert(routePoint and routePoint.worldX == 600 and routeKind == "rare",
    "the route arrow should receive the current stop and route category")
local pauseOk, pauseReason = focus.ToggleRoute()
assert(not pauseOk and pauseReason:find("paused", 1, true)
    and focus.IsRoutePaused() and not focus.IsRouteActive()
    and focus.Status():find("paused", 1, true)
    and focus.GetRoutePoint() == nil,
    "pausing should keep the route's visited state and explain its status")
assert(routeNotes[#routeNotes][2]:find("Paused", 1, true),
    "pausing should show a brief route note")
chosenKind, chosenState = focus.GetRouteChoice()
assert(chosenKind == "rare" and chosenState == "paused",
    "the route chooser should retain a visible choice while the route is paused")
player.worldX = 600
focus.Sync(123, player, { rareA, rareB }, {}, { rareNote })
assert(waypoint.position.x == .6 and focus.IsRoutePaused(),
    "arriving while paused must not advance through a waypoint")
player.worldX = 300
focus.Sync(123, player, { rareA, rareB }, {}, { rareNote })
assert(focus.ToggleRoute() and focus.IsRouteActive() and not focus.IsRoutePaused(),
    "resuming should continue the paused route")
focus.Sync(123, { worldX = nil, worldY = nil, instanceID = 42 }, { rareA, rareB }, {}, {})
focus.Sync(123, player, { rareA, rareB }, {}, { rareNote })
player.worldX = 589.9
focus.Sync(123, player, { rareA, rareB }, {}, { rareNote })
assert(waypoint.position.x == .6,
    "the current map pin must remain until Auto Route is within 10 yards")
player.worldX = 590.1
focus.Sync(123, player, { rareA, rareB }, {}, { rareNote })
assert(waypoint.position.x == .8, "Auto Route should advance after entering 10 yards")
player.worldX = 800
focus.Sync(123, player, { rareA, rareB }, {}, { rareNote })
assert(waypoint.position.x == .9, "rare route should continue into the selected map pack")
waypoint = UiMapPoint.CreateFromCoordinates(123, .97, .5)
focus.Sync(123, player, { rareA, rareB }, {}, { rareNote })
assert(not focus.IsRouteActive(), "a manually replaced waypoint must stop Auto Route")

local questA, questNext, questB = Step(350), Step(500), Step(700)
questA.questID, questNext.questID, questB.questID = 11, 11, 22
questA.name, questNext.name, questB.name = "First quest", "First quest", "Second quest"
local questDone = {}
local questActive, questTurnedIn = { [11] = true, [22] = true }, {}
local firstQuestObjective = { finished = false, numFulfilled = 0 }
C_QuestLog = {
    IsComplete = function(id) return questDone[id] == true end,
    IsOnQuest = function(id) return questActive[id] == true end,
    IsQuestFlaggedCompleted = function(id) return questTurnedIn[id] == true end,
    GetQuestObjectives = function() return { firstQuestObjective } end,
}
player.worldX = 300
focus.Sync(123, player, {}, { questA, questNext, questB }, {})
local questSelected = focus.SelectQuest(11)
player.worldX = 350
focus.Sync(123, player, {}, { questA, questNext, questB }, {})
assert(waypoint.position.x == .35 and focus.HasFocus(),
    "a focused quest point must not clear merely because the player reached its coordinates")
player.worldX = 300
focus.Sync(123, player, {}, { questA, questNext, questB }, {})
local questStarted, questReason = focus.ToggleRoute()
assert(questSelected and questStarted, "a clicked quest should anchor the quest route: " .. tostring(questReason))
player.worldX = 350
focus.Sync(123, player, {}, { questA, questNext, questB }, {})
assert(waypoint.position.x == .35,
    "arriving at an unfinished quest objective must keep its waypoint")
firstQuestObjective.finished = true
focus.Sync(123, player, {}, { questA, questNext, questB }, {})
assert(waypoint.position.x == .5,
    "completing a quest objective should choose the nearest remaining point")
player.worldX = 500
focus.Sync(123, player, {}, { questA, questNext, questB }, {})
assert(waypoint.position.x == .5 and focus.GetRoutePoint(),
    "arriving at the next unfinished objective must not skip to another quest")
firstQuestObjective.finished = false
focus.Sync(123, player, {}, { questA, questNext, questB }, {})
assert(waypoint.position.x == .5,
    "a quest stage reset must not count as a newly completed objective")
firstQuestObjective.finished = true
focus.Sync(123, player, {}, { questA, questNext, questB }, {})
assert(waypoint.position.x == .5 and focus.Status():find("Waiting", 1, true)
    and focus.GetRoutePoint() == nil,
    "completed quest points must not loop back to an earlier objective")
focus.Sync(123, { worldX = nil, worldY = nil, instanceID = 42 },
    {}, { questA, questNext, questB }, {})
focus.Sync(123, player, {}, { questA, questNext, questB }, {})
questDone[11] = true
focus.Sync(123, player, {}, { questA, questNext, questB }, {})
assert(waypoint.position.x == .5,
    "finishing objectives must not skip a quest before its turn-in")
questActive[11], questTurnedIn[11] = nil, true
focus.Sync(123, player, {}, { questA, questNext, questB }, {})
assert(waypoint.position.x == .7, "a completed quest should advance to the next available quest")
assert(focus.IsQuestRoute() and focus.SkipQuest()
    and not focus.IsRouteActive() and not focus.HasFocus() and waypoint == nil,
    "Skip Quest should move past a stuck quest and clear the final owned pin")

local objectiveFar, objectiveNear, objectiveNext = Step(400), Step(320), Step(520)
for _, objective in ipairs({ objectiveFar, objectiveNear, objectiveNext }) do
    objective.questID, objective.name = 33, "Three objectives"
end
questActive[33] = true
local objectiveProgress = { finished = false, numFulfilled = 0 }
C_QuestLog.GetQuestObjectives = function() return { objectiveProgress } end
player.worldX = 300
focus.Sync(123, player, {}, { objectiveFar, objectiveNear, objectiveNext }, {})
assert(focus.SelectQuest(33) and waypoint.position.x == .32,
    "choosing a quest by name should pin its closest objective")
assert(focus.ToggleRoute(), "the closest quest objective should start an Auto Route")
objectiveProgress.numFulfilled = 1
focus.Sync(123, player, {}, { objectiveFar, objectiveNear, objectiveNext }, {})
assert(waypoint.position.x == .32,
    "partial objective progress must keep the current waypoint")
objectiveProgress.finished = true
focus.Sync(123, player, {}, { objectiveFar, objectiveNear, objectiveNext }, {})
assert(waypoint.position.x == .4,
    "finishing an objective should pick the nearest remaining quest point")
assert(focus.Clear(), "the objective route should release its waypoint")
focus.Sync(123, player, {}, { questA, questNext, questB }, {})

local customWaypoint
WaypointUIAPI = { Navigation = { NewUserNavigation = function(options)
    customWaypoint = options
    waypoint = UiMapPoint.CreateFromCoordinates(options.mapID, options.x / 100, options.y / 100)
    return { mapID = options.mapID, x = options.x, y = options.y }
end } }
settings.vignetteRadarWorldFocusThemedWaypoint = true
settings.vignetteRadarQuestColors = true
addon.VignetteRadarQuestColors = { { .2, .3, .4 }, { .3, .4, .5 }, { .4, .5, .6 } }
addon.VignetteRadarStyle = { Color = function(slot)
    if slot == "rare" then return .9, .2, .1 end
    if slot == "treasure" then return .8, .6, .1 end
    return .5, .8, .7
end }
questB.colorSlot = 3
assert(focus.SelectQuest(22) and customWaypoint
    and customWaypoint.iconTexture == nil
    and customWaypoint.r == .4 and customWaypoint.g == .5 and customWaypoint.b == .6
    and customWaypoint.x == 70 and customWaypoint.y == 50,
    "WaypointUI should receive quest color and its own unobstructed icon")
assert(focus.SelectTarget({ key = rareA.key, name = rareA.name, category = rareA.kind,
    mapID = rareA.mapID, mapX = rareA.mapX, mapY = rareA.mapY,
    worldX = rareA.worldX, worldY = rareA.worldY, instanceID = rareA.instanceID })
    and customWaypoint.iconTexture == nil and customWaypoint.r == .9,
    "rare waypoints should use their theme color without drawing over the nameplate")
assert(focus.SelectNote(treasure) and customWaypoint.iconTexture == nil
    and customWaypoint.r == .8 and customWaypoint.g == .6,
    "treasure approach waypoints should preserve color and WaypointUI layout")
assert(focus.Advance() and focus.Advance() and customWaypoint.iconTexture == nil,
    "the final treasure stop should retain WaypointUI's legible native icon")
settings.vignetteRadarAutoRouteOnSelect = true
assert(focus.SelectTarget({ key = rareA.key, name = rareA.name, category = rareA.kind,
    mapID = rareA.mapID, mapX = rareA.mapX, mapY = rareA.mapY,
    worldX = rareA.worldX, worldY = rareA.worldY, instanceID = rareA.instanceID })
    and focus.IsRouteActive(), "the opt-in setting should start routing on a marker click")
settings.vignetteRadarAutoRouteOnSelect = false
focus.ToggleRoute()

WaypointUIAPI = nil
local liveChest, packChest = Step(500), Step(520)
liveChest.category, liveChest.key, liveChest.name = "treasure", "live:chest", "Live chest"
packChest.kind, packChest.key, packChest.name = "treasure", "pack:chest", "Pack chest"
packChest.route = { Step(400), Step(520) }
player.worldX = 100
focus.Sync(123, player, { liveChest }, {}, { packChest })
assert(focus.SelectTarget({ key = liveChest.key, name = liveChest.name,
    category = liveChest.category, mapID = liveChest.mapID,
    mapX = liveChest.mapX, mapY = liveChest.mapY,
    worldX = liveChest.worldX, worldY = liveChest.worldY,
    instanceID = liveChest.instanceID }) and waypoint.position.x == .4,
    "the preferred live treasure should inherit a nearby pack's entrance path")

local start, cave, direct = Step(300), Step(400), Step(550)
start.kind, start.key, start.name = "treasure", "start", "Starting cache"
cave.kind, cave.key, cave.name = "treasure", "cave", "Cave cache"
cave.route = { Step(500), Step(400) }
direct.kind, direct.key, direct.name = "treasure", "direct", "Open cache"
settings.vignetteRadarAutoRouteTravel = "ground"
player.worldX = 100
focus.Sync(123, player, {}, {}, { start, cave, direct })
assert(focus.SelectNote(start) and focus.ToggleRoute())
player.worldX = 300
focus.Sync(123, player, {}, {}, { start, cave, direct })
assert(waypoint.position.x == .55,
    "ground mode should account for a pack's entrance path when ordering stops")
settings.vignetteRadarAutoRouteTravel = "flying"
player.worldX = 100
focus.Sync(123, player, {}, {}, { start, cave, direct })
assert(focus.SelectNote(start))
assert(focus.ToggleRoute())
player.worldX = 300
focus.Sync(123, player, {}, {}, { start, cave, direct })
assert(waypoint.position.x == .5,
    "flying mode should favor the closer entrance when path length is less costly")

do
    local rare, chest, quest = Step(320), Step(330), Step(340)
    rare.key, rare.name, rare.category = "nearest-rare", "Nearby rare", "rare"
    chest.key, chest.name, chest.kind = "nearest-chest", "Nearby chest", "treasure"
    quest.questID, quest.name = 77, "Nearby quest"
    player.worldX = 300
    focus.Sync(123, player, { rare }, { quest }, { chest })
    assert(focus.StartNearest("rare") and waypoint.position.x == .32 and focus.IsRouteActive(),
        "the route chooser should start a rare route without first clicking a marker")
    assert(focus.StartNearest("treasure") and waypoint.position.x == .33 and focus.IsRouteActive(),
        "the route chooser should include saved treasure locations")
    settings.vignetteRadarAutoRouteOnSelect = true
    assert(focus.StartNearest("quest") and waypoint.position.x == .34 and focus.IsRouteActive(),
        "the chooser must not pause a route already started by auto-route-on-select")
    settings.vignetteRadarAutoRouteOnSelect = false
    focus.Sync(123, player, {}, {}, {})
    local ok, reason = focus.StartNearest("rare")
    assert(not ok and reason:find("No rare point", 1, true),
        "the chooser should explain when a route category has no point here")
end

local activeZygorStep = { num = 5, map = 123, current_waypoint_goal_num = 2,
    goals = {
        { map = 123, x = .5, y = .5, text = "First objective", status = "incomplete" },
        { map = 123, x = .6, y = .4, text = "Selected objective", status = "incomplete" },
    } }
ZygorGuidesViewer = { CurrentStep = activeZygorStep, Pointer = {
    current_waypoint = { m = 123, x = .9, y = .9, title = "Unrelated manual point" },
} }
local guide = focus.ZygorNote(123, function(_, vector)
    return vector.x * 1000, vector.y * 1000, 42
end, function(x, y) return { x = x, y = y } end)
assert(guide and guide.kind == "guide" and guide.worldX == 600
    and guide.name == "Selected objective"
    and not focus.ZygorNote(124, function() error("wrong map") end, function() end),
    "the selected, same-map guide objective should win over Zygor's manual arrow")
player.worldX = 300
focus.Sync(123, player, {}, {}, {})
assert(focus.SelectNote(guide, true))
player.worldX = 600
focus.Sync(123, player, {}, {}, {})
assert(focus.HasFocus() and waypoint.position.x == .6,
    "arriving at a Zygor objective must keep the pin until its guide step changes")
player.worldX = 300
activeZygorStep.goals[2].status = "complete"
local nextGoal = focus.ZygorNote(123, function(_, vector)
    return vector.x * 1000, vector.y * 1000, 42
end, function(x, y) return { x = x, y = y } end)
assert(nextGoal and nextGoal.mapX == .5,
    "a completed selected goal should yield to the next incomplete objective")
activeZygorStep.goals[1].status = "complete"
local waiting, waitingReason = focus.ZygorNote(123, function(_, vector)
    return vector.x * 1000, vector.y * 1000, 42
end, function(x, y) return { x = x, y = y } end, true, true)
assert(not waiting and waitingReason == "Waiting for Zygor's next guide step",
    "all completed goals must wait for Zygor rather than repin a finished objective")
activeZygorStep.goals[1].status = "incomplete"
activeZygorStep.goals[2].status = "incomplete"
activeZygorStep.waypath = { coords = {
    { map = 123, x = .3, y = .5 }, { map = 123, x = .45, y = .5 },
} }
local travel = focus.ZygorNote(123, function(_, vector)
    return vector.x * 1000, vector.y * 1000, 42
end, function(x, y) return { x = x, y = y } end, true, true, "travel")
assert(travel and travel.mapX == .45 and travel.name == "Travel Stop 2/2",
    "travel mode should advance past a nearby path node instead of pinning the objective")
activeZygorStep.waypath = nil
settings.vignetteRadarWorldFocusZygor = false
assert(not focus.ZygorNote(123, function() error("hidden guide") end, function() end),
    "the guide dot toggle should still hide Zygor from the radar")
assert(focus.ZygorNote(123, function(_, vector)
    return vector.x * 1000, vector.y * 1000, 42
end, function(x, y) return { x = x, y = y } end, true),
    "directly pinning Zygor should work even when its guide dot is hidden")
activeZygorStep.goals[2].GetWaypoint = function()
    return { m = 125, x = .61, y = .41 }
end
local normalized = focus.ZygorNote(123, function() return nil end,
    function(x, y) return { x = x, y = y } end, true, true)
assert(normalized and normalized.mapID == 125 and normalized.mapX == .61,
    "direct pinning should honor Zygor's resolved waypoint for the selected goal")
activeZygorStep.goals[2].GetWaypoint = nil
activeZygorStep.goals[2].map = 124
local remoteGuide = focus.ZygorNote(123, function() return nil end,
    function(x, y) return { x = x, y = y } end, true, true)
settings.vignetteRadarWorldFocusEnabled = false
assert(remoteGuide and remoteGuide.mapID == 124 and remoteGuide.worldX == nil
    and focus.SelectNote(remoteGuide, true) and waypoint.uiMapID == 124,
    "direct pinning should use the selected step's map even when marker focus is disabled")
assert(routeNotes[#routeNotes][1] == "ZYGOR STEP"
    and routeNotes[#routeNotes][2] == "Selected objective",
    "pinning the active Zygor objective should announce its text")
settings.vignetteRadarWorldFocusEnabled = true
focus.Sync(124, { worldX = 300, worldY = 500, instanceID = 42 }, {}, {}, {})
activeZygorStep.goals[2].x = nil
activeZygorStep.goals[1].map = nil
local objective = focus.ZygorNote(123, function() return nil end,
    function(x, y) return { x = x, y = y } end, true, true)
assert(objective and objective.mapID == 123 and objective.mapX == .5,
    "an unmapped selected goal should use another incomplete goal and inherit its step map")
activeZygorStep.goals = {}
activeZygorStep.waypath = { coords = { { map = 124, x = .7, y = .3 } } }
assert(focus.ZygorNote(123, function() return nil end,
    function(x, y) return { x = x, y = y } end, true, true).mapX == .7,
    "a guide step with no goal coordinates should use its own travel path")
activeZygorStep.waypath = nil
ZygorGuidesViewer.Pointer.current_waypoint = { m = 124, x = .8, y = .2,
    goal = { parentStep = activeZygorStep } }
assert(focus.ZygorNote(123, function() return nil end,
    function(x, y) return { x = x, y = y } end, true, true).mapX == .8,
    "a goal-owned pointer remains a last fallback for this guide step")
ZygorGuidesViewer.Pointer.current_waypoint = { m = 123, x = .9, y = .9,
    title = "Unrelated manual point" }
local missing, reason = focus.ZygorNote(124, function() end,
    function(x, y) return { x = x, y = y } end, true, true)
assert(not missing and reason == "Current Zygor step has no mapped location",
    "an unrelated manual arrow must not masquerade as the selected guide step")
ZygorGuidesViewer.CurrentStep = nil
local noStep, noStepReason = focus.ZygorNote(124, function() end,
    function(x, y) return { x = x, y = y } end, true, true)
assert(not noStep and noStepReason == "Zygor has no active guide step",
    "a missing guide step should explain why pinning cannot proceed")
local remoteQuest = Step(650)
remoteQuest.questID, remoteQuest.name, remoteQuest.mapID = 81, "Nearby map quest", 124
focus.Sync(123, player, {}, { remoteQuest }, {})
assert(focus.SelectQuest(81) and waypoint.uiMapID == 124,
    "quest focus must keep the quest point's map instead of replacing it with the player's map")
assert(focus.HasFocus() and focus.Clear() and not focus.HasFocus() and waypoint == nil,
    "clear focus should remove only the waypoint currently owned by the addon")
assert(focus.SelectQuest(81))
waypoint = UiMapPoint.CreateFromCoordinates(124, .1, .1)
assert(focus.Clear() and waypoint.position.x == .1,
    "clearing addon focus must preserve a waypoint another addon or the player set")
do
    local live = Step(700)
    live.key, live.category, live.name = "valid-live", "rare", "Valid rare"
    local incomplete = { key = "missing-coordinate", kind = "mob", mapID = 123 }
    player.worldX = 690
    focus.Sync(123, player, { live }, {}, { incomplete })
    assert(focus.StartNearest("rare") and waypoint.position.x == .7,
        "incomplete map notes must not break duplicate checking or valid rare routes")
end
do
    local first, second = Step(500), Step(600)
    first.kind, first.key, first.name = "treasure", "range:first", "First cache"
    second.kind, second.key, second.name = "treasure", "range:second", "Second cache"
    player.worldX = 480
    focus.Sync(123, player, {}, {}, { first, second })
    assert(focus.SelectNote(first) and focus.ToggleRoute() and waypoint.position.x == .5,
        "treasure Auto Route should start at the selected cache")
    player.worldX = 496.9
    focus.Sync(123, player, {}, {}, { first, second })
    assert(waypoint.position.x == .5,
        "treasure Auto Route must keep its stop at 3.1 yards even with rare distance set to 10")
    player.worldX = 497.1
    focus.Sync(123, player, {}, {}, { first, second })
    assert(waypoint.position.x == .6,
        "treasure Auto Route should continue after entering 3 yards")
    assert(focus.Clear())
end
do
    local looted, nextChest = Step(500), Step(600)
    looted.kind, looted.key, looted.name, looted.objectID =
        "treasure", "loot:first", "First cache", 777
    nextChest.kind, nextChest.key, nextChest.name =
        "treasure", "loot:second", "Second cache"
    player.worldX = 496
    focus.Sync(123, player, {}, {}, { looted, nextChest })
    assert(focus.SelectNote(looted) and focus.ToggleRoute()
        and waypoint.position.x == .5)
    GetTime = function() return 100 end
    GetNumLootItems = function() return 1 end
    GetLootSourceInfo = function() return "Creature-0-1-1-1-777-000" end
    focus.OnLootEvent("LOOT_OPENED")
    assert(not focus.OnLootEvent("LOOT_SLOT_CLEARED") and waypoint.position.x == .5,
        "looting a nearby creature must not consume a treasure route stop")
    GetLootSourceInfo = function() return "GameObject-0-1-1-1-999-000" end
    focus.OnLootEvent("LOOT_OPENED")
    assert(not focus.OnLootEvent("LOOT_SLOT_CLEARED") and waypoint.position.x == .5,
        "a different nearby container must not consume the saved treasure")
    GetLootSourceInfo = function() return "GameObject-0-1-1-1-777-000" end
    focus.OnLootEvent("LOOT_OPENED")
    assert(focus.OnLootEvent("LOOT_SLOT_CLEARED") and waypoint.position.x == .6,
        "looting the matched nearby treasure should advance even outside 3 yards")
end
io.write("vignette radar World Focus tests passed\n")
