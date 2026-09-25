local source = arg[1] or "VignetteRadar_Beacons.lua"
local settings = {
    vignetteRadarEnabled = true, vignetteRadarBeaconsEnabled = false,
    vignetteRadarBeaconRares = true, vignetteRadarBeaconQuests = true,
    vignetteRadarBeaconRange = 450, vignetteRadarBeaconMax = 8,
    vignetteRadarPOISource = "auto", vignetteRadarPOITypes = { mob = true },
    vignetteRadarQuestColors = true,
}
local addon = {
    GetSettings = function() return settings end,
    VignetteRadarStyle = { Color = function(slot)
        if slot == "rare" then return .8, .9, 1 end
        if slot == "boss" then return 1, .2, .1 end
        return .6, .8, 1
    end },
    VignetteRadarQuestColors = { { .3, .7, 1 } },
}
assert(loadfile(source))("VignetteRadar", addon)
local beacons = addon.VignetteRadarBeacons

CreateFrame = function() error("disabled beacons must not create a frame") end
beacons.Sync(1, { worldX = 0, worldY = 0 }, {}, {}, {})

local player = { worldX = 0, worldY = 0, instanceID = 8 }
local rare = { key = "rare-1", name = "Live rare", category = "rare",
    mapX = .4, mapY = .3, worldX = 100, worldY = 0, instanceID = 8 }
local boss = { key = "boss-1", name = "World boss", category = "rare", isWorldBoss = true,
    mapX = .2, mapY = .3, worldX = 300, worldY = 0, instanceID = 8 }
local stale = { key = "stale", category = "rare", stale = true,
    mapX = .1, mapY = .3, worldX = 50, worldY = 0, instanceID = 8 }
local quest = { questID = 17, name = "Find the stones", colorSlot = 1,
    mapX = .6, mapY = .3, worldX = 80, worldY = 10, instanceID = 8 }
local notes = {
    { kind = "mob", name = "Duplicate note", mapX = .41, mapY = .3,
        worldX = 120, worldY = 0, instanceID = 8 },
    { kind = "mob", name = "Other rare", mapX = .8, mapY = .3,
        worldX = 240, worldY = 0, instanceID = 8 },
    { kind = "treasure", name = "Not a rare", mapX = .9, mapY = .3,
        worldX = 250, worldY = 0, instanceID = 8 },
}
local result = beacons.BuildCandidates(1, player, { rare, boss, stale }, { quest }, notes,
    function() return true end, settings)
assert(#result == 4, "show live rare, boss, quest point, and nonduplicate data rare")
assert(result[1].name == "World boss" and result[1].r == 1,
    "bosses take priority and keep their theme color")
assert(result[2].name == "Live rare" and result[3].name == "Other rare",
    "a live rare should suppress the nearby data-pack copy")
assert(result[4].kind == "quest" and result[4].r == .3,
    "quest diamonds should use their radar quest color")

settings.vignetteRadarBeaconMax = 4
local moreQuests = { quest }
for index = 1, 4 do
    moreQuests[#moreQuests + 1] = { questID = 17 + index, name = "Other objective",
        mapX = .5, mapY = .4, worldX = 90 + index, worldY = 25, instanceID = 8 }
end
assert(#beacons.BuildCandidates(1, player, { rare, boss }, moreQuests, notes, nil, settings) == 4,
    "the visible candidate limit must be enforced before creating buttons")
settings.vignetteRadarBeaconMax = 8
settings.vignetteRadarBeaconQuests = false
assert(#beacons.BuildCandidates(1, player, { rare }, { quest }, {}, nil, settings) == 1,
    "quest points can be turned off independently")
settings.vignetteRadarBeaconQuests = true
settings.vignetteRadarBeaconRange = 150
local farRare = { key = "far", category = "rare", mapX = .2, mapY = .4,
    worldX = 200, worldY = 0, instanceID = 8 }
assert(#beacons.BuildCandidates(1, player, { farRare }, { quest }, {}, nil, settings) == 1,
    "the range filter must exclude distant rares")
assert(#beacons.BuildCandidates(1, player, { rare }, {}, {}, function() return false end, settings) == 0,
    "ignored or filtered live rares must stay hidden")

print("beacon candidate tests passed")
