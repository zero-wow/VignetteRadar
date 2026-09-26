local _, addon = ...
if type(addon) ~= "table" then return end

-- A reward-source link must be supplied explicitly. Collection state is
-- account-wide evidence; it says nothing about a character's loot eligibility.
local API = {}
addon.VignetteRadarCollectionLens = API

local MAX_LINKS, MAX_PER_POINT = 512, 12
local CATEGORIES = { mount=true, pet=true, toy=true, appearance=true }
local EVIDENCE = { api=true, bundled=true, ["trusted-pack"]=true, manual=true }

local function Safe(value)
    if type(issecretvalue) ~= "function" then return true end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret ~= true
end

local function Field(value, key)
    if not Safe(value) or type(value) ~= "table" then return nil end
    local ok, result = pcall(function() return value[key] end)
    if ok and Safe(result) then return result end
end

local function Text(value, limit)
    return Safe(value) and type(value) == "string" and #value > 0
        and #value <= limit and value or nil
end

local function ID(value)
    return Safe(value) and type(value) == "number" and value > 0
        and value <= 100000000 and value == math.floor(value) and value or nil
end

local function Normalize(raw)
    local sourceKey = Text(Field(raw, "sourceKey"), 160)
    local category = Field(raw, "category")
    local rewardID = ID(Field(raw, "rewardID"))
    local evidence = Field(raw, "evidence")
    if not sourceKey or not CATEGORIES[category] or not rewardID
        or not EVIDENCE[evidence] then return nil end
    return { sourceKey=sourceKey, category=category, rewardID=rewardID,
        evidence=evidence, name=Text(Field(raw, "name"), 100),
        itemID=ID(Field(raw, "itemID")), sourceName=Text(Field(raw, "sourceName"), 100) }
end

function API.New(links, resolver)
    local lens = { links={}, cache={}, resolver=nil, count=0 }
    setmetatable(lens, { __index=API })
    lens:SetResolver(resolver)
    lens:RegisterLinks(links)
    return lens
end

function API:SetResolver(resolver)
    self.resolver = type(resolver) == "function" and resolver or nil
    self.cache = {}
end

function API:RegisterLinks(links)
    self.links, self.count = {}, 0
    if type(links) ~= "table" then return 0 end
    local seen = {}
    for index = 1, math.min(#links, MAX_LINKS) do
        local link = Normalize(links[index])
        if link then
            local key = link.sourceKey .. ":" .. link.category .. ":" .. link.rewardID
            local bucket = self.links[link.sourceKey]
            if not seen[key] and (not bucket or #bucket < MAX_PER_POINT) then
                bucket = bucket or {}
                bucket[#bucket+1] = link
                self.links[link.sourceKey] = bucket
                seen[key], self.count = true, self.count + 1
            end
        end
    end
    self.cache = {}
    return self.count
end

local function CacheKey(category, rewardID)
    return category .. ":" .. rewardID
end

function API:CollectionState(category, rewardID)
    if not CATEGORIES[category] or not ID(rewardID) then
        return { status="unknown", evidence="none" }
    end
    local key = CacheKey(category, rewardID)
    if self.cache[key] then return self.cache[key] end
    local result = { status="unknown", evidence="none" }
    if self.resolver then
        local ok, response = pcall(self.resolver, category, rewardID)
        if ok and Safe(response) and type(response) == "table"
            and Field(response, "evidence") == "api" then
            local collected = Field(response, "collected")
            if type(collected) == "boolean" then
                result = { status=collected and "collected" or "uncollected",
                    evidence="api" }
            end
        end
    end
    self.cache[key] = result
    return result
end

function API:Invalidate(category, rewardID)
    if CATEGORIES[category] and ID(rewardID) then
        self.cache[CacheKey(category, rewardID)] = nil
    else
        self.cache = {}
    end
end

function API:GetRewards(sourceKeys, options)
    local keys = type(sourceKeys) == "table" and sourceKeys or { sourceKeys }
    local results, seen, linked = {}, {}, false
    for index = 1, math.min(#keys, 16) do
        local sourceKey = Text(keys[index], 160)
        local bucket = sourceKey and self.links[sourceKey]
        if bucket then
            linked = true
            for _, link in ipairs(bucket) do
                local id = CacheKey(link.category, link.rewardID)
                if not seen[id] then
                    seen[id] = true
                    local state = self:CollectionState(link.category, link.rewardID)
                    if not (type(options) == "table" and options.hideCollected
                        and state.status == "collected") then
                        results[#results+1] = {
                            sourceKey=link.sourceKey, category=link.category,
                            rewardID=link.rewardID, itemID=link.itemID,
                            name=link.name, sourceName=link.sourceName,
                            linkEvidence=link.evidence, status=state.status,
                            statusEvidence=state.evidence, eligibility="unknown",
                        }
                    end
                end
            end
        end
    end
    table.sort(results, function(a, b)
        if a.category ~= b.category then return a.category < b.category end
        return a.rewardID < b.rewardID
    end)
    return results, linked and "linked" or "unknown"
end
