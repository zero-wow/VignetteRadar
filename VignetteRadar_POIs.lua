local _, addon = ...
if type(addon) ~= "table" then return end

-- Map notes are possible locations supplied by one selected HandyNotes plugin.
-- Keep them separate from live vignettes so they cannot trigger detection alerts.
local POIs = {}
addon.VignetteRadarPOIs = POIs

local MAX_NODES = 768
local PROBE_NODES = 96
local SOURCE_CACHE_SECONDS = 10
local sourceCache, cacheOrder = {}, {}
local autoChoice
local function Safe(value)
    return not (type(issecretvalue) == "function" and issecretvalue(value))
end

local function String(value)
    return Safe(value) and type(value) == "string" and value ~= "" and value or nil
end

local function DisplayText(value)
    value = String(value)
    if not value then return nil end
    -- Some data packs store labels as lightweight {kind:id:label} tokens.
    return value:gsub("{[^{}:]+:[^{}:]+:([^{}]+)}", "%1")
        :gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function Field(object, key)
    if not Safe(object) or type(object) ~= "table" then return nil end
    local ok, value = pcall(function() return object[key] end)
    return ok and Safe(value) and value or nil
end

local function HandyNotes()
    local notes = _G.HandyNotes
    return type(notes) == "table" and type(notes.plugins) == "table" and notes or nil
end

local function Enabled(notes, name)
    local profile = notes.db and notes.db.profile
    local enabled = profile and profile.enabledPlugins
    return not enabled or enabled[name] ~= false
end

function POIs.Sources()
    local sources, notes = {}, HandyNotes()
    if not notes then return sources end
    for name, handler in pairs(notes.plugins) do
        if type(name) == "string" and type(handler) == "table"
            and type(handler.GetNodes2) == "function" then
            sources[#sources + 1] = { id = name, enabled = Enabled(notes, name) }
        end
    end
    table.sort(sources, function(a, b) return a.id:lower() < b.id:lower() end)
    return sources
end

local function CandidateMaps(mapID)
    local maps, seen = { mapID }, { [mapID] = true }
    if not (C_Map and type(C_Map.GetMapInfo) == "function") then return maps end
    for _ = 1, 3 do
        local ok, info = pcall(C_Map.GetMapInfo, maps[#maps])
        local parent = ok and Field(info, "parentMapID") or nil
        if type(parent) ~= "number" or parent <= 0 or seen[parent] then break end
        local parentOK, parentInfo = pcall(C_Map.GetMapInfo, parent)
        if not parentOK then break end
        local mapType = Field(parentInfo, "mapType")
        local continent = Enum and Enum.UIMapType and Enum.UIMapType.Continent
        if continent ~= nil and mapType == continent then break end
        maps[#maps + 1], seen[parent] = parent, true
    end
    return maps
end

local function Probe(handler, mapID)
    local ok, iterator, state, key = pcall(handler.GetNodes2, handler, mapID, true)
    if not ok or type(iterator) ~= "function" then return 0 end
    local count = 0
    for _ = 1, MAX_NODES do
        local yielded, coord, _, _, _, alpha = pcall(iterator, state, key)
        if not yielded or not Safe(coord) or type(coord) ~= "number" then break end
        key = coord
        if coord >= 0 and coord < 100010000 and Safe(alpha)
            and (type(alpha) ~= "number" or alpha > 0) then
            count = count + 1
            if count >= PROBE_NODES then break end
        end
    end
    return count
end

-- Query each registered pack for the current map, then its immediate zone
-- ancestors. A short cache keeps config redraws and one-second scans cheap.
function POIs.ZoneSources(mapID)
    local notes = HandyNotes()
    if not (notes and type(mapID) == "number" and Safe(mapID)) then return {} end
    local now = type(GetTime) == "function" and GetTime() or nil
    local registryCount = 0
    for _ in pairs(notes.plugins) do registryCount = registryCount + 1 end
    local snapshot = sourceCache[mapID]
    if snapshot and snapshot.registryCount == registryCount
        and now and snapshot.at and now - snapshot.at < SOURCE_CACHE_SECONDS then
        local cached = {}
        for _, entry in ipairs(snapshot.entries) do
            if Enabled(notes, entry.id) then cached[#cached + 1] = entry end
        end
        return cached
    end
    local maps, entries = CandidateMaps(mapID), {}
    for name, handler in pairs(notes.plugins) do
        if type(name) == "string" and type(handler) == "table"
            and type(handler.GetNodes2) == "function" and Enabled(notes, name) then
            for depth, candidate in ipairs(maps) do
                local count = Probe(handler, candidate)
                if count > 0 then
                    entries[#entries + 1] = { id = name, enabled = true,
                        mapID = candidate, depth = depth - 1, count = count }
                    break
                end
            end
        end
    end
    table.sort(entries, function(a, b) return a.id:lower() < b.id:lower() end)
    if not snapshot then
        cacheOrder[#cacheOrder + 1] = mapID
        if #cacheOrder > 8 then sourceCache[table.remove(cacheOrder, 1)] = nil end
    end
    sourceCache[mapID] = { registryCount = registryCount, at = now, entries = entries }
    return entries
end

function POIs.ResolveSource(mapID, chosen)
    if chosen == "none" or type(mapID) ~= "number" then return nil end
    local best
    for _, entry in ipairs(POIs.ZoneSources(mapID)) do
        if chosen == entry.id then return entry.id, entry.mapID end
        if chosen == "auto" and autoChoice and autoChoice.mapID == mapID
            and autoChoice.id == entry.id then return entry.id, entry.mapID end
        if chosen == "auto" and (not best or entry.depth < best.depth
            or (entry.depth == best.depth and entry.count > best.count)
            or (entry.depth == best.depth and entry.count == best.count and entry.id < best.id)) then
            best = entry
        end
    end
    if chosen == "auto" then autoChoice = best and { mapID = mapID, id = best.id } or nil end
    return best and best.id or nil, best and best.mapID or nil
end

local function GroupName(node)
    local group = Field(node, "group")
    if type(group) == "table" then
        local first = group[1] or group
        return String(Field(first, "name")) or String(Field(first, "label")) or ""
    end
    return String(group) or ""
end

function POIs.Kind(node, source)
    local group = GroupName(node):lower()
    local class = (String(Field(node, "class")) or ""):lower()
    local text = group .. " " .. class
    if text:find("profession", 1, true) or text:find("item", 1, true) then return "item" end
    if text:find("treasur", 1, true) or text:find("chest", 1, true)
        or text:find("container", 1, true) then return "treasure" end
    if text:find("rare", 1, true) or text:find("boss", 1, true)
        or Field(node, "npc") then return "mob" end
    local lowerSource = (source or ""):lower()
    if lowerSource:find("treasur", 1, true) then return "treasure" end
    if Field(node, "loot") then return "item" end
    if lowerSource:find("rare", 1, true) then return "mob" end
    return "note"
end

local function Name(node, kind)
    return DisplayText(Field(node, "label")) or DisplayText(Field(node, "name"))
        or DisplayText(Field(node, "title"))
        or ({ treasure = "Treasure location", mob = "Mob location",
            item = "Item location", note = "Map note" })[kind]
end

function POIs.Collect(mapID, source, mapToWorld, mapVector)
    local results, notes = {}, HandyNotes()
    if not (notes and type(mapID) == "number" and type(source) == "string"
        and type(mapToWorld) == "function" and type(mapVector) == "function") then return results end
    local handler = notes.plugins[source]
    if not (type(handler) == "table" and type(handler.GetNodes2) == "function"
        and Enabled(notes, source)) then return results end
    local ok, iterator, state, key = pcall(handler.GetNodes2, handler, mapID, true)
    if not ok or type(iterator) ~= "function" then return results end
    for _ = 1, MAX_NODES do
        local yielded, coord, nodeMapID, _, _, alpha = pcall(iterator, state, key)
        if not yielded or not Safe(coord) or type(coord) ~= "number" then break end
        if coord == nil then break end
        key = coord
        local x, y = math.floor(coord / 10000) / 10000, (coord % 10000) / 10000
        local pointMapID = type(nodeMapID) == "number" and Safe(nodeMapID) and nodeMapID or mapID
        if x >= 0 and x <= 1 and y >= 0 and y <= 1 and Safe(alpha)
            and (type(alpha) ~= "number" or alpha > 0) then
            local node = Field(state, coord)
            local kind = POIs.Kind(node, source)
            local converted, worldX, worldY, instanceID = pcall(function()
                return mapToWorld(pointMapID, mapVector(x, y))
            end)
            if converted and type(worldX) == "number" and type(worldY) == "number" then
                results[#results + 1] = {
                    key = source .. ":" .. pointMapID .. ":" .. coord,
                    mapID = pointMapID, mapX = x, mapY = y,
                    worldX = worldX, worldY = worldY, instanceID = instanceID,
                    source = source, kind = kind, name = Name(node, kind),
                    note = DisplayText(Field(node, "note")),
                }
            end
        end
    end
    return results
end
