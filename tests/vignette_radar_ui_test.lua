local sourcePath = arg[1] or "VignetteRadar_Radar.lua"
local legendSourcePath = arg[2] or "VignetteRadar_Legend.lua"
local targetPickerSourcePath = arg[3] or "VignetteRadar_TargetPicker.lua"
local optionsSourcePath = arg[4] or "VignetteRadar_Options.lua"
unpack = table.unpack

local objects = {}
local methods = {}
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
function methods:GetRight() return self.right or ((self:GetLeft() or 0) + self:GetWidth()) end
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
function methods:SetMovable(value) self.movable = value end
function methods:EnableMouse(value) self.mouse = value end
function methods:RegisterForClicks(...) self.clickButtons = { ... } end
function methods:RegisterForDrag(...) self.dragButtons = { ... } end
function methods:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:SetScript(name, callback) self.scripts = self.scripts or {}; self.scripts[name] = callback end
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
function methods:SetThickness(value) self.thickness = value end
function methods:SetStartPoint(...) self.startPoint = { ... } end
function methods:SetEndPoint(...) self.endPoint = { ... } end
function methods:SetFont(...) self.font = { ... } end
function methods:SetText(value) self.text = value end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:SetJustifyH(value) self.justifyH = value end
function methods:SetWordWrap(value) self.wordWrap = value end
function methods:IsShown() return self.shown == true end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false; if self.scripts and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:StartMoving() self.moving = true end
function methods:StopMovingOrSizing() self.moving = false end
function methods:GetLeft() return 30 end
function methods:GetTop() return 380 end
function methods:CreateTexture()
    local texture = setmetatable({ kind = "Texture", parent = self }, { __index = methods })
    objects[#objects + 1] = texture
    return texture
end
function methods:CreateFontString()
    local label = setmetatable({ kind = "FontString", parent = self }, { __index = methods })
    objects[#objects + 1] = label
    return label
end
function methods:CreateLine()
    local line = setmetatable({ kind = "Line", parent = self }, { __index = methods })
    objects[#objects + 1] = line
    return line
end

function CreateFrame(kind, name, parent)
    local frame = setmetatable({ kind = kind, name = name, parent = parent, shown = false }, { __index = methods })
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
    SetOwner = function() end, SetText = function() end, AddLine = function() end,
    Show = function() end, Hide = function() end,
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
assert(loadfile("VignetteRadar_Features.lua"))("VignetteRadar", addon)
assert(loadfile(legendSourcePath))("VignetteRadar", addon)
assert(loadfile(targetPickerSourcePath))("VignetteRadar", addon)
assert(loadfile(sourcePath))("VignetteRadar", addon)
assert(loadfile(optionsSourcePath))("VignetteRadar", addon)

local optionsEvent
for _, object in ipairs(objects) do
    if object.events and object.events.PLAYER_LOGIN then optionsEvent = object end
end
assert(optionsEvent and optionsEvent.scripts.OnEvent, "standalone addon must register its own settings")
optionsEvent.scripts.OnEvent(optionsEvent)
local optionsPanel = assert(_G.VignetteRadarOptionsPanel, "standalone addon needs a populated settings panel")
assert(optionsPanel.width == 520 and optionsPanel.height == 365 and registeredCategory,
    "standalone options must fit the Settings canvas without EllesmereUI")
local toggles, range150
toggles = {}
for _, object in ipairs(objects) do
    if object.parent == optionsPanel.pages.Radar and object.kind == "CheckButton" then
        toggles[#toggles + 1] = object
    elseif object.parent == optionsPanel.pages.Radar and object.text == "150 yd" then
        range150 = object
    end
end
assert(#toggles == 3 and range150, "standalone options must expose all visibility toggles and range choices")
range150.scripts.OnClick(range150)
assert(settings.vignetteRadarRange == 150 and range150.highlightLocked,
    "range buttons must update and reflect the standalone saved setting")
settings.vignetteRadarRange = 450
SlashCmdList.VIGNETTERADAR("config")
assert(openedCategory == 517, "config command must open the standalone AddOns settings category")

settings.vignetteRadarEnabled = false
SlashCmdList.VIGNETTERADAR("preview")
local panel = assert(_G.VignetteRadarPanel, "preview must construct the radar panel")
local launcher = assert(_G.VignetteRadarLauncher, "preview must construct the draggable launcher")
assert(settings.vignetteRadarEnabled == false, "layout preview must not silently enable live tracking")
assert(panel:IsShown() and panel.width == 220 and panel.height == 252, "preview must show the intended compact panel")
assert(panel.field.width == 200 and panel.field.height == 200 and panel.field.point[1] == "BOTTOM"
    and panel.field.point[3] == 9, "radar field must fit below the header with a visible gutter")
assert(panel.drag.width == 128 and panel.target.point[1] == "TOPRIGHT"
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
assert(panel.focusReadout:IsShown() and panel.height == 298 and panel.field.point[3] == 55,
    "focusing must reserve exactly the footer space without moving the radar into its header")
assert(panel.focusMeta.text:find("350 yd", 1, true) and panel.focusMeta.text:find("42% HP", 1, true),
    "focused live rare must show distance and available health")
assert(panel.focusName.width == 172 and panel.focusMeta.width == 172,
    "long target text must stay bounded within the focus footer")
-- Field bottom is 55; divider y46 leaves a 9px gutter. Footer ends y40 (6px gutter).
assert(panel.focusReadout.point[3] + panel.focusReadout.height <= 40
    and panel.focusDivider.point[3] == 46 and panel.field.point[3] >= 55,
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
assert(not panel.blipByKey.rare and not panel.focusReadout:IsShown() and panel.height == 252
    and panel.field.point[3] == 9, "expiry must clear focus and release footer space")

settings.vignetteRadarAlertSound = true
combat, now, guids = true, 120, { "treasure", "rare" }
addon.VignetteRadarAPI.Refresh(true)
assert(panel:GetAlpha() == 0.35 and launcher:GetAlpha() == 0.35 and #sounds == 0,
    "combat must fade both surfaces and suppress detection sounds")
combat, now = false, 125
addon.VignetteRadarAPI.Refresh(true)
assert(panel:GetAlpha() == 1 and launcher:GetAlpha() == 1 and #sounds == 0,
    "leaving combat must restore opacity without replaying suppressed detections")
instance = true
addon.VignetteRadarAPI.Refresh(true)
assert(panel:GetAlpha() == 0.35, "instance quiet mode must fade the radar")
instance = false
addon.VignetteRadarAPI.Refresh(true)
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

io.write("vignette radar UI tests passed\n")
