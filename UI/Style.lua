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

local function HueColor(hue, saturation, value)
    local position = (hue % 1) * 6
    local sector = math.floor(position)
    local fraction = position - sector
    local minimum = value * (1 - saturation)
    local rising = value * (1 - saturation * (1 - fraction))
    local falling = value * (1 - saturation * fraction)
    if sector == 0 then return { value, rising, minimum } end
    if sector == 1 then return { falling, value, minimum } end
    if sector == 2 then return { minimum, value, rising } end
    if sector == 3 then return { minimum, falling, value } end
    if sector == 4 then return { rising, minimum, value } end
    return { value, minimum, falling }
end

-- Additional palettes share legible category contrast while changing the
-- instrument's color family, background tint, and event marker treatment.
local additional = {
    { "mint", "Mint", .44, .63 }, { "jade", "Jade", .47, .88 },
    { "moss", "Moss", .27, .58 }, { "lime", "Lime", .22, .88 },
    { "neon", "Neon", .32, 1 }, { "pine", "Pine", .41, .74 },
    { "copper", "Copper", .075, .82 }, { "rust", "Rust", .035, .83 },
    { "solar", "Solar", .12, .94 }, { "sand", "Sand", .105, .47 },
    { "ivory", "Ivory", .13, .20 }, { "slate", "Slate", .60, .27 },
    { "steel", "Steel", .57, .48 }, { "ash", "Ash", .60, .10 },
    { "ruby", "Ruby", .97, .89 }, { "cherry", "Cherry", .00, .80 },
    { "coral", "Coral", .02, .70 }, { "peach", "Peach", .07, .56 },
    { "lilac", "Lilac", .76, .51 }, { "plum", "Plum", .80, .77 },
    { "dusk", "Dusk", .69, .59 }, { "arctic", "Arctic", .53, .43 },
    { "cobalt", "Cobalt", .62, .84 }, { "lagoon", "Lagoon", .49, .82 },
}
for _, definition in ipairs(additional) do
    local key, label, hue, saturation = definition[1], definition[2], definition[3], definition[4]
    local accent = HueColor(hue, saturation, 1)
    local rare = HueColor(.59 + hue * .07, .34, 1)
    local treasure = HueColor(.105 + hue * .025, .80, 1)
    presets[key] = {
        accent = accent,
        rings = HueColor(hue, saturation * .78, .82),
        heading = HueColor(hue, saturation * .52, 1),
        background = { .010 + accent[1] * .024, .013 + accent[2] * .024,
            .017 + accent[3] * .024 },
        rare = rare,
        boss = HueColor(.005 + hue * .012, .88, 1),
        treasure = treasure,
        event = HueColor(hue + .40, .72, 1),
        other = HueColor(hue, .22, .82),
        quest = HueColor(.105 + hue * .025, .67, 1),
    }
    Style.order[#Style.order + 1] = key
    Style.names[key] = label
end

function Style.HasTheme(name)
    return presets[name] ~= nil
end

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
