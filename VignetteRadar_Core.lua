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
    return db
end

addon.GetSettings()
