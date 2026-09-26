local addon = {}
assert(loadfile(arg[1] or "Routes/TravelAware.lua"))("VignetteRadar", addon)
local Travel = assert(addon.VignetteRadarTravelAware)

local origin = { mapID = 1, worldX = 0, worldY = 0 }
local nearby = { mapID = 1, worldX = 90, worldY = 0 }
local estimate = Travel.Estimate(nil, origin, nearby, { mode = "ground" })
assert(estimate.costYards == 90 and estimate.basis == "straight-line estimate")
local remote = { mapID = 2, worldX = 905, worldY = 0 }
assert(Travel.Estimate(nil, origin, remote).basis == "unknown",
    "unmapped cross-map distance must not be guessed")

local graph = assert(Travel.New({
    { id = "gate", kind = "portal", verified = true, yards = 10,
        from = { mapID = 1, worldX = 10, worldY = 0 },
        to = { mapID = 2, worldX = 900, worldY = 0 } },
}))
local via = Travel.Estimate(graph, origin, remote, { mode = "ground" })
assert(via.costYards == 25 and via.basis == "verified transition estimate"
    and via.transitions[1] == "gate", "verified portal should connect maps")
assert(Travel.Estimate(graph, origin, remote,
    { mode = "ground", avoidTransitions = true }).basis == "unknown",
    "avoid-transitions should not invent a cross-map path")
assert(Travel.Estimate(graph, origin, remote, { mode = "flying" }).costYards == 20.5,
    "flight mode should change open-leg estimates without altering portal cost")
assert(graph.cache["ground:all"] and graph.cache["flying:all"])
Travel.Invalidate(graph)
assert(next(graph.cache) == nil, "graph cache should be cancellable")

local mountain = { mapID = 1, worldX = 80, worldY = 0, route = {
    { mapID = 1, worldX = 100, worldY = 0 },
    { mapID = 1, worldX = 80, worldY = 0 },
} }
local longApproach = Travel.Estimate(nil, origin, mountain)
assert(longApproach.costYards == 120 and longApproach.basis == "approach estimate"
    and longApproach.costYards > Travel.Estimate(nil, origin, nearby).costYards,
    "explicit approach can rank a closer mountain chest behind an open route")
assert(not Travel.New({ { id = "unverified", kind = "portal", yards = 1,
    from = origin, to = remote } }), "unverified edges are invalid")
local overLimit = {}
for index = 1, 25 do overLimit[index] = {} end
assert(not Travel.New(overLimit), "transition counts must remain bounded")
print("travel aware tests passed")
