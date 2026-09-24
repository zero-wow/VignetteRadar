local _, addon = ...
if type(addon) ~= "table" then return end

-- Map notes are possible locations supplied by one selected HandyNotes plugin.
-- Keep them separate from live vignettes so they cannot trigger detection alerts.
local POIs = {}
addon.VignetteRadarPOIs = POIs

local MAX_NODES = 768
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
