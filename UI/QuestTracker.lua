local _, addon = ...
if type(addon) ~= "table" then return end

local API = {}
addon.VignetteRadarQuestTracker = API

local WIDTH, HEADER_HEIGHT, HEADER_ROW_HEIGHT, QUEST_ROW_HEIGHT = 306, 47, 20, 32
local VISIBLE_ROWS, FOOTER_HEIGHT = 8, 17
local TRAY_TAB, SLIDE_SECONDS = 20, .22
local DIAMOND = "Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond.tga"
local HOLLOW = "Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond-hollow.tga"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local frame, menu, entries, offset, pending = nil, nil, {}, 0, false
local lastThemeRevision = -1
local RefreshMenu

local function Secret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, result = pcall(issecretvalue, value)
    return not ok or result == true
end

local function Field(record, key)
    if Secret(record) or type(record) ~= "table" then return nil end
    local ok, value = pcall(function() return record[key] end)
    return ok and not Secret(value) and value or nil
end

local function Number(value)
    if Secret(value) or type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge then return nil end
    return value
end

local function Word(value)
    if Secret(value) or type(value) ~= "string" or value == "" then return nil end
    return value:sub(1, 150)
end

local function Call(owner, name, ...)
    if type(owner) ~= "table" then return nil end
    local callback = Field(owner, name)
    if type(callback) ~= "function" then return nil end
    local ok, a, b = pcall(callback, ...)
    if ok and not Secret(a) then return a, b end
end

local function Settings() return addon.GetSettings() end

local function MapID()
    local radar = addon.VignetteRadarAPI
    local value = radar and radar.GetCurrentMapID and radar.GetCurrentMapID()
    if Number(value) then return value end
    return Call(C_Map, "GetBestMapForUnit", "player")
end

local function QuestSlot(questID)
    local radar = addon.VignetteRadarAPI
    local slot = radar and radar.GetQuestColorSlot and radar.GetQuestColorSlot(questID)
    return Number(slot) or 1
end

local function QuestColor(slot)
    local palette = addon.VignetteRadarQuestColors
    local color = palette and palette[slot]
    if color then return color[1], color[2], color[3] end
    local style = addon.VignetteRadarStyle
    if style then return style.Color("quest") end
    return 1, .74, .27
end

local function DifficultyColor(level)
    if level and type(GetQuestDifficultyColor) == "function" then
        local ok, color = pcall(GetQuestDifficultyColor, level)
        if ok then
            local r, g, b = Number(Field(color, "r")), Number(Field(color, "g")),
                Number(Field(color, "b"))
            if r and g and b then return r, g, b end
        end
    end
    return .83, .87, .88
end

local function Objective(questID)
    local data = addon.VignetteRadarQuestData
    local summary = data and data.GetObjectiveSummary and data.GetObjectiveSummary(questID)
    if summary then
        local label, count = Word(summary.label), Word(summary.count)
        if label then return label, count end
    end
    local exploration = addon.VignetteRadarExploration
    local progress = exploration and exploration.ObjectiveProgress
        and exploration.ObjectiveProgress(questID)
    return nil, Word(progress) and progress:match("^%d+/%d+") or nil
end

-- The quest log supplies the player's own headers; the map APIs decide which
-- quests are local. A header is emitted only when it has a visible child.
function API.BuildEntries(mapID, scope)
    if scope ~= "watched" and scope ~= "all" then scope = "local" end
    local localIDs, watched, taskKinds = {}, {}, {}
    local radar = addon.VignetteRadarAPI
    local radarQuests = radar and radar.GetQuests and radar.GetQuests() or {}
    for _, quest in ipairs(radarQuests) do
        local id = Number(quest.questID)
        if id and quest.mapID == mapID then localIDs[id] = true end
    end
    if Number(mapID) then
        local records = Call(C_QuestLog, "GetQuestsOnMap", mapID)
        if type(records) == "table" and not Secret(records) then
            for index = 1, math.min(#records, 256) do
                local id = Number(Field(records[index], "questID"))
                if id then localIDs[id] = true end
            end
        end
        local tasks = Call(C_TaskQuest, "GetQuestsOnMap", mapID)
        if type(tasks) == "table" and not Secret(tasks) then
            for index = 1, math.min(#tasks, 128) do
                local record = tasks[index]
                local id = Number(Field(record, "questID")) or Number(Field(record, "questId"))
                if id then
                    localIDs[id] = true
                    taskKinds[id] = (Field(record, "isWorldQuest") == true
                        or Call(C_QuestLog, "IsWorldQuest", id) == true) and "World Quests"
                        or "Bonus Objectives"
                end
            end
        end
    end
    for _, spec in ipairs({
        { "GetNumQuestWatches", "GetQuestIDForQuestWatchIndex" },
        { "GetNumWorldQuestWatches", "GetQuestIDForWorldQuestWatchIndex" },
    }) do
        local count = Number(Call(C_QuestLog, spec[1])) or 0
        for index = 1, math.min(count, 40) do
            local id = Number(Call(C_QuestLog, spec[2], index))
            if id then
                watched[id] = true
                if Number(mapID) then
                    local x, y = Call(C_QuestLog, "GetNextWaypointForMap", id, mapID)
                    if Number(x) and Number(y) then localIDs[id] = true end
                end
            end
        end
    end

    local result, groups, present = {}, {}, {}
    local function AddQuest(id, title, level, header, kind)
        if not id or present[id] then return end
        if scope == "local" and not localIDs[id] then return end
        if scope == "watched" and not watched[id] then return end
        title = Word(title) or Word(Call(C_QuestLog, "GetTitleForQuestID", id))
        if not title then return end
        present[id] = true
        header = kind or Word(header) or "Quests"
        local group = groups[header]
        if not group then
            group = { kind = "header", title = header, count = 0 }
            groups[header] = group
            result[#result + 1] = group
        end
        group.count = group.count + 1
        local objective, progress = Objective(id)
        result[#result + 1] = { kind = "quest", questID = id, title = title,
            header = header, colorSlot = QuestSlot(id), level = level,
            watched = watched[id] == true, complete = Call(C_QuestLog, "IsComplete", id) == true,
            objective = objective, progress = progress }
    end

    local count = Number(Call(C_QuestLog, "GetNumQuestLogEntries")) or 0
    local header = "Quests"
    for index = 1, math.min(count, 500) do
        local info = Call(C_QuestLog, "GetInfo", index)
        if type(info) == "table" and not Secret(info) then
            if Field(info, "isHeader") == true then
                header = Word(Field(info, "title")) or header
            else
                local id = Number(Field(info, "questID"))
                local kind = taskKinds[id]
                if id and Call(C_QuestLog, "IsWorldQuest", id) == true then
                    kind = "World Quests"
                end
                AddQuest(id, Field(info, "title"),
                    Number(Field(info, "difficultyLevel")) or Number(Field(info, "level")),
                    header, kind)
            end
        end
    end
    -- World quests and bonus objectives need not have a quest-log row.
    for _, kind in ipairs({ "World Quests", "Bonus Objectives" }) do
        local ids = {}
        for id, taskKind in pairs(taskKinds) do
            if taskKind == kind and not present[id] then ids[#ids + 1] = id end
        end
        table.sort(ids)
        for _, id in ipairs(ids) do
            AddQuest(id, nil, Number(Call(C_QuestLog, "GetQuestDifficultyLevel", id)),
                kind, kind)
        end
    end
    return result
end

local function Label(parent, size, value)
    local label = parent:CreateFontString(nil, "OVERLAY")
    local font = EllesmereUI and EllesmereUI.EXPRESSWAY or STANDARD_TEXT_FONT
        or "Fonts\\FRIZQT__.TTF"
    label:SetFont(font, size, "")
    label:SetText(value or "")
    label:SetWordWrap(false)
    return label
end

local function Button(parent, value, width)
    local controls = addon.VignetteRadarControls
    return controls.Button(parent, value, width, 22)
end

local function Select(button, selected)
    if selected then
        if button.LockHighlight then button:LockHighlight() end
    elseif button.UnlockHighlight then button:UnlockHighlight() end
end

local function Hint(button, title, details)
    if not button.HookScript then return end
    button:HookScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, .87, .66)
        GameTooltip:AddLine(details, .66, .8, .78, true)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function SavePosition()
    if not frame then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if Number(left) and Number(top) and UIParent and UIParent.GetHeight then
        Settings().vignetteRadarQuestTrackerPosition = { x = left,
            y = top - UIParent:GetHeight() }
    end
end

local function RadarAnchor()
    local radar = addon.VignetteRadarAPI
    local root = radar and radar.GetPanel and radar.GetPanel()
    return root and (root.field or root), root
end

local function Place()
    if not frame then return end
    local db = Settings()
    local anchor, root = RadarAnchor()
    local dock = db.vignetteRadarQuestTrackerView == "tray" and root and root.IsShown
        and root:IsShown() and anchor and anchor.IsShown and anchor:IsShown()
    local side = db.vignetteRadarQuestTrackerSide or "right"
    if dock then
        local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
        local left, right, top, bottom = anchor:GetLeft(), anchor:GetRight(),
            anchor:GetTop(), anchor:GetBottom()
        if not (Number(screenW) and Number(screenH) and Number(left) and Number(right)
            and Number(top) and Number(bottom)) then dock = false end
        if dock then
            local fits = {
                right = right + WIDTH <= screenW - 8,
                left = left - WIDTH >= 8,
                top = top + frame:GetHeight() <= screenH - 8,
                bottom = bottom - frame:GetHeight() >= 8,
            }
            if not fits[side] then
                local opposite = { right = "left", left = "right", top = "bottom", bottom = "top" }
                if fits[opposite[side]] then side = opposite[side]
                else
                    for _, candidate in ipairs({ "right", "left", "top", "bottom" }) do
                        if fits[candidate] then side = candidate; break end
                    end
                end
            end
            if not fits[side] then dock = false end
            if dock then
                local xOffset, yOffset = 0, 0
                if side == "top" or side == "bottom" then
                    local center = math.max(WIDTH / 2 + 8,
                        math.min(screenW - WIDTH / 2 - 8, (left + right) / 2))
                    xOffset = center - (left + right) / 2
                end
                local progress = frame.slideProgress or 1
                local retreat = (1 - progress) *
                    ((side == "right" or side == "left") and (WIDTH - TRAY_TAB)
                        or (frame:GetHeight() - TRAY_TAB))
                local key = table.concat({ "tray", side, math.floor(left), math.floor(right),
                    math.floor(top), math.floor(bottom), frame:GetHeight(), xOffset,
                    math.floor(retreat * 10 + .5) }, ":")
                if frame._placementKey ~= key then
                    frame._placementKey = key
                    frame:ClearAllPoints()
                    if side == "right" then
                        frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", -2 - retreat, -2)
                    elseif side == "left" then
                        frame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 2 + retreat, -2)
                    elseif side == "top" then
                        frame:SetPoint("BOTTOM", anchor, "TOP", xOffset, -retreat)
                    else
                        frame:SetPoint("TOP", anchor, "BOTTOM", xOffset, retreat)
                    end
                end
            end
        end
    end
    if not dock then
        if frame._placementKey ~= "floating" then
            frame._placementKey = "floating"
            frame:ClearAllPoints()
            local position = db.vignetteRadarQuestTrackerPosition
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
                type(position) == "table" and Number(position.x) or 290,
                type(position) == "table" and Number(position.y) or -160)
        end
    end
    frame.actualSide = dock and side or nil
    local strata = dock and "LOW" or "MEDIUM"
    if frame._strata ~= strata then frame._strata = strata; frame:SetFrameStrata(strata) end
    frame.close:SetShown(not dock)
    frame.handle:SetShown(dock)
    if dock and frame.handleSide ~= side then
        frame.handleSide = side
        frame.handle:ClearAllPoints()
        if side == "right" or side == "left" then
            frame.handle:SetSize(TRAY_TAB, 68)
            frame.handle:SetPoint(side == "right" and "RIGHT" or "LEFT", frame,
                side == "right" and "RIGHT" or "LEFT")
        else
            frame.handle:SetSize(68, TRAY_TAB)
            frame.handle:SetPoint(side == "top" and "TOP" or "BOTTOM", frame,
                side == "top" and "TOP" or "BOTTOM")
        end
    end
    if type(frame.statusSurface) == "table" then
        local join = { right = { [1] = true, [4] = true, [7] = true },
            left = { [3] = true, [6] = true, [9] = true },
            top = { [7] = true, [8] = true, [9] = true },
            bottom = { [1] = true, [2] = true, [3] = true } }
        for index, texture in ipairs(frame.statusSurface.edge or {}) do
            texture:SetShown(not dock or not join[side][index])
        end
        if type(frame.handle.statusSurface) == "table" then
            for index, texture in ipairs(frame.handle.statusSurface.edge or {}) do
                texture:SetShown(dock and not join[side][index])
            end
        end
    end
end

local function Draw()
    if not frame then return end
    local controls = addon.VignetteRadarControls
    if controls then
        controls.RefreshRoundedStatusSurface(frame)
        controls.RefreshRoundedStatusSurface(frame.handle)
    end
    local style = addon.VignetteRadarStyle
    local ar, ag, ab = .05, .82, .62
    if style then ar, ag, ab = style.Color("accent") end
    frame.title:SetTextColor(ar, ag, ab, 1)
    frame.rule:SetColorTexture(ar, ag, ab, .2)
    if frame.handleIcon then frame.handleIcon:SetVertexColor(ar, ag, ab, 1) end
    local count = 0
    for _, entry in ipairs(entries) do if entry.kind == "quest" then count = count + 1 end end
    local scope = Settings().vignetteRadarQuestTrackerScope
    local scopeName = scope == "watched" and "WATCHED" or scope == "all" and "ALL" or "LOCAL"
    frame.count:SetText(scopeName .. "  ·  " .. count .. " QUEST" .. (count == 1 and "" or "S"))
    local collapsed = Settings().vignetteRadarQuestTrackerCollapsed
    local visible = {}
    local hiddenHeader
    for _, entry in ipairs(entries) do
        if entry.kind == "header" then
            hiddenHeader = collapsed[entry.title] == true
            visible[#visible + 1] = entry
        elseif not hiddenHeader then
            visible[#visible + 1] = entry
        end
    end
    frame.visibleEntries = visible
    local anchor, root = RadarAnchor()
    local trayHeight = Settings().vignetteRadarQuestTrackerView == "tray"
        and root and root.IsShown and root:IsShown() and anchor
        and Number(anchor:GetHeight()) and math.max(110, anchor:GetHeight() - 4)
    offset = math.max(0, math.min(offset, math.max(0, #visible - 1)))
    local capacity = VISIBLE_ROWS
    if trayHeight then
        capacity = 0
        local room, used = trayHeight - HEADER_HEIGHT - FOOTER_HEIGHT - 7, 0
        for index = offset + 1, math.min(#visible, offset + VISIBLE_ROWS) do
            local height = visible[index].kind == "header" and HEADER_ROW_HEIGHT
                or QUEST_ROW_HEIGHT
            if capacity > 0 and used + height > room then break end
            used, capacity = used + height, capacity + 1
        end
        capacity = math.max(1, capacity)
    end
    offset = math.max(0, math.min(offset, math.max(0, #visible - capacity)))
    local shown = math.min(#visible - offset, capacity)
    local contentHeight = 0
    for index = 1, shown do
        local entry = visible[offset + index]
        contentHeight = contentHeight + (entry.kind == "header" and HEADER_ROW_HEIGHT
            or QUEST_ROW_HEIGHT)
    end
    local overflow = #visible > capacity
    frame:SetHeight(trayHeight or (HEADER_HEIGHT + math.max(24, contentHeight)
        + (overflow and FOOTER_HEIGHT or 8)))
    frame.empty:SetShown(#visible == 0)
    frame.empty:SetText(scope == "local" and "No Local Quests On This Map"
        or scope == "watched" and "No Watched Quests" or "No Quests In Your Log")
    frame.footer:SetShown(overflow)
    frame.footer:SetText(overflow and ((offset + 1) .. "–"
        .. math.min(#visible, offset + capacity) .. " Of " .. #visible .. " · Scroll") or "")
    local rowY = -HEADER_HEIGHT
    for index, row in ipairs(frame.rows) do
        local entry = index <= capacity and visible[offset + index] or nil
        row.entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            local isHeader = entry.kind == "header"
            local height = isHeader and HEADER_ROW_HEIGHT or QUEST_ROW_HEIGHT
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, rowY)
            row:SetSize(WIDTH - 24, height)
            rowY = rowY - height
            row.header:SetShown(isHeader)
            row.quest:SetShown(not isHeader)
            if isHeader then
                row.header:SetText((collapsed[entry.title] and "+ " or "− ")
                    .. entry.title .. "  " .. entry.count)
                row.header:SetTextColor(ar, ag, ab, 1)
                row.hover:SetColorTexture(ar, ag, ab, .08)
            else
                local r, g, b = QuestColor(entry.colorSlot)
                row.diamond:SetTexture(entry.complete and DIAMOND or HOLLOW)
                row.diamond:SetVertexColor(r, g, b, 1)
                row.slot:SetText(tostring(entry.colorSlot))
                row.slot:SetTextColor(1, 1, 1, 1)
                row.center:SetVertexColor(r * .18, g * .18, b * .18, .96)
                row.center:SetShown(not entry.complete)
                local dr, dg, db = DifficultyColor(entry.level)
                row.name:SetText(entry.title)
                row.name:SetTextColor(dr, dg, db, 1)
                row.progress:SetText(entry.complete and "Ready To Turn In"
                    or entry.objective and (entry.progress and entry.progress .. "  " or "")
                        .. entry.objective or entry.progress or "Click To Focus")
                row.progress:SetTextColor(entry.complete and .48 or .66,
                    entry.complete and .9 or .77, entry.complete and .65 or .77, 1)
                local exploration = addon.VignetteRadarExploration
                local focused = exploration and exploration.GetFocusedQuest
                    and exploration.GetFocusedQuest() == entry.questID
                row.focus:SetColorTexture(r, g, b, focused and .84 or 0)
                row.hover:SetColorTexture(r, g, b, .08)
            end
        end
    end
    lastThemeRevision = style and style.revision or 0
    Place()
    if menu and menu:IsShown() and RefreshMenu then RefreshMenu() end
end

local function EnsureMenu()
    if menu then return menu end
    menu = CreateFrame("Frame", "VignetteRadarQuestTrackerOptions", UIParent)
    menu:SetSize(224, 294)
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    addon.VignetteRadarControls.RoundedStatusSurface(menu)
    menu.choices = {}
    local function Heading(text, y)
        local label = Label(menu, 9, text)
        label:SetPoint("TOPLEFT", 12, y)
        label:SetTextColor(.60, .77, .79, 1)
    end
    local function Choice(text, x, y, width, key, value, action)
        local button = Button(menu, text, width)
        button:SetPoint("TOPLEFT", x, y)
        button:SetScript("OnClick", function()
            if action then
                action()
            else
                local db = Settings()
                if key == "vignetteRadarQuestTrackerView" and value == "tray"
                    and db[key] == "floating" then
                    SavePosition()
                    if frame then frame.slideProgress = 0; frame.slideTarget = nil end
                    db.vignetteRadarQuestTrackerRetracted = false
                end
                db[key] = value
                if key == "vignetteRadarQuestDots" and addon.RefreshVignetteRadar then
                    addon.RefreshVignetteRadar(true)
                elseif key == "vignetteRadarQuestNumbers" and addon.RefreshVignetteRadar then
                    addon.RefreshVignetteRadar(false)
                end
                offset = 0
                API.Refresh()
            end
            RefreshMenu()
        end)
        menu.choices[#menu.choices + 1] = { button = button, key = key, value = value }
        return button
    end
    Heading("Tracker View", -10)
    Choice("Floating", 12, -27, 97, "vignetteRadarQuestTrackerView", "floating")
    Choice("Tray", 115, -27, 97, "vignetteRadarQuestTrackerView", "tray")
    Heading("Tray Side", -57)
    for index, spec in ipairs({ { "Left", "left" }, { "Right", "right" },
        { "Top", "top" }, { "Bottom", "bottom" } }) do
        Choice(spec[1], 12 + (index - 1) * 51, -74, 46,
            "vignetteRadarQuestTrackerSide", spec[2])
    end
    Heading("Quest Scope", -104)
    for index, spec in ipairs({ { "Local", "local" }, { "Watched", "watched" },
        { "All", "all" } }) do
        Choice(spec[1], 12 + (index - 1) * 69, -121, 64,
            "vignetteRadarQuestTrackerScope", spec[2])
    end
    Heading("Radar Quest Diamonds", -151)
    Choice("Off", 12, -168, 97, "vignetteRadarQuestDots", false)
    Choice("On", 115, -168, 97, "vignetteRadarQuestDots", true)
    Heading("Quest Number Labels", -198)
    Choice("Off", 12, -215, 97, "vignetteRadarQuestNumbers", false)
    Choice("On", 115, -215, 97, "vignetteRadarQuestNumbers", true)
    Heading("Visible Headers", -245)
    local function Fold(value)
        local saved = Settings().vignetteRadarQuestTrackerCollapsed
        for _, entry in ipairs(entries) do
            if entry.kind == "header" then saved[entry.title] = value or nil end
        end
        offset = 0
        Draw()
    end
    Choice("Fold All", 12, -262, 97, nil, nil, function() Fold(true) end)
    Choice("Expand All", 115, -262, 97, nil, nil, function() Fold(false) end)
    menu:RegisterEvent("GLOBAL_MOUSE_DOWN")
    menu:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver()
            and not (frame and frame.options and frame.options:IsMouseOver()) then
            self:Hide()
        end
    end)
    menu:Hide()
    return menu
end

RefreshMenu = function()
    if not menu then return end
    addon.VignetteRadarControls.RefreshRoundedStatusSurface(menu)
    for _, choice in ipairs(menu.choices) do
        if choice.key then Select(choice.button, Settings()[choice.key] == choice.value) end
    end
end

local function EnsureFrame()
    if frame or type(CreateFrame) ~= "function" or not UIParent then return frame end
    frame = CreateFrame("Frame", "VignetteRadarQuestTrackerPanel", UIParent)
    frame:SetSize(WIDTH, HEADER_HEIGHT + QUEST_ROW_HEIGHT + 8)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    addon.VignetteRadarControls.RoundedStatusSurface(frame)
    frame.slideProgress = Settings().vignetteRadarQuestTrackerRetracted == true and 0 or 1
    frame.handle = CreateFrame("Button", nil, frame)
    frame.handle:EnableMouse(true)
    frame.handle:RegisterForClicks("LeftButtonUp")
    addon.VignetteRadarControls.RoundedStatusSurface(frame.handle)
    if type(frame.handle.statusSurface) == "table" then
        for _, texture in ipairs(frame.handle.statusSurface.face or {}) do
            texture:Hide()
        end
    end
    frame.handleIcon = frame.handle:CreateTexture(nil, "OVERLAY")
    frame.handleIcon:SetTexture("Interface\\AddOns\\VignetteRadar\\Media\\radar-corner-controls.tga")
    frame.handleIcon:SetTexCoord((11 * 64 + 1) / 1024, (12 * 64 - 1) / 1024,
        1 / 256, 63 / 256)
    frame.handleIcon:SetSize(18, 18)
    frame.handleIcon:SetPoint("CENTER")
    frame.handle:SetScript("OnClick", function() API.ToggleTray() end)
    Hint(frame.handle, "Quest Tracker", "Click To Slide The Tray In Or Out.")
    frame.handle:Hide()
    local position = Settings().vignetteRadarQuestTrackerPosition
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
        type(position) == "table" and Number(position.x) or 290,
        type(position) == "table" and Number(position.y) or -160)
    frame.title = Label(frame, 12, "QUEST TRACKER")
    frame.title:SetPoint("TOPLEFT", 14, -8)
    frame.title:SetWidth(120)
    frame.title:SetJustifyH("LEFT")
    frame.count = Label(frame, 9, "0 QUESTS")
    frame.count:SetPoint("TOPLEFT", 14, -25)
    frame.rule = frame:CreateTexture(nil, "ARTWORK")
    frame.rule:SetPoint("TOPLEFT", 12, -40)
    frame.rule:SetPoint("TOPRIGHT", -12, -40)
    frame.rule:SetHeight(1)
    frame.options = Button(frame, "Options", 62)
    frame.options:SetPoint("TOPRIGHT", -39, -8)
    frame.options:SetScript("OnClick", function()
        local dropdown = EnsureMenu()
        dropdown:ClearAllPoints()
        if Number(frame:GetBottom()) and frame:GetBottom() < dropdown:GetHeight() + 8 then
            dropdown:SetPoint("BOTTOMRIGHT", frame.options, "TOPRIGHT", 0, 3)
        else
            dropdown:SetPoint("TOPRIGHT", frame.options, "BOTTOMRIGHT", 0, -3)
        end
        RefreshMenu()
        dropdown:SetShown(not dropdown:IsShown())
    end)
    Hint(frame.options, "Tracker Options", "Choose the view, tray side, quest scope, and radar labels.")
    frame.close = Button(frame, "×", 22)
    frame.close:SetPoint("TOPRIGHT", -9, -8)
    frame.close:SetScript("OnClick", function() API.Hide() end)
    frame.drag = CreateFrame("Button", nil, frame)
    frame.drag:SetPoint("TOPLEFT", 8, -5)
    frame.drag:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -110, -37)
    frame.drag:RegisterForDrag("LeftButton")
    frame.drag:SetScript("OnDragStart", function()
        if Settings().vignetteRadarQuestTrackerView == "floating" then frame:StartMoving() end
    end)
    frame.drag:SetScript("OnDragStop", function()
        if Settings().vignetteRadarQuestTrackerView == "floating" then
            frame:StopMovingOrSizing()
            SavePosition()
        end
    end)
    frame.drag:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Quest Tracker", 1, .87, .66)
        GameTooltip:AddLine("Diamond: Radar Color · Title: Difficulty Color", .66, .8, .78)
        GameTooltip:Show()
    end)
    frame.drag:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    frame.rows = {}
    for index = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetPoint("TOPLEFT", 12, -HEADER_HEIGHT)
        row:SetSize(WIDTH - 24, QUEST_ROW_HEIGHT)
        row.hover = row:CreateTexture(nil, "BACKGROUND")
        row.hover:SetAllPoints(row)
        row.hover:SetTexture(WHITE)
        row.hover:Hide()
        row.header = Label(row, 10)
        row.header:SetPoint("TOPLEFT", 7, -2)
        row.header:SetWidth(WIDTH - 45)
        row.header:SetJustifyH("LEFT")
        row.quest = CreateFrame("Frame", nil, row)
        row.quest:SetAllPoints(row)
        row.diamond = row.quest:CreateTexture(nil, "ARTWORK")
        row.diamond:SetSize(14, 14)
        row.diamond:SetPoint("TOPLEFT", 6, -7)
        row.center = row.quest:CreateTexture(nil, "ARTWORK")
        row.center:SetTexture(DIAMOND)
        row.center:SetSize(9, 9)
        row.center:SetPoint("CENTER", row.diamond, "CENTER")
        row.slot = Label(row.quest, 9)
        row.slot:SetFont(EllesmereUI and (EllesmereUI.EXPRESSWAY or EllesmereUI._font)
            or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        row.slot:SetPoint("CENTER", row.diamond, "CENTER", 1.5, 0)
        row.slot:SetSize(14, 14)
        row.slot:SetJustifyH("CENTER")
        row.name = Label(row.quest, 11)
        row.name:SetPoint("TOPLEFT", 28, -2)
        row.name:SetWidth(WIDTH - 48)
        row.name:SetJustifyH("LEFT")
        row.progress = Label(row.quest, 9)
        row.progress:SetPoint("TOPLEFT", 28, -17)
        row.progress:SetWidth(WIDTH - 48)
        row.progress:SetJustifyH("LEFT")
        row.focus = row.quest:CreateTexture(nil, "ARTWORK")
        row.focus:SetPoint("TOPLEFT", 25, -2)
        row.focus:SetSize(2, 27)
        row:SetScript("OnEnter", function(self)
            self.hover:Show()
            local radar = addon.VignetteRadarAPI
            if self.entry and self.entry.kind == "quest" and radar and radar.HighlightQuest then
                radar.HighlightQuest(self.entry.questID)
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.hover:Hide()
            local radar = addon.VignetteRadarAPI
            if radar and radar.HighlightQuest then radar.HighlightQuest(nil) end
        end)
        row:SetScript("OnClick", function(self)
            local entry = self.entry
            if not entry then return end
            if entry.kind == "header" then
                local saved = Settings().vignetteRadarQuestTrackerCollapsed
                saved[entry.title] = not saved[entry.title] or nil
                Draw()
            else
                local exploration = addon.VignetteRadarExploration
                if exploration and exploration.FocusQuest then
                    exploration.FocusQuest(entry.questID)
                    Draw()
                end
            end
        end)
        frame.rows[index] = row
    end
    frame.empty = Label(frame, 10)
    frame.empty:SetPoint("TOPLEFT", 21, -HEADER_HEIGHT - 7)
    frame.empty:SetTextColor(.67, .76, .77, 1)
    frame.footer = Label(frame, 9)
    frame.footer:SetPoint("BOTTOMLEFT", 14, 5)
    frame.footer:SetTextColor(.60, .73, .73, 1)
    frame:SetScript("OnMouseWheel", function(_, delta)
        local capacity = Settings().vignetteRadarQuestTrackerView == "tray" and 6 or VISIBLE_ROWS
        local maxOffset = math.max(0, #(frame.visibleEntries or {}) - capacity)
        offset = math.max(0, math.min(maxOffset, offset - delta))
        Draw()
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        if Settings().vignetteRadarQuestTrackerView == "tray" then
            local target = Settings().vignetteRadarQuestTrackerRetracted == true and 0 or 1
            if self.slideTarget ~= target then
                self.slideTarget, self.slideFrom, self.slideElapsed =
                    target, self.slideProgress or target, 0
            end
            if self.slideProgress ~= target then
                self.slideElapsed = math.min(SLIDE_SECONDS, self.slideElapsed + elapsed)
                local t = self.slideElapsed / SLIDE_SECONDS
                self.slideProgress = self.slideFrom + (target - self.slideFrom)
                    * (1 - (1 - t) * (1 - t) * (1 - t))
                if t == 1 then self.slideProgress = target end
                Place()
            end
        end
        self.themeElapsed = (self.themeElapsed or 0) + elapsed
        if self.themeElapsed < 1 then return end
        self.themeElapsed = 0
        local style = addon.VignetteRadarStyle
        if style and style.revision ~= lastThemeRevision then Draw() end
        if Settings().vignetteRadarQuestTrackerView == "tray" then Place() end
    end)
    frame:Hide()
    return frame
end

function API.Refresh()
    local panel = EnsureFrame()
    if not panel then return end
    if Settings().vignetteRadarQuestTrackerVisible ~= true then
        panel:Hide()
        if menu then menu:Hide() end
        return
    end
    entries = API.BuildEntries(MapID(), Settings().vignetteRadarQuestTrackerScope)
    Draw()
    panel:Show()
end

function API.Hide()
    Settings().vignetteRadarQuestTrackerVisible = false
    if frame then frame:Hide() end
    if menu then menu:Hide() end
end

function API.Toggle()
    local db = Settings()
    if db.vignetteRadarQuestTrackerView == "tray" then
        db.vignetteRadarQuestTrackerRetracted = db.vignetteRadarQuestTrackerVisible == true
            and not db.vignetteRadarQuestTrackerRetracted
        db.vignetteRadarQuestTrackerVisible = true
    else
        db.vignetteRadarQuestTrackerVisible = not db.vignetteRadarQuestTrackerVisible
    end
    API.Refresh()
    local _, root = RadarAnchor()
    if root and root.RefreshCornerTools then root.RefreshCornerTools() end
    return db.vignetteRadarQuestTrackerVisible
end

function API.ToggleTray()
    local db = Settings()
    if db.vignetteRadarQuestTrackerView ~= "tray" then
        if frame then frame.slideProgress = 0; frame.slideTarget = nil end
        db.vignetteRadarQuestTrackerView = "tray"
        db.vignetteRadarQuestTrackerRetracted = false
        db.vignetteRadarQuestTrackerVisible = true
        API.Refresh()
    else
        API.Toggle()
    end
    local _, root = RadarAnchor()
    if root and root.RefreshCornerTools then root.RefreshCornerTools() end
    return db.vignetteRadarQuestTrackerRetracted ~= true
end

function API.IsExpanded()
    local db = Settings()
    return frame and frame:IsShown() and db.vignetteRadarQuestTrackerRetracted ~= true
end

function API.IsShown() return frame and frame:IsShown() or false end
function API.SyncFocus() if frame and frame:IsShown() then Draw() end end

local events = CreateFrame and CreateFrame("Frame")
if events then
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
        "QUEST_LOG_UPDATE", "QUEST_POI_UPDATE", "QUEST_WATCH_LIST_CHANGED",
        "QUEST_WATCH_UPDATE", "TASK_PROGRESS_UPDATE", "QUEST_ACCEPTED",
        "QUEST_REMOVED", "QUEST_TURNED_IN" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        if C_Timer and C_Timer.After then
            C_Timer.After(.12, function() pending = false; API.Refresh() end)
        else
            pending = false
            API.Refresh()
        end
    end)
end
