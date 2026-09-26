local _, addon = ...
if type(addon) ~= "table" then return end

-- Small, detached route recipes. A pack path supplies coordinates, not proof
-- that a switch was used or a treasure was looted.
local Playbooks = {}
addon.VignetteRadarTreasurePlaybooks = Playbooks

local MAX_STEPS, MAX_TEXT = 12, 160
local KINDS = { location = true, interaction = true,
    quest_condition = true, instruction = true, treasure = true }

local function Safe(value)
    if type(issecretvalue) ~= "function" then return true end
    local ok, secret = pcall(issecretvalue, value)
    return ok and not secret
end

local function Field(source, key)
    if type(source) ~= "table" or not Safe(source) then return nil end
    local ok, result = pcall(function() return source[key] end)
    return ok and Safe(result) and result or nil
end

local function Number(value)
    return Safe(value) and type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge and value or nil
end

local function PositiveInteger(value)
    value = Number(value)
    return value and value > 0 and value == math.floor(value) and value or nil
end

local function Position(source)
    local mapID, x, y = PositiveInteger(Field(source, "mapID")),
        Number(Field(source, "mapX")), Number(Field(source, "mapY"))
    if not (mapID and x and y and x >= 0 and x <= 1
        and y >= 0 and y <= 1) then return nil end
    local position = { mapID = mapID, mapX = x, mapY = y }
    local worldX, worldY = Number(Field(source, "worldX")),
        Number(Field(source, "worldY"))
    if worldX and worldY then
        position.worldX, position.worldY = worldX, worldY
    end
    local instanceID = Number(Field(source, "instanceID"))
    if instanceID then position.instanceID = instanceID end
    return position
end

local function Text(value, fallback)
    if type(value) ~= "string" or not Safe(value) or value == "" then
        return fallback
    end
    return value:sub(1, MAX_TEXT)
end

local function Step(source, index, treasure)
    local kind = Field(source, "kind")
    if not KINDS[kind] then return nil, "Invalid step type at " .. index end
    local result = { kind = kind, name = Text(Field(source, "name"),
        kind == "treasure" and "Loot Treasure" or "Step " .. index),
        state = "pending" }
    local instruction = Field(source, "instruction")
    if type(instruction) == "string" and Safe(instruction) and instruction ~= "" then
        result.instruction = instruction:sub(1, MAX_TEXT)
    end
    local position = Position(source)
    if kind == "treasure" then position = position or Position(treasure) end
    if (kind == "location" or kind == "treasure") and not position then
        return nil, "Step needs an explicit position at " .. index
    end
    if position then
        for key, value in pairs(position) do result[key] = value end
    end
    result.objectID = PositiveInteger(Field(source, "objectID"))
    result.itemID = PositiveInteger(Field(source, "itemID"))
    result.questID = PositiveInteger(Field(source, "questID"))
    if kind == "quest_condition" and not result.questID then
        return nil, "Quest condition needs a quest ID at " .. index
    end
    if kind == "instruction" and not result.instruction then
        return nil, "Instruction text required at " .. index
    end
    return result
end

local function Recipe(treasure, metadata)
    local explicit = Field(metadata, "steps")
    if explicit ~= nil then
        if type(explicit) ~= "table" or not Safe(explicit)
            or #explicit < 1 or #explicit > MAX_STEPS then
            return nil, "Step count must be 1-12"
        end
        return explicit
    end
    local recipe, route = {}, Field(treasure, "route")
    if type(route) == "table" and Safe(route) then
        for index = 1, math.min(#route - 1, MAX_STEPS - 1) do
            if not Position(route[index]) then break end
            recipe[#recipe + 1] = {
                kind = "location", name = index == 1 and "Reach Entrance"
                    or "Follow Path " .. index, mapID = route[index].mapID,
                mapX = route[index].mapX, mapY = route[index].mapY,
                worldX = route[index].worldX, worldY = route[index].worldY,
                instanceID = route[index].instanceID,
            }
        end
    end
    recipe[#recipe + 1] = { kind = "treasure", name = "Loot Treasure",
        objectID = Field(treasure, "objectID"),
        itemID = Field(treasure, "itemID"),
        questID = Field(treasure, "questID") }
    return recipe
end

function Playbooks.New(treasure, metadata)
    if type(treasure) ~= "table" or not Safe(treasure)
        or Field(treasure, "kind") ~= "treasure" or not Position(treasure) then
        return nil, "Treasure needs a mapped position"
    end
    local key = Text(Field(treasure, "key"), nil)
    if not key then return nil, "Treasure needs a stable key" end
    local recipe, problem = Recipe(treasure, metadata)
    if not recipe then return nil, problem end
    local book = { version = 1, key = key,
        name = Text(Field(treasure, "name"), "Treasure"),
        source = Text(Field(metadata, "source"),
            Text(Field(treasure, "source"), "Map Data")),
        steps = {}, current = 1, state = "active" }
    for index = 1, #recipe do
        local step, err = Step(recipe[index], index, treasure)
        if not step then return nil, err end
        if step.kind == "treasure" and index ~= #recipe then
            return nil, "Treasure must be the final step"
        end
        book.steps[index] = step
    end
    if book.steps[#book.steps].kind ~= "treasure" then
        if #book.steps >= MAX_STEPS then return nil, "No room for final treasure" end
        book.steps[#book.steps + 1] = assert(Step({ kind = "treasure" },
            #book.steps + 1, treasure))
    end
    return book
end

function Playbooks.Current(book)
    if type(book) ~= "table" or book.state ~= "active" then return nil end
    return book.steps and book.steps[book.current]
end

local function Advance(book, result)
    local step = Playbooks.Current(book)
    if not step then return false end
    step.state = result
    book.current = book.current + 1
    if book.current > #book.steps then
        book.state = result == "confirmed" and "complete" or "skipped"
    end
    return true, Playbooks.Current(book)
end

-- Only explicit event evidence can confirm a step. Arrival may be displayed
-- by the caller but cannot confirm loot or an interaction.
function Playbooks.Confirm(book, evidence)
    local step = Playbooks.Current(book)
    if not step or type(evidence) ~= "table" or not Safe(evidence) then return false end
    local kind = Field(evidence, "kind")
    local id = PositiveInteger(Field(evidence, "id"))
    local confirmed = Field(evidence, "confirmed") == true
    if not confirmed then return false end
    if step.kind == "interaction" then
        if kind == "interaction" and id and step.objectID == id then
            return Advance(book, "confirmed")
        end
    elseif step.kind == "quest_condition" then
        if kind == "quest" and id == step.questID
            and Field(evidence, "complete") == true then
            return Advance(book, "confirmed")
        end
    elseif step.kind == "treasure" then
        if kind == "loot" and id and (id == step.objectID or id == step.itemID) then
            return Advance(book, "confirmed")
        end
        if kind == "quest" and id and id == step.questID
            and Field(evidence, "complete") == true then
            return Advance(book, "confirmed")
        end
        if kind == "treasure" and Field(evidence, "key") == book.key
            and Field(evidence, "lootConfirmed") == true then
            return Advance(book, "confirmed")
        end
    end
    return false
end

-- Next Step is a manual acknowledgement, not a loot confirmation.
function Playbooks.Next(book)
    local step = Playbooks.Current(book)
    if not step or step.kind == "treasure" then return false end
    return Advance(book, "manual")
end

function Playbooks.Skip(book)
    return Advance(book, "skipped")
end

function Playbooks.Reset(book)
    if type(book) ~= "table" or type(book.steps) ~= "table" then return false end
    book.current, book.state = 1, "active"
    for index = 1, math.min(#book.steps, MAX_STEPS) do
        book.steps[index].state = "pending"
    end
    return true
end
