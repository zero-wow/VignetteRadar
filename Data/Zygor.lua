local _, addon = ...
if type(addon) ~= "table" then return end

-- The guide is read through Zygor's live objects. We never edit its files or
-- poll the guide each frame; Zygor's own messages schedule a coalesced update.
local API = {}
addon.VignetteRadarZygor = API
local context, boundViewer, handler, queued
local paused, pauseReason, lastKey, lastReason = false, nil, nil, nil
local EVENTS = { "ZGV_STEP_CHANGED", "ZGV_STEP_WAYPOINT_CHANGED",
    "ZGV_GOAL_COMPLETED", "ZGV_GOAL_UNCOMPLETED" }

local function Settings() return addon.GetSettings() end

local function Clean(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|T.-|t", ""):gsub("[%c]", " ")
    return value ~= "" and value or nil
end

local function CurrentStep()
    local viewer = _G.ZygorGuidesViewer
    if not viewer then return nil, nil, "Zygor is not loaded" end
    local ok, step, guide = pcall(function() return viewer.CurrentStep, viewer.CurrentGuide end)
    if not ok or not step then return nil, viewer, "Zygor has no active guide step" end
    return step, viewer, guide
end

local function CurrentNote(mode, goalIndex)
    local focus = addon.VignetteRadarWorldFocus
    if not (focus and context) then return nil, "Radar map data is not ready" end
    local mapID = context.mapID()
    return focus.ZygorNote(mapID, context.mapToWorld, context.mapVector,
        true, true, mode or Settings().vignetteRadarZygorMode, goalIndex)
end

local function ExternalWaypoint()
    if not (C_Map and type(C_Map.GetUserWaypoint) == "function") then return false end
    local ok, point = pcall(C_Map.GetUserWaypoint)
    return ok and point ~= nil and not (issecretvalue and issecretvalue(point))
end

function API.PauseForManual(reason)
    if Settings().vignetteRadarFollowZygor ~= true then return end
    paused, pauseReason = true, reason or "Manual waypoint selected"
    lastKey = nil
end

function API.IsFollowing()
    return Settings().vignetteRadarFollowZygor == true and not paused
end

function API.IsPaused()
    return Settings().vignetteRadarFollowZygor == true and paused
end

function API.Status()
    if Settings().vignetteRadarFollowZygor ~= true then return "Zygor Follow is off" end
    if paused then return "Zygor Follow paused · " .. (pauseReason or "resume when ready") end
    if lastReason then return "Zygor Follow waiting · " .. lastReason end
    local step, _, reason = CurrentStep()
    if not step then return "Zygor Follow waiting · " .. (reason or "guide step") end
    local number = step and tonumber(step.num)
    return "Following Zygor" .. (number and (" · Step " .. number) or "")
end

function API.GuideLabel()
    local step, _, guide = CurrentStep()
    if not step then return guide or "Zygor has no active guide step" end
    local title = guide and Clean(guide.title_short or guide.title)
    local number = tonumber(step.num)
    local selected = tonumber(step.current_waypoint_goal_num)
    local total = type(step.goals) == "table" and #step.goals or 0
    local label = (title or "Zygor Guide") .. (number and (" · Step " .. number) or "")
    if selected and total > 0 then label = label .. " · Goal " .. selected .. "/" .. total end
    return label
end

function API.RefreshFollow(force)
    if not API.IsFollowing() then return false end
    local focus = addon.VignetteRadarWorldFocus
    if not focus then return false, "World Focus is unavailable" end
    local note, reason = CurrentNote()
    if not note then
        lastReason = reason or "Current step has no mapped location"
        return false, lastReason
    end
    if lastKey == note.key and focus.OwnsGuideWaypoint() then
        lastReason = nil
        return true
    end
    if not force and ((lastKey and not focus.OwnsGuideWaypoint())
        or (not lastKey and ExternalWaypoint() and not focus.OwnsGuideWaypoint())) then
        API.PauseForManual("Another waypoint is active")
        return false, pauseReason
    end
    local ok, pinReason = focus.SelectNote(note, true)
    if not ok then
        lastReason = pinReason or "Waypoint could not be set"
        return false, lastReason
    end
    lastKey, lastReason = note.key, nil
    if context and context.refresh then context.refresh() end
    return true
end

local function QueuedRefresh()
    queued = false
    API.RefreshFollow(false)
end

local function OnGuideMessage()
    if not API.IsFollowing() or queued then return end
    queued = true
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, QueuedRefresh)
    else QueuedRefresh() end
end

function API.Bind(mapToWorld, mapVector, mapID, refresh)
    if not context then context = {} end
    context.mapToWorld, context.mapVector = mapToWorld, mapVector
    context.mapID, context.refresh = mapID, refresh
    local viewer = _G.ZygorGuidesViewer
    if not (viewer and type(viewer.AddMessageHandler) == "function") then return false end
    if boundViewer == viewer then return true end
    if boundViewer and handler and type(boundViewer.RemoveMessageHandler) == "function" then
        for _, event in ipairs(EVENTS) do pcall(boundViewer.RemoveMessageHandler, boundViewer, event, handler) end
    end
    handler = function() OnGuideMessage() end
    for _, event in ipairs(EVENTS) do
        local ok = pcall(viewer.AddMessageHandler, viewer, event, handler)
        if not ok then return false end
    end
    boundViewer = viewer
    if API.IsFollowing() then OnGuideMessage() end
    return true
end

function API.SetFollow(enabled)
    Settings().vignetteRadarFollowZygor = enabled == true
    paused, pauseReason, lastReason, lastKey = false, nil, nil, nil
    if not enabled then return true end
    local ok, reason = API.RefreshFollow(true)
    if not ok and type(addon.ShowVignetteRadarRouteNote) == "function" then
        addon.ShowVignetteRadarRouteNote("ZYGOR FOLLOW", "Waiting · " .. (reason or "guide step"))
    end
    return ok, reason
end

function API.StartObjectiveRoute()
    Settings().vignetteRadarZygorMode = "objective"
    return API.SetFollow(true)
end

function API.ToggleFollow()
    if Settings().vignetteRadarFollowZygor ~= true then return API.SetFollow(true) end
    if not paused then
        paused, pauseReason, lastKey = true, "Paused by you", nil
        if type(addon.ShowVignetteRadarRouteNote) == "function" then
            addon.ShowVignetteRadarRouteNote("ZYGOR FOLLOW", "Paused · waypoint kept")
        end
        return true
    end
    paused, pauseReason, lastKey = false, nil, nil
    return API.RefreshFollow(true)
end

function API.SetMode(mode)
    if mode ~= "objective" and mode ~= "travel" then return false end
    Settings().vignetteRadarZygorMode = mode
    if API.IsFollowing() then return API.RefreshFollow(true) end
    return true
end

function API.Goals()
    local step, _, reason = CurrentStep()
    if not step then return {}, reason end
    local goals, rows = type(step.goals) == "table" and step.goals or {}, {}
    for index = 1, math.min(#goals, 64) do
        local goal = goals[index]
        if goal then
            local visible = true
            if type(goal.IsVisible) == "function" then
                local ok, result = pcall(goal.IsVisible, goal)
                visible = ok and result ~= false and not (issecretvalue and issecretvalue(result))
            end
            if visible then
                local text = Clean(goal.text or goal.title)
                if type(goal.GetText) == "function" then
                    local ok, result = pcall(goal.GetText, goal, false, true, false, true)
                    if ok then text = Clean(result) or text end
                end
                local complete = goal.status == "complete"
                if type(goal.IsComplete) == "function" then
                    local ok, result = pcall(goal.IsComplete, goal)
                    if ok and type(result) == "boolean" then complete = result end
                end
                local note, missing = CurrentNote("objective", index)
                rows[#rows + 1] = { index = index, name = text or ("Objective " .. index),
                    complete = complete, mapped = note ~= nil,
                    reason = missing, selected = step.current_waypoint_goal_num == index }
            end
        end
    end
    return rows
end

function API.Pin(mode, goalIndex)
    local focus = addon.VignetteRadarWorldFocus
    if not focus then return false, "World Focus is unavailable" end
    local note, reason = CurrentNote(mode, goalIndex)
    if not note then return false, reason end
    if goalIndex then
        local step = CurrentStep()
        if step and type(step.CycleWaypointTo) == "function" then
            pcall(step.CycleWaypointTo, step, goalIndex)
        end
    end
    local ok, pinReason = focus.SelectNote(note, true)
    if ok and API.IsFollowing() then lastKey, lastReason = note.key, nil end
    return ok, pinReason
end
