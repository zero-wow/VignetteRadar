local _, addon = ...
if type(addon) ~= "table" then return end

-- The expensive radar render calculates positions and quest geometry. When
-- only the player's facing changes, rotate those saved positions instead.
local Turn = {}
addon.VignetteRadarTurn = Turn

local TWO_PI = math.pi * 2

local function Number(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function Normalize(angle)
    angle = angle % TWO_PI
    if angle > math.pi then angle = angle - TWO_PI end
    return angle
end

function Turn.TrackPoint(region, x, y, facing)
    if not region then return end
    if not (Number(x) and Number(y) and Number(facing)) then
        region._turnFacing = nil
        return
    end
    region._turnX, region._turnY, region._turnFacing = x, y, facing
end

function Turn.TrackLine(line, x1, y1, x2, y2, facing)
    if not line then return end
    if not (Number(x1) and Number(y1) and Number(x2) and Number(y2)
        and Number(facing)) then
        line._turnFacing = nil
        return
    end
    line._turnX1, line._turnY1, line._turnX2, line._turnY2, line._turnFacing =
        x1, y1, x2, y2, facing
end

local function Rotate(x, y, sine, cosine)
    return x * cosine + y * sine, y * cosine - x * sine
end

local function MovePoint(region, center, facing)
    if not (region and Number(region._turnFacing)
        and (not region.IsShown or region:IsShown())) then return end
    local delta = Normalize(facing - region._turnFacing)
    if math.abs(delta) < .003 then return end
    local x, y = Rotate(region._turnX, region._turnY, math.sin(delta), math.cos(delta))
    region:SetPoint("CENTER", center, "CENTER", x, y)
    if region.screenX ~= nil then region.screenX, region.screenY = x, y end
end

local function MoveLine(line, center, facing)
    if not (line and Number(line._turnFacing)
        and (not line.IsShown or line:IsShown())) then return end
    local delta = Normalize(facing - line._turnFacing)
    if math.abs(delta) < .003 then return end
    local sine, cosine = math.sin(delta), math.cos(delta)
    local x1, y1 = Rotate(line._turnX1, line._turnY1, sine, cosine)
    local x2, y2 = Rotate(line._turnX2, line._turnY2, sine, cosine)
    line:SetStartPoint("CENTER", center, x1, y1)
    line:SetEndPoint("CENTER", center, x2, y2)
end

local function MovePoints(collection, center, facing)
    if type(collection) ~= "table" then return end
    for _, region in ipairs(collection) do MovePoint(region, center, facing) end
end

local function MoveLines(collection, center, facing)
    if type(collection) ~= "table" then return end
    for _, line in pairs(collection) do MoveLine(line, center, facing) end
end

function Turn.UpdateRadar(panel, facing)
    if not (panel and panel.field and Number(facing)) then return false end
    if panel._turnFacing and math.abs(Normalize(facing - panel._turnFacing)) < .003 then
        return false
    end
    panel._turnFacing = facing
    local center = panel.field
    MovePoints(panel.blips, center, facing)
    MovePoints(panel.questDots, center, facing)
    if panel.questDots then
        for _, dot in ipairs(panel.questDots) do MovePoint(dot.halo, center, facing) end
    end
    MovePoints(panel.mapNotes, center, facing)
    MovePoints(panel.questStartDots, center, facing)
    MovePoints(panel.edgeCues, center, facing)
    MovePoints(panel.exploreDots, center, facing)
    MovePoints(panel.trailDots, center, facing)
    MovePoints(panel.cardinals, center, facing)
    MovePoint(panel.activeCue, center, facing)
    MoveLines(panel.exploreLines, center, facing)
    MoveLines(panel.trailMarks, center, facing)
    MoveLines(panel.trailExtraMarks, center, facing)
    return true
end

function Turn.UpdateLauncher(launcher, facing)
    if not (launcher and launcher.instrument and Number(facing)) then return false end
    if launcher._turnFacing and math.abs(Normalize(facing - launcher._turnFacing)) < .003 then
        return false
    end
    launcher._turnFacing = facing
    MovePoints(launcher.miniBlips, launcher.instrument, facing)
    return true
end

function Turn.Interval(owner, throttled)
    if throttled then return .10 end
    if not owner then return .033 end
    local count = #(owner.blips or owner.miniBlips or {})
        + #(owner.questDots or {}) + #(owner.mapNotes or {})
        + #(owner.trailDots or {}) + #(owner.trailMarks or {})
        + #(owner.trailExtraMarks or {})
    return count > 160 and .067 or count > 80 and .05 or .033
end
