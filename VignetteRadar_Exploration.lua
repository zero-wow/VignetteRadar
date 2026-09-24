local _, addon = ...
if type(addon) ~= "table" then return end

local API = {}
addon.VignetteRadarExploration = API
local trail, trailMap, lastTrailAt = {}, nil, 0
local seen, seenMap = {}, nil
local approachInside, approachMap = {}, nil
local manualUntil, autoRange = 0, nil
local focusedQuestID
local focusedQuestMisses = 0
local MAX_PINS, MAX_ROUTE, MAX_JOURNAL, MAX_TRAIL = 60, 8, 100, 150
local MAX_CUSTOM_PRESETS = 8

local function Settings() return addon.GetSettings() end
local function Number(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value or nil
end
local function Text(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return type(value) == "string" and value:sub(1, 80) or nil
end
local function Now() return GetTime and GetTime() or 0 end
local function Time() return time and time() or 0 end
local function Tell(value)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("Vignette Radar: " .. value)
    end
end
local function Refresh()
    if addon.VignetteRadarAPI and addon.VignetteRadarAPI.Refresh then addon.VignetteRadarAPI.Refresh(false) end
    if API.RefreshPanel then API.RefreshPanel() end
end

function API.ManualZoom()
    manualUntil = Now() + 30
    autoRange = nil
end

function API.Range(player, focused)
    local db = Settings()
    local base = db.vignetteRadarRange
    if db.vignetteRadarSmartZoom ~= true or not player or Now() < manualUntil then return base end
    local speed = GetUnitSpeed and Number(GetUnitSpeed("player")) or 0
    local desired = speed and speed > 4 and math.max(1200, base) or base
    if focused and not focused.stale and Number(focused.distance) and focused.distance > 0 then
        desired = math.max(150, focused.distance * 1.25)
    end
    local ranges = addon.VignetteRadarRanges
    autoRange = ranges[#ranges]
    for _, range in ipairs(ranges) do
        if range >= desired then autoRange = range; break end
    end
    return autoRange
end

function API.FocusQuest(questID)
    questID = Number(questID)
    if focusedQuestID == questID then focusedQuestID = nil else focusedQuestID = questID end
    focusedQuestMisses = 0
    Refresh()
end
function API.GetFocusedQuest() return focusedQuestID end
function API.ValidateQuestFocus(quests, changedMap)
    if changedMap then focusedQuestID, focusedQuestMisses = nil, 0; return end
    if not focusedQuestID then return end
    for _, quest in ipairs(quests or {}) do
        if quest.questID == focusedQuestID then focusedQuestMisses = 0; return end
    end
    focusedQuestMisses = focusedQuestMisses + 1
    if focusedQuestMisses >= 3 then focusedQuestID, focusedQuestMisses = nil, 0 end
end

function API.ObjectiveProgress(questID)
    if not (C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function") then return nil end
    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(objectives) ~= "table" or (issecretvalue and issecretvalue(objectives)) then return nil end
    local completed, total = 0, 0
    for index = 1, math.min(#objectives, 30) do
        local objective = objectives[index]
        if type(objective) == "table" and not (issecretvalue and issecretvalue(objective)) then
            total = total + 1
            local finished = objective.finished
            if not (issecretvalue and issecretvalue(finished)) and finished == true then completed = completed + 1 end
        end
    end
    return total > 0 and (completed .. "/" .. total .. " objectives") or nil
end

function API.ObjectiveLines(questID)
    local lines = {}
    if not (C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function") then return lines end
    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if not ok or type(objectives) ~= "table" or (issecretvalue and issecretvalue(objectives)) then
        return lines
    end
    for index = 1, math.min(#objectives, 30) do
        local objective = objectives[index]
        if type(objective) == "table" and not (issecretvalue and issecretvalue(objective)) then
            local read, finished, label = pcall(function()
                return objective.finished, objective.text
            end)
            if read and not (issecretvalue and (issecretvalue(finished) or issecretvalue(label)))
                and finished ~= true and type(label) == "string" and label ~= "" then
                lines[#lines + 1] = label
                if #lines >= 5 then break end
            end
        end
    end
    return lines
end

function API.UpdateTrail(player, mapID, now)
    if trailMap ~= mapID then trail, trailMap, lastTrailAt = {}, mapID, 0 end
    if Settings().vignetteRadarBreadcrumbs ~= true or not player then return trail end
    now = Number(now) or Now()
    local lifetime = Settings().vignetteRadarTrailLifetime or 180
    local interval = lifetime <= 5 and .25 or 2
    local minDistance = lifetime <= 5 and .5 or 6
    while #trail > 0 and now - trail[1].at > lifetime do table.remove(trail, 1) end
    local x, y = Number(player.worldX), Number(player.worldY)
    if not x or not y then return trail end
    local last = trail[#trail]
    local distance = last and math.sqrt((x-last.x)^2 + (y-last.y)^2) or math.huge
    if now-lastTrailAt >= interval and distance >= minDistance then
        trail[#trail+1] = { x=x, y=y, at=now, instanceID=player.instanceID }
        if #trail > MAX_TRAIL then table.remove(trail, 1) end
        lastTrailAt = now
    end
    return trail
end
function API.GetTrail() return trail, trailMap end

function API.AddPin(player, name)
    if not player then return false, "Position unavailable" end
    local x, y = Number(player.worldX), Number(player.worldY)
    local mapID, mapX, mapY = Number(player.mapID), Number(player.mapX), Number(player.mapY)
    if not (x and y and mapID and mapX and mapY) then return false, "Position unavailable" end
    local pins = Settings().vignetteRadarPins
    local pinName = Text(name)
    if not pinName or pinName == "" then pinName = "My pin" end
    local pin = { id=Time() .. "-" .. tostring(math.random(100000)), name=pinName,
        mapID=mapID, mapX=mapX, mapY=mapY, worldX=x, worldY=y,
        instanceID=Number(player.instanceID), at=Time() }
    pins[#pins+1] = pin
    if #pins > MAX_PINS then table.remove(pins, 1) end
    Refresh()
    return true, pin
end
function API.GetPins(mapID)
    local result = {}
    for _, pin in ipairs(Settings().vignetteRadarPins) do
        if type(pin) == "table" and pin.mapID == mapID and Number(pin.worldX) and Number(pin.worldY) then
            result[#result+1] = pin
        end
    end
    return result
end
function API.RemovePin(id)
    local pins = Settings().vignetteRadarPins
    for index=#pins,1,-1 do
        if type(pins[index]) == "table" and pins[index].id == id then table.remove(pins,index) end
    end
    local route = Settings().vignetteRadarRoute
    for index=#route,1,-1 do
        if type(route[index]) == "table" and route[index].pinID == id then table.remove(route,index) end
    end
    Refresh()
end

local function RouteEntry(item)
    if type(item) ~= "table" then return nil end
    local x, y, mapID = Number(item.worldX), Number(item.worldY), Number(item.mapID)
    if not x or not y or not mapID then return nil end
    return { name=Text(item.name) or "Stop", worldX=x, worldY=y,
        mapID=mapID, mapX=Number(item.mapX), mapY=Number(item.mapY),
        instanceID=Number(item.instanceID), pinID=Text(item.id) }
end
function API.AddRouteStop(item)
    local route = Settings().vignetteRadarRoute
    if #route >= MAX_ROUTE then return false, "Route is full (8 stops)" end
    local entry = RouteEntry(item)
    if not entry then return false, "This stop has no position" end
    route[#route+1] = entry
    Refresh()
    return true
end
function API.GetRoute(mapID)
    local result = {}
    for _, stop in ipairs(Settings().vignetteRadarRoute) do
        if type(stop) == "table" and stop.mapID == mapID and Number(stop.worldX) and Number(stop.worldY) then
            result[#result+1] = stop
        end
    end
    return result
end
function API.PopRouteStop()
    table.remove(Settings().vignetteRadarRoute, 1)
    Refresh()
end
function API.ClearRoute()
    Settings().vignetteRadarRoute = {}
    Refresh()
end

function API.Watch(target)
    if not target or target.sample or target.stale then return false end
    local identity = Number(target.vignetteID) or Text(target.key)
    if not identity then return false end
    local watched = Settings().vignetteRadarWatched
    if type(watched) ~= "table" then watched = {}; Settings().vignetteRadarWatched = watched end
    local key = tostring(identity)
    watched[key] = not watched[key] and true or nil
    Tell(watched[key] and ("Watching " .. (target.name or "detection")) or "Watch removed")
    return watched[key] == true
end
function API.IsWatched(target)
    local watched = Settings().vignetteRadarWatched
    return target and type(watched) == "table" and watched[tostring(Number(target.vignetteID) or target.key)] == true
end
function API.CheckApproach(targets, player, mapID)
    if approachMap ~= mapID then approachInside, approachMap = {}, mapID end
    local db = Settings()
    if db.vignetteRadarApproachAlerts ~= true or not player then return nil end
    local threshold = Number(db.vignetteRadarApproachDistance) or 100
    local candidate
    for _, target in ipairs(targets) do
        if not target.stale and API.IsWatched(target)
            and (not player.instanceID or not target.instanceID or player.instanceID == target.instanceID) then
            local dx, dy = target.worldX-player.worldX, target.worldY-player.worldY
            local within = dx*dx+dy*dy <= threshold*threshold
            if within and approachInside[target.key] == false then candidate = target end
            approachInside[target.key] = within
        end
    end
    return candidate
end

function API.RecordSightings(targets, mapID)
    if seenMap ~= mapID then seen, seenMap = {}, mapID end
    if Settings().vignetteRadarJournalEnabled ~= true then return end
    local journal = Settings().vignetteRadarJournal
    for _, target in ipairs(targets) do
        if not target.stale and not seen[target.key] and Number(target.mapX) and Number(target.mapY) then
            seen[target.key] = true
            table.insert(journal, 1, { name=Text(target.name) or "Detection", category=Text(target.category),
                mapID=mapID, mapX=target.mapX, mapY=target.mapY, at=Time() })
            if #journal > MAX_JOURNAL then table.remove(journal) end
        end
    end
end
function API.ClearJournal() Settings().vignetteRadarJournal = {}; Refresh() end

local presetKeys = { "vignetteRadarRange", "vignetteRadarLayout", "vignetteRadarTheme",
    "vignetteRadarQuestDots", "vignetteRadarQuestAreas", "vignetteRadarNorthUp",
    "vignetteRadarShapes", "vignetteRadarBreadcrumbs", "vignetteRadarScale",
    "vignetteRadarMarkerSize", "vignetteRadarRingOpacity", "vignetteRadarChevronOpacity",
    "vignetteRadarHeadingOpacity", "vignetteRadarChevronDistance",
    "vignetteRadarHeadingLength", "vignetteRadarFullSweep" }
local builtin = {
    Treasure={ vignetteRadarRange=1200, vignetteRadarLayout="compact", vignetteRadarQuestDots=false,
        vignetteRadarQuestAreas=false, categories={ rare=false, treasure=true, event=false, other=false } },
    Rare={ vignetteRadarRange=1200, vignetteRadarLayout="classic", vignetteRadarQuestDots=false,
        vignetteRadarQuestAreas=false, categories={ rare=true, treasure=false, event=false, other=false } },
    Questing={ vignetteRadarRange=450, vignetteRadarLayout="squat", vignetteRadarQuestDots=true,
        vignetteRadarQuestAreas=true, vignetteRadarNorthUp=true,
        categories={ rare=true, treasure=true, event=true, other=true } },
    Exploring={ vignetteRadarRange=2400, vignetteRadarLayout="compact", vignetteRadarBreadcrumbs=true,
        categories={ rare=true, treasure=true, event=true, other=true } },
}
function API.SavePreset(name)
    name = Text(name)
    if not name or name == "" then return false end
    local db, preset = Settings(), {}
    if not db.vignetteRadarCustomPresets[name] then
        local count = 0
        for _ in pairs(db.vignetteRadarCustomPresets) do count = count + 1 end
        if count >= MAX_CUSTOM_PRESETS then return false, "8 named presets maximum" end
    end
    for _, key in ipairs(presetKeys) do preset[key] = db[key] end
    preset.colors = {}
    for slot, color in pairs(db.vignetteRadarColors) do
        if type(color) == "table" then preset.colors[slot] = { color[1], color[2], color[3] } end
    end
    preset.categories = {}
    for _, category in ipairs({ "rare", "treasure", "event", "other" }) do
        preset.categories[category] = db.vignetteRadarCategories[category] ~= false
    end
    db.vignetteRadarCustomPresets[name] = preset
    return true
end
function API.DeletePreset(name)
    Settings().vignetteRadarCustomPresets[name] = nil
    API.RefreshPanel()
end
function API.ApplyPreset(name)
    local db = Settings()
    local preset = builtin[name] or db.vignetteRadarCustomPresets[name]
    if type(preset) ~= "table" then return false end
    for _, key in ipairs(presetKeys) do if preset[key] ~= nil then db[key] = preset[key] end end
    if type(preset.colors) == "table" then
        db.vignetteRadarColors = {}
        for slot, color in pairs(preset.colors) do
            if type(color) == "table" then db.vignetteRadarColors[slot] = { color[1], color[2], color[3] } end
        end
    end
    if type(preset.categories) == "table" then
        for key, value in pairs(preset.categories) do db.vignetteRadarCategories[key] = value end
    end
    db.vignetteRadarActivePreset = name
    API.ManualZoom()
    Refresh()
    return true
end
function API.PresetNames()
    local names = { "Treasure", "Rare", "Questing", "Exploring" }
    for name in pairs(Settings().vignetteRadarCustomPresets) do names[#names+1] = name end
    return names
end

API.Tell = Tell

local panel, selectedPage = nil, "Modes"
local page = { Pins=1, Journal=1 }
local customPage = 1
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local function Label(parent, value, x, y, width, size)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(FONT, size or 10, "")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width or 300)
    label:SetJustifyH("LEFT")
    label:SetTextColor(.78, .85, .84, 1)
    label:SetText(value)
    return label
end
local function Button(parent, title, x, y, width, callback)
    local controls = addon.VignetteRadarControls
    local button = (title == "+" or title == "-" or title == "−")
        and controls.IconButton(parent, title, width, 23) or controls.Button(parent, title, width, 23)
    button:SetPoint("TOPLEFT", x, y)
    button:SetScript("OnClick", callback)
    return button
end
local function Checkbox(parent, key, title, y)
    local box = addon.VignetteRadarControls.Checkbox(parent)
    box:SetPoint("TOPLEFT", 15, y)
    local hit = CreateFrame("Button", nil, parent)
    hit:SetPoint("TOPLEFT", 44, y)
    hit:SetSize(270, 26)
    Label(hit, title, 0, -6, 250)
    local function Toggle()
        Settings()[key] = not Settings()[key]
        box:SetChecked(Settings()[key] == true)
        Refresh()
    end
    box:SetScript("OnClick", function(self)
        Settings()[key] = self:GetChecked() == true or self:GetChecked() == 1
        Refresh()
    end)
    hit:SetScript("OnClick", Toggle)
    return box
end
local function Input(parent, x, y, width)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, 25)
    box:SetPoint("TOPLEFT", x, y)
    box:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    box:SetBackdropColor(.035, .045, .05, .98)
    box:SetBackdropBorderColor(.28, .5, .46, .7)
    box:SetFontObject(GameFontHighlightSmall)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(60)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end
local function BuildPanel()
    if panel then return panel end
    panel = CreateFrame("Frame", "VignetteRadarExplorePanel", UIParent, "BackdropTemplate")
    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "VignetteRadarExplorePanel"
    end
    panel:SetSize(330, 425)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    panel:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1 })
    panel:SetBackdropColor(.035, .043, .049, .98)
    panel:SetBackdropBorderColor(.36, .59, .54, .45)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel.rail = panel:CreateTexture(nil, "ARTWORK")
    panel.rail:SetPoint("TOPLEFT", 1, -1)
    panel.rail:SetPoint("BOTTOMLEFT", 1, 1)
    panel.rail:SetWidth(2)
    panel.headerLine = panel:CreateTexture(nil, "ARTWORK")
    panel.headerLine:SetPoint("TOPLEFT", 12, -36)
    panel.headerLine:SetPoint("TOPRIGHT", -12, -36)
    panel.headerLine:SetHeight(1)
    panel.title = Label(panel, "EXPLORE", 15, -12, 190, 12)
    Button(panel, "×", 297, -8, 23, function() panel:Hide() end)
    panel.pages, panel.tabs = {}, {}
    for index, name in ipairs({ "Modes", "Tools", "Pins", "Journal" }) do
        local tab = Button(panel, name, 10+(index-1)*79, -42, 74, function()
            selectedPage = name
            API.RefreshPanel()
        end)
        panel.tabs[name] = tab
        local content = CreateFrame("Frame", nil, panel)
        content:SetSize(310, 346)
        content:SetPoint("TOPLEFT", 10, -73)
        panel.pages[name] = content
    end

    local modes = panel.pages.Modes
    Label(modes, "HUNTING PRESETS", 5, -3, 260, 9):SetTextColor(.05, .82, .62, 1)
    for index, name in ipairs({ "Treasure", "Rare", "Questing", "Exploring" }) do
        local x = 5 + ((index-1)%2)*153
        local y = -25 - math.floor((index-1)/2)*34
        Button(modes, name, x, y, 145, function() API.ApplyPreset(name) end)
    end
    Label(modes, "SAVE OR LOAD YOUR OWN", 5, -104, 260, 9):SetTextColor(.05, .82, .62, 1)
    panel.presetName = Input(modes, 5, -124, 296)
    Button(modes, "Save current", 5, -160, 145, function()
        local name = panel.presetName:GetText()
        local ok, reason = API.SavePreset(name)
        Tell(ok and ("Saved preset " .. name) or (reason or "Enter a preset name"))
        API.RefreshPanel()
    end)
    Button(modes, "Load named", 158, -160, 143, function()
        if not API.ApplyPreset(panel.presetName:GetText()) then Tell("Preset not found") end
    end)
    panel.activePreset = Label(modes, "", 5, -208, 296, 10)
    Label(modes, "Stores range, layout, filters and appearance.", 5, -225, 296, 9)
    Label(modes, "SAVED PRESETS", 5, -246, 290, 9):SetTextColor(.05, .82, .62, 1)
    panel.customRows = {}
    for index=1,4 do
        local button = Button(modes, "", 5+((index-1)%2)*153,
            -264-math.floor((index-1)/2)*29, 145, function(self, mouseButton)
                if not self.presetName then return end
                if mouseButton == "RightButton" then API.DeletePreset(self.presetName)
                else API.ApplyPreset(self.presetName) end
            end)
        if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
        panel.customRows[index] = button
    end
    Button(modes, "‹", 5, -322, 39, function() customPage=math.max(1,customPage-1); API.RefreshPanel() end)
    panel.customPageLabel = Label(modes, "", 129, -327, 80, 9)
    Button(modes, "›", 262, -322, 39, function() customPage=customPage+1; API.RefreshPanel() end)

    local tools = panel.pages.Tools
    panel.checks = {
        smart = Checkbox(tools, "vignetteRadarSmartZoom", "Smart zoom (manual zoom pauses 30 sec)", -3),
        untangle = Checkbox(tools, "vignetteRadarUntangle", "Spread crowded markers on hover", -34),
        trail = Checkbox(tools, "vignetteRadarBreadcrumbs", "Show dotted travel trail", -65),
        approach = Checkbox(tools, "vignetteRadarApproachAlerts", "Alert near watched detections", -96),
        journal = Checkbox(tools, "vignetteRadarJournalEnabled", "Keep a sightings journal", -127),
    }
    Label(tools, "APPROACH DISTANCE", 5, -164, 250, 9):SetTextColor(.05, .82, .62, 1)
    panel.approachValue = Label(tools, "", 114, -187, 75, 11)
    Button(tools, "−", 5, -183, 45, function()
        Settings().vignetteRadarApproachDistance = math.max(25, Settings().vignetteRadarApproachDistance - 25)
        API.RefreshPanel()
    end)
    Button(tools, "+", 254, -183, 45, function()
        Settings().vignetteRadarApproachDistance = math.min(600, Settings().vignetteRadarApproachDistance + 25)
        API.RefreshPanel()
    end)
    Label(tools, "DROP A PIN AT YOUR LOCATION", 5, -221, 290, 9):SetTextColor(.05, .82, .62, 1)
    panel.pinName = Input(tools, 5, -241, 190)
    Button(tools, "Add pin", 203, -242, 96, function()
        local player = addon.VignetteRadarAPI and addon.VignetteRadarAPI.GetPlayerSnapshot
            and addon.VignetteRadarAPI.GetPlayerSnapshot()
        local ok, result = API.AddPin(player, panel.pinName:GetText())
        Tell(ok and ("Pinned " .. result.name) or result)
    end)
    Button(tools, "Next route stop", 5, -280, 145, function() API.PopRouteStop() end)
    Button(tools, "Clear route", 158, -280, 141, function() API.ClearRoute() end)
    panel.routeStatus = Label(tools, "", 5, -319, 295, 9)
    Label(tools, "Ctrl-Alt-click a detection to watch it.", 5, -333, 295, 9)

    for _, name in ipairs({ "Pins", "Journal" }) do
        local content = panel.pages[name]
        panel[name .. "Rows"] = {}
        for index=1,9 do
            local row = Button(content, "", 5, -4-(index-1)*30, 296, function(self, button)
                local item = self.item
                if not item then return end
                if name == "Pins" then
                    if button == "RightButton" then API.RemovePin(item.id)
                    else
                        local ok, reason = API.AddRouteStop(item)
                        Tell(ok and ("Added " .. item.name .. " to route") or reason)
                    end
                end
            end)
            if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
            panel[name .. "Rows"][index] = row
        end
        Button(content, "‹", 5, -289, 42, function() page[name] = math.max(1, page[name]-1); API.RefreshPanel() end)
        panel[name .. "Page"] = Label(content, "", 118, -294, 70, 10)
        Button(content, "›", 259, -289, 42, function() page[name] = page[name]+1; API.RefreshPanel() end)
    end
    Label(panel.pages.Pins, "Click: route stop  •  Right-click: delete", 5, -325, 290, 9)
    Button(panel.pages.Journal, "Clear journal", 5, -319, 296, function() API.ClearJournal() end)
    panel:Hide()
    API.RefreshPanel()
    return panel
end

function API.RefreshPanel()
    if not panel then return end
    local style = addon.VignetteRadarStyle
    if style then
        local ar, ag, ab = style.Color("accent")
        local br, bg, bb = style.Color("background")
        panel:SetBackdropColor(math.min(.14, br * 2.7), math.min(.14, bg * 2.7),
            math.min(.14, bb * 2.7), .99)
        panel.title:SetTextColor(ar, ag, ab, 1)
        panel.rail:SetColorTexture(ar, ag, ab, .8)
        panel.headerLine:SetColorTexture(ar, ag, ab, .2)
        addon.VignetteRadarControls.RefreshTheme()
    end
    for name, content in pairs(panel.pages) do content:SetShown(name == selectedPage) end
    for name, tab in pairs(panel.tabs) do
        if name == selectedPage then tab:LockHighlight() else tab:UnlockHighlight() end
    end
    local db = Settings()
    panel.activePreset:SetText("Last loaded: " .. (db.vignetteRadarActivePreset or "Custom"))
    local customNames = {}
    for name in pairs(db.vignetteRadarCustomPresets) do customNames[#customNames+1] = name end
    table.sort(customNames)
    local customPages = math.max(1, math.ceil(#customNames/4))
    customPage = math.max(1, math.min(customPage, customPages))
    panel.customPageLabel:SetText(customPage .. " / " .. customPages)
    for index, row in ipairs(panel.customRows) do
        local name = customNames[(customPage-1)*4+index]
        row.presetName = name
        if name then row:SetText(name:sub(1, 18)); row:Show() else row:Hide() end
    end
    panel.approachValue:SetText(db.vignetteRadarApproachDistance .. " yd")
    panel.routeStatus:SetText(#db.vignetteRadarRoute .. "/" .. MAX_ROUTE
        .. " stops  •  Ctrl-click a detection to add it")
    local keys = { smart="vignetteRadarSmartZoom", untangle="vignetteRadarUntangle",
        trail="vignetteRadarBreadcrumbs", approach="vignetteRadarApproachAlerts",
        journal="vignetteRadarJournalEnabled" }
    for key, checkbox in pairs(panel.checks) do checkbox:SetChecked(db[keys[key]] == true) end
    for _, name in ipairs({ "Pins", "Journal" }) do
        local records = name == "Pins" and db.vignetteRadarPins or db.vignetteRadarJournal
        local pages = math.max(1, math.ceil(#records/9))
        page[name] = math.max(1, math.min(page[name], pages))
        panel[name .. "Page"]:SetText(page[name] .. " / " .. pages)
        for index, row in ipairs(panel[name .. "Rows"]) do
            local item = records[(page[name]-1)*9 + index]
            row.item = item
            if item then
                local text = (item.name or "Location"):sub(1, 19)
                if item.mapX and item.mapY then
                    text = text .. string.format("  %.0f, %.0f", item.mapX*100, item.mapY*100)
                end
                if name == "Journal" and item.at and date then
                    text = text .. "  " .. date("%m/%d %H:%M", item.at)
                end
                row:SetText(text)
                row:Show()
            else row:Hide() end
        end
    end
end

function API.TogglePanel()
    local frame = BuildPanel()
    if frame:IsShown() then frame:Hide() else API.RefreshPanel(); frame:Show() end
end
