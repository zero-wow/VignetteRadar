local _, addon = ...
if type(addon) ~= "table" then return end

-- The Intelligence panel presents evidence from optional, data-only systems.
-- It does no scanning or polling while closed; callers supply the current
-- selection and refresh it when their underlying evidence changes.
local Intelligence = {}
addon.VignetteRadarIntelligence = Intelligence

local WIDTH, HEIGHT, MAX_ROWS = 510, 388, 6
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TABS = { "Warband", "Resets", "Collections", "Phase", "Quest Chains" }
local ENABLE_KEYS = {
    Warband = "vignetteRadarWarbandBoardEnabled",
    Resets = "vignetteRadarResetPlannerEnabled",
    Collections = "vignetteRadarCollectionLensEnabled",
    Phase = "vignetteRadarPhaseLensEnabled",
    ["Quest Chains"] = "vignetteRadarQuestChainEnabled",
}
local context, selection = {}, {}
local panel, currentTab = nil, "Warband"
local resetActionMessage

local function Safe(value)
    if type(issecretvalue) ~= "function" then return true end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret ~= true
end

local function Field(record, key)
    if not Safe(record) or type(record) ~= "table" then return nil end
    local ok, value = pcall(function() return record[key] end)
    return ok and Safe(value) and value or nil
end

local function Text(value, fallback)
    if Safe(value) and type(value) == "string" and #value > 0 then
        return value:sub(1, 130)
    end
    return fallback
end

local function EvidenceLabel(value)
    local labels = {
        api = "API", bundled = "Bundled", ["trusted-pack"] = "Trusted Pack",
        manual = "Manual", observation = "Observation", none = "Unknown",
    }
    return labels[value] or "Unknown"
end

local function Settings()
    if type(addon.GetSettings) ~= "function" then return nil end
    local ok, db = pcall(addon.GetSettings)
    return ok and type(db) == "table" and db or nil
end

local function Enabled(tab)
    local db = Settings()
    return not db or db[ENABLE_KEYS[tab]] ~= false
end

local function Invoke(target, method, ...)
    if type(target) ~= "table" or type(target[method]) ~= "function" then return nil end
    local ok, result, other = pcall(target[method], target, ...)
    if ok and Safe(result) then return result, other end
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok and Safe(result) then return result end
end

local function Add(view, title, detail, tone, payload)
    if #view.rows >= (view.rowLimit or MAX_ROWS) then
        view.more = (view.more or 0) + 1
        return
    end
    view.rows[#view.rows + 1] = {
        title = Text(title, "Unknown"), detail = Text(detail, "Unknown"),
        tone = tone or "muted", payload = payload,
    }
end

local function TimeAgo(now, at)
    if type(now) ~= "number" or type(at) ~= "number" or at > now then
        return "Last Seen: Unknown"
    end
    local seconds = now - at
    if seconds < 60 then return "Last Seen: Just Now" end
    if seconds < 3600 then return "Last Seen: " .. math.floor(seconds / 60) .. " Min Ago" end
    if seconds < 86400 then return "Last Seen: " .. math.floor(seconds / 3600) .. " Hr Ago" end
    return "Last Seen: " .. math.floor(seconds / 86400) .. " Days Ago"
end

local function WarbandView(view)
    local board = context.board
    if not board then
        view.summary = "No Character Snapshots Available"
        Add(view, "Unknown", "Character status is not available yet.")
        return
    end
    local now = Call(context.getNow) or (type(time) == "function" and time()) or 0
    local character = Call(context.getCurrentCharacter)
    local key = Field(selection, "goalKey")
    local db = Settings() or {}
    if type(key) == "string" and key ~= "" then
        view.summary = "Goal: " .. Text(Field(selection, "goalName"), key)
        local rows = Invoke(board, "GetBoard", key, now, character)
        if type(rows) ~= "table" or #rows == 0 then
            Add(view, "Unknown", "No character has a saved snapshot for this goal.")
            return
        end
        for _, row in ipairs(rows) do
            if db.vignetteRadarWarbandView ~= "character"
                or row.character == character then
                local eligibility = row.eligibility == "available" and "Available"
                    or row.eligibility == "unavailable" and "Unavailable" or "Unknown"
                local evidence = row.stale and "Stale Snapshot"
                    or row.offline and "Offline Snapshot" or "Current Character"
                local detail = (row.offline and "Saved " or "") .. eligibility
                    .. " | " .. evidence .. " | "
                    .. TimeAgo(now, row.lastSeenAt)
                Add(view, Text(row.name, row.character), detail,
                    eligibility == "Available" and "positive" or "muted", row)
            end
        end
        if #view.rows == 0 then
            Add(view, "Unknown", "No snapshot for the current character.")
        end
        view.footer = "Offline eligibility is a saved observation, never live proof."
        return
    end
    view.summary = "Select A Goal To Compare Characters"
    local characters = board.characters
    if type(characters) ~= "table" then
        Add(view, "Unknown", "No character snapshots available.")
        return
    end
    local list = {}
    for id, row in pairs(characters) do
        list[#list + 1] = { id = id, row = row }
        if #list >= 16 then break end
    end
    table.sort(list, function(a, b)
        return (a.row.lastSeenAt or 0) > (b.row.lastSeenAt or 0)
    end)
    for _, item in ipairs(list) do
        Add(view, Text(item.row.name, item.id),
            "Saved Snapshot | " .. TimeAgo(now, item.row.lastSeenAt))
    end
    if #view.rows == 0 then Add(view, "Unknown", "No character snapshots available.") end
    view.footer = "Select a rare, treasure, or quest to inspect goal status."
end

local function ResetView(view)
    view.rowLimit = MAX_ROWS - 1 -- Reserve the final row for explicit rule actions.
    local planner = context.resetPlanner
    local goals = planner and planner.goals
    if type(goals) ~= "table" then
        view.summary = "No Reset Goals Available"
        Add(view, "Unknown", "Reset metadata has not been supplied.")
        return
    end
    local periods = Call(context.getResetPeriods) or {}
    local db = Settings() or {}
    local category = db.vignetteRadarResetCategory or "all"
    local list = {}
    for id, record in pairs(goals) do
        if category == "all" or record.resetKind == category then
            local result = Invoke(planner, "Evaluate", id, periods)
            if type(result) == "table" then list[#list + 1] = result end
        end
        if #list >= 256 then break end
    end
    local rank = { Confirmed = 1, Expected = 2, Unknown = 3, Completed = 4 }
    local kindNames = { daily = "Daily", weekly = "Weekly",
        ["one-time"] = "One-Time", unknown = "Unknown" }
    table.sort(list, function(a, b)
        local ra, rb = rank[a.status] or 5, rank[b.status] or 5
        if ra ~= rb then return ra < rb end
        return (a.name or a.id or "") < (b.name or b.id or "")
    end)
    local selectedKey = Field(selection, "goalKey")
    if type(selectedKey) ~= "string" or #selectedKey == 0
        or #selectedKey > 100 then selectedKey = nil end
    view.summary = selectedKey
        and ("Selected Goal: " .. Text(Field(selection, "goalName"), selectedKey))
        or ("Reset Goals: " .. #list)
    if selectedKey then
        local selected = Invoke(planner, "Evaluate", selectedKey, periods)
        Add(view, "Selected: " .. Text(Field(selection, "goalName"), selectedKey),
            selected and ((kindNames[selected.resetKind] or "Unknown") .. " | "
                .. Text(selected.status, "Unknown") .. " | "
                .. Text(selected.reason, "Evidence unavailable"))
                or "Unknown | Choose a reset rule below.",
            selected and selected.status == "Confirmed" and "positive" or "muted")
    end
    for _, result in ipairs(list) do
        if result.id ~= selectedKey then
            local status = Text(result.status, "Unknown")
            local reason = Text(result.reason, "Evidence unavailable")
            Add(view, result.name or result.id,
                (kindNames[result.resetKind] or "Unknown") .. " | "
                    .. status .. " | " .. reason,
                status == "Confirmed" and "positive"
                    or status == "Expected" and "caution" or "muted", result)
        end
    end
    if #view.rows == 0 then Add(view, "Unknown", "No goals match this reset filter.") end
    view.footer = resetActionMessage
        or "A reset rule never confirms current availability."
end

local function CollectionView(view)
    local lens = context.collectionLens
    if not lens then
        view.summary = "No Collection Links Available"
        Add(view, "Unknown", "Reward-source links have not been supplied.")
        return
    end
    local sourceKeys = Field(selection, "sourceKeys") or Field(selection, "sourceKey")
    if not sourceKeys then
        view.summary = "Select A Rare Or Treasure"
        Add(view, "Unknown", "No source selected for reward lookup.")
        return
    end
    local db = Settings() or {}
    local rewards, linkage = Invoke(lens, "GetRewards", sourceKeys,
        { hideCollected = db.vignetteRadarCollectionHideCollected == true })
    view.summary = "Collection Rewards: " .. (type(rewards) == "table" and #rewards or 0)
    if type(rewards) == "table" then
        for _, reward in ipairs(rewards) do
            local category = Text(reward.category, "Reward")
            local state = reward.status == "collected" and "Collected"
                or reward.status == "uncollected" and "Uncollected" or "Unknown"
            local link = EvidenceLabel(reward.linkEvidence)
            local observed = EvidenceLabel(reward.statusEvidence)
            Add(view, Text(reward.name, category .. " #" .. tostring(reward.rewardID or "?")),
                category:sub(1, 1):upper() .. category:sub(2) .. " | " .. state
                    .. " | Link: " .. link .. " | Status: " .. observed,
                state == "Uncollected" and "positive" or "muted", reward)
        end
    end
    if #view.rows == 0 then
        Add(view, "Unknown", linkage == "linked"
            and "Linked rewards are hidden by the current filter."
            or "No verified reward-source link for this point.")
    end
    view.footer = "Collection status does not prove character loot eligibility."
end

local function PhaseView(view)
    local lens = context.phaseLens
    local point = Field(selection, "point")
    if not lens or type(point) ~= "table" then
        view.summary = "Select A Saved Map Point"
        Add(view, "Unknown", "Phase evidence is unavailable for this selection.")
        return
    end
    local evaluation = Invoke(lens, "Evaluate", point,
        Call(context.getPhaseContext, point) or {})
    local status = type(evaluation) == "table" and evaluation.status or "unknown"
    local labels = {
        live = "Locally Detected", override = "Player Override",
        ["condition-match"] = "Condition Matches",
        ["condition-mismatch"] = "Condition Mismatch",
        ["possible-mismatch"] = "Possible Mismatch",
        unknown = "Unknown",
    }
    view.summary = "Phase: " .. (labels[status] or "Unknown")
    Add(view, Text(Field(point, "name"), "Selected Map Point"),
        Text(type(evaluation) == "table" and evaluation.reason,
            "Phase is not exposed by the client."),
        (status == "live" or status == "condition-match") and "positive"
            or status == "condition-mismatch" and "caution" or "muted")
    local evidence = type(evaluation) == "table" and evaluation.evidence
    Add(view, "Evidence", EvidenceLabel(evidence))
    local action = type(evaluation) == "table" and evaluation.action or "show"
    Add(view, "Display Action", Text(action, "show"):sub(1, 1):upper()
        .. Text(action, "show"):sub(2))
    view.footer = "Absence alone never proves a phase mismatch."
end

local function ChainView(view)
    local data = context.chainData
    local chains = data and data.chains
    local id = Field(selection, "chainID")
    if type(chains) ~= "table" then
        view.summary = "No Verified Quest Chain Data"
        Add(view, "Unknown", "Prerequisite data has not been supplied.")
        return
    end
    if not id then
        view.summary = "Choose A Quest Chain"
        local db = Settings() or {}
        local category = db.vignetteRadarQuestChainCategory or "all"
        for _, chain in ipairs(chains) do
            if category == "all" or chain.category == category then
                Add(view, chain.title,
                    "Source: " .. Text(chain.source, "Unknown") .. " | "
                        .. (chain.completeGraph and "Prerequisites Known"
                            or "Prerequisites Incomplete"),
                    "muted", { chainID = chain.id })
            end
        end
        if #view.rows == 0 then Add(view, "Unknown", "No chain matches this filter.") end
        view.footer = "Choose a chain to inspect its known steps."
        return
    end
    local chainAPI = addon.VignetteRadarQuestChain
    if not chainAPI or type(chainAPI.Inspect) ~= "function" then
        view.summary = "Quest Chain Unavailable"
        Add(view, "Unknown", "Quest chain inspection is unavailable.")
        return
    end
    local inspected = Call(chainAPI.Inspect, data, id,
        context.getQuestState, context.resolveQuestPoint)
    if type(inspected) ~= "table" then
        view.summary = "Unknown Quest Chain"
        Add(view, "Unknown", "The selected chain is not in the loaded data.")
        return
    end
    view.summary = Text(inspected.title, "Quest Chain")
    for _, step in ipairs(inspected.steps or {}) do
        local labels = { complete = "Complete", active = "Active",
            available = "Available", blocked = "Blocked", unknown = "Unknown" }
        local state = labels[step.state] or "Unknown"
        local detail = state .. " | " .. (step.point and "Mapped Location"
            or "Location Unknown")
        if step.state == "blocked" and #step.blockedBy > 0 then
            detail = detail .. " | Requires Quest #" .. step.blockedBy[1]
        elseif #step.unknownBy > 0 then
            detail = detail .. " | Prerequisite State Unknown"
        end
        Add(view, step.name, detail,
            step.state == "active" and "positive" or "muted",
            { step = step, chainView = inspected })
    end
    if #view.rows == 0 then Add(view, "Unknown", "No steps supplied.") end
    view.footer = inspected.prerequisitesKnown
        and "Only mapped steps can be selected for navigation."
        or "Prerequisite graph is incomplete; unknown steps remain unknown."
end

function Intelligence.GetView(tab)
    tab = ENABLE_KEYS[tab] and tab or currentTab
    local view = { tab = tab, rows = {}, summary = "", footer = "", enabled = Enabled(tab) }
    if not view.enabled then
        view.summary = tab .. " Is Disabled"
        Add(view, "Disabled", "Enable this page to inspect available evidence.")
        return view
    end
    if tab == "Warband" then WarbandView(view)
    elseif tab == "Resets" then ResetView(view)
    elseif tab == "Collections" then CollectionView(view)
    elseif tab == "Phase" then PhaseView(view)
    else ChainView(view) end
    if view.more then view.footer = "Showing " .. (view.rowLimit or MAX_ROWS) .. " rows; "
        .. view.more .. " more. " .. view.footer end
    return view
end

function Intelligence.SetContext(newContext)
    context = type(newContext) == "table" and newContext or {}
    local db = Settings()
    if db and context.phaseLens
        and (db.vignetteRadarPhaseLensAction or db.vignetteRadarPhaseHeuristics ~= nil) then
        Invoke(context.phaseLens, "SetOptions", {
            action = db.vignetteRadarPhaseLensAction,
            heuristic = db.vignetteRadarPhaseHeuristics,
        })
    end
    if panel and panel:IsShown() then Intelligence.Refresh() end
end

function Intelligence.SetSelection(newSelection)
    selection = type(newSelection) == "table" and newSelection or {}
    resetActionMessage = nil
    if panel and panel:IsShown() then Intelligence.Refresh() end
end

function Intelligence.SetEnabled(tab, enabled)
    local key, db = ENABLE_KEYS[tab], Settings()
    if not key or not db then return false end
    db[key] = enabled == true
    Intelligence.Refresh()
    return true
end

-- A user rule classifies a selected goal; it never calls Observe and cannot
-- create a reset period or an availability confirmation. Persistence is
-- required before the panel reports success.
function Intelligence.SetResetRule(kind)
    local planner = context.resetPlanner
    local key = Field(selection, "goalKey")
    if type(key) ~= "string" or #key == 0 or #key > 100 then
        return false, "Select a goal first"
    end
    if not planner or type(planner.goals) ~= "table" then
        return false, "Reset planner unavailable"
    end
    if kind ~= "daily" and kind ~= "weekly" and kind ~= "one-time"
        and kind ~= "remove" then return false, "Unknown reset rule" end
    if type(context.onIntelligenceChange) ~= "function" then
        return false, "Saving unavailable"
    end
    local old = planner.goals[key]
    if kind == "remove" then
        if not old then return false, "No saved rule to remove" end
        planner.goals[key] = nil
    else
        local name = Field(selection, "goalName")
        local category = Field(selection, "goalCategory")
        local changed = Invoke(planner, "SetGoal", key, {
            name = type(name) == "string" and name or key,
            category = type(category) == "string" and category or nil,
            resetKind = kind, source = "user-rule",
        })
        if changed ~= true then return false, "Could not set reset rule" end
        if old and old.resetKind ~= kind then
            local record = planner.goals[key]
            record.complete = false
            record.completedPeriod = nil
            record.confirmedPeriod = nil
            record.confirmedSession = nil
        end
    end
    local ok, saved = pcall(context.onIntelligenceChange, "resetPlanner", planner)
    if not ok or saved ~= true then
        planner.goals[key] = old
        resetActionMessage = "Could Not Save Reset Rule."
        Intelligence.Refresh()
        return false, "Saving failed"
    end
    local names = { daily = "Daily", weekly = "Weekly",
        ["one-time"] = "One-Time" }
    resetActionMessage = kind == "remove"
        and "Reset Rule Removed. Availability Was Not Changed."
        or (names[kind] .. " Rule Saved. Availability Was Not Changed.")
    Intelligence.Refresh()
    return true
end

local function Accent()
    local style = addon.VignetteRadarStyle
    if style and type(style.Color) == "function" then
        local ok, r, g, b = pcall(style.Color, "accent")
        if ok and type(r) == "number" then return r, g, b end
    end
    return .57, .73, 1
end

local function Label(parent, size, x, y, width, height)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(FONT, size, "")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetSize(width, height)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

local function Cycle(tab)
    local db = Settings()
    if not db then return end
    local key, choices
    if tab == "Warband" then
        key, choices = "vignetteRadarWarbandView", { "account", "character" }
    elseif tab == "Resets" then
        key, choices = "vignetteRadarResetCategory", { "all", "daily", "weekly", "one-time" }
    elseif tab == "Collections" then
        key = "vignetteRadarCollectionHideCollected"
        db[key] = db[key] ~= true
        Intelligence.Refresh()
        return
    elseif tab == "Phase" then
        key, choices = "vignetteRadarPhaseLensAction", { "show", "dim", "hide" }
    else
        key, choices = "vignetteRadarQuestChainCategory", { "all", "story", "side", "chosen" }
    end
    local index = 0
    for i, value in ipairs(choices) do if db[key] == value then index = i; break end end
    db[key] = choices[index % #choices + 1]
    if tab == "Phase" and context.phaseLens then
        Invoke(context.phaseLens, "SetOptions", {
            action = db[key], heuristic = db.vignetteRadarPhaseHeuristics == true,
        })
    end
    Intelligence.Refresh()
end

local function OptionText(tab)
    local db = Settings() or {}
    if tab == "Warband" then
        return "View: " .. (db.vignetteRadarWarbandView == "character"
            and "Character" or "Account")
    elseif tab == "Resets" then
        local value = db.vignetteRadarResetCategory or "all"
        return "Filter: " .. (value == "one-time" and "One-Time"
            or value:sub(1, 1):upper() .. value:sub(2))
    elseif tab == "Collections" then
        return db.vignetteRadarCollectionHideCollected and "Show Collected: Off"
            or "Show Collected: On"
    elseif tab == "Phase" then
        local value = db.vignetteRadarPhaseLensAction or "show"
        return "Action: " .. value:sub(1, 1):upper() .. value:sub(2)
    else
        local value = db.vignetteRadarQuestChainCategory or "all"
        return "Filter: " .. value:sub(1, 1):upper() .. value:sub(2)
    end
end

local function Build()
    if panel then return panel end
    local controls = addon.VignetteRadarControls
    if type(CreateFrame) ~= "function" or not controls or not controls.PopupSurface
        or not controls.Button then return nil end
    panel = CreateFrame("Frame", "VignetteRadarIntelligencePanel", UIParent, "BackdropTemplate")
    panel:SetSize(WIDTH, HEIGHT)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    controls.PopupSurface(panel)
    if type(UISpecialFrames) == "table" then
        UISpecialFrames[#UISpecialFrames + 1] = "VignetteRadarIntelligencePanel"
    end
    panel.title = Label(panel, 13, 18, -12, 405, 18)
    panel.title:SetText("Intelligence")
    panel.close = controls.Button(panel, "X", 24, 22)
    panel.close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -8)
    panel.close:SetScript("OnClick", function() Intelligence.Close() end)
    panel.tabs = {}
    for index, tab in ipairs(TABS) do
        local button = controls.Button(panel, tab, 89, 24)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + (index - 1) * 96, -43)
        button:SetScript("OnClick", function() currentTab = tab; Intelligence.Refresh() end)
        panel.tabs[tab] = button
    end
    panel.headerLine = panel:CreateTexture(nil, "ARTWORK")
    panel.headerLine:SetTexture(WHITE)
    panel.headerLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 17, -74)
    panel.headerLine:SetSize(WIDTH - 34, 1)
    panel.enable = controls.Button(panel, "Enabled", 92, 24)
    panel.enable:SetPoint("TOPLEFT", panel, "TOPLEFT", 17, -83)
    panel.enable:SetScript("OnClick", function()
        Intelligence.SetEnabled(currentTab, not Enabled(currentTab))
    end)
    panel.option = controls.Button(panel, "", 185, 24)
    panel.option:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -17, -83)
    panel.option:SetScript("OnClick", function() Cycle(currentTab) end)
    panel.extra = controls.Button(panel, "", 174, 24)
    panel.extra:SetPoint("TOPLEFT", panel, "TOPLEFT", 119, -83)
    panel.extra:SetScript("OnClick", function()
        if currentTab == "Phase" then
            local db = Settings()
            if not db then return end
            db.vignetteRadarPhaseHeuristics = db.vignetteRadarPhaseHeuristics ~= true
            if context.phaseLens then
                Invoke(context.phaseLens, "SetOptions", {
                    action = db.vignetteRadarPhaseLensAction or "show",
                    heuristic = db.vignetteRadarPhaseHeuristics,
                })
            end
            Intelligence.Refresh()
        elseif currentTab == "Quest Chains" then
            selection.chainID = nil
            Intelligence.Refresh()
        end
    end)
    panel.summary = Label(panel, 11, 19, -118, WIDTH - 38, 18)
    panel.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(WIDTH - 34, 32)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 17, -143 - (i - 1) * 34)
        row.face = row:CreateTexture(nil, "BACKGROUND")
        row.face:SetAllPoints(row)
        row.face:SetTexture(WHITE)
        row.title = Label(row, 10, 8, -3, WIDTH - 52, 13)
        row.detail = Label(row, 9, 8, -17, WIDTH - 52, 12)
        row:SetScript("OnClick", function(self)
            local payload = self.payload
            if type(payload) ~= "table" then return end
            if currentTab == "Resets" and payload.id then
                selection.goalKey = payload.id
                selection.goalName = payload.name
                resetActionMessage = nil
                Intelligence.Refresh()
            elseif payload.chainID then
                selection.chainID = payload.chainID
                Intelligence.Refresh()
            elseif payload.step and payload.step.point
                and type(context.onSelectStep) == "function" then
                local chainAPI = addon.VignetteRadarQuestChain
                local chosen = chainAPI and chainAPI.SelectMappedStep
                    and Call(chainAPI.SelectMappedStep,
                        payload.chainView, payload.step.questID)
                if chosen then Call(context.onSelectStep, chosen) end
            end
        end)
        row:SetScript("OnEnter", function(self)
            if self.payload then
                local r, g, b = Accent()
                self.face:SetVertexColor(r, g, b, .19)
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.face:SetVertexColor(.17, .21, .23, .30)
        end)
        panel.rows[i] = row
    end
    panel.resetActions = {}
    for index, action in ipairs({
        { label = "Daily", kind = "daily" },
        { label = "Weekly", kind = "weekly" },
        { label = "One-Time", kind = "one-time" },
        { label = "Remove", kind = "remove" },
    }) do
        local button = controls.Button(panel, action.label, 112, 28)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 17 + (index - 1) * 120, -315)
        button:SetScript("OnClick", function() Intelligence.SetResetRule(action.kind) end)
        button:Hide()
        panel.resetActions[action.kind] = button
    end
    panel.footerLine = panel:CreateTexture(nil, "ARTWORK")
    panel.footerLine:SetTexture(WHITE)
    panel.footerLine:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 17, 35)
    panel.footerLine:SetSize(WIDTH - 34, 1)
    panel.footer = Label(panel, 9, 19, -356, WIDTH - 38, 18)
    panel:Hide()
    return panel
end

function Intelligence.Refresh()
    if not panel or not panel:IsShown() then return Intelligence.GetView(currentTab) end
    local view = Intelligence.GetView(currentTab)
    local r, g, b = Accent()
    addon.VignetteRadarControls.RefreshPopupSurface(panel)
    panel.title:SetTextColor(r, g, b)
    panel.summary:SetTextColor(.85, .91, .93)
    panel.headerLine:SetVertexColor(r, g, b, .22)
    panel.footerLine:SetVertexColor(r, g, b, .16)
    panel.footer:SetTextColor(.57, .69, .72)
    panel.footer:SetText(view.footer)
    panel.summary:SetText(view.summary)
    panel.enable:SetText(view.enabled and "Enabled" or "Disabled")
    panel.option:SetText(OptionText(currentTab))
    panel.option:SetEnabled(view.enabled)
    local selectedKey = Field(selection, "goalKey")
    local canEditReset = currentTab == "Resets" and view.enabled
        and type(selectedKey) == "string" and #selectedKey > 0
        and #selectedKey <= 100 and context.resetPlanner
        and type(context.resetPlanner.goals) == "table"
        and type(context.onIntelligenceChange) == "function"
    for kind, button in pairs(panel.resetActions) do
        button:SetEnabled(canEditReset and (kind ~= "remove"
            or context.resetPlanner.goals[selectedKey] ~= nil) or false)
        local selectedGoal = canEditReset and context.resetPlanner.goals[selectedKey]
        if selectedGoal and selectedGoal.resetKind == kind then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
        if currentTab == "Resets" then button:Show() else button:Hide() end
    end
    if currentTab == "Phase" then
        local db = Settings() or {}
        panel.extra:SetText(db.vignetteRadarPhaseHeuristics == true
            and "Heuristic: On" or "Heuristic: Off")
        panel.extra:SetEnabled(view.enabled)
        panel.extra:Show()
    elseif currentTab == "Quest Chains" and selection.chainID then
        panel.extra:SetText("All Chains")
        panel.extra:SetEnabled(view.enabled)
        panel.extra:Show()
    else
        panel.extra:Hide()
    end
    for tab, button in pairs(panel.tabs) do
        if tab == currentTab then button:LockHighlight() else button:UnlockHighlight() end
    end
    for i, row in ipairs(panel.rows) do
        local data = view.rows[i]
        row.payload = data and data.payload or nil
        if data then
            row.title:SetText(data.title)
            row.detail:SetText(data.detail)
            row.face:SetVertexColor(.17, .21, .23, .30)
            if data.tone == "positive" then row.title:SetTextColor(.54, .91, .76)
            elseif data.tone == "caution" then row.title:SetTextColor(1, .77, .39)
            else row.title:SetTextColor(.86, .92, .94) end
            row.detail:SetTextColor(.62, .72, .75)
            row:Show()
        else
            row:Hide()
        end
    end
    return view
end

function Intelligence.Open(tab)
    if ENABLE_KEYS[tab] then currentTab = tab end
    local frame = Build()
    if not frame then return false, "UI controls unavailable" end
    frame:Show()
    Intelligence.Refresh()
    return true
end

function Intelligence.Close()
    if panel then panel:Hide() end
end

function Intelligence.Toggle(tab)
    if panel and panel:IsShown() then
        Intelligence.Close()
        return false
    end
    return Intelligence.Open(tab)
end

function Intelligence.IsOpen()
    return panel ~= nil and panel:IsShown()
end
