local addon = {}
assert(loadfile("Data/WarbandBoard.lua"))("VignetteRadar", addon)
assert(loadfile("Data/ResetPlanner.lua"))("VignetteRadar", addon)
assert(loadfile("Data/CollectionLens.lua"))("VignetteRadar", addon)
assert(loadfile("Data/PhaseLens.lua"))("VignetteRadar", addon)
assert(loadfile("Data/QuestChain.lua"))("VignetteRadar", addon)

local db = {}
addon.GetSettings = function() return db end
local methods = {}
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetPoint(...) self.point = { ... } end
function methods:SetAllPoints() end
function methods:SetFrameStrata() end
function methods:SetClampedToScreen() end
function methods:EnableMouse() end
function methods:SetMovable() end
function methods:RegisterForDrag() end
function methods:StartMoving() end
function methods:StopMovingOrSizing() end
function methods:SetScript(event, script)
    self.scripts = self.scripts or {}
    self.scripts[event] = script
end
function methods:CreateTexture() return setmetatable({}, { __index = methods }) end
function methods:CreateFontString() return setmetatable({}, { __index = methods }) end
function methods:SetFont() end
function methods:SetJustifyH() end
function methods:SetWordWrap() end
function methods:SetText(value) self.text = value end
function methods:SetTextColor() end
function methods:SetTexture() end
function methods:SetVertexColor() end
function methods:LockHighlight() self.selected = true end
function methods:UnlockHighlight() self.selected = false end
function methods:SetEnabled(value) self.enabled = value end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, parent = parent }, { __index = methods })
    if name then _G[name] = frame end
    return frame
end
UIParent = CreateFrame("Frame")
UISpecialFrames = {}
addon.VignetteRadarControls = {
    Button = function(parent, title, width, height)
        local button = CreateFrame("Button", nil, parent)
        button:SetSize(width, height)
        button:SetText(title)
        return button
    end,
    PopupSurface = function(frame) frame.popupFace = true end,
    RefreshPopupSurface = function() end,
}
assert(loadfile("UI/Intelligence.lua"))("VignetteRadar", addon)
local ui = addon.VignetteRadarIntelligence
assert(ui and not ui.IsOpen())

local board = addon.VignetteRadarWarbandBoard.New(nil, { staleAfter = 60 })
assert(board:UpdateCharacter("Zero-Realm", { name = "Zero", goals = {
    ["rare:1"] = { eligibility = "available", evidence = "api", completion = false },
} }, 100))
assert(board:UpdateCharacter("Alt-Realm", { name = "Alt", goals = {
    ["rare:1"] = { eligibility = "available", evidence = "api", completion = false },
} }, 100))
local planner = addon.VignetteRadarResetPlanner.New()
assert(planner:SetGoal("daily:1", { name = "Daily Cache", resetKind = "daily", source = "api" }))
assert(planner:Observe("daily:1", "completed", {
    verifiedReset = true, daily = "D1", sessionID = "S1" }, 100))
local collections = addon.VignetteRadarCollectionLens.New({
    { sourceKey = "rare:1", category = "mount", rewardID = 5,
        evidence = "trusted-pack", name = "Bright Mount" },
}, function() return { collected = false, evidence = "api" } end)
local phase = addon.VignetteRadarPhaseLens.New({ action = "show" })
local chains = assert(addon.VignetteRadarQuestChain.Load({ version = 1, chains = {
    { id = "story", title = "A Story", category = "story", source = "Trusted",
        completeGraph = false, steps = {
            { questID = 10, name = "Starting Quest" },
            { questID = 20, name = "Followup", requires = { 10 } },
        } },
} }))
local selectedStep
local savedPlanner, saveCalls
saveCalls = 0
local uiContext = {
    board = board, resetPlanner = planner, collectionLens = collections,
    phaseLens = phase, chainData = chains,
    getNow = function() return 200 end,
    getCurrentCharacter = function() return "Zero-Realm" end,
    getResetPeriods = function() return { verifiedReset = true, daily = "D2" } end,
    getQuestState = function(id) if id == 10 then return "complete" end end,
    resolveQuestPoint = function(id)
        if id == 20 then return { mapID = 1, mapX = .5, mapY = .5 } end
    end,
    onSelectStep = function(step) selectedStep = step end,
    onIntelligenceChange = function(kind, changed)
        assert(kind == "resetPlanner" and changed == planner)
        saveCalls = saveCalls + 1
        savedPlanner = changed:Export()
        return true
    end,
}
ui.SetContext(uiContext)
ui.SetSelection({ goalKey = "rare:1", sourceKey = "rare:1",
    point = { key = "pack:1" }, chainID = "story" })

local warband = ui.GetView("Warband")
assert(warband.rows[1].detail:find("Unknown"),
    "stale snapshots must not say available")
assert(warband.rows[1].detail:find("Stale Snapshot"))
assert(warband.rows[1].detail:find("Saved Unknown"),
    "offline evidence must be labeled as a saved snapshot")
local reset = ui.GetView("Resets")
assert(reset.rows[1].detail:find("Unknown"),
    "selected goal must show its unknown reset status")
assert(reset.rows[2].detail:find("Expected"))
assert(reset.footer:find("never confirms"), "reset boundary must not prove availability")
local rewards = ui.GetView("Collections")
assert(rewards.rows[1].detail:find("Uncollected"))
assert(rewards.footer:find("does not prove"), "collection state cannot imply eligibility")
local phaseView = ui.GetView("Phase")
assert(phaseView.summary == "Phase: Unknown" and phaseView.rows[1].detail:find("Phase not exposed"))
local chain = ui.GetView("Quest Chains")
assert(chain.rows[2].detail:find("Mapped Location"))
assert(chain.footer:find("incomplete"), "incomplete prerequisites must be explicit")

assert(ui.Open("Quest Chains"))
local frame = VignetteRadarIntelligencePanel
assert(frame.width == 510 and frame.height == 388)
assert(frame.rows[6].point[5] == -313 and -313 - 32 > -356,
    "last row must leave a visible gutter before the footer")
assert(frame.resetActions.remove.point[4] + frame.resetActions.remove.width < 510 - 17
    and -315 - 28 > -356, "reset actions must stay inside the panel gutter")
assert(frame.tabs["Quest Chains"].selected)
frame.rows[2].scripts.OnClick(frame.rows[2])
assert(selectedStep and selectedStep.questID == 20)
assert(ui.SetEnabled("Quest Chains", false))
assert(ui.GetView("Quest Chains").summary == "Quest Chains Is Disabled")
assert(db.vignetteRadarQuestChainEnabled == false)
frame.enable.scripts.OnClick(frame.enable)
assert(db.vignetteRadarQuestChainEnabled == true)
assert(ui.Open("Resets"))
assert(frame.resetActions.daily.enabled and not frame.resetActions.remove.enabled)
frame.resetActions.daily.scripts.OnClick(frame.resetActions.daily)
assert(planner.goals["rare:1"].resetKind == "daily"
    and planner.goals["rare:1"].source == "user-rule")
assert(frame.resetActions.daily.selected and not frame.resetActions.weekly.selected,
    "the selected reset rule should be visibly marked")
assert(planner:Evaluate("rare:1", { verifiedReset = true, daily = "D2" }).status == "Unknown",
    "assigning a daily rule must not confirm availability")
assert(savedPlanner.goals["rare:1"].resetKind == "daily" and saveCalls == 1)
frame.resetActions.weekly.scripts.OnClick(frame.resetActions.weekly)
assert(planner.goals["rare:1"].resetKind == "weekly" and saveCalls == 2)
uiContext.onIntelligenceChange = function() return false end
assert(not ui.SetResetRule("one-time"))
assert(planner.goals["rare:1"].resetKind == "weekly",
    "failed persistence must restore the previous rule")
assert(not ui.SetResetRule("remove") and planner.goals["rare:1"],
    "failed removal must restore the rule")
uiContext.onIntelligenceChange = function() saveCalls = saveCalls + 1; return true end
frame.resetActions["one-time"].scripts.OnClick(frame.resetActions["one-time"])
assert(planner.goals["rare:1"].resetKind == "one-time")
frame.resetActions.remove.scripts.OnClick(frame.resetActions.remove)
assert(not planner.goals["rare:1"] and saveCalls == 4)
assert(not ui.SetResetRule("remove"), "remove requires a saved rule")
ui.SetSelection({ goalKey = "daily:1", goalName = "Daily Cache" })
assert(planner:Evaluate("daily:1", { verifiedReset = true, daily = "D2" }).status == "Expected")
assert(ui.SetResetRule("one-time"))
assert(planner:Evaluate("daily:1", { verifiedReset = true, daily = "D2" }).status == "Unknown",
    "changing reset type must discard evidence from the old period")
assert(ui.Toggle() == false and not ui.IsOpen())
assert(ui.Open("Phase") and ui.IsOpen())
frame.option.scripts.OnClick(frame.option)
assert(db.vignetteRadarPhaseLensAction == "show", "first cycle starts at Show")
frame.option.scripts.OnClick(frame.option)
assert(db.vignetteRadarPhaseLensAction == "dim")
frame.extra.scripts.OnClick(frame.extra)
assert(db.vignetteRadarPhaseHeuristics == true)
ui.Close()
assert(not ui.IsOpen())
ui.SetContext({})
ui.SetSelection({})
for _, tab in ipairs({ "Warband", "Resets", "Collections", "Phase", "Quest Chains" }) do
    local empty = ui.GetView(tab)
    assert(#empty.rows >= 1 and empty.rows[1].detail,
        "missing data must have a readable empty state for " .. tab)
end
print("Intelligence panel tests passed")
