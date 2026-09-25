local addon = {}
local settings = { vignetteRadarFollowZygor = false,
    vignetteRadarZygorMode = "objective" }
addon.GetSettings = function() return settings end
local pinned, owned, refreshes = {}, false, 0
addon.VignetteRadarWorldFocus = {
    ZygorNote = function(_, _, _, _, _, mode, goalIndex)
        local step = ZygorGuidesViewer.CurrentStep
        if not step then return nil, "Zygor has no active guide step" end
        local name = mode == "travel" and "Travel Stop" or goalIndex and
            step.goals[goalIndex].text or step.goals[step.current_waypoint_goal_num].text
        return { key = tostring(step.num) .. ":" .. tostring(mode) .. ":"
            .. tostring(goalIndex or step.current_waypoint_goal_num),
            kind = "guide", name = name }
    end,
    SelectNote = function(note)
        pinned[#pinned + 1] = note
        owned = true
        return true
    end,
    OwnsGuideWaypoint = function() return owned end,
}
local handlers, timers = {}, {}
ZygorGuidesViewer = {
    CurrentGuide = { title = "Example Guide" },
    CurrentStep = { num = 3, current_waypoint_goal_num = 1, goals = {
        { text = "Find the chest", status = "incomplete" },
        { text = "Collect the key", status = "complete" },
    } },
    AddMessageHandler = function(_, event, handler) handlers[event] = handler end,
}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
C_Map = { GetUserWaypoint = function() return owned and {} or nil end }
assert(loadfile("Data/Zygor.lua"))("VignetteRadar", addon)
local bridge = addon.VignetteRadarZygor
assert(bridge.Bind(function() end, function() end, function() return 123 end,
    function() refreshes = refreshes + 1 end))
assert(handlers.ZGV_STEP_CHANGED and handlers.ZGV_STEP_WAYPOINT_CHANGED
    and handlers.ZGV_GOAL_COMPLETED,
    "follow must subscribe to guide and objective completion messages")
assert(bridge.SetFollow(true) and #pinned == 1
    and pinned[1].name == "Find the chest" and refreshes == 1,
    "enabling follow should pin the selected guide objective once")
handlers.ZGV_STEP_CHANGED()
handlers.ZGV_GOAL_COMPLETED()
assert(#timers == 1, "bursty guide messages should coalesce into one update")
timers[1]()
assert(#pinned == 1, "unchanged guide goals must not repin the same waypoint")
ZygorGuidesViewer.CurrentStep.num = 4
handlers.ZGV_STEP_CHANGED()
timers[2]()
assert(#pinned == 2 and bridge.GuideLabel():find("Step 4", 1, true),
    "step changes should advance the followed waypoint")
bridge.SetMode("travel")
assert(#pinned == 3 and pinned[3].name == "Travel Stop",
    "the selected follow mode should control the destination")
bridge.SetFollow(false)
assert(bridge.StartObjectiveRoute() and bridge.IsFollowing()
    and settings.vignetteRadarZygorMode == "objective"
    and pinned[#pinned].name == "Find the chest",
    "choosing Zygor as a route should follow its selected objective and pin it immediately")
local goals = bridge.Goals()
assert(#goals == 2 and goals[1].mapped and not goals[1].complete
    and goals[2].complete, "picker rows should show mapped objectives and completion")
assert(bridge.Pin("objective", 2) and pinned[#pinned].name == "Collect the key",
    "an explicit picker choice should pin the selected goal")
bridge.PauseForManual("Manual waypoint selected")
assert(bridge.IsPaused() and bridge.Status():find("Manual waypoint", 1, true),
    "manual waypoints should pause guide follow with an explanation")
handlers.ZGV_STEP_CHANGED()
assert(#timers == 2, "paused follow should ignore guide events")
assert(bridge.ToggleFollow() and bridge.IsFollowing(),
    "resuming should restore guide follow")
io.write("vignette radar Zygor tests passed\n")
