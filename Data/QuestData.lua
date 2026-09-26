local _, addon = ...
if type(addon) ~= "table" then return end

-- Read-only Blizzard quest metadata. The radar decides whether a returned map
-- point can be projected; a waypoint on another map is never moved here.
local API = {}
addon.VignetteRadarQuestData = API

local stepCache, stepCacheCount, stepCacheMap = {}, 0, nil
local startsCache, requestedMaps, startsCacheCount = {}, {}, 0
local objectiveCache, objectiveCacheCount = {}, 0
local STEP_AGE, STARTS_AGE, MAX_STEPS, MAX_STARTS = 2, 5, 64, 80
local MAX_CACHED_MAPS = 64

local function IsSecret(value)
    if not issecretvalue then return false end
    local ok, secret = pcall(issecretvalue, value)
    return not ok or secret == true
end

local function Number(value)
    if IsSecret(value) or type(value) ~= "number" then return nil end
    if value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function ID(value)
    value = Number(value)
    return value and value > 0 and value % 1 == 0 and value or nil
end

local function Position(value)
    value = Number(value)
    return value and value >= 0 and value <= 1 and value or nil
end

local function Text(value, limit)
    if IsSecret(value) or type(value) ~= "string" or value == "" then return nil end
    return value:sub(1, limit or 160)
end

local function Field(record, name)
    if IsSecret(record) or type(record) ~= "table" then return nil end
    local ok, value = pcall(function() return record[name] end)
    if ok and not IsSecret(value) then return value end
    return nil
end

local function Now()
    if type(GetTime) ~= "function" then return 0 end
    local ok, value = pcall(GetTime)
    return ok and Number(value) or 0
end

local function Copy(record)
    if not record then return nil end
    local result = {}
    for key, value in pairs(record) do result[key] = value end
    return result
end

local function Call(owner, name, ...)
    if type(owner) ~= "table" then return nil end
    local read, callback = pcall(function() return owner[name] end)
    if not read or IsSecret(callback) then return nil end
    if type(callback) ~= "function" then return nil end
    local ok, a, b, c = pcall(callback, ...)
    if not ok then return nil end
    return a, b, c
end

function API.Invalidate(reason)
    stepCache, stepCacheCount, stepCacheMap = {}, 0, nil
    startsCache, startsCacheCount = {}, 0
    objectiveCache, objectiveCacheCount = {}, 0
    if reason ~= "quest" then requestedMaps = {} end
end

-- Quest objectives are read at most once per two seconds between quest events,
-- even though the movable arrow redraws much more often.
function API.GetObjectiveSummary(questID, hint)
    questID = ID(questID)
    if not questID then return nil end
    local now = Now()
    local cached = objectiveCache[questID]
    if not cached or now - cached.at >= STEP_AGE then
        local raw = Call(C_QuestLog, "GetQuestObjectives", questID)
        local rows = {}
        if not IsSecret(raw) and type(raw) == "table" then
            local ok, count = pcall(function() return #raw end)
            if ok and Number(count) then
                for index = 1, math.min(count, 16) do
                    local objective = Field(raw, index)
                    local label = Text(Field(objective, "text"), 150)
                    if label then
                        local current = Number(Field(objective, "numFulfilled"))
                        local required = Number(Field(objective, "numRequired"))
                        local fromText, totalText = label:match("(%d+)%s*/%s*(%d+)%s*$")
                        current = current or tonumber(fromText)
                        required = required or tonumber(totalText)
                        label = label:gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", "")
                        if label == "" then label = "Quest Objective" end
                        rows[#rows + 1] = { label = label,
                            count = current and required and required > 0
                                and (math.floor(current) .. "/" .. math.floor(required)) or nil,
                            finished = Field(objective, "finished") == true }
                    end
                end
            end
        end
        if objectiveCacheCount >= MAX_STEPS then objectiveCache, objectiveCacheCount = {}, 0 end
        if not objectiveCache[questID] then objectiveCacheCount = objectiveCacheCount + 1 end
        cached = { at = now, rows = rows }
        objectiveCache[questID] = cached
    end
    local wanted = Text(hint, 160)
    if wanted then wanted = wanted:lower():gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", "") end
    local first
    for _, row in ipairs(cached.rows) do
        if not row.finished then
            if wanted and wanted ~= "" and (row.label:lower():find(wanted, 1, true)
                or wanted:find(row.label:lower(), 1, true)) then return Copy(row) end
            first = first or row
        end
    end
    if not first and #cached.rows == 0 then
        local fallback = Text(hint, 150)
        if fallback then
            local current, required = fallback:match("(%d+)%s*/%s*(%d+)%s*$")
            fallback = fallback:gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", "")
            return { label = fallback ~= "" and fallback or "Quest Objective",
                count = current and required and (current .. "/" .. required) or nil }
        end
    end
    return Copy(first)
end

-- Returns a map point when Blizzard provides one and its separate instruction
-- text when available. `onCurrentMap` is false for a waypoint on another map.
function API.GetNextStep(questID, mapID)
    questID, mapID = ID(questID), ID(mapID)
    if not questID then return nil end
    if stepCacheMap ~= mapID then
        stepCache, stepCacheCount, stepCacheMap = {}, 0, mapID
    end
    local now = Now()
    local cached = stepCache[questID]
    if cached and now - cached.at < STEP_AGE then return Copy(cached.value) end

    local result = { questID = questID }
    local x, y
    if mapID then
        x, y = Call(C_QuestLog, "GetNextWaypointForMap", questID, mapID)
        x, y = Position(x), Position(y)
        if x and y then
            result.mapID, result.x, result.y, result.onCurrentMap = mapID, x, y, true
        end
    end
    if not result.x then
        local waypointMap
        waypointMap, x, y = Call(C_QuestLog, "GetNextWaypoint", questID)
        waypointMap, x, y = ID(waypointMap), Position(x), Position(y)
        if waypointMap and x and y then
            result.mapID, result.x, result.y = waypointMap, x, y
            result.onCurrentMap = waypointMap == mapID
        end
    end
    result.text = Text(Call(C_QuestLog, "GetNextWaypointText", questID), 160)
    if not (result.x or result.text) then result = nil end

    if stepCacheCount >= MAX_STEPS then stepCache, stepCacheCount = {}, 0 end
    if not stepCache[questID] then stepCacheCount = stepCacheCount + 1 end
    stepCache[questID] = { at = now, value = result }
    return Copy(result)
end

local function Floor(value)
    value = Number(value)
    if value == 0 then return "above" end
    if value == 1 then return "below" end
    if value == 2 then return "same" end
    return nil
end

local function ReadStarts(mapID)
    local raw = Call(C_QuestLine, "GetAvailableQuestLines", mapID)
    if IsSecret(raw) or type(raw) ~= "table" then return {} end
    local result, seen = {}, {}
    local ok, count = pcall(function() return #raw end)
    if not ok or not Number(count) then return result end
    for index = 1, math.min(count, MAX_STARTS) do
        local read, entry = pcall(function() return raw[index] end)
        if not read then entry = nil end
        local questID, lineID = ID(Field(entry, "questID")), ID(Field(entry, "questLineID"))
        local x, y = Position(Field(entry, "x")), Position(Field(entry, "y"))
        if questID and lineID and x and y and Field(entry, "isQuestStart") == true
            and Field(entry, "isHidden") == false and not seen[lineID] then
            seen[lineID] = true
            result[#result + 1] = {
                questID = questID, questLineID = lineID,
                questName = Text(Field(entry, "questName"), 120),
                questLineName = Text(Field(entry, "questLineName"), 120),
                mapID = mapID, startMapID = ID(Field(entry, "startMapID")), x = x, y = y,
                isCampaign = Field(entry, "isCampaign") == true,
                isImportant = Field(entry, "isImportant") == true,
                floor = Floor(Field(entry, "floorLocation")),
            }
        end
    end
    return result
end

-- Blizzard supplies only lines currently available on this map. It may return
-- an empty list until its own map request has loaded; never invent quest starts.
function API.GetAvailableQuestStarts(mapID)
    mapID = ID(mapID)
    if not mapID then return {} end
    local now = Now()
    local cached = startsCache[mapID]
    if cached and now - cached.at < STARTS_AGE then
        local copy = {}
        for index, entry in ipairs(cached.value) do copy[index] = Copy(entry) end
        return copy
    end
    if not requestedMaps[mapID] then
        Call(C_QuestLine, "RequestQuestLinesForMap", mapID)
        requestedMaps[mapID] = true
    end
    local result = ReadStarts(mapID)
    if startsCacheCount >= MAX_CACHED_MAPS then startsCache, startsCacheCount = {}, 0 end
    if not startsCache[mapID] then startsCacheCount = startsCacheCount + 1 end
    startsCache[mapID] = { at = now, value = result }
    local copy = {}
    for index, entry in ipairs(result) do copy[index] = Copy(entry) end
    return copy
end
