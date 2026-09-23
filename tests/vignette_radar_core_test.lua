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
assert(defaults.vignetteRadarEnabled == true and defaults.vignetteRadarHideWhenEmpty == true
    and defaults.vignetteRadarLauncherVisible == true and defaults.vignetteRadarRange == 450,
    "the radar must work without either optional addon installed")
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
    and defaults.vignetteRadarMarkerSize == 7 and defaults.vignetteRadarShapes == true
    and defaults.vignetteRadarShowHealth == true,
    "feature preferences need complete defaults")
defaults.vignetteRadarAlertCooldown = -100
defaults.vignetteRadarLastSeenSeconds = 10000
defaults.vignetteRadarMarkerSize = 100
fresh.GetSettings()
assert(defaults.vignetteRadarAlertCooldown == 5 and defaults.vignetteRadarLastSeenSeconds == 60
    and defaults.vignetteRadarMarkerSize == 9, "numeric preferences must stay inside supported bounds")

io.write("vignette radar settings migration tests passed\n")
