local _, addon = ...
if type(addon) ~= "table" then return end

local Style = {}
addon.VignetteRadarStyle = Style
Style.revision = 0

Style.order = { "verdant", "ember", "frost", "violet", "amber", "mono", "rose", "ocean" }
Style.names = { verdant = "Verdant", ember = "Ember", frost = "Frost", violet = "Violet",
    amber = "Amber", mono = "Mono", rose = "Rose", ocean = "Ocean" }
Style.slots = { "accent", "rings", "heading", "background", "rare", "boss", "treasure", "event", "other", "quest" }
Style.labels = { accent = "Player / UI", rings = "Range rings", heading = "Facing cue",
    background = "Radar surface", rare = "Rare", boss = "World boss", treasure = "Treasure",
    event = "Event", other = "Other", quest = "Quest dots" }

local presets = {
    verdant = { accent = { .05, .82, .62 }, rings = { .05, .82, .62 }, heading = { .05, .82, .62 },
        background = { .015, .022, .028 }, rare = { .78, .88, 1 }, boss = { 1, .18, .12 },
        treasure = { 1, .68, .16 }, event = { .67, .42, 1 }, other = { .66, .72, .76 },
        quest = { 1, .74, .27 } },
    ember = { accent = { 1, .43, .22 }, rings = { .84, .31, .18 }, heading = { 1, .61, .32 },
        background = { .045, .020, .019 }, rare = { 1, .64, .40 }, boss = { 1, .12, .10 },
        treasure = { 1, .82, .31 }, event = { .95, .44, .62 }, other = { .75, .68, .65 },
        quest = { 1, .84, .38 } },
    frost = { accent = { .34, .75, 1 }, rings = { .25, .58, .89 }, heading = { .65, .88, 1 },
        background = { .013, .027, .043 }, rare = { .78, .90, 1 }, boss = { 1, .35, .31 },
        treasure = { .98, .83, .41 }, event = { .65, .58, 1 }, other = { .59, .76, .86 },
        quest = { .98, .83, .41 } },
    violet = { accent = { .70, .47, 1 }, rings = { .49, .35, .86 }, heading = { .86, .68, 1 },
        background = { .025, .019, .041 }, rare = { .75, .67, 1 }, boss = { 1, .31, .51 },
        treasure = { 1, .72, .33 }, event = { .93, .45, .96 }, other = { .68, .66, .79 },
        quest = { 1, .78, .46 } },
    amber = { accent = { 1, .72, .26 }, rings = { .75, .52, .19 }, heading = { 1, .86, .46 },
        background = { .036, .029, .017 }, rare = { 1, .88, .62 }, boss = { 1, .31, .18 },
        treasure = { 1, .66, .13 }, event = { .92, .51, .27 }, other = { .75, .69, .56 },
        quest = { 1, .83, .35 } },
    mono = { accent = { .78, .84, .85 }, rings = { .66, .75, .77 }, heading = { 1, 1, 1 },
        background = { .017, .020, .022 }, rare = { 1, 1, 1 }, boss = { 1, .43, .40 },
        treasure = { .91, .77, .48 }, event = { .74, .71, .91 }, other = { .58, .63, .65 },
        quest = { .91, .77, .48 } },
    rose = { accent = { 1, .47, .67 }, rings = { .86, .36, .57 }, heading = { 1, .72, .82 },
        background = { .038, .018, .030 }, rare = { 1, .72, .83 }, boss = { 1, .20, .29 },
        treasure = { 1, .78, .46 }, event = { .82, .50, 1 }, other = { .76, .65, .72 },
        quest = { 1, .78, .46 } },
    ocean = { accent = { .12, .84, .90 }, rings = { .12, .60, .70 }, heading = { .45, .94, 1 },
        background = { .010, .029, .037 }, rare = { .55, .88, 1 }, boss = { 1, .34, .30 },
        treasure = { 1, .79, .33 }, event = { .48, .68, 1 }, other = { .55, .72, .76 },
        quest = { 1, .79, .33 } },
}

function Style.PresetColor(name, slot)
    local value = presets[name] and presets[name][slot or "accent"]
    if value then return value[1], value[2], value[3] end
end

local function ValidColor(value)
    return type(value) == "table" and type(value[1]) == "number" and type(value[2]) == "number"
        and type(value[3]) == "number" and value[1] == value[1] and value[2] == value[2]
        and value[3] == value[3] and value[1] >= 0 and value[1] <= 1
        and value[2] >= 0 and value[2] <= 1 and value[3] >= 0 and value[3] <= 1
end

function Style.Color(slot)
    local db = addon.GetSettings()
    local custom = db.vignetteRadarColors
    local value = type(custom) == "table" and custom[slot]
    if ValidColor(value) then return value[1], value[2], value[3] end
    local theme = presets[db.vignetteRadarTheme] or presets.verdant
    value = theme[slot] or presets.verdant[slot] or presets.verdant.accent
    return value[1], value[2], value[3]
end

function Style.SetColor(slot, r, g, b)
    if not Style.labels[slot] then return false end
    if not ValidColor({ r, g, b }) then return false end
    local db = addon.GetSettings()
    if type(db.vignetteRadarColors) ~= "table" then db.vignetteRadarColors = {} end
    db.vignetteRadarColors[slot] = { r, g, b }
    Style.revision = Style.revision + 1
    return true
end

function Style.ClearColor(slot)
    local colors = addon.GetSettings().vignetteRadarColors
    if type(colors) == "table" then colors[slot] = nil; Style.revision = Style.revision + 1 end
end

function Style.SetTheme(name)
    if not presets[name] then return false end
    local db = addon.GetSettings()
    db.vignetteRadarTheme = name
    db.vignetteRadarColors = {}
    Style.revision = Style.revision + 1
    return true
end

function Style.IsCustomized()
    local colors = addon.GetSettings().vignetteRadarColors
    return type(colors) == "table" and next(colors) ~= nil
end
