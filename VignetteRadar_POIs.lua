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
local npcNames = {}
local function Safe(value)
    return not (type(issecretvalue) == "function" and issecretvalue(value))
end

local function String(value)
    return Safe(value) and type(value) == "string" and value ~= "" and value or nil
end

local function Field(object, key)
    if not Safe(object) or type(object) ~= "table" then return nil end
    local ok, value = pcall(function() return object[key] end)
    return ok and Safe(value) and value or nil
end

local function NPCName(id)
    id = tonumber(id)
    if not id or not (C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function") then return nil end
    if npcNames[id] then return npcNames[id] end
    local ok, info = pcall(C_TooltipInfo.GetHyperlink, "unit:Creature-0-0-0-0-" .. id)
    local lines = ok and Field(info, "lines")
    local name = lines and String(Field(Field(lines, 1), "leftText"))
    if name then npcNames[id] = name end
    return name
end

local function DisplayText(value)
    value = String(value)
    if not value then return nil end
    -- Some data packs store labels as lightweight {kind:id:label} tokens.
    value = value:gsub("{npc:(%d+):([^{}]+)}", function(id, label)
        return NPCName(id) or label
    end):gsub("{npc:(%d+)}", function(id)
        return NPCName(id) or "Creature"
    end):gsub("{[^{}:]+:[^{}:]+:([^{}]+)}", "%1")
        :gsub("{[^{}]+}", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return String(value:match("^%s*(.-)%s*$"))
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
        maps[#maps + 1], seen[parent] = parent, true
        if continent ~= nil and mapType == continent then break end
    end
    return maps
end

local function Probe(handler, mapID)
    local ok, iterator, state, key = pcall(handler.GetNodes2, handler, mapID, false)
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

local function MapNameHints(mapID)
    local snapshot = sourceCache[mapID]
    if snapshot and snapshot.mapNames then return snapshot.mapNames end
    local names, seen = {}, {}
    local current = mapID
    if C_Map and type(C_Map.GetMapInfo) == "function" then
        for depth = 1, 6 do
            if type(current) ~= "number" or seen[current] then break end
            seen[current] = true
            local ok, info = pcall(C_Map.GetMapInfo, current)
            if not ok then break end
            local name = String(Field(info, "name"))
            if name then
                name = name:lower():gsub("[^%w]", "")
                if #name >= 5 then names[#names + 1] = name end
            end
            current = Field(info, "parentMapID")
        end
    end
    if snapshot then snapshot.mapNames = names end
    return names
end

local function NameAffinity(id, names)
    local lower = id:lower():gsub("[^%w]", "")
    for depth, name in ipairs(names) do
        if lower:find(name, 1, true) then return #names - depth + 1 end
    end
    return 0
end

function POIs.ResolveSource(mapID, chosen)
    if chosen == "none" or type(mapID) ~= "number" then return nil end
    local best, sticky, bestAffinity = nil, nil, -1
    local entries = POIs.ZoneSources(mapID)
    local names = chosen == "auto" and MapNameHints(mapID) or {}
    for _, entry in ipairs(entries) do
        if chosen == entry.id then return entry.id, entry.mapID end
        if chosen == "auto" and autoChoice and autoChoice.mapID == mapID
            and autoChoice.id == entry.id then sticky = entry end
        if chosen == "auto" then
            local affinity = NameAffinity(entry.id, names)
            if not best or affinity > bestAffinity
                or (affinity == bestAffinity and entry.depth < best.depth)
                or (affinity == bestAffinity and entry.depth == best.depth and entry.count > best.count)
                or (affinity == bestAffinity and entry.depth == best.depth
                    and entry.count == best.count and entry.id < best.id) then
                best, bestAffinity = entry, affinity
            end
        end
    end
    if sticky and best and NameAffinity(sticky.id, names) == bestAffinity
        and sticky.depth == best.depth then best = sticky end
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
    local name = DisplayText(Field(node, "label")) or DisplayText(Field(node, "name"))
        or DisplayText(Field(node, "title"))
    if name == "Creature" then name = NPCName(Field(node, "npc")) end
    return name or NPCName(Field(node, "npc"))
        or ({ treasure = "Treasure location", mob = "Mob location",
            item = "Item location", note = "Map note" })[kind]
end

local function Finite(value)
    return Safe(value) and type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function IconDescriptor(iconpath, scale, alpha)
    if not Safe(iconpath) then return nil end
    local descriptor = {}
    local texture = type(iconpath) == "table" and Field(iconpath, "icon") or iconpath
    if not ((type(texture) == "number" and Finite(texture) and texture > 0)
        or String(texture)) then return nil end
    descriptor.texture = texture
    if type(iconpath) == "table" then
        local left = Finite(Field(iconpath, "tCoordLeft"))
        local right = Finite(Field(iconpath, "tCoordRight"))
        local top = Finite(Field(iconpath, "tCoordTop"))
        local bottom = Finite(Field(iconpath, "tCoordBottom"))
        if left and right and top and bottom and left >= 0 and right <= 1
            and top >= 0 and bottom <= 1 and left < right and top < bottom then
            descriptor.texCoord = { left, right, top, bottom }
        end
        local r = Finite(Field(iconpath, "r"))
        local g = Finite(Field(iconpath, "g"))
        local b = Finite(Field(iconpath, "b"))
        local a = Finite(Field(iconpath, "a"))
        if r and g and b then
            descriptor.color = { math.max(0, math.min(1, r)),
                math.max(0, math.min(1, g)), math.max(0, math.min(1, b)),
                a and math.max(0, math.min(1, a)) or 1 }
        end
    end
    descriptor.scale = math.max(.6, math.min(1.5, Finite(scale) or 1))
    descriptor.alpha = math.max(0, math.min(1, Finite(alpha) or 1))
    return descriptor
end

function POIs.Collect(mapID, source, mapToWorld, mapVector)
    local results, notes = {}, HandyNotes()
    if not (notes and type(mapID) == "number" and type(source) == "string"
        and type(mapToWorld) == "function" and type(mapVector) == "function") then return results end
    local handler = notes.plugins[source]
    if not (type(handler) == "table" and type(handler.GetNodes2) == "function"
        and Enabled(notes, source)) then return results end
    local ok, iterator, state, key = pcall(handler.GetNodes2, handler, mapID, false)
    if not ok or type(iterator) ~= "function" then return results end
    for _ = 1, MAX_NODES do
        local yielded, coord, nodeMapID, iconpath, iconScale, alpha = pcall(iterator, state, key)
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
                    npcID = tonumber(Field(node, "npc")),
                    objectID = tonumber(Field(node, "object")) or tonumber(Field(node, "objectID")),
                    questID = tonumber(Field(node, "quest")),
                    note = DisplayText(Field(node, "note")),
                    icon = IconDescriptor(iconpath, iconScale, alpha),
                }
            end
        end
    end
    return results
end
