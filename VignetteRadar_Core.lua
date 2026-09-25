local _, addon = ...
if type(addon) ~= "table" then return end

BINDING_HEADER_VIGNETTERADAR = "Vignette Radar"
BINDING_NAME_VIGNETTERADAR_RAISE_LAUNCHER = "Hold to Raise Launcher"
BINDING_NAME_VIGNETTERADAR_PEEK_RADAR = "Hold to Peek at Full Radar"
BINDING_NAME_VIGNETTERADAR_HOLD_LENS = "Hold to Filter Radar"
BINDING_NAME_VIGNETTERADAR_FOCUS_NEXT = "World Focus: Next Point"
BINDING_NAME_VIGNETTERADAR_FOCUS_PREVIOUS = "World Focus: Previous Point"
BINDING_NAME_VIGNETTERADAR_TOGGLE_RADAR = "Toggle Radar"
BINDING_NAME_VIGNETTERADAR_TOGGLE_SETTINGS = "Toggle Radar Settings"
BINDING_NAME_VIGNETTERADAR_TOGGLE_BEARING = "Toggle Bearing Bar"
BINDING_NAME_VIGNETTERADAR_TOGGLE_ROUTE = "Auto Route: Start, Pause, or Resume"
BINDING_NAME_VIGNETTERADAR_PIN_ZYGOR = "Pin Zygor's Current Step"
BINDING_NAME_VIGNETTERADAR_ROUTE_RARE = "Auto Route: Nearest Rare"
BINDING_NAME_VIGNETTERADAR_ROUTE_TREASURE = "Auto Route: Nearest Treasure"
BINDING_NAME_VIGNETTERADAR_ROUTE_QUEST = "Auto Route: Nearest Quest Point"
BINDING_NAME_VIGNETTERADAR_QUEST_STEP_PREVIOUS = "Quest Route: Previous Step"
BINDING_NAME_VIGNETTERADAR_QUEST_STEP_NEXT = "Quest Route: Next Step"
BINDING_NAME_VIGNETTERADAR_CLEAR_FOCUS = "World Focus: Clear Waypoint"

addon.VignetteRadarRanges = { 10, 25, 50, 100, 150, 300, 450, 600, 1200, 2400, 4800 }
addon.VignetteRadarLayouts = { "classic", "squat", "compact" }

local MIGRATED_KEYS = {
    "vignetteRadarEnabled",
    "vignetteRadarHideWhenEmpty",
    "vignetteRadarRange",
    "vignetteRadarLauncherVisible",
    "vignetteRadarPosition",
    "vignetteRadarLauncherPosition",
    "vignetteRadarCategories",
    "vignetteRadarHighlight",
}

local TRAIL_STYLES = {
    { id="dashes", label="Dashes", spacing=12, segments={{-3.5,0,3.5,0,2.5}} },
    { id="ticks", label="Ticks", spacing=14, segments={{0,-3.5,0,3.5,2}} },
    { id="dots", label="Dots", spacing=9, dot=5 },
    { id="squares", label="Squares", spacing=12, square=5 },
    { id="hollow-squares", label="Hollow squares", spacing=15,
        segments={{-3,-3,3,-3,1.5},{3,-3,3,3,1.5},{3,3,-3,3,1.5},{-3,3,-3,-3,1.5}} },
    { id="long", label="Long dashes", spacing=17, segments={{-5.5,0,5.5,0,2}} },
    { id="slashes", label="Slashes", spacing=13, segments={{-3,-3,3,3,2}} },
    { id="chevrons", label="Chevrons", spacing=15,
        segments={{-3,-3,2,0,2},{2,0,-3,3,2}} },
    { id="crosses", label="Crosses", spacing=16,
        segments={{-3,-3,3,3,1.8},{-3,3,3,-3,1.8}} },
    { id="diamonds", label="Diamonds", spacing=18,
        segments={{-4,0,0,3,1.6},{0,3,4,0,1.6},{4,0,0,-3,1.6},{0,-3,-4,0,1.6}} },
    { id="beads", label="Beads", spacing=12, dot=6, alternating=true },
    { id="pulses", label="Pulses", spacing=14, segments={{-4,0,4,0,2.5}}, alternating=true },
}
local TRAIL_STYLE_KEYS = {}
for _, definition in ipairs(TRAIL_STYLES) do TRAIL_STYLE_KEYS[definition.id] = definition end
addon.VignetteRadarTrailStyles = TRAIL_STYLES
addon.VignetteRadarTrailStyleByID = TRAIL_STYLE_KEYS
local TRAIL_SETTING_VALUES = {
    vignetteRadarTrailSpacing = { .5, .65, .75, 1, 1.25, 1.5, 2 },
    vignetteRadarTrailSpeed = { 0, .25, .5, .75, 1, 1.25, 1.5, 2, 3, 4 },
    vignetteRadarTrailSize = { .1, .25, .5, .75, 1, 1.25, 1.5, 2 },
}
addon.VignetteRadarTrailSettingValues = TRAIL_SETTING_VALUES
local function TrailSetting(db, key, default)
    for _, value in ipairs(TRAIL_SETTING_VALUES[key]) do
        if db[key] == value then return end
    end
    db[key] = default
end

local function CopySavedValue(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do
        if type(key) == "string" and (type(item) == "boolean" or type(item) == "number" or type(item) == "string") then
            copy[key] = item
        end
    end
    return copy
end

function addon.GetSettings()
    if type(VignetteRadarDB) ~= "table" then
        VignetteRadarDB = {}
        -- The old addon is optional; when it is installed, preserve the user's
        -- radar choices and draggable positions without sharing its DB forever.
        if type(WaffleHouseDB) == "table" then
            for _, key in ipairs(MIGRATED_KEYS) do
                if WaffleHouseDB[key] ~= nil then
                    VignetteRadarDB[key] = CopySavedValue(WaffleHouseDB[key])
                end
            end
        end
    end

    local db = VignetteRadarDB
    if type(db.vignetteRadarEnabled) ~= "boolean" then db.vignetteRadarEnabled = true end
    if type(db.vignetteRadarHideWhenEmpty) ~= "boolean" then db.vignetteRadarHideWhenEmpty = true end
    if type(db.vignetteRadarLauncherVisible) ~= "boolean" then db.vignetteRadarLauncherVisible = true end
    -- dev.67 enabled the screen-space bar automatically. Return it to an
    -- explicit opt-in once, then preserve every later on/off choice.
    if db.vignetteRadarBearingBarDefaulted ~= true then
        db.vignetteRadarBeaconsEnabled = false
        db.vignetteRadarBearingBarDefaulted = true
    end
    if type(db.vignetteRadarBeaconsEnabled) ~= "boolean" then db.vignetteRadarBeaconsEnabled = false end
    if db.vignetteRadarPerformance ~= "standard" and db.vignetteRadarPerformance ~= "balanced"
        and db.vignetteRadarPerformance ~= "low" then db.vignetteRadarPerformance = "standard" end
    if type(db.vignetteRadarWorldFocusEnabled) ~= "boolean" then db.vignetteRadarWorldFocusEnabled = true end
    if type(db.vignetteRadarWorldFocusAutoAdvance) ~= "boolean" then db.vignetteRadarWorldFocusAutoAdvance = false end
    if type(db.vignetteRadarWorldFocusRoutes) ~= "boolean" then db.vignetteRadarWorldFocusRoutes = true end
    if type(db.vignetteRadarWorldFocusSavedNotes) ~= "boolean" then db.vignetteRadarWorldFocusSavedNotes = false end
    if type(db.vignetteRadarWorldFocusZygor) ~= "boolean" then db.vignetteRadarWorldFocusZygor = false end
    if type(db.vignetteRadarFollowZygor) ~= "boolean" then db.vignetteRadarFollowZygor = false end
    if db.vignetteRadarZygorMode ~= "objective" and db.vignetteRadarZygorMode ~= "travel" then
        db.vignetteRadarZygorMode = "objective"
    end
    if type(db.vignetteRadarAutoRouteOnSelect) ~= "boolean" then db.vignetteRadarAutoRouteOnSelect = false end
    if type(db.vignetteRadarRouteArrow) ~= "boolean" then db.vignetteRadarRouteArrow = true end
    if type(db.vignetteRadarAutoRouteMapNotes) ~= "boolean" then db.vignetteRadarAutoRouteMapNotes = true end
    if type(db.vignetteRadarWorldFocusThemedWaypoint) ~= "boolean" then db.vignetteRadarWorldFocusThemedWaypoint = true end
    if db.vignetteRadarAutoRouteArrivalRadius ~= 10 and db.vignetteRadarAutoRouteArrivalRadius ~= 20
        and db.vignetteRadarAutoRouteArrivalRadius ~= 40 then
        db.vignetteRadarAutoRouteArrivalRadius = 10
    end
    if db.vignetteRadarAutoRouteTravel ~= "auto" and db.vignetteRadarAutoRouteTravel ~= "ground"
        and db.vignetteRadarAutoRouteTravel ~= "flying" then db.vignetteRadarAutoRouteTravel = "auto" end
    if db.vignetteRadarWorldFocusArrivalRadius ~= 10 and db.vignetteRadarWorldFocusArrivalRadius ~= 20
        and db.vignetteRadarWorldFocusArrivalRadius ~= 40 then db.vignetteRadarWorldFocusArrivalRadius = 20 end
    if type(db.vignetteRadarBeaconRares) ~= "boolean" then db.vignetteRadarBeaconRares = true end
    if type(db.vignetteRadarBeaconTreasures) ~= "boolean" then db.vignetteRadarBeaconTreasures = true end
    if type(db.vignetteRadarBeaconQuests) ~= "boolean" then db.vignetteRadarBeaconQuests = true end
    if db.vignetteRadarBeaconRange ~= 150 and db.vignetteRadarBeaconRange ~= 450
        and db.vignetteRadarBeaconRange ~= 1200 and db.vignetteRadarBeaconRange ~= 2400 then
        db.vignetteRadarBeaconRange = 1200
    end
    if db.vignetteRadarBeaconMax ~= 4 and db.vignetteRadarBeaconMax ~= 8
        and db.vignetteRadarBeaconMax ~= 12 and db.vignetteRadarBeaconMax ~= 16
        and db.vignetteRadarBeaconMax ~= 24 then
        db.vignetteRadarBeaconMax = 8
    end
    local validRange = false
    for _, range in ipairs(addon.VignetteRadarRanges) do
        if db.vignetteRadarRange == range then
            validRange = true
            break
        end
    end
    if not validRange then db.vignetteRadarRange = 450 end
    local validLayout = false
    for _, layout in ipairs(addon.VignetteRadarLayouts) do
        if db.vignetteRadarLayout == layout then
            validLayout = true
            break
        end
    end
    if not validLayout then db.vignetteRadarLayout = "classic" end
    if type(db.vignetteRadarScale) ~= "number" or db.vignetteRadarScale ~= db.vignetteRadarScale
        or db.vignetteRadarScale == math.huge or db.vignetteRadarScale == -math.huge then
        db.vignetteRadarScale = 1
    else
        db.vignetteRadarScale = math.max(0.8, math.min(1.8, db.vignetteRadarScale))
    end
    if type(db.vignetteRadarNorthUp) ~= "boolean" then db.vignetteRadarNorthUp = false end
    if type(db.vignetteRadarWorldMap) ~= "boolean" then db.vignetteRadarWorldMap = true end
    if type(db.vignetteRadarQuestDots) ~= "boolean" then db.vignetteRadarQuestDots = false end
    if type(db.vignetteRadarQuestAreas) ~= "boolean" then db.vignetteRadarQuestAreas = false end
    if type(db.vignetteRadarQuestHalos) ~= "boolean" then db.vignetteRadarQuestHalos = true end
    if type(db.vignetteRadarQuestColors) ~= "boolean" then db.vignetteRadarQuestColors = true end
    if type(db.vignetteRadarQuestAreaColors) ~= "boolean" then db.vignetteRadarQuestAreaColors = false end
    if db.vignetteRadarQuestAreaColorsReset ~= true then
        db.vignetteRadarQuestAreaColors = false
        db.vignetteRadarQuestAreaColorsReset = true
    end
    if type(db.vignetteRadarNextQuestStep) ~= "boolean" then db.vignetteRadarNextQuestStep = false end
    if type(db.vignetteRadarQuestStartBadges) ~= "boolean" then db.vignetteRadarQuestStartBadges = false end
    if type(db.vignetteRadarQuestNumbers) ~= "boolean" then db.vignetteRadarQuestNumbers = false end
    if type(db.vignetteRadarDataStatus) ~= "boolean" then db.vignetteRadarDataStatus = false end
    if type(db.vignetteRadarLensEnabled) ~= "boolean" then db.vignetteRadarLensEnabled = false end
    if db.vignetteRadarLensCategory ~= "quest" and db.vignetteRadarLensCategory ~= "rare"
        and db.vignetteRadarLensCategory ~= "treasure" then db.vignetteRadarLensCategory = "quest" end
    if db.vignetteRadarRouteDraftStops ~= 3 and db.vignetteRadarRouteDraftStops ~= 4
        and db.vignetteRadarRouteDraftStops ~= 5 then db.vignetteRadarRouteDraftStops = 5 end
    if db.vignetteRadarRouteDraftRange ~= 300 and db.vignetteRadarRouteDraftRange ~= 600
        and db.vignetteRadarRouteDraftRange ~= 1200 then db.vignetteRadarRouteDraftRange = 1200 end
    local haloRadius = db.vignetteRadarQuestHaloRadius
    if haloRadius ~= 10 and haloRadius ~= 20 and haloRadius ~= 40 and haloRadius ~= 80 then
        db.vignetteRadarQuestHaloRadius = 10
    end
    if type(db.vignetteRadarFollowTrackedQuest) ~= "boolean" then db.vignetteRadarFollowTrackedQuest = false end
    if type(db.vignetteRadarEdgeCues) ~= "boolean" then db.vignetteRadarEdgeCues = true end
    if type(db.vignetteRadarEmptyHelp) ~= "boolean" then db.vignetteRadarEmptyHelp = true end
    if type(db.vignetteRadarPeekEnabled) ~= "boolean" then db.vignetteRadarPeekEnabled = true end
    if type(db.vignetteRadarHoverTools) ~= "boolean" then db.vignetteRadarHoverTools = true end
    if type(db.vignetteRadarControlsVisible) ~= "boolean" then db.vignetteRadarControlsVisible = true end
    if type(db.vignetteRadarIndependentViews) ~= "boolean" then db.vignetteRadarIndependentViews = false end
    if type(db.vignetteRadarViewProfiles) ~= "table" then db.vignetteRadarViewProfiles = {} end
    if type(db.vignetteRadarQuestKeyProgress) ~= "boolean" then db.vignetteRadarQuestKeyProgress = true end
    if type(db.vignetteRadarGuideSeen) ~= "boolean" then db.vignetteRadarGuideSeen = false end
    if type(db.vignetteRadarRouteAutoAdvance) ~= "boolean" then db.vignetteRadarRouteAutoAdvance = false end
    if db.vignetteRadarRouteArrivalRadius ~= 10 and db.vignetteRadarRouteArrivalRadius ~= 20
        and db.vignetteRadarRouteArrivalRadius ~= 40 then db.vignetteRadarRouteArrivalRadius = 20 end
    if type(db.vignetteRadarPOISource) ~= "string" then db.vignetteRadarPOISource = "auto" end
    if type(db.vignetteRadarPOIZoneSources) ~= "table" then db.vignetteRadarPOIZoneSources = {} end
    if type(db.vignetteRadarPOIIcons) ~= "boolean" then db.vignetteRadarPOIIcons = false end
    if type(db.vignetteRadarHideCleared) ~= "boolean" then db.vignetteRadarHideCleared = false end
    if type(db.vignetteRadarRecentKills) ~= "table" then db.vignetteRadarRecentKills = {} end
    if type(db.vignetteRadarPOITypes) ~= "table" then db.vignetteRadarPOITypes = {} end
    for kind, enabled in pairs({ treasure = true, mob = true, item = true, note = true,
        entrance = true, guide = true }) do
        if type(db.vignetteRadarPOITypes[kind]) ~= "boolean" then
            db.vignetteRadarPOITypes[kind] = enabled
        end
    end
    if type(db.vignetteRadarAlerts) ~= "boolean" then db.vignetteRadarAlerts = true end
    if type(db.vignetteRadarAlertSound) ~= "boolean" then db.vignetteRadarAlertSound = false end
    if type(db.vignetteRadarAlertCategories) ~= "table" then db.vignetteRadarAlertCategories = {} end
    for category, enabled in pairs({ rare = true, treasure = true, event = false, other = false }) do
        if type(db.vignetteRadarAlertCategories[category]) ~= "boolean" then
            db.vignetteRadarAlertCategories[category] = enabled
        end
    end
    if type(db.vignetteRadarAlertCooldown) ~= "number" or db.vignetteRadarAlertCooldown ~= db.vignetteRadarAlertCooldown then
        db.vignetteRadarAlertCooldown = 60
    else
        db.vignetteRadarAlertCooldown = math.max(5, math.min(3600, db.vignetteRadarAlertCooldown))
    end
    if type(db.vignetteRadarFavorites) ~= "table" then db.vignetteRadarFavorites = {} end
    if type(db.vignetteRadarIgnored) ~= "table" then db.vignetteRadarIgnored = {} end
    if type(db.vignetteRadarLastSeen) ~= "boolean" then db.vignetteRadarLastSeen = true end
    if type(db.vignetteRadarLastSeenSeconds) ~= "number" or db.vignetteRadarLastSeenSeconds ~= db.vignetteRadarLastSeenSeconds then
        db.vignetteRadarLastSeenSeconds = 10
    else
        db.vignetteRadarLastSeenSeconds = math.max(1, math.min(60, db.vignetteRadarLastSeenSeconds))
    end
    if type(db.vignetteRadarQuietCombat) ~= "boolean" then db.vignetteRadarQuietCombat = true end
    if type(db.vignetteRadarQuietInstances) ~= "boolean" then db.vignetteRadarQuietInstances = true end
    if type(db.vignetteRadarKeepVisibleCombat) ~= "boolean" then
        -- Older versions tied combat fading to alert muting. Preserve their
        -- visual choice when these two controls become independent.
        db.vignetteRadarKeepVisibleCombat = db.vignetteRadarQuietCombat == false
    end
    if type(db.vignetteRadarCircleOnly) ~= "boolean" then db.vignetteRadarCircleOnly = true end
    if type(db.vignetteRadarMarkerSize) ~= "number" or db.vignetteRadarMarkerSize ~= db.vignetteRadarMarkerSize then
        db.vignetteRadarMarkerSize = 7
    else
        db.vignetteRadarMarkerSize = math.max(5, math.min(9, db.vignetteRadarMarkerSize))
    end
    if type(db.vignetteRadarShapes) ~= "boolean" then db.vignetteRadarShapes = true end
    if type(db.vignetteRadarShowHealth) ~= "boolean" then db.vignetteRadarShowHealth = true end
    if type(db.vignetteRadarFullSweep) ~= "boolean" then db.vignetteRadarFullSweep = false end
    if type(db.vignetteRadarSmartZoom) ~= "boolean" then db.vignetteRadarSmartZoom = false end
    if type(db.vignetteRadarUntangle) ~= "boolean" then db.vignetteRadarUntangle = true end
    if type(db.vignetteRadarBreadcrumbs) ~= "boolean" then db.vignetteRadarBreadcrumbs = false end
    if not TRAIL_STYLE_KEYS[db.vignetteRadarTrailStyle] then db.vignetteRadarTrailStyle = "dashes" end
    TrailSetting(db, "vignetteRadarTrailSpacing", 1)
    TrailSetting(db, "vignetteRadarTrailSpeed", 1)
    if type(db.vignetteRadarTrailSize) ~= "number" or db.vignetteRadarTrailSize ~= db.vignetteRadarTrailSize then
        db.vignetteRadarTrailSize = 1
    end
    db.vignetteRadarTrailSize = math.max(.1, math.min(2, db.vignetteRadarTrailSize))
    if type(db.vignetteRadarTrailTailFade) ~= "number" or db.vignetteRadarTrailTailFade ~= db.vignetteRadarTrailTailFade then
        db.vignetteRadarTrailTailFade = .5
    end
    db.vignetteRadarTrailTailFade = math.max(0, math.min(1, db.vignetteRadarTrailTailFade))
    if type(db.vignetteRadarTrailFadeSpan) ~= "number" or db.vignetteRadarTrailFadeSpan ~= db.vignetteRadarTrailFadeSpan then
        db.vignetteRadarTrailFadeSpan = 1
    end
    db.vignetteRadarTrailFadeSpan = math.max(0, math.min(1, db.vignetteRadarTrailFadeSpan))
    if type(db.vignetteRadarTrailLifetime) ~= "number"
        or db.vignetteRadarTrailLifetime ~= math.floor(db.vignetteRadarTrailLifetime)
        or db.vignetteRadarTrailLifetime < 1 or db.vignetteRadarTrailLifetime > 300 then
        db.vignetteRadarTrailLifetime = 180
    end
    if type(db.vignetteRadarApproachAlerts) ~= "boolean" then db.vignetteRadarApproachAlerts = false end
    if type(db.vignetteRadarApproachDistance) ~= "number" then db.vignetteRadarApproachDistance = 100 end
    db.vignetteRadarApproachDistance = math.max(25, math.min(600, db.vignetteRadarApproachDistance))
    if type(db.vignetteRadarJournalEnabled) ~= "boolean" then db.vignetteRadarJournalEnabled = false end
    if type(db.vignetteRadarPins) ~= "table" then db.vignetteRadarPins = {} end
    if type(db.vignetteRadarRoute) ~= "table" then db.vignetteRadarRoute = {} end
    if type(db.vignetteRadarJournal) ~= "table" then db.vignetteRadarJournal = {} end
    if type(db.vignetteRadarCustomPresets) ~= "table" then db.vignetteRadarCustomPresets = {} end
    local style = addon.VignetteRadarStyle
    if (style and not style.HasTheme(db.vignetteRadarTheme))
        or (not style and type(db.vignetteRadarTheme) ~= "string") then
        db.vignetteRadarTheme = "verdant"
    end
    if type(db.vignetteRadarColors) ~= "table" then db.vignetteRadarColors = {} end
    local appearance = {
        vignetteRadarRingOpacity = { .5, 0, 2 },
        vignetteRadarChevronOpacity = { .72, 0, 1 },
        vignetteRadarHeadingOpacity = { .46, 0, 1 },
        vignetteRadarChevronDistance = { 4, 2, 9 },
        vignetteRadarHeadingLength = { .30, .12, .8 },
    }
    for key, limits in pairs(appearance) do
        local value = db[key]
        if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
            db[key] = limits[1]
        else
            db[key] = math.max(limits[2], math.min(limits[3], value))
        end
    end
    local labelOpacity = db.vignetteRadarRangeLabelOpacity
    if type(labelOpacity) ~= "number" or labelOpacity ~= labelOpacity
        or labelOpacity == math.huge or labelOpacity == -math.huge then
        -- Existing characters start with text matching their current rings.
        db.vignetteRadarRangeLabelOpacity = db.vignetteRadarRingOpacity
    else
        db.vignetteRadarRangeLabelOpacity = math.max(0, math.min(16, labelOpacity))
    end
    return db
end

-- View profiles are opt-in so existing saved layouts continue to share their
-- range and scale until the player explicitly separates them.
addon.VignetteRadarViewProfiles = {}
function addon.VignetteRadarViewProfiles.Key(db)
    return db.vignetteRadarCircleOnly and "radarOnly" or db.vignetteRadarLayout
end
function addon.VignetteRadarViewProfiles.Record(db)
    if db.vignetteRadarIndependentViews ~= true then return end
    local key = addon.VignetteRadarViewProfiles.Key(db)
    db.vignetteRadarViewProfiles[key] = {
        range = db.vignetteRadarRange, scale = db.vignetteRadarScale,
        hoverTools = db.vignetteRadarHoverTools,
        controlsVisible = db.vignetteRadarControlsVisible,
    }
end
function addon.VignetteRadarViewProfiles.Switch(db, nextKey)
    if db.vignetteRadarIndependentViews ~= true then return end
    local profiles = db.vignetteRadarViewProfiles
    addon.VignetteRadarViewProfiles.Record(db)
    local saved = profiles[nextKey]
    if type(saved) ~= "table" then
        profiles[nextKey] = { range = db.vignetteRadarRange, scale = db.vignetteRadarScale,
            hoverTools = db.vignetteRadarHoverTools,
            controlsVisible = db.vignetteRadarControlsVisible }
        return
    end
    for _, supported in ipairs(addon.VignetteRadarRanges) do
        if saved.range == supported then db.vignetteRadarRange = supported; break end
    end
    if type(saved.scale) == "number" and saved.scale == saved.scale
        and saved.scale ~= math.huge and saved.scale ~= -math.huge then
        db.vignetteRadarScale = math.max(.8, math.min(1.8, saved.scale))
    end
    if type(saved.hoverTools) == "boolean" then db.vignetteRadarHoverTools = saved.hoverTools end
    if type(saved.controlsVisible) == "boolean" then
        db.vignetteRadarControlsVisible = saved.controlsVisible
    end
end

addon.GetSettings()
