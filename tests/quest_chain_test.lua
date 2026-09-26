local addon = {}
assert(loadfile(arg[1] or "Data/QuestChain.lua"))("VignetteRadar", addon)
local Q = addon.VignetteRadarQuestChain
local source = { version = 1, chains = { { id = "one", title = "A Story",
    category = "story", source = "Trusted Fixture", completeGraph = false,
    steps = { { questID = 10, name = "Start" },
        { questID = 20, name = "Middle", requires = { 10 } },
        { questID = 30, name = "End", requires = { 20, 99 } } } } } }
local data = assert(Q.Load(source))
local states = { [10] = "complete", [20] = "active" }
local function state(id) return states[id] end
local function point(id)
    if id == 20 then return { mapID = 42, mapX = .3, mapY = .4 } end
    return { mapID = 42, mapX = 8, mapY = .4 }
end
local view = assert(Q.Inspect(data, "one", state, point))
assert(view.activeQuestID == 20 and not view.prerequisitesKnown)
assert(view.steps[2].state == "active" and view.steps[3].state == "blocked"
    and #view.steps[3].blockedBy == 1, "known incomplete edge blocks")
local chosen = assert(Q.SelectMappedStep(view, 20))
assert(chosen.mapID == 42 and chosen.mapX == .3)
assert(Q.SelectMappedStep(view, 30) == nil, "unknown coordinates cannot be invented")
states[20] = "complete"
view = assert(Q.Inspect(data, "one", state))
assert(view.steps[3].state == "unknown" and #view.steps[3].unknownBy == 1)
local cyclic = { version = 1, chains = { { id = "cycle", title = "Cycle", steps = {
    { questID = 1, name = "One", requires = { 2 } },
    { questID = 2, name = "Two", requires = { 1 } } } } } }
assert(Q.Load(cyclic) == nil, "cycles must be rejected")
assert(Q.Load({ version = 2, chains = {} }) == nil, "unknown schema must be rejected")
print("quest_chain_test: ok")
