local addon = {}
local now, clock = 0, 0
local messages = {}
GetTime = function() return now end
debugprofilestop = function() return clock end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
assert(loadfile("Core/LayerBudget.lua"))("VignetteRadar", addon)
local B = addon.VignetteRadarLayerBudget

assert(B.ShouldRun("questBlobs"))
B.Record("questBlobs", 8, now)
now = 1
assert(B.ShouldRun("questBlobs"))
B.Record("questBlobs", 8, now)
now = 2
assert(B.ShouldRun("questBlobs"))
assert(B.Status("questBlobs").level == 1, "two busy windows should slow only the costly layer")
assert(B.Status("mapNotes").level == 0 and B.Status("trail").level == 0)
now = 2.1
assert(not B.ShouldRun("questBlobs"), "backoff should avoid repeated expensive draws")
now = 2.3
assert(B.ShouldRun("questBlobs"), "backoff should keep probing for recovery")
B.Record("questBlobs", .5, now)
for second = 3, 9 do
    now = second
    assert(B.ShouldRun("questBlobs"))
    B.Record("questBlobs", .5, now)
end
assert(B.Status("questBlobs").level == 0,
    "quiet probe windows should restore the selected drawing rate automatically")
assert(#messages == 2, "a slowdown and full recovery should each be announced once")

now = 20
clock = 100
local parent = B.Begin("render", true)
clock = 105
local child = B.Begin("trail", true)
clock = 108
B.Finish(child)
clock = 115
B.Finish(parent)
now = 21
B.ShouldRun("render", true)
B.ShouldRun("trail", true)
assert(B.Status("render").millisecondsPerSecond == 12,
    "parent rendering should exclude measured child work")
assert(B.Status("trail").millisecondsPerSecond == 3)
assert(B.StatusLine():find("quest areas", 1, true))

now = 30
B.Record("mapNotes", 50, now)
assert(B.Status("mapNotes").level == 1,
    "a single stalled layer should get an immediate limited backoff")
assert(B.Status("render").level == 0,
    "layer backoff must not indiscriminately throttle the whole radar")
print("VignetteRadar layer-budget tests passed")
