local sourcePath = arg[1] or "VignetteRadar_Radar.lua"
local legendSourcePath = arg[2] or "VignetteRadar_Legend.lua"
local targetPickerSourcePath = arg[3] or "VignetteRadar_TargetPicker.lua"
local optionsSourcePath = arg[4] or "VignetteRadar_Options.lua"
local quickSourcePath = arg[5] or "VignetteRadar_QuickConfig.lua"
unpack = table.unpack

local objects = {}
local methods = {}
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
function methods:GetRight() return self.right or ((self:GetLeft() or 0) + self:GetWidth() * self:GetScale()) end
function methods:SetPoint(...) self.point = { ... }; self.points = self.points or {}; self.points[#self.points + 1] = self.point end
function methods:ClearAllPoints() self.point, self.points = nil, {} end
function methods:SetAllPoints(...) self.allPoints = { ... } end
function methods:SetBackdrop(value) self.backdrop = value end
function methods:SetBackdropColor(...) self.backdropColor = { ... } end
function methods:SetBackdropBorderColor(...) self.backdropBorderColor = { ... } end
function methods:SetFrameStrata(value) self.strata = value end
function methods:SetFrameLevel(value) self.level = value end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:SetClipsChildren(value) self.clipsChildren = value end
function methods:SetScrollChild(value) self.scrollChild = value end
function methods:SetVerticalScroll(value) self.verticalScroll = value end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:SetMapID(value) self.mapID = value end
function methods:SetFillTexture(value) self.fillTexture = value end
function methods:SetBorderTexture(value) self.borderTexture = value end
function methods:SetFillAlpha(value) self.fillAlpha = value end
function methods:SetBorderAlpha(value) self.borderAlpha = value end
function methods:DrawNone() self.drawnQuests = {} end
function methods:DrawBlob(questID) self.drawnQuests = self.drawnQuests or {}; self.drawnQuests[#self.drawnQuests + 1] = questID end
function methods:UpdateMouseOverTooltip(x, y)
    self.hoverPosition = { x, y }
    if self.hoverQuestID and x >= .25 and x <= .75 and y >= .25 and y <= .75 then
        return self.hoverQuestID, 1
    end
end
function methods:SetMovable(value) self.movable = value end
function methods:EnableMouse(value) self.mouse = value end
function methods:EnableMouseWheel(value) self.mouseWheel = value end
function methods:SetEnabled(value) self.enabled = value end
function methods:RegisterForClicks(...) self.clickButtons = { ... } end
function methods:RegisterForDrag(...) self.dragButtons = { ... } end
function methods:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:SetScript(name, callback) self.scripts = self.scripts or {}; self.scripts[name] = callback end
function methods:HookScript(name, callback)
    local previous = self.scripts and self.scripts[name]
    self:SetScript(name, function(...)
        if previous then previous(...) end
        callback(...)
    end)
end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:LockHighlight() self.highlightLocked = true end
function methods:UnlockHighlight() self.highlightLocked = false end
function methods:SetHighlightTexture(texture) self.highlight = setmetatable({ texture = texture }, { __index = methods }) end
function methods:GetHighlightTexture() return self.highlight end
function methods:SetTexture(value) self.texture = value end
function methods:SetAtlas(value) self.atlas = value end
function methods:SetColorTexture(...) self.color = { ... } end
function methods:SetVertexColor(...) self.vertexColor = { ... } end
function methods:SetAlpha(value) self.alpha = value end
function methods:GetAlpha() return self.alpha == nil and 1 or self.alpha end
function methods:SetIgnoreParentAlpha(value) self.ignoreParentAlpha = value end
function methods:SetScale(value) self.scale = value end
function methods:GetScale() return self.scale or 1 end
function methods:GetEffectiveScale() return 1 end
function methods:SetThickness(value) self.thickness = value end
function methods:SetStartPoint(...)
    assert(select("#", ...) == 4, "line endpoints take anchor, frame, x, y")
    self.startPoint = { ... }
    assert(type(self.startPoint[3]) == "number" and type(self.startPoint[3]) == "number")
end
function methods:SetEndPoint(...)
    assert(select("#", ...) == 4, "line endpoints take anchor, frame, x, y")
    self.endPoint = { ... }
    assert(type(self.endPoint[3]) == "number" and type(self.endPoint[3]) == "number")
end
function methods:SetFont(...) self.font = { ... } end
function methods:SetFontObject(value) self.fontObject = value end
function methods:SetTextInsets(...) self.textInsets = { ... } end
function methods:SetAutoFocus(value) self.autoFocus = value end
function methods:SetMaxLetters(value) self.maxLetters = value end
function methods:GetText() return self.text end
function methods:ClearFocus() self.focused = false end
function methods:SetFontString(value) self.fontString = value end
function methods:SetText(value) self.text = value; if self.fontString then self.fontString:SetText(value) end end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:SetJustifyH(value) self.justifyH = value end
function methods:SetWordWrap(value) self.wordWrap = value end
function methods:IsShown() return self.shown == true end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false; if self.scripts and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:StartMoving() self.moving = true end
function methods:StopMovingOrSizing() self.moving = false end
function methods:GetLeft()
    if self.left then return self.left end
    if self.name == "VignetteRadarPanel" and self.point then return self.point[4] end
    return 30
end
function methods:GetTop()
    if self.top then return self.top end
    if self.name == "VignetteRadarPanel" and self.point then return UIParent:GetHeight() + self.point[5] end
    return 380
end
function methods:GetBottom() return self.bottom or (self:GetTop() - self:GetHeight() * self:GetScale()) end
function methods:CreateTexture(_, layer)
    local texture = setmetatable({ kind = "Texture", parent = self, layer = layer }, { __index = methods })
    objects[#objects + 1] = texture
    return texture
end
function methods:CreateFontString()
    local label = setmetatable({ kind = "FontString", parent = self }, { __index = methods })
    objects[#objects + 1] = label
    return label
end
function methods:CreateLine(_, layer)
    local line = setmetatable({ kind = "Line", parent = self, layer = layer }, { __index = methods })
    objects[#objects + 1] = line
    return line
end

function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, name = name, parent = parent, shown = false, enabled = true }, { __index = methods })
    objects[#objects + 1] = frame
    if name then _G[name] = frame end
    return frame
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1600, 900)
UIParent:Show()
STANDARD_TEXT_FONT = "default.ttf"
SlashCmdList = {}
GameTooltip = {
    SetOwner = function(self, owner) self.owner = owner end,
    GetOwner = function(self) return self.owner end,
    SetText = function(self, value) self.text = value end,
    AddLine = function(self, value) self.line = value end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
    IsShown = function(self) return self.shown == true end,
}
C_Timer = { After = function(_, callback) callback() end }
C_Map = {
    GetBestMapForUnit = function() return 777 end,
    GetPlayerMapPosition = function() return { x = 0.5, y = 0.5 } end,
    GetWorldPosFromMapPos = function(_, position) return 42, { x = position.x * 1000, y = position.y * 1000 } end,
}
C_VignetteInfo = {
    GetVignettes = function() return {} end,
    GetVignetteInfo = function() end,
    GetVignettePosition = function() end,
    GetRecommendedGroupSize = function(key)
        if key == "rare" then return 3, 5 end
    end,
}
C_Texture = { GetAtlasInfo = function(name) return name == "VignetteLoot" and {} or nil end }
GetPlayerFacing = function() return 0 end
issecretvalue = function() return false end

EllesmereUI = nil
local openedCategory, registeredCategory
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        assert(frame.name == name and name == "Vignette Radar", "standalone options category needs the addon name")
        return { GetID = function() return 517 end }
    end,
    RegisterAddOnCategory = function(category) registeredCategory = category end,
    OpenToCategory = function(categoryID) openedCategory = categoryID end,
}

local settings = { vignetteRadarEnabled = true, vignetteRadarHideWhenEmpty = true, vignetteRadarRange = 450 }
local addon = { GetSettings = function() return settings end }
VignetteRadarDB = settings
assert(loadfile("VignetteRadar_Core.lua"))("VignetteRadar", addon)
assert(loadfile("VignetteRadar_Style.lua"))("VignetteRadar", addon)
assert(loadfile("VignetteRadar_Controls.lua"))("VignetteRadar", addon)
assert(loadfile("VignetteRadar_Features.lua"))("VignetteRadar", addon)
assert(loadfile("VignetteRadar_Exploration.lua"))("VignetteRadar", addon)
assert(loadfile(legendSourcePath))("VignetteRadar", addon)
assert(loadfile(targetPickerSourcePath))("VignetteRadar", addon)
assert(loadfile(sourcePath))("VignetteRadar", addon)
assert(loadfile(optionsSourcePath))("VignetteRadar", addon)
assert(loadfile(quickSourcePath))("VignetteRadar", addon)

local optionsEvent
for _, object in ipairs(objects) do
    if object.events and object.events.PLAYER_LOGIN then optionsEvent = object end
end
assert(optionsEvent and optionsEvent.scripts.OnEvent, "standalone addon must register its own settings")
optionsEvent.scripts.OnEvent(optionsEvent)
local optionsPanel = assert(_G.VignetteRadarOptionsPanel, "standalone addon needs a populated settings panel")
assert(optionsPanel.width == 520 and optionsPanel.height == 365 and registeredCategory,
    "standalone options must fit the Settings canvas without EllesmereUI")
local toggles, lowerRange
toggles = {}
for _, object in ipairs(objects) do
    if object.parent == optionsPanel.pages.Radar and object.kind == "CheckButton" then
        toggles[#toggles + 1] = object
    elseif object.parent == optionsPanel.pages.Radar and object.text == "-" then
        lowerRange = object
    end
end
assert(#toggles == 4 and lowerRange, "standalone options must expose visibility, data scope, and range controls")
lowerRange.scripts.OnClick(lowerRange)
lowerRange.scripts.OnClick(lowerRange)
assert(settings.vignetteRadarRange == 150 and lowerRange.enabled == false,
    "range controls must update saved settings and stop at the smallest range")
settings.vignetteRadarRange = 450
SlashCmdList.VIGNETTERADAR("config")
assert(openedCategory == 517, "config command must open the standalone AddOns settings category")

settings.vignetteRadarEnabled = false
settings.vignetteRadarScale = 1.35
SlashCmdList.VIGNETTERADAR("preview")
local panel = assert(_G.VignetteRadarPanel, "preview must construct the radar panel")
local launcher = assert(_G.VignetteRadarLauncher, "preview must construct the draggable launcher")
assert(panel:GetScale() == 1.35, "a saved frame size must be restored when the radar is first created")
settings.vignetteRadarScale = 1
panel:SetScale(1)
assert(settings.vignetteRadarEnabled == false, "layout preview must not silently enable live tracking")
assert(panel:IsShown() and panel.width == 220 and panel.height == 278, "preview must reserve space for zoom controls")
SlashCmdList.VIGNETTERADAR("explore")
local explore = assert(_G.VignetteRadarExplorePanel)
assert(explore:IsShown() and explore.width == 330 and explore.height == 425,
    "exploration controls must fit the compact popout")
for _, content in pairs(explore.pages) do
    assert(content.point[3] == -73 and content.height == 346 and 73 + content.height < explore.height,
        "all exploration pages must stay inside the popout")
end
assert(explore.pages.Modes:IsShown() and not explore.pages.Tools:IsShown())
explore.tabs.Tools.scripts.OnClick(explore.tabs.Tools)
assert(explore.pages.Tools:IsShown() and not explore.pages.Modes:IsShown())
assert(panel.field.width == 200 and panel.field.height == 200 and panel.field.point[1] == "BOTTOM"
    and panel.field.point[3] == 35, "radar field must fit between header and zoom controls with visible gutters")
assert(panel.drag.width == 106 and panel.target.point[1] == "TOPRIGHT"
    and panel.legend.point[1] == "TOPRIGHT" and panel.close.point[1] == "TOPRIGHT",
    "drag target must stop before the focus, legend, and close controls")
assert(panel.title.font[1] == STANDARD_TEXT_FONT, "radar must work with the standard client font")
assert(panel.summary.text == "PREVIEW" and #panel.blips == 4,
    "preview must explicitly show rare, boss, treasure, and event samples")
local firstBlip, secondBlip = panel.blips[1], panel.blips[2]
for _, blip in ipairs(panel.blips) do
    assert(blip._seen and blip.target.sample == true, "preview marker must be labeled as sample data")
    assert(blip.target.category and blip.dot.vertexColor[4] == 1,
        "preview and live markers must use an opaque category treatment")
    local x, y = blip.point[4], blip.point[5]
    assert(math.sqrt(x * x + y * y) < 91, "preview markers must remain inside the radar ring")
end
panel.scripts.OnUpdate(panel, 0.06)
assert(panel.blips[1] == firstBlip and panel.blips[2] == secondBlip and firstBlip:IsShown() and secondBlip:IsShown(),
    "render ticks must retain stable blip buttons so hover tooltips do not flicker")
assert(#panel.outerRing == 64 and #panel.middleRing == 64 and #panel.innerRing == 64,
    "all radar rings must be complete and bounded")
assert(panel.clamped == true and panel.movable == true, "panel must remain movable and clamped to screen")
assert(launcher.width == 44 and launcher.height == 44 and launcher.clamped == true and launcher.movable == true,
    "launcher must be a compact draggable instrument that stays on screen")
assert(launcher.clickButtons[1] == "LeftButtonUp" and launcher.clickButtons[2] == "RightButtonUp"
    and launcher.dragButtons[1] == "LeftButton", "launcher must expose distinct click and drag gestures")
assert(#launcher.ring == 24 and #launcher.sweepLines == 2
    and launcher.bezel.texture:find("vignette%-radar%-bezel%.tga$")
    and launcher.closed.texture:find("vignette%-radar%-closed%.tga$"),
    "launcher needs matching jeweled closed and hollow live states")
assert(launcher.rangeLabel.text == "BOSS" and #launcher.miniBlips == 5 and launcher.miniBlips[1]:IsShown(),
    "launcher preview must mirror category markers with a plain boss cue")
launcher.scripts.OnUpdate(launcher, 0.05)
assert(launcher.bezel.alpha >= 0.93 and launcher.bezel.alpha <= 0.95
    and launcher.shadow == nil and launcher.halo == nil and launcher.alert == nil,
    "detection feedback must stay on the centered bezel without offset circular shadow or alert layers")

panel.legend.scripts.OnClick(panel.legend)
local legendPanel = assert(_G.VignetteRadarLegendPanel, "radar header must open its attached legend")
assert(legendPanel:IsShown() and legendPanel.point[1] == "TOPLEFT" and legendPanel.point[3] == "TOPRIGHT",
    "legend must open outside the radar with a visible gutter")
legendPanel.rows.rare.scripts.OnClick(legendPanel.rows.rare)
assert(settings.vignetteRadarHighlight == "rare" and firstBlip:GetAlpha() == 1 and secondBlip:GetAlpha() == 0.18,
    "spotlighting a category must keep its dots strong and dim the remaining context")
legendPanel.rows.treasure.toggle.scripts.OnClick(legendPanel.rows.treasure.toggle)
assert(settings.vignetteRadarCategories.treasure == false and not secondBlip:IsShown(),
    "legend category switches must remove disabled dots from the radar immediately")

-- Restore treasure so the specific-vignette picker can exercise more than one row.
addon.VignetteRadarLegend.SetCategoryEnabled("treasure", true)
panel.target.scripts.OnClick(panel.target, "LeftButton")
local targetPanel = assert(_G.VignetteRadarTargetPickerPanel, "reticle button must open its target picker")
assert(targetPanel:IsShown() and targetPanel.rows[1].target.key == "preview-boss",
    "specific-vignette picker must prioritize bosses before ordinary detections")
local rareRow
for _, row in ipairs(targetPanel.rows) do if row.target and row.target.key == "preview-rare" then rareRow = row end end
assert(rareRow).scripts.OnClick(rareRow)
assert(addon.VignetteRadarTargetPicker.GetFocus() == "preview-rare" and firstBlip:IsShown()
    and not secondBlip:IsShown(), "specific focus must isolate one vignette across the full radar")
panel.target.scripts.OnClick(panel.target, "RightButton")
assert(addon.VignetteRadarTargetPicker.GetFocus() == nil,
    "right-clicking the reticle must restore all category-filtered vignettes")
SlashCmdList.VIGNETTERADAR("off")
assert(launcher.closed:IsShown() and not launcher.bezel:IsShown() and not launcher.miniBlips[1]:IsShown(),
    "disabled tracking must close the live center into its filled jeweled state")

-- Exercise the complete feature path with deterministic live vignette data.
local now, combat, instance, shift, alt = 100, false, false, false, false
local mapID, guids, tracked, sounds = 777, {}, nil, {}
GetTime = function() return now end
InCombatLockdown = function() return combat end
IsInInstance = function() return instance end
IsShiftKeyDown = function() return shift end
IsAltKeyDown = function() return alt end
local health = 0.42
local liveInfo = {
    rare = { name = string.rep("Long rare name ", 5), atlasName = "VignetteKill", vignetteID = 101, onMinimap = true },
    treasure = { name = "Nearby treasure", atlasName = "VignetteLoot", vignetteID = 102, onMinimap = true },
    event = { name = "Event", atlasName = "VignetteEvent", vignetteID = 103, onMinimap = true },
}
local livePositions = { rare = { x = 0.85, y = 0.5 }, treasure = { x = 0.58, y = 0.5 }, event = { x = 0.52, y = 0.51 } }
C_Map.GetBestMapForUnit = function() return mapID end
C_VignetteInfo.GetVignettes = function() return guids end
C_VignetteInfo.GetVignetteInfo = function(key) return liveInfo[key] end
C_VignetteInfo.GetVignettePosition = function(key) return livePositions[key] end
C_VignetteInfo.GetHealthPercent = function() return health end
C_SuperTrack = { SetSuperTrackedVignette = function(key) tracked = key end }
SOUNDKIT = { TELL_MESSAGE = 1, RAID_WARNING = 2 }
PlaySound = function(sound) sounds[#sounds + 1] = sound end
addon.VignetteRadarLegend.SetHighlight(nil)
SlashCmdList.VIGNETTERADAR("on") -- Seed an empty first scan without alerts.
now, guids = 101, { "rare", "treasure" }
addon.VignetteRadarAPI.Refresh(true)
local rareBlip = assert(panel.blipByKey.rare)
assert(#sounds == 0 and rareBlip.target.newUntil > now, "default detection alerts must pulse silently")
assert(rareBlip.dot.texture:find("Skull", 1, true) and panel.blipByKey.treasure.dot.atlas == "VignetteLoot",
    "live rares and treasures must use familiar skull and chest imagery")
rareBlip.scripts.OnClick(rareBlip, "LeftButton")
assert(panel.focusReadout:IsShown() and panel.height == 324 and panel.field.point[3] == 81,
    "focusing must reserve exactly the footer space without moving the radar into its header")
assert(panel.focusMeta.text:find("350 yd", 1, true) and panel.focusMeta.text:find("42% HP", 1, true),
    "focused live rare must show distance and available health")
assert(panel.focusName.width == 172 and panel.focusMeta.width == 172,
    "long target text must stay bounded within the focus footer")
-- Field bottom is 81; divider y72 leaves 9px. Focus ends y66, above the zoom row.
assert(panel.focusReadout.point[3] + panel.focusReadout.height <= 66
    and panel.focusDivider.point[3] == 72 and panel.field.point[3] >= 81,
    "focus controls and radar must keep clear gutters on both sides of their divider")
settings.vignetteRadarRange = 150
addon.VignetteRadarAPI.Refresh(true)
assert(panel.edgeArrow:IsShown() and not panel.blipByKey.rare,
    "a live focused target outside range must become a bounded direction arrow")
local edgeX, edgeY = panel.edgeArrow.point[4], panel.edgeArrow.point[5]
assert(math.sqrt(edgeX * edgeX + edgeY * edgeY) + 7 <= 83,
    "edge arrow must leave a visible gutter before the outer ring")
shift = true
panel.edgeArrow.scripts.OnClick(panel.edgeArrow, "LeftButton")
assert(tracked == "rare", "shift-click must navigate to the actual live target")
shift, alt = false, true
panel.focusReadout.scripts.OnClick(panel.focusReadout, "LeftButton")
alt = false
assert(addon.VignetteRadarFeatures.IsFavorite(panel.focusReadout.target), "alt-click must persist a favorite")
addon.VignetteRadarTargetPicker.ClearFocus()
assert(addon.VignetteRadarAPI.GetSelectableTargets()[1].key == "rare", "favorites must rank before nearer ordinary targets")
settings.vignetteRadarRange = 450
addon.VignetteRadarAPI.Refresh(true)
rareBlip = panel.blipByKey.rare
assert(rareBlip.favorite:IsShown(), "favorite marker must remain recognizable without hovering")
rareBlip.scripts.OnClick(rareBlip, "LeftButton")
now, guids = 102, { "treasure" }
addon.VignetteRadarAPI.Refresh(true)
rareBlip = assert(panel.blipByKey.rare)
assert(rareBlip.target.stale and not rareBlip.dot:IsShown() and panel.focusMeta.text:find("seen", 1, true)
    and not panel.focusMeta.text:find("HP", 1, true), "lost targets must become hollow last-seen markers without stale health")
assert(not panel.edgeArrow:IsShown(), "stale snapshots must not present live out-of-range navigation")
shift, tracked = true, nil
rareBlip.scripts.OnClick(rareBlip, "LeftButton")
assert(tracked == nil, "last-seen positions must not silently navigate as live targets")
shift = false
local initialAlpha = rareBlip:GetAlpha()
now = 107
addon.VignetteRadarAPI.Refresh(true)
assert(panel.blipByKey.rare:GetAlpha() < initialAlpha, "last-seen markers must fade with elapsed time")
now = 113
addon.VignetteRadarAPI.Refresh(true)
assert(not panel.blipByKey.rare and not panel.focusReadout:IsShown() and panel.height == 278
    and panel.field.point[3] == 35, "expiry must clear focus and release its space while keeping zoom controls")

settings.vignetteRadarAlertSound = true
combat, now, guids = true, 120, { "treasure", "rare" }
addon.VignetteRadarAPI.Refresh(true)
assert(panel:GetAlpha() == 0.35 and launcher:GetAlpha() == 0.35 and #sounds == 0,
    "combat must fade both surfaces and suppress detection sounds")
assert(not panel.combatToggle.keepVisible and panel.combatToggle.backdrop == nil
    and #panel.combatToggle.eye == 4 and panel.combatToggle.pupil,
    "combat visibility must use a borderless eye icon rather than a lettered square")
assert(panel.combatToggle.eye[1].color[4] < 1,
    "the inactive eye must look subdued without introducing a boxed control")
assert(panel.combatToggle.ignoreParentAlpha == true,
    "the quick combat switch must remain legible while the radar is faded")
panel.combatToggle.scripts.OnClick(panel.combatToggle)
assert(settings.vignetteRadarKeepVisibleCombat == true and settings.vignetteRadarQuietCombat == true
    and panel.combatToggle.keepVisible and panel:GetAlpha() == 1 and launcher:GetAlpha() == 1
    and panel.combatToggle.eye[1].color[4] == 1
    and addon.VignetteRadarFeatures.IsQuiet() and #sounds == 0,
    "the footer eye must restore combat visibility without unmuting alerts or rescanning")
panel.combatToggle.scripts.OnClick(panel.combatToggle)
assert(settings.vignetteRadarKeepVisibleCombat == false and settings.vignetteRadarQuietCombat == true
    and not panel.combatToggle.keepVisible
    and panel:GetAlpha() == .35 and launcher:GetAlpha() == .35,
    "clicking the square again must restore combat fading")
combat, now = false, 125
addon.VignetteRadarAPI.Refresh(true)
assert(panel:GetAlpha() == 1 and launcher:GetAlpha() == 1 and #sounds == 0,
    "leaving combat must restore opacity without replaying suppressed detections")
instance = true
addon.VignetteRadarAPI.Refresh(true)
assert(panel:GetAlpha() == 0.35 and launcher:GetAlpha() == 0.35,
    "instance quiet mode must fade both surfaces")
panel.combatToggle.scripts.OnClick(panel.combatToggle)
assert(settings.vignetteRadarKeepVisibleCombat == true and panel:GetAlpha() == 1
    and launcher:GetAlpha() == 1 and addon.VignetteRadarFeatures.IsQuiet() and #sounds == 0,
    "stay fully visible must restore both surfaces inside an instance without unmuting alerts")
combat = true
addon.VignetteRadarAPI.Refresh(true)
assert(panel:GetAlpha() == 1 and launcher:GetAlpha() == 1,
    "stay fully visible must keep both surfaces opaque when combat starts inside an instance")
combat = false
addon.VignetteRadarAPI.Refresh(true)
assert(panel:GetAlpha() == 1 and launcher:GetAlpha() == 1,
    "leaving combat inside an instance must preserve stay fully visible")
panel.combatToggle.scripts.OnClick(panel.combatToggle)
assert(settings.vignetteRadarKeepVisibleCombat == false and panel:GetAlpha() == 0.35
    and launcher:GetAlpha() == 0.35,
    "turning stay fully visible off must restore instance fading on both surfaces")
instance = false
addon.VignetteRadarAPI.Refresh(true)
assert(panel:GetAlpha() == 1 and launcher:GetAlpha() == 1,
    "leaving the instance must restore normal opacity")
local treasureBlip = panel.blipByKey.treasure
treasureBlip.scripts.OnClick(treasureBlip, "RightButton")
assert(not panel.blipByKey.treasure and next(settings.vignetteRadarIgnored) == nil,
    "plain right-click must ignore only for this session")
rareBlip = panel.blipByKey.rare
shift = true
rareBlip.scripts.OnClick(rareBlip, "RightButton")
shift = false
assert(next(settings.vignetteRadarIgnored) ~= nil and #addon.VignetteRadarAPI.GetSelectableTargets() == 0,
    "shift-right-click must persist ignore and remove its target immediately")
addon.VignetteRadarFeatures.ClearIgnored()
addon.VignetteRadarAPI.Refresh(true)
assert(#addon.VignetteRadarAPI.GetSelectableTargets() == 2, "clearing ignores must restore current detections")
settings.vignetteRadarMarkerSize = 9
addon.VignetteRadarAPI.Refresh(true)
for _, blip in pairs(panel.blipByKey) do
    local x, y = blip.point[4], blip.point[5]
    assert(math.sqrt(x * x + y * y) + blip.width / 2 < 91,
        "largest supported marker hit target must remain clear of the outer ring")
end
now, guids = 200, { "treasure" }
addon.VignetteRadarAPI.Refresh(true)
now, guids = 270, { "rare", "treasure" }
addon.VignetteRadarAPI.Refresh(true)
assert(#sounds == 1 and sounds[1] == SOUNDKIT.RAID_WARNING,
    "an eligible favorite rediscovery after cooldown must play its distinct enabled sound")
addon.VignetteRadarAPI.Refresh(true)
assert(#sounds == 1, "repeated refreshes must not replay the same discovery sound")
-- A new map silently seeds live entries and drops old snapshots/focus.
addon.HandleVignetteClick(panel.blipByKey.rare.target, "LeftButton")
mapID, guids, now = 778, {}, 280
addon.VignetteRadarAPI.Refresh(true)
assert(#addon.VignetteRadarAPI.GetTargets() == 0 and addon.VignetteRadarTargetPicker.GetFocus() == nil,
    "zone transitions must not retain old-map targets")
Enum = { QuestTagType = { WorldBoss = 99 } }
C_QuestLog = { GetQuestTagInfo = function(id)
    return id == 700 and { worldQuestType = Enum.QuestTagType.WorldBoss } or nil
end }
liveInfo.boss = { name = "World boss", atlasName = "Unclassified", rewardQuestID = 700, vignetteID = 700, onMinimap = true }
livePositions.boss = { x = 0.55, y = 0.55 }
now, guids = 281, { "boss", "rare" }
addon.VignetteRadarAPI.Refresh(true)
local bossBlip = assert(panel.blipByKey.boss)
rareBlip = assert(panel.blipByKey.rare)
assert(bossBlip.target.isWorldBoss and bossBlip.target.category == "rare"
    and bossBlip.dot.width > rareBlip.dot.width and bossBlip.dot.vertexColor[1] == 1
    and bossBlip.dot.vertexColor[2] < 0.3 and rareBlip.dot.vertexColor[3] == 1,
    "confirmed world bosses must have larger red skulls distinct from silver-blue rares")
assert(launcher.rangeLabel.text == "BOSS" and launcher.bosses == 1,
    "a nearby confirmed boss must have a plain-language launcher cue")
bossBlip.scripts.OnClick(bossBlip, "LeftButton")
assert(panel.focusMeta.text:find("BOSS", 1, true), "focused boss identity must be explicit without color knowledge")
now, guids = 282, { "rare" }
addon.VignetteRadarAPI.Refresh(true)
assert(panel.blipByKey.boss.target.stale and panel.blipByKey.boss.target.isWorldBoss
    and launcher.rangeLabel.text ~= "BOSS", "last-seen boss classification must persist without implying a live nearby boss")

-- Wider ranges reveal only positions actually supplied by the game.
addon.VignetteRadarTargetPicker.ClearFocus()
settings.vignetteRadarAlertSound = false
liveInfo.far = { name = "Far map treasure", atlasName = "VignetteLoot", vignetteID = 800,
    onMinimap = false, onWorldMap = true, inFogOfWar = false }
liveInfo.fogged = { name = "Fogged", atlasName = "VignetteLoot", vignetteID = 801,
    onMinimap = false, onWorldMap = true, inFogOfWar = true }
liveInfo.unpublished = { name = "Unpublished", atlasName = "VignetteLoot", vignetteID = 802,
    onMinimap = false, onWorldMap = false, inFogOfWar = false }
livePositions.far = { x = 0.8, y = 0.5 }
livePositions.fogged = { x = 0.7, y = 0.5 }
livePositions.unpublished = { x = 0.6, y = 0.5 }
C_Map.GetWorldPosFromMapPos = function(_, position) return 42, { x = position.x * 10000, y = position.y * 10000 } end
now, guids, mapID = 300, { "far", "fogged", "unpublished" }, 779
addon.VignetteRadarAPI.Refresh(true)
assert(#addon.VignetteRadarAPI.GetTargets() == 1 and addon.VignetteRadarAPI.GetTargets()[1].source == "worldMap",
    "wide view must accept exposed map data while rejecting fogged and unpublished positions")
assert(not panel.blipByKey.far, "distant data must stay outside the current display range")
for _ = 1, 5 do panel.zoomOut.scripts.OnClick(panel.zoomOut) end
assert(settings.vignetteRadarRange == 4800 and panel.zoomLabel.text == "4800 yd" and panel.blipByKey.far,
    "zoom-out controls must reveal a supplied detection 3000 yards away")
assert(panel.blipByKey.far.target.distance == 3000 and launcher.detected == 0,
    "full-radar zoom must preserve yard distances and the launcher's fixed 150-yard radius")
panel.field.scripts.OnMouseWheel(panel.field, 1)
assert(settings.vignetteRadarRange == 2400 and not panel.blipByKey.far, "mouse wheel up must zoom in")
panel.scripts.OnMouseWheel(panel, -1)
assert(settings.vignetteRadarRange == 4800 and panel.blipByKey.far, "mouse wheel down must zoom out")
panel.blipByKey.far.scripts.OnMouseWheel(panel.blipByKey.far, 1)
assert(settings.vignetteRadarRange == 2400, "wheel zoom must also work while hovering a marker")
panel.zoomOut.scripts.OnClick(panel.zoomOut)
panel.blipByKey.far.scripts.OnClick(panel.blipByKey.far, "LeftButton")
assert(panel.focusReadout:IsShown() and panel.height == 324 and panel.zoomOut.point[5] == 6
    and panel.zoomOut.height == 20 and panel.focusReadout.point[3] >= 34,
    "disclosed focus readout must reserve a gutter above the zoom controls")
settings.vignetteRadarWorldMap = false
addon.VignetteRadarAPI.Refresh(true)
assert(#addon.VignetteRadarAPI.GetTargets() == 0 and not panel.blipByKey.far and not panel.focusReadout:IsShown(),
    "disabling world-map entries must clear them and their focus without leaving ghosts")
settings.vignetteRadarAlertSound = true
local soundCount = #sounds
settings.vignetteRadarWorldMap = true
addon.VignetteRadarAPI.Refresh(true)
assert(panel.blipByKey.far and #sounds == soundCount, "enabling wider data scope must seed silently")
assert(not addon.SetVignetteRadarRange(999999) and settings.vignetteRadarRange == 4800,
    "unsupported zoom ranges must not corrupt saved settings")
for _ = 1, 10 do panel.zoomIn.scripts.OnClick(panel.zoomIn) end
assert(settings.vignetteRadarRange == 150, "zoom-in must clamp at the minimum")

-- Resolve frame anchors, rather than assuming each layout uses the same origin.
local anchors = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
    LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
local function bounds(region)
    if region == panel then return { 0, 0, panel.width, panel.height } end
    local p = assert(region.point, "region needs an explicit anchor")
    local relative, relativePoint, x, y
    if type(p[2]) == "table" then relative, relativePoint, x, y = p[2], p[3], p[4] or 0, p[5] or 0
    else relative, relativePoint, x, y = region.parent, p[1], p[2] or 0, p[3] or 0 end
    local base, origin, target = bounds(relative), anchors[p[1]], anchors[relativePoint]
    local width, height = assert(region.width), assert(region.height)
    local left = base[1] + (base[3] - base[1]) * target[1] + x - width * origin[1]
    local bottom = base[2] + (base[4] - base[2]) * target[2] + y - height * origin[2]
    return { left, bottom, left + width, bottom + height }
end
local function separate(first, second, gap, label)
    local a, b = bounds(first), bounds(second)
    assert(a[3] + gap <= b[1] or b[3] + gap <= a[1]
        or a[4] + gap <= b[2] or b[4] + gap <= a[2], "layout gutter: " .. label)
end
local function inside(region, parent, gutter)
    local a, b = bounds(region), bounds(parent or panel)
    assert(a[1] >= b[1] + gutter and a[2] >= b[2] + gutter
        and a[3] <= b[3] - gutter and a[4] <= b[4] - gutter,
        "layout region escapes its parent: " .. tostring(region.text or region.kind))
end
local function checkLayout(focused)
    local controls = { panel.target, panel.legend, panel.close, panel.zoomOut, panel.zoomIn, panel.zoomLabel,
        panel.compass, panel.combatToggle }
    inside(panel.settingsDot, panel, 4)
    separate(panel.settingsDot, panel.title, 2, "settings/title")
    separate(panel.settingsDot, panel.summary, 2, "settings/status")
    separate(panel.settingsDot, panel.drag, 2, "settings/drag")
    for _, control in ipairs(controls) do separate(panel.settingsDot, control, 2, "settings/toolbar") end
    inside(panel.field.halo, panel, 4)
    inside(panel.title, panel, 4)
    inside(panel.summary, panel, 4)
    separate(panel.field.halo, panel.title, 4, "radar/title")
    separate(panel.field.halo, panel.summary, 4, "radar/summary")
    for index, control in ipairs(controls) do
        inside(control, panel, 4)
        separate(control, panel.field.halo, 4, "toolbar/radar")
        separate(control, panel.drag, 2, "toolbar/drag")
        for other = index + 1, #controls do separate(control, controls[other], 2, "toolbar hit targets") end
        if panel.layout ~= "classic" then
            assert(bounds(control)[4] <= 50, "alternate layouts must keep all controls below the radar")
        end
    end
    if focused then
        inside(panel.focusReadout, panel, 4)
        inside(panel.focusName, panel.focusReadout, 0)
        inside(panel.focusMeta, panel.focusReadout, 0)
        separate(panel.focusName, panel.focusMeta, 4, "focus name/metadata")
        separate(panel.focusReadout, panel.field.halo, 6, "focus/radar")
        separate(panel.focusDivider, panel.field.halo, 6, "divider/radar")
        separate(panel.focusDivider, panel.focusReadout, 6, "divider/focus")
        for _, control in ipairs(controls) do separate(control, panel.focusReadout, 6, "toolbar/focus") end
    elseif panel.layout == "squat" then
        inside(panel.layoutHint, panel, 4)
        separate(panel.layoutHint, panel.field.halo, 6, "hint/radar")
    end
    if panel.layout == "squat" then
        inside(panel.sideCaption, panel, 4)
        inside(panel.sideGuide, panel, 4)
        separate(panel.sideCaption, panel.focusReadout, 8, "right-rail caption/details")
        separate(panel.sideGuide, panel.focusReadout, 8, "right-rail details/action")
        separate(panel.sideCaption, panel.field.halo, 6, "right-rail caption/radar")
        separate(panel.sideGuide, panel.field.halo, 6, "right-rail action/radar")
    end
    assert(panel.resizeGrips and panel.resizeGrips.top.width == panel.width - 20
        and panel.resizeGrips.left.height == panel.height - 20,
        "each layout must keep all edge resize hit areas on its current borders")
    for _, grip in pairs(panel.resizeGrips) do
        inside(grip, panel, 0)
        for _, control in ipairs(controls) do
            separate(grip, control, 0, "resize border/button hit targets")
        end
    end
    assert(panel.field.width == panel.field.height, "layout must preserve circular radar geometry")
    inside(panel.frameToggle, panel, 4)
    local fieldRect, toggleRect = bounds(panel.field), bounds(panel.frameToggle)
    assert(toggleRect[1] >= (fieldRect[1] + fieldRect[3]) / 2 + panel.plotRadius + 8
        and panel.frameToggle.backdrop == nil and panel.frameToggle.label == nil
        and #panel.frameToggle.chevron == 2,
        "the frame toggle must be a borderless chevron outside every radar plotting area")
    if panel.layout == "squat" then
        assert(toggleRect[3] + 4 <= bounds(panel.focusDivider)[1],
            "the chevron must preserve a gutter before the squat details divider")
    end
    for _, line in ipairs(panel.rangeRing) do
        local x, y = line.startPoint[3], line.startPoint[4]
        assert(math.abs(math.sqrt(x*x + y*y) - panel.plotRadius) < 0.001, "rings must follow the active layout radius")
    end
end

addon.SetVignetteRadarRange(4800)
local savedPosition, savedCategories = { x = 90, y = -80 }, settings.vignetteRadarCategories
settings.vignetteRadarPosition = savedPosition
local originalPanel, originalField = panel, panel.field
local scanCount, getVignettes = 0, C_VignetteInfo.GetVignettes
C_VignetteInfo.GetVignettes = function() scanCount = scanCount + 1; return getVignettes() end
for _, name in ipairs({ "squat", "compact", "classic", "compact", "squat", "classic" }) do
    panel.legend.scripts.OnClick(panel.legend)
    assert(legendPanel:IsShown())
    local before = scanCount
    local choice
    for _, object in ipairs(objects) do
        if object.parent == optionsPanel.pages.Layout and object.kind == "Button"
            and object.text:lower() == name then choice = object; break end
    end
    assert(choice).scripts.OnClick(choice)
    assert(panel == originalPanel and panel.field == originalField and scanCount == before,
        "view changes must reuse existing frames without rescanning detection data")
    assert(settings.vignetteRadarLayout == name and panel.layout == name and not legendPanel:IsShown(),
        "switching views must save the selection and close old pop-outs")
    assert(settings.vignetteRadarRange == 4800 and settings.vignetteRadarPosition == savedPosition
        and settings.vignetteRadarCategories == savedCategories, "view changes must preserve range, filters and position")
    checkLayout(false)
    local far = assert(panel.blipByKey.far)
    if name == "squat" then
        assert(panel.focusReadout:IsShown() and panel.focusReadout.target.key == "far"
            and panel.sideCaption.text == "NEAREST DETECTION"
            and panel.focusName.text == "Far map treasure" and panel.focusMeta.text:find("3000 yd", 1, true)
            and panel.focusMeta.text:find("TREASURE", 1, true)
            and panel.sideGuide.text == "CLICK TO FOCUS",
            "Squat must show actionable current detection details without a manual focus")
        panel.focusReadout.scripts.OnClick(panel.focusReadout, "LeftButton")
        assert(addon.VignetteRadarTargetPicker.GetFocus() == "far" and panel.sideCaption.text == "TRACKING",
            "clicking automatic details must focus that exact detection")
        panel.focusReadout.scripts.OnClick(panel.focusReadout, "LeftButton")
        assert(addon.VignetteRadarTargetPicker.GetFocus() == nil
            and panel.sideCaption.text == "NEAREST DETECTION",
            "clicking the tracked details again must restore the automatic view")
    end
    local x, y = far.point[4], far.point[5]
    assert(math.abs(math.sqrt(x*x+y*y) - panel.plotRadius * 3000 / 4800) < 0.001,
        "live target distances must project to the resized plotting area")
    far.scripts.OnClick(far, "LeftButton")
    local baseHeight = panel.height
    if name == "squat" then
        assert(panel.sideCaption.text == "TRACKING" and panel.sideGuide.text == "CLICK AGAIN TO SHOW ALL",
            "the right side must clearly distinguish tracking from an automatic detection")
    end
    checkLayout(true)
    assert(panel.focusMeta.text:find("3000 yd", 1, true), "focus must retain actual yard distances in every layout")
    for _, other in ipairs({ "squat", "compact", "classic", name }) do
        addon.SetVignetteRadarLayout(other)
        assert(addon.VignetteRadarTargetPicker.GetFocus() == "far" and panel.focusReadout:IsShown(),
            "switching a focused view must preserve the target and disclosed details")
        checkLayout(true)
    end
    addon.SetVignetteRadarRange(150)
    assert(panel.edgeArrow:IsShown())
    x, y = panel.edgeArrow.point[4], panel.edgeArrow.point[5]
    assert(math.abs(math.sqrt(x*x+y*y) - panel.plotRadius) < 0.001
        and math.sqrt(x*x+y*y) + 7 < panel.fieldRadius, "rim arrow must track the resized plotting radius")
    if name == "squat" then
        addon.VignetteRadarTargetPicker.ClearFocus()
        assert(panel.focusReadout:IsShown() and panel.sideCaption.text == "OUTSIDE RADAR RANGE"
            and panel.sideGuide.text == "ZOOM OUT TO SEE IT",
            "automatic details must identify a reported detection beyond the selected radius")
    end
    addon.SetVignetteRadarRange(4800)
    for _, right in ipairs({ 400, 1590 }) do
        panel.right, panel.left = right, right - panel.width
        panel.target.scripts.OnClick(panel.target, "LeftButton")
        assert(targetPanel:IsShown() and targetPanel.clamped)
        separate(targetPanel, panel, 8, "target picker/panel")
        assert(targetPanel.point[1] == (right == 400 and "TOPLEFT" or "TOPRIGHT"),
            "target picker must choose the side that has space")
        panel.legend.scripts.OnClick(panel.legend)
        assert(legendPanel:IsShown() and legendPanel.clamped and not targetPanel:IsShown())
        separate(legendPanel, panel, 8, "legend/panel")
        panel.legend.scripts.OnClick(panel.legend)
    end
    panel.right, panel.left = nil, nil
    addon.VignetteRadarTargetPicker.ClearFocus()
    assert(name ~= "squat" or panel.height == baseHeight, "Squat must not grow taller when focusing a target")
    if name == "squat" then
        assert(panel.focusReadout:IsShown() and panel.sideCaption.text == "NEAREST DETECTION",
            "clearing focus should return to useful automatic details")
    end
    checkLayout(false)
end
assert(not addon.SetVignetteRadarLayout("invalid") and settings.vignetteRadarLayout == "classic")
for _, expected in ipairs({ "squat", "compact", "classic" }) do
    SlashCmdList.VIGNETTERADAR("layout")
    assert(settings.vignetteRadarLayout == expected, "bare layout command must cycle through all three views")
end
SlashCmdList.VIGNETTERADAR("layout compact")
assert(settings.vignetteRadarLayout == "compact", "layout command must also select a style by name")
SlashCmdList.VIGNETTERADAR("off")
addon.SetVignetteRadarLayout("squat")
assert(not panel:IsShown() and settings.vignetteRadarEnabled == false,
    "changing layout must not reopen or re-enable disabled tracking")
SlashCmdList.VIGNETTERADAR("preview")
for _, name in ipairs({ "squat", "compact", "classic" }) do
    addon.SetVignetteRadarLayout(name)
    checkLayout(false)
    if name == "squat" then
        addon.VignetteRadarLegend.SetCategoryEnabled("rare", false)
        assert(panel.focusReadout.target.category == "treasure",
            "automatic preview details must follow the enabled categories")
        addon.VignetteRadarLegend.SetCategoryEnabled("rare", true)
    end
    for _, blip in pairs(panel.blipByKey) do
        local x, y = blip.point[4], blip.point[5]
        assert(math.sqrt(x*x+y*y) + blip.width / 2 < panel.fieldRadius,
            "preview markers must remain inside the smallest radar with maximum marker size")
    end
end
assert(settings.vignetteRadarEnabled == false, "previewing alternate views must not enable tracking")

-- A narrow game canvas and saved positions next to screen edges must fit after resizing/focusing.
UIParent:SetSize(800, 600)
for _, name in ipairs({ "squat", "compact", "classic" }) do
    panel.left, panel.top = 780, 250
    addon.SetVignetteRadarLayout(name)
    addon.HandleVignetteClick(panel.blipByKey["preview-rare"].target, "LeftButton")
    local x, top = panel.point[4], UIParent.height + panel.point[5]
    assert(x >= 4 and x + panel.width <= UIParent.width - 4
        and top <= UIParent.height - 4 and top - panel.height >= 4,
        "expanded layout must reclamp with a visible gutter on an 800x600 canvas")
    checkLayout(true)
    addon.VignetteRadarTargetPicker.ClearFocus()
end
panel.left, panel.top = nil, nil
UIParent:SetSize(1600, 900)

-- Fixed north keeps both radars' detections still while the player direction line turns.
local playerFacing = 0
GetPlayerFacing = function() return playerFacing end
guids, now, mapID = { "rare" }, 400, 780
livePositions.rare = { x = 0.507, y = 0.5 }
addon.SetVignetteRadarRange(450)
SlashCmdList.VIGNETTERADAR("on")
local northOption
for _, object in ipairs(objects) do
    if object.optionKey == "vignetteRadarNorthUp" then northOption = object; break end
end
assert(northOption, "north-up must also be available in Layout settings")
local function near(actual, expected, message)
    assert(math.abs(actual - expected) < 0.001,
        message .. ": got " .. tostring(actual) .. ", expected " .. tostring(expected))
end
for _, name in ipairs({ "classic", "squat", "compact" }) do
    addon.SetVignetteRadarLayout(name)
    checkLayout(false)
    assert(panel.outerRing[1].color[4] < panel.rangeRing[1].color[4],
        "the circle outside the cardinal labels must be the faintest boundary")
    local headingLength = panel.plotRadius * 0.30
    assert(panel.direction.thickness >= 2.5 and panel.direction.color[4] < 0.5
        and headingLength < panel.plotRadius / 2 and headingLength > 9
        and #panel.headingChevron == 2
        and panel.headingChevron[1].thickness >= 2
        and panel.headingChevron[1].color[4] < 0.8,
        "the player heading must show a compact, translucent chevron and line in every panel layout")
    assert(panel.compass.text == "N" and not panel.compass._selected,
        "the compass must clearly show whether north is locked")
    playerFacing = 0
    addon.VignetteRadarAPI.RefreshPresentation()
    local northX, northY = panel.blipByKey.rare.point[4], panel.blipByKey.rare.point[5]
    playerFacing = math.pi / 2
    addon.VignetteRadarAPI.RefreshPresentation()
    near(panel.blipByKey.rare.point[4], northY, "heading-up must rotate the radar with the player")
    near(panel.direction.endPoint[3], 0, "heading-up player line must point straight up")
    near(panel.direction.endPoint[4], headingLength, "heading-up line must stay short")
    near(panel.direction.startPoint[4], 9, "heading ray must begin at the chevron tip")
    near(panel.headingChevron[1].startPoint[3], -4, "heading-up chevron must hug the dot")
    near(panel.headingChevron[2].startPoint[3], 4, "heading-up chevron must hug the dot")
    near(panel.headingChevron[1].startPoint[4], 4, "heading-up chevron must meet the dot")
    assert(panel.direction:IsShown() and panel.headingChevron[1]:IsShown(),
        "heading-up player cue must stay visible")
    local before = scanCount
    panel.compass.scripts.OnClick(panel.compass)
    assert(settings.vignetteRadarNorthUp and panel.compass._selected and northOption.checked
        and scanCount == before, "compass click must save north-up and sync options without rescanning")
    local miniX, miniY = launcher.miniBlips[1].point[4], launcher.miniBlips[1].point[5]
    for _, angle in ipairs({ 0, math.pi / 2, math.pi, 3 * math.pi / 2 }) do
        playerFacing = angle
        addon.VignetteRadarAPI.RefreshPresentation()
        near(panel.blipByKey.rare.point[4], northX, "north-up marker horizontal position must stay fixed")
        near(panel.blipByKey.rare.point[5], northY, "north-up marker vertical position must stay fixed")
        near(panel.cardinals[1].point[4], 0, "N must remain above the player in north-up")
        near(panel.cardinals[1].point[5], panel.fieldRadius - 5, "N must remain at the top of the ring")
        near(panel.direction.endPoint[3], -math.sin(angle) * headingLength, "player line must turn toward actual facing")
        near(panel.direction.endPoint[4], math.cos(angle) * headingLength, "player line must turn toward actual facing")
        near(panel.headingChevron[1].endPoint[3], -math.sin(angle) * 9,
            "chevron tip must follow player facing")
        near(panel.headingChevron[1].endPoint[4], math.cos(angle) * 9,
            "chevron tip must follow player facing")
        assert(panel.headingChevron[1]:IsShown() and panel.headingChevron[2]:IsShown(),
            "both sides of the player chevron must stay visible")
        near(launcher.miniBlips[1].point[4], miniX, "launcher must use the same fixed orientation")
        near(launcher.miniBlips[1].point[5], miniY, "launcher must use the same fixed orientation")
        assert(launcher.direction:IsShown(), "north-up launcher needs a player direction cue")
        near(launcher.direction.endPoint[3], -math.sin(angle) * 9, "launcher player line must turn")
    end
    playerFacing = nil
    addon.VignetteRadarAPI.RefreshPresentation()
    assert(not panel.direction:IsShown() and not panel.headingChevron[1]:IsShown()
        and not panel.headingChevron[2]:IsShown() and not launcher.direction:IsShown() and panel.blipByKey.rare,
        "unknown facing must hide its direction cue without losing north-up positions")
    playerFacing = 0
    addon.HandleVignetteClick(panel.blipByKey.rare.target, "LeftButton")
    livePositions.rare = { x = 0.53, y = 0.5 }
    addon.VignetteRadarAPI.Refresh(true)
    addon.SetVignetteRadarRange(150)
    for _, angle in ipairs({ 0, math.pi / 2 }) do
        playerFacing = angle
        addon.VignetteRadarAPI.RefreshPresentation()
        assert(panel.edgeArrow:IsShown())
        near(panel.edgeArrow.point[4], 0, "north-up out-of-range direction must remain fixed")
        near(panel.edgeArrow.point[5], panel.plotRadius, "north-up edge arrow must stay at north")
    end
    checkLayout(true)
    panel.compass.scripts.OnClick(panel.compass)
    assert(not settings.vignetteRadarNorthUp and not panel.compass._selected and not northOption.checked,
        "clicking compass again must restore facing-up and synchronize the checkbox")
    near(panel.edgeArrow.point[4], panel.plotRadius, "restoring facing-up must rotate the focused edge arrow")
    assert(not launcher.direction:IsShown(), "heading-up launcher must retain its existing appearance")
    addon.VignetteRadarTargetPicker.ClearFocus()
    livePositions.rare = { x = 0.507, y = 0.5 }
    addon.SetVignetteRadarRange(450)
    addon.VignetteRadarAPI.Refresh(true)
end
-- The checkbox and toolbar share one saved mode, including in preview.
northOption:SetChecked(true)
northOption.scripts.OnClick(northOption)
assert(panel.compass._selected and settings.vignetteRadarNorthUp)
SlashCmdList.VIGNETTERADAR("preview")
near(panel.cardinals[1].point[4], 0, "preview must honor fixed north")
near(panel.direction.endPoint[3], -math.sin(0.65) * panel.plotRadius * 0.30,
    "preview must demonstrate the short rotating player cue")
near(panel.headingChevron[1].endPoint[3], -math.sin(0.65) * 9,
    "preview must demonstrate the player's rotating chevron")

-- Border dragging uniformly scales the panel and keeps the opposite edge stable.
UIParent:SetSize(800, 600)
local cursorX, cursorY = 400, 300
GetCursorPosition = function() return cursorX, cursorY end
local resizeDirections = {
    { "left", -1, 0 }, { "right", 1, 0 }, { "top", 0, 1 }, { "bottom", 0, -1 },
    { "topLeft", -1, 1 }, { "topRight", 1, 1 },
    { "bottomLeft", -1, -1 }, { "bottomRight", 1, -1 },
}
for _, name in ipairs({ "squat", "compact", "classic" }) do
    settings.vignetteRadarScale = 1
    panel:SetScale(1)
    addon.SetVignetteRadarLayout(name)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
    checkLayout(false)
    for _, direction in ipairs(resizeDirections) do
        local key, horizontal, vertical = direction[1], direction[2], direction[3]
        local grip = assert(panel.resizeGrips[key])
        panel:SetScale(1)
        settings.vignetteRadarScale = 1
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
        cursorX, cursorY = 400, 300
        local left, top = panel:GetLeft(), panel:GetTop()
        local right, bottom = left + panel.width, top - panel.height
        grip.scripts.OnDragStart(grip)
        assert(grip.resize and grip.scripts.OnUpdate, "every edge and corner must start a resize gesture")
        cursorX, cursorY = cursorX + horizontal * 24, cursorY + vertical * 24
        grip.scripts.OnUpdate(grip)
        assert(panel:GetScale() > 1 and panel:GetScale() < 1.3, "outward edge dragging must grow the full panel")
        if horizontal < 0 then near(panel:GetLeft() + panel.width * panel:GetScale(), right,
            name .. " " .. key .. " resize must hold the right edge") end
        if horizontal > 0 then near(panel:GetLeft(), left, "right resize must hold the left edge") end
        if vertical > 0 then near(panel:GetBottom(), bottom, "top resize must hold the bottom edge") end
        if vertical < 0 then near(panel:GetTop(), top, "bottom resize must hold the top edge") end
        local x, panelTop = panel:GetLeft(), panel:GetTop()
        assert(x >= 4 and x + panel.width * panel:GetScale() <= 796
            and panelTop <= 596 and panelTop - panel.height * panel:GetScale() >= 4,
            "resizing must keep all layout states inside an 800x600 screen")
        grip.scripts.OnDragStop(grip)
        assert(grip.scripts.OnUpdate == nil and settings.vignetteRadarScale == panel:GetScale(),
            "stopping a drag must save the scale and stop updating")
        checkLayout(false)
    end
end
local rightGrip = panel.resizeGrips.right
panel:SetScale(1)
cursorX, cursorY = 400, 300
rightGrip.scripts.OnDragStart(rightGrip)
cursorX = cursorX + 1000
rightGrip.scripts.OnUpdate(rightGrip)
assert(panel:GetScale() <= 1.8 and panel:GetLeft() + panel.width * panel:GetScale() <= 796,
    "oversized drags must stop before the panel clips off screen")
rightGrip.scripts.OnDragStop(rightGrip)
local savedScale = settings.vignetteRadarScale
addon.SetVignetteRadarLayout("squat")
assert(settings.vignetteRadarScale == savedScale
    and math.abs(panel:GetScale() - math.min(savedScale, (800 - 274) / panel.width)) < 0.001,
    "saved size must survive layout changes while a narrow screen temporarily limits Squat")
addon.SetVignetteRadarLayout("classic")
assert(panel:GetScale() == savedScale, "roomier layouts must restore the requested size")
addon.SetVignetteRadarLayout("squat")
panel:SetScale(1)
settings.vignetteRadarScale = 1
panel:ClearAllPoints()
panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
cursorX, cursorY = 400, 300
rightGrip = panel.resizeGrips.right
rightGrip.scripts.OnDragStart(rightGrip)
cursorX = cursorX + 1000
rightGrip.scripts.OnUpdate(rightGrip)
assert(panel:GetScale() <= (800 - 274) / panel.width,
    "Squat resizing must leave room for the target picker on an 800px screen")
rightGrip.scripts.OnDragStop(rightGrip)
panel.target.scripts.OnClick(panel.target, "LeftButton")
assert(targetPanel:IsShown() and targetPanel.point[1] == "TOPLEFT"
    and panel:GetLeft() + panel.width * panel:GetScale() + 8 + targetPanel.width <= 796,
    "the target picker must remain beside a scaled Squat panel with an outer screen gutter")
addon.VignetteRadarTargetPicker.Hide()
panel:SetScale(1)
settings.vignetteRadarScale = 1
UIParent:SetSize(1600, 900)
mapID, guids, now = 781, {}, 500
SlashCmdList.VIGNETTERADAR("on")
addon.SetVignetteRadarLayout("squat")
assert(panel:IsShown() and not panel.focusReadout:IsShown()
    and panel.layoutHint:IsShown() and panel.sideCaption.text == "NO DETECTIONS"
    and panel.sideGuide.text == "MOVE OR CHECK THE MAP",
    "Squat needs an understandable empty state when no vignette is available")

-- Quest dots follow the chosen orientation, while Blizzard's native blob is
-- aligned and clipped only when north is fixed at the top.
local originalWorldPosition = C_Map.GetWorldPosFromMapPos
C_Map.GetWorldPosFromMapPos = function(_, position)
    return 42, { x = (0.5 - position.y) * 1000, y = (0.5 - position.x) * 1000 }
end
C_QuestLog = {
    GetQuestsOnMap = function() return { { questID = 12345, x = 0.52, y = 0.5, name = "Nearby quest" } } end,
    GetTitleForQuestID = function() return "Nearby quest" end,
}
settings.vignetteRadarQuestDots = true
settings.vignetteRadarQuestAreas = true
settings.vignetteRadarNorthUp = false
GetPlayerFacing = function() return 0 end
addon.VignetteRadarAPI.Refresh(true)
local questDot = assert(panel.questDots[1], "quest locations must create a distinct dot")
assert(questDot:IsShown() and questDot.quest.questID == 12345 and questDot.point[4] > 0
    and panel.summary.text == "1 QUEST IN RANGE", "quest dots should show live positions and a readable count")
assert(panel.questBlob and not panel.questBlob:IsShown(), "exact blobs must wait for north-up mode")
assert(panel.squarePlot and panel.field.background.texture == "Interface\\AddOns\\VignetteRadar\\Media\\radar-rounded-square.tga",
    "enabling quest areas must select a stable square surface even before blobs are available")
GetPlayerFacing = function() return math.pi / 2 end
addon.VignetteRadarAPI.Refresh(false)
assert(questDot.point[5] < 0, "quest dots should turn with the facing-up radar")
addon.SetVignetteRadarNorthUp(true)
assert(questDot.point[4] > 0 and math.abs(questDot.point[5]) < 0.001,
    "quest dots must return to their fixed map position in north-up mode")
assert(panel.questClip.clipsChildren and panel.questBlob:IsShown() and panel.questBlob.mapID == 781
    and panel.questBlob.drawnQuests[1] == 12345 and panel.questBlob.fillAlpha < 128
    and panel.questBlob.level < questDot.level,
    "native quest shapes must be translucent, clipped, and behind markers")
local originalBlob = panel.questBlob
for _, name in ipairs({ "classic", "compact", "squat" }) do
    addon.SetVignetteRadarLayout(name)
    checkLayout(false)
    local face, clip, toggle = bounds(panel.field.background), bounds(panel.questClip), bounds(panel.frameToggle)
    assert(panel.questBlob == originalBlob and panel.questBlob:IsShown()
        and panel.questBlob.parent == panel.questClip and panel.questClip.clipsChildren,
        "every square layout must preserve the single working native blob renderer")
    assert(face[3] - face[1] == panel.fieldRadius * 2 and face[4] - face[2] == panel.fieldRadius * 2
        and clip[1] == face[1] + 4 and clip[2] == face[2] + 4
        and clip[3] == face[3] - 4 and clip[4] == face[4] - 4,
        "native shading must retain the safe inset inside the rounded face")
    assert(toggle[1] >= face[3] + 3 and not panel.field.halo:IsShown() and not panel.outerRing[1]:IsShown(),
        "square mode must leave a clear restore-control gutter and remove the old circular outer rim")
    local corner = (face[3] - face[1]) * .04
    assert(math.sqrt(2) * (corner - 4) <= corner - 1,
        "every native clip corner must stay at least one unit inside the rounded outline")
    local border = assert(panel.squareBorder, "square layouts must create one rounded border texture")
    local borderPoint = assert(border.point, "rounded border texture needs an explicit center anchor")
    local borderBounds, faceBounds = bounds(border), bounds(panel.field.background)
    assert(border.kind == "Texture" and border.parent == panel.field and border.layer == "BORDER"
        and border.texture == "Interface\\AddOns\\VignetteRadar\\Media\\radar-rounded-border.tga"
        and borderPoint[1] == "CENTER" and borderPoint[2] == panel.field
        and borderPoint[3] == "CENTER" and (borderPoint[4] or 0) == 0 and (borderPoint[5] or 0) == 0
        and border.width == panel.field.background.width and border.height == panel.field.background.height
        and borderBounds[1] == faceBounds[1] and borderBounds[2] == faceBounds[2]
        and borderBounds[3] == faceBounds[3] and borderBounds[4] == faceBounds[4]
        and border:IsShown(),
        "the rounded border texture must cover the square face in the BORDER layer in every layout")
    panel:SetScale(.8)
    checkLayout(false)
    panel:SetScale(1)
end
local blobCount = 0
for _, object in ipairs(objects) do
    if object.kind == "QuestPOIFrame" then blobCount = blobCount + 1 end
end
assert(blobCount == 1, "layout changes must never duplicate the native blob renderer")
SlashCmdList.VIGNETTERADAR("preview")
addon.HandleVignetteClick(panel.blipByKey["preview-rare"].target, "LeftButton")
for _, name in ipairs({ "classic", "compact", "squat" }) do
    addon.SetVignetteRadarLayout(name)
    panel:SetScale(.8)
    checkLayout(true)
    inside(panel.field.background, panel, 4)
    inside(panel.questClip, panel.field.background, 4)
    separate(panel.frameToggle, panel.field.background, 3, "square surface/restore control")
    assert(panel.squarePlot and not panel.questBlob:IsShown(),
        "focused previews must keep square geometry without inventing quest blobs")
end
panel:SetScale(1)
addon.HandleVignetteClick(panel.blipByKey["preview-rare"].target, "LeftButton")
SlashCmdList.VIGNETTERADAR("on")
local originalCursor = GetCursorPosition
panel.field.left, panel.field.top = 0, panel.field:GetHeight()
panel.questBlob.left, panel.questBlob.top = 0, panel.field:GetHeight()
panel.questBlob:SetSize(panel.field:GetWidth(), panel.field:GetHeight())
panel.questBlob.hoverQuestID = 12345
GetCursorPosition = function() return panel.field:GetWidth() / 2, panel.field:GetHeight() / 2 end
panel.scripts.OnUpdate(panel, .11)
assert(GameTooltip:IsShown() and GameTooltip:GetOwner() == panel.questBlob
    and GameTooltip.text == "Nearby quest" and GameTooltip.line:find("Click to spotlight", 1, true),
    "hovering a native quest shape must identify the quest without a clickable blob layer")
panel.field.scripts.OnMouseUp(panel.field, "LeftButton")
assert(addon.VignetteRadarExploration.GetFocusedQuest() == 12345,
    "clicking a hovered native blob must spotlight its quest")
panel.field.scripts.OnMouseUp(panel.field, "LeftButton")
assert(addon.VignetteRadarExploration.GetFocusedQuest() == nil,
    "clicking a spotlighted blob again must restore all quest areas")
GetCursorPosition = function() return panel.field:GetWidth() * .8, panel.field:GetHeight() / 2 end
panel.scripts.OnUpdate(panel, .11)
assert(not GameTooltip:IsShown(), "hovering outside the exact quest shape must clear its tooltip")
panel.questBlob.UpdateMouseOverTooltip = function() return 12345 end
for _, sign in ipairs({ -1, 1 }) do
    for _, otherSign in ipairs({ -1, 1 }) do
        -- This point is in the square's corner, beyond the old circular hit area.
        panel.questBlob:SetSize(panel.field:GetWidth(), panel.field:GetHeight())
        GetCursorPosition = function()
            return panel.field:GetWidth() / 2 + sign * (panel.fieldRadius - 5),
                panel.field:GetHeight() / 2 + otherSign * (panel.fieldRadius - 5)
        end
        panel.scripts.OnUpdate(panel, .11)
        assert(GameTooltip:IsShown() and GameTooltip:GetOwner() == panel.questBlob,
            "quest tooltips must work in all four visible square corners")
    end
end
GetCursorPosition = function()
    return panel.field:GetWidth() / 2 + panel.fieldRadius - 3, panel.field:GetHeight() / 2
end
panel.scripts.OnUpdate(panel, .11)
assert(not GameTooltip:IsShown(), "quest tooltip hit testing must stop at the same square edge as shading")
panel.questBlob.UpdateMouseOverTooltip = nil
GetCursorPosition = originalCursor
panel.field.left, panel.field.top = nil, nil
panel.questBlob.left, panel.questBlob.top = nil, nil
panel.frameToggle.scripts.OnClick(panel.frameToggle)
assert(settings.vignetteRadarCircleOnly and panel.questBlob:IsShown() and questDot:IsShown()
    and panel.squarePlot and panel.squareBorder:IsShown() and panel.frameToggle:IsShown()
    and panel.backdropColor[4] == 0,
    "radar-only view must keep square shading and its restore control while hiding the outer frame")
panel.frameToggle.scripts.OnClick(panel.frameToggle)
assert(not settings.vignetteRadarCircleOnly and panel.questBlob:IsShown(),
    "restoring the frame must restore available quest-area shading")
settings.vignetteRadarQuestAreas = false
settings.vignetteRadarQuestDots = false
addon.VignetteRadarAPI.Refresh(true)
assert(not questDot:IsShown() and not panel.questBlob:IsShown(),
    "each quest overlay must disappear as soon as its option is disabled")
assert(not panel.squarePlot and panel.field.background.texture == "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    and panel.field.halo:IsShown() and panel.outerRing[1]:IsShown() and not panel.squareBorder:IsShown()
    and panel.frameToggle.width == 16 and panel.questBlob == originalBlob,
    "disabling quest areas must restore the original circular face without replacing the blob renderer")
settings.vignetteRadarQuestAreas = true
mapID = 782
C_Map.GetWorldPosFromMapPos = originalWorldPosition
addon.VignetteRadarAPI.Refresh(true)
assert(not panel.questBlob:IsShown(),
    "unrotatable native blobs must not appear on maps whose axes disagree with the radar")

-- Map corners can arrive after player and quest positions on the same map.
-- Missing basis data must be retried without requiring another zone change.
local missingQuestCorner = true
C_Map.GetWorldPosFromMapPos = function(_, position)
    if missingQuestCorner and position.x == 0 and position.y == 0 then return nil end
    return 42, { x = (0.5 - position.y) * 1000, y = (0.5 - position.x) * 1000 }
end
settings.vignetteRadarQuestDots = true
mapID, now = 783, 600
addon.VignetteRadarAPI.Refresh(true)
assert(panel.questDots[1]:IsShown() and not panel.questBlob:IsShown(),
    "quest dots must survive a temporarily missing map corner while native shading waits")
missingQuestCorner = false
now = 602
addon.VignetteRadarAPI.Refresh(false)
assert(panel.questBlob:IsShown() and panel.questBlob.mapID == 783,
    "native shading must recover when map corners become available on the same map")

-- DrawBlob may return successfully before Blizzard has loaded shape data.
-- Updates and a slow retry must redraw even when map, size, and IDs stay fixed.
local questEvents
for _, object in ipairs(objects) do
    if object.kind == "Frame" and object.events and object.events.QUEST_POI_UPDATE then
        questEvents = object
        break
    end
end
assert(questEvents and questEvents.events.QUEST_LOG_UPDATE and questEvents.scripts.OnEvent,
    "quest update events must be registered on the radar event frame")
local savedDrawNone, savedDrawBlob = panel.questBlob.DrawNone, panel.questBlob.DrawBlob
local drawNoneCount, drawBlobCount, shapeReady, shapeVersion = 0, 0, false, 1
panel.questBlob.DrawNone = function(self)
    drawNoneCount = drawNoneCount + 1
    self.renderedShape = nil
end
panel.questBlob.DrawBlob = function(self, questID)
    drawBlobCount = drawBlobCount + 1
    if shapeReady then self.renderedShape = tostring(questID) .. ":" .. tostring(shapeVersion) end
end
mapID, now = 784, 610
addon.VignetteRadarAPI.Refresh(true)
assert(panel.questBlob:IsShown() and drawBlobCount == 1 and drawNoneCount == 1
    and panel.questBlob.renderedShape == nil,
    "an initially empty native draw may still report success")
shapeReady = true
questEvents.scripts.OnEvent(questEvents, "QUEST_POI_UPDATE")
assert(panel.questBlob.renderedShape == "12345:1" and drawBlobCount == 2 and drawNoneCount == 2,
    "QUEST_POI_UPDATE must redraw late native shape data with unchanged quest IDs")
shapeVersion = 2
questEvents.scripts.OnEvent(questEvents, "QUEST_LOG_UPDATE")
assert(panel.questBlob.renderedShape == "12345:2" and drawBlobCount == 3 and drawNoneCount == 3,
    "QUEST_LOG_UPDATE must redraw changed native geometry with unchanged quest IDs")
local drawCount = drawBlobCount
for _ = 1, 5 do addon.VignetteRadarAPI.Refresh(false) end
assert(drawBlobCount == drawCount,
    "ordinary radar refreshes must not redraw native shapes at frame rate")
shapeVersion = 3
now = 612
addon.VignetteRadarAPI.Refresh(false)
assert(panel.questBlob.renderedShape == "12345:3" and drawBlobCount == drawCount + 1,
    "a slow retry must repair native geometry when a quest update event was missed")
panel.questBlob.DrawNone, panel.questBlob.DrawBlob = savedDrawNone, savedDrawBlob
settings.vignetteRadarQuestDots = false
C_Map.GetWorldPosFromMapPos = originalWorldPosition
settings.vignetteRadarQuestAreas = false
addon.VignetteRadarAPI.Refresh(false)
local savedFieldPoint = panel.field.point
panel.frameToggle.scripts.OnClick(panel.frameToggle)
assert(settings.vignetteRadarCircleOnly == true and panel.backdropColor[4] == 0
    and panel.backdropBorderColor[4] == 0 and not panel.title:IsShown()
    and not panel.combatToggle:IsShown() and not panel.resizeGrips.bottomRight:IsShown()
    and panel.frameToggle:IsShown() and panel.field.point == savedFieldPoint
    and panel.frameToggle.chevron[1].endPoint[3] > panel.frameToggle.chevron[1].startPoint[3],
    "circle-only view must hide the rectangular frame without moving the radar or its restore chevron")
panel.frameToggle.scripts.OnClick(panel.frameToggle)
assert(settings.vignetteRadarCircleOnly == false and panel.backdropColor[4] == .98
    and panel.title:IsShown() and panel.combatToggle:IsShown()
    and panel.resizeGrips.bottomRight:IsShown()
    and panel.frameToggle.chevron[1].endPoint[3] < panel.frameToggle.chevron[1].startPoint[3],
    "the circle control must restore full panel chrome and resize grips")

-- The compact panel owns every user-facing setting and remains usable at its
-- smallest page bounds. Theme edits must affect the actual radar textures.
addon.SetVignetteRadarNorthUp(false)
SlashCmdList.VIGNETTERADAR("preview")
panel.settingsDot.scripts.OnClick(panel.settingsDot)
local quick = assert(addon.VignetteRadarQuickConfig.GetPanel())
assert(quick:IsShown() and quick.width == 288 and quick.height == 365,
    "the settings dot must open the narrow, self-contained panel")
local tabCount, exposed, colorSlots = 0, {}, {}
for _ in pairs(quick.tabs) do tabCount = tabCount + 1 end
assert(tabCount == 8 and quick.pages.Themes and quick.pages.Guides,
    "compact settings must include dedicated theme and guide controls")
for _, object in ipairs(objects) do
    if object.optionKey then exposed[object.optionKey] = true end
    if object.colorSlot then colorSlots[object.colorSlot] = true end
    local page = object.parent
    if object.point and (object.kind == "Button" or object.kind == "CheckButton")
        and page and page.parent == quick and page ~= quick then
        local p = object.point
        assert(p[1] == "TOPLEFT" and p[2] == page, "compact controls need explicit page anchors")
        local x, y = p[4], p[5]
        assert(x >= 10 and x + object.width <= quick.width - 10
            and -y >= 0 and -y + object.height <= page.height - 10,
            "compact control must not clip against a page border")
    end
end
for _, key in ipairs({ "vignetteRadarEnabled", "vignetteRadarHideWhenEmpty", "vignetteRadarLauncherVisible",
    "vignetteRadarWorldMap", "vignetteRadarRange", "vignetteRadarLayout", "vignetteRadarScale",
    "vignetteRadarNorthUp", "vignetteRadarCircleOnly",
    "vignetteRadarAlerts", "vignetteRadarAlertSound", "vignetteRadarAlertCategories",
    "vignetteRadarAlertCooldown", "vignetteRadarCategories", "vignetteRadarHighlight",
    "vignetteRadarMarkerSize", "vignetteRadarShapes", "vignetteRadarShowHealth",
    "vignetteRadarLastSeen", "vignetteRadarLastSeenSeconds", "vignetteRadarQuietCombat",
    "vignetteRadarKeepVisibleCombat",
    "vignetteRadarQuietInstances", "vignetteRadarQuestDots", "vignetteRadarQuestAreas",
    "vignetteRadarRingOpacity", "vignetteRadarChevronOpacity", "vignetteRadarHeadingOpacity",
    "vignetteRadarChevronDistance", "vignetteRadarHeadingLength", "vignetteRadarFullSweep",
    "vignetteRadarTheme" }) do
    assert(exposed[key], "compact settings missing: " .. key)
end
for _, slot in ipairs(addon.VignetteRadarStyle.slots) do
    assert(colorSlots[slot], "theme missing color slot: " .. slot)
end
local function quickControl(page, key, value)
    for _, object in ipairs(objects) do
        if (object.parent == quick.pages[page] or (page == "Themes" and object.parent == quick.themeContent))
            and object.optionKey == key
            and (value == nil or object.optionValue == value) then return object end
    end
end
quick.tabs.Themes.scripts.OnClick(quick.tabs.Themes)
assert(quick.pages.Themes:IsShown() and not quick.pages.Radar:IsShown())
local style = addon.VignetteRadarStyle
assert(#style.order == 32 and quick.themeScroll.width == 244 and quick.themeScroll.height == 46
    and quick.themeScroll.clipsChildren and quick.themeScroll.scrollChild == quick.themeContent
    and quick.themeContent.height == 8 * 24,
    "thirty-two palettes must live in a clipped, two-row scroll viewport")
assert(quick.themeTrack.point[4] == 267 and quick.themeTrack.point[5] == -18
    and quick.themeScroll.point[4] + quick.themeScroll.width + 8 <= quick.themeTrack.point[4]
    and 18 + quick.themeTrack.height + 10 <= 78,
    "the scrollbar needs a visible gutter from palette buttons and controls below")
for index, name in ipairs(style.order) do
    local choice = assert(quick.themeChoices[name])
    local p = choice.point
    assert(style.HasTheme(name) and style.PresetColor(name, "accent")
        and choice.parent == quick.themeContent and choice.width == 56
        and p[4] == ((index - 1) % 4) * 61
        and p[4] + choice.width <= quick.themeContent.width - 5
        and -p[5] == math.floor((index - 1) / 4) * 24 + 1,
        "each named palette needs a valid color and a clipped four-column grid cell")
    for _, slot in ipairs(style.slots) do
        local r, g, b = style.PresetColor(name, slot)
        assert(type(r) == "number" and type(g) == "number" and type(b) == "number"
            and r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1,
            "every palette must define a valid color for " .. slot)
    end
end
local function visibleThemeCount()
    local count = 0
    for _, name in ipairs(style.order) do
        local top = -quick.themeChoices[name].point[5]
        if top >= quick.themeOffset and top + 21 <= quick.themeOffset + quick.themeScroll.height then
            count = count + 1
        end
    end
    return count
end
assert(visibleThemeCount() == 8, "only two rows of four palettes may fit in the viewport")
for _ = 1, 10 do quick.themeScroll.scripts.OnMouseWheel(quick.themeScroll, -1) end
assert(quick.themeOffset == 144 and quick.themeScroll:GetVerticalScroll() == 144
    and quick.themeThumb.point[5] < -25 and visibleThemeCount() == 8,
    "wheel scrolling must reach the last two rows and move the scrollbar thumb")
quick.SetThemeScroll(0)
quick.themeTrack.top = 500
cursorY = 500
quick.themeTrack.scripts.OnMouseDown(quick.themeTrack)
cursorY = 450
quick.themeTrack.scripts.OnUpdate(quick.themeTrack)
assert(quick.themeOffset == 144, "dragging the scrollbar must reach the final palette rows")
quick.themeTrack.scripts.OnMouseUp(quick.themeTrack)
assert(not quick.themeTrack.dragging and not quick.themeTrack.scripts.OnUpdate,
    "releasing the scrollbar must stop its drag update")
quick.themeTrack.top = nil
quick.themeChoices.lagoon.scripts.OnClick()
assert(settings.vignetteRadarTheme == "lagoon" and quick.themeOffset == 144,
    "a palette in the final row must remain selectable")
quick.SetThemeScroll(0)
quickControl("Themes", "vignetteRadarTheme", "ember").scripts.OnClick()
assert(settings.vignetteRadarTheme == "ember" and panel.title.textColor[1] == 1
    and panel.field.background.vertexColor[1] > .04,
    "theme presets must recolor the panel and radar surface")
ColorPickerFrame = {
    SetupColorPickerAndShow = function(self, info) self.info = info end,
    GetColorRGB = function() return .2, .4, .6 end,
}
for _, object in ipairs(objects) do
    if object.parent == quick.pages.Themes and object.colorSlot == "accent" then
        object.scripts.OnClick(object)
        break
    end
end
assert(ColorPickerFrame.info, "a color swatch must open Blizzard's color picker")
ColorPickerFrame.info.swatchFunc()
assert(math.abs(panel.player.vertexColor[1] - .2) < .001 and quick.customLabel.text == "CUSTOM COLORS",
    "a custom accent must immediately recolor the player dot")
quickControl("Themes", "vignetteRadarTheme", "frost").scripts.OnClick()
assert(settings.vignetteRadarTheme == "frost" and not addon.VignetteRadarStyle.IsCustomized(),
    "choosing a preset must replace the prior custom palette")
local iconToggle = quickControl("Themes", "vignetteRadarShapes")
iconToggle:SetChecked(false)
iconToggle.scripts.OnClick(iconToggle)
assert(settings.vignetteRadarShapes == false
    and panel.blipByKey["preview-rare"].dot.texture == "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    and panel.blipByKey["preview-boss"].dot.vertexColor[1] > panel.blipByKey["preview-rare"].dot.vertexColor[1],
    "dots-only mode must keep rare and boss colors visibly distinct")
for _, object in ipairs(objects) do
    if object.parent == quick.pages.Themes and object.colorSlot == "boss" then
        object.scripts.OnClick(object)
        break
    end
end
ColorPickerFrame.info.swatchFunc()
assert(math.abs(panel.blipByKey["preview-boss"].dot.vertexColor[1] - .2) < .001
    and math.abs(panel.blipByKey["preview-rare"].dot.vertexColor[1] - .78) < .001,
    "world-boss color must be independently editable from rare color")
quick.tabs.Guides.scripts.OnClick(quick.tabs.Guides)
local function plusFor(key)
    for _, object in ipairs(objects) do
        if object.parent == quick.pages.Guides and object.optionKey == key and object.text == "+" then
            return object
        end
    end
end
plusFor("vignetteRadarRingOpacity").scripts.OnClick()
assert(settings.vignetteRadarRingOpacity == .75
    and math.abs(panel.rangeRing[1].color[4] - .045 * .75) < .001,
    "ring visibility control must change the real ring alpha")
plusFor("vignetteRadarChevronOpacity").scripts.OnClick()
plusFor("vignetteRadarHeadingOpacity").scripts.OnClick()
assert(math.abs(panel.headingChevron[1].color[4] - .8) < .001
    and math.abs(panel.direction.color[4] - .5) < .001,
    "chevron and facing-line opacity must be separate live controls")
plusFor("vignetteRadarChevronDistance").scripts.OnClick()
assert(settings.vignetteRadarChevronDistance == 5
    and math.abs(panel.headingChevron[1].startPoint[4] - 5) < .001,
    "chevron gap must redraw at the new distance from the center dot")
plusFor("vignetteRadarHeadingLength").scripts.OnClick()
assert(math.abs(panel.direction.endPoint[4] - panel.plotRadius * .35) < .001,
    "facing-line length must redraw using the selected radius fraction")
local sweepToggle = quickControl("Guides", "vignetteRadarFullSweep")
sweepToggle:SetChecked(true)
sweepToggle.scripts.OnClick(sweepToggle)
local sweep = panel.sweepLines
assert(settings.vignetteRadarFullSweep and #sweep == 2 and sweep[1]:IsShown()
    and sweep[1].parent == panel.field and sweep[1].layer == "BORDER"
    and sweep[1].color[4] < .2 and panel.blipByKey["preview-rare"].level > panel.field.level,
    "the optional full-size sweep must stay subtle and behind markers")
local oldAngle = panel._sweepAngle
panel.scripts.OnUpdate(panel, .06)
assert(panel._sweepAngle ~= oldAngle and sweep[1]:IsShown(),
    "the full-size sweep must animate while enabled")
sweepToggle:SetChecked(false)
sweepToggle.scripts.OnClick(sweepToggle)
assert(not settings.vignetteRadarFullSweep and not sweep[1]:IsShown(),
    "turning the sweep off must hide its lines immediately")
quick.tabs.Behavior.scripts.OnClick(quick.tabs.Behavior)
local combatCheck = quickControl("Behavior", "vignetteRadarKeepVisibleCombat")
combatCheck:SetChecked(true)
combatCheck.scripts.OnClick(combatCheck)
assert(settings.vignetteRadarKeepVisibleCombat == true and panel.combatToggle.keepVisible,
    "the compact combat setting must update the footer square")
panel.combatToggle.scripts.OnClick(panel.combatToggle)
assert(settings.vignetteRadarKeepVisibleCombat == false and combatCheck:GetChecked() == false,
    "the footer square must keep compact settings synchronized")
panel.settingsDot.scripts.OnClick(panel.settingsDot)
assert(not quick:IsShown(), "clicking the dot again must close compact settings")
panel.settingsDot.scripts.OnClick(panel.settingsDot)
quick.tabs.Layout.scripts.OnClick(quick.tabs.Layout)
local circleCheck = quickControl("Layout", "vignetteRadarCircleOnly")
circleCheck:SetChecked(true)
circleCheck.scripts.OnClick(circleCheck)
assert(settings.vignetteRadarCircleOnly and not quick:IsShown() and not panel.title:IsShown(),
    "the compact layout setting must enter circle-only view and close the covered settings panel")
panel.frameToggle.scripts.OnClick(panel.frameToggle)
assert(not settings.vignetteRadarCircleOnly and circleCheck:GetChecked() == false,
    "the on-circle restore control must synchronize the compact layout setting")
UIParent:SetSize(800, 600)
addon.SetVignetteRadarLayout("squat")
panel:SetScale(1)
panel:ClearAllPoints()
panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 210, -100)
panel.settingsDot.scripts.OnClick(panel.settingsDot)
assert(quick:IsShown() and quick.point[1] == "TOPLEFT" and quick.point[2] == panel
    and quick:GetScale() > .65 and quick:GetScale() < .75,
    "on an 800px canvas the settings panel must shrink beside Squat instead of covering it")
panel.settingsDot.scripts.OnClick(panel.settingsDot)
UIParent:SetSize(1600, 900)

-- A map transition can briefly yield no map, position, vignettes, or quests.
-- The stay-visible choice keeps the instrument present without stale markers.
local savedQuestLog = C_QuestLog
C_QuestLog = { GetQuestsOnMap = function() return {} end }
settings.vignetteRadarHideWhenEmpty = true
settings.vignetteRadarKeepVisibleCombat = true
guids, mapID, now = {}, nil, 1000
addon.SetVignetteRadarEnabled(true) -- Reset the temporary manual open/closed choice.
for _, circleOnly in ipairs({ false, true }) do
    addon.SetVignetteRadarCircleOnly(circleOnly)
    addon.VignetteRadarAPI.Refresh(true)
    assert(panel:IsShown() and panel.summary.text == "POSITION UNAVAILABLE"
        and next(panel.blipByKey) == nil,
        "stay visible must keep an empty radar open through a missing map without old markers")
    mapID = 901
    addon.VignetteRadarAPI.Refresh(true)
    assert(panel:IsShown() and #addon.VignetteRadarAPI.GetTargets() == 0
        and next(panel.blipByKey) == nil,
        "stay visible must survive a new map whose vignette and quest scans are empty")
    mapID = nil
end

-- Explicit close and disable still take priority over automatic visibility.
panel.close.scripts.OnClick(panel.close)
addon.VignetteRadarAPI.Refresh(true)
assert(not panel:IsShown() and settings.vignetteRadarEnabled,
    "closing the panel must win over stay visible during later scans")
launcher.scripts.OnClick(launcher, "LeftButton")
assert(panel:IsShown(), "the launcher must reopen a manually closed radar")
addon.SetVignetteRadarEnabled(false)
addon.VignetteRadarAPI.Refresh(true)
assert(not panel:IsShown(), "disabled tracking must keep the panel closed even with stay visible enabled")

-- With the setting off, the original hide-when-empty behavior still applies.
settings.vignetteRadarKeepVisibleCombat = false
addon.SetVignetteRadarEnabled(true)
assert(not panel:IsShown(), "hide when empty must still work when stay visible is off")
settings.vignetteRadarKeepVisibleCombat = true
addon.VignetteRadarAPI.Refresh(true)
assert(panel:IsShown(), "turning stay visible back on must reopen the automatically hidden radar")

local savedTreasurePosition = livePositions.treasure
livePositions.treasure = { x = 0.51, y = 0.5 }
mapID, guids = 902, { "treasure" }
addon.VignetteRadarAPI.Refresh(true)
assert(panel:IsShown() and panel.blipByKey.treasure and panel.blipByKey.treasure.target.stale ~= true,
    "live detections returning after a map transition must render normally")
livePositions.treasure = savedTreasurePosition
C_QuestLog = savedQuestLog

-- Exploration overlays stay inside the field and crowded detections remain selectable.
local exploration = addon.VignetteRadarExploration
local ok, pin = exploration.AddPin(addon.VignetteRadarAPI.GetPlayerSnapshot(), "Test cave")
pin.worldX = pin.worldX + 40
assert(ok and exploration.AddRouteStop(pin))
addon.VignetteRadarAPI.Refresh(false)
assert(panel.exploreDots and panel.exploreDots[1]:IsShown() and panel.exploreLines[1]:IsShown(),
    "pins and numbered route stops must draw on the radar")
for _, dot in ipairs(panel.exploreDots) do
    if dot:IsShown() then
        local x, y = dot.point[4], dot.point[5]
        assert(x*x+y*y <= panel.plotRadius*panel.plotRadius,
            "exploration dots must stay inside the plotting ring")
    end
end
exploration.ClearRoute()
exploration.RemovePin(pin.id)
addon.VignetteRadarTargetPicker.ClearFocus()
settings.vignetteRadarCategories = { rare=true, treasure=true, event=true, other=true }
settings.vignetteRadarUntangle = true
livePositions.rare = { x=.51, y=.5 }
livePositions.treasure = { x=.51, y=.5 }
now, guids = 1100, { "rare", "treasure" }
addon.VignetteRadarAPI.Refresh(true)
local crowded
for _, blip in pairs(panel.blipByKey) do if blip.cluster then crowded = blip; break end end
assert(crowded and crowded.count:IsShown() and crowded.count.text == "2",
    "overlapping detections must expose a count badge")
crowded.scripts.OnEnter(crowded)
panel.scripts.OnUpdate(panel, .06)
assert(panel.blipByKey.rare and panel.blipByKey.treasure,
    "hovering a count badge must spread individual targets for selection")
assert(panel.blipByKey.rare.target.groupMin == 3 and panel.blipByKey.rare.target.groupMax == 5,
    "Blizzard's available group-size recommendation must reach the marker")

io.write("vignette radar UI tests passed\n")
