local _, addon = ...
if type(addon) ~= "table" then return end

local API = {}
addon.VignetteRadarQuestTracker = API

local WIDTH, HEADER_HEIGHT, ROW_HEIGHT, VISIBLE_ROWS = 306, 84, 42, 8
local DIAMOND = "Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond.tga"
local HOLLOW = "Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond-hollow.tga"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local frame, entries, offset, pending = nil, {}, 0, false
local lastThemeRevision = -1

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

local function Place()
    if not frame then return end
    local db = Settings()
    local radar = addon.VignetteRadarAPI
    local anchor = radar and radar.GetPanel and radar.GetPanel()
    local dock = db.vignetteRadarQuestTrackerView == "tray" and anchor and anchor.IsShown
        and anchor:IsShown()
    local side = db.vignetteRadarQuestTrackerSide or "right"
    if dock then
        local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
        local left, right, top, bottom = anchor:GetLeft(), anchor:GetRight(),
            anchor:GetTop(), anchor:GetBottom()
        if not (Number(screenW) and Number(screenH) and Number(left) and Number(right)
            and Number(top) and Number(bottom)) then dock = false end
        if dock then
            local fits = {
                right = right + 6 + WIDTH <= screenW - 8,
                left = left - 6 - WIDTH >= 8,
                top = top + 6 + frame:GetHeight() <= screenH - 8,
                bottom = bottom - 6 - frame:GetHeight() >= 8,
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
                -- Shift along the chosen edge if a tall tracker would clip.
                local xOffset, yOffset = 0, 0
                if side == "right" or side == "left" then
                    local wantedTop = math.max(frame:GetHeight() + 8,
                        math.min(screenH - 8, top))
                    yOffset = wantedTop - top
                else
                    local wantedLeft = math.max(8, math.min(screenW - WIDTH - 8, left))
                    xOffset = wantedLeft - left
                end
                local key = table.concat({ "tray", side, math.floor(left), math.floor(right),
                    math.floor(top), math.floor(bottom), frame:GetHeight(), xOffset, yOffset }, ":")
                if frame._placementKey ~= key then
                    frame._placementKey = key
                    frame:ClearAllPoints()
                    frame.connector:ClearAllPoints()
                    if side == "right" then
                        frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, yOffset)
                        frame.connector:SetSize(6, 2)
                        frame.connector:SetPoint("LEFT", frame, "TOPLEFT", -6, -yOffset - 18)
                    elseif side == "left" then
                        frame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -6, yOffset)
                        frame.connector:SetSize(6, 2)
                        frame.connector:SetPoint("LEFT", frame, "TOPRIGHT", 0, -yOffset - 18)
                    elseif side == "top" then
                        frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", xOffset, 6)
                        frame.connector:SetSize(2, 6)
                        frame.connector:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 20 - xOffset, 0)
                    else
                        frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", xOffset, -6)
                        frame.connector:SetSize(2, 6)
                        frame.connector:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 20 - xOffset, 0)
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
    frame.connector:SetShown(dock == true)
    frame.side:SetShown(db.vignetteRadarQuestTrackerView == "tray")
    local titleCase = addon.VignetteRadarControls.TitleCase
        or function(value) return value:sub(1, 1):upper() .. value:sub(2) end
    frame.mode:SetText(db.vignetteRadarQuestTrackerView == "tray" and "Tray" or "Floating")
    frame.side:SetText(titleCase(frame.actualSide or db.vignetteRadarQuestTrackerSide or "right"))
end

local function Draw()
    if not frame then return end
    local controls = addon.VignetteRadarControls
    if controls then controls.RefreshRoundedStatusSurface(frame) end
    local style = addon.VignetteRadarStyle
    local ar, ag, ab = .05, .82, .62
    if style then ar, ag, ab = style.Color("accent") end
    frame.title:SetTextColor(ar, ag, ab, 1)
    frame.rule:SetColorTexture(ar, ag, ab, .2)
    frame.connector:SetColorTexture(ar, ag, ab, .68)
    local count = 0
    for _, entry in ipairs(entries) do if entry.kind == "quest" then count = count + 1 end end
    frame.count:SetText(count .. " QUEST" .. (count == 1 and "" or "S"))
    local scope = Settings().vignetteRadarQuestTrackerScope
    frame.scope:SetText(scope == "watched" and "Watched" or scope == "all" and "All" or "Local")
    frame.dots:SetText(Settings().vignetteRadarQuestDots and "Dots On" or "Dots Off")
    frame.numbers:SetText(Settings().vignetteRadarQuestNumbers and "# On" or "# Off")
    local collapsed = Settings().vignetteRadarQuestTrackerCollapsed
    local hasOpenHeader = false
    for _, entry in ipairs(entries) do
        if entry.kind == "header" and not collapsed[entry.title] then
            hasOpenHeader = true
            break
        end
    end
    frame.collapse:SetText(hasOpenHeader and "Fold" or "Expand")
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
    offset = math.max(0, math.min(offset, math.max(0, #visible - VISIBLE_ROWS)))
    local shown = math.min(#visible, VISIBLE_ROWS)
    frame:SetHeight(HEADER_HEIGHT + math.max(1, shown) * ROW_HEIGHT + 26)
    frame.empty:SetShown(#visible == 0)
    frame.empty:SetText(scope == "local" and "No Local Quests On This Map"
        or scope == "watched" and "No Watched Quests" or "No Quests In Your Log")
    frame.footer:SetText(#visible > VISIBLE_ROWS
        and ((offset + 1) .. "–" .. math.min(#visible, offset + VISIBLE_ROWS)
            .. " Of " .. #visible .. " · Scroll")
        or "Diamond = Radar Color  ·  Title = Difficulty")
    for index, row in ipairs(frame.rows) do
        local entry = visible[offset + index]
        row.entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            local isHeader = entry.kind == "header"
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
                row.slot:SetTextColor(r, g, b, 1)
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
end

local function EnsureFrame()
    if frame or type(CreateFrame) ~= "function" or not UIParent then return frame end
    frame = CreateFrame("Frame", "VignetteRadarQuestTrackerPanel", UIParent)
    frame:SetSize(WIDTH, HEADER_HEIGHT + ROW_HEIGHT + 26)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    addon.VignetteRadarControls.RoundedStatusSurface(frame)
    frame.connector = frame:CreateTexture(nil, "BORDER")
    frame.connector:SetTexture(WHITE)
    local position = Settings().vignetteRadarQuestTrackerPosition
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
        type(position) == "table" and Number(position.x) or 290,
        type(position) == "table" and Number(position.y) or -160)
    frame.title = Label(frame, 12, "QUEST TRACKER")
    frame.title:SetPoint("TOPLEFT", 14, -12)
    frame.count = Label(frame, 9, "0 QUESTS")
    frame.count:SetPoint("TOPLEFT", 14, -29)
    frame.rule = frame:CreateTexture(nil, "ARTWORK")
    frame.rule:SetPoint("TOPLEFT", 12, -43)
    frame.rule:SetPoint("TOPRIGHT", -12, -43)
    frame.rule:SetHeight(1)
    frame.mode = Button(frame, "Floating", 72)
    frame.mode:SetPoint("TOPRIGHT", -96, -8)
    frame.mode:SetScript("OnClick", function()
        local db = Settings()
        if db.vignetteRadarQuestTrackerView == "floating" then SavePosition() end
        db.vignetteRadarQuestTrackerView = db.vignetteRadarQuestTrackerView == "tray"
            and "floating" or "tray"
        Place()
    end)
    frame.side = Button(frame, "Right", 54)
    frame.side:SetPoint("TOPRIGHT", -38, -8)
    frame.side:SetScript("OnClick", function()
        local sides = { "left", "right", "top", "bottom" }
        local current = frame.actualSide or Settings().vignetteRadarQuestTrackerSide
        for index, candidate in ipairs(sides) do
            if candidate == current then
                for advance = 1, #sides do
                    Settings().vignetteRadarQuestTrackerSide = sides[(index + advance - 1) % #sides + 1]
                    Place()
                    if frame.actualSide ~= current then break end
                end
                break
            end
        end
    end)
    Hint(frame.mode, "Tracker View", "Floating can be moved freely. Tray joins the radar frame.")
    Hint(frame.side, "Tray Side", "Choose Left, Right, Top, or Bottom. The tray uses another edge when needed to fit on screen.")
    frame.scope = Button(frame, "Local", 66)
    frame.scope:SetPoint("TOPLEFT", 12, -52)
    frame.scope:SetScript("OnClick", function()
        local setting = Settings()
        local current = setting.vignetteRadarQuestTrackerScope
        setting.vignetteRadarQuestTrackerScope = current == "local" and "watched"
            or current == "watched" and "all" or "local"
        offset = 0
        API.Refresh()
    end)
    Hint(frame.scope, "Quest Scope", "Cycle Local, Watched, and All quests.")
    frame.dots = Button(frame, "Dots Off", 68)
    frame.dots:SetPoint("LEFT", frame.scope, "RIGHT", 5, 0)
    frame.dots:SetScript("OnClick", function()
        Settings().vignetteRadarQuestDots = not Settings().vignetteRadarQuestDots
        if addon.RefreshVignetteRadar then addon.RefreshVignetteRadar(true) end
        API.Refresh()
    end)
    Hint(frame.dots, "Radar Quest Diamonds", "Show or hide matching quest points on the radar.")
    frame.numbers = Button(frame, "# Off", 54)
    frame.numbers:SetPoint("LEFT", frame.dots, "RIGHT", 5, 0)
    frame.numbers:SetScript("OnClick", function()
        Settings().vignetteRadarQuestNumbers = not Settings().vignetteRadarQuestNumbers
        if addon.RefreshVignetteRadar then addon.RefreshVignetteRadar(false) end
        Draw()
    end)
    Hint(frame.numbers, "Quest Labels", "Show each quest color number inside its radar diamond.")
    frame.collapse = Button(frame, "Fold", 50)
    frame.collapse:SetPoint("LEFT", frame.numbers, "RIGHT", 5, 0)
    frame.collapse:SetScript("OnClick", function()
        local saved = Settings().vignetteRadarQuestTrackerCollapsed
        local fold = false
        for _, entry in ipairs(entries) do
            if entry.kind == "header" and not saved[entry.title] then fold = true; break end
        end
        for _, entry in ipairs(entries) do
            if entry.kind == "header" then saved[entry.title] = fold or nil end
        end
        offset = 0
        Draw()
    end)
    Hint(frame.collapse, "Fold Headers", "Collapse or expand all visible quest headers.")
    frame.close = Button(frame, "×", 22)
    frame.close:SetPoint("TOPRIGHT", -9, -8)
    frame.close:SetScript("OnClick", function() API.Hide() end)
    frame.drag = CreateFrame("Button", nil, frame)
    frame.drag:SetPoint("TOPLEFT", 8, -6)
    frame.drag:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -170, -42)
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
    frame.rows = {}
    for index = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetPoint("TOPLEFT", 12, -HEADER_HEIGHT - (index - 1) * ROW_HEIGHT)
        row:SetSize(WIDTH - 24, ROW_HEIGHT - 2)
        row.hover = row:CreateTexture(nil, "BACKGROUND")
        row.hover:SetAllPoints(row)
        row.hover:SetTexture(WHITE)
        row.hover:Hide()
        row.header = Label(row, 10)
        row.header:SetPoint("LEFT", 7, 0)
        row.header:SetWidth(WIDTH - 45)
        row.quest = CreateFrame("Frame", nil, row)
        row.quest:SetAllPoints(row)
        row.diamond = row.quest:CreateTexture(nil, "ARTWORK")
        row.diamond:SetSize(16, 16)
        row.diamond:SetPoint("TOPLEFT", 5, -9)
        row.slot = Label(row.quest, 8)
        row.slot:SetPoint("TOPLEFT", 27, -5)
        row.slot:SetSize(16, 12)
        row.name = Label(row.quest, 11)
        row.name:SetPoint("TOPLEFT", 46, -4)
        row.name:SetWidth(WIDTH - 67)
        row.progress = Label(row.quest, 9)
        row.progress:SetPoint("TOPLEFT", 46, -21)
        row.progress:SetWidth(WIDTH - 67)
        row.focus = row.quest:CreateTexture(nil, "ARTWORK")
        row.focus:SetPoint("TOPLEFT", 43, -2)
        row.focus:SetSize(2, 32)
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
    frame.empty:SetPoint("TOPLEFT", 21, -HEADER_HEIGHT - 14)
    frame.empty:SetTextColor(.67, .76, .77, 1)
    frame.footer = Label(frame, 9)
    frame.footer:SetPoint("BOTTOMLEFT", 14, 10)
    frame.footer:SetTextColor(.60, .73, .73, 1)
    frame:SetScript("OnMouseWheel", function(_, delta)
        local maxOffset = math.max(0, #(frame.visibleEntries or {}) - VISIBLE_ROWS)
        offset = math.max(0, math.min(maxOffset, offset - delta))
        Draw()
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
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
    if Settings().vignetteRadarQuestTrackerVisible ~= true then panel:Hide(); return end
    entries = API.BuildEntries(MapID(), Settings().vignetteRadarQuestTrackerScope)
    Draw()
    panel:Show()
end

function API.Hide()
    Settings().vignetteRadarQuestTrackerVisible = false
    if frame then frame:Hide() end
end

function API.Toggle()
    Settings().vignetteRadarQuestTrackerVisible = not Settings().vignetteRadarQuestTrackerVisible
    API.Refresh()
    return Settings().vignetteRadarQuestTrackerVisible
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
