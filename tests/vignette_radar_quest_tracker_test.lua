local sourcePath = arg[1] or "UI/QuestTracker.lua"

local objects = {}
local methods = {}
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetPoint(...) self.point = { ... } end
function methods:ClearAllPoints() self.point = nil end
function methods:SetAllPoints() end
function methods:SetFrameStrata(value) self.strata = value end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:SetMovable(value) self.movable = value end
function methods:EnableMouse(value) self.mouse = value end
function methods:EnableMouseWheel(value) self.mouseWheel = value end
function methods:RegisterForDrag(value) self.dragButton = value end
function methods:RegisterEvent(value) self.events = self.events or {}; self.events[value] = true end
function methods:SetScript(key, value) self.scripts = self.scripts or {}; self.scripts[key] = value end
function methods:StartMoving() self.moving = true end
function methods:StopMovingOrSizing() self.moving = false end
function methods:GetLeft() return self.left or 290 end
function methods:GetRight() return self.right or ((self.left or 290) + (self.width or 0)) end
function methods:GetTop() return self.top or 740 end
function methods:GetBottom() return self.bottom or ((self.top or 740) - (self.height or 0)) end
function methods:SetText(value) self.text = value end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:SetFont(...) self.font = { ... } end
function methods:SetJustifyH(value) self.justify = value end
function methods:SetWordWrap(value) self.wrap = value end
function methods:SetTexture(value) self.texture = value end
function methods:SetVertexColor(...) self.vertex = { ... } end
function methods:SetColorTexture(...) self.color = { ... } end
function methods:IsShown() return self.shown == true end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(value) self.shown = value == true end
function methods:CreateTexture()
    return setmetatable({ shown = true }, { __index = methods })
end
function methods:CreateFontString()
    return setmetatable({ shown = true }, { __index = methods })
end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, parent = parent, shown = true }, { __index = methods })
    if name then _G[name] = frame end
    objects[#objects + 1] = frame
    return frame
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1600, 900)
local radarPanel = CreateFrame("Frame", nil, UIParent)
radarPanel:SetSize(246, 278)
radarPanel.left, radarPanel.top = 30, 380
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local settings = { vignetteRadarQuestTrackerVisible = true,
    vignetteRadarQuestTrackerScope = "local", vignetteRadarQuestTrackerCollapsed = {},
    vignetteRadarQuestDots = true, vignetteRadarQuestNumbers = false }
local highlights, focused, refreshes = {}, nil, 0
local addon = {
    GetSettings = function() return settings end,
    VignetteRadarQuestColors = { { .3, .6, 1 }, { 1, .7, .3 }, { .7, .4, 1 } },
    VignetteRadarStyle = { revision = 0, Color = function() return .3, .7, .9 end },
    VignetteRadarControls = {
        Button = function(parent, label, w, h)
            local button = CreateFrame("Button", nil, parent)
            button:SetSize(w, h)
            button:SetText(label)
            return button
        end,
        RoundedStatusSurface = function(frame) frame.statusSurface = true end,
        RefreshRoundedStatusSurface = function() end,
    },
    VignetteRadarQuestData = { GetObjectiveSummary = function(id)
        if id == 11 then return { label = "Collect Shells", count = "1/4" } end
    end },
    VignetteRadarExploration = {
        GetFocusedQuest = function() return focused end,
        FocusQuest = function(id) focused = focused == id and nil or id end,
    },
    VignetteRadarAPI = {
        GetPanel = function() return radarPanel end,
        GetCurrentMapID = function() return 84 end,
        GetQuests = function() return { { questID = 11, mapID = 84, colorSlot = 2 },
            { questID = 22, mapID = 99, colorSlot = 1 } } end,
        GetQuestColorSlot = function(id) return id == 11 and 2 or 3 end,
        HighlightQuest = function(id) highlights[#highlights + 1] = id or "clear" end,
    },
    RefreshVignetteRadar = function() refreshes = refreshes + 1 end,
}
C_QuestLog = {
    GetQuestsOnMap = function() return { { questID = 11 }, { questID = 33 } } end,
    GetNumQuestLogEntries = function() return 5 end,
    GetInfo = function(index)
        return ({
            { isHeader = true, title = "Dragon Isles" },
            { questID = 11, title = "Shell Search", difficultyLevel = 78 },
            { questID = 22, title = "Faraway Errand", difficultyLevel = 70 },
            { isHeader = true, title = "Old World" },
            { questID = 33, title = "Local History", difficultyLevel = 80 },
        })[index]
    end,
    GetNumQuestWatches = function() return 1 end,
    GetQuestIDForQuestWatchIndex = function() return 22 end,
    GetNextWaypointForMap = function() return nil end,
    IsComplete = function(id) return id == 33 end,
    IsWorldQuest = function() return false end,
    GetTitleForQuestID = function(id) return id == 44 and "World Event" end,
}
C_TaskQuest = { GetQuestsOnMap = function()
    return { { questID = 44, isWorldQuest = true } }
end }
GetQuestDifficultyColor = function(level)
    return level == 78 and { r = 1, g = .6, b = .2 } or { r = .7, g = .8, b = .9 }
end

assert(loadfile(sourcePath))("VignetteRadar", addon)
local tracker = assert(addon.VignetteRadarQuestTracker)
local localEntries = tracker.BuildEntries(84, "local")
assert(#localEntries == 6, "local scope should retain only populated quest-log headers and task quests")
assert(localEntries[1].title == "Dragon Isles" and localEntries[1].count == 1
    and localEntries[2].questID == 11 and localEntries[2].colorSlot == 2,
    "a local quest must keep its visible header and exact radar color slot")
assert(localEntries[3].title == "Old World" and localEntries[4].complete == true,
    "a second local header and ready quest should remain distinct")
assert(localEntries[5].title == "World Quests" and localEntries[6].questID == 44,
    "map tasks absent from the quest log should still surface")
local watched = tracker.BuildEntries(84, "watched")
assert(#watched == 2 and watched[1].title == "Dragon Isles" and watched[2].questID == 22,
    "watched scope must include an out-of-zone watched quest without empty headers")

local eventFrame
for _, object in ipairs(objects) do
    if object.events and object.events.PLAYER_LOGIN then eventFrame = object end
end
assert(eventFrame and eventFrame.events.QUEST_LOG_UPDATE)
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOGIN")
local panel = assert(_G.VignetteRadarQuestTrackerPanel)
assert(panel:IsShown() and panel.clamped and panel.movable and panel.mouseWheel,
    "the tracker must be visible, movable, and scrollable by default")
assert(not panel.accent and panel.statusSurface and panel.count.text == "3 QUESTS",
    "the tracker should use the shared surface without a left accent bar")
assert(panel.rows[2].entry.questID == 11 and panel.rows[2].name.textColor[2] == .6
    and panel.rows[2].diamond.vertex[2] == .7,
    "difficulty title and radar diamond must use independent colors")
panel.rows[2].scripts.OnEnter(panel.rows[2])
assert(highlights[#highlights] == 11, "hover should highlight matching radar diamonds")
panel.rows[2].scripts.OnLeave(panel.rows[2])
assert(highlights[#highlights] == "clear", "leaving should restore radar selection")
panel.rows[2].scripts.OnClick(panel.rows[2])
assert(focused == 11, "clicking a tracker quest should focus that quest")
panel.dots.scripts.OnClick(panel.dots)
assert(settings.vignetteRadarQuestDots == false and refreshes == 1)
panel.numbers.scripts.OnClick(panel.numbers)
assert(settings.vignetteRadarQuestNumbers == true and refreshes == 2)
panel.mode.scripts.OnClick(panel.mode)
assert(settings.vignetteRadarQuestTrackerView == "tray"
    and panel.mode.text == "Tray" and panel.side.text == "Right"
    and panel.point[1] == "TOPLEFT" and panel.point[3] == "TOPRIGHT"
    and panel.connector.shown,
    "Tray view should dock beside the radar and show a themed join")
settings.vignetteRadarQuestTrackerSide = "top"
tracker.Refresh()
assert(panel.point[1] == "BOTTOMLEFT" and panel.point[3] == "TOPLEFT"
    and panel.connector.width == 2 and panel.connector.height == 6,
    "the upper tray should emerge vertically from the radar")
settings.vignetteRadarQuestTrackerCollapsed = {
    ["Dragon Isles"] = true, ["Old World"] = true, ["World Quests"] = true,
}
radarPanel.left, radarPanel.top = 700, 540
settings.vignetteRadarQuestTrackerSide = "bottom"
tracker.Refresh()
assert(panel.height == 236 and panel.point[1] == "TOPLEFT"
    and panel.point[3] == "BOTTOMLEFT" and panel.connector.height == 6,
    "the lower tray should fit below the radar with folded quest headers")
settings.vignetteRadarQuestTrackerSide = "left"
tracker.Refresh()
assert(panel.point[1] == "TOPRIGHT" and panel.point[3] == "TOPLEFT"
    and panel.connector.width == 6,
    "the left tray should emerge horizontally from the radar")
radarPanel.left = 1300
settings.vignetteRadarQuestTrackerSide = "right"
tracker.Refresh()
assert(panel.actualSide == "left" and panel.side.text == "Left"
    and panel.point[1] == "TOPRIGHT",
    "Tray must switch to an edge that fits rather than cover the radar")
radarPanel:Hide()
panel.scripts.OnUpdate(panel, 1)
assert(panel.point[2] == UIParent and not panel.connector.shown,
    "Tray should use the saved floating position while the radar is hidden")
radarPanel:Show()
panel.scripts.OnUpdate(panel, 1)
assert(panel.point[2] == radarPanel and panel.connector.shown,
    "Tray should redock as soon as the radar is visible again")
panel.mode.scripts.OnClick(panel.mode)
assert(settings.vignetteRadarQuestTrackerView == "floating"
    and panel.mode.text == "Floating" and panel.point[2] == UIParent,
    "Floating view should restore its independent saved placement")
panel.close.scripts.OnClick(panel.close)
assert(not panel:IsShown() and settings.vignetteRadarQuestTrackerVisible == false)
assert(tracker.Toggle() and panel:IsShown(), "the settings button should restore the tracker")
print("quest tracker data, identity, interaction, and default visibility ok")
