local _, addon = ...
if type(addon) ~= "table" then return end

-- WaypointUI attaches its pylon directly to Blizzard's navigation frame.
-- Ease only our own displayed pylon; never change the actual map waypoint.
local API = {}
addon.VignetteRadarWaypointStability = API

local active, hooked, proxy, currentX, currentY, navFrame = false, false
local restoring = false
local elapsedTime = 0

local function Number(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function CanAnchor(frame)
    if not frame then return false end
    if type(InCombatLockdown) == "function" then
        local ok, locked = pcall(InCombatLockdown)
        if not ok or locked ~= false then return false end
    end
    if type(frame.IsProtected) == "function" then
        local ok, protected = pcall(frame.IsProtected, frame)
        if not ok or protected then return false end
    end
    return true
end

local function Relative(frame)
    if not (frame and type(frame.GetPoint) == "function") then return nil end
    local ok, _, relative = pcall(frame.GetPoint, frame, 1)
    return ok and relative or nil
end

local function Anchor(frame, from, point, relativePoint, offset)
    if not (Relative(frame) == from and CanAnchor(frame)) then return end
    local ok = pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint(point, proxy, relativePoint, 0, offset)
    end)
    if not ok then
        pcall(function()
            frame:ClearAllPoints()
            frame:SetPoint(point, from, relativePoint, 0, offset)
        end)
    end
end

local function Restore()
    local nav = navFrame
    if not nav then restoring = false; return end
    local waypoint, pinpoint = _G.WUIWaypointFrame, _G.WUIPinpointFrame
    if waypoint and CanAnchor(waypoint) and Relative(waypoint) == proxy then
        pcall(function()
            waypoint:ClearAllPoints()
            waypoint:SetPoint("CENTER", nav)
        end)
    end
    if pinpoint and CanAnchor(pinpoint) and Relative(pinpoint) == proxy then
        pcall(function()
            pinpoint:ClearAllPoints()
            pinpoint:SetPoint("BOTTOM", nav, "TOP", 0, 75)
        end)
    end
    restoring = (waypoint and Relative(waypoint) == proxy)
        or (pinpoint and Relative(pinpoint) == proxy) or false
end

local function Update(_, elapsed)
    if not active then
        if restoring then Restore() end
        return
    end
    local budget = addon.VignetteRadarBudget
    if budget and budget.paused and
        (budget.paused.radar or budget.paused.background) then
        API.Disable()
        return
    end
    elapsedTime = elapsedTime + (Number(elapsed) or 0)
    if elapsedTime < .033 then return end
    local delta = math.min(elapsedTime, .15)
    elapsedTime = 0
    local nav
    if C_Navigation and type(C_Navigation.GetFrame) == "function" then
        local ok, value = pcall(C_Navigation.GetFrame)
        if ok then nav = value end
    end
    if not nav or not proxy or not WorldFrame then return end
    local read, x, y = pcall(nav.GetCenter, nav)
    local centerRead, centerX, centerY = pcall(WorldFrame.GetCenter, WorldFrame)
    if not (read and centerRead and Number(x) and Number(y)
        and Number(centerX) and Number(centerY)) then return end
    if nav ~= navFrame then currentX, currentY, navFrame = x, y, nav end
    if not currentX then currentX, currentY = x, y end
    local distance
    if C_Navigation and type(C_Navigation.GetDistance) == "function" then
        local ok, value = pcall(C_Navigation.GetDistance)
        if ok then distance = value end
    end
    local duration = Number(distance) and distance > 150 and .20 or .10
    local factor = math.min(1, delta / duration)
    currentX = currentX + (x - currentX) * factor
    currentY = currentY + (y - currentY) * factor
    proxy:ClearAllPoints()
    proxy:SetPoint("CENTER", WorldFrame, "CENTER",
        currentX - centerX, currentY - centerY)
    Anchor(_G.WUIWaypointFrame, nav, "CENTER", "CENTER", 0)
    Anchor(_G.WUIPinpointFrame, nav, "BOTTOM", "TOP", 75)
end

function API.Enable()
    if not (_G.WUIWaypointFrame and _G.WUIPinpointFrame
        and C_Navigation and type(C_Navigation.GetFrame) == "function"
        and WorldFrame and UIParent and type(CreateFrame) == "function") then
        return false
    end
    if not hooked then
        if not (CanAnchor(_G.WUIWaypointFrame) and CanAnchor(_G.WUIPinpointFrame)) then
            return false
        end
        proxy = CreateFrame("Frame", nil, UIParent)
        proxy:SetSize(1, 1)
        _G.WUIWaypointFrame:HookScript("OnUpdate", Update)
        _G.WUIPinpointFrame:HookScript("OnUpdate", Update)
        hooked = true
    end
    currentX, currentY, navFrame, elapsedTime = nil, nil, nil, 0
    restoring = false
    active = true
    return true
end

function API.Disable()
    if not active and not restoring then return end
    active = false
    currentX, currentY, elapsedTime = nil, nil, 0
    restoring = true
    Restore()
end

function API.IsEnabled() return active end
