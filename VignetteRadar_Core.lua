local _, addon = ...
if type(addon) ~= "table" then return end

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
    if db.vignetteRadarRange ~= 150 and db.vignetteRadarRange ~= 300
        and db.vignetteRadarRange ~= 450 and db.vignetteRadarRange ~= 600 then
        db.vignetteRadarRange = 450
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
    if type(db.vignetteRadarMarkerSize) ~= "number" or db.vignetteRadarMarkerSize ~= db.vignetteRadarMarkerSize then
        db.vignetteRadarMarkerSize = 7
    else
        db.vignetteRadarMarkerSize = math.max(5, math.min(9, db.vignetteRadarMarkerSize))
    end
    if type(db.vignetteRadarShapes) ~= "boolean" then db.vignetteRadarShapes = true end
    if type(db.vignetteRadarShowHealth) ~= "boolean" then db.vignetteRadarShowHealth = true end
    return db
end

addon.GetSettings()
