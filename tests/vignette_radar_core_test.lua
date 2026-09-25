local sourcePath = arg[1] or "VignetteRadar_Core.lua"

WaffleHouseDB = {
    vignetteRadarEnabled = false,
    vignetteRadarHideWhenEmpty = false,
    vignetteRadarRange = 600,
    vignetteRadarLauncherVisible = false,
    vignetteRadarPosition = { x = 111, y = -222 },
    vignetteRadarLauncherPosition = { x = 33, y = -44 },
    vignetteRadarCategories = { rare = false, treasure = true },
    vignetteRadarHighlight = "treasure",
}
VignetteRadarDB = nil
local addon = {}
assert(loadfile(sourcePath))("VignetteRadar", addon)
local db = addon.GetSettings()
assert(db.vignetteRadarEnabled == false and db.vignetteRadarHideWhenEmpty == false
    and db.vignetteRadarLauncherVisible == false and db.vignetteRadarRange == 600,
    "standalone addon must migrate the user's original radar choices")
assert(db.vignetteRadarWorldMap == true, "world-map detections should be included by default")
assert(db.vignetteRadarKeepVisibleCombat == false,
    "existing quiet-combat settings should preserve combat fading")
assert(db.vignetteRadarQuestDots == false and db.vignetteRadarQuestAreas == false,
    "new quest overlays should preserve the existing uncluttered radar until enabled")
assert(db.vignetteRadarQuestHalos == true and db.vignetteRadarQuestColors == true
    and db.vignetteRadarQuestAreaColors == false
    and db.vignetteRadarQuestHaloRadius == 10,
    "estimated quest circles should be ready when quest dots and areas are enabled")
assert(db.vignetteRadarPosition.x == 111 and db.vignetteRadarLauncherPosition.y == -44
    and db.vignetteRadarCategories.rare == false and db.vignetteRadarHighlight == "treasure",
    "standalone addon must preserve placement and category choices")
db.vignetteRadarPosition.x = 999
db.vignetteRadarCategories.rare = true
assert(WaffleHouseDB.vignetteRadarPosition.x == 111 and WaffleHouseDB.vignetteRadarCategories.rare == false,
    "migrated settings must be independent of Waffle House")

WaffleHouseDB.vignetteRadarEnabled = true
assert(addon.GetSettings().vignetteRadarEnabled == false,
    "the old addon must not overwrite standalone settings after migration")

VignetteRadarDB = nil
WaffleHouseDB = nil
local fresh = {}
assert(loadfile(sourcePath))("VignetteRadar", fresh)
local defaults = fresh.GetSettings()
assert(defaults.vignetteRadarRangeLabelOpacity == defaults.vignetteRadarRingOpacity,
    "yard labels must start at the same visibility as the range rings")
defaults.vignetteRadarQuestAreaColorsReset = nil
defaults.vignetteRadarQuestAreaColors = true
fresh.GetSettings()
assert(defaults.vignetteRadarQuestAreaColors == false
    and defaults.vignetteRadarQuestAreaColorsReset == true,
    "the old quest-area color setting must reset to reliable blue once")
defaults.vignetteRadarQuestAreaColors = true
fresh.GetSettings()
assert(defaults.vignetteRadarQuestAreaColors == true,
    "an explicit later choice to color estimated circles must persist")
defaults.vignetteRadarQuestAreaColors = false
assert(defaults.vignetteRadarAutoRouteArrivalRadius == 3,
    "Auto Route must wait for a three-yard arrival by default")
assert(defaults.vignetteRadarBeaconsEnabled == false
    and defaults.vignetteRadarPerformance == "standard"
    and defaults.vignetteRadarBeaconRares == true
    and defaults.vignetteRadarBeaconTreasures == true
    and defaults.vignetteRadarBeaconQuests == true
    and defaults.vignetteRadarBeaconRange == 1200
    and defaults.vignetteRadarBeaconMax == 8,
    "the optional bearing bar should start disabled with bounded defaults")
defaults.vignetteRadarPerformance = "low"
fresh.GetSettings()
assert(defaults.vignetteRadarPerformance == "low", "the user's chosen update rate must persist")
defaults.vignetteRadarPerformance = "unsupported"
fresh.GetSettings()
assert(defaults.vignetteRadarPerformance == "standard", "invalid update rates must reset safely")
defaults.vignetteRadarBearingBarDefaulted = nil
defaults.vignetteRadarBeaconsEnabled = true
fresh.GetSettings()
assert(defaults.vignetteRadarBeaconsEnabled == false,
    "the previous automatic bar should be hidden once for existing users")
defaults.vignetteRadarBeaconsEnabled = true
fresh.GetSettings()
assert(defaults.vignetteRadarBeaconsEnabled == true,
    "turning the bearing bar on after migration must remain the user's choice")
defaults.vignetteRadarRingOpacity = 1.25
defaults.vignetteRadarRangeLabelOpacity = nil
fresh.GetSettings()
assert(defaults.vignetteRadarRangeLabelOpacity == 1.25,
    "existing ring visibility must seed the independent yard-label setting")
defaults.vignetteRadarRingOpacity = .25
fresh.GetSettings()
assert(defaults.vignetteRadarRangeLabelOpacity == 1.25,
    "later ring changes must leave yard-label visibility alone")
defaults.vignetteRadarRangeLabelOpacity = 20
fresh.GetSettings()
assert(defaults.vignetteRadarRangeLabelOpacity == 16,
    "yard-label visibility must stay within its supported range")
defaults.vignetteRadarRingOpacity, defaults.vignetteRadarRangeLabelOpacity = .5, .5
assert(defaults.vignetteRadarEnabled == true and defaults.vignetteRadarHideWhenEmpty == true
    and defaults.vignetteRadarLauncherVisible == true and defaults.vignetteRadarRange == 450
    and defaults.vignetteRadarWorldMap == true and defaults.vignetteRadarLayout == "classic"
    and defaults.vignetteRadarNorthUp == false and defaults.vignetteRadarScale == 1,
    "the radar must work without either optional addon installed")
assert(defaults.vignetteRadarPOISource == "auto",
    "new installations should follow the current zone when a data pack is available")
assert(defaults.vignetteRadarPOIIcons == false,
    "existing map notes should remain dots until pack icons are enabled")
defaults.vignetteRadarPOIIcons = true
fresh.GetSettings()
assert(defaults.vignetteRadarPOIIcons == true, "the pack-icon choice must persist")
defaults.vignetteRadarPOIIcons = "bad"
fresh.GetSettings()
assert(defaults.vignetteRadarPOIIcons == false, "invalid pack-icon settings must reset safely")
assert(defaults.vignetteRadarTrailStyle == "dashes",
    "new and migrated installations should use trail marks distinct from quest dots")
assert(defaults.vignetteRadarTrailSpacing == 1 and defaults.vignetteRadarTrailSpeed == 1
    and defaults.vignetteRadarTrailLifetime == 180
    and defaults.vignetteRadarTrailSize == 1 and defaults.vignetteRadarTrailTailFade == .5
    and defaults.vignetteRadarTrailFadeSpan == 1,
    "new installations should have readable animated marks and a three-minute fade")
for key, values in pairs(fresh.VignetteRadarTrailSettingValues) do
    for _, value in ipairs(values) do
        defaults[key] = value
        fresh.GetSettings()
        assert(defaults[key] == value, "every trail control choice must persist: " .. key .. "=" .. value)
    end
end
defaults.vignetteRadarTrailSpacing, defaults.vignetteRadarTrailSpeed = 1, 1
defaults.vignetteRadarTrailStyle = "ticks"
fresh.GetSettings()
assert(defaults.vignetteRadarTrailStyle == "ticks", "the chosen trail style must persist")
defaults.vignetteRadarTrailStyle = "diamonds"
defaults.vignetteRadarTrailSpacing = 1.5
defaults.vignetteRadarTrailSpeed = 0
defaults.vignetteRadarTrailLifetime = 300
fresh.GetSettings()
assert(defaults.vignetteRadarTrailStyle == "diamonds" and defaults.vignetteRadarTrailSpacing == 1.5
    and defaults.vignetteRadarTrailSpeed == 0 and defaults.vignetteRadarTrailLifetime == 300,
    "new trail styles and flow controls must persist")
defaults.vignetteRadarTrailStyle = "hollow-squares"
defaults.vignetteRadarTrailLifetime = 1
fresh.GetSettings()
assert(defaults.vignetteRadarTrailStyle == "hollow-squares"
    and defaults.vignetteRadarTrailLifetime == 1,
    "square styles and a one-second fade must remain saved")
defaults.vignetteRadarTrailStyle = "unsupported"
defaults.vignetteRadarTrailSpacing = -1
defaults.vignetteRadarTrailSpeed = 99
defaults.vignetteRadarTrailLifetime = 999
fresh.GetSettings()
assert(defaults.vignetteRadarTrailStyle == "dashes" and defaults.vignetteRadarTrailSpacing == 1
    and defaults.vignetteRadarTrailSpeed == 1 and defaults.vignetteRadarTrailLifetime == 180,
    "invalid trail settings must recover safely")
defaults.vignetteRadarTrailSize = .1
defaults.vignetteRadarTrailTailFade = .37
defaults.vignetteRadarTrailFadeSpan = .63
fresh.GetSettings()
assert(defaults.vignetteRadarTrailSize == .1 and defaults.vignetteRadarTrailTailFade == .37
    and defaults.vignetteRadarTrailFadeSpan == .63,
    "precise trail size and fade percentages must survive settings validation")
defaults.vignetteRadarPOISource = "none"
fresh.GetSettings()
assert(defaults.vignetteRadarPOISource == "none", "an existing Off choice must remain Off")
local expectedRanges = { 10, 25, 50, 100, 150, 300, 450, 600, 1200, 2400, 4800 }
assert(#fresh.VignetteRadarRanges == #expectedRanges, "all selectable ranges must be published")
for index, range in ipairs(expectedRanges) do
    assert(fresh.VignetteRadarRanges[index] == range, "range order must stay stable")
    defaults.vignetteRadarRange = range
    fresh.GetSettings()
    assert(defaults.vignetteRadarRange == range, "supported range must remain valid: " .. range)
end
local expectedLayouts = { "classic", "squat", "compact" }
assert(#fresh.VignetteRadarLayouts == #expectedLayouts, "all selectable layouts must be published")
for index, layout in ipairs(expectedLayouts) do
    assert(fresh.VignetteRadarLayouts[index] == layout, "layout order must stay stable")
end
defaults.vignetteRadarRange = 999
defaults.vignetteRadarWorldMap = "bad"
defaults.vignetteRadarQuestDots = "bad"
defaults.vignetteRadarQuestAreas = "bad"
defaults.vignetteRadarQuestHalos = "bad"
defaults.vignetteRadarQuestColors = "bad"
defaults.vignetteRadarQuestAreaColors = "bad"
defaults.vignetteRadarQuestHaloRadius = 999
defaults.vignetteRadarLayout = "unsupported"
defaults.vignetteRadarNorthUp = "bad"
defaults.vignetteRadarScale = "bad"
fresh.GetSettings()
assert(defaults.vignetteRadarRange == 450 and defaults.vignetteRadarWorldMap == true
    and defaults.vignetteRadarQuestDots == false and defaults.vignetteRadarQuestAreas == false
    and defaults.vignetteRadarQuestHalos == true and defaults.vignetteRadarQuestColors == true
    and defaults.vignetteRadarQuestAreaColors == false
    and defaults.vignetteRadarQuestHaloRadius == 10
    and defaults.vignetteRadarLayout == "classic" and defaults.vignetteRadarNorthUp == false
    and defaults.vignetteRadarScale == 1,
    "invalid range, mode, layout, and north-up values must reset to safe defaults")
defaults.vignetteRadarWorldMap = false
defaults.vignetteRadarNorthUp = true
defaults.vignetteRadarScale = 1.35
fresh.GetSettings()
assert(defaults.vignetteRadarNorthUp == true, "north-up preference must persist when enabled")
assert(defaults.vignetteRadarScale == 1.35, "user frame scale must persist")
for _, layout in ipairs({ "classic", "squat", "compact" }) do
    defaults.vignetteRadarLayout = layout
    fresh.GetSettings()
    assert(defaults.vignetteRadarLayout == layout, "supported layout must persist: " .. layout)
end
fresh.GetSettings()
assert(defaults.vignetteRadarWorldMap == false, "world-map choice must persist when disabled")
assert(defaults.vignetteRadarIndependentViews == false
    and defaults.vignetteRadarControlsVisible == true
    and defaults.vignetteRadarQuestKeyProgress == true
    and defaults.vignetteRadarRouteAutoAdvance == false
    and defaults.vignetteRadarRouteArrivalRadius == 20
    and type(defaults.vignetteRadarPOIZoneSources) == "table",
    "new navigation choices need safe defaults")
local profiles = fresh.VignetteRadarViewProfiles
defaults.vignetteRadarCircleOnly = false
defaults.vignetteRadarLayout = "classic"
defaults.vignetteRadarRange, defaults.vignetteRadarScale = 150, 1.2
defaults.vignetteRadarControlsVisible = false
defaults.vignetteRadarIndependentViews = true
profiles.Switch(defaults, "squat")
defaults.vignetteRadarLayout = "squat"
defaults.vignetteRadarRange, defaults.vignetteRadarScale = 300, .9
defaults.vignetteRadarControlsVisible = true
profiles.Switch(defaults, "classic")
defaults.vignetteRadarLayout = "classic"
assert(defaults.vignetteRadarRange == 150 and defaults.vignetteRadarScale == 1.2
    and defaults.vignetteRadarControlsVisible == false,
    "switching layouts must restore zoom, scale, and button visibility")
defaults.vignetteRadarIndependentViews = false
defaults.vignetteRadarCircleOnly = true
defaults.vignetteRadarControlsVisible = true
assert(defaults.vignetteRadarEdgeCues and defaults.vignetteRadarEmptyHelp
    and defaults.vignetteRadarPeekEnabled and defaults.vignetteRadarHoverTools
    and defaults.vignetteRadarFollowTrackedQuest == false,
    "new map, hover, and peek features need explicit saved defaults")
assert(defaults.vignetteRadarNextQuestStep == false
    and defaults.vignetteRadarQuestStartBadges == false
    and defaults.vignetteRadarQuestNumbers == false
    and defaults.vignetteRadarDataStatus == false
    and defaults.vignetteRadarLensEnabled == false
    and defaults.vignetteRadarLensCategory == "quest"
    and defaults.vignetteRadarRouteDraftStops == 5
    and defaults.vignetteRadarRouteDraftRange == 1200,
    "wayfinding additions need conservative opt-in defaults")
assert(defaults.vignetteRadarAlerts == true and defaults.vignetteRadarAlertSound == false
    and defaults.vignetteRadarAlertCategories.rare == true
    and defaults.vignetteRadarAlertCategories.treasure == true
    and defaults.vignetteRadarAlertCategories.event == false
    and defaults.vignetteRadarAlertCategories.other == false
    and defaults.vignetteRadarAlertCooldown == 60,
    "alert preferences need safe standalone defaults")
assert(type(defaults.vignetteRadarFavorites) == "table" and type(defaults.vignetteRadarIgnored) == "table"
    and defaults.vignetteRadarLastSeen == true and defaults.vignetteRadarLastSeenSeconds == 10
    and defaults.vignetteRadarQuietCombat == true and defaults.vignetteRadarQuietInstances == true
    and defaults.vignetteRadarKeepVisibleCombat == false
    and defaults.vignetteRadarCircleOnly == true
    and defaults.vignetteRadarMarkerSize == 7 and defaults.vignetteRadarShapes == true
    and defaults.vignetteRadarShowHealth == true,
    "feature preferences need complete defaults")
defaults.vignetteRadarCircleOnly = false
fresh.GetSettings()
assert(defaults.vignetteRadarCircleOnly == false,
    "a saved full-frame layout must remain the user's choice")
defaults.vignetteRadarAlertCooldown = -100
defaults.vignetteRadarLastSeenSeconds = 10000
defaults.vignetteRadarMarkerSize = 100
defaults.vignetteRadarScale = 99
fresh.GetSettings()
assert(defaults.vignetteRadarAlertCooldown == 5 and defaults.vignetteRadarLastSeenSeconds == 60
    and defaults.vignetteRadarMarkerSize == 9 and defaults.vignetteRadarScale == 1.8,
    "numeric preferences must stay inside supported bounds")

VignetteRadarDB = { vignetteRadarQuietCombat = false }
local migrated = {}
assert(loadfile(sourcePath))("VignetteRadar", migrated)
assert(migrated.GetSettings().vignetteRadarKeepVisibleCombat == true,
    "existing users who disabled combat quiet mode should retain a visible radar")

io.write("vignette radar settings migration tests passed\n")
