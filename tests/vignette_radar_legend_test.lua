local sourcePath = arg[1] or "UI/Legend.lua"

local objects = {}
local methods = {}
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
function methods:GetLeft() return self.left end
function methods:GetRight() return self.right or 100 end
function methods:GetTop() return self.top end
function methods:GetBottom() return self.bottom end
function methods:SetPoint(...) self.point = { ... }; self.points = self.points or {}; self.points[#self.points + 1] = self.point end
function methods:ClearAllPoints() self.point, self.points = nil, {} end
function methods:SetAllPoints(...) self.allPoints = { ... } end
function methods:SetBackdrop(value) self.backdrop = value end
function methods:SetBackdropColor(...) self.backdropColor = { ... } end
function methods:SetBackdropBorderColor(...) self.backdropBorderColor = { ... } end
function methods:SetFrameStrata(value) self.strata = value end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:EnableMouse(value) self.mouseEnabled = value end
function methods:SetFont(...) self.font = { ... } end
function methods:SetText(value) self.text = value end
function methods:SetTextColor(...) self.textColor = { ... } end
function methods:SetJustifyH(value) self.justifyH = value end
function methods:SetWordWrap(value) self.wordWrap = value end
function methods:SetMaxLines(value) self.maxLines = value end
function methods:SetColorTexture(...) self.color = { ... } end
function methods:SetTexture(value) self.texture = value end
function methods:SetAtlas(value) self.atlas = value end
function methods:SetVertexColor(...) self.vertexColor = { ... } end
function methods:SetAlpha(value) self.alpha = value end
function methods:SetScript(name, callback) self.scripts = self.scripts or {}; self.scripts[name] = callback end
function methods:IsShown() return self.shown == true end
function methods:Show() self.shown = true end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:Hide()
    self.shown = false
    if self.scripts and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:CreateTexture()
    local texture = setmetatable({ kind = "Texture", parent = self, shown = true }, { __index = methods })
    objects[#objects + 1] = texture
    return texture
end
function methods:CreateLine()
    local line = setmetatable({ kind = "Line", parent = self, shown = true }, { __index = methods })
    objects[#objects + 1] = line
    return line
end
function methods:SetThickness(value) self.thickness = value end
function methods:SetStartPoint(...) self.startPoint = { ... } end
function methods:SetEndPoint(...) self.endPoint = { ... } end
function methods:CreateFontString()
    local label = setmetatable({ kind = "FontString", parent = self, shown = true }, { __index = methods })
    objects[#objects + 1] = label
    return label
end

function CreateFrame(kind, name, parent)
    -- Native WoW frames begin shown, which catches lazy-panel initialization bugs.
    local frame = setmetatable({ kind = kind, name = name, parent = parent, shown = true }, { __index = methods })
    objects[#objects + 1] = frame
    if name then _G[name] = frame end
    return frame
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1600, 900)
STANDARD_TEXT_FONT = "fallback.ttf"
EllesmereUI = { EXPRESSWAY = "native-eui-font.ttf" }
local tooltipLines = {}
GameTooltip = {
    SetOwner = function() tooltipLines = {} end,
    SetText = function(_, value) tooltipLines[#tooltipLines + 1] = value end,
    AddLine = function(_, value) tooltipLines[#tooltipLines + 1] = value end,
    Show = function() end, Hide = function() end,
}

local settings = {}
local refreshes = 0
local addon = {
    GetSettings = function() return settings end,
    RefreshVignetteRadar = function() refreshes = refreshes + 1 end,
}
assert(loadfile(sourcePath))("VignetteRadar", addon)

local legend = assert(addon.VignetteRadarLegend, "legend module must publish its integration API")
for _, category in ipairs({ "rare", "treasure", "event", "other" }) do
    assert(settings.vignetteRadarCategories[category] == true, "all categories must default on: " .. category)
    assert(legend.IsCategoryEnabled(category), "default category state must be readable: " .. category)
end
assert(legend.GetHighlight() == nil, "spotlight must default to all categories")
assert(legend.IsCategoryEnabled("unknown"), "unknown Blizzard categories must safely use the other filter")

local r, g, b = legend.ColorFor("treasure")
assert(r == 1 and g == 0.68 and b == 0.16, "treasure must use the legend's gold treatment")
r, g, b = legend.ColorFor("rare")
assert(r == 0.78 and g == 0.88 and b == 1,
    "the shared rare filter must use silver-blue rather than boss red")
local _, _, _, _, alpha, normalized = legend.DotStyle("unrecognized")
assert(normalized == "other" and alpha == 1, "dot style must normalize unknown categories without inventing data")
assert(legend.VignetteSource({ source = "minimap" }) == "minimap"
    and legend.VignetteSource({ source = "worldMap" }) == "worldMap"
    and legend.VignetteSource({ source = "minimap", stale = true }) == "lastSeen"
    and legend.VignetteSource({ sample = true }) == "preview",
    "vignette source states must distinguish live, map-only, remembered, and preview marks")
assert(legend.QuestPointSource({ nextStep = { onCurrentMap = true, x = .2, y = .3 } }) == "objective"
    and legend.QuestPointSource({ nextStep = { onCurrentMap = false, x = .2, y = .3 } }) == "questMap"
    and legend.QuestPointSource({}) == "questMap",
    "only a current-map Blizzard waypoint is an objective point")
assert(legend.SourceDescription("estimated"):find("estimated location", 1, true)
    and legend.SourceDescription("saved"):find("not a live detection", 1, true),
    "source descriptions must avoid presenting estimates and saved notes as live data")

legend.SetHighlight("rare")
assert(settings.vignetteRadarHighlight == "rare", "spotlight selection must persist")
assert(legend.OpacityFor("rare") == 1 and legend.OpacityFor("event") == 0.18,
    "spotlight must preserve the chosen category and dim other enabled dots")
assert(refreshes == 1, "a spotlight change must refresh the radar")

legend.SetCategoryEnabled("treasure", false)
assert(not legend.IsCategoryEnabled("treasure") and legend.OpacityFor("treasure") == 0,
    "disabled categories must be completely filtered")
assert(refreshes == 2, "a category filter change must refresh the radar")
legend.SetCategoryEnabled("rare", false)
assert(legend.GetHighlight() == nil, "disabling the spotlighted category must clear the spotlight")

settings.vignetteRadarHighlight = "invented"
settings.vignetteRadarCategories.event = "bad"
legend.ApplyDefaults(settings)
assert(settings.vignetteRadarHighlight == nil and settings.vignetteRadarCategories.event == true,
    "defaults must repair invalid saved settings")

local anchor = CreateFrame("Frame", nil, UIParent)
anchor.right = 500
assert(legend.Toggle(anchor) == true and legend.IsShown(), "toggle must open the attached legend")
local panel = assert(_G.VignetteRadarLegendPanel, "legend panel must have a stable global frame name")
assert(panel.width == 232 and panel.height == 412 and panel.clamped == true
    and not panel.accent, "legend must fit without a left edge rail")
assert(panel.mouseEnabled == true and panel.divider.height == 1,
    "legend surface must capture input and preserve a visible header gutter")
assert(panel.point[1] == "TOPLEFT" and panel.point[3] == "TOPRIGHT" and panel.point[4] == 8,
    "legend must sit outside the radar with an explicit gutter")
assert(panel.title.font[1] == EllesmereUI.EXPRESSWAY and panel.title.text == "RADAR LEGEND",
    "legend must use native EllesmereUI typography")
assert(panel.liveHint.text == "CLICK LIVE TYPE TO SPOTLIGHT"
    and panel.showHint.text == "SHOW" and panel.all.label.text == "CLEAR"
    and panel.mapHeading.text == "MAP NOTES · REFERENCE ONLY"
    and panel.otherHeading.text == "OTHER MARKS · REFERENCE ONLY",
    "the legend must identify spotlightable rows, visibility switches, and reference-only symbols")
assert(panel.rows.rare and panel.rows.treasure and panel.rows.event and panel.rows.other,
    "legend must render one independent row for every supported filter")
for _, kind in ipairs({ "treasure", "mob", "item", "note", "entrance", "guide" }) do
    local note = assert(panel.mapNotes[kind], "every map note type needs a legend entry")
    assert(note.rim.texture == "Interface\\CharacterFrame\\TempPortraitAlphaMask"
        and note.core.width == 3 and note.core.height == 3,
        "map note symbols must match their hollow radar markers")
    assert(note.point[4] >= 9 and note.point[4] + note.width <= panel.width - 9
        and -note.point[5] + note.height < panel.height - 20,
        "map note entries must stay within the legend's visible gutters")
end
assert(panel.mapCaption.text:find("saved, not live", 1, true)
    and panel.guides.quest.fill.width == 8
    and panel.guides.quest.fill.texture == "Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond.tga"
    and panel.guides.area.fill.width == 11
    and panel.guides.pin and panel.guides.route.number.text == "1"
    and #panel.guides.trail.dots == 3 and #panel.guides.trail.marks == 3
    and #panel.guides.stale.lines == 4,
    "legend must explain quest, exploration, and last-seen symbols accurately")
for _, guide in pairs(panel.guides) do
    assert(guide.point[4] >= 9 and guide.point[4] + guide.width <= panel.width - 9
        and -guide.point[5] + guide.height < panel.height - 20,
        "guide entries must stay inside the panel with a footer gutter")
end
assert(panel.rows.rare.label.text == "RARE / BOSS" and panel.rows.rare.label.width == 90
    and panel.rows.rare.label.point[2] == 39 and panel.rows.rare.label.maxLines == 1,
    "the rare and boss label must stay bounded before its toggle")
assert(panel.rows.rare.swatch.texture == "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
    and panel.rows.rare.bossSwatch.texture == panel.rows.rare.swatch.texture
    and panel.rows.rare.swatch.vertexColor[1] == 0.78
    and panel.rows.rare.bossSwatch.vertexColor[1] == 1
    and panel.rows.rare.bossSwatch.point[2] == 21,
    "the rare filter must show separate silver and red skulls")
assert(panel.rows.treasure.swatch.atlas == "VignetteLoot",
    "treasure must use the familiar chest atlas when SetAtlas is available")
panel.rows.rare.scripts.OnEnter(panel.rows.rare)
assert(table.concat(tooltipLines, "\n"):find(
    "Silver skull: rare enemy. Red skull: world boss.", 1, true),
    "rare tooltip must explain both symbols in plain language")
assert(panel.rows.event.scripts.OnMouseDown and panel.rows.event.scripts.OnMouseUp,
    "category controls must expose native pressed feedback")
assert(panel.rows.rare.toggle.label.text == "OFF", "the UI must reflect persisted filter state")

settings.vignetteRadarPOISource = "none"
settings.vignetteRadarQuestDots = false
settings.vignetteRadarBreadcrumbs = false
legend.Refresh()
assert(panel.mapNotes.mob.alpha == .6 and panel.mapNotes.mob.label.text == "Mob off"
    and panel.mapCaption.text:find("Map notes off", 1, true)
    and panel.guides.quest.label.text == "Quest off"
    and panel.guides.trail.label.text == "Trail off",
    "the guide must visibly identify optional features that are switched off")
settings.vignetteRadarPOISource = "auto"
settings.vignetteRadarPOITypes = { treasure = true, mob = false, item = true, note = true }
settings.vignetteRadarQuestDots = true
settings.vignetteRadarQuestAreas = true
settings.vignetteRadarQuestHalos = true
settings.vignetteRadarBreadcrumbs = true
settings.vignetteRadarTrailStyle = "ticks"
settings.vignetteRadarShapes = false
legend.Refresh()
assert(panel.mapNotes.treasure.alpha == 1 and panel.mapNotes.mob.alpha == .6
    and panel.guides.quest.alpha == 1 and panel.guides.quest.halo:IsShown()
    and panel.guides.quest.label.text == "Quest + estimate"
    and panel.guides.area.label.text == "Blizzard area" and panel.guides.trail.alpha == 1
    and panel.guides.area.fill.vertexColor[3] > panel.guides.area.fill.vertexColor[1]
    and panel.guides.quest.halo.vertexColor[3] > panel.guides.quest.halo.vertexColor[1]
    and panel.guides.trail.label.text == "Trail: Ticks"
    and panel.guides.trail.marks[1]:IsShown() and not panel.guides.trail.dots[1]:IsShown()
    and panel.rows.rare.swatch.texture == "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    and panel.rows.treasure.swatch.texture == panel.rows.rare.swatch.texture,
    "guide and live symbols must track map filters, settings, and icon-free mode")
addon.VignetteRadarStyle = { Color = function(slot)
    if slot == "rare" then return .2, .3, .4 end
    if slot == "quest" then return .7, .6, .5 end
    return .8, .7, .6
end }
settings.vignetteRadarShapes = true
legend.Refresh()
assert(panel.mapNotes.mob.rim.vertexColor[1] == .2
    and panel.guides.quest.fill.vertexColor[1] == .7
    and panel.guides.stale.lines[1].color[4] == .4
    and panel.guides.stale.alpha ~= .4
    and panel.rows.rare.swatch.texture == "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
    and panel.rows.treasure.swatch.atlas == "VignetteLoot",
    "legend symbols must follow theme colors and restore icon artwork when re-enabled")
addon.VignetteRadarQuestColors = { { 94/255, 219/255, 199/255 } }
settings.vignetteRadarQuestColors = true
settings.vignetteRadarQuestAreaColors = true
legend.Refresh()
assert(panel.guides.area.fill.vertexColor[1] == 94/255
    and panel.guides.area.fill.vertexColor[2] == 219/255
    and panel.guides.quest.halo.vertexColor[1] == 94/255,
    "the legend must show matching area and halo colors when that option is enabled")
settings.vignetteRadarQuestAreaColors = false
legend.Refresh()
assert(panel.guides.area.fill.vertexColor[1] == .34
    and panel.guides.quest.halo.vertexColor[3] == 1,
    "the legend must return to blue when matching area colors are disabled")

panel.rows.event.scripts.OnClick(panel.rows.event)
assert(settings.vignetteRadarHighlight == "event", "clicking a category row must spotlight it")
assert(panel.rows.event.selection:IsShown() and panel.rows.event.focusCue:IsShown()
    and panel.rows.event.focusCue.text == "FOCUS",
    "the selected category needs an explicit spotlight cue")
assert(panel.rows.event.alpha == 1 and panel.rows.other.alpha == 0.58,
    "the selected row must remain strong while nonfocused enabled rows are dimmed")
panel.all.scripts.OnClick(panel.all)
assert(settings.vignetteRadarHighlight == nil and not panel.rows.event.focusCue:IsShown()
    and panel.status.text == "SPOTLIGHT OFF · SHOWN TYPES EQUAL",
    "CLEAR must remove the spotlight while preserving visibility filters")

local before = legend.IsCategoryEnabled("other")
panel.rows.other.toggle.scripts.OnClick(panel.rows.other.toggle)
assert(legend.IsCategoryEnabled("other") ~= before, "the row switch must toggle its category filter")
assert(legend.Toggle(anchor) == false and not legend.IsShown(), "toggle must close an open legend")

UIParent:SetSize(800, 600)
local squat = CreateFrame("Frame", nil, UIParent)
squat:SetSize(374, 230)
squat.left, squat.right, squat.top, squat.bottom = 213, 587, 415, 185
assert(legend.Toggle(squat) and legend.IsShown(), "legend must open from a Squat panel anchor")
assert(panel.point[1] == "TOPLEFT" and panel.point[3] == "TOPRIGHT" and panel.point[4] == 8
    and squat.point and squat.point[4] + squat.width + 8 + panel.width <= 800 - 8,
    "a tall legend must shift a centered Squat anchor just enough to fit beside it")
squat.bottom = 121
assert(legend.Reanchor(squat) and panel.point[1] == "TOPLEFT" and panel.point[3] == "TOPRIGHT",
    "an open legend must retain its side gutter after Squat layout changes")
assert(legend.Toggle(squat) == false, "legend Squat toggle must close")

-- The quest key is independent of the category legend and mirrors the same
-- per-quest color slot used by the radar diamond and quest key.
addon.VignetteRadarQuestColors = {
    { 94/255, 219/255, 199/255 }, { 255/255, 179/255, 87/255 },
}
settings.vignetteRadarQuestColors = true
local questAnchor = CreateFrame("Frame", nil, UIParent)
questAnchor.left, questAnchor.right, questAnchor.top, questAnchor.bottom = 320, 520, 400, 200
local entries = {}
for index = 1, 10 do
    entries[index] = { questID = index, name = "Quest " .. index,
        colorSlot = index % 2 + 1, distance = index * 10 }
end
legend.SetQuestEntries(entries)
assert(legend.ToggleQuest(questAnchor) and legend.IsQuestShown(),
    "quest key must open independently from the category legend")
local questPanel = assert(legend.Testing.GetQuestPanel(), "quest key must have a stable panel")
assert(questPanel.point[1] == "TOPRIGHT" and questPanel.point[3] == "TOPLEFT"
    and questPanel.point[4] == -8 and questPanel.width == 224 and not questPanel.accent,
    "quest key must sit left of the radar without a colored edge rail")
assert(questPanel.rows[1].name.text == "Quest 1" and questPanel.rows[1].fill.vertexColor[1] == 1
    and questPanel.rows[1].fill.vertexColor[2] == 179/255
    and questPanel.rows[1].fill.vertexColor[3] == 87/255,
    "quest names and diamonds must use the exact quest marker palette")
assert(questPanel.rows[1].rim.texture == "Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond-hollow.tga"
    and math.abs(questPanel.rows[1].rim.width - 13 * 26 / 30) < .001
    and not questPanel.rows[1].fill:IsShown(),
    "the quest key must show an unfinished quest with a hollow diamond")
entries[1].completed = true
legend.SetQuestEntries(entries)
assert(questPanel.rows[1].rim.texture == "Interface\\AddOns\\VignetteRadar\\Media\\quest-diamond.tga"
    and questPanel.rows[1].rim.width == 13
    and questPanel.rows[1].fill:IsShown(),
    "the quest key must use a solid diamond for a complete quest")
assert(questPanel.scrollTrack:IsShown() and questPanel.rows[8]:IsShown()
    and not questPanel.rows[9], "the compact key must scroll instead of escaping its panel")
questPanel.scripts.OnMouseWheel(questPanel, -1)
assert(questPanel.rows[1].name.text == "Quest 2" and questPanel.status.text:find("2–9", 1, true),
    "scrolling must update visible rows and position text")
settings.vignetteRadarQuestColors = false
legend.SetQuestEntries(entries)
assert(questPanel.rows[1].fill.vertexColor[1] == .7
    and questPanel.rows[1].fill.vertexColor[2] == .6,
    "the quest key must follow the themed single-color mode")
assert(legend.ToggleQuest(questAnchor) == false and not legend.IsQuestShown(),
    "quest key toggle must close an open key")

-- Validate fallback behavior without native EllesmereUI helpers or fonts.
EllesmereUI = nil
methods.SetAtlas = nil
local fallbackSettings = {}
local fallbackAddon = { GetSettings = function() return fallbackSettings end }
assert(loadfile(sourcePath))("VignetteRadar", fallbackAddon)
assert(fallbackAddon.VignetteRadarLegend.Toggle(anchor), "legend must build without EllesmereUI helper functions")
assert(fallbackAddon.VignetteRadarLegend.Testing.GetPanel().title.font[1] == STANDARD_TEXT_FONT,
    "helper-free mode must use the standard client font")
assert(fallbackAddon.VignetteRadarLegend.Testing.GetPanel().rows.treasure.swatch.texture
    == "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    and fallbackAddon.VignetteRadarLegend.Testing.GetPanel().rows.treasure.swatch.vertexColor[1] == 1,
    "treasure keeps its circular color swatch when the atlas API is absent")

io.write("vignette radar legend tests passed\n")
