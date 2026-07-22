local _, SMK = ...

local Store = {}
local Config = SMK.Config
local Util = SMK.Util

local cacheDirty = true
local cachedEntries = {}
local mapIndex = {}
local persistentKeys = {
    "mapID", "x", "y", "name", "categoryKey", "icon", "showPin", "pinTextureID", "keywords",
}

local function GetCategoryLabel(categoryKey)
    local category = Config.categoryByKey[categoryKey]
    return category and (SMK.L[category.nameKey] or category.key)
        or (SMK.L.CAT_OTHER or Config.defaultCategoryKey)
end

local function NormalizeLocation(values)
    if type(values) ~= "table" then return nil, "invalid location" end
    local entry = {
        mapID = tonumber(values.mapID),
        x = tonumber(values.x),
        y = tonumber(values.y),
        name = Util.Trim(values.name),
        categoryKey = Config.GetCategoryKey(values.categoryKey or values.category),
        icon = values.icon or Config.art.defaultLocationIcon,
        showPin = (values.showPin == true or tonumber(values.showPin) == 1) and 1 or 0,
        keywords = values.keywords ~= nil and Util.Trim(values.keywords) or nil,
    }
    local pinTextureID = tonumber(values.pinTextureID or values.pinTexture)
    entry.pinTextureID = pinTextureID and SMK.PinTextureByID[pinTextureID] and pinTextureID or 1
    if entry.keywords == "" then entry.keywords = nil end
    if not entry.mapID or entry.mapID <= 0 or entry.mapID % 1 ~= 0
        or not entry.x or entry.x < 0 or entry.x > 100
        or not entry.y or entry.y < 0 or entry.y > 100
        or entry.name == "" then
        return nil, "invalid location"
    end
    local ok, length = pcall(strlenutf8, entry.name)
    if not ok or length > Config.location.maxNameLength then
        return nil, "invalid location"
    end
    return entry
end

local function BuildSavedEntry(entry, index)
    local display = NormalizeLocation(entry)
    if not display then return end
    display.id = entry.id
    display.source = "saved"
    display.sourceIndex = index
    display.categoryLabel = GetCategoryLabel(display.categoryKey)
    display.normalizedName = Util.Normalize(display.name)
    display.normalizedSearchable = Util.Normalize(display.name .. " " .. (display.keywords or ""))
    return display
end

local function RebuildCache()
    local entries = {}
    local newMapIndex = {}
    for index, entry in ipairs(SMK.DB:Get().locations) do
        local display = BuildSavedEntry(entry, index)
        if display then
            entries[#entries + 1] = display
            local map = newMapIndex[display.mapID]
            if not map then
                map = {}
                newMapIndex[display.mapID] = map
            end
            map[#map + 1] = display
        end
    end
    cachedEntries = entries
    mapIndex = newMapIndex
    cacheDirty = false
end

function Store:GetCategory(entry)
    return GetCategoryLabel(entry and entry.categoryKey or Config.defaultCategoryKey)
end

function Store:NormalizeCategory(category)
    return Config.GetCategoryKey(category)
end

function Store:NormalizeLocation(values)
    return NormalizeLocation(values)
end

function Store:IsValid(entry)
    return NormalizeLocation(entry) ~= nil
end

function Store:InvalidateCache()
    cacheDirty = true
end

function Store:GetAll()
    if cacheDirty then RebuildCache() end
    return cachedEntries
end

function Store:GetByMap(mapID)
    if cacheDirty then RebuildCache() end
    return mapIndex[mapID] or {}
end

function Store:Add(values)
    if SMK.DB:IsReadOnly() then return nil, "database read-only" end
    local entry, errorMessage = NormalizeLocation(values)
    if not entry then return nil, errorMessage end
    local database = SMK.DB:Get()
    entry.id = SMK.DB:NextLocationID()
    database.locations[#database.locations + 1] = entry
    self:InvalidateCache()
    return BuildSavedEntry(entry, #database.locations)
end

function Store:Update(entry, values)
    if SMK.DB:IsReadOnly() then return false, "database read-only" end
    if type(entry) ~= "table" or not entry.id then return false end
    local normalized = NormalizeLocation(values)
    if not normalized then return false end
    local database = SMK.DB:Get()
    local target = database.locations[entry.sourceIndex]
    if not target or target.id ~= entry.id then
        target = nil
        for _, candidate in ipairs(database.locations) do
            if type(candidate) == "table" and candidate.id == entry.id then
                target = candidate
                break
            end
        end
    end
    if not target then return false end
    for _, key in ipairs(persistentKeys) do target[key] = normalized[key] end
    self:InvalidateCache()
    return true
end

function Store:DeleteMany(entries)
    if SMK.DB:IsReadOnly() then return 0, "database read-only" end
    local database = SMK.DB:Get()
    local requestedIDs = {}
    for _, entry in ipairs(entries or {}) do
        if type(entry) == "table" and entry.id then requestedIDs[entry.id] = true end
    end
    local deleted = 0
    for index = #database.locations, 1, -1 do
        local entry = database.locations[index]
        if type(entry) == "table" and requestedIDs[entry.id] then
            database.usageCounts["id:" .. entry.id] = nil
            table.remove(database.locations, index)
            deleted = deleted + 1
        end
    end
    if deleted > 0 then self:InvalidateCache() end
    return deleted
end

function Store:Delete(entry)
    return self:DeleteMany({ entry })
end

function Store:DeleteByCategory(category)
    local categoryKey = Config.GetCategoryKey(category)
    local matches = {}
    for _, entry in ipairs(self:GetAll()) do
        if entry.categoryKey == categoryKey then matches[#matches + 1] = entry end
    end
    return matches
end

function Store:DeleteByMap(mapID)
    local matches = {}
    for _, entry in ipairs(self:GetByMap(mapID)) do matches[#matches + 1] = entry end
    return matches
end

function Store:FindDuplicate(values, excludeEntry)
    if not values or not values.mapID then return end
    local normalizedName = Util.Normalize(values.name)
    for _, entry in ipairs(self:GetByMap(tonumber(values.mapID))) do
        if not (excludeEntry and excludeEntry.id == entry.id)
            and entry.normalizedName == normalizedName then
            return entry, string.format(SMK.L.DUPLICATE_NAME, entry.name)
        end
    end
end

local function UsageKey(entry)
    return "id:" .. tostring(entry and entry.id)
end

function Store:GetUsage(entry)
    return tonumber(SMK.DB:Get().usageCounts[UsageKey(entry)]) or 0
end

function Store:RecordUsage(entry)
    if SMK.DB:IsReadOnly() then return false end
    local counts = SMK.DB:Get().usageCounts
    local key = UsageKey(entry)
    counts[key] = self:GetUsage(entry) + 1
    return true
end

function Store:GetDuplicateKey(entry)
    local mapID = math.floor(tonumber(entry.mapID) or 0)
    local x = math.floor((tonumber(entry.x) or 0) * 100 + 0.5)
    local y = math.floor((tonumber(entry.y) or 0) * 100 + 0.5)
    return table.concat({ mapID, Util.Normalize(entry.name), x, y }, "\031")
end

SMK.Store = Store
