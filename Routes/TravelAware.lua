local _, addon = ...
if type(addon) ~= "table" then return end

-- Data-only travel estimates. A transition is usable only when a provider
-- explicitly verifies both ends; absence of graph data never invents a path.
local Travel = {}
addon.VignetteRadarTravelAware = Travel

local MAX_TRANSITIONS, MAX_ROUTE_STEPS = 24, 12
local HUGE = math.huge

local function Safe(value)
    if type(issecretvalue) ~= "function" then return true end
    local ok, secret = pcall(issecretvalue, value)
    return ok and not secret
end

local function Field(value, key)
    if type(value) ~= "table" or not Safe(value) then return nil end
    local ok, field = pcall(function() return value[key] end)
    return ok and Safe(field) and field or nil
end

local function Number(value)
    return Safe(value) and type(value) == "number" and value == value
        and value ~= HUGE and value ~= -HUGE and value or nil
end

local function Position(source)
    local mapID = Number(Field(source, "mapID"))
    local x, y = Number(Field(source, "worldX")), Number(Field(source, "worldY"))
    local instanceID = Number(Field(source, "instanceID"))
    if not (mapID and mapID > 0 and mapID == math.floor(mapID) and x and y) then return nil end
    return { mapID = mapID, worldX = x, worldY = y, instanceID = instanceID }
end

local function SamePlace(a, b)
    return a.mapID == b.mapID and (not a.instanceID or not b.instanceID
        or a.instanceID == b.instanceID)
end

local function Distance(a, b)
    if not SamePlace(a, b) then return nil end
    local dx, dy = a.worldX - b.worldX, a.worldY - b.worldY
    return math.sqrt(dx * dx + dy * dy)
end

local function Mode(options)
    local requested = Field(options, "mode")
    if requested == "direct" or requested == "flying" or requested == "ground" then
        return requested
    end
    return Field(options, "isFlying") == true and "flying" or "ground"
end

local function Weight(mode)
    -- Equivalent yards, not an arrival-time claim. Flight is cheaper for
    -- open stretches; the provider still controls transition availability.
    return mode == "flying" and .7 or 1
end

function Travel.New(transitions)
    if type(transitions) ~= "table" or not Safe(transitions)
        or #transitions > MAX_TRANSITIONS then return nil, "Too many transitions" end
    local graph = { nodes = {}, transitions = {}, cache = {} }
    local seen = {}
    for index = 1, #transitions do
        local entry = transitions[index]
        local id = Field(entry, "id")
        local from, to = Position(Field(entry, "from")), Position(Field(entry, "to"))
        local yards = Number(Field(entry, "yards"))
        local kind = Field(entry, "kind")
        if type(id) ~= "string" or #id < 1 or #id > 80 or seen[id]
            or Field(entry, "verified") ~= true or not from or not to
            or not yards or yards < 0 or yards > 1000000
            or (kind ~= "portal" and kind ~= "flight" and kind ~= "zone"
                and kind ~= "cave" and kind ~= "path") then
            return nil, "Invalid transition at " .. index
        end
        seen[id] = true
        local first = #graph.nodes + 1
        graph.nodes[first], graph.nodes[first + 1] = from, to
        graph.transitions[#graph.transitions + 1] = {
            id = id, from = first, to = first + 1, yards = yards,
            kind = kind, bidirectional = Field(entry, "bidirectional") == true,
            ground = Field(entry, "ground") ~= false,
            flying = Field(entry, "flying") ~= false,
        }
    end
    return graph
end

local function Matrix(graph, mode, avoid)
    local key = mode .. (avoid and ":avoid" or ":all")
    if graph.cache[key] then return graph.cache[key] end
    local nodes, dist, nextHop, edgeID = graph.nodes, {}, {}, {}
    for i = 1, #nodes do
        dist[i], nextHop[i], edgeID[i] = {}, {}, {}
        for j = 1, #nodes do
            local straight = Distance(nodes[i], nodes[j])
            dist[i][j] = i == j and 0 or straight and straight * Weight(mode) or HUGE
            if dist[i][j] < HUGE then nextHop[i][j] = j end
        end
    end
    if not avoid then
        for _, edge in ipairs(graph.transitions) do
            if edge[mode] then
                local cost = edge.yards
                if cost < dist[edge.from][edge.to] then
                    dist[edge.from][edge.to] = cost
                    nextHop[edge.from][edge.to] = edge.to
                    edgeID[edge.from][edge.to] = edge.id
                end
                if edge.bidirectional and cost < dist[edge.to][edge.from] then
                    dist[edge.to][edge.from] = cost
                    nextHop[edge.to][edge.from] = edge.from
                    edgeID[edge.to][edge.from] = edge.id
                end
            end
        end
    end
    for via = 1, #nodes do
        for i = 1, #nodes do
            if dist[i][via] < HUGE then
                for j = 1, #nodes do
                    local candidate = dist[i][via] + dist[via][j]
                    if candidate < dist[i][j] then
                        dist[i][j] = candidate
                        nextHop[i][j] = nextHop[i][via]
                    end
                end
            end
        end
    end
    local result = { dist = dist, nextHop = nextHop, edgeID = edgeID }
    graph.cache[key] = result
    return result
end

local function RouteApproach(target)
    local route = Field(target, "route")
    if type(route) ~= "table" or not Safe(route) or #route < 2 then return nil, 0 end
    local first, tail = Position(route[1]), 0
    if not first then return nil, 0 end
    local previous = first
    for index = 2, math.min(#route, MAX_ROUTE_STEPS) do
        local step = Position(route[index])
        local length = step and Distance(previous, step)
        if not length then return nil, 0 end
        tail = tail + length
        previous = step
    end
    local finish = Position(target)
    local finalLength = finish and Distance(previous, finish)
    if finalLength then tail = tail + finalLength end
    return first, tail
end

-- Returns a detached estimate with costYards, basis, reason, and transition IDs.
-- Call on route or travel-state changes, not from a per-frame renderer.
function Travel.Estimate(graph, origin, target, options)
    local start, finish = Position(origin), Position(target)
    if not (start and finish) then
        return { basis = "unknown", reason = "Location unavailable" }
    end
    options = type(options) == "table" and Safe(options) and options or {}
    local mode = Mode(options)
    local approach, tail = RouteApproach(target)
    local destination = approach or finish
    local direct = Distance(start, destination)
    local directCost = direct and direct * Weight(mode) + tail * Weight(mode) or nil
    if mode == "direct" then
        return { costYards = direct and direct + tail or nil,
            basis = direct and "straight-line estimate" or "unknown",
            reason = direct and "Direct yards on the same map" or "No verified cross-map transition",
            transitions = {}, mode = mode }
    end
    if type(graph) ~= "table" or type(graph.nodes) ~= "table"
        or #graph.nodes > MAX_TRANSITIONS * 2 then
        return { costYards = directCost,
            basis = directCost and (approach and "approach estimate" or "straight-line estimate") or "unknown",
            reason = directCost and "No verified travel graph" or "No verified cross-map transition",
            transitions = {}, mode = mode }
    end
    local matrix = Matrix(graph, mode, Field(options, "avoidTransitions") == true)
    local best, entry, exit = directCost, nil, nil
    for i = 1, #graph.nodes do
        local firstLeg = Distance(start, graph.nodes[i])
        if firstLeg then
            for j = 1, #graph.nodes do
                local lastLeg = Distance(graph.nodes[j], destination)
                if lastLeg then
                    local cost = firstLeg * Weight(mode) + matrix.dist[i][j]
                        + lastLeg * Weight(mode) + tail * Weight(mode)
                    if cost < (best or HUGE) - .001 then
                        best, entry, exit = cost, i, j
                    end
                end
            end
        end
    end
    if not best then
        return { basis = "unknown", reason = "No verified cross-map transition",
            transitions = {}, mode = mode }
    end
    local used = {}
    if entry then
        local current = entry
        for _ = 1, #graph.nodes do
            if current == exit then break end
            local nextNode = matrix.nextHop[current][exit]
            if not nextNode or nextNode == current then break end
            local transitionID = matrix.edgeID[current][nextNode]
            if transitionID then used[#used + 1] = transitionID end
            current = nextNode
        end
    end
    local viaTransition = #used > 0
    return { costYards = best,
        basis = viaTransition and "verified transition estimate"
            or approach and "approach estimate" or "straight-line estimate",
        reason = viaTransition and "Verified transition with estimated travel legs"
            or approach and "Explicit approach path, estimated yards"
            or "Direct yards on the same map",
        transitions = used, mode = mode }
end

function Travel.Invalidate(graph)
    if type(graph) == "table" then graph.cache = {} end
end
