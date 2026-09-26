local _, addon = ...
if type(addon) ~= "table" then return end

-- Explicit prerequisite graph only. Titles and proximity never imply an edge,
-- completion, eligibility, or coordinates.
local Chains = {}
addon.VignetteRadarQuestChain = Chains

local MAX_CHAINS, MAX_STEPS, MAX_DEPS, MAX_TEXT = 32, 256, 12, 100
local CATEGORIES = { story = true, side = true, chosen = true }

local function Safe(value)
    if type(issecretvalue) ~= "function" then return true end
    local ok, secret = pcall(issecretvalue, value)
    return ok and not secret
end

local function Field(record, key)
    if type(record) ~= "table" or not Safe(record) then return nil end
    local ok, value = pcall(function() return record[key] end)
    return ok and Safe(value) and value or nil
end

local function Integer(value)
    return Safe(value) and type(value) == "number" and value > 0
        and value == math.floor(value) and value <= 1e9 and value or nil
end

local function Text(value)
    return Safe(value) and type(value) == "string" and #value > 0
        and #value <= MAX_TEXT and value or nil
end

local function ValidPoint(point)
    local mapID = Integer(Field(point, "mapID"))
    local x, y = Field(point, "mapX"), Field(point, "mapY")
    if not mapID or type(x) ~= "number" or type(y) ~= "number"
        or not Safe(x) or not Safe(y) or x ~= x or y ~= y
        or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    return { mapID = mapID, mapX = x, mapY = y }
end

local function HasCycle(index)
    local colors = {}
    local function Visit(id)
        if colors[id] == 1 then return true end
        if colors[id] == 2 then return false end
        colors[id] = 1
        for _, required in ipairs(index[id].requires) do
            if index[required] and Visit(required) then return true end
        end
        colors[id] = 2
        return false
    end
    for id in pairs(index) do if Visit(id) then return true end end
    return false
end

function Chains.Load(source)
    if Integer(Field(source, "version")) ~= 1 then return nil, "Unsupported schema" end
    local input = Field(source, "chains")
    if type(input) ~= "table" or not Safe(input) or #input > MAX_CHAINS then
        return nil, "Chain limit exceeded"
    end
    local result = { version = 1, chains = {}, byID = {} }
    local total = 0
    for _, raw in ipairs(input) do
        local id, title = Text(Field(raw, "id")), Text(Field(raw, "title"))
        local steps = Field(raw, "steps")
        if not id or not title or result.byID[id] or type(steps) ~= "table"
            or not Safe(steps) or #steps == 0 then return nil, "Invalid chain" end
        local category = Field(raw, "category")
        local chain = { id = id, title = title,
            category = CATEGORIES[category] and category or "chosen",
            completeGraph = Field(raw, "completeGraph") == true,
            source = Text(Field(raw, "source")) or "Unknown",
            steps = {}, byQuestID = {} }
        result.chains[#result.chains + 1] = chain
        result.byID[id] = chain
        for _, rawStep in ipairs(steps) do
            total = total + 1
            if total > MAX_STEPS then return nil, "Step limit exceeded" end
            local questID = Integer(Field(rawStep, "questID"))
            local name = Text(Field(rawStep, "name"))
            local requirements = Field(rawStep, "requires")
            if not questID or not name or chain.byQuestID[questID]
                or (requirements ~= nil and (type(requirements) ~= "table"
                    or not Safe(requirements) or #requirements > MAX_DEPS)) then
                return nil, "Invalid step"
            end
            local step = { questID = questID, name = name, requires = {} }
            local seen = {}
            for _, required in ipairs(requirements or {}) do
                required = Integer(required)
                if not required or required == questID or seen[required] then
                    return nil, "Invalid prerequisite"
                end
                seen[required] = true
                step.requires[#step.requires + 1] = required
            end
            chain.steps[#chain.steps + 1] = step
            chain.byQuestID[questID] = step
        end
        if HasCycle(chain.byQuestID) then return nil, "Prerequisite cycle" end
    end
    return result
end

local function QuestState(query, questID)
    if type(query) ~= "function" then return "unknown" end
    local ok, state = pcall(query, questID)
    if not ok or not Safe(state) then return "unknown" end
    if type(state) == "table" then
        if Field(state, "complete") == true then return "complete" end
        if Field(state, "active") == true then return "active" end
        if Field(state, "available") == true then return "available" end
        return "unknown"
    end
    if state == "complete" or state == "active" or state == "available" then
        return state
    end
    return "unknown"
end

function Chains.Inspect(data, chainID, questState, resolvePoint)
    local chain = type(data) == "table" and Field(data, "byID")
    chain = chain and chain[chainID]
    if not chain then return nil, "Unknown chain" end
    local view = { id = chain.id, title = chain.title, category = chain.category,
        source = chain.source, prerequisitesKnown = chain.completeGraph,
        steps = {}, activeQuestID = nil, nextQuestID = nil }
    for _, step in ipairs(chain.steps) do
        local status = QuestState(questState, step.questID)
        local blockedBy, unknownBy = {}, {}
        for _, required in ipairs(step.requires) do
            local state = QuestState(questState, required)
            if state == "unknown" then unknownBy[#unknownBy + 1] = required
            elseif state ~= "complete" then blockedBy[#blockedBy + 1] = required end
        end
        if status ~= "complete" and status ~= "active" then
            if #blockedBy > 0 then status = "blocked"
            elseif #unknownBy > 0 then status = "unknown"
            elseif status ~= "available" then status = "unknown" end
        end
        local point
        if type(resolvePoint) == "function" then
            local ok, result = pcall(resolvePoint, step.questID)
            if ok then point = ValidPoint(result) end
        end
        local item = { questID = step.questID, name = step.name,
            state = status, blockedBy = blockedBy, unknownBy = unknownBy,
            prerequisitesKnown = chain.completeGraph, point = point }
        view.steps[#view.steps + 1] = item
        if status == "active" and not view.activeQuestID then
            view.activeQuestID = step.questID
        end
        if status == "available" and not view.nextQuestID then
            view.nextQuestID = step.questID
        end
    end
    return view
end

function Chains.SelectMappedStep(view, questID)
    if type(view) ~= "table" or type(view.steps) ~= "table" then return nil, "No chain view" end
    for _, step in ipairs(view.steps) do
        if step.questID == questID then
            if not step.point then return nil, "Location unknown" end
            return { questID = step.questID, name = step.name,
                state = step.state, mapID = step.point.mapID,
                mapX = step.point.mapX, mapY = step.point.mapY }
        end
    end
    return nil, "Unknown step"
end
