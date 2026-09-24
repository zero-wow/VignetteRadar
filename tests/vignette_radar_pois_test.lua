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
            return coord, nil, nil, 1, 1
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
assert(#pois.Collect(123, "Disabled", function() error("converted disabled source") end,
    function() end) == 0)
assert(pois.Kind(nil, "MidnightTreasures") == "treasure"
    and pois.Kind({ loot = { 123 } }, "MidnightTreasures") == "treasure"
    and pois.Kind({ npc = 123, loot = { 456 } }, "MidnightTreasures") == "mob"
    and pois.Kind(nil, "RareLocations") == "mob"
    and pois.Kind(nil, "GeneralMapPack") == "note")
io.write("vignette radar map-note tests passed\n")
