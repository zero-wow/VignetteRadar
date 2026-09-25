local sourcePath = arg[1] or "UI/Options.lua"

local objects = {}
local methods = {}
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
function methods:SetAllPoints(...) self.allPoints = { ... } end
function methods:ClearAllPoints() self.points = {} end
function methods:SetFontString(value) self.fontString = value end
function methods:SetText(value) self.text = value; if self.fontString then self.fontString:SetText(value) end end
function methods:SetFont(...) self.font = { ... } end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:SetBackdrop(value) self.backdrop = value end
function methods:SetBackdropColor(...) self.backdropColor = { ... } end
function methods:SetBackdropBorderColor(...) self.backdropBorderColor = { ... } end
function methods:SetAlpha(value) self.alpha = value end
function methods:SetColorTexture(...) self.color = { ... } end
function methods:SetTexture(value) self.texture = value end
function methods:SetVertexColor(...) self.vertexColor = { ... } end
function methods:SetThickness(value) self.thickness = value end
function methods:SetStartPoint(...)
    assert(select("#", ...) == 4, "line endpoints take anchor, frame, x, y")
    self.startPoint = { ... }
    assert(type(self.startPoint[3]) == "number" and type(self.startPoint[4]) == "number")
end
function methods:SetEndPoint(...)
    assert(select("#", ...) == 4, "line endpoints take anchor, frame, x, y")
    self.endPoint = { ... }
    assert(type(self.endPoint[3]) == "number" and type(self.endPoint[4]) == "number")
end
function methods:SetWordWrap(value) self.wordWrap = value end
function methods:SetJustifyH(value) self.justifyH = value end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled = value end
function methods:LockHighlight() self.highlightLocked = true end
function methods:UnlockHighlight() self.highlightLocked = false end
function methods:SetScript(name, callback) self.scripts = self.scripts or {}; self.scripts[name] = callback end
function methods:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:SetFrameStrata(value) self.strata = value end
function methods:Show() self.shown = true; if self.scripts and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown == true end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:CreateTexture()
    local texture = setmetatable({ kind = "Texture", parent = self }, { __index = methods })
    objects[#objects + 1] = texture
    return texture
end
function methods:CreateLine()
    local line = setmetatable({ kind = "Line", parent = self }, { __index = methods })
    objects[#objects + 1] = line
    return line
end
function methods:CreateFontString()
    local label = setmetatable({ kind = "FontString", parent = self }, { __index = methods })
    objects[#objects + 1] = label
    return label
end
function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, name = name, parent = parent, enabled = true }, { __index = methods })
    objects[#objects + 1] = frame
    if name then _G[name] = frame end
    return frame
end

UIParent = CreateFrame("Frame", "UIParent")
local registered, opened
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        assert(frame.name == name)
        return { GetID = function() return 42 end }
    end,
    RegisterAddOnCategory = function(value) registered = value end,
    OpenToCategory = function(id) opened = id end,
}

local db = {
    vignetteRadarEnabled = true, vignetteRadarHideWhenEmpty = true,
    vignetteRadarLauncherVisible = true, vignetteRadarRange = 450,
    vignetteRadarLayout = "classic",
    vignetteRadarCircleOnly = false,
    vignetteRadarNorthUp = false,
    vignetteRadarWorldMap = true,
    vignetteRadarQuestDots = false, vignetteRadarQuestAreas = false,
    vignetteRadarQuestHalos = true, vignetteRadarQuestColors = true,
    vignetteRadarQuestHaloRadius = 10,
    vignetteRadarAlerts = true, vignetteRadarAlertSound = false,
    vignetteRadarAlertCategories = { rare = true, treasure = 1, event = false, other = false },
    vignetteRadarAlertCooldown = 60, vignetteRadarLastSeen = true,
    vignetteRadarLastSeenSeconds = 10, vignetteRadarQuietCombat = true,
    vignetteRadarQuietInstances = true, vignetteRadarMarkerSize = 7,
    vignetteRadarShapes = true, vignetteRadarShowHealth = true,
    vignetteRadarIgnored = { hidden = true },
}
local refreshes, layoutRefreshes, previews, resets, clears = 0, 0, 0, 0, 0
local trailPickerAnchor
local addon = {
    VignetteRadarRanges = { 10, 25, 50, 100, 150, 300, 450, 600, 1200, 2400, 4800 },
    GetSettings = function() return db end,
    SetVignetteRadarEnabled = function(value) db.vignetteRadarEnabled = value end,
    SetVignetteRadarCircleOnly = function(value) db.vignetteRadarCircleOnly = value end,
    SetVignetteRadarKeepVisibleCombat = function(value) db.vignetteRadarKeepVisibleCombat = value end,
    ToggleVignetteRadarTrailPicker = function(anchor) trailPickerAnchor = anchor end,
    ToggleVignetteRadarPreview = function() previews = previews + 1 end,
    ResetVignetteRadarPositions = function() resets = resets + 1 end,
    RefreshVignetteRadar = function(rescan)
        assert(rescan == false, "layout changes must refresh presentation without rescanning")
        layoutRefreshes = layoutRefreshes + 1
    end,
    VignetteRadarAPI = { Refresh = function(rescan) assert(rescan == true); refreshes = refreshes + 1 end },
    VignetteRadarFeatures = { ClearIgnored = function()
        clears = clears + 1
        db.vignetteRadarIgnored = {}
    end },
}
assert(loadfile("UI/Controls.lua"))("VignetteRadar", addon)
assert(loadfile(sourcePath))("VignetteRadar", addon)
local event
for _, object in ipairs(objects) do
    if object.events and object.events.PLAYER_LOGIN then event = object end
end
assert(event and event.scripts.OnEvent)
event.scripts.OnEvent(event)
local panel = assert(_G.VignetteRadarOptionsPanel)
assert(panel.width == 520 and panel.height == 365 and registered,
    "the registered Settings canvas must retain its compact size")
assert(panel.pages and panel.pageButtons and panel.selectedPage == "Radar")
assert(panel.backdrop and not panel.rail and panel.headerLine and panel.tabLine,
    "the full settings canvas must keep the dark surface without an edge rail")

-- A page occupies the canvas. Check every clickable bounds and adjacent hit target
-- while each page is selected, including the separate two-column behavior page.
local function rect(control)
    local point = assert(control.points and control.points[1])
    assert(point[1] == "TOPLEFT", "page control needs a fixed top-left anchor")
    local x, y = point[4], -point[5]
    return x, y, x + control.width, y + control.height
end
local function overlaps(a, b)
    local ax1, ay1, ax2, ay2 = rect(a)
    local bx1, by1, bx2, by2 = rect(b)
    return ax1 < bx2 and bx1 < ax2 and ay1 < by2 and by1 < ay2
end
local controls = {}
local byKey = {}
local choices = {}
local action = {}
for _, pageName in ipairs({ "Radar", "Layout", "Alerts", "Behavior", "Quests", "Explore" }) do
    local page, tab = assert(panel.pages[pageName]), assert(panel.pageButtons[pageName])
    tab.scripts.OnClick(tab)
    assert(panel.selectedPage == pageName and tab.highlightLocked and page:IsShown())
    local pageControls = {}
    for _, object in ipairs(objects) do
        if object.parent == page and (object.kind == "Button" or object.kind == "CheckButton") then
            local x1, y1, x2, y2 = rect(object)
            assert(x1 >= 18 and x2 <= 496 and y1 >= 111
                and y2 <= ((pageName == "Quests" or pageName == "Layout") and 338 or 310),
                pageName .. " control escapes the content gutter or footer space: " .. tostring(object.text))
            for _, other in ipairs(pageControls) do
                assert(not overlaps(object, other), pageName .. " has overlapping hit targets")
            end
            pageControls[#pageControls + 1] = object
            controls[#controls + 1] = object
            if object.optionKey then
                byKey[object.optionKey .. (object.subkey and "." .. object.subkey or "")] = object
                assert(object.label and object.label.text, "checkbox needs a visible label")
                local lx = x2 + 5
                assert(object.label.width and object.label.wordWrap == false
                    and #object.label.text * 7 <= object.label.width
                    and lx + object.label.width <= 496,
                    "checkbox label must fit on one line inside the page gutter")
                if pageName == "Behavior" and x1 < 250 then
                    assert(lx + object.label.width <= 234,
                        "left-column text must preserve a 30px gutter before right-column controls")
                end
            elseif object.text then
                choices[object.text] = object
                action[object.text] = object
            end
        end
    end
    assert(#pageControls > 0)
    for otherName, otherPage in pairs(panel.pages) do
        if otherName ~= pageName then assert(not otherPage:IsShown()) end
    end
end
for _, pageName in ipairs({ "Radar", "Layout", "Alerts", "Behavior", "Quests", "Explore" }) do
    local tab = panel.pageButtons[pageName]
    local x1, _, x2 = rect(tab)
    assert(x1 >= 10 and x2 <= 510,
        pageName .. " tab must stay inside the 520px panel")
end
assert(#controls >= 26, "each feature must have a usable control")
for _, key in ipairs({
    "vignetteRadarEnabled", "vignetteRadarHideWhenEmpty", "vignetteRadarLauncherVisible",
    "vignetteRadarWorldMap", "vignetteRadarNorthUp", "vignetteRadarQuestDots", "vignetteRadarQuestAreas",
    "vignetteRadarQuestHalos", "vignetteRadarQuestColors", "vignetteRadarQuestAreaColors",
    "vignetteRadarAlerts", "vignetteRadarAlertSound", "vignetteRadarAlertCategories.rare",
    "vignetteRadarAlertCategories.treasure", "vignetteRadarAlertCategories.event",
    "vignetteRadarAlertCategories.other", "vignetteRadarLastSeen", "vignetteRadarQuietCombat",
    "vignetteRadarKeepVisibleCombat",
    "vignetteRadarQuietInstances", "vignetteRadarShapes", "vignetteRadarShowHealth",
    "vignetteRadarSmartZoom", "vignetteRadarUntangle", "vignetteRadarBreadcrumbs",
    "vignetteRadarApproachAlerts", "vignetteRadarJournalEnabled",
}) do
    assert(byKey[key], "missing setting: " .. key)
end
assert(byKey["vignetteRadarAlertCategories.rare"].label.text == "Rares And Bosses"
    and byKey["vignetteRadarShapes"].label.text == "Recognizable Icons"
    and byKey["vignetteRadarWorldMap"].label.text == "Include World-Map Detections",
    "rare alerts and icon settings must use recognizable player-facing names")
assert(byKey.vignetteRadarQuestDots.label.text == "Show Quest Diamonds"
    and byKey.vignetteRadarQuestAreas.label.text == "Shade Blizzard Quest Areas"
    and byKey.vignetteRadarQuestHalos.label.text == "Approximate Quest Circles"
    and byKey.vignetteRadarQuestColors.label.text == "Color Quest Diamonds"
    and byKey.vignetteRadarQuestAreaColors.label.text == "Color Estimated Quest Circles",
    "quest dots and areas need separate plain-language switches")
local trailPickerButton
for _, object in ipairs(objects) do
    if object.parent == panel.pages.Explore and object.kind == "Button"
        and object.text == "Styles & Flow" then trailPickerButton = object end
end
assert(trailPickerButton and trailPickerButton.text == "Styles & Flow",
    "the full Explore page must open the complete trail picker")
trailPickerButton.scripts.OnClick(trailPickerButton)
assert(trailPickerAnchor == trailPickerButton, "the picker must anchor to its settings button")
assert(byKey.vignetteRadarNorthUp.glyph.label
    and #byKey.vignetteRadarKeepVisibleCombat.glyph.lines == 4
    and choices["-"].backdrop == nil and #choices["-"].strokes == 1
    and choices["+"].backdrop == nil and #choices["+"].strokes == 2,
    "settings must reuse the radar's N, eye, and unboxed zoom glyph language")
local questHelp = {}
for _, object in ipairs(objects) do
    if object.parent == panel.pages.Quests and object.kind == "FontString" and object.text then
        questHelp[#questHelp + 1] = object.text
    end
end
assert(table.concat(questHelp, " "):find("north", 1, true)
    and table.concat(questHelp, " "):find("behind markers", 1, true),
    "quest settings should explain orientation and visual layering")
local themedCheck = byKey.vignetteRadarAlertSound
assert(themedCheck.visual and themedCheck.visual.backdrop
    and themedCheck.visual.width == 17 and #themedCheck.mark == 2
    and not themedCheck.mark[1]:IsShown(),
    "settings checks need a restrained inset box and a recognizable empty state")
local oldBorder = themedCheck.visual.backdropBorderColor[4]
themedCheck.scripts.OnEnter(themedCheck)
local hoveredFill = themedCheck.visual.backdropColor[2]
assert(themedCheck.visual.backdropBorderColor[4] > oldBorder and hoveredFill < 0.1
    and not themedCheck.mark[1]:IsShown(),
    "hovering must strengthen the outline without looking checked")
themedCheck:SetChecked(true)
assert(themedCheck.mark[1]:IsShown() and themedCheck.mark[2]:IsShown()
    and themedCheck.mark[1].thickness == 2
    and themedCheck.mark[1].color[2] > themedCheck.visual.backdropColor[2] + .4
    and themedCheck.visual.backdropColor[2] < .25
    and themedCheck.visual.backdropBorderColor[4] > .9,
    "checked state needs a bright tick and outline without a solid accent tile")
themedCheck.scripts.OnLeave(themedCheck)
assert(themedCheck.visual.backdropBorderColor[4] > .8 and themedCheck.mark[1]:IsShown(),
    "checked state must remain unmistakable after hover ends")
themedCheck:SetChecked(false)
local rangeReadout
for _, object in ipairs(objects) do
    if object.parent == panel.pages.Radar and object.kind == "FontString" and object.text == "450 yd" then
        rangeReadout = object
    end
end
assert(rangeReadout and rangeReadout.width == 118 and choices["-"] and choices["+"],
    "the compact range selector must show the saved value")
for _, layout in ipairs({ "classic", "squat", "compact" }) do
    assert(choices[layout:sub(1, 1):upper() .. layout:sub(2)], "missing selectable layout: " .. layout)
end
local layoutHelp = {}
for _, object in ipairs(objects) do
    if object.parent == panel.pages.Layout and object.kind == "FontString" and object.text then
        layoutHelp[object.text] = true
    end
end
assert(layoutHelp["Current portrait radar with details below."]
    and layoutHelp["Wide and short: radar left, details right, buttons below."]
    and layoutHelp["Smaller radar with range and controls below."],
    "layout choices need plain-language descriptions")
local behaviorFooter
for _, object in ipairs(objects) do
    if object.parent == panel.pages.Behavior and object.kind == "FontString"
        and object.text and object.text:find("overrides fading", 1, true) then
        behaviorFooter = object
    end
end
assert(behaviorFooter and behaviorFooter.text:find("alerts can stay muted", 1, true)
    and 24 + #behaviorFooter.text * 7 <= 496,
    "behavior help should explain the visibility override and muted alerts within the footer bounds")
assert(byKey["vignetteRadarAlertCategories.treasure"].checked == true,
    "saved numeric checked values should render as checked")

local function clickCheck(key, checked)
    local control = assert(byKey[key])
    control:SetChecked(checked)
    local before = refreshes
    control.scripts.OnClick(control)
    assert(refreshes == before + ((key == "vignetteRadarCircleOnly"
        or key == "vignetteRadarKeepVisibleCombat") and 0 or 1),
        key .. " must use the appropriate refresh path")
end
clickCheck("vignetteRadarAlertCategories.treasure", false)
assert(db.vignetteRadarAlertCategories.treasure == false)
clickCheck("vignetteRadarAlertCategories.event", 1)
assert(db.vignetteRadarAlertCategories.event == true,
    "WoW's numeric checked state must be accepted")
clickCheck("vignetteRadarAlertSound", true)
assert(db.vignetteRadarAlertSound == true)
clickCheck("vignetteRadarWorldMap", false)
assert(db.vignetteRadarWorldMap == false)
clickCheck("vignetteRadarEnabled", false)
assert(db.vignetteRadarEnabled == false)
for key, control in pairs(byKey) do
    if key ~= "vignetteRadarNorthUp" then
        local value
        if control.subkey then value = db[control.optionKey][control.subkey]
        else value = db[control.optionKey] end
        local nextValue = not (value == true or value == 1)
        clickCheck(key, nextValue)
        local saved
        if control.subkey then saved = db[control.optionKey][control.subkey]
        else saved = db[control.optionKey] end
        assert(saved == nextValue and control.checked == nextValue,
            key .. " must persist and display its updated state")
    end
end

local northUp = assert(byKey["vignetteRadarNorthUp"])
assert(northUp.points[1][4] == 18 and northUp.points[1][5] == -229
    and northUp.label.text == "Keep North At The Top",
    "north-up must remain between the layout descriptions and preview action")
local northBefore, scanBefore = layoutRefreshes, refreshes
northUp:SetChecked(true)
northUp.scripts.OnClick(northUp)
assert(db.vignetteRadarNorthUp == true and northUp.checked == true
    and layoutRefreshes == northBefore + 1 and refreshes == scanBefore,
    "north-up must save and redraw orientation without a detection rescan")

local function clickChoice(title, key, value)
    local button = assert(choices[title], "missing choice " .. title)
    local before = refreshes
    button.scripts.OnClick(button)
    assert(db[key] == value and refreshes == before + 1 and button.highlightLocked,
        title .. " must save, rescan, and show its selection")
end
local function stepRange(button, expected)
    local before = refreshes
    button.scripts.OnClick(button)
    assert(db.vignetteRadarRange == expected and refreshes == before + 1
        and rangeReadout.text == expected .. " yd", "range step must persist and refresh its readout")
end
stepRange(choices["+"], 600)
stepRange(choices["+"], 1200)
stepRange(choices["+"], 2400)
stepRange(choices["+"], 4800)
assert(choices["+"].enabled == false and choices["-"].enabled == true,
    "the upper range endpoint must disable the next step")
local endpointRefreshes = refreshes
choices["+"].scripts.OnClick(choices["+"])
assert(db.vignetteRadarRange == 4800 and refreshes == endpointRefreshes,
    "the upper endpoint must not save an invalid range")
for _, range in ipairs({ 2400, 1200, 600, 450, 300, 150, 100, 50, 25, 10 }) do
    stepRange(choices["-"], range)
end
assert(choices["-"].enabled == false and choices["+"].enabled == true,
    "the lower range endpoint must disable the previous step")
endpointRefreshes = refreshes
choices["-"].scripts.OnClick(choices["-"])
assert(db.vignetteRadarRange == 10 and refreshes == endpointRefreshes,
    "the lower endpoint must not save an invalid range")
db.vignetteRadarRange = 450
addon.RefreshVignetteRadarOptions()
assert(rangeReadout.text == "450 yd" and choices["-"].enabled and choices["+"].enabled,
    "external range changes must update open settings")
clickChoice("30 sec", "vignetteRadarAlertCooldown", 30)
clickChoice("15 sec", "vignetteRadarLastSeenSeconds", 15)
clickChoice("Large", "vignetteRadarMarkerSize", 9)
assert(not choices["Medium"].highlightLocked, "old choice must lose its highlight")
for _, layout in ipairs({ "Squat", "Compact", "Classic" }) do
    local before = layoutRefreshes
    local button = choices[layout]
    button.scripts.OnClick(button)
    assert(db.vignetteRadarLayout == layout:lower() and layoutRefreshes == before + 1
        and button.highlightLocked,
        layout .. " must save and refresh its panel layout without a rescan")
end
action["Preview"].scripts.OnClick(action["Preview"])
action["Reset"].scripts.OnClick(action["Reset"])
assert(previews == 1 and resets == 1, "existing layout actions must remain available")
local before = refreshes
action["Clear Ignored Vignettes"].scripts.OnClick(action["Clear Ignored Vignettes"])
assert(clears == 1 and next(db.vignetteRadarIgnored) == nil and refreshes == before + 1,
    "clear ignores must use the feature API and refresh")

addon.OpenOptions()
assert(opened == 42, "opening options should use the registered AddOns category")
Settings = nil
addon.OpenOptions()
assert(panel:IsShown() and panel.strata == "DIALOG", "standalone fallback should open")
io.write("vignette radar options tests passed\n")
