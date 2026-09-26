local addon = {}
assert(loadfile(arg[1] or "Routes/TreasurePlaybooks.lua"))("VignetteRadar", addon)
local Playbooks = assert(addon.VignetteRadarTreasurePlaybooks)

local treasure = { key = "pack:chest", kind = "treasure", name = "Hidden Chest",
    source = "HandyNotes", mapID = 7, mapX = .4, mapY = .5,
    worldX = 40, worldY = 50, objectID = 1234,
    route = {
        { mapID = 7, mapX = .1, mapY = .2, worldX = 10, worldY = 20 },
        { mapID = 7, mapX = .3, mapY = .4, worldX = 30, worldY = 40 },
        { mapID = 7, mapX = .4, mapY = .5, worldX = 40, worldY = 50 },
    } }
local book = assert(Playbooks.New(treasure))
assert(#book.steps == 3 and book.steps[1].name == "Reach Entrance"
    and book.steps[2].kind == "location" and book.steps[3].kind == "treasure")
treasure.route[1].mapX = .9
assert(book.steps[1].mapX == .1, "recipe must be detached from mutable pack data")
assert(not Playbooks.Confirm(book, { kind = "arrival", confirmed = true }),
    "proximity cannot auto-complete an entrance")
assert(Playbooks.Next(book) and Playbooks.Current(book).name == "Follow Path 2")
assert(Playbooks.Next(book) and Playbooks.Current(book).kind == "treasure")
assert(not Playbooks.Next(book), "Next Step cannot claim the final chest was looted")
assert(not Playbooks.Confirm(book, { kind = "loot", id = 9999, confirmed = true }))
assert(not Playbooks.Confirm(book, { kind = "loot", id = 1234 }))
assert(Playbooks.Confirm(book, { kind = "loot", id = 1234, confirmed = true }))
assert(book.state == "complete" and not Playbooks.Current(book))

local explicit = assert(Playbooks.New(treasure, { source = "Vetted Recipe", steps = {
    { kind = "location", name = "Enter Cave", mapID = 7, mapX = .2, mapY = .3 },
    { kind = "interaction", name = "Pull Lever", objectID = 555 },
    { kind = "quest_condition", name = "Unlock Door", questID = 789 },
    { kind = "instruction", instruction = "Use the left passage." },
    { kind = "treasure", name = "Open Chest" },
} }))
assert(Playbooks.Next(explicit))
assert(not Playbooks.Confirm(explicit,
    { kind = "interaction", id = 444, confirmed = true }))
assert(Playbooks.Confirm(explicit,
    { kind = "interaction", id = 555, confirmed = true }))
assert(not Playbooks.Confirm(explicit,
    { kind = "quest", id = 789, complete = false, confirmed = true }))
assert(Playbooks.Confirm(explicit,
    { kind = "quest", id = 789, complete = true, confirmed = true }))
assert(Playbooks.Next(explicit) and Playbooks.Current(explicit).kind == "treasure")
assert(not Playbooks.Confirm(explicit,
    { kind = "arrival", id = 1234, confirmed = true }))
assert(Playbooks.Skip(explicit) and explicit.state == "skipped")
assert(Playbooks.Reset(explicit) and explicit.current == 1
    and explicit.steps[2].state == "pending")

assert(not Playbooks.New({ key = "bad", kind = "treasure", mapID = 7,
    mapX = 2, mapY = .1 }))
assert(not Playbooks.New(treasure, { steps = {
    { kind = "location", instruction = "At the old oak" },
} }), "free-text location must not become guessed coordinates")
local many = {}
for i = 1, 13 do many[i] = { kind = "instruction", instruction = "Go" } end
assert(not Playbooks.New(treasure, { steps = many }))
print("treasure playbook tests passed")
