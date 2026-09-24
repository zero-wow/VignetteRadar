local addon = {}
assert(loadfile("VignetteRadar_POIs.lua"))("VignetteRadar", addon)
local pois = addon.VignetteRadarPOIs
assert(#pois.Sources() == 0 and #pois.Collect(123, "Missing", function() end, function() end) == 0)

local nodes = {
    [50005000] = { label = "Hidden chest", group = { { name = "treasures" } } },
    [51005000] = { label = "Ancient chest", group = { { name = "treasures" } } },
    [52005000] = { label = "Named rare", group = { { name = "rares" } }, npc = 123 },
    [53005000] = { label = "Profession item", group = { { name = "profession_treasures" } }, loot = 456 },
    [54005000] = { label = "{npc:123:Travel point}", group = { { name = "misc" } }, note = "On the ridge" },
}
local keys = { 50005000, 51005000, 52005000, 53005000, 54005000 }
local calls = 0
HandyNotes = { plugins = {
    Midnight = { GetNodes2 = function(_, mapID, minimap)
        assert(mapID == 123 and minimap == true)
        calls = calls + 1
        local index = 1
        return function()
            index = index + 1 -- simulate plugin hiding the first, completed chest
            local coord = keys[index]
            local icons = {
                [51005000] = { icon = 134400, tCoordLeft = .1, tCoordRight = .9,
                    tCoordTop = .2, tCoordBottom = .8, r = .8, g = .6, b = .4, a = .75 },
                [52005000] = 123456,
                [53005000] = "Interface\\Icons\\INV_Misc_QuestionMark",
            }
            return coord, nil, icons[coord], 1.3, .6
        end, nodes, nil
    end },
    Disabled = { GetNodes2 = function() error("disabled source queried") end },
}, db = { profile = { enabledPlugins = { Midnight = true, Disabled = false } } } }
local sources = pois.Sources()
assert(#sources == 2 and sources[1].id == "Disabled" and not sources[1].enabled
    and sources[2].id == "Midnight" and sources[2].enabled)
local results = pois.Collect(123, "Midnight", function(mapID, vector)
    assert(mapID == 123)
    return vector.x * 1000, vector.y * 1000, 42
end, function(x, y) return { x = x, y = y } end)
assert(calls == 1 and #results == 4, "only yielded, enabled nodes should be copied")
assert(results[1].kind == "treasure" and results[1].name == "Ancient chest"
    and results[1].worldX == 510 and results[1].worldY == 500)
assert(results[2].kind == "mob" and results[3].kind == "item"
    and results[4].kind == "note" and results[4].name == "Travel point"
    and results[4].note == "On the ridge")
assert(results[1].icon.texture == 134400 and results[1].icon.texCoord[1] == .1
    and results[1].icon.texCoord[4] == .8 and results[1].icon.color[1] == .8
    and results[1].icon.color[4] == .75 and results[1].icon.scale == 1.3
    and results[1].icon.alpha == .6 and results[2].icon.texture == 123456
    and results[3].icon.texture == "Interface\\Icons\\INV_Misc_QuestionMark"
    and results[4].icon == nil,
    "the pack's own file ID, path, crop, tint, and opacity must survive collection")
assert(#pois.Collect(123, "Disabled", function() error("converted disabled source") end,
    function() end) == 0)
assert(pois.Kind(nil, "MidnightTreasures") == "treasure"
    and pois.Kind({ loot = { 123 } }, "MidnightTreasures") == "treasure"
    and pois.Kind({ npc = 123, loot = { 456 } }, "MidnightTreasures") == "mob"
    and pois.Kind(nil, "RareLocations") == "mob"
    and pois.Kind(nil, "GeneralMapPack") == "note")

local now = 100
GetTime = function() return now end
Enum = { UIMapType = { Continent = 2 } }
C_Map = { GetMapInfo = function(mapID)
    if mapID == 125 then return { parentMapID = 124, mapType = 5 } end
    if mapID == 124 then return { parentMapID = 2, mapType = 3 } end
    return { parentMapID = 0, mapType = 3 }
end }
local otherZoneCalls = 0
HandyNotes.plugins.OtherZone = { GetNodes2 = function(_, mapID)
    otherZoneCalls = otherZoneCalls + 1
    if mapID ~= 124 then return function() end, {}, nil end
    local done = false
    return function()
        if done then return nil end
        done = true
        return 52005000, nil, nil, 1, 1
    end, { [52005000] = { label = "Other zone" } }, nil
end }
local zoneSources = pois.ZoneSources(123)
assert(#zoneSources == 1 and zoneSources[1].id == "Midnight"
    and zoneSources[1].mapID == 123 and zoneSources[1].count == 4,
    "current-zone sources must exclude unrelated and disabled packs")
local chosen, dataMap = pois.ResolveSource(123, "auto")
assert(chosen == "Midnight" and dataMap == 123)
chosen, dataMap = pois.ResolveSource(125, "auto")
assert(chosen == "OtherZone" and dataMap == 124,
    "a zone pack on the parent map must be found from a nested map")
assert(pois.ResolveSource(125, "Midnight") == nil
    and pois.ResolveSource(125, "none") == nil,
    "manual sources must not leak data into unrelated zones")
local callsBeforeCache = otherZoneCalls
assert(#pois.ZoneSources(125) == 1 and otherZoneCalls == callsBeforeCache,
    "repeated source lookups must reuse the map snapshot")
local previousZoneCalls = calls
pois.ZoneSources(123)
assert(calls == previousZoneCalls,
    "crossing between nearby map IDs must retain both recent source snapshots")
HandyNotes.plugins.SparseZone = { GetNodes2 = function(_, mapID)
    if mapID ~= 123 then return function() end, {}, nil end
    local done = false
    return function()
        if done then return nil end
        done = true
        return 50005000, nil, nil, 1, 1
    end, {}, nil
end }
chosen, dataMap = pois.ResolveSource(123, "auto")
assert(chosen == "Midnight" and dataMap == 123,
    "Auto must prefer the pack with more current-zone notes")
HandyNotes.plugins.DenseZone = { GetNodes2 = function(_, mapID)
    if mapID ~= 123 then return function() end, {}, nil end
    local index = 0
    return function()
        index = index + 1
        if index > 8 then return nil end
        return 50000000 + index * 10000, nil, nil, 1, 1
    end, {}, nil
end }
chosen = pois.ResolveSource(123, "auto")
assert(chosen == "Midnight", "Auto should not change packs mid-zone as note counts update")
assert(#pois.ZoneSources(999) == 0, "unrelated zones must show no data packs")
local tooltipCalls = 0
C_TooltipInfo = { GetHyperlink = function(link)
    tooltipCalls = tooltipCalls + 1
    assert(link == "unit:Creature-0-0-0-0-245699")
    return { lines = { { leftText = "Ancient Watcher" } } }
end }
HandyNotes.plugins.TokenPack = { GetNodes2 = function()
    local done = false
    return function()
        if done then return nil end
        done = true
        return 55005500, nil, nil, 1, 1
    end, { [55005500] = { label = "{npc:245699}", npc = 245699,
        group = "rares", quest = 12345, note = "Find {npc:245699} here." } }, nil
end }
local tokenNotes = pois.Collect(123, "TokenPack", function(_, vector)
    return vector.x * 1000, vector.y * 1000, 42
end, function(x, y) return { x=x, y=y } end)
assert(#tokenNotes == 1 and tokenNotes[1].name == "Ancient Watcher"
    and tokenNotes[1].note == "Find Ancient Watcher here."
    and tokenNotes[1].npcID == 245699 and tokenNotes[1].questID == 12345
    and tooltipCalls == 1,
    "numeric NPC tokens must resolve to the real name and cache repeat lookups")
io.write("vignette radar map-note tests passed\n")
